;; i64.atomic.store at an unaligned effective address (4, needs 8-byte align)
;; → trap "unaligned atomic". Covers the store path + an 8-byte width whose
;; mask (7) differs from the load fixture's (3). D-303. The trailing const is
;; never reached (the store traps first); it only shapes the i32 result type.
(module (memory 1)
  (func (export "test") (result i32)
    (i64.atomic.store (i32.const 4) (i64.const 0))
    (i32.const 0)))
