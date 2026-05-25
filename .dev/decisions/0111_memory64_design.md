# 0111 — memory64 design: idx_type + multi-memory + i32 fast-path

- **Status**: Accepted (2026-05-25; Phase 10 / 10.D ADR round close)
- **Date**: 2026-05-25
- **Author**: claude (autonomous loop, /continue prep path)
- **Tags**: memory64, wasm-3.0, multi-memory, codegen, ZirInstr,
  Phase 10 / 10.M
- **Paired ROADMAP row**: §10 / 10.M (impl), §10 / 10.D (this ADR's Accept gate)
- **Co-landed with**: ADR-0112..0117 (Phase 10 / 10.D round)

## Context

The Wasm 3.0 memory64 proposal introduces 64-bit memory index
type — a Memory can be declared `i32` (legacy; ≤ 4 GiB) or `i64`
(new; spec-full 2^64 addressable). Existing memory ops widen to
i64 offset arithmetic when targeting an i64 memory; i32 memories
keep the existing 32-bit semantics + emit byte-identical machine
code per the project's "i32 fast-path byte-identical" rule (per
`emit_test_*.zig`).

ROADMAP §10 calls for memory64 land at row 10.M (impl) with
this ADR Accepted at row 10.D. The design follows
`phase10_design_plan_ja.md` §3.1 — full upstream consensus
references:

- **WebAssembly/memory64**: https://github.com/WebAssembly/memory64
  (overview, spec, testsuite at `test/core/*.wast` ~127 files).
- **wasmtime** (`cranelift/codegen/src/wasm/...`): full u64
  offset carry through CLIF; per-memory `idx_type` discriminator.
- **wasmer-LLVM**: same shape.
- **WAMR**: AOT path carries u64 offsets; interp uses 64-bit
  arithmetic universally.
- **spec reference interp (OCaml)**: `interpreter/exec/memory.ml`
  uses `int64` for all offsets.

Industry convergence is unanimous on full-u64 offset carry. The
project's pre-Phase-10 IR carried `ZirInstr.payload: u32` (= max
4 GiB memarg offset). 10.Z (commit `7fb6593d`) widened
`payload` to `u64` — this ADR codifies the remaining layer:
idx_type on Memory + multi-memory + per-memory wrap-check
emission.

## Decision

Land the memory64 proposal with the following design choices:

1. **`MemoryEntry.idx_type` (parse) + `Memory.idx_type` (runtime)
   discriminator** — `enum { i32, i64 }`, always present (not
   build-option-gated; ABI stability). Parser reads the i64-flag
   bit from the limits prefix per Wasm 3.0 §5.4.4; rejects `i64`
   at parse time when `comptime build_options.wasm_level < .v3_0`.

2. **Multi-memory enabled in the same change** — `runtime.Runtime.
   memory: []u8` → `memories: []MemoryInstance`. Each
   `MemoryInstance` carries `bytes: []u8` + `idx_type` +
   `pages_min` + `pages_max`. Single-memory Wasm 1.0/2.0 fixtures
   keep `memories.len == 1`. multi-memory enable is codegen
   zero-cost (memidx 0 = current memory; the existing emit-side
   `[X_base, X_offset]` shape reads `memories[0]`).

3. **MemArg `extra` field becomes `packed struct(u32) MemArgExtra
   { align_pow2: u5, memidx: u8, _: u19 }`** — explicit memidx
   carry (was implicit `0`) per Wasm 3.0 §5.4.6 memarg encoding.

4. **i32 fast-path byte-identical guarantee** — every emit site
   uses a comptime + runtime two-stage gate:
   ```zig
   if (comptime build_options.wasm_level >= .v3_0) {
       if (mem.idx_type == .i64) {
           // i64 wrap-check + 64-bit offset materialise
           // (MOVZ+MOVK 4-lane on arm64; MOV imm64 → r10 on x86_64)
       } else {
           // i32 path (unchanged; byte-identical to v2.0 emit)
       }
   } else {
       // i32 path (unchanged; byte-identical to v2.0 emit)
   }
   ```
   `-Dwasm=v2_0` builds strip the i64 arm via DCE; `-Dwasm=v3_0
   + idx_type=.i32` traverses the runtime check but emits the
   same bytes. `emit_test_memory64.zig` (new) golden-snapshots
   the i64 wrap-check shape; existing `emit_test_memory.zig`
   verifies the i32 path stays byte-identical.

5. **64-bit offset materialise per arch**:
   - arm64: 4-lane `MOVZ x17, #lo16; MOVK x17, #..., LSL 16;
     MOVK x17, #..., LSL 32; MOVK x17, #..., LSL 48` → `[x_base,
     x17]`. X17 is the existing intra-call scratch (no regalloc
     reservation change per ADR-0018).
   - x86_64: `MOV r10, imm64; [r_base + r10]`. R10 is scratch
     per Win64/SysV. No regalloc reservation change.

6. **`bounds_fixups: ArrayList(u32)` storage stays unchanged** —
   the per-callsite metadata that ADR-0113 introduces is
   orthogonal to memory64; bounds-fixup carries the post-emit
   instruction PC, not the offset value.

## Alternatives considered

- **A. Universal i64 offset (drop the discriminator)** — every
  memory op uses 64-bit arithmetic regardless of memory's
  declared idx_type. Rejected: violates "i32 fast-path byte-
  identical" rule; the additional MOVZ+MOVK 4-lane cost on
  every i32 memory access (which is 99% of real-world Wasm
  today) breaks bench parity with the v2.0 baseline.

- **B. Two parallel ZirOp catalogs (`i32.load` vs `i64.load`
  per memidx)** — fork the dispatch table at the IR layer.
  Rejected: doubles handler counts; defeats the ZIR substrate
  unification per ROADMAP §4. The idx_type axis at emit time
  (decision §4 above) is the cleaner cut.

- **C. Defer multi-memory** (single-memory + idx_type only) —
  ship memory64 without `memories: []`. Rejected: the runtime
  refactor `memory: []u8 → memories: []MemoryInstance` IS the
  load-bearing change; doing it once vs twice halves the
  audit cost. Multi-memory enable is codegen-zero per Wasm 3.0
  §5.4.6 (memidx field at memarg site is opaque to most ops).

## Consequences

**Positive**:

- ZirInstr.payload (already u64 post-10.Z) carries spec-full
  memarg offset without further IR widen.
- Multi-memory enabled simultaneously (Wasm 3.0 §5.4.6) at
  zero codegen cost.
- i32 fast-path keeps existing JIT-emit byte-identical per
  `emit_test_memory.zig`; bench parity with v2.0 baseline.
- Industry convergence (wasmtime / wasmer / WAMR / spec ref
  all u64-offset) — design defensibility for v0.2 audit.

**Negative**:

- `Memory.idx_type` + `MemoryInstance` widening touch every
  runtime memory access call site. Estimated cascade: ~80
  sites in `src/runtime/instance/memory.zig` + per-op handlers
  in `instruction/wasm_1_0/memory.zig` + `wasm_2_0/bulk_memory.zig`.
- `MemArg` packed-struct change requires per-op packing helper
  updates in `src/parse/sections.zig::decodeMemArg`. Mechanical.
- Per-instruction memory overhead: ZirInstr's `payload: u64`
  already paid this cost at 10.Z (12 → 24 bytes due to
  alignment); no further overhead from this ADR.

## Removal condition

This ADR retires when memory64 ships at ROADMAP §10 / 10.M
`[x]`, with all six decisions above implemented, the
`memory64/test/core/*.wast` spec corpus green at 3-host gate,
and the `emit_test_memory64.zig` golden + `emit_test_memory.zig`
byte-identical verification both pass. At that point status
transitions to `Closed (Implemented)` with the impl SHA range
cited.

## References

- `phase10_design_plan_ja.md` §3.1 — full design spec (source
  of truth; this ADR codifies the decisions).
- WebAssembly/memory64 proposal:
  https://github.com/WebAssembly/memory64
- `~/Documents/OSS/wasmtime/cranelift/codegen/src/wasm/` — full
  u64 offset carry through CLIF (industry precedent).
- `~/Documents/OSS/WebAssembly/memory64/test/core/*.wast` —
  127-file spec testsuite (consumed at 10.M close).
- `~/Documents/OSS/WebAssembly/spec/interpreter/exec/memory.ml`
  — OCaml reference interp uses `int64` universally.
- ADR-0017 — JIT register inventory (X17 / R10 scratch
  unchanged; no reservation cascade).
- ADR-0023 — Zone layering (`runtime/instance/memory.zig` lives
  in Zone 1 — runtime; ABI-crossing types use `extern struct`).
- ADR-0113 — callsite_metadata (orthogonal; this ADR doesn't
  touch bounds_fixups storage).
- 10.Z commit `7fb6593d` — ZirInstr.payload u32→u64 widen
  (prerequisite; this ADR consumes the wider field).

## Revision history

- 2026-05-25 — Initial draft via /continue autonomous prep path
  (per `.claude/skills/continue/SKILL.md` §"Autonomous prep
  paths for user-gated ADRs"). Status: Proposed pending user
  collab review at 10.D. Co-drafted in the 10.D ADR round
  alongside ADR-0112..0117 (over multiple /continue cycles per
  the 7-ADR scope).
- 2026-05-25 — Status: Proposed → **Accepted** (user collab 1/7).
  All 6 decisions accepted. Enhancement added: `-Dwasm=v2_0`
  build symbol-absence gate (= `nm` check that `emitMem64Wrap`-class
  symbols are zero-count in v2.0 build) gets wired into
  `scripts/check_phase10_close_invariants.sh` (10.P) as a
  mechanical proof that comptime DCE of the i64 arm holds. This
  is the v2.0 substrate-fidelity invariant in nm-grep form, a
  generalisation pattern future `-Dgc=false` / `-Dwasm=v3_0`
  strip checks will replicate.
