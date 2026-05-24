;; ADR-0110 Phase A.2.2 boundary fixture — v128 f64x2 NaN payload
;; preservation through global cope path.
;;
;; Stress axis: numeric range (FP NaN per Wasm §6.2.3) × lane.
;; Both lanes carry non-canonical f64 NaNs (exp=all-ones, mantissa
;; with payload bits). Lane 0 = 0x7FF8DEADBEEFF00D; lane 1 =
;; 0x7FFFCAFEBABE1234. Bit pattern must survive the cope-path
;; round-trip.
;;
;; Returns 1 if both NaN payloads survive bit-exact.
(module
  (global $g (mut v128) (v128.const i64x2 0 0))
  (func (export "test") (result i32)
    (global.set $g
      (v128.const i64x2 0x7FF8DEADBEEFF00D 0x7FFFCAFEBABE1234))
    (i32.and
      (i64.eq
        (i64.reinterpret_f64 (f64x2.extract_lane 0 (global.get $g)))
        (i64.const 0x7FF8DEADBEEFF00D))
      (i64.eq
        (i64.reinterpret_f64 (f64x2.extract_lane 1 (global.get $g)))
        (i64.const 0x7FFFCAFEBABE1234)))))
