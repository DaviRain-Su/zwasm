;; Wasm spec §4.4.10 (table.get) — happy path against a fresh
;; funcref table. Slot 2 of a 5-entry table starts as `ref.null
;; funcref` (Wasm spec §4.5.7 table init default); `table.get`
;; pushes that null ref and `ref.is_null` collapses to i32:1.
(module
  (table 5 funcref)
  (func (export "test") (result i32)
    i32.const 2
    table.get 0
    ref.is_null))
