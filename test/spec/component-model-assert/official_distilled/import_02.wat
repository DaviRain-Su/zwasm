;; Official corpus import.wast — expected: "import name `a` conflicts with previous name `a`"
(component
    (type (component
      (import "a" (func))
      (import "a" (func))
    ))
  )
