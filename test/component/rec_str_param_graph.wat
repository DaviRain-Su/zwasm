;; D-305 RECORD-WITH-STRING param across a 2-component boundary.
;; info = record{ msg: string, n: u32 }. B exports f(p: info) -> u32 = n + len(msg).
;; A calls f({msg:"hello", n:3}) expecting 3+5 = 8.
;;
;; Unlike the flat-record param (record_param_graph.wat), `info` has an INTERNAL
;; POINTER (the string), so the param flattens to 3 core i32 words:
;;   (param i32 i32 i32) = (msg_ptr, msg_len, n)   [field order: msg then n]
;; The boundary must COPY the string bytes from A's memory into B's memory (B
;; reads its OWN linear memory at msg_ptr), while passing msg_len and n through.
;; Both sides therefore need (memory)+(cabi_realloc): A to hold the source
;; string, B as the lower target. Type spelling per record_param_graph.wat:
;; named record -> (export "info" (type ...)) -> alias across the boundary.
(component
  (component $B
    (type $info (record (field "msg" string) (field "n" u32)))
    (export $pe "info" (type $info))
    (core module $libc
      (memory (export "mem") 1)
      (global $bump (mut i32) (i32.const 1024))
      (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
        (global.get $bump)
        (global.set $bump (i32.add (global.get $bump) (local.get 3)))))
    (core instance $blibc (instantiate $libc))
    (core module $MB
      (import "libc" "mem" (memory 1))
      ;; f(msg_ptr, msg_len, n) -> n + msg_len  (B "reads" its copied string by
      ;; using the length the boundary lowered; the bytes live in B's mem at ptr).
      (func (export "f") (param i32 i32 i32) (result i32)
        (i32.add (local.get 2) (local.get 1))))
    (core instance $ib (instantiate $MB (with "libc" (instance $blibc))))
    (func $f (param "p" $pe) (result u32)
      (canon lift (core func $ib "f")
        (memory $blibc "mem") (realloc (func $blibc "cabi_realloc"))))
    (export "f" (func $f)))
  (component $A
    (type $info (record (field "msg" string) (field "n" u32)))
    (import "info" (type $pe (eq $info)))
    (import "f" (func $impf (param "p" $pe) (result u32)))
    (core module $libc
      (memory (export "mem") 1)
      (data (i32.const 256) "hello")
      (global $bump (mut i32) (i32.const 1024))
      (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
        (global.get $bump)
        (global.set $bump (i32.add (global.get $bump) (local.get 3)))))
    (core instance $alibc (instantiate $libc))
    (core func $fc (canon lower (func $impf)
      (memory $alibc "mem") (realloc (func $alibc "cabi_realloc"))))
    (core module $MA
      ;; Lowering an info PARAM gives core sig (msg_ptr, msg_len, n): A supplies
      ;; the source string pointer (256, "hello") + len 5 + n 3.
      (import "deps" "f" (func $f (param i32 i32 i32) (result i32)))
      (import "libc" "mem" (memory 1))
      (func (export "run") (result i32)
        (call $f (i32.const 256) (i32.const 5) (i32.const 3))))
    (core instance $deps (export "f" (func $fc)))
    (core instance $ia (instantiate $MA (with "deps" (instance $deps)) (with "libc" (instance $alibc))))
    (func (export "run") (result u32)
      (canon lift (core func $ia "run"))))
  (instance $b (instantiate $B))
  (alias export $b "info" (type $bp))
  (instance $a (instantiate $A
    (with "info" (type $bp))
    (with "f" (func $b "f"))))
  (export "run" (func $a "run")))
