use sha2::{Digest, Sha256};

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn main() {
    // Test vectors
    let tests: Vec<(&str, &str)> = vec![
        (
            "",
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        ),
        (
            "abc",
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        ),
        (
            "Hello, SHA-256!",
            "d0e8b8f11c98f369016eb2ed3c541e1f01382f9d5b3104c9ffd06b6175a46271",
        ),
    ];

    let mut pass = 0;
    for (input, expected) in &tests {
        let mut hasher = Sha256::new();
        hasher.update(input.as_bytes());
        let result = hex(&hasher.finalize());
        if result == *expected {
            pass += 1;
            println!("PASS: sha256(\"{input}\") = {result}");
        } else {
            println!("FAIL: sha256(\"{input}\") = {result} (expected {expected})");
        }
    }

    // Incremental hashing
    let mut hasher = Sha256::new();
    hasher.update(b"Hello, ");
    hasher.update(b"SHA-256!");
    let incremental = hex(&hasher.finalize());
    let expected = "d0e8b8f11c98f369016eb2ed3c541e1f01382f9d5b3104c9ffd06b6175a46271";
    if incremental == expected {
        pass += 1;
        println!("PASS: incremental hash matches");
    } else {
        println!("FAIL: incremental hash mismatch");
    }

    println!("sha256 tests: {pass}/4 passed");
    if pass == 4 {
        println!("result: OK");
    } else {
        println!("result: FAIL");
    }
}
