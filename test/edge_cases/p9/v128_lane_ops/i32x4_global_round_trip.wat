;; ADR-0110 Phase A.2.2 boundary fixture — v128 i32x4 round-trip
;; through global cope path. Stress axis: numeric range × lane
;; (boundary lanes 0 and 3). Tests sign-bit preservation in the
;; per-lane i32 (lane 3 carries 0x80000000 = INT_MIN).
;;
;; Returns 1 if lane 0 == 0xCAFEBABE and lane 3 == 0x80000000.
(module
  (global $g (mut v128) (v128.const i64x2 0 0))
  (func (export "test") (result i32)
    (global.set $g
      (v128.const i32x4 0xCAFEBABE 0x12345678 0xDEADBEEF 0x80000000))
    (i32.and
      (i32.eq
        (i32x4.extract_lane 0 (global.get $g))
        (i32.const 0xCAFEBABE))
      (i32.eq
        (i32x4.extract_lane 3 (global.get $g))
        (i32.const 0x80000000)))))
