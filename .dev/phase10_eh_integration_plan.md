# Phase 10 EH-on-JIT integration plan

> **Doc-state**: ACTIVE — load-bearing for the 10.E-codegen-4c..6
> sub-chunks. Drafted via /continue autonomous prep path
> 2026-05-26 per lesson `2026-05-26-eh-codegen-foundation-atom-rhythm.md`:
> foundation chain reached natural pause; this doc captures the
> integration path so the next implementer (user collab or
> autonomous multi-cycle session) can resume without
> re-deriving the design.

## Foundation already landed (cycles 10.E-codegen-1..4b + N-3 + N-4)

| Component | Path | Purpose |
|---|---|---|
| exception_table.zig | shared/ | Per-Instance HandlerEntry storage + Builder + lookup |
| unwind.zig | shared/ | FP-walk algorithm; UnwindResult union |
| frame_chain.zig | per-arch (arm64+x86_64) | Reads `[FP, 0]` / `[FP, 8]` raw frame prefix |
| frame_chain_adapter.zig | shared/ | Bridges per-arch frame_chain → unwind.FrameChainLoader via NormalizePcFn |
| code_map.zig | shared/ | Per-Instance Entry { start_addr, len, func_idx, frame_bytes } + binary-search lookup; normalizeForUnwind closes the adapter slot |
| zwasm_throw.zig | shared/ | Dispatcher entry: code_map.lookup → adapter ctx → unwind.walk |
| sp_restore.zig | per-arch | emitSpFromGpr / emitSpRestoreFull (frame_bytes-aware) |
| EmitCtx.exception_table_builder | per-arch ctx.zig | Optional `?*ExceptionTable.Builder = null` field |
| Per-op skeletons | per-arch ops/wasm_3_0/ | try_table/throw/throw_ref with ADR-0113 axes; emit returns UnsupportedOp |
| Runtime.tag_param_counts | instantiate.zig | Production-wired through instantiateRuntime |

End-to-end test fixture path: `dispatchThrow → unwind.walk → handler` works against synthetic frame chains; 4 unit tests in zwasm_throw.zig prove the data flow.

## What remains: 6 integration tasks

### IT-1. EmitCtx.exception_table_builder population at compile entry

**Where**: `src/engine/codegen/{arm64,x86_64}/emit.zig::compile()`.

**What**: Allocate an `ExceptionTable.Builder` on the function-emit
arena when the function contains any try_table op; set
`ctx.exception_table_builder = &builder`. Detection: scan
`func.instrs` once at compile entry for `.try_table` op tag.

**Why now (not later)**: per-op `op_exception_handling.try_table.emit`
needs the builder pointer; if null, emit returns `UnsupportedOp`
and the function fails to compile. The detection scan adds O(n)
to compile but only fires for functions with EH.

**Acceptance**: a function with try_table compiles past the EH
skeleton's `UnsupportedOp` return; ctx.exception_table_builder
is non-null inside the emit handler.

### IT-2. try_table emit body (10.E-codegen-4b-2)

**Where**: `src/engine/codegen/{arm64,x86_64}/ops/wasm_3_0/try_table.zig`.

**What**: For each catch clause in `ZirFunc.eh_catch_entries[ins.catches_start .. ins.catches_end]`:
- Compute `pc_start = ctx.buf.items.len` (current emit byte
  offset; converted to module-relative PC at finalize via
  CodeMap).
- Record a placeholder `pc_end` fixup; patch at the matching
  `end` op emit (mirrors `bounds_fixups` shape in EmitCtx).
- Compute `landing_pad_pc` = the catch-label target's emit
  offset (looked up via ctx.labels — same mechanism as
  `br`/`br_table`).
- `ctx.exception_table_builder.?.add(ctx.allocator, .{
    .pc_start, .pc_end (placeholder), .tag_idx, .landing_pad_pc, .kind
  })`.

Emit zero JIT bytes for the op itself; the inner block emits
via existing `block` recursion.

**Acceptance**: HandlerEntry count after compile matches the
parsed catch count; pc_start / pc_end / tag_idx / kind round-trip
correctly.

### IT-3. throw / throw_ref emit body (10.E-codegen-4c)

**Where**: `src/engine/codegen/{arm64,x86_64}/ops/wasm_3_0/throw{,_ref}.zig`.

**What**: Per ADR-0114 D6 sequence:
1. Pop N values from operand stack into a payload buffer (N =
   `tag_param_counts[tag_idx]`; compile-time known via the
   ZirFunc's referenced tag-section data).
2. Marshal `tag_idx` (u32) into the dispatcher's first argreg
   (arm64 X0 / x86_64 RDI — same convention as op_call).
3. Marshal payload base + length into argregs (2 + N or via
   stack overflow region for large N).
4. Emit a `CALL zwasm_throw` site (CallFixup placeholder to be
   resolved by the linker against `shared/zwasm_throw.dispatchThrow`).
5. Post-CALL: branch on the result (UnwindResult). On
   `.handler`, JMP to landing_pad_pc via `sp_restore.emitSpRestoreFull`
   + landing_pad_pc fetch from CodeMap. On `.uncaught`, set
   trap_flag=1 + emit standard trap-stub branch.

throw_ref: same shape but pop the exnref first and dereference
via `Value.refAsExceptionPtr` (the dispatcher then re-throws
that Exception).

**Acceptance**: minimal `throw 0 () catch_all` fixture compiles +
runs, exiting via the trap path (no handler installed yet).

### IT-4. CodeMap.Entry population at JIT link time

**Where**: `src/engine/codegen/shared/compile.zig` (or wherever
function start addrs are assigned after emit).

**What**: As each function's emit-buffer is mapped + executable,
populate the per-Instance `CodeMap.Builder.add({start_addr, len,
func_idx, frame_bytes})`. Finalize the builder once after all
functions are linked.

**Acceptance**: `code_map.lookup(any_addr_in_func_N)` returns
`.inside { relative_pc, func_idx = N }`.

### IT-5. CompiledWasm gains `exception_table: ExceptionTable`

**Where**: `src/engine/runner.zig` (or wherever CompiledWasm is
defined).

**What**: After all functions' per-op `Builder.add` calls land,
collect into a single per-Instance `ExceptionTable`. Owned by
the same arena as `tag_param_counts` / `globals_offsets`.

The Runtime's `dispatchThrow` call site (10.E-codegen-3e
landed) reads this field via the `*Runtime` parameter (already
threaded through the assembly trampoline glue per ADR-0114 D6).

**Acceptance**: a CompiledWasm with try_table has
`exception_table.entries.len > 0`.

### IT-6. zwasm_throw assembly entry glue (10.E-codegen-3i)

**Where**: per-arch `src/engine/codegen/{arm64,x86_64}/throw_trampoline.{zig,s}` (NEW files).

**What**: small assembly stub that:
1. Captures throw-site FP (X29 / RBP) + LR (X30) into a
   `ThrowSite` record on the stack.
2. Loads the Runtime pointer (X19 / R15) into the first argreg.
3. Calls `shared/zwasm_throw.dispatchThrow(table, code_map,
   throw_site, max_depth)`.
4. On `.handler` return: MOV SP, handler_fp + frame_bytes
   adjustment via `sp_restore.emitSpRestoreFull`; BR / JMP to
   landing_pad_pc.
5. On `.uncaught`: STR W17, [X19, #trap_flag_off] + MOV X0,
   #0; LDP X29, X30, [SP], #16 + RET (mirrors existing
   bounds-trap stub shape).

**Acceptance**: end-to-end `throw 0` fixture catches via
`try_table catch_all 0`, lands at the catch_all block, and
returns normally; uncaught variant traps.

## Sequencing recommendation

Cycle 1 (IT-1): EmitCtx.exception_table_builder population
+ trivial test that a try_table-containing function reaches the
per-op emit handler (still returns UnsupportedOp).

Cycle 2 (IT-2): try_table emit body. Acceptance via direct
HandlerEntry-count check; no end-to-end throw yet.

Cycle 3 (IT-3 + IT-5): throw / throw_ref emit body + CompiledWasm
exception_table field. Throws will hit the dispatcher; .uncaught
path returns. The CompiledWasm field collection mirrors
`tag_param_counts`.

Cycle 4 (IT-4): CodeMap.Entry population. Without this, the
dispatcher's PC normalization returns non_jit_pc_sentinel for
every throw site; the walker correctly walks but can never find
a handler. IT-4 closes the data path.

Cycle 5 (IT-6): assembly trampoline glue. Once the trampoline
exists, the .handler path lands correctly.

Cycle 6: spec corpus fixture run + close 10.E.

## Per-cycle test fixtures

| Cycle | Fixture | What it proves |
|---|---|---|
| 1 | minimal try_table compile | EmitCtx field threaded |
| 2 | try_table + catch_all + i32.const + br 0 | HandlerEntry registered |
| 3 | throw 0 / catch_all (no payload) | Dispatcher reached, .uncaught path |
| 4 | throw 0 / catch_all (with payload) | CodeMap.lookup hit |
| 5 | end-to-end throw → catch_all | Assembly glue closes path |
| 6 | wasm-3.0-assert/exception-handling/ corpus | 76 assertion green |

## Open questions for user collab

- IT-3's payload marshalling shape: stack-region for N>2 payloads,
  or heap-Exception object? ADR-0114 D1 picked inline payload
  for the interp; codegen has more flexibility. Recommend:
  same inline shape for ABI symmetry (the dispatcher reads
  payload from a stack region the throw emit set up).

- IT-6's assembly entry: pure Zig wrapping a function ptr load
  + indirect call, OR per-arch `.s` file? Pure Zig is portable
  but the stack-frame discipline at the throw boundary may
  need raw asm to capture X29/RBP precisely. Recommend:
  start with pure Zig + naked function attribute; fall back
  to `.s` if the naked-function semantics don't hold.

## Why this doc exists

The autonomous /continue loop shipped 13 foundation cycles + 5
ADR-enrichment cycles without converging on end-to-end EH
behavior (lesson `2026-05-26-eh-codegen-foundation-atom-rhythm.md`).
The integration needs 6 cycles with strong continuity; per-cycle
fragmentation re-derives the design surface each time.

This doc encodes the design surface so the next continuous
session (user collab or autonomous multi-cycle resume) can pick
up at IT-1 with the integration plan already settled. ADR-0114
+ all foundation files are referenced; nothing new is invented
here — only the wiring sequence is consolidated.

## References

- ADR-0114 — Exception Handling design (the source ADR).
- `2026-05-26-eh-codegen-foundation-atom-rhythm.md` — the lesson
  that motivated this consolidation.
- All 10.E-codegen-{1..4b} commits + 10.E-N-{3,4} (foundation +
  production tag wiring).
- ADR-0076 D2 — single-push commit pair (per-cycle gate
  discipline that applies to IT-1..6).
