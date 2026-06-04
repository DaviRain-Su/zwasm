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
