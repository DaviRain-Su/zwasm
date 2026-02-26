# zwasm Development Memo

Session handover document. Read at session start.

## Current State

- Stages 0-46 complete. v1.1.0 released. ~38K LOC, 510 unit tests.
- Spec: 62,158/62,158 Mac + Ubuntu (100.0%). E2E: 792/792 (100.0%).
- Wasm 3.0: all 9 proposals. WASI: 46/46 (100%). WAT parser complete.
- JIT: Register IR + ARM64/x86_64. Size: 1.31MB / 3.44MB RSS.
- **main = stable**: ClojureWasm depends on main (v1.1.0 tag).

## Current Task

Reliability improvement (branch: `strictly-check/reliability-003`).
Plan: `@./.dev/reliability-plan.md`. Progress: `@./.dev/reliability-handover.md`.

Phases A-J complete. E2E 792/792 (100%), x86_64 JIT bugs fixed.
**Phase K** (perf): div-by-constant (UMULL+LSR), FP-direct load/store, const-folded ADD/SUB,
self-call setup optimization (bypass shared prologue). fib 61→49ms (-20%), st_fib2 1.06→0.99s (-6%).
Next: K.5 benchmark re-recording on both platforms, then Phase H (documentation).

## Previous Task

J.1-J.3: Phase J complete. x86_64 JIT bug fixes:
- Division safety (SIGFPE): zero check, overflow, signed rem fixup
- ABI register clobbering: global.set, mem ops read vregs before clobbering RDI
- SCRATCH2/vreg10 alias: R11 reserved exclusively for SCRATCH2 (10→9 phys regs)
- Call liveness: rd treated as USE for return/store/branch in computeCallLiveSet

## Known Bugs

- c_hello_wasi: EXIT=71 on Ubuntu (WASI issue, not JIT — same with --profile)
- Go WASI: 3 Go programs produce no output (WASI compatibility, not JIT-related)

## References

- `@./.dev/roadmap.md`, `@./private/roadmap-production.md` (stages)
- `@./.dev/decisions.md`, `@./.dev/checklist.md`, `@./.dev/spec-support.md`
- `@./.dev/reliability-plan.md` (plan), `@./.dev/reliability-handover.md` (progress)
- `@./.dev/jit-debugging.md`, `@./.dev/ubuntu-x86_64.md` (gitignored)
- External: wasmtime (`~/Documents/OSS/wasmtime/`), zware (`~/Documents/OSS/zware/`)
