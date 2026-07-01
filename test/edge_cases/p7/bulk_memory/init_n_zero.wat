;; Wasm spec §4.4.7 (memory.init) — n=0 with in-bounds dst/src
;; must NOT trap and must not change memory. Returns 42.
(module
  (memory 1)
  (data "\01\02\03\04")
  (func (export "test") (result i32)
    i32.const 4           ;; dst
    i32.const 0           ;; src
    i32.const 0           ;; n
    memory.init 0
    i32.const 42))
