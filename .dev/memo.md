# zwasm Development Memo

Session handover document. Read at session start.

## Current State

- Stages 0-46 complete. v1.2.0 released. ~50K LOC, 521 unit tests.
- Spec: 62,263/62,263 Mac+Ubuntu (100.0%, 0 skip). E2E: 792/792 (100.0%, 0 leak).
- Wasm 3.0: all 9 proposals. WASI: 46/46 (100%). WAT parser complete.
- JIT: Register IR + ARM64/x86_64. Size: 1.19MB / 1.52MB RSS.
- **main = stable**: ClojureWasm depends on main (v1.2.0 tag).

## Current Task

Phase 1: Guard Pages + Module Cache (see `roadmap.md` Phase 1).

### 1.1 Virtual Memory Guard Pages

Eliminate per-load/store bounds check. mmap(8GB) + mprotect + SIGSEGV trap.
Files: memory.zig, jit.zig, x86.zig, vm.zig. Decision: D123.
Expected: 1.5-2x on memory-intensive benchmarks.

### 1.2 Module Cache / AOT Serialize

Save predecoded/RegIR to disk. cache.zig, `zwasm run --cache`, `zwasm compile`.
Decision: D124. Expected: 10-100x startup improvement.

Previous: v1.2.0 released (tagged 5d54ae9, CW updated).

## Known Bugs

None.

## References

- `@./.dev/roadmap.md` (future phases), `@./.dev/roadmap-archive.md` (completed stages)
- `@./private/future/03_zwasm_clojurewasm_roadmap_ja.md` (integrated roadmap)
- `@./.dev/decisions.md`, `@./.dev/checklist.md`, `@./.dev/spec-support.md`
- `@./.dev/jit-debugging.md`, `@./.dev/bench-strategy.md`
- External: wasmtime (`~/Documents/OSS/wasmtime/`), zware (`~/Documents/OSS/zware/`)
