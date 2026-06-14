# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Active bundle

- **Bundle-ID**: D-238 x86_64 cross-instance EH frame-walk (ADR-0185), slices 1–5
- **Cycles-remaining**: ~3
- **Done**: ADR-0185 `0d6b07e3`; **Slice 1** `68a480b9` (eh_registry thunk-range set +
  `isCodeAddr`, Mac-green); **Slice 2a** `9aadd97b` (`loadFrameSniffedPred` +
  4 tests, x86_64-cross-compiled — tests EXECUTE on ubuntu gate, not Mac).
- **NEXT — Slice 2b**: thread an `is_code_addr: ?*const fn(usize) bool` field into
  `frame_chain_adapter.Context` (separate axis from `normalize_ctx` — no dual-use);
  route the x86_64 branch of `loadFrameLink` to `loadFrameSniffedPred` when set;
  wire production in `throw_trampoline`/`zwasm_throw` (`adapterContextFor`) to
  `eh_registry.isCodeAddr`. Then **Slice 3** RBP-framed 40-byte thunk
  (`x86_64/thunk.zig`, byte test, `thunk_bytes` 27→40), **Slice 4** `setup.zig`
  registers each instance's `thunk_arena` via `registerThunkArena`, **Slice 5**
  ubuntu `ZWASM_SPEC_ENGINE=jit` EH-dir functional verify + ship ADR-0114
  `cross_module_throw_propagation.wat` fixture → close D-238 + ADR-0185.
- **Continuity-memo**: x86_64-functional-verify is ubuntu-only; the LOGIC of
  slices 1/2a IS unit-tested (eh_registry on Mac, frame_chain on ubuntu). Cross-
  compile (`-Dtarget=x86_64-linux-gnu`) gates compilation every slice.
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
**2026-06-14 internal-`blocked-by` staleness sweep** (`0049036e`/`b36f15fc`/`ea359302`):
the earlier "barrier sweep EXHAUSTED" was WRONG — internal-predicate rows had silently
gone stale. Corrected 5: **D-022**→note (category error: trap-event ≠ value-mismatch
localization; M3-a-2 unlocks nothing → not built); **D-202**→note + **ADR-0127 Closed**
(PHASE C landed `add983e8`, assert_unlinkable 5→0; only a latent same-typespace #1
residual, no fixture); **D-197**→note (validator-diag plumbing landed; per-cause
attribution deferred-by-no-signal); **D-178 CLOSED** (host-side construction surface fully
landed — C-API `wasm_{global,memory,table}_new` + facade `define{Global,Table,Memory}`).
Verified GENUINE-blocked: D-026/D-082 (Phase-11 emcc/externref), D-020 (4/5 dbg
threshold). **External/upstream-Zig rows re-verified GENUINE** (D-312/D-148/D-323
pin-gated to Zig 0.16; D-010 third-site trigger not fired — `rawFreeOwned` still 1
module): unlike internal rows these don't silently dissolve (pin-bump/trigger-gated).
**D-238 (x86_64 EH-JIT parity) is now an ACTIVE implementation campaign** — design
+ slices 1/2a landed; see the `## Active bundle` section at the top for the driving
next-step (Slice 2b). Else (after the campaign): future-phase / user-gated (§1.3 /
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
