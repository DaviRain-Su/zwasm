;; ADR-0110 Phase A.2.2 boundary fixture — v128 f32x4 round-trip
;; through global cope path. Lane bit patterns are loaded via
;; i32x4 reinterpret to bypass f32.const canonicalization. Lane 0
;; tests -0.0 (= 0x80000000); lane 3 tests f32 +Inf (= 0x7F800000).
;; Returns 1 if both lanes' bit patterns survive the round-trip.
(module
  (global $g (mut v128) (v128.const i64x2 0 0))
  (func (export "test") (result i32)
    (global.set $g
      (v128.const i32x4 0x80000000 0x3F800000 0x40000000 0x7F800000))
    (i32.and
      (i32.eq
        (i32.reinterpret_f32 (f32x4.extract_lane 0 (global.get $g)))
        (i32.const 0x80000000))
      (i32.eq
        (i32.reinterpret_f32 (f32x4.extract_lane 3 (global.get $g)))
        (i32.const 0x7F800000)))))
