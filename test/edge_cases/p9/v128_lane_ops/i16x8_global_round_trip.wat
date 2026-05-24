;; ADR-0110 Phase A.2.2 boundary fixture — v128 i16x8 round-trip
;; through global cope path. Stress axis: numeric range × lane
;; (extract_lane_u). Sets v128 global with 8 distinct i16 lanes,
;; reads back, extracts lane 0 (= 0x1111) and lane 7 (= 0x8888).
;; Returns 1 if both lanes match, 0 otherwise.
(module
  (global $g (mut v128) (v128.const i64x2 0 0))
  (func (export "test") (result i32)
    (global.set $g
      (v128.const i16x8 0x1111 0x2222 0x3333 0x4444
                        0x5555 0x6666 0x7777 0x8888))
    (i32.and
      (i32.eq
        (i16x8.extract_lane_u 0 (global.get $g))
        (i32.const 0x1111))
      (i32.eq
        (i16x8.extract_lane_u 7 (global.get $g))
        (i32.const 0x8888)))))
