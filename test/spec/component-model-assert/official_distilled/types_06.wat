;; Official corpus types.wast — expected: "import name `a` conflicts with previous name `A`"
(component
    (type (component
      (import "A" (func))
      (import "a" (func))
    ))
  )
