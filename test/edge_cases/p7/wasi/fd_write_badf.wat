;; Chunk 7.9-d-2: WASI host-import dispatch end-to-end smoke.
;; Calls `wasi_snapshot_preview1.fd_write` with fd=99 (invalid)
;; — the host stub returns EBADF=8 without touching memory.
;; A passing run proves: (1) the JIT body's import-call site
;; emits an indirect call through host_dispatch_base; (2) the
;; runner populated the dispatch table with the right WASI
;; handler ptr; (3) calling-convention plumbing
;; (rt-as-arg0 + Wasm args 1..N) is correct on the host arch.
(module
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (func (export "test") (result i32)
    i32.const 99      ;; bad fd
    i32.const 0       ;; iovs_ptr (ignored at EBADF path)
    i32.const 0       ;; iovs_len
    i32.const 0       ;; nwritten_ptr
    call $fd_write))  ;; returns i32:8 (EBADF)
