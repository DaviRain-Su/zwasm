;; §9.9 / 9.9-l-1b-d093-d64 (D-132): regression test for the
;; arm64 X10/X11/X12 clobber bug. Before d-64's fix,
;; `op_table.zig::emitTableGet` / `emitTableSet` used X10/X11/X12
;; as hardcoded scratch even though those slots were in
;; `allocatable_caller_saved_scratch_gprs`. When two table.set
;; ops appeared in the same function and the second nested a
;; table.get, the regalloc-assigned vreg in X10 (typically the
;; outer table.set's idx) was clobbered by the inner table.get's
;; `LDR X10, [X19, #tables_ptr_off]`. d-64 removes X10/X11/X12
;; from the allocatable pool; the fixture below covers the
;; canonical trigger pattern (mirror of table_get.wast's `init`
;; body whose `is_null-funcref(2) → 0` assertion surfaced the
;; bug at d-63).
(module
  (table $t 3 funcref)
  (elem (table $t) (i32.const 1) func $dummy)
  (func $dummy)

  (func $setup
    (table.set $t (i32.const 0) (ref.null func))
    (table.set $t (i32.const 2) (table.get $t (i32.const 1))))

  (func (export "test") (result i32)
    (call $setup)
    (ref.is_null (table.get $t (i32.const 2))))
)
