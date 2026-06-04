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

## NEXT (autonomous — §16 task-list done; phase-boundary audit DONE; backlog; ADR-0156)

- **Post-§16 backlog (no release; 完成形 = keep improving, ADR-0156).** DONE this session: phase-boundary
  `audit_scaffolding` (`1fa6c951`, healthy; D-258/261 discharged); **D-257** lesson-Citing backfill (`841da6d1`);
  **examples/ fmt-gate** (`73ff44f7`); **D-277** §10.4/§3.1 zwasm.h reconcile (`fd5729a1`); **D-275 re-scoped**
  (`4798ffec` — investigated: NOT a facade tweak). The clean quick wins are now exhausted; remaining items are
  involved (ADR + multi-layer + tests) → each is a focused FRESH-CONTEXT chunk, not a cram. Pick one per cycle:
  - **D-275** wire `wasm_instance_new`'s stubbed `trap_out` — capture the start-trap discarded at
    `instance.zig:758` → build a `wasm_trap_t` → write `trap_out`; then C hosts + `Module.instantiate` map it to a
    typed error (`InstantiateError = {InstantiateFailed} || Trap`). Benefits C-API too; likely a small ADR
    (trap_out is a surface decision). Template: `src/zwasm/instance.zig` `mapDispatchErr`. **Top.**
  - **D-273** CLI `--invoke` args + typed-result printing (arg-marshal by param type). **D-274** zlinter lazy dep
    (comptime `@import` blocker — verify lazy pattern). **D-269** callable funcref. **D-276** register-resident GC test.
  - **J.3** 32 active debt rows > 15; old `blocked-by` (D-007/010/020-028/074) → `suggest meta_audit` (user-gated).

## Step 0.7 (next resume)

**No ubuntu kick pending** — §16.6 was verified GREEN at `cf21b11c`; everything since (§16.7 docs + §16.7-close +
the phase-boundary audit + the D-258/261 discharge `1fa6c951`) is **doc/debt-only** (no `src/` change → ubuntu
unaffected). Next backlog item determines the next kick (D-274 = build.zig, no test impact; D-257 = lessons,
doc-only). **Gate**: Step-5 Mac = `bash scripts/mac_gate.sh`. windowsmini = manual-only (ADR-0156: no loop tag).

## Deferred / open debt

- **Memory-safety (§16.6 DONE, verified 2-host)** — residual **D-276** (callee-saved-register-resident worst
  case not independently forced; common case safe).
- **Surface residuals** — **D-269** funcref opaque `?u64` (not callable from a table slot). **D-273** CLI flag
  gap vs wasmtime (`--invoke` args/result-print, `--env`/`--fuel`/`--timeout`). **D-274** consuming zwasm fetches
  zlinter (make lazy). **D-275** `Module.instantiate` coarse error. **D-253** ref machinery (incl. D-253-D
  standalone-copy). **D-271** serialize=source-bytes (no AOT cache). **D-255** C-API WASI io. **D-251** WASI in AOT.
- **D-210** cohort root fix (D-142/206/210/245). **D-211** GcRootMap. **D-257** 10 lesson `Citing` backfill.
  **D-254** rust 3-OS. **D-249** win bench. **D-238** x86_64 EH thunk. **D-266/D-259** notes.

## Key refs

- ROADMAP §16 (16.1–16.4 ✅ → 16.5 dogfooding → 16.6 memory-safety → 16.7 docs; NO release gate). §1.2 (完成形
  industry-standard surfaces). ADR-0156 (endgame); **ADR-0159 (§16.4 CLI = run+compile)**; ADR-0157/0158 (C-API
  split + ref model); ADR-0109 (Zig facade); ADR-0136 (`run --engine`). `scripts/capi_surface_gap.sh` (gap=0).
