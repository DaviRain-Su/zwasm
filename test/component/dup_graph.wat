;; D-305 fixture: a 2-component graph that marshals a STRING PARAM AND a STRING
;; RESULT across the SAME boundary — `dup(s: string) -> string`. This is the
;; composition of strlen_graph's string PARAM with strret_graph's string RESULT:
;; the lowered import flattens to `(param_ptr, param_len, retptr) -> ()`.
;;
;; Component B exports `dup(s: string) -> string` returning the same string it
;; received: it reads s[0] from B's OWN memory (so the param MUST be marshalled
;; A-memory → B-memory), copies the bytes into a fresh B alloc, and writes the
;; result (ptr,len) at the retptr (B writes B's memory). Component A builds "Z"
;; (0x5A) in its own memory, calls dup("Z"), then reads the FIRST BYTE of the
;; returned string from A's OWN memory — which REQUIRES the result be lowered
;; B-memory → A-memory at the boundary (lift from B, lower into A). Must yield
;; 0x5A=90. Each component uses a separate $libc core module (memory +
;; cabi_realloc) so the canon lower/lift can reference a memory that exists
;; BEFORE the main module instance (no definition cycle).
;; Provenance: test/component/strlen_graph.wat + test/component/strret_graph.wat.
(component
  ;; ---- child B: dup(s: string) -> string ----
  (component $B
    (core module $libc
      (memory (export "mem") 1)
      (global $bump (mut i32) (i32.const 1024))
      (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
        (local $p i32)
        (local.set $p (global.get $bump))
        (global.set $bump (i32.add (global.get $bump) (local.get 3)))
        (local.get $p)))
    (core instance $blibc (instantiate $libc))
    (core module $MB
      (import "libc" "mem" (memory 1))
      (import "libc" "cabi_realloc" (func $realloc (param i32 i32 i32 i32) (result i32)))
      ;; Core ABI of a lifted `(string) -> string`: (param_ptr, param_len, retptr).
      ;; Copy the received bytes (read from B's OWN memory) into a fresh B alloc
      ;; and write the result (ptr,len) at retptr.
      (func (export "dup") (param $ptr i32) (param $len i32) (param $ret i32)
        (local $d i32) (local $i i32)
        (local.set $d (call $realloc (i32.const 0) (i32.const 0) (i32.const 1) (local.get $len)))
        (block $done
          (loop $copy
            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
            (i32.store8 (i32.add (local.get $d) (local.get $i))
              (i32.load8_u (i32.add (local.get $ptr) (local.get $i))))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $copy)))
        (i32.store (local.get $ret) (local.get $d))            ;; ret[0] = ptr
        (i32.store offset=4 (local.get $ret) (local.get $len)))) ;; ret[1] = len
    (core instance $ib (instantiate $MB
      (with "libc" (instance $blibc))))
    (func (export "dup") (param "s" string) (result string)
      (canon lift (core func $ib "dup")
        (memory $blibc "mem") (realloc (func $blibc "cabi_realloc")))))

  ;; ---- child A: imports dup, exports run() -> u32 ----
  (component $A
    (import "dup" (func $dup (param "s" string) (result string)))
    (core module $libc
      (memory (export "mem") 1)
      (global $bump (mut i32) (i32.const 1024))
      (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
        (local $p i32)
        (local.set $p (global.get $bump))
        (global.set $bump (i32.add (global.get $bump) (local.get 3)))
        (local.get $p)))
    (core instance $alibc (instantiate $libc))
    (core func $dup_core (canon lower (func $dup)
      (memory $alibc "mem") (realloc (func $alibc "cabi_realloc"))))
    (core module $MA
      ;; The lowered import: (param_ptr, param_len, retptr) where retptr is A's
      ;; return area for the boundary's A-side (ptr,len).
      (import "deps" "dup" (func $dup (param i32 i32 i32)))
      (import "libc" "mem" (memory 1))
      (func (export "run") (result i32)
        (i32.store8 (i32.const 16) (i32.const 0x5A))      ;; "Z" at A.mem[16]
        (call $dup (i32.const 16) (i32.const 1) (i32.const 256)) ;; ret-area at A.mem[256]
        (i32.load8_u (i32.load (i32.const 256)))))         ;; first byte of A's result
    (core instance $deps (export "dup" (func $dup_core)))
    (core instance $ia (instantiate $MA
      (with "deps" (instance $deps)) (with "libc" (instance $alibc))))
    (func (export "run") (result u32)
      (canon lift (core func $ia "run"))))

  (instance $b (instantiate $B))
  (instance $a (instantiate $A (with "dup" (func $b "dup"))))
  (export "run" (func $a "run")))
