;; Official corpus type-export-restrictions.wast — expected: "type not valid to be used as export"
(component
    (type $t (resource (rep i32)))
    (export "t" (type $t))
    (type $f (list (own $t)))
    (export "f" (type $f))
  )
