# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — §9.12-F D-090 closed (was stale-framed)

§9.12-F (debt active rows < 15) and §9.12-I (ADR canonical) open.

| Exit criterion                  | Latest fact                                                                |
|---------------------------------|----------------------------------------------------------------------------|
| §9.12-F: debt active rows < 15  | 21 (D-090 closed this commit; was 22)                                      |
| §9.12-I: ADR `Accepted` < 30    | strict 33 / loose 52 — blocked on Phase 9 close                            |

**This commit (D-090 close — stale framing)**:

D-090 was framed as "lower.zig needs a parallel type-stack
walker for untyped 0x1B select" but investigation showed the
trigger condition fired without notice. Three layers
already handle non-i32 untyped select correctly in production:

- `validator.zig::opSelect` (line 1221-1227): resolves the
  valtype byte and appends to `out_select_types`. Polymorphic
  `bot` case resolves to `0x7F` (i32) per spec §3.3.5.
- `lower.zig` line 257-262: reads `select_types[idx]` and
  threads via `ins.extra` to emit.
- `arm64/emit.zig:956-961` / x86_64 analog: dispatches
  `ins.extra` switch — 0x7E/0x70/0x6F → gpr64 CSEL Xd; 0x7D
  → fp32 FCSEL S; 0x7C → fp64 FCSEL D; default → gpr32.

The fixture trigger ("non-i32 select fixtures or realworld
coverage with 0x1B i64/f32/f64") already fired:
`test/edge_cases/p9/select_fp/select_f32_negzero.wat` +
`select_f64_negzero.wat` exercise untyped 0x1B on FP types
and pass (test-all green on Mac aarch64, ubuntunote x86_64).

Production path threads correctly via `compile.zig:822-860`
→ `shared/compile.zig:125`. The "future implementation" the
debt described is already done.

**Next pickup**: D-141 (file-size cap WARN proliferation; 18
files exceed 1000-LOC). Per ADR-0099 D2 conditions — most
catalog-shaped files don't qualify for split (P1-P4
conditions). Possible per-file ADR for one of the
codegen catalogs (e.g. `op_simd_int_arith.zig`, 1137 LOC)
OR amendment of file_size_check.sh to expand EXEMPT range
into [1000, 2000] for justified catalog files — requires
ADR-0099 amendment (load-bearing per §18).

## Recent context

- §9.12-G closed (`4bd62842`); §9.12-H closed (`600bd7cf`).
- §9.12-I batches 1+2.
- §9.12-F D-018 discharge / barrier sweep / D-055 close
  (`02397144` / `d68ad87c` / `871c78e1`).
- D-055 migration batches 1+2 + close (`84c83e11` /
  `b7d4f399` / `871c78e1`).
- D-090 close this commit (was stale-framed).

## Active `now` debts

- なし.

## Other queued work

1. **D-141 per-file file-size ADRs / file_size_check amendment**.
2. **§9.12-I revisit after Phase 9 close**.

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK.
- §9.12-F: 21 active rows; exit `< 15`.
- §9.12-G / §9.12-H / D-055 / D-090: closed.
- §9.12-I: 29 ADRs flipped; blocked on Phase 9 close.

## Open questions / blockers

- なし for D-141 next.

## See

- [ROADMAP](./ROADMAP.md) §9.12-F + §9.12-I scope + exit
- [`debt.md`](./debt.md), [`lessons/INDEX.md`](./lessons/INDEX.md)
- ADR-0099 (file_size_smell), ADR-0063 (EXEMPT marker)
