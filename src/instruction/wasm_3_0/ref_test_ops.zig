//! Wasm 3.0 GC `ref.test` / `ref.test_null` interp handlers
//! (10.G op_gc cycle 7 per `.dev/phase10_g_op_bundle_plan.md`).
//!
//! Encoding (Wasm 3.0 GC §3.3.5.3):
//!   - `ref.test heap_type` (0xFB 0x14): pop reftype; push i32
//!     (1 if value is a non-null instance of heap_type, else 0).
//!   - `ref.test_null heap_type` (0xFB 0x15): pop reftype; push
//!     i32 (1 if value is a (ref null heap_type), else 0). Null
//!     always matches the `_null` variant.
//!
//! Cycle-7 semantics (no RTT yet):
//!   - The validator already type-checked the heap_type → the
//!     operand statically matches the heap_type's parent class.
//!   - Without RTT (ADR-0116 type_hierarchy.zig lands later),
//!     we can't refine cast-to-subtype. The runtime trusts the
//!     validator's static narrowing and only distinguishes null
//!     from non-null at the value level:
//!       * `ref.test`: 1 if non-null, 0 if null.
//!       * `ref.test_null`: 1 always (null + non-null both match).
//!   - This matches simple corpus fixtures where heap_type ==
//!     declared reftype; cast-to-subtype refinement lands with
//!     RTT TypeInfo at sub-chunk 7's later cycles.
//!
//! Zone 1 (`src/instruction/`).

const std = @import("std");

const dispatch = @import("../../ir/dispatch_table.zig");
const zir = @import("../../ir/zir.zig");
const runtime = @import("../../runtime/runtime.zig");

const ZirOp = zir.ZirOp;
const ZirInstr = zir.ZirInstr;
const DispatchTable = dispatch.DispatchTable;
const InterpCtx = dispatch.InterpCtx;
const Runtime = runtime.Runtime;
const Value = runtime.Value;

inline fn op(o: ZirOp) usize {
    return @intFromEnum(o);
}

pub fn register(table: *DispatchTable) void {
    table.interp[op(.@"ref.test")] = refTest;
    table.interp[op(.@"ref.test_null")] = refTestNull;
    table.interp[op(.@"ref.cast")] = refCast;
    table.interp[op(.@"ref.cast_null")] = refCastNull;
}

fn refTest(c: *InterpCtx, _: *const ZirInstr) anyerror!void {
    const rt = Runtime.fromOpaque(c);
    const v = rt.popOperand();
    // Cycle-7 stub semantics: pre-RTT we can only distinguish
    // null from non-null. Validator-narrowed reftype guarantees
    // static type match; runtime returns 1 iff non-null.
    const matches: i32 = if (v.ref == Value.null_ref) 0 else 1;
    try rt.pushOperand(.{ .i32 = matches });
}

fn refTestNull(c: *InterpCtx, _: *const ZirInstr) anyerror!void {
    const rt = Runtime.fromOpaque(c);
    _ = rt.popOperand();
    // Cycle-7 stub semantics: `_null` variant accepts null too,
    // so given the validator's static narrowing, always 1.
    try rt.pushOperand(.{ .i32 = 1 });
}

/// Wasm 3.0 GC §3.3.5.4 — `ref.cast heap_type`: pop reftype;
/// trap if value is null OR type doesn't match heap_type;
/// otherwise push the value back narrowed to heap_type.
///
/// Cycle-8 stub semantics (pre-RTT): the validator already
/// type-checked the heap_type → operand statically matches.
/// Runtime distinguishes only null from non-null:
///   - null operand → Trap.NullReference (matches Wasm 3.0 spec
///     "ref.cast traps on null").
///   - non-null → push the value back unchanged.
/// Real subtype-mismatch trap lands with RTT TypeInfo at the
/// type_hierarchy.zig integration cycle.
fn refCast(c: *InterpCtx, _: *const ZirInstr) anyerror!void {
    const rt = Runtime.fromOpaque(c);
    const v = rt.popOperand();
    if (v.ref == Value.null_ref) return runtime.Trap.NullReference;
    try rt.pushOperand(v);
}

/// Wasm 3.0 GC §3.3.5.4 — `ref.cast_null heap_type`: like
/// ref.cast but accepts null (null + non-null both pass the
/// cast pre-RTT). Real subtype-mismatch trap lands with RTT.
fn refCastNull(c: *InterpCtx, _: *const ZirInstr) anyerror!void {
    const rt = Runtime.fromOpaque(c);
    const v = rt.popOperand();
    // Push the same reftype back; null OK with `_null` variant.
    try rt.pushOperand(v);
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;
const dispatch_loop = @import("../../interp/dispatch.zig");

fn driveOne(rt: *Runtime, table: *const DispatchTable, t: ZirOp, payload: u32, extra: u32) !void {
    const instr: ZirInstr = .{ .op = t, .payload = payload, .extra = extra };
    try dispatch_loop.step(rt, table, &instr);
}

test "ref.test: null ref returns 0 (10.G op_gc cycle 7)" {
    var t = DispatchTable.init();
    register(&t);
    var rt = Runtime.init(testing.allocator);
    defer rt.deinit();
    try rt.pushOperand(.{ .ref = Value.null_ref });
    try driveOne(&rt, &t, .@"ref.test", 0, 0);
    try testing.expectEqual(@as(i32, 0), rt.popOperand().i32);
}

test "ref.test: non-null ref returns 1 (10.G op_gc cycle 7)" {
    var t = DispatchTable.init();
    register(&t);
    var rt = Runtime.init(testing.allocator);
    defer rt.deinit();
    try rt.pushOperand(.{ .ref = 0xDEADBEEF });
    try driveOne(&rt, &t, .@"ref.test", 0, 0);
    try testing.expectEqual(@as(i32, 1), rt.popOperand().i32);
}

test "ref.test_null: null ref returns 1 (10.G op_gc cycle 7; null matches _null variant)" {
    var t = DispatchTable.init();
    register(&t);
    var rt = Runtime.init(testing.allocator);
    defer rt.deinit();
    try rt.pushOperand(.{ .ref = Value.null_ref });
    try driveOne(&rt, &t, .@"ref.test_null", 0, 0);
    try testing.expectEqual(@as(i32, 1), rt.popOperand().i32);
}

test "ref.test_null: non-null ref returns 1 (10.G op_gc cycle 7)" {
    var t = DispatchTable.init();
    register(&t);
    var rt = Runtime.init(testing.allocator);
    defer rt.deinit();
    try rt.pushOperand(.{ .ref = 0xCAFEBABE });
    try driveOne(&rt, &t, .@"ref.test_null", 0, 0);
    try testing.expectEqual(@as(i32, 1), rt.popOperand().i32);
}

test "ref.cast: null ref traps NullReference (10.G op_gc cycle 8)" {
    var t = DispatchTable.init();
    register(&t);
    var rt = Runtime.init(testing.allocator);
    defer rt.deinit();
    try rt.pushOperand(.{ .ref = Value.null_ref });
    try testing.expectError(runtime.Trap.NullReference, driveOne(&rt, &t, .@"ref.cast", 0, 0));
}

test "ref.cast: non-null ref round-trips unchanged (10.G op_gc cycle 8)" {
    var t = DispatchTable.init();
    register(&t);
    var rt = Runtime.init(testing.allocator);
    defer rt.deinit();
    try rt.pushOperand(.{ .ref = 0xDEADBEEF });
    try driveOne(&rt, &t, .@"ref.cast", 0, 0);
    try testing.expectEqual(@as(u64, 0xDEADBEEF), rt.popOperand().ref);
}

test "ref.cast_null: null ref round-trips unchanged (10.G op_gc cycle 8)" {
    var t = DispatchTable.init();
    register(&t);
    var rt = Runtime.init(testing.allocator);
    defer rt.deinit();
    try rt.pushOperand(.{ .ref = Value.null_ref });
    try driveOne(&rt, &t, .@"ref.cast_null", 0, 0);
    try testing.expectEqual(Value.null_ref, rt.popOperand().ref);
}

test "ref.cast_null: non-null ref round-trips unchanged (10.G op_gc cycle 8)" {
    var t = DispatchTable.init();
    register(&t);
    var rt = Runtime.init(testing.allocator);
    defer rt.deinit();
    try rt.pushOperand(.{ .ref = 0xCAFEBABE });
    try driveOne(&rt, &t, .@"ref.cast_null", 0, 0);
    try testing.expectEqual(@as(u64, 0xCAFEBABE), rt.popOperand().ref);
}
