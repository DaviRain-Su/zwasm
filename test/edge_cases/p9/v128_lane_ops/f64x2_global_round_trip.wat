;; ADR-0110 Phase A.2.2 boundary fixture — v128 f64x2 round-trip
;; through global cope path. Lane 0 tests -0.0 (= 0x8000000000000000);
;; lane 1 tests f64 +Inf (= 0x7FF0000000000000). Bit patterns are
;; loaded via i64x2 reinterpret to bypass canonicalization. Returns
;; 1 if both lanes' bit patterns survive the round-trip.
(module
  (global $g (mut v128) (v128.const i64x2 0 0))
  (func (export "test") (result i32)
    (global.set $g
      (v128.const i64x2 0x8000000000000000 0x7FF0000000000000))
    (i32.and
      (i64.eq
        (i64.reinterpret_f64 (f64x2.extract_lane 0 (global.get $g)))
        (i64.const 0x8000000000000000))
      (i64.eq
        (i64.reinterpret_f64 (f64x2.extract_lane 1 (global.get $g)))
        (i64.const 0x7FF0000000000000)))))
