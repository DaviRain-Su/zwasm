;; WASI-0.3 / CM-async fixture (D-335 unit D-ζ2 Slice 3b, ADR-0189): a guest
;; mints a stream, DROPS the writable end, then reads the readable end → the
;; read observes the dropped peer and returns DROPPED ((0<<4)|1 = 1). Asserts
;; the code, then EXITs. Exercises the read trampoline's dropped-peer path.
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
      ;; drop the writable end (wi = high 32) → marks the shared rendezvous dropped
      (call $dw (i32.wrap_i64 (i64.shr_u (local.get $h) (i64.const 32))))
      ;; read the readable end (ri = low 32) → DROPPED (peer gone)
      (call $rd (i32.wrap_i64 (local.get $h)) (i32.const 0) (i32.const 1))
      (i32.const 1) ;; DROPPED = (0<<4)|1
      (i32.ne)
      (if (then unreachable)) ;; trap if the read did NOT report DROPPED
      i32.const 0)) ;; 0 = EXIT
  (core instance $deps
    (export "stream-new" (func $sn))
    (export "stream-read" (func $rd))
    (export "drop-writable" (func $dw)))
  (core instance $i (instantiate $m (with "async" (instance $deps))))
  (func (export "run") async
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
