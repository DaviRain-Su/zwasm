;; ADR-0068 contract fixture — table.copy across two tables.
;;
;; `table.copy dst=$t1 src=$t0 ...` copies funcref entries from
;; $t0 to $t1. The dual-view bug applies to both source and
;; destination tables independently — the destination's
;; `funcptrs` view needs the mirror write derived from the
;; source's `refs` (via FuncEntity.funcptr). chunk α's helper
;; is empty so call_indirect into $t1 returns stale data.
;;
;; Spec expectation: $b runs (returns 23).
;; Pre-ADR-0068: $t1's pre-copy state was null → trap on
;;               UninitializedElement (different failure shape
;;               but same root cause).
(module
  (type $sig (func (result i32)))
  (func $a (type $sig) (i32.const 41))
  (func $b (type $sig) (i32.const 23))
  (table $t0 2 funcref)
  (table $t1 2 funcref)
  (elem (table $t0) (i32.const 0) $a $b)
  (func (export "test") (result i32)
    (table.copy $t1 $t0
      (i32.const 0)       ;; dst (in $t1)
      (i32.const 1)       ;; src (in $t0) — $b
      (i32.const 1))      ;; n
    (call_indirect $t1 (type $sig) (i32.const 0))))
