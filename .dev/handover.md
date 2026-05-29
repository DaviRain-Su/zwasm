# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc190 (`0f06df6e`) — **gc global-init type-check landed**:
  `validator.constExprResultType` + `validateGlobalInits` (GC-aware, ADR-0126
  iso-recursive) wired into `frontendValidate`. **gc invalid 57→60 fail=0**;
  ZERO regression (gc return 349 / trap 96 + all 5 proposals unchanged;
  assert_invalid 191→194). Root cause: native-API validate path never
  checked global init types (only legacy JIT compile.zig did, funcref-only).
  Remaining gc fails: **return=1 + trap=4 = .30/.48/.50 SignatureMismatch at
  instantiate** (D-198/201, the deeper edge — cyc191 target). §10 ROW close
  also needs realworld/p10 (clang_wasm64+clang_musttail autonomous; emcc/
  dart/ocaml/hoot tool-gated).
- Earlier arc: cyc177 iso-recursive canonicalEqual; cyc147-148 ADR-0125
  packed; cyc146 ADR-0016 M3 self-attribution; cyc130-140 i31/struct/array.
- Runner EXECUTES via interp; gc_heap + gc_type_infos + rt.datas all
  materialised at instantiate. Arrays use 8-byte uniform slots
  (type_info.slot_size); data-seg elements are NATURAL width.
- **Bundle 10.E-eh-tail CLOSED** cyc120 (`5db875b0`) — EH corpus FULLY
  GREEN 34/34 (cross-module propagation + caller-frame catch; ADR-0114
  full substrate cyc110–120; D-192 EH clause PROVEN). Lesson
  `eh-cross-module-tag-substrate-scope` has the journey.
- Mac+ubuntu green through cyc188 (`OK (HEAD=e7454fbf)`). No active bundle:
  10.G-gc + 10.H-multimem both CLOSED cyc188. Cross-module sharing substrate:
  D-199 memory + D-201 table/func.

## Active task — cycle 191: diagnose gc type-subtyping .30/.48/.50 SignatureMismatch — **NEXT**

cyc190 closed the gc-invalid axis (60/60). The remaining gc fails are
**return=1 + trap=4**, all from `gc/type-subtyping.30/.48/.50` which fail at
**instantiate with `SignatureMismatch`** (these are assert_return/trap
modules, not invalid). The runner prints `instantiate FAIL: SignatureMismatch`.
Hypothesis: an import/func signature comparison at instantiate is subtyping-
BLIND (exact `FuncType` eql instead of GC subtyping per ADR-0126) — a typed-
ref signature whose param/result reftype is a valid subtype is rejected.
**cyc191 plan**: (1) `wasm-tools print` .30/.48/.50 to see the actual sig
shapes + whether cross-module (register) or single-module call_indirect/
import. (2) grep instantiate.zig / linker.zig / checkImportTypeMatches
(instantiate.zig:1615) for the sig-equality site; check if it uses `.eql`
where `gcValTypeSubtype`/`canonicalEqual` is needed. (3) If a bounded
subtyping-aware sig-compare fix → land it (gc return 349→350, trap 96→100).
If it's the deep cross-module D-198 rabbit hole (re-exported import sig
threading), confirm + PIVOT to realworld/p10 clang fixtures (clang_wasm64 +
clang_musttail — autonomous).
**Bar**: any fix keeps gc invalid 60 + all 5 proposals green, 0 panics,
exit 0. If rabbit hole after 1 cycle of probing, defer (D-198) + pivot.

## §10 close map (cyc189 reassessment)

Feature impl rows (10.G/10.M/10.E/10.TC/10.R) are spec-corpus-mature but
ROADMAP-`[ ]`; their formal close needs realworld/p10 fixtures + 10.P.

- **realworld/p10** (skeleton, no `.wasm`): `clang_wasm64` + `clang_musttail`
  AUTONOMOUS (clang✓ in PATH, wasm-tools✓) — next major chunk after the
  spec residuals. `emscripten_eh` / `dart` / `wasm_of_ocaml` / `hoot` are
  TOOL-GATED (emcc/dart/ocaml absent) — self-provision via nix or defer.
- **gc .17** funcref-RTT (D-198 .17 rabbit hole) + **cross-module sig**
  (.30/.48/.50, uncounted, D-198/201) — deeper deferred edges.
- **funcrefs** 34/39 — 5 gated (externref-arg runner + resolveFuncrefGlobals
  off spec-corpus path); **10.P close gate** = user touchpoint by construction.

## Spec runner observable (cyc190, DIRECT binary run)

```
[memory64           ] return=337 (all pass)    [tail-call] return=71 (all pass)
[exception-handling ] 34/34 ✅ FULLY GREEN     [function-references] return=34/39
[gc                 ] return=349/407 trap=96/100 invalid=60/60 ✅ malformed=1/1 skip=20  ← cyc190 invalid-axis closed
[multi-memory       ] return=407/407 trap=244/244  ← cyc188 ALL-GREEN (D-199/200/201 cross-module chain)
```
> gc residual: return=1 + trap=4 = type-subtyping.30/.48/.50 SignatureMismatch (cyc191).

> Use `--fail-detail` (reliable per-assert), NOT the per-manifest breakdown
> (over-counts gc). Real gc residuals: i31(4) + type-sub(5) + ref_test(2).

## Open questions / blockers

- D-197: parse/validate/instantiate split DONE cyc127. Specific
  validate-error surfacing is ad-hoc via the cyc143 op-probe (lesson
  `gc-type-subtyping-is-rtt-blocked`); permanent diag emitter = D-197 tail.
- D-192: EH clause PROVEN (EH 34/34). funcrefs clause proven cyc108.

## Key refs

- ADR-0114 (EH `*TagInstance`, IMPLEMENTED cyc110–120); ADR-0115/0116/
  0121 (GC heap + type-info); ADR-0120/0123.
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (full EH journey) + `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
