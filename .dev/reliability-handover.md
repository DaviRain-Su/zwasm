# Reliability — Session Handover

> Plan: `@./.dev/reliability-plan.md`. Rules: `@./.claude/rules/reliability-work.md`.

## Branch
`strictly-check/reliability-003` (from main at d55a72b)

## Progress

### ✅ Completed
- A-F: Environment, compilation, compat, E2E expansion, benchmarks, analysis, W34 fix
- G.1-G.3: Ubuntu spec 62,158/62,158 (100%). Real-world: all pass without JIT, 6/9 fail with JIT → Phase J
- I.0-I.7: E2E 792/792 (100%). FP precision fix (JIT getOrLoad dirty FP cache),
  funcref validation, import type checking, memory64 bulk ops,
  GC array alloc guard, externref encoding, thread/wait sequential simulation.
- J.1-J.3: x86_64 JIT bug fixes complete. All C/C++ real-world pass with JIT.
  Fixes: division safety (SIGFPE), ABI register clobbering (global.set, mem ops),
  SCRATCH2/vreg10 alias (R11 reserved), call liveness (rd as USE for return/store).

### Active / TODO

**Phase K: Performance optimization (target: all ≤1.5x wasmtime)**
- [x] K.2: JIT opcode coverage — select, br_table, trunc_sat, div-by-constant (UMULL+LSR)
- [x] K.3: FP optimization — FP-direct load/store, const-folded ADD/SUB (marginal on ARM64)
- [x] K.4: Self-call setup optimization — bypass shared prologue, skip reg_ptr memory sync
- [ ] K.5: Benchmark re-recording on BOTH platforms

**Remaining gaps (non-blocked, > 1.5x wasmtime):**
- st_matrix 3.5x: register pressure (35 vregs, 12 spills) → needs regalloc improvement
- st_fib2 1.51x (was 1.6x): self-call still ~13 instrs overhead vs wasmtime ~5
- tgo_mfr 1.56x: MOV overhead from SSA lowering → needs better regalloc
- tgo_strops 1.1x (was 1.5x, fixed by div-by-constant)
- **Blocked**: gc_tree/gc_alloc (GC not JIT'd), rw_c_math/c_matrix/c_string (W34 needs OSR)

**Phase H: Documentation (LAST — requires Phase H Gate pass, see plan)**
- [ ] H.0: Phase H Gate — all 9 conditions verified (see `@./.dev/reliability-plan.md`)
- [ ] H.1: Audit README claims
- [ ] H.2: Fix discrepancies
- [ ] H.3: Update benchmark table

## Next session: start here

1. **Phase K: Performance optimization** — reduce benchmark gaps to ≤1.5x wasmtime.
2. After K: Phase H (documentation audit).

## x86_64 JIT status (Phase J complete)
All C/C++ real-world programs pass with JIT on Ubuntu x86_64:
- cpp_string_ops: FIXED (division safety + register clobbering)
- c_string_processing: FIXED (SCRATCH2/vreg10 alias, global.set clobbering)
- cpp_vector_sort: FIXED (SCRATCH2/vreg10 alias + call liveness analysis)
- c_math_compute, c_matrix_multiply: PASS
- c_hello_wasi: EXIT=71 (WASI issue, not JIT — same with --profile)
- go_*: EXIT=0 but no output (WASI compat issue, not JIT — same with --profile)

## Benchmark gaps (Phase K status)
**Improved**: tgo_strops 1.51x→1.1x (div-by-constant). fib 61→49ms (-20%), tak 10→8ms (-20%), st_fib2 1.06→0.99s (-6%).
**Blocked (needs OSR/GC JIT)**: rw_c_math 4.1x, rw_c_matrix 2.7x, rw_c_string 2.0x, gc_tree 5.0x, gc_alloc 2.4x.
**Needs arch changes**: st_matrix 3.5x (regalloc), st_fib2 1.51x (call overhead), tgo_mfr 1.56x (regalloc).
