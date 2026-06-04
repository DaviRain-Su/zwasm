;; §15.4 / D-246 chunk C boundary fixture — i32x4.dot_i16x8_s
;; (arm64 SMULL.4S + SMULL2.4S + ADDP.4S). Stress axis: pairwise
;; signed widening multiply-add × lane.
;; A = i16x8 [1,2,3,4,5,6,7,8], B = i16x8 [1,1,1,1,1,1,1,1].
;; dot[i] = A[2i]*B[2i] + A[2i+1]*B[2i+1]
;;        = [1+2, 3+4, 5+6, 7+8] = [3, 7, 11, 15].
;; Returns 1 iff extract_lane 0 == 3 AND extract_lane 3 == 15.
(module
  (func (export "test") (result i32)
    (local $r v128)
    (local.set $r
      (i32x4.dot_i16x8_s
        (v128.const i16x8 1 2 3 4 5 6 7 8)
        (v128.const i16x8 1 1 1 1 1 1 1 1)))
    (i32.and
      (i32.eq (i32x4.extract_lane 0 (local.get $r)) (i32.const 3))
      (i32.eq (i32x4.extract_lane 3 (local.get $r)) (i32.const 15)))))
