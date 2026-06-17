;; ADR-0195 (e) / D-464(1) adversarial ROBUSTNESS: a cross-component stream whose
;; WRITABLE peer is DROPPED mid-rendezvous must let the reader observe a clean
;; DROPPED, never hang (AsyncDeadlock), silently return 0, or trap.
;;
;; Component A's `run` mints a `stream<u8>` (readable r + writable w), async-calls
;; B's `tick(stream<u8>)` passing the writable w. B does NOT write — it DROPS w
;; (`stream.drop-writable`). The shared rendezvous is now marked dropped. A then
;; `stream.read(r, …)` → the read folds the dropped peer into a DROPPED return code
;; (the spec `ReturnCode.dropped` encodes as `(count << 4) | 1` = 1 for count 0).
;; A `task.return`s that raw read code; the test asserts A's task result == 1,
;; proving the reader saw DROPPED (not BLOCKED=0xffffffff, not COMPLETED=0, not a
;; hang). The graph drop path (B owns w after the boundary transfer, ADR-0197, so
;; `stream.drop-writable` is permitted) is otherwise untested cross-component.
(component
  ;; ---- child B: tick: async func(stream<u8>) — DROPS the writable end, writes nothing ----
  (component $B
    (type $st (stream u8))
    (core module $MemB (memory (export "mem") 1))
    (core instance $memb (instantiate $MemB))
    (core func $sdw (canon stream.drop-writable $st))
    (core module $MB
      (import "async" "stream-drop-writable" (func $sdw (param i32)))
      (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
      (func (export "tick") (param i32) (result i32)
        (call $sdw (local.get 0))    ;; drop the granted writable end w (no write)
        i32.const 0))                ;; 0 = EXIT
    (core instance $deps (export "stream-drop-writable" (func $sdw)))
    (core instance $ib (instantiate $MB (with "async" (instance $deps))))
    (func (export "tick") async (param "s" $st)
      (canon lift (core func $ib "tick") async (callback (func $ib "callback"))))
  )

  ;; ---- child A: mints the stream, async-calls B(w), reads r → DROPPED code, returns it ----
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
        (local $h i64) (local $r i32) (local $w i32)
        (local.set $h (call $sn))                                  ;; mint stream → r | (w<<32)
        (local.set $r (i32.wrap_i64 (local.get $h)))               ;; readable end
        (local.set $w (i32.wrap_i64 (i64.shr_u (local.get $h) (i64.const 32)))) ;; writable end
        (drop (call $tick (local.get $w)))                         ;; B runs now, DROPS w
        (call $a_tr (call $sr (local.get $r) (i32.const 0) (i32.const 1))) ;; read → DROPPED code 1; task.return it
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
