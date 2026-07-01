;; i8x16.relaxed_laneselect (0xFD 0x109) — full bitwise: mask lane=0xFF→a, 0x00→b.
;; lane1 mask=0x00 → b[1]=31.
(module (func (export "test") (result i32)
  (i8x16.extract_lane_u 1
    (i8x16.relaxed_laneselect
      (v128.const i8x16 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25)
      (v128.const i8x16 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45)
      (v128.const i8x16 0xFF 0x00 0 0 0 0 0 0 0 0 0 0 0 0 0 0)))))
