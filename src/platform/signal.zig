//! Production internal-fault handler (ADR-0166, D-292 B-core).
//!
//! v2 uses NO signal-based wasm trap semantics — every wasm trap is an explicit
//! check surfacing as `Error.Trap` (CLI exit 1 + a `trap kind=…` line). So ANY
//! fatal signal that reaches the OS is a zwasm-INTERNAL bug, never normal
//! operation. `installInternalFaultHandler` (called once from `cli/main.zig`)
//! installs a diagnostic-only, last-resort handler: on an unintended
//! SIGSEGV/SIGBUS/SIGILL/SIGFPE it writes a fixed "internal error" line
//! (async-signal-safe) and `_exit`s with a DISTINCT code, instead of a silent
//! signal-death — so the fault is diagnosable and clearly NOT a wasm trap.
//!
//! Diagnostic-only: it always EXITS, never resumes (no recovery, unlike the
//! test runner's `spec_assert_runner_base.installSigsegvHandler` which
//! siglongjmps for JIT-trap recovery). Windows lands in ADR-0166 cycle II.
//!
//! Zone 0 (`src/platform/`).

const builtin = @import("builtin");
const std = @import("std");
const skip = @import("../test_support/skip.zig");

/// EX_SOFTWARE (sysexits.h) — "an internal software error". Distinct from CLI
/// exit 1 (a clean wasm trap) and from a signal-default death (128+signo), so
/// the three outcomes are unambiguous to a caller / CI.
pub const INTERNAL_ERROR_EXIT_CODE: u8 = 70;

const enabled = builtin.os.tag != .windows and builtin.os.tag != .wasi;

/// Async-signal-safe raw write(2) — POSIX signal-safety(7). The `std.posix.write`
/// wrapper returns an error union (forcing a fallback in a signal context); the
/// raw libc primitive is the canonical async-signal-safe write. ADR-0070
/// necessary (production signal-handler site; same rationale as `_exit`).
extern "c" fn write(fd: c_int, buf: [*]const u8, count: usize) isize;

// Page-aligned alternate signal stack so a stack-overflow SIGSEGV (host-side deep
// native recursion, cf. D-288) can still run the handler on a fresh stack.
const ALT_STACK_SIZE: usize = 1 << 16; // 64 KiB
var alt_stack: [ALT_STACK_SIZE]u8 align(std.heap.page_size_max) = undefined;

const INTERNAL_ERROR_MSG =
    "zwasm: internal error — caught a fatal signal. This is a bug in zwasm " ++
    "(not a wasm trap); please report it.\n";

fn faultHandler(_: std.posix.SIG, _: *const std.posix.siginfo_t, _: ?*anyopaque) callconv(.c) void {
    // Async-signal-safe only: raw write(2) + `_exit` (skips atexit/stdio). No
    // allocation, no formatting, no recovery — always exits.
    _ = write(2, INTERNAL_ERROR_MSG, INTERNAL_ERROR_MSG.len);
    std.c._exit(INTERNAL_ERROR_EXIT_CODE);
}

/// Install the diagnostic-only internal-fault handler. Call once at CLI startup
/// (production entry). No-op on Windows (ADR-0166 cycle II) + wasi. NOT installed
/// by the test harness — the spec runners own their own (recovery) handler; this
/// is the production last-resort disposition.
pub fn installInternalFaultHandler() void {
    if (comptime !enabled) return;
    std.posix.sigaltstack(&.{
        .sp = &alt_stack,
        .flags = 0,
        .size = alt_stack.len,
    }, null) catch |err| {
        // Non-fatal: the handler still works without an altstack for the common
        // (non-stack-overflow) fault. Surface it; do NOT abort startup.
        std.debug.print("zwasm: warning: sigaltstack failed ({s}); fault handler degraded\n", .{@errorName(err)});
    };
    var act: std.posix.Sigaction = .{
        .handler = .{ .sigaction = faultHandler },
        .mask = std.posix.sigemptyset(),
        .flags = std.posix.SA.ONSTACK | std.posix.SA.SIGINFO,
    };
    std.posix.sigaction(.SEGV, &act, null);
    std.posix.sigaction(.BUS, &act, null);
    std.posix.sigaction(.ILL, &act, null);
    std.posix.sigaction(.FPE, &act, null);
}

test "installInternalFaultHandler: a fault in a forked child exits 70 (handler ran), not a signal-death" {
    // Windows handler = ADR-0166 cycle II; comptime gate also prunes the POSIX
    // fork tail (std.c.fork is not declared on Windows) — mirrors the realworld
    // runner's `if (comptime !use_fork)` pattern.
    if (comptime !enabled) return skip.phaseEnd(.win64);
    // fork the test process: the child installs the handler + deliberately
    // faults; the parent verifies the child EXITED with code 70 (the handler
    // ran + _exit'd cleanly) rather than being killed by the signal (which would
    // be WIFSIGNALED). std.c.fork/waitpid = ADR-0070 necessary (test-only).
    const pid = std.c.fork();
    try std.testing.expect(pid != -1); // fork must succeed on a POSIX test host
    if (pid == 0) {
        installInternalFaultHandler();
        const p: *allowzero volatile u8 = @ptrFromInt(0); // null page → SIGSEGV
        p.* = 0;
        std.c._exit(1); // unreachable if the handler fired
    }
    var status: c_int = 0;
    _ = std.c.waitpid(pid, &status, 0);
    const ustatus: u32 = @bitCast(status);
    try std.testing.expect(std.posix.W.IFEXITED(ustatus));
    try std.testing.expectEqual(@as(u32, INTERNAL_ERROR_EXIT_CODE), std.posix.W.EXITSTATUS(ustatus));
}
