;; Wasm spec §4.4.1.1 i64.div_s INT_MIN_64/-1: traps with
;; "integer overflow". Same shape as the i32 case but the
;; INT_MIN constant cannot be expressed as a CMP r64, imm32 —
;; the x86_64 handler materialises it via MOVABS RAX,imm64.
;; Result wrapped via i32.wrap_i64 because the edge runner is
;; runI32Export-only; the trap fires before the wrap.
(module
  (func (export "test") (result i32)
    i64.const 0x8000000000000000   ;; INT_MIN_64
    i64.const -1
    i64.div_s
    i32.wrap_i64))
