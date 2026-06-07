;; Core module for the WASI-P2 get-directories unit test. Exports a bump
;; cabi_realloc (the host calls it to allocate the list/string return area via a
;; nested invoke) + run, which calls the imported get-directories(retptr=16),
;; reads back the single tuple, and returns (list_len*1000 + str_len).
(module
  (import "fs" "get-directories" (func $getdirs (param i32)))
  (memory (export "memory") 1)
  (global $bump (mut i32) (i32.const 256))
  (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
    (local $p i32)
    (local.set $p (global.get $bump))
    (global.set $bump (i32.add (global.get $bump) (local.get 3)))
    (local.get $p))
  (func (export "run") (result i32)
    (local $list i32)
    (call $getdirs (i32.const 16))           ;; retptr=16 → [list_ptr@16, list_len@20]
    (local.set $list (i32.load (i32.const 16)))
    (i32.add
      (i32.mul (i32.load (i32.const 20)) (i32.const 1000)) ;; list_len*1000
      (i32.load (i32.add (local.get $list) (i32.const 8)))))) ;; + tuple.str_len
