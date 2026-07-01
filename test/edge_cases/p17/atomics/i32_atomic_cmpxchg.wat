;; i32.atomic.rmw.cmpxchg (0xFE 0x48) — expected matches → swap, return old.
(module (memory 1)
  (func (export "test") (result i32)
    (i32.atomic.store (i32.const 12) (i32.const 0x100))
    (i32.atomic.rmw.cmpxchg (i32.const 12) (i32.const 0x100) (i32.const 0x999))))
