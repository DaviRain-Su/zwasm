//! `Caller` — host-fn execution context per ADR-0109 §3.2.
//!
//! Passed as the first parameter of every host function registered
//! via `Linker.defineFunc`. Provides access to the *importing*
//! instance's runtime state (linear memory, allocator) so the host
//! fn can read / write through it without smuggling a back-pointer
//! out-of-band.

const std = @import("std");

const _runtime = @import("../runtime/runtime.zig");
const _memory = @import("memory.zig");

pub const Caller = struct {
    rt: *_runtime.Runtime,

    pub fn memory(self: Caller) ?_memory.Memory {
        if (self.rt.memory.len == 0) return null;
        return .{ .rt = self.rt };
    }

    pub fn allocator(self: Caller) std.mem.Allocator {
        return self.rt.alloc;
    }
};
