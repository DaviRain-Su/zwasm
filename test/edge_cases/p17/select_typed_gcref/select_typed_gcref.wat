;; D-492: typed `select t` with a GC abstract reftype (structref, 0x6B).
;; Wasm spec §3.3.2.2 admits any valtype in `select t`; zwasm rejected GC
;; reftypes at the validator (BadValType) + lowerer. wasmtime/spec accept.
;; cond=1 → first operand ($a); ref.cast + struct.get → 7.
(module
  (type $s (struct (field i32)))
  (func (export "test") (result i32)
    (local $a (ref null $s))
    (local.set $a (struct.new $s (i32.const 7)))
    (struct.get $s 0
      (ref.cast (ref $s)
        (select (result structref)
          (local.get $a) (ref.null struct) (i32.const 1))))))
