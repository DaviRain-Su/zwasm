# Contributing to zwasm

Thanks for your interest in zwasm.

## Status: Issues and Pull Requests are paused

zwasm v2 is a small, resource-limited project currently finishing its
from-scratch v2 line. To keep the maintenance load sustainable, we are
**not accepting issues or pull requests at this time.**

If you hit a bug, have a question, or want to propose something:

- Open a thread in **[Discussions](https://github.com/clojurewasm/zwasm/discussions)**
  and mention **@chaploud**.
- For **security** problems, follow [`SECURITY.md`](SECURITY.md) — please do
  **not** post exploit details in public.

We still very much want to hear about real-world breakage; Discussions is the
right channel while PRs are closed.

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
