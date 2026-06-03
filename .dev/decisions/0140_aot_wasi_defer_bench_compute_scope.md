# 0140 — WASI-in-AOT deferred (JIT parity, D-244); §12.3b closes at the compute subset; §12.4 bench re-scoped to zero-import compute fixtures

- **Status**: Accepted (2026-06-03; autonomous re-scoping per ADR-0132)
- **Date**: 2026-06-03
- **Author**: claude (autonomous Phase-12 re-scoping)
- **Tags**: Phase 12, §12.3b, §12.4, AOT, `.cwasm`, WASI, imports, bench, D-244, ADR-0136, ADR-0139, ROADMAP §18
- **Amends**: ROADMAP §12 (§12.3b scope/close, §12.4 bench fixture scope); closes bundle `12.3b-stateful-cwasm`
- **Authorised-by**: ADR-0132 (autonomous re-scope when a row's exit references genuinely-later/parity-blocked work)

## Context

§12.3b's planned cycle-2b was "WASI host imports in the AOT standalone runtime" — the last piece to run a real
v1-class (tinygo/shootout) guest AOT, which §12.4 (cold-start bench) was re-sequenced behind (ADR-0139).

Two findings (this cycle's survey + empirical check) change the picture:

1. **`--engine=jit` is itself compute-only** — no WASI I/O (ADR-0136; the D-244 "d-3 JIT-WASI" residual is
   deferred). `runVoidExport`/`runWasmJit` wire NO WASI host; `wasi/jit_dispatch.zig`'s `proc_exit` just sets
   `trap_flag` (discards the exit code). So a WASI-importing guest runs on **neither** the JIT-invoke path nor
   the AOT path. AOT lacking WASI is **parity with JIT, not a regression**.
2. **Shootout v1-class fixtures all import `proc_exit`** (verified in the binaries) → they trap on both paths.
   Conversely, **zero-import compute fixtures run AOT today** on cycle-1/2a: all 12 SIMD corpus fixtures
   (`bench/runners/wasm/simd/*.wasm` — memory + SIMD compute, no imports) `zwasm compile` + `zwasm run` to exit
   0 (verified 2026-06-03 at `cf32e57a`).

So WASI-in-AOT is a multi-cycle bundle (serialise import metadata + build host-dispatch + a WASI Host in the
standalone runtime) whose value is gated on the JIT side ALSO getting WASI — doing it AOT-first would diverge
from parity. And §12.4's "v1-class hyperfine fixtures" exit is unsatisfiable while WASI-importing fixtures run on
no path.

## Decision

1. **Defer §12.3b cycle-2b (WASI-in-AOT)** — land it WITH the JIT-WASI work (D-244 d-3), so both invoke paths
   gain WASI together (no AOT/JIT divergence). Tracked as a debt row.
2. **Close bundle `12.3b-stateful-cwasm` at cycle-2a** (pivot). The achievable AOT scope given JIT parity =
   STATEFUL COMPUTE: linear memory + data segments (cycle-1b) + globals (cycle-1a) + table 0 + element segments
   / `call_indirect` (cycle-2a). Delta achieved + verified: real memory/globals/table compute modules (incl. the
   12-fixture SIMD corpus) run AOT end-to-end. §12.3b row → `[x]` for this scope; imports forward-ref'd.
3. **Re-scope §12.4 bench fixtures**: "v1-class hyperfine fixtures" → **compute (zero-import) fixtures** — the
   SIMD corpus + any zero-import `bench/` compute kernels. The cold-start delta (AOT load+first-call vs JIT
   compile+first-call) is meaningful on these (representative compute, memory-using), and they run on BOTH paths
   today. WASI-importing-fixture bench defers with the WASI work. §12.4 is **unblocked** (no longer waiting on a
   WASI cycle).

### Rejected alternatives

- **Wire WASI into AOT before the JIT has it** — divergence + duplicated effort (the host-dispatch/WASI-host
  build would be rebuilt when JIT-WASI lands); a big bundle for no parity gain (JIT can't run WASI either).
- **Keep §12.4 blocked on WASI-importing v1-class fixtures** — unsatisfiable (they run on no path); the
  cold-start signal is fully available on compute fixtures now.

## Consequences

- ROADMAP §12.3b row → `[x]` (compute stateful scope: memory/globals/tables); imports note → deferred row.
- §12.4 row: "v1-class" → "compute (zero-import) fixtures (SIMD corpus / §11.3)"; un-blocks (drop the §12.3b
  dependency).
- New debt row: WASI-in-AOT standalone runtime (serialise imports + build host-dispatch + WASI Host), discharge
  WITH the JIT-WASI d-3 work (D-244).
- Bundle `12.3b-stateful-cwasm` closed; handover Active-bundle section removed.
- No code change in this ADR (ROADMAP + debt + handover).

> **Doc-state**: ACTIVE
