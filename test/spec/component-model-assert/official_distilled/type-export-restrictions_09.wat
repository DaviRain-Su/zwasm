;; Official corpus type-export-restrictions.wast — expected: "type not valid to be used as export"
(component
    (type $t (flags "a"))
    (type $f (list $t))
    (export "f" (type $f))
  )
