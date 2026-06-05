# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## D-291 — PAUSED for fresh context (standing investigation; full detail in the D-291 debt row)

ed25519 JIT `oob_table` miscompile, EXHAUSTIVELY localized this session (commits `6e49ecad`→`af2e1f18`,
gated `-Dtrace-stackprobe` diagnostics `trap_aux..trap_aux4`): func 17 (a 128-bit multiply) clobbers
`memory[16777416]` because it is called with `local0 ≈ 16777416` — a WRONG result-buffer ptr that one of its
733 callers computes ~16MB TOO HIGH (the addr lands in the DATA region, where a stack temp never should).
Frame/spill helpers + data-seg + load + cind all RULED OUT. NEXT (fresh session): runtime-capture the func-17
caller's result-buffer / SP computation (return-address → which caller → its WAT) → confirm __stack_pointer-
global vs wide-i32-arith miscompile. Non-gating (ed25519 excluded from suite/bench). **Paused at turn ~14 of a
long session per the debt row's "focused fresh-context session" guidance** — the diag infra makes resume cheap.

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
- **B — crash-vs-trap distinction. IN PROGRESS.**
  - ✅ diag hygiene (`80cba28a`): `[stack_probe]` + `[d-165] kind=4` prints gated behind `-Dtrace-stackprobe`
    (default false) → clean Debug test stderr; D-279/D-165 primitives preserved (opt-in). Step-0 CORRECTED the
    handover's premise — these are setup-time once-per-process Debug prints, NOT per-trap stub context.
  - **B core (deferred behind D-291): internal SIGSEGV/@panic → graceful INTERNAL ERROR.** Step-0 finding:
    NO signal handling anywhere (`grep` cli/+entry = empty) — an internal fault hits the OS as raw signal 11
    (exit 139), undistinguished from a clean wasm `Trap`. Fix = a `sigaction`/vectored-exception handler (any
    such signal in v2 = internal bug, since v2 uses NO signal-based wasm semantics — all traps are explicit
    checks) surfacing a distinct "internal error". NEEDS an **ADR-0070 (libc) amendment** + design ADR; bundle.
- **C — exception(EH)-vs-trap distinction.** · **D — audit vs wasmtime/wasmer/WasmEdge/v1 → gap list.**
- **D-291** (ed25519 `oob_table` miscompile, A-unblocked) — exhaustively localized this session, **PAUSED for
  fresh context** (see the D-291 section above + debt row). B-core/C/D remain (B-core needs an ADR-0070 amend).

DISCHARGE (D-292): all engines emit clear per-kind trap messages + crash/trap/exception cleanly distinguished +
audit-gap list closed-or-deferred.

## Recently completed (breadth, pivot from D-291)

- ✅ **D-287 DONE** (`cf605260`, ADR-0165): raised `zir.max_control_stack` 1024→4096 so valid deeply-nested
  wasm (shootout/switch.wasm, LLVM big C switch, depth 2568) validates + runs (wasmtime accepted it; we
  rejected it). Memory-bounded by the validator's host-stack `control_buf` (~280KB at 4096, safe); runtime
  label stack is hybrid-lazy. Tests: 2000-deep validates, 9000-deep overflows. Forward-ref: heap the validator
  control_buf to remove the cap entirely (full spec-completeness).

- **D-288 investigated, naive fix REVERTED** (no commit): the interp **recurses NATIVELY** (mvp.zig:654
  `invoke` ← `callOp:413`), ~8KB/native-frame → 8MB Mac stack ÷ ~1021. So `frame_buf[256]` is a SEGV GUARD
  (clean-traps before the host stack overflows); raising it (tested cap=4096) made ackermann SEGV at ~1021.
  Real fix = a flat/trampolined interp (no native recursion) OR a native-stack-limit check in `invoke` — an
  interp-architecture change (ADR). Substantial → moved to the queue. (Latent: Win 1MB native limit ~128 < 256.)

## ← LEAD: D-293 slice-1 — oob_table precision (PRECISE PLAN RECORDED in the D-293 debt row)

Surveyed this turn → a complete, corrected edit plan is in the D-293 row. KEY FINDINGS: (1) x86_64 has NO
oob_table precision at all (cind bounds + table bounds → generic `bounds_fixups`); arm64 is precise for cind
only. (2) A test asserting code 2 enforces BOTH-arches parity (fails the ubuntu gate otherwise) → must do both
arches together. (3) ⚠️ x86_64 op_call 495/546/597 are sig/null (codes 3/null_reference), NOT oob_table — a
subagent plan mis-classified them; route ONLY the bounds sites 529+583. EDITS: arm64 = re-route 7 op_table
bounds → `cind_bounds_fixups`; x86_64 = build an `oobtable_fixups` channel (mirror A3 `oob_fixups`→stub code 2)
+ thread it through op_call/op_table (bounds sites only). ~30 edits, error-prone → execute fresh + careful.
NOTE: this is a prep turn — the remaining queue (D-293/D-291/D-288/B-core) is uniformly substantial per-arch /
architectural work best executed with fresh context; the precise plans are recorded to make execution clean.

## Queue (time-consuming first, per user directive)

- **D-288** (interp flat/trampolined recursion OR native-stack-limit check; ADR — interp-architecture redesign).
- **D-291** (paused; see top) · **D-292 B-core** (SIGSEGV→internal-error, needs ADR-0070 amend) · C · D.
- Moderate: **D-284** (interp/jit/aot entry-resolution unify) · **D-290** (wabt→wasm-tools hygiene).
- Defer: **D-289** FP/param/stack large arms · **D-286** (fill/init byte-loop) · **D-285** (JIT bulk-memory, ADR-0153).

## Current state

- **Phase 16 (完成形) — open-ended; the loop CONTINUES, no release (ADR-0156).** v0.1.0-scope program is
  thoroughly complete + 3-host green (`deb97903`); ADR-0163 bench+docs program ALL DONE. Tag/publish/cutover are
  manual, user-only — there is no release gate.
- Debt ledger: 0 `now`. Last full 3-host green = `635bd734` (Mac + ubuntu `701cbe60` + windows `OK`).
  Mac green; ubuntu green through `0e076fc7`; windows = D-279 heisenbug (1-failed-step this run, non-blocking,
  tracked `win64-testall segv @5c70edcb`). D-291 diagnostics are gated (`-Dtrace-stackprobe`) → default unaffected.

## Step 0.7 (next resume) — verify remote logs

- **ubuntu**: ✅ GREEN through B-diag `a2ac1b89` (`[run_remote_ubuntu] OK (HEAD=a2ac1b89)`). A1/A2/A3 all green
  on x86_64 Linux. `tail -3 /tmp/ubuntu.log` next resume for the latest kick.
- **windows**: ⚠️ test-all at `85157236` (A3) RED = the standing **D-279** Win64 heisenbug, NOT a regression.
  Signature: `zwasm-spec-simd` (`simd_bit_shift` — A3 NEVER touched shift codegen) + `zwasm-spec-wasm-2-0-assert`
  fail Win64-ONLY while Mac arm64 + ubuntu x86_64 are GREEN on identical source; non-deterministic (D-279 lineage
  D-180/D-245). Tracked `win64-testall segv @ a2ac1b89` (streak 0). **Commits KEPT (D7).** Cadence recorded at
  `a2ac1b89` (windows = "checked, only known heisenbug" — NOT clean-green; do not treat as green-verified).
- **Gate note (retracted alarm)**: `run_remote_windows.sh` correctly has `set -euo pipefail` + aborts before
  printing `OK` on remote failure (the wrapper exited 1 here). "windows OK" IS a real green signal; absence of
  the `OK` line + a `Build Summary: N failed` = RED. Read the Build Summary, not just the wrapper exit.

## Key refs

- **ADR-0164** (this program: `.dev/decisions/0164_trap_crash_exception_diagnostics_ux.md`). **D-292** (program
  debt row) + **D-291** (ed25519 motivating case) + **D-165** (JIT trap-code infra). ADR-0156 (no autonomous
  release). ADR-0016 (trap stderr / diagnostic phases).
- Surfaces: `src/cli/run.zig` (`surfaceTrap` interp / `surfaceJitTrap` jit+aot / `runWasmJit` / `runCwasmWasi`),
  `src/api/trap_surface.zig` (`jitTrapCode` / `trapMessageFor` / `TrapKind`), `src/cli/main.zig` (`renderFallback`
  trap path), `src/runtime/trap.zig` (Trap set), `src/engine/codegen/shared/entry.zig` (`[d-165]` print),
  `src/engine/codegen/{arm64/emit.zig,x86_64/op_control.zig}` (trap-code write sites), `src/platform/stack_limit.zig`
  (`[stack_probe]` diag). v1 per-kind msgs: `~/Documents/MyProducts/zwasm/src/cli.zig`.
