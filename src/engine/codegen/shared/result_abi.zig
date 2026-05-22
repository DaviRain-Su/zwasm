//! Result-marshal ABI selector for JIT-compiled functions
//! (ADR-0106 path (a) cycle 2 foundation).
//!
//! Threaded into `arm64/emit.zig::compile()` + `x86_64/emit.zig::compile()`
//! to select between the legacy register-write epilogue
//! (per-class C-ABI: RAX/RDX/XMM0/XMM1 on x86_64, X0..X7/V0..V7
//! on arm64) and the new buffer-write epilogue per
//! `entry_buffer_write.zig::BufferWriteFn`.
//!
//! Per the ADR-0106 cycle 2 design spike at
//! `private/spikes/adr-0106-cycle2/SPIKE.md` (Alt 2 chosen), the
//! migration phases:
//!
//! - Cycle 2a (this commit): introduce the enum; ALL callers
//!   pass `.register_write`; no emit behaviour change.
//! - Cycle 2b/2c: x86_64 + arm64 emit branch on the flag at
//!   prologue (capture `results` ptr arg) + epilogue (write
//!   results[i] instead of RAX/RDX / X0/X1).
//! - Cycle 3: migrate spec runner / c_api / entry-helper
//!   callsites to `.buffer_write` for the buffer-write entry
//!   helper variant.
//! - Cycle 4: flip default to `.buffer_write`, remove legacy
//!   `register_write` path, remove `FuncRet_*` extern struct
//!   family from `entry.zig`, remove `SKIP-WIN64-MULTI-RESULT`
//!   from spec runner. D-094 + D-164 close.
//!
//! Zone 2 (`src/engine/codegen/shared/`).

const std = @import("std");

pub const ResultAbi = enum {
    /// Legacy per-class register-write epilogue. Multi-result on
    /// Win64 mis-marshals via hidden RCX struct-return — the
    /// D-164 root cause documented in ADR-0106 §"Context".
    register_write,
    /// Buffer-write epilogue per ADR-0106 path (a). The JIT body
    /// writes each result to `[results_ptr + 8*i]`; the entry
    /// helper's signature is `fn(*JitRuntime, [*]u64 results,
    /// [*]const u64 args) callconv(.c) ErrCode`. Win64-safe
    /// (single u64 ErrCode return); SysV / AAPCS64 use the same
    /// uniform shape.
    buffer_write,
};

const testing = std.testing;

test "ResultAbi: enum values present" {
    const r: ResultAbi = .register_write;
    const b: ResultAbi = .buffer_write;
    try testing.expect(r != b);
}
