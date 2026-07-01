# ADR-0145 — §14.P Phase-14 close: 3-host CI gate re-scoped past the D-245 win64 JIT-ABI bug (mirrors ADR-0144)

> **Status**: Accepted (2026-06-04). Autonomous per ADR-0132 carve-out +
> cross-phase-dep re-scope authority (`feedback_autonomous_roadmap_restructure`).
> **USER-FLAGGED**: narrows the 3-host phase-close gate — the same narrow carve-out
> accepted at §13.P (ADR-0144); surfaced in the resume message.

## Context

§14.P (Phase-14 close) wants the CI matrix green on 3 hosts. Phase 14 delivered:
the GitHub Actions workflows (`pr.yml`/`bench.yml`/`bench_baseline.yml`/`nightly.yml`,
all actionlint-clean, `workflow_dispatch`) + the fuzz infrastructure (`test/fuzz/`
crash-harness wired into `test-all`, runs on all 3 hosts). The windowsmini
`test-all` reconcile is **flaky-red on D-245 win64** (host→JIT callee-saved, the
v128/SIMD-JIT path) — the **exact same blocker re-scoped past at §13.P/ADR-0144**,
seed-dependent in Debug.

- **Not Phase-14 (nor Phase-13) work**: **zero `src/engine` / `src/instruction`
  diff since the Phase-12 close `0810b339`** (verified). Phase 14 added CI config +
  `test/fuzz/` + a `build.zig` test-fuzz step — no JIT/SIMD codegen.
- **Phase-14's new test-all layer (`test-fuzz`) is cross-host green** (Mac +
  ubuntu verified; windowsmini confirmed at this close — see commit body).
- D-245 has now silently flaky-failed windows reconciles across the Phase-11/12/13/14
  closes; it is elevated (its §11.3/Phase-15 home) and is the genuine windows-CI-green
  blocker — including for Phase-15's windows perf bench.

## Decision

1. **Re-scope §14.P "3-host CI green"** to: *"Phase-14 deliverables verified — CI
   workflows actionlint-clean + the new `test-fuzz` layer passes on all 3 hosts
   (windowsmini reconcile); the sole windowsmini failure (D-245 win64 SIMD-JIT
   host→JIT flakiness) is the tracked, elevated carry."* Mark §14.P `[x]`; widget
   14 → DONE; expand the Phase-15 table.
2. **Narrow carve-out** (not a general weakening), identical to ADR-0144: an
   unrelated, pre-existing, flaky JIT-ABI bug does not block an unrelated phase's
   close; it is tracked + routed, not buried. The 3-host invariant holds for
   Phase-14's own deliverables.
3. **D-245 win64 stays the elevated windows-CI-green blocker**, homed at §11.3 /
   Phase-15 (where the windows perf bench also needs it) — it must land in Phase 15
   to stop re-scoping windows green past it.

## Consequences

- Phase 14 closes honest (CI scaffolding + fuzz infra delivered + cross-host green
  for its layers); advance to Phase 15 (perf parity + ClojureWasm).
- windows `test-all` remains seed-flaky until D-245 win64 lands — now EXPLICIT
  across two phase closes (ADR-0144 + this).
- USER-FLAGGED: if the strict full-windows-green gate is preferred, prioritise the
  D-245 win64 trampoline before further phase closes / the Phase-15 windows bench.
- No ROADMAP §1/§2/§4/§5/§11/§14 change; §9 (§14.P) exit re-scope only (ADR-0132).
