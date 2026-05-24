# 0057 — spec_assert_runner factoring: base + specialisations

- **Status**: Closed (implemented)
- **Date**: 2026-05-12
- **Author**: zwasm v2 maintainer (autonomous `/continue` loop, Phase 9 close, §9.9 / 9.9-l-1)
- **Tags**: phase-9, testing, spec-runner, refactor

## Context

§9.9 (Wasm 2.0 100% PASS on Mac+OrbStack per ADR-0056) requires
runtime-asserting the non-SIMD Wasm 2.0 spec corpus, not just
parse+validate. The current state:

- `test/spec/wast_runner.zig` (332 LOC) — parse + validate only.
  Walks 1158 modules in `test/spec/wasm-2.0/`; succeeds when each
  module parses and validates. **Does not invoke the JIT or
  compare expected results**.
- `test/spec/spec_assert_runner.zig` — Wasm 1.0 scalar runtime
  assert runner (i32/i64/f32/f64). Predates SIMD work.
- `test/spec/simd_assert_runner.zig` (1071 LOC) — Wasm 2.0 SIMD
  runtime assert runner. Walks 13301-fixture manifest with full
  runtime invocation + result compare. Mac aarch64 + OrbStack
  x86_64 bit-identical 13301/0/440 (skip-impl + skip-adr).

Agent X's audit (`private/p9-x-wasm2-non-simd-coverage.md`)
identifies a **"fake green" gap**: `wast_runner.zig` reports
green on the Wasm 2.0 corpus but only at the parse+validate
layer. Many Wasm 2.0 features (sign-ext, sat-trunc, multi-value,
ref types, table ops, bulk memory) require runtime-asserting
to detect miscompiles. The SIMD runner exercises that for v128
ops; non-SIMD runtime assertions need an analogous runner.

## Decision

Adopt **Option B (factor base + specialisations)** per Agent X's
recommendation. Concretely:

1. Extract a new `test/spec/spec_assert_runner_base.zig` (~550-650
   LOC) containing:
   - Manifest line parser with directive dispatch (`module`,
     `assert_return`, `assert_trap`, `assert_invalid`,
     `assert_malformed`, `skip-impl/skip-adr` prefix routing).
   - ADR-0029 skip-impl vs skip-adr tally semantics.
   - Scalar token parsers (`parseI32Token()`, `parseI64Token()`).
   - JitRuntime constructor helper (`makeJitRuntime()`).
   - Module-init delegation (`applyActiveDataSegments()`,
     `applyDefinedGlobalsInit()`, `applyTableInit()`).
   - Scratch buffers (`scratch_memory[65536]`, `scratch_globals[256]`,
     `scratch_funcptrs[]`, `scratch_typeidxs[]`).
   - Tally struct (`AssertTally`) + outcome enums (`AssertOutcome`,
     `TrapOutcome`).

2. The base exposes a `RunnerCallbacks` trait (function-pointer
   struct):

   ```zig
   pub const RunnerCallbacks = struct {
       parse_arg_token: *const fn ([]const u8) anyerror!ArgValueScalar,
       handle_assert_return: *const fn (ctx: *AssertCtx, line: []const u8) anyerror!AssertOutcome,
       handle_assert_trap: *const fn (ctx: *AssertCtx, line: []const u8) anyerror!AssertOutcome,
   };
   ```

   Specialisations (SIMD + non-SIMD) implement the trait and pass
   it into `base.runCorpus(io, gpa, dir, &tally, stdout,
   callbacks)`.

3. Refactor existing `simd_assert_runner.zig` (1071 LOC) to use
   the base. Post-refactor target: ~450-550 LOC containing only
   SIMD-specific surface:
   - v128 token parsers (`parseV128Token()`, `parseV128LanesToken()`).
   - Per-lane NaN matchers (`matchLaneF32()`, `matchLaneF64()`).
   - `invokeV128()` (40+ v128-shape entry helpers).
   - v128-specific `runAssertTrap` outcome dispatch.
   - SIMD callbacks struct + `main()` calling base.runCorpus.

4. Create new `test/spec/spec_assert_runner_non_simd.zig` (~450-500
   LOC) in chunk **l-1b** (split from l-1a). Same shape as SIMD
   runner but scalar-only:
   - Scalar invoke dispatch (i32/i64/f32/f64).
   - Scalar `runAssertTrap` outcome dispatch.
   - Non-SIMD callbacks struct + `main()` calling base.runCorpus.

5. New `test-spec-wasm-2.0-assert` build step (in l-1b) runs the
   non-SIMD runner against a curated `test/spec/wasm-2.0-assert/`
   corpus (subset of wasm-2.0 with runtime-assertable feature
   coverage per Agent X §6).

## Alternatives considered

### Option A — Extend `wast_runner.zig` in-place

Add runtime-assert execution to the existing parse+validate-only
runner. Rejected because:

- Mixes orthogonal concerns (parse + validate are fast structural
  checks; runtime assert needs JIT compile + dispatch).
- Recompilation burden: each assertion would re-JIT, expensive for
  1158 modules.
- Hard to gate: "wasm-2.0 parse=0" vs "wasm-2.0 runtime assert=0"
  are separate release criteria.
- Difficult to debug: parse errors vs validation errors vs
  execution errors all in one flow.

### Option B — Base + specialisations (adopted)

DRY the 600 LOC of manifest-walk + skip-tally + module-init across
all assertion runners; specialisations differ only in token/result
codecs and entry dispatch.

- Saves ~900 LOC of duplication (vs reimplementing each runner).
- Clear separation: wast_runner stays parse+validate; base+specs
  handle runtime asserts.
- Extensibility: future assertion variants (e.g., GC heap ops in
  Phase 10) plug into base with callback impl only.

### Option C — `comptime` parameterisation via generic runner

A single generic runner taking type parameters for ResultKind +
ArgValue. Rejected because:

- Zig 0.16 generic functions get unwieldy for variadic argument
  shapes (60+ entry helper signatures in SIMD; 30+ in non-SIMD).
- The callback pattern is more readable and matches the existing
  zwasm-v2 dispatch-table style (e.g., `instruction/` per-version
  registrations).

## Consequences

**Positive**:

- Non-SIMD spec runtime assertions become first-class (l-1b
  builds on l-1a's base).
- 50% LOC reduction in SIMD runner (1071 → ~500) — easier to
  maintain.
- New assertion runners can be added in <500 LOC each by
  implementing the callback trait.

**Negative**:

- 3 files instead of 2 (`base` + `simd` + `non_simd`).
- Refactor risk: l-1a MUST preserve exact SIMD runner output
  (Mac + OrbStack bit-identical 13301/0/440). Mitigated by:
  - Running `test-spec-simd` before + after l-1a; require
    identical pass/fail/skip counts.
  - No new corpus or directive semantics in l-1a (pure refactor).

**Neutral / follow-ups**:

- l-1a (this chunk): base extraction + SIMD refactor. Pure
  refactor; zero behavior change.
- l-1b (next chunk): non-SIMD specialisation + new build step +
  curated wasm-2.0-assert corpus.
- k-1 (downstream) — Wasm 2.0 non-SIMD wast vendor (~30 files)
  is unblocked once l-1b's runner exists.

## Chunk split

Per chunk-granularity rule (≤ 800 LOC per chunk):

- **l-1a** (this chunk): ~500-600 LOC base extraction + SIMD
  refactor. Pure refactor; SIMD test gate verifies green-to-green.
- **l-1b** (next chunk): ~600-700 LOC non-SIMD specialisation +
  build wiring + curated corpus. Feature-add.

## References

- [`private/notes/p9-99-l-1-spec-assert-survey.md`](../../private/notes/p9-99-l-1-spec-assert-survey.md)
  — full survey informing this design.
- `private/p9-x-wasm2-non-simd-coverage.md` — Agent X audit
  motivating l-1.
- `test/spec/simd_assert_runner.zig` (existing 1071 LOC source).
- `test/spec/wast_runner.zig` (parse+validate runner; not
  extended).
- ADR-0029 (Path B skip-impl / skip-adr semantics).
- ADR-0045 (scratch-buffer-direct JitRuntime construction; spec
  runners bypass setupRuntime per this ADR).
- ADR-0052 (v128 globals layout — referenced by both runners).
- ADR-0056 (Phase 9 = Wasm 2.0 100% PASS scope; l-1 is sub-task).

## Revision history

- 2026-05-12: Initial accept at the l-1 survey close. Implementation
  l-1a / l-1b pending in subsequent chunks.
