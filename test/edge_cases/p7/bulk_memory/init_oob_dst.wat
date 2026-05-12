;; Wasm spec §4.4.7 (memory.init) — dst+n > mem_size traps.
;; Memory = 1 page = 65536 bytes. dst=65530 n=10 → dst+n=65540 OOB.
(module
  (memory 1)
  (data "\01\02\03\04\05\06\07\08\09\0a")
  (func (export "test") (result i32)
    i32.const 65530       ;; dst — overshoots
    i32.const 0           ;; src
    i32.const 10          ;; n
    memory.init 0
    i32.const 0))
