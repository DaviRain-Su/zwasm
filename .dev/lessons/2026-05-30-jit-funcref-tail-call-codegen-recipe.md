# JIT funcref-call + tail-call codegen recipe (cyc198-211)

**Date**: 2026-05-30 · **Citing**: `ef34724c`..`92c06c60` · Phase 10 (10.TC/10.R JIT)

The arc that landed direct/indirect/recursion `return_call`, `call_ref`, and
`return_call_ref` JIT codegen on both arches. Reusable recipe + gotchas.

## Adding a new call/tail-call JIT op — the 4 moving parts

1. **liveness arm** (`src/ir/analysis/liveness.zig`, SHARED across arches). The
   FIRST gate — a missing arm → `UnsupportedOp[stackEffect-missing]` aborts
   `compileWasm` BEFORE emit even runs (mis-reads as an emit gap). `call_ref` =
   NON-terminator (mirror the `.call`/`.call_indirect` block: pop funcref + sig
   params, push results; sig from `module_types[payload]`). `return_call*` =
   TERMINATORs (join the `return`/`unreachable` drain branch; ADR-0113 §A).

2. **per-arch emit**. funcref operand = `@intFromPtr(*const FuncEntity)` (ref.func /
   Value.fromFuncRef). `call_ref` = pop funcref → null-check → `LDR/MOV` from
   `funcentity_funcptr_offset` → `BLR/CALL` → capture. `return_call_ref` = same
   front + tail-call tail (`frame_teardown` + `BR/JMP`) instead of CALL+capture.
   NO runtime sig-check (validator guarantees the funcref's type ⊑ `$sig`).

3. **dispatch ASYMMETRY** (non-obvious): arm64 wires call/call_indirect/return_call*/
   call_ref via the **manual `switch` in `arm64/emit.zig`** (the collected dispatch
   at emit.zig:775 runs first, falls through to the switch). x86_64 wires them via
   **collected per-op files** (`x86_64/ops/.../X.zig` → `op_*.emit*Ctx`, registered
   in `dispatch_collector_ops.zig` + the `collected_x86_64_ctx_ops` count test).
   When adding an op, MIRROR its sibling (`return_call` for `return_call_ref`).

4. **test** = a `runI32Export` byte-array module in `src/engine/runner.zig`.

## Gotchas

- **x86_64 JIT is RUNTIME-verifiable ONLY on ubuntu.** Mac is aarch64; `compileOne`
  is comptime-arch-locked (`shared/compile.zig:42` + x86_64 regalloc params). So an
  x86_64-only emit bug surfaces only on the ubuntu gate (ADR-0076 D3), and a fix
  can't be locally verified — land arm64 first (gate test to aarch64 + debt-row the
  x86_64 half per test_discipline §4), then mirror x86_64 + ungate + ubuntu-verify.
  Byte-disasm of x86_64 on Mac needs replicating compileOne with x86_64 params OR an
  ubuntu byte-dump round-trip (see D-208).
- **LEB128 in hand-written fixtures**: `i32.const 99` is NOT single byte `0x63` —
  `0x63` as signed-LEB sign-extends to -29 (0xFFFFFFE3). Use `0xE3 0x00` or a value
  < 64. (cyc199 indirect-call test "miscompile" was this fixture bug, not the impl.)
- **x86_64 `usesRuntimePtr` whitelist is load-bearing for funcref calls** (D-208,
  cyc213). call_ref/return_call_ref pass the runtime_ptr (`MOV <arg0>,R15`) AND emit
  a null-check trap-stub fixup (stub writes `[R15+trap_flag_off]`). If the op is NOT
  in `x86_64/usage.zig::usesRuntimePtr`, the prologue skips `MOV R15,RDI` → the trap
  stub writes trap_flag via a garbage R15 → a **null funcref returns 0 instead of
  trapping** (Mac arm64 immune — X19 always set). The POSITIVE test masked it: its
  module has `ref.func` (already whitelisted → R15 set up), the null test has
  `ref.null` (not whitelisted). New emit op that reads R15 / emits a trap-stub fixup
  MUST be added to the whitelist. `check_uses_runtime_ptr.sh` now follows the
  call-family delegation (thin `ops/**` files hid the R15 use in `op_call`/`op_tail_call`).

## Related

- D-205 (tail-call JIT, discharged) · D-206 (cross-module TC) · D-207 (discharged) ·
  D-208 (x86_64 funcref null-check) — RESOLVED cyc213: call_ref/return_call_ref were
  missing from `x86_64/usage.zig::usesRuntimePtr` (D-180-class gap; see Gotchas). The
  byte-dump (ndisasm) was the key probe — it showed correct JZ→trap-stub bytes using
  R15, with NO `MOV R15,RDI` in the prologue, pointing straight at the whitelist.
- Sibling lesson: `2026-05-28-x86_64-uses-runtime-ptr-eh-gap.md` (the EH `usesRuntimePtr`
  gap — same class; D-208 is its funcref-call twin).
- lesson `2026-05-30-clang-wasm-realworld-toolchain-recipe.md` (clang musttail).
