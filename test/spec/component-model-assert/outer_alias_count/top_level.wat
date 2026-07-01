;; Invalid component: a top-level `alias outer` with count 100 — only count 0
;; (the current component) is enclosing-reachable at the top level. Official
;; corpus reason: "invalid outer alias count of 100" (alias.wast). ADR-0176
;; validator rule 6.
(component
  (alias outer 100 0 (type))
)
