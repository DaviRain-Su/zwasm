# `wasi_p2_listen_rust.wasm` — real Rust TCP **listener** fixture (ADR-0180 Phase 2)

The Phase-2 existence proof: a genuine `rustc --target wasm32-wasip2`
`std::net::TcpListener` guest that binds the port given as `argv[1]`,
blocks in `accept` (listener-readiness pollable: subscribe + poll),
accepts the host's connection, echoes the received bytes + `-ack`, and
prints `served <msg> on <port>` (the port from a REAL `local-address`).

Exercises the full listener surface: `start-listen`/`finish-listen`,
`accept` (3-tuple `own<tcp-socket, input-stream, output-stream>` mint),
`local-address`, `remote-address` (rust std reads the peer address on
accept), `set-listen-backlog-size` (if rust std issues it), and
socket-backed stream reads/writes on the ACCEPTED connection.

## Source

`wasi_p2_listen_rust.rs`.

## Build (Mac gen host only)

```sh
nix develop ../..#gen --command bash -c '
  rustc --target wasm32-wasip2 -O wasi_p2_listen_rust.rs -o /tmp/listen.wasm
  wasm-tools strip /tmp/listen.wasm -o wasi_p2_listen_rust.wasm
  wasm-tools validate --features component-model wasi_p2_listen_rust.wasm'
```

Asserted in `src/api/component.zig` ("ADR-0180 Phase 2"): the e2e test
picks a free loopback port, runs a concurrent host CLIENT
(retry-connect → "ping" → read "ping-ack"), and drives the guest's main.
Windows execution is D-319-gated until WSAPoll lands.
