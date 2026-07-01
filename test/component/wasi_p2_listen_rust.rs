// ADR-0180 Phase-2 existence proof: a real `rustc --target wasm32-wasip2`
// std::net::TcpListener guest. Binds the port given as argv[1], accepts one
// connection, echoes the received bytes + "-ack", and reports via stdout.
// Exercises start/finish-listen, accept (3-tuple mint), local-address,
// remote-address (rust std reads the peer addr on accept), and the
// listener-readiness pollable (accept blocks via subscribe + poll).
use std::io::{Read, Write};
use std::net::TcpListener;

fn main() {
    let port: u16 = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .expect("usage: tcp_listen <port>");
    let listener = TcpListener::bind(("127.0.0.1", port)).expect("bind failed");
    let local = listener.local_addr().expect("local_addr failed");
    let (mut conn, _peer) = listener.accept().expect("accept failed");
    let mut buf = [0u8; 16];
    let n = conn.read(&mut buf).expect("read failed");
    conn.write_all(&buf[..n]).expect("write failed");
    conn.write_all(b"-ack").expect("write failed");
    println!("served {} on {}", String::from_utf8_lossy(&buf[..n]), local.port());
}
