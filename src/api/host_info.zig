//! `host_info` accessor surface of the C ABI binding — the
//! `WASM_DECLARE_REF_BASE` trio (`wasm_X_get_host_info` /
//! `_set_host_info` / `_set_host_info_with_finalizer`) for the entity
//! handles `Func` / `Global` / `Table` / `Memory` / `Ref` / `Extern`.
//!
//! host_info lets a C host attach/retrieve its own opaque pointer to an
//! object (+ a finalizer fired when the object is deleted). The two storage
//! fields (`host_info` + `host_info_finalizer`) live on each handle struct in
//! `handles.zig`; the finalizer is fired in each `wasm_X_delete` (instance.zig).
//! `wasm_foreign_*` host_info (the same shape) predates this and stays in
//! `extern_new.zig`; `wasm_{instance,module,trap}_*_host_info` are a separate
//! follow-up (Instance host_info needs a Zone decision — it is a `runtime.*`
//! alias, not a Zone-3 handle).
//!
//! Zone 3 (`src/api/`); re-exported via `api/wasm.zig`.

const std = @import("std");
const testing = std.testing;

const handles = @import("handles.zig");
const zir = @import("../ir/zir.zig");
const instance = @import("instance.zig");
const trap_surface = @import("trap_surface.zig");
// test-only: exercise finalizer-fires-on-delete via a standalone object.
const extern_new = @import("extern_new.zig");
const types = @import("types.zig");

const Finalizer = ?*const fn (?*anyopaque) callconv(.c) void;

// Generic accessors — uniform across every handle struct carrying the
// `host_info` + `host_info_finalizer` field pair.

fn getHostInfo(comptime T: type, h: ?*const T) ?*anyopaque {
    return (h orelse return null).host_info;
}

fn setHostInfo(comptime T: type, h: ?*T, info: ?*anyopaque) void {
    const handle = h orelse return;
    handle.host_info = info;
    handle.host_info_finalizer = null;
}

fn setHostInfoFin(comptime T: type, h: ?*T, info: ?*anyopaque, fin: Finalizer) void {
    const handle = h orelse return;
    handle.host_info = info;
    handle.host_info_finalizer = fin;
}

pub export fn wasm_func_get_host_info(h: ?*const handles.Func) callconv(.c) ?*anyopaque {
    return getHostInfo(handles.Func, h);
}
pub export fn wasm_func_set_host_info(h: ?*handles.Func, info: ?*anyopaque) callconv(.c) void {
    setHostInfo(handles.Func, h, info);
}
pub export fn wasm_func_set_host_info_with_finalizer(h: ?*handles.Func, info: ?*anyopaque, fin: Finalizer) callconv(.c) void {
    setHostInfoFin(handles.Func, h, info, fin);
}

pub export fn wasm_global_get_host_info(h: ?*const handles.Global) callconv(.c) ?*anyopaque {
    return getHostInfo(handles.Global, h);
}
pub export fn wasm_global_set_host_info(h: ?*handles.Global, info: ?*anyopaque) callconv(.c) void {
    setHostInfo(handles.Global, h, info);
}
pub export fn wasm_global_set_host_info_with_finalizer(h: ?*handles.Global, info: ?*anyopaque, fin: Finalizer) callconv(.c) void {
    setHostInfoFin(handles.Global, h, info, fin);
}

pub export fn wasm_table_get_host_info(h: ?*const handles.Table) callconv(.c) ?*anyopaque {
    return getHostInfo(handles.Table, h);
}
pub export fn wasm_table_set_host_info(h: ?*handles.Table, info: ?*anyopaque) callconv(.c) void {
    setHostInfo(handles.Table, h, info);
}
pub export fn wasm_table_set_host_info_with_finalizer(h: ?*handles.Table, info: ?*anyopaque, fin: Finalizer) callconv(.c) void {
    setHostInfoFin(handles.Table, h, info, fin);
}

pub export fn wasm_memory_get_host_info(h: ?*const handles.Memory) callconv(.c) ?*anyopaque {
    return getHostInfo(handles.Memory, h);
}
pub export fn wasm_memory_set_host_info(h: ?*handles.Memory, info: ?*anyopaque) callconv(.c) void {
    setHostInfo(handles.Memory, h, info);
}
pub export fn wasm_memory_set_host_info_with_finalizer(h: ?*handles.Memory, info: ?*anyopaque, fin: Finalizer) callconv(.c) void {
    setHostInfoFin(handles.Memory, h, info, fin);
}

pub export fn wasm_ref_get_host_info(h: ?*const handles.Ref) callconv(.c) ?*anyopaque {
    return getHostInfo(handles.Ref, h);
}
pub export fn wasm_ref_set_host_info(h: ?*handles.Ref, info: ?*anyopaque) callconv(.c) void {
    setHostInfo(handles.Ref, h, info);
}
pub export fn wasm_ref_set_host_info_with_finalizer(h: ?*handles.Ref, info: ?*anyopaque, fin: Finalizer) callconv(.c) void {
    setHostInfoFin(handles.Ref, h, info, fin);
}

pub export fn wasm_extern_get_host_info(h: ?*const handles.Extern) callconv(.c) ?*anyopaque {
    return getHostInfo(handles.Extern, h);
}
pub export fn wasm_extern_set_host_info(h: ?*handles.Extern, info: ?*anyopaque) callconv(.c) void {
    setHostInfo(handles.Extern, h, info);
}
pub export fn wasm_extern_set_host_info_with_finalizer(h: ?*handles.Extern, info: ?*anyopaque, fin: Finalizer) callconv(.c) void {
    setHostInfoFin(handles.Extern, h, info, fin);
}

pub export fn wasm_module_get_host_info(h: ?*const instance.Module) callconv(.c) ?*anyopaque {
    return getHostInfo(instance.Module, h);
}
pub export fn wasm_module_set_host_info(h: ?*instance.Module, info: ?*anyopaque) callconv(.c) void {
    setHostInfo(instance.Module, h, info);
}
pub export fn wasm_module_set_host_info_with_finalizer(h: ?*instance.Module, info: ?*anyopaque, fin: Finalizer) callconv(.c) void {
    setHostInfoFin(instance.Module, h, info, fin);
}

pub export fn wasm_trap_get_host_info(h: ?*const trap_surface.Trap) callconv(.c) ?*anyopaque {
    return getHostInfo(trap_surface.Trap, h);
}
pub export fn wasm_trap_set_host_info(h: ?*trap_surface.Trap, info: ?*anyopaque) callconv(.c) void {
    setHostInfo(trap_surface.Trap, h, info);
}
pub export fn wasm_trap_set_host_info_with_finalizer(h: ?*trap_surface.Trap, info: ?*anyopaque, fin: Finalizer) callconv(.c) void {
    setHostInfoFin(trap_surface.Trap, h, info, fin);
}

test "host_info trio: get/set/set_with_finalizer across all 6 handle types + null discipline" {
    var marker: u8 = 0;
    const fin = struct {
        fn f(_: ?*anyopaque) callconv(.c) void {
            // no-op: this test only checks set_with_finalizer stores it.
        }
    }.f;

    var func: handles.Func = .{ .instance = null, .func_idx = 0 };
    try testing.expect(wasm_func_get_host_info(&func) == null);
    wasm_func_set_host_info(&func, &marker);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&marker)), wasm_func_get_host_info(&func));
    wasm_func_set_host_info_with_finalizer(&func, &marker, fin);
    try testing.expect(func.host_info_finalizer != null);
    wasm_func_set_host_info(&func, null); // clears finalizer
    try testing.expect(func.host_info_finalizer == null);

    var glob: handles.Global = .{ .instance = null, .global_idx = 0, .valtype = .i32, .mutable = false };
    wasm_global_set_host_info(&glob, &marker);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&marker)), wasm_global_get_host_info(&glob));

    var tbl: handles.Table = .{ .instance = null, .elem_type = zir.ValType.funcref, .min = 0, .max = null };
    wasm_table_set_host_info_with_finalizer(&tbl, &marker, fin);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&marker)), wasm_table_get_host_info(&tbl));

    var mem: handles.Memory = .{ .instance = null };
    wasm_memory_set_host_info(&mem, &marker);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&marker)), wasm_memory_get_host_info(&mem));

    var rf: handles.Ref = .{ .instance = null, .ref = 0 };
    wasm_ref_set_host_info(&rf, &marker);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&marker)), wasm_ref_get_host_info(&rf));

    var ext: handles.Extern = .{ .kind = .func, .instance = null };
    wasm_extern_set_host_info(&ext, &marker);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&marker)), wasm_extern_get_host_info(&ext));

    var mod: instance.Module = .{ .store = null, .bytes_ptr = null, .bytes_len = 0 };
    wasm_module_set_host_info(&mod, &marker);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&marker)), wasm_module_get_host_info(&mod));

    var trap: trap_surface.Trap = .{ .store = null, .kind = .unreachable_, .message_ptr = null, .message_len = 0 };
    wasm_trap_set_host_info_with_finalizer(&trap, &marker, fin);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(&marker)), wasm_trap_get_host_info(&trap));

    // null discipline (get → null; set → no crash).
    try testing.expect(wasm_func_get_host_info(null) == null);
    wasm_func_set_host_info(null, &marker);
    wasm_extern_set_host_info_with_finalizer(null, &marker, fin);
}

fn markFired(info: ?*anyopaque) callconv(.c) void {
    if (info) |p| @as(*bool, @ptrCast(@alignCast(p))).* = true;
}

test "host_info finalizer fires on delete (standalone memory)" {
    const e = instance.wasm_engine_new() orelse return error.EngineAllocFailed;
    defer instance.wasm_engine_delete(e);
    const s = instance.wasm_store_new(e) orelse return error.StoreAllocFailed;
    defer instance.wasm_store_delete(s);
    var lim: types.Limits = .{ .min = 1, .max = 0xffff_ffff };
    const mt = types.wasm_memorytype_new(&lim) orelse return error.MemTypeAllocFailed;
    defer types.wasm_memorytype_delete(mt); // wasm_memory_new only reads it
    const mem = extern_new.wasm_memory_new(s, mt) orelse return error.MemoryAllocFailed;

    var fired = false;
    wasm_memory_set_host_info_with_finalizer(mem, &fired, markFired);
    instance.wasm_memory_delete(mem);
    try testing.expect(fired);
}
