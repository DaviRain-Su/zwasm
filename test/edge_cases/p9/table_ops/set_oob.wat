;; Wasm spec §4.4.11 (table.set) — idx >= table.len traps.
(module
  (table 3 funcref)
  (func (export "test") (result i32)
    i32.const 7
    ref.null func
    table.set 0
    i32.const 0))
