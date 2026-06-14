# WebAssembly Proposal Phase Watch

> Reviewed quarterly. zwasm v2 implements all Phase 5 (= W3C
> Recommendation) proposals for v0.1.0; lower phases are watched and
> re-evaluated when they advance. Phase 4 non-web proposals are the
> v0.2.0 line.

Last reviewed: **2026-06-13**.

## Phase 5 — W3C Recommendation (zwasm v2 v0.1.0 MUST implement)

WebAssembly 3.0 (W3C Recommendation 2025-09):

| Proposal                                      | zwasm v2 phase | ZirOp prefix         |
|-----------------------------------------------|----------------|----------------------|
| MVP (i32/i64/f32/f64, control, memory)        | 1–2           | core                 |
| Multi-value (block params, multi-return)      | 1–2           | (sig-driven)         |
| Sign extension ops                            | 1–2           | core                 |
| Saturating float-to-int                       | 1–2           | core                 |
| Bulk memory                                   | 1–2           | core                 |
| Reference types                               | 1–2           | core                 |
| SIMD-128 (fixed-width)                        | 8              | `*x*.*` /  `v128.*`  |
| Memory64                                      | 9              | core (64-bit memarg) |
| Exception Handling (try-table, throw_ref)     | 9              | `eh_*`               |
| Tail Call (return_call, return_call_indirect) | 9              | `tail_*`             |
| WasmGC (struct/array/i31)                     | 9              | `gc_*`               |
| Function references                           | 9              | core                 |
| Extended const                                | 1–2           | (const-expr)         |
| Relaxed-SIMD                                  | 8              | `*.relaxed_*`        |

Plus v1 parity items at Phase 5:

- Wide arithmetic (i64x2 multiply, add-with-carry)
- Custom page sizes (memory.discard + memarg page-size variants)

## Phase 4 — Standardize (deferred to v0.2.0 for non-web items)

| Proposal                    | Status  | zwasm intent            |
|-----------------------------|---------|-------------------------|
| Threads (atomics, smem)     | Phase 4 | v0.2.0 (after WASI 0.2) |
| JS Promise Integration      | Phase 4 | **SKIP** (web-only)     |
| Web Content Security Policy | Phase 4 | **SKIP** (web-only)     |

## Phase 3 — Implementation (per-feature judgement)

| Proposal                         | Note                  | zwasm intent                    |
|----------------------------------|-----------------------|---------------------------------|
| ESM Integration                  | JS modules            | **SKIP**                        |
| Wide arithmetic (i64x2 mul, ADC) | BigInt-relevant       | Phase 9 alongside SIMD (v0.1.0) |
| Stack switching (continuations)  | Large; gates WASI 0.3 | **DEFER** (D-300; survey 2026-06-07: format unstable + 3 ADRs + ~25-35cyc) |
| Compact import section           | Size opt              | v0.2.0+                         |
| Custom page sizes                | memory tuning         | Phase 10 (v0.1.0)               |
| Custom Descriptors / JS Interop  | JS-only               | **SKIP**                        |

## Phase 2 — Proposed (watch only)

`Profiles`, `Relaxed Dead Code Validation`, `Numeric Values in WAT
Data Segments`, `Extended Name Section`, `Rounding Variants`,
`Compilation Hints`, `JS Primitive Builtins`. Re-evaluate quarterly.

## Phase 1 — Champion (watch only)

`Type Imports`, `Component Model` (v0.2.0 entry point),
`WebAssembly C and C++ API` (already adopted as ABI; ROADMAP §4.4),
`Flexible Vectors`, `Memory Control` (memory.discard), `Reference-
Typed Strings`, `Profiles` (Rossberg variant), `Shared-Everything
Threads`, `Frozen Values`, `Half Precision (FP16)`, `More Array
Constructors`, `JIT Interface` (interesting for self-JIT),
`Multibyte Array Access`, `Type Reflection` (likely demoted), `JS
Text Encoding Builtins` (skip).

## WASI roadmap

| WASI version   | zwasm phase   | Notes                                   |
|----------------|---------------|-----------------------------------------|
| 0.1 (preview1) | Phases 4 / 11 | de-facto baseline; complete in Phase 11 |
| 0.2 (preview2) | **Phase 17 (ACTIVE)** | Component Model required; full campaign per ADR-0170 (`component_model_plan.md`) |
| 0.3            | post-v0.1.0 (post-v0.2.0) | **released 2026-06-11**; rebases WASI on CM async — streams/futures replace 0.2 poll/`pollable`; breaking vs 0.2; impl gated on CM-async + stack-switching (D-300, DEFER) |

## Toolchain proposals (non-Wasm; trigger zwasm scaffolding changes)

| Proposal                                     | Status                                | Trigger                                                                                                                                       |
|----------------------------------------------|---------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| Zig `@deprecated()` builtin + `-fdeprecated` | ziglang/zig#22822 — accepted, urgent | When this lands (likely 0.17+), revisit ADR-0009 — native compiler enforcement may obsolete the zlinter `no_deprecated` dependency entirely. |

## Review log

- **2026-04-30** — initial table seeded from zwasm v1's
  `.dev/proposal-watch.md` and the pre-skeleton survey at
  `~/zwasm/private/v2-investigation/surveys/wasm-proposal-status.md`.
- **2026-05-03** — added "Toolchain proposals" section tracking
  ziglang/zig#22822 as the ADR-0009 sunset trigger.
- **2026-06-07** — **Component Model + WASI-P2**: the ROADMAP §15 ecosystem-gate
  is RESOLVED in CM's favour (ADR-0170, user-directed) — CM-as-capability is a
  rare differentiator (only wasmtime-class), not consumer-count-gated. Now the
  active Phase-17 campaign; full wasmtime-equivalent target; driver
  `component_model_plan.md`. Supersedes the prior "deferred to post-v0.1.0" framing.
- **2026-06-07** — **branch-hinting** (`metadata.code.branch_hint` custom
  section): v1 advertised COMPLETE; the proposal is an advisory QoI hint with
  NO conformance effect. v2 accepts it via the generic custom-section skip
  (verified @dcc8d71c, fixture `edge_cases/p17/branch_hint`, hints ignored) —
  this satisfies "a conformant runtime may ignore it." OPTIONAL future QoI:
  consume the hints to bias JIT branch layout (likely/unlikely). Not scheduled
  (no behaviour/conformance gain); revisit only if a perf campaign wants it.
- **2026-06-13** — **WASI 0.3.0 released** (2026-06-11): rebases WASI on the
  Component Model's async primitives — first-class streams/futures replace the
  0.2 poll/`pollable` pattern; breaking vs 0.2. Stays **post-v0.1.0 (post-v0.2.0)**:
  its async core is gated on CM-async + stack-switching (D-300, still DEFER —
  format unstable per the 2026-06-07 survey). v0.1.0 scope = Wasm 3.0 + WASI 0.2
  (Phase 17) UNCHANGED; no current-scope drift. Reference-clone note: local
  `WebAssembly/{spec,testsuite,WASI}` clones trail `.dev/spec_pin.yaml` (pinned
  2026-06-04, NEWER than the clones) — the tested/vendored corpus is current for
  the targeted scope; refresh the clones for manual lookups when convenient.
- **2026-06-14** — **wg-3.0 currency re-verification (the debt's "multi-value-runner
  ceiling" was STALE, refuted)**: empirically compared committed corpus assert
  counts vs the frozen `wg-3.0` tag for every proposal — ALL current: EH try_table
  34=34, gc all files (array 24 / struct 17 / i31 55 / type-subtyping 17 / ref_cast
  11 / ref_test 68), tail-call (un-reverted `21959b5f`). 0 skip-impl; multi-value-
  result asserts (`type-f64-i64-to-i32-f32`, `get_globals`) PRESENT + passing via
  `invokeMulti`. **Alpha conformance condition (100% latest 3.0 spec) MET.** Spec
  pin bumped 21b053f→f3d3448 (`.dev/spec_pin.yaml`): the drift was PURELY `[spectec]`
  formal-spec tooling + editorial/typing-rule fixes (PRs #2180-2186), `test/core/
  *.wast` ZERO changes → corpora unaffected. Also: JIT exnref completeness done
  (D-327 reify + throw_ref / D-328 multi-value catch result-vreg; conformance-
  neutral but user-directed "ideal form"; bundle `3234f7a9`).
