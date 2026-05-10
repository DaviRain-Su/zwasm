# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.7 row — Phase 9 active.
3. `.dev/debt.md` — D-055 + 9 `blocked-by:` rows (D-054 closed `b80cca3d`).
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: simd compare ops, x86_64 SSE/PCMPGT idioms, ADR-0041 §5
   baseline rationale).
5. `.dev/decisions/0041_simd_128_design.md` (SSE4.2 baseline post-9.7-m
   amendment; §5 + Alternative E hold the rationale).
6. `private/notes/p9-9.7-m-survey.md` (gitignored; cranelift recipe +
   adoption data) — only if revisiting the SSE4.2 baseline call.

## Current state — Phase 9 / §9.7 in-flight (9.7-a..as landed; D-054 closed); **9.7-at NEXT**

9.7-as: D-054 close. SysV x86_64 `frame_unaligned` was missing
`r15_save_bytes` (8). With outgoing_max_bytes=0 (no shadow
space), local 0 at [RBP-16] sat BELOW RSP and the next CALL's
pushed return address clobbered it (the 0xFD1BD386 garbage =
stack residue). Win64's 32-byte shadow space hid it. Fix is a
1-line + in emit.zig:278. OrbStack now strict 212/0/20 (was
211/1/20 with D-054 carry). 187 SIMD ops still handled
(D-054 close orthogonal to SIMD count).

**9.7-at NEXT** — `i32x4.trunc_sat_f32x4_u` (1 op, last of 4
deferred 9.7-ae u-variants). Cranelift recipe needs 3 scratch
xmms, exceeding zwasm's 2-scratch budget (XMM14/15). Two paths:
(a) ADR-grade extension to reserve a 3rd scratch xmm
    (e.g., XMM13). Affects regalloc XMM pool, abi.zig,
    inst.zig spill-aware machinery — broad change.
(b) Spill one scratch through stack: emit `MOVUPS [RBP-spill],
    XMM14` then reuse XMM14 + reload. Adds 4-6 instr per call
    but no infra change.
Recommend (b) for one-off use; if more 3-scratch ops arrive,
reconsider (a).

Subsequent: §9.7 close-out — backfill SHA pointers per phase-
boundary procedure, then **§9.7 / 7.13 hard gate** triggers
(per `.dev/phase8_transition_gate.md`). Loop pauses for
collaborative review.

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-054 CLOSED** (`b80cca3d`) — was OrbStack-only `as-loop-broke`
  FAIL; root cause was SysV x86_64 frame under-allocation; 1-line
  fix (`frame_unaligned` += `r15_save_bytes`).
- **D-055** (x86_64 prologue inject) — blocked-by D-052 prologue
  extract.
- 9 `blocked-by:` rows: D-007/D-010/D-016/D-018/D-020/D-021/D-022/
  D-026/D-028/D-052 — barriers all hold.

Closed Phase 8b artefacts (preserved for Phase 12 + Phase 15
reference) live in git: ADRs 0035-0040, lessons indexed in
`.dev/lessons/INDEX.md`, code in `src/ir/coalesce/`,
`src/engine/codegen/shared/regalloc.zig` (LIFO free-pool),
`src/engine/codegen/aot/`. No need to duplicate pointers here —
`git log` is the authoritative lookup.

**Phase**: Phase 9 (SIMD-128, ADR-0041 — SSE4.2 baseline post-9.7-m).
§9.5 [x] (ARM64 NEON pt 1), §9.6 [x] (ARM64 NEON pt 2),
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..as landed; D-054 closed; 9.7-at NEXT).
**Branch**: `zwasm-from-scratch`。
