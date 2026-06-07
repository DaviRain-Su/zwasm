# ReleaseSafe-only JIT-ABI failures (D-311) — findings

> **Doc-state**: ACTIVE

## Context

The per-chunk gates (`mac_gate.sh`, `run_remote_ubuntu.sh`,
`run_remote_windows.sh`) run `zig build test-all` with **no `-Doptimize`**
→ Zig's `standardOptimizeOption` default = **Debug**. Debug host execution
is ~5–10× slower than ReleaseSafe, hurting integration-test iteration speed
(user-flagged 2026-06-08). ReleaseSafe keeps all safety checks and is the
intended CI mode (ADR-0015); it also exposes a JIT-ABI bug class Debug
hides (D-245 — `check_jit_releasesafe.sh`), because the optimized host
keeps callee-saved registers + poisons undefined memory with `0xaa`.

## Finding (Mac aarch64, `zig build test-all -Doptimize=ReleaseSafe` @c046f4a7)

**Debug = green; ReleaseSafe = 4 fail + 4 crash** (2690/2710 pass). All in
the JIT multi-result / entry-buffer / wrapper-thunk ABI glue:

| Test | Symptom |
|---|---|
| `linker.test.link: 2-function module fn0 calls fn1 returns 7` | SIGABRT — SEGV at `linker.zig:219 entryAddr` (`func_offsets[idx]`, addr 0x0) |
| `linker.test.link+execute: fn0 return_call fn1 returns 7 (ADR-0112)` | SEGV addr `0xaaaa…fa` (undefined memory) at linker.zig:830 |
| `entry.test.entry: f32 local round-trip (local.get 0 f32 via V0)` | Bus error addr `0xaaaa…` |
| `entry_buffer_write … invokeMultiResultNoArgs 3-i32 (ADR-0106 3b)` | expected 100, found 0 (result not written) |
| `entry_buffer_write … () → (i32,i64) (ADR-0106 3c)` | expected 7, found 0 |
| `entry_buffer_write … () → (i64,i32) (ADR-0106 3c)` | expected 2882400018, found 0 |
| `runner_test … invokeMulti 2-result (i32 i32) via entry_buf (ADR-0106 3)` | panic: access union field `i32` while `f32` active (runner.zig:680) |
| `runner_test … invokeMulti 1-param 2-result (arg,42) (D-229)` | expected 5, found 1862664544 (garbage) |

Common thread: the **multi-result entry-buffer + wrapper-thunk return-value
unpacking** reads uninitialized memory / the wrong `Value` union field under
ReleaseSafe. `0xaaaa…` = ReleaseSafe undefined-poison → an uninitialized
read the Debug build happens to get away with. The `union field i32 while
f32 active` is a real type-confusion in the multi-result Value path.

## Plan (D-311 / ADR-0177 bundle: ReleaseSafe-JIT-hardening)

1. Fix the 8 ReleaseSafe-only failures (correctness + memory-safety —
   undefined reads in JIT ABI glue). Likely 1–2 root causes (entry-buffer
   result write + Value-union tagging in multi-result unpack).
2. THEN switch the per-chunk gates to `-Doptimize=ReleaseSafe` for the
   integration steps (`test-all`); keep unit `test` Debug; `gate_merge.sh`
   keeps Debug test-all (merge-checkpoint undefined-fill coverage) + its
   existing ReleaseSafe JIT smoke. Cache keys on optimize → Debug +
   ReleaseSafe caches coexist (no thrash).

Reproduce: `zig build test-all -Doptimize=ReleaseSafe` (Mac). Full log
captured at investigation time; per-test isolation via the named test.
