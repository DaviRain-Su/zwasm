;; Official corpus types.wast — expected: "type index out of bounds"
(component
    (core type (module
      (export "a" (func (type 0)))
    ))
  )
