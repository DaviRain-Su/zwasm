;; WASI Preview 2 component that reads wasi:clocks/monotonic-clock.now() twice and
;; exit(0) iff the clock is sane (first read > 0 AND second read >= first), else
;; exit(1). Exercises the clocks_monotonic_now trampoline (Phase D3-2): now() ->
;; instant(u64) lowers to a core ()->i64; the trampoline forwards to the host
;; monotonic clock (P1 clock id 1). The exit channel (D3-1) surfaces the verdict
;; as host.exit_code — no stdout / return-area needed.
(component
  (import "wasi:clocks/monotonic-clock@0.2.0" (instance $mono
    (export "now" (func (result u64)))))
  (import "wasi:cli/exit@0.2.0" (instance $cli-exit
    (export "exit" (func (param "status" (result))))))

  (core func $now (canon lower (func $mono "now")))
  (core func $exit (canon lower (func $cli-exit "exit")))

  (core module $M
    (import "io" "now" (func $now (result i64)))
    (import "io" "exit" (func $exit (param i32)))
    (func (export "run") (result i32)
      (local $t1 i64)
      (local.set $t1 (call $now))
      (if (i32.and
            (i64.gt_s (local.get $t1) (i64.const 0))      ;; clock started
            (i64.ge_s (call $now) (local.get $t1)))       ;; monotonic non-decreasing
        (then (call $exit (i32.const 0)))                 ;; ok
        (else (call $exit (i32.const 1))))                ;; fail
      (i32.const 0)))                                     ;; unreached (exit traps)

  (core instance $deps-io (export "now" (func $now)) (export "exit" (func $exit)))
  (core instance $m (instantiate $M (with "io" (instance $deps-io))))

  (type $run-result (result))
  (func $run (result $run-result) (canon lift (core func $m "run")))
  (component $RunShim
    (import "import-func-run" (func $rf (result (result))))
    (export "run" (func $rf)))
  (instance $run-inst (instantiate $RunShim (with "import-func-run" (func $run))))
  (export "wasi:cli/run@0.2.0" (instance $run-inst))
)
