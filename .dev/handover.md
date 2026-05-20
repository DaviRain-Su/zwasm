# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure

1. **READ FIRST** [`.dev/phase9_structural_debt_close_plan.md`](phase9_structural_debt_close_plan.md)
   (Status: Proposed 2026-05-20). この close-plan が
   `/continue` Step 1a の override を発火させ、ROADMAP
   §9.<N> task より先に §6 Work sequence を実行する。
2. **READ NEXT** [`.dev/lessons/2026-05-20-refactor-tradeoffs-honest-accounting.md`](lessons/2026-05-20-refactor-tradeoffs-honest-accounting.md) — 経緯記録。
3. `git log --oneline -10` — last code commit: `4090d7da`
   (close-plan §6 (j) Step B cohort 5: effectiveMemory0Max で
   imported memory grow cap)。
4. **Live status**: `zig build test-spec-wasm-2.0-assert >
   /tmp/spec.log 2>&1 || true; grep "^FAIL " /tmp/spec.log |
   sort | uniq -c | sort -rn` — current breakdown is the
   source of truth.
5. `.dev/debt.md::D-154` — close-plan umbrella row。

## Active state

- Phase 9.12-E。close-plan §6 (j) Step B 進行中。
- §6 (j) Step A 完了 (`f5b3f626`): spectest.wat auto-register。
- §6 (j) Step B cohort 1+2 部分着 (`2ddcdd7c`): const-expr
  `global.get N` for imported globals + importer-side
  `scratch_globals` の `[0..num_imports)` を registered
  exporter から populate。
- §6 (j) Step B cohort 3-5 完 (`45bc96d3` / `ce67cd4a` /
  `72a87509` / `4090d7da`)。
- 次: 残 1 件 — **cohort 6** (elem.68 `call_imported_elem`
  trap)。`(elem (i32.const 0) funcref (global.get 0))` を decoder
  が null sentinel で受理し、call_indirect 0 が trap する。
  作業内容:
  1. `readFuncrefInitExpr` の 0x23 arm を改修。null sentinel
     ではなく `0x80000000 | N` を funcidxs に格納。
  2. `applyTableInitForTableCtx` / `populateTableRefs` で
     marker を検出、`ctx.buf[ctx.offsets[N]]` (= 8-byte
     FuncEntity ptr) を deref して funcptr+typeidx を抽出。
  3. `RegisteredExporter.ensureCompiledAndRt` で scratch_func_
     entities allocate 後に `runner_mod.resolveFuncrefGlobals`
     を呼び exporter の scratch_globals 内 funcref globals を
     FuncEntity ptr に resolve。
  4. `applyImportedGlobalsFromRegistered` は既に bytes copy
     するので、importer の scratch_globals[offset] に
     resolve 済み FuncEntity ptr が入る。

## Step B 再開時の手順 (cold-start)

```sh
# 1. ログ再生
zig build test-spec-wasm-2.0-assert > /tmp/spec.log 2>&1
grep "^FAIL " /tmp/spec.log | sort | uniq -c | sort -rn

# 2. cohort 3 候補の fixture を bisect
#    InvalidFuncIndex: imports.60/61, elem.57, linking.17, table_grow.6
#    InvalidFunctype: elem.66/68
ls test/spec/wasm-2.0-assert/imports/imports.6{0,1}.wat
```

仮説 (verified at 2026-05-21):
- elem.57 / elem.66 / elem.68 などは declarative elem
  segment で typeidx が type section 範囲外、または
  declarative funcidx の resolve タイミング差。compile 時の
  validator がリジェクトすべきところで何かが抜けている。

cohort 詳細は `.dev/phase9_structural_debt_close_plan.md`
§6 (j) Step B 参照。

## Open questions / blockers

- なし。autonomous loop resumed。

## §9.12-B progress chunks

`.dev/phase_log/p9_12_B_chunks.md` (B1〜B158) に移管。
handover はポインタのみ保持。

## See

- [ROADMAP](./ROADMAP.md) §9.12 — phase row
- [`debt.md`](./debt.md) — D-154 umbrella, D-153 paused
- [`lessons/INDEX.md`](./lessons/INDEX.md) — 2026-05-20 entry
