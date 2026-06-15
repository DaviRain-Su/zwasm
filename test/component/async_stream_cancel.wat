;; WASI-0.3 / CM-async fixture (D-335 unit D-ζ2 Slice 3c, ADR-0189): a guest
;; mints a stream, issues a read that BLOCKs (parks the readable end async-
;; copying), then cancel-reads it → returns CANCELLED count 0 ((0<<4)|2 = 2).
;; Exercises the stream.cancel-read host builtin (single-task: read-then-cancel
;; within one task is reachable; the read parks, cancel unparks).
(component
  (type $st (stream u8))
  (core module $libc (memory (export "mem") 1))
  (core instance $libc (instantiate $libc))
  (core func $sn (canon stream.new $st))
  (core func $rd (canon stream.read $st (memory $libc "mem")))
  (core func $cr (canon stream.cancel-read $st))
  (core module $m
    (import "async" "stream-new" (func $sn (result i64)))
    (import "async" "stream-read" (func $rd (param i32 i32 i32) (result i32)))
    (import "async" "cancel-read" (func $cr (param i32) (result i32)))
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
    (func (export "run") (result i32)
      (local $r i32)
      (local.set $r (i32.wrap_i64 (call $sn))) ;; readable end (ri = low 32)
      (call $rd (local.get $r) (i32.const 0) (i32.const 1)) ;; BLOCKED → end parks
      (i32.const -1) (i32.ne) (if (then unreachable)) ;; assert it blocked
      (call $cr (local.get $r)) ;; cancel the parked read
      (i32.const 2) (i32.ne) (if (then unreachable)) ;; assert CANCELLED (count 0)
      i32.const 0)) ;; 0 = EXIT
  (core instance $deps
    (export "stream-new" (func $sn))
    (export "stream-read" (func $rd))
    (export "cancel-read" (func $cr)))
  (core instance $i (instantiate $m (with "async" (instance $deps))))
  (func (export "run") async
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
