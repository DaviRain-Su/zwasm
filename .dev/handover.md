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

## NEXT (autonomous — §16 task-list done; phase-boundary audit, then backlog; ADR-0156)

- **MANDATORY FIRST: phase-boundary `audit_scaffolding`.** §16.7 was the last §16 [ ] → the §16 task-list is
  complete, so the mandatory phase-boundary audit is owed (deferred from the §16.7-close turn for context length —
  it deserves fresh context). Invoke `audit_scaffolding` (walk §A–G; weight §F debt-coherence + §G
  extended-challenge anchor commands). `block` finding → fix locally if local-scope, else ADR + queue here.
  Optionally SHA-backfill §16 rows after.
- **Then: backlog debt + refinement** (no release; 完成形 reached = keep improving, ADR-0156). Pick
  highest-value-per-risk each cycle: **D-274** make zlinter a lazy dep (consumers shouldn't fetch the lint tool —
  clean, scoped, closes a real consumability wart); **D-273** CLI `--invoke` args + typed-result printing
  (wasmtime-parity UX); **D-277** reconcile §10.4 ↔ zwasm.h (or ship `zwasm_func_call_fast`); **D-269** callable
  funcref from host (deeper); **D-276** force the register-resident GC-rooting worst case; **D-275** richer
  `Module.instantiate` error; `examples/` not fmt-gated by `gate_commit.sh` (tiny tooling fix).

## Step 0.7 (next resume)

**No ubuntu kick pending** — §16.6 was verified GREEN at `cf21b11c`; everything since (all of §16.7:
`12390815`/`3a5e8ba0` + the [x] flip) is **doc-only** (no `src/` change → ubuntu unaffected). The next action
(audit_scaffolding) is read-only. **Gate**: Step-5 Mac = `bash scripts/mac_gate.sh`. windowsmini = a future
manual-only concern (ADR-0156: no release/tag from the loop).

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
