# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc192 (`6a77cb19`) — **cross-module func import SUBTYPING landed**:
  `validator.funcTypeImportCompatible` (contravariant params / covariant
  results, §4.5.10/§3.3.5.1) wired into `checkImportTypeMatches`. **gc
  .30/.48/.50 SignatureMismatch 3→0** — they instantiate now. Monotonic-safe
  (eql fast-path); ZERO regression (all 5 proposals + gc 349/96/60 unchanged;
  0 panics). Count note: .30/.48/.50 are `module` directives (uncounted), so
  gc headline count is steady — real win = SignatureMismatch eliminated.
- cyc190 (`0f06df6e`, ubuntu-green) — gc global-init type-check (invalid 57→60).
- gc residual: **return=1 (.17 run InvokeFailed) + trap=4** = the .17 multi-
  mechanism rabbit hole (D-198, deep defer). §10 ROW close also needs realworld/
  p10 (clang_wasm64+clang_musttail autonomous; emcc/dart/ocaml/hoot tool-gated).
- Earlier arc: cyc177 iso-recursive canonicalEqual; cyc147-148 ADR-0125
  packed; cyc146 ADR-0016 M3 self-attribution; cyc130-140 i31/struct/array.
- Runner EXECUTES via interp; gc_heap + gc_type_infos + rt.datas all
  materialised at instantiate. Arrays use 8-byte uniform slots
  (type_info.slot_size); data-seg elements are NATURAL width.
- EH corpus FULLY GREEN 34/34 (ADR-0114 substrate cyc110-120; lesson
  `eh-cross-module-tag-substrate-scope` has the journey).
- Mac+ubuntu green through cyc190 (`OK` exit 0). 10.G-gc + 10.H-multimem
  CLOSED cyc188. Cross-module sharing substrate: D-199 memory + D-201 table/func.

## Active bundle

- **Bundle-ID**: 10.X-xmodule-import-subtype (D-198 .30/.48/.50)
- **Cycles-remaining**: ~1
- **Continuity-memo**: cyc192 (`6a77cb19`) DONE — positive direction:
  `funcTypeImportCompatible` (func subtyping) in `checkImportTypeMatches`
  `.cross_module` arm; .30/.48/.50 instantiate (SignatureMismatch 3→0). Same-
  typespace simplification (M≡importer type defs) → D-202 tracks the distinct-
  layout generalization. Monotonic-safe (eql fast-path). cyc193 = verify the
  negative direction via assert_unlinkable (below).
- **cyc193 NEXT — implement `assert_unlinkable`** to VERIFY + COUNT the negative
  direction. The .30/.48/.50 `module` directives are followed by `skip-impl
  directive-assert_unlinkable` lines (manifest L56-58 etc.) — those test that
  NON-subtype imports are correctly REJECTED, but the runner doesn't implement
  the directive so they're skipped (so cyc192's reject path is unverified by
  corpus, only by the unit test). Mirror cyc184 `assert_uninstantiable`:
  (1) `regen_spec_3_0_assert.sh` — emit `assert_unlinkable <wasm>` (not skip-impl)
  + copy the .wasm; (2) `wasm_3_0_manifest.zig` — add Kind + parseLine;
  (3) runner — compile + instantiate against `cur_linker`, count PASS if
  instantiate fails with a LINK error (ImportTypeMismatch / UnknownImport /
  ImportKindMismatch), not a runtime trap; (4) targeted regen for gc/type-
  subtyping. First step: check whether the unlinkable .wasm fixtures are
  extracted (cyc184 had to add the copy case) — `ls` the dir + read manifest.
- **Exit-condition**: gc/type-subtyping `assert_unlinkable` directives counted +
  passing (verifies cyc192 reject-non-subtype direction); NO regression to all
  5 proposals / gc 349/96/60 / multi-mem 407 / EH 34; 0 panics; exit 0. If the
  unlinkable fixtures aren't extractable (cyc184-style regen gap that balloons),
  close the bundle on cyc192's positive win + D-202, pivot to realworld/p10.

## §10 close map (after this bundle)

Spec-corpus rows (10.G/10.M/10.E/10.TC/10.R) are mature but ROADMAP-`[ ]`;
formal close needs realworld/p10 + 10.P. Residual after the bundle:
- **realworld/p10** (skeleton): clang_wasm64 + clang_musttail AUTONOMOUS
  (clang✓), emscripten/dart/ocaml/hoot TOOL-GATED — next major chunk.
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

## Key refs

- ADR-0114 (EH `*TagInstance`, IMPLEMENTED cyc110–120); ADR-0115/0116/
  0121 (GC heap + type-info); ADR-0120/0123.
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (full EH journey) + `2026-05-29-zig-run-step-cache-stale-diag.md`.
- ROADMAP §10; `.dev/phase_log/phase10.md`.
