;; Invalid component: a `canon lift` referencing core-func index 99, but the
;; core-func index space has only one entry. The official corpus calls this
;; "function index out of bounds". Encoded with `wasm-tools parse` (no
;; validation); zwasm must REJECT it via the ADR-0176 validator (rule 2: Canon
;; index bounds), not accept it.
(component
  (core module $M (func (export "run") (result i32) (i32.const 0)))
  (core instance $m (instantiate $M))
  (type $ft (func (result u32)))
  (func (type $ft) (canon lift (core func 99)))
)
