;; Official corpus instantiate.wast — expected: "export name `a` conflicts with previous name `a`"
(component
    (component $c)
    (instance
      (export "a" (component $c))
      (export "a" (component $c))
    )
  )
