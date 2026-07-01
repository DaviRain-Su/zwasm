# x86_64 `usesRuntimePtr` manual list — drift hides R15-dependent ops

**Date**: 2026-05-28
**Tags**: x86_64, JIT, prologue, R15, usesRuntimePtr, EH, IT-6, Mac-only-gate, skip-discipline, drift detection
**Discovered at**: D-180 investigation (HEAD `2808bc81`).
**Citing**: fix commit `2808bc81`; gates that hid it `c9b9d16c` (cycle 3c-iii-d), `81e1bd9a` (tag_idx marshal).

## What happened

`runI32Export: throw + catch_all returns 42` was Mac-aarch64-only
gated. When ungated on Linux x86_64 SysV it returned 0 (not 42, not
99, no Trap). The IT-6 BUNDLE CLOSED claim's "fully wired on both
arches" was wrong — only Mac was fully wired.

Root cause: the x86_64 prologue ONLY emits `PUSH R15 / MOV R15,
<entry_arg0>` when `usage.usesRuntimePtr(func)` returns true. The
opcode list that gates this was a **manual enum** of ops whose emit
touches R15: memory accesses, table ops, division traps, trunc
traps. The Phase 10 EH ops (`.throw`, `.throw_ref`, `.try_table`)
were missing.

For an EH-only function (`(block (try_table (catch_all $b) (throw
$e)))`), `usesRuntimePtr` returned false, the prologue skipped R15
setup, and the throw site's trampoline call read R15's startup
value — typically Linux loader base `0x7ffff7ffd000`. From that
garbage "rt", `eh_table_entries` deref-ed unrelated memory, found
no match, returned `.uncaught`, wrote `trap_flag = 1` into garbage,
RETed to the trap stub which also corrupted memory, and the function
eventually returned 0.

## Why it was hard to find

- **Mac aarch64 is structurally immune**: prologue UNCONDITIONALLY
  saves + sets X19 (pinned rt) per ADR-0017. The R15 setup
  conditional is x86_64-only.
- **The Mac-aarch64-only test gate hid it**: the EH e2e fixtures
  reported "Mac green, both arches green" via gates that didn't
  actually run on Linux.
- **The `usesRuntimePtr` manual list is a drift surface**: every new
  R15-dependent op must remember to add itself to the list, and there
  is no compile-time / link-time check that enforces it.

## Diagnostic that pinpointed it

Inside `trampolineCore`, add `std.debug.print` of `rt`-pointer
incoming value. On Linux x86_64 for an EH-only function, `rt`
showed `0x7ffff7ffd000` — recognisably Linux loader base, not a
JitRuntime stack allocation. Cross-referenced with the unit-test
direct-call probe (which uses synthetic rt) → only the JIT-emitted
op_throw path showed the garbage; the unit test was fine. That
narrowed the bug to "prologue or runtime-ptr setup", which led to
`usage.zig`.

## Generalisable rule (structural)

Any x86_64 op whose emit:
1. Reads or writes `[R15 + off]` in its emitted bytes, OR
2. Invokes a runtime callback (trampoline, host dispatch, memory
   grow) that itself reads R15, OR
3. Generates a trap-stub fixup (the trap stub writes
   `trap_flag` / `trap_kind` via R15),

MUST be in `src/engine/codegen/x86_64/usage.zig::usesRuntimePtr`'s
`=> return true` list. The list IS the truth; the prologue gates
on it. Drift = silent miscompile on Linux x86_64 (Mac aarch64
masks it).

## Defenses going forward

- `scripts/check_uses_runtime_ptr.sh` — heuristic scan of
  `src/engine/codegen/x86_64/ops/**/*.zig` for R15 references +
  trampoline-call patterns, cross-reference with the
  `usesRuntimePtr` enum list. Surfaces "potential gap" for review.
- `usage.zig`'s opcode list carries a comment-as-invariant
  ("INVARIANT: any op whose emit produces R15-dependent bytes...
  see lesson 2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md").
- `test_discipline.md` §4 (added in this same commit) — Mac-aarch64-
  only test gates without paired debt OR rationale citing the
  arch-specific impl gap are an audit smell.

## Related

- ADR-0017 (pinned rt regs: X19 / R15)
- ADR-0026 (Cc-pivot — x86_64 R15 save site)
- D-180 (debt entry for this bug — closed at `2808bc81`)
- `src/engine/codegen/x86_64/prologue.zig` (the conditional R15
  setup that gates on `usesRuntimePtr`)
- `.dev/lessons/2026-05-28-eh-test-wrapper-host-fp-walk-segv.md` —
  sibling lesson about EH test hygiene (sentinel-frame discipline)
