# §15.P — v2-vs-v1 JIT parity measurement (2026-06-04)

> **Doc-state**: RESOLVED — the loop-carried-local regression (§Findings 2) was
> root-caused (D-265) and closed by the register-homing rework campaign (ADR-0153
> phases I–V). Post-rework verification below (§D-265 post-rework).

Phase 15 close gate (D-263): measure v2-jit vs v1-jit, no unexplained regression,
+ the ADR-0151 W45 loop-isolated measurement. Both binaries built **ReleaseFast**;
v1 from `~/Documents/MyProducts/zwasm` (`zig build -Doptimize=ReleaseFast`).
Comparison: v1 `zwasm run <wasm>` (default JIT) vs v2 `zwasm run --engine=jit <wasm>`.
hyperfine, Mac aarch64, 7–10 runs + warmup.

## Methodology constraint (load-bearing) — SUPERSEDED 2026-06-05

> **Update (ADR-0163 A, D-244):** the constraint below was true *at §15.P time*
> (2026-06-04) but is **no longer**. D-244 gave the JIT (and AOT) the full WASI
> command set, so WASI-printing fixtures **no longer trap** under `--engine=jit`
> — all TinyGo / cljw / shootout fixtures are now JIT/AOT-benchable. The current
> all-engine WASI re-profile lives in
> [`all_engine_matrix.md`](all_engine_matrix.md). The paragraph below is retained
> as the historical record of why this §15.P comparison was JIT-compute-only.

**[Historical, pre-D-244] v2 `--engine=jit` was compute-only (ADR-0136): no WASI
I/O under the JIT yet.** So WASI-printing fixtures (all TinyGo, + shootout that
`fd_write` their result) **trapped** under v2-jit and could not be JIT-benched. Of
the realworld corpus, only 4 were compute-only (import `proc_exit` only, never
call it for output): gimli, heapsort, keccak, memmove. v2's **default engine is
interp** (full WASI), so end-users running WASI programs got interp — this JIT
comparison covered the compute/embedding path (where the §15.2/15.3/15.4 perf
folds applied).

## Results — v2-jit / v1-jit (lower = v2 faster)

| Workload | class | v1 ms | v2 ms | v2/v1 |
|---|---|--:|--:|--:|
| simd/* (all 12 ops) | SIMD compute | 8–14 | 4–12 | **0.52–0.96× (v2 faster on ALL 12)** |
| shootout/keccak | bitwise/permute | 148.6 | 7.1 | **0.05× (v2 20× faster)** |
| shootout/gimli | bitwise/permute | 6.3 | 5.4 | 0.87× (v2 faster) |
| w45_scalar_loop (a=a+CONST) | body does NOT read i | 27.7 | 27.4 | 0.99× (parity) |
| **w45_addc (a=a+CONST, 20M)** | **A/B control: no i read** | 12.7 | 12.3 | **0.96× (parity)** |
| **w45_addi (a=a+i, 20M)** | **A/B: body READS i** | 12.4 | 28.4 | **2.30× (SLOWER)** |
| w45_mul / and / shl / or | body reads i (via op) | 12.1–12.5 | 26–37 | 2.1–2.9× (SLOWER) |
| w45_simd_loop (50M f32x4.add) | v128 accumulator (no i read) | 67.1 | 33.1 | **0.49× (v2 2× faster)** |
| shootout/heapsort | sort (indexes via i) | 727 | 1735 | 2.38× (SLOWER) |
| shootout/memmove | copy (indexes via i) | 130 | 258 | 1.98× (SLOWER) |
| w45_mem_loop (20M load+store) | indexes via i | 17.7 | 39.1 | 2.21× (SLOWER) |

## Findings

1. **v2-jit is at-parity-or-FASTER on compute** — SIMD (all 12 ops faster),
   bitwise/permute (keccak 20×, gimli), scalar register loops (parity). The
   §15.2/15.3/15.4 fold conclusion ("v2 emit already efficient") **holds for the
   compute/register axis**.
2. **v2-jit is ~2.3× SLOWER for loops whose body READS a loop-carried local**
   — NOT memory-access (the initial framing was confounded). **A/B bisected**
   (identical loop, only body differs): `a=a+CONST` (body doesn't read i) →
   **0.96× parity**; `a=a+i` (body reads i) → **2.30×**. Same `i32.add` both.
   Holds across mul/and/shl/or (2.1–2.9×) and load/store (2.2–2.4×) — all share
   "body re-reads the mutated loop counter". heapsort/memmove/mem_loop showed it
   only because array indexing reads `i`. **→ D-265.** Mechanism (strong
   inference): v2's single-pass spill-everything slot allocator reloads the loop
   local each body use; v1 keeps it register-pinned. **This contradicts the
   §15.2/15.3 "~0 regalloc headroom" folds** (ADR-0149/0150) — they measured spill
   traffic as % of *total* instructions, the wrong proxy (one reload in a 3-instr
   hot loop ≈ 0% of the program but ≈2× of that loop's wall-clock).
   Bisection fixtures: `private/spikes/s15p-parity/w45_{addi,addc,mul,and,shl,or}.wat`.
3. **W45 verdict (ADR-0151 gate): folded, data-backed.** The 50M-iter v128-local
   loop runs **2× FASTER on v2** than v1 (0.49×) → v2's per-iteration v128-reload
   does NOT dominate → ADR-0151's "re-open W45 if v2 lags" trigger is NOT met →
   **W45 loop-persistence stays folded.**
4. **w45_baseline edge**: a near-empty (counter-only) loop is 2.3× slower on v2 —
   slower than the *more*-work scalar_loop. A narrow v2-jit codegen quirk for
   minimal loop bodies; low real-workload impact (real loops have bodies). Noted,
   not chased.

## D-265 post-rework verification (2026-06-04, campaign close)

Register-homing landed on BOTH backends (arm64 stages 1+2 `a64c72a1`/`5d1dd221`;
x86_64 stage-4-redo `e8b7ad10`). Re-measured the decisive A/B (`a=a+i` reads the
loop local vs `a=a+CONST` does not):

| target | fixture | metric | pre-rework | post-rework |
|---|---|---|--:|--:|
| arm64 (Mac, native) | w45_addi (reads `i`) | v2/v1 | **2.30×** | **0.97×** (parity/faster) |
| x86_64 (Rosetta) | w45_addi (reads `i`) | v2/v1 | (NotImpl pre-stage-4) | **1.17×** |
| x86_64 (Rosetta) | w45_addc (control, no `i`) | v2/v1 | — | **1.19×** |

**Verdict: the loop-carried-local reload penalty is ELIMINATED on both backends.**
The D-265 signature was a ~2.4× *differential* between reads-`i` (2.30×) and the
no-`i` control (0.96×). Post-rework that differential is **gone**: arm64 hits
0.97× (≤1.1× ROI target met); on x86_64-Rosetta `addi` (1.17×) and `addc` (1.19×)
are statistically equal — reading the loop local now costs nothing extra. The
residual flat ~1.18× on Rosetta appears in the control too, so it is uniform
binary-translation / baseline-codegen overhead, **not** the D-265 mechanism
(native arm64 confirms: 0.97×). Native-x86_64 *absolute* ROI vs v1 is unmeasured
(needs v1 built on ubuntu) → D-266 note; the differential evidence is conclusive
that the mechanism is fixed, and ubuntu `test-all` is green (correctness).

## Reproduction

Scratch (gitignored): `private/spikes/s15p-parity/` — `run_parity.sh` +
`w45_*.wat/.wasm` (scalar / simd / mem / baseline loops, 50M/20M iters). Rebuild
v1: `cd ~/Documents/MyProducts/zwasm && zig build -Doptimize=ReleaseFast`.
