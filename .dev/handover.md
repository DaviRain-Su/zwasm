# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase 16 (完成形) — §16.1–16.7 task-list COMPLETE; the loop CONTINUES, no release (ADR-0156).** Phases 0–15
  + the entire §16 surface/safety/docs task-list are DONE. The v2 redesign has hit the 完成形 bar: clean design +
  lightweight-fast + full-featured + 100% spec across the runtime AND the surfaces (C/Zig/CLI). **The loop never
  tags/publishes/cuts over** (manual user-only); it now keeps refining + paying backlog debt **indefinitely**.
  Phase Status widget stays Phase-16 IN-PROGRESS (completion-finalization is open-ended, not a closeable phase).
- **§16 outcomes** (detail in the ROADMAP §16 rows + ADRs + CHANGELOG): **§16.1** migration guide (`58a483e8`);
  **§16.2** C-API **gap 0 (293/293)** (`e9367bb2`, `scripts/capi_surface_gap.sh`); **§16.3** Zig-API facade
  confirmed minimal/clean (ADR-0025→0109); **§16.4** CLI = **run+compile** + --version/--help (ADR-0159);
  **§16.5** dogfooding — external consumability fixed + Global/Table accessors (D-272 closed), full facade proven
  via `examples/zig_dep/`; **§16.6** GC-on-JIT memory-safe — collect trigger + adversarial UAF test green
  Mac+x86_64 (ADR-0160); **§16.7** docs — README/CHANGELOG/`docs/reference/`/`docs/tutorial.md` to the settled
  surface (`12390815`, `3a5e8ba0`).

## NEXT — USER-DIRECTED PROGRAM 2026-06-05 (supersedes the bucket-3 plateau): complete WASI + all-engine + CM

The prior finalization items are DONE (C-API funcref D-269 = owned-handle `of.ref`, `01c1d0cb`, bundle D-269B
closed; verified x86_64 `OK HEAD=2ea7c187`). A new **user-directed program** (chat 2026-06-05) is now the active
work — **ADR-0161** (WASI completion) + **ADR-0162** (toolchain carve-out). Ordered:

- **A — 整備 (mostly DONE this session)**: rust installed (win rustc 1.96.0 / ubuntu flake `.#rust-host` `a5cf80fb`);
  ADR-0161+0162; ROADMAP §11.1 overclaim corrected (**WASI = 21/46, NOT full**); D-278 scheduled. **Remaining 整備**:
  A5 Component-Model 馴染みサーベイ (de-risk — read v1 CM + wasmtime + `wasm-tools` → findings doc, NO impl);
  A1-wire (`build.zig run-rust-host` 3-host + resolve win MSVC/GNU); `toolchain_provisioning.md` update (per ADR-0162).
- **1. D-273(1) `--invoke` args + typed result** (the only `now` row) — type-driven parse (export param types) →
  result to stdout, exit-code = success only. Ref v1 CLI. **FIRST** (small/independent).
- **2. D-278 WASI preview1 21→46** (interp) — sockets ×9 / fd_readdir / path_* ×7 / pread/pwrite/sync/... TDD each.
- **3. All-engine WASI** (D-251 AOT + D-244 d-3 JIT) — WASI host on all 3 engines (today interp-only).
- **4. Precise GC root + AOT-GC** (D-211) — first verify WHERE precise rooting is truly load-bearing; build only there.
- **5. D-254 3-OS rust run** — after A1-wire.
- **Post-v0.1.0**: Component Model / WASI P2 (v1-parity; A5 survey informs). WASI 0.3/async (open horizon;
  ClojureWasmFromScratch `runtime/agent.zig` async-Zig ref).

**Local commits to push (next /continue Step 3)**: `fdb41880` (debt directives) · `a5cf80fb` (flake rust-host) ·
`6b54fd3e` (ADR-0161) · `0182ed00` (§11.1+D-278) · `9b276ace` (ADR-0162).

## Step 0.7 (next resume) — no kick pending

D-269B kick already verified GREEN (`OK HEAD=2ea7c187`). This session's commits since are doc/flake/ADR/debt only
(no `src/`) → no kick. The first code chunk (D-273(1) `--invoke`) kicks the D6 `test-all` when it lands.
**Gate**: Step-5 Mac = `bash scripts/mac_gate.sh`. windowsmini = manual-only (ADR-0156: no loop tag).

## Deferred / open debt (D-274/275/276/257 discharged this session — removed)

- **Memory-safety (§16.6 DONE, verified 2-host; D-276 proven by ADR-0060)** — only residual is **D-211** precise
  GcRootMap (deferred; conservative scan proven sufficient meanwhile). **D-210** cohort root fix (D-142/206/210/245).
- **Surface residuals** — (**D-269** promoted to NEXT chunk above.) **D-273** CLI flag gap vs wasmtime (validated
  defer). **D-253** ref machinery (incl. D-253-D standalone-copy; owned-handle `of.ref` model). **D-271**
  serialize=source-bytes (no AOT cache). **D-255** C-API WASI io. **D-251** WASI in AOT.
- **D-254** rust 3-OS. **D-249** win bench. **D-238** x86_64 EH thunk. **D-266/D-259** notes.

## Key refs

- ROADMAP §16 (16.1–16.4 ✅ → 16.5 dogfooding → 16.6 memory-safety → 16.7 docs; NO release gate). §1.2 (完成形
  industry-standard surfaces). ADR-0156 (endgame); **ADR-0159 (§16.4 CLI = run+compile)**; ADR-0157/0158 (C-API
  split + ref model); ADR-0109 (Zig facade); ADR-0136 (`run --engine`). `scripts/capi_surface_gap.sh` (gap=0).
