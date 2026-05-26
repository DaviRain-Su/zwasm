# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `79749ffe` — TypedValue → runtime.Value payload parser
  (10.E spec-runner bundle cycle 2; parsePayload + 8 new tests).
- **ROADMAP §10 progress**: 7/13 DONE (10.0/10.C9/10.J/10.F/
  10.Z/10.D/10.T), 4 IN-PROGRESS (10.M/10.R/10.TC/10.E with
  10.E core + 10.TC same-module direct + indirect substantively
  done), 2 Pending (10.G/10.P).
- **Active debt rows**: 17 — all `blocked-by:` with named
  structural barriers (Phase 11 / toolchain / GC / v0.2 / 10.R).
  Zero `now`-status rows.
- **D-180 structural defenses STILL IN PLACE** (x86_64
  `usesRuntimePtr` whitelist drift detector + test discipline
  §4 + lesson).

## 10.TC-emit-body bundle close — observable deltas

Bundle ran 8 cycles (1 reverted + re-applied via D-185 fix).
Observable deltas at close (HEAD `ae2abab7`):

- `return_call N` arm64 e2e: `link+execute: fn0 return_call fn1
  returns 7 via B/JMP fixup` GREEN on Mac aarch64 + Linux x86_64
  SysV (cycles 3 + 5).
- `return_call_indirect type_idx 0` arm64 byte-snapshot:
  `compile: return_call_indirect — bounds + sig + funcptr-to-X16
  + frame_teardown + BR X16` GREEN (cycle 6 re-applied at
  `73187e6f`).
- x86_64 emit dispatched via collected_x86_64_ctx_ops grew
  394 → 395 (cycle 5) → 396 (cycle 8).
- `CallFixup.is_tail` ships on both arches; arm64 linker
  dispatches encB vs encBL based on the flag (cycle 1).
- D-185 closed (root cause: shared facade host-dispatch); lesson
  `2026-05-26-shared-facade-host-dispatched-cross-arch-byte-test`
  filed.
- D-186 filed for `return_call_ref` deferral (blocked-by 10.R
  call_ref codegen + typed-funcref Value shape).

## Active bundle

- **Bundle-ID**: 10.E-spec-runner
- **Cycles-remaining**: ~4
- **Continuity-memo**: cycles 1-2 landed in
  `test/spec/wasm_3_0_manifest.zig`. Cycle 1 (`3ae3cfaa`): parseLine
  over alloc-free TypedValue slices + Directive shape (8 tests).
  Cycle 2 (`79749ffe`): parsePayload → runtime.Value with
  i32/i64 unsigned-wrap @bitCast + f32/f64 bit-pattern @bitCast +
  PayloadError mapping (8 more tests; 17 total in the file).
  Parser layer COMPLETE — execution dispatch starts cycle 3.
- **Exit-condition**: at least ONE assert_return directive from a
  wasm-3.0-assert sub-corpus manifest executes end-to-end via
  `cli_run.runWasmCaptured` (or equivalent invocation path) with
  the parsed args + expected result matched against actual
  return; `zig build test-spec-wasm-3.0-assert` reports >0
  assertions passed (vs the current skeleton's 0).
- **Next cycle (cycle 3)**: module loader + invoke integration.
  Survey `spec_assert_runner_base.zig` (4091 LOC) for the
  existing module-load + invoke pattern. Add `runOne(dir,
  directive, args[], expected[])` helper. Same-cycle observable:
  ONE wasm-3.0-assert manifest entry executes end-to-end
  through runOne (e.g. return_call.0.wasm `type-i32 () -> i32:306`).

## Next candidates (after 10.E-spec-runner bundle closes)

- **10.R-4/5** — `call_ref` / `return_call_ref`. Needs the
  `(ref $sig)` typed-funcref Value shape decision first (per
  D-186). Survey-then-spike chunk before implementation.
- **10.G WasmGC** — large multi-cycle bundle; design plan +
  ADRs (0115/0116/0117) already shipped.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).
- **10.E follow-on**: c_api tag accessors (include/wasm.h needs
  upstream EH-proposal sync first), cross-module EH propagation
  (v0.2), eh_frequency_runner bench scaffolding (Phase 8b).

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.
- D-186 — `return_call_ref` blocked-by 10.R-3/4/5.

## Key refs

- ADR-0017, ADR-0026, ADR-0111, ADR-0112 (tail-call design;
  governed the just-closed bundle), ADR-0113 §A (terminator
  class), ADR-0114 D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.TC.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
