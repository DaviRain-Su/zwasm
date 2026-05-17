;; ADR-0068 contract fixture — table.set + call_indirect.
;;
;; `ref.func $b` produces a funcref Value (= `*FuncEntity`).
;; `table.set 0 idx=0 val=ref.func($b)` writes the funcref
;; into slot 0's `refs` view. The dual-view bug leaves
;; `funcptrs[0]` pointing at $a's code body. `call_indirect`
;; reads `funcptrs[0]` → $a runs instead of $b.
;;
;; Spec expectation: $b runs (returns 99).
;; Pre-ADR-0068: $a runs (returns 11).
(module
  (type $sig (func (result i32)))
  (func $a (type $sig) (i32.const 11))
  (func $b (type $sig) (i32.const 99))
  (table 1 funcref)
  (elem (i32.const 0) $a)
  ;; Declarative elem registers $b for `ref.func` use without
  ;; placing it in any table.
  (elem declare func $b)
  (func (export "test") (result i32)
    (table.set 0 (i32.const 0) (ref.func $b))
    (call_indirect (type $sig) (i32.const 0))))
