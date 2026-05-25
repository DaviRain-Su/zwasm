;; ADR-0111 D4 — i64-indexed memory bounds-check trap.
;;
;; Mirror of p7/memory_bounds/past_limit_load_i32.wat but on an
;; i64-typed memory (Wasm 3.0 §3.4.7). Validator dispatches the
;; address operand type via `memory0_idx_type` (10.M-5); codegen
;; routes through emitMemOpI64 (10.M-4b). eff_addr (65533) +
;; access_size (4) == 65537 > mem_limit (65536) → trap.
;;
;; Stress axes:
;;   - Spec-defined trap condition (bounds-check on i64 addr).
;;   - Alignment / offset: page-edge OOB (mem.size + 1).
;;   - Validator strictness: i64-typed address must pass
;;     opLoad's `memAddrType()` dispatcher (rejects i32-typed
;;     address against i64 memory).
(module
  (memory i64 1)
  (func (export "test") (result i32)
    i64.const 65533
    i32.load))
