# Shared per-arch facade is host-dispatched; cross-arch byte tests silently mis-emit

**Date**: 2026-05-26
**Citing**: D-185 close commit `73187e6f` (this lesson backfilled).

## Observation

`src/engine/codegen/shared/frame_teardown.zig` is a facade that
dispatches on `builtin.target.cpu.arch` at comptime, picking the
per-arch sibling (`arm64/frame_teardown.zig` or `x86_64/`). The
intent: host-agnostic callers (the linker, multi-arch test
harnesses) call the facade and get the right per-arch emit
"for free".

The bug: arm64-specific emit code (`arm64/op_tail_call.zig`)
imported the shared facade, then called it from byte-snapshot
tests that run on BOTH hosts (no `if (!aarch64) skip`). On the
Linux x86_64 host:

- arm64 `compile()` runs (called explicitly from the test).
- Inside, arm64 `op_tail_call.emitIndirectReturnCall` calls
  `frame_teardown.emit(...)` via the shared facade.
- Shared facade sees `builtin.target.cpu.arch == .x86_64`
  (host arch when host==target), routes to `x86_64/
  frame_teardown` → emits `POP RBP` (1 byte) instead of
  arm64 `LDP X29, X30` (4 bytes).
- arm64 byte stream becomes mis-aligned by 1 byte. Downstream
  4-byte fixup patching (`EmitCindStub.emit`'s `@divExact`)
  panics with "exact division produced remainder".

## Why same-host e2e tests hid this for 5 cycles

The cycles 1-5 e2e fixture in `shared/linker.zig` is
host-gated to `(macos and aarch64) or (linux and x86_64)`.
On both gated hosts, the test calls the NATIVE arch
`compile()` (Mac → arm64, Linux → x86_64). In each case,
`host == target` AND the per-arch op_tail_call's facade
routes to the matching per-arch frame_teardown — correctly.

Cycle 6 introduced an arm64 byte-snapshot test
(`emit_test_call.zig`) that runs arm64 `compile()` on BOTH
hosts (no host gate — arm64 emit is host-agnostic by
design). That was the first call site exercising the
cross-arch facade routing.

## Fix

Per-arch emit code MUST import its sibling helper directly,
NOT the shared facade. The facade is for code that genuinely
doesn't know its target (host-agnostic linker dispatch).

```zig
// arm64/op_tail_call.zig
- const frame_teardown = @import("../shared/frame_teardown.zig");
+ const frame_teardown = @import("frame_teardown.zig");
```

Same for `x86_64/op_tail_call.zig`.

## Re-derivability

The diagnostic that surfaced this in one cycle: probe
`buf.items.len % 4` after each major emit step in the new
code. Mac and Linux probes were identical up to
`post-loadCalleeRt`; Linux diverged at `post-frame_teardown`
(grew by 1 byte, not 4). Single divergence step → single
suspect helper → root cause.

## Reviewer checklist (apply at PR review when arch-specific
emit imports a `shared/*` helper)

- [ ] Does the imported `shared/*` helper internally switch
      on `builtin.target.cpu.arch`?
- [ ] If yes, does the consumer have a byte-snapshot test
      that runs on a host of a DIFFERENT arch from the
      consumer's arch?
- [ ] If yes, the consumer must import the sibling
      `<arch>/<helper>.zig` directly.

## Forbidden anti-pattern

Importing `shared/<helper>.zig` from arch-specific emit
code (e.g. `arm64/foo.zig`) without verifying the shared
helper is genuinely host-agnostic. The trap: looks clean
("share the facade"), works on native-arch tests, fails
silently on cross-arch byte-snapshot tests with downstream
alignment-style panics that don't point at the import.

## Generalisation

This is one instance of the broader pattern: **arch-specific
code calling a helper that's host-dispatched at comptime**.
Other potential sites: anywhere `arm64/*.zig` imports
`shared/*.zig`. Audit candidate:

```sh
rg -l '@import\("\.\./shared/' src/engine/codegen/arm64/ src/engine/codegen/x86_64/
```

Each hit must verify the helper is genuinely host-agnostic
or be flipped to a direct sibling import.

## Related

- D-185 (closed by `73187e6f` — this lesson is the citation).
- `.claude/rules/zone_deps.md` — A3 (no cross-arch imports).
  This lesson is the dual: sibling-direct imports are
  preferred over shared-facade for arch-specific consumers.
- ADR-0112 D3 (the original tail-call design that exposed
  this).
