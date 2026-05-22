# Wasm 3.0 ZirOp ↔ spec opcode mapping

> **Doc-state**: ACTIVE — load-bearing reference (Phase 9+ scope).

> Phase 10 prep deliverable per ROADMAP §9.12-G. Tracks the
> Wasm 3.0 ZirOps declared in `src/ir/zir.zig` against the
> upstream `WebAssembly/<proposal>/document/core/binary.rst`
> opcode numbers. Source-of-truth for the encoder /
> dispatch-collector wiring at Phase 10 open. Future
> regenerations should walk `dispatch_collector` instead of
> hand-curating — left for a Phase-10-open script chunk.

The numeric opcodes below are taken from each proposal's
`document/core/binary.rst` in the upstream WebAssembly repo at
`~/Documents/OSS/WebAssembly/`. Where a proposal uses a multi-byte
prefix (0xFB / 0xFC / 0xFD / 0xFE), the prefix is included; the
trailing LEB128(u32) sub-opcode is given as the second column.
Single-byte opcodes have a `-` in the sub-opcode column.

## memory64 — 64-bit memory size / grow

Proposal: <https://github.com/WebAssembly/memory64>. Spec status:
merged into Wasm 3.0 (2024). Slots reserved in the MVP-family
range because the existing `memory.size` / `memory.grow` opcodes
flip semantics when `(memory i64)` is declared; the i64 variant
is a separate ZirOp for clean dispatch.

| ZirOp              | Prefix | Sub-op | Notes                                                |
|--------------------|--------|--------|------------------------------------------------------|
| `memory.size_64`   | -      | 0x3F   | Same opcode as MVP `memory.size`; dispatch on memory's index type |
| `memory.grow_64`   | -      | 0x40   | Same opcode as MVP `memory.grow`; dispatch on memory's index type |

## exception-handling — try_table / throw / throw_ref

Proposal: <https://github.com/WebAssembly/exception-handling>.
Spec status: merged into Wasm 3.0 (2024). The legacy
`try` / `catch` opcodes are NOT in scope (zwasm v2 implements
the post-2024 `try_table` form only).

| ZirOp        | Prefix | Sub-op | Notes                                                              |
|--------------|--------|--------|--------------------------------------------------------------------|
| `try_table`  | -      | 0x1F   | Block with per-tag handler vector                                  |
| `throw`      | -      | 0x08   | Throw with explicit tagidx                                         |
| `throw_ref`  | -      | 0x0A   | Throw an existing exception reference (re-throw shape)             |

## tail-call — return_call / return_call_indirect / return_call_ref

Proposal: <https://github.com/WebAssembly/tail-call>. Merged into
Wasm 3.0.

| ZirOp                   | Prefix | Sub-op | Notes                                       |
|-------------------------|--------|--------|---------------------------------------------|
| `return_call`           | -      | 0x12   | Direct tail call                            |
| `return_call_indirect`  | -      | 0x13   | Indirect tail call via table                |
| `return_call_ref`       | -      | 0x15   | Tail call through funcref                   |

## function-references — call_ref / br_on_null / ref.as_non_null

Proposal: <https://github.com/WebAssembly/function-references>.
Merged into Wasm 3.0.

| ZirOp              | Prefix | Sub-op | Notes                                       |
|--------------------|--------|--------|---------------------------------------------|
| `call_ref`         | -      | 0x14   | Call via typed funcref                      |
| `ref.as_non_null`  | -      | 0xD4   | Cast nullable → non-null (traps on null)    |
| `br_on_null`       | -      | 0xD5   | Branch when funcref is null                 |
| `br_on_non_null`   | -      | 0xD6   | Branch when funcref is non-null             |

## gc — struct / array / ref.cast / i31

Proposal: <https://github.com/WebAssembly/gc>. Merged into Wasm 3.0.
All ops are 0xFB-prefixed sub-opcodes per binary.rst §"GC".

| ZirOp                | Prefix | Sub-op | Notes                                |
|----------------------|--------|--------|--------------------------------------|
| `struct.new`         | 0xFB   | 0      | Struct allocation with explicit fields |
| `struct.new_default` | 0xFB   | 1      | Struct allocation with default-init  |
| `struct.get`         | 0xFB   | 2      | Field access (no sign-extend)        |
| `struct.get_s`       | 0xFB   | 3      | Field access, sign-extend            |
| `struct.get_u`       | 0xFB   | 4      | Field access, zero-extend            |
| `struct.set`         | 0xFB   | 5      | Field mutation                       |
| `array.new`          | 0xFB   | 6      | Array allocation with init value     |
| `array.new_default`  | 0xFB   | 7      | Array allocation, default-init       |
| `array.new_fixed`    | 0xFB   | 8      | Array allocation from stack elements |
| `array.new_data`     | 0xFB   | 9      | Array init from data segment         |
| `array.new_elem`     | 0xFB   | 10     | Array init from element segment      |
| `array.get`          | 0xFB   | 11     | Element access (no sign-extend)      |
| `array.get_s`        | 0xFB   | 12     | Element access, sign-extend          |
| `array.get_u`        | 0xFB   | 13     | Element access, zero-extend          |
| `array.set`          | 0xFB   | 14     | Element mutation                     |
| `array.len`          | 0xFB   | 15     | Array length                         |
| `array.fill`         | 0xFB   | 16     | Bulk fill                            |
| `array.copy`         | 0xFB   | 17     | Bulk copy                            |
| `array.init_data`    | 0xFB   | 18     | Bulk init from data segment          |
| `array.init_elem`    | 0xFB   | 19     | Bulk init from element segment       |
| `ref.test`           | 0xFB   | 20     | Non-null type test                   |
| `ref.test_null`      | 0xFB   | 21     | Nullable type test                   |
| `ref.cast`           | 0xFB   | 22     | Non-null cast (traps on mismatch)    |
| `ref.cast_null`      | 0xFB   | 23     | Nullable cast                        |
| `br_on_cast`         | 0xFB   | 24     | Branch on cast success               |
| `br_on_cast_fail`    | 0xFB   | 25     | Branch on cast failure               |
| `any.convert_extern` | 0xFB   | 26     | externref → anyref                   |
| `extern.convert_any` | 0xFB   | 27     | anyref → externref                   |
| `ref.i31`            | 0xFB   | 28     | i32 → i31ref                         |
| `i31.get_s`          | 0xFB   | 29     | i31ref → i32 (sign-extend)           |
| `i31.get_u`          | 0xFB   | 30     | i31ref → i32 (zero-extend)           |

## relaxed-simd — relaxed v128 ops

Proposal: <https://github.com/WebAssembly/relaxed-simd>. Merged
into Wasm 3.0. 0xFD-prefixed sub-opcodes.

| ZirOp                                | Prefix | Sub-op | Notes                              |
|--------------------------------------|--------|--------|------------------------------------|
| `i8x16.relaxed_swizzle`              | 0xFD   | 256    | -                                  |
| `i32x4.relaxed_trunc_f32x4_s`        | 0xFD   | 257    | -                                  |
| `i32x4.relaxed_trunc_f32x4_u`        | 0xFD   | 258    | -                                  |
| `i32x4.relaxed_trunc_f64x2_s_zero`   | 0xFD   | 259    | -                                  |
| `i32x4.relaxed_trunc_f64x2_u_zero`   | 0xFD   | 260    | -                                  |
| `f32x4.relaxed_madd`                 | 0xFD   | 261    | -                                  |
| `f32x4.relaxed_nmadd`                | 0xFD   | 262    | -                                  |
| `f64x2.relaxed_madd`                 | 0xFD   | 263    | -                                  |
| `f64x2.relaxed_nmadd`                | 0xFD   | 264    | -                                  |
| `i8x16.relaxed_laneselect`           | 0xFD   | 265    | -                                  |
| `i16x8.relaxed_laneselect`           | 0xFD   | 266    | -                                  |
| `i32x4.relaxed_laneselect`           | 0xFD   | 267    | -                                  |
| `i64x2.relaxed_laneselect`           | 0xFD   | 268    | -                                  |
| `f32x4.relaxed_min`                  | 0xFD   | 269    | -                                  |
| `f32x4.relaxed_max`                  | 0xFD   | 270    | -                                  |
| `f64x2.relaxed_min`                  | 0xFD   | 271    | -                                  |
| `f64x2.relaxed_max`                  | 0xFD   | 272    | -                                  |
| `i16x8.relaxed_q15mulr_s`            | 0xFD   | 273    | -                                  |
| `i16x8.relaxed_dot_i8x16_i7x16_s`    | 0xFD   | 274    | -                                  |
| `i32x4.relaxed_dot_i8x16_i7x16_add_s`| 0xFD   | 275    | -                                  |

## wide-arith — i64.{add,sub}128 / i64.mul_wide_{s,u}

Proposal: <https://github.com/WebAssembly/wide-arithmetic>. Merged
into Wasm 3.0. 0xFC-prefixed sub-opcodes.

| ZirOp              | Prefix | Sub-op | Notes                                  |
|--------------------|--------|--------|----------------------------------------|
| `i64.add128`       | 0xFC   | 19     | 128-bit add (two i64 → two i64)        |
| `i64.sub128`       | 0xFC   | 20     | 128-bit sub                            |
| `i64.mul_wide_s`   | 0xFC   | 21     | i64 × i64 → 128-bit signed product     |
| `i64.mul_wide_u`   | 0xFC   | 22     | i64 × i64 → 128-bit unsigned product   |

## custom-page-sizes — memory.discard

Proposal: <https://github.com/WebAssembly/custom-page-sizes>.
Merged into Wasm 3.0.

| ZirOp             | Prefix | Sub-op | Notes                                |
|-------------------|--------|--------|--------------------------------------|
| `memory.discard`  | 0xFC   | 23     | Hint to drop physical pages          |

## Status of files in src/instruction/wasm_3_0/

44 placeholder files present (refreshed 2026-05-21 per §9.12-G);
no handler bodies registered — each is a one-op stub that maps
to a slot in the ZirOp catalogue.

**GC proposal** (~25 files):
- arrays: `array_new.zig`, `array_new_default.zig`,
  `array_new_fixed.zig`, `array_new_data.zig`, `array_new_elem.zig`,
  `array_get.zig`, `array_get_s.zig`, `array_get_u.zig`,
  `array_set.zig`, `array_len.zig`, `array_copy.zig`,
  `array_fill.zig`, `array_init_data.zig`, `array_init_elem.zig`.
- structs: `struct_new.zig`, `struct_new_default.zig`,
  `struct_get.zig`, `struct_get_s.zig`, `struct_get_u.zig`,
  `struct_set.zig`.
- references / casts: `ref_test.zig`, `ref_test_null.zig`,
  `ref_cast.zig`, `ref_cast_null.zig`, `ref_as_non_null.zig`,
  `ref_i31.zig`, `i31_get_s.zig`, `i31_get_u.zig`,
  `any_convert_extern.zig`, `extern_convert_any.zig`,
  `br_on_cast.zig`, `br_on_cast_fail.zig`, `br_on_null.zig`,
  `br_on_non_null.zig`.

**Exception-handling proposal** (3 files): `throw.zig`,
`throw_ref.zig`, `try_table.zig`.

**Tail-call / typed-funcref proposals** (4 files):
`call_ref.zig`, `return_call.zig`, `return_call_indirect.zig`,
`return_call_ref.zig`.

**Pre-existing single-file proposals** (3 files):
`custom_page_sizes.zig`, `extended_const.zig`, `wide_arith.zig`.

### Coverage gaps (vs §9.12-G exit criteria)

§9.12-G demands "all Phase 10 feature ZirOps reject with
`Error.UnsupportedOpForBuildLevel` at `comptime`". Each
placeholder above MUST contain that comptime-reject body
once registered; the audit at Phase 10 open verifies coverage.

**Still missing at file-level** (per §9.12-G coverage check):

- `memory64`: no dedicated wasm_3_0 placeholder file. The two
  new ZirOps `memory.size_64` / `memory.grow_64` (per the
  table above) share opcodes with the MVP forms and dispatch
  on memory index type — placement may end up in
  `src/instruction/wasm_1_0/` with index-type variant
  selection rather than as separate wasm_3_0 files.
- `relaxed-simd`: no placeholders. Relaxed-SIMD ops live in the
  0xFD-prefix SIMD family and belong under
  `src/instruction/wasm_3_0/relaxed_simd/` (or a single
  `relaxed_simd.zig` register-many) when added.
- `multi-memory`: no opcodes (existing memory ops gain a
  `memidx` immediate); placeholder file unnecessary, but
  the dispatch wiring needs a Phase 10 audit.

These gaps are tracked under §9.12-G deliverable (b) — extend
`src/instruction/wasm_3_0/` placeholders to cover all Phase 10
features.

## Sub-opcode source verification

The numbers above were transcribed by reading each proposal's
`document/core/binary.rst` and `wasm-tools/crates/wasmparser/src/
binary_reader.rs`. Re-verify at Phase 10 open by walking
`dispatch_collector` against this table and surfacing
mismatches; that script is the eventual machine-generated
replacement for the table prose (per §9.12-G "(collector
machine-generate)" note).

## See

- ROADMAP §9.12-G — Phase 10 prep substrate row
- `src/ir/zir.zig` — ZirOp enum (lines 555-700+; Wasm 3.0 + Phase
  3-4 proposals)
- `src/instruction/wasm_3_0/` — placeholders
- `~/Documents/OSS/WebAssembly/<proposal>/document/core/binary.rst`
  — upstream opcode definitions
