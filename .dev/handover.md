# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: `157595d6`→(this cyc211 docs commit). funcref-call + tail-call JIT POSITIVE
  paths done both arches (call_ref + return_call_ref + direct/indirect/recursion
  return_call + clang musttail; all ubuntu-verified). **D-208 (open, close-blocker)**:
  x86_64 call_ref/return_call_ref of a NULL funcref returns Ok(0) not trapping (arm64 OK,
  gated). cyc211 static investigation ruled out ALL 6 hypotheses (JZ-encoding / patcher /
  ref.null-value / regalloc[shared+arm64-correct] / trap-stub-emission[unreachable proves
  it] / fixup) — bug is in x86_64 EMIT BYTES but elusive to static analysis. D-205/D-207
  discharged; open: D-208, D-206 (cross-module TC, harness-gated).
- Earlier: 10.TC same-module tail-call (direct/indirect/recursion + clang musttail
  → 15, cyc198-201); EH corpus 34/34 (ADR-0114); cyc190-196 gc global-init/subtyping.
  Phase 10 CLOSE-ELIGIBLE (spec corpus interp-complete); Runner EXECUTES via interp,
  gc_heap materialised at instantiate. 10.M memory64 + 10.E EH JIT largely done;
  10.G GC JIT = interp-only (extreme: regalloc stack-map, ADR-0113 §C).
- **Step 0.7 on resume**: cyc210+cyc211 are docs-only (10.P rationale refresh + D-208
  investigation) → no ubuntu kick; green holds. Last code-kick: cyc209 ubuntu
  `OK (HEAD=9dbc84ee)` GREEN (D-208 gate recovery — gated null-trap tests skip on x86_64).

## Active task — D-208 byte-disasm harness (x86_64 null-check)  **NEXT**

Static analysis exhausted (all 6 hypotheses ruled out, see D-208). Root-cause needs
seeing the EMITTED x86_64 bytes. Build a Mac-runnable byte-dump (x86_64 emit is pure
byte-gen): mirror `src/engine/codegen/x86_64/emit_test_int.zig` — construct a ZirFunc
`[ref.null $sig, call_ref $sig, end]`, compute real liveness (`ir/analysis/liveness.zig`)
+ regalloc (`shared/regalloc.zig`), call `x86_64/emit.zig` compile → `out.bytes`, write
to a tmp file, `ndisasm -b64` it (debug_jit_auto skill). INSPECT: the `OR r64,r64`, the
`JZ rel32` (its PATCHED disp — does it point at the trap stub?), and the trap stub
(does it set trap_flag + RET?). The bug is one of those bytes. Fix → re-run the
(aarch64-gated) null-trap test logic mentally → ungate → 1 ubuntu round-trip to verify.
Deferred: cross-module TC (D-206, multi-module harness); GC JIT (10.G, extreme).
**Yield/user note**: JIT milestone delivered; a user check-in on Phase-10-close-vs-grind
is high-value (see Open questions yield-taper note).

## §10 close map

Spec-corpus rows (10.G/10.M/10.E/10.TC/10.R) are mature but ROADMAP-`[ ]`;
formal close needs realworld/p10 + 10.P. Residual:
- **realworld/p10**: clang_musttail DONE (cyc201, JIT result-checked); clang_wasm64
  next-AUTONOMOUS (clang✓); emscripten/dart/ocaml/hoot TOOL-GATED.
- **gc .17** funcref-RTT (D-198 multi-mechanism rabbit hole) — deep defer.
- **funcrefs** 34/39 — 5 gated; **10.P close gate** = user touchpoint.

## Spec runner observable (cyc190, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=349/407 trap=96/100 invalid=60/60 ✅ malformed=1/1 skip=20  ← cyc190 invalid-axis closed
[multi-memory       ] return=407/407 trap=244/244  ← cyc188 ALL-GREEN (D-199/200/201 cross-module chain)
```
> gc residual: return=1 + trap=4 = type-subtyping.30/.48/.50 (the bundle).
> Use `--fail-detail` (reliable per-assert), NOT the per-manifest breakdown.

## Open questions / blockers

- D-197: parse/validate/instantiate split DONE cyc127. Specific
  validate-error surfacing is ad-hoc via the cyc143 op-probe (lesson
  `gc-type-subtyping-is-rtt-blocked`); permanent diag emitter = D-197 tail.
- D-192: EH clause PROVEN (EH 34/34). funcrefs clause proven cyc108.
- **Yield-taper note (2026-05-30)**: the funcref-call + tail-call JIT milestone is
  DELIVERED (cyc198-208, both arches, ubuntu-verified). cyc208-210 were lower-yield
  (null-trap fixture + D-208 gate-recovery + 10.P rationale refresh). Remaining
  autonomous JIT work is gated/slow: D-208 (x86_64 null-check — needs x86_64 disasm /
  ubuntu-iterate), cross-module TC (D-206 — multi-module harness), 10.G GC JIT
  (extreme). **Phase 10 close is a user touchpoint** (close map below; 10.P I18 now
  FAILs on open D-208 = close-blocker). Loop continues on the D-208 byte-disasm
  (autonomous-eligible), but a user check-in on "close Phase 10 vs keep grinding JIT"
  would be high-value before the next big chunk. NOT a stop — re-arm holds.

## Key refs

- ADR-0114 (EH `*TagInstance`, IMPLEMENTED cyc110–120); ADR-0115/0116/
  0121 (GC heap + type-info); ADR-0120/0123.
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (full EH journey) + `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
