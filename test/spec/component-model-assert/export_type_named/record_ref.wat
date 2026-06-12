;; Invalid component: exporting a record type whose field references another
;; anonymous LOCAL type — exported types may only reference named (imported/
;; exported/aliased) types. Official corpus reason: "type not valid to be used
;; as export" (type-export-restrictions.wast). ADR-0176 validator rule 7.
(component
  (type $t (record (field "f" u32)))
  (type $f (record (field "f" $t)))
  (export "f" (type $f))
)
