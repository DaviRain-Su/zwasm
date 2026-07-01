;; ADR-0195 step (d-b-2): a single-shot guest↔guest async FUTURE rendezvous across
;; a component graph. Component A's `run: async func() -> u32` mints a `future<u32>`
;; (readable r + writable w), async-calls B's `tick: async func(future<u32>)` passing
;; the writable handle w. B runs DURING the async call (synchronous enqueue), stores
;; 42 in its memory and `future.write(w, &42, 1)` — depositing the value into the
;; graph-shared rendezvous. A then `future.read(r, &out, 1)` → COMPLETED, reads 42
;; out of its memory and task.returns it. The test asserts A's own task result == 42,
;; proving the value crossed B→A through the future (not just both tasks completing).
;;
;; The future handle crosses as a bare i32: A's `future.new` mints both ends into the
;; GRAPH-shared StreamFutureTable over the GRAPH-shared SharedTable, so w is valid in
;; B's `future.write` lookup and resolves to the SAME rendezvous slot A reads.
(component
  ;; ---- child B: tick: async func(future<u32>) — writes 42 into the future ----
  (component $B
    (type $ft (future u32))
    (core module $MemB (memory (export "mem") 1))
    (core instance $memb (instantiate $MemB))
    (core func $fw (canon future.write $ft (memory $memb "mem")))
    (core module $MB
      (import "mem" "mem" (memory 1))
      (import "async" "future-write" (func $fw (param i32 i32) (result i32)))
      (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
      (func (export "tick") (param i32) (result i32)
        (i32.store (i32.const 0) (i32.const 42))     ;; value to send
        (drop (call $fw (local.get 0) (i32.const 0))) ;; future.write(w, &42)
        i32.const 0))                                ;; 0 = EXIT
    (core instance $deps (export "future-write" (func $fw)))
    (core instance $ib (instantiate $MB (with "mem" (instance $memb)) (with "async" (instance $deps))))
    (func (export "tick") async (param "f" $ft)
      (canon lift (core func $ib "tick") async (callback (func $ib "callback"))))
  )

  ;; ---- child A: mints the future, async-calls B(w), reads the value, returns it ----
  (component $A
    (type $ft (future u32))
    (import "tick" (func $tick async (param "f" $ft)))
    (core module $Mem (memory (export "mem") 1))
    (core instance $mem (instantiate $Mem))
    (core func $fn (canon future.new $ft))
    (core func $fr (canon future.read $ft (memory $mem "mem")))
    (core func $tick_core (canon lower (func $tick) async (memory $mem "mem")))
    (core func $a_tr (canon task.return (result u32)))
    (core module $MA
      (import "mem" "mem" (memory 1))
      (import "async" "future-new" (func $fn (result i64)))
      (import "async" "future-read" (func $fr (param i32 i32) (result i32)))
      (import "deps" "tick" (func $tick (param i32) (result i32)))
      (import "deps" "task-return" (func $a_tr (param i32)))
      (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
      (func (export "run") (result i32)
        (local $h i64) (local $r i32) (local $w i32)
        (local.set $h (call $fn))                                  ;; mint future → ri|wi<<32
        (local.set $r (i32.wrap_i64 (local.get $h)))               ;; readable end
        (local.set $w (i32.wrap_i64 (i64.shr_u (local.get $h) (i64.const 32)))) ;; writable end
        (drop (call $tick (local.get $w)))                         ;; B runs now, writes 42 into the future
        (drop (call $fr (local.get $r) (i32.const 4))) ;; future.read → 42 at mem[4]
        (call $a_tr (i32.load (i32.const 4)))                      ;; task.return(42)
        i32.const 0))                                              ;; 0 = EXIT
    (core instance $deps
      (export "future-new" (func $fn))
      (export "future-read" (func $fr))
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
