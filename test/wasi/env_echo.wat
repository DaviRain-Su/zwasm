;; D-295 P0: WASI env-reader. Reads environ (environ_sizes_get + environ_get)
;; and writes the first env string MINUS its trailing NUL to stdout. The runner
;; injects `GREETING=hi` via the `.env` sidecar (→ CLI --env → host.setEnvs), so
;; environ holds "GREETING=hi\0" and stdout = "GREETING=hi". End-to-end check of
;; the --env → setEnvs → environ_get path.
(module
  (import "wasi_snapshot_preview1" "environ_sizes_get"
    (func $environ_sizes_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "environ_get"
    (func $environ_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory 1)
  (func $main
    (drop (call $environ_sizes_get (i32.const 0) (i32.const 4)))   ;; count@0, bufsize@4
    (drop (call $environ_get (i32.const 64) (i32.const 128)))       ;; ptrs@64, "GREETING=hi\00"@128
    (i32.store (i32.const 200) (i32.const 128))                     ;; ciovec.buf = 128
    (i32.store (i32.const 204) (i32.sub (i32.load (i32.const 4)) (i32.const 1))) ;; len = bufsize-1
    (drop (call $fd_write (i32.const 1) (i32.const 200) (i32.const 1) (i32.const 16))))
  (export "_start" (func $main)))
