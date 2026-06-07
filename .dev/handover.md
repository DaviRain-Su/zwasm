# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## NEVER-IDLE PROTOCOL (read first — user-directed 2026-06-06)

The loop **NEVER idles.** v0.2/v0.3 feature work is UNBLOCKED ("AIが思いのほか早いのでどんどんやろう"). **No
release/tag EVER** (ADR-0156; user reconfirmed "タグは切らない"). **Work priority each resume:**
1. **THE ACTIVE CAMPAIGN below** (Component Model + WASI-P2) — the primary forward track. Drive it via the plan doc.
2. Between chunks OR campaign-gated → sweep `.dev/remaining_sweep.md` / 完成形 polish — never idle.
3. **D-279 DISCHARGED @c287d39c** — Win64 heisenbug root-caused (H7: always-on `d-163-jit` dump floods Win64 stdout →
   abort; decisive A/B @cb90da90), mitigated (dump env-gated off), streak 5/5 over 5 SHAs. Row deleted; trail in lesson
   `2026-06-07-always-on-debug-dump-was-the-heisenbug`. No further action.

## Active campaign — Component Model + WASI Preview 2 (ADR-0170, user-directed 2026-06-07)

**Goal**: full **wasmtime-equivalent** CM + WASI-P2, the zwasm-v2 way (spec/test-referenced NOT copied;
philosophy-maintained; proven by Rust+Go sample components). Decision + rationale: **ADR-0170**.

- **DRIVER = [`.dev/component_model_plan.md`](component_model_plan.md)** — its **§Work sequence** is authoritative
  and SUPERSEDES ROADMAP §17 ordering for this campaign (close-plan-override; Resume routes here, not to a §9 row).
  Follow the first unchecked chunk; each chunk recipe = goal · files · refs · red test · exit.
- **Step 0 survey is DONE** — do NOT re-survey. Read `.dev/component_model_survey.md` (architecture, 4 hard pieces,
  module breakdown) + the plan's "Reference chains" (spec `~/Documents/OSS/WebAssembly/component-model/`; v1
  textbook `~/Documents/MyProducts/zwasm/src/{component,wit,wit_parser,canon_abi}.zig`; wasmtime/wasm-tools refs).
- **Tier 0 (A1–A4) + Tier-1 (B1–B6) COMPLETE — "COMPONENT MODEL WORKS".** decode/types/wit (A1–A4) · canon value
  machinery (B1–B5: flat-scalar/enum/flags/string/list/record/variant over guest memory) · **B6 single-component
  instantiate+invoke e2e** (IT-1 @20132372 instantiate+invoke · IT-2 @41e50658 flat trampoline + Value bridge · IT-3a
  @6e784d5c cabi_realloc-via-guest seam · IT-3b-1 @9024d4bb canon-section decode · IT-3b-2 @cff26592 real fixture decodes
  · **IT-3b-3 @e0e7c9f5 a REAL wasm-tools string→string component RUNS e2e** — `greet("zwasm")`⇒`"Hello, zwasm!"`).
  ADR-0171 (cabi_realloc seam) + ADR-0172 (Zone split). **Bundle CM-B6-IT CLOSED** (exit met @e0e7c9f5).
- **Discipline**: pure logic Zone 1 (`feature/component/`), orchestration Zone 3 (`api/component.zig`); component-value
  DISTINCT from `runtime.Value`; TDD; no-copy; 3-host gate; **no tag**.
- **Phase C COMPLETE (Tier-1 done): resources + multi-component linking.** C1 @11043031 (`resource_table.zig`:
  handles table, own/borrow, new/rep/drop, double-drop/use-after-drop/still-lent traps). **C2 @fc5956dc**: C2-1
  core-instance/alias decode · C2-2 export resolution (D-304 closed) · C2-3a component-instance §5 decode · C2-3b-1
  real 2-component fixture decodes · **C2-3b-2 a 2-component graph LINKS + RUNS** (`instantiateGraph`: wire A's core
  import to B's `adder` via Linker cross-module; `add-five(10)`=15, a real cross-component call). Bundle CM-C2 CLOSED.
  Name-matched-import shortcut + aggregate cross-component args → **D-305**.
- **Phase D (WASI Preview 2) IN PROGRESS** (plan doc §Phase D). **D1-1 @b35a683e** (`src/wasi/adapter.zig`: pure P2→P1
  name-map `classifyImport`/`p1Target`, CLI subset, reuses P1 `fd.zig fdWrite`). **D1-2 fixture @aeb71483**
  (`test/component/wasi_p2_hello.wasm` — real P2 hello-world, imports wasi:cli/stdout+io/streams, prints 'hello' via
  wasmtime; structural decode test green). See the Active bundle below.

## Active bundle

- **Bundle-ID**: CM-D1-2 (run a WASI-P2 hello-world via the adapter)
- **Cycles-remaining**: ~2
- **Continuity-memo**: decode DONE (D1-2a/b). **(b) HOST TRAMPOLINES DONE @2d099ff1** (isolated): host-ctx seam
  `Caller.data` + `Linker.defineFuncCtx` (ADR-0173, extends ADR-0109 §3.2); `api/component.zig` `WasiP2Ctx` +
  `p2{GetStdout,OutStreamWrite,OutStreamDrop}` name-map onto P1 `wasi/fd.zig writeSlice` (extracted from fdWrite; P2
  `list<u8>` is flat ptr/len, not a ciovec). `defineWasiP2Io(lk, "io", ctx)` registers the 3. Proven by a `$M`-shaped
  core module (own memory) printing "hello\n" to a captured fd. **NEXT = (c) RUN the REAL `wasi_p2_hello.wasm`
  decode-driven**: the inner structure (see `.wat`) is — canon-lower `get-stdout`/`write`(memory $libc)/resource.drop
  `drop-os`; core module `$libc` (exports memory) + its instance; core module `$M` (imports `io.{get-stdout,write,
  drop-os}` + `libc.memory`, exports `run`); core instance `$deps-io` (re-exports the 3 lowered funcs); core instance
  `$m` = instantiate $M with io=$deps-io + libc=$libc; canon-lift run → RunShim subcomponent → export `wasi:cli/run`.
  SURVEY DONE: `ctypes.TypeInfo` exposes `core_instances` (`.instantiate{module,args:[{name,instance}]}` /
  `.inline_exports:[{name,sort,index}]`), `canons` (`.lower{func,opts}` / `.lift{core_func,opts,type_index}` /
  `.resource_drop`), `aliases` (`.core_export{instance,name}` / `.outer`). Core modules = the Nth `.core_module`
  section. **FIRST SUB-CHUNK = fix the core-func index-space model**: `types.zig resolveCoreFuncExport` (line ~359)
  walks ONLY core-func aliases, so for `wasi_p2_hello` (core funcs [0=lower get-stdout, 1=lower write,
  2=resource.drop, 3=alias $m.run]) index 3 mis-resolves. Build a unified walk assigning core-func indices in
  definition order across {canon lower, canon resource.{new,drop,rep}-that-mint-core-funcs, core-func aliases} →
  map idx → {lowered-component-func J | resource-builtin | core-export alias}. THEN `runWasiP2Main` in
  `api/component.zig`: from the `canon lift run` → its core_func alias → core_export{$m,"run"}; $m =
  core_instances[..].instantiate{module=$M, args=[io→$deps-io, libc→$libc]}; instantiate $libc (no-arg) → memory;
  instantiate $M via a Linker wiring `io.*` (resolve $deps-io inline_exports → canon-lower idx → map the lowered
  component-import name via `adapter.classifyImport` → `defineWasiP2Io` trampoline) + `libc.memory` → $libc memory
  (`defineMemoryInstance`, cross-instance like C2); invoke run; assert `host.stdout_buffer` == "hello\n".
- **Exit-condition**: `wasi_p2_hello.wasm` runs via `api/component.zig` and writes "hello" to the captured stdout.

## Current state

- **Phase 17 (v0.2) IN-PROGRESS** (ADR-0168). DONE+3-host: atomics @9eb84833 · wide-arith @231d4536 ·
  custom-page-sizes @cd0de2dd · relaxed-SIMD @08342ec5 (+official corpus @8ef2e752, 13420 pass arm64+x86). Wasm-3.0
  core 100%-spec COMPLETE. Last SHA **c287d39c** (CM-D1-2 trampolines @2d099ff1 + D-279 discharge).
- **Atomics fully conformant @e6f3b0c0** — official corpus **294 pass, 0 SKIPPED** (D-301), incl. the JIT
  unaligned-atomic-trap fix D-303 (code-14 `unaligned_atomic_fixups` both arches, @5b0db8e1, 3-host).
- **ALL bounded debt CLEARED**: ✅ D-301 · ✅ D-303 · ✅ D-231 (cross-x86 DCE gate wired @aac4fe2f) · ✅ D-302
  (branch-hint custom-section verified @dcc8d71c) · ✅ **D-279 DISCHARGED @c287d39c**.
- Debt ledger **52 entries**. `now` = D-299 only (env-constrained). **Correctly DEFERRED (do NOT clear)**: D-209
  (hot-path), D-259 (W54-ABI-risk), D-300 stack-switching (Phase-3 unstable), D-299 (x86_64 W^X).
- 完成形 v0.1 surface COMPLETE: CLI D-295 (~85%, intentionally lean) · C-API ZERO gaps (293/293) · Zig-API
  COMPLETE · memory-safety all-areas SOUND (D-296/D-297). Dogfooding D-264 DONE (cw v1 side).

**Blocked / parked**: 31 blocked-by (call_ref §10.R / D-177 / D-178 / future proposals). **D-290** = 3 distillers
direction-gated. 

## Step 0.7 (next resume) — verify remote logs

- **ubuntu**: re-kicked each turn (D6). Verify `[run_remote_ubuntu] OK`. Last GREEN @9f5ce2db. Red → auto-revert
  (D3; first-resume + non-code-gap exceptions).
- **windows**: BATCHED (D8). Last GREEN @9f5ce2db; next batch ≥12 / ABI-risk. A Win64 exit-3 WITHOUT the dump would
  re-open D-279 (not expected). NOT auto-revert (D7).
- **Gate note**: `OK` = green. EXPECTED non-failures: `zig-host-hello` exit-42, `--__selftest-crash` exit-70,
  sha256 `verify: FAIL` (fixture-wrong-constant FALSE lead).

## Key refs

- **ADR-0170** (CM full campaign) + [`component_model_plan.md`](component_model_plan.md) +
  [`component_model_survey.md`](component_model_survey.md) — the active campaign.
- **ADR-0156** (no release) · **ADR-0076** (3-host cadence) · **ADR-0168** (Phase 17) · **ADR-0023** (subsystem
  slots) · `no_copy_from_v1` · `single_slot_dual_meaning` · `.dev/proposal_watch.md`.
