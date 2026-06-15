;; WASI-0.3 / CM-async fixture (D-335 / D-445): a guest calls stream.read with a
;; handle it never minted (999) → the host table lookup returns InvalidHandle.
;; A guest-supplied bad handle is a guest fault, so the call traps (canonical
;; guest trap) rather than aborting the host. Regression guard for D-445: before
;; the mapAsyncFault narrowing this InvalidHandle hit mapDispatchErr's
;; else=>@panic and crashed the host process on guest input.
(component
  (type $st (stream u8))
  (core module $libc (memory (export "mem") 1))
  (core instance $libc (instantiate $libc))
  (core func $rd (canon stream.read $st (memory $libc "mem")))
  (core module $m
    (import "async" "stream-read" (func $rd (param i32 i32 i32) (result i32)))
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
    (func (export "run") (result i32)
      ;; read a never-minted handle → InvalidHandle → traps before returning
      (call $rd (i32.const 999) (i32.const 0) (i32.const 1))
      drop
      i32.const 0)) ;; a clean EXIT here would mean the bad handle did NOT trap
  (core instance $deps
    (export "stream-read" (func $rd)))
  (core instance $i (instantiate $m (with "async" (instance $deps))))
  (func (export "run") async
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
