# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Active program — ADR-0164: trap / crash / exception diagnostics & UX (D-292)

JIT/AOT printed a bare `Trap` (no kind) where v1 + v2-interp give per-kind messages — a v1-parity
regression (surfaced by D-291). Audit-first, spans engines; four workstreams **A→B→C→D**, then D-291:

- ✅ **A — surface the trap KIND + message on ALL engines. DONE.**
  - CLI surface (`b6da8604`): JIT/AOT run paths thread `trap_kind` → `trap_surface.jitTrapCode` → per-kind CLI
    message; single-message interp-parity (double-`Trap` bug fixed, genuine trap = exit 1 not re-raised).
  - **Codegen widening DONE for the common 4** (per-kind stub + per-kind fixup channel demuxed from
    `bounds_fixups`; arm64 `EmitCindStub` / x86_64 `emitTrapExitStub`): A1 `6fcbabbd` unreachable=5 ·
    A2 `687d1a73` div_by_zero=7 + div_s overflow=8 (fixed a latent x86_64 overflow→div-by-zero misreport) ·
    A3 `63e8c6eb` oob_memory=6 (memory load/store + bulk + v128). All UNIFIED across arm64+x86_64.
  - The OTHER still-generic kinds (oob_table / invalid_conversion / trunc int_overflow / null_reference /
    cast_failure / array_oob — `bounds_fixups` is a multi-kind catch-all) are **D-293** (kinded-fixup refactor),
    deferred behind B/C/D. Trap-kind execution tests live in `src/engine/runner_trap_test.zig` (new this turn).
- **← LEAD (B): crash-vs-trap distinction.** Internal SIGSEGV/@panic = INTERNAL ERROR, not `Trap`; ideal zero
  host-crash; **restrict the `[stack_probe]` diag to genuine stack-overflow** (it currently prints on EVERY
  JIT trap as stub context — the noise seen on `unreachable`; `src/platform/stack_limit.zig`). Step 0 survey
  where `[stack_probe]` fires + how a genuine SIGSEGV/@panic surfaces today vs a clean wasm trap.
- **C — exception(EH)-vs-trap distinction.**
- **D — audit vs wasmtime / wasmer / WasmEdge / v1** (messages, backtrace, exit codes) → gap list.
- **then D-291** (ed25519 JIT trap) — once A's widening surfaces the KIND, debug_jit_auto PC→op + shrink to a
  minimal repro. The trap is a clean controlled wasm trap (characterized `256433`/`cf63377b`), not a SIGSEGV.

DISCHARGE (D-292): all engines emit clear per-kind trap messages + crash/trap/exception cleanly distinguished +
audit-gap list closed-or-deferred.

## Queue after the active program (time-consuming first, per user directive)

3. **D-288** (interp frame-stack inline+overflow redesign; ackermann 1021-deep traps at the 256 cap; ADR-likely).
4. **D-287** (validator control-stack cap 1024 rejects valid deep nesting — raise + ADR; product-envelope call).
5. Moderate: **D-284** (interp/jit/aot entry-resolution unify) · **D-290** (wabt→wasm-tools, user-directed hygiene).
6. Defer (low-signal / measure-first): **D-289 FP/param/stack large arms** · **D-286** (fill/init byte-loop).
   **D-285** (JIT byte-loop/bulk-memory codegen, ADR-0153 rework candidate — scheduled after this program).

## Current state

- **Phase 16 (完成形) — open-ended; the loop CONTINUES, no release (ADR-0156).** v0.1.0-scope program is
  thoroughly complete + 3-host green (`deb97903`); ADR-0163 bench+docs program ALL DONE. Tag/publish/cutover are
  manual, user-only — there is no release gate.
- Debt ledger: 0 `now`. Last full 3-host green = `635bd734` (Mac + ubuntu `701cbe60` + windows `OK`).
  Mac green through A3 `63e8c6eb`. **A1+A2 verified 3-host GREEN** (ubuntu `OK` + windows `OK` at dca1b7a1 —
  D-279 heisenbug did NOT fire; trap-stub work clean on all hosts). A3 kicks fire at this turn's push.

## Step 0.7 (next resume) — verify remote logs

- **ubuntu**: `tail -3 /tmp/ubuntu.log` — expect GREEN on A3 (`63e8c6eb`). RED on a codegen-real failure →
  auto-revert (D3); a trap-kind mismatch would be a real regression (the per-kind stubs), not a flake.
- **windows**: GREEN expected (A1+A2 were clean). RED with the sha256-shootout non-deterministic signature =
  the standing **D-279** Win64 heisenbug — `track_heisenbug.sh win64-testall segv`, KEEP commits (D7),
  non-blocking. Real new Win64 bug (reproduces on re-run, codegen/ABI touch) → debt row + fix.
- Windows cadence: record green via `should_gate_windows.sh --record` once A3's windows kick is verified.

## Key refs

- **ADR-0164** (this program: `.dev/decisions/0164_trap_crash_exception_diagnostics_ux.md`). **D-292** (program
  debt row) + **D-291** (ed25519 motivating case) + **D-165** (JIT trap-code infra). ADR-0156 (no autonomous
  release). ADR-0016 (trap stderr / diagnostic phases).
- Surfaces: `src/cli/run.zig` (`surfaceTrap` interp / `surfaceJitTrap` jit+aot / `runWasmJit` / `runCwasmWasi`),
  `src/api/trap_surface.zig` (`jitTrapCode` / `trapMessageFor` / `TrapKind`), `src/cli/main.zig` (`renderFallback`
  trap path), `src/runtime/trap.zig` (Trap set), `src/engine/codegen/shared/entry.zig` (`[d-165]` print),
  `src/engine/codegen/{arm64/emit.zig,x86_64/op_control.zig}` (trap-code write sites), `src/platform/stack_limit.zig`
  (`[stack_probe]` diag). v1 per-kind msgs: `~/Documents/MyProducts/zwasm/src/cli.zig`.
