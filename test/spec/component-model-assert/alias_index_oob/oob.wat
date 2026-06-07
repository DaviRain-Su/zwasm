;; Invalid component: an `alias core export` from core-instance index 99, but the
;; core-instance index space has only one entry. Official corpus: "instance index
;; out of bounds". Encoded via `wasm-tools parse` (no validation); zwasm must
;; REJECT it via the ADR-0176 validator (rule 3: alias instance-index bounds).
(component
  (core module $M (func (export "f")))
  (core instance $m (instantiate $M))
  (alias core export 99 "f" (core func))
)
