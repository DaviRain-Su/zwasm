(module (memory 1)
  (func (export "test") (result i32)
    (i32.atomic.store8 (i32.const 12) (i32.const 0xAB))
    (i32.atomic.rmw8.cmpxchg_u (i32.const 12) (i32.const 0xAB) (i32.const 0x05))))
