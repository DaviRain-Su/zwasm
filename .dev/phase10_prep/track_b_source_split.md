# Phase 10 prep — Track B: D-057 / D-065 source-split partition

> Status: **DRAFT — awaiting user partition approval**
> Date: 2026-05-12
> Author: autonomous `/continue` loop, Phase 10 prep mode
> Path note: relocated from `private/notes/p10-prep-track-b-…`
> (gitignored, can't commit) to `.dev/phase10_prep/` per Track A
> precedent.

## §1. Question

What is the concrete file partition for the **5 files** currently
exceeding the §A2 / §14 2000-LOC hard cap?

| Current file                              | LOC  | Functions | Cap-breach % |
|-------------------------------------------|------|-----------|--------------|
| `src/engine/codegen/x86_64/op_simd.zig`   | 4694 | 260       | +135%        |
| `src/engine/codegen/x86_64/op_simd_test.zig` | 2700 | 91 tests | +35%         |
| `src/engine/codegen/x86_64/inst_sse.zig`  | 2464 | 165       | +23%         |
| `src/engine/codegen/arm64/inst_neon.zig`  | 2323 | 176       | +16%         |
| `src/engine/codegen/arm64/op_simd.zig`    | 2307 | 231       | +15%         |
| **Total**                                  | 14488 | 923       |              |

D-057 (x86_64 op_simd.zig + sibling test/inst_sse) and D-065
(arm64 op_simd.zig + inst_neon) jointly track this surface. Both
debts say "single ADR can govern both source-splits OR two ADRs
in a cohort". This Track decides which **and** lands the
partition.

## §2. Precedent — ADR-0030 (D-051 close)

ADR-0030 split `x86_64/emit.zig` (4305 LOC) by **extracting
inline tests** to a sibling `emit_test.zig` as primary path,
deferring the multi-vector structural split. Key lessons that
apply here:

1. **"Test files are discovery surfaces, not authored modules"**
   — accepting test-file LOC overage when test discovery is
   mechanically aggregated is in-line precedent. This bounds
   the test-file scope of Track B.
2. **Defer fine-grained family split** to opportunistic cleanup
   — landing the primary structural split first lets each step's
   correctness be verified independently. ADR-0030 deferred the
   per-op-class family split (`emit_test_alu_int.zig` /
   `emit_test_memory.zig` / …) to Phase 8 opportunistic work.
3. **One private helper goes pub** is acceptable cost
   (`localDisp` precedent).

## §3. Op-family inventory

### §3.1 `x86_64/op_simd.zig` (4694 LOC, 260 fns)

Function class breakdown (from `grep -c "^pub fn emit*"`):

| Class            | Count | Examples                                   | LOC est. |
|------------------|-------|--------------------------------------------|----------|
| `emitV128*`      |    30 | Load/Store/Load*Splat/Load*Lane/Load*Zero/Load*Extend, Const, Not, And, Or, Xor, Andnot, Bitselect | ~900    |
| `emitI*`         |   152 | i8x16/i16x8/i32x4/i64x2 arith + cmp + shift + lane + extend + narrow + popcnt + bitmask | ~2500   |
| `emitF*`         |    54 | f32x4/f64x2 arith + cmp + lane + convert + round + neg/abs/sqrt | ~1100   |
| private helpers  |    24 | `emitV128IntBinop`, `v128MemPrologue`, `emitV128IntCmpSigned/Unsigned`, `emitV128FpCmp`, `emitV128FpMin/Max/Unop/Abs/Neg/Round`, `emitV128AllTrue`, `emitV128IntShift/Neg/Ne`, `emitV128ExtendLow/High`, `v128LoadExtend/Lane`, `v128StoreLane`, `emitConstLoad` | ~200    |

### §3.2 `arm64/op_simd.zig` (2307 LOC, 231 fns)

| Class       | Count | LOC est. |
|-------------|-------|----------|
| `emitV128*` |    31 | ~500    |
| `emitI*`    |   126 | ~1100   |
| `emitF*`    |    54 | ~600    |
| helpers     |    20 | ~100    |

### §3.3 `x86_64/inst_sse.zig` (2464 LOC, 165 fns)

Encoder family groups visible from `grep "^pub fn enc"`:

| Family                       | Examples                                              | LOC est. |
|------------------------------|-------------------------------------------------------|----------|
| Memory load/store (XMM mem)  | `encStoreXmm{F32,F64,V128}Mem*`, `encLoadXmm*`        | ~400    |
| MOV register-shape variants  | `encMovaps`, `encMovups*`, `encMovd*`, `encMovq*`     | ~250    |
| Scalar conversion            | `encCvttScalar2Int`, `encCvtsi2Scalar`                | ~100    |
| SSE packed binary (P*)       | `encPadd{B,W,D,Q}`, `encPsub*`, `encPmull*`, etc.     | ~800    |
| SSE scalar binary            | `encSseScalarBinary`, `encUcomi{ss,sd}`               | ~200    |
| SSE comparison + round       | `encRoundss`, `encRoundsd`, `encSsePackedBinary`      | ~200    |
| Misc + shared shape helpers  | `EncodedInsn` struct + variants                       | ~500    |

### §3.4 `arm64/inst_neon.zig` (2323 LOC, 176 fns)

| Family                       | Examples                                              | LOC est. |
|------------------------------|-------------------------------------------------------|----------|
| Memory load/store (Q-form)   | `encLdrQ*`, `encStrQ*`, `encLd1r*`                    | ~150    |
| Reg-move + foundation        | `encOrrV16B`, `encMovV16B`, `encDup*`, `encAnd/Bic/Eor/Mvn16B` | ~200    |
| Arithmetic                   | `encAdd*`, `encSub*`, `encMul*`, `encAbs*`, `encNeg*`, `encCnt16B` | ~400    |
| Comparison + min/max         | (lower section, by family)                            | ~600    |
| Lane access (UMOV/SMOV/INS)  | `encUmov*`, `encSmov*`, `encIns*`                     | ~400    |
| FP variants                  | `encFAdd*`, `encFMul*`, etc.                          | ~300    |
| Misc encoding helpers        |                                                         | ~250    |

### §3.5 `x86_64/op_simd_test.zig` (2700 LOC, 91 tests)

Test groups mirror handler families (sampled from `grep "^test \""`):

| Group                       | Tests | LOC est. |
|-----------------------------|-------|----------|
| Int arith + saturated       |   ~15 | ~400    |
| Int compare (signed + unsigned) | ~15 | ~400   |
| Int lane (splat/extract/replace/extend/narrow) | ~12 | ~350 |
| Int bitwise + popcnt + bitmask | ~10 | ~300   |
| FP compare + arith          |   ~15 | ~450    |
| FP min/max NaN-correction   |    ~6 | ~250    |
| V128 mem + bitwise + bitselect |  ~10 | ~350   |
| FP lane (splat/extract/replace) | ~8 | ~200    |

Per ADR-0030, **test files are discovery surfaces** — overage is
acceptable but bounded. With 2700 LOC across 91 tests, the file
warrants a family split to align with the source split,
otherwise the test↔handler 1:1 navigation breaks.

## §4. Proposed partition

### §4.1 Strategy summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ADR shape | **Single ADR-0054** covering both x86_64 and arm64 (5 files together) | D-057/D-065 are co-derived from the same gate-dormancy lesson; one ADR keeps the design rationale unified |
| Primary split target | Each file ≤ 1800 LOC post-split (~90% of cap, leaving headroom) | Single migration; no second-pass needed for normal Phase 10 growth |
| Granularity | **3-way per heavy file** (orchestrator + int + fp) | Matches op_simd.zig's natural class boundary (V128/I/F prefix); avoids ADR-0030's "too-fine family split" deferral problem |
| Test split | Mirror source split (3-way per arch) | Test↔handler navigation preserved |
| Encoder split (inst_sse / inst_neon) | 3-way by encoder family | Memory/reg-move foundation + arith + lane/cmp; matches functional grouping visible in current file order |

### §4.2 Partition table — x86_64

| Current file → New file                              | Op group / handler list                                                                | LOC est. |
|------------------------------------------------------|----------------------------------------------------------------------------------------|----------|
| `op_simd.zig` (kept; orchestrator)                   | `emitConstLoad`, `v128MemPrologue`, `v128LoadExtend/Lane`, `v128StoreLane`, `emitV128IntBinop`, all `emitV128*` handlers (mem + bitwise) | ~1100    |
| `op_simd_int.zig` (new)                              | All `emitI*` handlers (152 fns) + `emitV128IntCmpSigned/Unsigned`, `emitV128IntShift`, `emitV128IntNeg`, `emitV128IntNe`, `emitV128ExtendLow/High`, `emitV128AllTrue` | ~1900    |
| `op_simd_fp.zig` (new)                               | All `emitF*` handlers (54 fns) + `emitV128FpCmp`, `emitV128FpUnop`, `emitV128FpMin/Max`, `emitV128FpAbs/Neg/Round` | ~1600    |
| `op_simd_test.zig` (kept; aggregator)                | Cross-cutting V128 mem/bitwise tests + import statements for split test files          | ~600     |
| `op_simd_test_int.zig` (new)                         | Int arith/cmp/shift/lane/extend/narrow/popcnt/bitmask tests                            | ~1100    |
| `op_simd_test_fp.zig` (new)                          | FP arith/cmp/min-max/lane/convert/round tests                                          | ~1000    |
| `inst_sse.zig` (kept; foundation)                    | `EncodedInsn` struct, mem load/store XMM, MOV register-shape, scalar cvt helpers       | ~1100    |
| `inst_sse_packed.zig` (new)                          | All `encP*` packed binary encoders (PADD/PSUB/PMUL/PCMP/PMIN/PMAX/PAND/POR/PXOR/PSHUFB/PSHUFD/PSLL/PSRL/PSRA/PEXTR/PINSR/etc.) | ~900     |
| `inst_sse_scalar.zig` (new)                          | `encSseScalarBinary`, `encUcomi{ss,sd}`, `encRoundss/sd`, `encSsePackedBinary`, FP convert encoders | ~500     |

### §4.3 Partition table — arm64

| Current file → New file                | Op group / handler list                                                  | LOC est. |
|----------------------------------------|--------------------------------------------------------------------------|----------|
| `op_simd.zig` (kept; orchestrator)     | Helpers + all `emitV128*` handlers (mem + bitwise)                       | ~650     |
| `op_simd_int.zig` (new)                | All `emitI*` handlers (126 fns) + int-shared helpers                     | ~1200    |
| `op_simd_fp.zig` (new)                 | All `emitF*` handlers (54 fns) + FP-shared helpers                       | ~700     |
| `inst_neon.zig` (kept; foundation)     | Memory (LDR/STR Q-form, LD1R), reg-move (ORR/MOV/DUP/AND/BIC/EOR/MVN), Q-shape helpers | ~700     |
| `inst_neon_arith.zig` (new)            | ADD/SUB/MUL/MIN/MAX/ABS/NEG/CNT/AVGR/sat-arith encoders (per-shape variants) | ~900    |
| `inst_neon_lane_cmp.zig` (new)         | UMOV/SMOV/INS lane access + CMEQ/CMGT/CMHI/CMHS comparison + extract/replace | ~750     |

### §4.4 Why this granularity, not finer

A 4-way split (e.g. separating int_arith from int_cmp_lane) was
considered. Rejected because:

- Each new file would land at ~700–900 LOC, far below the soft
  cap (1000). Phase 10 SIMD-adjacent additions (GC reftype
  packing, memory64 lane variants) would need to navigate
  more files. The proposed 3-way layout leaves headroom for
  Phase 10 growth without needing a second-pass split.
- ADR-0030 explicitly rejected ADR-0021's 6-file family split
  as the immediate path; that level of decomposition was
  deferred to "opportunistic Phase 8 cleanup". Same logic
  applies here: defer file_test family splits below the
  proposed 3-way to opportunistic Phase 12+ cleanup if a
  consumer pattern emerges (e.g. test-only changes producing
  large diffs in unrelated handler regions).
- The 3-way prefix split (`V128*` / `I*` / `F*`) matches the
  Wasm SIMD opcode taxonomy 1:1 — no semantic loss.

### §4.5 Why kept-file naming (`op_simd.zig`) instead of renaming

ADR-0030 precedent: kept the original name for the slimmed-down
orchestrator and added sibling files. Same pattern here:

- `op_simd.zig` (kept) = orchestrator + V128 mem/bitwise; consumers
  importing `op_simd` still resolve the same set of `pub fn
  emitV128*` symbols.
- New siblings export `pub fn emitI*` and `pub fn emitF*`
  respectively; consumers must update import paths for those
  handlers. The dispatch site (`src/engine/codegen/x86_64/op_simd_
  dispatch.zig` if exists, or whichever file routes per opcode)
  updates to multi-import. Mechanical change.

## §5. ADR-0054 draft skeleton

```markdown
# 0054 — Split op_simd.zig + inst_{sse,neon}.zig per §A2 cap (D-057 + D-065)

- Status: Accepted
- Date: 2026-05-{XX} (lands when prep mode closes)
- Author: Phase 10 prep cycle (autonomous /continue loop)
- Tags: roadmap, phase9-close, refactor, file-shape, jit, simd, x86_64, arm64, mirror-adr-0030

## Context

5 SIMD-adjacent codegen files exceed §A2's 2000-LOC hard cap as
of 2026-05-12:

| File | LOC | Cap-breach |
|------|-----|------------|
| `src/engine/codegen/x86_64/op_simd.zig`      | 4694 | +135% |
| `src/engine/codegen/x86_64/op_simd_test.zig` | 2700 | +35%  |
| `src/engine/codegen/x86_64/inst_sse.zig`     | 2464 | +23%  |
| `src/engine/codegen/arm64/inst_neon.zig`     | 2323 | +16%  |
| `src/engine/codegen/arm64/op_simd.zig`       | 2307 | +15%  |

D-057 + D-065 jointly tracked the breach. The 2026-05-11 audit
identified the root cause: `scripts/file_size_check.sh` was
opt-in (no git pre-commit hook with hyphen-form filename;
`.githooks/pre_commit` underscore-form didn't fire). The hook
rename + warn-only-mode-pending-discharge landed
`9.9-h-14`-adjacent.

ADR-0030 (D-051 close — x86_64 emit.zig split) established the
precedent: extract inline tests as primary path, defer
fine-grained family split. The same shape applies here, plus
**source-side** splits because op_simd.zig's bloat is overwhelmingly
in handler bodies (not tests).

## Decision

3-way per heavy file, single ADR covering both arches.
**See `.dev/phase10_prep/track_b_source_split.md` §4.2 + §4.3**
for the partition tables. Summary:

- **x86_64**: op_simd.zig → {op_simd, op_simd_int, op_simd_fp};
  op_simd_test.zig → {op_simd_test, op_simd_test_int, op_simd_test_fp};
  inst_sse.zig → {inst_sse, inst_sse_packed, inst_sse_scalar}.
- **arm64**: op_simd.zig → {op_simd, op_simd_int, op_simd_fp};
  inst_neon.zig → {inst_neon, inst_neon_arith, inst_neon_lane_cmp}.

Migration plan: 6 chunks (one per current cap-breach file),
each chunk lands the split + import-fixup + test gate green.

Post-discharge target LOC: every file ≤ 1800 LOC (~90% of cap).

After the 6 chunks land, `scripts/file_size_check.sh` flips from
warn-only to hard-gate (the 2026-05-11 hook activation reverted
to warn-only pending D-057/D-065 discharge).

## Alternatives considered

### A — Two ADRs (one per arch, ADR-0054 x86_64 + ADR-0055 arm64)

Rejected. D-057 + D-065 share the same root cause (gate dormancy)
and the same discharge shape (3-way structural split mirroring
ADR-0030). Two ADRs would duplicate context and risk drift between
the two arches' final shape. One ADR keeps the design unified;
the 6 migration chunks are independent enough that they don't
need separate ADRs.

### B — Family-split (6+ files per arch, mirroring arm64's emit_test family)

Rejected as primary path (deferred to opportunistic Phase 12+
cleanup). Same reasoning as ADR-0030: each step's correctness
should be verifiable independently; family-split before the
structural 3-way split lands invites bisection complexity.

### C — Keep test files monolithic; only split source

Rejected. With 2700 LOC of tests, the test↔handler navigation
breaks once source is split into 3 files. Mirroring the split
preserves the 1:1 source↔test discoverability.

### D — Wait until Phase 11+ (folded into bench infra cohort per Track A)

Rejected. D-057/D-065 are independent of Track A's §9.10 →
Phase 11 migration. The cap breach blocks file_size_check.sh's
hard-gate restoration, which in turn allows further drift; this
is structural debt unrelated to bench infra.

## Consequences

### Positive

- D-057 + D-065 close jointly.
- `file_size_check.sh` flips back to hard-gate, preventing
  recurrence.
- Phase 10 (GC + EH + tail call + memory64) opens with all
  codegen files within cap; new SIMD-adjacent handlers added in
  Phase 10 won't trip cap warnings.
- Test↔source 1:1 navigation preserved.

### Negative

- 6 chunks of migration work. Each chunk is mechanical
  (Edit-move-imports-test-commit) but cumulative wall-clock
  ~3–5h of autonomous loop time.
- Some private helpers may need to become `pub` for cross-file
  test access (ADR-0030 precedent: `localDisp` went pub).
- Brief period where dispatch site (`op_simd_dispatch.zig` or
  equivalent) imports 3 modules instead of 1; readability tradeoff.

### Neutral / follow-ups

- Family-split of test files (e.g. `op_simd_test_int_arith.zig` /
  `op_simd_test_int_cmp.zig`) deferred to Phase 12+ opportunistic
  cleanup; not a debt row unless a consumer pattern surfaces.
- `inst_sse_packed.zig` and `inst_sse_scalar.zig` are encoder-
  only; no test split needed (encoders are tested via
  `op_simd_test*` already).

## References

- ADR-0030 (D-051 close — x86_64 emit.zig split; pattern template)
- D-057 (this ADR's primary discharge target — x86_64)
- D-065 (this ADR's secondary discharge target — arm64)
- ROADMAP §A2 / §14 (file-size cap)
- `.dev/phase10_prep/track_b_source_split.md` (this Track's
  deliverable — partition tables + migration plan)
- 2026-05-11 ADR audit SUMMARY §4.2 (root-cause: gate dormancy)
- 2026-05-11 lesson: `.dev/lessons/2026-05-11-…` (gate dormancy)

## Revision history

| Date       | Commit       | Summary                                          |
|------------|--------------|--------------------------------------------------|
| 2026-05-XX | `<backfill>` | Initial Decision; 3-way split per arch (6 chunks total) |
```

## §6. Migration plan — 6 chunks

Sized for the per-task TDD loop in autonomous `/continue` mode
post-prep. Each chunk lands in a single commit with test gate
green on Mac + OrbStack (windowsmini deferred per ADR-0049).

| Chunk        | Scope                                                                         | Estimated LOC moved | Risk          |
|--------------|-------------------------------------------------------------------------------|---------------------|---------------|
| 9.9-h-15     | x86_64 `op_simd.zig` → {op_simd, op_simd_int, op_simd_fp} source split        | ~3500 (moved)       | medium (152 emitI* + 54 emitF* import-site updates) |
| 9.9-h-16     | x86_64 `op_simd_test.zig` → {op_simd_test, op_simd_test_int, op_simd_test_fp} | ~2000 (moved)       | low (test-only) |
| 9.9-h-17     | x86_64 `inst_sse.zig` → {inst_sse, inst_sse_packed, inst_sse_scalar}          | ~1300 (moved)       | medium (165 encoders, mostly consumed by op_simd*) |
| 9.9-h-18     | arm64 `op_simd.zig` → {op_simd, op_simd_int, op_simd_fp}                       | ~1600 (moved)       | medium (mirror of 9.9-h-15) |
| 9.9-h-19     | arm64 `inst_neon.zig` → {inst_neon, inst_neon_arith, inst_neon_lane_cmp}      | ~1500 (moved)       | medium |
| 9.9-h-20     | Flip `scripts/file_size_check.sh` warn → gate; remove `(warn-only, see D-057)` note from `gate_commit.sh`; debt rows D-057 + D-065 discharge | ~30 (config) | low |

Chunks 15-19 are independent at file granularity but **must
sequence after Track A/C/D implementation chunks** (those
land first per prep mode contract). Chunk 20 is the gate
restore + debt close; must be the last of the 6.

### §6.1 Per-chunk recipe (Edit-move-import-test pattern)

For each split chunk (15-19):

1. Create new sibling file(s) with the partitioned handlers.
2. Move handler bodies from current file to new file(s) (`git
   mv` semantics manually — Edit-delete from source +
   Write-create new).
3. Update imports in:
   - `src/engine/codegen/<arch>/op_simd_dispatch.zig` (or
     equivalent dispatch site)
   - Any other consumer (likely `src/engine/codegen/<arch>/
     emit.zig` directly references some `emitI*` handlers in
     Phase 9 paths)
4. Make 0–2 private helpers `pub` if cross-file calls require
   (per ADR-0030 `localDisp` precedent).
5. Run `zig build test` + parallel OrbStack gate.
6. Commit `refactor(p9-close): §9.9 / 9.9-h-{N} — split <file>
   per ADR-0054`.

## §7. Effect on Tracks C / D + Phase 10 entry

- **Track C (ADR-0029 path A vs B)** is orthogonal — skip
  vocabulary decision unaffected.
- **Track D (Phase 10 transition gate doc)**: gate doc's "code
  hygiene" §3 checklist should include "all file_size_check
  hard-cap breaches resolved (D-057 / D-065 closed)" as one
  exit checkbox. This Track's discharge IS one of Phase 10
  entry's checklist items.
- **Phase 10 chunk count budget**: 6 chunks of migration land
  before §9.10/§9.11/§9.12 close. Compared to Track A's
  Option (3) net cost (1 chunk for §9.10 migration), Track B
  is the **single largest prep-driven implementation effort**.

## §8. Open questions for user

1. **3-way vs 4-way granularity for x86_64 op_simd.zig**:
   proposed 3-way leaves `op_simd_int.zig` at ~1900 LOC (close
   to soft cap). Would you prefer a 4-way split now
   (`op_simd_int_arith.zig` + `op_simd_int_cmp_lane.zig`)?
   Tradeoff: more files now vs. faster soft-cap re-breach in
   Phase 10.
2. **Single ADR-0054 vs ADR-0054 + ADR-0055**: proposed single
   ADR covering both arches. OK or prefer separation?
3. **Test family split scope**: proposed 3-way test split
   mirrors source. Want to also split test-only sub-families
   (e.g. `op_simd_test_int_cmp.zig` separate from
   `op_simd_test_int_arith.zig`) in the same chunk, or defer to
   opportunistic Phase 12+ cleanup per ADR-0030 precedent?
4. **Naming**: `op_simd_int.zig` / `op_simd_fp.zig` proposed.
   Alternative names considered: `op_simd_integer.zig` /
   `op_simd_float.zig` (more explicit), or
   `op_simd_intops.zig` / `op_simd_fpops.zig` (compact). The
   `_int` / `_fp` shape matches existing `emit_test_int.zig` /
   `emit_test_float.zig` precedent — recommend keeping.
5. **Helper visibility**: the deeper-private helpers
   (`emitV128IntCmpSigned`, `emitV128FpMin`, etc.) currently
   `fn` (file-private). After split, the int handlers in
   `op_simd_int.zig` call `emitV128IntCmpSigned` which now lives
   either in `op_simd.zig` (foundation) or in `op_simd_int.zig`
   (callsite-local). Proposed: keep cmp helpers in
   `op_simd_int.zig` (single-arch use); cross-class helpers
   (`emitV128IntBinop`, `v128MemPrologue`) stay in `op_simd.zig`
   and become `pub`. OK?

## §9. Decision record

| Date       | Decision | Recorded by |
|------------|----------|-------------|
| (pending)  | TBD      | (user review) |

## §10. References

- `.dev/decisions/0030_x86_64_emit_test_split.md` (precedent —
  D-051 close)
- `.dev/debt.md` D-057 (x86_64 hard-cap breach), D-065 (arm64
  hard-cap breach)
- `.dev/phase10_prep.md` §"Track B"
- `.dev/phase10_prep/track_a_9.10_scope.md` (Track A — sibling
  prep deliverable)
- ROADMAP §A2 / §14 (file-size cap)
- `src/engine/codegen/{x86_64,arm64}/{op_simd,inst_*}.zig`
  (the 5 files this Track partitions)
- `scripts/file_size_check.sh` (gate; currently warn-only
  pending Track B discharge)
- `scripts/gate_commit.sh` (per-commit wrapper)
- 2026-05-11 ADR audit SUMMARY §4.2 (root-cause analysis)
