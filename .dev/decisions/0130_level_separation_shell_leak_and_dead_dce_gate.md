# 0130 — Wasm level-separation leaks in shared dispatch shells + revive the dead DCE gate

- **Status**: Accepted (2026-06-02 — autonomous loop, deep audit per user-flagged primary axis; ADR-0073 wording PRESERVED, code fixed to satisfy it)
- **Date**: 2026-06-02
- **Author**: claude (autonomous loop)
- **Tags**: level-separation, DCE, build-options, A12, §4.6, ADR-0073, interp, jit-codegen, enforcement-gap, Phase 10
- **Paired**: audit `.dev/wasm_level_separation_audit.md` (EXECUTED); debt D-230; lesson `2026-06-02-detection-without-enforcement-dead-gate`

## Context

The user's primary integrity question (2026-06-02): is the Wasm 1.0/2.0/3.0
separation **real** or **"half規約頼み"** (half convention-reliant)? ROADMAP §4.6 /
A12 + ADR-0073 promise: `-Dwasm=v1_0` selects a level; higher-level op code is
**comptime-DCE'd** so the binary has *no symbol* for 2.0/3.0 handlers; separation is
by per-feature **directory + dispatch registration** gated by `wasm_level` metadata,
not by pervasive `if (gc_enabled)`.

Deep audit (nm truth-test, the decisive experiment ADR-0073 §"absent from binary"
invites) found the claim is **partially false**:

1. **The real part holds.** Per-op-FILE handlers (`instruction/wasm_*/`,
   `codegen/*/ops/wasm_*/`) ARE genuinely DCE'd via
   `dispatch_collector.enabledByBuild()`'s comptime filter, and some inline guards
   (`codegen/arm64/op_memory.zig:86` `comptime build_options.wasm_level >= v3_0`)
   eliminate correctly. For these, "absent from binary" is TRUE.

2. **Shared-dispatch-shell handlers leak.** Where 3.0 logic is invoked by an
   **unconditional dispatch arm in a shared shell** (not a per-op file, not comptime-
   guarded), it is compiled into sub-3.0 binaries:
   - interp `mvp.zig`: `callIndirectOp`/`callRefOp` called `ref_test_ops.concreteReaches`
     (3.0 §3.3.5.5 subtype) unconditionally → `concreteReaches` symbol in v1_0/v2_0.
     (Introduced THIS session by `80aeee1d`, the .17 subtype fix — a fresh regression.)
   - JIT `arm64/emit.zig` + `x86_64/emit.zig`: the central `switch(op)` arms
     `.return_call` / `.return_call_indirect` / `.return_call_ref` / `.throw`
     (+ `try_table`) call `ops/wasm_3_0/*.emit` unconditionally → 5 `wasm_3_0.*.emit`
     symbols (per host arch). PRE-EXISTING since Phase 10 TC/EH.
   - **Proof**: `check_build_dce.sh --gate` → **v1_0 AND v2_0 FAIL "wasm_3_0 present"**,
     v3_0 clean. nm: 6 leaked symbols on Mac aarch64.
   - Note: `br_on_cast`'s `gcRefMatchesNonNull` did NOT leak — single call site →
     inlined, no standalone symbol. The prep doc's br_on_cast concern is moot; the
     nm-grep cannot see inlined 3.0 code (a known, accepted limit — see Consequences).

3. **The enforcement gate is dead (the meta-finding).** `check_build_dce.sh` has the
   CORRECT detection (`nm | grep -E wasm_3_0`) and DOES flag every leak. But `--gate`
   mode (the only mode that exits non-zero) is invoked ONLY by `check_subrow_exit.sh`,
   which **nothing calls** — not `gate_commit.sh`, not `gate_merge.sh`, not `GATE.md`,
   not CI. `dispatch_consistency_audit` runs it in `--sample` mode (always exits 0).
   So a correct check existed but never blocked → the leaks accumulated silently. This
   IS the "half規約頼み" at the infra level: the convention holds where followed, but
   nothing FORCED it.

## Decision

Treat the leaks as **bugs to fix, not an exception to bless.** Per P1/P3 (no
workaround) + A12, the fix makes ADR-0073's "absent from binary" claim TRUE rather
than narrowing the claim to match the leak.

1. **Comptime-gate the leaked dispatch arms** so the 3.0 calls are not instantiated
   in sub-3.0 builds:
   - interp `mvp.zig` (DONE this commit): `concreteReaches` arm behind a comptime
     `wasm_v3_plus` const. Sub-3.0 `call_indirect`/`call_ref` require exact `sigEq`
     (spec-correct: subtype acceptance is a 3.0-only relaxation). v1_0 symbol removed
     (verified: 6→5 symbols, text −848 B).
   - JIT `arm64/emit.zig` + `x86_64/emit.zig` (NEXT, D-230): comptime-gate the
     `.return_call*` / `.throw` / `.try_table` arms behind `wasm_level >= v3_0`. These
     ops can never appear in a sub-3.0 module (feature_level_check forbids lowering),
     so the arms are provably dead in those builds.

2. **Revive the gate** (D-230 close step): wire `check_build_dce.sh --gate` into the
   real pipeline. Preferred: `gate_commit.sh` is too slow (6 ReleaseSafe builds) for
   per-commit, so wire it into `gate_merge.sh` (A13 merge gate) + a periodic
   `audit_scaffolding` anchor, and delete/repoint the orphan `check_subrow_exit.sh`.
   This is the LAST step of the fix bundle — running `--gate` before all leaks are
   fixed makes it red.

3. **PRESERVE ADR-0073's "absent from binary" wording.** Do not narrow it to "per-op-
   file handlers only." The strong claim is the design intent; the code is brought up
   to it. (Decision-point-3 resolved: NO narrowing.)

4. **No new `dispatch_consistency_audit` body-containment axis** (decision-point-2):
   the existing nm-grep already catches body leaks (it caught these). The gap was
   enforcement (dead `--gate`), not detection. Reviving the gate is the structural fix.

## Consequences

- nm-grep cannot detect 3.0 logic that is fully **inlined** into a sub-3.0-reachable
  handler (e.g. a single-call-site helper). This is an accepted residual limit:
  inlined code carries no symbol and is effectively merged into a legitimately-present
  handler. The containment guarantee is therefore "no standalone 3.0 symbol", which is
  what `check_build_dce.sh` enforces. Handlers whose *registration* should also vanish
  (br_on_cast et al. registered unconditionally in mvp.zig:92 by design, per the
  mvp.zig:98-104 comment) are out of scope here — the lowering-layer feature gate keeps
  them unreachable; only symbol-level containment is asserted.
- Bundle `10.G`'s scope grows by the JIT-emit fix + gate revival (D-230). Until D-230
  closes, v1_0/v2_0 builds still carry the 5 JIT-emit symbols (no behavior impact —
  dead arms; only the containment guarantee is incomplete).

## Alternatives rejected

- **Bless the shared-shell-inline pattern + narrow ADR-0073** — rejected: weakens the
  guarantee to match a leak; P1/P3 violation; the fix is cheap (comptime gate).
- **Add a treesit/grep body-containment axis to the audit** — rejected: redundant with
  the nm-grep that already works; the gap is enforcement wiring, not detection.
