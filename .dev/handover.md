# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## ▶ ACTIVE CAMPAIGN: v1→v2 Tier-1 parity + release-doc prep (user-directed 2026-06-08)

Pre-release groundwork. Plan = `docs/migration_v1_to_v2.md` §1 tiers +
`docs/v1_contributor_history.md`. Tier table decided with the user.

**Phase A — implement Tier 1** (this order):
1. ✅ **#2 link hardening** — `static-lib` step + `scripts/test_extlink.sh` +
   migration-guide link line + D-312 (GNU-stack=zig-upstream). `45438b7a`.
2. ✅ **ADR (#3) = ADR-0179** — interruption/limits per wasmtime's 3 orthogonal
   mechanisms: fuel (deterministic, opt-in) · epoch (cheap counter, timeout+
   cancel) · store-limits (max memory/table). Explicit names.
3. **#3a interruption** (timeout + host-thread cancel; cooperative flag, NOT a
   u64 epoch counter — the v0 form per ADR-0179, a per-instance
   `*std.atomic.Value(u32)` the guest polls):
   - ✅ **#3a-1 interp foundation** `1001fa0e`: `error.Interrupted` +
     `Runtime.interrupt`/`checkInterrupt` + func-entry (`mvp.invoke`) & throttled
     loop-back-edge (`dispatch.run`, /1024) polls. 3 deterministic tests green.
   - ✅ **#3a-2 facade wiring** `460210f1`: `Instance.interrupt()`/`clearInterrupt()`/
     `interruptRequested()` backed by `Runtime.interrupt_flag_storage` (armed at
     `api/instance.zig`); facade invoke polls at func entry; mapDispatchErr arm;
     facade e2e test green.
   - **← NEXT #3a-3 JIT**: JitRuntime gains `interrupt_ptr` (= `&rt.interrupt_flag_storage`,
     set in `entry.zig` invoke build); prologue (ride stack-probe @emit.zig) + loop
     back-edge (`op_control.zig` emitBr loop case) poll, BOTH arches + an
     interrupted trap stub → `error.Interrupted`. FIRST sub-step: real perf spike
     (Q3) — bench a JIT loop with/without the back-edge poll.
   - **#3a-4**: C API (`zwasm.h`) + `TrapKind.interrupted` in trap_surface (today
     it maps to binding_error) + CLI `--timeout <ms>` (timer thread sets flag).
4. **#3c store limits** → 5. **#3b fuel (opt-in)** → 6. **#1 C-API WASI preopen**
   (`wasi.h`; CLI `--dir` capability already exists; D-251).

**Phase B** — write the honest "v1-has / v2-still-lacks" remainder into
`docs/migration_v1_to_v2.md` (Tier 2 #5 ILP32; Tier 3 #4 allocator / #6 mem-copy
helpers / #7 WAT / #8 rich CLI).
**Phase C** — re-freeze (no tag; ADR-0156 manual-only).
**Phase D** — re-organize public-facing docs (README etc.) for official release,
then stop.

Tier 3 (won't do): #4 allocator (no contributor need, Q5), #6, #7 (WAT→wasm-tools
ADR-0159), #8 (lean CLI ADR-0159). Tier 2: #5 ILP32 = needs static-lib step +
#97-class `@sizeOf(usize)<8` work (not 1-target-add); weigh after Tier 1.

**Already landed (pushed `02d08793`)**: musl portability (ADR-0178), test-stderr
noise cleanup. Docs committed local `f1bee8f1` (contributor history + guide
rewrite). No release tagged (ADR-0156 user-only).

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
