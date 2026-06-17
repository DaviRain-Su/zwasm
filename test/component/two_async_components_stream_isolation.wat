;; ADR-0197 (adversarial / D-463): cross-component async HANDLE ISOLATION. Demonstrates
;; that child B can today reach child A's UN-GRANTED stream handle because the graph
;; gives all children ONE shared StreamFutureTable (the D-463 leak), and pins the
;; post-fix guarantee that it must instead TRAP.
;;
;; Child A mints TWO streams over the (currently graph-shared) table:
;;   stream1 → readable r1=1, writable w1=2
;;   stream2 → readable r2=3, writable w2=4   (A's PRIVATE stream — never passed out)
;; A async-calls B's `tick(stream<u8>)` passing ONLY w1. B IGNORES its granted handle
;; and writes 3 bytes {10,20,12} to the bare index 4 — which is A's PRIVATE writable
;; end w2, a handle B was never given. A then reads its private r2 and sums the bytes.
;;
;; TODAY (shared table — the leak): index 4 resolves in B's lookup to A's w2, so B's
;; write SUCCEEDS, injecting bytes into A's private stream2; A reads r2 → 10+20+12 == 42
;; and `driveAsyncMain` returns normally. The isolation test `expectError`s instead —
;; so it is RED today (proving the cross-component data-injection leak exists).
;;
;; POST-FIX (per-component tables, ADR-0197): only the transferred w1 lives in B's own
;; table; bare index 4 is out of B's table → `stream.write` traps (InvalidHandle →
;; canonical guest `error.Unreachable`). The test goes GREEN.
(component
  ;; ---- child B: tick: async func(stream<u8>) — writes {10,20,12} to the BARE index 4 ----
  (component $B
    (type $st (stream u8))
    (core module $MemB (memory (export "mem") 1))
    (core instance $memb (instantiate $MemB))
    (core func $sw (canon stream.write $st (memory $memb "mem")))
    (core module $MB
      (import "mem" "mem" (memory 1))
      (import "async" "stream-write" (func $sw (param i32 i32 i32) (result i32)))
      (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
      (func (export "tick") (param i32) (result i32)
        (i32.store8 (i32.const 0) (i32.const 10))      ;; bytes to inject
        (i32.store8 (i32.const 1) (i32.const 20))
        (i32.store8 (i32.const 2) (i32.const 12))
        ;; ADVERSARIAL: write to bare handle 4 (A's PRIVATE w2), NOT the granted param 0.
        (drop (call $sw (i32.const 4) (i32.const 0) (i32.const 3)))
        i32.const 0))                                  ;; 0 = EXIT
    (core instance $deps (export "stream-write" (func $sw)))
    (core instance $ib (instantiate $MB (with "mem" (instance $memb)) (with "async" (instance $deps))))
    (func (export "tick") async (param "s" $st)
      (canon lift (core func $ib "tick") async (callback (func $ib "callback"))))
  )

  ;; ---- child A: mints TWO streams, grants only w1, reads its private r2 ----
  (component $A
    (type $st (stream u8))
    (import "tick" (func $tick async (param "s" $st)))
    (core module $Mem (memory (export "mem") 1))
    (core instance $mem (instantiate $Mem))
    (core func $sn (canon stream.new $st))
    (core func $sr (canon stream.read $st (memory $mem "mem")))
    (core func $tick_core (canon lower (func $tick) async (memory $mem "mem")))
    (core func $a_tr (canon task.return (result u32)))
    (core module $MA
      (import "mem" "mem" (memory 1))
      (import "async" "stream-new" (func $sn (result i64)))
      (import "async" "stream-read" (func $sr (param i32 i32 i32) (result i32)))
      (import "deps" "tick" (func $tick (param i32) (result i32)))
      (import "deps" "task-return" (func $a_tr (param i32)))
      (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
      (func (export "run") (result i32)
        (local $h1 i64) (local $w1 i32) (local $h2 i64) (local $r2 i32)
        (local.set $h1 (call $sn))                                 ;; stream1 → r1=1, w1=2
        (local.set $w1 (i32.wrap_i64 (i64.shr_u (local.get $h1) (i64.const 32))))
        (local.set $h2 (call $sn))                                 ;; stream2 (PRIVATE) → r2=3, w2=4
        (local.set $r2 (i32.wrap_i64 (local.get $h2)))             ;; readable r2
        (drop (call $tick (local.get $w1)))                        ;; B runs; injects into bare 4 == w2
        (drop (call $sr (local.get $r2) (i32.const 8) (i32.const 3))) ;; read A's private stream2
        (call $a_tr (i32.add (i32.add
          (i32.load8_u (i32.const 8))
          (i32.load8_u (i32.const 9)))
          (i32.load8_u (i32.const 10))))                           ;; task.return(10+20+12 == 42)
        i32.const 0))                                              ;; 0 = EXIT
    (core instance $deps
      (export "stream-new" (func $sn))
      (export "stream-read" (func $sr))
      (export "tick" (func $tick_core))
      (export "task-return" (func $a_tr)))
    (core instance $ia (instantiate $MA (with "mem" (instance $mem)) (with "async" (instance $deps)) (with "deps" (instance $deps))))
    (func (export "run") async (result u32)
      (canon lift (core func $ia "run") async (callback (func $ia "callback"))))
  )

  (instance $b (instantiate $B))
  (instance $a (instantiate $A (with "tick" (func $b "tick"))))
  (export "run" (func $a "run"))
)
