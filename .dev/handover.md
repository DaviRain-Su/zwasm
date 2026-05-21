# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — §9.12-G in progress

ROADMAP §9.12-G is Phase 10 prep substrate, 7 deliverables.
Track inline; commit per-sub-chunk per ROADMAP §18.3.

| # | Deliverable | Status |
|---|---|---|
| (a) | `.dev/wasm_3_0_zirop_mapping.md` Status section currency | ✅ `c305deb1` |
| (b) | Extend `src/instruction/wasm_3_0/` for memory64 / relaxed-simd / multi-memory; comptime `Error.UnsupportedOpForBuildLevel` | **blocked-by ADR**: no relaxed-simd / memory64_64 ZirOps exist in `src/ir/zir.zig` yet; adding them is §4-territory (deviation watch), requires ADR. Defer until (c)/(d) inform the ZirOp slot policy |
| (c) | `src/api/instance.zig` (1431 LOC) health + helper extraction + minimal c_api Instance-path test coverage (D-139); P3 evaluation per ADR-0099 §D2 first | open |
| (d) | CLI `--invoke` mode (prerequisite for Phase 11 bench) | open |
| (e) | `include/wasm.h` upstream diff check vs WebAssembly/wasm-c-api | ✅ this commit — `scripts/check_wasm_h_upstream.sh` lands; local is byte-identical to upstream |
| (f) | `scripts/zone_check.sh --gate` enforcement | ✅ already landed; verified `6d5e7551` |
| (g) | `.dev/architecture/zone_layout.md` reference | ✅ `568bb888` |

**Next pickup**: (c) — `api/instance.zig` health + P3 evaluation.
This is a substrate audit + restructure (~1431 LOC file); start
with the §D2 P3 conditions check before any code change. May
require an ADR if extraction is justified.

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
4. **§9.12-G (b)** unblocking once ZirOp slot policy for memory64
   / relaxed-simd is decided (likely after (c) and a fresh ADR).

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK + `check_wasm_h_upstream.sh`
  available (not yet gate-wired).
- §9.12-F (D-141 + reform): closed.
- §9.12-G: a/e/f/g done; b blocked-by ADR; c/d open.
- §9.12-H / §9.12-I: open.

## Open questions / blockers

- (b) blocked-by missing ZirOp slot design ADR. The mapping doc's
  table presents `memory.size_64` / `memory.grow_64` and
  relaxed-simd opcodes as aspirational targets; none are
  registered as ZirOp enum tags today. Decision needed:
  per-op enum slots vs index-type-dispatched shared slots.

## See

- [ROADMAP](./ROADMAP.md) §9.12-G; §4.1 zones
- [`.dev/wasm_3_0_zirop_mapping.md`](./wasm_3_0_zirop_mapping.md)
- [`.dev/architecture/zone_layout.md`](./architecture/zone_layout.md)
- [`.dev/phase10_prep.md`](./phase10_prep.md)
- [`scripts/check_wasm_h_upstream.sh`](../scripts/check_wasm_h_upstream.sh) — new this commit
- [`scripts/zone_check.sh`](../scripts/zone_check.sh) — BASELINE=0 + --gate
- [`debt.md`](./debt.md) — D-055 only `now`
- [`lessons/INDEX.md`](./lessons/INDEX.md)
