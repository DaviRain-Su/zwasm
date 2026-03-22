# zwasm Development Memo

Session handover document. Read at session start.

## Current State

- Stages 0-46 + Phase 1, 3, 5, 8, 11, 15 complete. **v1.6.0** (tagged 503e73a).
- Spec: 62,263/62,263 Mac+Ubuntu+Windows (100.0%, 0 skip). E2E: 792/792. Real-world: 50/50.
- Wasm 3.0: all 9 proposals. WASI: 46/46 (100%). WAT parser complete.
- JIT: Register IR + ARM64/x86_64 (macOS, Linux, Windows x86_64). Size: 1.22MB stripped.
- **Windows x86_64**: First-class support (D129, PR #8). platform.zig abstraction,
  VEH guard pages, Win64 ABI, HostHandle WASI, Python test runners, CI 3-OS.
- **C API**: `libzwasm` — 25 exported functions (D126). c_allocator + ReleaseSafe default.
  Issue #11 fixed (Zig GPA PIC bug). 64-test FFI suite via dlopen.
- **Rust FFI example**: PR #12 merged. edition 2024, CI integrated.
- **Conditional compilation**: `-Djit=false`, `-Dcomponent=false`, `-Dwat=false` (D127).
- **main = stable**: v1.6.0+. ClojureWasm updated to v1.5.0.

## Current Task

**Phase 19: JIT Reliability — differential testing + fuel check**

Goal: make JIT a verifiably correct optimization layer over the interpreter.

- [ ] JIT differential testing infrastructure (interp vs JIT comparison)
- [ ] JIT fuel/deadline check at back-edges (replaces jitSuppressed())
- [ ] W35 ARM64 JIT OOB investigation (unpin CI Rust)

### Design Principles

1. **Interpreter = source of truth**. JIT must produce identical results.
2. **Differential testing** catches JIT-only bugs automatically.
3. **Incremental**: each step independently committable, all gates pass.
4. **No existing behavior removed** — only new verification added.

## Handover Notes

### JIT fuel/timeout suppression — current fix vs proper solution
- **Current fix**: `jitSuppressed()` disables JIT entirely when `fuel != null`. Simple, correct, zero impact on normal execution.
- **Proper solution**: Emit fuel/deadline checks at JIT loop back-edges (like wasmtime). This preserves JIT performance even with fuel/timeout.
  - wasmtime uses negative-accumulation fuel (increment toward 0, sign check) + epoch-based timeout (atomic counter at loop headers).
  - zwasm JIT caches `vm_ptr` in x20 (ARM64) — inline `vm->fuel` decrement + conditional trampoline exit is feasible.
  - Separate future task. See `@./private/pr6-timeout-review.md` §Fix Options and wasmtime research in `~/Documents/OSS/wasmtime/crates/cranelift/src/func_environ.rs`.
- **Flaky compat tests**: W36 in checklist.md — `go_crypto_sha256`/`go_regex` intermittent DIFF on base code (pre-existing, likely W35-related).

### Issue #11 root cause (2026-03-22)
- Zig 0.15 GPA crashes in Debug-mode shared libraries on Linux x86_64 (PIC codegen).
- Fix: c_allocator (libc malloc) + library builds default to ReleaseSafe.
- Zig build system also has shuffle bug with same-named artifacts → shared-lib/static-lib split.

## References

- `@./.dev/roadmap.md` (future phases), `@./.dev/roadmap-archive.md` (completed stages)
- `@./private/future/03_zwasm_clojurewasm_roadmap_ja.md` (integrated roadmap)
- `@./.dev/references/allocator-injection-plan.md` (Phase 11 design + tasks)
- `@./.dev/decisions.md`, `@./.dev/checklist.md`, `@./.dev/spec-support.md`
- `@./.dev/jit-debugging.md`, `@./.dev/bench-strategy.md`
- External: wasmtime (`~/Documents/OSS/wasmtime/`), zware (`~/Documents/OSS/zware/`)
