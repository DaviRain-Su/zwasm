;; D-093 (d-13) regression: `(if (param T) (result T))` with NO else.
;; Per Wasm spec §3.4.4 + validator: param_type must equal result_type
;; for implicit-else to validate. cond=0 path takes the implicit
;; identity else — result is the original param.
;;
;; Mirrors `if.wast:add64_u_saturated`'s if-frame minus the
;; multi-result func call (which lands at d-11). Cond fed by
;; (i32.const 0) → expect else-fall-through → return param = 1253.
;;
;; Expected: 1253.
(module
  (func (export "test") (result i32)
    (i32.const 1253)
    (if (param i32) (result i32) (i32.const 0)
      (then (drop) (i32.const 7)))))
