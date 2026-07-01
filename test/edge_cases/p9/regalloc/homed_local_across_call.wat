;; Boundary (D-265 campaign Phase IV stage 2): a register-HOMED i32 accumulator
;; ($sum) and loop counter ($i) are live across a plain CALL each loop iteration.
;; Stage 1 gated homing OFF for any call-containing function; stage 2 enables it
;; by spilling the caller-saved homed locals around the BL (arm64/op_call.zig).
;; If the spill/reload is wrong, $sum or $i is clobbered by the callee and the
;; result diverges — so this is the executable proof that the homed accumulator
;; survives the call.
;;
;; $double(x) = x*2 (a separate local function, so the loop body BLs it).
;; sum = sum_{i=0..4} double(i) = 2*(0+1+2+3+4) = 20.
(module
  (func $double (param $x i32) (result i32)
    (i32.mul (local.get $x) (i32.const 2)))
  (func (export "test") (result i32)
    (local $i i32) (local $sum i32)
    (local.set $i (i32.const 0))
    (local.set $sum (i32.const 0))
    (block $done
      (loop $loop
        (br_if $done (i32.ge_s (local.get $i) (i32.const 5)))
        ;; sum += double(i) — the homed $sum + $i must survive the call.
        (local.set $sum
          (i32.add (local.get $sum) (call $double (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $loop)))
    (local.get $sum)))
