;; WASI Preview 2 filesystem error-path component (D-307). Opens a preopen dir
;; then calls descriptor.open-at on "nope.txt" WITHOUT the create flag, so the
;; host's P1 path_open fails with `noent` → the trampoline must write
;; result.err(error-code::no-entry) rather than trap. The guest asserts the
;; result discriminant is `err` and the error-code ordinal is 20 (no-entry);
;; a mismatch traps (unreachable), so a clean run proves the D-307 mapping.
(component
  (import "wasi:filesystem/types@0.2.0" (instance $types
    (export "descriptor" (type $descriptor (sub resource)))
    ;; error-code declared up to no-entry (ordinal 20) so the fixture can name it.
    (type $err-def (enum "access" "would-block" "already" "bad-descriptor" "busy"
                         "deadlock" "quota" "exist" "file-too-large"
                         "illegal-byte-sequence" "in-progress" "interrupted"
                         "invalid" "io" "is-directory" "loop" "too-many-links"
                         "message-size" "name-too-long" "no-device" "no-entry"))
    (export "error-code" (type $error-code (eq $err-def)))
    (type $of-def (flags "create" "directory" "exclusive" "truncate"))
    (export "open-flags" (type $open-flags (eq $of-def)))
    (type $pf-def (flags "symlink-follow"))
    (export "path-flags" (type $path-flags (eq $pf-def)))
    (type $df-def (flags "read" "write"))
    (export "descriptor-flags" (type $descriptor-flags (eq $df-def)))
    (type $borrow-desc (borrow $descriptor))
    (type $own-desc (own $descriptor))
    (export "[method]descriptor.open-at"
      (func (param "self" $borrow-desc) (param "path-flags" $path-flags) (param "path" string)
            (param "open-flags" $open-flags) (param "flags" $descriptor-flags)
            (result (result $own-desc (error $error-code)))))))
  (alias export $types "descriptor" (type $descriptor))

  (import "wasi:filesystem/preopens@0.2.0" (instance $preopens
    (alias outer 1 $descriptor (type $desc-in))
    (export "descriptor" (type $desc-ex (eq $desc-in)))
    (type $own-d (own $desc-ex))
    (type $tup (tuple $own-d string))
    (type $dirlist (list $tup))
    (export "get-directories" (func (result $dirlist)))))

  (core module $libc
    (memory (export "memory") 1)
    (global $bump (mut i32) (i32.const 1024))
    (func (export "cabi_realloc") (param i32 i32 i32 i32) (result i32)
      (local $p i32)
      (local.set $p (global.get $bump))
      (global.set $bump (i32.add (global.get $bump) (local.get 3)))
      (local.get $p)))
  (core instance $libc (instantiate $libc))
  (alias core export $libc "cabi_realloc" (core func $cabi_realloc))

  (core func $getdirs
    (canon lower (func $preopens "get-directories") (memory $libc "memory") (realloc $cabi_realloc)))
  (core func $openat
    (canon lower (func $types "[method]descriptor.open-at") (memory $libc "memory") (realloc $cabi_realloc)))

  (core module $M
    (import "fs" "get-directories" (func $getdirs (param i32)))
    (import "fs" "open-at" (func $openat (param i32 i32 i32 i32 i32 i32 i32)))
    (import "libc" "memory" (memory 1))
    (data (i32.const 16) "nope.txt")
    (func $check (param $cond i32) (if (local.get $cond) (then (unreachable))))
    (func (export "run") (result i32)
      (local $dir i32)
      (call $getdirs (i32.const 256))
      (local.set $dir (i32.load (i32.load (i32.const 256))))
      ;; open-at(dir, pf=0, path=16 "nope.txt" len=8, open-flags=0 (no create), flags=0, ret=288)
      (call $openat (local.get $dir) (i32.const 0) (i32.const 16) (i32.const 8) (i32.const 0) (i32.const 0) (i32.const 288))
      (call $check (i32.ne (i32.load8_u (i32.const 288)) (i32.const 1)))   ;; result disc == err
      (call $check (i32.ne (i32.load8_u (i32.const 292)) (i32.const 20)))  ;; error-code == no-entry
      (i32.const 0)))

  (core instance $deps (export "get-directories" (func $getdirs))
                       (export "open-at" (func $openat)))
  (core instance $m (instantiate $M
    (with "fs" (instance $deps))
    (with "libc" (instance $libc))))

  (type $run-result (result))
  (func $run (result $run-result) (canon lift (core func $m "run")))
  (component $RunShim
    (import "import-func-run" (func $rf (result (result))))
    (export "run" (func $rf)))
  (instance $run-inst (instantiate $RunShim (with "import-func-run" (func $run))))
  (export "wasi:cli/run@0.2.0" (instance $run-inst))
)
