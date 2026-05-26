# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `062f3c94` — spec_assert_runner_wasm_3_0 main-loop
  now executes assert_return; first run reports pass=25 fail=364
  across 774 directives (tail-call: 25 pass / 6 fail confirms the
  closed 10.TC-emit-body bundle against wast-baked fixtures).
- **ROADMAP §10 progress**: 7/13 DONE (10.0/10.C9/10.J/10.F/
  10.Z/10.D/10.T), 4 IN-PROGRESS (10.M/10.R/10.TC/10.E with
  10.E core + 10.TC same-module direct + indirect + 10.E spec
  runner parser→executor primitives substantively done), 2
  Pending (10.G/10.P).
- **Active debt rows**: 17 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows.

## 10.E-spec-runner bundle close — observable deltas

Bundle ran 3 cycles closing at HEAD `734c6219` (source) +
`ca0f51a0` (handover mark). Observable deltas:

- **C1 (`3ae3cfaa`)**: `test/spec/wasm_3_0_manifest.zig` —
  parseLine over alloc-free TypedValue slices + Directive shape.
  8 unit tests.
- **C2 (`79749ffe`)**: parsePayload → runtime.Value with
  i32/i64 unsigned-wrap @bitCast + f32/f64 bit-pattern @bitCast
  + PayloadError mapping. 8 more tests (17 total).
- **C3 (`734c6219`)**: `runOne(alloc, wasm_bytes, func_name,
  args[])` via Native Zig API (ADR-0109 Engine + Linker +
  Instance.invoke). First e2e test executes
  `return_call.0.wasm::type-i32 () → i32:306` via @embedFile-
  pinned fixture. 19 tests total in file. Green Mac + Linux
  (ubuntu verified at `ca0f51a0`).

Cross-link: the e2e test exercises the just-closed 10.TC-emit-
body bundle's same-module direct return_call codegen on real
wast-compiled bytes (not synthetic ZIR) — first cross-bundle
verification of the tail-call substrate.

## Next candidates

- **10.E spec runner: tail-call FAIL bisect** (6 fails out of 31
  assert_returns). Identify which 6 fail; root-cause each. Likely
  candidates: multi-result returns, v128 / refs in args/results,
  cross-module funcref tail-call. Small-cycle wins per failure.
- **10.E spec runner: assert_trap execution** — expect runOne to
  return RunError.InvokeFailed for assert_trap directives; needs
  trap-class discrimination to verify the EXPECTED trap kind.
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

- ADR-0017, ADR-0026, ADR-0109 (Native Zig API; governs the
  just-closed bundle's runOne shape), ADR-0111, ADR-0112,
  ADR-0113 §A, ADR-0114 D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.T /
  10.TC / 10.E.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
