;; Wasm spec §4.4.1.1 i32.rem_s INT_MIN/-1: returns 0 (does NOT
;; trap). The spec defines result = j1 - (j1 ÷_s j2) * j2, which
;; for INT_MIN/-1 wraps to INT_MIN - INT_MIN * (-1) = 0 in the
;; 32-bit domain. ARM64 SDIV+MSUB naturally produces 0; x86_64
;; needs a pre-IDIV special case so #DE doesn't crash the JIT.
(module
  (func (export "test") (result i32)
    i32.const 0x80000000   ;; INT_MIN_32
    i32.const -1
    i32.rem_s))
