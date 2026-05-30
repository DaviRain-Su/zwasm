;; Wasm cross-proposal: SIMD/v128 × function-references (call_ref).
;; A `call_ref` invokes a funcref whose signature returns a `v128`; the
;; caller extracts lane 0 → i32. Exercises the v128-result capture path of
;; the funcref-call JIT emit (a 16-byte XMM/Q-reg result marshal, more
;; complex than the i32 path the other call_ref fixtures use, and untested
;; through call_ref). $vec returns i32x4(42,0,0,0); extract_lane 0 → 42.
;;
;; Stress axes (test_discipline.md §1): ABI boundary (v128 result marshal
;; back through the call_ref capture) + dispatch shape (call_ref → SIMD func).
;; → 42.
;;
;; Provenance: internally derived from 10.P cross-feature close-prep (cyc220);
;; assembled with wasm-tools parse. Last of the cleanly-JIT-able cross combos.
(module
  (type $sig (func (result v128)))
  (func $vec (type $sig) (result v128)
    v128.const i32x4 42 0 0 0)
  (func (export "test") (result i32)
    ref.func $vec
    call_ref $sig
    i32x4.extract_lane 0)
  (elem declare func $vec))
