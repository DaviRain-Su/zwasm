;; ADR-0068 contract fixture — table.fill + call_indirect.
;;
;; `table.fill 0 dst=0 val=ref.func($b) n=2` writes $b into
;; slots 0 and 1 of the `refs` view. The funcptrs view stays
;; at $a (from the active segment). call_indirect reads
;; funcptrs → $a, contradicting the post-fill state.
;;
;; Spec expectation: $b runs (returns 13).
;; Pre-ADR-0068: $a runs (returns 17).
(module
  (type $sig (func (result i32)))
  (func $a (type $sig) (i32.const 17))
  (func $b (type $sig) (i32.const 13))
  (table 2 funcref)
  (elem (i32.const 0) $a $a)
  ;; Declarative elem registers $b for `ref.func` use.
  (elem declare func $b)
  (func (export "test") (result i32)
    (table.fill 0
      (i32.const 0)         ;; dst
      (ref.func $b)         ;; val
      (i32.const 2))        ;; n
    (call_indirect (type $sig) (i32.const 1))))
