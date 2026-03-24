# zwasm Development Memo

Session handover document. Read at session start.

## Current State

- Stages 0-46 + Phase 1, 3, 5, 8, 10, 11, 13, 15, 19 all complete.
- Spec: 62,263/62,263 Mac+Ubuntu+Windows (100.0%, 0 skip).
- E2E: 792/792 (Mac+Ubuntu). Real-world: 50/50.
- JIT: Register IR + ARM64/x86_64 + SIMD (NEON 253/256, SSE 244/256).
- Binary: 1.29MB stripped. Memory: ~3.5MB RSS.
- Platforms: macOS ARM64, Linux x86_64/ARM64, Windows x86_64.
- **main = stable**. ClojureWasm updated to v1.5.0.

## Current Task

**W38 merged to main** — v128 sync fix + investigation.

- ARM64 JIT v128 sync: MOV copies simd_v128, CONST clears it (correctness bug fix)
- OSR prologue: x20/x21 caching before emitLoadMemCache
- Root cause: C-compiled functions have reentry guards preventing JIT (13-131x gap)
- OSR attempted but blocked by v128 state transfer for complex functions

### Next: Lazy AOT (Recommended approach for W38)

Compile all functions to JIT at module load / first call, bypassing interpreter.
Eliminates tier-up state transfer problem entirely (matches wasmtime architecture).
Detailed research and 4 candidate approaches documented in:
**`@./.dev/references/w38-osr-research.md`** — read this before starting.

### Open Work Items

| Item     | Description                            | Status             |
|----------|----------------------------------------|--------------------|
| W38      | C-compiled SIMD perf (Lazy AOT path)   | Research complete   |
| Phase 18 | Lazy Compilation + CLI Extensions      | Aligns with W38    |

## Completed Phases (summary)

| Phase | Name                                  | Date       |
|-------|---------------------------------------|------------|
| 1     | Guard Pages + Module Cache            | 2026-03    |
| 3     | CI Automation + Documentation         | 2026-03    |
| 5     | C API + Conditional Compilation       | 2026-03    |
| 8     | Real-World Coverage + WAT Parity      | 2026-03    |
| 10    | Quality / Stabilization               | 2026-03    |
| 11    | Allocator Injection + Embedding       | 2026-03    |
| 13    | SIMD JIT (NEON + SSE)                 | 2026-03-23 |
| 15    | Windows Port                          | 2026-03    |
| 19    | JIT Reliability                       | 2026-03    |

## References

- `@./.dev/roadmap.md` — Phase roadmap
- `@./.dev/checklist.md` — W38 details (investigation steps, benchmarks, sources)
- `@./.dev/references/w38-osr-research.md` — **W38 next steps: 4 approaches compared**
- `@./.dev/decisions.md` — architectural decisions (D131: epoch JIT timeout)
- `@./.dev/jit-debugging.md` — JIT debug techniques
- `bench/simd_comparison.yaml` — SIMD performance data (3 layers: baseline → post-opt → JIT)
- `bench/simd/src/` — C source for compiler-generated SIMD benchmarks
- `bench/run_simd_bench.sh` — SIMD microbenchmark runner
- External: wasmtime (`~/Documents/OSS/wasmtime/`), zware (`~/Documents/OSS/zware/`)
