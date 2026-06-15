//! WASI 0.3 conformance (mirrors wasi-testsuite cli-exit): the program exits
//! with a failure status, so the runtime must report exit code 1.
fn main() {
    std::process::exit(1);
}
