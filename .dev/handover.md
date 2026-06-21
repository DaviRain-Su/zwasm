# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state — Phase 17 完成形 completion-refinement (release = USER-ONLY, ADR-0156)

Project at the **完成形 plateau** (all dims confirmed): clean (C/Zig/CLI audits), full-featured (WASI complete +
now cross-component STRING composition, D-305 milestone), 100% spec (`test-spec` 25539/0), lightweight-yet-fast
(v1-JIT parity, D-265 closed). Robustness: interp+JIT fuzz 0 crashes. Closed-arc detail lives in git/ADRs/lessons.

**Closed arcs (detail in git/ADRs/debt — do NOT re-walk)**: D-305 cross-component linker (string/list/record
marshalling both directions, ADR-0196, comp-assert 170/0); ADR-0195 guest↔guest async FUNCTIONALLY COMPLETE +
D-463 handle isolation (ADR-0197); D-034 SIMD spill-completeness CLOSED @411dd1e14; wasi:random, D-335 typed
marshalling, C-API Windows-export. Residual long-tails (debt-tracked, do NOT grind): D-464 async adversarial,
D-305 niche shapes. Version `2.0.0-alpha.3`. Low-pri follow-up: consolidate duplicated SIMD spill helpers.

## RESUME POINTER (2026-06-21) — ADR-0200 JIT API delivered; `.auto`=interp (flip twice-reverted; dispatch matrix incomplete)

**ADR-0200 JIT-backed embedding API delivered; explicit `.jit` solid + completing.** Dual-engine facade accessors
@3d701ddaf + exportFuncSig @5b6449779 + export_types-on-JIT @f68532e44 (C-ABI by-name discovery/invoke works on
`.jit`) + **f64/f32 2-arg FP export-invoke @d7da97e04** (cljw from_cljw_03). cap api/instance.zig→3800 (user-auth).

**`.auto`→JIT FLIP TWICE-REVERTED** (@1e01e6797, then re-landed @f62e08bac, **re-reverted @7dbdb973c**; origin green
ubuntu OK @7dbdb973). Each re-land's 3-host ubuntu gate surfaced MORE JIT export-invoke gaps on x86_64 that Mac
masks (arm64 `.auto` falls back to interp for modules x86_64 JIT-builds). The flip is the FORCING FUNCTION exposing
an incomplete **JIT export-invoke dispatch matrix** — see Active bundle. cljw aligned (to_cljw_04; default `.interp`).

## Active bundle

- **Bundle-ID**: jit-export-invoke-dispatch-matrix
- **Cycles-remaining**: ~3 (fill dispatch gaps → wast_runtime_runner passes under JIT → re-land flip + verify)
- **Continuity-memo**: The host→guest entry dispatch (`runner.zig` `dispatchScalar1/2`, `dispatchVoid2`,
  `invokeMulti`, 3+arg dispatchers) only has KEYS for the type-combos the spec corpus historically exercised;
  real-consumer shapes fall to `else => UnsupportedEntrySignature` → surface as TRAP. `dispatchScalar1` (1-arg) is
  COMPLETE (all 16). **DONE: dispatchScalar2 FP 2-arg @d7da97e04** (keys 0x03/0x28/0x2a/0x2e/0x3a/0x3c/0x3f; entry
  helpers `callF64_f64f64` etc. pre-existed — only keys were missing). **REMAINING (from the @f62e08bac ubuntu flip
  run, `^FAIL` list)**: (1) multi-result FP via `invokeMulti` (`many-results/f` binding_error); (2) 3+arg shapes
  (`func--params/x`, `issue/f` binding_error) — check the 3/4-arg dispatchers for FP/key gaps; (3) `divbyzero`
  binding_error (a (i32,i32)→i32 div traps as binding_error not DivByZero — investigate the trap-kind mapping under
  JIT invoke); (4) `imported-memory-copy InstanceAllocFailed` (memory-IMPORT module: `.auto` should fall back to
  interp — check why fallback fails / the runner's import binding). **Method**: for each, add a facade `.jit` unit
  test reproducing (like the addf test, instance.zig), confirm RED, add the dispatch key / fix, verify arm64 +
  x86_64-macos. Entry helpers usually already exist (grep `entry.zig`).
- **Exit-condition**: re-land the `.auto` flip (re-apply git @9fcf9fb5b code; the revert of it is @7dbdb973c — so
  `git revert 7dbdb973c`) and the **ubuntu x86_64 gate is GREEN** (wast_runtime_runner + wasmtime_misc_runtime pass
  under `.auto`→JIT). Until then `.auto` stays interp. Residual non-blocking: funcref `Table.set` @panic + v128 (D-478/D-477).

**STANDING DIRECTIVE = CORRECTNESS SWEEP** (user 2026-06-20, memory `feedback_correctness_sweep_phase`): high-value
bar OFF. Sweep toward 0% the 3 gap classes — (1) wasmtime-works-zwasm-doesn't, (2) wasm/wasi spec non-conformance,
(3) instability/crashes — easiest-first, TDD + 3-host, repeat; don't ask "is this high-value." Status: spec
skip-impl=0, realworld JIT 56/56 GATING (`test-realworld-diff-jit`), no UnsupportedOp crash, fuzz 0-crash.
ADR-0200 (JIT embedding API) + D-477 (JIT host-invoke) were the live fronts — both delivered/closed; the
ADR-0200 tail = D-478. Prior sweep closures (D-468/D-469/D-470/D-475/D-476/extended-const/GC trap-kind/
memory64+SIMD/fuzz exec-differential) are in git/lessons — do NOT re-walk.
**VERIFICATION LESSON (operationally live)**: a JIT-codegen fix MUST be checked with `test-spec-wasm-2.0-assert`
on BOTH arm64 AND `-Dtarget=x86_64-macos` — NOT `test-spec`(interp)/`zig build test`(unit).
**D-475 table64 slice 4 (JIT table64 codegen) PARKED** (structural u32→u64 descriptor widening, Win64-risk; bounded
4-cycle bundle in debt row, PERF not correctness). Self-contained table64 interp-conformance DONE.

**Phase 17 完成形 plateau** (validated — do NOT re-walk): async COMPLETE; v128 spill (D-034/D-460/D-461) CLOSED;
surface audits clean 2026-06-18; fuzz 0-crash; realworld JIT run 56/56 byte-match wasmtime (gating). NOT-WORTH: D-294-R2 TrapKind.

**Step-0.7 NOTE**: `failed command: test…--listen=-` is COSMETIC (exits 0); trust `[run_remote_*] OK/FAIL` + `N
passed, 0 failed`, not that line.

**PARKED / gated (do NOT speculatively grind)**: D-305 long-tail (list<record>/variant/multi-param — niche, +
`component_graph.zig` 1895/2000 file-split first); D-464 async; 21 `blocked-by` (upstream/proposal/time-gate/corpus).

## Closed arcs (detail in ADRs/git/debt)

- D-305 STRING milestone (@4cceeb1e, ADR-0196) · doc-inventory fresh (`42441634`) · ADR-0192 wasmtime differential
  (9+6 engine bugs fixed; residual D-209/D-456 parked) · 4-front async-maturity (wasmtime async .wast, wasip3, perf
  ROI-rejected D-450, GC corpus 6 bugs) · WASI 0.3 core DONE (D-335, ADR-0187-0191). **validator.zig at 3449/3450
  cap — NEXT validator edit MUST extract per the file's marker plan.**

## Long-tail (debt-tracked / parked — NOT active; see debt.yaml)

- **JIT-correctness** (front B): D-331(B) CLOSED @adb7b99a · D-330 c_sha256 PROVABLY-BLOCKED (bucket-2) ·
  D-331(A) go runtime-corruption (DRIVABLE; build mem-divergence diff first) · D-333 (folds into D-330). Corpus
  interp-green; run-stage opt-in. Trace: `ZWASM_DEBUG=jit.dump` + `scripts/jit_value_trace.sh` (Recipe 18).
- **D-454** (future-bucket): real GC-language program execution fixture, blocked on Hoot reflect-ABI host port.

## State (all 3-host green @046d9c67/win @886d0667; release = USER-ONLY, ADR-0156)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip (GC 362/0). **WASI 0.1** complete; **0.2/CM** default-ON (corpus 158/0/0);
  **0.3 core** done. Sandboxing triad everywhere.
- **Surfaces**: C-API 293/293 · Zig-API complete (full WASI parity) · lean CLI · memory-safety sound · dogfooded into
  cw. Runners ReleaseSafe (ADR-0177; `check_releasesafe_runners.sh`).
- **EH**: cross-instance JIT EH on BOTH arches (arm64 `4f73d9ee` + x86_64 `c534afca`). Interp + JIT EH corpus green.
- **Debt**: 62 entries; **ZERO `now`-class** (D-034 spill arc CLOSED @411dd1e14 → `note`; D-460 v128-GC + D-461 +
  D-293 + D-294 all `note`). Remaining partials: D-305 (consumer-gated CM shapes), D-331(A)/D-330 (go_* JIT; B closed).
  Rest front-tagged (future-bucket/parked); D-462 feature-separation = user-gated. **完成形 plateau.**
- **Realworld corpus**: 56 fixtures (c/cpp/emcc/go/tinygo/rust/zig), interp 56/0; JIT run-stage opt-in.
- **Tag**: `v2.0.0-alpha.3` tag-only (no Release → Latest stays v1.11.0), USER-ONLY.

## Key refs

- [`flake.nix`](../flake.nix) `devShells.gen` / `.#gen-wasip3` — fixture toolchains. [`docs/zig_api_design.md`](../docs/zig_api_design.md).
- ADRs: **0156** (NO autonomous release) · **0153** (rework) · **0187-0191** (CM-async) · **0185** (x86_64 EH) ·
  **0099** (file-size caps) · **0126** (iso-recursive canonical equality).
- lessons INDEX: `.dev/lessons/INDEX.md` (keyword index for Step 0.4).
