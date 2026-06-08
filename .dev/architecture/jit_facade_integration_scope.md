# JIT-from-facade/C-API integration — scope assessment

> **Doc-state**: ACTIVE

**Date**: 2026-06-08
**Subject**: What it would take to let the public Zig facade (`src/zwasm/*`) and
the C API (`src/api/instance.zig` + `include/`) run modules on the **JIT** engine,
not only the interpreter.
**Status**: ASSESSMENT (no decision to build yet). Scopes the effort behind
debt **D-314**. Not v0.1-blocking — the interp (default) carries every
embedder-facing guarantee today.

## Why JIT is API-unreachable today (structural)

zwasm has **two separate execution worlds** that were designed/grown apart
(facade = ADR-0109, interp-based; JIT = the CLI `--engine jit` fast path):

| Aspect | Interpreter (what the API uses) | JIT (`--engine jit` only) |
|---|---|---|
| Runtime struct | `runtime.Runtime` — native Zig, flexible (`src/runtime/runtime.zig`) | `JitRuntime` — **extern C-ABI fixed layout**, invariants pinned in reserved GPRs (X28/X27/X26/X25/X24 arm64; X28/R15 x86_64, ADR-0018) (`src/engine/codegen/shared/jit_abi.zig:150+`) |
| Construction | `instantiateRuntime` builds memory/tables/globals/funcs/host_calls (`src/runtime/instance/instantiate.zig:1077-1441`) | `setupRuntime`/`RuntimeOwned`, a SEPARATE path (`src/engine/setup.zig:51-238`) |
| Invoke | `Instance.invoke(name, args, results)` — **any arity, all types** (i32/i64/f32/f64/v128/funcref/externref); `dispatch.run` + pushFrame (`src/zwasm/instance.zig:203-304`) | **enumerated signatures only** — 0/1/2/3-arg specific combos; **4+ args UNSUPPORTED** (`src/engine/codegen/shared/entry.zig:322-872`, `src/engine/runner.zig:780`) |
| Arg marshalling | generic | **comptime-selected inline-asm trampolines** per host ABI (BLR / CALL thunks) |
| Host imports | Linker → `host_calls[]` thunk, generic (`src/zwasm/linker.zig:65-200`) | WASI-only dispatch table (`src/wasi/jit_dispatch.zig`); Linker NOT wired |
| Arch | every target | **aarch64 / x86_64 only** (`else => @compileError`, `src/engine/codegen/shared/compile.zig:42-46`); **Win64 native JIT skipped** |

Consequence (verified): `wasm_instance_new`/`Module.instantiate` ALWAYS allocate
an interp `Runtime` (`src/api/instance.zig:666-680`), so `Instance.runtime` is
always non-null and the facade is interp-only. The ZE-2 `assert(runtime != null)`
seam on the budget mutators (`src/zwasm/instance.zig`) marks exactly the spot a
JIT-backed instance would have to branch.

## Work to close the gap (by weight)

1. **Generic invoke-by-name-with-args ABI — the heaviest item.** The JIT entry
   is today a small set of enumerated 0–3-arg dispatchers + per-arch inline asm.
   The API's `invoke` demands any arity + all value types. This needs a **generic
   argument-marshalling trampoline** (place N args into regs/stack per ABI → call
   JIT code → collect results) for **three ABIs**: arm64, x86_64-SysV, Win64. The
   multi-value `buffer-write wrapper thunk` (ADR-0106) is a partial scaffold for
   the RESULT side; the input side is unbuilt. **This is the gating spike.**
2. **Instantiate path: fork or unify.** `Module.instantiate` must branch on engine
   into JIT `setupRuntime`. memory/globals/tables can partly share (D-199 aliasing),
   but native code pages (`funcptrs`) + host_calls construction are a separate system.
3. **Accessor `runtime == null` branches.** `memory()`/`global()`/`table()` all read
   `rt.*`; a JIT-backed instance reads `JitRuntime.vm_base`/`globals_base`/`funcptr_base`
   instead. Mechanical but touches every accessor. `exportFuncSig` already works
   runtime-free.
4. **Host-import JIT wiring.** Bridge the Linker's `host_calls` thunk model into the
   JIT dispatch table (WASI already lives in `jit_dispatch.zig`; generalise to
   arbitrary host fns).
5. **Sandbox parity (the existing D-314 core).** Make ADR-0179 guarantees hold on
   JIT: host→JIT interrupt driving path + prologue/back-edge poll codegen (both
   arches) + per-instruction fuel decrement + memory/table grow caps + a
   JIT-run-trap test harness. Bundle memo: commit `fb18bd82`.
6. **Win64 native JIT.** Currently skipped; a facade that promises JIT everywhere
   must enable Win64 codegen (and test it — windowsmini is an Intel N100 @ ~800MHz,
   ~5.8× slower clock than ubuntunote's i7, so its gate is slow for HW reasons, not
   a Debug build; both hosts run the same `zig build test-all`).

## Scale tiers

- **Minimal ("JIT invoke works", Mac/Linux, no sandbox parity):** medium — items
  #1 (2 ABIs) + #2 instantiate branch + #3 accessor branches. A focused multi-day
  campaign.
- **Full contract (all types/arity, host imports, 3-host incl. Win64, sandbox
  parity):** large — items #1–#6. An ADR-level multi-cycle campaign. This is why
  D-314 tracks it as a "focused windows-resumed bundle", blocked-by.

## Honest read + recommended first step

The interp/JIT split is **intentional** (ADR-0109 facade is interp-based; JIT
evolved as the CLI fast path). The dominant barrier is item #1, the generic
argument-ABI trampoline; once that exists the rest is mostly mechanical wiring.
**First move if we pursue this: a `private/spikes/` spike of the generic invoke
trampoline (arm64 first) to measure feasibility + true cost before committing to
the campaign.** Everything else is gated on that number.

## Anchors
- JIT entry: `src/cli/run.zig:44` (runWasmJit) → `src/engine/runner.zig:451`
  (runWasiLenient) → `src/engine/codegen/shared/entry.zig:322+` (callXxx dispatchers).
- JIT runtime/ownership: `src/engine/setup.zig:51-238`, `src/engine/codegen/shared/jit_abi.zig:150+`.
- Interp contract: `src/zwasm/instance.zig:203-304` (invoke), `:136-182` (accessors).
- Interp construction: `src/runtime/instance/instantiate.zig:1077-1441`.
- C-API call: `src/api/instance.zig:1568-1642`. Linker host imports: `src/zwasm/linker.zig:65-200`.
