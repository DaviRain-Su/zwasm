;; WASI-0.3 / CM-async fixture (D-335 unit D-ζ2 Slice 3, ADR-0189): an async
;; export whose core entry mints a stream, then drops BOTH ends (readable +
;; writable) and EXITs. Exercises stream.drop-readable/writable host builtins:
;; the first drop marks the shared rendezvous dropped + releases one ref (kept
;; alive), the second frees the shared (refcount → 0).
(component
  (type $st (stream u8))
  (core func $sn (canon stream.new $st))
  (core func $dr (canon stream.drop-readable $st))
  (core func $dw (canon stream.drop-writable $st))
  (core module $m
    (import "async" "stream-new" (func $sn (result i64)))
    (import "async" "drop-readable" (func $dr (param i32)))
    (import "async" "drop-writable" (func $dw (param i32)))
    (func (export "callback") (param i32 i32 i32) (result i32) i32.const 0)
    (func (export "run") (result i32)
      (local $h i64)
      (local.set $h (call $sn))
      (call $dr (i32.wrap_i64 (local.get $h)))                              ;; ri (low 32)
      (call $dw (i32.wrap_i64 (i64.shr_u (local.get $h) (i64.const 32))))   ;; wi (high 32)
      i32.const 0)) ;; 0 = EXIT
  (core instance $deps
    (export "stream-new" (func $sn))
    (export "drop-readable" (func $dr))
    (export "drop-writable" (func $dw)))
  (core instance $i (instantiate $m (with "async" (instance $deps))))
  (func (export "run") async
    (canon lift (core func $i "run") async (callback (func $i "callback")))))
