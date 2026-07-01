# Contributing to zwasm

Thanks for your interest in zwasm.

## How to contribute

zwasm v2 has reached its first release candidate and welcomes contributions.
This is a small, resource-limited project, so please keep the following in mind
to make review sustainable:

- **Bugs / feature requests** — open an
  [Issue](https://github.com/clojurewasm/zwasm/issues/new/choose) using the
  templates. A minimal `.wasm` / `.wat` reproducer helps enormously.
- **Questions & ideas** — start a thread in
  [Discussions](https://github.com/clojurewasm/zwasm/discussions).
- **Pull requests** — welcome. For anything non-trivial, please open an issue
  or discussion first so we can agree on the approach before you invest time.
  Keep PRs focused; make sure `zig build test-all` and `zig fmt src/` are clean.
- **Security** — do **not** post exploit details publicly; follow
  [`SECURITY.md`](SECURITY.md) (private vulnerability reporting).

Response times may vary since this is maintained in spare time — thanks for
your patience.

## Building and testing (for trying it locally / forking)

zwasm targets **Zig 0.16.0** (pinned). With Zig on your `PATH`:

```sh
zig build              # compile the zwasm CLI + library
zig build test         # unit tests
zig build test-all     # all enabled test layers
zig fmt src/           # format
```

The differential and spec suites additionally use
[`wasmtime`](https://wasmtime.dev/) as a reference oracle when it is present;
without it those comparisons are skipped, not failed. The committed test
corpus (spec suite + real-world `.wasm` fixtures) runs with **no extra
toolchain** — only Zig (and optionally wasmtime). Regenerating the fixtures
from source needs the Nix `gen` shell and is a maintainer task.

A reproducible dev shell is provided via [`flake.nix`](flake.nix)
(`nix develop`), pinned to the same Zig version.

See [`docs/tutorial.md`](docs/tutorial.md) to build, run, and embed zwasm.

## License

By contributing you agree that your contributions are licensed under the
project's license, **Apache-2.0** (see [`LICENSE`](LICENSE)). Note that v2 is
Apache-2.0; the frozen v1 line was MIT.
