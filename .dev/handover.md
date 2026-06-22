# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state — Phase 17, `.auto`→JIT flip campaign (user=C); tree green @dad3550ba; (A) narrowed to one fix path

**USER RECONFIRMED C 2026-06-22** (continue full flip before tag; multi-day x86_64-JIT campaign).
Both attempt-#4 ubuntu gaps root-caused; (A) fix-path NARROWED this cycle (full detail in D-496):
- **(A)** x86_64 prologue fuel/interrupt poll gated on `uses_runtime_ptr` → trivial fns unbounded. The lighter
  RAX-poll idea was IMPLEMENTED + Rosetta-tested → **FALSIFIED (crash)**: the trap stub writes trap_kind via R15,
  which a lean fn never installs. **ONLY correct codegen fix = (a) force `uses_runtime_ptr=true` (emit.zig:193) +
  recompute the 59 byte-exact emit tests** (each `body_start_offset(false,fb)`→`(true,NEW_fb)`; per-test frame
  recompute — good SUBAGENT task). Alt: **(b) pin the ~3 facade sandbox tests `.interp` + debt the gap** (runaway
  -safety intact; only fuel=0-trivial semantic differs). Pick (a) unless it proves too costly → fall to (b).
- **(B)** `wast_runtime_runner.zig:709,798` `.auto`→JIT for imported-memory → pin `.interp`. 2-line fix (re-doable).
**REMAINING flip plan**: do (A) [(a) via subagent for the 59 tests, OR (b)] → (B) pin → `git revert 18d2f887a`
restores the whole flip + attempt-#3's ~14 pins → layer A+B → full Mac test → **ubuntu-gate (MANDATORY)** → 3-host
green → tag alpha.3. funcref D-497/D-498 stay pinned-debt. cljw waits. cron `f34c7ee2`; CronDelete only at final stop.

**IN FLIGHT**: a subagent (agentId a4b151e9...) is implementing the (a) always-R15 fix + `bodyStartFromBytes`
helper + 59 emit-test sed, verifying Mac-green + Rosetta `--fuel 0`-traps; it leaves changes UNCOMMITTED for review
(do NOT edit emit.zig/prologue.zig/emit_test_* concurrently). Next cycle: review its diff → commit (A) → (B) pin →
`git revert 18d2f887a` (restore flip+~14 pins) → layer A+B → ubuntu-gate → 3-host → tag.

**LESSON (load-bearing): Mac `zig build test` is INSUFFICIENT to declare the flip green — MUST ubuntu-gate.**

## D-496 campaign (jit-capi-surface-flip) — accessors LANDED+green; flip re-land pending (A)+(B) fixes

Five chunks done: ch1 @45f5b93c7 (kind-generic exports), ch2/3/5 @f7d5e0233 (global/memory/get_func arms), ch4
@d3602f214 (table), ch6 FLIP @3db5e40bd (`.auto`→JIT, full test 69→0). instance.zig `(cap=UNCAPPED)` @4e1b06892.
Known niche JIT gaps: D-497 (funcref-table grow), D-498 (funcref param/result C-API marshalling) — both pinned+debt.
**Backstop cron `f34c7ee2`** (10-min /continue): `CronDelete` at the FINAL stop (after the tag), no ScheduleWakeup
re-arm (clean stop). The alpha.3 tag is USER-AUTHORIZED, cut ONLY after 3-host green.

**DONE (committed, 3-host green @462ea1e57)**: D-489 + D-494 (the two real flip blockers) RESOLVED = regalloc LSRA dual
spill-slot mint collision, fix = unify on `n_spill_minted`. The 69-failure flip-attempt detail + reverted-flip work is
in D-496. cljw CONSUMED to_cljw_07/08 (resource pts 1-4 confirmed) + AWAITS the tag (cut at campaign end). Release notes
drafted `.dev/release_notes/v2.0.0-alpha.3.md`; last tag `v2.0.0-alpha.2`.

Project at the **完成形 plateau** (all dims confirmed): clean (C/Zig/CLI audits), full-featured (WASI complete +
now cross-component STRING composition, D-305 milestone), 100% spec (`test-spec` 25539/0), lightweight-yet-fast
(v1-JIT parity, D-265 closed). Robustness: interp+JIT fuzz 0 crashes. Closed-arc detail lives in git/ADRs/lessons.

**Closed arcs (detail in git/ADRs/debt — do NOT re-walk)**: D-305 cross-component linker (string/list/record
marshalling both directions, ADR-0196, comp-assert 170/0); ADR-0195 guest↔guest async FUNCTIONALLY COMPLETE +
D-463 handle isolation (ADR-0197); D-034 SIMD spill-completeness CLOSED @411dd1e14; wasi:random, D-335 typed
marshalling, C-API Windows-export. Residual long-tails (debt-tracked, do NOT grind): D-464 async adversarial,
D-305 niche shapes. Version `2.0.0-alpha.3`. Low-pri follow-up: consolidate duplicated SIMD spill helpers.

## Closed: D-489/D-494 regalloc fix (DONE @462ea1e57) + windows gate

D-489/D-494 both flip blockers resolved by the unified spill-mint fix (lesson `2026-06-22-d489-capture-path-investigation.md`).
Windows gate 3-host GREEN @ed9332294 (intermittent host-example file-create = ENV flake, debt `windows-host-example-filecreate`, not a regression).

## Closed arcs (do NOT re-walk)

v128-GC sweep (D-491/492/493 fixed, D-495 guarded); arm64 JIT-exec ZERO divergences; ADR-0200 JIT embedding API +
cljw consumed `to_cljw_06`. Tag-cut PENDED (release notes drafted `.dev/release_notes/v2.0.0-alpha.3.md`; last tag
`v2.0.0-alpha.2`). cljw dogfooding PAUSED both sides. D-489/D-494 detail → lesson `2026-06-22-d489-capture-path-investigation.md`.

**Operational notes**: a JIT-codegen fix → verify on BOTH arm64 AND `-Dtarget=x86_64-macos` (NOT interp `test-spec`).
**Rosetta x86_64-macos reproduces D-489** (the prior "Rosetta MASKS x86_64 bugs" claim is FALSE — corrected). Phase 17
完成形 plateau holds (spec 100%, fuzz 0-crash, surface audits clean 2026-06-18, realworld JIT 56/56 byte-match wasmtime
GATING via `test-realworld-diff-jit`). D-475 table64-JIT PARKED (perf, Win64-risk). The prior 2026-06-20 "correctness
sweep" standing directive is SUPERSEDED by the `.auto`→JIT flip-campaign priority (POSTURE above).

**Step-0.7 NOTE**: `failed command: test…--listen=-` is COSMETIC (exits 0); trust `[run_remote_*] OK/FAIL` + `N
passed, 0 failed`, not that line.

**PARKED / gated (do NOT speculatively grind)**: D-305 long-tail (niche, + `component_graph.zig` 1895/2000
file-split first); D-464 async; 21 `blocked-by`. **validator.zig at 3449/3450 cap — NEXT validator edit MUST
extract per the file's marker plan.** Closed-arc detail (D-305/ADR-0192/async/WASI-0.3) is in git/ADRs/debt.

## Long-tail (debt-tracked / parked — NOT active; see debt.yaml)

- **JIT-correctness** (front B): D-330/D-331/D-333 all resolved+deleted from debt. Re-verified post-462ea1e57: ALL
  go_*/c_sha256/rust_sha256 realworld fixtures content-match interp-vs-jit on BOTH arches. D-454 GC-program fixture
  future-bucket. Trace tooling: `ZWASM_DEBUG=jit.dump`/`regverify` + `scripts/jit_value_trace.sh` (Recipe 18).

## State (all 3-host green @046d9c67/win @886d0667; release = USER-ONLY, ADR-0156)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip (GC 362/0). **WASI 0.1** complete; **0.2/CM** default-ON (corpus 158/0/0);
  **0.3 core** done. Sandboxing triad everywhere.
- **Surfaces**: C-API 293/293 · Zig-API complete (full WASI parity) · lean CLI · memory-safety sound · dogfooded into
  cw. Runners ReleaseSafe (ADR-0177; `check_releasesafe_runners.sh`).
- **EH**: cross-instance JIT EH on BOTH arches (arm64 `4f73d9ee` + x86_64 `c534afca`). Interp + JIT EH corpus green.
- **Debt**: 62 entries; **ZERO `now`-class** (D-034 spill arc CLOSED @411dd1e14 → `note`; D-460 v128-GC + D-461 +
  D-293 + D-294 all `note`). Remaining partials: D-305 (consumer-gated CM shapes), D-331(A)/D-330 (go_* JIT; B closed).
  Rest front-tagged (future-bucket/parked); D-462 feature-separation = user-gated. **完成形 plateau.**
- **Realworld corpus**: 56 fixtures (c/cpp/emcc/go/tinygo/rust/zig), interp 56/0; JIT run-stage opt-in.
- **Tag**: `v2.0.0-alpha.3` tag-only (no Release → Latest stays v1.11.0), USER-ONLY.

## Key refs

- [`flake.nix`](../flake.nix) `devShells.gen` / `.#gen-wasip3` — fixture toolchains. [`docs/zig_api_design.md`](../docs/zig_api_design.md).
- ADRs: **0156** (NO autonomous release) · **0153** (rework) · **0187-0191** (CM-async) · **0185** (x86_64 EH) ·
  **0099** (file-size caps) · **0126** (iso-recursive canonical equality).
- lessons INDEX: `.dev/lessons/INDEX.md` (keyword index for Step 0.4).
