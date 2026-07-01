;; ADR-0068 contract fixture (chunk α gate FAIL → β/γ PASS).
;;
;; D-126 surfaces when a table-mutating op writes to
;; `tables_ptr[k].refs` (FuncEntity-ptr encoding) without
;; updating the parallel `funcptrs` view that `call_indirect`'s
;; X26 fast path reads. This fixture exercises the bug:
;;
;;   1. Element segment populates slot 0 → $a (returns 42)
;;      and slot 1 → $b (returns 7) at instantiation. Both
;;      views (refs + funcptrs) are coherent here because
;;      `applyTableInit` populates both during setup.
;;   2. `table.copy 0 0 src=0 dst=1 n=1` overwrites slot 1
;;      with slot 0's funcref via the mutating op. With
;;      the dual-view bug, only `refs[1]` is rewritten;
;;      `funcptrs[1]` still points at $b's code body.
;;   3. `call_indirect t=0 (idx=1)` reads `funcptrs[1]`
;;      and dispatches there.
;;
;; Spec expectation: $a runs (returns 42).
;; Pre-ADR-0068 (and chunk α): $b runs (returns 7) — the
;; dual-view divergence surfaces as a wrong-callee bug.
;;
;; This fixture is a CONTRACT test on call_indirect post-
;; mutation correctness, NOT on dual-view internals — the
;; 9.12 substrate audit may unify / restructure storage and
;; the fixture stays green regardless.
(module
  (type $sig (func (result i32)))
  (func $a (type $sig) (i32.const 42))
  (func $b (type $sig) (i32.const 7))
  (table 2 funcref)
  (elem (i32.const 0) $a $b)
  (func (export "test") (result i32)
    (table.copy 0 0
      (i32.const 1)       ;; dst
      (i32.const 0)       ;; src
      (i32.const 1))      ;; n
    (call_indirect (type $sig) (i32.const 1))))
