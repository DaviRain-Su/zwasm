;; ADR-0110 Phase A.2.2 boundary fixture — v128 i8x16 round-trip
;; through global.set/get exercising the ADR-0052 cope path
;; (`scratch_globals` byte buffer + per-valtype `slot_size 16`
;; switch). Phase A.4g unifies this; the fixture forms the
;; behaviour-preservation contract.
;;
;; Stress axis: numeric range × v128 lane (extract_lane_u). Sets
;; a v128 global with 16 distinct byte values, reads back, extracts
;; lane 0 (= 1) and lane 15 (= 16), combines as (lane15 << 8 | lane0)
;; = 0x1001 = 4097. Returns 1 if intact, 0 otherwise.
(module
  (global $g (mut v128) (v128.const i64x2 0 0))
  (func (export "test") (result i32)
    (global.set $g
      (v128.const i8x16 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16))
    (i32.eq
      (i32.or
        (i32.shl
          (i8x16.extract_lane_u 15 (global.get $g))
          (i32.const 8))
        (i8x16.extract_lane_u 0 (global.get $g)))
      (i32.const 4097))))
