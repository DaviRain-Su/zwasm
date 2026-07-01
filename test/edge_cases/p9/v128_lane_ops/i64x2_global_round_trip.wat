;; ADR-0110 Phase A.2.2 boundary fixture — v128 i64x2 round-trip
;; through global cope path. Stress axis: numeric range × lane
;; (each lane is full 64-bit; tests both halves of the 128-bit
;; storage). Lane 1 carries i64 INT_MIN (= 0x8000000000000000)
;; to stress sign-bit preservation through the cope path's
;; byte-copy width logic.
;;
;; Returns 1 if both lanes match.
(module
  (global $g (mut v128) (v128.const i64x2 0 0))
  (func (export "test") (result i32)
    (global.set $g
      (v128.const i64x2 0x0123456789ABCDEF 0x8000000000000000))
    (i32.and
      (i64.eq
        (i64x2.extract_lane 0 (global.get $g))
        (i64.const 0x0123456789ABCDEF))
      (i64.eq
        (i64x2.extract_lane 1 (global.get $g))
        (i64.const 0x8000000000000000)))))
