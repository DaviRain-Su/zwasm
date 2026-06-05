;; D-285: non-overlapping memory.copy, n=15 = one 8-byte word + 7-byte tail. data 1..15 @0.
(module
  (memory 1)
  (data (i32.const 0) "\01\02\03\04\05\06\07\08\09\0a\0b\0c\0d\0e\0f")
  (func (export "test") (result i32)
    i32.const 64 i32.const 0 i32.const 15 memory.copy
    i32.const 75 i32.load))
