# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: J.close — docs-only。ROADMAP §10 / 10.J `[x]`
  flipped; ADR-0109 Revision row "Implementation complete; Status
  remains Accepted pending cw v1 dogfooding"; D-075 status re-scoped
  to "dogfooding gate only" (impl tracker duty discharged); plan §4.2
  coverage audit result appended。10.J 6 cycles closed (J.2..J.7 SHAs:
  `017193bc` `698c23ce` `995270cf` `b10922d2` `97434726` `05c47829`)。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。
- **Mac `zig build test`**: 1824/1838 passed (14 skipped); lint clean。

## Active task — 10.F NEXT (c_api scalar accessors)

10.J 完了。Phase 10 内の次の `[ ]` 行は **10.F** (c_api scalar
accessors D-171/172/173)。`/continue` loop は 10.F..10.P まで自走。

| Row | Scope | Status |
|---|---|---|
| 10.0 | Phase 9→10 transition | `[x]` |
| 10.C9 | Phase 9 close 後始末 | `[x]` |
| 10.J | Native Zig API (ADR-0109) | **CLOSED this commit** |
| **10.F NEXT** | c_api scalar accessors (D-171/172/173) — `wasm_extern_as_{global,table,memory}` + `wasm_global_new/get/set` + `wasm_table_get/set/size/grow` + `wasm_memory_data/data_size/size/grow` を `src/api/instance.zig` に追加 (wasm-c-api spec 標準)。Sub-chunks in `phase_log/phase10.md` row 10.F | `[ ]` |
| 10.Z | (TBD; ROADMAP §10 row Z) | `[ ]` |
| 10.D / 10.T / 10.M / 10.R / 10.TC / 10.E / 10.G / 10.P | (TBD; ROADMAP §10 rows) | `[ ]` |

**10.F exit criterion** (per ROADMAP §10 row + D-171/172/173):
spec-standard accessors を `src/api/instance.zig` に追加して
3 つの c_api audit gap (A1 / B1 / B2) を埋める; `wasm_global_new` 等
は `include/wasm.h:452-459 / 471-481 / 483-497` の signature exact。
v128 path は c_api から永久 excluded (spec-prohibited; lesson
`2026-05-24-c_api-v128-spec-boundary.md`). 詳細
`.dev/c_api_instance_audit_2026-05-24.md` + 各 D 行。

## Known plan latent issues

- ADR-0109 Status `Accepted` (not `Closed`) until cw v1 dogfooding
  feedback per Removal condition。D-075 carries the gate;
  retires when ADR-0109 flips。

## Phase 10 progress

ROADMAP §10 = 13-row task table。10.0/10.C9/10.J done; 10.F next;
10.Z/10.D/10.T/10.M/10.R/10.TC/10.E/10.G/10.P pending。

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1338+
- **ADR-0109**: [`decisions/0109_native_zig_api_inversion.md`](./decisions/0109_native_zig_api_inversion.md) (Accepted; impl-complete Revision row 2026-05-25; Closed pending cw v1 dogfooding)
- **10.J plan + audit**: [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md) §4.2 audit result
- **10.F audit context**: [`c_api_instance_audit_2026-05-24.md`](./c_api_instance_audit_2026-05-24.md)
- **Phase 10 全体設計**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
