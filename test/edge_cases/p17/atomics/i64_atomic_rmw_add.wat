;; i64 rmw.add (res64 emit path) — wrap result to i32 for the runner.
(module (memory 1)
  (func (export "test") (result i32)
    (i64.atomic.store (i32.const 16) (i64.const 0x55))
    (i32.wrap_i64 (i64.atomic.rmw.add (i32.const 16) (i64.const 0x23)))))
