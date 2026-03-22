# zwasm Development Memo

Session handover document. Read at session start.

## Current State

- Stages 0-46 + Phase 1, 3, 5, 8, 11, 15, **19** complete. **v1.6.0+** (main dd8003b).
- Spec: 62,263/62,263 Mac+Ubuntu+Windows (100.0%, 0 skip). E2E: 792/792. Real-world: 50/50.
- Wasm 3.0: all 9 proposals. WASI: 46/46 (100%). WAT parser complete.
- JIT: Register IR + ARM64/x86_64. Fuel check at back-edges (Phase 19.2).
- **C API**: c_allocator + ReleaseSafe default (#11 fix). 64-test FFI suite.
- **CLI**: `--interp` flag for interpreter-only execution (Phase 19 debug tool).
- **main = stable**. ClojureWasm updated to v1.5.0.

## Current Task

**W35: JIT OOB fix** (Phase 19.3, branch `fix/w35-arm64-jit-oob`)

### Key Findings (2026-03-22, updated)

W35 was **doubly misdiagnosed**. The original "JIT-only" diagnosis was wrong, AND the
re-diagnosis "interpreter bug" was also wrong. It is a **JIT codegen bug** exposed by
a `--interp` flag bug that allowed JIT to run even in interpreter-only mode.

**Root cause chain:**
1. `--interp` flag (`force_interpreter`) only checked in `callFunction` top-level,
   NOT in `doCallDirectIR`. Sub-calls within IR execution still used JIT. **FIXED.**
2. `i32.store16` JIT access_size was 1 (should be 2) — bounds check off-by-one. **FIXED.**
3. **ARM64 JIT `emitGlobalSet` clobbers value register**: When reg_count > 20,
   vreg r21 maps to x1. `emitGlobalSet` wrote global_idx to w1 BEFORE reading
   the value from r21, getting 0 instead of the correct stack pointer.
   Fix: read value into x2 FIRST, then set up ABI args (x0, x1). **FIXED.**

**Evidence:**
- `--interp` (with fix) works correctly for both 1.92 and 1.93 binaries
- RegIR interpreter (no JIT) works correctly
- JIT-only for func 63 alone reproduces the crash
- Binary search: all other 15 JIT functions are fine, only func 63 is buggy
- Func 63 has 23 vregs (= MAX_PHYS_REGS): r14-r22 → x2-x7, x0-x1, x17
- **x86_64 JIT works correctly** — bug is **ARM64-specific**
- ARM64 codegen looks correct on manual review — bug is subtle
- 1.92 binary has identical IR for VacantEntry::insert (func 65) with same 23 regs
  but different instruction ORDER at pc=85-92. Both JIT binaries are 1636 bytes.
- 1.92 works, 1.93 doesn't. The difference: in 1.93, i64.load/store comes BEFORE
  const32/i32.add/i32.load/i32.store at pc=85-92 (rustc reordered these).
- Ruled out: liveness analysis, spillCallerSavedLive (conservative also crashes),
  isConstAddrSafe, scratch_vreg cache, tryEmitBinopImm32, trampoline fast path

### Investigation Next Steps

1. **Memory write comparison**: Add JIT store hook for func 63 to log every
   (addr, value, size) triplet. Compare with RegIR execution to find the
   divergent store. This is the most direct path to the root cause.
2. **Disassemble pc=85-92 region**: Verify ARM64 codegen for the reordered block
   in 1.93 vs 1.92. Focus on register allocation decisions and physical register
   reuse patterns.
3. **Create minimal .wat reproducer**: Extract func 63 + callees, or craft a synthetic
   function with 23 vregs and the same instruction pattern.
4. **Fix**: ARM64-specific codegen issue (likely in instruction encoding or register
   allocation for high-numbered vregs x0-x7 range)
5. **Unpin CI, Gate**: spec/e2e/real-world/FFI all pass

### Fixes Applied (uncommitted)

1. `vm.zig:doCallDirectIR` — check `self.force_interpreter` before JIT dispatch
2. `jit.zig:2751` — `i32.store16` access_size 1→2

### Remaining Workarounds

| Workaround              | Status          | Plan                                        |
|--------------------------|-----------------|---------------------------------------------|
| CI Rust pinned 1.92.0   | W35 blocks      | Fix JIT bug → unpin                         |
| jitSuppressed(deadline) | Active          | Epoch-based check (future)                  |
| W36 flaky go compat     | May be W35      | Investigate after W35 fix                   |

## Handover Notes

### Phase 19 (completed, merged dd8003b)
- `force_interpreter` flag + 4 differential tests (interp vs JIT comparison)
- JIT fuel: back-edge decrement (jit_fuel i64) + shared exit stub
- `jitSuppressed()` no longer blocks JIT for fuel (only deadline)
- `--interp` CLI flag added (branch `fix/w35-arm64-jit-oob`, not yet merged)

### Issue #11 root cause (2026-03-22)
- Zig 0.15 GPA crashes in Debug-mode shared libraries on Linux x86_64 (PIC codegen)
- Fix: c_allocator + library builds default to ReleaseSafe

### PR #12 (Rust FFI example, merged)
- edition 2024, CI integrated, book en/ja updated

## References

- `@./.dev/roadmap.md` — Phase 19.3 has the investigation plan
- `@./.dev/checklist.md` — W35 has detailed reproduce steps
- `@./.dev/jit-debugging.md` — JIT debug techniques (dump, objdump)
- `@./.dev/decisions.md`, `@./.dev/spec-support.md`
- External: wasmtime (`~/Documents/OSS/wasmtime/`), zware (`~/Documents/OSS/zware/`)
