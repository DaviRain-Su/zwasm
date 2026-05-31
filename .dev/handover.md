# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD**: `5d2c4e8a` — 10.G **`struct.{new,get,set,new_default}` ALL emit both arches**
  (struct family complete). This turn: C3 `aa158810` x86_64 struct.new SysV mirror + C4
  `5d2c4e8a` struct.set both arches (2→0 store: null-trap ref, reload slab, STORE value at
  `[base+8+fieldidx*8]`; stage-0 reused for ref-then-value). struct.new mechanism: lowerer
  stamps `struct_field_counts[typeidx]`→`ZirInstr.extra` (via `lowerFunctionBodyWith` +
  `compileOne` param); emit allocs (CALL jitGcAlloc) → reloads slab base AFTER → stores
  force-spilled fields. e2e round-trips ungated both arches (struct.new→42; struct.set→55).
  Verified: full `zig build test` (arm64) EXIT=0 + lint 0 + x86_64 cross-compile EXIT=0;
  x86_64 RUNTIME = ubuntu gate (kicked against final HEAD).
- **Two execution paths (CODE-verified)**: spec corpus runs **interp-only**
  (`instance.invoke`→`_dispatch.run`, `instance.zig:169`); JIT corpus run = §1. JIT emits
  1.0/2.0 + TC + func-refs + EH + i31 + full struct family (both arches); remaining GC
  (array.* / ref.cast / ref.eq) interp-only (D-211). Green gc/EH corpus = INTERP.
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
  re-derive). Verified x86_64 facts: pinned rt = R15; SysV args RDI/RSI, ret EAX; emit
  scratch = `spill_stage_gprs` = {R10(stage0), R11(stage1)} — NOT in regalloc pool
  (`allocatable_gprs` = {RBX,R12,R13,R14}; do NOT use R13/R14 as ad-hoc scratch); struct.get
  slab base uses R11 (stage1) so it can't alias the popped ref / result in stage0=R10;
  result via gprDefSpilled/gprStoreSpilled (encoders: read existing x86_64 struct files).
  x86_64 ctx-op count test in dispatch_collector.zig is a LITERAL (`expectEqual(406, ...)`) —
  bump per added op. struct offsets UNIFORM `8+idx*8` (ADR-0116 §3a); rooting DEFERRED.
- **First-op order**: i31 + **struct.{new_default,get,new,set}** all DONE both arches. Proven
  per-GC-op touch-points (REUSE for array): op-file `codegen/{arm64,x86_64}/ops/wasm_3_0/<op>.zig`
  + register in `collected_{arm64_ops,x86_64_ctx_ops}` (dispatch_collector_ops.zig) + bump the
  count LITERALS in dispatch_collector.zig (arm64 = `migratedArchOpCount`, x86_64 =
  `collected_x86_64_ctx_ops.len`) + `stackEffect` entry (or liveness special-case if variadic) +
  x86_64 `usage.zig` `usesRuntimePtr` for any op touching R15 (slab/CALL; D-180 guard) + ungated
  `runI32Export` e2e (hand-encode; **i32.const value ≥ 64 needs multi-byte signed LEB128** — bit 6
  set sign-extends, e.g. 99=`E3 00` not `63`; keep test values < 64). Alloc ops also need the
  ADR-0060 force-spill (struct.new_default/struct.new are in regalloc_compute.zig `is_call`).
  **NEXT = array.* (`array.new`/`array.new_default`/`array.get`/`array.set`/`array.len`)**: shares
  alloc + slab machinery; needs length field in the object header + element-type stride (survey
  `instruction/wasm_3_0/array_ops.zig` interp contract + ADR-0116 array layout first — Step 0).
  Then ref.cast / ref.test / ref.eq.
- **Exit-condition**: all GC ops emit on both arches + spec corpus green via JIT mode (§1).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 STALE (payload u64; lift leftover u32 check).
- **10.R** function-references — JIT emit present, corpus green; residual = D-198.
- **10.TC** tail-call — JIT matrix complete; residuals = D-210 + `wasm_of_ocaml`.
- **10.E** EH — JIT emit present; residuals = eh_frequency runner (I20), c_api tag
  accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit PARTIAL (D-211): i31 + **full struct family** (new_default/get/new/set)
  DONE both arches; remaining = array.* / ref.cast / ref.eq + ADR-0127 PHASE C + D-198 +
  gc_stress (I19) + dart/hoot realworld (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

Prior x86_64 struct mirror (`805d7aa8`) ubuntu-verified green `OK (HEAD=805d7aa8)` — the
`failed command:` line in `/tmp/ubuntu.log` is **benign** negative-test stderr (reproduces
locally with EXIT=0; resolved). Prior `b5a8cdc7` (C1+C2) ubuntu-verified green this session.
This turn = C3 `aa158810` (x86_64 struct.new mirror) + C4 `5d2c4e8a` (struct.set both arches).
Verified locally: full `zig build test` (arm64) EXIT=0 + lint 0 + `zig build
-Dtarget=x86_64-linux-gnu` EXIT=0. Both struct e2e round-trips are **ungated** — x86_64 RUNTIME
exec of struct.new + struct.set is verified ONLY by the ubuntu kick (Mac runs arm64). Verify
`tail -3 /tmp/ubuntu.log` next resume; revert the turn's commits to the last ubuntu-green HEAD
(`b5a8cdc7`) on FAIL.

**Lesson (still live)**: `gate_commit.sh --fast` DEFERS `zig build test`/`lint` (Step 4/5 own
them); the parent's independent full `zig build test` before push is the real gate.

## Key refs

- **ADR-0128** (Phase 10 100% master plan); ADR-0127 (cross-module func type-identity);
  ADR-0115 §10 (non-moving β collector); ADR-0060 (force-spill + A-3 amend). ROADMAP §10.
- Debt: **D-211** (GC-on-JIT), D-209 (stale), D-202 / D-198 / D-210. Lessons
  `2026-05-31-wasmgc-jit-non-moving-deferred-rooting` + `...-partial-spec-corpus-interp`.
