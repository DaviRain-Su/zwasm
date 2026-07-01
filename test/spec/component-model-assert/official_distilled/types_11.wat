;; Official corpus types.wast — expected: "export name `FOO-bar-BAZ` conflicts with previous name `foo-BAR-baz`"
(component
    (type (instance
      (export "foo-BAR-baz" (func))
      (export "FOO-bar-BAZ" (func))
    ))
  )
