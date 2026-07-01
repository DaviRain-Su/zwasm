;; Official corpus type-export-restrictions.wast — expected: "type not valid to be used as export"
(component
    (type $t (record (field "f" u32)))
    (type $f (variant (case "c" $t)))
    (export "f" (type $f))
  )
