# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD**: 10.G **A-10a `array.new_data`** emit both arches. Alloc-from-segment trampoline (mirror
  array.fill 5-arg): NEW `jitGcArrayNewData(rt, typeidx, segidx, offset, size) → u32` (ref/0=trap)
  allocs a `size`-elem array + copies payload from data segment `segidx` at byte `offset`, reading
  the element NATURAL size (i8=1/i16=2/i32,f32=4/i64,f64=8) LE-zero-extended into each 8-byte slot
  (mirror interp arrayNewData). **REUSES** `JitRuntime.data_segments_ptr`/`data_dropped_ptr` (the
  same descriptors `memory.init` uses, ADR-0056 m-3b) — NO new JitRuntime field. Emit marshals 5
  args (rt + typeidx/segidx imms + offset/size operands) → CALL → `CMP/TEST 0; B.EQ/JE →
  bounds_fixups` → capture W0/EAX ref. 2→1; strict force-spill; usesRuntimePtr. e2e: passive data
  seg i32 [10,20,30]; `array.new_data 0 0` → array; `array.get 1` → 20. (A-1..A-9 DONE; A-9
  `array.copy` ubuntu GREEN `93925bb6`.) A-10a THIS turn. Verified: arm64 `test-all` EXIT=0 + lint
  0 + x86_64 cross EXIT=0.
- **Two execution paths (CODE-verified)**: spec corpus runs **interp-only**
  (`instance.invoke`→`_dispatch.run`, `instance.zig:169`); JIT corpus run = §1. JIT emits
  1.0/2.0 + TC + func-refs + EH + i31 + full struct family + array.{new_default,len,get,set,
  new,new_fixed,get_s,get_u,fill,copy,new_data} + ref.eq (both arches); remaining GC (array
  new_elem + ref.cast/test) interp-only (D-211). Green gc/EH corpus = INTERP.
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
- **Cycles-remaining**: ~4-5
- **Continuity-memo**: PROVEN per-GC-op recipe + full struct design in
  **`.dev/phase10_g_op_bundle_plan.md`** §"GC-on-JIT emit design" (single source — do NOT
  re-derive) + §"array.* sub-bundle". Verified x86_64 facts: pinned rt = R15; SysV args
  RDI/RSI(/EDX), ret EAX; emit scratch = `spill_stage_gprs` {R10=stage0, R11=stage1} — NOT in
  regalloc pool (`allocatable_gprs` {RBX,R12,R13,R14}; don't use R13/R14 ad-hoc); result via
  gprDefSpilled/gprStoreSpilled (encoders: read existing x86_64 struct files). x86_64 ctx-op
  count test in dispatch_collector.zig is a LITERAL — bump per added op. struct offsets UNIFORM
  `8+idx*8` (ADR-0116 §3a); array offsets `12+i*8` (4-mod-8, register-offset); rooting DEFERRED.
- **First-op order**: i31 + **struct.{new_default,get,new,set}** all DONE both arches. Per-GC-op
  touch-points (REUSE for array; full list in bundle plan §"array.* sub-bundle"): op-file +
  register in `collected_{arm64_ops,x86_64_ctx_ops}` + bump dispatch_collector.zig count LITERALS
  + `stackEffect` (or liveness special-case if variadic) + x86_64 `usesRuntimePtr` (R15 ops) +
  ungated `runI32Export` e2e (**hand-encode: i32.const ≥ 64 needs multi-byte signed LEB128** —
  bit 6 sign-extends; keep test values < 64) + ADR-0060 force-spill for alloc ops (is_call).
  array A-1 (trampoline) `06ebc165` + A-2 (new_default + len) `d6dea34d` + A-3 (get + set,
  register-offset + bounds-check) `dc5869ca` + A-4 (array.new via `jitGcAllocArrayFill`
  trampoline-fill) `690bcf0d` + A-5 (`array.new_fixed`, variadic, `jitGcAllocArray(rt,typeidx,N)`
  + inline reverse-pop stores, inclusive force-spill) `d4f2a141` + A-6a (`array.get_s` = A-3 load
  + SXTB/SXTH; element valtype threaded via `array_elem_valtypes`→`extra`) `25218e9f` + A-6b
  (`array.get_u` = same + UXTB/UXTH / MOVZX) `62de416c` + A-7 (`array.fill` = `jitGcArrayFill`
  trampoline, 6-arg marshal + post-CALL trap) `17088594` + A-8 (`ref.eq` = CMP+CSET/SETE, no
  trampoline) `a0eae42a` + A-9 (`array.copy` = `jitGcArrayCopy`, typeidx dropped/esz=8) `aa1178a0`
  + A-10a (`array.new_data` = `jitGcArrayNewData`, LE-unpack from data segment, reuse
  data_segments_ptr) THIS turn DONE both arches.
  **NEXT = A-10b = `array.new_elem` emit, both arches** — trivial variant of A-10a: NEW
  `jitGcArrayNewElem(rt, typeidx, segidx, offset, size) → u32` mirrors jitGcArrayNewData but
  reads `rt.elem_segments_ptr[segidx]` (`ElemSlice{refs:[*]u64, len:u32}`, reuse table.init's
  plumbing) + `elem_dropped_ptr`, and copies `size` u64 ref Values DIRECT (no LE-unpack, esz=8).
  Emit = copy array_new_data.zig verbatim with `jitGcArrayNewElem` + op_tag (lower sub-op 10).
  recipe in bundle plan §"array.* sub-bundle". Then ref.test/ref.cast (RTT 8-deep Cohen display
  per ADR-0116; architectural sub-bundle).
- **Exit-condition**: all GC ops emit on both arches + spec corpus green via JIT mode (§1).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 STALE (payload u64; lift leftover u32 check).
- **10.R** function-references — JIT emit present, corpus green; residual = D-198.
- **10.TC** tail-call — JIT matrix complete; residuals = D-210 + `wasm_of_ocaml`.
- **10.E** EH — JIT emit present; residuals = eh_frequency runner (I20), c_api tag
  accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit PARTIAL (D-211): i31 + **full struct family** + **array.{new_default,
  len,get,set,new,new_fixed,get_s,get_u,fill,copy,new_data}** + **ref.eq** DONE both arches;
  remaining = array new_elem (A-10b) + ref.cast/test (RTT) + ADR-0127 PHASE C + D-198 + gc_stress
  (I19) + dart/hoot (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

This turn landed A-10a code (`array.new_data`) + this handover chore; prior cycle's survey
(`a0d997ca`) was docs-only on top of A-9's ubuntu-verified `93925bb6`. ubuntu **test-all** kicked
in background against this turn's pushed HEAD (`/tmp/ubuntu.log`). Step 0.7 next `/continue`:
`tail -3 /tmp/ubuntu.log`; expect `OK (HEAD=<final pushed SHA>)`. On FAIL → `git reset --mixed
HEAD~2` (A-10a source + this handover chore) to last ubuntu-verified HEAD (`93925bb6`), fix,
re-gate. On GREEN/non-code-gap → proceed to A-10b (`array.new_elem`).
**User-requested clean-session stop** (context-window reset): NO ScheduleWakeup re-arm this turn;
this fresh handover is the entry point for the next manual `/continue`. A-10b recipe is in the
Active bundle NEXT + bundle plan §"array.* sub-bundle" — a verbatim copy of `array_new_data.zig`
swapping the trampoline (`jitGcArrayNewElem`, `elem_segments_ptr`, direct u64 copy) + op_tag.

**Lesson (still live)**: `gate_commit.sh --fast` DEFERS `zig build test`/`lint` (Step 4/5 own them) — parent's full `zig build test` before push is the real gate.

## Key refs

- **ADR-0128** (Phase 10 100% master plan); ADR-0127 (cross-module func type-identity);
  ADR-0115 §10 (non-moving β collector); ADR-0060 (force-spill + A-3 amend). ROADMAP §10.
- Debt: **D-211** (GC-on-JIT), D-209 (stale), D-202 / D-198 / D-210. Lessons
  `2026-05-31-wasmgc-jit-non-moving-deferred-rooting` + `...-partial-spec-corpus-interp`.
