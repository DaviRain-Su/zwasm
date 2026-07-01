;; custom-page-sizes (ADR-0168 v0.2): memory.size on a 1-byte-page mem = byte count.
(module (memory 1 1 (pagesize 1)) (func (export "test") (result i32) (memory.size)))
