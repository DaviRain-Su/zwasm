//! WASI 0.3 conformance: read argv[1]; success = exit(0) (the wasi:cli/exit
//! result<_,_> channel can only signal ok/err, so 0 is the only success code).
fn main() {
    match std::env::args().nth(1).as_deref() {
        Some("hello") => std::process::exit(0),
        _ => std::process::exit(1),
    }
}
