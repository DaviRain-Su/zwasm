(component
  ;; ---- child component B: exports adder: func(u32,u32)->u32 ----
  (component $B
    (core module $MB
      (func (export "adder") (param i32 i32) (result i32)
        local.get 0 local.get 1 i32.add))
    (core instance $ib (instantiate $MB))
    (func (export "adder") (param "a" u32) (param "b" u32) (result u32)
      (canon lift (core func $ib "adder")))
  )

  ;; ---- child component A: imports adder, exports add-five: func(u32)->u32 ----
  (component $A
    (import "adder" (func $adder (param "a" u32) (param "b" u32) (result u32)))
    ;; lower the imported component func to a core func A's module can call
    (core func $adder_core (canon lower (func $adder)))
    (core module $MA
      (import "deps" "adder" (func $adder (param i32 i32) (result i32)))
      (func (export "add-five") (param i32) (result i32)
        local.get 0 i32.const 5 call $adder))
    (core instance $deps (export "adder" (func $adder_core)))
    (core instance $ia (instantiate $MA (with "deps" (instance $deps))))
    (func (export "add-five") (param "x" u32) (result u32)
      (canon lift (core func $ia "add-five")))
  )

  ;; ---- outer: instantiate B, instantiate A with B, re-export add-five ----
  (instance $b (instantiate $B))
  (instance $a (instantiate $A (with "adder" (func $b "adder"))))
  (export "add-five" (func $a "add-five"))
)
