;; Official corpus naming.wast — expected: "`1` is not in kebab case"
(component
    (import "f" (func))
    (instance (export "1" (func 0)))
  )
