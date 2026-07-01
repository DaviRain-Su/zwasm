;; WASI-0.3 / CM-async fixture (D-335 / D-445): a guest mints a stream and calls
;; stream.cancel-read with NO copy in flight → StreamFutureEnd.cancel returns
;; NotCopying (the end is idle, not async-copying). That illegal op sequencing
;; is a guest fault, so the call traps rather than aborting the host. Regression
;; guard for D-445 (the cancel trampoline's mapAsyncFault narrowing).
(component
  (type $st (stream u8))
  (core func $sn (canon stream.new $st))
  (core func $cr (canon stream.cancel-read $st))
  (core module $m
    (import "async" "stream-new" (func $sn (result i64)))
    (import "async" "cancel-read" (func $cr (param i32) (result i32)))
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
    (func (export "run") (result i32)
      (local $r i32)
      (local.set $r (i32.wrap_i64 (call $sn))) ;; readable end, idle (no copy)
      ;; cancel an idle end → NotCopying → traps before returning
      (call $cr (local.get $r))
      drop
      i32.const 0)) ;; a clean EXIT here would mean the illegal cancel did NOT trap
  (core instance $deps
    (export "stream-new" (func $sn))
    (export "cancel-read" (func $cr)))
  (core instance $i (instantiate $m (with "async" (instance $deps))))
  (func (export "run") async
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
