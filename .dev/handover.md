# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: source pending this cycle — tail-call FAIL bisect
  test + D-187 root-cause file. wasm-3.0-assert tail-call still
  pass=25 / fail=6 (regression marker pinned).
- **ROADMAP §10 progress**: 7/13 DONE (10.0/10.C9/10.J/10.F/
  10.Z/10.D/10.T), 4 IN-PROGRESS (10.M/10.R/10.TC/10.E with
  10.E core + 10.TC same-module direct + indirect + 10.E spec
  runner parser→executor primitives substantively done), 2
  Pending (10.G/10.P).
- **Active debt rows**: 18 — all `blocked-by:` with named
  structural barriers. Zero `now`-status rows.

## Active task — 10.TC interp trampoline (D-187 discharge)

Tail-call FAIL bisect (handover prior "next candidate")
**root-caused this cycle**: the 6 failing assert_returns
(`count` ≥ 1000, `even` / `odd` ≥ 999999) all trip
`Trap.CallStackExhausted` at interp frame ceiling 256. Root
cause is the documented interp limitation at
`src/interp/mvp.zig:440-443`: `returnCallOp` (mvp.zig:467)
invokes the callee via host-Zig recursion (`invoke(callee)` then
`tailReturn`), so each Wasm tail-call pushes a host-side Frame
instead of reusing the caller's. The JIT codegen from the closed
10.TC-emit-body bundle implements actual frame-reuse via
`frame_teardown` + BR X16 / JMP R11, but Native API
`Instance.invoke` (`src/zwasm/instance.zig:113`) routes through
`dispatch.run` → interp dispatch table.

**Discharge** = land the interp trampoline already named in
ROADMAP §10 row 10.TC scope ("interp trampoline (v1 vm.zig
pattern re-derive)"). No ADR needed — it's planned same-row
scope, not a §4 architecture deviation. v1's `vm.zig`
non-recursive dispatch is the textbook (read-only per
`no_copy_from_v1.md`); re-derive in v2's `interp/mvp.zig`
substrate.

Regression marker pinned at `test/spec/wasm_3_0_manifest.zig`
"tail-call bisect" (`pass == 25, fail == 6`) — fires red when
the trampoline lands; retighten to `pass == 31` at that point.

## Next sub-chunk candidates (names only)

- **10.TC interp trampoline** — D-187 discharge; Step 0 survey
  v1 `vm.zig` non-recursive dispatch shape.
- **10.E spec runner: assert_trap execution** — expect runOne to
  return RunError.InvokeFailed for assert_trap directives; needs
  trap-class discrimination to verify the EXPECTED trap kind.
- **10.E spec runner: assert_invalid execution** — surface
  validator's reject-class; manifest's 4 assert_invalid +
  surrounding ones (return_call.[1-4,7-12].wasm).
- **10.R-3** — `br_on_non_null` (unblocks 10.R-4 `call_ref` and
  10.R-5 `return_call_ref` per D-186).
- **10.G WasmGC** — large multi-cycle bundle; design plan +
  ADRs (0115/0116/0117) already shipped.
- **10.M-realworld** — toolchain-blocked (D-179 wabt 1.0.41+).

## Open questions / blockers

- ADR-0120 — Status: Proposed pending user flip to Accepted.
- 10.G-4 (struct ops) — blocked-by GC heap impl.
- 10.M-realworld — toolchain-blocked (D-179).
- 10.P close gate — user touchpoint by construction.
- D-186 — `return_call_ref` blocked-by 10.R-3/4/5.
- D-187 — interp tail-call host-stack growth; discharge =
  10.TC interp trampoline (planned row 10.TC scope).

## Key refs

- ADR-0017, ADR-0026, ADR-0109 (Native Zig API; governs the
  runOne + Instance.invoke shape that D-187 sits on), ADR-0111,
  ADR-0112 (10.TC JIT codegen scope), ADR-0113 §A, ADR-0114
  D1/D5/D6, ADR-0119, ADR-0120.
- ROADMAP §10, Phase log `.dev/phase_log/phase10.md` Row 10.T /
  10.TC / 10.E.
- Lessons (recent): `.dev/lessons/INDEX.md` entries 2026-05-26
  (shared-facade-host-dispatched) + 2026-05-28 (5 EH lessons).
