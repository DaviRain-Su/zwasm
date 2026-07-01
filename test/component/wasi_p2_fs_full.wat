;; WASI Preview 2 filesystem component exercising the descriptor-completion ops
;; (D3-6): after get-directories + open-at "out.txt" + write "DATA42", it calls
;; descriptor.sync, descriptor.stat (asserts size==6 + type==regular-file),
;; descriptor.get-type (asserts regular-file), descriptor.read (asserts the 6
;; bytes "DATA42" + eof), and output-stream.blocking-flush on stdout. Every
;; result is checked against the expected value; a mismatch traps (unreachable),
;; so a clean run proves all five trampolines returned correct data.
(component
  ;; ---- import wasi:filesystem/types ----
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
    (type $dt-def (enum "unknown" "block-device" "character-device" "directory"
                        "fifo" "symbolic-link" "regular-file" "socket"))
    (export "descriptor-type" (type $descriptor-type (eq $dt-def)))
    (type $datetime-def (record (field "seconds" u64) (field "nanoseconds" u32)))
    (export "datetime" (type $datetime (eq $datetime-def)))
    (type $dstat-def (record (field "type" $descriptor-type) (field "link-count" u64)
                             (field "size" u64) (field "data-access-timestamp" (option $datetime))
                             (field "data-modification-timestamp" (option $datetime))
                             (field "status-change-timestamp" (option $datetime))))
    (export "descriptor-stat" (type $descriptor-stat (eq $dstat-def)))
    (type $borrow-desc (borrow $descriptor))
    (type $own-desc (own $descriptor))
    (type $list-u8 (list u8))
    (type $read-tuple (tuple $list-u8 bool))
    (export "[method]descriptor.open-at"
      (func (param "self" $borrow-desc) (param "path-flags" $path-flags) (param "path" string)
            (param "open-flags" $open-flags) (param "flags" $descriptor-flags)
            (result (result $own-desc (error $error-code)))))
    (export "[method]descriptor.write"
      (func (param "self" $borrow-desc) (param "buffer" $list-u8) (param "offset" u64)
            (result (result u64 (error $error-code)))))
    (export "[method]descriptor.read"
      (func (param "self" $borrow-desc) (param "length" u64) (param "offset" u64)
            (result (result $read-tuple (error $error-code)))))
    (export "[method]descriptor.sync"
      (func (param "self" $borrow-desc) (result (result (error $error-code)))))
    (export "[method]descriptor.stat"
      (func (param "self" $borrow-desc) (result (result $descriptor-stat (error $error-code)))))
    (export "[method]descriptor.get-type"
      (func (param "self" $borrow-desc) (result (result $descriptor-type (error $error-code)))))))
  (alias export $types "descriptor" (type $descriptor))

  ;; ---- import wasi:filesystem/preopens (get-directories) ----
  (import "wasi:filesystem/preopens@0.2.0" (instance $preopens
    (alias outer 1 $descriptor (type $desc-in))
    (export "descriptor" (type $desc-ex (eq $desc-in)))
    (type $own-d (own $desc-ex))
    (type $tup (tuple $own-d string))
    (type $dirlist (list $tup))
    (export "get-directories" (func (result $dirlist)))))

  ;; ---- import wasi:cli/stdout + wasi:io/streams (output-stream flush) ----
  (import "wasi:io/streams@0.2.0" (instance $streams
    (export "output-stream" (type $ostream (sub resource)))
    (type $se-def (variant (case "last-operation-failed") (case "closed")))
    (export "stream-error" (type $stream-error (eq $se-def)))
    (type $borrow-os (borrow $ostream))
    (export "[method]output-stream.blocking-flush"
      (func (param "self" $borrow-os) (result (result (error $stream-error)))))))
  (alias export $streams "output-stream" (type $ostream))
  (import "wasi:cli/stdout@0.2.0" (instance $stdout
    (alias outer 1 $ostream (type $os-in))
    (export "output-stream" (type $os-ex (eq $os-in)))
    (type $own-os (own $os-ex))
    (export "get-stdout" (func (result $own-os)))))

  ;; ---- libc: memory + a bump cabi_realloc ----
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
  (core func $read
    (canon lower (func $types "[method]descriptor.read") (memory $libc "memory") (realloc $cabi_realloc)))
  (core func $sync
    (canon lower (func $types "[method]descriptor.sync") (memory $libc "memory")))
  (core func $stat
    (canon lower (func $types "[method]descriptor.stat") (memory $libc "memory")))
  (core func $gettype
    (canon lower (func $types "[method]descriptor.get-type") (memory $libc "memory")))
  (core func $getstdout
    (canon lower (func $stdout "get-stdout")))
  (core func $flush
    (canon lower (func $streams "[method]output-stream.blocking-flush") (memory $libc "memory")))
  (core func $dropdesc
    (canon resource.drop $descriptor))
  (core func $dropos
    (canon resource.drop $ostream))

  ;; ---- core module that drives the descriptor ops ----
  (core module $M
    (import "fs" "get-directories" (func $getdirs (param i32)))
    (import "fs" "open-at" (func $openat (param i32 i32 i32 i32 i32 i32 i32)))
    (import "fs" "write" (func $write (param i32 i32 i32 i64 i32)))
    (import "fs" "read" (func $read (param i32 i64 i64 i32)))
    (import "fs" "sync" (func $sync (param i32 i32)))
    (import "fs" "stat" (func $stat (param i32 i32)))
    (import "fs" "get-type" (func $gettype (param i32 i32)))
    (import "fs" "drop" (func $dropdesc (param i32)))
    (import "io" "get-stdout" (func $getstdout (result i32)))
    (import "io" "flush" (func $flush (param i32 i32)))
    (import "io" "drop-os" (func $dropos (param i32)))
    (import "libc" "memory" (memory 1))
    (data (i32.const 16) "out.txt")
    (data (i32.const 32) "DATA42")
    (func $check (param $cond i32) (if (local.get $cond) (then (unreachable))))
    (func (export "run") (result i32)
      (local $dir i32) (local $file i32) (local $sh i32) (local $dptr i32)
      (call $getdirs (i32.const 256))
      (local.set $dir (i32.load (i32.load (i32.const 256))))
      ;; open-at(dir, pf=0, path=16, len=7, oflags=CREATE|TRUNCATE=9, dflags=0, ret=288)
      (call $openat (local.get $dir) (i32.const 0) (i32.const 16) (i32.const 7) (i32.const 9) (i32.const 0) (i32.const 288))
      (call $check (i32.load8_u (i32.const 288)))            ;; open-at ok
      (local.set $file (i32.load (i32.const 292)))
      (call $write (local.get $file) (i32.const 32) (i32.const 6) (i64.const 0) (i32.const 320))
      (call $check (i32.load8_u (i32.const 320)))            ;; write ok
      ;; sync(file, ret=352)
      (call $sync (local.get $file) (i32.const 352))
      (call $check (i32.load8_u (i32.const 352)))            ;; sync ok
      ;; stat(file, ret=384): result disc@384; record@392 (type@392, link@400, size@408)
      (call $stat (local.get $file) (i32.const 384))
      (call $check (i32.load8_u (i32.const 384)))            ;; stat ok
      (call $check (i64.ne (i64.load (i32.const 408)) (i64.const 6)))  ;; size==6
      (call $check (i32.ne (i32.load8_u (i32.const 392)) (i32.const 6))) ;; type==regular-file
      ;; get-type(file, ret=360): disc@360, type@361
      (call $gettype (local.get $file) (i32.const 360))
      (call $check (i32.load8_u (i32.const 360)))            ;; get-type ok
      (call $check (i32.ne (i32.load8_u (i32.const 361)) (i32.const 6))) ;; regular-file
      ;; read(file, length=16, offset=0, ret=512): disc@512, list_ptr@516, len@520, eof@524
      (call $read (local.get $file) (i64.const 16) (i64.const 0) (i32.const 512))
      (call $check (i32.load8_u (i32.const 512)))            ;; read ok
      (call $check (i32.ne (i32.load (i32.const 520)) (i32.const 6)))  ;; len==6
      (call $check (i32.eqz (i32.load8_u (i32.const 524))))  ;; eof==true
      (local.set $dptr (i32.load (i32.const 516)))
      (call $check (i32.ne (i32.load8_u (local.get $dptr)) (i32.const 68)))             ;; 'D'
      (call $check (i32.ne (i32.load8_u (i32.add (local.get $dptr) (i32.const 5))) (i32.const 50))) ;; '2'
      ;; stdout flush
      (local.set $sh (call $getstdout))
      (call $flush (local.get $sh) (i32.const 544))
      (call $check (i32.load8_u (i32.const 544)))            ;; flush ok
      (call $dropos (local.get $sh))
      (call $dropdesc (local.get $file))
      (i32.const 0)))

  (core instance $deps (export "get-directories" (func $getdirs))
                       (export "open-at" (func $openat))
                       (export "write" (func $write))
                       (export "read" (func $read))
                       (export "sync" (func $sync))
                       (export "stat" (func $stat))
                       (export "get-type" (func $gettype))
                       (export "drop" (func $dropdesc)))
  (core instance $iodeps (export "get-stdout" (func $getstdout))
                         (export "flush" (func $flush))
                         (export "drop-os" (func $dropos)))
  (core instance $m (instantiate $M
    (with "fs" (instance $deps))
    (with "io" (instance $iodeps))
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
