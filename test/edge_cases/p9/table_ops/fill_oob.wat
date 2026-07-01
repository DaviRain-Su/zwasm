;; Wasm spec §4.4.14 (table.fill) — dst+n > table.len traps.
;; 3-entry table; dst=2 n=2 → 2+2=4 > 3 → trap.
(module
  (table 3 funcref)
  (func (export "test") (result i32)
    i32.const 2
    ref.null func
    i32.const 2
    table.fill 0
    i32.const 0))
