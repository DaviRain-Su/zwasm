;; i32.atomic.store (0xFE 0x17) — store then atomic-load back.
(module (memory 1)
  (func (export "test") (result i32)
    (i32.atomic.store (i32.const 12) (i32.const 0x600DCAFE))
    (i32.atomic.load (i32.const 12))))
