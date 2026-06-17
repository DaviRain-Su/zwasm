;; ADR-0195 step (d-c-1): a SYNCHRONOUS multi-element guest↔guest async STREAM
;; rendezvous across a component graph. Component A's `run: async func() -> u32`
;; mints a `stream<u8>` (readable r + writable w), async-calls B's
;; `tick: async func(stream<u8>)` passing the writable handle w. B runs DURING the
;; async call (synchronous enqueue), stores 3 bytes {10,20,12} in its memory and
;; `stream.write(w, &bytes, 3)` — depositing the elements into the graph-shared
;; rendezvous. A then `stream.read(r, &out, 3)` → COMPLETED(3), reads the 3 bytes
;; out of its memory, sums them (10+20+12 == 42) and task.returns the sum. The test
;; asserts A's own task result == 42, proving the bytes crossed B→A through the
;; stream (not just both tasks completing).
;;
;; The stream handle crosses as a bare i32: A's `stream.new` mints both ends into
;; the GRAPH-shared StreamFutureTable over the GRAPH-shared SharedTable, so w is
;; valid in B's `stream.write` lookup and resolves to the SAME rendezvous slot A
;; reads. The write happens BEFORE the read (B runs synchronously during the call),
;; so A's read never BLOCKs — the blocking (read-first) path is d-c-2.
(component
  ;; ---- child B: tick: async func(stream<u8>) — writes {10,20,12} into the stream ----
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
        (i32.store8 (i32.const 0) (i32.const 10))      ;; bytes to send
        (i32.store8 (i32.const 1) (i32.const 20))
        (i32.store8 (i32.const 2) (i32.const 12))
        (drop (call $sw (local.get 0) (i32.const 0) (i32.const 3))) ;; stream.write(w, &bytes, 3)
        i32.const 0))                                  ;; 0 = EXIT
    (core instance $deps (export "stream-write" (func $sw)))
    (core instance $ib (instantiate $MB (with "mem" (instance $memb)) (with "async" (instance $deps))))
    (func (export "tick") async (param "s" $st)
      (canon lift (core func $ib "tick") async (callback (func $ib "callback"))))
  )

  ;; ---- child A: mints the stream, async-calls B(w), reads the bytes, returns sum ----
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
        (local.set $h (call $sn))                                  ;; mint stream → ri|wi<<32
        (local.set $r (i32.wrap_i64 (local.get $h)))               ;; readable end
        (local.set $w (i32.wrap_i64 (i64.shr_u (local.get $h) (i64.const 32)))) ;; writable end
        (drop (call $tick (local.get $w)))                         ;; B runs now, writes 3 bytes into the stream
        (drop (call $sr (local.get $r) (i32.const 4) (i32.const 3))) ;; stream.read → {10,20,12} at mem[4..7]
        (call $a_tr (i32.add (i32.add                              ;; task.return(10+20+12 == 42)
          (i32.load8_u (i32.const 4))
          (i32.load8_u (i32.const 5)))
          (i32.load8_u (i32.const 6))))
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
