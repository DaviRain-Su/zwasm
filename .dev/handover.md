# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## ⏸ zwasm v2 development PAUSED (user directive 2026-06-08)

**Paused at `1c542a84`, verified green Mac aarch64 + ubuntu x86_64** (windows
gating suspended @9d832f1d, ADR-0174). Development is **demand-driven from now
on**: resume only when ClojureWasm v1 (cw v1) surfaces a concrete requirement.
The runtime is feature-complete for cw v1's needs. Handoff for the consuming
side: [`docs/handoff_cw_v1.md`](../docs/handoff_cw_v1.md). No release tagged
(ADR-0156: tag/publish/`main`-cutover are manual, user-only). The autonomous
loop is **NOT re-armed** while paused.

## State at pause

- **Core Wasm 1.0/2.0/3.0**: 100% spec, 0 skip, 3-host green. **v0.2 features**
  (atomics / wide-arith / custom-page-sizes / relaxed-SIMD) complete + official
  corpora. **WASI 0.1** complete.
- **Component Model + WASI Preview 2** (opt-in `-Dcomponent`): a real Rust
  wasm32-wasip2 component runs e2e (ADR-0170/0175); E1 spec-corpus runner
  (`test/spec/component-model-assert/`); **structural validation** rules 1-4
  (type-index/Canon/alias/ExternDesc bounds — ADR-0176, `feature/component/validate.zig`).
- **Surfaces**: C-API 293/293 gap-free · Zig-API complete · CLI (`run`/`compile`,
  intentionally lean) · memory-safety sound · dogfooded into cw v1.
- **Test iteration**: integration runners build ReleaseSafe (ADR-0177); unit
  `zig build test` stays Debug. `zig build test-all` auto-fast, no flag.
- Debt ledger **52 entries** (D-311 discharged @02965aa6/a0069ce8). `now` = D-299
  only (env-constrained x86_64 W^X). Rest `blocked-by`/`note` = long-tail.

## Parked work (resume threads, demand-driven)

- **CM deeper conformance** (the natural next thread): name validation
  (kebab/extern-name — fixtures need binary extraction from official `.wast`;
  WIT text parser rejects bad names), outer-alias nesting-depth + export-name
  existence, deep subtyping / canon-ABI constraints, CM corpus growth. Driver:
  [`component_model_plan.md`](component_model_plan.md); validator seam ready.
- **WASI-P2 sockets** (D3-8, spike-first); **Go/tinygo cross-toolchain proof**
  (toolchain-gated). 32 `blocked-by` debt = call_ref / future proposals.

## Resuming (if cw v1 needs more)

1. Read this file + [`ROADMAP.md`](ROADMAP.md) (single source of truth).
2. `/continue` skill drives the autonomous TDD loop; pick the CM-deeper thread
   or whatever cw v1's need maps to. 3-host gate discipline unchanged.
3. Before any `main` merge / Win64-risk diff: `should_gate_windows.sh --resume`.

## Key refs

- [`docs/handoff_cw_v1.md`](../docs/handoff_cw_v1.md) — consumer-side handoff.
- **ADR-0170** (CM campaign) · **ADR-0176** (component validation) ·
  **ADR-0177** (runners ReleaseSafe) · **ADR-0156** (no release) ·
  **ADR-0174** (windows gate suspend) · **ADR-0153** (rework posture).
- [`component_model_plan.md`](component_model_plan.md) ·
  [`releasesafe_jit_failures.md`](releasesafe_jit_failures.md) (D-311 resolved).
