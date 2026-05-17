# 0066 — Per-import bridge thunks for cross-module function-import dispatch

- **Status**: Accepted
- **Date**: 2026-05-17
- **Author**: zwasm v2 maintainer (Phase 9 §9.9-III Cat III work)
- **Tags**: phase-9, cat-iii, cross-module, host-imports, jit, abi, instance, store, dispatch, thunks

## Context

ADR-0065 absorbed Wasm 1.0 cross-module / instance / linker work
into Phase 9 (§9.9-III). Sub-chunks (c)-1a / (c)-1b / (c)-1c
landed the foundation: `Store.register` (name → `*Instance`
opaque), `hostImportTrapStub` spectest no-op (binary-no-op
return), and runner `(register "M" $inst)` directive parsing.

The cross-module **call dispatch** (sub-chunk (c)-2) is the next
piece. Today's emit path (chunk 7.9-d, `op_call.zig:emitCall`)
routes every `call N` with `N < num_imports` through the
shared `host_dispatch_base` table:

```text
ARM64:
  LDR  X16, [X19, #host_dispatch_base_off]   ; ptr-of-ptrs
  LDR  X16, [X16, #(idx*8)]                  ; fn ptr at slot
  ORR  X0,  XZR, X19                         ; X0 = caller's JitRuntime
  BLR  X16                                    ; indirect call

x86_64:
  MOV  RAX, [R15 + host_dispatch_base_off]
  MOV  RAX, [RAX + idx*8]
  MOV  RDI, R15                              ; RDI = caller's JitRuntime
  CALL RAX
```

Each instance's `JitRuntime.host_dispatch_base` is a `[*]const
usize` indexed by import-function-idx. Today every slot points
at `hostDispatchTrap` (sets `trap_flag = 1`, returns 0) or, for
modules sharing the (c)-1b spectest stub, `hostImportTrapStub`
(returns 0 unconditionally).

**Critical observation**: the call site loads the *caller's*
`JitRuntime` pointer (X19 / R15) into the host stub's arg 0.
For a true host C function this is correct — the host stub
reads `*JitRuntime` to twiddle `trap_flag` / memory base / etc.
For a cross-module **Wasm** callee, this is wrong: the callee's
JIT body needs its own instance's memory / globals / table /
host_dispatch_base, all of which are reached through *its*
`JitRuntime`.

D-138 (filed 2026-05-17, lesson
[`cross-module-noop-stub-controlflow-hang`](../lessons/2026-05-17-cross-module-noop-stub-controlflow-hang.md))
documents the proof: a naive sub-chunk (c)-2 attempt routed
registered-alias function imports through the shared
`hostImportTrapStub` no-op (mirroring (c)-1b's spectest path).
The spec_assert runner hung past 180 s on
`zwasm-spec-wasm-2-0-assert` because cross-module callees are
arbitrary user code — they expect to mutate counter globals,
return non-zero control-flow signals, etc. — and a no-op stub
that returns 0 forever breaks the importer's loop-termination
contract. The fix needs **a per-import dispatch path that
actually executes the callee's JIT body in the callee's
instance context**.

A textbook survey of v1, wasmtime, zware, and wasm3 (see
2026-05-17 Step 0 survey) shows three viable approaches:

1. **Per-import lazy-compiled bridge thunk** (this ADR): each
   `host_dispatch_base[i]` slot points at a tiny native-code
   thunk that swaps the JitRuntime pointer (X0 / RDI) from
   caller's to callee's and tail-jumps to the callee's JIT
   entry. Caller-side emit is unchanged.
2. **No-thunk uniform convention**: caller pre-loads the
   callee's JitRuntime into X0/RDI from a parallel resolver
   table indexed by import_idx, then dispatches. Requires a
   second per-instance `[*]const *JitRuntime` array alongside
   `host_dispatch_base`, plus caller-side emit changes.
3. **Per-instance pre-compiled thunk module**: at instantiate
   time compile a complete "thunk module" with one bridge per
   import; same cost as #1 but eagerly compiled.

## Decision

Adopt **Alternative 1 — per-import lazy-compiled bridge thunks +
unchanged `host_dispatch_base` array slot**.

Concretely:

- **Slot layout**: `JitRuntime.host_dispatch_base[i]` stays a
  single `usize` per import-function. No new parallel arrays;
  no new caller-side metadata loads.
- **Slot contents**:
  - For a func import resolved against a registered exporter
    (`Store.lookup(import.module) != null`) and where the named
    export is a Wasm function: a pointer to a **bridge thunk**
    compiled into the importer instance's thunk arena.
  - For a func import resolved against a registered exporter
    whose named export is a **host C function** (future
    `wasm_func_new_with_env` integration): a direct pointer to
    that C function (no thunk; the host already speaks the
    `fn(rt: *JitRuntime, ...args) callconv(.c)` shape).
  - For a func import without a registered exporter (e.g.
    `(import "spectest" "print_i32" ...)` when no spectest
    bridge is installed): the existing `hostImportTrapStub` /
    `hostDispatchTrap` pointer.
- **Bridge thunk shape** (ARM64, ~32 bytes):

  ```text
  ; entry: X0 = caller's JitRuntime, X1..X7 = wasm args
    ADR  X16, .literals
    LDR  X0,  [X16]            ; X0 ← callee's JitRuntime
    LDR  X16, [X16, #8]        ; X16 ← callee's JIT entry
    BR   X16                    ; tail-call (callee's RET → caller)
  .literals:
    .quad <callee_rt_ptr>
    .quad <callee_entry_ptr>
  ```

  On x86_64 (~22 bytes):

  ```text
    MOV  RDI, <callee_rt imm64>
    MOV  RAX, <callee_entry imm64>
    JMP  RAX
  ```

  Tail-call semantics matter: the callee's `RET` returns
  directly to the importer's call site, so its return value
  sits in the callee's-ABI return register (X0/V0 on ARM64,
  RAX/XMM0 on x86_64). The caller's existing
  `captureCallResult` already reads that register per the
  callee's signature (known from `ctx.func_sigs[ins.payload]`).
- **Thunk arena**: per-instance JIT-allocated, mmap-ed RX,
  parallel to the function-body block. Sized at instantiate
  time to `num_func_imports * thunk_size`. Lives until the
  importer instance is destroyed (matching the
  `host_dispatch_base` lifetime).
- **Resolver wire-up** (the new code path):
  1. At `instantiateRuntime`, after parsing the import section
     and validating type compatibility against
     `Store.lookup(import.module).exports[import.name]`, walk
     each function import.
  2. If the exporter is a registered Wasm instance: emit a
     bridge thunk (ARM64 / x86_64 emitter shared via
     `engine/codegen/shared/thunk.zig`) into the thunk arena,
     planting (callee_rt, callee_entry) constants.
  3. Store `@intFromPtr(&thunk)` into
     `host_dispatch_base[import_idx]`.
  4. If the exporter is missing or the named export is missing:
     keep the existing default trap stub.
- **Linker `IMPORT_SENTINEL_OFFSET`**: unchanged. The sentinel
  still marks "function-table entries that name imports must
  not be reached via body-relative BL"; the thunk path is
  reached only via the `host_dispatch_base` indirect call,
  which the linker already handles.

## Alternatives considered

### Alternative 2 — No-thunk uniform convention with parallel resolver table

- **Sketch**: Add `JitRuntime.host_dispatch_rtptrs: [*]const
  *JitRuntime` parallel to `host_dispatch_base`. Per-import
  resolution writes `(callee_entry, callee_rt)` into the two
  arrays. ARM64 emit changes to:

  ```text
    LDR  X16, [X19, #host_dispatch_base_off]
    LDR  X16, [X16, #(idx*8)]      ; fn ptr
    LDR  X0,  [X19, #host_dispatch_rtptrs_off]
    LDR  X0,  [X0,  #(idx*8)]      ; callee's rt ptr
    BLR  X16
  ```

  No per-thunk native code; resolver table is plain data.

- **Why rejected**:
  - Adds two extra load instructions on the *call hot path*
    for every imported call. The bridge-thunk design keeps the
    call site at four instructions (LDR / LDR / ORR / BLR),
    paying the swap cost only when the call actually fires.
  - Adds a parallel data array to every `JitRuntime` shape,
    bloating the JitRuntime struct + `instantiateRuntime`
    bookkeeping. Bridge thunks live in a separate arena that's
    only allocated when ≥ 1 import resolves cross-module.
  - Loses the call-site uniformity for "host C fn vs Wasm
    cross-module fn" — host C fns don't need an
    rtptrs-array entry, so the resolver becomes "is this slot
    a C fn (skip rtptrs) or a Wasm fn (consume rtptrs)?"
    branching at instantiate time. Thunks make the call site
    uniform: every slot is just "indirect-call this address".
  - Caller-side emit needs to learn two new instructions and
    a new struct offset. Thunks change zero caller-side code.

### Alternative 3 — Per-instance pre-compiled thunk module (eager)

- **Sketch**: Same thunk shape as Alternative 1, but compile
  *every* possible thunk variant at instantiate time (one per
  import slot, regardless of whether the exporter has been
  registered yet). When `Store.register` runs later, patch the
  thunk's literals in-place.

- **Why rejected**:
  - Wasm 1.0 spec requires the importer's `(register ...)`
    targets to be registered **before** the importer is
    instantiated (the spec runner enforces this via wast
    directive order). So lazy compilation at instantiate time
    can always inspect the resolved exporter; no eagerness
    needed.
  - Eager compilation wastes thunk-arena space for imports
    that bind to host C fns (where no thunk is needed).
  - Patching mmap-ed RX memory in-place requires either an
    extra W writable mapping (double-map) or a `mprotect(...,
    PROT_READ | PROT_WRITE)` round-trip per `register` call.
    Lazy-compile-at-instantiate avoids the
    write-after-mmap-RX hazard entirely.

### Alternative 4 — Late-bind at call site (Wasmtime-style VMContext offsets)

- **Sketch**: Compile out per-import dispatch indirection
  entirely: at `instantiateRuntime` time compute the
  caller-import-idx → callee-instance-VMContext-offset mapping
  AOT and embed the resolved (rt, entry) constants directly
  into the importer's JIT body. Caller's `call N` for `N <
  num_imports` becomes a direct BL/CALL to the callee's entry.

- **Why rejected**:
  - Requires recompiling the importer's JIT body after the
    exporter is registered. Today's `instantiateRuntime` runs
    AFTER `compileWasm`, and the imports are already part of
    the produced byte stream (with `IMPORT_SENTINEL_OFFSET`
    sentinels). Re-emitting the import call site would mean
    keeping the JIT-emit pipeline addressable post-link, which
    is a much larger architectural change than this ADR.
  - Loses Wasm 1.0 spec idiom of late-binding: `(register
    "M" $inst)` after the importer is instantiated must still
    work (the spec testsuite uses this order in several
    fixtures). Wasmtime-style AOT-bake requires register
    before instantiate, which doesn't match the spec.
  - Wasmtime tolerates the AOT-bake because its module
    compilation phase is separate from instantiation. v2's
    JIT-first pipeline collapses both into `instantiateRuntime`,
    so AOT-bake would re-introduce a second compile phase.

## Consequences

- **Positive**:
  - Call-site emit (`op_call.zig`) is **unchanged**. Every
    chunk that previously consumed the `host_dispatch_base`
    indirect-call shape continues to work.
  - Per-call cost is the same as the existing host-import call
    (one indirect call + 3 register moves). The thunk adds a
    second indirect jump (BR/JMP) but no extra loads on the
    importer-side emit.
  - Thunk shape is **opcode-pinned** (4 ARM64 instructions / 3
    x86_64 instructions) — exactly the shape that the
    `audit_scaffolding §G.4` invariant-comment lint can sanity
    check without per-instance variation.
  - Bridge thunk arena is **per-instance**, so destroying the
    importer destroys its thunks cleanly. No global thunk
    registry; no GC needed.
  - Compatible with C-ABI host imports (slot points directly
    at the C fn) and Wasm-cross-module imports (slot points at
    a thunk) without a slot-side discriminator. The slot type
    stays `usize`.
- **Negative**:
  - New shared module `src/engine/codegen/shared/thunk.zig`
    (under [`shared/`](../../src/engine/codegen/shared/)) +
    per-arch sub-modules `arm64/thunk.zig` / `x86_64/thunk.zig`
    holding the encoder. Adds ~150 LOC per arch + ~100 LOC
    shared. Within the §A2 1000-LOC soft cap and well under
    the §14 hard cap.
  - Thunk arena allocation adds a per-`instantiateRuntime`
    `mmap(..., PROT_READ | PROT_EXEC, ...)` (or a sub-arena
    within the existing `JitModule.block`). Lifetime tied to
    instance lifetime; freed at instance destroy.
  - Per-thunk literal patching requires either:
    - A two-pass scheme (allocate thunk slot, then resolve +
      patch + mprotect-RX), or
    - A separate writable scratch arena that's `mremap`-ed RX
      after all thunks are emitted (one syscall, not per-
      import).
    The implementation chunks below pick the second.
  - Cross-arch thunk emitters must stay in step (W54 class).
    `audit_scaffolding §G.3` "Mac vs OrbStack thunk byte-shape
    parity" check goes on the post-implementation watchlist.
- **Neutral / follow-ups**:
  - **Implementation chunk plan** (each chunk is one commit;
    sequence per close-plan §6 step (c)-2):
    1. **(c)-2.1** — `shared/thunk.zig` skeleton + per-arch
       encoder unit tests. Lands the byte layout + the
       constant-poke API; no resolver wiring yet.
    2. **(c)-2.2** — `Instance`-level thunk arena allocation +
       `mmap` lifecycle. Plumbs the arena ptr into the
       `JitRuntime` shape (or a new sibling field, TBD by the
       implementer based on alignment constraints).
    3. **(c)-2.3** — Resolver wire-up in
       `instantiateRuntime`: walk imports, look up exporters
       in `Store.instances`, emit thunk per func import.
    4. **(c)-2.4** — spec_assert runner integration test: the
       smallest `(register ...)` + cross-module call fixture
       that exercises non-trivial callee behaviour (counter
       mutation / non-zero return). Expected: bit-identical
       Mac+OrbStack, +N PASS delta where N = number of
       previously-skipped `linking-Mf-call`-class assertions.
  - Host C function binding (`wasm_func_new_with_env` from
    wasm-c-api) reuses the same slot mechanism: slot points
    directly at the host fn pointer; the host fn already
    speaks the `fn(rt: *JitRuntime, ...) callconv(.c)` shape.
    No thunk allocation for that path. Wire-up is a separate
    sub-chunk under (c)-3 / (c)-4 (spectest host imports +
    other host bindings).
  - **D-079** (v128 cross-module imports, status `now` per
    ADR-0065 §9.9-III): the v128 result-class marshalling
    already works for cross-module-bound calls because the
    callee's RET goes straight to the importer's call site —
    the caller's `captureCallResult` reads V0 (ARM64) or
    XMM0 (x86_64) per the callee's signature, identical to
    a same-module call. (c)-2.4 includes one v128 fixture to
    verify.
  - **D-126** (`bulk.wast` call_indirect post-`table.copy` /
    `table.init` returns stale entries): orthogonal — the
    table-mutation path goes through `tables_jit_ci_ptr`, not
    through `host_dispatch_base`. ADR-0066 does not discharge
    D-126.
  - **D-138** (this ADR's seed): discharged when (c)-2.4
    lands and the prior naive-relaxation hang is replaced
    by working dispatch. Delete D-138 in the (c)-2.4 commit.

## References

- ROADMAP §9.9-III (Cat III absorption per ADR-0065)
- Related ADRs:
  - [`0017_jit_function_call_marshalling.md`](0017_jit_function_call_marshalling.md)
    — original ABI for in-module calls; this ADR extends the
    cross-module path without changing the in-module path.
  - [`0023_zone_split_post_phase_6.md`](0023_zone_split_post_phase_6.md)
    — Zone layering; `engine/codegen/shared/thunk.zig` lives
    in Zone 2 (`engine/`).
  - [`0027_globals_runtime_pointer_strategy.md`](0027_globals_runtime_pointer_strategy.md)
    — runtime-ptr reservation strategy that the thunk's X0
    swap relies on.
  - [`0049_per_chunk_gate_host_subset.md`](0049_per_chunk_gate_host_subset.md)
    — 2-host (Mac + OrbStack) gate discipline; (c)-2 chunks
    follow it.
  - [`0056_phase9_scope_extension_to_wasm2_full.md`](0056_phase9_scope_extension_to_wasm2_full.md)
    — 4-category exit predicate.
  - [`0065_wasm_1_0_instance_work_phase9_rescope.md`](0065_wasm_1_0_instance_work_phase9_rescope.md)
    — Cat III absorption.
- External:
  - Wasm 1.0 core spec §4.5 (Instances, Stores, Imports,
    Linking).
  - AAPCS64 (Arm IHI 0055) §6.4 call sequence; tail-call via
    `BR` preserves the link register from the caller's BL.
  - System V AMD64 ABI §3.2.3 calling convention; tail-call
    via `JMP` preserves RIP from the caller's CALL.
- Lessons:
  - [`2026-05-17-cross-module-noop-stub-controlflow-hang.md`](../lessons/2026-05-17-cross-module-noop-stub-controlflow-hang.md)
    (D-138 case study; the failure mode this ADR addresses).
- Debt:
  - D-138 (filed 2026-05-17, discharged at (c)-2.4 landing).
  - D-079 (v128 cross-module imports, sub-gap ii) —
    incidentally covered by (c)-2.4's v128 fixture.
- Phase-9 close plan: [`../phase9_close_plan.md`](../phase9_close_plan.md)
  §6 step (c) — the umbrella for this ADR's implementation.

<!--
## Revision history

| Date       | SHA          | Note                                    |
|------------|--------------|-----------------------------------------|
| 2026-05-17 | `<backfill>` | Initial accepted version (Phase 9 §9.9-III (c)-2 design). |
-->
