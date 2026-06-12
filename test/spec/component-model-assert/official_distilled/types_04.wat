;; Official corpus types.wast — expected: "type index out of bounds"
(component
    (type (component
      (export "a" (func (type 0)))
    ))
  )
