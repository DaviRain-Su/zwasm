# Inline-switch cutover ↔ DCE substrate coupling (B108-B112)

**Date**: 2026-05-20
**Citing**: B108 `aa39c73b`, B109 `3591fa57` + `6d89236e` (regression fix),
B110 `c1780807`, B112 `59bde111` (D-150 close).

## Observation

The §9.12-B inline-switch cutover (ADR-0073) and the build-option DCE
substrate (ADR-0075) interact in a non-obvious way: removing the giant
switch arms in `emit.zig` makes the dispatch path comptime-DCE-eligible,
but the **call-site comptime elimination is only one of two ingredients**.

The leaked symbols in v1.0 builds (D-150) came from `src/api/instance.zig`'s
`dispatchTable()` initializer, which **unconditionally** called
`ext_bulk_memory.register(&table)` etc. The dispatcher's `enabledByBuild`
filter correctly DCEs the call-site to the per-op file's `emit`, but the
host module (`instruction/wasm_2_0/bulk_memory.zig`) is still in the binary
because `register(table)` is referenced from the always-active
`dispatchTable()` path.

The Zig compiler's DCE walks references; if any always-active code path
references `bulk_memory.register`, all `pub fn`s in `bulk_memory.zig`
(including `dataDrop`, `memoryFill`, etc.) stay linked.

## Root-cause pattern

**DCE-effective gating requires gating at the *use-site*, not just the
dispatch path.** A four-layer architecture (ADR-0073: parse / validate /
ir / runtime + emit) needs the `if (comptime build_options.wasm_level >=
.v2_0) {...}` wrap at EVERY layer's wasm_2_0 reference, not just the
dispatcher.

For `src/api/instance.zig`:

```zig
const wasm_2_0_enabled = @intFromEnum(build_options.wasm_level)
                      >= @intFromEnum(@as(@TypeOf(build_options.wasm_level), .v2_0));

const ext_bulk_memory = if (wasm_2_0_enabled)
    @import("../instruction/wasm_2_0/bulk_memory.zig")
else
    struct {};

// At use-site:
if (comptime wasm_2_0_enabled) {
    ext_bulk_memory.register(&g_dispatch_table_storage);
}
```

The `else struct {}` for the import keeps the type comptime-resolved when
disabled, so the `if` branch doesn't reference a missing symbol.

## Why this surfaces only at exit-check time

The dispatcher's comptime filter (B79-B107 + B108-B110 inline-switch
cutover) PASSED its own unit tests because the runtime test build always
has `wasm_level = .v3_0` (default), so the filter is inactive in tests.
The DCE leak only manifests in `-Dwasm=v1_0` BUILDS, which `test-all`
doesn't exercise. It surfaces at `scripts/check_build_dce.sh --gate` time.

Lesson for future Phase work: any DCE-axis substrate change must include
the build-option-matrix gate in its exit criterion, not just the default
build's tests.

## The B109 multi-tag-arm regression (separate failure mode)

Independently of D-150, the B109 dead-arm prune script removed the
combined `.select, .select_typed => try op_alu_int.emitSelectCtx(&ctx,
&ins),` arm because the body matched the Ctx-call pattern. But only
`.select` was in `collected_x86_64_ctx_ops`; `.select_typed` lacked a
Zone 1 meta file (per B70 deferral).

The mechanical prune script didn't audit each constituent of multi-tag
arms — a class of regression now codified in `.claude/rules/bug_fix_
survey.md` item 2 (Multi-tag arm audit) and re-applicable to future
inline-switch refactors.

## Mac vs Linux cross-arch invisibility

Mac aarch64 test-all PASSED the B109 broken state because Mac uses
`arm64/emit.zig` for compile path, NOT `x86_64/emit.zig`. The ubuntu
x86_64 test caught it via spec-wasm-2-0-assert / select.0.wasm. This is
a structural reminder: arch-specific emit changes need arch-specific
testing — Mac coverage of x86_64 emit.zig is fundamentally limited
without cross-compile.

## When this lesson dissolves

- If future inline-switch cutovers do not also touch use-sites in
  parallel layers, the coupling no longer applies (different problem
  shape).
- If `check_build_dce.sh` is wired into the per-chunk gate (currently
  it's exit-criterion-only), the leak would be caught earlier.

## Related

- ADR-0073 (build-option DCE substrate).
- ADR-0075 (x86_64 EmitCtx ctx-passing unification).
- B109 commit `3591fa57` + fix commit `6d89236e` (regression case study).
- B112 commit `59bde111` (D-150 closure with use-site gating pattern).
- `.claude/rules/bug_fix_survey.md` item 2 (Multi-tag arm audit).
- ROADMAP §9.12-B exit criterion.
