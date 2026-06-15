//! WASI 0.3 conformance: write a known string to stderr (proves cli/stderr).
fn main() {
    eprint!("zwasm-wasip3-err");
}
