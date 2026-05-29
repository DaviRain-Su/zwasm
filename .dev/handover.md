# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cyc195 (`a25dd0a0`) — **non-null-local definite-assignment**
  (D-203 RESOLVED): grow-only `locals_init` bitset (params always-init — key
  fix; declared locals init iff defaultable; reachable-code set/get checks;
  dead-code-skip). func.21 rejected → **`zig build test-all` GREEN** (was
  falsely-green→RED since cyc177). ZERO regression (gc 349/96/60 + all 5
  proposals + wast_runner 1158/1158). **Bundle 10.Y CLOSED.** validator.zig
  cap 3200→3300 (ADR-0099); module-validation helpers = extraction candidate
  → D-204. **Process gap**: Mac per-chunk gate (test+test-spec) never builds
  test-all-only exes — latent breaks surface only via ubuntu test-all.
- cyc194 (`7bfc5d64`) restored wast-runner compile. cyc193 assert_unlinkable
  (5 fail = D-202). cyc192 import subtyping. cyc190 gc global-init. gc residual:
  .17 (D-198) + 5 unlinkable (D-202). All ubuntu-green through cyc190.
- Earlier arc: cyc177 iso-recursive canonicalEqual; cyc147-148 ADR-0125
  packed; cyc146 ADR-0016 M3 self-attribution; cyc130-140 i31/struct/array.
- Runner EXECUTES via interp; gc_heap + gc_type_infos + rt.datas all
  materialised at instantiate. Arrays use 8-byte uniform slots
  (type_info.slot_size); data-seg elements are NATURAL width.
- EH corpus FULLY GREEN 34/34 (ADR-0114 substrate cyc110-120; lesson
  `eh-cross-module-tag-substrate-scope` has the journey).
- Mac+ubuntu green through cyc190 (`OK` exit 0). 10.G-gc + 10.H-multimem
  CLOSED cyc188. Cross-module sharing substrate: D-199 memory + D-201 table/func.

## Active task — cycle 196: realworld/p10 clang fixtures (§10 ROW close) — **NEXT**

test-all is GREEN; the spec corpus is mined to deep/niche tracked edges (.17 =
D-198, 5 unlinkable = D-202). The next forward §10 work = **realworld/p10
fixtures** (§10 ROW 10.G/10.M/10.E/10.TC/10.R close criteria; currently skeleton
dirs, no `.wasm`). Autonomous: `clang_wasm64` (memory64) + `clang_musttail`
(tail-call) — clang✓ (wasm32+wasm64 targets) + wasm-tools✓ in PATH.
**cyc196 Step 0 (read-only survey)**: (1) `test/realworld/p10/README.md` + the
`test/realworld/` harness (build.zig `test-realworld` / `test-realworld-run`
steps) — how a fixture is declared + run via `cli_run.runWasm`; does it pick up
p10 or need wiring? (2) clang → wasm freestanding (`clang --target=wasm32
-nostdlib -Wl,--no-entry -Wl,--export-all`) producing a runnable no-import
module with an exported func — verify a trivial C → `.wasm` → runs in zwasm.
(3) FIRST fixture: clang_musttail (tail-call C `__attribute__((musttail))`) is
likely simplest (wasm64 needs >4GiB host alloc).
**Bar**: land ONE real clang fixture (`.wasm` + provenance + expected) zwasm
runs correctly, wired into a runnable test step; test-all stays GREEN; 0 panics.
If clang can't emit runnable wasm cleanly, debt-track per extended_challenge;
emscripten/dart/ocaml/hoot toolchains stay gated.

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
