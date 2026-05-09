# Session handover

> Read this at session start. **Replace** (not append) the `Current state`
> block + the `Active task` table at session end. Keep ≤ 100 lines.

## Next files to read on a cold start (in order)

1. `.dev/handover.md` (this file).
2. `.dev/ROADMAP.md` §9 Phase Status widget + §9.7 row — Phase 9 active.
3. `.dev/debt.md` — D-054 + D-055 + 9 other rows.
4. `.dev/lessons/INDEX.md` — keyword-grep for the active task domain
   (focus: simd compare ops, x86_64 SSE/PCMPGT idioms, ADR-0041 §5
   baseline rationale).
5. `.dev/decisions/0041_simd_128_design.md` (SSE4.2 baseline post-9.7-m
   amendment; §5 + Alternative E hold the rationale).
6. `private/notes/p9-9.7-m-survey.md` (gitignored; cranelift recipe +
   adoption data) — only if revisiting the SSE4.2 baseline call.

## Current state — Phase 9 / §9.7 in-flight (9.7-a..ar landed); **D-054 SPIKE FOLLOW-UP NEXT**

9.7-ar: x86_64 i8x16.shuffle via emit-time derived a-mask/b-mask
+ PSHUFB-pair + POR-merge (1 op, 7-instr recipe). Closes the
structural blocker from 9.7-al/am. Total SIMD ops handled: 187.

**SIDE-FINDING (this cycle)**: spike confirmed D-054 OrbStack
as-loop-broke FAIL is a HOIST PASS BUG (NOT Rosetta artefact) —
`ZWASM_NO_HOIST=1` makes OrbStack 212/0/20 green. Likely a
synthetic-local lifetime / SysV-caller-saved-reg interaction
around `call $dummy`. Updated D-054 with concrete discharge plan.

**9.7-as NEXT** — D-054 root-cause investigation + fix.
Investigation summary so far: code-read of hoist pass +
emit's local.set/local.get + SysV vs Win64 abi
(allocatable_gprs = RBX/R12/R13/R14, all callee-saved on
both ABIs — so vreg pool is NOT the bug source). Synthetic
local 0 is at [RBP-16] when uses_runtime_ptr=true; localDisp
math is correct. RBP non-volatile in both ABIs. So the bug
is NOT register choice, NOT disp offset, NOT prologue size.

**Action items next cycle (concrete):**
1. Build a Zig spike at `private/spikes/d054-jit-bytes/`
   that loads `test/spec/wasm-1.0-assert/unreachable/
   unreachable.0.wasm`, finds `as-loop-broke` function,
   compiles via `zwasm.compileWasm`, and dumps the per-
   function JIT bytes as hex.
2. Run via `orb run -m my-ubuntu-amd64 zig run …` to get
   Linux x86_64 bytes. Then run on Mac aarch64 (same code-
   gen path but different arch) — confirm the bytes are
   *identical* on Linux x86_64 vs Win x86_64 (windowsmini)
   to establish whether codegen diverges between ABIs.
3. If bytes are identical → bug is at execution-time (not
   codegen); investigate the call/return path for SysV-
   specific stack effects (e.g., runtime_ptr R15 save/
   restore around CALL, or ARG marshaling that overwrites
   a stack region overlapping with [RBP-16]).
4. If bytes differ → diff the per-ABI emit paths (most
   likely candidate: shadow-space alloc, or arg marshal
   stack allocation difference).
5. Per `.claude/rules/debug_jit.md` Recipe 1 (lldb -b),
   confirm faulting RIP / stack state on OrbStack.

Subsequent: 9.7-at (i32x4.trunc_sat_f32x4_u — needs 3 scratch
xmms; ADR-grade scratch-budget extension OR fall back to
spilling tmp to stack). Phase 7 close-out approaching:
~1-2 chunks + D-054 fix until 7.13 hard gate.

## Open structural debt (pointers — full list in `.dev/debt.md`)

- **D-054** (OrbStack-only as-loop-broke) — Rosetta JIT-emulation
  artefact; baseline 211/1/20 carried as known.
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
§9.7 in-flight (x86_64 SSE4.1+SSE4.2; 9.7-a..ar landed; D-054 fix or 9.7-as NEXT).
**Branch**: `zwasm-from-scratch`。
