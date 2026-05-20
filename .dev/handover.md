# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. `git log --oneline -10` — last commit: `4cb46274`
   (backfill_adr_shas.sh --multi-report mode)。直近 code:
   `c3e391f9` (ADR-0079 Steps 2+3 close)。
2. **Live status**: `zig build test-spec-wasm-2.0-assert >
   /tmp/spec.log 2>&1 || true; grep "passed\\|^FAIL " /tmp/spec.log`
   — Mac aarch64 baseline expected at HEAD `7b2e1b02`:
   spec non_simd 25401 PASS / 0 FAIL / 0 runtime-skip / 525
   skip-adr; spec simd 13351 / 0 / 0 / 390 skip-adr; 4 testsuites
   green.
3. ROADMAP §9 Phase Status widget: Phase 9 IN-PROGRESS。§9.12-E
   は `[x]` 既 close (`7b2e1b02` Mac). 次 `[ ]` は **§9.12-F**
   (Phase-9-eligible debt cohort)。

## Active state

- Phase 9.12-E **完** (`7b2e1b02` Mac aarch64, 4 testsuites
  green). close-plan §6 (j) Step B 完了 — 43 → 0 FAIL, 192 → 0
  runtime-skip, +93 PASS over 7 chunks。close-plan §7
  (Accept) を次 cycle で正式に締める想定。
- §9.12-F **進行中** (`3ace7fb4`): 6 dissolved-barrier closures
  (D-153/154/156/102/103/105); D-079 barrier rewritten honestly。
  active rows 31 → 25 (target < 15)。
- §9.12-F residual の honest accounting:
  - **speculative-preventive** (corpus does not exercise) —
    D-090 (lower select type-stack walker) / D-094 (x86_64
    multi-result hidden-ptr) / D-062 (arm64 v128 9th+ overflow)。
    `karpathy-guidelines` (auto-load) と `no_workaround.md` で
    指針: "don't add features beyond what the task requires" →
    実装には触らず、被害が surface した時に対応。
  - **multi-cycle architectural** — D-141 (file_size_check
    WARN; per-file ADR + impl across runner.zig (ADR-0079
    Proposed) / validator.zig / lower.zig / emit.zig × 2 archs
    / inst.zig × 2 archs) / D-081 (emit.zig source split) /
    D-055 (emit_test_*.zig migration; depends D-081)。next
    cycle で ADR-0079 runner.zig 3-way split implementation
    が高 yield (1995 → ~700+700+600 LOC、現在 EXEMPT marker
    で乗っ取り中)。
  - **external blocker** — D-010 (Zig stdlib) / D-021 (Phase
    14 concurrency) / D-028 (zig 0.16 IPC) / D-148 (Codeberg
    ziglang/zig#35343) — 維持。
  - **Phase-future-row blocked** — D-007 / D-018 / D-020 /
    D-022 / D-026 / D-058 / D-059 / D-074 / D-075 / D-082 /
    D-136 / D-139 / D-149 — 当該 Phase row open まで凍結
    (Phase 10 / 11 / 14 / v0.1.0 RC etc)。
  - **now-status (mechanical)** — D-155 (ADR-0078 token-class
    follow-up scripts): non-trivial; runner output schema 拡張
    が前提なので multi-cycle。
- 結論: §9.12-F の "< 15" target は構造的に achievable for
  this loop iteration ではない。speculative-preventive の
  3 件を fix する vs ADR-0079 を impl する のいずれかが
  next cycle の高 yield 候補。
- ADR-0079 全 Step 完 (`166cb319` Step 1 + `c3e391f9` Steps 2+3):
  - setup.zig 555 LOC (RuntimeOwned + setupRuntime +
    hostDispatchTrap)
  - compile.zig 1225 LOC (compileWasm + apply* / patch* /
    declaredTable* / countDeclaredTables / resolveFuncrefGlobals)
  - runner.zig 2051 → 397 LOC (driver only: Error / CompiledWasm
    / findExportFunc / runI32Export / runVoidExport + tests +
    pub-const re-exports for backwards-compat external surface)
- D-141 row partial discharge: runner.zig now under 1000 soft cap。
  WARN list 残: validator.zig / lower.zig / liveness.zig /
  emit.zig (arm64+x86_64) / inst.zig (arm64+x86_64) / op_simd_*。
- §9.12-G partial discharge (`39f1dc15`): Wasm 3.0 ZirOp mapping
  doc + wasm.h byte-identical + zone_check --gate enforced。
- §9.12-I partial discharge (`0ceed353` + `4cb46274`): D-149
  mechanical SHA backfill 42/100。`scripts/backfill_adr_shas.sh
  --multi-report` で 46 multi-match candidates 一覧化 ←
  narrative-context-pass の入力。残 57 placeholders 中:
  - 46 multi-match (candidates list で human review)
  - 5 zero-match (date mismatch; manual check)
  - 6 inline-no-date (placeholder line に date 無し; nearby
    lookup でも見つからず)
  各々 ADR の prose を読みつつ 1 file ずつ pass する必要あり。
  autonomous loop の効率が低いため、batch session で対応推奨。
- 次 cycle 候補:
  - §9.12-G 残: all-Phase-10-feature-ZirOp comptime reject
    infrastructure (大きい), c_api Instance test (D-139 blocked)
  - §9.12-H bench baseline (Mac-only Wasm 2.0 + wasmtime
    comparison)
  - §9.12-I D-149 ADR SHA backfill (tedious mechanical, 75
    entries)
  - D-141 残 per-file ADR (validator.zig / lower.zig / emit.zig
    × 2 archs / inst.zig × 2 archs / liveness.zig)

## Ubuntu mirror verification

- Mac aarch64 で 4 testsuites green は確認済 (`7b2e1b02`)。
- ubuntunote 上の test-spec mirror は `bash scripts/
  run_remote_ubuntu.sh test-spec-wasm-2.0-assert &` で次 push
  時に kick。`§9.12-E` exit text の `Mac+ubuntunote
  bit-identical` 要件は ubuntu mirror が一致した時点で
  完成宣言。

## Open questions / blockers

- なし。autonomous loop resumed。

## §9.12-B progress chunks

`.dev/phase_log/p9_12_B_chunks.md` (B1〜B158) に移管。
handover はポインタのみ保持。

## See

- [ROADMAP](./ROADMAP.md) §9.12 — §9.12-E `[x]` `7b2e1b02`,
  next `[ ]` = §9.12-F。
- [`debt.md`](./debt.md) — D-094 / D-090 / D-062 / D-141 /
  D-081 / D-055 が §9.12-F の対象。
- [`phase9_structural_debt_close_plan.md`](./phase9_structural_debt_close_plan.md)
  §6 (j) Step B execution log。
- [`lessons/INDEX.md`](./lessons/INDEX.md) — 2026-05-20 entry。
