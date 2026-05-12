;; Wasm spec §4.4.10 / §4.4.11 — set then get the same slot.
;; A 4-entry funcref table; `table.set 0 idx=1 (ref.null func)`
;; followed by `table.get 0 idx=1; ref.is_null` returns i32:1.
;; Exercises the JIT's table.set value-store path explicitly
;; (instead of relying only on the static element-segment init).
(module
  (table 4 funcref)
  (func (export "test") (result i32)
    i32.const 1
    ref.null func
    table.set 0
    i32.const 1
    table.get 0
    ref.is_null))
