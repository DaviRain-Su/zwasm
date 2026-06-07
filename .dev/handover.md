# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## ⚑ windowsmini-hardening campaign — DONE; gating SUSPENDED (ADR-0174, 2026-06-07)

**win-harden-I bundle CLOSED @9d832f1d.** The `pass=0` anomaly did NOT reproduce: fresh windows `test-all` @f8bcc040
showed real pass counts IDENTICAL to ubuntu (simd 13420, non_simd 25437+294, 1.0 212; 0 `SKIP-START-TRAP`). Root cause =
a **transient windowsmini corpus state** (@87635409→@f8bcc040 is doc-only), masked by a silent "0 manifests" exit-0 in
the simd/non_simd/wasm_3_0 runners. **Fix (3-host green @9d832f1d)**: those runners now `exit(1)` on a missing corpus
root; build.zig `test-corpus-presence` (3 neg-runs, expectExitCode 1) wired into test-all = the v1 "no naive windows
skip" lesson made a gate. Findings: [`windows_hardening_findings.md`](windows_hardening_findings.md); lesson
`2026-06-07-windows-spec-pass0-was-transient-corpus`.

**Gating now SUSPENDED** — `.dev/windows_gate_suspended` = `9d832f1d` ⇒ inner loop is **2-host (Mac+ubuntu) FAST**.
`should_gate_windows.sh --resume` before any `main` merge / Win64-risk diff (ABI/calling-convention/frame-layout) / on
user request. A13 strict-3-host merge gate (`gate_merge.sh`) UNCHANGED. **Now resume the CM+WASI-P2 campaign below
(Phase D3/E).** Loop NEVER idles; **No release/tag EVER** (ADR-0156).

## ✅ E2 bundle CLOSED — a REAL Rust wasm32-wasip2 component RUNS via zwasm (@96e1ccce)

The campaign headline: a genuine `rustc --target wasm32-wasip2` component (NOT hand-authored; wit-bindgen
shim/fixup-table indirection, full wasi:cli world) prints "hello from a real rust wasip2 component" e2e + exit 0.
Delivered: **ADR-0175** general instance-graph engine @8eab1703 · **D-310** runtime fix @4e802881 (imported host
funcs funcref-able: per-import placeholder sig + call_indirect→host_calls) + component memory fix @96e1ccce
(trampolines use `WasiP2Ctx.mem_instance`, not the memory-less shim caller) · core-table decode @73df8a7e ·
cli/environment+terminal+check-write @0888a3f9. Fixture `test/component/wasi_p2_hello_rust.wasm` (78 KB) + e2e + dogfood.

**E1 DONE** (plan §Phase E): `test/spec/component_model_assert_runner.zig` — a Component-Model spec corpus runner
that decodes+instantiates+invokes over `test/spec/component-model-assert/`, built against a component-ENABLED
`zwasm` module (`core_comp` in build.zig), wired into `test-all`. First corpus = greet (string→string) + adder graph
(cross-module i32): 4 pass, 0 skip. ADR-0174 lesson: missing corpus root = hard `exit(1)`. Fixtures reuse `test/component/`.

**NEXT = E3** (plan §Phase E, the next `[ ]`): WASI-P2 conformance + edge cases — AND grow the E1 corpus.
**Survey finding (@279b7fb3)**: `~/Documents/OSS/WebAssembly/component-model/test/wasm-tools/*.wast` = **365
`assert_invalid` + 17 `assert_malformed`, ZERO invoke tests** — negative decode/VALIDATE tests. Our `decode.zig` is
decode-only (no component validation), so most would FALSELY pass → honest ingestion needs **component-validation
depth (ADR-grade: how much §-by-§ component validation to implement) + a `.wast`→corpus distill script + `assert_invalid`/
`assert_malformed` runner directives**. That makes E3 a multi-cycle BUNDLE, not a quick chain — open it with a Step 0
survey + an ADR on validation scope. Positive-decode fixtures (bare `(component …)` forms) are the cheaper first slice.
E2 remainder (Go/tinygo cross-toolchain proof + io/error trampoline) is opportunistic —
toolchain-gated (wit-bindgen-go not in the gen shell), do it when convenient, not the blocker.
**Resume routing**: handover §Active campaign DRIVER → `component_model_plan.md` §Work sequence (close-plan-override);
ROADMAP §17 row also redirects there. Follow the plan's first `[ ]` (= E3). `/continue` alone resumes correctly.

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
- **Phase D (WASI Preview 2) — D1+D2+D3 DONE** (detail in plan §Phase D). D1 core @96edb868 (`runWasiP2Main`
  decode-drives the inner core graph; `wasi_p2_hello.wasm` prints "hello") + CLI run path @161236db (`zwasm run`
  dogfooded) + ADR-0173 (host-ctx seam). D2 @85bcb5a5 — resource-modeled fs (descriptor RT, get-directories list via
  reentrant cabi_realloc, open-at/write); classified-by-interface wiring D-306.
- **Phase D3 DONE** (hand-authored-fixture native host; detail in plan §Phase D3). D3-1 exit · D3-2/3 clocks · D3-4
  random · D3-5 stdin · **D3-6 fs descriptor** @43909eba (read/sync/stat/get-type + flush; **D-307 DISCHARGED**
  @beb887c6) · **D3-7 wasi:io/poll** @3a128a01 (pollable + subscribe + ready/block/poll). **D-309 DONE** @ccdee2fa —
  WASI-P2 trampolines extracted to `api/component_wasi_p2.zig` (component.zig 1922→1250).
- **NOW = E3** (conformance + corpus growth; E1 runner DONE). Deferred: D3-8 sockets (spike-first).
  Cross-component aggregate → D-305. **D-308**: runWasiP2Main error-cleanup SEGVs on a failed-import wire (error path).

## Current state

- **Phase 17 (v0.2) IN-PROGRESS** (ADR-0168). DONE+3-host: atomics @9eb84833 · wide-arith @231d4536 ·
  custom-page-sizes @cd0de2dd · relaxed-SIMD @08342ec5 (+official corpus @8ef2e752, 13420 pass arm64+x86). Wasm-3.0
  core 100%-spec COMPLETE. Last SHA **3660a85b** (E2 done + edge-fixture gate enforcement; ubuntu OK; windows susp @9d832f1d).
- **Atomics fully conformant @e6f3b0c0** — official corpus **294 pass, 0 SKIPPED** (D-301), incl. the JIT
  unaligned-atomic-trap fix D-303 (code-14 `unaligned_atomic_fixups` both arches, @5b0db8e1, 3-host).
- **ALL bounded debt CLEARED**: ✅ D-301 · ✅ D-303 · ✅ D-231 (cross-x86 DCE gate wired @aac4fe2f) · ✅ D-302
  (branch-hint custom-section verified @dcc8d71c) · ✅ **D-279 DISCHARGED @c287d39c**.
- Debt ledger **53 entries** (D-307/D-309/D-310 discharged). `now` = D-299 only
  (env-constrained). **Correctly DEFERRED (do NOT clear)**: D-209
  (hot-path), D-259 (W54-ABI-risk), D-300 stack-switching (Phase-3 unstable), D-299 (x86_64 W^X).
- 完成形 v0.1 surface COMPLETE: CLI D-295 (~85%, intentionally lean) · C-API ZERO gaps (293/293) · Zig-API
  COMPLETE · memory-safety all-areas SOUND (D-296/D-297). Dogfooding D-264 DONE (cw v1 side).

**Blocked / parked**: 31 blocked-by (call_ref §10.R / D-177 / D-178 / future proposals). **D-290** = 3 distillers
direction-gated. 

## Step 0.7 (next resume) — hosts were SHUT DOWN; first windows run = the campaign

- **All 3 hosts powered off** after @87635409 (user). `/tmp/ubuntu.log` last verdict was OK @87635409;
  `/tmp/win.log` shows the **pass=0 spec-assert anomaly** (see NEW DIRECTIVE #1 — the campaign's first lead). On a
  fresh boot, `/tmp/*.log` are stale — re-kick both as the first campaign step; the windows run IS the investigation.
- **ubuntu**: re-kicked each turn (D6). Red → auto-revert (D3; first-resume exception). **windows**: NOT auto-revert
  (D7); the campaign is actively hunting Win64 bugs, so a red windows is the SIGNAL, not a flake-to-dismiss.
- **Gate note**: realworld `OK` can MASK a broken spec-assert phase (the pass=0 anomaly). EXPECTED non-failures:
  `zig-host-hello` exit-42, `--__selftest-crash` exit-70, sha256 `verify: FAIL` (fixture-wrong-constant FALSE lead).

## Key refs

- **ADR-0170** (CM full campaign) + [`component_model_plan.md`](component_model_plan.md) +
  [`component_model_survey.md`](component_model_survey.md) — the active campaign.
- **ADR-0174** (windowsmini hardening → gate suspension; switch = `scripts/should_gate_windows.sh --suspend|--resume`,
  sentinel `.dev/windows_gate_suspended`) · **ADR-0156** (no release) · **ADR-0076** (3-host cadence) · **ADR-0168**
  (Phase 17) · **ADR-0023** (subsystem slots) · `no_copy_from_v1` · `single_slot_dual_meaning` · `.dev/proposal_watch.md`.
