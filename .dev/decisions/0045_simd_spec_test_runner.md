---
name: SIMD spec test runner — parallel runner + v128-aware text manifest
description: Add a separate simd_assert_runner.zig (parallel to spec_assert_runner) consuming a v128-aware text manifest format, wired as `test-spec-simd` step
status: Accepted
date: 2026-05-10
---

# ADR-0045: SIMD spec test runner

## Status

Accepted (2026-05-10)

## Context

§9.9's exit criterion (per ROADMAP §9 task table): "`simd.wast` spec
test wired in; fail=skip=0 across both backends (3-host gate)."

The upstream WebAssembly testsuite ships a SIMD bundle:

- 57 SIMD-specific `.wast` files at
  `~/Documents/OSS/WebAssembly/testsuite/proposals/simd/`
- ~25,515 total assertions across the bundle
- Heaviest files: `simd_f{32x4,64x2}_pmin_pmax.wast` (3,886 each),
  `simd_f{32x4,64x2}_cmp.wast` (~2,600 each), `simd_f{32x4,64x2}_arith.wast`
  (~1,820 each)
- Lightest: `simd_address.wast` (46), `simd_align.wast` (54),
  `simd_select.wast` (6)

The existing test infrastructure has two related runners:

- **`test/spec/wast_runner.zig`** — parse + validate only; consumes
  text manifests with `valid` / `invalid` / `malformed` directives.
  Does NOT execute (no JIT invocation), so cannot verify SIMD
  semantics.
- **`test/spec/spec_assert_runner.zig`** (~603 LOC, landed §9.7 / 7.5)
  — JIT-execute + runtime `assert_return` comparison; consumes the
  manifest format produced by `scripts/regen_spec_1_0_assert.sh` (via
  `wast2json` + Python distillation). Currently scoped to scalar
  types (i32 / i64 / f32 / f64). Cannot represent v128 values in
  args / results.

Two questions for §9.9-a:

1. **Extend `spec_assert_runner.zig` for v128, or fork into a new
   `simd_assert_runner.zig`?**
2. **What manifest format represents v128 args / results?**

## Decision

**1. Fork into `test/spec/simd_assert_runner.zig`** — a parallel
runner, not an extension of `spec_assert_runner`.

**2. Manifest format**: extend the existing `<type>:<value>` token
shape with `v128:<32 hex digits>` for 128-bit bit-pattern
representation. Example assertion:

```
module simd_address.0.wasm
assert_return load_at_zero () -> i32:0
assert_return store_at_zero v128:00010203040506070809000102030405 -> ()
```

Hex digits encode the in-memory little-endian Wasm v128 layout
**byte-by-byte starting from the lowest-addressed byte (lane 0
of `i8x16`)**. Example: `v128:00010203...0F` decodes to lane 0
= 0x00, lane 1 = 0x01, ..., lane 15 = 0x0F — i.e. lower-byte-
first matching `simd_assert_runner.zig` decoder. This matches
the Wasm SIMD spec §4.4.7 `v128` literal text format
`i8x16(0 1 2 ... 15)` written left-to-right and the in-memory
representation Intel SSE / ARM NEON load instructions produce.

## Alternatives considered

### A. Extend spec_assert_runner.zig in-place

Add a `Value.v128: [16]u8` union arm + extend the manifest parser
to recognise `v128:` tokens. Rejected:

- Couples scalar Wasm 1.0 + SIMD into a single 800+ LOC file,
  growing the §A2 hard-cap pressure on a load-bearing test runner.
- Mixes the §9.7 / 7.5 spec_assert close-out (`212 passed, 0 failed,
  20 skipped`) with the §9.9 SIMD bring-up's expected long debug-
  iterate cycle. Forking gives independent baselines.
- The manifest format split is cleaner: scalar manifests stay
  `<type>:<int_or_float>`; v128 manifests admit hex byte patterns
  without ambiguity.

### B. Binary manifest format (.expect-style packed bytes)

Pre-encode the assertions as a packed binary file (header + per-
assertion record). Rejected:

- Worse debuggability — when an assertion fails, the text manifest
  is grep-able; the binary needs a decoder script.
- Spec-tracing harder — text manifests preserve the original wast
  filename + line for cross-reference back to the Wasm spec.
- No speed advantage — the runner load time is dominated by JIT
  compile cost, not manifest parsing.

### C. Direct `.wast` consumption via embedded wast2json

Link a wast2json equivalent into the runner; consume `.wast` files
at test time. Rejected:

- Adds `wabt` (or its Zig port) as a runtime test dependency; we
  currently only need it at regen time per
  `scripts/regen_spec_1_0_assert.sh`.
- Indirection between test invocation and assertion source.

## Consequences

### Files added at §9.9-a foundation

- `.dev/decisions/0045_simd_spec_test_runner.md` (this ADR).
- `scripts/regen_spec_simd_assert.sh` — manifest generator, `wast2json`-driven; stubs first batch (lightweight files only).
- `test/spec/simd_assert_runner.zig` — runner skeleton; consumes
  the v128 manifest format. Initially empty manifest list
  (foundation chunk reports "0 assertions wired").
- `test/spec/wasm-2.0-simd-assert/` — manifest output directory.
- `build.zig` — `test-spec-simd` step, NOT yet aggregated into
  `test-all` (deferred until 9.9-b lands a non-zero baseline +
  the runner reaches stability).

### Subsequent §9.9 chunks

- **9.9-b**: populate manifest with lightweight files
  (simd_address, simd_align, simd_const, simd_select, splat ops).
  Initial baseline; expect partial fail+skip.
- **9.9-c**: iterate to fail=skip=0 on lightweight files.
  Likely surfaces validator gaps + emit-side bugs.
- **9.9-d**: scale to FP arithmetic + compares (the heavy 9k+
  assertion files); NaN canonicalisation likely surfaces here.
- **9.9-e**: aggregate `test-spec-simd` into `test-all`; flip
  §9.9 row [x].

### Three-host parity

The runner is host-agnostic (consumes the same manifest on Mac
aarch64 / OrbStack Linux x86_64 / windowsmini Win x86_64). Per-
arch divergence (NEON vs SSE) surfaces as different fail/pass
counts on the same fixture — an immediately-visible gate failure
that catches cross-arch bugs at commit time.

## References

- Survey notes: `private/notes/p9-9.9-survey.md` (gitignored).
- Existing runner: `test/spec/spec_assert_runner.zig`
  (template — 603 LOC).
- Manifest generator template:
  `scripts/regen_spec_1_0_assert.sh`.
- Upstream testsuite:
  `~/Documents/OSS/WebAssembly/testsuite/proposals/simd/`.
- Wasm SIMD spec:
  `https://webassembly.github.io/spec/core/syntax/instructions.html#vector-instructions`.

## Revision history

| Date       | Reason                                                    |
|------------|-----------------------------------------------------------|
| 2026-05-10 | Initial — filed at §9.9-a foundation chunk start.        |
| 2026-05-11 | **Byte-order wording clarified** (per 2026-05-11 ADR audit, SUMMARY §3.5 / batch_D). The original "Hex digits in big-endian byte order" phrasing conflicted with `simd_assert_runner.zig`'s decoder doc ("lower-byte-first to match in-memory little-endian Wasm v128 layout"). Both meant lane-0-first / low-byte-first; the runner's wording is canonical because the decoder is the authoritative parser. ADR Decision § rewritten to use the same "lower-byte-first" framing without changing the format. |
