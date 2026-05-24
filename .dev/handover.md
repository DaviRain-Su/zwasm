# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
  §9.13 hard gate cleared; widget 9→DONE; §10 task table inline 展開済。
  **10.C9 closed** (this commit; 5 sub-steps recorded in
  `phase_log/phase10.md`)。
- **Last commit**: this commit (10.C9 [x] flip + phase_log/phase10.md
  作成 — step 5). 10.C9 直近 4 commits: `1433004b` (steps 1+2 SHA backfill
  + audit) → `e861143c` (step 3 bench baseline) → `4f612ba9` (handover
  retarget) → `91059738` (step 4 master plan ARCHIVED-IN-PLACE + I7 amend
  + rule retirement note).
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持
  (I7 ARCHIVED-IN-PLACE 受理確認済)。

## Active task — 10.F c_api scalar accessors (next chunk)

per ROADMAP §10 / 10.F row + `phase9_close_master.md` §5.3a Phase F:

**Scope**: `src/api/instance.zig` に wasm-c-api spec 標準 scalar
accessor 群を追加。closes D-171 / D-172 / D-173 の 3 行（全て
`blocked-by: Phase F`）。

- **D-171** — `wasm_extern_as_global` + `wasm_global_new` +
  `wasm_global_get` + `wasm_global_set` (scalar i32/i64/f32/f64
  のみ; v128 は spec-prohibited per `2026-05-24-c_api-v128-spec
  -boundary` lesson + `include/wasm.h:329-338`)
- **D-172** — `wasm_extern_as_table` + `wasm_table_get` /
  `wasm_table_set` / `wasm_table_size` / `wasm_table_grow`
  (`include/wasm.h:483-497`)
- **D-173** — `wasm_extern_as_memory` + `wasm_memory_data` /
  `wasm_memory_data_size` / `wasm_memory_size` / `wasm_memory
  _grow` (`include/wasm.h:471-481`)

**Approach**: 1 chunk (or up to 3 if test diff > 400 LOC). Step 0
survey: wasmtime / wasmer の `crates/c-api/src/{global,table,memory}.rs`
+ wasm-c-api `include/wasm.h` 該当範囲 + v1 zwasm `src/c_api/`。
TDD: 各 accessor に in-source `test "wasm 2.0 c_api scalar
accessor: <fn>"` block。

## 10.F 完了後の chunk 順序 (design plan §6 全体)

- 10.Z (ZirInstr 128-bit 拡張; Z.1 直接実装)
- 10.D (ADR-0111-0117 + ROADMAP §12 amend 設計ラウンド)
- 10.T (test infra: corpus import / stress runners / emit_test
  baseline / realworld skeleton)
- 10.M (memory64) → 10.R (function-refs) → 10.TC (Tail Call)
  → 10.E (EH) → 10.G (WasmGC)
- 10.P (Phase 10 close: invariants script + widget 10→DONE)

## Audit follow-up (4 soon items; cleanup chunk候補)

audit-2026-05-24-phase9-close.md `soon` セクション:

- **ADR-0078 paired-artifact drift** — 3 SKIP-* rows (D-157 /
  D-162 / D-163) reference discharged debts; table の Paired
  artifact column を `D-NNN @ <discharge-sha>` 形式に更新 OR
  SKIP-* emission retire。10.C9 後 cleanup chunk。
- **Spike lifecycle hygiene** — 7 件 (2 merged-into-prod 残置 +
  5 pre-skeleton no-README); `chore(audit): spike lifecycle
  hygiene per audit-2026-05-24` bundle 1 commit。
- **ADR `<backfill>` 5 件 (ADR-0107 含む)** — 10.C9 step 2 で
  ROADMAP 側は完了; ADR 側は別 work。Phase 10 内で消化。
- **Debt 25 rows > 15 threshold + Phase 9 boundary** → `meta_audit`
  suggest (J.3 + J.7); user-gated per `meta_audit/SKILL.md` —
  do NOT autonomously fire; surface at next resume only。

## Cold-start procedure

Per `/continue` SKILL.md Resume Steps 0.5 / 0.7 / 0.8。Step 0.8
の `scripts/check_phase9_close_invariants.sh --gate` は Phase 9 =
DONE 後 permanent regression check として残存 (I7 ARCHIVED-IN-PLACE
受理済; 18/18 PASS)。

**Phase 10 設計の authoritative source**:
[`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3-§8。

## See

- [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) —
  r3; サブシステム別実装方針 / テスト戦略 / 7 ADR / 23 invariants
- [`phase10_transition_gate_ja.md`](./phase10_transition_gate_ja.md)
  — §9.13 ゲート文書日本語版・現実反映 (cleared)
- [`phase9_close_master.md`](./phase9_close_master.md) — Phase 9
  close master plan (ARCHIVED-IN-PLACE 2026-05-25; cite-only)
- [`phase_log/phase10.md`](./phase_log/phase10.md) — Phase 10
  sub-chunk record (per §18.3 prose-offload)
- ROADMAP §10 (inline expanded; 11 sub-rows 10.0-10.P)
- `private/audit-2026-05-24-phase9-close.md` (gitignored; 10.C9
  step 1 deliverable; 0 block / 4 soon / 6 watch)
- `private/notes/p10-design/{01..12}-*.md` (gitignored; 業界調査
  6948 行; phase10_design_plan_ja.md References §から参照)
