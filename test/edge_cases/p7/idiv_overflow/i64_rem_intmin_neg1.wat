;; Wasm spec §4.4.1.1 i64.rem_s INT_MIN_64/-1: returns 0 (does
;; NOT trap). Same semantic as the i32 case scaled to 64-bit.
;; Result wrapped via i32.wrap_i64 for the runI32Export-only
;; edge runner; 0 wraps to 0 so the assertion is preserved.
(module
  (func (export "test") (result i32)
    i64.const 0x8000000000000000   ;; INT_MIN_64
    i64.const -1
    i64.rem_s
    i32.wrap_i64))
