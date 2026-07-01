# Regalloc pool overlap with hardcoded emit scratch (D-132)

Citing: §9.9 / 9.9-l-1b-d093-d64 (mid-investigation pause at
commit `2c961b49`; partial fix in `git stash`).

## Observation

`src/engine/codegen/arm64/op_table.zig` hardcoded X10/X11/X12
as scratch (`LDR X10, [X19, #tables_ptr_off]` etc.) while those
same registers were members of
`abi.allocatable_caller_saved_scratch_gprs`. When a vreg's
live range crossed a table.get / table.set and regalloc landed
the vreg on one of those slots, the emit's LDR silently
clobbered the vreg's value. Latent since the regalloc landed;
surfaced at d-63 when reftype-alias-to-i64 enabled
`table_get:is_null-funcref(2)` (the corpus finally exercised
the trigger: two nested table ops + enough register pressure).

## Angles

### no-workaround

The d-63 close had to file D-132 + targeted-skip the failing
manifest line to keep the gate green. That target-skip is a
classic surface-level workaround — it hides the real bug,
which is structural (an unchecked invariant in `abi.zig`).
Per [`no_workaround.md`](../../.claude/rules/no_workaround.md)
this is acceptable ONLY paired with a debt row (D-132) naming
the structural barrier, with discharge in the next chunk
(d-64). Surface skips that outlive their named-barrier-fix
chunk would violate the rule.

### こうすればもっとデバッグが楽だった

- The d-64 root-cause walk took several iterations of "is it
  bounds check? regalloc spill? bit-elision?" because the
  symptom was `trap` (= bounds-check fired) when the actual
  cause was operand corruption. A
  `private/dbg/d132/repro.zig` spike dumping JIT bytes was
  what finally surfaced "MOVZ X10, #2; ... LDR X10, [X19,
  tables_ptr_off]" — i.e. the visible clobber. **The JIT-byte
  dump should be a first-class helper** (`scripts/jit_dump.sh
  <wat>` or `zig build dump-jit -Dfixture=<path>`), not a
  one-off spike.
- A **minimal `funcref_roundtrip.wat` edge fixture** bisecting
  ("one table.set works; two with nested get fails") was the
  decisive evidence. Edge fixtures are cheap; should be the
  default first move on any new spec FAIL.

### 今後のために

- **Compile-time disjointness assertion** in `abi.zig`: extend
  the existing `spill_stage_gprs` ∩ `allocatable_gprs == ∅`
  check to also cover op-internal hardcoded scratch
  (`table_emit_scratch_gprs`, `memory_emit_scratch_gprs`, …)
  via named-constant arrays. Magic numbers `10`/`11`/`12` in
  emit code become a lint violation.
- **Bug-fix grep discipline** ([`bug_fix_survey.md`](../../.claude/rules/bug_fix_survey.md))
  was not applied at d-64 mid-cycle: I fixed TableGet/TableSet
  only, left TableFill/Grow/Copy/Init + op_memory's
  emitMemoryInit/DataDrop with the same latent shape. Self-
  observed anti-pattern.

### 見えた設計課題

1. **Comment-as-invariant**: `op_table.zig`'s docstring
   "X10/X11/X12 are private scratch within this handler" was
   authoritative-looking but wrong. Invariants asserted in
   prose are silently false when no enforcement exists. The
   project pattern should be **delete the prose claim OR
   pair it with code-level enforcement**.
2. **Two-source-of-truth drift**: register usage was
   described in `op_table.zig` (comments + literals) AND
   `abi.zig` (`allocatable_gprs`). No coherence check linked
   them.
3. **W54 pattern recurrence**: the v1
   [`w54-redesign-postmortem.md`](~/Documents/MyProducts/zwasm/.dev/archive/w54-redesign-postmortem.md)
   describes the same shape — modules with implicit
   assumptions about shared resources, drift undetected for
   long. v2's redesign explicitly motivated by W54
   avoidance; recurrence at smaller scale = the avoidance
   mechanism (audit cadence, encoded-invariant discipline)
   isn't strong enough.
4. **Coverage-growth masking**: bug existed since regalloc
   landed but never triggered because corpus didn't generate
   the required register-pressure-plus-table-op pattern.
   Test design needs explicit "stress axes" (register
   pressure, call-crossing, nested ops) rather than relying
   on natural corpus distribution.

## Cited from

- `.dev/debt.md` D-132 (Status: now; d-64 paused)
- `.dev/archive/phase9/phase9_completion_substrate_audit.md` (Phase 10 prep
  audit gate — investigation trigger added)
