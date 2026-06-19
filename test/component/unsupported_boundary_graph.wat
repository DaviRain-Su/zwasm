;; D-466 regression fixture: a cross-component graph with an UNSUPPORTED boundary
;; shape (B exports sel with 5 params — the boundary trampoline handles only
;; 1/2/3-flat-scalar arities), so instantiateGraph returns UnsupportedBoundaryType.
;; Used by component_tests.zig to assert the FAILED-instantiate cleanup path does
;; not double-free (graph.deinit is the sole owner of appended module/bctx/fctx;
;; the prior local errdefers double-freed). NOT a corpus assert fixture.
(component
  (component $B
    (core module $MB (func (export "sel") (param i32 i32 i32 i32 i32) (result i32) local.get 4))
    (core instance $ib (instantiate $MB))
    (func (export "sel") (param "a" u32)(param "b" u32)(param "c" u32)(param "d" u32)(param "e" u32) (result u32)
      (canon lift (core func $ib "sel"))))
  (component $A
    (import "sel" (func $s (param "a" u32)(param "b" u32)(param "c" u32)(param "d" u32)(param "e" u32) (result u32)))
    (core func $sc (canon lower (func $s)))
    (core module $MA
      (import "deps" "sel" (func $s (param i32 i32 i32 i32 i32) (result i32)))
      (func (export "run") (result i32) (call $s (i32.const 1)(i32.const 2)(i32.const 3)(i32.const 4)(i32.const 5))))
    (core instance $deps (export "sel" (func $sc)))
    (core instance $ia (instantiate $MA (with "deps" (instance $deps))))
    (func (export "run") (result u32) (canon lift (core func $ia "run"))))
  (instance $b (instantiate $B))
  (instance $a (instantiate $A (with "sel" (func $b "sel"))))
  (export "run" (func $a "run")))
