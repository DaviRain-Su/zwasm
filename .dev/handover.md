# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state — Phase 17 完成形 completion-refinement (release = USER-ONLY, ADR-0156)

Recent closed arcs (3-host or ubuntu-verified; full detail in git/lessons): **D-457** SIMD systemic close (24805/0) ·
**D-458** core-2.0 corpus completeness + cross-corpus audit · doc-inventory pass · **C-ABI trap-kind drift guard** ·
**D-455** array-alloc dedup · **D-459** Wasm 3.0 §3.3.1 local definite-assignment (restore-at-end NOT intersection) ·
**win-specassert-pass0 (ADR-0174 Phase-1) CLOSED**: windowsmini wasm-3.0-assert pass=0 root-caused to CRLF — the
runner was the lone one not trimming `\r`, so windows-CRLF manifests gave `module_path` ending `\r` →
`error.BadPathName` → all modules silently un-loaded. Fixed @02592aa8 (trim, mirrors 4 other runners) → **windows
now pass=10234 = ubuntu, 0 MODULE-READ-FAIL, VERIFIED**; + @b1606384 gates the runner on fails (closes the
"OK-hides-pass=0" masking; lesson `windows-crlf-manifest-badpathname-hidden-by-nongating-skeleton`). D-458 RESIDUAL
(note): broad regen non-idempotency. Ratchet baseline 24 loose (real 22) — harmless. Stale-doc: ROADMAP §16.7 D-277.

CLI surface audit (@4e5e42fe): code↔`--help` fully consistent. Gate change @b1606384 **VERIFIED GREEN on BOTH hosts**
(windows `[run_remote_windows] OK.` wasm-3.0-assert pass=10234 fail=0 / simd 24805/0 / spec 25539/0; ubuntu OK
@f1a1d503). win-specassert campaign fully closed; the fail-gate is clean.

**NEXT (autonomous)**: **ADR-0193 feature-separation migration CLOSED** (P1-P4, D-462) — one ordered `-Dwasi`
axis (default p2), `-Dcomponent` removed, p3/async comptime-fenced (`test-wasi-p3` + DCE), docs synced (WASI D+→B,
component D→B; default `p2→p3` flip tracked under D-335). Now driving the **D-461 rework campaign** (see below).
Then `D-209` memory64. **windowsmini gating RESUMED**. Version → `2.0.0-alpha.3`.

## D-461 regalloc-origin rework (ADR-0153/ADR-0194) — CLOSED Phase I-V 2026-06-16

- **CLOSED**: the x86_64 regalloc v128-spill OOB (`regalloc.zig:222`) is FIXED. Root was THREE inconsistent
  spill-frame origins (mint `max(gpr,fp)` / `spill_offsets` sizing hardcoded-8 / `slot()` resolve patched-pool).
  **Fix (ADR-0194)**: thread the per-arch `max_reg_slots_gpr` into `computeWith`→`computeSpillOffsets` so the array
  is sized+indexed from the same origin `slot()` resolves with, set at BUILD time (dropped compile.zig's GPR
  post-patch). Phases: I (`ccf49f4c` instrumented dump), II (`c4c1d567` characterization + the zero-coverage
  spill_offsets resolve path), III (`6500a611` ADR-0194 design), IV (`3cd2ede6` impl). **Verified**: arm64
  byte-identical 2922 green; x86_64-Rosetta rc=0, OOB gone; lesson `x86_64-regalloc-fp-spill-origin-mismatch`.
- **Phase V retrospective**: hit the 完成形 (one coherent origin, no arch-tuned-default trap); rejected the
  class-aware-mint over-reach + the array-elimination (scalars still pack 8-byte). New debt = none beyond the
  pre-existing D-461 continuation below.

## D-461 SIMD v128-spill — high-value DONE (3-host green); result-write remainder = tracked debt (exotic)

**DONE both arches, 3-host green**: regalloc-origin rework (ADR-0194, Win64-verified @8f4f88c5) + all 6
extract_lane + all 4 bitmask widths. Concrete D-460 blocker CLEARED. **Result-write remainder is now TRACKED DEBT
(D-461)**, not active: Extend/Extadd/replace_lane/binop-dsts — arm64 unops ALREADY spill-aware (shared
`emitV128Unop`), so it's **x86_64-only** but needs `spill_base_off` threaded through ~26 sig sites per category +
per-op scratch-XMM audit (LANDMINE). EXOTIC (high-v128-pressure only). Full per-op scope + the reusable fixture
recipe (`.wat` → `wasm-tools parse`, build the or-chain programmatically) are in the D-461 debt row. Re-open as a
focused bundle if a real program needs it.

## Active bundle — D-335 typed stream/future element marshalling (Unit E first slice)

- **Bundle-ID**: D-335-typed-marshalling
- **Cycles-remaining**: ~2-3
- **Continuity-memo**: (Step-0 survey DONE this cycle) stream<T>/future<T> copy currently assumes **u8 / count==bytes**.
  The byte-copy sites are `component_wasi_p2.zig:1795` (host sink write), `:1814` (host source read), `:1809`
  (pending-read park), `:231` (deliverParkedReads) — all `mem.sliceAt(ptr, count)` = count BYTES. The Zone-1
  rendezvous (`async.zig:517 SharedStream.read/write`) is element-agnostic (count only; host moves bytes) → NO change
  there. **elem_type IS threaded** (`StreamFutureEnd.elem_type`, `SharedStream.elem_type` — async.zig:147/483/552)
  from mint (`p2StreamNew` :1677 passes `abc.type_index`) but NEVER read at copy. `canon.sizeOf(CanonType)→{1,2,4,8}`
  exists (canon.zig:186). **PLAN**: resolve `elem_size = canon.sizeOf(T)` where `stream<T>` is canon-decoded (find
  the StreamFutureOp.type_index decode site — the type table is available there) → store `elem_size: u32` (default 1)
  on StreamFutureOp → thread through AsyncBuiltinCtx → StreamFutureEnd/SharedStream → the 4 copy sites multiply
  `count * elem_size`. **RISK**: confirm the type table is reachable at the decode site (if only the index survives to
  the copy, store the resolved size at mint instead). **TEST**: author `test/component/async_*stream_u32*.wat` (mirror
  the u8 stdout-via-stream fixture; write N u32s → host sees N*4 bytes); `wasm-tools parse` + a bespoke
  `component_wasi_p3.zig` test (the existing async-fixture test pattern).
- **Exit-condition**: a `stream<u32>` (or `future<u32>`) e2e test passes with N*4-byte host transfer; u8 streams
  unchanged (existing 158/0/0 component + async corpora green).

Other D-335 remainders (guest↔guest stream byte-buffering, sockets/http async = big Unit E) + `D-209` memory64 are
the fronts after this bundle. D-461 result-write = tracked debt (above).

## Closed/paused (detail in git + debt.yaml)

- **doc-inventory freshening DONE** (`42441634` README + ADR-0193 P4 doc-sync): reader-facing surfaces clean
  (C-API 293/293, component 158/0/0, Wasm 2.0 skip-impl==0, 3.0 all-9-proposals, version anchors retired).
- **ADR-0192 wasmtime differential campaign — paused**: goal met (9 real engine bugs fixed via wasmtime
  misc_testsuite + 6 SIMD via D-457). Residuals: **`D-460`** v128-GC (arm64 struct/array get/set EMIT DONE
  `f79a3ced`/`41015a9b`; array.new_fixed/copy + x86_64 mirror unblocked NOW by the D-461 spill fixes in progress),
  **`D-209`** memory64 >4 GiB offset, **D-456** host-import fixtures (parked). Harness `scripts/wasmtime_misc_*.sh`.

**Closed campaigns (detail in git/lessons)**: prior 4-front async-maturity (2026-06-16) — ② wasmtime async .wast
TIER-1 (`afcf889a`/`05b35c28`; D-446/447 deferred), ① wasip3 conformance (7 real-rust fixtures, `.#gen-wasip3`),
④ perf (ROI-rejected single-pass ceiling, D-450), ③ real-world GC corpus (6 engine bugs FIXED: D-451-453/9064faa5/
480809af/9ec68a75/79742cb4; 4 GC edge fixtures; real Hoot execution → D-454). **WASI 0.3/Preview-3 core DONE**
(D-335; ADR-0187-0191). validator.zig at 3449/3450 cap — NEXT validator edit MUST extract per the file's marker plan.

## Long-tail (debt-tracked / parked — NOT active; see debt.yaml)

- **JIT-correctness** (front B / parked): D-330 c_sha256 `\n` (parked — conflicting-constraint; do NOT re-run the
  blanket fix) · D-331(A) go runtime-corruption (infra-blocked) · D-331(B)/D-289 go_regex emit (parked) · D-333
  (br_table, folds into D-330). Realworld corpus interp-green; JIT run-stage opt-in (`ZWASM_JIT_RUN=1`). Trace:
  `ZWASM_DEBUG=jit.dump` + `scripts/jit_value_trace.sh` (Recipe 18).
- **D-454** (future-bucket): real GC-language program execution fixture, blocked on Hoot reflect-ABI host port.

## State (all 3-host green @046d9c67/win @886d0667; release = USER-ONLY, ADR-0156)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip (GC 362/0). **WASI 0.1** complete; **0.2/CM** default-ON (corpus 158/0/0);
  **0.3 core** done. Sandboxing triad everywhere.
- **Surfaces**: C-API 293/293 · Zig-API complete (full WASI parity) · lean CLI · memory-safety sound · dogfooded into
  cw. Runners ReleaseSafe (ADR-0177; `check_releasesafe_runners.sh`).
- **EH**: cross-instance JIT EH on BOTH arches (arm64 `4f73d9ee` + x86_64 `c534afca`). Interp + JIT EH corpus green.
- **Debt**: 61 entries; `now`-class = D-462 (feature-separation, ADR-0193, user-gated), D-460 (v128-GC partial),
  D-461 (SIMD-spill, blocks D-460). D-335 (WASI 0.3 core) DONE. Rest front-tagged (future-bucket/parked).
- **Realworld corpus**: 56 fixtures (c/cpp/emcc/go/tinygo/rust/zig), interp 56/0; JIT run-stage opt-in.
- **Tag**: `v2.0.0-alpha.3` tag-only (no Release → Latest stays v1.11.0), USER-ONLY.

## Key refs

- [`flake.nix`](../flake.nix) `devShells.gen` / `.#gen-wasip3` — fixture toolchains. [`docs/zig_api_design.md`](../docs/zig_api_design.md).
- ADRs: **0156** (NO autonomous release) · **0153** (rework) · **0187-0191** (CM-async) · **0185** (x86_64 EH) ·
  **0099** (file-size caps) · **0126** (iso-recursive canonical equality).
- lessons INDEX: `.dev/lessons/INDEX.md` (keyword index for Step 0.4).
