# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: this commit — 10.J Plan + ADR-0109 J.1 rename
  clause WITHDRAWN per 2026-05-25 user-direction (Zig 0.16 namespace
  separation で `runtime.Runtime` + `jit_abi.JitRuntime` は問題なく
  coexist; ADR-0017 sub-2a が `Jit` prefix を最初から付けていた設計
  intent を維持; 詳細は ADR-0109 Revision history row 3 + plan §3 J.1
  retraction note)。直前: `4d626f3e` (handover audit report) →
  `9aef64ee` (cw v1 naming 正規化)。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。
- **ubuntu test-all** (HEAD `9aef64ee` 時点; 2026-05-25 verified):
  exit 0 GREEN。

## Active task — 10.J impl train (J.2..J.close)

ADR-0109 Accepted 2026-05-25 + amended same day (J.1 withdrawn).
`/continue` loop は **J.2 から J.close まで自走**; 各 sub-chunk close
時に handover が次 sub-chunk へ retarget; 7-11 cycles 想定;
per-sub-chunk user 承認 不要。

| Sub-chunk | Scope | Gate | Status |
|---|---|---|---|
| ~~J.1~~ | (rename retracted) | n/a | WITHDRAWN 2026-05-25 |
| **J.2 NEXT** | `Engine` + `Module` skeleton; native parser path; allocator strict-pass (new starting chunk) | substrate | 着手準備完了 |
| J.3 | Instance + 完全 Trap set | substrate | J.2 後 |
| J.4 | TypedFunc + Memory + multi-result (**critical path**; spike 可) | substrate | J.3 後 |
| J.5 | Linker + Caller + host imports | substrate | J.4 後 |
| J.6 | Tier-2 zig_facade_runner | cohort | J.5 後 |
| J.7 | WASI defineWasi skeleton | substrate | J.6 後 |
| J.close | Coverage audit + D-075 close + ROADMAP 10.J [x] | substrate | J.7 後 |

**J.2 exit criterion**: (a) `Engine.init(custom_recording_allocator, .{})`
で allocator strict-pass verified; (b) `engine.compile(facade_extend8_s_wasm)`
→ `Module` 成功; (c) Tier-1 "zwasm facade Wasm 2.0 round-trip via Engine /
Module / Instance" GREEN; (d) I3 invariant gate GREEN (新 grep
`pub const Engine`); (e) 内部 `runtime.Runtime` (`src/runtime/runtime.zig:96`)
は unchanged の確認 (J.1 withdrawn 後)。詳細 plan §3 J.2。

## Known plan latent issues (Serious; 着手中に解決推奨)

audit で surface したが致命的でない: 着手 cycle 内で paired-discharge
する流れ。

- **S-1** (J.5): host-func marshal の ABI 経路 (`runtime.HostCall`
  interp vs `host_dispatch_base` JIT) を J.5 着手時に明示。
- **S-2** (J.2): `Module` 削除が c_api `Module` (extern struct) に
  波及しない carve-out を exit criterion に追加。
- **S-3** (resolved 2026-05-25 ADR amend): ADR-0109 Consequences の
  `src/api/linker.zig` 等 path を `src/zwasm/*` に修正済。
- **S-4** (J.close): "100% public-symbol coverage" vs
  coverage matrix の "deferred" 行 (`defineGlobal`/`defineTable`) の
  自己矛盾を J.close 時に exit criterion を "100% except D6 defer"
  に reframe。
- **B-3** (resolved 2026-05-25 ADR amend): I3 invariant grep
  update は J.2 のみで実施 (J.close 重複は plan §3 J.close の
  Files-touched 行で「J.2 で完了済」と明示することで解消)。

## Phase 10 progress

ROADMAP §10 = 13-row task table (10.0/10.C9 done; 10.J active;
10.F/10.Z/10.D/10.T/10.M/10.R/10.TC/10.E/10.G/10.P pending; Phase 10
は 10.J close 時点では大半未完)。

## Key refs

- **Plan**: [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md) §3 (J.2 → J.close)
- **ADR-0109**: [`decisions/0109_native_zig_api_inversion.md`](./decisions/0109_native_zig_api_inversion.md) (Accepted + amended 2026-05-25 row 3)
- **ADR-0017** (`Jit` prefix の歴史): [`decisions/0017_jit_runtime_abi.md`](./decisions/0017_jit_runtime_abi.md)
- **Phase 10 全体設計**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1-§3.6
- **Zig API spec**: [`../docs/zig_api_design.md`](../docs/zig_api_design.md)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
