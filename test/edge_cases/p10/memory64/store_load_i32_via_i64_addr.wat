;; ADR-0111 D2 + D4 — Wasm 3.0 memory64 end-to-end fixture.
;;
;; Memory declared with i64 idx_type (`(memory i64 1)`); per spec
;; §3.4.7 / §5.4.6 all memory ops on this memory take i64
;; addresses, regardless of the op's value-type suffix. Store 42
;; at address 0; load it back; export the loaded i32. Expected
;; result: 42.
;;
;; Stress axes (`.claude/rules/edge_case_testing.md`):
;;   - Numeric range: i64 address space (this fixture: trivial addr=0).
;;   - Dispatch shape: i32.load on i64-indexed memory (validator
;;     `opLoad` must dispatch address type on memory0_idx_type;
;;     codegen must route to emitMemOpI64 X-form addr load).
;;   - Validator strictness: skipMemarg must consume the memarg
;;     correctly regardless of bit-6 (this fixture's memarg has
;;     bit-6 unset → implicit memidx=0).
;;
;; Provenance: internally derived from sub-10.M-5 boundary at
;; commit 96dafb3c (validator widening + e2e test in runner.zig
;; verifies the same end-state).
(module
  (memory i64 1)
  (func (export "test") (result i32)
    i64.const 0
    i32.const 42
    i32.store offset=0 align=2
    i64.const 0
    i32.load offset=0 align=2))
