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

**Current gate state**: **17/18 passed** (was 16/18 at
2026-05-23 session start; 2026-05-23 advanced via ADR-0106
cycle 3e Phase 2'a–2'l implementation chain). Sole remaining
FAIL: **I1b — D-163 SKIP-WIN64-CALL-INDIRECT-TRAP**.

## Bucket-3 stop — user touchpoint required

All autonomous prep walked; loop stops without re-arm.

**Gating user touchpoint(s)**:

- **D-163 Win64 JIT call_indirect trap path investigation**
  requires actual Win64 runtime inspection (lldb-attach via
  windowsmini OR a Win64 test machine). Autonomous probe via
  Mac cross-compile + llvm-objdump is feasible but the byte-
  sequence analysis can't distinguish the leading hypotheses
  (H1 ADD-RSP shadow-space mismatch vs H2 VEH unwinder
  confusion vs H3 R15↔entry_arg0_gpr mapping) without runtime
  probe data. After D-163 fix lands + windowsmini reconciliation
  green, gate flips 18/18 and §9.13-0 / §9.12-F / §9.12-I /
  §9.13 are eligible for `[x]` per ADR-0104.

**Autonomous prep walked this resume** (do not re-walk):

- **Reference-repo enrichment**: wasmtime (Cranelift x64 +
  Winch) + Wasmer singlepass surveyed 2026-05-23. Findings in
  `private/spikes/d-163-win64-call-indirect-trap/README.md`:
  mature engines emit Win64 `.pdata + .xdata` unwind info per
  JIT function (zwasm v2 does not); wasmtime uses VEH context-
  rewrite for traps (zwasm v2 uses trap-stub RET); wasm-1.0
  `unreachable` works on Win64 with same RET pattern (refutes
  "unwind absence" as sole cause).
- **Throwaway spike**: `private/spikes/d-163-win64-call-
  indirect-trap/` running. 5 numbered hypotheses + distinguishing
  probes; refined ranking H2 (core) → H1 (supported) → H3
  (plausible) → H4/H5 (low).
- **ADR Consequences refinement**: ADR-0078 SKIP taxonomy row
  already cites D-163 + lists codegen-bug spike as the close
  path. No further refinement needed.
- **WebFetch upstream**: not strictly walked; wasmtime
  reference-repo survey covered the relevant MSDN Win64 ABI
  considerations (UNWIND_INFO + VEH mechanics).

**To resume**: get the cycle started on a Win64 host (or
windowsmini) with the runner under lldb; capture PC + register
state at crash point; match against the 5 hypotheses; then
re-invoke /continue with the probe results in handover.md
"Active task". Alternative autonomous path:
write a synthetic Zig spike (`private/spikes/d-163-.../probe.zig`)
that emits the bounds-check + trap-stub bytes for the
`call_indirect` OOB fixture, cross-compile to
`x86_64-windows-gnu`, and inspect via `llvm-objdump -d`. The
spike doc enumerates which hypotheses each probe distinguishes.

## Work landed this session (2026-05-23 cycle)

ADR-0106 cycle 3e: Phase 2'a/2'b/2'd/2'e (per-arch wrapper emit
for SysV + arm64 covering 2-int + 3-int shapes), Phase 2'f
(`JitModule.entry_buf` + `thunk_offsets`), Phase 2'g
(`linker.linkWithThunks` + `WrapperSpec`), Phase 2'h step 1
(compileWasm wires linkWithThunks), Phase 2'h step 2 (entry
helpers Win64-route via `module.entry_buf` + `invokeBufWin64NoArgs`),
Phase 2'i (Win64 2-int wrapper), Phase 2'j (Win64 3-int
MEMORY-class wrapper with XCHG RCX↔RDX), Phase 2'k (body-side
cycle 2c MEMORY-class extended to Win64 — gate + Cc-aware
rt_src_gpr/hidden_ptr_gpr), Phase 2'l (SKIP-WIN64-MULTI-RESULT
arm removed). D-094 + D-164 closed. Two latent wrapper bugs
caught + fixed via end-to-end tests (arm64 X30-not-saved +
x86_64 RBX clobbered). Lesson recorded:
`2026-05-23-wrapper-thunk-stack-save-not-callee-saved.md`.
D-163 wasmtime+Wasmer survey + spike + debt row refinement
(`3b456290`).

## Active `now` debts

(None — D-094 + D-164 discharged this session.)

## See

- [`phase9_close_master.md`](./phase9_close_master.md).
- ADR-0104 (Phase 9 honest-accounting reframe).
- ADR-0105 (JIT-prologue stack-probe — D-162 closed prior).
- ADR-0106 (multi-result ABI redesign — cycles 1 through 3e
  Phase 2'l landed this session).
- ADR-0078 (SKIP taxonomy — only `SKIP-WIN64-CALL-INDIRECT-TRAP`
  arm remains; closes with D-163).
- `private/spikes/d-163-win64-call-indirect-trap/` (gitignored
  hypothesis enumeration + probe ranking).
- `.dev/debt.md`: D-163 row body refined with hypothesis
  ranking.
