# Dispatcher wire design (§9.12-B / B3 design note)

> **Doc-state**: ACTIVE — load-bearing reference (Phase 9+ scope).

> Where each of the 5 per-axis dispatchers per ADR-0073 / ADR-0023
> §4.5 amend actually hooks into the existing codebase. Authored
> during §9.12-B / B3 as the design output before per-axis wiring
> chunks (B4..B?). Living document — amend as each axis lands.

## §1 The mismatch

ADR-0073 says the 5 dispatch axes are `validate / lower / arm64 /
x86_64 / interp`, all keyed on `ZirOp`. The existing dispatcher
sites do not all key on `ZirOp`:

| Site                                        | Keyed on            | Notes |
|---------------------------------------------|---------------------|-------|
| `src/validate/validator.zig:dispatch()`     | Wasm byte (`u8`)    | Runs **during** parsing; type-stack tracking |
| `src/ir/lower.zig`                          | Wasm byte (`u8`)    | Lowers byte → `ZirOp` tag + payload |
| `src/engine/codegen/arm64/emit.zig`         | `ZirOp`             | ZIR → arm64 machine code |
| `src/engine/codegen/x86_64/emit.zig`        | `ZirOp`             | ZIR → x86_64 machine code |
| `src/interp/mvp.zig` + `src/interp/dispatch.zig` | `ZirOp`        | Via `DispatchTable.interp[@intFromEnum(op)]` (already in dispatch-table shape) |

So 2 of the 5 dispatchers are at the **bytecode** layer; 3 are at the
**ZirOp** layer. The dispatch_collector currently keys on `ZirOp`.

## §2 Per-axis wire-in approach

### §2.1 `validate` (bytecode → validate)

Two viable approaches:

**(A) Bytecode-keyed dispatcher in dispatch_collector**: extend
`dispatch_collector.dispatcher(.validate)` to accept `(u8, *Validator)`
and route via a comptime-built `[256]?fn(*Validator)` table that
maps Wasm bytes to per-op modules' `.handlers.validate` (each per-op
file additionally declares `pub const wasm_byte: u8 = 0x6A;`).

- Pros: validator.zig wire is `try dispatcher(.validate)(op_byte, self)`.
- Cons: per-op file gains a 2nd metadata field; ZIR-vs-bytecode dual identity.

**(B) Validator computes ZirOp on the fly**: validator.zig calls
`lower.byteToZirOp(op)` (helper extracted from lower.zig) to get the
ZirOp tag, then `dispatcher(.validate)(zir_tag, self)`.

- Pros: per-op file stays ZirOp-keyed (single identity).
- Cons: requires lifting `byteToZirOp` out of lower.zig as a pure
  function (currently the byte→ZirOp mapping is embedded in
  `lower.lowerInstruction` payload handling).

**Recommended**: (B). The per-op file's identity is its `ZirOp` tag;
the bytecode↔ZirOp mapping is a separate concern that lives in
parse/lower infrastructure.

### §2.2 `lower` (bytecode → ZirOp + payload)

Lower's job is **producing** ZirOp tags. There's no "per-op file
lowers the op" structure — the lower step IS the mapping. The
correct interpretation:

- Per-op file's `handlers.lower` is the **payload-construction**
  fn for that op: given `(ctx: *LowerCtx, /* immediates */)`, it
  populates the `ZirInstr` extra fields.
- Dispatcher fires after the byte-tag mapping is decided.

The current `lower.zig` has a master switch over bytecode; each arm
populates `ZirInstr` with op-specific payload. The wire-in: convert
each arm into a call to `dispatcher(.lower)(zir_tag, lower_ctx)`.

Since lower IS the byte→ZirOp source, the wire actually means:
"after lower decided the ZirOp tag, route the payload-emit through
the dispatcher".

### §2.3 `arm64` + `x86_64` emit

Cleanest wire targets — both already key on `ZirOp` via switch.
Replace each arm with `try dispatcher(.<axis>)(op_tag, &emit_ctx)`
with NotMigrated → legacy switch fallback.

**Per-axis collector split (per ADR-0074, B9 amend)**: the arm64 /
x86_64 axes are dispatched from a **Zone 2** collector at
`src/engine/codegen/dispatch_collector.zig` (new in B10+), not from
the Zone 1 `src/ir/dispatch_collector.zig`. The two collectors share
the `Axis` enum + `enabledByBuild` filter (both at Zone 1). The wire
shape at `arm64/emit.zig` / `x86_64/emit.zig` is the same; only the
import path changes (from `ir/dispatch_collector` to
`engine/codegen/dispatch_collector`). The B4/B5 wires currently
target the Zone 1 collector — they stay valid through B9 (i32.add
stubs still resolve via the Zone 1 collector); they retarget to the
Zone 2 collector when B10 lands the per-arch op files.

### §2.4 `interp` (via DispatchTable)

The runtime interpreter loop uses `DispatchTable.interp[op]` (a
function pointer table indexed by ZirOp). The wire-in:

- At runtime init, `DispatchTable.interp` is populated. The
  collector becomes the **populator**: for each migrated op_mod
  with non-stub `.handlers.interp`, install it in the table.
  Non-migrated ops keep the legacy interp handler.

This is a **table-population** dispatcher rather than a
per-call switch — different shape from validate/emit/lower. The
collector's `dispatcher(.interp)` may not even be the right
abstraction; instead, a `pub fn populateDispatchTable(table: *DispatchTable) void`
in dispatch_collector that walks `collected_ops` and writes
`table.interp[@intFromEnum(op_mod.op_tag)] = wrap(op_mod.handlers.interp)`.

## §3 Recommended B-sub-chunk sequence (revised)

| Sub-chunk | Description |
|---|---|
| B3 (this commit) | Design note (this file). |
| B4 | Wire `arm64/emit.zig` (cleanest; ZirOp-keyed; legacy switch fallback). Implement for i32.add as proof-of-pattern. |
| B5 | Wire `x86_64/emit.zig` (mirror B4 pattern). |
| B6 | Wire `interp` via `populateDispatchTable` in dispatch_collector. Implement for i32.add. |
| B7 | Extract `byteToZirOp` helper from lower.zig; wire `validator.zig` via §2.1 (B). |
| B8 | Wire `lower.zig` payload-construction routing. |
| B9..Bn | Per-op-file migrations (cohorts of 5-15 ops per chunk per LOOP.md). |
| B(n+1) | CLI declarative form. |
| B(n+2) | c_api declarative form. |
| B(n+3) | WASI declarative form. |
| B(n+4) | `scripts/check_build_dce.sh --gate` exit-criterion verification across 6-build matrix. |

## §4 Open design questions for future ADRs

1. **Per-axis ctx types**: each axis has a distinct ctx (validator
   `*Validator`, lower `*LowerCtx`, emit `*Arm64EmitCtx`, ...).
   Currently `dispatcher(axis: Axis) fn(op, ctx: anytype)` accepts
   `anytype` — that loses type-safety. Phase 10 may want a typed
   `AxisCtx(axis: Axis)` mapping. For now, anytype is acceptable.
2. **Per-op file granularity for stateless ops vs stateful**: some
   ops (`i32.add`) are pure compute; others (`call_indirect`) are
   stateful + cross-cutting. Per-op file may not be the right
   granularity for the stateful set. Phase 10 re-evaluate based on
   B-sub-chunk experience.
3. **Comptime `inline switch` IR-size scaling**: the
   `q3-zig-inline-switch` spike measured 581 tags at +1.9% .text.
   Phase 10's expansion to ~700-900 tags is unmeasured. Re-spike at
   that boundary.

## §5 References

- ADR-0023 §4.5 amend (per-op file pattern formal adoption)
- ADR-0073 (all-layer build-option DCE substrate)
- ADR-0071 §Q3 (Hypothesis C adoption)
- Master plan §9.12-B (Q3 C adoption completion)
- `private/spikes/q3-build-option-dce-poc/` (spike that validated the substrate)
- `src/ir/dispatch_collector.zig` (the framework)
- `src/instruction/wasm_1_0/i32_add.zig` (the first per-op template)
