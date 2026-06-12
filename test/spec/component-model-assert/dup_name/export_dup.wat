;; Invalid component: two exports with conflicting names — kebab labels compare
;; ASCII-case-insensitively, so `a-B` conflicts with `A-b`. Official corpus
;; reason: "export name `..` conflicts with previous name `..`" (naming.wast).
;; ADR-0176 validator rule 8.
(component
  (type $t (func))
  (export "a-B" (type $t))
  (export "A-b" (type $t))
)
