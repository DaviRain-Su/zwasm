# ADR-0143 — §13.3 C-API WASI inherit_argv/inherit_env/preopen_dir deferred (one Init-token root cause)

> **Status**: Accepted (2026-06-04). Autonomous per ADR-0132 carve-out
> (re-scoping because a phase's exit references genuinely-blocked work).

## Context

ROADMAP §13.3 = "wasi.h + zwasm.h ABI surface complete." `include/wasi.h` (a
hand-authored, zwasm-specific extension header, ADR-0005 — NOT upstream wasm-c-api)
declared **three** host-config builders with **no definition** in `src/api/wasi.zig`:

- `zwasm_wasi_config_inherit_argv` (void)
- `zwasm_wasi_config_inherit_env` (void)
- `zwasm_wasi_config_preopen_dir` (bool)

A C/Rust host that *called* any of them would fail to link (undefined symbol). The
§13.4 conformance suite + c_host/rust_host link only because none of them reference
these three (verified: grep of `test/ examples/ src/` finds zero consumers — only the
header's own declarations + doc example).

The implemented, shipping surface is `new`/`delete`, `set_args`, `set_envs`,
`inherit_stdio` (`47298cd1`), + `set_wasi`.

## Root cause (one constraint, all three)

All three need a **process/io capability token** that a C-library context does not
have. Zig 0.16's capability-I/O model hands argv/env/io to a Zig binary's `main` via
`std.process.Init` (`src/cli/main.zig:43-44` — `io = init.io`, `args = init.minimal.args`,
`environ_map`). The C-ABI exports (`wasm_engine_new`, `zwasm_wasi_config_*`) receive **no
`Init`** and the C-API engine constructs **no io** of its own:

- **inherit_argv** — no Zig-0.16 stdlib path to the process argv from a library context
  at all (only fragile per-platform C interop: `_NSGetArgv` / `/proc/self/cmdline` /
  `GetCommandLineW`). This is the hard block.
- **inherit_env** — technically reachable via `std.c.environ` (consistent with the
  B132 precedent that made `std.c.getenv` Necessary for `wasm_engine_new`, ADR-0070
  line 62), BUT iterating *all* env adds a **new cross-platform `std.c.environ`
  Necessary site** (Windows `_environ`/CRT differs) — a §14 "unconscious libc fanout"
  cost for convenience-only value over the existing explicit `set_envs`.
- **preopen_dir** — the CLI opens preopen dirs via `std.Io.Dir.cwd().openDir(io, …)`
  (`src/cli/run.zig:155`), which **needs an `io`**; `cfg.io = io` is wired from the
  CLI's ambient Init io. The io-free alternative (raw `std.posix.open`) has dubious
  Windows directory semantics for the 3-host gate. Worse, even a successfully-opened
  preopen is **unusable at runtime** without `cfg.io` set for `path_open`/`fd_read` —
  which again needs a library-side io the C-API does not yet construct.

So §13.3's remainder is not three independent gaps; it is one missing piece —
**a library-constructed io + a vetted cross-platform process-context helper** — that
the C-API does not yet have.

## Decision

1. **Defer all three** (`inherit_argv`, `inherit_env`, `preopen_dir`) to post-v0.1.
   **Remove their declarations** from `include/wasi.h` (+ the doc example's
   `inherit_argv`/`inherit_env` lines). Rationale for removal over stubbing: the two
   `void` builders cannot be honestly no-op'd (a silent no-op = "argv NOT inherited"
   is the forbidden silent-fallback pattern, `no_workaround.md`); an always-`false`
   `preopen_dir` is a degenerate always-fail stub. An undeclared symbol is honest; a
   declared-but-undefined / lying one is not.

2. **Re-scope §13.3 exit** to the io-free explicit-config surface actually
   implemented: `new`/`delete` + `set_args` + `set_envs` + `inherit_stdio` +
   `set_wasi`. Mark §13.3 `[x]`.

3. **Discharge path** (debt **D-255**): when the C-API gains a library-side io
   (a `std.Io.Threaded`/blocking io constructed by the engine or `set_wasi`, wired to
   `Host.io`) — co-located with **D-251** (WASI/host imports under the C-API) and the
   Phase-14+ AOT push (which needs cross-platform argv/env anyway) — re-add the three
   builders together: `preopen_dir` + `inherit_env` first (io + `environ`), then
   `inherit_argv` once a cross-platform process-context helper exists.

## Consequences

- The C-API v0.1 surface is **honest**: no declared-but-undefined symbols; the conformance
  suite + examples are unaffected (zero consumers removed).
- C-API embedders get explicit argv/env config + stdio inheritance in v0.1; **filesystem
  hosting + process inheritance via the pure C-API wait** for the io infra (D-255/D-251).
  The CLI's `--dir` (which has ambient io) is the v0.1 path for file hosting.
- No ROADMAP §1/§2/§4/§5/§11/§14 change; §9-scope re-scope only (ADR-0132). The §13.P
  close records D-255 as an open Phase-13 carry.
