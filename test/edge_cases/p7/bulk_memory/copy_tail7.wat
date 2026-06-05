;; D-285: memory.copy n=7 = all tail, no word. data 1..7 @0.
(module
  (memory 1)
  (data (i32.const 0) "\01\02\03\04\05\06\07")
  (func (export "test") (result i32)
    i32.const 64 i32.const 0 i32.const 7 memory.copy
    i32.const 64 i32.load))
