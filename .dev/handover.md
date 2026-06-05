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

## Active bundle

- **Bundle-ID**: wasi-p1-completion (D-278)
- **Cycles-remaining**: ~2
- **Continuity-memo**: 21→**39/46** wired (all `std.Io.File`/`std.Io.Dir`-based, cross-compile-clean every push).
  **fd file-meta DONE** (prior turn) + **path_* ×8 DONE this turn** in new `src/wasi/path.zig`:
  create_directory/remove_directory (`aafd3bfd`), filestat_get/filestat_set_times (`6753570b`), symlink/readlink
  (`d434757a`), rename/link (`89a6bbf2`). path.zig has shared resolve(preopen+`..`-guard) + mapDirErr; symlink/
  hardlink tests are privilege-tolerant (acces→skip on Win-no-DevMode). **REMAINING ~7**: **fd_readdir**
  (std.Io.Dir.iterate + Dircookie u64 cursor + dirent {next-cookie/ino/namlen/type}+name marshal — the one MEDIUM
  op), **proc_raise** (sandbox: NOT a real host raise — map to notsup or a trap; short note, no real signal),
  **sockets** (std.Io has NO sockets — std.net gone; std.posix.socket + manual sockaddr; **VERIFY exact preview1
  socket count** — standard wasi_snapshot_preview1 has only sock_accept/recv/send/shutdown=4, NOT the survey's 9;
  reconcile the 46 total against the canonical list at impl time). Recipe: thunk + handler + `lookupWasiThunk`
  name + resolve-all test name + TDD. **DISCIPLINE: `zig build -Dtarget=x86_64-windows-gnu` before every push.**
  `src/wasi/fd.zig`=1190 LOC + new path.zig — fd.zig split candidate after the batch.
- **Exit-condition**: lookupWasiThunk resolves all preview1 names + each has a green handler test, Mac+Linux.

## NEXT — USER-DIRECTED PROGRAM 2026-06-05 (supersedes the bucket-3 plateau): complete WASI + all-engine + CM

The prior finalization items are DONE (C-API funcref D-269 = owned-handle `of.ref`, `01c1d0cb`, bundle D-269B
closed; verified x86_64 `OK HEAD=2ea7c187`). A new **user-directed program** (chat 2026-06-05) is now the active
work — **ADR-0161** (WASI completion) + **ADR-0162** (toolchain carve-out). Ordered:

- **A — 整備 DONE (prior session)**: rust on test hosts; ADR-0161/0162/0076-D7; §11.1 corrected (**WASI=21/46**);
  A5 CM survey + A1-wire 3-OS rust DONE; **D-279 Win64 SIMD heisenbug** (intermittent, monitored by D7).
- **1. D-273(1) `--invoke NAME=ARGS` args + typed result — ✅ DONE (`34dbebbc`)**: `src/cli/invoke_args.zig` parses
  comma-args by export param type (i32/i64/f32/f64; base-0+unsigned-wrap; floats) → boundary Vals; results vec
  sized to result arity (value-returning export now runs); typed results print bare on guest-stdout (wasmtime
  semantics). Interp only; JIT/.cwasm loudly reject `=ARGS`. Smoke-verified (add=2,3→5, swap multi-value, hex, neg).
- **2. D-278 WASI preview1 21→46 (interp) — IN PROGRESS, see `## Active bundle` (39/46)**: all fd_* file-meta +
  positional I/O + the full path_* ×8 batch landed. Remaining ~7 = fd_readdir + proc_raise + sockets.
- **3. All-engine WASI** (D-251 AOT + D-244 d-3 JIT). **4. Precise GC root + AOT-GC** (D-211; verify load-bearing first).
- **Post-v0.1.0**: Component Model / WASI P2 (A5 survey informs). WASI 0.3/async (ClojureWasmFromScratch agent ref).

**ADR-0076 D7 (windows cadence gate)**: the loop now HONORS `should_gate_windows.sh` (run windows たまに — ABI-risk
diff OR ≥4 commits, NOT per-turn/too-slow, NOT phase-boundary/too-rare). Win64 red = heisenbug-classify (re-run),
no auto-revert. Step 6+7: `should_gate_windows.sh` exit 0 → kick `run_remote_windows.sh test-all` + `--record`.

## Step 0.7 (next resume) — verify per-cadence remote logs

Prior turn (`b42c03bd`, fd file-meta): ubuntu GREEN + windows GREEN (file-op runtime verified `[run_remote_windows]
OK.`); windows cadence recorded. This turn pushed the path_* batch (`aafd3bfd`/`6753570b`/`d434757a`/`89a6bbf2` +
handover) — all `-Dtarget=x86_64-windows-gnu` cross-compile-clean + ubuntu/windows kicked. Step 0.7 next resume:
`tail /tmp/win.log` (must be OK — Dir.rename/symLink/hardLink semantics differ on Win64; symlink tests are
acces-tolerant) + `tail /tmp/ubuntu.log` (auto-revert on FAIL). **DISCIPLINE: cross-compile windows-gnu before
every push touching `src/wasi/` or `std.posix`.** **Gate**: Mac = `mac_gate.sh`; ubuntu = always (D6); windows = cadence (D7).

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
