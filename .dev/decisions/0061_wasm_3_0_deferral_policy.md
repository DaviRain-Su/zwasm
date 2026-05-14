# 0061 — Defer all Wasm 3.0 proposals to Phase 10+; keep §9.9 scope strictly Wasm 2.0

- **Status**: Accepted
- **Date**: 2026-05-14
- **Author**: Shota Kudo
- **Tags**: scope, wasm-version, sequencing, §9.9, phase9

## Context

§9.9's exit criterion (per ROADMAP §9.9 / 9.9) is **"Wasm 2.0
(incl. SIMD) 100% PASS on Mac+OrbStack"**. Per the 2026-05-14
review of `private/wasm2-completion-plan/` against the live
corpus, the §9.9 sub-cluster was leaking Wasm 3.0 surface in
two distinct places:

1. **Input path (testsuite regeneration)**.
   `scripts/regen_spec_2_0_assert.sh` invoked `wast2json` with
   four explicit Wasm 3.0 enables:
   `--enable-function-references`, `--enable-tail-call`,
   `--enable-extended-const`, `--enable-multi-memory`. The
   resulting wabt parse accepted 3.0 syntax (typed-refs,
   `return_call`, extended const-expr, multi-memory), so
   downstream NAMES enablement could have silently introduced
   3.0 fixtures into a "2_0" manifest.

2. **Test corpus drift**. The upstream `WebAssembly/spec`
   clone at `~/Documents/OSS/WebAssembly/spec` tracks `main`,
   not the `wg-2.0` tag. Spec working-group amendments have
   added 3.0 syntax to historically-2.0 wast files (e.g.
   `local_tee.wast:615` `(func $f (param (ref null $t)))` —
   the `(ref null T)` type is function-references / Wasm 3.0).
   With the four enables on, wast2json accepted such mixed
   files; without them, wast2json correctly rejects.

The verification path (lower/emit/runtime) has **no Wasm 3.0
leak**: ZIR declares 3.0 ops (`return_call`, `call_ref`, etc.)
but lower/emit are unimplemented, so any compile attempt
returns `UnsupportedOp` cleanly. Only the parse-layer surface
was leaking via wast2json flag grants.

Several open debts (D-103, D-104) referenced `D-075` as the
"reftype scope umbrella". D-075 is actually about the Zig
library facade (ADR-0025 partial implementation), unrelated
to reftype. Those barrier citations were broken aliases for a
non-existent umbrella debt; the actual barrier is the
unimplemented parse-layer + JIT branches for reftype globals
/ select-typed, which are Wasm 2.0 features.

## Decision

**§9.9 is strictly Wasm 2.0.** All Wasm 3.0 proposals
(typed-function-references, tail-call, extended-const-expr,
multi-memory, relaxed-SIMD, GC, EH, threads, memory64) are
deferred to Phase 10+. The deferral is enforced at three
checkpoints:

1. **Tool layer**. `wast2json` invocations in regen scripts
   pass **no `--enable-*` flag for 3.0 proposals**. The
   wabt-1.0.40 default-on set (`reference-types`,
   `bulk-memory-opt`, `multi-value`, `simd`,
   `saturating-float-to-int`, `sign-extension`) is the Wasm
   2.0 baseline; the script relies on the default.

2. **Corpus layer**. NAMES in `scripts/regen_spec_2_0_assert.sh`
   never contains a Wasm 3.0 corpus name (`return_call.wast`,
   `call_ref.wast`, `ref.wast`, `ref_as_non_null.wast`,
   `local_init.wast`, `br_on_null.wast`, `br_on_non_null.wast`,
   `type-canon.wast`, `type-equivalence.wast`, `type-rec.wast`,
   `memory64/`, `multi-memory/`, `gc/`, `relaxed-simd/`,
   `exceptions/`). If a historically-2.0 wast file in upstream
   has been amended with 3.0 syntax (so wast2json rejects
   without enables), the regen script logs `skip $n (wast2json
   rejected)` and moves on. **The existing per-name corpus
   directory is preserved** when regen skips — those manifests
   were produced from the file's still-valid 2.0 content, so
   the runner continues to exercise the 2.0 surface.

3. **Reference clones layer**. `.dev/reference_clones.md`
   notes the recommended pin (`wg-2.0` tag) for the spec
   testsuite clone. The actual checkout policy stays
   user-managed (we don't enforce git operations on the
   reference clone tree), but the doc records the intent so
   future regen drift is detectable. Vendoring the relevant
   wasts into the project tree (eliminating the dependency on
   upstream's branch state) is reserved for a future ADR if
   the drift becomes load-bearing.

This decision **does not** change ROADMAP §9.9's scope; it
clarifies that the scope was already Wasm 2.0 and closes the
input-path leak that contradicted the intent.

## Alternatives considered

### Alternative A — Keep the four `--enable-*` flags, vet manifests by hand

- **Sketch**: Leave the 3.0 enables in place; manually inspect
  each generated manifest for 3.0-syntax leakage; rely on
  reviewer vigilance to keep `2_0` clean.
- **Why rejected**: Vigilance is a fragile gate (Phase 6 + 7
  retrospectives already documented this class of failure).
  The regen script's name is the spec; the flags must match
  the name.

### Alternative B — Switch to `--disable-*` for 3.0 features (whitelist)

- **Sketch**: Explicitly disable each known 3.0 proposal:
  `--disable-tail-call`, `--disable-function-references`, etc.
- **Why rejected**: wabt 1.0.40's default-off is already the
  conservative state; explicit `--disable-*` is noisy and
  drifts every time wabt promotes a proposal to default-on.
  No-flag-at-all is the simplest correct invocation.

### Alternative C — Vendor `wg-2.0`-tag wast files into the project tree

- **Sketch**: Copy the post-tag wasm-2.0 wasts into
  `test/spec/wg-2.0/` and run regen against the vendored
  snapshot, severing the dependency on upstream HEAD.
- **Why rejected for this ADR**: Adds ~100 KB of vendored
  text to the repo for a problem that the no-3.0-flag fix
  already addresses. Vendoring becomes load-bearing only if
  upstream drift starts producing **2.0-side** breakage
  (e.g. a wast file modified in a way that breaks our
  classifier for an unrelated reason). Reserved for a future
  ADR if/when that happens.

### Alternative D — Defer Wasm 2.0 reftype to Phase 10+ (status quo before this ADR)

- **Sketch**: Treat reftype globals / select-typed as
  Phase-10+ scope; keep `elem.wast`, `global.wast`,
  `select.wast` reftype portions deferred.
- **Why rejected**: Reference Types **IS** Wasm 2.0 (W3C Rec
  2024-12). The parse-layer fix (`readValType` 2-byte
  extension + `op_globals.zig` reftype branch +
  `select-typed` reftype path) is small (~30 LOC across two
  files per the completion plan) and falls cleanly inside
  Wasm 2.0 scope. Calling it Phase 10+ was a
  mis-classification anchored on a wrong `D-075` citation
  (D-075 is actually about the Zig library facade per
  ADR-0025, not reftype).

## Consequences

- **Positive**:
  - Scope leak eliminated. `regen_spec_2_0_assert.sh` is now
    consistent with its name.
  - The path to "Wasm 2.0 100% PASS" is now grounded in
    Wasm 2.0 features only; reftype + bulk-memory-opt +
    multi-value + SIMD + sign-extension + saturating-float-to-int
    + simple imported globals.
  - D-104 (and D-103's reftype portion) flips from
    "Phase 10+ blocked" → "Phase 9 actionable". Discharge
    path: d-32 = `readValType` parse-layer fix; d-33 =
    `op_globals.zig` reftype + select-typed; then re-evaluate
    `elem.wast` enablement.

- **Negative**:
  - `local_tee.wast` and `func.wast` from the spec HEAD now
    fail wast2json without the 3.0 enables. The existing
    corpora (regenerated under the prior policy) survive
    because the regen script preserves stale `$DEST/$n` on
    rejection; the runner still exercises them. If those
    upstream files drift further (e.g. removing the 2.0
    fixtures), we lose the coverage until we vendor or pin.
  - The mismatch between the regen script's "for all in
    NAMES" loop and wast2json's actual acceptance means some
    NAMES entries are effectively pinned to their last
    successful regen. Audit-flag for `audit_scaffolding` to
    cross-check NAMES against actual corpus dir presence.

- **Neutral / follow-ups**:
  - **D-103** debt narrative: remove the incorrect
    `D-075 reftype umbrella` citation; rewrite barrier as
    `blocked-by: D-104 discharge (reftype Wasm 2.0 path) +
    D-079 (cross-module imports)`. Discharge plan: d-32 +
    d-33 land readValType + op_globals reftype, after which
    elem.wast is re-evaluated for NAMES enablement.
  - **D-104** debt narrative: status flips from
    `blocked-by: reftype runtime (per D-075 / Phase 10+)` →
    `now`. Discharge plan: d-32 + d-33 above.
  - **D-075** stays as-is (Zig library facade ADR-0025
    partial; unrelated to reftype).
  - A future ADR may revisit Alternative C (vendoring
    wg-2.0 wasts) if upstream drift starts affecting 2.0
    coverage.

## References

- ROADMAP §9.9 — Wasm 2.0 100% PASS exit criterion
- `private/wasm2-completion-plan/REPORT.md` — sequencing
  rationale (M-1 hygiene = this ADR's tool/corpus layer)
- `private/wasm2-completion-plan/02-wast2json-leak.md` —
  flag-by-flag analysis of the leak
- `private/wasm2-completion-plan/03-debt-classification.md` —
  D-104 / D-103 / D-075 re-classification
- ADR-0025 — Zig library facade (the actual scope of D-075)
- `scripts/regen_spec_2_0_assert.sh` — flag list (post-d-31)
- `.dev/debt.md` rows D-103, D-104
