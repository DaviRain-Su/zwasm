# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state — Phase 17 完成形 completion-refinement (release = USER-ONLY, ADR-0156)

Recent closed arcs (3-host or ubuntu-verified; full detail in git/lessons): **D-457** SIMD systemic close (24805/0) ·
**D-458** core-2.0 corpus completeness + cross-corpus audit · doc-inventory pass · **C-ABI trap-kind drift guard** ·
**D-455** array-alloc dedup · **D-459** Wasm 3.0 §3.3.1 local definite-assignment (restore-at-end NOT intersection) ·
**win-specassert-pass0 (ADR-0174 Phase-1) CLOSED**: windowsmini wasm-3.0-assert pass=0 root-caused to CRLF — the
runner was the lone one not trimming `\r`, so windows-CRLF manifests gave `module_path` ending `\r` →
`error.BadPathName` → all modules silently un-loaded. Fixed @02592aa8 (trim, mirrors 4 other runners) → **windows
now pass=10234 = ubuntu, 0 MODULE-READ-FAIL, VERIFIED**; + @b1606384 gates the runner on fails (closes the
"OK-hides-pass=0" masking; lesson `windows-crlf-manifest-badpathname-hidden-by-nongating-skeleton`). D-458 RESIDUAL
(note): broad regen non-idempotency. Ratchet baseline 24 loose (real 22) — harmless. Stale-doc: ROADMAP §16.7 D-277.

CLI surface audit (@4e5e42fe): code↔`--help` fully consistent. Gate change @b1606384 **VERIFIED GREEN on BOTH hosts**
(windows `[run_remote_windows] OK.` wasm-3.0-assert pass=10234 fail=0 / simd 24805/0 / spec 25539/0; ubuntu OK
@f1a1d503). win-specassert campaign fully closed; the fail-gate is clean.

**NEXT (autonomous)**: **ADR-0193 feature-separation migration CLOSED** (P1-P4, D-462) — one ordered `-Dwasi`
axis (default p2), `-Dcomponent` removed, p3/async comptime-fenced (`test-wasi-p3` + DCE), docs synced (WASI D+→B,
component D→B; default `p2→p3` flip tracked under D-335). Now driving the **D-461 rework campaign** (see below).
Then `D-209` memory64. **windowsmini gating RESUMED**. Version → `2.0.0-alpha.3`.

## Active rework campaign — D-461 x86_64 regalloc FP-spill arch-parameterization (ADR-0153)

- **Measured deficiency**: x86_64 JIT PANICS (`index out of bounds`, regalloc.zig:222) under ≥7 live FP/v128
  vregs — a correctness gap (not bench). Root: the deterministic regalloc is **arm64-tuned** (8 GPR/13 FP slots,
  spills minted at origin 8); x86_64 (4 GPR/6 XMM) "fakes" extra spills by lowering `slot()` thresholds, and the
  v128 `spill_offsets` array is sized origin-8 but indexed `id - max_reg_slots_gpr(=4)` → +4 skew → OOB. Blocks
  D-460 v128-GC x86_64 + array-copy-inline.6.
- **Phase I (Investigation) DONE 2026-06-16** (`ccf49f4c`): mechanism nailed via instrumented `slot()` dump
  (class=.fpr id=9 gpr=4 fp=6 n_slots=13 len=5 spill_idx=5); lesson `x86_64-regalloc-fp-spill-origin-mismatch` +
  D-461 debt updated. Repro: un-gate the 12-live-v128 D-461 test (`runner_gc_test.zig:278`) + `zig build test
  -Dtarget=x86_64-macos` (Rosetta).
- **Phase II (Correctness-assurance) DONE** (`c4c1d567`): the buggy resolve path (regalloc.zig:221
  `offsets[id-gpr]`) had ZERO direct unit coverage (all prior tests used the null-spill_offsets fallback). Added 3
  characterization tests pinning the WORKING consistent-origin contract (GPR spill / FPR-spill-past-boundary /
  spillBytes through spill_offsets) + 1 adversarial `skip.blocker(.@"D-461")` fix-verifier reproducing the x86_64
  divergent-origin OOB (un-gate target for Phase IV). Test 2922/2935 green.
- **Phase III (Design ADR) — NEXT**: the deep issue (found during II): the regalloc is **class-blind** — one
  `force_spill_threshold` (8) mints register ids 0..7 for ALL vregs, but x86_64 has 4 GPR / 6 XMM. x86_64 "fakes"
  the extra spills by lowering `slot()` thresholds; scalar GPR spills survive via the array-less `(id-gpr)*16`
  fallback, but v128 spills use the BOUNDED `spill_offsets` array (sized origin-8) → faked-spill ids (FP 6,7) have
  no entry + real spills index `id-4` vs sized `id-8` → OOB/underflow. Design must decide: (a) make the regalloc
  class-AWARE at mint (separate GPR/FP pools — needs per-vreg gpr-vs-fpr class, only v128 shape_tags exist today)
  OR (b) keep class-blind mint but store the spill-array origin in `Allocation` + give the array entries for ALL
  slot()-spilled ids (not just minted-spill ids ≥8). Weigh against P3/P6 single-pass invariant. Then IV impl
  (un-gate the adversarial test), V retrospective.

## Active phase — doc-inventory + freshening (USER-requested 2026-06-16)

- **Goal**: walk ALL zwasm_from_scratch docs (CLAUDE.md, `.dev/`, `.claude/`, README, `docs/`) and reconcile against
  CODE TRUTH — find+fix stale claims (e.g. "100% SIMD spec" was once overstated; conversion ops were missing).
- **Phase I survey DONE** (Explore subagent): main staleness was README version-line anchors. **README FRESHENED**
  (`42441634`): retired `v0.1.0`/Phase-16 anchors (ADR-0181) → 完成形 framing + `v2.0.0-alpha.*` pre-release. VERIFIED
  the coverage claims (Wasm 2.0 `skip-impl==0`, 3.0 all-9-proposals) are ACCURATE vs current test output (the
  survey's "skip-impl 1790" finding was a Phase-9 historical false positive — always re-verify against CURRENT
  state). Other docs clean of the retired-anchor class (only CLAUDE.md:108 uses `v0.1.0` as intentional design-
  priority shorthand — left as-is).
- **Reader-facing count/coverage claims VERIFIED accurate** (vs current runners): C-API **293/293** (gap=0,
  `capi_surface_gap.sh`), component corpus **158/0/0** (README:45 + migration_v1_to_v2.md, ×2), Wasm 2.0
  `skip-impl==0` + 3.0 all-9-proposals. No Phase-16 staleness in zwasm claims (the `cw_v1_consumer_contracts.md`
  "Phase 16" refs are correctly about CW v1's own roadmap, not zwasm). **Reader-facing doc surface = clean.**
- **NEXT (lower-priority remaining)**: `.dev/ROADMAP.md` widget + working-doc count drift (e.g. handover State
  "Debt: 56" is now 61) are internal hygiene, not reader-facing — opportunistic. The high-risk surfaces (README,
  c_api.md, version anchors) are done.

## ADR-0192 wasmtime campaign — substantive work DONE; residuals debt-tracked (paused 2026-06-16)

- **Differential-coverage GOAL MET**: ran wasmtime's `tests/misc_testsuite/` through zwasm; found every gap; **fixed
  9 real engine bugs** the synthetic suite missed — array.copy self-region alias ×interp+JIT (`46c2975e`), array.new
  u32 overflow (`7e527dba`), bottom-reftype decode (`d54b789f`), C-API active-data-drop (`c1f727d4`),
  extern/any.convert in const-expr (`2daaf643`), v128-in-GC-aggregate layout+interp+const-expr (`60c54db5`), + 6 SIMD
  via D-457. Lessons: `native-sweep-instantiate-fail-not-equal-host-import` + 2 more.
- **Residuals (all exotic, debt-tracked, NOT premature-locked — discharge predicates clear)**: **`D-460`** (partial)
  v128-GC: arm64 JIT struct+array get/set EMIT DONE (`f79a3ced`/`41015a9b`, 4 runI32Export tests, arm64-gated via
  skip.blocker) — array.new_fixed/copy + the x86_64 mirror + array-copy-inline.6 are all blocked on **`D-461`** (a
  PRE-EXISTING broad SIMD-spill gap: lane ops can't read a spilled v128 — x86_64 `resolveXmm` rejects `.spill`,
  arm64 lane-op GPR paths SPILL-EXEMPT; staging XMMs xmm14/15 + V29/30 exist, so it's per-op wiring across many SIMD
  ops × 2 arches). **`D-209`** memory64 >4 GiB memarg offset (10.M-4b multi-arch). **Parked = D-456** host-import
  fixtures. Harness: `scripts/wasmtime_misc_{sweep,native_sweep}.sh`. Re-open D-461 as its own bundle if a real
  high-v128-pressure program (not just this fixture) needs it, or to finish v128-GC.

**Closed campaigns (detail in git/lessons)**: prior 4-front async-maturity (2026-06-16) — ② wasmtime async .wast
TIER-1 (`afcf889a`/`05b35c28`; D-446/447 deferred), ① wasip3 conformance (7 real-rust fixtures, `.#gen-wasip3`),
④ perf (ROI-rejected single-pass ceiling, D-450), ③ real-world GC corpus (6 engine bugs FIXED: D-451-453/9064faa5/
480809af/9ec68a75/79742cb4; 4 GC edge fixtures; real Hoot execution → D-454). **WASI 0.3/Preview-3 core DONE**
(D-335; ADR-0187-0191). validator.zig at 3449/3450 cap — NEXT validator edit MUST extract per the file's marker plan.

## Long-tail (debt-tracked / parked — NOT active; see debt.yaml)

- **JIT-correctness** (front B / parked): D-330 c_sha256 `\n` (parked — conflicting-constraint; do NOT re-run the
  blanket fix) · D-331(A) go runtime-corruption (infra-blocked) · D-331(B)/D-289 go_regex emit (parked) · D-333
  (br_table, folds into D-330). Realworld corpus interp-green; JIT run-stage opt-in (`ZWASM_JIT_RUN=1`). Trace:
  `ZWASM_DEBUG=jit.dump` + `scripts/jit_value_trace.sh` (Recipe 18).
- **D-454** (future-bucket): real GC-language program execution fixture, blocked on Hoot reflect-ABI host port.

## State (all 3-host green @046d9c67/win @886d0667; release = USER-ONLY, ADR-0156)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip (GC 362/0). **WASI 0.1** complete; **0.2/CM** default-ON (corpus 158/0/0);
  **0.3 core** done. Sandboxing triad everywhere.
- **Surfaces**: C-API 293/293 · Zig-API complete (full WASI parity) · lean CLI · memory-safety sound · dogfooded into
  cw. Runners ReleaseSafe (ADR-0177; `check_releasesafe_runners.sh`).
- **EH**: cross-instance JIT EH on BOTH arches (arm64 `4f73d9ee` + x86_64 `c534afca`). Interp + JIT EH corpus green.
- **Debt**: 61 entries; `now`-class = D-462 (feature-separation, ADR-0193, user-gated), D-460 (v128-GC partial),
  D-461 (SIMD-spill, blocks D-460). D-335 (WASI 0.3 core) DONE. Rest front-tagged (future-bucket/parked).
- **Realworld corpus**: 56 fixtures (c/cpp/emcc/go/tinygo/rust/zig), interp 56/0; JIT run-stage opt-in.
- **Tag**: `v2.0.0-alpha.3` tag-only (no Release → Latest stays v1.11.0), USER-ONLY.

## Key refs

- [`flake.nix`](../flake.nix) `devShells.gen` / `.#gen-wasip3` — fixture toolchains. [`docs/zig_api_design.md`](../docs/zig_api_design.md).
- ADRs: **0156** (NO autonomous release) · **0153** (rework) · **0187-0191** (CM-async) · **0185** (x86_64 EH) ·
  **0099** (file-size caps) · **0126** (iso-recursive canonical equality).
- lessons INDEX: `.dev/lessons/INDEX.md` (keyword index for Step 0.4).
