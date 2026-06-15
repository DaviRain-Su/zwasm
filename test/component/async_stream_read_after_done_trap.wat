;; WASI-0.3 / CM-async fixture (D-335 front②, wasmtime trap-if-done.wast): a copy
;; is only valid on an IDLE end. The guest mints a stream, drops the writable
;; end, reads once (→ DROPPED, which moves the readable end to the DONE state),
;; then reads AGAIN on the now-DONE end → spec `stream_copy` traps
;; (`trap_if(e.state != CopyState.IDLE)`). The first read is fine (idle); the
;; second must trap, so a clean EXIT here would mean the precondition is missing.
(component
  (type $st (stream u8))
  (core module $libc (memory (export "mem") 1))
  (core instance $libc (instantiate $libc))
  (core func $sn (canon stream.new $st))
  (core func $rd (canon stream.read $st (memory $libc "mem")))
  (core func $dw (canon stream.drop-writable $st))
  (core module $m
    (import "async" "stream-new" (func $sn (result i64)))
    (import "async" "stream-read" (func $rd (param i32 i32 i32) (result i32)))
    (import "async" "drop-writable" (func $dw (param i32)))
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
    (func (export "run") (result i32)
      (local $h i64)
      (local.set $h (call $sn))
      (call $dw (i32.wrap_i64 (i64.shr_u (local.get $h) (i64.const 32)))) ;; drop writable
      (call $rd (i32.wrap_i64 (local.get $h)) (i32.const 0) (i32.const 1)) ;; 1st read → DROPPED, end now DONE
      drop
      (call $rd (i32.wrap_i64 (local.get $h)) (i32.const 0) (i32.const 1)) ;; 2nd read on DONE end → traps
      drop
      i32.const 0)) ;; a clean EXIT would mean the 2nd read did NOT trap
  (core instance $deps
    (export "stream-new" (func $sn))
    (export "stream-read" (func $rd))
    (export "drop-writable" (func $dw)))
  (core instance $i (instantiate $m (with "async" (instance $deps))))
  (func (export "run") async
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
