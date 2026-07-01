;; D-093 (d-9) regression: full `break-inner` spec fixture
;; (block.wast). Chains four block patterns with brs at varying
;; depths; sums their results into local 0. Pre-d-9 returned 16
;; instead of 15.
(module
  (func (export "test") (result i32)
    (local i32)
    (local.set 0 (i32.const 0))
    (local.set 0 (i32.add (local.get 0) (block (result i32) (block (result i32) (br 1 (i32.const 0x1))))))
    (local.set 0 (i32.add (local.get 0) (block (result i32) (block (br 0)) (i32.const 0x2))))
    (local.set 0 (i32.add (local.get 0) (block (result i32) (i32.ctz (br 0 (i32.const 0x4))))))
    (local.set 0 (i32.add (local.get 0) (block (result i32) (i32.ctz (block (result i32) (br 1 (i32.const 0x8)))))))
    (local.get 0)))
