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

- **WASI preview1 46/46 DONE (interp, `1d2cb8df`) + ALL-ENGINE JIT DONE (D-244, bundle CLOSED `9414d9b9`).**
  `zwasm run --engine jit <prog>` does REAL WASI end-to-end — prints, exits w/ guest code, sees argv, `--dir` file
  ops — by reusing the interp handlers (zero re-impl): wasi_host field + run*ExportWasi + full 46-syscall JIT lookup
  (`487a38ed`) + preopens (`dfa614cd`). **Verified 3-host green at `71cd3c85`** (Mac + ubuntu `OK` + windows `OK`).
  D-278 discharged; sockets=notsock (real socket I/O = D-281); a pre-existing CLI stdout-drop bug fixed (`f320db6f`).
  Follow-up debt: **D-283** (realworld corpus under `--engine jit` for differential coverage). Open env note:
  **D-282** windowsmini configure-phase build flake (Defender/.zig-cache race; all-runners-0-failed = green).

## NEXT — USER-DIRECTED PROGRAM 2026-06-05 (supersedes the bucket-3 plateau): complete WASI + all-engine + CM

The prior finalization items are DONE (C-API funcref D-269 = owned-handle `of.ref`, `01c1d0cb`, bundle D-269B
closed; verified x86_64 `OK HEAD=2ea7c187`). A new **user-directed program** (chat 2026-06-05) is now the active
work — **ADR-0161** (WASI completion) + **ADR-0162** (toolchain carve-out). Ordered:

- **A — 整備 DONE (prior session)**: rust on test hosts; ADR-0161/0162/0076-D7; §11.1 corrected (**WASI=21/46**);
  A5 CM survey + A1-wire 3-OS rust DONE; **D-279 Win64 SIMD heisenbug** (intermittent, monitored by D7).
- **1. D-273(1) `--invoke NAME=ARGS` args + typed result — ✅ DONE (`34dbebbc`)** (interp; `src/cli/invoke_args.zig`).
- **2. D-278 WASI preview1 21→46 (interp) — ✅ 46/46 COMPLETE (`1d2cb8df`), verified Mac+ubuntu, D-278 discharged.**
- **3. All-engine WASI — JIT ✅ DONE (D-244, 3-host green `71cd3c85`); 🔵 NEXT = D-251 AOT-WASI.** `.cwasm` is
  compute-only: it doesn't serialize import metadata, so AOT-loaded code can't resolve WASI imports. Survey
  `engine/codegen/aot/{format,load,run}.zig` → add `.cwasm` v0.3 import-metadata (module+name+kind) →
  reconstruct `host_dispatch_base` (reuse `wasi/jit_dispatch.zig:populateDispatch`) + attach a Host in `runEntry`.
  Then `zwasm run <file.cwasm>` does WASI. **4. Precise GC root + AOT-GC** (D-211; verify load-bearing first).
- **Post-v0.1.0**: Component Model / WASI P2 (A5 survey informs). WASI 0.3/async (ClojureWasmFromScratch agent ref).

**ADR-0076 D7 (windows cadence gate)**: the loop now HONORS `should_gate_windows.sh` (run windows たまに — ABI-risk
diff OR ≥4 commits, NOT per-turn/too-slow, NOT phase-boundary/too-rare). Win64 red = heisenbug-classify (re-run),
no auto-revert. Step 6+7: `should_gate_windows.sh` exit 0 → kick `run_remote_windows.sh test-all` + `--record`.

## Step 0.7 (next resume) — verify per-cadence remote logs

**D-244 (JIT-WASI) is 3-host GREEN at `71cd3c85`** — ubuntu `OK` + windows `OK.` + Mac. Bundle CLOSED (`9414d9b9`);
windows cadence recorded. No remote verification pending. **A fresh `/continue` starts directly on the NEXT program
item: D-251 (AOT-WASI)** — do its Step 0 survey of `engine/codegen/aot/{format,load,run}.zig` (the `.cwasm` import-
metadata gap), then TDD. (No Active bundle = normal ROADMAP/NEXT-program resume.) **DISCIPLINE: cross-compile
windows-gnu (catches compile gaps); Win64 runtime panics — std `TODO implement ... windows` — only surface on the
actual windows run; reroute the op like `20b9f860`/`f320db6f` did.** **Gate**: Mac = `mac_gate.sh`; ubuntu = always
(D6); windows = cadence (D7); the realworld diff_runner uses capture buffers so the fd_write→real-stdout fix is
regression-safe.

## Deferred / open debt (D-274/275/276/257 discharged this session — removed)

- **Memory-safety (§16.6 DONE, verified 2-host; D-276 proven by ADR-0060)** — only residual is **D-211** precise
  GcRootMap (deferred; conservative scan proven sufficient meanwhile). **D-210** cohort root fix (D-142/206/210/245).
- **Surface residuals** — **D-273** now `note`: (1) `--invoke` args DONE (`34dbebbc`); (2)-(5)
  `--env`/`--fuel`/`--timeout`/`--wasi` deferred-pending-need. **D-253** ref machinery (incl. D-253-D
  standalone-copy; owned-handle `of.ref` model). **D-271**
  serialize=source-bytes (no AOT cache). **D-255** C-API WASI io. **D-251** WASI in AOT.
- **D-254** rust 3-OS. **D-249** win bench. **D-238** x86_64 EH thunk. **D-266/D-259** notes.

## Key refs

- ROADMAP §16 (16.1–16.4 ✅ → 16.5 dogfooding → 16.6 memory-safety → 16.7 docs; NO release gate). §1.2 (完成形
  industry-standard surfaces). ADR-0156 (endgame); **ADR-0159 (§16.4 CLI = run+compile)**; ADR-0157/0158 (C-API
  split + ref model); ADR-0109 (Zig facade); ADR-0136 (`run --engine`). `scripts/capi_surface_gap.sh` (gap=0).
