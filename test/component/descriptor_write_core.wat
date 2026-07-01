;; Core module for the WASI-P2 descriptor.write unit test. Receives a descriptor
;; resource handle as run's param (the test mints it from a preopen fd), writes
;; "HELLO-FS" at offset 0 via [method]descriptor.write, then drops the handle.
(module
  (import "fs" "write" (func $write (param i32 i32 i32 i64 i32)))
  (import "fs" "drop" (func $drop (param i32)))
  (memory (export "memory") 1)
  (data (i32.const 16) "HELLO-FS")
  (func (export "run") (param $h i32)
    (call $write (local.get $h) (i32.const 16) (i32.const 8) (i64.const 0) (i32.const 128))
    (call $drop (local.get $h))))
