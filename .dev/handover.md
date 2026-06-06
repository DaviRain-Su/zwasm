# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase 16 (完成形) — open-ended; the loop CONTINUES, no release (ADR-0156).** Phases 0–15 DONE;
  v0.1.0-scope complete + 3-host green. Tag/publish/cutover are manual, user-only — no release gate.
- Debt ledger: **66 entries, 0 `now`** (D-213 discharged this turn). All remaining = blocked-by future phases /
  notes (QoI/exotic/historical) / 3 partial. No actionable HIGH-value item open (verified §0.5 sweep 2026-06-06).

## ← LEAD: 完成形 surface work COMPLETE; entering maintenance/depth (2026-06-06 session)

**All three surface audits DONE** (user-steered direction): CLI→**D-295** (~85% + intentionally lean; declines
per ADR-0159 ≠ gaps; `--env` shipped). C-API→**ZERO gaps** (D-296; `capi_surface_gap.sh` 293/293; Phase-13
conformance verified+exceeded). Zig-API→**COMPLETE** (D-296): closed gap#1 (`Module.imports/exports`) + ALL
implementable residuals this session — `Memory.grow` (`f163e882`, shared `Runtime.growMemory`, test-spec 9/0),
`Memory.sliceAt` (`e5f34ff8`), `Engine.linker()` (`994a5aef`), `Linker.defineInstance` (`dba99bb8`, all 4 export
kinds). Surface reviewed CLEAN (subagent, no HIGH/MED), `docs/zig_api_design.md` synced (`e120cc15`), example
introspection demo (`40553679`).

**Memory-safety (完成形 dimension)**: facade additions reviewed clean; **cross-module aliasing** audited
(**D-297**) — model SOUND (zombie-parking keeps aliased storage alive past instance deletes; DISPROVED a claimed
table-UAF). One real gap fixed (`477a9004`): documented the **Linker-must-outlive-its-Instances** contract
(importer holds raw ptr into Linker-owned CallCtx). Optional debug-assert guard deferred (D-297). NOT-yet-swept:
WASI fd resource lifecycle (the one remaining distinct area).

**D-279 (Win64 SIMD-JIT heisenbug, the one open RED-class issue)**: resurfaced @23542591 (wasm-2.0-assert exit-3)
→ confirmed FLAKE (D7 re-run green, facade exonerated: ubuntu green, exit-3=crash not wrong-result). Streak reset
6→0 then 1. INSTRUMENTED (`22310693`): `windows_traphandler.zig::diagUnrecovered` emits `[d-279-veh] UNRECOVERED
(unfiltered-code | rip-outside-jit): code/rip/jit` on the two previously-silent armed-but-escaping VEH paths →
**next Win64 crash self-identifies its mechanism**. Investigation: REFUTED H1 (SIMD-spill aligned-move #GP —
spills use MOVUPS); refined lead = FP-walk/stack-walk corruption (D-180/D-245). Can't progress until the next
crash surfaces a `[d-279-veh]` line.

**NEXT track** (high-value autonomous surface work is largely done): (a) WASI fd memory-safety sweep (last
distinct unswept area; tight HIGH-confidence brief + adversarially verify any finding — last audit had a false
positive); OR (b) wait for a `[d-279-veh]` line on the next Win64 RED to pick the D-279 hypothesis; OR (c)
blocked-by barrier-dissolution re-checks. Discipline reinforced: **always adversarially verify audit "CRITICAL"
labels** (the cross-module audit flip-flopped + 1/2 criticals was a false positive).

**Blocked / parked**: 31 blocked-by (call_ref §10.R / Phase-11 D-177 WASI-config / D-178 standalone Global-Memory /
future proposals). **D-290** = 3 proposal-laden distillers, direction-gated (wasm-tools↔wabt output divergence;
wabt stays). **D-264** ClojureWasm dogfooding gated. `.dev/proposal_watch.md` = v0.2.0 backlog.

## Step 0.7 (next resume) — verify remote logs

- **ubuntu**: re-kicked each turn (D6 always). Verify `[run_remote_ubuntu] OK` in `/tmp/ubuntu.log`. Last GREEN
  @`2d896c33`. Red → auto-revert (D3).
- **windows**: BATCHED (D8). A run validating the VEH diagnostic (`22310693`) was IN FLIGHT at session pause —
  verify `[run_remote_windows] OK` in `/tmp/win.log`; if green + the batch fired, run `should_gate_windows.sh
  --record`. Red → NOT auto-revert; if it's a `[d-279-veh]`/exit-3 SIMD crash = D-279 flake (`track_heisenbug.sh
  win64-testall segv` + proceed); else investigate. Don't poll-wait.
- **Gate note**: `[run_remote_windows] OK` = real green; `Build Summary: N failed` (no OK) = RED. EXPECTED
  non-failures: `zig-host-hello` exit-42 + `--__selftest-crash` exit-70 "failed command"; the sha256 `verify:
  FAIL` line is the known fixture-wrong-constant FALSE lead (zwasm hashes correctly).

## Key refs

- **ADR-0156** (no autonomous release) · **ADR-0153** (rework campaign) · **ADR-0076** (3-host cadence D6/D7/D8)
  · **ADR-0109** (native Zig API) · **ADR-0014 §2.1** (zombie-parking lifetime, D-297).
- **D-296** = surface-audit record (C/Zig-API) · **D-297** = cross-module memory-safety audit · **D-279** =
  Win64 SIMD heisenbug (instrumented) · `.dev/proposal_watch.md` = v0.2.0 feature backlog.
