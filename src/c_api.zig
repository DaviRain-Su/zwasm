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

test "c_api: last_error_message is empty after success" {
    _ = zwasm_module_validate(MINIMAL_WASM.ptr, MINIMAL_WASM.len);
    const msg = zwasm_last_error_message();
    try testing.expect(msg[0] == 0);
}
