# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). The prior "close-eligible" posture is RETRACTED: §10 exit requires the
  official Wasm 3.0 testsuite at pass=fail=skip=0 on **both backends** (interp + JIT).
- **HEAD**: `97658b5d` (cyc246 — **x86_64 i31 emit** + ungated e2e; i31 op family now
  complete on BOTH backends). cyc245 (`3e05fa62`, arm64 i31) ubuntu-verified green.
- **Two execution paths (CODE-verified)**: the spec corpus runs **interp-only**
  (`instance.invoke`→`_dispatch.run`, `instance.zig:169`). The JIT emits 1.0/2.0 +
  tail-call + function-references + EH + **i31 (both arches)**; remaining GC (struct/
  array/ref.cast/ref.eq) still interp-only (D-211). Green gc/EH spec corpus is INTERP
  coverage; the JIT is unverified against the corpus.
- **ADR-0128 + ADR-0127 both Accepted (2026-05-31, user "100%")** — no remaining user
  gate; the loop executes the workstreams below autonomously.

## Active task — Phase 10 → 100% (ADR-0128)  **NEXT**

Six workstreams (ADR-0128). Drive in this order; each is value-prioritized, NOT the
§10 table-first `[ ]` (the six `[ ]` rows are parallel proposal tracks):

1. **Spec-corpus JIT execution mode** (§1) — verification backbone: run the official
   testsuite through the JIT (compile-every-fn → JIT-entry invoke → compare; wasmtime
   `tests/wast.rs` pattern) so every JIT gap (incl. GC) shows up RED. Host-call thunking +
   typed trap mapping + multi-value + NaN; `assert_invalid` stays on validator path.
2. **GC-on-JIT op emit** (D-211 bundle; §2) — struct/array/ref.cast/i31/ref.eq, both
   arches. NON-moving collector + β no-reclaim ⇒ **rooting deferred** (no safepoints /
   stack-maps); this is op-emit like the landed EH/TC op files, NOT regalloc surgery.
   ref.cast = Cohen supertype-vector display (`n1>=n2` guard, CVE-2024-4761).
3. **ADR-0127 PHASE C** — cross-`Types` `canonicalEqual`; `gc/type-subtyping`
   assert_unlinkable 5→0.
4. Quick wins: **D-209** (lift the leftover `>u32` offset check, `lower.zig:864-867` +
   `lower_simd.zig:372`; payload is already u64), then **D-198** (rec-group subtype),
   **D-210** (cross-module proper-tail-call — arm64 prologue cohort-save).
5. **Realworld GC/EH/TC producers** (§5; flake.nix `#gen`): `wasm_of_ocaml` (triple
   crown) / `emcc -fwasm-exceptions` / `guile-hoot`; `wat2wasm --enable-all` lever for
   per-opcode gaps. Updates `toolchain_provisioning.md`.

## Active bundle

- **Bundle-ID**: `10.G-gc-on-jit-IT-1..N`
- **Cycles-remaining**: ~5-6
- **Continuity-memo**: PROVEN recipe — i31 landed both arches cyc245-246; reuse verbatim
  for struct/array/cast/eq. Per GC op, the touch-points are: (1) op-file
  `codegen/{arm64,x86_64}/ops/wasm_3_0/<op>.zig` (`pub const op_tag/wasm_level/wasi_level`
  + `pub fn emit(ctx,ins) Error!void`); arm64 → `collected_arm64_ops`, x86_64 → **`collected_x86_64_ctx_ops`**
  (NOT `_ops` — the v3_0 ops live in the ctx tuple). (2) `stackEffect` entry per *value* op
  in `ir/analysis/liveness_stack_effect.zig` (drives liveness + `populateShapeTags`;
  non-SIMD producers auto-tag `.scalar`=GPR) — omit → `UnsupportedOp[stackEffect-missing]`.
  (3) bump count tests in `dispatch_collector.zig` (`migratedArchOpCount(.arm64)` + `collected_x86_64_ctx_ops.len`).
  (4) **any trap-emitting op (bounds_fixups / JE→trap) MUST be added to x86_64
  `usage.zig` `usesRuntimePtr`** — else D-180 silent miscompile (trap stub writes
  trap_flag via uninit R15 on x86_64; Mac arm64 immune). struct.new's alloc trampoline
  CALL also needs this. (5) e2e via `runI32Export` (hand-encode wasm; wat2wasm 1.0.40
  lacks GC text). `Value.anyref`=u32 on stack. struct/array: alloc trampoline model =
  `shared/throw_trampoline.zig` + heap `feature/gc/heap.zig` (`allocate(size)→GcRef`=u32
  slab off, ObjectHeader 8B); rooting DEFERRED (non-moving). Per-op lowering: ADR-0128 §2.
- **First-op order**: (1) **i31** — DONE both arches (`97658b5d`). NEXT = (2) **struct.new
  / struct.get / struct.set** — add `shared/gc_alloc_trampoline.zig` (CALL into
  `heap.allocate`; needs `usesRuntimePtr`); field load/store = base+`StructInfo.fields[i].offset`.
  (3) array.new/get/set/len. (4) ref.cast/test (Cohen supertype-vector display, `n1>=n2`
  guard, CVE-2024-4761). (5) ref.eq. Then workstream 1 (spec-corpus JIT mode).
- **Exit-condition**: i31 green via `runI32Export` both arches — **DONE** (`97658b5d`).
  Bundle continues to struct/array/ref.cast; close when all GC ops emit + corpus green.

## §10 remaining — the six `[ ]` rows (精査)

- **10.M** memory64 — corpus green; **D-209 is STALE** (payload u64; spec max offset =
  2^32−1; lift the leftover u32 check → done).
- **10.R** function-references — JIT emit present, corpus green; residual = **D-198**.
- **10.TC** tail-call — JIT matrix complete; residuals = **D-210** + `wasm_of_ocaml`.
- **10.E** EH — JIT emit present; residuals = eh_frequency runner (I20), c_api tag
  accessors (I14 → Phase 13), emscripten_eh realworld (I21; now provisioned, §5).
- **10.G** GC — **JIT emit PARTIAL (D-211)**: i31 family DONE both arches (cyc245-246);
  remaining = struct/array/ref.cast/ref.eq both arches + **ADR-0127 PHASE C** + D-198 +
  gc_stress (I19) + dart/hoot realworld (I21, §5). GC-on-JIT = op-emit (§2).
- **10.P** close — flips to close only at 100% both-backends (ADR-0128); the
  close-eligible SKIP invariants (I16 GC-on-JIT; I3/I5/I19/I20/I21; I11/I14/I23) become
  REAL targets, not permanent SKIPs.

## Step 0.7 (next resume)

cyc245 (`3e05fa62`, arm64 i31) ubuntu-verified green. cyc246 (`97658b5d`) = x86_64 i31 +
ungated e2e: the 3 `runI32Export` i31 tests now RUN on ubuntu x86_64 (incl. the null-trap
path that exercises the R15 trap stub — the real D-180 verification for the `usesRuntimePtr`
whitelist entry). Verify `tail -3 /tmp/ubuntu.log` next resume; FAIL → revert cyc246.

## Key refs

- **ADR-0128** (Phase 10 100% both-backends — the master plan); ADR-0127 (Accepted,
  cross-module func type-identity); ADR-0115 §10 (non-moving β collector; reclamation →
  Phase 11); ADR-0066 / ADR-0112+Amendment (cross-module TC).
- Debt: **D-211** (GC-on-JIT), D-209 (memory64 offset — stale), D-202 / D-198 / D-210.
- Lessons `2026-05-31-wasmgc-jit-non-moving-deferred-rooting`,
  `2026-05-30-phase10-jit-coverage-partial-spec-corpus-interp`. ROADMAP §10.
