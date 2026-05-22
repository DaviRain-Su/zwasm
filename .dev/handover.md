# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing discipline:
> [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Fresh-session start here

**Authoritative remaining-work source**:
[`.dev/phase9_close_master.md`](./phase9_close_master.md).

**Mandatory before any §9.x [x] flip**: run

```sh
bash scripts/check_phase9_close_invariants.sh --gate
```

(per `.claude/skills/continue/SKILL.md` Resume Step 5d +
ADR-0104 + `.claude/rules/phase9_close_invariants.md`).

**Current gate state**: **17/18 passed**. Sole remaining FAIL:
**I1b — D-163 SKIP-WIN64-CALL-INDIRECT-TRAP**.

## Active task — D-163 close drive

**Step 0 (first action this session)**: read `/tmp/win.log`.
A `bash scripts/run_remote_windows.sh test-all` run was kicked
in background at the end of the prior session (2026-05-23
~06:30) to capture the post-Phase-2'l Win64 state. The log
contains:

- Whether Phase 2'a → 2'l Win64 path (cycles 2'i + 2'j + 2'k
  wrappers + body MEMORY-class) executes correctly at runtime.
- Specific failures (if any) on the wasm-2.0 corpus's
  `assert_trap as-call_indirect-last ()` fixture in
  `call/call.0.wasm` (= D-163 reproduction).
- The exact crash signature (return code, stderr).

**Decision tree from the log**:

1. **windowsmini test-all all-green** → unexpected; verify
   D-163 SKIP arm was actually removed + re-check the
   wasm-2.0 corpus path. Possibly D-163 dissolved.
2. **windowsmini crashes at the D-163 fixture** → proceed
   with the spike's ranked-hypothesis investigation:
   - H2 (VEH unwinder confusion) CORE
   - H1 (ADD-RSP shadow-space mismatch) SUPPORTED
   - H3 (R15↔entry_arg0_gpr) PLAUSIBLE
   - Use the spike doc's distinguishing probes; SSH back
     into windowsmini for lldb-attach or specific dumps.
3. **windowsmini fails elsewhere first** (Phase 2'a → 2'l
   regression) → fix that path before D-163 resumes.

windowsmini is reachable via SSH alias (verified 2026-05-23).
Per ADR-0049 only the per-chunk test gate is deferred;
investigation work via windowsmini is autonomous-eligible.

## Work landed this session (2026-05-23)

ADR-0106 cycle 3e Phase 2'a → 2'l (full implementation chain:
per-arch wrapper emit SysV+arm64+Win64 × 2-int+3-int shapes,
linker hookup, compileWasm wiring, entry helpers Win64-routing,
body-side cycle 2c MEMORY-class Win64 extension, SKIP arm
removal). D-094 + D-164 closed. 2 latent wrapper bugs caught
via e2e tests (arm64 X30 + x86_64 RBX). Lesson:
`2026-05-23-wrapper-thunk-stack-save-not-callee-saved.md`.
D-163 wasmtime+Wasmer survey + spike + debt refinement.

## Active `now` debts: none.

## See

- [`phase9_close_master.md`](./phase9_close_master.md) (§5.1
  D-163 only remaining; §6 exit predicate).
- `private/spikes/d-163-win64-call-indirect-trap/` (gitignored;
  5 hypotheses + distinguishing probes).
- ADR-0104 / 0105 / 0106 / 0078.
- `.dev/debt.md`: D-163 row body refined with hypothesis
  ranking.
