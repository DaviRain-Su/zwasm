;; Wasm spec §4.4.7 (memory.init) — after data.drop, the segment's
;; effective length is 0; any n>0 traps via src+n > 0.
(module
  (memory 1)
  (data "\01\02\03\04")
  (func (export "test") (result i32)
    data.drop 0
    i32.const 0           ;; dst
    i32.const 0           ;; src
    i32.const 1           ;; n=1 → trap (seg_len=0)
    memory.init 0
    i32.const 0))
