//! EH frequency runner skeleton (10.T-3; impl-body lands with 10.E).
//!
//! Per Phase 10 design plan §3.4 — once `feature/exception_handling/`
//! ships at row 10.E, this runner sweeps the throw-rate × catch-depth
//! matrix to verify try_table 0-byte emit (ADR-0114 §"Context"
//! invariant 2) does not regress the non-throwing fast path.
//!
//! Matrix:
//!
//!   throw_rate ∈ {0%, 1%, 50%, 100%}
//!   catch_depth ∈ {1, 10, 100}
//!
//! Pass criteria:
//!   - 0% throw_rate: latency matches baseline within 1%
//!     (try_table costs ZERO in fast path per ADR-0114 §"Decision" D3)
//!   - 100% throw_rate: throw → FP-walk unwind → catch is bounded
//!     by catch_depth × O(frame-chain-walk)
//!
//! Until 10.E lands, this runner reports "skeleton (10.E impl
//! pending)" + exits 0 so `test-all` stays green regardless.
//!
//! Per ROADMAP §10 / 10.T-3 + design plan §3.4 "テスト戦略".

const std = @import("std");

pub const std_options: std.Options = .{
    .enable_segfault_handler = false,
};

const ThrowRate = enum { p0, p1, p50, p100 };
const CatchDepth = enum(u32) { d1 = 1, d10 = 10, d100 = 100 };

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buf: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    try stdout.print("[eh_frequency_runner] skeleton (10.E impl pending; ADR-0114 Accept gate first)\n", .{});
    inline for (.{ ThrowRate.p0, .p1, .p50, .p100 }) |rate| {
        inline for (.{ CatchDepth.d1, .d10, .d100 }) |depth| {
            try stdout.print("  [SKIP-P10-EH-GAP] throw_rate={s} catch_depth={d} — awaits feature/exception_handling/ at row 10.E\n",
                .{ @tagName(rate), @intFromEnum(depth) });
        }
    }
    try stdout.flush();
}

test "eh_frequency_runner: matrix enumerates 4 throw_rate × 3 catch_depth = 12 cells" {
    var count: usize = 0;
    inline for (.{ ThrowRate.p0, .p1, .p50, .p100 }) |_| {
        inline for (.{ CatchDepth.d1, .d10, .d100 }) |_| {
            count += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 12), count);
}
