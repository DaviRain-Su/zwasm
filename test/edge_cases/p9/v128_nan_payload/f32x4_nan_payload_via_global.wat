;; ADR-0110 Phase A.2.2 boundary fixture — v128 f32x4 NaN payload
;; preservation through global cope path.
;;
;; Stress axis: numeric range (FP NaN per Wasm §6.2.3) × lane.
;; Lane 0 carries a non-canonical f32 NaN with payload bits
;; 0x7FC0DEAD; lane 2 carries 0x7FFFCAFE. Both have exp=all-ones
;; (NaN) but non-canonical mantissas. The cope path's per-valtype
;; byte-copy must NOT canonicalize the payload — Wasm spec requires
;; payload preservation through storage round-trips for scalar FP;
;; v128 lanes inherit the same contract.
;;
;; Returns 1 if both NaN payloads survive bit-exact.
(module
  (global $g (mut v128) (v128.const i64x2 0 0))
  (func (export "test") (result i32)
    (global.set $g
      (v128.const i32x4 0x7FC0DEAD 0x40490FDB 0x7FFFCAFE 0x40000000))
    (i32.and
      (i32.eq
        (i32.reinterpret_f32 (f32x4.extract_lane 0 (global.get $g)))
        (i32.const 0x7FC0DEAD))
      (i32.eq
        (i32.reinterpret_f32 (f32x4.extract_lane 2 (global.get $g)))
        (i32.const 0x7FFFCAFE)))))
