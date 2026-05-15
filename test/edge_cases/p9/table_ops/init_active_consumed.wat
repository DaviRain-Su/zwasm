;; Wasm spec §4.5.4 — active elem segments are consumed at
;; instantiation; their effective size becomes 0 for any
;; subsequent `table.init`. Without an explicit `elem.drop`,
;; calling `table.init` on the active segment with n > 0 traps
;; "out of bounds table access". §9.9 / 9.9-l-1b-d093-d49 fix
;; (D-123): the spec_assert harness's `populateElemSegments`
;; marks active + declarative segments as dropped at module
;; load so this trap fires correctly.
(module
  (table 3 funcref)
  (func $f0)
  (elem (table 0) (i32.const 0) func $f0)
  (func (export "test") (result i32)
    i32.const 0
    i32.const 0
    i32.const 1
    table.init 0 0
    i32.const 0))
