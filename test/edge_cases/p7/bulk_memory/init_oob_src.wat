;; Wasm spec §4.4.7 (memory.init) — src+n > seg.len traps.
;; Segment has 4 bytes; src=2 n=4 → src+n=6 > 4.
(module
  (memory 1)
  (data "\01\02\03\04")
  (func (export "test") (result i32)
    i32.const 0           ;; dst
    i32.const 2           ;; src
    i32.const 4           ;; n
    memory.init 0
    i32.const 0))
