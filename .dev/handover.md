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
   - **#3a-3 JIT interruption** — DEFERRED in order (see RE-SEQUENCE below): it is
     a **Win64-prologue/frame-layout-risk** codegen change → per ADR-0174 needs
     `should_gate_windows.sh --resume` FIRST. Plan: JitRuntime `interrupt_ptr`
     (= `&rt.interrupt_flag_storage`, set where JitRuntime is built — find the
     construction site that has the Runtime); prologue poll (ride stack-probe
     @emit.zig, both arches) + loop back-edge (`op_control.zig` emitBr loop case);
     interrupted trap stub → `error.Interrupted`. FIRST sub-step = Q3 perf spike.
   - **#3a-4**: C API (`zwasm.h`) + `TrapKind.interrupted` in trap_surface (today
     `mapInterpTrap` else→binding_error) + CLI `--timeout <ms>` (timer→flag).

**STATE**: **interp-engine sandboxing TRIAD COMPLETE + green + pushed** (the
default engine) = interrupt (#3a-1/2) + memory-limit (#3c-1 `7216e7b1`) + fuel
(#3b `58479dd6`), all via the Zig facade `Instance.{interrupt,setMemoryPagesLimit,
setFuel,...}`. This is the substantive Tier-1 sandboxing deliverable.

Remaining Tier-1 GATED / reframed (Step-0 findings):
- **JIT-engine sandboxing = documented enhancement, NOT v0.1-blocking** (bundle
  CLOSED). It needs MORE than codegen: a host→JIT interrupt DRIVING path (today
  none — facade is interp-only; CLI `--engine jit` has no interrupt API) + the
  prologue poll/stub codegen (Win64-risk) + a JIT-run-trap test harness (none
  exists). The default interp engine already gives the sandbox guarantee; route
  untrusted code through it. → Phase B documents this.
- **#3a-4 surface** (CLI `--fuel`/`--max-memory`/`--timeout` + C-API config
  setters for the interp path) = small follow-on; the Zig facade (primary surface,
  ADR-0109) already has it → Phase B notes it.
- **#1 C-API WASI preopen — BLOCKED by D-251** (`wasi.h:90-92`: pure C-API has no
  `std.Io` to open dirs). Needs an io-design ADR → Phase B documented gap.

**← NEXT: Phase B** (Tier-1's feasible core is done; honestly document the rest).

**Phase B** — write the honest "v1-has / v2-still-lacks" remainder into
`docs/migration_v1_to_v2.md` (Tier 2 #5 ILP32; Tier 3 #4 allocator / #6 mem-copy
helpers / #7 WAT / #8 rich CLI).
**Phase C** — re-freeze (no tag; ADR-0156 manual-only).
**Phase D** — re-organize public-facing docs (README etc.) for official release,
then stop.

Tier 3 (won't do): #4 allocator (no contributor need, Q5), #6, #7 (WAT→wasm-tools
ADR-0159), #8 (lean CLI ADR-0159). Tier 2: #5 ILP32 = needs static-lib step +
#97-class `@sizeOf(usize)<8` work (not 1-target-add); weigh after Tier 1.

**Already pushed (all ubuntu-green)**: #2 static-lib `45438b7a`, ADR-0179
`91727cc6`, #3a-1 interp-interrupt `1001fa0e`, #3a-2 facade-interrupt `460210f1`,
#3c-1 interp-memory-limit `7216e7b1`. Earlier: musl (ADR-0178), test-noise
cleanup, contributor history + guide rewrite. No release tagged (ADR-0156).

**D-313 (filed, not blocking)**: realworld `c_sha256_hash.wasm` has a WRONG baked
expected hash — zwasm computes the CORRECT sha256 (verified vs `shasum`, interp
+jit). Gate passes (realworld-run lane doesn't assert guest stdout = a gate
hole). NOT a zwasm bug; fixture regen + runner-assert deferred.

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

**Parked (demand-driven, NOT this campaign)**: CM deeper conformance
([`component_model_plan.md`](component_model_plan.md)); WASI-P2 sockets; Go/tinygo
proof; 32 `blocked-by` debt (call_ref / future proposals).

## Key refs

- [`docs/handoff_cw_v1.md`](../docs/handoff_cw_v1.md) — consumer-side handoff.
- **ADR-0170** (CM campaign) · **ADR-0176** (component validation) ·
  **ADR-0177** (runners ReleaseSafe) · **ADR-0156** (no release) ·
  **ADR-0174** (windows gate suspend) · **ADR-0153** (rework posture).
- [`component_model_plan.md`](component_model_plan.md) ·
  [`releasesafe_jit_failures.md`](releasesafe_jit_failures.md) (D-311 resolved).
