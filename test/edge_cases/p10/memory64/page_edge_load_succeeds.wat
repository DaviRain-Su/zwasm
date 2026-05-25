;; ADR-0111 D4 — i64-indexed memory page-edge load.
;;
;; Boundary: i32.load at exactly the last legal 4-byte slot
;; (mem.size - access_size = 65532). eff_addr (65532) +
;; access_size (4) == 65536 == mem_limit → succeeds (the bounds
;; check is `>`, not `>=`). Memory is zero-initialised so the
;; load returns 0.
;;
;; Stress axes:
;;   - Numeric range: exact-equals boundary (off-by-one detector
;;     for the bounds-check comparison).
;;   - Alignment / offset: page-edge (last legal address).
;;   - Dispatch shape: i32.load on i64-indexed memory (codegen
;;     emitMemOpI64 X-form addr load with non-trivial address).
(module
  (memory i64 1)
  (func (export "test") (result i32)
    i64.const 65532
    i32.load))
