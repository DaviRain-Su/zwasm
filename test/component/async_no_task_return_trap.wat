;; WASI-0.3 / CM-async fixture (D-335 front ②, wasmtime task-return-traps.wast):
;; an async-lifted export that DECLARES a result (`result u32`) but EXITs without
;; ever calling task.return. Per CanonicalABI.md the task "failed to produce a
;; result" → trap. Contrast async_task_return.wat (same shape but calls
;; task.return(42) → completes cleanly). The runner checks ctx.task_return after
;; the callback loop exits when the export's lifted type has a result.
(component
  (core module $m
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
    (func (export "run") (result i32)
      i32.const 0)) ;; EXIT without task.return — must trap (result undelivered)
  (core instance $i (instantiate $m))
  (func (export "run") async (result u32)
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
