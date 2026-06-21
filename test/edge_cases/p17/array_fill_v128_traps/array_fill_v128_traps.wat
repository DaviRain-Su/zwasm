;; D-495: array.fill with a v128 value — the JIT fill helper receives the value
;; as a u64 (8 bytes); a 16-byte v128 can't be reconstructed → it must TRAP
;; cleanly, NOT panic the host (guest-triggerable host panic before the guard).
;; Interim = clean trap; proper v128-fill impl (pointer-marshal the value) is D-495.
;; When that lands, this fixture returns 7 instead of trapping.
(module (type $a (array (mut v128)))
  (func (export "test") (result i32)
    (local $arr (ref $a))
    (local.set $arr (array.new_default $a (i32.const 3)))
    (array.fill $a (local.get $arr) (i32.const 0) (v128.const i32x4 5 6 7 8) (i32.const 3))
    (i32x4.extract_lane 2 (array.get $a (local.get $arr) (i32.const 1)))))
