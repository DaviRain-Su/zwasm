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
- K.x86: x86_64 JIT trunc_sat fix. Indefinite value detection for i32 case,
  subtract-2^63-and-add-back for i64 unsigned. Interpreter: floatToIntBits (IEEE 754).
  Ubuntu spec: 62150→62158/62158 (100%).

### Active / TODO

**Phase K: Performance optimization (target: all ≤1.5x wasmtime)**
- [x] K.2: JIT opcode coverage — select, br_table, trunc_sat, div-by-constant (UMULL+LSR)
- [x] K.3: FP optimization — FP-direct load/store, const-folded ADD/SUB (marginal on ARM64)
- [x] K.4: Self-call setup optimization — bypass shared prologue, skip reg_ptr memory sync
- [x] K.5: Benchmark re-recording on BOTH platforms (results below)

**Mac ARM64 benchmark status (quick run, vs wasmtime 41.0.1):**
- Non-blocked gap >1.5x: st_matrix 3.21x (regalloc, 35 vregs)
- Improved to ≤1.5x: tgo_mfr 1.21x (was 1.56x), st_fib2 1.34x (was 1.51x), gc_alloc 1.47x
- **Blocked**: rw_c_math 2.94x, rw_c_matrix 1.71x, rw_c_string 1.63x (OSR), gc_tree 4.10x (GC JIT)

**Ubuntu x86_64 benchmark status (quick run):**
- x86_64 JIT significantly slower than ARM64 on most benchmarks
- fib 3.05x, tak 3.30x, tgo_fib 3.22x, st_fib2 6.98x, tgo_list 4.87x, rw_c_math 4.89x
- x86_64 JIT lacks: div-by-constant (UMULL→MUL+SHR), self-call optimization
- Some wins: sieve 0.50x, nbody 0.71x, st_nestedloop 0.06x, tgo_rwork 0.53x

**Phase H: Documentation (LAST — requires Phase H Gate pass, see plan)**
- [ ] H.0: Phase H Gate — conditions 1-5,8 met. Conditions 6-7 (benchmarks ≤1.5x) blocked by:
  - Mac: st_matrix (regalloc), rw_c_* (OSR), gc_tree (GC JIT)
  - Ubuntu: x86_64 JIT needs optimization parity with ARM64
- [ ] H.1: Audit README claims
- [ ] H.2: Fix discrepancies
- [ ] H.3: Update benchmark table

## Next session: start here

1. **x86_64 JIT optimization**: Port ARM64 optimizations (div-by-constant, self-call) to x86_64.
2. **Phase H Gate blockers**: st_matrix (regalloc), OSR for rw_c_*, GC JIT for gc_tree.
3. After gates pass: Phase H (documentation audit).

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
