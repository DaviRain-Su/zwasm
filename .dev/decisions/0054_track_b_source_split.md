# 0054 — Track B source-split: x86_64 + arm64 SIMD source partition (D-057 + D-065 close)

- **Status**: Closed (implemented)
- **Date**: 2026-05-12
- **Author**: Phase 10 prep + §9.9-h-15..-20 autonomous /continue cycle
- **Tags**: roadmap, phase9, refactor, file-shape, jit, simd, x86_64, arm64, mirror-adr-0030

## Context

D-057 named `src/engine/codegen/x86_64/op_simd.zig` (4694 LOC) and
its siblings `op_simd_test.zig` (2700 LOC) + `inst_sse.zig` (2464
LOC) as exceeding ROADMAP §A2 / §14's 2000-LOC hard cap. D-065
named `src/engine/codegen/arm64/inst_neon.zig` (2323 LOC) +
`arm64/op_simd.zig` (2307 LOC) on the same structural failure mode.
Both debts pointed at the same root cause: `scripts/file_size_check.sh`
was opt-in (no git hook), so cap breaches accumulated silently
during the §9.7..§9.9 SIMD chunk run.

Phase 10 prep mode (2026-05-11..2026-05-12) produced
`.dev/phase10_prep/track_b_source_split.md` — a user-confirmed
design doc resolving the 5 outstanding partition questions
(granularity, ADR shape, test mirror, naming convention, helper
visibility). This ADR codifies the decisions as load-bearing per
ROADMAP §18.2 (single-ADR governance of co-derived source splits).

The 5 files in scope at chunk 9.9-h-15 open:

| File | LOC at start | Cap-breach % |
|---|---|---|
| `x86_64/op_simd.zig` | 4694 | +135% |
| `x86_64/op_simd_test.zig` | 2700 | +35% |
| `x86_64/inst_sse.zig` | 2464 | +23% |
| `arm64/inst_neon.zig` | 2323 | +16% |
| `arm64/op_simd.zig` | 2307 | +15% |

## Decision

### 1. Single ADR governs both arches (one ADR-0054, not two)

D-057 + D-065 are co-derived from the same gate-dormancy lesson
(opt-in `file_size_check.sh` lets soft drift accumulate into
hard breach). One ADR keeps the design rationale unified.

### 2. 4-way granularity for `op_simd.zig` (both arches)

`op_simd.zig` splits into 4 files, not 3:

- `op_simd.zig` (kept; orchestrator) — V128 mem family + bitwise
  (Not/And/Or/Xor/Andnot/Bitselect/AnyTrue) + Const + helpers
- `op_simd_int_arith.zig` (new) — Int ALU + sat + shift + min/max
  + neg/abs + avgr + popcnt + (x86_64 only) i64x2.mul synthesis
- `op_simd_int_cmp_lane.zig` (new) — Int cmp + splat + extract/
  replace lane + narrow + extend low/high + extmul + extadd-
  pairwise + bitmask + AllTrue dispatchers + shuffle + swizzle
- `op_simd_float.zig` (new) — all `emitF*` handlers + FP recipes
  + trunc-sat-FP + convert + promote/demote

3-way (e.g. `op_simd_int.zig` carrying both arith + cmp/lane)
would leave the int subspace at ~1900 LOC on x86_64 — soft-cap
re-breach with Phase 10's GC reftype + memory64 lane variants
landing in the same file family. Pay the split cost once now,
not as a mid-Phase-10 second-pass migration.

### 3. 3-way for encoder files (per-arch encoder partitions)

x86_64 `inst_sse.zig` → 3 files:

- `inst_sse.zig` (kept; foundation) — `EncodedInsn`, mem load/
  store XMM, MOV reg-shape (MOVAPS/MOVUPS/MOVD/MOVQ/MOVSD), scalar
  cvt (CVTTSS2SI / CVTSI2SS)
- `inst_sse_packed.zig` (new) — all `encP*` packed integer
  encoders (PADD/PSUB/PMUL family, PCMP*, PMIN/PMAX, PAND/POR/
  PXOR/PANDN, PSHUFB/PSHUFD, PSLL/PSRL/PSRA, PEXTR/PINSR/
  PMOVMSKB/PTEST, PMOVSX*/PMOVZX*, saturating arith, AVGR, dot)
- `inst_sse_scalar.zig` (new) — SSE scalar binary (encSseScalarBinary,
  encUcomi{ss,sd}, encRoundss/sd) + FP packed shapes
  (ADD/SUB/MUL/DIV/MIN/MAX/SQRT/CMP/ROUND PS+PD + packed cvts)

arm64 `inst_neon.zig` → 3 files:

- `inst_neon.zig` (kept; foundation) — Memory (LDR/STR Q-form,
  LD1R), reg-move foundation (ORR/MOV/DUP/AND/BIC/EOR/MVN .16B),
  Q-shape helpers, BSL/BIT/BIF, Vn/Xn type aliases
- `inst_neon_arith.zig` (new) — ADD/SUB/MUL/MIN/MAX/ABS/NEG/CNT/
  AVGR/sat-arith + shifts (USHL/SSHL/SSHR-imm) + reductions
  (UMAXV/UMINV/ADDV) + ZIP1/EXT/TBL + SXTL/UXTL + SQXTN/SQXTUN +
  SCVTF/UCVTF/FCVTL/FCVTN/FCVTZ + FP arith FADD/FSUB/FMUL/FDIV +
  FP unary FABS/FNEG/FSQRT/FRINT* + FMAX/FMIN
- `inst_neon_lane_cmp.zig` (new) — UMOV/SMOV/INS lane access +
  CMEQ/CMGT/CMGE/CMHI/CMHS int cmp + FCMEQ/FCMGT/FCMGE FP cmp

### 4. 4-way test mirror with strict `<source>_test.zig` suffix (x86_64 only)

`x86_64/op_simd_test.zig` (2700 LOC, 91 tests) → 4 sibling test
files mirroring the source partition:

- `op_simd_test.zig` (kept; aggregator)
- `op_simd_int_arith_test.zig`
- `op_simd_int_cmp_lane_test.zig`
- `op_simd_float_test.zig`

Strict naming convention: `<source>_test.zig` (so
`op_simd_int_arith.zig` ↔ `op_simd_int_arith_test.zig`). Per
ADR-0030 precedent ("test files are discovery surfaces"), test-
file LOC overage is acceptable when discovery is mechanically
aggregated — but the family split keeps the source ↔ test
1:1 navigation legible.

arm64 op_simd.zig has no inline tests at split time — no test
mirror is needed (chunk 9.9-h-18 noted this; if inline tests
land later, the partition shape is pre-decided).

### 5. Tiered `pub` for cross-class primitives

Per ADR-0030's `localDisp`-style precedent: primitives consumed
across the new file family go `pub` in the orchestrator file
(`op_simd.zig`); class-internal recipes stay file-private. The
`pub` keyword itself signals "cross-class primitive" — no
separate doc-comment ceremony.

x86_64 promoted to `pub` in `op_simd.zig`: `emitV128IntBinop`,
`emitV128AllTrue`, `emitConstLoad`, `lookupOrAppendExtraConst`,
`v128MemPrologue`, `v128LoadExtend`, `v128LoadLane`, `v128StoreLane`
(8 helpers). `emitV128FpUnop` promoted in `op_simd_float.zig`
(consumed by int_arith's Abs handlers).

arm64 promoted to `pub` in `op_simd.zig`: `simd_scratch_v` (V31
const), `emitV128Binop`, `emitV128Unop`, `emitV128BinopSwapped`,
`emitV128Ne`.

### 6. Two facade strategies, both within scope

For consumer call-site discipline:

- **x86_64 inst_sse split (chunk 9.9-h-17)**: re-route the
  existing `inst.zig` re-export facade (the `pub const enc* = ...`
  block) to dispatch each name at the correct sub-module
  (`inst_sse` / `inst_sse_packed` / `inst_sse_scalar`). Consumer
  call sites stay **byte-identical** through `inst.encXxx`.
  ~800 call sites in op_simd_* + op_alu_float + op_convert +
  emit.zig untouched.
- **All other splits** (x86_64 op_simd, arm64 op_simd, arm64
  inst_neon): direct call-site rewrites (`op_simd.emitXxx` →
  `op_simd_<class>.emitXxx`) since these have no facade-import
  surface. Mechanical `replace_all` per (function-name, target-
  module) pair.

The facade-vs-rewrite choice is pragmatic per consumer
topology — there is no global rule.

### 7. `file_size_check.sh` flips warn → gate at chunk close

Chunk 9.9-h-20 (this ADR's enabling chunk) lands the
`scripts/gate_commit.sh` edit that invokes `bash scripts/file_size_check.sh
--gate` (was `bash scripts/file_size_check.sh` with the
"(warn-only, see D-057)" callout). The `--gate` mode exits 1
on any hard-cap violation. Combined with `.githooks/pre-push`
running `gate_commit.sh`, future hard-cap drift surfaces
immediately at the chunk that introduces it.

Soft-cap warnings (> 1000 LOC) remain informational — they
flag candidates for the next opportunistic split, not gate
failures.

## Alternatives

### A. Two ADRs (one per arch)

Rejected. The discharge sequencing is identical (split source
→ split tests → flip gate → close debts). Two ADRs would
duplicate the Context + Decision rationale, and the audit-
scaffolding §F debt-coherence check would surface the
"co-derived ADRs without single reference point" smell.

### B. 3-way for op_simd.zig (instead of 4-way)

Rejected. The 3-way shape (`op_simd` + `op_simd_int` +
`op_simd_float`) leaves `op_simd_int.zig` at ~1900 LOC on
x86_64 — within hard cap but 90% of the way to re-breach.
Phase 10's GC reftype + memory64 lane variants land in this
file family; pay the 4-way split cost once now, not as a
mid-Phase-10 second-pass migration with 2× the test-gate
overhead.

### C. Facade-only for all splits (skip call-site rewrites)

Rejected for op_simd splits. The `op_simd.zig` orchestrator
doesn't have an `inst.zig`-style facade layer above it; adding
one (e.g. `op_simd_dispatch.zig` re-exporting all 200+ handler
names) would create a permanent indirection layer with no
post-split benefit. The call-site rewrites are mechanical and
final.

Accepted for `inst_sse.zig` split because the `inst.zig`
facade already exists and call sites already route through it
— no new abstraction layer is needed.

### D. Defer the split to Phase 10 entry

Rejected. D-057 + D-065 were `blocked-by: ADR for source-split
landing` — the longer the split waits, the more the files grow
(D-057 narrative: 2913 → 4494 LOC in ~6 weeks). The Phase 10
entry gate (`.dev/phase10_transition_gate.md`) gets read more
cleanly with the split landed; the gate is a different
deliverable from the split itself.

### E. Keep `op_simd_test.zig` as one file (skip 4-way mirror)

Rejected. With source split 4-way, a single 2700-LOC test file
breaks the source ↔ test 1:1 navigation (a future maintainer
looking at `op_simd_int_arith.zig` would have to grep the
test file rather than open `op_simd_int_arith_test.zig`).
Per ADR-0030, test-file LOC overage is acceptable, but the
discoverability cost of NOT mirroring is steeper than the
50-LOC overhead of carrying 4 file headers + aggregator
imports.

## Consequences

### Positive

- All 5 hard-cap-exceeding files split. `file_size_check.sh`
  hard-cap list = **0** post-9.9-h-19.
- `file_size_check.sh --gate` flip prevents future drift at
  the chunk that would introduce it (no more silent accumulation).
- D-057 + D-065 close.
- Phase 10 GC reftype + memory64 lane variants land in pre-named
  files (`op_simd_int_arith.zig` / `op_simd_int_cmp_lane.zig`) —
  no second-pass split needed.

### Negative

- 9 new source files + 3 new test files across 2 arches add
  surface area. Mitigated by strict naming convention (=
  trivially navigable) + tiered `pub` (= primitives stay
  discoverable in orchestrator file).
- One acceptable helper duplication: x86_64 `inst_sse_packed.zig`
  and `inst_sse_scalar.zig` both need `encSsePackedIntBinop`
  (66-prefix shape). The scalar file carries a private copy
  `encSsePd66Binop` (~10 lines bit-identical). Trade-off:
  preserves mutual file independence (no cross-import in either
  direction) at the cost of 10 LOC duplication. Future GC / Wasm
  3.0 SIMD adjacencies will live in just one of these files,
  not both, so the duplication doesn't grow.

### Deferral — legacy `emit_test_*.zig` rename (D-081)

The existing `x86_64/emit_test_int.zig` + `emit_test_float.zig`
files (created by ADR-0030 / D-051 close) do not match the
`<source>_test.zig` strict suffix introduced here — they are
test-only family splits of monolithic `emit.zig` (no
corresponding `emit_int.zig` / `emit_float.zig` source exists).
Renaming them to `emit_int_test.zig` + `emit_float_test.zig`
without source split would imply non-existent source files.
Deferred to `D-081`, blocked-by `emit.zig` source split
(D-052's prologue extract trigger has effectively fired since
`emit.zig` is at 1991 LOC near the 1000-LOC soft cap).

## References

- `.dev/phase10_prep/track_b_source_split.md` — design rationale +
  partition tables (this ADR codifies its decisions; the prep
  doc remains the implementation walkthrough)
- ADR-0030 — `x86_64/emit.zig` test extraction (D-051 close;
  precedent for `pub localDisp` helper promotion + test-file
  LOC overage acceptance)
- ADR-0041 — SIMD-128 design framing (shape-as-variant ZirOp +
  tiered pub precedent at §4.6)
- D-057 (closed by this chunk's gate flip)
- D-065 (closed by this chunk's gate flip)
- D-081 (filed at this chunk; legacy emit_test_* rename deferred
  until `emit.zig` source split)
- D-052 (emit.zig prologue extract — trigger for D-081 discharge)
- ROADMAP §A2 (file-size cap) + §14 (forbidden patterns;
  silent quiet-edit drift)
- ROADMAP §18.2 (load-bearing change → ADR required)

## Revision history

- 2026-05-12: Accepted; co-landed with chunk 9.9-h-20
  (`file_size_check.sh` warn → gate flip + D-057 + D-065 close +
  D-081 file). SHA backfilled at phase close per /continue
  Step 7 batch-backfill discipline.
- 2026-05-21 (`f79104bb`): **Amendment — legacy-file
  grandfather clause for §"Naming convention"**. The strict
  `<source>_test.zig` shape is **forward-looking** for new
  files. Two legacy test files predate the convention:
  - `src/engine/codegen/x86_64/emit_test_int.zig` (catalog
    of i32/i64 + control/memory/calls JIT-emit tests, ~1600
    LOC after D-055 helper migration)
  - `src/engine/codegen/x86_64/emit_test_float.zig` (catalog
    of f32/f64 JIT-emit tests, ~1500 LOC)
  Both test ops scattered across many per-op files (per
  ADR-0074 per-op-file pattern absorbed the int/float emit
  content). No single source file matches their name; the
  strict convention's "1:1 mapping" assumption doesn't hold.
  **Resolution**: grandfather these two specific files
  (D-081 close); new test files MUST still use strict shape
  per the original convention. Sites of grandfathering listed
  here so future audits don't re-flag them.
