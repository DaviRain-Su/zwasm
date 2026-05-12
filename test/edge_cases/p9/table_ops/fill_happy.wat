;; Wasm spec §4.4.14 (table.fill) — fill 3 cells in a 5-entry
;; funcref table with `ref.null func`, then verify slot 2 reads
;; back as null (i32:1). Exercises the inline-loop emit path.
(module
  (table 5 funcref)
  (func (export "test") (result i32)
    i32.const 1          ;; dst
    ref.null func        ;; val
    i32.const 3          ;; n
    table.fill 0
    i32.const 2          ;; idx into the filled region
    table.get 0
    ref.is_null))
