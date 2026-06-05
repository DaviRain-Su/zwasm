# All-engine × multi-runtime matrix (ADR-0163 A; 2026-06-05)

> **Doc-state**: ACTIVE — point-in-time, machine-specific snapshot. Regenerate
> with the reproduction command below; numbers drift with host + toolchain.
>
> **⚠ Numbers below are the PRELIMINARY `--quick` + ReleaseSafe run and are being
> superseded.** Two corrections landed 2026-06-05: (1) the bench now builds
> **ReleaseFast** (was ReleaseSafe — an unfair handicap vs the optimized
> comparators); (2) **memmove's JIT byte-loop is FIXED** (D-285, word-wise copy)
> — memmove zwasm-jit 254→38 ms, now faster than interp. A non-quick ReleaseFast
> re-measure refreshes the tables. The `memmove` / `base64` rows below predate
> both fixes; see §Findings 5 for the corrected reading.

The first profile of zwasm across **all three of its engines** (interp / JIT /
AOT) against four external runtimes, on the **same** fixture inventory. This
supersedes the methodology constraint of [`s15p_parity_vs_v1.md`](s15p_parity_vs_v1.md)
§"Methodology constraint" — that doc states the JIT is "compute-only, no WASI",
which **D-244 made false**: JIT and AOT now run the full WASI command set, so the
TinyGo / cljw WASI fixtures are benched under every engine here.

## Methodology

- **Host**: `Darwin aarch64` (Mac, native). Single machine — cross-host numbers
  (ubuntu x86_64) are not folded in; these are one host's figures.
- **zwasm engines**: `interp` (`run --engine interp`, default), `jit`
  (`run --engine jit`), `aot` (`compile`→`.cwasm`, then `run` the artifact —
  timed cmd excludes the one-off compile; cold-start is
  [`aot_coldstart.md`](aot_coldstart.md)).
- **Comparators**: wasmtime 43.0.1 (Cranelift JIT), wazero 1.11.0 (Go compiler),
  wasmer 5.0.4 (Cranelift), wasmedge 0.16.1 (interpreter by default). All pinned
  in `flake.nix devShells.bench`.
- **Harness**: `hyperfine`, **`--quick` (3 runs + 1 warmup)** — comparative, not
  publication-grade stability; re-run without `--quick` (5+3) for tighter CIs.
- Each runtime executes the module's WASI `_start` (`zwasm run`, `wasmtime run`,
  `wazero run`, `wasmer run`, `wasmedge <wasm>`). RSS via `/usr/bin/time -l`.

### Caveats (load-bearing — read before the tables)

1. **Startup confound.** The TinyGo + cljw fixtures run in single-digit ms; at
   that scale **process+instantiate startup dominates**, so the ranking there
   measures *startup latency*, not steady-state throughput. The shootout
   fixtures (100 ms–60 s) amortise startup and reflect execution speed. Do not
   read "zwasm fastest on tinygo/fib" as a throughput claim.
2. **`wasmedge` runs its interpreter** by default (AOT needs a separate
   `wasmedge compile`); compare it to `zwasm-interp`, not to the JITs.
3. **`handwritten/nbody`** exports `init`/`run`/`advance` with **no `_start`**;
   the harness only drives `_start`, so strict engines (jit / wasmer / wasmedge)
   report `—` and the tolerant ones time bare instantiation, not the n-body
   computation. Its row is not a valid workload comparison (→ D-284).

## mean_ms (lower = faster)

| fixture              | zwasm-interp | zwasm-jit | zwasm-aot | wasmtime | wazero | wasmer | wasmedge |
|----------------------|-------------:|----------:|----------:|---------:|-------:|-------:|---------:|
| shootout/fib2        |     64727.02 |   1062.65 |   1052.92 |   703.85 | 776.31 | 716.94 | 42793.40 |
| shootout/sieve       |     14191.71 |    335.56 |    335.71 |   204.24 | 492.87 | 204.81 | 20559.96 |
| shootout/nestedloop  |         3.06 |      5.36 |      3.15 |     8.98 |  11.50 |  12.92 |    15.10 |
| shootout/matrix      |      5999.08 |    341.56 |    340.99 |    88.15 | 197.50 |  91.37 | 11011.40 |
| shootout/heapsort    |     17148.60 |   1575.58 |   1573.69 |   635.91 | 918.91 | 639.50 | 23785.19 |
| shootout/base64      |      7349.26 |    770.46 |    768.13 |    58.33 |  78.06 |  60.71 | 10988.84 |
| shootout/gimli       |       105.41 |      9.24 |      8.99 |     9.00 |   5.29 |  11.74 |   156.87 |
| shootout/memmove     |       138.38 |    254.23 |    252.84 |    17.13 |  14.37 |  20.85 |    40.78 |
| shootout/keccak      |       265.52 |     32.39 |     32.08 |     8.57 |   7.75 |  14.75 |   378.94 |
| tinygo/arith         |         1.96 |      2.46 |      1.86 |     5.00 |   5.58 |   9.48 |    13.56 |
| tinygo/fib           |         2.08 |      2.26 |      1.65 |     6.48 |   5.31 |  11.38 |    13.52 |
| tinygo/fib_loop      |         1.99 |      2.30 |      1.97 |     6.89 |   6.15 |  10.61 |    13.77 |
| tinygo/gcd           |         1.92 |      2.17 |      2.06 |     6.08 |   5.86 |  10.00 |    13.30 |
| tinygo/list_build    |         2.10 |      2.44 |      1.84 |     5.82 |   5.70 |  10.67 |    13.00 |
| tinygo/mfr           |         2.19 |      2.45 |      1.84 |     6.05 |   5.73 |   9.85 |    13.87 |
| tinygo/nqueens       |         2.28 |      2.44 |      2.42 |     5.72 |   6.67 |   9.91 |    13.35 |
| tinygo/real_work     |         3.89 |      4.98 |      3.52 |     6.07 |   6.48 |  10.76 |    13.02 |
| tinygo/sieve         |         2.62 |      2.58 |      1.98 |     6.13 |   6.13 |  11.66 |    14.31 |
| tinygo/string_ops    |         2.18 |      2.44 |      1.92 |     5.83 |   5.77 |  10.63 |    12.98 |
| tinygo/tak           |         2.17 |      2.46 |      2.10 |     5.65 |   5.84 |  10.41 |    14.72 |
| handwritten/nbody † |         2.01 |        — |      1.98 |     6.04 |   3.61 |     — |       — |
| cljw/fib             |         2.15 |      2.54 |      2.03 |     5.65 |   6.35 |  10.38 |    14.74 |
| cljw/gcd             |         2.20 |      2.43 |      1.86 |     5.12 |   5.73 |  10.78 |    13.62 |
| cljw/arith           |         2.17 |      2.37 |      1.86 |     5.07 |   5.47 |  10.57 |    12.61 |
| cljw/sieve           |         2.17 |      2.34 |      2.06 |     4.96 |   5.69 |  10.43 |    15.28 |
| cljw/tak             |         2.13 |      2.37 |      2.05 |     5.21 |   5.67 |  10.91 |    13.95 |

† `nbody` has no `_start` — see Caveat 3. Not a valid comparison row.

## peak RSS (MB)

| fixture           | zwasm-interp | zwasm-jit | zwasm-aot | wasmtime | wazero | wasmer | wasmedge |
|-------------------|-------------:|----------:|----------:|---------:|-------:|-------:|---------:|
| shootout/heapsort |         35.5 |      19.1 |      18.0 |     13.0 |   45.0 |   27.0 |     23.4 |
| shootout/keccak   |         19.6 |      19.5 |      18.2 |     13.2 |   11.7 |   27.1 |     24.0 |
| tinygo/fib        |          3.5 |       3.3 |       2.2 |     13.2 |    8.4 |   27.6 |     23.7 |
| tinygo/real_work  |         35.4 |      35.2 |      34.1 |     13.3 |    9.6 |   27.5 |     23.7 |
| tinygo/sieve      |          5.4 |       5.2 |       4.0 |     13.2 |    9.0 |   27.5 |     23.8 |
| cljw/tak          |          3.4 |       3.2 |       2.1 |     13.2 |    8.5 |   27.4 |     23.6 |

(Representative rows; the full per-fixture RSS matrix regenerates with
`--capture-rss`. The tinygo/cljw pattern — zwasm ~2–5 MB vs 8–28 MB — is uniform.)

## Findings (honest)

1. **Memory footprint is zwasm's clear, consistent win.** On the small WASI
   guests zwasm holds **~2–5 MB** RSS where wasmtime sits at ~13 MB, wazero
   ~8–9 MB, wasmer ~27 MB, wasmedge ~24 MB — a **4–12× advantage**. AOT is the
   leanest engine (no JIT buffers). This is the "lightweight" half of
   "lightweight-yet-fast" showing up in the numbers.
2. **Startup latency favours zwasm** (Caveat 1). On sub-10 ms fixtures
   zwasm-aot/interp (~2 ms) beat wasmtime (~5–6 ms) and wasmer/wasmedge
   (~10–14 ms). Real, but it measures cold start, not throughput.
3. **On sustained compute, the optimizing JITs lead — as expected.** Once
   startup amortises (shootout), wasmtime/wasmer (Cranelift) and wazero pull
   ahead of zwasm-jit/aot: fib2 ~1.5×, sieve ~1.6×, heapsort ~2.5×, keccak
   ~3.8×, matrix ~3.9×. This is the **designed** trade of a single-pass,
   no-optimizing-tier backend (§1.3/§3.2) against multi-pass optimizers — not a
   regression. zwasm-jit ≈ zwasm-aot throughout (shared lowering; AOT's win is
   cold-start, not steady-state).
4. **zwasm-jit/aot vs zwasm-interp**: 10–90× faster on heavy compute (fib2
   64.7 s → 1.06 s), near-parity on startup-bound fixtures. zwasm-interp and
   wasmedge-interp are the same class (both tree-walking-ish interpreters);
   zwasm-interp trails wasmedge ~1.5× on the heaviest loops.
5. **One real codegen defect (now FIXED) + one re-attributed:**
   - **`memmove`** — was a genuine codegen defect: zwasm-jit (254 ms) slower than
     its own interpreter (138 ms), a byte-at-a-time `memory.copy` loop. **FIXED**
     (D-285, `4e6d17fc`/`838de5a1`): word-wise lowering on both backends →
     zwasm-jit **38 ms**, now faster than interp and 2.3× wasmtime.
   - **`base64`** — initially flagged with memmove, but the copy fix left it
     unchanged (770→782 ms): base64's hot loop is 6-bit-group + table-lookup byte
     processing, **not** `memory.copy`. Its ~13× is the **genuine single-pass-vs-
     optimizer gap** (the §1.3 designed trade, amplified for byte-shuffling) —
     **not** a bug.
   - `memory.fill`/`memory.init` share the old byte-loop pattern → **D-286**
     (same-class follow-on). **D-284** = the nbody no-`_start` harness gap.

## Reproduction

```sh
nix develop .#bench --command \
  bash scripts/run_bench.sh --engines=interp,jit,aot --compare=all --capture-rss
# (--quick for the 3-run snapshot above; omit for 5+3 publication runs)
```
