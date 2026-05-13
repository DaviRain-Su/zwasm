;; D-093 (d-14) probe: match `if.wast:add64_u_saturated` exactly
;; including the inner add64_u_with_carry's full shape.
;; Expected: 1253 (wrapped i64 1253).
(module
  (func $add64_u_with_carry (param $i i64) (param $j i64) (param $c i32) (result i64 i32)
    (local $k i64)
    (local.set $k
      (i64.add
        (i64.add (local.get $i) (local.get $j))
        (i64.extend_i32_u (local.get $c))))
    (return (local.get $k) (i64.lt_u (local.get $k) (local.get $i))))
  (func $add64_u_saturated (param $i i64) (param $j i64) (result i64)
    (call $add64_u_with_carry (local.get $i) (local.get $j) (i32.const 0))
    (if (param i64) (result i64)
      (then (drop) (i64.const -1))))
  (func (export "test") (result i32)
    (i32.wrap_i64
      (call $add64_u_saturated (i64.const 1230) (i64.const 23)))))
