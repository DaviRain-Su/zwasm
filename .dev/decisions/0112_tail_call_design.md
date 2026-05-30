# 0112 — Tail Call design: inline cross-module emit + frame_teardown helper + terminator class

- **Status**: Accepted (2026-05-25; Phase 10 / 10.D ADR round close)
- **Date**: 2026-05-25
- **Author**: claude (autonomous loop, /continue prep path)
- **Tags**: tail-call, wasm-3.0, codegen, regalloc, terminator-class, safepoint-free, Phase 10 / 10.TC
- **Paired ROADMAP row**: §10 / 10.TC (impl), §10 / 10.D (this ADR's Accept gate)
- **Co-landed with**: ADR-0111 / ADR-0113..0117 (Phase 10 / 10.D round)

## Context

The Wasm 3.0 tail-call proposal adds `return_call`, `return_call_indirect`,
`return_call_ref` — these consume the caller's frame instead of layering
a new one, enabling unbounded mutual recursion and proper-tail-call
semantics for functional-language targets (OCaml, Hoot, Dart). The
proposal is shipped: clang's `__attribute__((musttail))` + emitted
`return_call` is in production for compilers targeting Wasm.

ROADMAP §10 calls for tail-call land at row 10.TC (impl) with this
ADR Accepted at row 10.D. The design follows
`phase10_design_plan_ja.md` §3.3 — industry references:

- **wasmtime** (`cranelift/codegen/src/isa/aarch64/lower.isle` +
  `inst/emit.rs`): tail-calls lower to a `Cret` (call-then-return)
  CLIF op; cross-module tail-calls share the unwind path with
  normal returns; no separate trampoline.
- **wasmer-singlepass** (`lib/compiler-singlepass/src/translator/code_translator.rs`):
  emits tail-call as `prologue restoration + branch` inline.
- **wasm3** (`source/m3_compile.c`): interpreter trampoline pattern
  with a `pc_continue` flag (the pattern this ADR re-derives in
  Zig v2 per `phase10_design_plan_ja.md` §3.3 step 6).
- **zwasm v1** (`vm.zig:838-889`): existing v1 trampoline shape;
  re-derived in v2 per the no-copy-from-v1 rule.

The challenge: tail-call MUST NOT create a new safepoint between the
caller's epilogue and the callee's entry. Allocator calls / host
checks / signal probes between caller-teardown and callee-jump would
violate the spec's "tail call consumes the caller frame" semantics
and break OCaml/Hoot's unbounded recursion guarantee.

## Decision

Land tail-call with the following design choices:

1. **ZIR pre-existing** — `src/instruction/wasm_3_0/return_call{,_indirect,_ref}.zig`
   are already placeholders (per ROADMAP §4 forward-decl). Phase 10
   fills them with `wasm_level: .v3_0` + handler implementations.

2. **`engine/codegen/<arch>/op_tail_call.zig` new file** — NOT an
   extension to `op_call.zig`. Per the single_slot_dual_meaning rule
   (§14 forbidden list), a tail-call's emit shape differs structurally
   from a regular call: the prologue restoration happens BEFORE the
   branch (vs after for regular `call`'s return). Keeping the two
   in one file would tempt sharing helpers across the boundary.

3. **`engine/codegen/shared/frame_teardown.zig` new helper** —
   centralised "SP restore + LDP X29,X30 + X19/X24-X28 restore" emit
   sequence. Inputs: `{ n_clobber_saved: u8, frame_bytes: u32,
   n_incoming: u8, n_outgoing: u8 }`. **The existing `prologue.zig`
   / `epilogue.zig` are NOT touched** — they remain the
   ABI-pinned shape that emit_test_*.zig byte-snapshots verify.
   frame_teardown is a new sibling helper specifically for the
   tail-call shape.

4. **Cross-module tail-call uses inline emit** —
   `engine/codegen/shared/cross_module_tail_call.zig` new file.
   The existing `cross_module/thunk.zig` (ADR-0066) is a
   call-and-return shape: it pushes a synthetic frame for the
   destination and returns to the caller. Tail-call needs the
   opposite — consume caller's frame, jump directly. Reusing the
   thunk would violate frame-consumption semantics. Emit sequence:

   ```
   (1) marshal args → X1..X7 / V0..V7  (BEFORE teardown; caller frame still live)
   (2) load callee_rt → X0          (from caller's literal pool)
   (3) load callee_entry → X16
   (4) frame_teardown.emit(…)       (caller's frame disappears here)
   (5) BR X16                       (no LR; callee returns to caller's caller)
   ```

   x86_64 mirror: marshal args via RDI/RSI/RDX/RCX/R8/R9 / XMM0-7,
   load callee_rt into RDI, callee_entry into R11, frame_teardown,
   `JMP R11`.

5. **regalloc terminator-class extension** —
   `engine/codegen/shared/regalloc.zig`'s op classification gains
   `is_terminator: bool`. Per-op files declare via
   `pub const is_terminator: bool = true;` for
   `return_call` / `return_call_indirect` / `return_call_ref`.
   Liveness analysis treats terminator ops as ending the current
   basic block (no fallthrough → no live-range across).

6. **Interpreter trampoline pattern** — `src/interp/` gets a
   trampoline outer loop with a `pc_continue` flag, re-derived
   from v1 `vm.zig:838-889` (READ, do not copy). Tail-call sets
   the flag + the next-callee identity; outer loop re-enters
   dispatch without growing the Zig native stack.
   `fixed-16 buffer` is dropped in favor of `[MAX_PARAMS]u64`
   stack scratch on the trampoline's frame.

7. **safepoint-free invariant (comptime-asserted)** — tail-call
   thunk + cross-module bridge have:
   - **Zero allocator calls** (no `alloc.create` / `dupe` / `realloc`
     between teardown and jump).
   - **Zero host call invocations** (no detour through
     `runtime.HostCall.fn_ptr`).
   - **Zero signal-check branches** (no `runtime.checkInterrupt` etc).
   Per-op file carries `pub const is_safepoint: bool = false;` —
   `comptime { std.debug.assert(!@import("op_tail_call.zig").is_safepoint); }`
   in `codegen/<arch>/emit.zig` enforces structurally.

## Amendment 2026-05-30 — cross-module path is call-and-return, not frame-consuming (D-206 step 2)

Decision §4's inline-BR sequence (load callee_rt → X0/RDI, frame_teardown,
`BR X16` / `JMP R11`) is **correct on x86_64 but corrupts the caller's
caller on arm64**. The asymmetry is rooted in the per-arch pinned-register
save discipline (ADR-0017 vs ADR-0026), surfaced by the first cross-module
`return_call` test (D-206 step 2):

- **x86_64**: the runtime-ptr register R15 is the *only* pinned reg, and
  every frame that uses it PUSH-saves it in its prologue and POP-restores
  it in its epilogue (`frame_teardown`'s `uses_runtime_ptr` path). A
  frame-consuming tail-jump therefore preserves a same-module grand-caller's
  R15 for free: `frame_teardown` restores it before the `JMP`, the callee
  re-saves-and-restores it, and the callee's `RET` lands in the grand-caller
  with R15 intact.
- **arm64**: the pinned cohort is X19 (runtime_ptr) + X24-X28
  (typeidx_base / table_size / funcptr_base / mem_limit / vm_base). The
  prologue **MOV-installs X19 from X0 and LOADs X24-X28 from the rt** — it
  does **not** stack-save them (ADR-0017 sub-2d-ii; confirmed by
  `arm64/frame_teardown.zig` Params `uses_runtime_ptr` being arm64-ignored).
  A frame-consuming tail-jump to a different-rt callee therefore leaves the
  callee's cohort (B's) in the registers when control returns to a
  same-module grand-caller that expects A's cohort → wrong memory base /
  table base on the grand-caller's next memory/table/call op. This is the
  D-142 corruption class, now in tail-call form.

**Refined decision**: cross-module `return_call{,_indirect,_ref}` lowers to
**call-and-return through the existing ADR-0066 bridge thunk** (which
already save/restores the full pinned cohort across the BLR/CALL) +
the normal `frame_teardown` + `RET`, i.e. the emit shape of
`call $import` immediately followed by the function epilogue. The result
register already holds the callee's result (validation requires the callee
result type == the current function result type for ≤ 2 results), so no
`captureCallResult` runs. This is cohort-correct on **both** arches.

Consequence — the cross-module path is **NOT frame-consuming**: A's frame
stays live across the BLR/CALL to the callee, so unbounded *cross-module*
mutual tail-recursion grows the native stack (eventually overflows) instead
of running in constant space. Same-module `return_call` (decisions §4
inline-BR / §4 emitDirectTailJump) remains proper-tail-call (frame
consumed). The proper-tail-call cross-module path is deferred to the
arm64-prologue-cohort-save work (**D-210**); when arm64 prologues stack-save
the cohort (Option B of `abi_callee_saved_pinning.md`), the frame-consuming
`BR X16` path becomes cohort-correct and both arches can adopt it. x86_64
could adopt the frame-consuming `JMP R11` path today, but both arches stay
on call-and-return for now so cross-module tail-recursion depth doesn't
diverge observably between hosts.

This refines decision §4 (it does NOT reuse the thunk as a tail-bridge —
the rejected Alternative A — but composes the thunk's *call* with the
function's *return*, which is a different construction). The new file
`cross_module_tail_call.zig` named in §4 is **not created**; the emit is a
~6-line `emitCrossModuleReturnCall` in each arch's `op_tail_call.zig`
delegating to a shared `op_call.emitImportDispatch` helper. `op_tail_call`'s
safepoint-free invariant (D7) is unaffected: the BLR-thunk path is the
existing ADR-0066 call shape, not a new safepoint.

Regression guard: `runner.zig` gains a top-level cross-module `return_call`
test (→ 42) and a **nested cohort-probe** test (a same-module `$mid` that
`return_call`s the import, a `test` that calls `$mid` then `i32.load`s its
own memory — passes only if the cross-module tail-call preserved A's
cohort; a naive BR-bridge regression traps on B's empty memory).

## Alternatives considered

- **A. Reuse `cross_module/thunk.zig` for tail-call cross-module**
  (avoid new file). Rejected: thunk's call-and-return shape pushes
  a synthetic frame; tail-call needs frame-consumption. Forcing the
  reuse means flagging "tail or normal" inside thunk body, which
  defeats the safepoint-free invariant (the flag-check IS a
  branch).

- **B. Extend `op_call.zig` instead of new `op_tail_call.zig`**.
  Rejected: per single_slot_dual_meaning, one file owning two
  emit shapes (call vs tail-call) accumulates implicit-coupling
  drift over Phase 11+. The 1-file split cost is bounded; the
  drift cost is unbounded.

- **C. Per-arch `frame_teardown_<arch>.zig` instead of shared**.
  Rejected: the teardown sequence is the same logical operation
  (SP restore + LDP/POP callee-saved + LDP X29,X30 / POP RBP) on
  both arm64 and x86_64; the actual emit calls differ but the
  invariant order is identical. Sharing the helper at Zone 2 keeps
  the safepoint-free invariant audit single-pass.

- **D. Use Cranelift's tail-call ABI** (special calling convention
  with `tail` LLVM ABI). Rejected: Zwasm v2 uses standard Wasm
  calling convention (no special tail-cc); the prologue
  restoration sequence IS the tail-call shape. The Cranelift
  approach trades safepoint correctness for ABI complexity; Zwasm
  follows wasm3 / wasmer-singlepass pattern instead.

## Consequences

**Positive**:

- Unbounded mutual recursion supported per spec § 7.1.13 (proper
  tail call); OCaml / Hoot / Dart realworld fixtures can use
  recursion at scale without stack overflow.
- `clang __attribute__((musttail))` lowering supported directly;
  C source can guarantee tail-call disposition.
- safepoint-free invariant is structurally enforceable
  (comptime-asserted per-op-file constant).
- Cross-module tail-call works without thunk-shape reuse —
  cleaner separation per the no-shared-shape rule.

**Negative**:

- New file count: `op_tail_call.zig` (per-arch, ×2),
  `frame_teardown.zig` (shared), `cross_module_tail_call.zig`
  (shared). ~4 new files, ~600 LOC total estimate.
- `regalloc.zig` op-classification table gains `is_terminator`
  axis — small refactor (mechanical: add field + populate from
  per-op files).
- Interpreter trampoline pattern reshapes the dispatch loop —
  not a behavior change for non-tail-call ops, but the loop
  control flow has to handle the `pc_continue` flag-set on every
  iteration. Cost: one branch per dispatch step (modern
  branch-predictor should mask this).

## Removal condition

This ADR retires when tail-call ships at ROADMAP §10 / 10.TC `[x]`,
with all seven decisions above implemented, the
`tail-call/test/core/*.wast` (95 files) spec corpus green at
3-host gate, the realworld/p10/clang_musttail and
realworld/p10/wasm_of_ocaml fixtures green, and the safepoint-free
invariant assert holds at compile time. At that point status
transitions to `Closed (Implemented)` with the impl SHA range cited.

## References

- `phase10_design_plan_ja.md` §3.3 — full design spec (source of
  truth; this ADR codifies the decisions).
- WebAssembly tail-call proposal:
  https://github.com/WebAssembly/tail-call
- `~/Documents/OSS/wasmtime/cranelift/codegen/src/isa/aarch64/lower.isle`
  — wasmtime tail-call lowering (precedent).
- `~/Documents/OSS/wasmer/lib/compiler-singlepass/src/translator/code_translator.rs`
  — singlepass inline emit pattern (closest to this ADR).
- `~/Documents/OSS/wasm3/source/m3_compile.c` — interpreter
  trampoline + flag pattern (re-derived in v2 step 6).
- `~/Documents/MyProducts/zwasm/src/interp/vm.zig:838-889` —
  v1 trampoline shape (READ; not copied — per no_copy_from_v1).
  **Note (2026-05-26 verification)**: v1 has NO JIT codegen for
  tail-call ops — `~/Documents/MyProducts/zwasm/src/jit*` does
  not exist and `grep return_call` across v1 src/ matches only
  the interp / opcode-enum / validator paths. The JIT-side
  codegen for `return_call` / `return_call_indirect` /
  `return_call_ref` is **green-field in zwasm v2**; there is no
  v1 precedent to follow or reject. The primary codegen
  references remain wasmtime/cranelift + wasmer/singlepass
  (cited above).
- ADR-0017 — JIT register inventory (X16 / X17 / R11 scratch
  for callee_entry; no reservation change).
- ADR-0018 — regalloc reserved set (terminator axis is
  additive; reserved set unchanged).
- ADR-0066 — cross-module thunk shape (call-and-return;
  intentionally NOT reused for tail-call per decision §4).
- ADR-0113 — callsite_metadata (orthogonal; tail-call doesn't
  carry post-call bounds_fixups since it doesn't return).
- 10.Z commit `7fb6593d` — ZirInstr.payload u64 widen
  (memory64-driven; tail-call doesn't consume this widening
  but inherits the shape).

## Revision history

- 2026-05-25 — Initial draft via /continue autonomous prep path
  (per `.claude/skills/continue/SKILL.md` §"Autonomous prep
  paths for user-gated ADRs"). Status: Proposed pending user
  collab review at 10.D. Co-drafted in the 10.D ADR round
  alongside ADR-0111 + ADR-0113..0117 (across multiple
  /continue cycles per the 7-ADR scope).
- 2026-05-25 — Status: Proposed → **Accepted** (user collab 3/7).
  All 7 decisions accepted as drafted (inline emit + frame_teardown
  shared helper; interpreter trampoline + pc_continue; safepoint-free
  comptime invariant; op_tail_call.zig as separate file).
- 2026-05-26 — References §: clarified that v1 has NO JIT codegen
  for tail-call ops (interp-only); the JIT-side codegen for
  `return_call` / `return_call_indirect` / `return_call_ref` in
  zwasm v2 is green-field. Primary precedents remain
  wasmtime/cranelift + wasmer/singlepass. Verification grep
  done at this commit; recorded so future cycles don't re-walk
  the v1-precedent question.
- 2026-05-30 — **Amendment** (D-206 step 2): cross-module
  `return_call` lowers to call-and-return through the ADR-0066
  bridge thunk + normal epilogue, NOT the inline frame-consuming
  BR/JMP of decision §4. Rationale: arm64 MOV-installs the pinned
  cohort (X19/X24-X28) rather than stack-saving it, so a
  frame-consuming cross-module tail-jump corrupts a same-module
  grand-caller's cohort (x86_64's per-frame R15 save makes it safe
  there). Frame-consuming cross-module tail-call deferred to the
  arm64-prologue-cohort-save work (D-210). See the "Amendment
  2026-05-30" section above. Cohort-asymmetry observation recorded
  as lesson `2026-05-30-cross-module-tail-call-cohort-asymmetry.md`.
