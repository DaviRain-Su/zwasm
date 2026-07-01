;; WASI Preview 2 component that calls wasi:random/insecure-seed.insecure-seed()
;; -> tuple<u64, u64>, ORs the two returned u64, and exit(0) iff some bit is set
;; (i.e. a real 128-bit seed was written), else exit(1). The tuple flattens past
;; MAX_FLAT_RESULTS=1 so it lowers to a core (i32 retptr); the trampoline writes
;; the two u64 at retptr (+0, +8) from the host's secure fill (over-satisfies the
;; insecure-seed contract). Proves the insecure-seed import resolves end-to-end.
(component
  (import "wasi:random/insecure-seed@0.2.0" (instance $seed
    (export "insecure-seed" (func (result (tuple u64 u64))))))
  (import "wasi:cli/exit@0.2.0" (instance $cli-exit
    (export "exit" (func (param "status" (result))))))

  (core module $libc (memory (export "memory") 1))
  (core instance $libc (instantiate $libc))

  (core func $seed (canon lower (func $seed "insecure-seed") (memory $libc "memory")))
  (core func $exit (canon lower (func $cli-exit "exit")))

  (core module $M
    (import "io" "seed" (func $seed (param i32)))   ;; (retptr)
    (import "io" "exit" (func $exit (param i32)))
    (import "libc" "memory" (memory 1))
    (func (export "run") (result i32)
      (call $seed (i32.const 16))                   ;; retptr=16: lo@16, hi@24
      (if (i64.ne (i64.or (i64.load (i32.const 16)) (i64.load (i32.const 24))) (i64.const 0))
        (then (call $exit (i32.const 0)))
        (else (call $exit (i32.const 1))))
      (i32.const 0)))

  (core instance $deps-io (export "seed" (func $seed)) (export "exit" (func $exit)))
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
