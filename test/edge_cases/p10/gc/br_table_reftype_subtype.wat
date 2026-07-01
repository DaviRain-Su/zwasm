;; Wasm 3.0 §3.3.8.8 br_table: branch operands must be a SUBTYPE of EACH
;; target label's type — NOT pairwise-equal across labels. Here the two
;; targets differ ($b1 = (ref func) non-null, $b0 = funcref = (ref null func));
;; the branched value (ref func) is a subtype of BOTH, so the br_table is
;; spec-valid. The old validator used pairwise labelTypesEq (exact equality)
;; and wrongly rejected this (D-452, same exact-eql-vs-subtyping class as the
;; return_call / table.copy fixes). wasm-tools validates it.
;;
;; Stress axes (test_discipline.md §1): control-flow (br_table multi-target) ×
;; reftype subtyping (nullable vs non-null across labels). ref.is_null of the
;; non-null funcref → 0.
;;
;; Provenance: minimal reduction (front ③ validator-hardening); wasm-tools parse.
(module
  (elem declare func $f)
  (func $f)
  (func (export "test") (result i32)
    (block $b0 (result funcref)
      (block $b1 (result (ref func))
        ref.func $f
        i32.const 0
        br_table $b1 $b0)
    )
    ref.is_null))
