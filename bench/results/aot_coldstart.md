# AOT cold-start bench-delta (§12.4 / ADR-0040)

Host: `Darwin arm64` (bench 2-host Mac+Linux per ADR-0137; numbers are point-in-time, machine-specific).

AOT `zwasm run *.cwasm` (load+reloc+first-call) vs JIT `zwasm run --engine=jit *.wasm`
(parse+lower+regalloc+emit+first-call), compute (zero-import) SIMD fixtures.
Threshold: AOT ≥30% faster on ≥3 fixtures (warmup 5, runs 30).

| fixture | AOT ms | JIT ms | delta | |
|---|--:|--:|--:|:-:|
| `i32x4_add` | 13.10 | 19.96 | 34.4% | ok |
| `f32x4_add` | 13.23 | 20.32 | 34.9% | ok |
| `i32x4_mul` | 14.27 | 21.25 | 32.8% | ok |
| `i16x8_mul` | 13.94 | 21.21 | 34.3% | ok |
| `i8x16_swizzle` | 12.70 | 19.93 | 36.3% | ok |
| `v128_and` | 12.75 | 20.23 | 36.9% | ok |

Result: 6/6 fixtures cleared ≥30%.
