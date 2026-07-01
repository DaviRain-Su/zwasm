;; WASI Preview 2 component that reads stdin via wasi:cli/stdin get-stdin →
;; wasi:io/streams input-stream.read, then exit(0) iff it read 5 bytes whose
;; first/last are 'z'/'m' (host feeds "zwasm"). Exercises the cli_get_stdin +
;; in_stream_read trampolines (Phase D3-5): get-stdin mints an input-stream
;; bound to fd 0; read(self, len) -> result<list<u8>, stream-error> reads into a
;; cabi_realloc'd buffer (the trampoline writes the result at retptr: ok disc@0,
;; data_ptr@4, len@8). Verdict via the exit channel (D3-1).
(component
  (import "wasi:io/error@0.2.0" (instance $io-error
    (export "error" (type (sub resource)))))
  (alias export $io-error "error" (type $error))

  (import "wasi:io/streams@0.2.0" (instance $io-streams
    (alias outer 1 $error (type $error-in))
    (export "error" (type $error-ex (eq $error-in)))
    (export "input-stream" (type $input-stream (sub resource)))
    (type $stream-error-def (variant (case "last-operation-failed" (own $error-ex)) (case "closed")))
    (export "stream-error" (type $stream-error (eq $stream-error-def)))
    (type $borrow-is (borrow $input-stream))
    (type $list-u8 (list u8))
    (export "[method]input-stream.read"
      (func (param "self" $borrow-is) (param "len" u64) (result (result $list-u8 (error $stream-error)))))))
  (alias export $io-streams "input-stream" (type $input-stream))

  (import "wasi:cli/stdin@0.2.0" (instance $cli-stdin
    (alias outer 1 $input-stream (type $is-out))
    (export "input-stream" (type (eq $is-out)))
    (type $own-is (own $is-out))
    (export "get-stdin" (func (result $own-is)))))
  (import "wasi:cli/exit@0.2.0" (instance $cli-exit
    (export "exit" (func (param "status" (result))))))

  (core module $libc
    (memory (export "memory") 1)
    (global $bump (mut i32) (i32.const 1024))
    (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
      (local $p i32)
      (local.set $p (global.get $bump))
      (global.set $bump (i32.add (global.get $bump) (local.get 3)))
      (local.get $p)))
  (core instance $libc (instantiate $libc))
  (alias core export $libc "cabi_realloc" (core func $cabi_realloc))

  (core func $get-stdin (canon lower (func $cli-stdin "get-stdin")))
  (core func $read
    (canon lower (func $io-streams "[method]input-stream.read") (memory $libc "memory") (realloc $cabi_realloc)))
  (core func $exit (canon lower (func $cli-exit "exit")))

  (core module $M
    (import "io" "get-stdin" (func $get-stdin (result i32)))
    (import "io" "read" (func $read (param i32 i64 i32)))   ;; (self, len, retptr)
    (import "io" "exit" (func $exit (param i32)))
    (import "libc" "memory" (memory 1))
    (func (export "run") (result i32)
      (local $h i32) (local $ptr i32) (local $got i32)
      (local.set $h (call $get-stdin))
      (call $read (local.get $h) (i64.const 16) (i32.const 16))   ;; retptr=16: disc@16, ptr@20, len@24
      (if (i32.eqz (i32.load8_u (i32.const 16)))                  ;; ok disc?
        (then
          (local.set $ptr (i32.load (i32.const 20)))
          (local.set $got (i32.load (i32.const 24)))
          (if (i32.and
                (i32.eq (local.get $got) (i32.const 5))           ;; "zwasm" = 5 bytes
                (i32.and
                  (i32.eq (i32.load8_u (local.get $ptr)) (i32.const 0x7a))                       ;; 'z'
                  (i32.eq (i32.load8_u (i32.add (local.get $ptr) (i32.const 4))) (i32.const 0x6d)))) ;; 'm'
            (then (call $exit (i32.const 0)))
            (else (call $exit (i32.const 1)))))
        (else (call $exit (i32.const 1))))
      (i32.const 0)))

  (core instance $deps-io
    (export "get-stdin" (func $get-stdin))
    (export "read" (func $read))
    (export "exit" (func $exit)))
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
