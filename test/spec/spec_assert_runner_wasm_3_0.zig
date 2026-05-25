//! Wasm 3.0 spec assertion runner skeleton (10.T-2b).
//!
//! Sub-corpus selector for the 5 Wasm 3.0 proposals (memory64 /
//! tail-call / exception-handling / gc / function-references).
//! Currently a SKELETON — enumerates the baked manifests under
//! `<corpus-root>/<proposal>/<name>/manifest.txt` and reports
//! per-proposal directive counts. JIT-execute + actual assertion
//! matching comes online cycle-by-cycle as impl rows 10.M / 10.R /
//! 10.TC / 10.E / 10.G land (each impl row will adopt the
//! `spec_assert_runner_base` callbacks pattern once its proposal's
//! ZIR / runtime / codegen surface exists).
//!
//! Until then this runner serves as the **observable wiring** —
//! `zig build test-spec-wasm-3.0-assert` builds + runs it,
//! exiting clean against the smoke-baked corpus (10.T-2a). When
//! the corpus is absent (e.g. fresh checkout before 10.T-1 /
//! 10.T-2a land), reports `0 manifests` and exits clean — same
//! shape as the wasm-2.0-assert runner so test-all stays green
//! regardless of corpus state.
//!
//! Usage:
//!   spec_assert_runner_wasm_3_0 <corpus-root>
//!
//! Per ROADMAP §10 / 10.T-2b + Phase 10 design plan §4.6.

const std = @import("std");

pub const std_options: std.Options = .{
    .enable_segfault_handler = false,
};

const PROPOSALS = [_][]const u8{
    "memory64",
    "tail-call",
    "exception-handling",
    "gc",
    "function-references",
};

const ProposalSummary = struct {
    name: []const u8,
    manifests: u32 = 0,
    modules: u32 = 0,
    asserts_return: u32 = 0,
    asserts_trap: u32 = 0,
    asserts_invalid: u32 = 0,
    asserts_malformed: u32 = 0,
    asserts_exception: u32 = 0,
    skips: u32 = 0,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.next() orelse return;
    const corpus_root = args.next() orelse {
        try stdout.print("usage: spec_assert_runner_wasm_3_0 <corpus-root>\n", .{});
        try stdout.flush();
        return;
    };

    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, corpus_root, .{}) catch {
        try stdout.print("[wasm-3.0-assert] corpus root not found: {s} (0 manifests; exit 0)\n", .{corpus_root});
        try stdout.flush();
        return;
    };
    defer dir.close(io);

    var grand_total_manifests: u32 = 0;
    var grand_total_directives: u32 = 0;

    for (PROPOSALS) |proposal| {
        var summary: ProposalSummary = .{ .name = proposal };

        var pdir = dir.openDir(io, proposal, .{ .iterate = true }) catch {
            try stdout.print("[{s}] (no subdir; 0 manifests)\n", .{proposal});
            continue;
        };
        defer pdir.close(io);

        var it = pdir.iterate();
        while (try it.next(io)) |entry| {
            if (entry.kind != .directory) continue;
            if (std.mem.eql(u8, entry.name, "raw")) continue;

            const manifest_path = try std.fmt.allocPrint(gpa, "{s}/manifest.txt", .{entry.name});
            defer gpa.free(manifest_path);

            const manifest = pdir.readFileAlloc(io, manifest_path, gpa, .limited(1 << 20)) catch continue;
            defer gpa.free(manifest);

            summary.manifests += 1;
            var lines = std.mem.splitScalar(u8, manifest, '\n');
            while (lines.next()) |line| {
                if (line.len == 0) continue;
                if (std.mem.startsWith(u8, line, "module ")) summary.modules += 1
                else if (std.mem.startsWith(u8, line, "assert_return ")) summary.asserts_return += 1
                else if (std.mem.startsWith(u8, line, "assert_trap ")) summary.asserts_trap += 1
                else if (std.mem.startsWith(u8, line, "assert_invalid ")) summary.asserts_invalid += 1
                else if (std.mem.startsWith(u8, line, "assert_malformed ")) summary.asserts_malformed += 1
                else if (std.mem.startsWith(u8, line, "assert_exception ")) summary.asserts_exception += 1
                else if (std.mem.startsWith(u8, line, "skip-")) summary.skips += 1;
            }
        }

        const total_directives = summary.modules + summary.asserts_return + summary.asserts_trap +
            summary.asserts_invalid + summary.asserts_malformed + summary.asserts_exception + summary.skips;
        try stdout.print(
            "[{s:<22}] manifests={d:<3} module={d:<3} return={d:<4} trap={d:<3} invalid={d:<3} malformed={d:<3} exception={d:<3} skip={d}\n",
            .{ proposal, summary.manifests, summary.modules, summary.asserts_return, summary.asserts_trap,
               summary.asserts_invalid, summary.asserts_malformed, summary.asserts_exception, summary.skips },
        );
        grand_total_manifests += summary.manifests;
        grand_total_directives += total_directives;
    }

    try stdout.print(
        "[wasm-3.0-assert] total: {d} manifests, {d} directives (skeleton; JIT-execute lands per impl row 10.M/10.R/10.TC/10.E/10.G)\n",
        .{ grand_total_manifests, grand_total_directives },
    );
    try stdout.flush();
}

test "wasm-3.0-assert: PROPOSALS list matches design plan §3.1-§3.5 + §4.6" {
    try std.testing.expectEqual(@as(usize, 5), PROPOSALS.len);
    try std.testing.expectEqualStrings("memory64", PROPOSALS[0]);
    try std.testing.expectEqualStrings("tail-call", PROPOSALS[1]);
    try std.testing.expectEqualStrings("exception-handling", PROPOSALS[2]);
    try std.testing.expectEqualStrings("gc", PROPOSALS[3]);
    try std.testing.expectEqualStrings("function-references", PROPOSALS[4]);
}
