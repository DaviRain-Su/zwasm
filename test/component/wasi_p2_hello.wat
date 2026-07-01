;; Minimal hand-authored WASI Preview 2 component.
;; Prints "hello\n" to stdout via component-level WASI interfaces:
;;   wasi:io/error    -- error resource (referenced by stream-error)
;;   wasi:io/streams  -- output-stream resource, blocking-write-and-flush, resource-drop
;;   wasi:cli/stdout  -- get-stdout
;; Exports the wasi:cli/run world's `run: func() -> result`.
(component
  ;; ---- import wasi:io/error (just the `error` resource) ----
  (import "wasi:io/error@0.2.0" (instance $io-error
    (export "error" (type (sub resource)))))
  (alias export $io-error "error" (type $error))

  ;; ---- import wasi:io/streams ----
  ;; stream-error = variant { last-operation-failed(own<error>), closed }
  ;; NOTE: a named type used in an instance-type func signature must be referenced
  ;; through its EXPORTED binding, not the original definition (wasm-tools rule).
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

  ;; ---- import wasi:cli/stdout ----
  (import "wasi:cli/stdout@0.2.0" (instance $cli-stdout
    (alias outer 1 $output-stream (type $os-out))
    (export "output-stream" (type (eq $os-out)))
    (type $own-os (own $os-out))
    (export "get-stdout" (func (result $own-os)))))

  ;; ---- lower the imported component funcs to core funcs ----
  (core func $get-stdout
    (canon lower (func $cli-stdout "get-stdout")))
  (core module $libc (memory (export "memory") 1))
  (core instance $libc (instantiate $libc))
  (core func $write
    (canon lower (func $io-streams "[method]output-stream.blocking-write-and-flush")
      (memory $libc "memory")))
  (core func $drop-os
    (canon resource.drop $output-stream))

  ;; ---- core module that does the print ----
  (core module $M
    (import "io" "get-stdout" (func $get-stdout (result i32)))
    ;; blocking-write-and-flush(self:i32, ptr:i32, len:i32, retptr:i32)
    (import "io" "write" (func $write (param i32 i32 i32 i32)))
    (import "io" "drop-os" (func $drop-os (param i32)))
    (import "libc" "memory" (memory 1))
    (data (i32.const 16) "hello\n")
    (func (export "run") (result i32)
      (local $stream i32)
      (local.set $stream (call $get-stdout))
      ;; write "hello\n" (ptr=16, len=6); retptr=128 holds the result variant
      (call $write (local.get $stream) (i32.const 16) (i32.const 6) (i32.const 128))
      (call $drop-os (local.get $stream))
      ;; run returns result<_,_>; ABI: 0 = ok. retptr@128 byte0 = write disc, ignore.
      (i32.const 0)))

  (core instance $deps-io (export "get-stdout" (func $get-stdout))
                          (export "write" (func $write))
                          (export "drop-os" (func $drop-os)))
  (core instance $m (instantiate $M
    (with "io" (instance $deps-io))
    (with "libc" (instance $libc))))

  ;; ---- lift the core `run` to the component-level wasi:cli/run signature ----
  ;; run: func() -> result   (no payload, no error payload)
  (type $run-result (result))
  (func $run (result $run-result) (canon lift (core func $m "run")))
  (component $RunShim
    (import "import-func-run" (func $rf (result (result))))
    (export "run" (func $rf)))
  (instance $run-inst (instantiate $RunShim (with "import-func-run" (func $run))))
  (export "wasi:cli/run@0.2.0" (instance $run-inst))
)
