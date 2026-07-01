//! WASI 0.3 conformance: read all of stdin; success (== "hello") = exit(0).
use std::io::Read;
fn main() {
    let mut buf = String::new();
    let _ = std::io::stdin().read_to_string(&mut buf);
    std::process::exit(if buf == "hello" { 0 } else { 1 });
}
