//! WASI Preview 2 `wasi:sockets` host backing (ADR-0180 Phase 1).
//!
//! The TCP-client subset's OS-facing half: a `TcpSocket` state machine
//! (`wasi:sockets/tcp` documented transitions: unbound → bind-in-progress →
//! bound → connect-in-progress → connected) over `std.Io.net` (the pinned
//! Zig 0.16 stdlib has NO raw `std.posix` socket surface — networking is
//! io-based, the same discipline the WASI fs host already follows via
//! `host.io`). The component trampolines (impl-2) lower WIT records onto
//! this surface; nothing here touches guest memory.
//!
//! DIVERGENCE from the wasmtime shape (noted in ADR-0180): `std.Io.net`'s
//! `connect` is synchronous, so the OS connect executes inside
//! `start-connect` and `finish-connect` returns the cached result — the
//! guest-observable contract (validate at start; establishment failures
//! surface at finish) is preserved without an async runtime. Readiness for
//! the poll(2)-honest pollables still comes from `posix.poll` on the
//! socket handle (`ready`).
//!
//! Zone 2 (`src/wasi/`). `std.Io.net` + `std.posix.poll` only — no new
//! libc surface (`libc_boundary`).

const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const net = std.Io.net;

/// `wasi:sockets/network` `error-code` — spec-pinned ordinals 0–20
/// (sockets.wit `enum error-code` declaration order).
pub const ErrorCode = enum(u8) {
    unknown = 0,
    access_denied = 1,
    not_supported = 2,
    invalid_argument = 3,
    out_of_memory = 4,
    timeout = 5,
    concurrency_conflict = 6,
    not_in_progress = 7,
    would_block = 8,
    invalid_state = 9,
    new_socket_limit = 10,
    address_not_bindable = 11,
    address_in_use = 12,
    remote_unreachable = 13,
    connection_refused = 14,
    connection_reset = 15,
    connection_aborted = 16,
    datagram_too_large = 17,
    name_unresolvable = 18,
    temporary_resolver_failure = 19,
    permanent_resolver_failure = 20,
};

/// `wasi:sockets/network` `ip-address-family` (enum: ipv4, ipv6).
pub const AddressFamily = enum(u8) { ipv4 = 0, ipv6 = 1 };

/// Map a Zig networking error onto the spec `error-code`. Errors with no
/// spec counterpart fall back to `unknown` (the spec's catch-all).
pub fn errorToCode(err: anyerror) ErrorCode {
    return switch (err) {
        error.AccessDenied, error.PermissionDenied => .access_denied,
        error.AddressFamilyUnsupported, error.ProtocolUnsupportedByAddressFamily, error.ProtocolUnsupportedBySystem, error.SocketModeUnsupported, error.OptionUnsupported => .not_supported,
        error.InvalidArgument, error.AddressUnavailable => .invalid_argument,
        error.SystemResources, error.OutOfMemory => .out_of_memory,
        error.ConnectionTimedOut, error.Timeout => .timeout,
        error.WouldBlock => .would_block,
        error.ProcessFdQuotaExceeded, error.SystemFdQuotaExceeded => .new_socket_limit,
        error.AddressInUse => .address_in_use,
        error.NetworkUnreachable, error.NetworkDown, error.HostUnreachable => .remote_unreachable,
        error.ConnectionRefused => .connection_refused,
        error.ConnectionResetByPeer => .connection_reset,
        error.ConnectionAborted => .connection_aborted,
        error.MessageTooBig => .datagram_too_large,
        else => .unknown,
    };
}

/// `wasi:sockets/tcp` documented state machine (client subset; `listening`
/// arrives with ADR-0180 Phase 2).
pub const TcpState = enum { unbound, bind_started, bound, connect_started, connected, closed };

/// One live TCP socket: spec state + the `std.Io.net` objects backing it.
/// The OS socket is created lazily by bind/connect (`std.Io.net` has no
/// bare-socket constructor; wasmtime is lazy the same way). The component
/// layer owns the resource handle; this struct owns the OS handle(s).
pub const TcpSocket = struct {
    family: AddressFamily,
    state: TcpState = .unbound,
    /// Set from `.bound` (start-bind path).
    socket: ?net.Socket = null,
    /// Set once the connect succeeded (start-connect path).
    stream: ?net.Stream = null,
    /// Establishment failure cached by start-connect, surfaced by
    /// finish-connect (the spec's two-phase contract).
    connect_err: ?anyerror = null,

    /// `tcp-create-socket.create-tcp-socket` — records the family; the OS
    /// socket is created by the first bind/connect.
    pub fn create(family: AddressFamily) TcpSocket {
        return .{ .family = family };
    }

    pub fn deinit(self: *TcpSocket, io: std.Io) void {
        if (self.stream) |s| s.close(io);
        if (self.socket) |s| s.close(io);
        self.stream = null;
        self.socket = null;
        self.state = .closed;
    }

    /// `tcp.start-bind`. The bind executes here; the two-step spec shape is
    /// honoured by the state transitions.
    pub fn startBind(self: *TcpSocket, io: std.Io, addr: net.IpAddress) !void {
        if (self.state != .unbound) return error.InvalidState;
        if (!familyMatches(self.family, addr)) return error.InvalidArgument;
        self.socket = try addr.bind(io, .{ .mode = .stream, .protocol = .tcp });
        self.state = .bind_started;
    }

    /// `tcp.finish-bind`.
    pub fn finishBind(self: *TcpSocket) !void {
        if (self.state != .bind_started) return error.NotInProgress;
        self.state = .bound;
    }

    /// `tcp.start-connect`. The synchronous `std.Io.net` connect executes
    /// here; a failure is cached for finish-connect (see module docstring).
    /// Connecting FROM an explicitly bound socket is Phase-2 scope
    /// (`std.Io.net` has no bound-socket connect) — truthful not-supported.
    pub fn startConnect(self: *TcpSocket, io: std.Io, addr: net.IpAddress) !void {
        if (self.state == .bound or self.state == .bind_started) return error.OptionUnsupported;
        if (self.state != .unbound) return error.InvalidState;
        if (!familyMatches(self.family, addr)) return error.InvalidArgument;
        self.state = .connect_started;
        self.stream = addr.connect(io, .{ .mode = .stream, .protocol = .tcp }) catch |err| {
            self.connect_err = err;
            return;
        };
    }

    /// `tcp.finish-connect` — the cached start-connect result.
    pub fn finishConnect(self: *TcpSocket) !void {
        if (self.state != .connect_started) return error.NotInProgress;
        if (self.connect_err) |err| {
            self.state = .closed;
            return err;
        }
        self.state = .connected;
    }

    /// Socket-backed input-stream `read` (one-shot; blocks under the
    /// Threaded io until data arrives — the `blocking-read` contract; the
    /// non-blocking `read` trampoline gates on `ready` first).
    pub fn recv(self: *TcpSocket, io: std.Io, buf: []u8) !usize {
        const stream = self.connectedStream() orelse return error.InvalidState;
        var bufs = [_][]u8{buf};
        return io.vtable.netRead(io.userdata, stream.socket.handle, &bufs);
    }

    /// Socket-backed output-stream `write` (one-shot).
    pub fn send(self: *TcpSocket, io: std.Io, bytes: []const u8) !usize {
        const stream = self.connectedStream() orelse return error.InvalidState;
        const data = [_][]const u8{bytes};
        return io.vtable.netWrite(io.userdata, stream.socket.handle, "", &data, 1);
    }

    /// Readiness for the poll(2)-honest pollable (ADR-0180): is the
    /// connected socket ready for `interest` (POLL.IN / POLL.OUT) now?
    pub fn ready(self: *TcpSocket, interest: i16) !bool {
        const stream = self.connectedStream() orelse return error.InvalidState;
        return pollOnce(stream.socket.handle, interest);
    }

    fn connectedStream(self: *TcpSocket) ?net.Stream {
        if (self.state != .connected) return null;
        return self.stream;
    }
};

fn familyMatches(family: AddressFamily, addr: net.IpAddress) bool {
    return switch (addr) {
        .ip4 => family == .ipv4,
        .ip6 => family == .ipv6,
    };
}

/// One zero-timeout poll(2) on a single socket handle: true iff `interest`
/// (or an error/hup condition, which also unblocks a waiter) is pending.
fn pollOnce(handle: net.Socket.Handle, interest: i16) !bool {
    switch (builtin.os.tag) {
        // WSAPoll wiring is ADR-0180 Phase-2 scope (D-319).
        .windows => @panic("wasi:sockets readiness poll on Windows pending (D-319, ADR-0180 Phase 2)"),
        else => {
            var fds = [_]posix.pollfd{.{ .fd = handle, .events = interest, .revents = 0 }};
            const n = try posix.poll(&fds, 0);
            return n > 0 and (fds[0].revents & (interest | posix.POLL.ERR | posix.POLL.HUP)) != 0;
        },
    }
}

// ============================================================
// Tests
// ============================================================
const testing = std.testing;
const skip = @import("../test_support/skip.zig");

test "tcp client lifecycle: create → connect → echo against a loopback listener" {
    // Windows socket-host verification is ADR-0180 Phase-2 scope (D-319).
    if (builtin.os.tag == .windows) return skip.blocker(.@"D-319");
    var threaded: std.Io.Threaded = .init(testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    // In-test loopback listener on an ephemeral port (the impl-3 e2e host
    // echo server's seed).
    const listen_addr: net.IpAddress = .{ .ip4 = net.Ip4Address.loopback(0) };
    var server = try listen_addr.listen(io, .{ .mode = .stream, .protocol = .tcp });
    defer server.deinit(io);
    const port = server.socket.address.getPort();

    var client = TcpSocket.create(.ipv4);
    defer client.deinit(io);
    try client.startConnect(io, .{ .ip4 = net.Ip4Address.loopback(port) });
    try client.finishConnect();
    try testing.expectEqual(TcpState.connected, client.state);

    var conn = try server.accept(io);
    defer conn.close(io);

    // client → server
    try testing.expectEqual(@as(usize, 4), try client.send(io, "ping"));
    var srv_buf: [16]u8 = undefined;
    var srv_bufs = [_][]u8{&srv_buf};
    const got = try io.vtable.netRead(io.userdata, conn.socket.handle, &srv_bufs);
    try testing.expectEqualStrings("ping", srv_buf[0..got]);

    // server → client; readiness flips the client's POLL.IN pollable.
    const reply = [_][]const u8{"pong"};
    _ = try io.vtable.netWrite(io.userdata, conn.socket.handle, "", &reply, 1);
    var attempts: u32 = 0;
    while (!(try client.ready(posix.POLL.IN)) and attempts < 500) : (attempts += 1) {
        try io.sleep(.{ .nanoseconds = 2 * std.time.ns_per_ms }, .awake);
    }
    try testing.expect(try client.ready(posix.POLL.IN));
    var cli_buf: [16]u8 = undefined;
    const echoed = try client.recv(io, &cli_buf);
    try testing.expectEqualStrings("pong", cli_buf[0..echoed]);
}

test "tcp state machine: invalid transitions are rejected" {
    if (builtin.os.tag == .windows) return skip.blocker(.@"D-319");
    var threaded: std.Io.Threaded = .init(testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var sock = TcpSocket.create(.ipv4);
    defer sock.deinit(io);
    // finish before start → not-in-progress.
    try testing.expectError(error.NotInProgress, sock.finishBind());
    try testing.expectError(error.NotInProgress, sock.finishConnect());
    // recv/send/ready before connected → invalid-state.
    var buf: [4]u8 = undefined;
    try testing.expectError(error.InvalidState, sock.recv(io, &buf));
    try testing.expectError(error.InvalidState, sock.send(io, "x"));
    try testing.expectError(error.InvalidState, sock.ready(posix.POLL.IN));
    // family mismatch → invalid-argument.
    try testing.expectError(error.InvalidArgument, sock.startConnect(io, .{ .ip6 = net.Ip6Address.loopback(1) }));
    // bind twice → invalid-state on the second start-bind.
    try sock.startBind(io, .{ .ip4 = net.Ip4Address.loopback(0) });
    try testing.expectError(error.InvalidState, sock.startBind(io, .{ .ip4 = net.Ip4Address.loopback(0) }));
    try sock.finishBind();
    try testing.expectEqual(TcpState.bound, sock.state);
    // bound → connect is Phase-2 scope (std.Io.net has no bound connect).
    try testing.expectError(error.OptionUnsupported, sock.startConnect(io, .{ .ip4 = net.Ip4Address.loopback(1) }));
}

test "tcp connect to a closed port surfaces connection-refused at finish-connect" {
    if (builtin.os.tag == .windows) return skip.blocker(.@"D-319");
    var threaded: std.Io.Threaded = .init(testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    // Grab an ephemeral port, then close the listener so nothing accepts.
    const listen_addr: net.IpAddress = .{ .ip4 = net.Ip4Address.loopback(0) };
    var server = try listen_addr.listen(io, .{ .mode = .stream, .protocol = .tcp });
    const port = server.socket.address.getPort();
    server.deinit(io);

    var sock = TcpSocket.create(.ipv4);
    defer sock.deinit(io);
    try sock.startConnect(io, .{ .ip4 = net.Ip4Address.loopback(port) });
    try testing.expectError(error.ConnectionRefused, sock.finishConnect());
    try testing.expectEqual(ErrorCode.connection_refused, errorToCode(error.ConnectionRefused));
}

test "errorToCode: spec ordinals pinned" {
    try testing.expectEqual(@as(u8, 8), @intFromEnum(ErrorCode.would_block));
    try testing.expectEqual(@as(u8, 9), @intFromEnum(ErrorCode.invalid_state));
    try testing.expectEqual(@as(u8, 12), @intFromEnum(errorToCode(error.AddressInUse)));
    try testing.expectEqual(@as(u8, 14), @intFromEnum(errorToCode(error.ConnectionRefused)));
    try testing.expectEqual(@as(u8, 20), @intFromEnum(ErrorCode.permanent_resolver_failure));
    try testing.expectEqual(ErrorCode.unknown, errorToCode(error.Unexpected));
}
