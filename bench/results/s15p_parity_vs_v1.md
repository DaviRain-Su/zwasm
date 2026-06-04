# §15.P — v2-vs-v1 JIT parity measurement (2026-06-04)

> **Doc-state**: ACTIVE

Phase 15 close gate (D-263): measure v2-jit vs v1-jit, no unexplained regression,
+ the ADR-0151 W45 loop-isolated measurement. Both binaries built **ReleaseFast**;
v1 from `~/Documents/MyProducts/zwasm` (`zig build -Doptimize=ReleaseFast`).
Comparison: v1 `zwasm run <wasm>` (default JIT) vs v2 `zwasm run --engine=jit <wasm>`.
hyperfine, Mac aarch64, 7–10 runs + warmup.

## Methodology constraint (load-bearing)

**v2 `--engine=jit` is compute-only (ADR-0136): no WASI I/O under the JIT yet.**
So WASI-printing fixtures (all TinyGo, + shootout that `fd_write` their result)
**trap** under v2-jit and cannot be JIT-benched. Of the realworld corpus, only 4
are compute-only (import `proc_exit` only, never call it for output): gimli,
heapsort, keccak, memmove. v2's **default engine is interp** (full WASI), so
end-users running WASI programs get interp — this JIT comparison covers the
compute/embedding path (where the §15.2/15.3/15.4 perf folds applied).

## Results — v2-jit / v1-jit (lower = v2 faster)

| Workload | class | v1 ms | v2 ms | v2/v1 |
|---|---|--:|--:|--:|
| simd/* (all 12 ops) | SIMD compute | 8–14 | 4–12 | **0.52–0.96× (v2 faster on ALL 12)** |
| shootout/keccak | bitwise/permute | 148.6 | 7.1 | **0.05× (v2 20× faster)** |
| shootout/gimli | bitwise/permute | 6.3 | 5.4 | 0.87× (v2 faster) |
| w45_scalar_loop (50M i32.add) | scalar reg loop | 27.7 | 27.4 | 0.99× (parity) |
| w45_simd_loop (50M f32x4.add) | v128 reg loop | 67.1 | 33.1 | **0.49× (v2 2× faster)** |
| **shootout/heapsort** | sort (load/store-heavy) | 727 | 1735 | **2.38× (v2 SLOWER)** |
| **shootout/memmove** | memory copy | 130 | 258 | **1.98× (v2 SLOWER)** |
| **w45_mem_loop (20M load+store)** | pure load/store | 17.7 | 39.1 | **2.21× (v2 SLOWER)** |
| w45_baseline (50M counter-only) | near-empty loop | 27.2 | 62.7 | 2.31× (v2 slower, edge) |

## Findings

1. **v2-jit is at-parity-or-FASTER on compute** — SIMD (all 12 ops faster),
   bitwise/permute (keccak 20×, gimli), scalar register loops (parity). The
   §15.2/15.3/15.4 fold conclusion ("v2 emit already efficient") **holds for the
   compute/register axis**.
2. **v2-jit is ~2.2× SLOWER on memory-access-heavy workloads** — confirmed by a
   pure 20M load+store control (2.21×), and reproduced on heapsort (2.38×) +
   memmove (1.98×). The load/store emit path is the v2-jit gap vs v1. **→ D-265.**
   Leading hypothesis: v2 emits per-access bounds checks / recomputed effective
   addresses that v1 elides or hoists (cf. the empty `simd_base_special` /
   address-cache scaffolding noted in ADR-0151). Whether v1 is *safe* there
   (does it bounds-check?) is the first root-cause question — the gap may be a
   safety/perf tradeoff, not pure codegen loss.
3. **W45 verdict (ADR-0151 gate): folded, data-backed.** The 50M-iter v128-local
   loop runs **2× FASTER on v2** than v1 (0.49×) → v2's per-iteration v128-reload
   does NOT dominate → ADR-0151's "re-open W45 if v2 lags" trigger is NOT met →
   **W45 loop-persistence stays folded.**
4. **w45_baseline edge**: a near-empty (counter-only) loop is 2.3× slower on v2 —
   slower than the *more*-work scalar_loop. A narrow v2-jit codegen quirk for
   minimal loop bodies; low real-workload impact (real loops have bodies). Noted,
   not chased.

## Reproduction

Scratch (gitignored): `private/spikes/s15p-parity/` — `run_parity.sh` +
`w45_*.wat/.wasm` (scalar / simd / mem / baseline loops, 50M/20M iters). Rebuild
v1: `cd ~/Documents/MyProducts/zwasm && zig build -Doptimize=ReleaseFast`.
