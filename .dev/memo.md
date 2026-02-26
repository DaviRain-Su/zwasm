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
**Do NOT merge to main until P1+P2 complete** (nbody regression + rw_c_string hang).
Plan: `@./.dev/reliability-plan.md`. Progress: `@./.dev/reliability-handover.md`.

**Plan A: Incremental regression fix + feature implementation**
- [x] P1: rw_c_string hang fix — skip back-edge JIT for reentry guard (20.2ms)
- [x] P2: nbody FP cache fix — expand D-reg cache D2-D15, FP-aware MOV (23.1ms, was 43.8ms)
- P3: rw_c_math re-measure (Priority C)
- P4: GC JIT basic implementation (Priority B)
- P5: st_matrix accept as exception (Priority C)

**Active: P3 (rw_c_math re-measure)**
P1+P2 complete. Ready for merge gate check, then reliability-004 for P3-P5.

## Previous Task

P1: Fix rw_c_string hang — skip back-edge JIT for reentry guard functions.
Root cause: OSR (On-Stack Replacement) for C/C++ init-guard functions caused
infinite loop in JIT code. Fix: detect reentry guard pattern and fall back to
register IR interpreter (20.2ms, was timeout).

## Known Bugs

- c_hello_wasi: EXIT=71 on Ubuntu (WASI issue, not JIT — same with --profile)
- Go WASI: 3 Go programs produce no output (WASI compatibility, not JIT-related)

## References

- `@./.dev/roadmap.md`, `@./private/roadmap-production.md` (stages)
- `@./.dev/decisions.md`, `@./.dev/checklist.md`, `@./.dev/spec-support.md`
- `@./.dev/reliability-plan.md` (plan), `@./.dev/reliability-handover.md` (progress)
- `@./.dev/jit-debugging.md`, `@./.dev/ubuntu-x86_64.md` (gitignored)
- External: wasmtime (`~/Documents/OSS/wasmtime/`), zware (`~/Documents/OSS/zware/`)
