(module (memory 1)
  (func (export "test") (result i32)
    (i32.atomic.store8 (i32.const 12) (i32.const 0xFF))
    (i32.atomic.rmw8.and_u (i32.const 12) (i32.const 0x0F))))
