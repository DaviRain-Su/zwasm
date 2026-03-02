// Copyright (c) 2026 zwasm contributors. Licensed under the MIT License.
// See LICENSE at the root of this distribution.

//! C ABI export layer for zwasm.
//!
//! Provides a flat C-callable API wrapping WasmModule. All functions use
//! `callconv(.c)` for FFI compatibility. Opaque pointer types hide internal
//! layout. Error messages are stored in a thread-local buffer accessible
//! via `zwasm_last_error_message()`.
//!
//! Allocator strategy: Each CApiModule owns a GeneralPurposeAllocator,
//! heap-allocated via page_allocator so its address is stable. The GPA
//! provides the allocator for WasmModule and all its internal state.

const std = @import("std");
const types = @import("types.zig");
const WasmModule = types.WasmModule;
const WasiOptions = types.WasiOptions;

// ============================================================
// Error handling — thread-local error message buffer
// ============================================================

const ERROR_BUF_SIZE = 512;
threadlocal var error_buf: [ERROR_BUF_SIZE]u8 = undefined;
threadlocal var error_len: usize = 0;

fn setError(err: anyerror) void {
    const msg = @errorName(err);
    const len = @min(msg.len, ERROR_BUF_SIZE);
    @memcpy(error_buf[0..len], msg[0..len]);
    error_len = len;
}

fn clearError() void {
    error_len = 0;
}

// ============================================================
// Internal wrapper — GPA + WasmModule co-located
// ============================================================

const Gpa = std.heap.GeneralPurposeAllocator(.{});

/// Internal wrapper owning both the GPA and WasmModule.
/// Heap-allocated via page_allocator for address stability.
const CApiModule = struct {
    gpa: Gpa,
    module: *WasmModule,

    fn create(wasm_bytes: []const u8, wasi: bool) !*CApiModule {
        const self = try std.heap.page_allocator.create(CApiModule);
        errdefer std.heap.page_allocator.destroy(self);
        self.gpa = .{};
        const allocator = self.gpa.allocator();
        self.module = if (wasi)
            try WasmModule.loadWasi(allocator, wasm_bytes)
        else
            try WasmModule.load(allocator, wasm_bytes);
        return self;
    }

    fn createWasiConfigured(wasm_bytes: []const u8, opts: WasiOptions) !*CApiModule {
        const self = try std.heap.page_allocator.create(CApiModule);
        errdefer std.heap.page_allocator.destroy(self);
        self.gpa = .{};
        const allocator = self.gpa.allocator();
        self.module = try WasmModule.loadWasiWithOptions(allocator, wasm_bytes, opts);
        return self;
    }

    fn createWithImports(wasm_bytes: []const u8, imports: []const types.ImportEntry) !*CApiModule {
        const self = try std.heap.page_allocator.create(CApiModule);
        errdefer std.heap.page_allocator.destroy(self);
        self.gpa = .{};
        const allocator = self.gpa.allocator();
        self.module = try WasmModule.loadWithImports(allocator, wasm_bytes, imports);
        return self;
    }

    fn destroy(self: *CApiModule) void {
        self.module.deinit();
        _ = self.gpa.deinit();
        std.heap.page_allocator.destroy(self);
    }
};

// ============================================================
// Opaque type (C sees zwasm_module_t*)
// ============================================================

pub const zwasm_module_t = CApiModule;

// ============================================================
// Module lifecycle
// ============================================================

/// Create a new Wasm module from binary bytes.
/// Returns null on error — call `zwasm_last_error_message()` for details.
export fn zwasm_module_new(wasm_ptr: [*]const u8, len: usize) ?*zwasm_module_t {
    clearError();
    return CApiModule.create(wasm_ptr[0..len], false) catch |err| {
        setError(err);
        return null;
    };
}

/// Create a new WASI module from binary bytes.
/// Returns null on error — call `zwasm_last_error_message()` for details.
export fn zwasm_module_new_wasi(wasm_ptr: [*]const u8, len: usize) ?*zwasm_module_t {
    clearError();
    return CApiModule.create(wasm_ptr[0..len], true) catch |err| {
        setError(err);
        return null;
    };
}

/// Free all resources held by a module.
/// After this call, the module pointer is invalid.
export fn zwasm_module_delete(module: *zwasm_module_t) void {
    module.destroy();
}

/// Validate a Wasm binary without instantiating it.
/// Returns true if valid, false if invalid or malformed.
export fn zwasm_module_validate(wasm_ptr: [*]const u8, len: usize) bool {
    clearError();
    var gpa = Gpa{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const validate = types.runtime.validateModule;
    var module = types.runtime.Module.init(allocator, wasm_ptr[0..len]);
    defer module.deinit();
    module.decode() catch |err| {
        setError(err);
        return false;
    };
    validate(allocator, &module) catch |err| {
        setError(err);
        return false;
    };
    return true;
}

// ============================================================
// Function invocation
// ============================================================

/// Invoke an exported function by name.
/// Args and results are passed as uint64_t arrays. Returns false on error.
export fn zwasm_module_invoke(
    module: *zwasm_module_t,
    name_ptr: [*:0]const u8,
    args: ?[*]u64,
    nargs: u32,
    results: ?[*]u64,
    nresults: u32,
) bool {
    clearError();
    const name = std.mem.sliceTo(name_ptr, 0);
    const args_slice = if (args) |a| a[0..nargs] else &[_]u64{};
    const results_slice = if (results) |r| r[0..nresults] else &[_]u64{};
    module.module.invoke(name, args_slice, results_slice) catch |err| {
        setError(err);
        return false;
    };
    return true;
}

/// Invoke the _start function (WASI entry point). Returns false on error.
export fn zwasm_module_invoke_start(module: *zwasm_module_t) bool {
    clearError();
    module.module.invoke("_start", &[_]u64{}, &[_]u64{}) catch |err| {
        setError(err);
        return false;
    };
    return true;
}

// ============================================================
// Export introspection
// ============================================================

/// Return the number of exported functions.
export fn zwasm_module_export_count(module: *zwasm_module_t) u32 {
    return @intCast(module.module.export_fns.len);
}

/// Return the name of the idx-th exported function as a null-terminated string.
/// Returns null if idx is out of range.
export fn zwasm_module_export_name(module: *zwasm_module_t, idx: u32) ?[*:0]const u8 {
    if (idx >= module.module.export_fns.len) return null;
    const name = module.module.export_fns[idx].name;
    // Wasm names are stored as slices. Return as pointer — the data lives in
    // the module's decoded section and is null-terminated by virtue of the
    // underlying wasm bytes being contiguous. However, we can't guarantee a
    // null terminator after the slice, so we copy into the error_buf as a
    // scratch space. This is a simplification for C callers.
    // For zero-copy, callers should use memory_data + offsets.
    if (name.len >= ERROR_BUF_SIZE) return null;
    @memcpy(error_buf[0..name.len], name);
    error_buf[name.len] = 0;
    return @ptrCast(error_buf[0..name.len :0]);
}

/// Return the number of parameters of the idx-th exported function.
/// Returns 0 if idx is out of range.
export fn zwasm_module_export_param_count(module: *zwasm_module_t, idx: u32) u32 {
    if (idx >= module.module.export_fns.len) return 0;
    return @intCast(module.module.export_fns[idx].param_types.len);
}

/// Return the number of results of the idx-th exported function.
/// Returns 0 if idx is out of range.
export fn zwasm_module_export_result_count(module: *zwasm_module_t, idx: u32) u32 {
    if (idx >= module.module.export_fns.len) return 0;
    return @intCast(module.module.export_fns[idx].result_types.len);
}

// ============================================================
// WASI configuration
// ============================================================

/// Opaque WASI configuration handle.
const CApiWasiConfig = struct {
    argv: std.ArrayList([*:0]const u8),
    env_keys: std.ArrayList([*]const u8),
    env_vals: std.ArrayList([*]const u8),
    env_key_lens: std.ArrayList(usize),
    env_val_lens: std.ArrayList(usize),
    preopen_host: std.ArrayList([*]const u8),
    preopen_guest: std.ArrayList([*]const u8),
    preopen_host_lens: std.ArrayList(usize),
    preopen_guest_lens: std.ArrayList(usize),

    fn init() CApiWasiConfig {
        const alloc = std.heap.page_allocator;
        return .{
            .argv = std.ArrayList([*:0]const u8).init(alloc),
            .env_keys = std.ArrayList([*]const u8).init(alloc),
            .env_vals = std.ArrayList([*]const u8).init(alloc),
            .env_key_lens = std.ArrayList(usize).init(alloc),
            .env_val_lens = std.ArrayList(usize).init(alloc),
            .preopen_host = std.ArrayList([*]const u8).init(alloc),
            .preopen_guest = std.ArrayList([*]const u8).init(alloc),
            .preopen_host_lens = std.ArrayList(usize).init(alloc),
            .preopen_guest_lens = std.ArrayList(usize).init(alloc),
        };
    }

    fn deinit(self: *CApiWasiConfig) void {
        self.argv.deinit();
        self.env_keys.deinit();
        self.env_vals.deinit();
        self.env_key_lens.deinit();
        self.env_val_lens.deinit();
        self.preopen_host.deinit();
        self.preopen_guest.deinit();
        self.preopen_host_lens.deinit();
        self.preopen_guest_lens.deinit();
    }
};

pub const zwasm_wasi_config_t = CApiWasiConfig;

/// Create a new WASI configuration handle.
export fn zwasm_wasi_config_new() ?*zwasm_wasi_config_t {
    const config = std.heap.page_allocator.create(CApiWasiConfig) catch return null;
    config.* = CApiWasiConfig.init();
    return config;
}

/// Free a WASI configuration handle.
export fn zwasm_wasi_config_delete(config: *zwasm_wasi_config_t) void {
    config.deinit();
    std.heap.page_allocator.destroy(config);
}

/// Set command-line arguments for WASI. argv entries are null-terminated C strings.
export fn zwasm_wasi_config_set_argv(config: *zwasm_wasi_config_t, argc: u32, argv: [*]const [*:0]const u8) void {
    config.argv.clearRetainingCapacity();
    for (0..argc) |i| {
        config.argv.append(argv[i]) catch {};
    }
}

/// Set environment variables for WASI. keys and vals are arrays of C strings.
export fn zwasm_wasi_config_set_env(
    config: *zwasm_wasi_config_t,
    count: u32,
    keys: [*]const [*]const u8,
    key_lens: [*]const usize,
    vals: [*]const [*]const u8,
    val_lens: [*]const usize,
) void {
    config.env_keys.clearRetainingCapacity();
    config.env_vals.clearRetainingCapacity();
    config.env_key_lens.clearRetainingCapacity();
    config.env_val_lens.clearRetainingCapacity();
    for (0..count) |i| {
        config.env_keys.append(keys[i]) catch {};
        config.env_vals.append(vals[i]) catch {};
        config.env_key_lens.append(key_lens[i]) catch {};
        config.env_val_lens.append(val_lens[i]) catch {};
    }
}

/// Add a preopened directory mapping for WASI.
export fn zwasm_wasi_config_preopen_dir(
    config: *zwasm_wasi_config_t,
    host_path: [*]const u8,
    host_path_len: usize,
    guest_path: [*]const u8,
    guest_path_len: usize,
) void {
    config.preopen_host.append(host_path) catch {};
    config.preopen_host_lens.append(host_path_len) catch {};
    config.preopen_guest.append(guest_path) catch {};
    config.preopen_guest_lens.append(guest_path_len) catch {};
}

/// Create a new WASI module with custom configuration.
/// Returns null on error.
export fn zwasm_module_new_wasi_configured(
    wasm_ptr: [*]const u8,
    len: usize,
    config: *zwasm_wasi_config_t,
) ?*zwasm_module_t {
    clearError();

    // Build WasiOptions from config
    // argv: slice of sentinel-terminated pointers — direct from config
    const argv_slice: []const [:0]const u8 = blk: {
        const items = config.argv.items;
        // Reinterpret [*:0]const u8 array as [:0]const u8 slice
        const ptr: [*]const [:0]const u8 = @ptrCast(items.ptr);
        break :blk ptr[0..items.len];
    };

    // env: build slices from stored pointers + lengths
    const gpa_alloc = std.heap.page_allocator;
    const env_keys = gpa_alloc.alloc([]const u8, config.env_keys.items.len) catch {
        setError(error.OutOfMemory);
        return null;
    };
    defer gpa_alloc.free(env_keys);
    const env_vals = gpa_alloc.alloc([]const u8, config.env_vals.items.len) catch {
        setError(error.OutOfMemory);
        return null;
    };
    defer gpa_alloc.free(env_vals);
    for (config.env_keys.items, config.env_key_lens.items, 0..) |ptr, l, i| {
        env_keys[i] = ptr[0..l];
    }
    for (config.env_vals.items, config.env_val_lens.items, 0..) |ptr, l, i| {
        env_vals[i] = ptr[0..l];
    }

    // preopens: build slices
    const preopens = gpa_alloc.alloc([]const u8, config.preopen_host.items.len) catch {
        setError(error.OutOfMemory);
        return null;
    };
    defer gpa_alloc.free(preopens);
    for (config.preopen_host.items, config.preopen_host_lens.items, 0..) |ptr, l, i| {
        preopens[i] = ptr[0..l];
    }

    const opts = WasiOptions{
        .args = argv_slice,
        .env_keys = env_keys,
        .env_vals = env_vals,
        .preopen_paths = preopens,
    };

    return CApiModule.createWasiConfigured(wasm_ptr[0..len], opts) catch |err| {
        setError(err);
        return null;
    };
}

// ============================================================
// Memory access
// ============================================================

/// Return a direct pointer to linear memory (memory index 0).
/// Returns null if the module has no memory.
/// WARNING: Pointer is invalidated by memory growth (any call that may grow memory).
export fn zwasm_module_memory_data(module: *zwasm_module_t) ?[*]u8 {
    const mem = module.module.instance.getMemory(0) catch return null;
    const bytes = mem.memory();
    if (bytes.len == 0) return null;
    return bytes.ptr;
}

/// Return the current size of linear memory in bytes.
/// Returns 0 if the module has no memory.
export fn zwasm_module_memory_size(module: *zwasm_module_t) usize {
    const mem = module.module.instance.getMemory(0) catch return 0;
    return mem.memory().len;
}

/// Read bytes from linear memory into out_buf. Returns false on out-of-bounds.
export fn zwasm_module_memory_read(
    module: *zwasm_module_t,
    offset: u32,
    len: u32,
    out_buf: [*]u8,
) bool {
    clearError();
    const mem = module.module.instance.getMemory(0) catch |err| {
        setError(err);
        return false;
    };
    const bytes = mem.memory();
    const end = @as(u64, offset) + @as(u64, len);
    if (end > bytes.len) {
        setError(error.OutOfBoundsMemoryAccess);
        return false;
    }
    @memcpy(out_buf[0..len], bytes[offset..][0..len]);
    return true;
}

/// Write bytes from data into linear memory. Returns false on out-of-bounds.
export fn zwasm_module_memory_write(
    module: *zwasm_module_t,
    offset: u32,
    data: [*]const u8,
    len: u32,
) bool {
    clearError();
    const mem = module.module.instance.getMemory(0) catch |err| {
        setError(err);
        return false;
    };
    const bytes = mem.memory();
    const end = @as(u64, offset) + @as(u64, len);
    if (end > bytes.len) {
        setError(error.OutOfBoundsMemoryAccess);
        return false;
    }
    @memcpy(bytes[offset..][0..len], data[0..len]);
    return true;
}

/// Return the last error message as a null-terminated C string.
/// Returns an empty string if no error has occurred.
/// The pointer is valid until the next C API call on the same thread.
export fn zwasm_last_error_message() [*:0]const u8 {
    if (error_len == 0) return "";
    if (error_len < ERROR_BUF_SIZE) {
        error_buf[error_len] = 0;
        return @ptrCast(error_buf[0..error_len :0]);
    }
    error_buf[ERROR_BUF_SIZE - 1] = 0;
    return @ptrCast(error_buf[0 .. ERROR_BUF_SIZE - 1 :0]);
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

const MINIMAL_WASM = &[_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };

test "c_api: module_new with minimal wasm" {
    const module = zwasm_module_new(MINIMAL_WASM.ptr, MINIMAL_WASM.len);
    try testing.expect(module != null);
    zwasm_module_delete(module.?);
}

test "c_api: module_new with invalid bytes returns null" {
    const bad = &[_]u8{ 0x00, 0x00, 0x00, 0x00 };
    const module = zwasm_module_new(bad.ptr, bad.len);
    try testing.expect(module == null);
    const msg = zwasm_last_error_message();
    try testing.expect(msg[0] != 0);
}

test "c_api: module_new_wasi with minimal wasm" {
    const module = zwasm_module_new_wasi(MINIMAL_WASM.ptr, MINIMAL_WASM.len);
    try testing.expect(module != null);
    zwasm_module_delete(module.?);
}

test "c_api: module_validate with valid wasm" {
    try testing.expect(zwasm_module_validate(MINIMAL_WASM.ptr, MINIMAL_WASM.len));
}

test "c_api: module_validate with invalid bytes" {
    const bad = &[_]u8{ 0x00, 0x00, 0x00, 0x00 };
    try testing.expect(!zwasm_module_validate(bad.ptr, bad.len));
    const msg = zwasm_last_error_message();
    try testing.expect(msg[0] != 0);
}

// Module with exported function "f" returning i32 42: () -> i32
const RETURN42_WASM = "\x00\x61\x73\x6d\x01\x00\x00\x00" ++
    "\x01\x05\x01\x60\x00\x01\x7f" ++ // type: () -> i32
    "\x03\x02\x01\x00" ++ // func section
    "\x07\x05\x01\x01\x66\x00\x00" ++ // export "f" = func 0
    "\x0a\x06\x01\x04\x00\x41\x2a\x0b"; // code: i32.const 42, end

test "c_api: invoke exported function" {
    const module = zwasm_module_new(RETURN42_WASM.ptr, RETURN42_WASM.len).?;
    defer zwasm_module_delete(module);

    var results = [_]u64{0};
    try testing.expect(zwasm_module_invoke(module, "f", null, 0, &results, 1));
    try testing.expectEqual(@as(u64, 42), results[0]);
}

test "c_api: invoke nonexistent function returns false" {
    const module = zwasm_module_new(RETURN42_WASM.ptr, RETURN42_WASM.len).?;
    defer zwasm_module_delete(module);

    try testing.expect(!zwasm_module_invoke(module, "nonexistent", null, 0, null, 0));
    const msg = zwasm_last_error_message();
    try testing.expect(msg[0] != 0);
}

// Module with 1-page memory exported as "memory" + function "store42" that stores 42 at offset 0
const MEMORY_WASM = "\x00\x61\x73\x6d\x01\x00\x00\x00" ++
    "\x01\x04\x01\x60\x00\x00" ++ // type: () -> ()
    "\x03\x02\x01\x00" ++ // func section
    "\x05\x03\x01\x00\x01" ++ // memory: min=0, max=1
    "\x07\x0d\x02\x01\x6d\x02\x00" ++ // export "m" = memory 0
    "\x01\x66\x00\x00" ++ // export "f" = func 0
    "\x0a\x0b\x01\x09\x00\x41\x00\x41\x2a\x36\x02\x00\x0b"; // code: i32.const 0, i32.const 42, i32.store, end

test "c_api: memory_data and memory_size" {
    const module = zwasm_module_new(MEMORY_WASM.ptr, MEMORY_WASM.len).?;
    defer zwasm_module_delete(module);

    const size = zwasm_module_memory_size(module);
    try testing.expect(size > 0); // At least 1 page = 65536 bytes

    const data = zwasm_module_memory_data(module);
    try testing.expect(data != null);
}

test "c_api: memory_write and memory_read" {
    const module = zwasm_module_new(MEMORY_WASM.ptr, MEMORY_WASM.len).?;
    defer zwasm_module_delete(module);

    // Write data
    const write_data = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    try testing.expect(zwasm_module_memory_write(module, 0, &write_data, 4));

    // Read it back
    var read_buf: [4]u8 = undefined;
    try testing.expect(zwasm_module_memory_read(module, 0, 4, &read_buf));
    try testing.expectEqualSlices(u8, &write_data, &read_buf);
}

test "c_api: memory_read out of bounds" {
    const module = zwasm_module_new(MEMORY_WASM.ptr, MEMORY_WASM.len).?;
    defer zwasm_module_delete(module);

    var buf: [1]u8 = undefined;
    try testing.expect(!zwasm_module_memory_read(module, 0xFFFFFFFF, 1, &buf));
}

test "c_api: export introspection" {
    const module = zwasm_module_new(RETURN42_WASM.ptr, RETURN42_WASM.len).?;
    defer zwasm_module_delete(module);

    try testing.expectEqual(@as(u32, 1), zwasm_module_export_count(module));

    const name = zwasm_module_export_name(module, 0);
    try testing.expect(name != null);
    try testing.expectEqualStrings("f", std.mem.sliceTo(name.?, 0));

    try testing.expectEqual(@as(u32, 0), zwasm_module_export_param_count(module, 0));
    try testing.expectEqual(@as(u32, 1), zwasm_module_export_result_count(module, 0));

    // Out of range
    try testing.expect(zwasm_module_export_name(module, 99) == null);
}

test "c_api: wasi config lifecycle" {
    const config = zwasm_wasi_config_new();
    try testing.expect(config != null);
    zwasm_wasi_config_delete(config.?);
}

test "c_api: last_error_message is empty after success" {
    _ = zwasm_module_validate(MINIMAL_WASM.ptr, MINIMAL_WASM.len);
    const msg = zwasm_last_error_message();
    try testing.expect(msg[0] == 0);
}
