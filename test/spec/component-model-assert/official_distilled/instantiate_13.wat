;; Official corpus instantiate.wast — expected: "index out of bounds"
(component
    (component $c)
    (instance (instantiate $c
      (with "" (func 0))
    ))
  )
