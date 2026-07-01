;; Official corpus types.wast — expected: "export name `A` conflicts with previous name `a`"
(component
    (type (component
      (export "a" (func))
      (export "A" (func))
    ))
  )
