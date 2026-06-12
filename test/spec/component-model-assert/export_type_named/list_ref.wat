;; Invalid component: exporting a list type whose element references an
;; anonymous LOCAL type. Official corpus reason: "type not valid to be used
;; as export" (type-export-restrictions.wast). ADR-0176 validator rule 7.
(component
  (type $t (record (field "f" u32)))
  (type $f (list $t))
  (export "f" (type $f))
)
