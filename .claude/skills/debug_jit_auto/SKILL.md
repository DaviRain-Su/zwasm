---
name: debug_jit_auto
description: JIT runtime debug toolkit (lldb/ndisasm/strace/SIGSEGV recipes for SEGV / miscompile investigation). Invoke when investigating SEGV, signal 11, exit code 139, mprotect issues, JIT byte stream disassembly, or any runtime crash in zwasm v2 codegen / interpreter.
---

# JIT / runtime debug toolkit — autonomous SEGV / miscompile recipes

> **Living document.** When you discover new tools, recipes, or
> workflow patterns during a debug session, **edit this file in
> the same commit as the fix** (or in a follow-up `chore(debug):`
> commit). Don't let the knowledge evaporate into chat history —
> the next debug session needs to find it via this skill's
> on-demand load. Adding a new recipe is cheap; re-deriving it from
> scratch is expensive.

Invoked when investigating SEGV / miscompile / runtime crash in JIT
codegen, interpreter, runtime, realworld runners, edge-case fixtures,
or anything under `private/spikes/`. Codifies the toolchain
established during §9.7 / 7.10-l (run-stage SEGV chunk-m investigation):
which tools live where, and copy-paste-ready batch-mode recipes that
the autonomous `/continue` loop can invoke without human-in-loop
debugger steering.

`extended_challenge.md` Step 4 explicitly authorises spikes +
WebFetch + reference-repo deep reads in autonomous scope. This file
is the **how** for runtime-debug spikes — the catalogue of tools that
already exist locally + the recipe shapes that fit the autonomous
loop.

## Tool inventory (post-7.10-l, ubuntunote-updated 2026-05-17)

| Tool | Mac (nix `flake.nix`) | ubuntunote (`apt` / `nix profile`) | Purpose |
|---|---|---|---|
| `lldb` | `pkgs.lldb` (21.x) | Nix dev-shell via `flake.nix` (21.x) | batch-mode debugger; primary autonomous tool |
| `gdb` | not in flake (darwin gdb is finicky — codesign required) | `apt install gdb` (15.x) | Linux-side alternative to lldb |
| `ndisasm` / `nasm` | `pkgs.nasm` (3.x) | `apt install nasm` (2.16.x) | raw byte stream → x86_64 disasm |
| `objdump` | clang's (in nix shell) | `apt install binutils` (default) | ELF / Mach-O disasm |
| `strace` | not on Mac (use `dtruss` Apple-native) | `apt install strace` (6.8) | mmap / mprotect syscall trace (catches RWX page issues) |
| `ltrace` | n/a | `apt install ltrace` (0.7.3) | libc / dynamic library call trace |
| `valgrind` | `pkgs.valgrind` (Linux only at flake level) | `apt install valgrind` (3.22) | heap analysis when DebugAllocator isn't enough |
| `bpftrace` | n/a (macOS lacks eBPF) | `apt install bpftrace` (0.20) + `bpfcc-tools` | kernel-level dynamic tracing (sigaction / SEGV path investigation; D-134 used `print-fatal-signals` + dmesg in lieu — `bpftrace` is the next-level escalation) |
| `perf` | n/a | `apt install linux-tools-generic` | CPU profiling, branch / cache analysis |
| `qemu-x86_64` | n/a | `apt install qemu-user-static` | cross-arch verification (run an x86_64 ELF under emulation) — useful for sanity-checking what the *native* x86_64 hardware does vs an emulator |
| `readelf` / `nm` | clang's | binutils default | ELF inspection |
| `xxd` | available | available | hex dump / patch |
| `file` | available | `apt install file` | quick arch / format identification |

**Not viable / out of scope**: `rr` (record-and-replay) — needs
perf counters that virtualised hosts often don't expose
correctly; not yet installed on ubuntunote. If true record-
replay is needed on the native x86_64 host, run on bare metal
with `rr record` directly. **D-134's investigation** (LD_PRELOAD
sigaction shim + handler-entry probe + dmesg
`print-fatal-signals` + vanilla C reproducer) is documented in
the canonical pattern at
[`.dev/lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md`](../../.dev/lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md);
the same shape applies to future SIGSEGV / signal-handling
oddities.

The `.dev/ubuntunote_setup.md` document carries the canonical
apt-vs-nix decision table (system-level vs project-pinned).
`.dev/orbstack_setup.md` is retained but reflects OrbStack's
**dev-scratch-only** role per ADR-0067 — debug tools listed
there are duplicates of the ubuntunote inventory at a slightly
older version.

## Autonomous recipe 1 — `lldb -b` first triage

For "where exactly does the SEGV happen" — fastest path:

```bash
lldb -b \
  -o "settings set target.x86-disassembly-flavor intel" \
  -o "process launch -- <argv>" \
  -o "register read" \
  -o "disassemble --pc --count 20" \
  -o "memory read --size 1 --count 256 \$pc" \
  -o "thread backtrace" \
  -o "quit" \
  ./path/to/binary 2>&1 | tee /tmp/lldb-segv.log
```

**Key flags**:
- `-b` = batch mode (auto-quit when commands finish)
- `-o "cmd"` = lldb command to execute in order
- `process launch -- <argv>` = pass argv to the process
- After SEGV, `register read` + `disassemble --pc` show the faulting site

**Reading the output**:
- `RIP` (x86_64) / `PC` (arm64) = faulting instruction address
- Subtract from `block.bytes.ptr` (printed by emit-pass diag) →
  byte offset within the JIT block
- Use `objdump -d -b binary -m i386:x86-64 -M intel` (or
  `ndisasm -b 64 -o <base>`) to disasm that byte range from the
  hex dump

## Autonomous recipe 2 — `ndisasm` for raw JIT byte stream

When the spike has dumped JIT block hex and we need to know
"what x86_64 instructions does this byte sequence decode to":

```bash
# Hex dump from spike code: write block.bytes to /tmp/jit.bin
ndisasm -b 64 /tmp/jit.bin | head -40
# Or with arbitrary base address (matches lldb's $pc display):
ndisasm -b 64 -o 0x1000 /tmp/jit.bin

# objdump alternative:
objdump -D -b binary -m i386:x86-64 -M intel /tmp/jit.bin | head -40
```

Both work; `ndisasm` is a single line of output per insn (easier
to grep). `objdump` matches lldb's display style.

## Autonomous recipe 3 — `strace` for mmap / mprotect inspection

When suspecting JIT block protection (e.g. RWX → RX transition
not happening, or `PROT_EXEC` not applied):

```bash
# ubuntunote only (Mac uses dtruss):
ssh ubuntunote 'cd ~/Documents/MyProducts/zwasm_from_scratch &&
    strace -f -e trace=mmap,mprotect,munmap \
        ./<binary> 2>&1' | grep -E "^mmap|^mprotect" | tail -20
```

Look for:
- `mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)`
- `mprotect(addr, size, PROT_READ|PROT_EXEC)` — JIT block flip
- A `mprotect` with `PROT_EXEC = 4` flag is the executable transition

Mac equivalent (root-required):
```bash
sudo dtruss -f -t mprotect ./binary 2>&1 | tail -20
```

## Autonomous recipe 4 — SIGSEGV handler (no debugger)

When neither lldb nor gdb is available (or the segfault happens
before main reaches a debuggable state), install a Zig signal
handler in the spike code:

```zig
// In private/spikes/jit_segv/main.zig
const std = @import("std");

fn segvHandler(sig: c_int, info: *const std.posix.siginfo_t, ctx: ?*const anyopaque) callconv(.c) noreturn {
    _ = sig;
    _ = ctx;
    const fault_addr = info.fields.sigfault.addr;
    std.debug.print("\nSEGV at fault_addr={*} (siginfo)\n", .{fault_addr});
    // Print extracted RIP from the ucontext (platform-specific)
    // ... (see std.os.linux.ucontext for layout)
    std.process.exit(139);
}

pub fn main() !void {
    var act: std.posix.Sigaction = .{
        .handler = .{ .sigaction = &segvHandler },
        .mask = std.posix.empty_sigset,
        .flags = std.posix.SA.SIGINFO,
    };
    try std.posix.sigaction(std.posix.SIG.SEGV, &act, null);

    // ... reproduce the SEGV here ...
}
```

This buys the autonomous loop fault-address visibility WITHOUT
shelling out to a debugger. `siginfo_t.fields.sigfault.addr` is
the faulting memory address; the exact offset within the JIT
block is `(fault_addr - block.bytes.ptr)`.

## Autonomous recipe 5 — `private/spikes/jit_segv/` skeleton

When the realworld_run_jit runner segfaults but it's hard to
isolate which fixture / which op, build a minimal in-process
spike:

```
private/spikes/jit_segv/
├── README.md            ← what we're testing + findings
├── minimal.wasm.hex     ← hand-crafted 1-function wasm bytes
├── main.zig             ← compileWasm + dump bytes + invoke
└── build.zig            ← Zig build harness (maybe `zig build-exe`)
```

`extended_challenge.md` Step 4 grants spikes ≤ 1 day; outcomes
land as ADR (if rejected) / lesson (if observational) /
production code (if the fix). The `private/spikes/` directory
is gitignored — only the lessons / ADRs persist.

## Recipe 6 — bisection by Wasm op

Hand-craft a series of progressively-larger wasm modules to
binary-search the SEGV-triggering op family:

1. `(func)` — empty
2. `(func) (i32.const 0) (drop)` — i32.const + drop
3. `(func) (i32.const 0) (i32.const 0) (i32.add) (drop)` — i32.add
4. `(func (param i32)) (local.get 0) (drop)` — local.get
5. ... continue until SEGV reproduces.

Each step → compile → invoke → check exit code. The op family
that flips from "exit 0" to "SIGSEGV" is the regression source.
Bisection cost: log₂(N) compiles to localise to ≤ 1 op family.

## Recipe 7 — crash-time JIT context dump (async-signal-safe)

When a SEGV reproduces inside the JIT body and you want fault
context (faulting address, surrounding bytes, RIP) WITHOUT a
debugger attached, install a `SA.SIGINFO` handler that writes
raw bytes via async-signal-safe primitives only. Reference
implementation: `test/spec/spec_assert_runner_base.zig`
(`sigsegvHandler` + `installSigsegvHandler`). The pattern:

```zig
const std = @import("std");

fn handler(sig: c_int, info: *const std.posix.siginfo_t, _: ?*const anyopaque) callconv(.c) noreturn {
    _ = sig;
    // siginfo.fields.sigfault.addr is the faulting address.
    // Async-signal-safe: only raw writes; no allocator, no
    // formatted std.debug.print (which acquires a mutex).
    const fault_addr = @intFromPtr(info.fields.sigfault.addr);
    var buf: [128]u8 = undefined;
    const n = std.fmt.bufPrint(&buf, "SEGV at 0x{x}\n", .{fault_addr}) catch buf[0..0];
    _ = std.posix.write(std.posix.STDERR_FILENO, n) catch {};
    std.c._exit(142);  // 142 distinct from 139 to disambiguate
                       // "our handler ran" vs "kernel killed us".
}

// In main, before invoking the JIT:
const SS = 1 << 18;  // 256 KB altstack — required for stack-
                     // exhaustion SEGV cases (assert_exhaustion).
var stack: [SS]u8 align(std.heap.page_size_max) = undefined;
std.posix.sigaltstack(&.{ .sp = &stack, .flags = 0, .size = SS }, null) catch {};
var act: std.posix.Sigaction = .{
    .handler = .{ .sigaction = &handler },
    .mask = std.posix.sigemptyset(),
    .flags = std.posix.SA.ONSTACK | std.posix.SA.SIGINFO,
};
std.posix.sigaction(.SEGV, &act, null);
// Optionally also SIGBUS for Mach-side mis-aligned access:
std.posix.sigaction(.BUS, &act, null);
```

**Don't do** in a signal handler:
- `std.debug.print` (acquires a mutex, deadlocks if interrupted
  thread held it).
- Allocator calls (likewise re-entrant).
- `std.fs` / `std.Io` non-raw paths.
- Any libc function not in the POSIX async-signal-safe list
  (`man 7 signal-safety`).

**Do**:
- `std.posix.write` to a fixed-size stack buffer.
- `std.c._exit` (not `exit` — atexit handlers may not be
  async-signal-safe).
- `siglongjmp` to a previously-set `sigsetjmp` recovery point
  (use only when the saved frame is provably alive).

**Exit-code disambiguation** (d-71 lesson): pick an exit code
DIFFERENT from `139` (= 128 + SIGSEGV, the kernel's default
exit code when no handler installed). Otherwise a
`zig build` report of "exited with code 139" is ambiguous
between "your handler ran and chose 139" and "the kernel
killed the process before your handler installed". The
spec_assert runner uses `142` for this reason.

**When to factor out**: while only one site uses this pattern
today, the second site (e.g. a JIT-execution sentinel runner
for cross-host differential diagnosis per ADR-0034) should
extract a `src/diagnostic/jit_dump.zig` module rather than
duplicate. Until then, copy the pattern from spec_assert and
adapt the recovery target.

## Recipe 8 — fault-address poison-pattern decoding (FIRST step on every SEGV)

Per D-142 cycle 6 (2026-05-17): **the very first action on any
SEGV is to capture the fault address from `siginfo_t.addr`
via SA_SIGINFO and decode its pattern**. The pattern usually
identifies the bug class in seconds, narrowing which recipe
above to invoke next.

The infrastructure is already in place at
`test/spec/spec_assert_runner_base.zig::sigsegvHandler`
(SA_SIGINFO upgrade landed in commit `dd0cd332`); the
unarmed-branch trace emits
`(handler-entry=N last-armed=M fault-addr=0xNNNN...)`
automatically. For new SEGV-prone code paths, install the same
sa_sigaction + `siginfo.addr` emission pattern.

### Pattern cheatsheet

| Fault address pattern | Likely cause | Decode example |
|---|---|---|
| `0xAA...AA` ± small offset | Zig `undefined` poison (Debug only) — uninitialised memory dereferenced. The low byte reveals the offset from the poison base: `0xB2 = 0xAA + 8`, `0xCC = 0xAA + 0x22`, etc. | `0xaaaaaaaaaaaaaab2` ⇒ uninit pointer deref at `+8`. Trace back: which field is at offset 8 of an extern struct that was constructed with `.foo = undefined`? See `.claude/rules/zig_tips.md` `undefined in extern struct` entry. |
| `0xCC...CC` ± small offset | x86 INT3 / Zig safety-stub remnant. Often inside a freed or de-init'd region. | grep for `@memset(buf, 0xCC)` or look for use-after-free. |
| `0xDEADBEEF` / `0xDEAD_DEAD` | Sentinel value. Check `linker.IMPORT_SENTINEL_OFFSET` (`0xFFFF_FFFF`), `@ptrFromInt(0xDEADBEEF)` patterns. | grep `0xDEAD` / `IMPORT_SENTINEL`. |
| `0xFFFF_FFFF` / `0xFFFF_FFFF_FFFF_FFFF` | sentinel "no value"; for slices, `len = maxInt(u32)` etc. | check the slice's len/cap fields. |
| Near current SP (within 8 KB of `mov sp, sp`) | Stack-guard hit (stack overflow). | compare against pthread stack info via `pthread_attr_getstack`; check for deep recursion. |
| Mac aarch64 `0x1xx_xxxxxx` | `.text` or MAP_JIT region. Cross-check `otool -tv <binary>` (Recipe 1 / 2). | likely a code-address fault (bad function pointer load or RX page that wasn't mapped X). |
| Linux x86_64 `0x40_xxxx_xxxx` / `0x55_xxxx_xxxx` | `.text` or MAP_JIT region. | `/proc/self/maps` cross-check. |
| `0x0` or low (< 0x1000) | NULL deref. | trivially `*null`; check optional unwrap sites. |
| Large random-looking address (e.g. `0x7fff_xxxx_xxxx`) | Likely valid stack / heap area but wrong contents. | use Recipe 1 to capture register state + check pointer provenance. |

### Why first-step

Without the fault address, every SEGV investigation starts by
guessing the bug class from the symptom. The address narrows
the search **before** committing to a specific recipe. D-142
spent 5 cycles rejecting hypotheses (PAC, siglongjmp re-entry,
altstack, layout, MAP_JIT-flip) before the fault-address
emission landed; cycle 6 identified the poison pattern in
under a minute.

### When the pattern doesn't match the cheatsheet

Capture the address anyway and add a row to this table in
the same commit that closes the bug. The cheatsheet's
value is cumulative.

## When to invoke each recipe (decision tree)

```
SEGV reproduces in test-realworld-run-jit?
├── YES → Recipe 1 (lldb -b) for first triage. Read fault RIP.
│        ├── RIP inside JIT block (block.bytes.ptr ≤ RIP < ptr+len)?
│        │   ├── YES → Recipe 2 (ndisasm) on the byte range.
│        │   │        Identify the faulting x86 insn → trace back
│        │   │        to the emit-pass site that produced it.
│        │   │        → Likely candidates: prologue stack
│        │   │          alignment, spill region overflow, trap
│        │   │          stub address calc.
│        │   └── NO → not in JIT body. Check entry shim
│        │            (entry.zig), runtime ptr passing, or
│        │            JitRuntime layout (Recipe 3).
│        └── Crash before lldb attaches?
│            └── Recipe 4 (SIGSEGV handler) instead.
│
├── NO but suspect mprotect issue?
│   └── Recipe 3 (strace) for mmap/mprotect timeline.
│
└── Hard to localise to one fixture?
    └── Recipe 5 (spike) + Recipe 6 (bisection).
```

## Lessons / ADR landing

Per `.claude/rules/lessons_vs_adr.md`:
- Spike outcome that's observational ("we tried X, learned Y") →
  lesson at `.dev/lessons/<date>-<slug>.md`
- Spike outcome that's load-bearing decision ("X is rejected
  because Y") → ADR at `.dev/decisions/NNNN_<slug>.md`
- Production fix → normal source commit

Always cite the concrete `lldb -b` output / `ndisasm` line / etc.
in the commit body — the recipe + finding lineage matters for
future-you debugging similar SEGVs.

## How this file evolves (meta — read on every load)

This file is a **living toolkit**, not a frozen reference. The
autonomous loop is expected to extend it whenever new ground is
covered. Concretely:

- **New tool installed** (Mac via `flake.nix` / `pkgs.X` or
  Ubuntu via `apt install Y`)? Add it to the **Tool inventory**
  table with one-line purpose. Mention which platform.
- **New recipe figured out** (e.g. a specific `gdb -ex` chain
  that auto-extracts JIT bytes around a crash, or a `strace`
  filter that catches a particular runtime quirk)? Add it as
  a numbered Recipe with a copy-paste block.
- **Tried-and-rejected tool** (e.g. `rr` requires perf counters
  that aren't exposed everywhere)? Note it in **Not viable** /
  **Not in scope** so the next session doesn't re-pay the trial
  cost.
- **Tool installation gap discovered** (e.g. ndisasm missing
  on a host)? Update `.dev/ubuntunote_setup.md` / `flake.nix`
  AND the inventory table here in the same commit.

**Edit triggers** (when this skill is loaded, scan for these):
- Are you about to debug a SEGV / miscompile / runtime crash?
  → Apply the decision tree at the bottom.
- Did you just finish such a debug session?
  → Did you use a tool / recipe NOT documented here? Add it.
- Did you install a new tool to the dev environment? → Inventory
  table.

**Don't be precious about edits.** A new recipe with rough
copy-paste output is more valuable than a polished prose entry.
Aim for "future-me can grep this file and find the exact
incantation" not "this reads like documentation".

## Cross-references

- `extended_challenge.md` — autonomous self-resolution discipline
  (spikes, WebFetch, reference-repo deep reads). This skill is
  the toolkit; that rule is the policy.
- `lessons_vs_adr.md` — where to land the FINDINGS (lesson vs
  ADR vs production code).
- `bug_fix_survey.md` — once root-caused, grep for siblings.
- `.dev/ubuntunote_setup.md` — canonical apt/Nix install lines
  for the native x86_64 Linux gate host (post-ADR-0067).
- `.dev/orbstack_setup.md` — retained for dev-scratch use only
  (no longer the per-chunk gate host per ADR-0067).
- `.dev/windows_ssh_setup.md` — windowsmini setup (no JIT debug
  workflow yet — Windows-side JIT crashes need their own
  recipes; add when first encountered).
