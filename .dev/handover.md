# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.9 row — Phase 9 active.
3. `.dev/debt.md` — D-063 / D-066 / D-069 (residual) + D-065 + 11 `blocked-by:` rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/decisions/0041_simd_128_design.md` (SSE4.2 baseline).

## Current state — Phase 9 / §9.9 in-flight; **9.9-g-8 NEXT — ARM64 emit shr_s / shr_u (8 ops via NEG-then-(U|S)SHL synthesis); add simd_bit_shift to corpus**

9.9-g-7 (`<pending-sha>`): SIMD shift family — validator
opSimdShift + lower for 12 sub-ops + arm64 shl (4 ops). PLUS
critical off-by-one fix to §9.9-g-6 extend wiring (i16x8/i32x4
were misnumbered 134..137 / 166..169; spec says 135..138 /
167..170). +228 PASS (10499→10727), -1 FAIL (-1).

**Mac aarch64 simd_assert_runner totals after 9.9-g-7**:
**10727 PASS** / **4 FAIL** / 1937 SKIP (over 20 manifests).
OrbStack green; windowsmini gate not yet run this round.

Residual 4 fails (all pre-existing):
- 2× simd_const call_indirect Trap (D-063, spike-pending).
- simd_const.388 BadValType (parse-side gap).
- simd_lane f64x2_extract_lane mismatch (D-066).

**Next 9.9-g-8 — ARM64 shr_s / shr_u synthesis**:
- 4 new encoders `encSshl{16B,8H,4S,2D}` (Advanced SIMD
  vector SSHL — Arm IHI 0055 §C7.2.331).
- Shared helper `emitV128IntShr(ctx, dup_enc, shift_enc)`:
  `SUB W<tmp>, WZR, W<amt>; DUP V<scratch>.<T>, W<tmp>;
  (U|S)SHL Vd, Vsrc, V<scratch>`.
- 8 emit handlers (i*x*.shr_s + shr_u for 4 shapes).
- 8 dispatch arms in arm64/emit.zig.
- Add simd_bit_shift to NAMES + rebake.
- For i64x2: SUB X<tmp>, XZR, X<amt> (zero-extended W<amt>
  works for non-negative Wasm-mod-shift amounts).
- Likely +many-thousand PASS.

After D-069 closes: D-066 / D-063 spikes → §9.10 (smoke
benches) → §9.11 (audit + SHA backfill) → §9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-063** (simd_const call_indirect v128 Trap) — `now`.
- **D-066** (simd_lane f64x2_extract_lane mismatch) — `now`.
- **D-069** (shr_s/shr_u arm64 emit) — `now`; shl landed.
- **D-065** (arm64/inst_neon.zig 2050+ LOC > 2000 cap) —
  blocked-by ADR for source-split.
- **D-055** (x86_64 prologue inject) — blocked-by D-052.
- **D-057** (x86_64 op_simd.zig 4442 LOC hard-cap) —
  blocked-by ADR for source-split landing.
- 10 `blocked-by:` rows: D-007/D-010/D-016/D-018/D-020/D-021/
  D-022/D-026/D-028/D-052 — barriers all hold this resume.

Closed Phase 8b artefacts (preserved for Phase 12 + Phase 15)
live in git: ADRs 0035-0040, lessons in `.dev/lessons/INDEX.md`,
code in `src/ir/coalesce/`, regalloc.zig LIFO free-pool,
`src/engine/codegen/aot/`. `git log` is authoritative.

**Phase**: Phase 9 (SIMD-128, ADR-0041 — SSE4.2 baseline).
§9.5 [x] (ARM64 NEON pt 1), §9.6 [x] (ARM64 NEON pt 2),
§9.7 [x] (x86_64 SSE4.1+SSE4.2; 9.7-a..bb landed),
§9.8 [x] (scope absorbed per ADR-0044),
§9.9 in-flight (9.9-a..c + 9.9-d-1..7 + 9.9-e-1..2 +
9.9-f-1..8 + 9.9-g-1..7 landed; 9.9-g-8 NEXT).
**Branch**: `zwasm-from-scratch`。
