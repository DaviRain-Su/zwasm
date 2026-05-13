;; D-093 (d-13) regression: multi-result call feeding implicit-else
;; if (carry=0). callee returns (i64 sum, i32 carry); cond=carry=0
;; takes implicit-else; result = param = sum.
;;
;; Expected: 1253 (i32 wrap of i64 1253).
(module
  (func $with_carry (param i64 i64) (result i64 i32)
    (i64.add (local.get 0) (local.get 1))
    (i32.const 0))
  (func (export "test") (result i32)
    (i32.wrap_i64
      (call $with_carry (i64.const 1230) (i64.const 23))
      (if (param i64) (result i64)
        (then (drop) (i64.const -1))))))
