;; Wasm threads — i32.atomic.load on a misaligned address traps
;; "unaligned atomic" (Trap.UnalignedAtomic). addr=2 is in-bounds but
;; not 4-aligned; the runtime alignment check fires BEFORE the bounds
;; check (spec exec step 8 < 14a). Validates the JIT align-trap stub.
(module
  (memory 1)
  (func (export "test") (result i32)
    (i32.atomic.load (i32.const 2))))
