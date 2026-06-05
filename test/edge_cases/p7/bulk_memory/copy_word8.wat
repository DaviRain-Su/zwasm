;; D-285: memory.copy n=8 = exactly one word, no tail. data 1..8 @0.
(module
  (memory 1)
  (data (i32.const 0) "\01\02\03\04\05\06\07\08")
  (func (export "test") (result i32)
    i32.const 64 i32.const 0 i32.const 8 memory.copy
    i32.const 68 i32.load))
