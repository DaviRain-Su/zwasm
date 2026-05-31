# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD**: 10.G **A-10b `array.new_elem`** emit both arches (`bcec8199`) — completes
  the **array.\* JIT-emit sub-bundle**. NEW `jitGcArrayNewElem(rt, typeidx, segidx, offset,
  size) → u32` (ref/0=trap): trivial variant of A-10a — allocs a `size`-elem array + copies
  `size` u64 ref Values DIRECT (no LE-unpack, esz=8) from element segment `segidx` at `offset`
  (mirror interp arrayNewElem). **REUSES** `JitRuntime.elem_segments_ptr` (ElemSlice) +
  `elem_dropped_ptr` (table.init's plumbing, ADR-0058 m-2c-init) — NO new JitRuntime field.
  Emit = byte-for-byte array.new_data shape (5-arg marshal → CALL → CMP/TEST 0; B.EQ/JE →
  bounds_fixups → capture W0/EAX). 2→1; strict force-spill; usesRuntimePtr. e2e: array of
  `(ref null $sig)` + passive elem seg `[ref.func $worker]`; `array.new_elem 1 0` → array;
  `array.get 1` → funcref; `call_ref $sig` → 42 (proves the EXACT ref was copied). Verified:
  arm64 `zig build test` EXIT=0 + lint 0 + x86_64 cross EXIT=0.
- **Two execution paths (CODE-verified)**: spec corpus runs **interp-only**
  (`instance.invoke`→`_dispatch.run`, `instance.zig:169`); JIT corpus run = §1. JIT emits
  1.0/2.0 + TC + func-refs + EH + i31 + full struct family + **full array family**
  (new_default,len,get,set,new,new_fixed,get_s,get_u,fill,copy,new_data,new_elem) + ref.eq
  (both arches); remaining GC = ref.cast/test only (D-211). Green gc/EH corpus = INTERP.
- **ADR-0128 + ADR-0127 both Accepted** — no remaining user gate; loop runs autonomously.

## Active task — Phase 10 → 100% (ADR-0128)  **NEXT**

Six workstreams (ADR-0128), value-prioritized (NOT §10 table-first):

1. **Spec-corpus JIT execution mode** (§1) — verification backbone: run the official
   testsuite through the JIT (compile-every-fn → JIT-entry invoke → compare; wasmtime
   `tests/wast.rs` pattern) so every JIT gap shows up RED.
2. **GC-on-JIT op emit** (D-211 bundle; §2) — see Active bundle below.
3. **ADR-0127 PHASE C** — cross-`Types` `canonicalEqual`; `gc/type-subtyping` 5→0.
4. Quick wins: **D-209** (lift leftover `>u32` offset check; payload already u64), **D-198**
   (rec-group subtype), **D-210** (cross-module proper-tail-call — arm64 prologue cohort-save).
5. **Realworld GC/EH/TC producers** (§5; flake.nix `#gen`): `wasm_of_ocaml` / `emcc
   -fwasm-exceptions` / `guile-hoot`.

## Active bundle

- **Bundle-ID**: `10.G-gc-on-jit-IT-1..N`
- **Cycles-remaining**: ~2-3
- **Continuity-memo**: PROVEN per-GC-op recipe + full struct/array design in
  **`.dev/phase10_g_op_bundle_plan.md`** §"GC-on-JIT emit design" + §"array.* sub-bundle"
  (single source — do NOT re-derive). Verified x86_64 facts: pinned rt = R15; SysV args
  RDI/RSI/RDX(/RCX/R8), ret EAX; emit scratch = R10 (CALL target) — NOT in regalloc pool
  ({RBX,R12,R13,R14}); result via gprDefSpilled/gprStoreSpilled. dispatch_collector.zig
  count tests are LITERALS — bump per added op (now arm64=372 / x86_64_ctx=421). struct
  offsets UNIFORM `8+idx*8` (ADR-0116 §3a); array offsets `12+i*8`; rooting DEFERRED.
- **DONE both arches**: i31 + struct.{new_default,get,new,set} + **array.\* COMPLETE**
  (new_default,len,get,set,new,new_fixed,get_s,get_u,fill,copy,new_data,new_elem) + ref.eq.
  Per-op SHAs in `git log` + bundle plan §"array.* sub-bundle". Per-GC-op touch-points
  (REUSE): op-file (arm64+x86_64) + register in `collected_{arm64_ops,x86_64_ctx_ops}` +
  bump dispatch_collector.zig count LITERALS + `stackEffect` + x86_64 `usesRuntimePtr` (R15
  ops) + regalloc_compute force-spill (alloc/CALL ops) + ungated `runI32Export` e2e
  (**hand-encode: wat2wasm 1.0.40 can't parse GC array text; i32.const ≥ 64 needs multi-byte
  signed LEB128** — keep test values < 64).
- **NEXT = ref.test / ref.cast emit, both arches** — ARCHITECTURAL sub-bundle (NOT a trivial
  emit variant): RTT 8-deep Cohen display per ADR-0116. Needs Step 0 survey + design first
  (display-walk shape, where the RTT lives in the GcTypeInfo, trampoline vs inline compare).
  This is a fresh-turn architectural chunk — do NOT chain onto an emit turn.
- **Exit-condition**: all GC ops emit on both arches + spec corpus green via JIT mode (§1).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 STALE (payload u64; lift leftover u32 check).
- **10.R** function-references — JIT emit present, corpus green; residual = D-198.
- **10.TC** tail-call — JIT matrix complete; residuals = D-210 + `wasm_of_ocaml`.
- **10.E** EH — JIT emit present; residuals = eh_frequency runner (I20), c_api tag
  accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit PARTIAL (D-211): i31 + **full struct family** + **full array family**
  + **ref.eq** DONE both arches; remaining = ref.cast/test (RTT, architectural) + ADR-0127
  PHASE C + D-198 + gc_stress (I19) + dart/hoot (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

**A-10b `array.new_elem` kicked to ubuntu THIS turn** (background, scope-matched to A-10b's
runI32Export e2e). Next `/continue`: `tail -3 /tmp/ubuntu.log` — expect `[run_remote_ubuntu]
OK (HEAD=<A-10b sha>)`. On FAIL: revert the A-10b commit pair to the last ubuntu-verified HEAD
(`8eab8e09` = A-10a). On GREEN: proceed to NEXT (ref.cast/test architectural — Step 0 survey).

**Lesson (still live)**: `gate_commit.sh --fast` DEFERS `zig build test`/`lint` (Step 4/5 own
them) — parent's full `zig build test` before push is the real gate.

## Key refs

- **ADR-0128** (Phase 10 100% master plan); ADR-0127 (cross-module func type-identity);
  ADR-0116 (RTT 8-deep Cohen display — ref.cast/test design); ADR-0115 §10 (non-moving β
  collector); ADR-0058 (elem/data segment JIT plumbing); ADR-0060 (force-spill). ROADMAP §10.
- Debt: **D-211** (GC-on-JIT), D-209 (stale), D-202 / D-198 / D-210. Lessons
  `2026-05-31-wasmgc-jit-non-moving-deferred-rooting` + `...-partial-spec-corpus-interp`.
