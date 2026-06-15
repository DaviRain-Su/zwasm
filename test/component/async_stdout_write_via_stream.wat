;; WASI-0.3 / CM-async fixture (D-335 unit E1, ADR-0190): the host stream peer.
;; A guest mints a stream<u8>, hands the readable end to wasi:cli/stdout
;; write-via-stream (the host becomes the always-ready reader → sink fd 1),
;; writes "hi\n" to the writable end (→ COMPLETION, host captures the bytes),
;; drops the writable end, EXITs. First guest stream.write COMPLETION +
;; element marshalling e2e. wit: cli/wit/stdio.wit:48.
(component
  (import "wasi:cli/stdout@0.3.0" (instance $stdout
    (type $ec (enum "io" "illegal-byte-sequence" "pipe"))
    (export "error-code" (type (eq $ec)))
    (export "write-via-stream"
      (func (param "data" (stream u8)) (result (future (result (error $ec))))))))
  (type $st (stream u8))
  (core module $libc (memory (export "mem") 1))
  (core instance $libc (instantiate $libc))
  (core func $wvs (canon lower (func $stdout "write-via-stream")))
  (core func $sn (canon stream.new $st))
  (core func $wr (canon stream.write $st (memory $libc "mem")))
  (core func $dw (canon stream.drop-writable $st))
  (core module $m
    (import "async" "write-via-stream" (func $wvs (param i32) (result i32)))
    (import "async" "stream-new" (func $sn (result i64)))
    (import "async" "stream-write" (func $wr (param i32 i32 i32) (result i32)))
    (import "async" "drop-writable" (func $dw (param i32)))
    (import "libc" "mem" (memory 1))
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
    (func (export "run") (result i32)
      (local $h i64) (local $w i32)
      (i32.store8 (i32.const 0) (i32.const 0x68))  ;; 'h'
      (i32.store8 (i32.const 1) (i32.const 0x69))  ;; 'i'
      (i32.store8 (i32.const 2) (i32.const 0x0a))  ;; '\n'
      (local.set $h (call $sn))
      (local.set $w (i32.wrap_i64 (i64.shr_u (local.get $h) (i64.const 32)))) ;; wi (high 32)
      ;; hand the readable end (ri = low 32) to the host stdout sink
      (drop (call $wvs (i32.wrap_i64 (local.get $h))))
      ;; write "hi\n" to the writable end → host sink captures → COMPLETED(3)
      (call $wr (local.get $w) (i32.const 0) (i32.const 3))
      (i32.const 0x30) (i32.ne) (if (then unreachable)) ;; COMPLETED(3) = (3<<4)|0 = 0x30
      (call $dw (local.get $w)) ;; close the writable end
      i32.const 0)) ;; 0 = EXIT
  (core instance $deps
    (export "write-via-stream" (func $wvs))
    (export "stream-new" (func $sn))
    (export "stream-write" (func $wr))
    (export "drop-writable" (func $dw)))
  (core instance $i (instantiate $m (with "async" (instance $deps)) (with "libc" (instance $libc))))
  (func (export "run") async
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
