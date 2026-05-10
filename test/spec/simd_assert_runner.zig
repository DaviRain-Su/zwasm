//! SIMD spec assertion runner — JIT-execute + compare against
//! `assert_return` expectations on the WebAssembly testsuite SIMD
//! bundle (§9.9 per ADR-0045).
//!
//! Parallel runner to `spec_assert_runner.zig`; consumes a v128-
//! aware text manifest format that extends the scalar shape with
//! `v128:<32 hex digits>` tokens for 128-bit bit-pattern args /
//! results (see ADR-0045 §"Decision" / 2).
//!
//! §9.9-a (this commit) — **foundation**: walks the corpus root,
//! reports the manifest count, exits 0 if 0 manifests are wired
//! (current state — manifest population starts at §9.9-b). The
//! runner skeleton + build.zig wiring + manifest format spec
//! (per ADR-0045) form the load-bearing scaffold; subsequent
//! chunks add manifests and assertion logic.
//!
//! Usage:
//!   simd_assert_runner <corpus-root>
//! exits non-zero if any `failed > 0`.

const std = @import("std");

const zwasm = @import("zwasm");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    _ = zwasm; // foundation; assertion logic lands in §9.9-b+

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    var arg_it = try std.process.Args.Iterator.initAllocator(init.minimal.args, gpa);
    defer arg_it.deinit();
    _ = arg_it.next().?;
    const corpus_root_arg = arg_it.next() orelse {
        try stdout.print("usage: simd_assert_runner <corpus-root>\n", .{});
        try stdout.flush();
        std.process.exit(2);
    };
    const corpus_root = try gpa.dupe(u8, corpus_root_arg);
    defer gpa.free(corpus_root);

    const passed: u32 = 0;
    const failed: u32 = 0;
    const skipped: u32 = 0;
    var manifest_count: u32 = 0;

    const cwd = std.Io.Dir.cwd();
    var root = cwd.openDir(io, corpus_root, .{ .iterate = true }) catch |err| {
        // Foundation phase: a missing corpus dir is acceptable
        // (no manifests wired yet). Report 0/0/0 and exit clean.
        try stdout.print("simd_assert_runner: corpus '{s}' not found ({s}); 0 manifests (§9.9-a foundation)\n", .{ corpus_root, @errorName(err) });
        try stdout.flush();
        return;
    };
    defer root.close(io);

    var iter = root.iterate();
    while (try iter.next(io)) |dir_entry| {
        if (dir_entry.kind != .directory) continue;
        manifest_count += 1;
        // §9.9-b: walk each subdirectory's manifest.txt + invoke
        // JIT for each `assert_return` directive. Stub for now —
        // count subdirs to confirm corpus discovery works.
    }

    try stdout.print(
        "simd_assert_runner: {d} passed, {d} failed, {d} skipped (over {d} manifests; §9.9-a foundation, assertion logic deferred to §9.9-b)\n",
        .{ passed, failed, skipped, manifest_count },
    );
    try stdout.flush();

    if (failed > 0) std.process.exit(1);
}
