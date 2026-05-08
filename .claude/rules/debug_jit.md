---
paths:
  - "src/engine/codegen/**/*.zig"
  - "src/engine/runner.zig"
  - "src/engine/interp/**/*.zig"
  - "src/runtime/**/*.zig"
  - "test/realworld/**/*.zig"
  - "test/runners/**/*.zig"
  - "test/edge_cases/**/*.zig"
  - "private/spikes/**/*.zig"
  - "private/spikes/**/*.md"
  - "private/dbg/**"
  - ".dev/lessons/*-segv-*.md"
  - ".dev/lessons/*-jit-*.md"
  - ".dev/lessons/*-debug-*.md"
---

# JIT / runtime debug toolkit — autonomous SEGV / miscompile recipes

> **Living document.** When you discover new tools, recipes, or
> workflow patterns during a debug session, **edit this file in
> the same commit as the fix** (or in a follow-up `chore(debug):`
> commit). Don't let the knowledge evaporate into chat history —
> the next debug session needs to find it via this file's
> auto-load. Adding a new recipe is cheap; re-deriving it from
> scratch is expensive.

Auto-loaded when editing JIT codegen / interpreter / runtime
sources, realworld runners, edge-case fixtures, or anything
under `private/spikes/`. Codifies the toolchain established
during §9.7 / 7.10-l (run-stage SEGV chunk-m investigation):
which tools live where, and copy-paste-ready batch-mode recipes
that the autonomous `/continue` loop can invoke without
human-in-loop debugger steering.

`extended_challenge.md` Step 4 explicitly authorises spikes +
WebFetch + reference-repo deep reads in autonomous scope. This
file is the **how** for runtime-debug spikes — the catalogue of
tools that already exist locally + the recipe shapes that fit
the autonomous loop.

## Tool inventory (post-7.10-l)

| Tool | Mac (nix `flake.nix`) | OrbStack Ubuntu (`apt`) | Purpose |
|---|---|---|---|
| `lldb` | `pkgs.lldb` (21.x) | `apt install lldb` (20.x) | batch-mode debugger; primary autonomous tool |
| `gdb` | not in flake (darwin gdb is finicky — codesign required) | `apt install gdb` (16.x) | Linux-side alternative to lldb |
| `ndisasm` | `pkgs.nasm` (3.x) | `apt install nasm` | raw byte stream → x86_64 disasm |
| `objdump` | clang's (in nix shell) | `apt install binutils` (default) | ELF / Mach-O disasm |
| `strace` | not on Mac (use `dtruss` Apple-native) | `apt install strace` | mmap / mprotect syscall trace (catches RWX page issues) |
| `readelf` / `nm` | clang's | binutils default | ELF inspection |
| `xxd` | available | available | hex dump / patch |

**Not viable in OrbStack**: `rr` (record-and-replay) — VM doesn't
expose perf counters; `ptrace EIO` on every `rr record`. If true
record-replay is needed, run on a bare-metal Linux x86_64 box.

**Not in scope here**: `valgrind` (overkill for JIT), `radare2`
(too heavy; `ndisasm` covers raw bytes), `pwntools` (not yet
needed).

The `.dev/orbstack_setup.md` document carries the canonical
`apt install` line for the OrbStack VM provisioning.

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
# OrbStack only (Mac uses dtruss):
strace -f -e trace=mmap,mprotect,munmap \
  ./binary 2>&1 | grep -E "^mmap|^mprotect" | tail -20
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
- **Tried-and-rejected tool** (e.g. `rr` failed on OrbStack)?
  Note it in **Not viable in OrbStack** / **Not in scope** so
  the next session doesn't re-pay the trial cost.
- **Tool installation gap discovered** (e.g. ndisasm missing
  on a host)? Update `.dev/orbstack_setup.md` / `flake.nix` AND
  the inventory table here in the same commit.

**Edit triggers** (when this rule auto-loads, scan for these):
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
  (spikes, WebFetch, reference-repo deep reads). This rule is
  the toolkit; that rule is the policy.
- `lessons_vs_adr.md` — where to land the FINDINGS (lesson vs
  ADR vs production code).
- `bug_fix_survey.md` — once root-caused, grep for siblings.
- `.dev/orbstack_setup.md` — canonical apt install line for the
  OrbStack VM.
- `.dev/windows_ssh_setup.md` — windowsmini setup (no JIT debug
  workflow yet — Windows-side JIT crashes need their own
  recipes; add when first encountered).
