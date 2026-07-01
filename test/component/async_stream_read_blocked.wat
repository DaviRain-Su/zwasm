;; WASI-0.3 / CM-async fixture (D-335 unit D-ζ2 Slice 3b, ADR-0189): a guest
;; mints a stream and reads its readable end with no writer ready → the read
;; returns BLOCKED (0xffffffff). The guest asserts the code, then EXITs. Single-
;; task can only reach BLOCKED here (COMPLETION needs a peer — Unit E; see lesson
;; 2026-06-16-stackless-stream-completion-needs-host-peer).
(component
  (type $st (stream u8))
  (core module $libc (memory (export "mem") 1))
  (core instance $libc (instantiate $libc))
  (core func $sn (canon stream.new $st))
  (core func $rd (canon stream.read $st (memory $libc "mem")))
  (core module $m
    (import "async" "stream-new" (func $sn (result i64)))
    (import "async" "stream-read" (func $rd (param i32 i32 i32) (result i32)))
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
    (func (export "run") (result i32)
      (local $h i64)
      (local.set $h (call $sn))
      ;; read readable end (ri = low 32) into mem[0], capacity 1 → BLOCKED
      (call $rd (i32.wrap_i64 (local.get $h)) (i32.const 0) (i32.const 1))
      (i32.const -1) ;; 0xffffffff = BLOCKED
      (i32.ne)
      (if (then unreachable)) ;; trap if the read did NOT block
      i32.const 0)) ;; 0 = EXIT
  (core instance $deps
    (export "stream-new" (func $sn))
    (export "stream-read" (func $rd)))
  (core instance $i (instantiate $m (with "async" (instance $deps))))
  (func (export "run") async
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
