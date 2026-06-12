;; Official corpus naming.wast — expected: "import name `[method]a.a` conflicts with previous name `a`"
(component
    (import "a" (type $a (sub resource)))
    (import "[method]a.a" (func (param "self" (borrow $a))))
  )
