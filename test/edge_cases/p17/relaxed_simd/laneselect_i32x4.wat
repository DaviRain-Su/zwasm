;; i32x4.relaxed_laneselect (0xFD 0x10B) — mask lane0 all-ones → a[0]=100.
(module (func (export "test") (result i32)
  (i32x4.extract_lane 0
    (i32x4.relaxed_laneselect
      (v128.const i32x4 100 101 102 103)
      (v128.const i32x4 200 201 202 203)
      (v128.const i32x4 0xFFFFFFFF 0 0 0)))))
