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
- P1: rw_c_string hang fix (Priority A — correctness)
- P2: nbody FP cache fix (Priority C — regression)
- P3: rw_c_math re-measure (Priority C)
- P4: GC JIT basic implementation (Priority B)
- P5: st_matrix accept as exception (Priority C)

**Active: P1 (rw_c_string hang)**
Introduced at ee5f585 (OSR). Worked at 22859e2 (21ms).
Investigate OSR back-edge detection or guard function misjudgment.

## Previous Task

reliability-003 Phases A-K + OSR + bench infra upgrade:
- E2E 792/792, spec 62,158, x86 JIT fixes, self-call/div-const opt
- Bench recording upgraded: 29 benchmarks, runs=5/warmup=3, timeout
- history.yaml: per-commit rerun (28 commits)
- **Discovery**: be466a0 caused nbody 4x regression (FP cache precision fix)

## Known Bugs

- c_hello_wasi: EXIT=71 on Ubuntu (WASI issue, not JIT — same with --profile)
- Go WASI: 3 Go programs produce no output (WASI compatibility, not JIT-related)

## References

- `@./.dev/roadmap.md`, `@./private/roadmap-production.md` (stages)
- `@./.dev/decisions.md`, `@./.dev/checklist.md`, `@./.dev/spec-support.md`
- `@./.dev/reliability-plan.md` (plan), `@./.dev/reliability-handover.md` (progress)
- `@./.dev/jit-debugging.md`, `@./.dev/ubuntu-x86_64.md` (gitignored)
- External: wasmtime (`~/Documents/OSS/wasmtime/`), zware (`~/Documents/OSS/zware/`)
