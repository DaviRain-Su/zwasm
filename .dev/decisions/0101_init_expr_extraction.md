# 0101 — Extract `parse/init_expr.zig` (Wasm constant-expression utility)

- **Status**: Closed (§9.12-A DONE)
- **Date**: 2026-05-21
- **Author**: post-ADR-0099 redesign
- **Tags**: file-layout, refactor, zone-1, parse, init-expr, deep-utility
- **Supersedes**: ADR-0095, ADR-0096 (per ADR-0100 — those extracted sibling decoders with helper-circular imports)

## Context

ADR-0095 / ADR-0096 extracted per-section decoders (element, codes,
data) from `parse/sections.zig` to siblings, but the siblings call
`sections.scanInitExpr` and `sections.readValType` — helpers that
had to be pub-leaked from `sections.zig`. Per ADR-0099 §D2, this is
N1+N2 — extraction at the wrong boundary.

The correct boundary is at the Wasm const-expression machinery
(`scanInitExpr` / `readValType` / `skipLeb128`), which is consumed
by multiple section decoders within `sections.zig` (decodeGlobals,
decodeElements, decodeDatas) AND by the 3 extracted siblings
(sections_element, sections_codes, sections_data). The shared
machinery is a **deep utility**, not a per-section concern.

Wasm spec citations:
- `scanInitExpr` realises §5.4.1 (constant expressions / init
  expressions) — used by globals, element-segments, data-segments.
- `readValType` realises §5.3.1 (valtype encoding).
- `skipLeb128` is a primitive used internally by scanInitExpr.

## Decision

Extract const-expression utilities to `src/parse/init_expr.zig` as
a deep utility module:

```zig
pub const Error = error{ UnexpectedEnd, InvalidFunctype, BadValType } || leb128.Error;
pub fn scanInitExpr(body: []const u8, pos: *usize) Error!void
pub fn readValType(body: []const u8, pos: *usize) Error!ValType
fn skipLeb128(body: []const u8, pos: *usize, comptime max_bytes: usize) Error!void  // private
```

External callers (`sections.zig` + 3 siblings + future Wasm 3.0 GC
decoders) consume via `init_expr.X`. No circular imports —
`init_expr.zig` depends only on `support/leb128.zig` + `ir/zir.zig`
(both Zone-0/1 layers below).

## Justification per ADR-0099 §D2

**P3 (Independent change cadence + deep interface) fires**:

- ≥ 3 public symbols: `scanInitExpr`, `readValType`, `Error` (a
  type counts toward the symbol-count threshold per §D2 P3
  wording). The `skipLeb128` primitive stays private.
- ≥ 2 external callers: `sections.zig` (decodeGlobals + others) +
  3 sibling files (sections_element, sections_codes, sections_data).
  Easily satisfies the "≥ 2 external callers OR 1 caller with ≥ 10
  use-sites" criterion. Actual site count across the 4 consumers
  is ~9 today.
- Independent change cadence: const-expression machinery is
  Wasm-spec-locked. It changes only when the Wasm spec adds new
  const ops (e.g. when `global.get` was added to const-exprs in
  Wasm 2.0). Section-decoder logic (table layout, code-body
  decoding) changes orthogonally.

**No N fires**:

- N1 (helper-circular): `init_expr.zig` does not import
  `sections.zig`. The flow is `sections → init_expr` (and never
  reverse). After 5c, internal `sections.zig` callers also
  delegate to `init_expr.X`; the prior internal-call pattern
  ceases to count as circular.
- N2 (pub-leak): the helpers are pub in `init_expr.zig` by design,
  not pub-leaked from a previously-private state. The original
  `sections.scanInitExpr` was pub-leaked to satisfy ADR-0095's
  siblings; after this ADR lands, that leak goes away (deleted in
  sub-step 5c).
- N3 (shallow): `init_expr.zig` is ~80 LOC substantive — above
  the 100 LOC bar marginally, but the spec-axis (P1 partial:
  "const-expression machinery is Wasm proposal §5.4.1") combined
  with P3 makes it a defensible deep-utility extraction. The
  module is "shallow" in LOC terms but conceptually deep: callers
  pass `(body, *pos)` and receive `Error!T`; everything between
  is encapsulated.
- N4 (test dup): no test fixtures duplicated.

## Conditions check summary

| P/N | Status | Notes |
|---|---|---|
| P1 (spec sub-language) | partial | Wasm §5.4.1 const expressions — shared with §5.3.1 valtype reader |
| P2 (pure-data dominance) | not applicable | functions, not data |
| **P3 (deep interface + indep cadence)** | **PASS** | 3 pub symbols, 4+ external callers, Wasm-spec-locked cadence |
| P4 (test isolation) | corroborating | no shared test fixtures |
| N1 (helper-circular) | clear | one-way dep flow |
| N2 (pub-leak) | clear | helpers pub by design |
| N3 (shallow) | clear | ~80 LOC, but spec-axis + deep callers |
| N4 (test dup) | clear | no test dup |

## Sub-step execution

Cycle 5 is split into 3 sub-steps; each lands as its own commit
and is independently green:

- **5a** (this commit): create `init_expr.zig` with the helpers
  copied from `sections.zig`. `sections.zig` retains its versions
  during this sub-step (duplicate, but tests pass on both copies).
- **5b**: re-point `sections_element.zig` / `sections_codes.zig` /
  `sections_data.zig` at `init_expr.X`. After 5b: siblings no
  longer depend on `sections.scanInitExpr` / `sections.readValType`
  for helpers. (The `sections.X` pub-leak of the helpers still
  exists in `sections.zig` for its internal callers.)
- **5c**: replace internal `sections.zig` calls of
  `scanInitExpr` / `readValType` with `init_expr.X`. Delete the
  helper functions from `sections.zig`. The pub-leak is gone.

Each sub-step's intermediate state preserves `zig build test`
green.

## Alternatives

1. **Path A — straight rollback of ADR-0095/0096 with FILE-SIZE-EXEMPT
   marker on sections.zig** — Rejected. The per-section sibling
   organisation has legitimate spec-axis value (each sibling
   corresponds to a Wasm §5.5.x section); throwing it away
   forfeits a P1 candidate. Path B preserves the sibling shape
   and fixes the boundary.

2. **Keep helpers in sections.zig + accept N1+N2** — Rejected.
   ADR-0099 §D2 explicitly rejects this; the discipline must
   apply uniformly or it erodes.

3. **Combine init_expr with leb128.zig** — Rejected. `leb128` is
   a primitive (Zone 0 support); `init_expr` consumes leb128 +
   adds Wasm-spec semantics. Mixing them collapses the layering.

## Consequences

### Positive
- ADR-0095/0096 sibling shape preserved; the boundary fix is
  surgical.
- Future Wasm 3.0 GC decoders (table.atomic_*, struct.new,
  array.new_default, etc.) can extend `init_expr.zig` without
  re-entering `sections.zig`.
- `sections.zig` shrinks; LOC under soft cap by margin.
- `check_split_smell.sh` findings reduce from 9 → 4
  (3 N1-helper-circular + 2 N3-shallow clear in sections siblings).

### Negative
- One new file (`init_expr.zig`, ~80 LOC). Net file count: +1
  vs the pre-D-141 baseline (since 5c removes nothing else).
- Cycle 5's 3 sub-steps need to be executed in order; a mid-step
  interruption requires resuming at the next sub-step (the plan
  document's §"Recovery from mid-cycle interruption" describes
  how to detect state via `grep -r 'sections\.scanInitExpr'`).

### Neutral
- `sections.Error` continues to be the externally-observable
  error union for section decoders; `init_expr.Error` is a
  strict subset implicitly convertible (Zig's narrow-error-set
  inference handles this without explicit wrappers).

## References

- ADR-0099 (the framework — file-size discipline reframe)
- ADR-0100 (rollback notice paired with this ADR)
- ADR-0095 / ADR-0096 (superseded — the per-section extractions
  with helper-circular imports)
- Wasm spec §5.4.1 (constant expressions / init expressions)
- Wasm spec §5.3.1 (valtype encoding)
- `private/file-size-reform/06-rollback-plan.md` (decision
  walkthrough between Path A and Path B)

## Revision history

- 2026-05-21 — Initial draft, Cycle 5 of file-size discipline reform.

- 2026-05-22 (`006f0d6d`) — Status: Accepted → Closed (§9.12-A DONE).
