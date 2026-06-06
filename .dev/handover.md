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

- ✅ **D-287 DONE** (`cf605260`, ADR-0165): `zir.max_control_stack` 1024→4096 (deeply-nested switch.wasm now
  validates). **D-288** (queued): interp recurses NATIVELY, `frame_buf[256]` is a SEGV guard; real fix = flat/
  trampolined interp OR native-stack-limit check (ADR) — see queue.

- ✅ **ADR-0164 trap-crash-exception-diagnostics PROGRAM COMPLETE** (full detail in debt.yaml D-292/D-293 +
  commits; this session's body of work):
  - **D-293** (slices 1–4d): per-kind JIT trap codes unified arm64+x86_64 via demuxed fixup-channels —
    oob_table(2)/cind_sig(3)/trunc-overflow(8)/invalid_conversion(9)/null_reference(10)/array_oob(6)/cast_failure
    (11); slice-4a also fixed the INTERP surface (null/cast/uncaught were `binding_error`) + a latent arm64
    call_ref→oob_table mis-report. runner_trap_test per kind (JIT+interp parity). GC trampolines/i31 deferred.
  - **D-292 B-core** (`400c7006`, ADR-0166, bundle closed): production internal-fault handler — internal SIGSEGV
    → `zwasm: internal error …` + **exit 70** (vs trap exit 1 / silent crash). POSIX sigaction + Windows VEH
    (`First=1`, the gate caught it losing to Zig's default); `test-internal-fault` 3-host green. Lesson filed.
  - **D-292 C** (`c2650de5`): JIT uncaught throw/throw_ref → uncaught_exception(12); fixed a latent x86_64
    →unreachable(5) mis-report. **D** (`4bdaec59`): trap-UX audit vs wasmtime/wasmer/v1 — clean, ADR-0159-aligned;
    one bug found → **D-294** (JIT call_indirect null-elem → mislabels indirect_call_mismatch; fix = code 13).

## ← LEAD: D-290 build.zig increment done (`b0bb147a`) — remaining D-290 = regen-reverify campaign

**D-290 build.zig swap** (`b0bb147a`): spectest.wat→spectest.wasm now uses `wasm-tools parse` (was `wat2wasm`).
SAFE because it's BUILD-TIME gen (no committed-data drift) + flake.nix:56 provides wasm-tools to the remote nix
shell (`nix develop --command`), so 3-host build is unaffected. test-spec green (9 passed). **Remaining D-290 is
deliberately NOT a quick swap**: regen_spec_2_0_assert.sh (912 LOC bespoke wast2json-parsing + own
normalization), regen_test_data.sh (committed `.0.wasm` bytes), regen_v1_carry_over.sh — each REGENERATES
COMMITTED FIXTURES whose bytes/format may drift under wasm-tools, so each needs a full regenerate-and-reverify
cycle (spec-suite + 3-host green), porting the D-179 normalization baker. That's a focused campaign, not
tail-of-turn — queued, see debt row D-290.

**Prior (still landed)**: D-291 closed (`23874eda` arm64 callee-saved-home spill fix, 3-host green, guard
`9ab34d18`). D-284 DONE (`fbc60815`, `runner.runWasiLenient` unified JIT entry-resolution; nbody jit==interp).
**NEXT — queue**: **D-290 regen campaign** (above); **D-288** (interp native-recursion → flat/trampolined
redesign, ADR-grade, the biggest); **D-279** (Win64 spec-simd heisenbug, non-deterministic, streak 2/5).
0 `now` debts.

**Other status**: ADR-0164 COMPLETE. **D-294 3-HOST GREEN** (`partial`, residuals polish). **D-279 sha256 lead
FALSE** (corrected — zwasm hashes correctly; fixture has a wrong baked-in constant, golden-matched, never gates;
tracker fail→silent, **streak 3/5**; genuine D-279 = `simd_bit_shift` CRASH only, H3 withdrawn; minor: regen
c_sha256_hash fixture → D-290). Queued: D-288, D-284, D-290.

## Queue (time-consuming first, per user directive)

- **D-288** (interp flat/trampolined recursion OR native-stack-limit check; ADR — interp-architecture redesign).
- **D-291** (paused; see top) · **D-292 B-core** (SIGSEGV→internal-error, needs ADR-0070 amend) · C · D.
- Moderate: **D-284** (interp/jit/aot entry-resolution unify) · **D-290** (wabt→wasm-tools hygiene).
- Defer: **D-289** FP/param/stack large arms · **D-286** (fill/init byte-loop) · **D-285** (JIT bulk-memory, ADR-0153).

## Current state

- **Phase 16 (完成形) — open-ended; the loop CONTINUES, no release (ADR-0156).** v0.1.0-scope program is
  thoroughly complete + 3-host green (`deb97903`); ADR-0163 bench+docs program ALL DONE. Tag/publish/cutover are
  manual, user-only — there is no release gate.
- Debt ledger: **1 `now`** (**D-295** — D-291 regression guard, not minimally reproducible). **D-291 RESOLVED**
  (`23874eda`, local test-all GREEN). D-294 → `partial` (3-host green, residuals polish). ADR-0164 COMPLETE. Phase 16.

## Step 0.7 (next resume) — verify remote logs

- **ubuntu**: kicked @`b0bb147a` (D-290 build.zig wasm-tools swap — confirms wasm-tools-built spectest.wasm +
  broad x86_64 suite on the remote nix shell). Next resume: verify `/tmp/ubuntu.log` `OK`.
- **windows**: kicked @`b0bb147a` (cadence FIRED — build.zig is an ABI-touching path per should_gate_windows).
  Verifies wasm-tools is in the windows nix shell + spectest builds. Next resume: verify `/tmp/win.log`
  `[run_remote_windows] OK`. The `verify: FAIL` sha256 line is the known FALSE lead (fixture's wrong constant;
  zwasm's d0e8b8f… is correct). windows red → NOT auto-revert (D7): re-run once → track_heisenbug if flake.
- **Gate note**: `run_remote_windows.sh` `OK` line = real green; `Build Summary: N failed` (no `OK`) = RED.
  `zig-host-hello` exit-42 + `--__selftest-crash` exit-70 "failed command" = EXPECTED, not crashes.

## Key refs

- **ADR-0164** (this program: `.dev/decisions/0164_trap_crash_exception_diagnostics_ux.md`). **D-292** (program
  debt row) + **D-291** (ed25519 motivating case) + **D-165** (JIT trap-code infra). ADR-0156 (no autonomous
  release). ADR-0016 (trap stderr / diagnostic phases).
- Surfaces: `src/cli/run.zig` (`surfaceTrap` interp / `surfaceJitTrap` jit+aot / `runWasmJit` / `runCwasmWasi`),
  `src/api/trap_surface.zig` (`jitTrapCode` / `trapMessageFor` / `TrapKind`), `src/cli/main.zig` (`renderFallback`
  trap path), `src/runtime/trap.zig` (Trap set), `src/engine/codegen/shared/entry.zig` (`[d-165]` print),
  `src/engine/codegen/{arm64/emit.zig,x86_64/op_control.zig}` (trap-code write sites), `src/platform/stack_limit.zig`
  (`[stack_probe]` diag). v1 per-kind msgs: `~/Documents/MyProducts/zwasm/src/cli.zig`.
