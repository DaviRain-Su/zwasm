---
description: "Cat III runtime/instance/store/linker layer の zone-rule + hygiene anchor。`src/runtime/instance/` + `src/api/instance.zig` への編集時に invariant comment / silent fallback / cross-zone import を防ぐ。"
paths:
  - "src/runtime/instance/**/*.zig"
  - "src/runtime/store.zig"
  - "src/runtime/runtime.zig"
  - "src/api/instance.zig"
  - "src/api/cross_module.zig"
---

# Runtime / instance / store / linker layer hygiene

> **状態**: skeleton (2026-05-19)。ADR-0071 §Q5 (Cat III hygiene anchor) で
> justify。§9.12-C で完成。

## The rule

Phase 9 §9.9-III で Cat III code (Wasm 1.0 instance / store / linker / cross-
module / host-imports / start-trap) が land した。この layer は以下の規律を
守る:

### Zone direction

- `src/runtime/instance/*.zig` は **Zone 2 = runtime**
- import 方向: `runtime/instance/` → `runtime/`, `ir/`, `parse/`, `support/`, `support/platform/` (= Zone 0-2 のみ)
- 禁止: `runtime/instance/` → `engine/codegen/*` (Zone 3); `cli/*` (= UI Zone)
- 詳細: `.claude/rules/zone_deps.md`

### Invariant comments

`.claude/rules/comment_as_invariant.md` が適用される。"X は always Y" 系の
prose-only comment は禁止 (comptime/runtime assert で強制 OR 削除)。

### Silent fallback

`.claude/rules/no_fallback_on_failure.md` が適用される。`catch \|err\| return
null` 等で linker error を握り潰さない。`Error.UnknownImport` /
`Error.ImportTypeMismatch` 等は named error として propagate。

### Cross-module 状態管理

- `Store.register(name, *Instance)` で session-local registry に登録
- `Instance.findExport(name, kind, sig)` で type-check 経由 lookup
- `resolveCrossModuleImports()` で bridge thunk 経由 dispatch
- これらの function に対する extension は ADR で justify (D-079 / D-102 / D-103
  / D-105 cohort discharge は §9.12-E で)

## Why

Cat III code は §9.9-III の急ぎ実装が含まれており、Phase 9 完備 substrate audit
Q5 hygiene anchor の対象。本 rule で hygiene 規律を auto-load して、新規
編集が同じ failure mode (Pointer 0xAA poisoning / X19 corruption / etc.) を
再現しないよう牽制する。

## Enforcement

- 本 rule auto-load on the listed paths
- `audit_scaffolding §G` の D-132 / D-133 grep 拡張が runtime/instance/ にも適用
- `bash scripts/zone_check.sh --gate` が zone violation 検出 (§9.12-G で
  enforce mode 移行)

## Related

- ADR-0066 (cross-module import bridge thunks)
- ADR-0068 (dual-view table storage fix)
- ADR-0071 §Q5 (Phase 9 完備 hygiene resolution)
- D-079 / D-102 / D-103 / D-105 (Cat III tail debt; §9.12-E で discharge)
- `.dev/lessons/2026-05-17-d134-rosetta-2-signal-translation-limit.md`
- `.dev/lessons/2026-05-17-gamma3d-dispatch-write-segv-bisect.md`
