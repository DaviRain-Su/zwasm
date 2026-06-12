;; Invalid component: duplicate variant case name. Official corpus reason:
;; "variant case name `x` conflicts with previous case name `x`"
;; (type-syntax.wast). ADR-0176 validator rule 8.
(component
  (type (variant (case "x" u32) (case "x")))
)
