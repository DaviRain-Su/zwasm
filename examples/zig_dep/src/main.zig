//! Minimal external consumer of zwasm v2's native Zig embedding API
//! (ADR-0109): Engine → compile → instantiate → typedFunc().call().
//! Imported through the package boundary (`@import("zwasm")` resolves to
//! the path-dep's public module), unlike `examples/zig_host/` which shares
//! the in-repo private module. Proves true library consumability (§16.5).

const std = @import("std");
const zwasm = @import("zwasm");

// (module (func (export "add") (param i32 i32) (result i32)
//   local.get 0  local.get 1  i32.add))
const add_wasm = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f,
    0x03, 0x02, 0x01, 0x00,
    0x07, 0x07, 0x01, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00,
    0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b,
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var eng = try zwasm.Engine.init(alloc, .{});
    defer eng.deinit();
    var mod = try eng.compile(&add_wasm);
    defer mod.deinit();
    var inst = try mod.instantiate(.{});
    defer inst.deinit();

    const add = inst.typedFunc(fn (i32, i32) i32, "add");
    const r = try add.call(.{ 2, 40 });

    std.debug.print("zwasm zig_dep: add(2, 40) = {d}\n", .{r});
    if (r != 42) std.process.exit(2);
}
