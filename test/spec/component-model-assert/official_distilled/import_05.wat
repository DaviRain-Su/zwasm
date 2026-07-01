;; Official corpus import.wast — expected: "conflicts with previous name"
(component
    (import "wasi:http/types" (func))
    (import "wasi:http/types" (func))
  )
