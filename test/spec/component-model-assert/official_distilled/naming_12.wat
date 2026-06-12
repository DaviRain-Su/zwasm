;; Official corpus naming.wast — expected: "import name `[static]a.a` conflicts with previous name `a`"
(component
    (import "a" (type $a (sub resource)))
    (import "[static]a.a" (func))
  )
