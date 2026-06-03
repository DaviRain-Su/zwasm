# ADR-0142 — Phase-13 §13.2 C-API surface scoping + §13.3/§13.4 sequencing + §13.5 rust_host Mac-only scope

> **Status**: Accepted (2026-06-04). Autonomous per ADR-0132 carve-out
> (re-scoping because a phase's exit references genuinely-later/blocked work).

## Context

ROADMAP §13.2 = "Implement the missing `wasm.h` surface (valtype / functype /
… / ref / … / foreign), grouped by category." The **load-bearing surface is
complete**:

- Type constructors + queries + vecs (`7ac09d80`); externtype + import/export
  types (`6f721b6b`); module imports/exports (`80131306`/`befd8acd`); frames +
  trap origin/trace (`d3819d32`).
- Extern conversions: `extern_as_*_const` + `extern_type` (`63dab69d`);
  `*_as_extern[_const]` (`0fc0aac5`, `api/extern_new.zig`).
- Host-entity construction (all importable): `wasm_global_new` (`5faef5d9`),
  `wasm_memory_new` (`a1c9fbfe`), `wasm_table_new` (`08d5fd23`),
  `wasm_func_new[_with_env]` (`c712eac1`, closed D-252).
- Ref machinery: `wasm_ref_copy`/`_same` (`9e634743`); funcref cross-cast
  `wasm_func_as_ref`/`wasm_ref_as_func` (`8775e30f`); `wasm_foreign` +
  host_info + `as_ref`/`ref_as_foreign` (`9c15ca50`).

What remains is tracked in **D-253**: (C) per-entity `host_info` on
func/global/table/memory; (E) the degenerate `wasm_{instance,extern,global,
table,memory}_as_ref` casts.

## Decision

1. **Mark §13.2 `[x]`.** C/E stay in D-253, deferred §13.4-driven. Rationale:
   - **(C) host_info bulk** is low-value (host attaching data to a wasm entity
     is rarely exercised by the conformance examples) AND cap-constrained
     (`instance.zig` is at 3299/3300; adding `host_info` fields to four structs
     exceeds the exempt cap → needs a Store-level side-table keyed by handle
     ptr, or another cap raise). Defer that design until a consumer needs it.
   - **(E) degenerate casts** are genuinely not-modeled: instances/externs are
     not spec reference *values* (no `runtime.Value` encoding for "a reference
     to an instance/extern"). Whether to expose them at all is a model decision
     that §13.4 (does any ported example use them?) informs. NOT silent stubs —
     documented as not-modeled in D-253.

2. **Sequence §13.4 before the §13.3 remainder.** §13.3's `inherit_argv`/
   `inherit_env` + `preopen_dir` are blocked on the ADR-0070 (libc boundary)
   C-API io/process-provenance decision (Zig 0.16's capability-based I/O gives
   a C-library context no `Init` token — see the §13.3-partial handover note).
   §13.4 (conformance) is unblocked, validates the §13.2 surface end-to-end via
   the existing `zig build test-c-api` harness, and reveals which of D-253 C/E
   actually matter. So: §13.4 next; §13.3 remainder interleaves once ADR-0070
   lands.

3. **§13.5 `rust_host` is Mac-only; the "rust on all 3 OS" sub-clause is
   deferred to §13.P.** §13.5's exit reads "examples build + run on all 3 OS."
   c_host (`test-c-api`) and zig_host (`run-zig-host`) are in test-all → 3-OS-
   verified at the phase boundary. rust_host (`run-rust-host`, `extern "C"` over
   `libzwasm.a`) builds + runs on Mac only: the ubuntunote / windowsmini test
   hosts are **rustc-free by design** (`toolchain_provisioning.md` — fixtures
   are generated on Mac, committed artifacts run toolchain-free on the test
   hosts), so a "rust run" there would require crossing that invariant. This is
   the §18.1-first-bullet case (exit references genuinely-blocked work). Mark
   §13.5 `[x]` now (examples exist + the C-ABI surface rust_host consumes is
   already 2-host conformance-tested at §13.4); record the rust-3-OS gap as
   **D-254** and defer the FINAL exit call — provision rustc on test hosts
   (needs its own ADR to cross the toolchain-free invariant) **vs** re-phrase the
   exit to "Mac rust_host + 2-host C-ABI conformance" — to §13.P, the 🔒
   user-gated close. The decision is deferred, not made here.

## Consequences

- §13.2 closes without C/E; D-253 (blocked-by §13.4 prioritization) carries
  them with full encoding/ownership notes + discharge order.
- §13.P (phase close 🔒) gates on conformance fail=0 + examples — by then D-253
  C/E are either implemented (if §13.4 needs them) or confirmed not-modeled.
- §13.5 closes with rust_host Mac-only; D-254 (blocked-by test-host rustc)
  carries the 3-OS-rust gap + the two discharge options; §13.P makes the call.
- No ROADMAP §1/§2/§4/§5/§11/§14 change; §9-scope re-scope only (ADR-0132).
