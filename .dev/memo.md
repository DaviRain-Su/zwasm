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

**W35: Interpreter OOB fix** (Phase 19.3, branch `fix/w35-arm64-jit-oob`)

### Key Finding (2026-03-22)

W35 was **misdiagnosed as JIT-only**. It is an **interpreter correctness bug**:
- Both `--interp` and JIT crash with OOB on serde_json built with rustc 1.93.1
- wasmtime runs the same wasm correctly
- `--interp` crashes earlier (2 lines output) than JIT (6 lines)
- serde_json built with rustc 1.92.0 works fine on both paths

### Investigation Plan

1. **Diff wasm binaries**: `wasm-tools dump /tmp/serde_json_1.92.wasm` vs `_1.93.wasm`
   - Both already built at `/tmp/serde_json_1.92.wasm` (208KB) and `/tmp/serde_json_1.93.wasm` (203KB)
2. **Binary search function**: which function causes OOB?
   - Add per-function call tracing, or use fuel to step through execution
   - `wasm-tools strip` to remove functions, `wasm-tools mutate` to isolate
3. **Minimal reproducer**: reduce to single .wat function
4. **Fix**: interpreter opcode handler → verify JIT also fixed
5. **Unpin CI**: `.github/tool-versions` RUST_VERSION → latest stable
6. **Gate**: spec/e2e/real-world/FFI all pass, serde_json 1.93.1 works

### Remaining Workarounds

| Workaround               | Status          | Plan                                         |
|---------------------------|-----------------|----------------------------------------------|
| CI Rust pinned 1.92.0    | W35 blocks      | Fix interpreter bug → unpin                  |
| jitSuppressed(deadline)  | Active          | Epoch-based check (future)                   |
| W36 flaky go compat      | May be W35      | Investigate after W35 fix                    |

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
