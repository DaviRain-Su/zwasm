# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Fresh-session start here

**Authoritative remaining-work source**:
[`phase9_close_master.md`](./phase9_close_master.md)
§5.3a (Phase A + Phase B 2-stage iteration discipline).

**Mandatory before any §9.x [x] flip**:
`bash scripts/check_phase9_close_invariants.sh --gate`.

**Phase 9 close gate (mac-host)**: **18/18 PASS** (was 17/18
pre-cycle-20). I1 satisfied — no SKIP-WIN64-* emission.

**Test state**:
- Mac aarch64 `zig build test` / `test-all`: green.
- ubuntu test-all: green at HEAD=39eac7ba (verify next resume
  Step 0.7 for HEAD post-this-commit-pair).
- windowsmini test-all: simd_assert green (13351/0 fail);
  spec_assert_non_simd has D-167 1+arg multi-result fails
  (~10-11 directives across `break-br_if-num-num` /
  `break-br_table-num-num` / `break-br_table-nested-num-num` /
  `add64_u_with_carry`). NOT blocking Phase 9 close gate.

Closed cycles 10-25: `git log --grep="cycle 2[0-5]\|A1\|A2\|A4"`.

## Cycles 26-30 progress

- 26-28: D-167 spike step 1 COMPLETE — 3 wrapper shapes
  Mac-green (1-arg+2-int, 3-arg+2-int, 1-arg+3-int MEMORY)
  via TDD red→green; `git log --grep="D-167 shape"`.
- 29: D-167 wire-up attempt hit entry.zig EXEMPT-CAP EXCEEDED
  (2521 vs 2500). Reverted; filed **D-168**.
- 30: D-168 options (a/b/c) reject per ADR-0099 N3-shallow;
  drafted **ADR-0108** (CATALOG-EXEMPT cap 4000 tier) for
  the option (d) path. D-168 → `blocked-by: ADR-0108 Accept`.

## Remaining work

### Autonomous-eligible (next session pick from here)

- (cycle 31 finding: body-side cycle 2c Win64 MEMORY-class
  IS already supported per D-165 close at `75f96dee` /
  `99a047f6` 2026-05-23 — see emit_setup.zig:104 +
  emit.zig:209. Stale claims in wrapper_thunk.zig comments
  + spike README + prior handover removed. **D-167 wire-up
  shape 3/3 now only blocks on D-168 → ADR-0108 Accept**,
  same as shapes 1-2.)
- After ADR-0108 Accept: single-cycle wire-up of all 3
  shapes in entry.zig (`callI32i32_i32` / `callI32i64_i32` /
  `callI64i32_i64i64i32` / `callI32i32i64_i32`) +
  `invokeBufWin64Args` helper + windowsmini integration
  verify.

### User-gated (this session)

- **ADR-0108** — `Status: Proposed → Accepted` flip needed
  to unblock D-168 → D-167 wire-up shape 1-2. Review
  uniform-pattern-catalog tier (cap 4000) + alternatives
  in `.dev/decisions/0108_uniform_pattern_catalog_cap.md`.

### User-gated

- **A3 D-079 (ii)** — blocked-by: ADR-0107 Accept. Structural
  `Runtime.globals` byte-buffer migration (13 callsites + JIT
  codegen). ADR proposed; awaiting collab review.
- **§9.13 hard gate** — ADR-0105 + ADR-0106 `Status: Accepted`
  flip via Track D collab review + Phase B `[x]` re-flip with
  cited SHAs (per `phase9_close_master.md` §5.3a Phase B).

## Cold-start procedure

Per `/continue` SKILL.md Resume Steps 0.5 / 0.7 / 0.8. Lesson
scan: `2026-05-23-d163-d166-shared-root-cause.md` for Win64
multi-result context. D-167 is sole `now` row (sub-shape 2/3
next per "Remaining work" above).

## See

- [`phase9_close_master.md`](./phase9_close_master.md) §5.3a + §6.
- `private/spikes/d167-win64-multi-arg-wrapper/README.md`.
- ADR-0104 Revision 2026-05-23 (Phase 9 真スコープ).
- ADR-0107 Proposed (D-079 (ii) byte-buffer globals).

windowsmini SSH-reachable per ADR-0049. Debug infra:
`debug_jit_auto/SKILL.md` Recipes 15-17.
