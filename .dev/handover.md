# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

File-size discipline reform complete (2026-05-21 cycles C1..C6).
Standard cold-start procedure resumes; next priority is §9.12-G.

1. ROADMAP §9.12 open items: G (`api/instance.zig` redesign), H
   (bench baseline), I (ADR/lesson curation closure). Approach
   §9.12-G by evaluating P3 conditions per ADR-0099 §D2 **before**
   any extraction (c_api lifecycle redesign; not file-size-driven).
2. **DO NOT** mechanically extract WARN files from
   `scripts/file_size_check.sh`. ADR-0099 §D1 makes EXEMPT the
   default outcome when no valid extraction exists.
3. `bash scripts/check_split_smell.sh` runs informationally inside
   `gate_commit.sh`. Current 6 findings are acceptable carve-outs:
   - api/wasm.zig hub-emptiness (public C ABI surface).
   - inst_neon N3 (informational, naming-pattern sibling).
   - regalloc_compute N1 test-context (intentional round-trip).
   - regalloc.zig + regalloc_compute.zig testFenceTableFill N4
     dup (3-LOC helper, ADR-0100 accepted).
   - sections_codes / sections_data N3 (P1 spec-axis siblings;
     §D2 tie-breaker acceptable even though substantive < 100).

## Active `now` debts

- **D-055** (mechanical, multi-cycle): emit_test_int has 27 sites
  pending. Discharge unblocked now that reform has landed.

## Other queued work

1. **§9.12-G** — `api/instance.zig` redesign (P3 evaluation per
   ADR-0099 §D2; c_api lifecycle restructure).
2. **§9.12-H** — bench baseline (Mac Wasm 2.0 + wasmtime
   comparison).
3. **§9.12-I** — ADR/lesson curation closure (Phase 9 close).
4. **D-055 continuation** (now unblocked).
5. **Remaining D-141 WARN files** — most resolve to
   FILE-SIZE-EXEMPT marker per ADR-0099 §D2; the audit_scaffolding
   §J.8 split-smell finding is the source of truth, not the raw
   WARN list.

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK (check_split_smell.sh wired).
- §9.12-F (D-141 sweep + reform): closed. 15 ADRs Accepted; net
  after reform = 12 valid + 1 redesigned (init_expr) + 3 retired.
- §9.12-G / §9.12-H / §9.12-I: open.

## Reform — closed (this session, 2026-05-21)

- ADR-0099 (file-size discipline reframe; 4+4 conditions; EXEMPT
  as default).
- ADR-0100 (retrospective rollback notice; ADR-0097 rolled back,
  ADR-0095/0096 superseded by ADR-0101).
- ADR-0101 (init_expr.zig extraction; P3 deep utility).
- `.claude/rules/file_size_smell.md` (auto-loaded discipline).
- `scripts/check_split_smell.sh` (informational gate addition).
- `.dev/lessons/2026-05-21-file-size-cap-as-smell-detector-not-metric.md`.
- Planning artifacts archived at
  `private/archive/2026-05-21-file-size-reform/`.

## Open questions / blockers

- なし。

## See

- [`.dev/decisions/0099_file_size_discipline_reframe.md`](./decisions/0099_file_size_discipline_reframe.md)
- [`.dev/decisions/0100_rollback_invalid_d141_extractions.md`](./decisions/0100_rollback_invalid_d141_extractions.md)
- [`.dev/decisions/0101_init_expr_extraction.md`](./decisions/0101_init_expr_extraction.md)
- [`.claude/rules/file_size_smell.md`](../.claude/rules/file_size_smell.md)
- [`scripts/check_split_smell.sh`](../scripts/check_split_smell.sh)
- [`.dev/lessons/2026-05-21-file-size-cap-as-smell-detector-not-metric.md`](./lessons/2026-05-21-file-size-cap-as-smell-detector-not-metric.md)
- [ROADMAP](./ROADMAP.md) §9.12 G/H/I; §5 A2 reframed
- [`debt.md`](./debt.md) — D-055 only `now`
- [`lessons/INDEX.md`](./lessons/INDEX.md)
