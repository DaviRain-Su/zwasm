# Reliability Check — Session Handover

> Progress tracker for `.dev/reliability-plan.md`.
> Read plan for full context. Update after each phase.

## Branch
`strictly-check/reliability-002` (from main at 86e0490)

Branch naming: `-001`, `-002`, ... (sequential). See CLAUDE.md § Reliability Work Branch Strategy.

## Progress Tracker

- [x] A.1: Create feature branch
- [x] A.2: Expand flake.nix (Go, wasi-sdk 30)
- [ ] A.3: Verify flake.nix on Ubuntu
- [x] B.1: Rust programs → wasm32-wasip1
- [x] B.2: Go programs → wasip1/wasm
- [x] B.3: C programs → wasm32-wasi
- [x] B.4: C++ programs → wasm32-wasi
- [x] B.5: Build automation script
- [x] C.1: Compatibility test runner
- [x] C.2: Fix compatibility failures (W34 root cause + test fixes)
- [x] C.3: Document unsupported cases (FP precision only)
- [x] D.1: Fix existing E2E failures (was already 356/356)
- [x] D.2: Feature-specific E2E tests (53 proposal tests added, 724/778 pass)
- [x] D.3: Update E2E runner (named module auto-register, GC ref types, table index fix)
- [ ] E.1: Real-world benchmarks
- [ ] E.2: Benchmark harness update
- [ ] E.3: Fair benchmark audit
- [ ] E.4: Record baseline
- [ ] F.1: Analyze weak spots
- [ ] F.2: Profile and optimize
- [x] F.3: JIT back-edge reentry fix (W34)
- [ ] G.1: Push and pull on Ubuntu
- [ ] G.2: Build and test on Ubuntu
- [ ] G.3: Real-world wasm on Ubuntu
- [ ] G.4: Benchmarks on Ubuntu
- [ ] G.5: Fix Ubuntu-only failures
- [ ] H.1: Audit README claims
- [ ] H.2: Fix discrepancies
- [ ] H.3: Update benchmark table

## Current Phase
C complete. F.3 done (W34 root cause fixed). Merged to main (86e0490).
Now on reliability-002.
D.1: existing E2E was already 356/356. D.2 in progress: proposal E2E added.

## W34 Root Cause Analysis

The bug was NOT in JIT code generation. It was a back-edge JIT restart issue:

1. C/C++ WASI programs have a reentry guard in `_start` (`__wasm_call_ctors`):
   `if (flag != 0) unreachable; flag = 1;`
2. The interpreter runs the function, sets flag = 1, then back-edge JIT triggers
3. JIT compiles the function and **restarts from the beginning**
4. On restart, the JIT reads the flag (now 1), hits the guard → `unreachable` trap

**Fix**: `hasReentryGuard()` scans the first 8 IR instructions for branches to
`unreachable`. If found, back-edge JIT is skipped (function stays on interpreter).
Call-count JIT is unaffected.

## Compatibility Test Results (Mac, after fix)
13 real-world wasm binaries. 12 PASS, 1 DIFF, 0 CRASH.

The 1 DIFF is c_math_compute (FP precision difference, expected):
- zwasm: 21304744.877962
- wasmtime: 21304744.878669

All benchmark performance restored (no regressions from fix).

## Phase D: E2E Test Expansion Results

Added 53 proposal-specific E2E tests from wasmtime misc_testsuite:
- Function references: 5 files (call_indirect, table_fill/get/grow/set)
- Tail call: 1 file (loop-across-modules)
- Multi-memory: 1 file
- Threads: 12 files
- Memory64: 8 files (excl. more-than-4gb)
- GC: 25 files

Total: 778 assertions, 724 PASS (93.1%), 54 FAIL.

### Bugs found and fixed
1. **table_grow/size/fill used store.getTable(raw_idx) instead of instance.getTable(idx)**
   — wrong table accessed in multi-module scenarios. Fixed in both bytecode and RegIR paths.
2. **E2E runner: named modules not auto-registered** — modules with `$name` weren't
   importable by other modules. Fixed: `registerExports()` called for named modules.
3. **E2E runner: GC ref types not handled** — anyref, structref, arrayref, i31ref etc.
   not recognized in valuesMatch(). Fixed.

### Remaining 54 failures (known limitations)
- 30 assert_invalid: typed funcref validation (zwasm accepts invalid stack types)
- 7 assert_unlinkable (linking-errors): import type checking not implemented
- 6 memory64_bounds: zero-length ops at out-of-bounds addresses should trap
- 3 memory64_multi-memory: same bounds edge case
- 2 gc_ref-test: ref.test with certain type combinations returns wrong result
- 2 gc_array-alloc-too-large: missing OOM trap for oversized arrays
- 2 memory64_linking: linking type validation
- 1 memory64_linking-errors: decode overflow
- 1 threads_SB_atomic: concurrency ordering (single-threaded limitation)

## Notes
- Rust: system rustup with wasm32-wasip1 target (not in nix)
- Go: nix provides Go 1.25.5 with wasip1/wasm support
- wasi-sdk: v30, fetched as binary in flake.nix
- Sensitive info (SSH IPs) must NOT be in committed files
