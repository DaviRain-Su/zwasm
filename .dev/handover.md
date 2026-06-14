# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Active bundle

- **Bundle-ID**: D-238 x86_64 cross-instance EH frame-walk (ADR-0185), slices 1–5
- **Cycles-remaining**: ~3
- **Done**: ADR-0185 `0d6b07e3`; **Slice 1** `68a480b9` (eh_registry thunk-range set
  + `isCodeAddr`, Mac-green); **Slice 2a** `9aadd97b` (`loadFrameSniffedPred` + 4
  tests); **Slice 2b** `05c66ab0` (`Context.is_code_addr` field + `dispatchThrow`
  predicate param + x86_64 `loadFrameLink` routing + `throw_trampoline` wires
  `eh_registry.isCodeAddr`; arm64 + unit tests unaffected via null fallback);
  **Slice 3** `9fbb7881` (RBP-framed 40-byte thunk + 4 byte tests).
  **Regression FIX `808090f2`**: the ubuntu gate caught a SEGV — slice 2b's
  predicate REPLACED the local CodeMap, breaking single-instance EH (unregistered
  edge-runner thrower → `isCodeAddr` false for all → mis-walk → SEGV 0x1008).
  Fixed by UNION'ing the local throwing-instance CodeMap (normalize_ctx) with the
  global predicate (lesson `global-predicate-cannot-replace-local-codemap`). All
  cross-compiled + Mac-test-green; union regression tests added `29c4a049`
  (per user) pin the broken shape. **Slice 4** `03e99a8a` (spec-runner registers
  each instance's thunk_arena range via `registerThunkArena`/`unregisterThunkArena`
  at the eh_registry.register/unregister sites; interp spec corpus 0-fail).
- **ubuntu test-all GREEN `3387413c`** (`[run_remote_ubuntu] OK`) — the SEGV
  union-fix + the slice-3 follow-up `thunk_bytes` test 27→40 (a stale x86_64-only
  test I'd missed) make slices 1-4 + fixes pass on x86_64. windows re-kicked after a
  D-028-class configure-phase FileNotFound flake (build never reached tests; tracked).
  A fresh ubuntu kick is verifying the `81710782` ReleaseSafe-audit build.zig change.
- **Slice 5 IN-FLIGHT (the D-238 exit-condition)**: `ZWASM_SPEC_ENGINE=jit
  bash scripts/run_remote_ubuntu.sh test-spec-wasm-3.0-assert` kicked → `/tmp/ubuntu_jit.log`.
  Proof = exception-handling JIT 0-fail/0-crash on x86_64 (the `catch-imported`/
  `imported-mismatch` try_table cross-module tests; Mac arm64 baseline this session
  was JIT `return 34/0/0`). PENDING VERIFY next Step 0.7: this JIT log + windows re-kick.
- **NEXT (on JIT green) — CLOSE D-238 + ADR-0185**: (1) ADR-0114's
  `cross_module_throw_propagation.wat` is SUBSUMED by try_table `catch-imported`
  (official corpus, both arches, JIT) → reconcile via an ADR-0114 Revision note
  (do NOT author a duplicate fixture; edge-runner can't do multi-module);
  (2) flip D-238→resolved + ADR-0185 → Closed(Implemented) with the SHA range;
  (3) close the bundle (`check_bundle_active --close`).
- **Continuity-memo**: x86_64-functional-verify is ubuntu-only (opt-in JIT engine);
  unit tests (frame_chain + thunk byte tests) execute on the ubuntu gate, not Mac
  (x86_64/ files aren't in the Mac test graph). Cross-compile gates compilation
  every slice. Default ubuntu test-all verifies unit tests + regression; Slice 5
  is a SEPARATE `ZWASM_SPEC_ENGINE=jit` remote run.
- **Exit-condition**: ubuntu `ZWASM_SPEC_ENGINE=jit` EH cross-module dir green
  (importer catches exporter throw) + non-EH D-225 set + arm64 EH stay green +
  ADR-0114 fixture shipped both arches.

## ACTIVE AGENDA (user-directed 2026-06-14) — drive these in order via `/continue`

Project is feature-complete + 3-host green + tag-ready; **tag is user-only, NEVER
autonomous (ADR-0156)**. This agenda is completion-refinement under Phase 17.
Work the tasks top-to-bottom; each names a concrete first action.

**A1 — flaky `zig build test` (D-311) — DONE `120e9fc1` (de-escalated + fixed).**
Pinned it: `zig build test` EXITS 0 + the test binary passes 2754/0 STANDALONE
across 4 seeds → the "failed command --listen=-" is a Zig build-runner IPC artifact,
**NOT a real failure** (earlier "seed-flaky SEGV" framing was overstated). Shipped the
correctness fix anyway: new pub `entry.callEntrySafe` (wraps the D-245 trampoline) +
routed the 8 contract-violating test direct-calls (entry.zig f32 / linker.zig×2 /
runner_test.zig×4). Full finding: [`releasesafe_jit_failures.md`](releasesafe_jit_failures.md)
§RESOLVED-as-NOT-A-FAILURE. (Residual --listen line = build-runner quirk, deferred.)

**A2 — cljw Zig-API current-state handoff doc — DONE `4aeaea75`.** Authored
`docs/handoff_cw_v2_zig_api.md` (signatures verified accurate-to-HEAD via source
survey): mental model + outlives contracts, lifecycle, host imports (defineFunc/
defineFuncCtx + Caller), cross-module linking, WASI P1 (WasiConfig{args,envs};
preopens=D-177), invoke (untyped+typedFunc), state access, sandboxing, Component
Model (comp.open→Opened: invokeTyped/resolveFuncSig/dropResource/diagnostics +
WitType + ComponentValue), trap set, known-gaps table. Linked from README; tables
aligned. cljw can now read the current Zig embedding surface in one place.

**A3 — external-facing doc精査 + update — DONE `ff9ad225`.** Audited every public
doc vs source. Fixed: reference/zig_api.md (defineWasi args+envs); migration_v1_to_v2.md
(C-API WASI preopen was "deferred" in 4 places — STALE, ADR-0184 shipped
preopen_dir+inherit_env; jit-sandbox "not yet enforced" → D-314 enforced; CM
"opt-in experimental" → default-ON). tutorial/README/benchmarks/cli/c_api CLEAN.

**AGENDA COMPLETE** (A1+A2+A3 done). **D-177 preopens SHIPPED `9bdf9401` + closed
`94c40966`** (full facade WASI args/envs/preopens parity; docs synced `93e94821`).
**2026-06-14 debt-coherence sweep** (`0049036e`..`ea359302`): corrected 5 silently-stale
internal `blocked-by` rows (D-022/D-202/D-197→note, D-178 closed, ADR-0127 Closed) +
re-verified the external/upstream-Zig rows GENUINE (D-312/D-148/D-323 pin-gated; D-010
trigger not fired). Full detail in git. **D-238 (x86_64 EH-JIT parity) is now an ACTIVE
campaign** — see the `## Active bundle` at top for the driving next-step. After the
campaign: future-phase / user-gated (§1.3 /
tag / §13.4). No auto-tag (ADR-0156).

## State (tag-ready baseline, all 3-host green)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip. **WASI 0.1** complete; **0.2/CM**
  default-ON (ADR-0182/0183; corpus 158/0/0). Sandboxing triad everywhere.
- **Surfaces**: C-API 293/293 (+preopen_dir/inherit_env, ADR-0184) · Zig-API
  complete (+`WasiConfig.{envs,preopens,io}` — full WASI parity) · lean CLI ·
  memory-safety sound · dogfooded into cw v1. Runners ReleaseSafe (ADR-0177).
- **Debt**: 46 entries, **zero `now`**; 20 blocked-by(external/future/user-gated) + 24 note long-tail.
  2026-06-14 barrier-dissolution sweep (verified via `test-spec-wasm-3.0-assert`)
  closed D-196 (multi-memory 407/0) / D-195 / D-186 (return_call_ref both arches) /
  D-198 (iso-recursive, gc fail=0) / D-206 (cross-module return_call) + D-301/D-179
  + D-297/D-177. **Cluster SWEPT** — remaining blocked-by are genuinely external
  (upstream Zig / hosts / §1.3 demand-gated / Phase-11 cohort) or partial-remainder.
- **Alpha conformance MET** (`d151538a`): 3.0 corpus fully wg-3.0-current. Tag
  `v2.0.0-alpha.3` is tag-only (no Release → Latest stays v1.11.0), USER-ONLY.

## Key refs

- [`docs/zig_api_design.md`](../docs/zig_api_design.md) (Zig API, §3.8 WASI/§3.9
  component) · [`docs/handoff_cw_v1.md`](../docs/handoff_cw_v1.md) (prior cljw handoff).
- **ADR-0184** (engine-owned io) · **0183** (typed component API) · **0182** (CM
  default-ON) · **0179** (sandboxing) · **0177** (ReleaseSafe runners) · **0156**
  (NO autonomous release) · **0153** (rework) · **0109** (Linker/facade API).
- [`component_model_plan.md`](component_model_plan.md) ·
  [`releasesafe_jit_failures.md`](releasesafe_jit_failures.md) (D-311 / A1 recipe).
