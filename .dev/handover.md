# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## NEVER-IDLE PROTOCOL (read first — user-directed 2026-06-06)

The loop **NEVER idles in "minimal turns."** The 完成形 v0.1 surface is done, but the user **UNBLOCKED v0.2 AND
v0.3 feature work** (2026-06-06) — "AIが思いのほか早いのでどんどんやろう." **Work priority each resume:**
1. **v0.2 / v0.3 features** — the primary forward track now (ROADMAP §17 / `.dev/proposal_watch.md`: threads,
   wide-arith, relaxed-SIMD, custom-page-sizes, component-model, …). Survey → sequence → TDD-implement. **No
   release/tag ever** (ADR-0156 stands — user reconfirmed "タグは切らない").
2. When between features OR a feature is gated → **sweep `.dev/remaining_sweep.md`** (Bucket A ledger-prune → B
   actionable-low-value → C deferred) — never idle, sweep the leftover systematically.
3. **D-279 + similar are NEVER "left alone"** (user: "放置せず常にシステムは動作するように") — keep it actively
   progressing: the H3 diagnostic is deployed; re-kick windows when work lands so a reproduction is always being
   hunted; verify the signal at every Step 0.7.
Idle/minimal turn is now a BUG, not a steady-state. Dogfooding (D-264) is **DONE** (cw v1 side succeeded).

## Current state

- **Phase 17 (v0.2) IN-PROGRESS** (ADR-0168). DONE+**3-host-confirmed**: **17.1-atomics @9eb84833** ·
  **17.2-wide-arith @231d4536** · **17.3-custom-page-sizes @cd0de2dd** · **17.4-relaxed-SIMD @08342ec5**
  (delta 0→**20 ops** JIT both arches; +ADR-0169 per-arch hardware semantics; emit_test probe → `memory.discard`).
  17.4 verified Mac + ubuntu @758ff210 + **Win64 @758ff210** (dot_add_s=110/dot_s=3/q15mulr=8192,32767; gate
  recorded; D-279 silent streak=3; 1-failed=D-028 IPC flake, 0 assertions). **Wasm-3.0 100%-spec is COMPLETE —
  no lurking reserved-but-unimpl Phase-5 ops** (audited zir_ops enum 2026-06-07; only stack-switching/
  memory-control stubs remain = Phase-3).
- **relaxed-SIMD official spec corpus DONE @8ef2e752 + x86 dot fix @b8c1c31d** — 7 upstream `.wast` in
  simd_assert_runner with `(either)` support (ADR-0169); **13420 passed, 0 fail** on arm64 AND x86_64 (Rosetta-
  verified). The corpus caught a REAL x86 bug (relaxed_dot passed `a` as PMADDUBSW's unsigned operand → wrong for
  a<0; fixed by swapping → b=unsigned/a=signed). ubuntu was RED@5d098216 (3 fail) → forward-fixed (impl bug, not
  revert). dot_s_neg edge fixture guards the sign boundary. ubuntu re-confirm pending @b8c1c31d.
- **atomics assert_trap un-skipped @aa6e1a76 (D-301) → found D-303** — the distiller blanket-skipped ALL atomic
  assert_trap with a FALSE reason ("argparse"). Un-skipped: added `(i32,i64,i64)` arm to nonSimdRunAssertTrap +
  emit real directives. **247 → 282 pass** (+35 RMW/cmpxchg unaligned-traps now live). The un-skip EXPOSED a REAL
  JIT bug **D-303 FIXED + DISCHARGED @5b0db8e1**: inline atomic load/store omitted the unaligned-trap check the
  interp has; added a code-14 `unaligned_atomic_fixups` stub both arches. corpus **292 pass / 0 D303-skip**,
  3-host confirmed (arm64 Mac + x86_64 Rosetta + **x86_64 ubuntu @fac174b5**); Win64 codegen-confirmed (TEST/JNE
  bytes in dump, 0 did-not-trap) — its 292 summary blocked only by the unrelated D-279 crash. 2 wait skips remain.
- **D-231 leak FIXED @96fcdf9f** — running check_build_dce's nm-grep on a cross-compiled x86_64 v1_0 binary
  found 3 dead `wasm_3_0` codegen symbols surviving DCE (x86 legacy-switch br_on_null cohort lacked the
  `if (comptime wasm_v3_plus)` guard arm64 had). Fixed; v1_0 x86 wasm_3_0 3→0. REMAINING D-231 = wire the gate
  (cross-nm x86 in check_build_dce; mechanism validated). D-209 memory64 >4GiB = correctly measure-first-deferred
  (hot-path branch cost, no consumer). D-259 spillBytes = measure-first.
- **v1-parity audit (2026-06-07, user-directed)** — v1 advertised "Full Wasm 3.0 (18/18) + Component Model/WASI-P2
  + threads + branch-hinting". v2 MATCHES all Wasm-3.0-core + atomics/wide-arith/custom-page/relaxed-SIMD +
  multi-memory(parse/validate/interp). **v2 gaps vs v1-claims**: (1) **Component Model + WASI Preview 2** = the
  BIG one (v1 claimed complete; v2 deferred to v0.2.0 — the v0.2 entry per proposal_watch; multi-session campaign,
  needs survey+ADRs); (2) **branch-hinting** = D-302 (advisory custom-section, no conformance effect, likely
  already a no-op skip — quick verify); (3) **multi-memory JIT** = §14-deferred allowlist (~458 skips;
  parse/interp done).
- **NEXT — ordered (correctness-first)**:
  1. **d-163-jit dump cleanup (this turn)** — D-163 is CLOSED (not in ledger) but `spec_assert_runner_base.zig:3160`
     still `if (true)` dumps every compiled func's bytes on EVERY test-all (huge noise + the only D-279 lead).
     Env-gate it → removes noise AND probes whether D-279 persists without the dump (decisive isolation).
  2. **D-301 residual** mark scratch shared for wait32/64 (2 nonshared skips) — `base.growable_memory` shared flag.
  3. **D-231** wire cross-nm x86 DCE gate into `check_build_dce.sh` (mechanism validated; ELF-nm in nix).
  4. **D-302** verify a `metadata.code.branch_hint` module parses+runs on v2 (custom-section skip path).
  Then the BIG forward track = **Component Model / WASI-P2 survey** (the real v1-parity completion + v0.2 entry).
  **Correctly DEFERRED (do NOT clear)**: D-209 (hot-path/exotic), D-259 (W54-ABI-risk/zero-perf), D-300
  stack-switching (Phase-3 unstable). **D-299** (inline atomic misalign-trap, x86_64 W^X) env-constrained. No tag.
- Debt ledger: **54 entries** (D-303 discharged @5b0db8e1). D-299 `now`. Never idle.
- **D-279 BREAKTHROUGH @92cf7979** — the decisive Win64 RED finally landed (@16fc1bb3, the run the user cut off):
  `zwasm-spec-wasm-2-0-assert` exit-3 with the `[d-279-veh] STACK-OVERFLOW` diagnostic PRESENT but NOT firing →
  **H3 REFUTED**. `[W4 DIR]` raw-beacon pinned crash module = **`address.2.wasm` (NON-SIMD i32/i64 load/store)** in
  the NON-SIMD runner → **H4 CONFIRMED: NOT a SIMD bug** (12-month framing wrong). ZERO `[d-279-veh]` despite all 3
  armed/overflow diags → crash takes the SILENT **unarmed** branch (H6). Landed UNARMED-FATAL diagnostic
  (`windows_traphandler.zig:191`, code+RIP for fatal-class, guard-page-filtered). `track_heisenbug win64-testall
  segv` streak 4→0. Next Win64 batch self-IDs the faulting RIP (compile vs runtime vs interp) or proves H5
  (non-exception abort). Full enumeration in D-279 debt row.

## 完成形 v0.1 surface COMPLETE (history — 2026-06-06)

All three surface audits DONE: CLI→**D-295** (~85% + intentionally lean, declines per ADR-0159 ≠ gaps). C-API→
**ZERO gaps** (D-296; 293/293). Zig-API→**COMPLETE** (D-296; `Module.imports/exports` + `Memory.grow/sliceAt` +
`Engine.linker()` + `Linker.defineInstance`; `docs/zig_api_design.md` synced). Memory-safety ALL areas swept
**SOUND** (D-297 cross-module aliasing; WASI fd lifecycle; 3 audit "CRITICAL" labels dissolved under verification
→ discipline: always adversarially verify audit criticals; lesson `fd0a1914`). v0.2 tractable features all DONE
(atomics/wide-arith/custom-page/relaxed-SIMD); forward track = remaining_sweep + completeness (NEVER-IDLE above).

**D-279 (Win64 JIT heisenbug — NO LONGER "SIMD")**: H1/H2/H3 REFUTED; NON-SIMD. NEW @fac174b5: crashed BOTH
threads-assert AND wasm-2-0-assert (exit-3, 0 did-not-trap, NO `[d-279-veh]` despite UNARMED-FATAL armed) →
**crash is at JIT-COMPILE/d-163-jit-DUMP time, NOT execution** (all VEH diagnostics are execution-path → can't
see it). H7 = the always-on `[d-163-jit]` `std.debug.print` dump (base.zig:3160 `if(true)`, D-163 closed) is the
suspect — env-gating it (next) isolates dump-I/O-trigger vs real compile crash. streak→0 (segv). Full row.

**Blocked / parked**: 31 blocked-by (call_ref §10.R / D-177 WASI-config / D-178 Global-Memory / future proposals).
**D-290** = 3 distillers direction-gated (wasm-tools↔wabt divergence; wabt stays). **D-264** dogfooding gated.

## Step 0.7 (next resume) — verify remote logs

- **ubuntu**: re-kicked each turn (D6 always). Verify `[run_remote_ubuntu] OK` in `/tmp/ubuntu.log`. Red →
  auto-revert (D3; first-resume + non-code-gap exceptions apply).
- **windows**: BATCHED (D8). @fac174b5 RED = D-279 crash (threads + wasm-2-0-assert exit-3, 0 did-not-trap →
  D-303 NOT regressed; recorded segv, NOT reverted per D7). After the d-163-jit-dump env-gate lands, re-kick:
  if exit-3 persists WITHOUT the dump → D-279 is a real compile/execution crash (not dump I/O); if it stops →
  dump I/O was the trigger. threads-assert **292 pass** on Win64 still the D-303 Win64-summary confirmation.
- **Gate note**: `OK` = green; `Build Summary: N failed` (no OK) = RED. EXPECTED non-failures: `zig-host-hello`
  exit-42, `--__selftest-crash` exit-70, sha256 `verify: FAIL` (fixture-wrong-constant FALSE lead).

## Key refs

- **ADR-0156** (no autonomous release) · **ADR-0153** (rework campaign) · **ADR-0076** (3-host cadence D6/D7/D8)
  · **ADR-0168** (Phase 17 v0.2 line) · **ADR-0109** (native Zig API) · **ADR-0086** (dispatch_collector migration).
- **D-296** = surface-audit record (C/Zig-API) · **D-297** = cross-module memory-safety audit · **D-279** =
  Win64 SIMD heisenbug (instrumented) · `.dev/proposal_watch.md` = v0.2.0 feature backlog.
