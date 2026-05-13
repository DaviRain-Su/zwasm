;; D-093 (d-13) regression: implicit-else cond=1 (then-arm)
;; complement to implicit_else_param. Cond=1 → then-arm consumes
;; param via drop, pushes new i32 = 7. Result = 7.
(module
  (func (export "test") (result i32)
    (i32.const 1253)
    (if (param i32) (result i32) (i32.const 1)
      (then (drop) (i32.const 7)))))
