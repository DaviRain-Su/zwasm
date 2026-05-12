;; Wasm spec §4.4.7 (memory.init) — happy path. Data segment with
;; 4 bytes; memory.init copies them to memory[64..68] (not aliased
;; with any active-segment region so the load directly proves the
;; init op did the copy). i32.load reads back as little-endian i32.
;; 0x04030201 = 67305985.
(module
  (memory 1)
  (data "\01\02\03\04")
  (func (export "test") (result i32)
    i32.const 64          ;; dst (well past any active-seg landing)
    i32.const 0           ;; src
    i32.const 4           ;; n
    memory.init 0
    i32.const 64
    i32.load))
