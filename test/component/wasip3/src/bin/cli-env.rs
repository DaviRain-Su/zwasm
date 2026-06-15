fn main() {
    match std::env::var("WASI_TEST").as_deref() {
        Ok("ok") => std::process::exit(0),
        _ => std::process::exit(1),
    }
}
