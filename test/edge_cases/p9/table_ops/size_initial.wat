;; Wasm spec §4.4.12 (table.size) — declared table of 5 funcref
;; entries returns 5 via table.size 0 (no operands; pushes i32).
(module
  (table 5 funcref)
  (func (export "test") (result i32)
    table.size 0))
