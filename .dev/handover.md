# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: `9aef64ee` (naming 正規化 cw v2 → cw v1 + plan
  APPROVED + handover J.1 retarget)。
- **Phase 9 close invariants gate (mac-host)**: **18/18 PASS** 維持。
- **ubuntu test-all** (HEAD `9aef64ee` verified 2026-05-25): exit 0
  GREEN (background gate against accumulated d558c898→9aef64ee
  code gap including 142502a5 D-171 minimum-viable)。

## Bucket-2 stop — 10.J Plan + ADR-0109 systemic issues (re-audit)

**Discovered 2026-05-25 at J.1 着手**. User 承認済の Plan + ADR-0109 に
**新規型名導入前の既存名 grep が抜けている** という systemic な欠陥が
ある。2 つの並列 agent (deep-analysis + plan-audit) で 10 findings;
うち 3 が blocker (= 着手不能), 4 が serious (= 着手中に追加発見が
高確率)。Plan 全体の amend round が必要 (1 cycle docs work)。

### Blockers (3) — plan amend 必須

**B-1: `JitRuntime` 名は既に取得済**
- ADR-0109 §1 + plan J.1 が `runtime.Runtime` → `runtime.JitRuntime`
  rename を規定。前提: "JIT-emitted code reads via [X19 + offset]" の
  ABI surface を保持する。
- 事実: `src/engine/codegen/shared/jit_abi.zig:137` に既に
  `pub const JitRuntime = extern struct` (vm_base/mem_limit/
  funcptr_base/table_size/typeidx_base/trap_flag/globals_base/
  host_dispatch_base) が存在 (399 usages / 26 files)。
- JIT body が `[X19 + @offsetOf(JitRuntime, ...)]` で読むのは
  `jit_abi.JitRuntime` であり (jit_abi.zig:396-428 のオフセット定数;
  arm64/emit.zig:233-244 が `jit_abi.vm_base_off` 等を使用)、
  `runtime.Runtime` ではない。ADR-0109 §1 の rationale は誤認。
- **推奨 rename target**: `InterpRuntime` (`InterpRuntime` vs
  `JitRuntime` の対称形; interp engine per-instance state を明示;
  衝突なし)。alternatives: `RuntimeState` (汎用すぎ), `RuntimeCtx`
  (Ctx は per-call の含意), `Runtime` 維持 (ADR-0109 §"Alternatives
  Rejected" rationale が機能停止)。

**B-2: `Engine` 名も既に取得済** (= 同型問題が J.2 にも潜在)
- ADR-0109 §1 + plan J.2 が `src/zwasm/engine.zig` に新規
  `pub const Engine = struct` を導入予定。
- 事実: 既に 4 箇所で `Engine` 使用中:
  - `src/runtime/engine.zig:19`: `pub const Engine = extern struct
    { alloc_ptr, alloc_vtable }` (wasm-c-api `wasm_engine_t` の
    shape)
  - `src/runtime/runtime.zig:60`: `pub const Engine = @import(...).Engine`
  - `src/api/instance.zig:71`: `pub const Engine = runtime.Engine`
  - `src/api/wasm.zig:80`: `pub const Engine = instance.Engine`
- **推奨対応**: c_api 側 `Engine` を `CApiEngine` / `WasmCApiEngine`
  にリネーム (J.1 と同 chunk または J.1 直後)、OR native facade
  側を `ZwasmEngine` 等にする。ADR-0109 §1 の Decision 文に明示
  追加必要。

**B-3: I3 invariant gate の更新タイミング矛盾**
- `scripts/check_phase9_close_invariants.sh:83` は
  `src/zwasm.zig` で `pub const Runtime` を grep する Phase 9
  close の永続 regression check (`.claude/rules/phase9_close_invariants.md`
  で「permanent regression check」明記)。
- Plan J.2 (line 136) で「I3 grep を `pub const Engine` に更新」
  と claim、同時に J.close (line 215) でも同じ更新を claim。
  どちらかは余剰; どちらか一方に固定すべし。J.2 で更新するなら
  J.close の重複記述を「J.2 で完了済」に書き換え。

### Serious (4) — 着手中に追加発見の高確率

**S-1: J.5 host-func marshal の ABI 経路指定が欠落** — `runtime.HostCall`
(interp 経路; `*Runtime` 引数) と JIT `host_dispatch_base` (= JIT
経路; `jit_abi.JitRuntime` の field) のどちらに thunk が合わせるか
未指定。J.1 rename 後の HostCall.fn_ptr 型変更も J.5 scope に
未反映。

**S-2: J.2 `Module` 削除が c_api `Module` (`src/api/instance.zig`
extern struct) に波及するリスク**。Plan は "Old `src/zwasm.zig::Module`
DELETED" と書くが、c_api wasm_* 経路には及ばない carve-out が
exit criterion に必要。

**S-3: ADR-0109 vs plan の file-path 不整合** — ADR
Consequences §"Negative" (line 224) は `src/api/linker.zig` /
`src/api/memory_view.zig` (new); plan §3 J.5 は
`src/zwasm/linker.zig` 等。どちらが authoritative か明文化必要。

**S-4: J.close exit criterion 自己矛盾** — (a) "100% public-symbol
coverage" 要求の一方で coverage matrix (line 269-270) は
`Linker.defineGlobal` / `defineTable` を "deferred" と明記。
mechanical 判定不能。

**S-5: J.1 files-touched に `src/zwasm.zig` 欠落** — `src/zwasm.zig:105`
の `pub const Runtime` struct 内で `runtime.Runtime` を参照。
J.1 rename がここにも波及するが plan 列挙 17 files に含まれない。

### Cosmetic (3) — 致命的でない

- ADR-0109 References §ADR-0107 行に旧 draft 表現残存
- Plan §0 が "12 task rows" と言いつつ列挙は 13 行 (10.0..10.P)
- ADR-0109 "6-8 cycles" と plan §7 "8-12 cycles" の数字 diverge

### Autonomous prep walked this resume (do not re-walk)

- ubuntu test-all (HEAD `9aef64ee`): exit 0 GREEN.
- Phase 9 close invariants gate: 18/18 PASS.
- 2 並列 agent (`feature-dev:code-explorer` deep-analysis +
  `feature-dev:code-reviewer` plan-audit) を派遣 →
  上記 10 findings 集約 (各々 file:line 根拠あり)。
- agent IDs: `a85fd862f09c5e323` (rename target deep-fix),
  `a006c2bfda015bf45` (plan audit) — 詳細逐語修正案 (ADR §1 +
  Consequences + Alternative D + plan J.1 + R3 + survey §3 追記)
  は agent 1 の report を参照。

### Gating user touchpoint(s)

Loop stops **without re-arm**. User decision needed on:

- **Q1 (B-1)**: rename target — `InterpRuntime` (recommended) /
  `RuntimeState` / `Runtime` 維持 / その他。
- **Q2 (B-2)**: `Engine` 衝突解消 — c_api 側 rename
  (`CApiEngine` 等; recommended) / native facade 側 rename
  (`ZwasmEngine`) / ADR-0109 §1 全面再設計。
- **Q3 (B-3, S-1..S-5, cosmetic)**: amend cycle を 1 cycle で
  まとめて消化することを承認するか (= 次 /continue で agent 報告
  逐語案を順次 ADR-0109 amend + plan amend + survey 追記; その後
  J.1 着手)。

**Resume path**: Q1/Q2/Q3 を裁定後 `/continue`。autonomous mode で
amend cycle 1 cycle → J.1 〜 J.close と再開。

## Key refs (full snapshot in ROADMAP §10 / /continue SKILL.md)

- **Plan + ADR amend target**: [`phase10_zig_api_plan.md`](./phase10_zig_api_plan.md) §3 + [`decisions/0109_native_zig_api_inversion.md`](./decisions/0109_native_zig_api_inversion.md)
- **Phase 10 全体設計**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1-§3.6
- **Zig API spec**: [`../docs/zig_api_design.md`](../docs/zig_api_design.md)
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
- **Phase 9 close master**: [`phase9_close_master.md`](./phase9_close_master.md) (ARCHIVED-IN-PLACE 2026-05-25)
- **ROADMAP §10**: 13-row task table (10.J ACTIVE; ~10 rows pending)
