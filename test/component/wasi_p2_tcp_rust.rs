use std::io::{Read, Write};
use std::net::TcpStream;

fn main() {
    let port: u16 = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .expect("usage: tcp_echo <port>");
    let mut stream = TcpStream::connect(("127.0.0.1", port)).expect("connect failed");
    stream.write_all(b"ping").expect("write failed");
    let mut buf = [0u8; 16];
    let n = stream.read(&mut buf).expect("read failed");
    println!("got {}", String::from_utf8_lossy(&buf[..n]));
}
