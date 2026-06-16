;; D-305 security fixture: a 2-component graph (cf. strlen_graph.wat) where A
;; calls B's `firstbyte(s: string) -> u32` with an OUT-OF-BOUNDS (ptr,len). A's
;; $libc memory is 1 page (64 KiB); A passes (ptr=0x10000000, len=0x10000000),
;; both far past that. The boundary trampoline's `caller_mem.sliceAt` over A's
;; memory MUST fail → the cross-component call MUST TRAP, not silently marshal a
;; wrong/empty string and return 0. Mirrors strlen_graph's structure exactly
;; except for the OOB constants in $MA's `run`.
(component
  ;; ---- child B: firstbyte(s: string) -> u32 = s[0] ----
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
      (func (export "firstbyte") (param $ptr i32) (param $len i32) (result i32)
        (i32.load8_u (local.get $ptr))))   ;; reads B's OWN memory at ptr
    (core instance $ib (instantiate $MB (with "libc" (instance $blibc))))
    (func (export "firstbyte") (param "s" string) (result u32)
      (canon lift (core func $ib "firstbyte")
        (memory $blibc "mem") (realloc (func $blibc "cabi_realloc")))))

  ;; ---- child A: imports firstbyte, exports run() -> u32 ----
  (component $A
    (import "firstbyte" (func $fb (param "s" string) (result u32)))
    (core module $libc
      (memory (export "mem") 1)
      (global $bump (mut i32) (i32.const 1024))
      (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
        (local $p i32)
        (local.set $p (global.get $bump))
        (global.set $bump (i32.add (global.get $bump) (local.get 3)))
        (local.get $p)))
    (core instance $alibc (instantiate $libc))
    (core func $fb_core (canon lower (func $fb)
      (memory $alibc "mem") (realloc (func $alibc "cabi_realloc"))))
    (core module $MA
      (import "deps" "firstbyte" (func $fb (param i32 i32) (result i32)))
      (import "libc" "mem" (memory 1))
      (func (export "run") (result i32)
        ;; OOB string (ptr,len) — both 0x10000000, far past A's 1-page memory.
        (call $fb (i32.const 0x10000000) (i32.const 0x10000000))))
    (core instance $deps (export "firstbyte" (func $fb_core)))
    (core instance $ia (instantiate $MA (with "deps" (instance $deps)) (with "libc" (instance $alibc))))
    (func (export "run") (result u32)
      (canon lift (core func $ia "run"))))

  (instance $b (instantiate $B))
  (instance $a (instantiate $A (with "firstbyte" (func $b "firstbyte"))))
  (export "run" (func $a "run")))
