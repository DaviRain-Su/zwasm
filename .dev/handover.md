# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `ae2abab7` — x86_64 return_call_indirect emit body
  (10.TC emit-body bundle closes here; return_call_ref carved
  out as D-186, blocked-by 10.R typed-funcref impl).
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

## Next candidates

- **10.E spec corpus runner** — `spec_assert_runner_wasm_3_0.zig`
  is a 130-line skeleton (enumerate-and-count). Adding actual
  assert_return / assert_trap / assert_exception execution is
  multi-cycle.
- **10.R sub-chunks 10.R-3..5** — `br_on_non_null` / `call_ref` /
  `return_call_ref`. Unblocks D-186. The `(ref $sig)` typed-
  funcref Value shape lands at 10.R-4 (call_ref codegen)
  per the row's scope.
- **10.G WasmGC** — large multi-cycle bundle; design plan +
  ADRs (0115/0116/0117) already shipped.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).
- **10.E follow-on**: c_api tag accessors, cross-module EH
  propagation (v0.2), eh_frequency_runner bench scaffolding
  (Phase 8b).

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
