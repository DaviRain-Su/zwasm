//! `Linker` — host-import builder per ADR-0109 §3.2.
//!
//! Maintains a `(module, name) → host-fn / memory` registry that
//! is consulted at `instantiate(module)` time. Each `defineFunc`
//! comptime-derives the Wasm signature from the user's Zig fn,
//! type-checks it against the importing module's declared
//! signature at instantiate time (per Wasm spec §3.4.10), and
//! installs a `runtime.HostCall` slot.

const std = @import("std");
const Allocator = std.mem.Allocator;

const _api_instance = @import("../api/instance.zig");
const _api_wasi = @import("../api/wasi.zig");
const _sections = @import("../parse/sections.zig");
const _runtime = @import("../runtime/runtime.zig");
const _runtime_import = @import("../runtime/instance/import.zig");
const _wasi_host = @import("../wasi/host.zig");
const _zir = @import("../ir/zir.zig");

const _zwasm = @import("../zwasm.zig");
const _engine = @import("engine.zig");
const _module = @import("module.zig");
const _memory_mod = @import("memory.zig");
const _caller = @import("caller.zig");
const _marshal = @import("host_func_marshal.zig");

pub const Caller = _caller.Caller;

pub const LinkError = error{
    UnknownImport,
    /// A `wasi_snapshot_preview1` import whose name has no thunk
    /// registered in `src/api/wasi.zig::lookupWasiThunk`. Distinct
    /// from `UnknownImport` so callers can route these as
    /// "phase-11 deferred" rather than treating them as fatal.
    UnsupportedWasiImport,
    ImportKindMismatch,
    SignatureMismatch,
    InstantiateFailed,
    WasiAlreadyDefined,
    OutOfMemory,
};

/// Bulk WASI configuration per ADR-0109 §3.8 +
/// `docs/zig_api_design.md` §3.8. v0.1 carries the minimum
/// surface; full preopens / env / stdin streams land at Phase 11
/// (D-177).
pub const WasiConfig = struct {
    args: []const []const u8 = &.{},
    // envs / preopens / stdin / stdout / stderr deferred to Phase 11 (D-177).
};

pub const Linker = struct {
    engine: *_engine.Engine,
    entries: std.ArrayList(Entry) = .empty,
    ctx_storage: std.ArrayList(CtxEntry) = .empty,
    /// WASI host registered by `defineWasi`. Linker owns the
    /// allocation; thunks receive the pointer via their `ctx`
    /// argument (not via `store.wasi_host`, whose owning allocator
    /// is `wasm_store_delete`'s c_allocator).
    wasi_host: ?*_wasi_host.Host = null,

    pub const CtxEntry = struct {
        ptr: *anyopaque,
        destroy_fn: *const fn (Allocator, *anyopaque) void,
    };

    pub const Entry = struct {
        module: []const u8,
        name: []const u8,
        payload: Payload,
    };

    pub const Payload = union(enum) {
        host_func: HostFuncEntry,
        memory_alias: MemoryAlias,
    };

    pub const HostFuncEntry = struct {
        thunk_fn: *const fn (*_runtime.Runtime, *anyopaque) anyerror!void,
        ctx: *anyopaque,
        params: []const _zir.ValType,
        results: []const _zir.ValType,
    };

    pub const MemoryAlias = struct {
        bytes: []u8,
    };

    pub fn init(engine: *_engine.Engine) Linker {
        return .{ .engine = engine };
    }

    pub fn deinit(self: *Linker) void {
        for (self.ctx_storage.items) |e| e.destroy_fn(self.engine.alloc, e.ptr);
        self.ctx_storage.deinit(self.engine.alloc);
        self.entries.deinit(self.engine.alloc);
        if (self.wasi_host) |h| {
            h.deinit();
            self.engine.alloc.destroy(h);
            self.wasi_host = null;
        }
    }

    /// ADR-0109 §3.8 — bulk WASI bindings. After `defineWasi`,
    /// any `(import "wasi_snapshot_preview1" "<name>" ...)` in
    /// the module is satisfied by the registered host. v0.1
    /// installs args; envs / preopens / stdin streams land at
    /// Phase 11 (D-177). At-most-once per Linker.
    pub fn defineWasi(self: *Linker, cfg: WasiConfig) !void {
        if (self.wasi_host != null) return error.WasiAlreadyDefined;
        const h = try self.engine.alloc.create(_wasi_host.Host);
        errdefer self.engine.alloc.destroy(h);
        h.* = try _wasi_host.Host.init(self.engine.alloc);
        errdefer h.deinit();

        if (cfg.args.len > 0) try h.setArgs(cfg.args);

        self.wasi_host = h;
    }

    fn destroyForCtx(comptime Ctx: type) *const fn (Allocator, *anyopaque) void {
        return struct {
            fn d(a: Allocator, p: *anyopaque) void {
                const cp: *Ctx = @ptrCast(@alignCast(p));
                a.destroy(cp);
            }
        }.d;
    }

    /// Register a host function whose first parameter must be
    /// `*Caller`. The Wasm signature is comptime-derived from the
    /// remaining parameters and the return type per ADR-0109 §3.2.
    pub fn defineFunc(
        self: *Linker,
        module: []const u8,
        name: []const u8,
        comptime Sig: type,
        user_fn: *const Sig,
    ) !void {
        const fn_info = @typeInfo(Sig).@"fn";
        if (fn_info.params.len == 0 or (fn_info.params[0].type orelse return error.SignatureMismatch) != *Caller) {
            @compileError("Linker.defineFunc: host fn must take *Caller as first param");
        }
        const Ctx = _marshal.HostFnCtx(Sig);
        const ctx_ptr = try self.engine.alloc.create(Ctx);
        errdefer self.engine.alloc.destroy(ctx_ptr);
        ctx_ptr.* = .{ .user_fn = user_fn };
        try self.ctx_storage.append(self.engine.alloc, .{
            .ptr = ctx_ptr,
            .destroy_fn = destroyForCtx(Ctx),
        });

        const sig = comptime _marshal.signatureOf(Sig);
        try self.entries.append(self.engine.alloc, .{
            .module = module,
            .name = name,
            .payload = .{ .host_func = .{
                .thunk_fn = _marshal.thunkFor(Sig),
                .ctx = ctx_ptr,
                .params = sig.params,
                .results = sig.results,
            } },
        });
    }

    pub fn defineMemory(self: *Linker, module: []const u8, name: []const u8, mem: _memory_mod.Memory) !void {
        try self.entries.append(self.engine.alloc, .{
            .module = module,
            .name = name,
            .payload = .{ .memory_alias = .{ .bytes = mem.rt.memory } },
        });
    }

    /// Instantiate `mod` against the registered imports, returning
    /// a native `Instance`. Per ADR-0109 §3.2 the signature
    /// type-check happens here against each `(import ...)`
    /// declaration; unknown imports + signature mismatches surface
    /// as named errors before any runtime state is allocated.
    pub fn instantiate(self: *Linker, mod: *_module.Module) LinkError!_zwasm.Instance {
        const arena = std.heap.ArenaAllocator;
        var scratch_arena = arena.init(self.engine.alloc);
        defer scratch_arena.deinit();
        const scratch = scratch_arena.allocator();

        const imp_section = mod.native.find(.import);
        var bindings_list: std.ArrayList(_runtime_import.ImportBinding) = .empty;
        defer bindings_list.deinit(scratch);

        if (imp_section) |sec| {
            var decoded = _sections.decodeImports(scratch, sec.body) catch return error.InstantiateFailed;
            defer decoded.deinit();

            const types_section = mod.native.find(.type);
            var module_types: ?_sections.Types = null;
            defer if (module_types) |*t| t.deinit();
            if (types_section) |ts| {
                module_types = _sections.decodeTypes(scratch, ts.body) catch return error.InstantiateFailed;
            }

            // Each WASI thunk receives the host via its `ctx`
            // argument (`host_call.ctx = host`), so we deliberately
            // do NOT write `store.wasi_host` here — that field's
            // owning allocator is `wasm_store_delete`'s c_allocator,
            // while ours is the Engine's user-supplied allocator.
            // The Linker keeps ownership of the host across all
            // instances created from it.

            for (decoded.items) |it| {
                // ADR-0109 §3.8 — WASI shortcut: any
                // `wasi_snapshot_preview1` import resolves through
                // the registered host even if no entry was added
                // via defineFunc.
                if (std.mem.eql(u8, it.module, "wasi_snapshot_preview1")) {
                    if (it.kind != .func) return error.ImportKindMismatch;
                    const host = self.wasi_host orelse return error.UnknownImport;
                    const thunk = _api_wasi.lookupWasiThunk(it.name) orelse return error.UnsupportedWasiImport;
                    bindings_list.append(scratch, .{ .func = .{
                        .host_call = .{ .fn_ptr = thunk, .ctx = @ptrCast(host) },
                        .source = .wasi,
                    } }) catch return error.OutOfMemory;
                    continue;
                }

                const entry = self.findEntry(it.module, it.name) orelse return error.UnknownImport;
                switch (it.kind) {
                    .func => {
                        const host = switch (entry.payload) {
                            .host_func => |h| h,
                            else => return error.ImportKindMismatch,
                        };
                        const typeidx = switch (it.payload) {
                            .func_typeidx => |t| t,
                            else => return error.SignatureMismatch,
                        };
                        const types = (module_types orelse return error.SignatureMismatch).items;
                        if (typeidx >= types.len) return error.SignatureMismatch;
                        const declared = types[typeidx];
                        if (!sigEqual(declared.params, host.params) or !sigEqual(declared.results, host.results)) {
                            return error.SignatureMismatch;
                        }
                        bindings_list.append(scratch, .{
                            .func = .{
                                .host_call = .{ .fn_ptr = host.thunk_fn, .ctx = host.ctx },
                                // `.wasi` variant skips the runtime-side
                                // cross-module type-check; we already
                                // type-checked above against `host.params/results`.
                                .source = .wasi,
                            },
                        }) catch return error.OutOfMemory;
                    },
                    .memory => {
                        const memlimits = switch (it.payload) {
                            .memory => |m| m,
                            else => return error.ImportKindMismatch,
                        };
                        const alias = switch (entry.payload) {
                            .memory_alias => |m| m,
                            else => return error.ImportKindMismatch,
                        };
                        bindings_list.append(scratch, .{ .memory = .{
                            .memory = alias.bytes,
                            .source_idx_type = memlimits.idx_type,
                            .source_min = memlimits.min,
                            .source_max = memlimits.max,
                        } }) catch return error.OutOfMemory;
                    },
                    .table, .global => return error.ImportKindMismatch,
                }
            }
        }

        const prebuilt = bindings_list.items;
        const Pre = struct {
            slice: ?[]const _runtime_import.ImportBinding,
            fn b(ctx: *anyopaque, arena_alloc: Allocator, bytes: []const u8, store: *_api_instance.Store) anyerror!?[]const _runtime_import.ImportBinding {
                _ = arena_alloc;
                _ = bytes;
                _ = store;
                const s: *@This() = @ptrCast(@alignCast(ctx));
                return s.slice;
            }
            fn asBuilder(s: *@This()) _api_instance.BindingsBuilder {
                return .{ .ctx = s, .build = b };
            }
        };
        var pre: Pre = .{ .slice = if (prebuilt.len == 0) null else prebuilt };
        const inst_ptr = _api_instance.instantiateInternal(mod.c_store, mod.c_handle, pre.asBuilder()) orelse return error.InstantiateFailed;
        return .{ .handle = inst_ptr, .c_store = mod.c_store };
    }

    fn findEntry(self: *Linker, module: []const u8, name: []const u8) ?*const Entry {
        for (self.entries.items) |*e| {
            if (std.mem.eql(u8, e.module, module) and std.mem.eql(u8, e.name, name)) return e;
        }
        return null;
    }
};

fn sigEqual(a: []const _zir.ValType, b: []const _zir.ValType) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| if (x != y) return false;
    return true;
}
