# Zig 0.16.0 Migration Work Log

Target release: **v1.10.0** (minor bump — downstream is source-compatible but
toolchain is a hard breaking change).

Zig 0.16.0 was released 2026-04-13 ("Juicy Main"). Headline: 244 contributors,
1183 commits, **I/O as an Interface** — the biggest stdlib refactor since
async-IO was reverted.

## References

- 0.16.0 release notes: https://ziglang.org/download/0.16.0/release-notes.html
- Tarball-bundled stdlib (authoritative API reference):
  `/opt/homebrew/Cellar/zig/0.16.0_1/lib/zig/std/` (Mac) —
  use for `grep`/`Read` when checking current signatures.
- Pre-migration source mirror: `~/Documents/OSS/zig/` — GitHub mirror, history
  up to the codeberg migration (2026-04). Good for older-version blame.
- Reference PR: [#41](https://github.com/clojurewasm/zwasm/pull/41) by
  @notxorand — **grep-target only** (API translations are mostly wrong).

## Key breaking changes

### `std.fs` deprecated → `std.Io.Dir`

The entire `std.fs` module is now a deprecation shim. `std.fs.cwd()` etc.
delegate to `std.Io.Dir`, and methods take an `io: Io` as first positional
argument:

```zig
// 0.15.2
const file = try std.fs.cwd().openFile(path, .{});

// 0.16.0
const file = try std.Io.Dir.cwd().openFile(io, path, .{});
```

The `io` is an instance of the `Io` interface (vtable). Implementations:

| Impl | Purpose |
|---|---|
| `std.Io.Threaded` | Blocking stdlib, OS-thread based |
| `std.Io.Uring` | Linux io_uring |
| `std.Io.Kqueue` | macOS/BSD kqueue |

**Design decision needed**: How does zwasm acquire / thread `io`?

- **Option A (minimum-effort)**: Construct `std.Io.Threaded.init(allocator)` once
  in `cli.zig` main, thread it down through `WasmModule` API signatures.
- **Option B (library-honest)**: `WasmModule.Config` gains an `io: ?Io = null`
  field; if null, zwasm constructs its own `Threaded` impl internally.
- **Option C (WASI-local)**: Keep `io` internal to `wasi.zig` (the only
  heavy `std.fs` user). Don't propagate through public API. Fewest callers
  break downstream.

Option **C** looks best — 33/40 `std.fs` hits are in `wasi.zig`; the rest
are leaf CLI / example code that can construct `io` locally. ClojureWasm
and other embedders stay source-compatible. Promote to D135 when the
direction is confirmed.

### `std.Io.Writer` — already adopted (no work)

This repo is already on the new-style `std.Io.Writer` (14 occurrences across
`cli.zig`, `trace.zig`). The 0.15.x preview of `std.Io` is the same shape as
the 0.16.0 final, so no code changes needed for writer plumbing.

### `std.os.windows` / `std.os.linux`

Still exist in 0.16.0, but some symbols have moved. Need per-call verification
in `platform.zig`, `guard.zig`, `wasi.zig`.

### `std.posix` — likely stable

`std.posix.munmap`, `getenv`, `PROT`, `timespec`, `futimens` are all still
there. Spot-check during migration but expect zero or near-zero churn.

### `std.mem.splitScalar` — already modern

3 hits, all using the post-0.14 `splitScalar` API. No action.

## Impact footprint

Generated 2026-04-24 via
`grep -rn "std\.<mod>\." src/ bench/ examples/ test/ build.zig`.

| API prefix | Hits | Notes |
|---|---|---|
| `std.fs.` | 78 | **Biggest surface** — 33 in `wasi.zig`, 6 in `test/e2e/e2e_runner.zig`, 5 in `trace.zig` |
| `std.Io.` | 14 | Already 0.16-style (`Io.Writer` type in function signatures) |
| `std.os.` | 8 | `std.os.windows` (3 files), `std.os.linux` (2 sites) |
| `std.posix.` | 8 | `munmap`, `getenv`, `PROT`, `timespec`, `futimens` |
| `std.process.` | 21 | Mostly `std.process.exit` / `argsAlloc`. Likely stable. |
| `std.mem.split*` | 3 | All already `splitScalar`. |
| `std.io.get*` | 0 | Already migrated to `std.Io.Writer`. |
| `std.debug.print` | 1 | Stable. |

### Per-file `std.fs.` hotspot

```
33  src/wasi.zig        ← primary
 6  test/e2e/e2e_runner.zig
 5  src/trace.zig
 4  src/cli.zig
 3  src/vm.zig
 3  src/cache.zig
 3  src/c_api.zig
 3  examples/zig/host_functions.zig
 2  src/types.zig
 2  src/platform.zig
 2  src/module.zig
 2  examples/zig/memory.zig
 2  examples/zig/inspect.zig
 2  examples/zig/basic.zig
 2  bench/fib_bench.zig
 …
```

## Migration phases

### Phase 1: Toolchain bump

- [ ] `flake.nix`: 0.15.2 URLs/sha256 → 0.16.0 (4 arch triples)
- [ ] `flake.lock`: regenerate
- [ ] `.github/workflows/ci.yml`: `version: 0.15.2` → `0.16.0`
- [ ] `CLAUDE.md`: "Zig 0.15.2" → "Zig 0.16.0" (1 occurrence)
- [ ] `README.md`: "Requires Zig 0.15.2." → 0.16.0 (line 208)
- [ ] `book/en/src/{getting-started,contributing}.md`: Zig version strings
- [ ] `book/ja/src/{getting-started,contributing}.md`: Zig version strings
- [ ] `docs/audit-36.md`: references to 0.15.2 (2 lines) — keep for historical
      context, mark as "0.15.2 era"
- [ ] `.claude/references/zig-tips.md`: retitle to 0.16.0, keep 0.15.2 pitfalls
      section, add 0.16-specific gotchas
- [ ] `build.zig`: fix any API drift (lazyPath, addModule, etc.)

At end of Phase 1, `zig build` should reach compile errors. No code logic
changes yet.

### Phase 2: Source migration (leaf-first)

Order (each commit = one file, TDD discipline):

1. `src/leb128.zig` — no stdlib deps beyond core, likely zero change
2. `src/platform.zig` — munmap / getenv / PROT
3. `src/guard.zig` — mprotect wrapper
4. `src/types.zig`, `src/module.zig`, `src/predecode.zig`, `src/regalloc.zig`
5. `src/vm.zig` — bulk interpreter, minor `std.fs` (3 hits)
6. `src/jit/**` — if any stdlib drift
7. `src/trace.zig` — 5 `std.fs.` hits (objdump invocation)
8. `src/cache.zig` — file cache
9. **`src/wasi.zig`** — the 33-hit mountain; requires `io` threading decision
10. `src/cli.zig` — top-level, constructs `io`
11. `src/c_api.zig` — C-visible entry points
12. `examples/zig/**` — showcase code, reflect new API
13. `bench/fib_bench.zig`, `test/e2e/e2e_runner.zig` — ancillary
14. `src/fuzz_loader.zig`, `src/fuzz_wat_loader.zig` — stdin wrapper harnesses

### Phase 3: Full gates green

- Mac: unit / spec / e2e / realworld / FFI / minimal build / size
- Ubuntu x86_64 (OrbStack): same set
- Bench: record `0.16.0` baseline; investigate any >10% regression

### Phase 4: Docs + AI-materials sweep

- [ ] `docs/embedding.md`, `docs/usage.md`, `docs/errors.md`,
      `docs/api-boundary.md` — update all code examples to 0.16 API
- [ ] `book/en/src/**` and `book/ja/src/**` — scan every chapter with code
      samples; the `c-api` chapters are probably unchanged, the
      `embedding-guide` ones will need the most work
- [ ] `.claude/references/zig-tips.md` — add "0.16 migration pitfalls" section
      from this doc's findings (`Io.Dir` signature, deprecated `std.fs`, etc.)
- [ ] `.claude/rules/**` — audit for any 0.15-specific advice
- [ ] `.dev/decisions.md` — **D135**: `io` threading strategy (Option C
      locality); **D136**: toolchain bump cadence going forward
- [ ] `CHANGELOG.md` — `[1.10.0] - 2026-MM-DD` section with Breaking/Changed/
      Added/Fixed
- [ ] `.dev/checklist.md` — close / reframe any Zig-version-gated items

### Phase 5: Release

- PR `develop/zig-0.16.0 → main`, close #41 with thanks
- `Release v1.10.0` commit + tag
- `bench: record v1.10.0 baseline`
- CW `develop/bump-zwasm-v1.10.0` — may also need a `flake.nix` bump since
  CW inherits the Zig toolchain through `zig fetch`

## Open questions

1. **`io` threading design** (D135 pending) — Option C locality vs Option B
   Config-injected. Need to sketch a 20-line API diff for each before
   committing.
2. **Threaded vs Uring/Kqueue** — should WASI use `Threaded` (portable) or
   detect `Uring` on Linux and `Kqueue` on macOS for better `fd_read`/
   `fd_write` perf? Defer to post-migration — get correctness first.
3. **Examples dual-write**: examples are linked in the book. Decide whether
   to show only the 0.16 API or include a deprecation-era note for readers
   on older zig. Prefer 0.16-only, and gate on the tarball version.
4. **0.16.0 lib/std source**: tarball ships with `.zig` sources so `zig fmt`
   and tools work, but git history is not included. For stdlib archaeology
   (e.g., "why did `openFile` change?"), we'd need codeberg clone or GitHub
   mirror — the GitHub mirror's history stops around the codeberg migration,
   so upstream development after 2026-04 needs codeberg access.

## Log

- 2026-04-24 — Doc created. Impact grep run. brew zig 0.16.0 installed.
  GitHub mirror cloned to `~/Documents/OSS/zig` (development migrated to
  codeberg — consider adding codeberg remote if archaeological need arises).
