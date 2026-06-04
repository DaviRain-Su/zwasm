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

- **Post-§16 backlog — high-value autonomous work is now CLEARED (loop in refinement/maintenance mode; no
  release, ADR-0156).** DONE this session: phase-boundary `audit_scaffolding` (healthy; D-258/261 discharged);
  **D-257** lesson-Citing backfill; **examples/ fmt-gate**; **D-277** zwasm.h reconcile; **D-275** wired
  `wasm_instance_new` `trap_out` → `StartTrapped` + C-host start-trap (C-API conformance fix); **D-276 discharged
  by PROOF** (`4accb556`) — ADR-0060 force-spill makes the GC-on-JIT register-resident worst case structurally
  impossible → conservative rooting *proven* correct, not just tested. **Remaining backlog is deferred/gated, NOT
  build-now**:
  Plus this turn: **D-274 accepted+discharged** (`84f8a652`) — zlinter eager fetch can't be made lazy (comptime
  `@import` resolves it regardless of `.lazy`; zlinter's `builder()` API needs the import) AND the whole dep is
  slated for removal at Zig 0.17+ (build.zig:2 TODO) → temporary one-time cached cost, documented at build.zig:6.
  **Remaining backlog — no clean high-value autonomous build-now item left:**
  - **D-262** (the only `now` row): gate-topology hardening so per-arch x86_64/win64 emit bugs are caught
    per-chunk, not only at a phase-boundary windowsmini run. Actionable but **involved (process/infra) + non-urgent**
    — effectively mitigated by the followed discipline (test-all on ubuntu for emit chunks + windowsmini at phase
    boundary). Do only if an emit-heavy work stream resumes; else low priority.
  - **D-273** CLI `--invoke` args + **D-269** callable funcref — wasmtime-parity, **no demonstrated need** (§16.5
    dogfooding). Per ADR-0159 (evaluate against real need; don't pre-build) → wait for a real consumer need.
  - **J.3** ~30 `blocked-by` rows (D-007/010/020-028/074, all external/later-blocked) → `suggest meta_audit`
    (user-gated re-walk). **15.6** (only open ROADMAP `[ ]`) externally blocked on cw-v1 landing (D-264).
  - Next cycle: the substantive work is done (Phase 16 + 8 backlog items this session). Absent user direction /
    a new emit work stream, there is no high-value autonomous chunk — avoid speculative over-engineering (ADR-0159);
    a fresh `audit_scaffolding` is over-auditing (just ran `1fa6c951`). Re-arm + idle is acceptable here.

## Step 0.7 (next resume)

**No ubuntu kick pending** — last `src/` change was D-275 (`d7190346`, verified GREEN `OK (HEAD=72ebe1ed)`).
Everything since (D-276 ADR proof, D-274 build.zig comment + debt) is doc/comment-only — `build.zig`'s change is
an inert comment, no build-behaviour change. No `src/` delta → ubuntu unaffected.
**Gate**: Step-5 Mac = `bash scripts/mac_gate.sh`. windowsmini = manual-only (ADR-0156: no loop tag).

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
