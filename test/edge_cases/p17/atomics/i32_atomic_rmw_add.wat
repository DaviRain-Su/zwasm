;; i32.atomic.rmw.add (0xFE 0x1e) — store seed, rmw.add returns OLD value.
(module (memory 1)
  (func (export "test") (result i32)
    (i32.atomic.store (i32.const 12) (i32.const 0x100))
    (i32.atomic.rmw.add (i32.const 12) (i32.const 0x23))))
