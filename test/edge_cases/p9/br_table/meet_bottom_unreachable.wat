;; Wasm spec §3.3.5.8 (br_table) + §3.3.5 (polymorphic stack) —
;; in unreachable code, br_table targets with non-unifiable result
;; types are accepted (joined type collapses to bottom).
;; §9.9 / 9.9-l-1b-d093-d52 (D-130): the validator's labelTypesEq
;; check now skips when topFrame.unreachable_flag is set; the emit
;; pads pushed_vregs with placeholder vregs at .end so the outer
;; reachable code's pop balances. Fixture mirrors
;; `unreached-valid.wast` `meet-bottom`: outer block-f64 wraps
;; inner block-f32 whose body is `unreachable; i32.const 1;
;; br_table 0 1 1`. The outer fall-through returns 0 (after `drop`
;; consumes the inner block's placeholder f32 result and the
;; outer's f64.const 0).
(module
  (func (export "test") (result i32)
    (block (result f64)
      (block (result f32)
        unreachable
        i32.const 1
        br_table 0 1 1)
      drop
      f64.const 0)
    drop
    i32.const 7))
