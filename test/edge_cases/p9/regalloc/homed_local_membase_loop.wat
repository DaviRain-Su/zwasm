;; Boundary (D-265 campaign Phase IV stage 1): reproduces the clang -O0
;; arr_sum/fp_sum miscompile shape that the 3 loop-carried fixtures miss.
;; A register-HOMED i32 local ($base) is used as a memory base address, read
;; repeatedly inside a loop whose condition is the clang -O0 multi-step form
;;   local.get; i32.load; i32.const; i32.lt_s; i32.const; i32.and; i32.eqz; br_if
;; The body re-reads $base every iteration to index memory + accumulate into a
;; second homed local ($sum). This exercises the liveness<->emit operand-stack
;; numbering across the and/eqz/br_if chain with a homed local live throughout.
;;
;; Memory at offset 0: [5,2,8,1,9,3,7,4] (i32 LE). sum = 39 (matches arr_sum).
(module
  (memory 1)
  (data (i32.const 0) "\05\00\00\00\02\00\00\00\08\00\00\00\01\00\00\00\09\00\00\00\03\00\00\00\07\00\00\00\04\00\00\00")
  (func (export "test") (result i32)
    (local $base i32) (local $i i32) (local $sum i32)
    (local.set $base (i32.const 0))
    (local.set $i (i32.const 0))
    (local.set $sum (i32.const 0))
    (block $done
      (loop $loop
        ;; clang -O0 loop condition: (i < 8) as load/lt_s/and/eqz/br_if-out.
        (br_if $done
          (i32.eqz
            (i32.and
              (i32.lt_s (local.get $i) (i32.const 8))
              (i32.const 1))))
        ;; sum += mem[base + i*4]
        (local.set $sum
          (i32.add
            (local.get $sum)
            (i32.load (i32.add (local.get $base) (i32.shl (local.get $i) (i32.const 2))))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $loop)))
    (local.get $sum)))
