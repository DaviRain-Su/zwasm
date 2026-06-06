(module (memory 4 100 (pagesize 1))
  (func (export "test") (result i32)
    (i32.store (i32.const 0) (i32.const 0x600DCAFE))
    (i32.load (i32.const 0))))
