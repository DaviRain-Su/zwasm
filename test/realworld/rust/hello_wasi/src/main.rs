use std::env;

fn main() {
    println!("Hello from Rust/WASI!");
    let args: Vec<String> = env::args().collect();
    println!("argc = {}", args.len());
    for (i, arg) in args.iter().enumerate() {
        println!("argv[{}] = {}", i, arg);
    }

    match env::var("HOME") {
        Ok(val) => println!("HOME = {}", val),
        Err(_) => println!("HOME not set"),
    }
}
