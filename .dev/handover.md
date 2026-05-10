# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.9 row — Phase 9 active.
3. `.dev/debt.md` — D-063 / D-066 / D-069 + D-065 + 11 `blocked-by:` rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain.
5. `.dev/decisions/0041_simd_128_design.md` (SSE4.2 baseline).

## Current state — Phase 9 / §9.9 in-flight; **9.9-g-7 NEXT — SIMD int shift family (D-069): validator opSimdShift + lower-side wiring + arm64 emit + simd_bit_shift corpus**

9.9-g-6 (`<pending-sha>`): wired 12 SIMD int extend sub-ops
in lower.zig (134..137 / 166..169 / 199..202); added
simd_int_to_int_extend to corpus. Mac aarch64 simd_assert:
+24 PASS (10475→10499), one transient FAIL (D-069).

**Mac aarch64 simd_assert_runner totals after 9.9-g-6**:
**10499 PASS** / **5 FAIL** / 2165 SKIP (over 20 manifests).
OrbStack test-all green; windowsmini gate not yet run this
round (heuristic-deferred).

Residual 5 fails:
- simd_int_to_int_extend.0 StackUnderflow (D-069 — shift
  family validator+lower+emit gap).
- 2× simd_const call_indirect Trap (D-063, spike-pending).
- simd_const.388 BadValType (parse-side gap).
- simd_lane f64x2_extract_lane mismatch (D-066).

**Next 9.9-g-7 — SIMD int shift family (D-069 discharge)**:
- Validator: add `opSimdShift` (pop i32, pop v128, push v128).
- Move 138..140 / 171..173 / 203..205 from binop list to
  opSimdShift.
- Lower.zig: wire 9 sub-ops to existing ZirOps
  (`.i*x*.shl`/`shr_s`/`shr_u`).
- ARM64 emit: 9 handlers using NEON SSHL/USHL with DUP of
  the i32 shift-amount. New encoders: `encDup{16B,8H,4S,2D}
  FromW` (DUP from W into all lanes; some pre-exist) +
  `encSshl{16B,8H,4S,2D}` + `encUshl{16B,8H,4S,2D}` (8 new
  encoders or shared via a size-paramatised helper). Plus
  shr is NEON `(SS|US)HL` with negative shift amount (per
  Arm IHI 0055 §C7.2.331 / §C7.2.412) — synthesise via
  `NEG W<amt>; DUP V<dst>.<T>, W<amt>; SSHL V<d>, V<src>,
  V<dst>` (or use SSRA when constant-shift).
- Simd_bit_shift corpus add.

After D-069 closes: D-066 spike → D-063 spike → §9.10 (smoke
benches) → §9.11 (audit) → §9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-063** (simd_const call_indirect v128 Trap) — `now`.
- **D-066** (simd_lane f64x2_extract_lane mismatch) — `now`.
- **D-069** (SIMD int shift family unwired) — `now`.
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
9.9-f-1..8 + 9.9-g-1..6 landed; 9.9-g-7 NEXT).
**Branch**: `zwasm-from-scratch`。
