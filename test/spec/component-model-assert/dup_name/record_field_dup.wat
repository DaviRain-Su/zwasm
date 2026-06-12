;; Invalid component: record field labels conflict case-insensitively
;; (`A-b-C-d` vs `a-B-c-D`). Official corpus reason: "record field name
;; `A-b-C-d` conflicts with previous field name `a-B-c-D`" (naming.wast).
;; ADR-0176 validator rule 8.
(component
  (type (record (field "a-B-c-D" u32) (field "A-b-C-d" u32)))
)
