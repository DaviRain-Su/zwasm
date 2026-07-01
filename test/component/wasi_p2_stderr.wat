;; WASI Preview 2 component that prints "oops\n" to STDERR (not stdout) via
;; wasi:cli/stderr get-stderr → wasi:io/streams output-stream. Exercises the
;; classified host wiring on a second std stream (fd 2): get-stderr mints an
;; output-stream bound to fd 2, blocking-write-and-flush forwards to it.
(component
  (import "wasi:io/error@0.2.0" (instance $io-error
    (export "error" (type (sub resource)))))
  (alias export $io-error "error" (type $error))

  (import "wasi:io/streams@0.2.0" (instance $io-streams
    (alias outer 1 $error (type $error-in))
    (export "error" (type $error-ex (eq $error-in)))
    (export "output-stream" (type $output-stream (sub resource)))
    (type $stream-error-def (variant (case "last-operation-failed" (own $error-ex)) (case "closed")))
    (export "stream-error" (type $stream-error (eq $stream-error-def)))
    (type $borrow-os (borrow $output-stream))
    (type $list-u8 (list u8))
    (export "[method]output-stream.blocking-write-and-flush"
      (func (param "self" $borrow-os) (param "contents" $list-u8) (result (result (error $stream-error)))))))
  (alias export $io-streams "output-stream" (type $output-stream))

  (import "wasi:cli/stderr@0.2.0" (instance $cli-stderr
    (alias outer 1 $output-stream (type $os-out))
    (export "output-stream" (type (eq $os-out)))
    (type $own-os (own $os-out))
    (export "get-stderr" (func (result $own-os)))))

  (core func $get-stderr
    (canon lower (func $cli-stderr "get-stderr")))
  (core module $libc (memory (export "memory") 1))
  (core instance $libc (instantiate $libc))
  (core func $write
    (canon lower (func $io-streams "[method]output-stream.blocking-write-and-flush")
      (memory $libc "memory")))
  (core func $drop-os
    (canon resource.drop $output-stream))

  (core module $M
    (import "io" "get-stderr" (func $get-stderr (result i32)))
    (import "io" "write" (func $write (param i32 i32 i32 i32)))
    (import "io" "drop-os" (func $drop-os (param i32)))
    (import "libc" "memory" (memory 1))
    (data (i32.const 16) "oops\n")
    (func (export "run") (result i32)
      (local $stream i32)
      (local.set $stream (call $get-stderr))
      (call $write (local.get $stream) (i32.const 16) (i32.const 5) (i32.const 128))
      (call $drop-os (local.get $stream))
      (i32.const 0)))

  (core instance $deps-io (export "get-stderr" (func $get-stderr))
                          (export "write" (func $write))
                          (export "drop-os" (func $drop-os)))
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
