;; WASI Preview 2 filesystem component (the CM-D2-fs bundle exit). Obtains a
;; preopened directory descriptor via wasi:filesystem/preopens.get-directories,
;; opens/creates "out.txt" under it (descriptor.open-at), writes "DATA42"
;; (descriptor.write), and drops both descriptors. Exercises the descriptor
;; RESOURCE + the realloc-from-trampoline list return area end-to-end.
(component
  ;; ---- import wasi:filesystem/types (descriptor resource + open-at/write) ----
  (import "wasi:filesystem/types@0.2.0" (instance $types
    (export "descriptor" (type $descriptor (sub resource)))
    (type $err-def (enum "access" "would-block"))
    (export "error-code" (type $error-code (eq $err-def)))
    (type $of-def (flags "create" "directory" "exclusive" "truncate"))
    (export "open-flags" (type $open-flags (eq $of-def)))
    (type $pf-def (flags "symlink-follow"))
    (export "path-flags" (type $path-flags (eq $pf-def)))
    (type $df-def (flags "read" "write"))
    (export "descriptor-flags" (type $descriptor-flags (eq $df-def)))
    (type $borrow-desc (borrow $descriptor))
    (type $own-desc (own $descriptor))
    (type $list-u8 (list u8))
    (export "[method]descriptor.open-at"
      (func (param "self" $borrow-desc) (param "path-flags" $path-flags) (param "path" string)
            (param "open-flags" $open-flags) (param "flags" $descriptor-flags)
            (result (result $own-desc (error $error-code)))))
    (export "[method]descriptor.write"
      (func (param "self" $borrow-desc) (param "buffer" $list-u8) (param "offset" u64)
            (result (result u64 (error $error-code)))))))
  (alias export $types "descriptor" (type $descriptor))

  ;; ---- import wasi:filesystem/preopens (get-directories) ----
  (import "wasi:filesystem/preopens@0.2.0" (instance $preopens
    (alias outer 1 $descriptor (type $desc-in))
    (export "descriptor" (type $desc-ex (eq $desc-in)))
    (type $own-d (own $desc-ex))
    (type $tup (tuple $own-d string))
    (type $dirlist (list $tup))
    (export "get-directories" (func (result $dirlist)))))

  ;; ---- libc: memory + a bump cabi_realloc (host allocates the list area here) ----
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

  ;; ---- lower the imported component funcs to core funcs ----
  (core func $getdirs
    (canon lower (func $preopens "get-directories") (memory $libc "memory") (realloc $cabi_realloc)))
  (core func $openat
    (canon lower (func $types "[method]descriptor.open-at") (memory $libc "memory") (realloc $cabi_realloc)))
  (core func $write
    (canon lower (func $types "[method]descriptor.write") (memory $libc "memory")))
  (core func $dropdesc
    (canon resource.drop $descriptor))

  ;; ---- core module that does the file write ----
  (core module $M
    (import "fs" "get-directories" (func $getdirs (param i32)))
    (import "fs" "open-at" (func $openat (param i32 i32 i32 i32 i32 i32 i32)))
    (import "fs" "write" (func $write (param i32 i32 i32 i64 i32)))
    (import "fs" "drop" (func $dropdesc (param i32)))
    (import "libc" "memory" (memory 1))
    (data (i32.const 16) "out.txt")
    (data (i32.const 32) "DATA42")
    (func (export "run") (result i32)
      (local $dir i32) (local $file i32)
      (call $getdirs (i32.const 256))                  ;; → [list_ptr@256, list_len@260]
      (local.set $dir (i32.load (i32.load (i32.const 256)))) ;; tuple[0].descriptor
      ;; open-at(dir, path-flags=0, path=16, len=7, open-flags=CREAT|TRUNC=9, flags=0, retptr=288)
      (call $openat (local.get $dir) (i32.const 0) (i32.const 16) (i32.const 7) (i32.const 9) (i32.const 0) (i32.const 288))
      (local.set $file (i32.load (i32.const 292)))      ;; result payload (own<descriptor>) @ retptr+4
      (call $write (local.get $file) (i32.const 32) (i32.const 6) (i64.const 0) (i32.const 320))
      (call $dropdesc (local.get $file)) ;; drop the opened file; the dir is the host-owned preopen
      (i32.const 0)))

  (core instance $deps (export "get-directories" (func $getdirs))
                       (export "open-at" (func $openat))
                       (export "write" (func $write))
                       (export "drop" (func $dropdesc)))
  (core instance $m (instantiate $M
    (with "fs" (instance $deps))
    (with "libc" (instance $libc))))

  ;; ---- lift run to wasi:cli/run ----
  (type $run-result (result))
  (func $run (result $run-result) (canon lift (core func $m "run")))
  (component $RunShim
    (import "import-func-run" (func $rf (result (result))))
    (export "run" (func $rf)))
  (instance $run-inst (instantiate $RunShim (with "import-func-run" (func $run))))
  (export "wasi:cli/run@0.2.0" (instance $run-inst))
)
