# 10.Z chunk plan — ZirInstr.payload `u32` → `u64`

> **Doc-state**: ACTIVE — gates 10.Z second attempt.

## Context

ROADMAP §10 / 10.Z calls for widening `ZirInstr.payload`
(`src/ir/zir.zig:73`) from `u32` to `u64` to follow upstream
(wasmtime / wasmer-LLVM / WAMR / spec ref) and carry memory64
offsets at spec-full width. Row text: "Spike なし; 失敗時 chunk
revert".

## Cycle-1 attempt (2026-05-25, reverted)

Mechanical widen of the field surfaced **131 compile errors**
across the codebase, distributed as:

| Error class                                              | Count |
|----------------------------------------------------------|-------|
| `error: expected type 'u32', found 'u64'`                 |   120 |
| `error: @bitCast size mismatch: 'u64' has 64 bits but 'i32' has 32 bits` |     7 |
| `error: @bitCast size mismatch: 'i32' has 32 bits but 'u64' has 64 bits` |     4 |

Top hot files: `src/instruction/wasm_1_0/memory.zig` (load/store
handlers passing `instr.payload` to `loadInt(rt, T, signed, offset:
u32)` etc.); secondary cascades in interp / lower / codegen.

Cycle-1 reverted; build returned to 1827/1841 PASS.

## Cycle-2 strategy (subagent-driven mechanical migration)

The cascade is mechanical-but-numerous. Cycle-2 will:

1. **Delegate** the bulk migration to an Explore subagent with
   the brief: "After widening `ZirInstr.payload: u64`, propagate
   the type through every call site so the Zig 0.16 type checker
   re-accepts. For sites where the consumer is a low-level
   helper signature (e.g. `loadInt(rt, T, signed, offset)`):
   widen the helper's `offset` parameter to `u64` too; downstream
   `rt.memory[offset..]` slice access already takes `usize`.
   For sites where the consumer is a packed struct field (e.g.
   `LowerInstr.payload: u32` at zir.zig:225): widen the field
   too. For @bitCast size-mismatches: re-shape via @truncate /
   @as(u64, _) as appropriate."
2. **Sub-divide** the 131 sites into 3 cohorts: (a) memory-op
   handlers (load/store) — bulk of `wasm_1_0/memory.zig` +
   `wasm_2_0/bulk_memory.zig`; (b) `LowerInstr.payload`
   propagation (zir.zig:225 + lower.zig consumers); (c) misc
   long-tail (interp dispatch helpers, codegen emit sites).
3. **Verify** byte-identical JIT emit per the ROADMAP row's
   "既存 emit_test_*.zig byte-identical 確認" constraint —
   regalloc + emit only consume the low 32 bits today, so
   widening the IR field shouldn't change emitted bytes for any
   Wasm 1.0/2.0 fixture (which encodes ≤ 32-bit offsets / consts).
4. **Phase 9 corpus** must stay green at 3-host gate after the
   widen.
5. **Failure path** (per ROADMAP "失敗時 chunk revert"): if
   cycle-2 subagent attempt completes but leaves a residual
   non-mechanical issue (e.g. a u32-packed struct on the
   serialised AOT path), revert and reframe as "10.Z deferred
   until memory64 (10.M) reaches the actual offset > 4 GiB
   carry point".

## Cycle-3 contingency

If cycle-2 fails too, cycle-3 considers narrowing scope: instead
of widening the field universally, introduce `payload_hi: u32`
as a paired secondary slot used only by memory64-offset emit
sites. This preserves the existing u32 payload semantics for
every other op. Architectural cost: ZirInstr grows by 4 bytes
(`{op, payload, extra, payload_hi}` = 1+4+4+4 = 13 → padded 16
bytes); per-instr memory overhead +33%. Acceptable trade-off if
the universal widen has subtle byte-identical-emit breakages
the cycle-2 audit can't quickly resolve.

## Architectural-chunk cap

Per `.claude/rules/architectural_spike.md` + LOOP.md "Chunk
types", `architectural` chunks are capped at **3 cycles** without
measurable progress. 10.Z is on attempt 1/3.

## References

- ROADMAP §10 row 10.Z
- `phase10_design_plan_ja.md` §3.1 / Z.1 (referenced from ROADMAP row)
- `src/ir/zir.zig:73` (the field)
- `src/ir/zir.zig:225` (LowerInstr.payload mirror)
- Cycle-1 attempt cycle: this commit's HEAD
