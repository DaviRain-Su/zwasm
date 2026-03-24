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

**W38 Lazy AOT — in progress** on branch `perf/w38-lazy-aot`.

### Done

- HOT_THRESHOLD 10 → 3: earlier JIT compilation
- Back-edge `jit_failed` poisoning fix: `back_edge_bailed` separate flag
  so reentry guard/br_table bail doesn't block call-path JIT
- ARM64 extract_lane encoding fix: imm5 shift + upper-half memory load
- Added ldr32/ldrb/ldrsb32/ldrh/ldrsh32 ARM64 helpers
- Tests: force_interpreter for fuel/deadline/memory resource tests

### Status

- `zig build test`: all pass
- Spec: 62,258/62,263 (5 pre-existing JIT bugs in linking/memory_grow64)
- E2E: 792/792. Real-world: 49/50 (rust_compression pre-existing)
- Benchmarks: no regression

### Next Steps

1. Run SIMD benchmarks to measure W38 perf improvement
2. Investigate 5 spec failures (linking: 3, memory_grow64: 2)
3. Run Merge Gate (Ubuntu) if merging

### Open Work Items

| Item     | Description                                      | Status           |
|----------|--------------------------------------------------|------------------|
| W38      | C-compiled SIMD perf (threshold + back-edge fix) | Implementation   |
| W39      | JIT bugs: linking(3), memory_grow64(2) at T=3    | New              |
| W40      | JIT SIMD: stack-allocated Vm simd_v128 access     | New              |
| Phase 18 | Lazy Compilation + CLI Extensions                | Aligns with W38  |

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
