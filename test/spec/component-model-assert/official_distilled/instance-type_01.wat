;; Official corpus instance-type.wast — expected: "export name `a` conflicts with previous name `a`"
(component
    (type (instance
      (export "a" (func))
      (export "a" (func)))))
