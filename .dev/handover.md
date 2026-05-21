# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — §9.12-G in progress

ROADMAP §9.12-G is Phase 10 prep substrate, 7 deliverables.
Track inline; commit per-sub-chunk per ROADMAP §18.3.

| # | Deliverable | Status |
|---|---|---|
| (a) | `.dev/wasm_3_0_zirop_mapping.md` Status currency | ✅ `c305deb1` |
| (b) | Extend `src/instruction/wasm_3_0/` for memory64 / relaxed-simd / multi-memory | **blocked-by ADR**: ZirOp slot policy (no slots exist yet; §4 deviation requires ADR). Defer |
| (c) | `src/api/instance.zig` (1431 LOC) health + ADR-0099 §D2 P3 evaluation; D-139 c_api Instance-path test coverage | ✅ this commit — audit verdict FILE-SIZE-EXEMPT (0 P-conditions fire, 4 N-conditions on any proposed extraction); marker added; audit saved at `.dev/architecture/api_instance_audit.md`. D-139 v0.1.0 RC discharge unchanged (19 inline tests sufficient for §9.12-G entry) |
| (d) | CLI `--invoke` mode (Phase 11 bench prerequisite) | open |
| (e) | `include/wasm.h` upstream diff check | ✅ `038d861f` |
| (f) | `zone_check.sh --gate` enforcement | ✅ verified `6d5e7551` |
| (g) | `.dev/architecture/zone_layout.md` reference | ✅ `568bb888` |

**Next pickup**: (d) — CLI `--invoke` mode. Need to survey
existing `src/cli/` shape + decide invocation surface (positional
vs flag-based) before any code. May warrant a small ADR if it
introduces a new CLI subcommand axis.

After (d), remaining §9.12-G items are (b) only — which is ADR-gated.
At that point §9.12-G effectively closes for this Phase 9 cycle,
with (b) tracked as a Phase 10-open dependency.

## Recent reform context (file-size discipline)

Cycles C1..C6 (2026-05-21) landed ADR-0099 + 0100 + 0101 + rule +
script + lesson + init_expr.zig redesign. Reform complete;
planning artefacts archived at
`private/archive/2026-05-21-file-size-reform/`.

## Active `now` debts

- **D-055** (mechanical, multi-cycle): emit_test_int has 27 sites
  pending. Discharge unblocked.

## Other queued work (post-§9.12-G)

1. **§9.12-H** — bench baseline (Mac Wasm 2.0 + wasmtime).
2. **§9.12-I** — ADR/lesson curation closure (Phase 9 close).
3. **D-055 continuation**.
4. **§9.12-G (b)** unblocking once ZirOp slot policy ADR lands.

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK + `check_wasm_h_upstream.sh`.
- §9.12-F (D-141 + reform): closed.
- §9.12-G: a/c/e/f/g done; (b) blocked-by ADR; (d) open.
- §9.12-H / §9.12-I: open.

## Open questions / blockers

- (b) ZirOp slot policy ADR (memory64 / relaxed-simd / multi-memory
  dispatch shape: per-op slots vs index-type-dispatched shared
  slots). Defer to Phase 10 entry.

## See

- [ROADMAP](./ROADMAP.md) §9.12-G; §4.1 zones
- [`.dev/architecture/api_instance_audit.md`](./architecture/api_instance_audit.md) — this commit
- [`.dev/architecture/zone_layout.md`](./architecture/zone_layout.md)
- [`.dev/wasm_3_0_zirop_mapping.md`](./wasm_3_0_zirop_mapping.md)
- [`.dev/phase10_prep.md`](./phase10_prep.md)
- [`scripts/check_wasm_h_upstream.sh`](../scripts/check_wasm_h_upstream.sh)
- [`scripts/zone_check.sh`](../scripts/zone_check.sh)
- [`debt.md`](./debt.md) — D-055 only `now`; D-079 / D-139 noted
- [`lessons/INDEX.md`](./lessons/INDEX.md)
