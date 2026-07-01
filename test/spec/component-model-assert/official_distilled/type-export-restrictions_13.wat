;; Official corpus type-export-restrictions.wast — expected: "type not valid to be used as export"
(component
    (type (component
      (type $t (record (field "f" u32)))
      (type $f (record (field "t" $t)))
      (export "f" (type (eq $f)))
    ))
  )
