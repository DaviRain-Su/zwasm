---
date: 2026-05-23
keywords: ADR-0106, wrapper thunk, Win64 ABI, hidden RCX, multi-result, callconv(.c), Zig-vs-JIT boundary
citing: 7ea1662a, a3139eed, 81165ee6
---

# ADR-0106 wrapper-thunk approach: Zig-level vs JIT-emitted distinction

## The insight worth not re-deriving

A **JIT-emitted machine-code wrapper thunk** with Zig-side
signature `fn(rt, results, args) callconv(.c) ErrCode` (single
u32 return) bypasses Win64's hidden-RCX struct-return ABI for
multi-result functions WITHOUT requiring intra-module call
lowering changes. The thunk internally calls the function body
via raw assembly (no `callconv(.c)` at the internal call → no
Win64 ABI rules apply at the internal call).

The cycle-2 spike rejected "wrapper approach" assuming a
**Zig-level** wrapper (entry helper itself). A Zig-level wrapper
can't intercept Win64's hidden-RCX struct-return — Zig's caller
already mis-marshalled before the wrapper sees results. The
distinction:

- **Zig-level wrapper** (REJECTED in cycle-2 spike): Zig declares
  `fn(rt) callconv(.c) FuncRet_i32i64`. Zig caller follows Win64
  ABI for `FuncRet_i32i64` (16 bytes → hidden RCX pointer).
  Mismatch with JIT body that writes RAX/RDX. Wrapper sees the
  already-broken result.
- **JIT-emitted wrapper** (ADOPTED in cycle 3e revised approach):
  Zig declares `fn(rt, results, args) callconv(.c) u32`. Single
  u32 return is in RAX — no hidden pointer needed at Zig/C
  boundary. Wrapper internally CALLs the body via raw assembly;
  the body uses its existing register convention, wrapper picks
  up RAX/RDX and writes to results buffer.

## Why the cycle-2 spike missed this

The cycle-2 spike framed Alt 3 generically: "wrapper approach".
The Zig-vs-JIT distinction wasn't explicit. Both Zig-level AND
JIT-emitted are "wrappers" — but they have different ABI
implications because Zig-level inherits Zig's ABI rules at every
function boundary, while JIT-emitted is machine code with no
Zig-level signature at the internal call.

## When to apply this lesson

Whenever an ABI conversion is needed AT a function boundary:

- If conversion can happen in JIT-emitted bytes (no `callconv(.c)`
  involvement at the internal CALL), prefer that.
- Zig-level conversions are subject to Zig's ABI rules, which
  may include hidden-pointer struct-return on Windows.

## Sibling case: how this differs from per-shape inline-asm thunks (Path c, ADR-0106 REJECTED)

Per-shape inline-asm thunks are also "JIT-emitted-like" (Zig
inline-asm reads RAX/RDX after CALL). The difference:

- **Per-shape thunk**: ONE thunk per result-shape category (5
  shapes per ADR-0106 D-164 debt: `FuncRet_i32i64` /
  `FuncRet_i32i32` / `FuncRet_i32f64` / `FuncRet_f64i32` /
  `FuncRet_f64f32`). Scales linearly with new return shapes
  (Wasm 3.0 GC reftypes, EH tag-pack, memory64 add more shapes).
  Industry consensus REJECTS it (neither v1, wasmtime, wasmer,
  wabt-interp, nor wasm-c-api use this pattern).
- **Wrapper thunk** (this lesson's pattern): ONE thunk per
  FUNCTION (auto-generated from the function's specific sig).
  Doesn't scale per new shape category — scales per function,
  which is the natural granularity (each function gets one
  wrapper regardless of how many result categories exist).

## Refs

- ADR-0106 (path (a) Accepted 2026-05-23) §"Alternative 3 —
  Wrapper approach (REJECTED)".
- private/spikes/adr-0106-cycle2/SPIKE.md (cycle 2 design).
- private/spikes/adr-0106-cycle3e-call-lowering/SPIKE.md
  §"REVISED APPROACH" (cycle 3e re-think landing the wrapper
  thunk).
- `src/engine/codegen/shared/wrapper_thunk.zig` (Phase 1 type
  foundation, `a3139eed`).
- Commits `7ea1662a` (handover pivot) + `81165ee6` (ADR
  References) + `a3139eed` (foundation file).
