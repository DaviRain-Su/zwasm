;; Official corpus type-export-restrictions.wast — expected: "type not valid to be used as export"
(component
    (type $t (variant (case "a")))
    (type $f (list $t))
    (export "f" (type $f))
  )
