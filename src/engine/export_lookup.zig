//! Module export lookup helpers.
//!
//! Companion to `engine/runner.zig`'s `findExportFunc` (which
//! stays in runner.zig for now — at the 2000-LOC hard cap, every
//! new addition lands here instead per D-141 / file_size_check
//! ratchet). This module focuses on "given wasm bytes + an export
//! name, find the indexed entity"; callers compose this with the
//! engine runtime to read or invoke the resolved entity.
//!
//! Zone 2 (`src/engine/`).

const std = @import("std");

const parser = @import("../parse/parser.zig");
const sections = @import("../parse/sections.zig");
const runner_mod = @import("runner.zig");
const zir = @import("../ir/zir.zig");

const Allocator = std.mem.Allocator;
const Error = runner_mod.Error;

/// Per-defined-global metadata (offsets + valtypes + total byte
/// size) extracted from `wasm_bytes`. Mirrors the non-empty-fn
/// path's calculation in `runner.zig::compileWasm`; used by the
/// empty-fn path (D-152 discharge per §9.12-E / B138) so spec
/// runners reading globals via `applyDefinedGlobalsInit` get
/// correct offsets even for modules with no functions
/// (`exports.wast` `(module $Global)` shape).
///
/// Both slices are caller-owned via `allocator`; pair with
/// `deinitGlobalsLayout`. Empty (no global section) returns
/// `.{ .offsets = &.{}, .valtypes = &.{} }` (zero-length slices,
/// no allocations). Total byte size is derivable as
/// `valtypes.len * 16` per ADR-0110 §9.13-V uniform stride.
pub const GlobalsLayout = struct {
    offsets: []u32,
    valtypes: []zir.ValType,
};

/// Decode the import + global sections and compute per-global
/// byte offsets + valtypes + total byte size. Result indexed by
/// the FULL wasm global index space (§9.12-E / B153 per D-153
/// Option A): `[0..num_global_imports)` are imports;
/// `[num_global_imports..total)` are defined globals. Post
/// ADR-0110 §9.13-V Phase A.4b: every global occupies a uniform
/// 16-byte slot regardless of valtype — matching `@sizeOf(Value)`
/// + the `[*]Value` stride that c_api's JitRuntime.globals_base
/// hands to JIT-emitted code. Total stays 16-byte rounded.
pub fn computeGlobalsLayout(allocator: Allocator, wasm_bytes: []const u8) Error!GlobalsLayout {
    var module = try parser.parse(allocator, wasm_bytes);
    defer module.deinit(allocator);

    var num_imports: u32 = 0;
    var import_vts: [256]zir.ValType = undefined;
    if (module.find(.import)) |is| {
        var imports = try sections.decodeImports(allocator, is.body);
        defer imports.deinit();
        for (imports.items) |imp| {
            if (imp.kind != .global) continue;
            if (num_imports >= import_vts.len) return Error.UnsupportedEntrySignature;
            import_vts[num_imports] = imp.payload.global.valtype;
            num_imports += 1;
        }
    }

    const gs_opt = module.find(.global);
    var defined_count: usize = 0;
    if (gs_opt) |gs| {
        var gs_buf = try sections.decodeGlobals(allocator, gs.body);
        defer gs_buf.deinit();
        defined_count = gs_buf.items.len;
    }
    const total = @as(usize, num_imports) + defined_count;

    const offsets = try allocator.alloc(u32, total);
    errdefer allocator.free(offsets);
    const valtypes = try allocator.alloc(zir.ValType, total);
    errdefer allocator.free(valtypes);

    var off: u32 = 0;
    // Post-ADR-0110 widen: uniform 16-byte stride for every valtype.
    // This converges the spec-runner byte-buffer layout with the
    // c_api `[*]Value` stride that JitRuntime.globals_base hands
    // JIT-emitted code. Scalar writes (8 bytes) land in the low
    // 8 bytes of each 16-byte slot; W/X/S/D-form JIT reads pick up
    // the matching prefix bytes via little-endian.
    for (0..num_imports) |i| {
        const vt = import_vts[i];
        valtypes[i] = vt;
        offsets[i] = off;
        off += 16;
    }
    if (gs_opt) |gs| {
        var gs_buf = try sections.decodeGlobals(allocator, gs.body);
        defer gs_buf.deinit();
        for (gs_buf.items, 0..) |gd, gi| {
            const dst = num_imports + gi;
            valtypes[dst] = gd.valtype;
            offsets[dst] = off;
            off += 16;
        }
    }
    return .{ .offsets = offsets, .valtypes = valtypes };
}

/// Find an exported global by name. Returns its global_idx in the
/// module's global index space (imports + defined). Used by the
/// §9.12-E spec runner `get-action` directive (Wasm spec `(get
/// "name")` action — reads a global's current value for an
/// `assert_return` comparison). Pairs with `runner.findExportFunc`
/// for the action-dispatcher discharge of `non-invoke-action`
/// skip-impl sites (master plan §5.3).
///
/// Returns `Error.ExportNotFound` when no export with that name
/// exists; `Error.ExportIsNotFunction` (reused with global
/// semantics — the error set has no dedicated `ExportIsNotGlobal`
/// variant yet) when the named export is not a global.
pub fn findExportGlobal(allocator: Allocator, wasm_bytes: []const u8, name: []const u8) Error!u32 {
    var module = try parser.parse(allocator, wasm_bytes);
    defer module.deinit(allocator);

    const export_section = module.find(.@"export") orelse return Error.ExportNotFound;
    var exports = try sections.decodeExports(allocator, export_section.body);
    defer exports.deinit();

    for (exports.items) |e| {
        if (!std.mem.eql(u8, e.name, name)) continue;
        if (e.kind != .global) return Error.ExportIsNotFunction;
        return e.idx;
    }
    return Error.ExportNotFound;
}

/// §9.12-E / B140 — look up an exported function by name and
/// resolve its signature via the type section. Returns a
/// caller-owned `FuncType` whose `params` + `results` are
/// freshly allocated via `allocator`; caller frees both slices.
///
/// Used by the spec runner's `applyAssertUnlinkable` callback
/// to compare an importer's expected func type against the
/// registered exporter's actual func type (B141 wiring).
pub fn getExportFuncType(allocator: Allocator, wasm_bytes: []const u8, name: []const u8) Error!zir.FuncType {
    var module = try parser.parse(allocator, wasm_bytes);
    defer module.deinit(allocator);

    const export_section = module.find(.@"export") orelse return Error.ExportNotFound;
    var exports = try sections.decodeExports(allocator, export_section.body);
    defer exports.deinit();

    var func_idx: ?u32 = null;
    for (exports.items) |e| {
        if (!std.mem.eql(u8, e.name, name)) continue;
        if (e.kind != .func) return Error.ExportIsNotFunction;
        func_idx = e.idx;
        break;
    }
    const fidx = func_idx orelse return Error.ExportNotFound;

    // Count imported funcs (they occupy the low end of the
    // func index space). Defined funcs start at num_func_imports.
    var num_func_imports: u32 = 0;
    if (module.find(.import)) |is| {
        var imports = try sections.decodeImports(allocator, is.body);
        defer imports.deinit();
        for (imports.items) |imp| {
            if (imp.kind == .func) num_func_imports += 1;
        }
    }

    // Resolve the funcidx → typeidx. For defined funcs, walk
    // the function section. For imported funcs, walk the import
    // section's payload.func_typeidx fields.
    const typeidx: u32 = if (fidx >= num_func_imports) blk: {
        const func_sec = module.find(.function) orelse return Error.ExportNotFound;
        const func_typeidxs = try sections.decodeFunctions(allocator, func_sec.body);
        defer allocator.free(func_typeidxs);
        const defined_off = fidx - num_func_imports;
        if (defined_off >= func_typeidxs.len) return Error.ExportNotFound;
        break :blk func_typeidxs[defined_off];
    } else blk: {
        const import_sec = module.find(.import) orelse return Error.ExportNotFound;
        var imports = try sections.decodeImports(allocator, import_sec.body);
        defer imports.deinit();
        var seen: u32 = 0;
        for (imports.items) |imp| {
            if (imp.kind != .func) continue;
            if (seen == fidx) break :blk imp.payload.func_typeidx;
            seen += 1;
        }
        return Error.ExportNotFound;
    };

    const type_sec = module.find(.type) orelse return Error.ExportNotFound;
    var types = try sections.decodeTypes(allocator, type_sec.body);
    defer types.deinit();
    if (typeidx >= types.items.len) return Error.ExportNotFound;
    const src = types.items[typeidx];

    // Caller-owned copies; `types` arena is freed by deinit().
    const params = try allocator.alloc(zir.ValType, src.params.len);
    errdefer allocator.free(params);
    const results = try allocator.alloc(zir.ValType, src.results.len);
    @memcpy(params, src.params);
    @memcpy(results, src.results);
    return .{ .params = params, .results = results };
}

test "getExportFuncType: returns sig for exported defined func" {
    // Module: (type (func (param i32) (result i32)))
    //         (func (type 0) (i32.const 42))
    //         (export "f" (func 0))
    const bytes = [_]u8{
        0x00, 0x61, 0x73, 0x6d,
        0x01, 0x00, 0x00, 0x00,
        // type section (id=1): 1 type, (i32) -> (i32)
        0x01, 0x06, 0x01, 0x60,
        0x01, 0x7f, 0x01, 0x7f,
        // function section (id=3): 1 func, typeidx=0
        0x03, 0x02, 0x01, 0x00,
        // export section (id=7): "f" → func 0
        0x07, 0x05, 0x01, 0x01,
        0x66, 0x00, 0x00,
        // code section (id=10): body = i32.const 42; end
        0x0a,
        0x06, 0x01, 0x04, 0x00,
        0x41, 0x2a, 0x0b,
    };
    const ft = try getExportFuncType(std.testing.allocator, &bytes, "f");
    defer std.testing.allocator.free(ft.params);
    defer std.testing.allocator.free(ft.results);
    try std.testing.expectEqual(@as(usize, 1), ft.params.len);
    try std.testing.expectEqual(zir.ValType.i32, ft.params[0]);
    try std.testing.expectEqual(@as(usize, 1), ft.results.len);
    try std.testing.expectEqual(zir.ValType.i32, ft.results[0]);
}

test "findExportGlobal: returns idx for named global export" {
    // Minimal module bytes containing:
    //   - magic + version
    //   - global section: 1 global, type=i32 const 42 mut=immut
    //   - export section: 1 export "g" → global 0
    const bytes = [_]u8{
        0x00, 0x61, 0x73, 0x6d, // \0asm
        0x01, 0x00, 0x00, 0x00, // version 1
        // type section (id=1) — required for some parsers; empty here
        // global section (id=6)
        0x06, 0x06, 0x01, 0x7f,
        0x00, 0x41, 0x2a, 0x0b,
        // export section (id=7) — 1 export "g" kind=global idx=0
        0x07, 0x05, 0x01, 0x01,
        0x67, 0x03, 0x00,
    };
    const idx = try findExportGlobal(std.testing.allocator, &bytes, "g");
    try std.testing.expectEqual(@as(u32, 0), idx);
}

test "findExportGlobal: ExportNotFound for missing name" {
    const bytes = [_]u8{
        0x00, 0x61, 0x73, 0x6d,
        0x01, 0x00, 0x00, 0x00,
        0x06, 0x06, 0x01, 0x7f,
        0x00, 0x41, 0x2a, 0x0b,
        0x07, 0x05, 0x01, 0x01,
        0x67, 0x03, 0x00,
    };
    try std.testing.expectError(Error.ExportNotFound, findExportGlobal(std.testing.allocator, &bytes, "missing"));
}
