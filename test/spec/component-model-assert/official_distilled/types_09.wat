;; Official corpus types.wast — expected: "invalid outer alias count of 100"
(component $c
    (type $f (func))
    (type $t (component
      (alias outer 100 0 (type))
    ))
  )
