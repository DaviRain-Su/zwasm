# D-489 — x86_64 JIT miscompile = regalloc dual-counter spill collision (RESOLVED @462ea1e57)

**RESOLUTION**: the LSRA had two independent spill-slot mint counters — the
spans_call path minted `force_spill_threshold + n_spill_minted` while the normal
path minted `n_slots`, which reaches the same `threshold + k` ids once registers
are exhausted. A call-spanning vreg and a normal-path spilled vreg got the same
spill slot while both live → clobber. x86_64-only because its 4-GPR pool makes
normal-path spilling routine; arm64's 8 rarely spill via the normal path. Fix =
unify both spill mints on `n_spill_minted`. Resolved BOTH D-489 (tinygo_json
130→90) AND D-494 (dfr2 defer/recover deadlock → result=42) — shared root.
Diagnostic oracle: `ZWASM_DEBUG=regverify` (overlap verifier in the prod compile
path) + `regalloc.dblassign`/`noreuse` experiments (now removed). Method note
below kept as the investigation audit trail.

---

# D-489 — x86_64 JIT miscompile (the "capture-path" theory is FALSIFIED)

**Symptom**: `tinygo_json.wasm` under JIT on **any x86_64** prints CORRUPT (130B,
Go fmt `name=%s age=%d city=%s` collapses to 23 NUL bytes + `%!(EXTRA …)` +
`roundtrip: FAIL`). CORRECT (90B) on arm64 JIT and on interp (both arches). It is
a **genuine x86_64 codegen MISCOMPILE** — the guest computes a wrong scalar that
becomes a wrong iovec pointer/length (orig analysis: interp issues 3 writes
`#2 off=90512 len=29` + `#3 len=14`; x86_64-JIT issues 2, `#2 off=90928 len=67`
= pointer off by Δ416 + wrong length, leading bytes zero).

## The 2026-06-22 "capture-path correction" was WRONG — re-falsified same day
The prior note claimed direct `zwasm run --engine jit` was correct (90) and only
the stdout-CAPTURE path (`writeSlice` appendSlice) corrupted. **Disproven by
direct measurement at HEAD**:
- arm64 macos native CLI `--engine jit`: **90 ✓**
- Rosetta x86_64-macos CLI `--engine jit`: **130 ✗**
- x86_64-linux (Mac-cross) CLI `--engine jit`: **130 ✗**

Three experiments on `d489-repro` killed the capture theory:
- **A/B** add a syscall to the capture path → still 130 (syscall does not correct).
- **C** make the capture path byte-identical to real-fd (pure syscall, NO
  appendSlice) → STILL 130. So `appendSlice` is NOT the corruptor.
- **memory.grow instrumentation**: stderr empty — **no grow happens** during the
  run → the realloc/stale-vm_base theory is also dead.

The capture vs real-fd "divergence" the prior session saw was an artifact of
comparing a **Rosetta-masked** baseline (it believed Rosetta hid the bug) against
the linux gate. **Rosetta x86_64-macos REPRODUCES it** — the handover's
"Rosetta masks D-489-class bugs" claim is false for D-489.

## What this unlocks
- **FAST LOOP = Rosetta on Mac, no scp**: `zig build -Dtarget=x86_64-macos &&
  <x86-bin> run --engine jit test/realworld/wasm/tinygo_json.wasm | wc -c`
  (90 = fixed, 130 = bug). Cross-check arm64 native = 90.
- Simplest repro is the plain CLI, not `d489-repro` (which still works as the
  scenario-1 exit gate).

## Standing root-cause narrowing (from the original, NOT superseded)
Wrong scalar VALUE upstream in Go's fmt/reflect, x86_64-only → spill-pressure
class (x86_64 has 4 allocatable GPRs vs arm64's 8). NOT a D-490 stage-alias bug
(audited). emitMemOp EA in ISOLATION ruled out (bounded fixtures clean). Needs
**dynamic value trace of the real tinygo_json run** (diff jit-vs-interp store
addrs / stack values), not more synthetic fixtures — now runnable on Rosetta.

## TIPS (still valid)
- gdb 15.1 native on ubuntu; rr via `nix-shell -p rr`. lldb has no Zig plugin.
- `ZWASM_DEBUG` is a NO-OP in the `zwasm run` CLI (gate not init'd there); works
  in the `d489-repro` exe (Debug). `wasi.iovec` channel = host-received iovec
  ground truth (engine-independent), already wired in `fd.zig:fdWrite`.
- tinygo seeds a map via random_get → raw linear-mem fingerprints differ run-to-run.
