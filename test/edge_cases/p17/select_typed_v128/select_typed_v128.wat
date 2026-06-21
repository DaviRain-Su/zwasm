;; D-491: typed `select (result v128)` (0x1c with v128 type byte 0x7B).
;; Wasm spec §3.3.2.2 allows `select t` for any valtype incl. v128;
;; zwasm previously rejected at the validator (BadValType) + lowerer
;; (BadBlockType). wasmtime/spec accept it. SIMD is JIT-only, so this
;; runs under the edge-runner's JIT (runI32Export). cond=1 → first value.
(module
  (func (export "test") (result i32)
    (i32x4.extract_lane 0
      (select (result v128)
        (v128.const i32x4 111 0 0 0)
        (v128.const i32x4 222 0 0 0)
        (i32.const 1)))))
