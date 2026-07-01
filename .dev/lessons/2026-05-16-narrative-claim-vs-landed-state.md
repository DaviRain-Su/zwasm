# Narrative claim vs landed state — verify before believing

Citing: §9.9 / 9.9-l-1b-d093-d68 `e2231c89`

## What happened

Phase 9 §9.9 / 9.9-l-1b-d093-d65's investigation chunk
(`9329c799`) deeply investigated OrbStack's
`zwasm-spec-wasm-2-0-assert` SEGV flake (D-134). The
retrospective at
`.dev/lessons/2026-05-16-zig-sigsegv-recovery-flake.md` and the
debt entry D-134 both claimed:

> "After installing our own `sigsegvHandler` and disabling
> Zig's via `std_options.enable_segfault_handler = false`, the
> handler IS confirmed installed (verified via
> `sigaction(SEGV, null, &oact)` readback) and DOES fire on
> intentional null deref (probe), but does NOT fire on the real
> SEGV..."

This was treated as ground truth for the next 3 chunks (d-65,
d-66, d-67), which assumed the Zig-handler-disable was already
in place and pursued other hypotheses (cross-thread
`siglongjmp`, then libc-context SEGV).

At d-68 resume, a routine repo-wide grep for `std_options` /
`enable_segfault_handler` found **no declaration anywhere in
the project**. The disable d-65 claimed had never landed. d-68
landed the actual disable and the OrbStack SEGV vanished
immediately — D-134 was discharged on the first probe of
hypothesis (ii).

## Why d-65's narrative was wrong

d-65 was an investigation-chunk that:

1. Wrote a 3-arg `SA.SIGINFO` probe handler in
   `spec_assert_runner_base.zig` to capture RIP/RSP on real SEGV.
2. Confirmed the probe handler did fire on intentional null
   deref but did NOT fire on the real SEGV.
3. **Reverted** the probe handler at chunk close so the
   committed diff was doc-only.

The revert step likely also reverted whatever
`std_options.enable_segfault_handler = false` declaration was
in d-65's working tree during testing. The retrospective +
debt entry both described the in-test-but-reverted state as
the committed state, conflating "what I tested while
investigating" with "what landed in git".

## The cost of the conflation

d-67 ran a wholly redundant probe (single-threaded module
flag → cross-thread refutation). The result was useful
(narrowed hypothesis space) but the chunk's wall-clock could
have been saved if d-68's probe had been tried first — and
the natural probe order would have been hypothesis (ii) first
if the debt entry hadn't claimed Zig's handler was already
disabled.

## The fix at the discipline level

**When a retrospective claims "we did X to mitigate the
symptom", the retrospective is responsible for ensuring X is
actually present in the committed state.** This means:

1. After the investigation chunk's source changes are reverted
   (often the right call for an investigation), the
   retrospective must also revert its language. "We did X" →
   "Our investigation noted X mitigates the symptom; X was not
   landed at chunk close — see follow-up". A grep verification
   right before commit-message authoring catches the gap.
2. **Step 0.5 of `/continue`** (debt sweep) already requires
   "barrier-dissolution check on every blocked-by row". This
   case shows the analogous check is needed for **claimed-fix
   rows on `now` debts**: when a `now` debt's narrative names
   a code path that "we already did X to", grep for X. If X
   isn't in `src/` / `test/`, the narrative is stale and the
   next probe should be X itself.
3. The audit `audit_scaffolding` `§F` debt-coherence check
   should look for **debt-narrative claims that grep finds no
   evidence for**. Concrete pattern: a debt entry says
   "verified via `<symbol>`" or "after installing `<symbol>`"
   → `rg -n '<symbol>' src/ test/` should find a match. No
   match = stale narrative.

## How this lesson interacts with `no_handover_predictions.md`

This case is a sibling of the no-handover-predictions rule.
That rule forbids forward-looking numeric claims in
handover/debt; this lesson teaches that **backward-looking
"we did X" claims in retrospectives need the same verification
discipline**. The mitigation in both cases is the same: a
short scripted sanity check (grep for the named code path)
before committing the narrative.

## Rule of thumb

> A retrospective is fiction until grep confirms its claims.

When writing one, run a quick `rg -n '<the-thing-we-said-we-
did>'` and append the matching line to the retrospective
proper. When reading one, do the same grep before treating
its claims as ground truth for the next investigation step.

## What to read next

- `.dev/lessons/2026-05-16-zig-sigsegv-recovery-flake.md` —
  the d-65 retrospective this lesson catches as having a
  narrative-vs-landed-state gap. A future amendment to that
  lesson should add a "post-d-68 correction" footer.
- `.claude/rules/no_handover_predictions.md` — the sibling
  rule about forward-looking claims.
- `.claude/rules/lessons_vs_adr.md` — the boundary this lesson
  rests within (observational rule, not load-bearing
  decision).
