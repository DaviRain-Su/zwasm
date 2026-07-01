;; ADR-0068 contract fixture — table.init + call_indirect.
;;
;; Element segment 0 is passive (not auto-applied). The
;; `table.init 0 0` op copies elem entries [0..2) into
;; table slot 0..1, overwriting whatever was there from
;; the active segment 1. Pre-ADR-0068 the `refs` view
;; receives the FuncEntity-encoded values; the `funcptrs`
;; view (read by call_indirect's fast path) keeps stale
;; values from the active segment.
;;
;; Spec expectation: $b runs (returns 5).
;; Pre-ADR-0068: $a runs (returns 1).
(module
  (type $sig (func (result i32)))
  (func $a (type $sig) (i32.const 1))
  (func $b (type $sig) (i32.const 5))
  (table 2 funcref)
  ;; passive segment: [$b]
  (elem func $b)
  ;; active segment: [$a, $a]
  (elem (i32.const 0) $a $a)
  (func (export "test") (result i32)
    (table.init 0 0
      (i32.const 0)       ;; dst
      (i32.const 0)       ;; src in elem 0
      (i32.const 1))      ;; n
    (call_indirect (type $sig) (i32.const 0))))
