//! D-478 — generic host-func dispatch bridge for the JIT path.
//!
//! A JIT-compiled guest's `call <import_idx>` lowers to `LDR X16,
//! [host_dispatch_base + idx*8]; BLR X16`, invoking the slot as a native
//! `fn(rt: *JitRuntime, ...wasm_args) callconv(.c) <ret>`. WASI imports plant a
//! hand-written C-ABI thunk (`wasi/jit_dispatch.zig`); an EMBEDDER host func
//! (`wasm_func_new`) needs a thunk that marshals the native call into the
//! `WasmFuncCallback` ABI (`args:*ValVec, results:*ValVec`).
//!
//! Rather than emit per-arch reg-marshalling stubs, this plants a **Zig
//! comptime-generated thunk** whose calling convention Zig itself lowers —
//! arch-independent (no arm64/x86_64/Win64 codegen, no Rosetta verification).
//! `thunkN_<ret>[K]` hardcodes its slot index K (comptime), reads
//! `rt.host_payloads_base[K]` for the `*HostFuncPayload`, calls the callback,
//! and on a returned trap sets `rt.trap_flag` (the JIT epilogue's post-call
//! check raises it as a guest trap — same path as WASI's `defaultTrap`).
//!
//! **GP-scalar collapse**: i32 and i64 wasm args both occupy a single integer
//! arg register, so a thunk declaring `u64` params receives BOTH correctly; the
//! bridge marshals each per `payload.params[i]` (i32 → low 32 bits). This avoids
//! a per-arg-type table — coverage is (arity 0..4 × result {void,i32,i64} ×
//! slot). FP args/results (f32/f64) live in a SEPARATE register class and need
//! positionally-typed thunks (a later increment); a signature with any FP /
//! v128 / ref / >4 args is rejected at JIT instantiate (`instance.zig` →
//! `.interp` fallback), never silently mis-dispatched.
//!
//! Zone 3 (`src/api/`): touches `HostFuncPayload` + the `wasm_val_t` ABI. Only
//! the planted fn-ptr (an opaque `usize`) crosses into Zone 2 setup.

const std = @import("std");

const jit_abi = @import("../engine/codegen/shared/jit_abi.zig");
const handles = @import("handles.zig");
const vec = @import("vec.zig");
const trap_surface = @import("trap_surface.zig");
const zir = @import("../ir/zir.zig");

const JitRuntime = jit_abi.JitRuntime;
const HostFuncPayload = handles.HostFuncPayload;
const Val = handles.Val;
const ValVec = vec.ValVec;
const Trap = trap_surface.Trap;

/// Bound on the func-import slot count a host-bridge thunk table can serve.
/// A module with more host-func imports than this falls back to `.interp` at
/// instantiate.
pub const MAX_HOST_SLOTS = 64;

/// Max host-func arity the GP-scalar bridge covers (≤4 keeps every arg in a
/// register on each ABI; >4 would stack-spill and is rejected → `.interp`).
const MAX_ARITY = 4;

/// Result kinds the bridge covers. FP / v128 / ref results are uncovered.
const RetKind = enum { void, i32, i64 };

fn RT(comptime r: RetKind) type {
    return switch (r) {
        .void => void,
        .i32 => i32,
        .i64 => i64,
    };
}

fn retKind(results: []const zir.ValType) ?RetKind {
    if (results.len == 0) return .void;
    if (results.len != 1) return null;
    return switch (results[0]) {
        .i32 => .i32,
        .i64 => .i64,
        .f32, .f64, .v128, .ref => null, // uncovered → caller falls back to .interp
    };
}

fn isGP(vt: zir.ValType) bool {
    return vt == .i32 or vt == .i64;
}

/// Marshal one integer-register arg into a `wasm_val_t` per its wasm type.
fn gpToVal(vt: zir.ValType, bits: u64) Val {
    return switch (vt) {
        .i64 => .{ .kind = .i64, .of = .{ .i64 = @bitCast(bits) } },
        // i32 occupies the low 32 bits of the GP register.
        .i32 => .{ .kind = .i32, .of = .{ .i32 = @bitCast(@as(u32, @truncate(bits))) } },
        .f32, .f64, .v128, .ref => unreachable, // dispatchPtrFor rejects non-GP params
    };
}

/// Mark the JIT runtime trapped; the epilogue's post-call check unwinds and the
/// returned sentinel is discarded.
fn trapResult(rt: *JitRuntime, comptime r: RetKind) RT(r) {
    rt.trap_flag = 1;
    rt.trap_kind = 1; // generic (the host callback's own trap detail is consumed)
    return switch (r) {
        .void => {},
        .i32 => 0,
        .i64 => 0,
    };
}

fn marshalRet(v: Val, comptime r: RetKind) RT(r) {
    return switch (r) {
        .void => {},
        .i32 => v.of.i32,
        .i64 => v.of.i64,
    };
}

/// Generic host-call bridge. `idx` is the func-import slot (the thunk hardcodes
/// it); `gp_args` are the integer-register args in guest order. Reads the
/// payload, invokes the embedder callback, returns the native result.
fn bridge(rt: *JitRuntime, idx: usize, gp_args: []const u64, comptime r: RetKind) RT(r) {
    const base = rt.host_payloads_base orelse return trapResult(rt, r);
    const payload: *HostFuncPayload = @ptrFromInt(base[idx]);
    if (payload.params.len != gp_args.len) return trapResult(rt, r); // arity invariant
    var argbuf: [MAX_ARITY]Val = undefined;
    for (0..gp_args.len) |i| argbuf[i] = gpToVal(payload.params[i], gp_args[i]);

    var res_storage: [1]Val = .{.{ .kind = .i32, .of = .{ .i32 = 0 } }};
    const nr = payload.results.len;
    var args_vec: ValVec = .{ .size = gp_args.len, .data = if (gp_args.len > 0) &argbuf else null };
    var res_vec: ValVec = .{ .size = nr, .data = if (nr > 0) &res_storage else null };
    const trap: ?*Trap =
        if (payload.callback_env) |cb|
            cb(payload.env, &args_vec, &res_vec)
        else if (payload.callback) |cb|
            cb(&args_vec, &res_vec)
        else
            return trapResult(rt, r);
    if (trap) |tr| {
        trap_surface.wasm_trap_delete(tr); // consume the callback's owned trap
        return trapResult(rt, r);
    }
    return marshalRet(res_storage[0], r);
}

// Per-arity thunk generators. Each declares EXACTLY N `u64` params so the C ABI
// arg count matches the JIT call site; `K` (slot) is hardcoded comptime.
fn t0(comptime K: usize, comptime r: RetKind) *const fn (*JitRuntime) callconv(.c) RT(r) {
    return &struct {
        fn f(rt: *JitRuntime) callconv(.c) RT(r) {
            return bridge(rt, K, &.{}, r);
        }
    }.f;
}
fn t1(comptime K: usize, comptime r: RetKind) *const fn (*JitRuntime, u64) callconv(.c) RT(r) {
    return &struct {
        fn f(rt: *JitRuntime, a0: u64) callconv(.c) RT(r) {
            const a = [_]u64{a0};
            return bridge(rt, K, &a, r);
        }
    }.f;
}
fn t2(comptime K: usize, comptime r: RetKind) *const fn (*JitRuntime, u64, u64) callconv(.c) RT(r) {
    return &struct {
        fn f(rt: *JitRuntime, a0: u64, a1: u64) callconv(.c) RT(r) {
            const a = [_]u64{ a0, a1 };
            return bridge(rt, K, &a, r);
        }
    }.f;
}
fn t3(comptime K: usize, comptime r: RetKind) *const fn (*JitRuntime, u64, u64, u64) callconv(.c) RT(r) {
    return &struct {
        fn f(rt: *JitRuntime, a0: u64, a1: u64, a2: u64) callconv(.c) RT(r) {
            const a = [_]u64{ a0, a1, a2 };
            return bridge(rt, K, &a, r);
        }
    }.f;
}
fn t4(comptime K: usize, comptime r: RetKind) *const fn (*JitRuntime, u64, u64, u64, u64) callconv(.c) RT(r) {
    return &struct {
        fn f(rt: *JitRuntime, a0: u64, a1: u64, a2: u64, a3: u64) callconv(.c) RT(r) {
            const a = [_]u64{ a0, a1, a2, a3 };
            return bridge(rt, K, &a, r);
        }
    }.f;
}

fn Table(comptime Fn: type) type {
    return [MAX_HOST_SLOTS]Fn;
}
fn buildTable(comptime gen: anytype, comptime r: RetKind) Table(@TypeOf(gen(0, r))) {
    var arr: Table(@TypeOf(gen(0, r))) = undefined;
    for (0..MAX_HOST_SLOTS) |k| arr[k] = gen(k, r);
    return arr;
}

/// Raw fn-ptr (as `usize`) for the arity-`N` thunk of result kind `r` at slot
/// `idx`. `gen` is the per-arity thunk generator.
fn ptrFor(comptime gen: anytype, r: RetKind, idx: usize) usize {
    inline for (std.meta.fields(RetKind)) |rf| {
        if (r == @field(RetKind, rf.name)) {
            const tab = comptime buildTable(gen, @field(RetKind, rf.name));
            return @intFromPtr(tab[idx]);
        }
    }
    unreachable;
}

/// The dispatch fn-ptr (as a raw `usize`, planted into `host_dispatch_base[idx]`)
/// for a host-func import of signature `(params)->(results)` at func-import slot
/// `idx`, or null if the bridge does not cover this signature (caller rejects
/// the JIT instantiate → `.interp`). Covers: 0..4 GP-scalar (i32/i64) args with
/// a {void, i32, i64} result. Any FP/v128/ref param or result, or >4 args → null.
pub fn dispatchPtrFor(params: []const zir.ValType, results: []const zir.ValType, idx: usize) ?usize {
    if (idx >= MAX_HOST_SLOTS) return null;
    if (params.len > MAX_ARITY) return null;
    for (params) |p| if (!isGP(p)) return null;
    const r = retKind(results) orelse return null;
    return switch (params.len) {
        0 => ptrFor(t0, r, idx),
        1 => ptrFor(t1, r, idx),
        2 => ptrFor(t2, r, idx),
        3 => ptrFor(t3, r, idx),
        4 => ptrFor(t4, r, idx),
        else => null,
    };
}
