//! `Module` — validated Wasm module ready for instantiation per
//! ADR-0109 §3. Holds the native parsed view (`runtime.Module`) plus
//! a transitional c_api handle so the existing `Instance` veneer
//! can still instantiate. J.3 drops the c_api side.

const std = @import("std");
const Allocator = std.mem.Allocator;

const _api_instance = @import("../api/instance.zig");
const _trap_surface = @import("../api/trap_surface.zig");
const _runtime_module = @import("../runtime/module.zig");
const _sections = @import("../parse/sections.zig");

const _zwasm = @import("../zwasm.zig");

/// The shape of an imported / exported entity. Native-Zig mirror of the
/// wasm-c-api `wasm_externkind_t`; `tag` covers the Wasm 3.0 EH tag
/// import (no `tag` export kind exists in the binary format).
pub const ExternKind = enum { func, table, memory, global, tag };

/// One decoded import: the two-level name (`module` + `name`) plus the
/// entity kind. Names are owned by the enclosing `ModuleImports.arena`.
pub const ImportItem = struct {
    module: []const u8,
    name: []const u8,
    kind: ExternKind,
};

/// One decoded export: the field `name` plus the entity kind. The name
/// is owned by the enclosing `ModuleExports.arena`.
pub const ExportItem = struct {
    name: []const u8,
    kind: ExternKind,
};

/// Owned result of `Module.imports`; `deinit` frees the items + names.
pub const ModuleImports = struct {
    arena: std.heap.ArenaAllocator,
    items: []const ImportItem,

    pub fn deinit(self: *ModuleImports) void {
        self.arena.deinit();
    }
};

/// Owned result of `Module.exports`; `deinit` frees the items + names.
pub const ModuleExports = struct {
    arena: std.heap.ArenaAllocator,
    items: []const ExportItem,

    pub fn deinit(self: *ModuleExports) void {
        self.arena.deinit();
    }
};

/// `DecodeFailed` = the import/export section body, already accepted by
/// `compile`, failed structural re-decode (an internal inconsistency,
/// surfaced rather than swallowed).
pub const IntrospectError = error{ DecodeFailed, OutOfMemory };

fn importKind(k: _sections.ImportKind) ExternKind {
    return switch (k) {
        .func => .func,
        .table => .table,
        .memory => .memory,
        .global => .global,
        .tag => .tag,
    };
}

fn exportKind(k: _sections.ExportDesc) ExternKind {
    return switch (k) {
        .func => .func,
        .table => .table,
        .memory => .memory,
        .global => .global,
    };
}

pub const Module = struct {
    alloc: Allocator,
    // J.2 transition: c_api handle drives `instantiate` until J.3
    // lifts Instance onto the native surface.
    c_store: *_api_instance.Store,
    c_handle: *_api_instance.Module,
    native: _runtime_module.Module,

    pub fn deinit(self: *Module) void {
        _api_instance.wasm_module_delete(self.c_handle);
        self.native.deinit(self.alloc);
    }

    pub const InstantiateOpts = struct {};

    /// `StartTrapped` = the module's `(start)` function trapped during
    /// instantiation (D-275); `InstantiateFailed` = any other failure
    /// (link / alloc). The specific trap kind is available to C hosts via
    /// `wasm_instance_new`'s `trap_out` + `wasm_trap_message`.
    pub const InstantiateError = error{ InstantiateFailed, StartTrapped };

    pub fn instantiate(self: *Module, _: InstantiateOpts) InstantiateError!_zwasm.Instance {
        var trap: ?*_trap_surface.Trap = null;
        const inst = _api_instance.wasm_instance_new(self.c_store, self.c_handle, null, &trap) orelse {
            if (trap) |t| {
                _trap_surface.wasm_trap_delete(t); // facade owns the trap; free it
                return error.StartTrapped;
            }
            return error.InstantiateFailed;
        };
        return .{ .handle = inst, .c_store = self.c_store };
    }

    /// Section count from the native parser.
    pub fn sectionCount(self: *const Module) usize {
        return self.native.sections.items.len;
    }

    /// Decoded import descriptors (module + field name + extern kind) for
    /// pre-instantiation introspection — an embedder learns which host
    /// definitions a `Linker` must supply before linking. Mirrors
    /// wasmtime's `Module::imports()`. The result owns its strings; call
    /// `.deinit()` when done. Empty when the module has no import section.
    pub fn imports(self: *const Module, gpa: Allocator) IntrospectError!ModuleImports {
        var arena = std.heap.ArenaAllocator.init(gpa);
        errdefer arena.deinit();
        const a = arena.allocator();

        const sec = self.native.find(.import) orelse return .{ .arena = arena, .items = &.{} };
        var decoded = _sections.decodeImports(gpa, sec.body) catch |e| switch (e) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.DecodeFailed,
        };
        defer decoded.deinit();

        const out = try a.alloc(ImportItem, decoded.items.len);
        for (decoded.items, 0..) |it, i| {
            out[i] = .{
                .module = try a.dupe(u8, it.module),
                .name = try a.dupe(u8, it.name),
                .kind = importKind(it.kind),
            };
        }
        return .{ .arena = arena, .items = out };
    }

    /// Decoded export descriptors (field name + extern kind). Mirrors
    /// wasmtime's `Module::exports()`. The result owns its strings; call
    /// `.deinit()` when done. Empty when the module has no export section.
    pub fn exports(self: *const Module, gpa: Allocator) IntrospectError!ModuleExports {
        var arena = std.heap.ArenaAllocator.init(gpa);
        errdefer arena.deinit();
        const a = arena.allocator();

        const sec = self.native.find(.@"export") orelse return .{ .arena = arena, .items = &.{} };
        var decoded = _sections.decodeExports(gpa, sec.body) catch |e| switch (e) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.DecodeFailed,
        };
        defer decoded.deinit();

        const out = try a.alloc(ExportItem, decoded.items.len);
        for (decoded.items, 0..) |e, i| {
            out[i] = .{
                .name = try a.dupe(u8, e.name),
                .kind = exportKind(e.kind),
            };
        }
        return .{ .arena = arena, .items = out };
    }
};

const testing = std.testing;

test "Module.imports: func import → {module,name,kind} (ADR-0109 introspection)" {
    // Minimal module: type (func)->(), import env.imp_f (func 0),
    // export "exp_f" = the imported func (idx 0). No code section.
    const bytes = [_]u8{
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, // magic + version
        0x01, 0x04, 0x01, 0x60, 0x00, 0x00, // type: 1× (func)->()
        0x02, 0x0d, 0x01, 0x03, 'e', 'n', 'v', 0x05, 'i', 'm', 'p', '_', 'f', 0x00, 0x00, // import env.imp_f (func 0)
        0x07, 0x09, 0x01, 0x05, 'e', 'x', 'p', '_', 'f', 0x00, 0x00, // export exp_f = func 0
    };
    var eng = try _zwasm.Engine.init(testing.allocator, .{});
    defer eng.deinit();
    var mod = try eng.compile(&bytes);
    defer mod.deinit();

    var imps = try mod.imports(testing.allocator);
    defer imps.deinit();
    try testing.expectEqual(@as(usize, 1), imps.items.len);
    try testing.expectEqualStrings("env", imps.items[0].module);
    try testing.expectEqualStrings("imp_f", imps.items[0].name);
    try testing.expectEqual(ExternKind.func, imps.items[0].kind);

    var exps = try mod.exports(testing.allocator);
    defer exps.deinit();
    try testing.expectEqual(@as(usize, 1), exps.items.len);
    try testing.expectEqualStrings("exp_f", exps.items[0].name);
    try testing.expectEqual(ExternKind.func, exps.items[0].kind);
}

test "Module.exports: memory export → kind=.memory (kind-mapping boundary)" {
    const bytes = [_]u8{
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, // magic + version
        0x05, 0x03, 0x01, 0x00, 0x01, // memory: 1× {min 1}
        0x07, 0x05, 0x01, 0x01, 'm', 0x02, 0x00, // export "m" = memory 0
    };
    var eng = try _zwasm.Engine.init(testing.allocator, .{});
    defer eng.deinit();
    var mod = try eng.compile(&bytes);
    defer mod.deinit();

    var imps = try mod.imports(testing.allocator);
    defer imps.deinit();
    try testing.expectEqual(@as(usize, 0), imps.items.len); // no import section → empty

    var exps = try mod.exports(testing.allocator);
    defer exps.deinit();
    try testing.expectEqual(@as(usize, 1), exps.items.len);
    try testing.expectEqualStrings("m", exps.items[0].name);
    try testing.expectEqual(ExternKind.memory, exps.items[0].kind);
}
