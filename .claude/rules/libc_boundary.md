---
description: "libc 依存境界 — `std.c.*` 呼び出しは ADR-0070 の 3 区分 (necessary/replaceable/convenience) に該当しないと禁止。新規 `std.c.*` 追加は ADR justification 必須。"
paths:
  - "src/**/*.zig"
---

# libc dependency boundary

> **状態**: skeleton (2026-05-19)。ADR-0070 (Proposed) で justify。§9.12-D で完成。

## The rule

Zig source で `std.c.*` 呼び出しを新規追加するときは、ADR-0070 の 3 区分の
いずれかに該当しなければならない:

| 区分 | 例 | 取扱 |
|---|---|---|
| necessary | `sigsetjmp` / `siglongjmp` / `pthread_jit_write_protect_np` | OK; Zig stdlib 追加待ち issue link 推奨 |
| replaceable | `std.c.write` / `_exit` / `getenv` / `munmap` | NG — `std.posix.*` / `process.Environ` 使用 |
| convenience | `std.heap.DebugAllocator` (Debug only) | Debug build のみ OK |

新規 site が必要なら、ADR-0070 への amend (新 site を necessary 区分に追加) 必須。

## Before writing `std.c.<name>`, check first

- `std.posix.<name>` — POSIX 抽象が存在するか
- `std.Io.<name>` — Zig 0.16 の Io abstraction
- `process.Environ` — env var 取得
- 該当する `std.os.linux.*` / `std.os.darwin.*` syscall wrapper

## Enforcement

- `scripts/check_libc_boundary.sh` (§9.12-D で実装): grep ベース新規 std.c.*
  site 検出 + ADR-0070 必須区分 cross-check
- `audit_scaffolding §G.5` 拡張
- ROADMAP §14 forbidden list "Unconscious libc fanout" (§9.12-D で追加)

## Grep-able anti-patterns

```sh
grep -nE 'std\.c\.(write|_exit|getenv|munmap)\b' src/ test/
```

## Related

- ADR-0070 (libc dependency policy; 3 区分の根拠)
- ADR-0067 (ubuntunote pivot; D-134 Rosetta — libc 信頼性問題の発端)
- ADR-0071 §Q6 (Phase 9 完備 libc boundary resolution)
- マスター計画書 §3.6 / §5.3 §9.12-D
