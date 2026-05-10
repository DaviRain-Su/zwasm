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

## Current state — Phase 9 / §9.7 in-flight (9.7-a..ax landed); **9.7-ay v128.load*_splat NEXT**

9.7-ax: 2 ops (commit `df06b54e`) — v128.load + v128.store
foundation memory chunk. New encoder encMovupsMemBaseIdx
(SSE no-prefix MOVUPS, load 0F 10 / store 0F 11 with SIB
scale=1 base+index). emitV128Load + emitV128Store + shared
v128MemPrologue helper (RAX/RCX/RDX scratches; bounds_fixups
+ ADR-0028 trace.writeBounds uniformly wired with scalar).
uses_runtime_ptr prescan extended for v128.load/store. 217
SIMD ops handled total. 3-host green.

**Next — 9.7-ay**: v128.load{8,16,32,64}_splat (4 ops). Pattern:
load N-bit scalar from memory, broadcast to all lanes of the
v128 result.
- load8_splat: MOVZX r32, byte [mem]; MOVD xmm, r32; PSHUFB
  zero-mask broadcast (cranelift: PINSRB lane 0 + PSHUFB
  zero-broadcast).
- load16_splat: MOVZX r32, word [mem]; MOVD xmm, r32; PSHUFLW
  imm 0; PSHUFD imm 0.
- load32_splat: MOV r32, dword [mem]; MOVD xmm, r32; PSHUFD
  imm 0 (broadcast lane 0 to all 4 lanes).
- load64_splat: MOVQ xmm, qword [mem]; MOVDDUP / PSHUFD imm
  0x44 (broadcast lane 0 to lane 1).
Reuses 9.7-ax's v128MemPrologue with access_size = 1/2/4/8.
Foundation encoders mostly exist (PSHUFD/PSHUFB/MOVD/MOVQ);
likely need PSHUFLW + MOVDDUP encoders.

Sub-chunks remaining:
- 9.7-ay: load_splat × 4
- 9.7-az: load*_zero × 2 (load32/64 zero)
- 9.7-ba: load_lane / store_lane × 8 (load/store 8/16/32/64)
- 9.7-bb: load*x*_s/u extending loads × 6

Once those land, §9.7 row + §9.8 row (overlapping scope)
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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..ax landed; 9.7-ay
NEXT; ~20 v128 memory ops still unhandled before §9.7 close).
**Branch**: `zwasm-from-scratch`。
