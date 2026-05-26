# 0120 — JIT payload-marshalling shape for EH throw → catch propagation

- **Status**: Proposed
- **Date**: 2026-05-28
- **Author**: zwasm-from-scratch loop
- **Tags**: phase-10, exception-handling, codegen, abi

## Context

ADR-0114 D1 codified the runtime `Exception` extern struct with
inline payload (`payload: [*]Value`, `payload_len: u32`,
`param_count: u32`), and D6 codified the `zwasm_throw` thread-
local trampoline that stores `(tag, params, fp_at_throw,
pc_at_throw)` into a thread-local Exception slot before invoking
the FP-walk unwind.

What ADR-0114 did NOT specify is the **JIT-emitted byte sequence**
at the throw site and the catch landing pad that moves payload
values between the regalloc operand stack and the thread-local
Exception object. The integration plan
(`.dev/phase10_eh_integration_plan.md` §IT-3) flagged this as an
open design question:

> IT-3's payload marshalling shape: stack-region for N>2 payloads,
> or heap-Exception object? ADR-0114 D1 picked inline payload for
> the interp; codegen has more flexibility. Recommend: same inline
> shape for ABI symmetry.

The current state (HEAD `f37977df`): throw.emit marshals tag_idx
into W0/RDI and calls the trampoline; catch landing pad PC is
recorded in `HandlerEntry.landing_pad_pc` but the JIT emits no
code at that PC that pushes the payload onto the catch block's
operand stack. End-to-end probe with a 1-param tag confirms the
silent payload-drop: `throw $e0 (i32.const 88)` caught by
`catch $e0` → catch block reads stack and returns 0 (uninitialized
slot), not 88.

This ADR codifies the choice so the IT-3 / IT-2 follow-on impl
cycles can proceed without re-litigating the design.

## Decision

**Use a fixed-size per-Runtime payload buffer with throw-side
write + landing-pad-side read**:

1. **Per-Runtime field** (Zone 1, `src/runtime/runtime.zig`):
   ```zig
   /// EH payload staging region — written by JIT throw sites
   /// (each pops N vregs and stores them here, N ≤ 16 per
   /// ADR-0114 D1's inline-payload cap), read by JIT catch
   /// landing pads (push each as a fresh vreg before the catch
   /// block's body runs). Co-located with the thread-local
   /// Exception slot (ADR-0114 D6).
   eh_payload_buf: [16]u64 = [_]u64{0} ** 16,
   eh_payload_len: u32 = 0,
   ```

   Width = `u64` (covers i32/i64/f32/f64; v128/exnref tag params
   are out of scope for v0.1 — see Consequences §3).

2. **Throw-site emit shape** (per-arch
   `src/engine/codegen/{arm64,x86_64}/ops/wasm_3_0/throw.zig`):
   ```text
   For each i in [0, N): pop vreg, store value at
   [runtime_ptr + eh_payload_buf_off + i*8]
   Store N at [runtime_ptr + eh_payload_len_off]
   MOV tag_idx into argreg-0 (existing IT-3 step 2)
   BLR / CALL trampoline (existing)
   ```

   N = `tag_param_counts[tag_idx]` — read from EmitCtx at emit
   time (compile-time-known per ZirFunc's referenced tag-section
   data; threaded from CompiledWasm.tag_param_counts through
   EmitCtx.InitArgs).

   For N=0 (e.g., the existing IT-6 `throw $e1 → catch $e1
   returns 77` test's `(tag $e1)` shape), the payload-write loop
   degenerates to a single `STR Wzr` for `eh_payload_len = 0`;
   the regalloc operand stack is undisturbed.

3. **Catch-landing-pad emit shape** (synthesized by
   `op_exception_handling.try_table.emit` at the per-catch
   landing_pad_pc — i.e., immediately after the `end` of the
   try_table block, before the catch's target-block body):
   ```text
   For each i in [0, N): LDR W/X, [runtime_ptr + eh_payload_buf_off + i*8]
   → STR into next available regalloc spill slot (push as fresh vreg)
   For catch_ref / catch_all_ref: additionally LDR exnref pointer
   from thread-local Exception slot + push as a fresh vreg
   ```

   N = same `tag_param_counts[tag_idx]` for `catch_` /
   `catch_ref`; N=0 for `catch_all` / `catch_all_ref`.

4. **EmitCtx threading**: add `tag_param_counts: []const u32 =
   &.{}` field to per-arch EmitCtx (mirrors `globals_offsets` +
   `memory0_idx_type` default-empty pattern). Initialised by
   `compile()` from `CompiledWasm.tag_param_counts`. Default-empty
   keeps all 36+ existing EmitCtx call sites behaviour-preserving;
   only EH-touching paths consult it.

5. **Invariant** (mechanised via `comment_as_invariant.md` + a
   comptime-assert sibling): `eh_payload_buf.len * 8 ==
   payload_buf_byte_cap`. The 16-slot cap is shared with
   ADR-0114 D1's `Exception.payload[16]Value` inline cap; if
   either is widened, both grow together.

## Alternatives considered

- **A. Stack region per try_table** — reserve N words just below
  the try_table's `fp + frame_bytes` boundary; throw writes,
  catch reads. Rejected: requires the throw emit to know which
  enclosing try_table the throw lies in at emit time (currently
  determined by the unwinder at dispatch time via the
  ExceptionTable PC range lookup); the throw doesn't have
  per-try_table frame metadata at emit. Forcing this would
  pessimise the existing IT-6 trampoline path's "throw-site is
  PC-only" invariant.

- **B. Per-Exception heap payload** (mirror wasmtime's
  `Exception` heap object). Rejected: heap allocation on every
  throw breaks ADR-0114's "throws should be on par with
  bounds-trap dispatch latency" target; zwasm v2's per-Runtime
  arena gives a sub-cycle pointer-bump alternative, but then the
  throw site must call into the runtime to claim a payload slot
  rather than writing to a fixed buffer — extra dispatch overhead
  with no benefit when payloads are bounded by N ≤ 16.

- **C. Pass payload via dispatcher argregs**. Rejected: dispatcher
  is a Zig function with fixed signature (`dispatchThrow(table,
  code_map, site, max_depth)`); extending it to varargs-per-N
  payloads would force per-N specialisations OR
  in-band-with-tag_idx packing. Both worse than the dedicated
  buffer.

## Consequences

1. **Bundle-friendly impl ordering**: the cycle sequence is
   - Cycle 1 (this bundle's first impl chunk after the ADR
     lands): add `eh_payload_buf` + `eh_payload_len` fields to
     `Runtime`; add `tag_param_counts` field to EmitCtx;
     thread through `compile()`. Same-cycle observability via a
     unit test that constructs Runtime + verifies the fields'
     default zero/empty state.
   - Cycle 2: throw.emit reads `tag_param_counts[tag_idx]`,
     emits the pop+store sequence (arm64 first; x86_64 follows
     same cycle bundled per the established arch-symmetry
     rhythm).
   - Cycle 3: try_table.emit synthesizes the catch-landing-pad
     prologue (load payload values + push to regalloc operand
     stack). Same cycle: end-to-end test `throw + catch_ with
     i32 payload returns 88` (currently silent-drops, returns 0).
   - Cycle 4: catch_ref / catch_all_ref exnref push. Builds on
     the interp 10.E-exnref-b path's exnref dispatch shape.
   - Cycle 5: spec-corpus runner wiring + close 10.E.

2. **Throws with N=0 tags pay zero extra emit cost**: the
   per-i loop has 0 iterations; the `STR Wzr` for
   `eh_payload_len = 0` is 4 bytes per throw site. Net delta on
   the existing `throw + catch_all returns 42` IT-6 test: +4
   bytes per throw, no semantic change.

3. **v128 / exnref tag params deferred to v0.2**: the `u64`
   buffer width covers all v0.1 Wasm-3.0 tag-param types
   (i32/i64/f32/f64). v128 (16-byte) and `exnref` (16-byte
   `?*Exception`) tag params would require either widening the
   buffer to 16-byte slots OR a sidecar buffer. Filed as
   follow-up: D-NNN at v0.2 scope (no Phase 10 row blocked).

4. **Thread-locality**: `eh_payload_buf` is a per-`Runtime`
   field, not thread-local. v2's current single-threaded model
   makes this safe; multi-threaded guests (Phase 14+) need
   per-thread payload bufs paired with the per-thread Exception
   slot, but the field shape stays the same — just promoted to
   a `[*]ThreadLocal` lookup.

## References

- ADR-0114 D1 (Exception extern struct + inline payload cap=16)
- ADR-0114 D6 (zwasm_throw thread-local trampoline)
- ADR-0119 (naked-Zig trampoline impl shape)
- `.dev/phase10_eh_integration_plan.md` §IT-3 (open question)
- `.dev/phase_log/phase10.md` §10.E-N-1 / §10.E-5c (interp-side
  precedent for payload pop + push via tag_param_counts)
- `src/runtime/runtime.zig:205-213` (existing
  `tag_param_counts` field)
- `src/engine/runner.zig:170` (CompiledWasm.tag_param_counts)
- `src/engine/codegen/shared/exception_table.zig:51`
  (HandlerEntry shape — landing_pad_pc consumes this ADR's emit
  sequence)
