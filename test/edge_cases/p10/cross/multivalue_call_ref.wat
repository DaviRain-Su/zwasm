;; Wasm cross-proposal: multi-value (Wasm 2.0) × function-references (call_ref).
;; A `call_ref` invokes a funcref whose signature returns TWO results
;; (i32, i32); the caller sums them. Exercises the multi-result capture
;; path of the funcref-call JIT emit (captureCallResult with >1 result) —
;; the existing call_ref fixtures only return a single i32, so the
;; multi-result marshal-back through the call_ref path was untested.
;;
;; Stress axes (test_discipline.md §1): ABI boundary (multi-result return
;; marshal) + dispatch shape (call_ref → multi-value func). 30 + 12 → 42.
;;
;; Provenance: internally derived from 10.P cross-feature close-prep
;; (cyc218); assembled with wasm-tools parse.
(module
  (type $sig (func (result i32 i32)))
  (func $pair (type $sig) (result i32 i32)
    i32.const 30
    i32.const 12)
  (func (export "test") (result i32)
    ref.func $pair
    call_ref $sig
    i32.add)
  (elem declare func $pair))
