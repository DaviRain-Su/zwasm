;; i32.atomic.load at an unaligned effective address (1, needs 4-byte align)
;; → trap "unaligned atomic" (spec exec step 8, before bounds). D-303: the JIT
;; inline atomic load path previously omitted this check the interp had.
(module (memory 1)
  (func (export "test") (result i32)
    (i32.atomic.load (i32.const 1))))
