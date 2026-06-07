# ADR-0175 — General component instantiation (instance-graph engine), not special-cased runWasiP2Main

**Status**: Accepted (2026-06-07)
**Scope**: CM campaign Phase E2 (`.dev/component_model_plan.md`). Generalises the
WASI-P2 runner under ADR-0170's mandate; consumes `runtime/instance/instantiate.zig`
+ `Instance` unchanged (per the survey's "reuses, no core change"). No §1/§2 (P/A)
change; the Zone-3 orchestration home is unchanged (ADR-0172).

## Context

`runWasiP2Main` (`api/component_wasi_p2.zig`) is hand-tailored to the shape of the
hand-authored test fixtures: one `$main` core module + a `$libc` memory sub-module
+ host-WASI funcs supplied as `inline_exports` instances of direct `canon lower`s.
It special-cases that topology (finds the lift's core instance, resolves `$main`'s
imports against the `with` args, classifies each `inline_exports` func).

A **real** `rustc --target wasm32-wasip2` component (Phase E2 spike,
`private/spikes/e2-rust-component/`) does not fit that shape. wit-bindgen emits a
**shim / fixup-table indirection** to break the lower↔memory cyclic dependency
(a lowered import that needs `(memory)`/`(realloc)` cannot be created before
`$main` — which provides the memory — is instantiated, but `$main` imports it):

1. `$wit-component-shim` core module exports trampolines (`0..N`) that are pure
   `call_indirect $imports (i32.const k)` through a table it also exports as
   `"$imports"`.
2. Per-interface `inline_exports` instances supply the direct lowers
   (exit/get-std*/pollable.block) — these already classify.
3. `$main` instantiates importing the shim trampolines (for the memory-needing
   funcs) + the direct lowers; exports `memory` + `cabi_realloc` + the `run` entry.
4. The memory-needing lowers (`output-stream.write`, `get-environment`,
   `get-terminal-*`) are `canon lower (... (memory $main) (realloc))` core funcs
   defined AFTER `$main`.
5. A `$fixup` core module with an **active `elem` segment** + a table import is
   instantiated with a synthetic instance exporting `{$imports table, lowers 0..N}`
   → the `elem` fires, wiring the lowers into the shared table slots.

`runWasiP2Main`'s special-casing returns `UnsupportedWasiImport` on the shim
(`.alias`/`.instantiate` topology it does not model). Two paths considered:

- **(A) Special-case the wit-bindgen shape** — pattern-match shim+fixup and wire it.
  Rejected: a workaround keyed to one toolchain's output (no_workaround); brittle to
  wit-bindgen version drift; not spec-defined behaviour.
- **(B) General instance-graph instantiation** — process the component's
  core-instance index space in definition order, instantiating each core instance
  (real module OR synthetic `inline_exports`) through the EXISTING engine, wiring
  imports against already-built instances, and materialising `canon lower`s as host
  trampolines. The shim table is filled by the engine's own active-`elem` handling.

## Decision

**(B).** Build a general component-instantiation engine in Zone 3
(`api/component_wasi_p2.zig` for now; promote to `api/component.zig` once it
subsumes the special path). It walks the core-instance index space once:

- **`.instantiate <module> (with ...)`** → compile the embedded core module, build a
  `Linker` whose definitions are the already-built instances' exports named in
  `with`, instantiate via the existing `instantiate.zig`. Tables / `call_indirect` /
  active `elem` / `start` are the core engine's job — NOT re-implemented here. This
  alone runs the shim and the fixup (the fixup's `elem` fills the shim table).
- **`.inline_exports`** → a synthetic instance exposing host trampolines (classified
  WASI funcs) and/or aliased exports of prior instances (the fixup-args packaging
  `{table, lowers}`).
- **component-level `canon lower`** of a WASI import → a host trampoline bound to the
  named `(memory)`/`(realloc)` instance, exposed for whichever instance re-exports it.
- `classifyCoreExport` follows `.alias` → its target core-instance export → the
  underlying `canon lower` (or resource builtin), so aliased host funcs classify.

Host WASI trampolines remain the `adapter.P2Op`-classified `p2*` set. Phase E2 adds
the missing interfaces (`wasi:cli/environment`, `terminal-*`, `wasi:io/error`,
`output-stream.check-write`) as ordinary trampolines.

## Consequences

- The special-cased fixture path is subsumed: hand-authored fixtures are a degenerate
  instance graph (main + libc + inline_exports), so they keep passing through the
  general engine — the existing e2e tests are the regression net.
- No core-engine change: tables, `elem`, `call_indirect`, `start` are reused. The new
  code is orchestration + host-trampoline materialisation.
- Build order (multi-cycle bundle E2): (1) `classifyCoreExport` follows `.alias`;
  (2) general core-instance walk replacing the special-cased import resolution;
  (3) component-level `canon lower`→trampoline binding main's memory; (4) the missing
  interface trampolines; (5) e2e: real Rust component prints + exits 0; commit it as a
  realworld fixture. Each increment is unit-tested; the e2e is the bundle exit.
- Risk: the general walk must preserve the libc-memory cross-instance + the
  reentrant-`cabi_realloc` seam (lesson `2026-06-07-engine-invoke-is-reentrant…`).
  The existing fixtures pin those invariants at every commit.
