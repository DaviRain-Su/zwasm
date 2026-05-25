# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: `995270cf` — J.4 TypedFunc(comptime Sig) + Memory +
  multi-result (ADR-0109 §3.1/§3.3/§3.4)。`src/zwasm/typed_func.zig` +
  `src/zwasm/memory.zig` 新規; `Instance.typedFunc(Sig, name)` +
  `Instance.memory()` 追加。Critical-path comptime layer 成立。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。
- **Mac `zig build test`**: 1819/1833 passed (14 skipped); lint clean。
  J.4 で新規 +4 test: T1.5 add / T1.6 swap (multi-result) /
  T1.7 Memory round-trip / T1.8 quiet-NaN bit preservation。
- **ubuntu test (`substrate`)**: HEAD `995270cf` を post-push で
  バックグラウンド kick 予定 — 次 resume Step 0.7 で verify。

## Active task — 10.J impl train (J.5 next)

ADR-0109 Accepted 2026-05-25。`/continue` loop は J.5..J.close まで自走。

| Sub-chunk | Scope | Gate | Status |
|---|---|---|---|
| ~~J.1~~ | (rename retracted) | n/a | WITHDRAWN 2026-05-25 |
| J.2 | Engine + Module skeleton; native parser; allocator strict-pass | substrate | CLOSED `017193bc` |
| J.3 | Instance + untyped invoke + full Trap set | substrate | CLOSED `698c23ce` |
| J.4 | TypedFunc + Memory + multi-result (critical path) | substrate | **CLOSED `995270cf`** |
| **J.5 NEXT** | `Linker` + `Caller` + host imports + host-func marshal | substrate | 着手準備完了 |
| J.6 | Tier-2 zig_facade_runner | cohort | J.5 後 |
| J.7 | WASI defineWasi skeleton | substrate | J.6 後 |
| J.close | Coverage audit + D-075 close + ROADMAP 10.J [x] | substrate | J.7 後 |

**J.5 exit criterion** (per plan §3 J.5):
(a) Tier-1 T1.9 `linker.defineFunc("env", "print", hostPrint)` +
instantiate + invoke imports the host fn correctly;
(b) T1.10 host fn calls `caller.memory()` and reads / writes Wasm linear memory;
(c) T1.11 defineFunc with arity-mismatched signature → `error.SignatureMismatch`
at instantiate;
(d) T1.12 two-instance memory sharing via `linker.defineMemory`。
新 `src/zwasm/linker.zig` (~200 LOC) + `src/zwasm/caller.zig` (~40 LOC) +
`src/zwasm/host_func_marshal.zig` (~150 LOC)。

**S-1 解決方針**: host-func marshal の ABI 経路は `runtime.HostCall`
(interp path; `runtime.zig:89-92`) を再利用; comptime adapter generator
が thunk を emit して `{fn_ptr, ctx}` shape に適合。JIT-side
`host_dispatch_base` は J.5 scope 外 (interp path のみで T1.9〜T1.12 通る)。
詳細 plan §3 J.5。

## Known plan latent issues

- **S-4** (J.close): "100% public-symbol coverage" vs coverage matrix の
  "deferred" 行 (`defineGlobal`/`defineTable`) の自己矛盾を J.close 時に
  exit criterion を "100% except D6 defer" に reframe。

## Phase 10 progress

ROADMAP §10 = 13-row task table (10.0/10.C9 done; 10.J active;
10.F/10.Z/10.D/10.T/10.M/10.R/10.TC/10.E/10.G/10.P pending; Phase 10
は 10.J close 時点では大半未完)。

## Key refs

- **Plan**: [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md) §3 (J.5 → J.close)
- **ADR-0109**: [`decisions/0109_native_zig_api_inversion.md`](./decisions/0109_native_zig_api_inversion.md) (Accepted + amended 2026-05-25 row 3)
- **Phase 10 全体設計**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1-§3.6
- **Zig API spec**: [`../docs/zig_api_design.md`](../docs/zig_api_design.md)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
