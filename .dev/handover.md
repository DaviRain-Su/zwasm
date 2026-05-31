# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — committed to 100% (ADR-0128)** (Phase 9 = DONE
  2026-05-24). §10 exit requires the official Wasm 3.0 testsuite at pass=fail=skip=0
  on **both backends** (interp + JIT).
- **HEAD**: 10.G **R-2 `ref.cast`** emit both arches (`8e3f6a83`). ref.test sub-bundle:
  R-1 `ref.test`/`ref.test_null` (`c2a8fd11`) + R-2 `ref.cast` (`8e3f6a83`) now JIT-emit on
  both arches. NEW trampolines `jitGcRefTest(rt, ref:u64, ht_nullbit) → u32(0/1)` (null folds
  in via `(ht>>8)&1`) + `jitGcRefCast(rt, ref:u64, ht) → u64(ref or 0=trap)`. **KEY**: the
  subtype-check core is now SHARED — refactored the interp's `gcRefMatchesNonNull(rt,...)` into
  a Runtime-free `gcRefMatchesNonNullCore(gti, heap, v, ht)` (ref_test_ops.zig) that BOTH the
  interp wrapper AND the JIT trampolines call (one algorithm; no canonical_id/func-resolution
  drift between engines). Emit: pop ref → 3-arg marshal (rt + 64-bit ref + ht|nullbit) → CALL →
  [cast: CMP X0/RAX,#0 64-bit + B.EQ/JE bounds_fixups] → capture i32(test)/64-bit ref(cast).
  1→1; strict force-spill; usesRuntimePtr. Verified: arm64 `zig build test` EXIT=0 + lint 0 +
  x86_64 cross EXIT=0.
- **Two execution paths (CODE-verified)**: spec corpus runs **interp-only**
  (`instance.invoke`→`_dispatch.run`, `instance.zig:169`); JIT corpus run = §1. JIT emits
  1.0/2.0 + TC + func-refs + EH + i31 + full struct family + **full array family** + ref.eq +
  **ref.test/ref.test_null/ref.cast** (both arches); remaining GC = ref.cast_null + br_on_cast
  (D-211). Green gc/EH corpus = INTERP.
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
- **Continuity-memo**: PROVEN per-GC-op recipe in **`.dev/phase10_g_op_bundle_plan.md`**
  §"GC-on-JIT emit design" + §"array.* sub-bundle" (single source — do NOT re-derive). Verified
  x86_64 facts: pinned rt = R15; SysV args RDI/RSI/RDX(/RCX/R8), ret RAX; emit scratch = R10
  (CALL target) ∉ regalloc pool ({RBX,R12,R13,R14}); result via gprDefSpilled/gprStoreSpilled.
  **ref ops carry FULL 64-bit values** (funcref ptr / i31-tagged / u32 heap offset) — marshal
  with 64-bit moves (encOrrReg / encMovRR(.q)); ref.cast trap-check is 64-bit (encCmpImmX /
  encTestRR(.q)). dispatch_collector.zig counts are LITERALS — bump per op (now arm64=375 /
  x86_64_ctx=424). Subtype check is the SHARED `gcRefMatchesNonNullCore` (ref_test_ops.zig).
- **DONE both arches**: i31 + struct.{new_default,get,new,set} + **array.\* (all 12)** + ref.eq
  + **ref.test + ref.test_null (R-1) + ref.cast (R-2)**. Per-op SHAs in `git log` + bundle plan.
  Per-GC-op touch-points (REUSE): op-file ×2 + `collected_{arm64_ops,x86_64_ctx_ops}` + bump
  dispatch_collector.zig count LITERALS + `stackEffect` + x86_64 `usesRuntimePtr` (R15 CALL ops)
  + regalloc_compute force-spill (CALL ops) + ungated `runI32Export` e2e (**hand-encode:
  wat2wasm 1.0.40 can't parse GC array/ref text; ref.cast leaves a REF on stack — trap-test
  bodies need `drop; i32.const 0` to type-check; i32.const ≥ 64 needs multi-byte signed LEB128**).
- **NEXT = ref.cast_null emit, both arches** — like ref.cast but null PASSES (returns null, no
  trap), so emit needs an INLINE null-skip branch (CBZ Xref,.done / TEST+JZ → push original ref;
  else CALL jitGcRefCast → trap-on-0; .done) — a forward-branch fixup, NOT straight-line. Reuses
  the existing `jitGcRefCast` trampoline (only non-null mismatch traps). Then br_on_cast /
  br_on_cast_fail (0xFB 0x18/0x19 — combine the cast with a branch; control-flow, separate).
- **Exit-condition**: all GC ops emit on both arches + spec corpus green via JIT mode (§1).

## §10 remaining — the six `[ ]` rows

- **10.M** memory64 — corpus green; D-209 STALE (payload u64; lift leftover u32 check).
- **10.R** function-references — JIT emit present, corpus green; residual = D-198.
- **10.TC** tail-call — JIT matrix complete; residuals = D-210 + `wasm_of_ocaml`.
- **10.E** EH — JIT emit present; residuals = eh_frequency runner (I20), c_api tag
  accessors (I14 → Phase 13), emscripten_eh realworld (I21).
- **10.G** GC — JIT emit PARTIAL (D-211): i31 + full struct family + full array family + ref.eq
  + **ref.test/test_null/cast** DONE both arches; remaining = ref.cast_null + br_on_cast (RTT)
  + ADR-0127 PHASE C + D-198 + gc_stress (I19) + dart/hoot (I21).
- **10.P** close — flips only at 100% both-backends (ADR-0128).

## Step 0.7 (next resume)

**R-1 + R-2 kicked to ubuntu THIS turn** (background `test-all`, final HEAD `8e3f6a83`).
Next `/continue`: `tail -3 /tmp/ubuntu.log` — expect `[run_remote_ubuntu] OK (HEAD=8e3f6a83)`.
On FAIL: revert the turn's commit pairs to the last ubuntu-verified HEAD (`829b6914` = A-10b).
On GREEN: proceed to NEXT (ref.cast_null — Step 0 survey is light; recipe in Active bundle).

**Lesson (still live)**: `gate_commit.sh --fast` DEFERS `zig build test`/`lint` (Step 4/5 own
them) — parent's full `zig build test` before push is the real gate.

## Key refs

- **ADR-0128** (Phase 10 100% master plan); ADR-0116 (RTT 8-deep Cohen display + subtype check);
  ADR-0127 (cross-module func type-identity); ADR-0126 (canonical type ids); ADR-0115 §10
  (non-moving β collector); ADR-0060 (force-spill). ROADMAP §10.
- Debt: **D-211** (GC-on-JIT), D-209 (stale), D-202 / D-198 / D-210. Lessons
  `2026-05-31-wasmgc-jit-non-moving-deferred-rooting` + `...-partial-spec-corpus-interp`.
