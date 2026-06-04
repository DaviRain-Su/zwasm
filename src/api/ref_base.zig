//! `WASM_DECLARE_REF_BASE` / `WASM_DECLARE_REF` surface — the `wasm_X_same`
//! identity tests (this file, E3b-1), and (later sub-chunks) `wasm_X_as_ref` /
//! `wasm_ref_as_X` casts + `wasm_X_copy` clones, for the entity handles
//! func / global / table / memory / extern / instance / module / trap / foreign.
//!
//! Model: ADR-0158. `same` is ENTITY identity, not pointer identity, because
//! `wasm_instance_exports` returns a fresh handle each call — two handles to the
//! same export must compare same. Instance-backed func/global/table/memory
//! compare `(instance, idx)`; standalone (host-created, no instance) compare
//! pointer identity (the handle IS the entity); instance/module/trap/foreign are
//! pointer-identity objects. `wasm_ref_same` (funcref/externref payload) stays in
//! `extern_new.zig`.
//!
//! Zone 3 (`src/api/`); re-exported via `api/wasm.zig`.

const std = @import("std");
const testing = std.testing;

const handles = @import("handles.zig");
const instance = @import("instance.zig");
const trap_surface = @import("trap_surface.zig");
const extern_new = @import("extern_new.zig");
const types = @import("types.zig"); // test-only: build types for as_ref round-trips

/// Entity identity for the instance-backed handles (func/global/table/memory):
/// same iff both are backed by the same instance AND the same index; a
/// standalone handle (no instance) is identity-compared by pointer.
fn entitySame(comptime T: type, a: ?*const T, b: ?*const T, comptime idx_field: []const u8) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    if (x.instance) |xi| {
        const yi = y.instance orelse return false; // x instance-backed, y standalone → distinct
        return xi == yi and @field(x, idx_field) == @field(y, idx_field);
    }
    return x == y; // standalone → pointer identity
}

/// Pointer identity for the per-object handles (instance/module/trap/foreign).
fn ptrSame(comptime T: type, a: ?*const T, b: ?*const T) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return x == y;
}

pub export fn wasm_func_same(a: ?*const handles.Func, b: ?*const handles.Func) callconv(.c) bool {
    return entitySame(handles.Func, a, b, "func_idx");
}
pub export fn wasm_global_same(a: ?*const handles.Global, b: ?*const handles.Global) callconv(.c) bool {
    return entitySame(handles.Global, a, b, "global_idx");
}
pub export fn wasm_table_same(a: ?*const handles.Table, b: ?*const handles.Table) callconv(.c) bool {
    return entitySame(handles.Table, a, b, "table_idx");
}
pub export fn wasm_memory_same(a: ?*const handles.Memory, b: ?*const handles.Memory) callconv(.c) bool {
    return entitySame(handles.Memory, a, b, "memory_idx");
}

/// extern same: same kind AND the wrapped entity same (delegates per kind).
pub export fn wasm_extern_same(a: ?*const handles.Extern, b: ?*const handles.Extern) callconv(.c) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    if (x.kind != y.kind) return false;
    return switch (x.kind) {
        .func => wasm_func_same(x.func, y.func),
        .global => wasm_global_same(x.global, y.global),
        .table => wasm_table_same(x.table, y.table),
        .memory => wasm_memory_same(x.memory, y.memory),
    };
}

pub export fn wasm_instance_same(a: ?*const instance.Instance, b: ?*const instance.Instance) callconv(.c) bool {
    return ptrSame(instance.Instance, a, b);
}
pub export fn wasm_module_same(a: ?*const instance.Module, b: ?*const instance.Module) callconv(.c) bool {
    return ptrSame(instance.Module, a, b);
}
pub export fn wasm_trap_same(a: ?*const trap_surface.Trap, b: ?*const trap_surface.Trap) callconv(.c) bool {
    return ptrSame(trap_surface.Trap, a, b);
}
pub export fn wasm_foreign_same(a: ?*const extern_new.Foreign, b: ?*const extern_new.Foreign) callconv(.c) bool {
    return ptrSame(extern_new.Foreign, a, b);
}

// ===========================================================================
// as_ref / ref_as (+const) — ADR-0158. A handle's `as_ref` returns a borrowed
// `ref_view` Ref whose payload is `@intFromPtr(handle)` (object identity);
// `ref_as_X` recovers it via `@ptrFromInt` (caller-guarantees-type, exactly as
// `wasm_ref_as_foreign`). The view is cached on the handle + freed in its
// `wasm_X_delete`. func/foreign as_ref live in extern_new.zig (funcref/externref
// payload, not object identity). This chunk: global/table/memory; extern/module/
// trap/instance follow (instance needs the Zone-1 anyopaque ref_view workaround).
// ===========================================================================

/// Cached object-identity `ref_view` for `handle` (payload `@intFromPtr(obj)`).
/// `store` is the handle's owning store (instance-backed → instance.store;
/// standalone → handle.store). Null store/OOM → null.
fn objAsRef(store: ?*instance.Store, obj: *const anyopaque, slot: *?*handles.Ref) ?*handles.Ref {
    if (slot.*) |rv| return rv;
    const s = store orelse return null;
    const alloc = instance.storeAllocator(s) orelse return null;
    const rv = alloc.create(handles.Ref) catch return null;
    rv.* = .{ .instance = null, .ref = @intFromPtr(obj), .store = s };
    slot.* = rv;
    return rv;
}

fn storeOf(inst: ?*instance.Instance, standalone: ?*instance.Store) ?*instance.Store {
    if (inst) |i| return i.store;
    return standalone;
}

pub export fn wasm_global_as_ref(g: ?*handles.Global) callconv(.c) ?*handles.Ref {
    const h = g orelse return null;
    return objAsRef(storeOf(h.instance, h.store), h, &h.ref_view);
}
pub export fn wasm_ref_as_global(r: ?*handles.Ref) callconv(.c) ?*handles.Global {
    const h = r orelse return null;
    if (h.ref == 0) return null;
    return @ptrFromInt(h.ref);
}
pub export fn wasm_global_as_ref_const(g: ?*const handles.Global) callconv(.c) ?*const handles.Ref {
    return wasm_global_as_ref(@constCast(g));
}
pub export fn wasm_ref_as_global_const(r: ?*const handles.Ref) callconv(.c) ?*const handles.Global {
    return wasm_ref_as_global(@constCast(r));
}

pub export fn wasm_table_as_ref(t: ?*handles.Table) callconv(.c) ?*handles.Ref {
    const h = t orelse return null;
    return objAsRef(storeOf(h.instance, h.store), h, &h.ref_view);
}
pub export fn wasm_ref_as_table(r: ?*handles.Ref) callconv(.c) ?*handles.Table {
    const h = r orelse return null;
    if (h.ref == 0) return null;
    return @ptrFromInt(h.ref);
}
pub export fn wasm_table_as_ref_const(t: ?*const handles.Table) callconv(.c) ?*const handles.Ref {
    return wasm_table_as_ref(@constCast(t));
}
pub export fn wasm_ref_as_table_const(r: ?*const handles.Ref) callconv(.c) ?*const handles.Table {
    return wasm_ref_as_table(@constCast(r));
}

pub export fn wasm_memory_as_ref(m: ?*handles.Memory) callconv(.c) ?*handles.Ref {
    const h = m orelse return null;
    return objAsRef(storeOf(h.instance, h.store), h, &h.ref_view);
}
pub export fn wasm_ref_as_memory(r: ?*handles.Ref) callconv(.c) ?*handles.Memory {
    const h = r orelse return null;
    if (h.ref == 0) return null;
    return @ptrFromInt(h.ref);
}
pub export fn wasm_memory_as_ref_const(m: ?*const handles.Memory) callconv(.c) ?*const handles.Ref {
    return wasm_memory_as_ref(@constCast(m));
}
pub export fn wasm_ref_as_memory_const(r: ?*const handles.Ref) callconv(.c) ?*const handles.Memory {
    return wasm_ref_as_memory(@constCast(r));
}

test "wasm_X_same: entity-identity (func/global/table/memory) + pointer (instance/module/trap/foreign)" {
    const inst_a: *instance.Instance = @ptrFromInt(0x1000); // fake, never deref'd by `same`
    var f1: handles.Func = .{ .instance = inst_a, .func_idx = 3 };
    var f2: handles.Func = .{ .instance = inst_a, .func_idx = 3 }; // same entity, distinct handle
    var f3: handles.Func = .{ .instance = inst_a, .func_idx = 4 };
    try testing.expect(wasm_func_same(&f1, &f2)); // (instance, idx) match
    try testing.expect(!wasm_func_same(&f1, &f3)); // idx differs
    var fs1: handles.Func = .{ .instance = null, .func_idx = 0 };
    var fs2: handles.Func = .{ .instance = null, .func_idx = 0 };
    try testing.expect(wasm_func_same(&fs1, &fs1)); // standalone → pointer identity
    try testing.expect(!wasm_func_same(&fs1, &fs2));
    try testing.expect(!wasm_func_same(&f1, &fs1)); // instance-backed vs standalone

    var g1: handles.Global = .{ .instance = inst_a, .global_idx = 1, .valtype = .i32, .mutable = false };
    var g2: handles.Global = .{ .instance = inst_a, .global_idx = 1, .valtype = .i32, .mutable = true };
    try testing.expect(wasm_global_same(&g1, &g2)); // identity ignores cached valtype/mutable

    var e1: handles.Extern = .{ .kind = .func, .instance = inst_a, .func = &f1 };
    var e2: handles.Extern = .{ .kind = .func, .instance = inst_a, .func = &f2 };
    var e3: handles.Extern = .{ .kind = .global, .instance = inst_a, .global = &g1 };
    try testing.expect(wasm_extern_same(&e1, &e2)); // same kind + same func entity
    try testing.expect(!wasm_extern_same(&e1, &e3)); // kind differs

    const ti: *trap_surface.Trap = @ptrFromInt(0x2000);
    try testing.expect(wasm_trap_same(ti, ti));
    try testing.expect(!wasm_trap_same(ti, @ptrFromInt(0x3000)));

    // null discipline (two nulls same; one null distinct).
    try testing.expect(wasm_func_same(null, null));
    try testing.expect(!wasm_func_same(&f1, null));
    try testing.expect(wasm_instance_same(null, null));
    try testing.expect(wasm_module_same(null, null));
    try testing.expect(wasm_foreign_same(null, null));
}

test "as_ref / ref_as round-trip (global/table/memory) — object identity + cache + null discipline" {
    const e = instance.wasm_engine_new() orelse return error.EngineAllocFailed;
    defer instance.wasm_engine_delete(e);
    const s = instance.wasm_store_new(e) orelse return error.StoreAllocFailed;
    defer instance.wasm_store_delete(s);

    // memory — full round-trip + cache + lifetime.
    var mlim: types.Limits = .{ .min = 1, .max = 0xffff_ffff };
    const mt = types.wasm_memorytype_new(&mlim) orelse return error.MemTypeAllocFailed;
    defer types.wasm_memorytype_delete(mt);
    const mem = extern_new.wasm_memory_new(s, mt) orelse return error.MemoryAllocFailed;
    const mref = wasm_memory_as_ref(mem) orelse return error.NoRef;
    try testing.expectEqual(mem, wasm_ref_as_memory(mref).?); // round-trip → same handle
    try testing.expectEqual(mref, wasm_memory_as_ref(mem).?); // cached view (same Ref)
    instance.wasm_memory_delete(mem); // frees the ref_view (no leak/UAF)

    // global — round-trip.
    const gt = types.wasm_globaltype_new(types.wasm_valtype_new(0), 0) orelse return error.GtAllocFailed;
    defer types.wasm_globaltype_delete(gt);
    var gval: instance.Val = .{ .kind = .i32, .of = .{ .i32 = 7 } };
    const glob = extern_new.wasm_global_new(s, gt, &gval) orelse return error.GlobalAllocFailed;
    const gref = wasm_global_as_ref(glob) orelse return error.NoRef;
    try testing.expectEqual(glob, wasm_ref_as_global(gref).?);
    instance.wasm_global_delete(glob);

    // table — round-trip.
    var tlim: types.Limits = .{ .min = 1, .max = 0xffff_ffff };
    const tt = types.wasm_tabletype_new(types.wasm_valtype_new(129), &tlim) orelse return error.TtAllocFailed;
    defer types.wasm_tabletype_delete(tt);
    const tbl = extern_new.wasm_table_new(s, tt, null) orelse return error.TableAllocFailed;
    const tref = wasm_table_as_ref(tbl) orelse return error.NoRef;
    try testing.expectEqual(tbl, wasm_ref_as_table(tref).?);
    instance.wasm_table_delete(tbl);

    // null discipline.
    try testing.expect(wasm_memory_as_ref(null) == null);
    try testing.expect(wasm_ref_as_memory(null) == null);
    try testing.expect(wasm_global_as_ref(null) == null);
}
