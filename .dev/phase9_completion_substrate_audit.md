# Phase 9 完備 substrate re-examination gate

> **Hard human-in-loop gate** before §9.12 flips and Phase 10
> prep work begins. The autonomous `/continue` loop **must stop**
> when it reaches this row and surface to the user; no
> `ScheduleWakeup` fires until the audit deliverables below are
> collaboratively cleared.
>
> Anchored from ROADMAP §9.9 row 9.12 (`🔒` + this doc) and
> `.claude/skills/continue/SKILL.md` §"Exception — hard
> human-in-loop transition gates" generic carve-out (Detection
> rule fires on `🔒` + `phase*_*.md` reference).
>
> Filed per **ADR-0062** (2026-05-16). Existing Phase 10 entry
> gate (Track D prep, was 9.12) is renumbered to 9.13 — this
> audit precedes it.

## Why this gate exists

Phase 9 closes with **Wasm 2.0 100% PASS** on Mac aarch64 +
OrbStack x86_64 + windowsmini, achieved by direct editing of
exhaustive `switch (ZirOp)` blocks across `src/ir/lower.zig`
/ `src/validate/validator.zig` / `src/engine/codegen/arm64/
emit.zig` / `src/engine/codegen/x86_64/emit.zig`, plus point
fixes in the spec_assert harness. This trajectory ships PASS
count but **diverges from ROADMAP §4.5 / §4.6** which prescribe
per-op handler modules registered into a central
`DispatchTable`, with build-time `-Dwasm=` / `-Denable=` flags
selecting which modules compile in.

The concrete drift is in ADR-0062 §"Context" — five enumerated
facts about `WasmLevel`'s dead use, `DispatchTable`'s null
init, `feature/*/register.zig` no-op stubs,
`instruction/wasm_X_Y/*/<cat>.zig` dead writes, and switch-arm
direct edits as the actual binding mechanism.

This gate forces a stop **before** Phase 10 starts adding Wasm
3.0 features (GC, EH, tail-call, memory64), so the substrate
on which they land is the correct one — not the inherited
500-arm-switch shape.

## Project value axes (user-stated 2026-05-16)

The audit must keep all five axes in mind and choose
architecture that maximises them jointly:

| Axis              | Translation                                              |
|-------------------|----------------------------------------------------------|
| 構造的にきれい    | Source organisation by op / by feature is navigable      |
| 高速              | Hot paths (interp inner loop; per-op JIT emit dispatch) free of avoidable indirection |
| 小さい            | `-Dwasm=1.0` build excludes 2.0/3.0 code (binary + comptime) |
| 教科書的          | A reader can pick up one file and understand one op family |
| 実用的            | Hot ABI invariants (ZirOp slot count, dispatch shape) survive future Wasm proposal merges without further substrate redesign |

**Anti-axis**: "ship now" cost. Per user directive: cost is
not a constraint.

## Open questions (resolve via this gate)

These four questions surfaced in the 2026-05-16 design
discussion. Each must have a decided answer before the gate
closes:

### Q1 — Trigger mechanism (resolved)

- **Resolved by ADR-0062**: this gate is row 9.12 (new),
  separate from Phase 10 entry gate (now 9.13). Track D
  prep and substrate audit are not merged.
- **No further action**.

### Q2 — Re-examination scope

- Sub-questions:
  - Does the audit reopen ROADMAP §2 P13 ("Day-one ZIR sized
    for full target") — i.e. should the `ZirOp` enum itself be
    feature-conditioned at comptime?
  - Does the audit reopen P14 ("Pervasive build-time
    if-branching") — i.e. is the wording too broad? Does
    `if (comptime build_options.feature_X)` count as
    forbidden? (Suggested in 2026-05-16 thread: P14 sharpens
    to "no runtime if-branching on feature flags; comptime is
    fine".)
  - Does the audit reopen §4.5 (dispatch-table architecture)
    — is the function-pointer table the right abstraction at
    all?
- **Required deliverable**: explicit decisions (Accept /
  Amend / Reject) for §2 P13, §2 P14, §4.5, §4.6, recorded in
  this doc's "Decisions" section below.

### Q3 — Architecture spike (the core technical question)

Three hypotheses (from 2026-05-16 thread):

- **A (Complete §4.5 as written)**: Function-pointer
  `DispatchTable` × 4-5 axes per ZirOp, populated at startup
  by `registerAll(*DispatchTable)` from enabled feature
  modules.
- **B (Comptime-gated switch)**: Keep current exhaustive
  `switch (ZirOp)` arms; wrap each Wasm-2.0+ / feature-X arm
  in `if (comptime build_options.feature_X) { ... } else {
  return Error.UnsupportedOpForBuildLevel; }`. Dead-code
  eliminated at -Dwasm=1.0 build.
- **C (Hybrid: per-op file + comptime-generated inline-switch)**:
  Each op lives in `src/instruction/wasm_X_Y/<op>.zig`
  exporting `pub const handlers = .{ .feature = ..., .validate
  = fn, .lower = fn, .arm64 = fn, .x86_64 = fn, .interp = fn };`.
  At comptime, a `dispatch_emit_arm64` builder uses
  `inline for (collectEnabledOpHandlers()) |h| { if (op == h.op)
  return h.arm64(...); }` — switch performance, per-op-file
  source organisation.

- **Required deliverable**: a `private/spikes/substrate_dispatch/`
  directory with N spikes (one per hypothesis), each measuring:
  - Emitted machine code shape (JIT compile pass) — verify
    inline-switch is comparable to direct switch, and
    function-pointer indirect call is N cycles slower.
  - Zig comptime compile cost (especially for hypothesis C
    with `inline for` over hundreds of ops).
  - Source organisation outcome (1 module touched per op vs
    N modules touched).
  - Build size with `-Dwasm=1.0` (does the disabled feature
    actually drop out of the binary?).
- An ADR (0063 or similar) **Accepted** with the chosen
  hypothesis + measurement evidence + rejection reasons for
  the others.

### Q4 — Boundary of audit vs. implementation

- The audit gate's deliverable is **decision + ADRs**, not
  implementation. Implementation lands in Phase 10 sub-rows.
- But: minimal proof-of-concept may be wanted. The audit may
  ship a single representative op converted to the chosen
  architecture (e.g. `i32.add`) as a working reference.
- **Required deliverable**: explicit scope statement in this
  doc's "Outcome" section.

### Q5 — Substrate hygiene: invariants encoded as code, not prose

Accumulated **investigation triggers** surfaced during Phase 9
that point at the same class of substrate weakness — invariants
asserted in comments / docstrings without code-level
enforcement, drifting silently as the codebase grows. The audit
should walk these and decide on a unified enforcement strategy
(comptime assertions / lint scripts / audit_scaffolding §G
extensions / typed pool abstractions). Each entry below names
the originating chunk and the lesson record.

- **D-132 / regalloc-pool-scratch-overlap** (2026-05-16,
  [`lessons/2026-05-16-regalloc-pool-scratch-overlap.md`](lessons/2026-05-16-regalloc-pool-scratch-overlap.md)):
  `op_table.zig` hardcoded X10/X11/X12 as scratch while those
  slots were in `abi.allocatable_caller_saved_scratch_gprs`.
  Latent since regalloc landed; surfaced only when corpus
  pressure + nested table-op pattern aligned at d-63/d-64.
  Lesson's 4-angle retrospective (no-workaround / debug
  ergonomics / future-proofing / design issues) names the
  remediation surface. Investigation tasks the audit should
  enumerate:
  - Extend `abi.zig`'s existing comptime disjointness check
    (`spill_stage_gprs` ∩ `allocatable_gprs == ∅`) to ALL
    op-internal hardcoded scratch via named-constant arrays
    (`table_emit_scratch_gprs`, `memory_emit_scratch_gprs`,
    …). Magic-numeral register references in emit code become
    a comptime / lint violation.
  - Add `audit_scaffolding` §G grep for `encLdrImm\([0-9]+,
    abi\.runtime_ptr_save_gpr` (and analogous x86_64 sites)
    that flags ANY hardcoded register numeral as drift-prone.
  - Decide whether `bug_fix_survey.md` ([`.claude/rules/`](../.claude/rules/bug_fix_survey.md))
    discipline should be enforced via a self-review checklist
    in `/continue` Step 4 (the d-64 retrospective recorded a
    self-observed lapse — TableGet/TableSet fixed, but the
    same-shape sites at TableFill/Grow/Copy/Init +
    op_memory's emitMemoryInit/DataDrop were not swept).
  - Codify a "comment-as-invariant" anti-pattern rule
    (`.claude/rules/` or extension of `no_workaround.md`):
    prose invariants in docstrings must either be (a) paired
    with comptime / runtime enforcement, or (b) deleted.
    `op_table.zig`'s "X10/X11/X12 are private scratch within
    the handler" comment was authoritative-looking but false.
  - Reconsider test-design "stress axes" — register
    pressure, call-crossing, nested ops — as explicit corpus
    requirements rather than incidental side-effects of
    natural fixture growth. Coverage-growth masking is what
    let D-132 live latent for so long.

- *(Append future trigger entries here. The audit walks all
  entries under Q5 at gate-fire time and produces one or more
  ADRs / rule files / debt rows per resolved item.)*

### Q6 — libc dependency boundary (Pre-Phase-10 hygiene)

Surfaced 2026-05-16 during the d-65 D-134 investigation
(SIGSEGV recovery via `sigsetjmp`/`siglongjmp` is libc-only),
combined with a wider audit of `std.c.*` call sites across
the codebase. Zig 0.16's stdlib direction (`std.Io` /
`std.posix` / `std.Threaded`) explicitly aims at
**buildable-without-libc**; zwasm v2 is currently moving in
the opposite direction with `flake.nix` / `build.zig`
hard-requiring `-lc` and the signal-handling core fanned out
through libc. Phase 10 + (AOT mode, embedded distribution,
Windows-native compatibility) make the cost of unwinding
libc fanout much higher post-Phase 10 than now.

**Current libc dependency surface** (concrete inventory):

1. **Signal recovery core** — `sigsetjmp` / `siglongjmp` via
   `@extern(.{ .library_name = "c" })` in
   `test/spec/spec_assert_runner_base.zig` (D-103 → d-29 →
   d-62 → d-65 lineage). Zig stdlib has no equivalent.
   **Class: necessary** until Zig adds stdlib `sigsetjmp`.
2. **`std.c.munmap` / `std.c.write` / `std.c._exit` /
   `std.c.getenv` / `gettid()`** — JIT block release,
   async-signal-safe handler writes, diagnostic output,
   `hostImportTrapStub` etc. Broadly used.
   **Class: mechanically replaceable** with `std.posix.write`
   / `std.posix.exit` / `std.posix.munmap` / `process.Environ`
   / `linux.gettid` syscall wrapper. Estimated <100 sites.
3. **`pthread_jit_write_protect_np` / `sys_icache_invalidate`**
   — Mac aarch64 W^X toggle in `src/platform/jit_mem.zig`.
   Darwin libc-specific API.
   **Class: necessary** on Darwin; no kernel-direct
   equivalent.
4. **Build configuration** — `zig build-exe ... -lc ...`
   threaded across the entire test runner family
   (verified via `zig build test-spec-wasm-2.0-assert
   --verbose`). Loss of `-lc` would require resolving every
   `@extern("c")` symbol first.
   **Class: structural** — flips only after the per-symbol
   work above lands.
5. **`std.heap.DebugAllocator` (= `init.gpa` under Debug)**
   — start.zig's `use_debug_allocator` selection requires
   libc on Linux. Without libc, falls back to
   `std.heap.smp_allocator` (no leak detection).
   **Class: convenience** — losing leak detection is a real
   regression for development; OK to keep libc-dependent
   under Debug.

**Why this question matters before Phase 10**:

- Phase 10's GC / EH / Tail call / memory64 features need
  cross-platform signal handling stories. Trying to unwind
  libc-coupled signal recovery while simultaneously adding
  new ZirOps and runtime entries multiplies risk.
- AOT mode (Phase 12) wants minimal-dependency output
  binaries. Every `std.c.*` call in shared code becomes an
  AOT-target requirement.
- Windows-native compatibility (Phase 13+) — `sigsetjmp` /
  `pthread_jit_write_protect_np` are POSIX/Darwin-specific;
  the abstraction boundary must be ready before Phase 13.

**Required audit deliverables for Q6**:

1. An **ADR** (likely `00NN_libc_dependency_policy.md`)
   spelling out:
   - The **necessary** set (signal recovery primitives,
     Darwin W^X toggles) with rationale + Zig issue links
     for "if upstream stdlib adds X, migrate".
   - The **replaceable** set with a migration plan (one
     debt row per migration cluster, or a single sweep
     chunk in Phase 10 prep).
   - The **convenience** set (DebugAllocator) — explicitly
     allowed under specific build modes.
   - A clear rule: **new `std.c.*` call sites are rejected
     by default** unless they fall into the necessary set
     OR an ADR amendment expands the boundary.
2. **`.claude/rules/libc_boundary.md`** project rule that
   auto-loads when editing Zig source. Codifies:
   - Before writing `std.c.<name>`, check
     `std.posix.<name>` / `std.Io.<name>` /
     `process.Environ` first.
   - Cite the ADR.
   - Reviewer checklist for grep-able anti-patterns:
     `grep -nE 'std\.c\.(write|_exit|getenv|munmap)\b' src/ test/`.
3. **ROADMAP §14 amendment** — add one line:
   "Unconscious libc fanout (new `std.c.*` calls without
   ADR justification or rule exception)" to the forbidden
   list, with cite to the new ADR.
4. **`audit_scaffolding` §I extension** (or new §J) — the
   grep above runs as a recurring check, surfacing new
   `std.c.*` sites in diffs against `main`.
5. **One initial mechanical-replacement chunk** (Phase 10
   prep, NOT Phase 9 — the boundary work itself is Phase
   10+ scope): convert the easy `std.c.write` /
   `std.c._exit` / `std.c.getenv` / `std.c.munmap` sites
   to `std.posix.*` equivalents. This is the "proof the
   rule has teeth" deliverable.

The audit MUST NOT close Q6 with "deferred" — each of the
five items above lands as a concrete artifact (ADR / rule
file / ROADMAP edit / audit script / migration chunk).
Items can be batched into one PR if scope allows.

## Deliverables required to close the gate

1. **ADR-0063** (or sequential) recording the chosen
   architecture (Q3). Accepted status.
2. **ADRs amending or affirming**: §2 P13, §2 P14, §4.5,
   §4.6 (Q2). Each gets explicit Accept / Amend / Reject.
   May be one combined ADR or multiple — at audit author's
   discretion.
3. **Optional `private/spikes/substrate_dispatch/`** with
   spike experiments and measurements supporting Q3's
   choice.
4. **Phase 10 plan amendment** (if substrate redesign
   requires it). The existing `.dev/phase10_transition_gate.md`
   may need its first-row scope adjusted to "substrate
   refactor lands before Wasm 3.0 feature work" — or split
   into a new Phase 9.5 implementation phase.
5. **This doc's "Decisions" section** filled in with
   the four Q resolutions plus Q5's + Q6's enumerated
   trigger / artifact resolutions.
6. **Audit summary** at the top of this doc — a 5-10 line
   abstract for future readers.
7. **Q5 outputs**: per trigger entry under Q5, one of
   {comptime assertion landed in code, `.claude/rules/` file
   created, `audit_scaffolding` §G amended, debt row filed
   with named structural barrier, ADR amending a §2
   principle}. Q5 should NOT close with "deferred" — each
   entry needs a concrete artifact.
8. **Q6 outputs**: ADR (`00NN_libc_dependency_policy.md`),
   `.claude/rules/libc_boundary.md`, ROADMAP §14 amendment
   line, `audit_scaffolding` grep extension, and one
   mechanical-replacement chunk landing in Phase 10 prep.
   Q6 MUST NOT close with "deferred".

## Decisions (fill at gate close)

> Filled by the user-led review session. Each Q gets an
> explicit answer + cross-reference to the relevant ADR.

### Q2 — Scope decisions

- **P13** (ZirOp enum sized for full target):
  - [ ] Accept as-is
  - [ ] Amend (text below)
  - [ ] Reject (text below)
  - ADR ref:
- **P14** (no pervasive build-time if-branching):
  - [ ] Accept as-is
  - [ ] Amend (text below)
  - [ ] Reject (text below)
  - ADR ref:
- **§4.5** (dispatch-table feature modules):
  - [ ] Accept as-is
  - [ ] Amend (text below)
  - [ ] Reject (text below)
  - ADR ref:
- **§4.6** (build flags `-Dwasm=` / `-Denable=`):
  - [ ] Accept as-is
  - [ ] Amend (text below)
  - [ ] Reject (text below)
  - ADR ref:

### Q3 — Architecture decision

- [ ] Hypothesis A — DispatchTable function-pointer
- [ ] Hypothesis B — Comptime-gated switch
- [ ] Hypothesis C — Hybrid (per-op file + inline-switch)
- [ ] Hypothesis D — Other (specify)
- ADR ref:
- Spike evidence path(s):

### Q4 — Audit boundary

- [ ] Decision-only (implementation in Phase 10)
- [ ] Decision + minimal POC (one op)
- [ ] Decision + full skeleton (all ops, no behaviour change)
- ADR ref:

### Q5 — Substrate hygiene triggers (one row per accumulated trigger)

> Each Q5 trigger entry above (under "Open questions") gets a
> resolution row here at audit close. Add rows as triggers
> accrue during the rest of Phase 9.

- **D-132 / regalloc-pool-scratch-overlap**
  - [ ] Comptime disjointness extended to op-internal scratch
  - [ ] `audit_scaffolding` §G magic-numeral lint added
  - [ ] `bug_fix_survey.md` enforcement in `/continue` Step 4
  - [ ] "Comment-as-invariant" rule filed
  - [ ] Test-design stress-axis requirement codified
  - ADR / rule / debt refs:

### Q6 — libc dependency boundary decisions

- [ ] ADR `00NN_libc_dependency_policy.md` authored
      (necessary / replaceable / convenience classification)
- [ ] `.claude/rules/libc_boundary.md` filed
- [ ] ROADMAP §14 amendment line added (with ADR cite)
- [ ] `audit_scaffolding` grep extension landed
- [ ] Mechanical-replacement chunk scheduled in Phase 10 prep
- ADR / rule / debt refs:

## Outcome (audit summary — fill at close)

> 5-10 line abstract for future readers.

## Reference

- **ADR-0062** — this gate's authoring decision.
- **ADR-0023** — Zone layering + §4.5 origin.
- **ADR-0041** — SIMD-128 design framing (precedent for
  shape-as-variant ZirOp / feature-register pattern that the
  audit will re-examine).
- 2026-05-16 chat discussion thread.
- ROADMAP §2 P13, P14; §4.5, §4.6; §14 forbidden list;
  §18 amendment policy.
