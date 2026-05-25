# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: `cf6f009e` — 10.F-b D-172 table accessors。
  `pub const Table` + minimal `pub const Ref` + 6 c_api exports
  (`wasm_ref_delete` / `wasm_extern_as_table` / `wasm_table_delete` /
  `wasm_table_size` / `wasm_table_get` / `wasm_table_set`)
  per `include/wasm.h:466-477 + 327-365`。Tier-1 round-trip test
  PASS。`wasm_table_grow` deferred to 10.F-c。File-size exempt cap
  2800→3000 via ADR-0099 (cap=N) override。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。
- **Mac `zig build test`**: 1826/1840 passed (14 skipped); lint clean。

## Active task — 10.F-c NEXT (D-171 wasm_global_new + wasm_table_grow follow-up)

10.F は 3 sub-chunks 構成:

| Sub-chunk | Scope | Status |
|---|---|---|
| 10.F-a | D-173 memory accessors | CLOSED `7a8c3ae2` |
| 10.F-b | D-172 table accessors (get/set/size + Ref) | CLOSED `cf6f009e` |
| **10.F-c NEXT** | D-171 `wasm_global_new` (host-side standalone) + deferred `wasm_table_grow` follow-up + any 10.F audit gap finalisation | 着手準備完了 |
| 10.F close | D-171/D-172/D-173 全 discharged; ROADMAP §10 / 10.F `[x]` flip | 10.F-c 後 |

**10.F-c exit criterion** (per `include/wasm.h:452-459` + audit §3 A1):
(a) `wasm_global_new(store, type, init) → ?*Global` — host-side
standalone Global construction (no Instance back-pointer; backed
by a Store-anchored Value cell);
(b) `wasm_globaltype_new(valtype, mutability) → ?*GlobalType` の
最小 surface 追加 (wasm_global_new の引数として必要);
(c) `wasm_table_grow(?*Table, u32 delta, ?*Ref init) → bool` —
deferred from 10.F-b; realloc-extend `rt.tables[idx].refs` with
init fill;
(d) Tier-1 round-trip tests: 標準で新しい Global を作って Extern wrap
してインスタンス imports へ渡す + table.grow round-trip;
(e) D-171 / D-172 / D-173 all in Discharged section; ROADMAP §10
row 10.F flips `[x]`。
詳細: audit §3 A1 + `include/wasm.h:452-459`。

## Phase 10 progress

ROADMAP §10 = 13-row task table。10.0/10.C9/10.J done; **10.F active
(3 sub-chunks; 2 done)**; 10.Z/10.D/10.T/10.M/10.R/10.TC/10.E/10.G/10.P pending。

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1338+
- **c_api audit**: [`c_api_instance_audit_2026-05-24.md`](./c_api_instance_audit_2026-05-24.md) §3 A1/B1/B2
- **lesson (v128 spec boundary)**: [`lessons/2026-05-24-c_api-v128-spec-boundary.md`](./lessons/2026-05-24-c_api-v128-spec-boundary.md)
- **wasm-c-api spec**: `include/wasm.h:452-477 + 327-365`
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
