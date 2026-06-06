(module (memory 1 100 (pagesize 1))
  (func (export "test") (result i32)
    (drop (memory.grow (i32.const 10)))
    (memory.size)))
