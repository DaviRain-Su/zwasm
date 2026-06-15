;; WASI-0.3 / CM-async fixture (D-335 unit D-ζ2 Slice 1, ADR-0189): an async
;; export with a result. The core task entry calls `task.return(42)` to deliver
;; its result, then returns EXIT (0). Exercises the P3 runner's task.return host
;; builtin end-to-end — after the loop exits, ctx.task_return == 42.
;; canon task.return plumbing verified vs the canon-import pattern in
;; wasi_p2_cli_env.wat (core func -> core instance export -> with).
(component
  (core func $tr (canon task.return (result u32)))
  (core module $m
    (import "async" "task-return" (func $tr (param i32)))
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
    (func (export "run") (result i32)
      (call $tr (i32.const 42)) ;; deliver result 42
      i32.const 0))             ;; 0 = EXIT
  (core instance $deps (export "task-return" (func $tr)))
  (core instance $i (instantiate $m (with "async" (instance $deps))))
  (func (export "run") async (result u32)
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
