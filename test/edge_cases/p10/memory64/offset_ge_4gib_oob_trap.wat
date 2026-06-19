;; memory64 STATIC memarg offset >= 2^32 (D-209). clang --target=wasm64
;; emits width-padded offset LEBs; lowering artificially capped the offset
;; at u32 (Error.BadMemarg → module wouldn't instantiate), though wasmtime
;; runs it (memory64/offsets.wast assert_trap with offset=0xffff...fff0).
;; The validator already gatekeeps per-memory offset width, so lifting the
;; cap is safe. ea = 0 + 0xffff_ffff_ffff_fff0 is far OOB → traps (the
;; 64-bit base+offset + carry-branch codegen already exists both arches).
(module
  (memory i64 1)
  (func (export "test") (result i32)
    i64.const 0
    i32.load offset=0xfffffffffffffff0))
