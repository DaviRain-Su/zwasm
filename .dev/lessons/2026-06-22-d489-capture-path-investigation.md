# D-489 — JIT stdout-capture path corrupts a guest value (x86_64-linux only)

**Symptom**: `tinygo_json.wasm` under JIT prints CORRECT (90B) via the direct CLI
(`zwasm run … --engine jit`, real-fd stdout) but CORRUPT (130B, Go fmt
`%!(EXTRA …)` + `roundtrip: FAIL`) when stdout is CAPTURED to a buffer
(`runWasmJitCaptured` with `host.stdout_buffer` set). The only code diff is in
`src/wasi/fd.zig:writeSlice` (~157): `buffer.appendSlice(…)` (capture) vs
`std_stream.writeStreamingAll(io)` (real-fd). **This is what the diff-jit gate's
tinygo_json MISMATCH actually is — NOT a codegen miscompile** (direct JIT is
correct, so the `.auto`→JIT flip is NOT blocked by a real miscompile; the gate
gives a false signal via the capture path). x86_64-LINUX ONLY (arm64 + Rosetta
x86_64-macos both MASK it). Deterministic, optimize-INDEPENDENT (Debug/ReleaseSafe/
ReleaseFast all 130; ReleaseSafe does NOT panic).

**Minimal repro (committed)**: `zig build d489-repro` (`test/realworld/d489_repro.zig`)
— scenario(1) "jit-alone" = 130 on x86_64-linux only.

## Hypotheses DEFINITIVELY ruled out (do NOT re-walk)
- **Registers** — an UNCONDITIONAL asm clobber of ALL caller-saved GPRs
  (r10/r11/rcx/rdx/rsi/rdi/r8/r9) at `jit_dispatch.fd_write` return left the
  non-capture CLI CORRECT (90). Callee-saved are host-preserved (callconv .c).
  → JIT relies on NO register value across the host call.
- **JIT frame / SysV red zone** — a +4096 prologue frame pad (`emit.zig:297`)
  did NOT fix it. Spills are RBP-relative within the SUB-RSP frame, not below RSP.
- **Heap layout** — pre-sized capture buffer (no realloc) AND an 8 MB heap pad
  both still 130. Not allocation/adjacency.
- **rodata overwrite** — `ZWASM_DEBUG=fmtwatch` shows the fmt format string
  ("name=%s age=%d city=%s" @guest-off 86586) INTACT at all 9 fd_writes. So the
  corrupted thing is a guest VALUE (the format-slice ptr/len fmt receives), not
  the bytes.
- **Build env** — a Mac-CROSS-built x86_64-linux-gnu binary on ubuntu = identical.

**Remaining**: a pure MEMORY/DATA effect of heap-write(appendSlice) vs
syscall(writeStreamingAll). NEXT = rr/gdb reverse-debug the wrong guest value.

## TIPS (hard-won — for the next session)
- **FAST LOOP**: edit on Mac → `zig build [d489-repro] -Dtarget=x86_64-linux-gnu
  [-Doptimize=Debug]` → `scp` the ELF to `ubuntunote:/tmp/` → run on ubuntu. NO
  slow remote nix build. (Cross-build runs the run-step on Mac which fails for
  the d489-repro exe — ignore; the ELF is already in `.zig-cache`, `find` it.)
- **TOOLS on ubuntu**: `gdb 15.1` native (`/usr/bin/gdb`); `rr 5.9` via
  `nix-shell -p rr --run '…'`. lldb (in `nix develop`) has NO Zig type plugin —
  raw regs/mem only; prefer gdb.
- **dbg-gate caveat**: `dbg.on(ch)` is compiled OUT in ReleaseFast/Small AND the
  CLI never calls `dbg.initFromEnv` (only `cli/main.zig`/`wasm_engine_new` do, and
  the d489-repro exe path does) → `ZWASM_DEBUG=…` is a NO-OP in the `zwasm run`
  CLI. For CLI instrumentation use UNCONDITIONAL code, or instrument via the
  d489-repro exe (Debug) where the gate works (`fmtwatch` worked there).
- **random_get confounds mem.cksum**: tinygo seeds a map via random_get, so raw
  linear-memory fingerprints differ run-to-run regardless of the bug.
- **SSH quoting**: use the outer/inner script pattern (`cd $HOME/repo && exec nix
  develop --command bash /tmp/inner.sh`); `ssh host 'cd X && nix …'` re-parses the
  `&&` in the login shell → nix runs in the wrong dir. PIE → break by NAME not addr.
