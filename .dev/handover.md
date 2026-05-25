# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: `7a8c3ae2` — 10.F-a D-173 memory accessors。
  `pub const Memory` + 5 wasm-c-api spec exports
  (`wasm_extern_as_memory` / `wasm_memory_data{,_size}` /
  `wasm_memory_size` / `wasm_memory_grow` / `wasm_memory_delete`)
  per `include/wasm.h:471-481`。Tier-1 round-trip test PASS。
  File-size exempt cap 2500→2800 via ADR-0099 (cap=N) override。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。
- **Mac `zig build test`**: 1825/1839 passed (14 skipped); lint clean。

## Active task — 10.F-b NEXT (D-172 table accessors)

10.J 完了; 10.F は 3 sub-chunks に分割中:

| Sub-chunk | Scope | Status |
|---|---|---|
| 10.F-a | D-173 memory accessors | CLOSED `7a8c3ae2` |
| **10.F-b NEXT** | D-172 table accessors — `pub const Table` + `wasm_extern_as_table` + `wasm_table_get / set / size / grow` per `include/wasm.h:483-497`。Tier-1 round-trip test on `mixed_exports_wasm` 's exported "t" table | 着手準備完了 |
| 10.F-c | D-171 `wasm_global_new` (the only missing scalar-global export; `wasm_extern_as_global` + `wasm_global_get/set` already shipped). 既存テストが `wasm_global_new` を必要としていれば paired test 追加 | 10.F-b 後 |
| 10.F close | D-171/D-172/D-173 全 discharged; ROADMAP §10 / 10.F `[x]` flip | 10.F-c 後 |

**10.F-b exit criterion** (per `include/wasm.h:483-497`):
(a) `pub const Table = struct { instance, table_idx }` 追加;
(b) `Extern.table: ?*Table` field + exports loop の `.table` branch で Table handle 生成;
(c) `wasm_extern_as_table` / `wasm_table_get` / `wasm_table_set` /
`wasm_table_size` / `wasm_table_grow` / `wasm_table_delete` exports 追加;
(d) Tier-1 round-trip test on `mixed_exports_wasm` 's "t" table (funcref);
(e) `wasm_extern_delete` cascade に Table 追加。
詳細: audit §3 B1 + `include/wasm.h:483-497`。

## Phase 10 progress

ROADMAP §10 = 13-row task table。10.0/10.C9/10.J done; **10.F active
(3 sub-chunks; 1 done)**; 10.Z/10.D/10.T/10.M/10.R/10.TC/10.E/10.G/10.P pending。

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1338+
- **c_api audit**: [`c_api_instance_audit_2026-05-24.md`](./c_api_instance_audit_2026-05-24.md) §3 B1/B2/A1
- **lesson (v128 spec boundary)**: [`lessons/2026-05-24-c_api-v128-spec-boundary.md`](./lessons/2026-05-24-c_api-v128-spec-boundary.md)
- **wasm-c-api spec**: `include/wasm.h:452-497` (global/table/memory accessor signatures)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
