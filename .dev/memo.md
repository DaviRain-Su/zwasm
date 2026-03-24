# zwasm Development Memo

Session handover document. Read at session start.

## Current State

- Stages 0-46 + Phase 1, 3, 5, 8, 10, 11, 13, 15, 19 all complete.
- Spec: 62,263/62,263 Mac+Ubuntu (100.0%, 0 skip).
- E2E: 792/792 (Mac+Ubuntu).
- Real-world: Mac 41/50, Ubuntu 48/50 (JIT bugs W41 + wasmtime diffs W42).
- JIT: Register IR + ARM64/x86_64 + SIMD (NEON 253/256, SSE 244/256).
- HOT_THRESHOLD=3 (lowered from 10 in W38).
- Binary: 1.29MB stripped. Memory: ~3.5MB RSS.
- Platforms: macOS ARM64, Linux x86_64/ARM64, Windows x86_64.
- **main = stable**. ClojureWasm updated to v1.5.0.

## Current Task

**Phase 20: JIT Correctness Sweep** — in progress.

W38 (Lazy AOT) で HOT_THRESHOLD を 10→3 に下げた結果、以前は JIT されなかった
関数がコンパイルされるようになり、潜在 JIT バグが露出した。
Spec は 100% だが、real-world プログラムに影響がある。これらを修正するフェーズ。

### Real-world JIT failures (W41)

| Program          | Mac   | Ubuntu | 原因                                     |
|------------------|-------|--------|------------------------------------------|
| rust_compression | DIFF  | PASS   | ARM64 back-edge JIT OOB (T=10でも再現)   |
| rust_enum_match  | DIFF  | PASS   | ARM64 JIT float 化け                     |
| rust_serde_json  | DIFF  | PASS   | ARM64 JIT OOB                            |
| tinygo_hello     | DIFF  | DIFF   | ARM64+x86 共通 JIT OOB                   |
| tinygo_json      | DIFF  | DIFF   | ARM64+x86 共通 JIT OOB                   |
| tinygo_sort      | DIFF  | PASS   | ARM64 JIT 出力差異                        |

全て `--interp` で正常動作。JIT コードの correctness 問題。

### wasmtime 互換性差異 (W42, Mac のみ)

go_crypto_sha256, go_math_big, go_regex — JIT 無関係、interp でも差異。
Go runtime の env/args 処理や WASI 差異の可能性。

### Progress

**Fixed: ARM64 emitMemFill/emitMemCopy/emitMemGrow ABI register clobbering**
- `getOrLoad` returns physical registers that alias ABI arg registers (x0-x3)
- Sequential ABI arg setup clobbers vreg values before they're read
- Fix: spill all arg vregs to memory, load from regs[] into ABI regs
- x86 backend already had this fix; ARM64 did not

**Remaining: tinygo_hello OOB (both platforms)**
- The OOB originates in func#200 (`fmtInteger`) called from func#193 (`printArg`)
- func#193 JIT passes correct-looking args to func#200 via trampoline
- func#200 runs via interpreter (401 instrs) but crashes with OOB
- Bug only manifests with reg_count ≥ 12 functions being JIT'd
- Likely cause: corrupted wasm memory state from an earlier JIT-compiled function
- NOT ABI clobbering (all BLR callsites verified)
- Need: differential execution tracing (compare memory state JIT vs interpreter)

### Approach

1. Build differential execution trace comparing memory writes JIT vs interpreter
2. Find first divergence in memory state
3. Trace back to the JIT instruction that wrote the wrong value
4. Fix root cause, run merge gate

### Open Work Items

| Item     | Description                                       | Status         |
|----------|---------------------------------------------------|----------------|
| W41      | JIT real-world correctness (6 programs)           | Next session   |
| W42      | wasmtime 互換性差異 (3 Go programs, Mac)           | Low priority   |
| Phase 18 | Lazy Compilation + CLI Extensions                 | Future         |

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
- `@./.dev/checklist.md` — W38/W41/W42 details
- `@./.dev/references/w38-osr-research.md` — OSR research (4 approaches)
- `@./.dev/decisions.md` — architectural decisions (D131: epoch JIT timeout)
- `@./.dev/jit-debugging.md` — JIT debug techniques
- `bench/simd_comparison.yaml` — SIMD performance data
- External: wasmtime (`~/Documents/OSS/wasmtime/`), zware (`~/Documents/OSS/zware/`)
