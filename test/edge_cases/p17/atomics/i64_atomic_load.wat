;; Wasm threads — i64.atomic.load (0xFE 0x11, natural align=3). Edge
;; runner is i32-only, so store an i64 and return its low 32 bits via
;; i32.wrap_i64 to prove the 8-byte atomic load reaches the JIT.
(module
  (memory 1)
  (func (export "test") (result i32)
    (i64.store (i32.const 8) (i64.const 0x123456789ABCDEF0))
    (i32.wrap_i64 (i64.atomic.load (i32.const 8)))))
