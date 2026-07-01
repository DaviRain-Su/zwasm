;; i32x4.relaxed_dot_i8x16_i7x16_add_s (0xFD 0x113) — 4-way i8 dot + c.
;; a=[1..16], b=1s, c=[100,200,300,400]. lane0 = (1+2+3+4)+100 = 110.
(module
  (func (export "test") (result i32)
    (i32x4.extract_lane 0
      (i32x4.relaxed_dot_i8x16_i7x16_add_s
        (v128.const i8x16 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)
        (v128.const i8x16 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
        (v128.const i32x4 100 200 300 400))))
  (func (export "test_lane1") (result i32)
    (i32x4.extract_lane 1
      (i32x4.relaxed_dot_i8x16_i7x16_add_s
        (v128.const i8x16 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)
        (v128.const i8x16 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
        (v128.const i32x4 100 200 300 400)))))
