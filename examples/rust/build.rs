use std::{env, path::PathBuf};

fn main() {
    let manifest = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let lib_dir = manifest
        .join("..")
        .join("..")
        .join("zig-out")
        .join("lib")
        .canonicalize()
        .expect("zig-out/lib not found — run `zig build lib` first");

    if env::var("ZWASM_STATIC").is_ok() {
        // Static linking: requires libzwasm.a built with -Dpic=true -Dcompiler-rt=true
        // Copy only the .a to a temp dir to prevent the linker from picking the .dylib/.so
        let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
        let static_dir = out_dir.join("zwasm_static");
        std::fs::create_dir_all(&static_dir).unwrap();
        std::fs::copy(lib_dir.join("libzwasm.a"), static_dir.join("libzwasm.a")).unwrap();
        println!("cargo:rustc-link-search=native={}", static_dir.display());
        println!("cargo:rustc-link-lib=static=zwasm");
        println!("cargo:rustc-link-lib=c");
        println!("cargo:rustc-link-lib=m");
    } else {
        // Dynamic linking (default)
        println!("cargo:rustc-link-search=native={}", lib_dir.display());
        println!("cargo:rustc-link-lib=zwasm");
        println!("cargo:rustc-link-arg=-Wl,-rpath,{}", lib_dir.display());
    }
}
