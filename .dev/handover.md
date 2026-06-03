# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **11 IN-PROGRESS — WASI 0.1 full + bench infra** (Phase 10 DONE; §11 table: 11.0✓ / 11.1 WASI / 11.2
  bench / 11.3 SIMD-gap ✓ / 11.4→Phase 15 / 11.P). §11.P windowsmini reconcile surfaced a **systemic Win64 JIT
  bug** → bundle (below).
- **§11.P windowsmini test-all** (first since §11.1, against `00cd6d1f`): fd.zig compile fix WORKED (Windows test
  build compiles + runs); spec suite + WASI all PASS. But the unit-test layer FAILED: `run test 2213 pass, 12 fail,
  19 crash`. Two named aborts, both **Phase-10 JIT features on the Win64 ABI for the first time** (windowsmini is
  phase-boundary-only, so Win64 JIT EH/GC was NEVER exercised before): (1) `throw_trampoline` test SEGV; (2)
  `runner_gc_test … struct.new_default + ref.is_null → 0` returns 1 (wrong).
- **ROOT CAUSE (subagent-confirmed, unifying)**: x86_64 code calling a `callconv(.c)` helper **hardcodes SysV arg
  regs (RDI/RSI/RDX/RCX)** instead of the Cc-aware `abi.current.arg_gprs[]`. On Win64 the helper reads args from
  RCX/RDX/R8/R9 → garbage → `jitGcAlloc` returns null → `ref.is_null`=1 (BUG 2, production, HIGH conf, **17 GC/EH
  emit files**). BUG 1 = the `throw_trampoline` TEST wrapper `invokeTrampolineWith` is SysV-only (tag→RDI, no
  `.windows` arm); the *production* `.windows` trampoline arm is correct (test-only fix, MED conf).
- **Fix is SysV-no-op-safe**: `abi.current.arg_gprs[0..3]` == `{rdi,rsi,rdx,rcx}` on SysV (abi.zig:60 + test),
  so swapping literals → `arg_gprs[N]` is byte-identical on Mac+Linux (existing byte tests prove it) and only
  corrects Win64. Regalloc pool ∩ arg_gprs = ∅ (comptime-enforced) → no shuffle-collision hazard.
- **Prior gates GREEN**: ubuntu test-all `173ca8af` OK; Mac local green. windowsmini = the only Win64 host
  (~90min/run, SSH, NO local Win64 execution → cross-compile-check only).

## Active bundle

- **Bundle-ID**: 11.P-win64-jit-arg-marshal
- **Cycles-remaining**: ~1 (cycle-1 `f725dcd6` + cycle-2 `97b95bc9` DONE; remaining = throw_trampoline Win64
  crash fix + windowsmini-green confirm)
- **Continuity-memo**: **run-1 (cycle-1) VALIDATED on windowsmini**: `run test` 2213→2237 pass, **12 fail→0**
  (≤4-arg GC value bugs cleared — arg_gprs approach sound), 19 crash→7. CYCLE-2 (`97b95bc9`, D-248): 6 ≥5-arg
  array ops Win64 stack-spill (`gc_marshal.routeArg` + `computeOutgoingMaxBytes` reserves Win64 shadow(32)/
  stack(48) for GC ops; SysV byte-identical) → fixes the `array.fill`-class crashes. throw_trampoline Win64 crash
  FIX LANDED (`3c19f638`): root cause = RSP 16-byte misalignment — the test wrapper's `pushq %rbp` enters the
  trampoline at ≡0 mod 16 but production JIT-CALL enters at ≡8 → trampolineCore reached misaligned → Win64
  ABI-strict aligned-SSE prologue faults (SysV tolerates). `subq/addq $8` in the `.windows` wrapper arm restores
  parity (test-only, Win64-arm-only). **run-2 (vs `3c19f638`) verifies BOTH cycle-2 array ops + the parity fix.**
  Medium-high conf on parity; if it still crashes → in-body RSP parity differs, add an RSP-capture diagnostic.
- **Exit-condition**: windowsmini `test-all` → `[run_remote_windows] OK` (0 crash for GC/EH JIT tests). D-248 =
  the array-op part; throw_trampoline = the EH-wrapper part (both in this bundle).

## Next task (autonomous)

**NEXT** = (1) diagnose + fix the `throw_trampoline` Win64 test crash (trace RSP alignment through wrapper →
production `.windows` trampoline arm :357 → trampolineCore → dispatchThrow; the 0xffff… SEGV). (2) kick windowsmini
run-2 vs `97b95bc9` (validates cycle-2 array-op fixes — expect the `array.fill`-class crashes gone) — fold in the
throw_trampoline fix if found first. (3) On windowsmini fully green: discharge D-248 + close the bundle, flip
§11.1/§11.2/§11.3 + §11.P `[x]`, run `audit_scaffolding` (MANDATORY phase-boundary), open Phase 12.

## Deferred / open debt (none a Phase-11 blocker except the bundle)

- **D-245** host→JIT callee-saved: arm64 + x86_64-SysV no-arg-void FIXED + regression-gated; win64 + arg'd variants
  = remainder. (Related family to the new Win64-arg-marshal bundle but distinct: D-245 = caller-saved preservation;
  bundle = arg-reg routing.)
- **D-246** §11.3 → Phase 15: arm64 dot/extmul JIT-emit hole. **D-211** GC-on-JIT precise rooting → Phase 15.
- **D-238** x86_64-SysV cross-instance EH thunk. **D-244** SIMD interp-free by design (partial). **D-210** /
  **D-234** / D-237 / D-229 / D-231 / D-204 / D-209 / D-213 (note).

## Step 0.7 (next resume)

windowsmini run-2 kicked vs `3c19f638` (cycle-2 array-op stack-spill + throw_trampoline parity fix). Step 0.7
next cycle: read `/tmp/windows.log` → `run test` crash count should drop to ~0 (the `array.fill`-class crashes
gone via D-248; `throw_trampoline` uncaught-path PASS via the parity fix). If `[run_remote_windows] OK` →
discharge D-248 + close the bundle. ubuntu+Mac already GREEN for the SysV-no-op changes (run-1 + local).

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile-check: `zig build test
-Dtarget=x86_64-windows-gnu` (compile-only; "unable to execute" run-error = compile PASSED). ReleaseSafe
`--engine=jit` repro: `zig build -Doptimize=ReleaseSafe && zig-out/bin/zwasm run --engine=jit <fixture>`.

## Key refs

- ROADMAP line 83 (4-platform JIT incl. x86_64-windows = IN SCOPE). `src/engine/codegen/x86_64/abi.zig` (current/
  sysv/win64 namespaces; arg_gprs). `src/engine/codegen/shared/throw_trampoline.zig`.
- Lessons: `2026-06-03-windowsmini-reconciliation-catches-os-only-compile-drift` (the phase-boundary-drift rule
  that predicted this); + a new Win64-arg-marshal lesson (file at commit).
