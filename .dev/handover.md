# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: `698c23ce` — J.3 Instance native + full 12-variant
  Trap set (ADR-0109 §3.5/§3.6)。`src/zwasm/instance.zig` 新規; c_api
  veneer の `error.Trap` catchall 廃止; dispatch.run 直接呼び出しで
  `OutOfBoundsLoad`/`OutOfBoundsStore` + `StackOverflow`/`CallStackExhausted`
  も個別可達。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。
- **Mac `zig build test`**: 1815/1829 passed (14 skipped = build-option /
  arch DCE 構造的スキップ; J.3 で新規 +3 test: T1.3/T1.4/T1.4-types)。
- **ubuntu test (`substrate`)**: HEAD `698c23ce` を post-push で
  バックグラウンド kick 予定 — 次 resume Step 0.7 で verify。

## Active task — 10.J impl train (J.4 next; **critical path**)

ADR-0109 Accepted 2026-05-25。`/continue` loop は J.4..J.close まで
自走。

| Sub-chunk | Scope | Gate | Status |
|---|---|---|---|
| ~~J.1~~ | (rename retracted) | n/a | WITHDRAWN 2026-05-25 |
| J.2 | Engine + Module skeleton; native parser; allocator strict-pass | substrate | CLOSED `017193bc` |
| J.3 | Instance + untyped invoke + full Trap set | substrate | **CLOSED `698c23ce`** |
| **J.4 NEXT** | `TypedFunc(comptime Sig)` + Memory + multi-result (**critical path**; spike 可) | substrate | 着手準備完了 |
| J.5 | Linker + Caller + host imports | substrate | J.4 後 |
| J.6 | Tier-2 zig_facade_runner | cohort | J.5 後 |
| J.7 | WASI defineWasi skeleton | substrate | J.6 後 |
| J.close | Coverage audit + D-075 close + ROADMAP 10.J [x] | substrate | J.7 後 |

**J.4 exit criterion** (per plan §3 J.4):
(a) Tier-1 T1.5 `instance.typedFunc(fn(i32, i32) i32, "add").call(.{2, 3})`
returns `5`;
(b) T1.6 multi-result `fn(i32, i32) struct { i32, i32 }` returns ordered tuple;
(c) T1.7 `mem.write(0x100, @as(i32, 42))` + `mem.read(i32, 0x100)` round-trip;
(d) T1.8 NaN-boxing round-trip f64 quiet NaN bits preserved (no canonicalization)。
新 `src/zwasm/typed_func.zig` (~300 LOC; comptime `@typeInfo(.@"fn")`)
+ `src/zwasm/memory.zig` (~80 LOC)。
**Risk: CRITICAL** — comptime layer は ADR-0109 設計の中核。詰まったら
0.5-cycle spike (`private/spikes/typed_func/`) → 必要なら ADR-0109
amendment per `architectural_spike.md`。詳細 plan §3 J.4。

## Known plan latent issues

- **S-1** (J.5): host-func marshal の ABI 経路 (`runtime.HostCall`
  interp vs `host_dispatch_base` JIT) を J.5 着手時に明示。
- **S-4** (J.close): "100% public-symbol coverage" vs coverage matrix の
  "deferred" 行 (`defineGlobal`/`defineTable`) の自己矛盾を J.close 時に
  exit criterion を "100% except D6 defer" に reframe。

## Phase 10 progress

ROADMAP §10 = 13-row task table (10.0/10.C9 done; 10.J active;
10.F/10.Z/10.D/10.T/10.M/10.R/10.TC/10.E/10.G/10.P pending; Phase 10
は 10.J close 時点では大半未完)。

## Key refs

- **Plan**: [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md) §3 (J.4 → J.close)
- **ADR-0109**: [`decisions/0109_native_zig_api_inversion.md`](./decisions/0109_native_zig_api_inversion.md) (Accepted + amended 2026-05-25 row 3)
- **Phase 10 全体設計**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1-§3.6
- **Zig API spec**: [`../docs/zig_api_design.md`](../docs/zig_api_design.md)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
