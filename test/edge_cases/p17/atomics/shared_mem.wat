;; Wasm threads — shared memory (limits flag 0x03 = has_max+shared).
;; On the single-threaded substrate it behaves like a normal memory;
;; this proves the shared-mem parse gate + atomics on shared memory.
(module (memory 1 1 shared)
  (func (export "test") (result i32)
    (i32.atomic.store (i32.const 0) (i32.const 42))
    (i32.atomic.load (i32.const 0))))
