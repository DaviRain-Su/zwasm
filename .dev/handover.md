# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24).
- **HEAD**: cycle 111 (`<this commit>`) — **CORRECTION**: cycle-110's
  "try_table.1/.5 → INSTANTIATE" claim was FALSE. Direct-binary run of
  the wasm-3.0-assert runner shows try_table.1/.5 STILL
  `compile FAIL: ParseFailed`; the 34 EH return-fails are 33×NO-CURINST
  (try_table.1 never parses) + 1×InvokeFailed (imported-mismatch under
  try_table.2, which DOES instantiate). The EH blocker is **parse-side,
  not execution-side**. The false claim was a stale `zig build`
  run-step-cache + lossy-stderr artifact (new lesson
  `2026-05-29-zig-run-step-cache-stale-diag.md`).
- Prior: 110 EH step-1 ImportKind.tag (`447c1048`; correct but
  currently UNREACHABLE — Type section fails before Import section);
  108 ref.func global-init → funcrefs return 24→32; 100-107 funcrefs.
- Mac test+lint green at cycle 110 (`e71677c8`). ubuntu: cycle-110 HEAD
  green (`OK (HEAD=e71677c8)`). Cycle 111 = docs-only correction.

## Active bundle

- **Bundle-ID**: 10.E-xmodule-tags (EH cross-module, ADR-0114)
- **Cycles-remaining**: ~6 (parse-side chain re-sequenced ahead of
  execution-side)
- **Continuity-memo**: try_table.1 PARSE blockers, in section-decode
  order (earliest wins; Type=1 first): **(1) bare exnref `0x69` as a
  ValType** — its Type section has functype results `(i32, exnref)`
  = `7f 69`; `parse/init_expr.zig:readValType` has `0x7F..0x6A` +
  typed-ref `0x63/0x64` but NO bare `0x69` (`zir.zig:40` "not yet a
  ValType"). **(2) module Tag section (id 13)** — defines 7 tags
  (`0d 0f 07 …`), distinct from the tag IMPORT. (3) ImportKind.tag —
  DONE cyc110, reached only after 1+2. Then execution-side: instantiate
  tag binding → `*TagInstance` (ADR-0114) → pointer-identity
  throw/catch → JIT. Full chain + correction in
  `lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`.
  **VERIFY runner deltas by running the BINARY DIRECTLY** (zig-build
  stderr is cache/lossy — see the cache lesson).
- **Exit-condition**: exception-handling try_table corpus return pass
  ≥ 5/34 (currently 0/34).

## Active task — cycle 112: `ValType.exnref` + readValType 0x69 arm

Smallest red test: `parse/init_expr.zig` `readValType` accepts bare
`0x69` → `ValType.exnref`; assert a functype `(result i32 exnref)`
(`60 00 02 7f 69`) decodes. Then add `exnref` to the `ValType`
enum/union and walk the exhaustive-switch cascade (à la cycle-110
`ImportKind.tag`: `zig build` → fix arm → repeat). Observable: rerun
the runner BINARY DIRECTLY; try_table.1's Type-section ParseFail should
move past section 1 (toward the Tag-section blocker, cycle 113).
Watch ADR scope: `ValType` is a §4 ZirOp-adjacent type — adding a
variant is allowed under ADR-0120 (EH payload, Accepted) + the
zir.zig:40 plan; no new ADR (it's the planned exnref landing). If the
cascade surfaces a design fork (e.g. exnref in the GC subtype lattice),
file an ADR first.

## Larger §10 work (later bundles)

- **10.E EH execution** (post-parse) — `*TagInstance` identity match +
  JIT throw/throw_ref emit (`arm64/emit.zig:1172`).
- **10.G WasmGC** — corpus baked impl=0%; ZIR ops + heap + subtype
  lattice (refines `valTypeIsSubtypeFree`'s pre-GC assumption). Many
  gc/* still `compile FAIL: ParseFailed` (shares exnref/ref decode).
- **Deferred funcrefs gaps** (post-EH): engine/cli_run
  `resolveFuncrefGlobals` unwired; externref-elem runner arg parsing.
- **10.P close gate** — user touchpoint by construction.

## Spec runner observable (cycle-111, verified by DIRECT binary run)

```
[memory64           ] return=337 trap=205 invalid=83  (all pass)
[tail-call          ] return=71  trap=7   invalid=24  (all pass)
[exception-handling ] return=34(fail34) trap=2(fail2) invalid=7(pass) exception=4(fail4)
   └─ try_table.0+.2 INSTANTIATE; try_table.1+.5 compile FAIL:ParseFailed
      → 33 asserts NO-CURINST + 1 InvokeFailed (imported-mismatch).
[function-references] return=39(pass=32 fail=1) trap=4(pass) invalid=18(pass) ParseFailed=0
[gc                 ] return=407(fail) trap=100(fail) invalid=60(pass=55 fail=5)
[multi-memory       ] return=407(pass=387 fail=20) trap=238(pass=237 fail=1)
```

## Open questions / blockers

- ADR-0120 / ADR-0123: Accepted; impl autonomous.
- D-192: funcrefs clause PROVEN. EH clause = bundle 10.E (now
  parse-side first: exnref ValType → Tag section → instantiate → exec).

## Key refs

- ADR-0114 (EH design — `*TagInstance`); ADR-0120 (EH payload);
  ADR-0123 (typed-ref).
- `.dev/lessons/2026-05-29-eh-cross-module-tag-substrate-scope.md`
  (corrected blocker chain) + `2026-05-29-zig-run-step-cache-stale-diag.md`
  (direct-binary-run discipline).
- ROADMAP §10; `.dev/phase_log/phase10.md`.
