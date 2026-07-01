;; Invalid component: an `alias outer` with count 100 inside a nested component
;; type — at depth 2 only counts 0..1 are enclosing-reachable. Official corpus
;; reason: "invalid outer alias count of 100" (types.wast). ADR-0176 validator
;; rule 6.
(component
  (type (component
    (alias outer 100 0 (type))
  ))
)
