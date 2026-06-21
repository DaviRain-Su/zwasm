# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state — Phase 17, `.auto`→JIT FLIP CAMPAIGN = PRIORITY (release = USER-ONLY, ADR-0156)

**POSTURE (user-directed 2026-06-21, REVISED)**: drive the **`.auto`→JIT flip** as the top priority. The flip's
only true blockers are the two no-fallback runtime bugs **D-489** (x86_64 realworld JIT miscompile, tinygo_json) +
**D-494** (TinyGo defer/recover asyncify deadlock under JIT, both arches) — everything else (imports / unsupported
ops / wide host-sigs) rejects at instantiation and falls back to interp safely (instance.zig:725-731). Fix both →
re-land the flip → green-light = 3-host gate + full x86_64 interp-vs-jit realworld sweep clean. **Tag-cut PENDED**
(release notes already drafted at `.dev/release_notes/v2.0.0-alpha.3.md`; last actual tag = `v2.0.0-alpha.2`).
**cljw dogfooding PAUSED both sides** (cljw mid require-redesign; brief `to_cljw_06.md` sent with current truth).

Project at the **完成形 plateau** (all dims confirmed): clean (C/Zig/CLI audits), full-featured (WASI complete +
now cross-component STRING composition, D-305 milestone), 100% spec (`test-spec` 25539/0), lightweight-yet-fast
(v1-JIT parity, D-265 closed). Robustness: interp+JIT fuzz 0 crashes. Closed-arc detail lives in git/ADRs/lessons.

**Closed arcs (detail in git/ADRs/debt — do NOT re-walk)**: D-305 cross-component linker (string/list/record
marshalling both directions, ADR-0196, comp-assert 170/0); ADR-0195 guest↔guest async FUNCTIONALLY COMPLETE +
D-463 handle isolation (ADR-0197); D-034 SIMD spill-completeness CLOSED @411dd1e14; wasi:random, D-335 typed
marshalling, C-API Windows-export. Residual long-tails (debt-tracked, do NOT grind): D-464 async adversarial,
D-305 niche shapes. Version `2.0.0-alpha.3`. Low-pri follow-up: consolidate duplicated SIMD spill helpers.

## Active bundle

- **Bundle-ID**: D-489-capture-path-rr
- **Cycles-remaining**: ~3 (until d489-repro scenario1 = 90)
- **Continuity-memo**: D-489 = the JIT stdout-CAPTURE path corrupts a guest VALUE (the fmt format-slice) on
  **x86_64-linux ONLY** (arm64/Rosetta mask it). **NOT a codegen miscompile** — direct `zwasm run … --engine jit` =
  90B CORRECT; the diff-jit gate's tinygo_json MISMATCH(130B) IS this capture bug; the `.auto`→JIT flip is NOT blocked
  by a miscompile. Registers (unconditional caller-saved clobber), red-zone (+4096 pad), heap-layout (pre-size/8MB),
  rodata (fmtwatch INTACT), build-env (Mac-cross==ubuntu) ALL ruled out → pure heap-write(appendSlice) vs
  syscall(writeStreamingAll) data effect in `src/wasi/fd.zig:writeSlice`. **Full investigation + hard-won TIPS (FAST
  LOOP = Mac cross-build `-Dtarget=x86_64-linux-gnu` + `scp` to ubuntu; tools gdb-native + rr via `nix-shell -p rr`;
  dbg-gate is OFF in the `zwasm run` CLI; SSH outer/inner script pattern) → lesson
  `.dev/lessons/2026-06-22-d489-capture-path-investigation.md` + debt D-489.** NEXT = rr/gdb reverse-debug the
  corrupted format-slice on ubuntu. (D-494 dfr2 is arm64-correct at HEAD — likely the same artifact; verify later.)
- **Exit-condition**: `zig build d489-repro` scenario(1) prints `len=90 OK` (= diff-jit tinygo_json MATCHes).

**WINDOWS GATE — 3-host GREEN @ed9332294** (2026-06-21): earlier host-example file-create failure was an ENV FLAKE,
cleared on re-run (Win64 spec 25539/0, simd 25075/0, wasi 3/0). Recorded via `--record`. Intermittent
host-embedding-example file-create stays debt-tracked (`windows-host-example-filecreate`), NOT a code regression.

## Closed arcs (do NOT re-walk)

v128-GC sweep (D-491/492/493 fixed, D-495 guarded); arm64 JIT-exec ZERO divergences; ADR-0200 JIT embedding API +
cljw consumed `to_cljw_06`. Tag-cut PENDED (release notes drafted `.dev/release_notes/v2.0.0-alpha.3.md`; last tag
`v2.0.0-alpha.2`). cljw dogfooding PAUSED both sides. D-489 full detail → the `## Active bundle` above + its lesson.

**Operational notes**: a JIT-codegen fix → verify on BOTH arm64 AND `-Dtarget=x86_64-macos` (NOT interp `test-spec`);
but **D-489-class x86_64-LINUX bugs need the Mac-cross+ubuntu loop — Rosetta x86_64-macos MASKS them**. Phase 17
完成形 plateau holds (spec 100%, fuzz 0-crash, surface audits clean 2026-06-18, realworld JIT 56/56 byte-match wasmtime
GATING via `test-realworld-diff-jit`). D-475 table64-JIT PARKED (perf, Win64-risk). The prior 2026-06-20 "correctness
sweep" standing directive is SUPERSEDED by the `.auto`→JIT flip-campaign priority (POSTURE above).

**Step-0.7 NOTE**: `failed command: test…--listen=-` is COSMETIC (exits 0); trust `[run_remote_*] OK/FAIL` + `N
passed, 0 failed`, not that line.

**PARKED / gated (do NOT speculatively grind)**: D-305 long-tail (niche, + `component_graph.zig` 1895/2000
file-split first); D-464 async; 21 `blocked-by`. **validator.zig at 3449/3450 cap — NEXT validator edit MUST
extract per the file's marker plan.** Closed-arc detail (D-305/ADR-0192/async/WASI-0.3) is in git/ADRs/debt.

## Long-tail (debt-tracked / parked — NOT active; see debt.yaml)

- **JIT-correctness** (front B): D-331(B) CLOSED · D-330 c_sha256 PROVABLY-BLOCKED · D-331(A) go runtime-corruption
  DRIVABLE · D-333 folds into D-330 (all in debt.yaml; D-489 may share the go/x86_64 spill root). D-454 GC-program
  fixture future-bucket. Trace tooling: `ZWASM_DEBUG=jit.dump` + `scripts/jit_value_trace.sh` (Recipe 18).

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
