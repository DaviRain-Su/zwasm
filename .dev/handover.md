# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state — Phase 17 完成形 plateau; v2.0.0-alpha.3 TAGGED @fc7ff0b3b; plateau GENUINELY CLEAN

**Mode: overnight autonomous niche-debt discharge** (user 2026-06-23: "逐次修正、取り組めるところを；枯渇しても判断して進める").
`.auto`→JIT flip DONE + 3-host green; tag `v2.0.0-alpha.3` @fc7ff0b3b (tag-only, Latest stays v1.11.0); cljw pins it.
No active campaign/bundle.

**This session closed ALL named niche JIT gaps** (latest @aa00e0efd):
- **D-498 @ab996afc0** — JIT C-API funcref param+result marshalling (`invokeRefIdx` 1/2-param ref-result arms). Deleted.
- **D-497 @11d70d69f, 3-host GREEN** — JIT funcref-table grow (ADR-0201): setup pre-allocs funcptr/typeidx mirrors to
  growCapacity; jitTableGrowGuest (resolve *FuncEntity) vs jitTableGrowHost (fail-safe clear); arm64 X25 reload after
  table-0 grow; `wasm_table_grow` C-API JIT arm. Deleted.
- **D-499 @cd0a75e96 RATIFIED interp-only** (note) — targeted fix intractable (always-R15 regresses Win64 buffer-write;
  trap stub structurally needs R15); runaway-safety intact both arches; 3 facade tests `.interp`-pinned.
- **D-500 RESOLVED** (note) — component CM-API `.interp` is RATIFIED ARCHITECTURE (ADR-0172: cross-instance aliasing is
  Zone-2, component-on-JIT precluded), NOT a workaround; residual general Win64 `wrapper_thunk` ≥2-arg/3-result gap → D-477 sliver(4).
- **D-477 sliver(3) @083affd47 RESOLVED+tested** — mixed (i32,f64)→f64 JIT export works via the 2-arg buffer-thunk
  fall-through (regression guard added). **SIMD-spill dedup @df3fa42d7** (xmmDefSpilledV128→delegates).

**NEXT — ACTIVE BUNDLE (below): D-477 v128 host-invoke** (Phase 16 是 indefinite 完成形/debt-repayment; the
"build-on-demand" tag was phase-relative to the now-done API phase, not permanent). Builds JIT host-invoke ABI
completeness for v128 args/results + unblocks the SIMD-vs-wasmtime differential oracle (currently blocked, lesson
2026-06-20). No `now`-class debt; this is the chosen completeness front.
**Fuzz sweeps CLEAN** (2026-06-23 @7af222e9a): loader campaign `2008 processed, 1777 compiled (1266 interp + 1665 JIT),
231 rejected, 0 crashes`; exec-differential (interp-vs-JIT, D-469) seed `9/9 funcs, 0 mismatched`. Robustness +
JIT-correctness reconfirmed. NOTE: exec-diff over the RAW SMITH campaign corpus reports `0 funcs compared` (smith
exports no 0-param/scalar-result funcs — KNOWN limitation, lesson 2026-06-20) → don't re-run exec-diff on raw smith;
the curated `exec_seed` is its real coverage. Re-run loader: `nix develop .#gen --command bash scripts/gen_fuzz_corpus.sh campaign && zig build fuzz-campaign`.

## Active bundle

- **Bundle-ID**: D-477-v128-host-invoke
- **Cycles-remaining**: ~4 (argByteOffsets helper + arm64 emit + SysV emit + Win64-by-ref + CLI v128 literal; arm64+SysV first, Win64-by-ref tail)
- **Continuity-memo**: model A = v128 is 2 consecutive 16-aligned u64 slots in the existing `[*]u64` buffer (NOT a sig
  widen — keeps scalar 8·k byte tests intact; slot size only governs cursor STRIDE + 16-align pad before each v128).
  A SHARED `argByteOffsets(sig)` helper (cumulative, 16-align-before-v128) MUST drive BOTH the thunk loads AND the runner
  packing identically. Per-arch param emit: arm64 `LDR Q V{fp},[X2,#16k]`; SysV `MOVUPS XMM{fp},[RDX+off]`; Win64 GOTCHA
  = v128 passed BY REFERENCE (LEA ptr-to-slot into the GPR arg slot, body does its own MOVUPS). Result always V0/XMM0 →
  STR Q / MOVUPS. Full recipe: `private/notes/d477-remaining-slices-design.md` Slice 3. Survey agent ae0522a8 mapping
  current file:line + smallest-first red chunk.
- **Plan (survey ae0522a8, concrete)**: chunk1 = **`()->v128` result-only, arm64** — (a) `TypedResult` gains a `.v128`
  variant + `invokeMultiIdx` result-unpack arm (runner.zig ~1452, currently no `.v128`); (b) wrapper_thunk emitArm64
  v128-result arm (`n_params==0, n_results==1, results[0]==.v128`): `LDR Q V0,[X2/results]; STR Q V0,[X1]` via existing
  `encLdrQImm`/`encStrQImm`; (c) red test asserting an `i32x4(42,42,42,42)` const-result invoke round-trips. v128 gate
  at wrapper_thunk.zig:185-187/696-699 (`contains_v128`→UnsupportedOp). chunk2 = v128 PARAMS + shared `argByteOffsets`
  (16-stride) + SysV thunk (MOVUPS, Rosetta-verify); chunk3 = Win64-by-ref (windowsmini); chunk4 = CLI v128 literal +
  wire SIMD differential. NOTE: direct-entry `callV128_*` already work (entry.zig:1819+); the gap is the THUNK path only.
- **Exit-condition**: a v128 host-invoke (v128 arg + v128 result) round-trips byte-correct on arm64 + ubuntu x86_64
  (Mac+ubuntu green); then the JIT-SIMD-vs-wasmtime differential can invoke v128-signature exports (no longer blocked).

## Operational invariants (keep using)

- **Win64 fast-repro** (~2min): cross-build `zig build test -Dtarget=x86_64-windows-gnu` on Mac (run-step "fails" but
  test.exe builds) → `scp` to windowsmini → ssh-run from the repo dir (cwd matters for file-fixture tests).
- **Mac `zig build test` is INSUFFICIENT for flip/ABI-class changes** — ubuntu-gate mandatory; arm64 masks x86_64 bugs.
  Rosetta `-Dtarget=x86_64-macos` REPRODUCES x86_64-linux JIT bugs. JIT-codegen fix → verify arm64 AND x86_64-macos.
- **Step-0.7 NOTE**: `failed command: …--listen=-` / host-example exe lines are COSMETIC (exit 0); trust
  `[run_remote_*] OK/FAIL` + `N passed, 0 failed`.

## Parked / gated — do NOT speculatively grind (see debt.yaml)

- **D-477 slivers** (partial, build-on-demand, no DIRECT consumer): (1) v128 args/results invoke (Win64-by-ref gotcha;
  would unblock the SIMD differential oracle — but indirect + itself otherwise-blocked); (2) Win64 ≥4-param stack-spill;
  (4) Win64 ≥2-arg/3-result MEMORY-class thunk (folded from D-500). Full recipe: `private/notes/d477-remaining-slices-design.md`
  + debt D-477. **RE-EXAMINED 2026-06-23 — design note + debt BOTH classify these "build-on-demand NICHE"; do NOT
  re-investigate or speculatively build.** Trigger = a real consumer (e.g. SIMD-differential productization, a v128/Win64
  host-invoke need). SIMD correctness already covered (simd_assert 25075/0 + fuzz-loader 1665 JIT-compiled clean).
- **validator.zig at 3449/3450 cap** — NEXT validator edit MUST extract per the file's marker plan first.
- D-305 long-tail (niche CM shapes; `component_graph.zig` 1895/2000 split first); D-464 async adversarial; D-475
  table64-JIT (perf, Win64-risk); D-462 feature-separation (user-gated). 22 `blocked-by` = future-bucket/parked.

## State (release = USER-ONLY, ADR-0156 — the loop NEVER tags/publishes)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip. **WASI 0.1** complete; **0.2/CM** default-ON; **0.3 core** done. Sandbox triad.
- **Surfaces**: C-API · Zig-API (full WASI parity) · lean CLI · memory-safety sound · dogfooded into cw. Runners ReleaseSafe.
- **EH**: cross-instance JIT EH both arches. Interp+JIT EH corpus green. Realworld 56 fixtures interp 56/0; JIT diff-gated.
- **Debt**: 67 entries — **ZERO `now`-class** (22 blocked-by, 42 note, 3 partial). 完成形 plateau (all dims confirmed,
  surface audits clean 2026-06-18, interp+JIT fuzz 0-crash, v1-JIT parity D-265 closed).

## Key refs

- [`flake.nix`](../flake.nix) `devShells.gen` / `.#gen-wasip3`. [`docs/zig_api_design.md`](../docs/zig_api_design.md).
- ADRs: **0156** (NO autonomous release) · **0153** (rework) · **0201** (funcref-table grow) · **0172** (components=interp) ·
  **0099** (file-size caps) · **0126** (iso-recursive equality). lessons INDEX: `.dev/lessons/INDEX.md` (Step 0.4 keyword index).
