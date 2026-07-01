;; D-093 (d-11) regression: multi-result function call. Callee
;; returns (i64, i32) — first i64 into X0, second i32 into W1
;; per AAPCS64 §6.5. Caller's `captureCallResult` pushes 2 vregs
;; matching that mapping; the if-with-params consumes them.
;;
;; Mirrors `if.wast:add64_u_saturated` minus the saturation
;; branching: provides explicit (i64 sum, i32 carry) → return sum
;; on carry=0.
;;
;; Expected: 1253 (= 1230 + 23, carry=0).
(module
  (func $add64_u_with_carry (param $i i64) (param $j i64) (param $c i32) (result i64 i32)
    (local $k i64)
    (local.set $k
      (i64.add
        (i64.add (local.get $i) (local.get $j))
        (i64.extend_i32_u (local.get $c))))
    (local.get $k)
    (i64.lt_u (local.get $k) (local.get $i)))
  (func (export "test") (result i32)
    (call $add64_u_with_carry (i64.const 1230) (i64.const 23) (i32.const 0))
    (if (param i64) (result i32)
      (then (drop) (i32.const 0))
      (else (drop) (i32.const 1253))
    )))
