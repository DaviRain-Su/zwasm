;; D-305 rare-shape: a 4-PARAM arity cross-component boundary. B exports
;; sel4(a,b,c,d: u32) -> u32 = d. Four flat u32 params flatten to four core i32
;; words; the boundary trampoline handled only ≤3 (BoundarySig3), so
;; boundaryShapeOk rejected params.len == 4. All primitive (no nominal types).
;; A calls sel4(7,8,9,10), expects d = 10.
(component
  (component $B
    (core module $MB
      (func (export "sel4") (param i32 i32 i32 i32) (result i32) local.get 3))
    (core instance $ib (instantiate $MB))
    (func (export "sel4") (param "a" u32)(param "b" u32)(param "c" u32)(param "d" u32) (result u32)
      (canon lift (core func $ib "sel4"))))
  (component $A
    (import "sel4" (func $s (param "a" u32)(param "b" u32)(param "c" u32)(param "d" u32) (result u32)))
    (core func $sc (canon lower (func $s)))
    (core module $MA
      (import "deps" "sel4" (func $s (param i32 i32 i32 i32) (result i32)))
      (func (export "run") (result i32) (call $s (i32.const 7)(i32.const 8)(i32.const 9)(i32.const 10))))
    (core instance $deps (export "sel4" (func $sc)))
    (core instance $ia (instantiate $MA (with "deps" (instance $deps))))
    (func (export "run") (result u32) (canon lift (core func $ia "run"))))
  (instance $b (instantiate $B))
  (instance $a (instantiate $A (with "sel4" (func $b "sel4"))))
  (export "run" (func $a "run")))
