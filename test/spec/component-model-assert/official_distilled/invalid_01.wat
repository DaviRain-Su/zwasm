;; Official corpus invalid.wast — expected: "type index out of bounds"
(component
    (core type (module
      (import "" "" (func (type 1)))
    ))
    (type (func))
  )
