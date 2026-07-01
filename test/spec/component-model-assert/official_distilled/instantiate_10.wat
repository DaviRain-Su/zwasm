;; Official corpus instantiate.wast — expected: "instantiation argument `a` conflicts with previous argument `a`"
(component
    (component $m)
    (instance $i (instantiate $m))
    (instance (instantiate $m
      (with "a" (instance $i))
      (with "a" (instance $i))
    ))
  )
