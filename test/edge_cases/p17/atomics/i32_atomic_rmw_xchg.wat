(module (memory 1)
  (func (export "test") (result i32)
    (i32.atomic.store (i32.const 12) (i32.const 0x100))
    (i32.atomic.rmw.xchg (i32.const 12) (i32.const 0x23))))
