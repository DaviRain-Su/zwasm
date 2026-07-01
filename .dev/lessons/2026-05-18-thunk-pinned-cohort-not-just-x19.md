# Bridge thunk save-restore must cover the FULL pinned-callee-saved cohort, not just X19

> Keywords: bridge-thunk, cross-module, X19, X24-X28, ABI,
> callee-saved, pinning, call_indirect, sig-mismatch.

Citing: 2026-05-18 ADR-0066 §A2 amendment commit (γ.4 cycle 4 —
D-144 root cause).

## Context

ADR-0066 §A1 (D-142 fix, 2026-05-17) grew the arm64 bridge
thunk from a 32-byte tail-jump to a 56-byte
save-call-restore frame to preserve **X19** across
cross-module returns. The fix was correct for X19 but
**stopped at X19**.

D-144 (γ-4 relax probe, 2026-05-18) surfaced
`imports.1.wasm print64 i64:24 -> Trap` with
`kind=3` (call_indirect sig). Root cause: arm64 prologue
also overwrites X24/X25/X26/X27/X28 (the typeidx_base /
table_size / funcptr_base / mem_limit / vm_base reserved-
invariant cohort) WITHOUT first stack-saving the caller's
value. Same shape as the X19 violation §A1 fixed.

After cross-module return, the caller's call_indirect
read `typeidx_base[1]` via X24 — but X24 still held the
**callee's** typeidx_base. The mismatch surfaced as sig
trap kind=3, not crash.

## Why X19 was fixed alone in §A1

The D-142 SEGV's manifest fault address (X19-corrupted →
deref garbage) was the *first* sibling to surface because
X19 deref is the most direct (every JIT op reads from
`[X19 + offset]`). X24-X28 dereferences were rarer in
small fixtures so the corruption stayed silent until a
fixture (print64) chained:
- cross-module call (corrupts X24-X28)
- multiple intervening ops (most don't read X24-X28)
- call_indirect on table 0 (reads X24 explicitly)

## Lesson

The `abi_callee_saved_pinning.md` rule was written
post-D-142 with "X19 / R15" as the canonical pinning
example. The rule's "audit ALL call boundaries" wording
covered the discipline but didn't *call out the full
cohort*. Future readers internalised "X19 problem" and
missed the parallel pin set.

**The fix discipline**: when a bug-fix patches one
member of a structural cohort (here: pinned-callee-saved
regs), `bug_fix_survey.md` Step 2 mandates grep for
sibling members of the same axis BEFORE landing. The
audit grep for D-142 should have been
`grep reserved_invariant_gprs src/engine/codegen/arm64/abi.zig`
— which would have surfaced X24-X28 immediately.

## Related

- ADR-0066 §A2 amendment (bridge thunk 56 → 96 bytes).
- `.claude/rules/abi_callee_saved_pinning.md` — rule
  updated to list the full cohort.
- `.claude/rules/bug_fix_survey.md` — sibling-search
  discipline that would have prevented the §A1/§A2 split.
- D-144 closure commit.
