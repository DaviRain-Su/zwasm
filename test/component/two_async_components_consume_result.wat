;; ADR-0195 step (d-b): the caller CONSUMES the callee's async result. Component A
;; async-imports B's `tick: async func() -> u32` (B task.returns 42). A's `run`
;; async-calls tick with a retptr; the graph lowers B's synchronously-resolved
;; result into A's memory at the retptr (asyncBoundaryRetTrampoline, d-b), so A
;; reads mem[retptr] == 42 and task.returns it. The test asserts A's own task
;; result (task 1) == 42 — proving A received B's value, not just that B produced
;; it (that is the d-a fixture two_async_components_task_return.wat, task 2 == 42).
(component
  ;; ---- child B: exports tick: async func() -> u32 (delivers 42) ----
  (component $B
    (core func $tr (canon task.return (result u32)))
    (core module $MB
      (import "async" "task-return" (func $tr (param i32)))
      (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
      (func (export "tick") (result i32)
        (call $tr (i32.const 42)) ;; deliver result 42
        i32.const 0))             ;; 0 = EXIT
    (core instance $deps (export "task-return" (func $tr)))
    (core instance $ib (instantiate $MB (with "async" (instance $deps))))
    (func (export "tick") async (result u32)
      (canon lift (core func $ib "tick") async (callback (func $ib "callback"))))
  )

  ;; ---- child A: async-imports tick, reads its result, exports run: async func() -> u32 ----
  (component $A
    (import "tick" (func $tick async (result u32)))
    (core module $Mem (memory (export "mem") 1))
    (core instance $mem (instantiate $Mem))
    ;; the lowered core func of a result-bearing async import is
    ;; `(param retptr i32) -> (result i32)`: retptr names where the subtask's u32
    ;; result lands (in $mem); the result is the async-call status code.
    (core func $tick_core (canon lower (func $tick) async (memory $mem "mem")))
    (core func $a_tr (canon task.return (result u32)))
    (core module $MA
      (import "mem" "mem" (memory 1))
      (import "deps" "tick" (func $tick (param i32) (result i32)))
      (import "deps" "task-return" (func $a_tr (param i32)))
      (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
      (func (export "run") (result i32)
        (drop (call $tick (i32.const 0)))      ;; start subtask; B's result lands at mem[0]
        (call $a_tr (i32.load (i32.const 0)))  ;; A reads B's result + task.returns it
        i32.const 0))                          ;; 0 = EXIT
    (core instance $deps (export "tick" (func $tick_core)) (export "task-return" (func $a_tr)))
    (core instance $ia (instantiate $MA (with "mem" (instance $mem)) (with "deps" (instance $deps))))
    (func (export "run") async (result u32)
      (canon lift (core func $ia "run") async (callback (func $ia "callback"))))
  )

  (instance $b (instantiate $B))
  (instance $a (instantiate $A (with "tick" (func $b "tick"))))
  (export "run" (func $a "run"))
)
