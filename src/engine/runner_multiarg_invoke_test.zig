//! D-477 characterization tests — host→guest JIT multi-arg `--invoke`.
//!
//! Pins the CURRENT behaviour of the JIT host-invoke path before the
//! D-477 bundle generalises `wrapper_thunk.emit` to arbitrary N typed
//! args + multi/FP/ref results (findings: `.dev/d477_findings.md`):
//!
//!  - `JitInstance.invoke` handles 0-3 args / single scalar result via
//!    the shape-specific `entry.callXxx_yyy` family (runner.zig:934);
//!    4+ args → `UnsupportedEntrySignature`.
//!  - `runWasiLenient` (the CLI `--invoke` path) rejects EVERY param
//!    (runner.zig:657) — only 0-arg exports invoke under the JIT today.
//!
//! The "GAP" assertions below pin the rejects. As each Phase IV slice
//! lands, the matching reject-pin flips to a value-assertion IN THE SAME
//! COMMIT that removes the reject — so the change is always deliberate
//! and the interp oracle (the full spec suite, multi-arg pervasive) is
//! never silently diverged from. Discovered via `src/zwasm.zig`'s
//! `test {}` block. Module bytes are hand-encoded (wat2wasm-free at
//! test runtime), mirroring `runner_test.zig`.

const std = @import("std");
const testing = std.testing;

const runner = @import("runner.zig");
const JitInstance = runner.JitInstance;

// (module (func (export "add") (param i32 i32) (result i32)
//   local.get 0 local.get 1 i32.add))
const add_i32i32 = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, // magic + version
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f, // type: (i32 i32)->i32
    0x03, 0x02, 0x01, 0x00, // func: type 0
    0x07, 0x07, 0x01, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00, // export "add" func 0
    0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b, // code
};

// (module (func (export "sum4") (param i32 i32 i32 i32) (result i32)
//   local.get 0 local.get 1 i32.add local.get 2 i32.add local.get 3 i32.add))
const sum4_i32 = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x09, 0x01, 0x60, 0x04, 0x7f, 0x7f, 0x7f, 0x7f, 0x01, 0x7f, // type: (i32 i32 i32 i32)->i32
    0x03, 0x02, 0x01, 0x00,
    0x07, 0x08, 0x01, 0x04, 0x73, 0x75, 0x6d, 0x34, 0x00, 0x00, // export "sum4"
    0x0a, 0x0f, 0x01, 0x0d, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a,
    0x20, 0x02, 0x6a, 0x20, 0x03, 0x6a, 0x0b,
};

test "D-477 baseline: JitInstance.invoke 2×i32 add(2,3) → 5 (current working shape, durable)" {
    var inst = try JitInstance.init(testing.allocator, &add_i32i32);
    defer inst.deinit(testing.allocator);
    const got = try inst.invoke(testing.allocator, "add", &.{ 2, 3 });
    try testing.expectEqual(@as(?u64, 5), got);
}

test "D-477 GAP (flips in Phase IV): JitInstance.invoke 4×i32 → UnsupportedEntrySignature" {
    // runner.zig:989 "4+ args: future cycle". When the generalized thunk
    // lands, this flips to expectEqual(@as(?u64, 14), got) for sum4(2,3,4,5).
    var inst = try JitInstance.init(testing.allocator, &sum4_i32);
    defer inst.deinit(testing.allocator);
    try testing.expectError(
        runner.Error.UnsupportedEntrySignature,
        inst.invoke(testing.allocator, "sum4", &.{ 2, 3, 4, 5 }),
    );
}

test "D-477 GAP (flips in Phase IV): runWasiLenient --invoke of a 2-arg export → UnsupportedEntrySignature" {
    // runner.zig:657 — the CLI `--invoke` JIT path rejects any param today.
    // Phase IV routes it through invokeMulti/invokeBufferWrite; this flips to
    // a value-check then.
    try testing.expectError(
        runner.Error.UnsupportedEntrySignature,
        runner.runWasiLenient(testing.allocator, &add_i32i32, "add", null, null, .{}, null),
    );
}
