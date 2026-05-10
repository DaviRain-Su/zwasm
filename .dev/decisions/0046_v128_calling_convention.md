---
name: v128 calling convention — return marshal first, params deferred
description: Land v128 single-result return marshal on both backends (XMM0 / V0); v128 param marshal deferred to follow-up chunk
status: Accepted
date: 2026-05-10
---

# ADR-0046: v128 calling convention

## Status

Accepted (2026-05-10)

## Context

§9.9 spec test wiring requires JIT-compiling functions with v128
results. The upstream WebAssembly testsuite SIMD bundle uses
patterns like:

```wasm
(func (export "load_at_zero") (result v128) (v128.load (i32.const 0)))
```

Currently both backends reject v128 in function signatures:

- **x86_64** (`src/engine/codegen/x86_64/emit.zig:1505`):
  `.v128 => return rejectUnsupported("func-end-return-v128", func.func_idx)`
- **ARM64** (`src/engine/codegen/arm64/emit.zig:969`): v128 falls
  into the i32/i64/funcref arm using `ORR ZR-to-X0` (64-bit GPR
  move) — silently truncates the upper 64 bits of the v128.
  Also a bug; the rejection is implicit (wrong move width) rather
  than explicit.
- **x86_64 params** (`emit.zig:178-181`): v128 explicitly rejected
  in the param-type loop.
- **ARM64 params**: similar gap (TBD on detailed inspection).

Without v128 result marshal, no spec assertion that returns a
v128 can be JIT-tested. Without v128 param marshal, fewer
assertions are blocked but multi-arg v128 tests still are.

## Decision

**Phase the calling convention extension into two chunks**:

1. **§9.9-b — v128 RETURN marshal** (this commit):
   - x86_64: replace the rejection at emit.zig:1505 with the
     same `MOVAPS XMM0, src_x` path that f32/f64 already use
     (already copies all 128 bits per Intel SDM "MOVAPS").
   - ARM64: add a `.v128` arm distinct from the i64/funcref one;
     emit `MOV V0.16B, Vn.16B` (128-bit-wide vector move).
   - Update existing `func-end-return-v128 → UnsupportedOp` unit
     tests (at `emit_test_int.zig:860`, `emit_test_float.zig:1489`)
     to expect success and assert the marshal byte sequence.

2. **§9.9-? (subsequent) — v128 PARAM marshal**:
   - Allocate XMM/V argument slots for v128 params; thread
     through the local-allocation pass so v128 locals get
     16-byte stride (vs scalar 8-byte).
   - Update prologue param-marshaling to MOVAPS the v128 arg
     reg into the local slot.
   - Param-side change is structurally larger because it
     touches local layout + frame sizing; deserves its own
     chunk.

## Alternatives considered

### A. Land param + return in one bundled chunk

Tackle both v128 marshaling sides in one commit. Rejected:

- Per LOOP "Split when ANY hold: implementation crosses an
  instruction class": param marshal touches prologue +
  local-layout pass + arg-reg allocator; return marshal is a
  single switch arm. Distinct shapes.
- Return-only is unblocking for the majority of spec assertions
  (single-result is the dominant pattern); param-side gates
  fewer assertions and can iterate independently.

### B. Defer all v128 calling convention work to a Phase 9 close-out chunk

Wait until §9.9 / §9.10 surface concrete demand. Rejected:

- §9.9-b's manifest population needs v128 return support to
  produce a useful baseline (otherwise every fixture skips
  with "v128 result unsupported"). Foundation work blocks
  meaningful iteration.

### C. Synthesise v128 return as 2× i64 (split high/low)

Return high 64 bits in RAX, low in RDX (or similar). Rejected:

- Diverges from SysV / Win64 SIMD ABI (both pass v128 in XMM0
  on return). External callers via `wasm-c-api` would mis-marshal.
- ARM64 SIMD ABI uses V0 for v128 return; consistent with
  x86_64's XMM0; the cross-arch parity is easier to maintain
  with the standard ABI.

## Consequences

- Both backends gain v128 single-result return support in this
  chunk. ABI is the standard SysV / Win64 / AAPCS64 SIMD
  convention (XMM0 / V0).
- The v128 entry helper (`callV128NoArgs` returning `[16]u8`)
  needed by the SIMD spec runner can be added in §9.9-c
  alongside the manifest population.
- Multi-result v128 (Wasm 2.0 multi-value with v128 in result
  list) stays blocked on the existing "single-result only"
  emit-side limit (separate from this chunk).
- Param-side v128 deferral means spec assertions invoking
  `(func (param v128) (param v128) (result v128))` style
  remain skipped at §9.9-c baseline; they unblock when the
  param chunk lands.

## References

- ADR-0045 (SIMD spec test runner) — the immediate consumer
  of this calling convention extension.
- Intel SDM Vol 2A "MOVAPS" — confirms the existing f32/f64
  marshal already copies all 128 bits.
- Arm IHI 0055 §6.5 "AAPCS64 SIMD calling convention" — V0 is
  the v128 return register.

## Revision history

| Date       | Reason                                                    |
|------------|-----------------------------------------------------------|
| 2026-05-10 | Initial — filed at §9.9-b. v128 return marshal lands; param marshal split off into a follow-up chunk. |
