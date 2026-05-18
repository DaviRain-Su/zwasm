# 0073 — All-layer consistent DCE substrate via build-option

- **Status**: Proposed
- **Date**: 2026-05-19
- **Author**: continue loop §9.12 substrate audit cycle (reflecting 2026-05-19 user feedback)
- **Tags**: phase-9, substrate, build-option, dce, feature-flag, all-layer-consistent

> **State**: skeleton. To be expanded into a full draft in §9.12-pre (including implementation details + results from 3 spike measurements).

## Context

User feedback 2026-05-19 (Q3 adoption policy):

> The design intent: when filtered out by build-option (`-Dwasm` / `-Dwasi` / `-Denable`),
> the code for that feature is **literally "absent"** = the command-line argument does not exist
> = it is functionally unavailable. Branching is likely to spread because this was not
> originally a consideration, but it is worth proceeding incrementally + via spike.

Current facts:
- `build.zig` declares `-Dwasm=v1_0|v2_0|v3_0` (default v3_0), `-Dwasi=p1|p2` (default
  p1), `-Dengine=interp|jit|both`, etc.
- However, `build_options.wasm_level` is only consulted in 2 diagnostics in CLI `main.zig`
  + `diagnostic/trace.zig`
- None of validator / lower / emit / runtime / c_api / CLI / WASI applies a build-option
  feature gate (binaries always include all levels)
- The placeholder structure for `src/instruction/wasm_X_Y/<op>.zig` already exists (3514 LOC populated),
  but the build-option DCE pattern is not yet established

## Decision

**Establish build-option-driven DCE in a single uniform pattern across all layers.**

### Common pattern across all layers

Every declarative element (op / CLI arg / c_api export / WASI syscall) carries:

```zig
pub const wasm_level: ?WasmLevel = ...;   // null = enabled in all builds
pub const wasi_level: ?WasiLevel = ...;
pub const enable_features: []const Feature = &.{};  // for future use
```

Central collector (1 file per layer):

```zig
inline for/switch (registered_elements) |e| {
    if (comptime e.wasm_level) |lvl| {
        if (comptime lvl > build_options.wasm_level) continue;  // or @compileError
    }
    // ... registration or dispatch of the element
}
```

In a `-Dwasm=v1_0` build, handlers / CLI args / c_api exports / WASI syscalls
for Wasm 2.0+ are **not reached at comptime → absent from the binary**.

### Layer-by-layer specifics

#### Layer 1: ZirOp + validator + lower + JIT + interp

`src/instruction/wasm_X_Y/<op>.zig` exports `pub const handlers = .{... 5 axes ...}`.
`src/ir/dispatch_collector.zig` (new) imports + filters every op file at comptime
and constructs the central dispatchers (`validator.zig`, `lower.zig`, `arm64/emit.zig`,
`x86_64/emit.zig`, `interp/dispatch.zig`) using `inline switch`.

#### Layer 2: CLI (`src/cli/`)

Declare CLI arguments in declarative form (`args = .{ ... }`). Each arg carries
`wasm_level` / `wasi_level` metadata, and the parser's comptime filter performs
build-option DCE. In a `-Dwasm=v1_0` build, the `--enable-gc` argument is absent
from the parser and becomes "unknown argument". It also does not appear in
`zwasm --help`.

#### Layer 3: C API (`src/api/wasm.zig` + `include/wasm.h`)

Declare C API exported functions in declarative form (`exports = .{ ... }`); the
comptime `@export(...)` filter performs symbol DCE. On the `include/wasm.h` side,
a build.zig header configure step generates preprocessor gates such as
`#if ZWASM_WASM_LEVEL >= 2`. In a `-Dwasm=v1_0` build, the `wasm_v128_extract`
symbol does not appear in nm / dumpbin output.

#### Layer 4: WASI (`src/wasi/`)

WASI syscalls follow the same pattern. `wasi_p1_*` / `wasi_p2_*` carry `wasi_level`
metadata and are DCE'd by build-option.

### Enforcement (aligned with ADR-0071)

- `scripts/check_build_dce.sh` — verify symbol table grep + size across 6 build-option combinations
- `audit_scaffolding §K.1` (new section — Phase 9 completion enforcement) — flag signs that DCE has broken
- `test/build_completeness/` — E2E test (verify in each build that the feature is "absent")

## Alternatives considered

> Skeleton — to be expanded in §9.12-pre with implementation detail + results from 3 spike measurements.

### Alternative — runtime feature toggle (Wasmer style)

- Sketch: a single binary contains all features, with runtime `--wasm-level` rejecting features
- Rejected: does not satisfy true DCE via build-option = "literally absent from the binary". Does not fit the attack-surface / size-reduction goals.
- Complement: the runtime option **can coexist** (= further filter from what the build includes at runtime). The default build (`-Dwasm=v3_0`) contains all features, and a two-stage control allows runtime downgrade via the `--wasm-level=2.0` argument.

### Alternative — establish the build-option axis only at the ZirOp layer

- Sketch: defer the extension to CLI / c_api / WASI to Phase 10
- Rejected: does not satisfy user requirement (4) "no trouble in Phase 10+". All-layer consistency is a requirement.

## Consequences

- **Positive**:
  - A `-Dwasm=v1_0` build is literally a minimal binary (size + attack surface)
  - CLI / c_api / WASI feature surface is entirely removed by build-option
  - The same pattern (`declarative form + comptime filter`) unifies 4 layers → boilerplate
    is known when adding a new layer
  - When Wasm 3.0 features are added in Phase 10, the build-option `-Dwasm=v3_0` alone
    enables handlers in all layers simultaneously

- **Negative**:
  - Rewriting the existing 5 dispatchers into inline switch + collector consumption
  - Reshaping CLI / c_api / WASI into declarative form (reshape of existing code)
  - Zig 0.16's `inline switch (op) { inline else => |tag| ... }` may hit a compile-time
    wall at 581 tags → to be measured by §9.12-pre spike

- **Neutral / follow-ups**:
  - If the `inline switch` wall is hit, work around it by splitting tag ranges
    (equivalent to Cranelift `isle-split-match`)
  - Verify whether preprocessor gate generation for `wasm.h` is feasible via build.zig's
    `addConfigHeader`

## References

- ROADMAP §2 P14 (sharpening), §4.5 (per-op file pattern), §4.6 (build flags)
- ADR-0023 (src directory structure; paired with §4.5 amend)
- ADR-0071 (Phase 9 substrate audit resolution; basis for Q3 adoption)
- ADR-0050 (aligned with the skip-impl one-way ratchet)
- User feedback 2026-05-19 (adoption of the build-option DCE axis)
- 3 spikes: `private/spikes/q3-zig-inline-switch/`, `q3-interp-dispatch-bench/`,
  `q3-build-option-dce-poc/` (to be created + measured in §9.12-pre)

## Revision history

| Date       | SHA          | Note                                                                              |
|------------|--------------|-----------------------------------------------------------------------------------|
| 2026-05-19 | `<backfill>` | Initial skeleton — build-option DCE substrate; full draft + 3 spike in §9.12-pre. |
