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
//! `thunk0_<ret>[K]` hardcodes its slot index K (comptime), reads
//! `rt.host_payloads_base[K]` for the `*HostFuncPayload`, calls the callback,
//! and on a returned trap sets `rt.trap_flag` (the JIT epilogue's post-call
//! check raises it as a guest trap — same path as WASI's `defaultTrap`).
//!
//! Increment 1 (D-478) covers **0-arg → {void, i32}**. Wider arities / FP /
//! ref results follow; uncovered signatures are rejected at JIT instantiate
//! (`instance.zig` → `.interp` fallback), never silently mis-dispatched.
//!
//! Zone 3 (`src/api/`): touches `HostFuncPayload` + the `wasm_val_t` ABI. Only
//! the planted fn-ptr (an opaque `usize`) crosses into Zone 2 setup.

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
/// Each table is `MAX_HOST_SLOTS` fn pointers (≈512 B per table); a module with
/// more host-func imports than this falls back to `.interp` at instantiate.
pub const MAX_HOST_SLOTS = 64;

/// Mark the JIT runtime trapped (the callback returned a trap, or the payload
/// is malformed). The JIT epilogue reads `trap_flag` after the dispatched call
/// and unwinds; the returned sentinel value is discarded.
fn trapResult(rt: *JitRuntime, comptime Ret: type) Ret {
    rt.trap_flag = 1;
    rt.trap_kind = 1; // generic (the host callback's own trap detail is consumed)
    return switch (Ret) {
        void => {},
        else => 0,
    };
}

fn marshalRet(v: Val, comptime Ret: type) Ret {
    return switch (Ret) {
        void => {},
        i32 => v.of.i32,
        i64 => v.of.i64,
        f32 => v.of.f32,
        f64 => v.of.f64,
        else => @compileError("unsupported host-bridge result type"),
    };
}

/// Generic 0-arg host-call bridge. `idx` is the func-import slot (the thunk
/// hardcodes it). Reads the payload, invokes the embedder callback with an
/// empty args vec + a single result slot, and returns the native result.
fn bridge0(rt: *JitRuntime, idx: usize, comptime Ret: type) Ret {
    const base = rt.host_payloads_base orelse return trapResult(rt, Ret);
    const payload: *HostFuncPayload = @ptrFromInt(base[idx]);
    var res_storage: [1]Val = .{.{ .kind = .i32, .of = .{ .i32 = 0 } }};
    const nr = payload.results.len;
    var args_vec: ValVec = .{ .size = 0, .data = null };
    var res_vec: ValVec = .{ .size = nr, .data = if (nr > 0) &res_storage else null };
    const trap: ?*Trap =
        if (payload.callback_env) |cb|
            cb(payload.env, &args_vec, &res_vec)
        else if (payload.callback) |cb|
            cb(&args_vec, &res_vec)
        else
            return trapResult(rt, Ret);
    if (trap) |tr| {
        trap_surface.wasm_trap_delete(tr); // consume the callback's owned trap
        return trapResult(rt, Ret);
    }
    return marshalRet(res_storage[0], Ret);
}

fn make0(comptime idx: usize, comptime Ret: type) *const fn (*JitRuntime) callconv(.c) Ret {
    return &struct {
        fn t(rt: *JitRuntime) callconv(.c) Ret {
            return bridge0(rt, idx, Ret);
        }
    }.t;
}

fn table0(comptime Ret: type) [MAX_HOST_SLOTS]*const fn (*JitRuntime) callconv(.c) Ret {
    var arr: [MAX_HOST_SLOTS]*const fn (*JitRuntime) callconv(.c) Ret = undefined;
    for (0..MAX_HOST_SLOTS) |k| arr[k] = make0(k, Ret);
    return arr;
}

const thunk0_i32 = table0(i32);
const thunk0_void = table0(void);

/// The dispatch fn-ptr (as a raw `usize`, planted into `host_dispatch_base[idx]`)
/// for a host-func import of signature `(params)->(results)` at func-import slot
/// `idx`, or null if the bridge does not cover this signature (caller rejects
/// the JIT instantiate → `.interp`). Increment 1: 0-arg → {void, i32} only.
pub fn dispatchPtrFor(params: []const zir.ValType, results: []const zir.ValType, idx: usize) ?usize {
    if (params.len != 0) return null; // 0-arg only this increment
    if (idx >= MAX_HOST_SLOTS) return null;
    if (results.len == 0) return @intFromPtr(thunk0_void[idx]);
    if (results.len == 1) return switch (results[0]) {
        .i32 => @intFromPtr(thunk0_i32[idx]),
        else => null, // i64/f32/f64 0-arg deferred to the next increment
    };
    return null;
}
