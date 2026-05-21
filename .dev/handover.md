# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — §9.12-G in progress

ROADMAP §9.12-G is **Phase 10 prep substrate**, 7 deliverables.
Track inline here; commit per-sub-chunk per ROADMAP §18.3.

| # | Deliverable | Status |
|---|---|---|
| (a) | `.dev/wasm_3_0_zirop_mapping.md` machine-generated from collector | exists (184 LOC); verify currency |
| (b) | Extend `src/instruction/wasm_3_0/` placeholders for all Phase 10 features (GC / EH / tail-call / memory64 / multi-memory / typed funcrefs); each must reject with `Error.UnsupportedOpForBuildLevel` at comptime | partial (44 files in GC/EH/tail-call; memory64 / multi-memory / typed-funcref coverage unverified) |
| (c) | `src/api/instance.zig` (1431 LOC) health + helper extraction + minimal c_api Instance-path test coverage (D-139 pulled forward); P3 evaluation per ADR-0099 §D2 first | open |
| (d) | CLI `--invoke` mode (prerequisite for Phase 11 bench) | open |
| (e) | `include/wasm.h` upstream diff check vs WebAssembly/wasm-c-api | open |
| (f) | `scripts/zone_check.sh` migration info → `--gate` enforcement in `gate_commit.sh` | open (BASELINE=0, 0 current violations — mechanical edit) |
| (g) | `.dev/architecture/zone_layout.md` reference document | ✅ this commit |

**Next pickup**: (f) — `zone_check.sh --gate` migration. Smallest
isolated edit (gate_commit.sh insert) + verify pre-commit gate
stays green on docs-only and src diffs.

## Recent reform context (file-size discipline)

Cycles C1..C6 (2026-05-21) landed ADR-0099 + 0100 + 0101 +
rule + script + lesson + init_expr.zig redesign. Reform complete;
planning artefacts archived at `private/archive/2026-05-21-file-size-reform/`.

## Active `now` debts

- **D-055** (mechanical, multi-cycle): emit_test_int has 27 sites
  pending. Discharge now unblocked.

## Other queued work (post-§9.12-G)

1. **§9.12-H** — bench baseline (Mac Wasm 2.0 + wasmtime).
2. **§9.12-I** — ADR/lesson curation closure (Phase 9 close).
3. **D-055 continuation**.
4. **Remaining D-141 WARN files** — per ADR-0099 §D2 mostly
   resolve to FILE-SIZE-EXEMPT markers.

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK (check_split_smell wired).
- §9.12-F (D-141 + reform): closed.
- §9.12-G: in progress (g done; a/b verify pending; c-f open).
- §9.12-H / §9.12-I: open.

## Open questions / blockers

- なし。Next sub-chunk (f) is mechanical.

## See

- [ROADMAP](./ROADMAP.md) §9.12-G (full deliverable list); §4.1 zones
- [`.dev/architecture/zone_layout.md`](./architecture/zone_layout.md) — landed this commit
- [`.dev/wasm_3_0_zirop_mapping.md`](./wasm_3_0_zirop_mapping.md) — needs currency verification
- [`.dev/phase10_prep.md`](./phase10_prep.md) — pre-existing Phase 10 scoping
- [`.dev/decisions/0099_file_size_discipline_reframe.md`](./decisions/0099_file_size_discipline_reframe.md)
- [`.claude/rules/zone_deps.md`](../.claude/rules/zone_deps.md)
- [`scripts/zone_check.sh`](../scripts/zone_check.sh)
- [`debt.md`](./debt.md) — D-055 only `now`
- [`lessons/INDEX.md`](./lessons/INDEX.md)
