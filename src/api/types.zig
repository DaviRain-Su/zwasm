//! wasm-c-api type-representation constructors (§13.2 / Phase 13).
//!
//! The `wasm_{valtype,functype,globaltype,tabletype,memorytype}_t` opaque
//! type descriptors + their queries + `wasm_valtype_vec_t`. These are pure
//! data descriptors (no Store/runtime coupling), so they allocate directly
//! via `std.heap.c_allocator` — unlike Trap/Module/Instance which recover
//! the allocator from a Store back-pointer (`api/instance.zig`).
//!
//! Ownership (upstream wasm-c-api, ADR-0004 pin): every `_new` returns an
//! `own *T` the caller frees with `_delete`; `_new` TAKES ownership of its
//! `own` inputs (a `globaltype_new` consumes its valtype; `functype_new`
//! consumes both valtype_vecs — their data arrays + elements). Queries
//! return borrowed `const *T` (owner = the containing type). The pointer-vec
//! `_vec_delete` cascades into per-element `_delete` (mirrors
//! `instance.wasm_extern_vec_delete`); `_vec_copy` DEEP-copies (each new vec
//! owns its own elements — a shallow copy would double-free).
//!
//! Zone 3 (`src/api/`). Re-exported via `api/wasm.zig`; `export fn`s
//! auto-link into the C-API lib.

const std = @import("std");
const testing = std.testing;

const ca = std.heap.c_allocator;

// wasm.h: WASM_I32=0, I64=1, F32=2, F64=3, EXTERNREF=128, FUNCREF=129.
// wasm_mutability_t: WASM_CONST=0, WASM_VAR=1.

/// `wasm_limits_t` — { min, max } (max = 0xffffffff when unbounded).
pub const Limits = extern struct {
    min: u32,
    max: u32,
};

/// Opaque `wasm_valtype_t` — a value-type descriptor (the valkind byte;
/// refs 128/129 are distinguished by the byte itself).
pub const ValType = extern struct {
    kind: u8,
};

/// `wasm_valtype_vec_t` — `WASM_DECLARE_VEC(valtype, *)`: a pointer-vec of
/// owned `wasm_valtype_t*`. C-ABI `{ size_t size; wasm_valtype_t** data; }`.
pub const ValTypeVec = extern struct {
    size: usize,
    data: ?[*]?*ValType,
};

// wasm_externkind_t (wasm.h): FUNC=0, GLOBAL=1, TABLE=2, MEMORY=3, TAG=4.
pub const extern_func: u8 = 0;
pub const extern_global: u8 = 1;
pub const extern_table: u8 = 2;
pub const extern_memory: u8 = 3;

/// `wasm_externtype_t` — the shared header (a `kind` discriminant) the four
/// concrete extern types embed as their FIRST field, so `*_as_externtype` /
/// `wasm_externtype_as_*` are zero-alloc reinterpret casts (the upstream
/// inheritance layout). An externtype pointer IS a concrete-type pointer.
pub const ExternType = extern struct {
    kind: u8,
};

/// Opaque `wasm_functype_t` — owns its param + result valtype vecs.
pub const FuncType = extern struct {
    kind: u8 = extern_func,
    params: ValTypeVec,
    results: ValTypeVec,
};

/// Opaque `wasm_globaltype_t` — owns its content valtype.
pub const GlobalType = extern struct {
    kind: u8 = extern_global,
    content: ?*ValType,
    mutability: u8,
};

/// Opaque `wasm_tabletype_t` — owns its element valtype + limits.
pub const TableType = extern struct {
    kind: u8 = extern_table,
    element: ?*ValType,
    limits: Limits,
};

/// Opaque `wasm_memorytype_t` — limits only.
pub const MemoryType = extern struct {
    kind: u8 = extern_memory,
    limits: Limits,
};

// =====================================================================
// valtype
// =====================================================================

pub export fn wasm_valtype_new(kind: u8) callconv(.c) ?*ValType {
    const vt = ca.create(ValType) catch return null;
    vt.* = .{ .kind = kind };
    return vt;
}

pub export fn wasm_valtype_delete(vt: ?*ValType) callconv(.c) void {
    if (vt) |p| ca.destroy(p);
}

pub export fn wasm_valtype_kind(vt: ?*const ValType) callconv(.c) u8 {
    return (vt orelse return 0).kind;
}

pub export fn wasm_valtype_copy(vt: ?*const ValType) callconv(.c) ?*ValType {
    const src = vt orelse return null;
    return wasm_valtype_new(src.kind);
}

// =====================================================================
// valtype vec (pointer-vec; delete cascades to element delete)
// =====================================================================

pub export fn wasm_valtype_vec_new_empty(out: ?*ValTypeVec) callconv(.c) void {
    (out orelse return).* = .{ .size = 0, .data = null };
}

pub export fn wasm_valtype_vec_new_uninitialized(out: ?*ValTypeVec, size: usize) callconv(.c) void {
    const o = out orelse return;
    if (size == 0) {
        o.* = .{ .size = 0, .data = null };
        return;
    }
    const buf = ca.alloc(?*ValType, size) catch {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    @memset(buf, null);
    o.* = .{ .size = size, .data = buf.ptr };
}

pub export fn wasm_valtype_vec_new(out: ?*ValTypeVec, size: usize, src: ?[*]const ?*ValType) callconv(.c) void {
    const o = out orelse return;
    if (size == 0 or src == null) {
        o.* = .{ .size = 0, .data = null };
        return;
    }
    const buf = ca.alloc(?*ValType, size) catch {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    @memcpy(buf, src.?[0..size]);
    o.* = .{ .size = size, .data = buf.ptr };
}

pub export fn wasm_valtype_vec_copy(out: ?*ValTypeVec, src: ?*const ValTypeVec) callconv(.c) void {
    const o = out orelse return;
    const s = src orelse {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    if (s.size == 0 or s.data == null) {
        o.* = .{ .size = 0, .data = null };
        return;
    }
    // Deep copy — each new vec owns its own elements (shallow would double-free).
    const buf = ca.alloc(?*ValType, s.size) catch {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    for (s.data.?[0..s.size], 0..) |opt, i| {
        buf[i] = if (opt) |vt| wasm_valtype_copy(vt) else null;
    }
    o.* = .{ .size = s.size, .data = buf.ptr };
}

pub export fn wasm_valtype_vec_delete(v: ?*ValTypeVec) callconv(.c) void {
    const handle = v orelse return;
    if (handle.data) |dp| {
        for (dp[0..handle.size]) |opt| {
            if (opt) |vt| wasm_valtype_delete(vt);
        }
        ca.free(dp[0..handle.size]);
    }
    handle.* = .{ .size = 0, .data = null };
}

// =====================================================================
// functype — consumes both valtype vecs
// =====================================================================

pub export fn wasm_functype_new(params: ?*ValTypeVec, results: ?*ValTypeVec) callconv(.c) ?*FuncType {
    const ft = ca.create(FuncType) catch return null;
    ft.* = .{
        .params = if (params) |p| p.* else .{ .size = 0, .data = null },
        .results = if (results) |r| r.* else .{ .size = 0, .data = null },
    };
    // Ownership transferred — zero the inputs so the caller's _vec_delete is
    // a no-op (the functype now owns the data arrays + elements).
    if (params) |p| p.* = .{ .size = 0, .data = null };
    if (results) |r| r.* = .{ .size = 0, .data = null };
    return ft;
}

pub export fn wasm_functype_delete(ft: ?*FuncType) callconv(.c) void {
    const f = ft orelse return;
    wasm_valtype_vec_delete(&f.params);
    wasm_valtype_vec_delete(&f.results);
    ca.destroy(f);
}

pub export fn wasm_functype_params(ft: ?*const FuncType) callconv(.c) ?*const ValTypeVec {
    return &(ft orelse return null).params;
}

pub export fn wasm_functype_results(ft: ?*const FuncType) callconv(.c) ?*const ValTypeVec {
    return &(ft orelse return null).results;
}

pub export fn wasm_functype_copy(ft: ?*const FuncType) callconv(.c) ?*FuncType {
    const src = ft orelse return null;
    const nf = ca.create(FuncType) catch return null;
    var p: ValTypeVec = undefined;
    var r: ValTypeVec = undefined;
    wasm_valtype_vec_copy(&p, &src.params);
    wasm_valtype_vec_copy(&r, &src.results);
    nf.* = .{ .params = p, .results = r };
    return nf;
}

// =====================================================================
// globaltype — consumes its content valtype
// =====================================================================

pub export fn wasm_globaltype_new(content: ?*ValType, mutability: u8) callconv(.c) ?*GlobalType {
    const gt = ca.create(GlobalType) catch return null;
    gt.* = .{ .content = content, .mutability = mutability };
    return gt;
}

pub export fn wasm_globaltype_delete(gt: ?*GlobalType) callconv(.c) void {
    const g = gt orelse return;
    if (g.content) |c| wasm_valtype_delete(c);
    ca.destroy(g);
}

pub export fn wasm_globaltype_content(gt: ?*const GlobalType) callconv(.c) ?*const ValType {
    return (gt orelse return null).content;
}

pub export fn wasm_globaltype_mutability(gt: ?*const GlobalType) callconv(.c) u8 {
    return (gt orelse return 0).mutability;
}

pub export fn wasm_globaltype_copy(gt: ?*const GlobalType) callconv(.c) ?*GlobalType {
    const src = gt orelse return null;
    const content_copy = if (src.content) |c| wasm_valtype_copy(c) else null;
    return wasm_globaltype_new(content_copy, src.mutability);
}

// =====================================================================
// tabletype — consumes its element valtype, copies limits
// =====================================================================

pub export fn wasm_tabletype_new(element: ?*ValType, limits: ?*const Limits) callconv(.c) ?*TableType {
    const tt = ca.create(TableType) catch return null;
    tt.* = .{
        .element = element,
        .limits = if (limits) |l| l.* else .{ .min = 0, .max = 0xffff_ffff },
    };
    return tt;
}

pub export fn wasm_tabletype_delete(tt: ?*TableType) callconv(.c) void {
    const t = tt orelse return;
    if (t.element) |e| wasm_valtype_delete(e);
    ca.destroy(t);
}

pub export fn wasm_tabletype_element(tt: ?*const TableType) callconv(.c) ?*const ValType {
    return (tt orelse return null).element;
}

pub export fn wasm_tabletype_limits(tt: ?*const TableType) callconv(.c) ?*const Limits {
    return &(tt orelse return null).limits;
}

pub export fn wasm_tabletype_copy(tt: ?*const TableType) callconv(.c) ?*TableType {
    const src = tt orelse return null;
    const elem_copy = if (src.element) |e| wasm_valtype_copy(e) else null;
    var lim = src.limits;
    return wasm_tabletype_new(elem_copy, &lim);
}

// =====================================================================
// memorytype — limits only
// =====================================================================

pub export fn wasm_memorytype_new(limits: ?*const Limits) callconv(.c) ?*MemoryType {
    const mt = ca.create(MemoryType) catch return null;
    mt.* = .{ .limits = if (limits) |l| l.* else .{ .min = 0, .max = 0xffff_ffff } };
    return mt;
}

pub export fn wasm_memorytype_delete(mt: ?*MemoryType) callconv(.c) void {
    if (mt) |m| ca.destroy(m);
}

pub export fn wasm_memorytype_limits(mt: ?*const MemoryType) callconv(.c) ?*const Limits {
    return &(mt orelse return null).limits;
}

pub export fn wasm_memorytype_copy(mt: ?*const MemoryType) callconv(.c) ?*MemoryType {
    const src = mt orelse return null;
    var lim = src.limits;
    return wasm_memorytype_new(&lim);
}

// =====================================================================
// externtype — reinterpret-cast views over the 4 concrete types
// =====================================================================

pub export fn wasm_externtype_kind(et: ?*const ExternType) callconv(.c) u8 {
    return (et orelse return 0).kind;
}

// concrete → externtype: zero-alloc cast (kind is the shared first field).
pub export fn wasm_functype_as_externtype(ft: ?*FuncType) callconv(.c) ?*ExternType {
    return @ptrCast(ft);
}
pub export fn wasm_globaltype_as_externtype(gt: ?*GlobalType) callconv(.c) ?*ExternType {
    return @ptrCast(gt);
}
pub export fn wasm_tabletype_as_externtype(tt: ?*TableType) callconv(.c) ?*ExternType {
    return @ptrCast(tt);
}
pub export fn wasm_memorytype_as_externtype(mt: ?*MemoryType) callconv(.c) ?*ExternType {
    return @ptrCast(mt);
}
pub export fn wasm_functype_as_externtype_const(ft: ?*const FuncType) callconv(.c) ?*const ExternType {
    return @ptrCast(ft);
}
pub export fn wasm_globaltype_as_externtype_const(gt: ?*const GlobalType) callconv(.c) ?*const ExternType {
    return @ptrCast(gt);
}
pub export fn wasm_tabletype_as_externtype_const(tt: ?*const TableType) callconv(.c) ?*const ExternType {
    return @ptrCast(tt);
}
pub export fn wasm_memorytype_as_externtype_const(mt: ?*const MemoryType) callconv(.c) ?*const ExternType {
    return @ptrCast(mt);
}

// externtype → concrete: checked cast (null on kind mismatch).
pub export fn wasm_externtype_as_functype(et: ?*ExternType) callconv(.c) ?*FuncType {
    const e = et orelse return null;
    return if (e.kind == extern_func) @ptrCast(@alignCast(e)) else null;
}
pub export fn wasm_externtype_as_globaltype(et: ?*ExternType) callconv(.c) ?*GlobalType {
    const e = et orelse return null;
    return if (e.kind == extern_global) @ptrCast(@alignCast(e)) else null;
}
pub export fn wasm_externtype_as_tabletype(et: ?*ExternType) callconv(.c) ?*TableType {
    const e = et orelse return null;
    return if (e.kind == extern_table) @ptrCast(@alignCast(e)) else null;
}
pub export fn wasm_externtype_as_memorytype(et: ?*ExternType) callconv(.c) ?*MemoryType {
    const e = et orelse return null;
    return if (e.kind == extern_memory) @ptrCast(@alignCast(e)) else null;
}
pub export fn wasm_externtype_as_functype_const(et: ?*const ExternType) callconv(.c) ?*const FuncType {
    const e = et orelse return null;
    return if (e.kind == extern_func) @ptrCast(@alignCast(e)) else null;
}
pub export fn wasm_externtype_as_globaltype_const(et: ?*const ExternType) callconv(.c) ?*const GlobalType {
    const e = et orelse return null;
    return if (e.kind == extern_global) @ptrCast(@alignCast(e)) else null;
}
pub export fn wasm_externtype_as_tabletype_const(et: ?*const ExternType) callconv(.c) ?*const TableType {
    const e = et orelse return null;
    return if (e.kind == extern_table) @ptrCast(@alignCast(e)) else null;
}
pub export fn wasm_externtype_as_memorytype_const(et: ?*const ExternType) callconv(.c) ?*const MemoryType {
    const e = et orelse return null;
    return if (e.kind == extern_memory) @ptrCast(@alignCast(e)) else null;
}

// externtype delete/copy dispatch to the concrete type by kind.
pub export fn wasm_externtype_delete(et: ?*ExternType) callconv(.c) void {
    const e = et orelse return;
    switch (e.kind) {
        extern_func => wasm_functype_delete(@ptrCast(@alignCast(e))),
        extern_global => wasm_globaltype_delete(@ptrCast(@alignCast(e))),
        extern_table => wasm_tabletype_delete(@ptrCast(@alignCast(e))),
        extern_memory => wasm_memorytype_delete(@ptrCast(@alignCast(e))),
        else => {},
    }
}
pub export fn wasm_externtype_copy(et: ?*const ExternType) callconv(.c) ?*ExternType {
    const e = et orelse return null;
    return switch (e.kind) {
        extern_func => wasm_functype_as_externtype(wasm_functype_copy(@ptrCast(@alignCast(e)))),
        extern_global => wasm_globaltype_as_externtype(wasm_globaltype_copy(@ptrCast(@alignCast(e)))),
        extern_table => wasm_tabletype_as_externtype(wasm_tabletype_copy(@ptrCast(@alignCast(e)))),
        extern_memory => wasm_memorytype_as_externtype(wasm_memorytype_copy(@ptrCast(@alignCast(e)))),
        else => null,
    };
}

/// `wasm_externtype_vec_t` — pointer-vec; delete cascades to element delete.
pub const ExternTypeVec = extern struct {
    size: usize,
    data: ?[*]?*ExternType,
};

pub export fn wasm_externtype_vec_new_empty(out: ?*ExternTypeVec) callconv(.c) void {
    (out orelse return).* = .{ .size = 0, .data = null };
}
pub export fn wasm_externtype_vec_new_uninitialized(out: ?*ExternTypeVec, size: usize) callconv(.c) void {
    const o = out orelse return;
    if (size == 0) {
        o.* = .{ .size = 0, .data = null };
        return;
    }
    const buf = ca.alloc(?*ExternType, size) catch {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    @memset(buf, null);
    o.* = .{ .size = size, .data = buf.ptr };
}
pub export fn wasm_externtype_vec_new(out: ?*ExternTypeVec, size: usize, src: ?[*]const ?*ExternType) callconv(.c) void {
    const o = out orelse return;
    if (size == 0 or src == null) {
        o.* = .{ .size = 0, .data = null };
        return;
    }
    const buf = ca.alloc(?*ExternType, size) catch {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    @memcpy(buf, src.?[0..size]);
    o.* = .{ .size = size, .data = buf.ptr };
}
pub export fn wasm_externtype_vec_delete(v: ?*ExternTypeVec) callconv(.c) void {
    const handle = v orelse return;
    if (handle.data) |dp| {
        for (dp[0..handle.size]) |opt| {
            if (opt) |e| wasm_externtype_delete(e);
        }
        ca.free(dp[0..handle.size]);
    }
    handle.* = .{ .size = 0, .data = null };
}

// =====================================================================
// importtype / exporttype  (name = wasm_byte_vec_t)
// =====================================================================

const ByteVec = @import("vec.zig").ByteVec;

/// Opaque `wasm_importtype_t` — owns its module/name byte vecs + externtype.
pub const ImportType = extern struct {
    module: ByteVec,
    name: ByteVec,
    et: ?*ExternType,
};

/// Opaque `wasm_exporttype_t` — owns its name byte vec + externtype.
pub const ExportType = extern struct {
    name: ByteVec,
    et: ?*ExternType,
};

fn freeByteVec(bv: *ByteVec) void {
    if (bv.data) |p| ca.free(p[0..bv.size]);
    bv.* = .{ .size = 0, .data = null };
}

fn copyByteVec(src: ByteVec) ByteVec {
    if (src.size == 0 or src.data == null) return .{ .size = 0, .data = null };
    const buf = ca.alloc(u8, src.size) catch return .{ .size = 0, .data = null };
    @memcpy(buf, src.data.?[0..src.size]);
    return .{ .size = src.size, .data = buf.ptr };
}

pub export fn wasm_importtype_new(module: ?*ByteVec, name: ?*ByteVec, et: ?*ExternType) callconv(.c) ?*ImportType {
    const it = ca.create(ImportType) catch return null;
    it.* = .{
        .module = if (module) |m| m.* else .{ .size = 0, .data = null },
        .name = if (name) |n| n.* else .{ .size = 0, .data = null },
        .et = et,
    };
    if (module) |m| m.* = .{ .size = 0, .data = null }; // ownership transferred
    if (name) |n| n.* = .{ .size = 0, .data = null };
    return it;
}

pub export fn wasm_importtype_delete(it: ?*ImportType) callconv(.c) void {
    const i = it orelse return;
    freeByteVec(&i.module);
    freeByteVec(&i.name);
    if (i.et) |e| wasm_externtype_delete(e);
    ca.destroy(i);
}

pub export fn wasm_importtype_module(it: ?*const ImportType) callconv(.c) ?*const ByteVec {
    return &(it orelse return null).module;
}
pub export fn wasm_importtype_name(it: ?*const ImportType) callconv(.c) ?*const ByteVec {
    return &(it orelse return null).name;
}
pub export fn wasm_importtype_type(it: ?*const ImportType) callconv(.c) ?*const ExternType {
    return (it orelse return null).et;
}
pub export fn wasm_importtype_copy(it: ?*const ImportType) callconv(.c) ?*ImportType {
    const src = it orelse return null;
    const ni = ca.create(ImportType) catch return null;
    ni.* = .{
        .module = copyByteVec(src.module),
        .name = copyByteVec(src.name),
        .et = if (src.et) |e| wasm_externtype_copy(e) else null,
    };
    return ni;
}

pub export fn wasm_exporttype_new(name: ?*ByteVec, et: ?*ExternType) callconv(.c) ?*ExportType {
    const xt = ca.create(ExportType) catch return null;
    xt.* = .{
        .name = if (name) |n| n.* else .{ .size = 0, .data = null },
        .et = et,
    };
    if (name) |n| n.* = .{ .size = 0, .data = null };
    return xt;
}

pub export fn wasm_exporttype_delete(xt: ?*ExportType) callconv(.c) void {
    const x = xt orelse return;
    freeByteVec(&x.name);
    if (x.et) |e| wasm_externtype_delete(e);
    ca.destroy(x);
}

pub export fn wasm_exporttype_name(xt: ?*const ExportType) callconv(.c) ?*const ByteVec {
    return &(xt orelse return null).name;
}
pub export fn wasm_exporttype_type(xt: ?*const ExportType) callconv(.c) ?*const ExternType {
    return (xt orelse return null).et;
}
pub export fn wasm_exporttype_copy(xt: ?*const ExportType) callconv(.c) ?*ExportType {
    const src = xt orelse return null;
    const nx = ca.create(ExportType) catch return null;
    nx.* = .{
        .name = copyByteVec(src.name),
        .et = if (src.et) |e| wasm_externtype_copy(e) else null,
    };
    return nx;
}

// importtype / exporttype vecs (pointer-vecs; delete cascades).
pub const ImportTypeVec = extern struct { size: usize, data: ?[*]?*ImportType };
pub const ExportTypeVec = extern struct { size: usize, data: ?[*]?*ExportType };

pub export fn wasm_importtype_vec_new_empty(out: ?*ImportTypeVec) callconv(.c) void {
    (out orelse return).* = .{ .size = 0, .data = null };
}
pub export fn wasm_importtype_vec_new_uninitialized(out: ?*ImportTypeVec, size: usize) callconv(.c) void {
    const o = out orelse return;
    if (size == 0) {
        o.* = .{ .size = 0, .data = null };
        return;
    }
    const buf = ca.alloc(?*ImportType, size) catch {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    @memset(buf, null);
    o.* = .{ .size = size, .data = buf.ptr };
}
pub export fn wasm_importtype_vec_new(out: ?*ImportTypeVec, size: usize, src: ?[*]const ?*ImportType) callconv(.c) void {
    const o = out orelse return;
    if (size == 0 or src == null) {
        o.* = .{ .size = 0, .data = null };
        return;
    }
    const buf = ca.alloc(?*ImportType, size) catch {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    @memcpy(buf, src.?[0..size]);
    o.* = .{ .size = size, .data = buf.ptr };
}
pub export fn wasm_importtype_vec_delete(v: ?*ImportTypeVec) callconv(.c) void {
    const handle = v orelse return;
    if (handle.data) |dp| {
        for (dp[0..handle.size]) |opt| {
            if (opt) |it| wasm_importtype_delete(it);
        }
        ca.free(dp[0..handle.size]);
    }
    handle.* = .{ .size = 0, .data = null };
}

pub export fn wasm_exporttype_vec_new_empty(out: ?*ExportTypeVec) callconv(.c) void {
    (out orelse return).* = .{ .size = 0, .data = null };
}
pub export fn wasm_exporttype_vec_new_uninitialized(out: ?*ExportTypeVec, size: usize) callconv(.c) void {
    const o = out orelse return;
    if (size == 0) {
        o.* = .{ .size = 0, .data = null };
        return;
    }
    const buf = ca.alloc(?*ExportType, size) catch {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    @memset(buf, null);
    o.* = .{ .size = size, .data = buf.ptr };
}
pub export fn wasm_exporttype_vec_new(out: ?*ExportTypeVec, size: usize, src: ?[*]const ?*ExportType) callconv(.c) void {
    const o = out orelse return;
    if (size == 0 or src == null) {
        o.* = .{ .size = 0, .data = null };
        return;
    }
    const buf = ca.alloc(?*ExportType, size) catch {
        o.* = .{ .size = 0, .data = null };
        return;
    };
    @memcpy(buf, src.?[0..size]);
    o.* = .{ .size = size, .data = buf.ptr };
}
pub export fn wasm_exporttype_vec_delete(v: ?*ExportTypeVec) callconv(.c) void {
    const handle = v orelse return;
    if (handle.data) |dp| {
        for (dp[0..handle.size]) |opt| {
            if (opt) |xt| wasm_exporttype_delete(xt);
        }
        ca.free(dp[0..handle.size]);
    }
    handle.* = .{ .size = 0, .data = null };
}

// =====================================================================
// Tests
// =====================================================================

test "valtype: new/kind/copy/delete round-trip" {
    const vt = wasm_valtype_new(0).?; // WASM_I32
    defer wasm_valtype_delete(vt);
    try testing.expectEqual(@as(u8, 0), wasm_valtype_kind(vt));
    const c = wasm_valtype_copy(vt).?;
    defer wasm_valtype_delete(c);
    try testing.expectEqual(@as(u8, 0), wasm_valtype_kind(c));
    wasm_valtype_delete(null); // null-tolerant
}

test "valtype_vec: new from elements, delete cascades to elements" {
    var elems = [_]?*ValType{ wasm_valtype_new(0), wasm_valtype_new(1) };
    var vec: ValTypeVec = undefined;
    wasm_valtype_vec_new(&vec, elems.len, &elems);
    try testing.expectEqual(@as(usize, 2), vec.size);
    try testing.expectEqual(@as(u8, 1), wasm_valtype_kind(vec.data.?[1].?));
    wasm_valtype_vec_delete(&vec); // frees the two valtypes + the array
    try testing.expectEqual(@as(usize, 0), vec.size);
}

test "functype: new consumes vecs, params/results query, delete" {
    var params = [_]?*ValType{ wasm_valtype_new(0), wasm_valtype_new(1) }; // (i32,i64)
    var results = [_]?*ValType{wasm_valtype_new(2)}; // -> f32
    var pv: ValTypeVec = undefined;
    var rv: ValTypeVec = undefined;
    wasm_valtype_vec_new(&pv, params.len, &params);
    wasm_valtype_vec_new(&rv, results.len, &results);
    const ft = wasm_functype_new(&pv, &rv).?;
    defer wasm_functype_delete(ft);
    // Inputs were consumed (zeroed).
    try testing.expectEqual(@as(usize, 0), pv.size);
    try testing.expectEqual(@as(usize, 2), wasm_functype_params(ft).?.size);
    try testing.expectEqual(@as(usize, 1), wasm_functype_results(ft).?.size);
    try testing.expectEqual(@as(u8, 2), wasm_valtype_kind(wasm_functype_results(ft).?.data.?[0].?));
}

test "functype: copy is deep (independent delete)" {
    var pv: ValTypeVec = undefined;
    var rv: ValTypeVec = undefined;
    var params = [_]?*ValType{wasm_valtype_new(0)};
    wasm_valtype_vec_new(&pv, params.len, &params);
    wasm_valtype_vec_new_empty(&rv);
    const ft = wasm_functype_new(&pv, &rv).?;
    defer wasm_functype_delete(ft);
    const ft2 = wasm_functype_copy(ft).?;
    defer wasm_functype_delete(ft2); // independent — no double-free
    try testing.expectEqual(@as(usize, 1), wasm_functype_params(ft2).?.size);
}

test "globaltype: content/mutability + owns valtype" {
    const gt = wasm_globaltype_new(wasm_valtype_new(3), 1).?; // f64, VAR
    defer wasm_globaltype_delete(gt);
    try testing.expectEqual(@as(u8, 3), wasm_valtype_kind(wasm_globaltype_content(gt).?));
    try testing.expectEqual(@as(u8, 1), wasm_globaltype_mutability(gt));
}

test "tabletype + memorytype: limits round-trip" {
    var lim: Limits = .{ .min = 1, .max = 10 };
    const tt = wasm_tabletype_new(wasm_valtype_new(129), &lim).?; // funcref
    defer wasm_tabletype_delete(tt);
    try testing.expectEqual(@as(u32, 1), wasm_tabletype_limits(tt).?.min);
    try testing.expectEqual(@as(u8, 129), wasm_valtype_kind(wasm_tabletype_element(tt).?));

    const mt = wasm_memorytype_new(&lim).?;
    defer wasm_memorytype_delete(mt);
    try testing.expectEqual(@as(u32, 10), wasm_memorytype_limits(mt).?.max);
}

test "externtype: functype round-trips through as_externtype + kind + checked downcast" {
    var pv: ValTypeVec = undefined;
    var rv: ValTypeVec = undefined;
    wasm_valtype_vec_new_empty(&pv);
    wasm_valtype_vec_new_empty(&rv);
    const ft = wasm_functype_new(&pv, &rv).?;
    const et = wasm_functype_as_externtype(ft).?; // zero-alloc view
    try testing.expectEqual(extern_func, wasm_externtype_kind(et));
    try testing.expect(wasm_externtype_as_functype(et) == ft); // same object
    try testing.expect(wasm_externtype_as_globaltype(et) == null); // kind mismatch
    wasm_externtype_delete(et); // dispatches to functype_delete (frees the object once)
}

test "externtype: copy dispatches by kind (independent delete)" {
    var lim: Limits = .{ .min = 2, .max = 4 };
    const mt = wasm_memorytype_new(&lim).?;
    const et = wasm_memorytype_as_externtype(mt).?;
    const et2 = wasm_externtype_copy(et).?;
    defer wasm_externtype_delete(et2);
    defer wasm_externtype_delete(et);
    try testing.expectEqual(extern_memory, wasm_externtype_kind(et2));
    try testing.expectEqual(@as(u32, 4), wasm_externtype_as_memorytype(et2).?.limits.max);
}

test "importtype: module/name/type + owns externtype, delete frees all" {
    var lim: Limits = .{ .min = 1, .max = 1 };
    const et = wasm_tabletype_as_externtype(wasm_tabletype_new(wasm_valtype_new(129), &lim).?).?;
    var mod: ByteVec = undefined;
    var nm: ByteVec = undefined;
    @import("vec.zig").wasm_byte_vec_new(&mod, 3, "env");
    @import("vec.zig").wasm_byte_vec_new(&nm, 1, "t");
    const it = wasm_importtype_new(&mod, &nm, et).?;
    defer wasm_importtype_delete(it);
    try testing.expectEqual(@as(usize, 0), mod.size); // consumed
    try testing.expectEqual(@as(usize, 3), wasm_importtype_module(it).?.size);
    try testing.expectEqual(extern_table, wasm_externtype_kind(wasm_importtype_type(it).?));
}

test "exporttype: name/type + copy is independent" {
    var lim: Limits = .{ .min = 0, .max = 0xffff_ffff };
    const et = wasm_memorytype_as_externtype(wasm_memorytype_new(&lim).?).?;
    var nm: ByteVec = undefined;
    @import("vec.zig").wasm_byte_vec_new(&nm, 3, "mem");
    const xt = wasm_exporttype_new(&nm, et).?;
    defer wasm_exporttype_delete(xt);
    const xt2 = wasm_exporttype_copy(xt).?;
    defer wasm_exporttype_delete(xt2); // independent
    try testing.expectEqual(@as(usize, 3), wasm_exporttype_name(xt2).?.size);
    try testing.expectEqual(extern_memory, wasm_externtype_kind(wasm_exporttype_type(xt2).?));
}

test "importtype_vec: delete cascades to element delete" {
    var lim: Limits = .{ .min = 1, .max = 1 };
    var mod: ByteVec = undefined;
    var nm: ByteVec = undefined;
    @import("vec.zig").wasm_byte_vec_new(&mod, 1, "a");
    @import("vec.zig").wasm_byte_vec_new(&nm, 1, "b");
    const it = wasm_importtype_new(&mod, &nm, wasm_memorytype_as_externtype(wasm_memorytype_new(&lim).?).?).?;
    var elems = [_]?*ImportType{it};
    var vec: ImportTypeVec = undefined;
    wasm_importtype_vec_new(&vec, 1, &elems);
    try testing.expectEqual(@as(usize, 1), vec.size);
    wasm_importtype_vec_delete(&vec); // frees the importtype (+ its name vecs + externtype)
    try testing.expectEqual(@as(usize, 0), vec.size);
}
