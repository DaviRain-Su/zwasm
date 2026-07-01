;; WASI Preview 2 component that reads wasi:clocks/wall-clock.now() and exit(0)
;; iff the realtime clock is past 2017 (seconds > 1_500_000_000), else exit(1).
;; Exercises the clocks_wall_now trampoline (Phase D3-3): now() -> datetime
;; {seconds: u64, nanoseconds: u32} lowers to a core (i32 retptr)->() with the
;; 12-byte record written into the guest's $libc memory at retptr; no realloc.
;; The exit channel (D3-1) surfaces the verdict as host.exit_code.
(component
  (import "wasi:clocks/wall-clock@0.2.0" (instance $wall
    (type $datetime-def (record (field "seconds" u64) (field "nanoseconds" u32)))
    (export "datetime" (type $datetime (eq $datetime-def)))
    (export "now" (func (result $datetime)))))
  (import "wasi:cli/exit@0.2.0" (instance $cli-exit
    (export "exit" (func (param "status" (result))))))

  (core module $libc (memory (export "memory") 1))
  (core instance $libc (instantiate $libc))
  (core func $now (canon lower (func $wall "now") (memory $libc "memory")))
  (core func $exit (canon lower (func $cli-exit "exit")))

  (core module $M
    (import "io" "now" (func $now (param i32)))   ;; retptr to a 16-byte datetime area
    (import "io" "exit" (func $exit (param i32)))
    (import "libc" "memory" (memory 1))
    (func (export "run") (result i32)
      (call $now (i32.const 16))                  ;; write datetime at offset 16
      (if (i64.gt_u (i64.load (i32.const 16)) (i64.const 1500000000)) ;; seconds @ 16
        (then (call $exit (i32.const 0)))
        (else (call $exit (i32.const 1))))
      (i32.const 0)))

  (core instance $deps-io (export "now" (func $now)) (export "exit" (func $exit)))
  (core instance $m (instantiate $M
    (with "io" (instance $deps-io))
    (with "libc" (instance $libc))))

  (type $run-result (result))
  (func $run (result $run-result) (canon lift (core func $m "run")))
  (component $RunShim
    (import "import-func-run" (func $rf (result (result))))
    (export "run" (func $rf)))
  (instance $run-inst (instantiate $RunShim (with "import-func-run" (func $run))))
  (export "wasi:cli/run@0.2.0" (instance $run-inst))
)
