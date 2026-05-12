;; Wasm spec §4.4.10 (table.get) — idx >= table.len traps
;; `OutOfBoundsTableAccess`. Table of 3 entries; access idx=5.
(module
  (table 3 funcref)
  (func (export "test") (result i32)
    i32.const 5
    table.get 0
    ref.is_null))
