(module (memory 1)
  (func (export "test") (result i32)
    (i64.atomic.store (i32.const 16) (i64.const 0xABCD))
    (i32.wrap_i64 (i64.atomic.rmw.cmpxchg (i32.const 16) (i64.const 0xABCD) (i64.const 0x11)))))
