;; Wasm spec §4.4.1.1 i32.div_s INT_MIN/-1: traps with
;; "integer overflow" (the quotient 2^31 is unrepresentable).
;; Without the per-handler check this slips through silently
;; on ARM64 (SDIV produces INT_MIN) and crashes the JIT process
;; on x86_64 (IDIV raises #DE). Pairs with D-047 discharge.
(module
  (func (export "test") (result i32)
    i32.const 0x80000000   ;; INT_MIN_32
    i32.const -1
    i32.div_s))
