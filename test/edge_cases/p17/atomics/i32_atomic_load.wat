;; Wasm threads — i32.atomic.load (0xFE 0x10, natural align=2).
;; Atomics do NOT require shared memory (wasm-tools check_shared_memarg);
;; a plain (memory 1) suffices. Store a word at an aligned address, then
;; read it back atomically — proves the JIT load path end-to-end. The
;; runtime alignment trap (misaligned address) is a separate fixture.
(module
  (memory 1)
  (func (export "test") (result i32)
    (i32.store (i32.const 8) (i32.const 0x12345678))
    (i32.atomic.load (i32.const 8))))
