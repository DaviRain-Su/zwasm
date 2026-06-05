;; D-285: overlapping memory.copy, dst>src (backward copy required), n=16 (2 words).
;; Word-wise lowering must copy high→low to avoid clobbering the source. data 1..16 @0.
(module
  (memory 1)
  (data (i32.const 0) "\01\02\03\04\05\06\07\08\09\0a\0b\0c\0d\0e\0f\10")
  (func (export "test") (result i32)
    i32.const 1 i32.const 0 i32.const 16 memory.copy
    i32.const 13 i32.load))
