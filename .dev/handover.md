# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD**: `fb73a87b` — 10.G **regalloc alloc-op force-spill** (A-3 foundation; ADR-0060
  amend): `struct.new` reads its field operands AFTER the internal jitGcAlloc CALL, so a
  vreg whose last_use IS the struct.new PC must spill across it. Added an inclusive-alloc-op
  category to the ADR-0060 force-spill pre-scan (`regalloc_compute.zig`: `cp <= last_use_pc`
  for struct.new; struct.new_default stays strict — 0 field operands). 3 regalloc unit tests.
  Verified: full `zig build test` (native arm64) EXIT=0 + `zig build lint` 0. (Prior
  `fb991029` x86_64 struct.new_default/get mirror ubuntu-verified `OK HEAD=805d7aa8`.)
- **Two execution paths (CODE-verified)**: spec corpus runs **interp-only**
  (`instance.invoke`→`_dispatch.run`, `instance.zig:169`). JIT emits 1.0/2.0 + tail-call +
  function-references + EH + i31 (both arches) + **struct.new_default/get (both arches)**;
  remaining GC (struct.new variadic / struct.set / array / ref.cast / ref.eq) interp-only
  (D-211). Green gc/EH corpus = INTERP coverage; JIT corpus run = §1 workstream.
- **ADR-0128 + ADR-0127 both Accepted** — no remaining user gate; loop runs autonomously.

## Active task — Phase 10 → 100% (ADR-0128)  **NEXT**

Six workstreams (ADR-0128), value-prioritized (NOT §10 table-first):

1. **Spec-corpus JIT execution mode** (§1) — verification backbone: run the official
   testsuite through the JIT (compile-every-fn → JIT-entry invoke → compare; wasmtime
   `tests/wast.rs` pattern) so every JIT gap shows up RED. Host-call thunking + typed trap
   mapping + multi-value + NaN; `assert_invalid` stays on validator path.
2. **GC-on-JIT op emit** (D-211 bundle; §2) — see Active bundle below.
3. **ADR-0127 PHASE C** — cross-`Types` `canonicalEqual`; `gc/type-subtyping`
   assert_unlinkable 5→0.
4. Quick wins: **D-209** (lift leftover `>u32` offset check, `lower.zig:864-867` +
   `lower_simd.zig:372`; payload already u64), **D-198** (rec-group subtype), **D-210**
   (cross-module proper-tail-call — arm64 prologue cohort-save).
5. **Realworld GC/EH/TC producers** (§5; flake.nix `#gen`): `wasm_of_ocaml` / `emcc
   -fwasm-exceptions` / `guile-hoot`. Updates `toolchain_provisioning.md`.

## Active bundle

- **Bundle-ID**: `10.G-gc-on-jit-IT-1..N`
- **Cycles-remaining**: ~4-5
- **Continuity-memo**: PROVEN per-GC-op recipe + full struct design in
  **`.dev/phase10_g_op_bundle_plan.md`** §"GC-on-JIT emit design" (single source — do NOT
  re-derive). Verified x86_64 facts: pinned rt = R15; SysV args RDI/RSI, ret EAX; emit
  scratch = `spill_stage_gprs` = {R10(stage0), R11(stage1)} — NOT in regalloc pool
  (`allocatable_gprs` = {RBX,R12,R13,R14}; do NOT use R13/R14 as ad-hoc scratch); struct.get
  slab base uses R11 (stage1) so it can't alias the popped ref / result in stage0=R10;
  result via gprDefSpilled/gprStoreSpilled; encoders encMovRR/encMovImm32W/encMovImm64Q/
  encCallReg/encTestRR/encJccRel32/encMovR64FromMemDisp32/encAddRR (.slice()). x86_64
  ctx-op count test in dispatch_collector.zig is a LITERAL (`expectEqual(406, ...)`) — bump
  it per added op. struct offsets UNIFORM `8+idx*8` (ADR-0116 §3a); rooting DEFERRED.
- **First-op order**: i31 both arches DONE (`97658b5d`). struct.new_default/struct.get:
  arm64 DONE (A-2b-1 `68a2dbf0` / A-2b-2 `81bd0312`), x86_64 DONE (`fb991029`). **A-3 IN
  PROGRESS**: regalloc alloc-op force-spill DONE (`fb73a87b`, ADR-0060 amend). **NEXT = A-3
  arm64 `struct.new` emit**: thread compile-time `struct_field_counts: []const u32` (typeidx
  index; built from type section) into `liveness.compute` + EmitCtx; liveness special-case
  (mirror `call` arm @ liveness.zig:453 — pop field_count, push 1); arm64 `struct_new.zig`
  emit (marshal rt+typeidx → BLR &jitGcAlloc → W0=ref; **reload slab base AFTER call**; store
  each field `[slab+ref+8+i*8]`; push ref); e2e `runI32Export` round-trip. Then x86_64
  mirror. Then `struct.set` (2→0). Then array.* / ref.cast / ref.eq.
- **Exit-condition**: all GC ops emit on both arches + spec corpus green via JIT mode (§1).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 STALE (payload u64; lift leftover u32 check).
- **10.R** function-references — JIT emit present, corpus green; residual = D-198.
- **10.TC** tail-call — JIT matrix complete; residuals = D-210 + `wasm_of_ocaml`.
- **10.E** EH — JIT emit present; residuals = eh_frequency runner (I20), c_api tag
  accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit PARTIAL (D-211): i31 + struct.new_default/get DONE both arches;
  remaining = struct.new variadic / struct.set / array / ref.cast / ref.eq + ADR-0127
  PHASE C + D-198 + gc_stress (I19) + dart/hoot realworld (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

Prior x86_64 struct mirror (`805d7aa8`) ubuntu-verified green `OK (HEAD=805d7aa8)` — the
`failed command:` line in `/tmp/ubuntu.log` is **benign** negative-test stderr (reproduces
locally with EXIT=0; resolved this resume). This turn's commits verified locally by full
`zig build test` (arm64, EXIT=0) + `zig build lint` 0; ubuntu kick launched against the
turn's final HEAD — verify `tail -3 /tmp/ubuntu.log` next resume; revert the turn's commits
on FAIL.

**Lesson (still live)**: `gate_commit.sh --fast` DEFERS `zig build test`/`lint` (Step 4/5
own them) — a worker gated only on `--fast` can ship red code; the parent's independent full
`zig build test` before push is the real gate. Prefer MAIN over subagents when the harness is
degraded (2026-05-31 elevated-error incident; `408e0a36` revert).

## Key refs

- **ADR-0128** (Phase 10 100% both-backends — master plan); ADR-0127 (cross-module func
  type-identity); ADR-0115 §10 (non-moving β collector); ADR-0066 / ADR-0112+Amendment (TC).
- Debt: **D-211** (GC-on-JIT), D-209 (stale), D-202 / D-198 / D-210.
- Lessons `2026-05-31-wasmgc-jit-non-moving-deferred-rooting`,
  `2026-05-30-phase10-jit-coverage-partial-spec-corpus-interp`. ROADMAP §10.
