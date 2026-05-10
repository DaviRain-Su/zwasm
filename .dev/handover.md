# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.7 row — Phase 9 active.
3. `.dev/debt.md` — D-055 / D-057 + 10 `blocked-by:` rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: simd ops, x86_64 SSE/SSE4.1/SSE4.2, ADR-0041 §5).
5. `.dev/decisions/0041_simd_128_design.md` (SSE4.2 baseline post-9.7-m
   amendment).

## Current state — Phase 9 / §9.7 in-flight (9.7-a..az landed); **9.7-ba v128.load_lane/store_lane NEXT**

9.7-az: 2 ops (commit `b5fc6454`) — v128.load{32,64}_zero.
Single-instruction MOVSS/MOVSD memory load (scalar mem-form
already zero-extends upper bits per Intel SDM, exactly matches
Wasm load*_zero). No new encoders. 223 SIMD ops handled total.
3-host green.

**Next — 9.7-ba**: v128.load_lane + v128.store_lane × {8,16,32,64}
(8 ops). Pop 2 (idx + v128) for store, 2 (idx + v128) for load
+ push v128. Lane immediate in payload (per existing 9.7-e/f/g
lane-access pattern). Recipe per cranelift:
- load_lane: load N bytes from mem into a scratch xmm via
  PINSR{B/W/D/Q} mem-form, OR via GPR roundtrip (MOVZX +
  PINSR{B/W/D/Q} reg-form). Result merges into the input v128
  at the specified lane.
- store_lane: PEXTR{B/W/D/Q} the lane to a GPR, then MOV
  byte/word/dword/qword [mem], r.

Existing encoders: PINSR/PEXTR{B/W/D} reg-form (9.7-e/f/g) +
PEXTR Q (9.7-aw). Need: maybe mem-form variants (or rely on
GPR roundtrip via existing reg-form). Plan: GPR roundtrip
(no new encoders) — simpler for the chunk; cranelift mem-form
is a perf nicety we can revisit in §9.10.

Sub-chunks remaining:
- 9.7-ba: load_lane / store_lane × 8 (~8 ops)
- 9.7-bb: load*x*_s/u extending loads × 6

After those (~14 ops), §9.7 row + §9.8 row (overlapping scope)
close together via §18 ADR or scope merge.

Subsequent: §9.9 (simd.wast wired in, fail=skip=0), §9.10
(smoke benches + gap analysis), §9.11 (audit + SHA backfill),
§9.12 (open Phase 10).

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-055** (x86_64 prologue inject) — blocked-by D-052 prologue
  extract.
- **D-057** (op_simd.zig hard-cap, now ~4070 LOC) — blocked-by
  ADR for source-split landing. Discharge requires ADR mirror
  of ADR-0030; deferred until §9.7 row close.
- 10 `blocked-by:` rows: D-007/D-010/D-016/D-018/D-020/D-021/
  D-022/D-026/D-028/D-052 — barriers all hold this resume.

Closed Phase 8b artefacts (preserved for Phase 12 + Phase 15)
live in git: ADRs 0035-0040, lessons in `.dev/lessons/INDEX.md`,
code in `src/ir/coalesce/`, regalloc.zig LIFO free-pool,
`src/engine/codegen/aot/`. `git log` is authoritative.

**Phase**: Phase 9 (SIMD-128, ADR-0041 — SSE4.2 baseline).
§9.5 [x] (ARM64 NEON pt 1), §9.6 [x] (ARM64 NEON pt 2),
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..az landed; 9.7-ba
NEXT; ~14 v128 memory ops still unhandled before §9.7 close).
**Branch**: `zwasm-from-scratch`。
