# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `9a134d78` — feat(p10): x86_64 br_on_null +
  br_on_non_null JIT emit (10.R cycle 58, D-194 Path B discharge).
  `captureOrEmitBlockMergeMovCtx` ctx-shape wrapper added to
  `x86_64/op_control.zig`; two per-op files mirror arm64; both
  arches now exercise the same `entry.zig` JIT-execution fixture.
  Mac aarch64 `zig build test-all` + lint green.
- **10.R bundle status — 5 of 5 ADR-0123-independent null-ops
  JIT+tested on both arches**: ref.as_non_null + br_on_null +
  br_on_non_null × {arm64, x86_64}. call_ref + return_call_ref
  remain gated on ADR-0123 Accept (still Proposed).
- **D-194 DISCHARGED** cycle 58 (`9a134d78`, Path B). All `now`
  debt rows discharged; remaining 16 rows are `blocked-by:` with
  named barriers.
- **D-193 FULLY DISCHARGED** earlier (cycle 47, `eccab477`): 0
  `skip.blocker(.@"D-193")` sites repo-wide; D-180-hazard coverage
  gap gone.

## Active bundle

- **Bundle-ID**: 10.R-function-references
- **Cycles-remaining**: ~1
- **Continuity-memo**: ADR-0123 (Proposed) gates call_ref /
  return_call_ref impl. All 3 null-ops (ref.as_non_null,
  br_on_null, br_on_non_null) JIT-green on both arches as of
  cycle 58 (`9a134d78`). Final autonomous chunk = wire
  function-references spec return/trap fixtures into the runner
  (see §"Next chunk" below).
- **Exit-condition**: function-references spec return/trap
  fixtures run on the spec runner (currently only invalid=12);
  the 3 null-ops execute under interp + JIT on both arches
  (autonomous portion **MET**); call_ref family after
  ADR-0123 Accept flip.

## Active task — 10.R cycle 59: wire function-references spec return/trap fixtures

The function-references manifest currently registers
`invalid=12` directives; the runner has not yet been wired for
the proposal's `return` + `trap` fixtures. Per the spec runner
observable below, opening the path requires:

1. **Survey** (Step 0): identify the function-references
   manifest set under
   `test/spec/wasm-3.0-assert/function-references/` (or the
   upstream `~/Documents/OSS/WebAssembly/function-references/`
   bundle) — locate the existing fixture corpus and the
   manifest decl in `test/spec/wasm_3_0_manifest.zig`.
2. **Wire** — add return/trap entries to the manifest so the
   spec runner picks them up. The 3 null-ops (now JIT-emitted on
   both arches) should let most simple `assert_return` /
   `assert_trap` directives flip green; complex fixtures using
   call_ref will fail with `UnsupportedOp` and need ADR-0123
   Accept.
3. **Record** observed counts in
   `.dev/phase_log/phase10.md`; file a `D-NNN` row for any
   call_ref-dependent fixture skipped pending ADR-0123.

Bundle close after this chunk: 3 null-ops green + return/trap
fixtures wired. call_ref / return_call_ref wait on ADR-0123.

## Larger §10 work (blocked / later)

- **10.M memory64** — spec passes; remaining = multi-memory
  (`memories: []MemoryInstance`) + clang_wasm64 realworld (D-179).
- **10.E EH** — blocked: exnref ValType (ADR §4 deviation) + runner
  cross-module register (D-188 / D-192).
- **10.G WasmGC op-corpus** — D-179-blocked (wabt 1.0.41+). Substrate
  landed end-to-end (parse + struct/array ops + β mark-sweep + roots).
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (HEAD `9a134d78`; gate-only cycles unchanged)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=31  trap=0   invalid=10  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(fail2) exception=4(fail4)
[function-references] invalid=12 (all pass)   <- return/trap fixtures not yet wired (cycle-59 target)
```

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- ADR-0123 — Status: Proposed. Accept flip unblocks call_ref /
  return_call_ref impl (the 3 null-ops already proceeded under
  D2's representation-independent reading).
- D-179 — wabt 1.0.41+ blocks GC corpus + clang_wasm64 realworld.
- D-188 / D-192 — EH blocked on exnref ValType + cross-module register.
- 10.P close gate — user touchpoint by construction.

## Key refs

- ADR-0122 (test skip categorization) — D-193 discharge complete.
- ADR-0115 / ADR-0116 (GC heap / roots+RTT+i31) — check for
  function-references typing coverage during 10.R close.
- ADR-0076 (D1 gate / D2 single-push / D3 ubuntu kick).
- ROADMAP §10 rows 10.R / 10.TC; `.dev/phase_log/phase10.md`.
