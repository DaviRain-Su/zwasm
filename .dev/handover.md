# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: `017193bc` — J.2 `Engine` + `Module` native
  facade + allocator strict-pass (ADR-0109)。c_api `Runtime` +
  `Module` veneers が `src/zwasm.zig` から削除され、`src/zwasm/{engine,module}.zig`
  で native parser path に切り替え。Instance/Value は J.3 まで存続。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** (I3
  grep が `pub const Engine` に切替後も維持)。
- **Mac `zig build test`**: 1812/1826 passed (14 skipped =
  build-option / arch DCE 構造的スキップ、新規追加なし)。
- **ubuntu test (`substrate` class)**: HEAD `017193bc` を post-push
  でバックグラウンド kick 済 — 次 resume Step 0.7 で verify。

## Active task — 10.J impl train (J.3 next)

ADR-0109 Accepted 2026-05-25。`/continue` loop は J.3..J.close まで
自走; per-sub-chunk user 承認 不要。

| Sub-chunk | Scope | Gate | Status |
|---|---|---|---|
| ~~J.1~~ | (rename retracted) | n/a | WITHDRAWN 2026-05-25 |
| J.2 | Engine + Module skeleton; native parser; allocator strict-pass | substrate | **CLOSED `017193bc`** |
| **J.3 NEXT** | `Instance` + untyped `invoke` + full `Trap` error set re-export | substrate | 着手準備完了 |
| J.4 | TypedFunc + Memory + multi-result (**critical path**; spike 可) | substrate | J.3 後 |
| J.5 | Linker + Caller + host imports | substrate | J.4 後 |
| J.6 | Tier-2 zig_facade_runner | cohort | J.5 後 |
| J.7 | WASI defineWasi skeleton | substrate | J.6 後 |
| J.close | Coverage audit + D-075 close + ROADMAP 10.J [x] | substrate | J.7 後 |

**J.3 exit criterion** (per plan §3 J.3): (a) Tier-1 T1.3
`instance.invoke("main", &.{}, &results)` happy-path GREEN; (b) Tier-1
T1.4 div-by-zero invoke surfaces `error.IntDivByZero` (NOT
`error.Trap` catchall); (c) 12 Trap variants 全てが error union signature
経由で到達可能であることを `@typeInfo` で verify。新 `src/zwasm/instance.zig`
(~100 LOC); `src/zwasm.zig` の旧 `Instance` (c_api veneer) を削除。
`Trap` 再エクスポート元は `runtime.Trap`。詳細 plan §3 J.3。

## Known plan latent issues (Serious; J.3 着手中に解決推奨)

- **S-1** (J.5): host-func marshal の ABI 経路 (`runtime.HostCall`
  interp vs `host_dispatch_base` JIT) を J.5 着手時に明示。
- **S-2** (resolved at J.2): `Module` 削除が c_api `Module`
  (extern struct in `src/api/instance.zig`) に波及しない carve-out を
  確認済 — `pub const Module = @import("zwasm/module.zig").Module;` の
  re-export と c_api 側は名前空間別 (Zig 0.16 namespace separation)。
- **S-4** (J.close): "100% public-symbol coverage" vs coverage matrix の
  "deferred" 行 (`defineGlobal`/`defineTable`) の自己矛盾を J.close 時に
  exit criterion を "100% except D6 defer" に reframe。

## Phase 10 progress

ROADMAP §10 = 13-row task table (10.0/10.C9 done; 10.J active;
10.F/10.Z/10.D/10.T/10.M/10.R/10.TC/10.E/10.G/10.P pending; Phase 10
は 10.J close 時点では大半未完)。

## Key refs

- **Plan**: [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md) §3 (J.3 → J.close)
- **ADR-0109**: [`decisions/0109_native_zig_api_inversion.md`](./decisions/0109_native_zig_api_inversion.md) (Accepted + amended 2026-05-25 row 3)
- **Phase 10 全体設計**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1-§3.6
- **Zig API spec**: [`../docs/zig_api_design.md`](../docs/zig_api_design.md)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
