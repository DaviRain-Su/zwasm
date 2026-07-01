# 0162 — Toolchain-on-test-host carve-out: native rust for §13.5 3-OS rust_host

- **Status**: Accepted (2026-06-05; user-directed — chat 2026-06-05 "Ubuntu や
  Windows にツールチェーンがないなら今インストールしてしまっていい").
- **Date**: 2026-06-05
- **Author**: claude (user directive)
- **Tags**: toolchain, test-host, rust, §13.5, D-254, D-028, provisioning,
  toolchain-free-invariant
- **Amends**: the "test hosts are toolchain-free artifact-runners" invariant
  (`.dev/toolchain_provisioning.md`); resolves D-254 via path (a) not (b).

## Context

`.dev/toolchain_provisioning.md` holds a **toolchain-free invariant**: realworld
`.wasm` fixtures are GENERATED on the Mac host (`nix develop .#gen`); the committed
artifacts RUN on the ubuntunote / windowsmini test hosts via the Zig-built
edge-runner with NO compiler toolchain there. Rationale: keep the test hosts lean
artifact-runners (compounds with D-028 — Microsoft Defender scans `.zig-cache`/
`zig-out` on Windows; more toolchains = more scan surface + maintenance).

Consequence: D-254 — the §13.5 `rust_host` embedder example (`examples/rust_host/
hello.rs`, a Rust program linking `libzwasm.a` over the C ABI) BUILDS only on Mac,
so the "3-OS rust run" exit could not be met. The prior plan was resolution (b):
re-phrase the exit to "Mac rust_host + 2-host c_host C-ABI conformance".

The user (2026-06-05) chose resolution **(a)**: provision native rust on the test
hosts now, so the 3-OS rust run is met literally.

## Decision

A **narrow carve-out**, not a wholesale invariant repeal:

- **Native rust IS now allowed on the test hosts — for the `rust_host` build/run
  step ONLY.** The gen toolchains (emcc / tinygo / go / clang+lld) stay Mac-only;
  the `test-all` gate shell (`devShells.default`) stays toolchain-free.
- **ubuntunote**: native rustc via a dedicated **`devShells.rust-host`** (zig +
  `rustNative`, ADR-pin'd; flake commit `a5cf80fb`). The `run-rust-host` step runs
  under `nix develop .#rust-host` — pinned + reproducible, off the `default` shell.
- **windowsmini**: native rust via **winget** (`Rustlang.Rustup` → rustc 1.96.0,
  installed 2026-06-05; no nix on Windows). `run-rust-host` runs `zig build` +
  rustc on the native PATH. **Open**: rustup default is MSVC-host — linking
  `libzwasm.a` may need MSVC `link.exe` OR a switch to the GNU toolchain
  (`stable-x86_64-pc-windows-gnu`); resolved empirically at the `build.zig`
  `run-rust-host` cross-host wiring (A1-wire).

## Consequences

- D-254 discharges via (a): §13.5 exit stays "3-OS rust run". `build.zig`
  `run-rust-host` becomes 3-host (was Mac-only) + a `run_remote_*` path.
- `.dev/toolchain_provisioning.md` updated: the invariant now reads "test hosts
  carry NO *generation* toolchain; native rust is the sole carve-out (rust_host)".
- D-028 surface grows slightly on windowsmini (rust in `~/.cargo`); accepted as
  the cost of the user-chosen 3-OS completeness.
- Reversible: removing the `rust-host` shell + uninstalling winget rust restores
  the strict invariant; this ADR is the record of why the carve-out exists.

## References

- `.dev/toolchain_provisioning.md` (the invariant); `flake.nix` `devShells.rust-host`
  (`a5cf80fb`); `examples/rust_host/hello.rs`; `build.zig` `run-rust-host`; D-254;
  D-028 (Defender scan); ROADMAP §13.5 / §13.P.
