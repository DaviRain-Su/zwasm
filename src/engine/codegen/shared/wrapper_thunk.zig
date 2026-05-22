//! Buffer-write entry wrapper thunk (ADR-0106 cycle 3e
//! foundation).
//!
//! Per the cycle 3e design spike at
//! `private/spikes/adr-0106-cycle3e-call-lowering/SPIKE.md`
//! §"REVISED APPROACH", the cycle 3e implementation pivots
//! from "in-body buffer_write epilogue" to "per-function
//! wrapper thunk":
//!
//! - **Function body**: unchanged, compiled with default
//!   `.register_write` epilogue. Intra-module dispatch
//!   (Wasm `call N` / `call_indirect`) routes through
//!   `funcptr_base[i]` = body address, preserving register
//!   convention internally.
//! - **Wrapper thunk** (this file): a JIT-emitted machine-
//!   code thunk per multi-result function. Zig-side
//!   signature `fn(rt, results, args) callconv(.c) ErrCode`
//!   — single u32 return, no hidden RCX pointer issue on
//!   Win64. Internally calls the function body via raw
//!   assembly (no `callconv(.c)` at the internal call →
//!   no Win64 ABI rules → no struct-return ABI mismatch).
//!
//! Per-arch emit primitives are stubs in this commit; cycle
//! 3e Phase 2' implements them. This file provides the
//! type foundation + the `EmitParams` shape so subsequent
//! cycles have a stable callsite contract.
//!
//! Zone 2 (`src/engine/codegen/shared/`) — same as
//! `entry_buffer_write.zig` + `result_abi.zig`.

const std = @import("std");
const builtin = @import("builtin");

const jit_abi = @import("jit_abi.zig");
const FuncType = @import("../../../ir/zir.zig").FuncType;

/// Wrapper thunk emit parameters. The caller (cycle 3e
/// `compileWasm` + linker) builds this per multi-result
/// function it wants to wrap.
pub const EmitParams = struct {
    /// Wasm function signature — params + results define
    /// how the wrapper loads args from `[R8/RDX/X2 + 8*i]`
    /// and stores results to `[RDX/RSI/X1 + 8*i]`.
    sig: FuncType,
    /// Byte offset of the function body within the linker's
    /// linked code blob. The wrapper's internal CALL/BL
    /// reaches this address (PC-relative on arm64, RIP-
    /// relative + indirect on x86_64).
    body_offset: u32,
    /// Self-offset where the wrapper itself lives within
    /// the linked code blob. Needed to compute the
    /// body_offset - thunk_offset displacement for the
    /// internal CALL/BL.
    thunk_offset: u32,
};

/// Per-arch emit result.
pub const EmitOutput = struct {
    /// Wrapper thunk machine-code bytes.
    bytes: []const u8,
};

/// Emit a wrapper thunk for the given function. Per-arch
/// dispatch happens here; the implementation is platform-
/// specific bytes-emit per the calling convention.
///
/// CYCLE 3e STATUS: stub returning Error.UnsupportedOp. The
/// actual emit logic for x86_64 + arm64 lands in Phase 2'
/// per the spike doc. This file provides the type + public
/// API foundation so callers + tests have a stable shape.
pub const Error = error{
    /// The function shape isn't supported by this arch's
    /// wrapper emit. Cycle 3e Phase 2' replaces this with
    /// the actual per-shape emit.
    UnsupportedOp,
    /// Allocator out of memory during byte buffer growth.
    OutOfMemory,
};

/// Emit a wrapper thunk for the given function. Per-arch
/// dispatch based on `builtin.cpu.arch` + `builtin.os.tag`.
///
/// CYCLE 3e Phase 2' (incremental): the only shape covered
/// in this commit is **x86_64 SysV, 3-int-result MEMORY-
/// class** (the `() → (i32, i32, i32)` SKIP arm shape).
/// Other shapes still return UnsupportedOp; subsequent
/// cycles add them per [`SPIKE.md`](../../../../private/spikes/adr-0106-cycle3e-call-lowering/SPIKE.md).
///
/// 3-int-result MEMORY-class wrapper (SysV) shape:
///
/// ```text
///     ; Wrapper entry (Zig caller passed: RDI=rt, RSI=results, RDX=args).
///     ; Body expects MEMORY-class layout: RDI=&result_buf, RSI=rt.
///     ; Args are 0 (the 3 SKIP-arm shapes all have empty params).
///     XCHG RDI, RSI            ; 48 87 FE  (3 bytes)
///     CALL body_offset         ; E8 d0 d1 d2 d3   (5 bytes; rel32 disp)
///     XOR EAX, EAX             ; 31 C0  (2 bytes; ErrCode_OK)
///     RET                      ; C3  (1 byte)
/// ```
///
/// Total: 11 bytes. Body writes 3 i32 results to
/// `[RDI+0/4/8]` directly via the MEMORY-class epilogue
/// (cycle-2c implementation); since RDI=results-buf for
/// us, the body fills the caller's buffer naturally.
///
/// Stack alignment: wrapper entry has RSP ≡ 8 (mod 16) per
/// SysV (after caller's CALL pushed return address). XCHG
/// doesn't change RSP. Wrapper's CALL pushes its own return
/// → body entry has RSP ≡ 0 (mod 16) which is SysV-correct
/// (body's PUSH RBP brings it back to ≡ 8).
pub fn emit(
    allocator: std.mem.Allocator,
    params: EmitParams,
) Error!EmitOutput {
    if (builtin.cpu.arch != .x86_64 or builtin.os.tag == .windows) {
        return Error.UnsupportedOp;
    }
    // Only the 3-int-result MEMORY-class shape covered here;
    // other shapes deferred to subsequent Phase 2' chunks.
    if (params.sig.params.len != 0) return Error.UnsupportedOp;
    if (params.sig.results.len != 3) return Error.UnsupportedOp;
    for (params.sig.results) |r| {
        if (r != .i32) return Error.UnsupportedOp;
    }

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);

    // XCHG RDI, RSI — 48 87 FE
    try bytes.appendSlice(allocator, &.{ 0x48, 0x87, 0xFE });
    // CALL rel32 — E8 + 32-bit displacement = body_offset - (thunk_offset + 4 + 4)
    // (the displacement is from the instruction AFTER the CALL).
    const call_site_after: i64 = @as(i64, @intCast(params.thunk_offset)) + 3 + 5;
    const disp: i32 = @intCast(@as(i64, @intCast(params.body_offset)) - call_site_after);
    try bytes.append(allocator, 0xE8);
    var disp_bytes: [4]u8 = undefined;
    std.mem.writeInt(i32, &disp_bytes, disp, .little);
    try bytes.appendSlice(allocator, &disp_bytes);
    // XOR EAX, EAX — 31 C0
    try bytes.appendSlice(allocator, &.{ 0x31, 0xC0 });
    // RET — C3
    try bytes.append(allocator, 0xC3);

    return .{ .bytes = try bytes.toOwnedSlice(allocator) };
}

const testing = std.testing;

test "wrapper_thunk: EmitParams + EmitOutput types present" {
    // Compile-time sanity: the types exist and have the
    // expected fields. Once Phase 2' lands, additional
    // tests verify byte-sequence correctness per arch.
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &.{} },
        .body_offset = 0,
        .thunk_offset = 0,
    };
    _ = params;
}

test "wrapper_thunk: emit returns UnsupportedOp for 0-result sig" {
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &.{} },
        .body_offset = 0,
        .thunk_offset = 0,
    };
    const r = emit(testing.allocator, params);
    try testing.expectError(Error.UnsupportedOp, r);
}

test "wrapper_thunk: emit x86_64 SysV 3-int-result MEMORY-class (11 bytes)" {
    if (builtin.cpu.arch != .x86_64 or builtin.os.tag == .windows) {
        return error.SkipZigTest;
    }
    const i32_results = [_]@TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32)){ .i32, .i32, .i32 };
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &i32_results },
        .body_offset = 100,
        .thunk_offset = 50,
    };
    const out = try emit(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 11), out.bytes.len);
    // XCHG RDI, RSI
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x87, 0xFE }, out.bytes[0..3]);
    // CALL opcode
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[3]);
    // disp32 = body_offset(100) - (thunk_offset(50) + 3 + 5) = 42
    const disp = std.mem.readInt(i32, out.bytes[4..8], .little);
    try testing.expectEqual(@as(i32, 42), disp);
    // XOR EAX, EAX + RET
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[8..11]);
}

// Reference jit_abi so the import survives `zig build test`
// even though Phase 2' is the consumer.
comptime {
    _ = jit_abi;
    _ = builtin;
}
