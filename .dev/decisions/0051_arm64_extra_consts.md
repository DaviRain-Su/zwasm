---
name: ARM64 extra_consts infrastructure (mirror of x86_64 SIMD const-pool extension)
description: Extend ARM64's per-function const-pool to carry emit-time-derived 16-byte SIMD constants alongside lower-time literals, mirroring the x86_64 mechanism added at §9.7-am.
type: ADR
status: Accepted
date: 2026-05-11
---

# ADR-0051: ARM64 extra_consts infrastructure

## Status

Accepted (2026-05-11)

## Context

ADR-0042 (SIMD const-pool design, 2026-05-09) introduced the
per-function const-pool plumbing on **both** arches for the
lower-time literal use-cases:

- `v128.const` — 16-byte literal from the wasm body.
- `i8x16.shuffle` — 16-byte shuffle-mask immediate.

Both literals are collected at lower time into
`ZirFunc.simd_consts: ?[]const [16]u8`. At per-arch emit close
the const-pool is appended (16-byte aligned) past the trap stub,
and each `LDR Q<rt>, <label>` / `MOVUPS xmm, [rip+disp32]`
placeholder has its imm field patched to point at the
appropriate slot.

§9.7-am extended **x86_64 only** with a second source of
const-pool entries: **emit-time-derived** 16-byte constants
appearing inside per-op codegen recipes. Examples that have
landed on x86_64 since:

- `INT32_MAX_F64_BROADCAST` for `i32x4.trunc_sat_f64x2_*_zero`
  (the saturating clamp's upper bound).
- `POPCNT_LUT` + `NIBBLE_MASK_BROADCAST` for the PSHUFB-LUT
  popcnt recipe.
- `UINT_MASK_HIGH` (2^52 magic) for `f64x2.convert_low_i32x4_u`.

Mechanism (x86_64): `compile()` keeps a local
`extra_consts: std.ArrayList([16]u8)` alongside the existing
`simd_const_fixups` list. Handlers call
`lookupOrAppendExtraConst(value)` which returns a global
`const_idx`; the index lives in a single flat namespace via
`simd_consts_base = func.simd_consts.?.len` (i.e. extra entries
sit *after* the lower-time entries when the pool is flushed). At
function close both lists are appended in order to produce the
flat 16-byte-aligned pool, and the existing fixup-patch loop
addresses all entries uniformly.

§9.9-g-19 (i\*x\*.bitmask on ARM64) is the **first** ARM64
consumer that needs emit-time-derived constants. The per-lane
position-mask constants (`0x80402010_08040201` × 2 for i8x16;
`0x0080_0040_0020_0010_...` for i16x8; `0x00000008_..._00000001`
for i32x4) are not provided by the wasm bytecode — they are
implementation-detail materialised by the lowering recipe (per
cranelift `aarch64/lower.isle:2883-2943`). Without an
`extra_consts` mechanism on ARM64 there are two suboptimal
options:

1. Inline materialisation via `MOVZ/MOVK` chains: 8 MOVZ/MOVK +
   2 INS = ~10 instructions per mask, ~40 bytes per use site.
2. Side-channel the masks through `ZirFunc.simd_consts`: would
   require lower to know the codegen recipe (violates
   Zone 1 ↔ Zone 2 separation; lower must not know per-arch
   constants).

The handover at `52666319` named this gap and the survey
(`private/notes/p9-9.9-g-19-bitmask-neon-survey.md`) verified
the encoder bit patterns are mechanical (SSHR.16B/8H/4S,
ADDV.16B/8H/4S, ZIP1.16B, EXT.16B, UMOV). The blocking question
was const-pool infrastructure, not encoder synthesis.

## Decision

Adopt option (a) from the handover: **mirror x86_64's
`extra_consts` mechanism on ARM64** by extending
`engine/codegen/arm64/ctx.zig:EmitCtx` and the function-close
const-pool flush in `arm64/emit.zig`.

### Surface change (`EmitCtx`)

Add two fields (both lifetimes managed by `compile()`'s local
state, mirroring x86_64):

```zig
// engine/codegen/arm64/ctx.zig
pub const EmitCtx = struct {
    // ... existing fields ...

    /// Emit-time-derived 16-byte SIMD constants discovered by
    /// per-op handlers (per-shape masks, magic constants, etc.).
    /// At function close these are appended to the JIT byte
    /// buffer *after* the per-instance `func.simd_consts`
    /// entries, forming a single flat 16-byte-aligned pool.
    extra_consts: *std.ArrayList([16]u8),

    /// Number of lower-time entries the flat const-pool starts
    /// with. Equals `func.simd_consts.?.len` when simd_consts
    /// is non-null, 0 otherwise. Handlers compute their
    /// `const_idx` as `simd_consts_base +
    /// position-in-extra_consts`.
    simd_consts_base: u32,
};
```

### Shared helper (mirror of x86_64)

Add `op_simd.zig`-internal helper:

```zig
fn lookupOrAppendExtraConst(
    ctx: *EmitCtx,
    value: [16]u8,
) Error!u32 {
    for (ctx.extra_consts.items, 0..) |c, i| {
        if (std.mem.eql(u8, &c, &value)) {
            return ctx.simd_consts_base + @as(u32, @intCast(i));
        }
    }
    const idx: u32 = ctx.simd_consts_base +
        @as(u32, @intCast(ctx.extra_consts.items.len));
    try ctx.extra_consts.append(ctx.allocator, value);
    return idx;
}
```

Dedup is a linear scan; this matches x86_64. The `extra_consts`
array typically stays ≤ 5 entries per function (per-shape masks
+ a few magics), so the linear cost is irrelevant against the
~1 KB JIT block sizes Phase 9 codegen produces.

### Function-close flush (`arm64/emit.zig`)

Update the `if (simd_const_fixups.items.len > 0) { ... }` block
in `compile()` to:

1. Allow `func.simd_consts == null` as long as `extra_consts`
   is non-empty (current code raises `AllocationMissing`).
2. Append `func.simd_consts.?` entries first (if non-null), then
   `extra_consts.items` entries, both as 16-byte-aligned
   contiguous blocks.
3. Use `simd_consts_base + fx.const_idx` mapping: lower-time
   entries land at `pool_byte + i*16` for `i ∈ [0, base)`;
   extra entries at `pool_byte + (base + j)*16` for
   `j ∈ [0, extra.len)`. Since `simd_consts_base` is exactly
   `func.simd_consts.?.len` (or 0), the existing
   `pool_byte + fx.const_idx*16` arithmetic remains correct
   without modification.

### Lifetimes

- `extra_consts` is owned by `compile()`'s local state:
  `var extra_consts: std.ArrayList([16]u8) = .empty;` +
  `defer extra_consts.deinit(allocator);` — mirror of
  `simd_const_fixups`.
- `simd_consts_base` is computed once at `EmitCtx`
  initialisation: `const simd_consts_base: u32 = if
  (func.simd_consts) |sc| @intCast(sc.len) else 0;`. It is
  immutable for the function's lifetime.

## Alternatives considered

### Option (b) — inline MOVZ/MOVK materialisation per use site (Rejected)

- Per the survey: each per-shape mask needs ~10 instructions
  (8× MOVZ/MOVK + 2× INS to populate both lanes of a Q-reg).
  Total ~40 bytes per use site.
- Bitmask alone has 3 vector-mask consumers (i8x16, i16x8,
  i32x4); each use site pays the full ~40-byte cost without
  the option to dedup.
- Future emit-time consts (e.g. ARM64 popcnt LUT, ARM64 f64x2
  convert magic) would each multiply the same per-use cost.
- Rejected for the same reason ADR-0042 rejected MOVZ/MOVK for
  v128.const: pay infrastructure cost once, not per-use
  forever.

### Option (c) — extend `func.simd_consts` via lower-time per-arch hook (Rejected)

- Add a callback `(ZirOp) → ?[][16]u8` invoked at lower time so
  the lower pass can ask the codegen layer for extra
  constants. Lower flushes everything to `func.simd_consts` in
  one place.
- Pro: keeps the const-pool single-source (no `extra_consts`).
- Con: cross-zone callback (Zone 1 `ir/lower.zig` calling into
  Zone 2 `engine/codegen/<arch>/`) violates ROADMAP §4.1 zone
  hierarchy. Lower is not allowed to depend on codegen.
- Rejected.

### Option (d) — separate fixup list for extra-const fixups (Rejected)

- Two lists: `simd_const_fixups` for lower-time entries,
  `extra_const_fixups` for emit-time entries, two flush
  passes.
- Pro: keeps the two sources cleanly separated in code.
- Con: doubles the fixup-patch loop; const_idx becomes a
  union type carrying the source discriminator.
- Rejected as gratuitous complexity — the existing `const_idx`
  is already a flat index into the final pool; routing both
  sources through `simd_consts_base + offset` is the simpler
  composition.

## Consequences

### Positive

- Symmetric architecture surface across arm64 / x86_64. The
  same shared helper (`lookupOrAppendExtraConst`) and the same
  flat-pool flush model applies to both.
- Unblocks §9.9-g-19 (bitmask). Per-shape masks land in
  `extra_consts` deduplicated; the bitmask family pays one mask
  per shape per function regardless of use count.
- Reusable for future emit-time const consumers on ARM64
  (popcnt LUT once the NEON CNT-based recipe lands, f64x2
  convert magics, dot-product shuffles, etc.).
- No change to `ZirFunc.simd_consts` (still owns lower-time
  literals only). Lower stays Zone-1-pure.

### Negative

- ARM64 EmitCtx surface grows by 2 fields. Bounded change;
  parameter-bundle pattern (ADR-0023) absorbs cleanly.
- `compile()`'s local state grows by one ArrayList; mirror of
  x86_64's existing shape.
- `simd_const_fixups` flush no longer requires
  `func.simd_consts != null` — the diagnostic `return
  Error.AllocationMissing` path narrows to "fixups present AND
  both sources empty" (theoretically unreachable; defensive
  check retained).

## Implementation chunk plan (§9.9-g-19)

This ADR is the design artifact; the implementation chunk
(also §9.9-g-19) bundles:

1. **Infrastructure** (this ADR's surface):
   - `engine/codegen/arm64/ctx.zig`: add `extra_consts` +
     `simd_consts_base` fields to `EmitCtx`.
   - `engine/codegen/arm64/emit.zig`: instantiate
     `extra_consts` in `compile()`; thread into ctx; extend
     close-time flush to append both lists; relax
     `func.simd_consts == null` guard.

2. **First consumer — i\*x\*.bitmask** (D-067 discharge):
   - `engine/codegen/arm64/inst_neon.zig`: new encoders
     `encSshrVecImm` (16B/8H/4S shapes), `encAddvB/H/S`
     (across-lanes reduce), `encUmovWFromB/H/S` /
     `encUmovXFromD` (scalar extract from lane), `encZip1V16B`,
     `encExtV16B` (imm4=8 byte-swap), `encLsrXImm` (scalar
     64-bit logical right shift, if not already present).
   - `engine/codegen/arm64/op_simd.zig`: 4 handlers
     (`emitI8x16Bitmask`, `emitI16x8Bitmask`,
     `emitI32x4Bitmask`, `emitI64x2Bitmask`). Per-shape mask
     literals registered via `lookupOrAppendExtraConst`. i64x2
     uses scalar UMOV + LSR + ADD path (no vector mask —
     NEON has no `.2D` form for `ADDV`).
   - `engine/codegen/arm64/emit.zig`: dispatch arms for the 4
     bitmask ZirOps.
   - `src/validate/validator.zig`: route sub-ops
     100/132/164/196 to `opSimdAllTrueOrAnyTrue` (same
     1-pop-v128 / 1-push-i32 shape).
   - `src/ir/lower.zig`: wire sub-ops 100/132/164/196 to the
     4 bitmask ZirOps.

3. **Debt update**: discharge D-067 in the same commit (close
   row + mention this ADR in commit body).

## References

- ADR-0042 (SIMD const-pool design) — the lower-time
  predecessor this ADR extends.
- ADR-0041 (SIMD-128 design framing) — shape-as-variant ZirOp
  catalogue + per-arch emit divergence policy.
- ADR-0046 (v128 calling convention) — cross-arch v128 ABI.
- D-067 (`.dev/debt.md`) — the `now`-status debt entry naming
  the structural barrier this ADR resolves.
- `private/notes/p9-9.9-g-19-bitmask-neon-survey.md` — encoder
  + cranelift-recipe survey.
- `src/engine/codegen/x86_64/emit.zig:580-590` — x86_64's
  in-place `extra_consts` declaration (the mechanism this
  ADR mirrors).
- `src/engine/codegen/x86_64/op_simd.zig:4088-4105` — x86_64
  `lookupOrAppendExtraConst` (verbatim shape mirrored on
  arm64).
- Arm IHI 0055 §C7.2.325 (SSHR), §C7.2.8 (ADDV), §C7.2.383
  (UMOV), §C7.2.424 (ZIP1), §C7.2.119 (EXT) — the encoder
  references the bitmask handlers consume.
- Cranelift `aarch64/lower.isle:2883-2943` — the `vhigh_bits`
  recipe pattern this implementation re-derives.
