;; D-305(b) RECORD result across a 2-component boundary.
;; B exports mk() -> point, point = record{x:u32, y:u32}, returning {x:3,y:4}.
;; A calls mk() and exports run() -> x+y = 7.
;;
;; A 2-u32 record RESULT exceeds MAX_FLAT_RESULTS(=1) so the canon ABI uses a
;; RETPTR. Asymmetric core sig: LIFT side (B's exported producer) is
;; `(result i32)` — returns a linear-memory pointer; LOWER side (A's caller
;; view) is `(param i32)` — the caller allocates the buffer and passes the
;; pointer in, then reads field x at offset 0 and y at offset 4. Both lift
;; and lower therefore REQUIRE (memory)+(realloc) canon options. The record
;; type must still cross the boundary via an exported/imported type (see
;; record_param_graph.wat header).
(component
  (component $B
    (type $point (record (field "x" u32) (field "y" u32)))
    (export $pe "point" (type $point))
    (core module $libc
      (memory (export "mem") 1)
      (global $bump (mut i32) (i32.const 1024))
      (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
        (global.get $bump)
        (global.set $bump (i32.add (global.get $bump) (local.get 3)))))
    (core instance $blibc (instantiate $libc))
    (core module $MB
      (import "libc" "mem" (memory 1))
      (func (export "mk") (result i32)
        (i32.store (i32.const 8) (i32.const 3))
        (i32.store offset=4 (i32.const 8) (i32.const 4))
        (i32.const 8)))
    (core instance $ib (instantiate $MB (with "libc" (instance $blibc))))
    (func $f (result $pe)
      (canon lift (core func $ib "mk")
        (memory $blibc "mem") (realloc (func $blibc "cabi_realloc"))))
    (export "mk" (func $f)))
  (component $A
    (type $point (record (field "x" u32) (field "y" u32)))
    (import "point" (type $pe (eq $point)))
    (import "mk" (func $mk (result $pe)))
    (core module $libc
      (memory (export "mem") 1)
      (global $bump (mut i32) (i32.const 1024))
      (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
        (global.get $bump)
        (global.set $bump (i32.add (global.get $bump) (local.get 3)))))
    (core instance $alibc (instantiate $libc))
    (core func $mk_core (canon lower (func $mk)
      (memory $alibc "mem") (realloc (func $alibc "cabi_realloc"))))
    ;; Lowering a record-RESULT import gives core sig (param i32): the CALLER
    ;; supplies the retptr buffer; mk writes x,y there. (Lifting gives result i32;
    ;; lowering flips it to a param — the canon ABI's caller-allocates form.)
    (core module $MA
      (import "deps" "mk" (func $mk (param i32)))
      (import "libc" "mem" (memory 1))
      (func (export "run") (result i32)
        (call $mk (i32.const 128))
        (i32.add (i32.load (i32.const 128)) (i32.load offset=4 (i32.const 128)))))
    (core instance $deps (export "mk" (func $mk_core)))
    (core instance $ia (instantiate $MA (with "deps" (instance $deps)) (with "libc" (instance $alibc))))
    (func (export "run") (result u32)
      (canon lift (core func $ia "run"))))
  (instance $b (instantiate $B))
  (alias export $b "point" (type $bp))
  (instance $a (instantiate $A
    (with "point" (type $bp))
    (with "mk" (func $b "mk"))))
  (export "run" (func $a "run")))
