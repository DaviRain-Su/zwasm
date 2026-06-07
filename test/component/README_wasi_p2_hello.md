# p17 WASI-P2 fixture: wasi_p2_hello (prints "hello\n" to stdout)

Minimal real WASI Preview 2 **component** that writes `"hello\n"` to stdout
via the component-level WASI interfaces, then exports the `wasi:cli/run`
world's `run: func() -> result`. Used to exercise a P2 host that name-maps
these imports onto a preview1 `fd_write`.

THE fixture is the hand-authored WAT component (`wasi_p2_hello.wasm`, 1128 B,
imports exactly 3 `wasi:*` interfaces). A heavier `fmt.Println`-based tinygo
build is documented below as an alternative (it pulls in 11 interfaces).

## Reproduce (THE fixture — hand-authored WAT, minimal)

```sh
wasm-tools parse wasi_p2_hello.wat -o wasi_p2_hello.wasm
wasm-tools validate --features component-model wasi_p2_hello.wasm
wasmtime run wasi_p2_hello.wasm        # prints: hello
```

## Files

- `wasi_p2_hello.wat`  — hand-authored component (imports stdout+streams+error,
  canon-lowers them, exports `wasi:cli/run`)
- `wasi_p2_hello.wasm` — THE fixture (1128 B)
- `wasi_p2_hello.go`   — 5-line Go used for the tinygo alternative below

## Import structure (`wasm-tools print` / `wasm-tools component wit`)

WIT world:

```wit
world root {
  import wasi:io/error@0.2.0;     // resource error
  import wasi:io/streams@0.2.0;   // output-stream + blocking-write-and-flush + (drop)
  import wasi:cli/stdout@0.2.0;   // get-stdout
  export wasi:cli/run@0.2.0;      // run: func() -> result
}
```

Component-level imported funcs (canonical names):

- `wasi:cli/stdout` — `get-stdout: func() -> own<output-stream>`
- `wasi:io/streams` — `[method]output-stream.blocking-write-and-flush:
  func(self: borrow<output-stream>, contents: list<u8>) -> result<_, stream-error>`
- `[resource-drop]output-stream` is synthesized via `(canon resource.drop output-stream)`
  (no explicit interface import needed for the drop intrinsic).

Inner core module (`$M`) imports — what the canon-lowering produces:

```wat
(import "io" "get-stdout" (func (result i32)))               ;; -> stream handle
(import "io" "write"      (func (param i32 i32 i32 i32)))    ;; self, ptr, len, retptr
(import "io" "drop-os"    (func (param i32)))                ;; resource.drop
(import "libc" "memory"   (memory 1))                        ;; canon ABI lift/lower memory
```

The core `run` returns `i32` (the `result<_>` discriminant; 0 = ok), lifted to
the component `run: func() -> result`.

## Behaviour

`run()` calls `get-stdout`, writes the 6 bytes `"hello\n"` (data segment at
offset 16) via `blocking-write-and-flush` (retptr=128), drops the stream, and
returns ok. `wasmtime run` prints `hello` and exits 0.

## Authoring note (wasm-tools gotcha)

A named type used in an **instance-type func signature** must be referenced
through its EXPORTED binding, not the original definition — otherwise
`wasm-tools validate` rejects it with *"instance not valid to be used as
import."* I.e. write `(export "stream-error" (type $se (eq $se-def)))` then
reference `$se` in the func result, not `$se-def`.

## Alternative: tinygo wasip2 (heavier, 11 interfaces)

`wasi_p2_hello.go` built with tinygo's `wasip2` target emits a real component
that prints via `fmt.Println` — but `fmt` drags in environment / clocks /
filesystem / random / stdin / stderr (11 distinct `wasi:*` interfaces, ~730 KB).
Kept only as a reference; NOT the committed fixture.

```sh
# inside: nix develop .#gen --command bash -c '...'
tinygo build -target=wasip2 -o wasi_p2_hello_tinygo.wasm wasi_p2_hello.go
# tinygo 0.40.1 (go 1.25.9, LLVM 20.1.8); wasmtime run prints "hello"
```
