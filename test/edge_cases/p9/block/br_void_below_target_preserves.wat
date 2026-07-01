;; D-093 (d-9) regression: br to a void inner block must preserve
;; vregs below the target's entry stack-depth. Pre-d-9 liveness's
;; br handler closed ALL live vregs at the br site, causing
;; regalloc to alias the local.get's vreg with the i32.const that
;; followed the void block.
;;
;; Provenance: block.wast `break-inner` (Wasm spec corpus). The
;; original fixture combines four block patterns; this minimal
;; case isolates pattern #2 — `(block (br 0))` followed by
;; `(i32.const N)` inside a local-add chain.
;;
;; Expected: 0 + 2 = 2. Pre-d-9 returned 4.
(module
  (func (export "test") (result i32)
    (local i32)
    (local.set 0 (i32.const 0))
    (local.set 0 (i32.add (local.get 0) (block (result i32) (block (br 0)) (i32.const 0x2))))
    (local.get 0)))
