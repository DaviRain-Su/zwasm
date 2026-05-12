;; Wasm spec §4.4.14 (table.fill) — n=0 is a no-op even at the
;; OOB boundary (dst == table.len, n=0). No trap.
(module
  (table 3 funcref)
  (func (export "test") (result i32)
    i32.const 3          ;; dst at boundary
    ref.null func
    i32.const 0          ;; n=0
    table.fill 0
    i32.const 42))
