# 0164 — Trap / crash / exception diagnostics & UX: completeness audit + unification

- **Status**: Accepted (2026-06-05; user-directed program — chat 2026-06-05).
- **Date**: 2026-06-05
- **Author**: claude (user directive, paraphrased: "trap をユーザーフレンドリーに。
  クラッシュとの区別(理想はクラッシュゼロ)、例外処理との区別など、他の wasm 処理系や
  zwasm v1 時代の配慮で不足している点がないか点検し、足す。時間のかかるものをクリア
  セッションの先頭から。")
- **Tags**: diagnostics, trap, crash, exception-handling, UX, completeness,
  §16, completion-finalization, release-readiness, ADR-0156
- **Amends**: nothing normative — Phase-16 completion-finalization (§16: clean +
  full-featured + user-facing quality). Routine per §18.

## Context

The runtime's error reporting is **opaque and inconsistent across engines**, and
the trap / host-crash / exception boundary is muddy. Surfaced concretely while
debugging **D-291** (ed25519 under `--engine jit`): the CLI printed a bare
`Trap` with no kind, and a `[stack_probe]` diag fired on a NON-stack trap — it
took an lldb session just to establish "this is a clean wasm trap, not a SIGSEGV,
not stack exhaustion." A user (or maintainer) cannot act on `Trap`.

Findings (current state):

1. **Internal trap kinds exist** (`src/runtime/trap.zig` `Trap` error set:
   `Unreachable`, `OutOfBoundsLoad/Store/TableAccess`, `IndirectCallTypeMismatch`,
   `CallStackExhausted`, …) and the **interp** path surfaces them
   (`src/cli/run.zig surfaceTrap` — "print the kind + message on stderr").
2. **The JIT path does NOT** — `runWasmJit` propagates a generic `Error.Trap`;
   the JIT trap stub records a numeric trap-code to a runtime slot (D-165 infra)
   but it is never mapped back to the specific `Trap` kind / message. So JIT
   traps print bare `Trap`. AOT likely similar.
3. **zwasm v1 HAD per-kind CLI messages** (`~/Documents/MyProducts/zwasm/src/cli.zig`:
   "unreachable instruction executed", "call_indirect type mismatch", …) — so
   this is a **v1-parity regression** in the JIT/CLI surface.
4. **crash vs trap is not clearly distinguished**: the `[stack_probe]` diag
   prints on *every* trap (not just stack-overflow), reading as a stack problem
   when it isn't; and a zwasm-internal fault (a real SIGSEGV / `@panic` = a BUG)
   is not clearly separated from a defined wasm trap.
5. **No wasm backtrace** (wasmtime prints a function-index/name chain); zwasm
   gives no location context.
6. **Exception (Wasm EH) vs trap**: an uncaught exception/tag should report
   distinctly from a trap; current distinction unaudited.

## Decision

Open a user-directed **trap/crash/exception diagnostics & UX program**. Run as
Phase-16 completion work; **investigation/audit FIRST** (it spans engines), then
fix. Suggested workstreams (audit drives the exact list):

- **A — Trap-kind surfacing across ALL engines.** Wire the JIT (and AOT) trap
  path to map the recorded trap-code → the specific `Trap` kind → the SAME
  user-friendly message the interp's `surfaceTrap` emits. Outcome: `interp` /
  `jit` / `aot` all print e.g. `wasm trap: out of bounds memory access` /
  `unreachable executed` / `call_indirect: type mismatch` / `call stack
  exhausted`. Recovers the v1 CLI coverage.
- **B — crash vs trap distinction (ideal: zero host crashes).** A *defined* wasm
  trap is normal (clean exit, clear message); a zwasm-internal fault (SIGSEGV /
  `@panic` / unreachable Zig path) is a BUG and MUST report as an INTERNAL ERROR,
  visibly distinct from a wasm trap, never as `Trap`. Restrict the
  `[stack_probe]` diag to genuine stack-overflow traps (it currently fires on
  all). Audit the host-fault catch paths so the host never crashes on guest
  input the spec says should trap.
- **C — Exception (EH) vs trap.** Ensure an uncaught wasm exception/tag reports
  distinctly from a trap (different message; correct exit semantics).
- **D — Audit vs other runtimes + v1.** wasmtime (rich messages + wasm
  backtrace), wasmer, WasmEdge, and zwasm v1 — enumerate what zwasm lacks
  (kind messages [A], backtrace, exit-code conventions, stderr format). Feed
  gaps back into A–C. Optional stretch: a minimal wasm backtrace
  (func-index chain) behind the existing trap infra.

### Boundary — ADR-0156 still holds

Diagnostics/UX work; no release/tag/version. Pure §16 completion quality.

## Consequences

- New investigation/findings doc + multi-engine diagnostic wiring (A) + the
  crash/trap separation (B). Likely a debt row per workstream; D-291's repro
  (ed25519) becomes a beneficiary (its trap kind would be one command away).
- This is **time-consuming** (cross-engine audit + multi-site wiring), so it is
  positioned at the FRONT of the clean session per the user directive, ahead of
  easy/speculative items (D-289-FP arms, D-286 fill/init, D-290 hygiene).

## References

- D-291 (the JIT generic-`Trap` that motivated this); D-165 (JIT trap-code infra
  to map from). `src/runtime/trap.zig` (Trap set), `src/cli/run.zig`
  (surfaceTrap, runWasmJit), `src/cli/diag_print.zig`. v1: `~/Documents/MyProducts/
  zwasm/src/cli.zig` (per-kind messages). `src/platform/stack_limit.zig`
  (stack_probe diag to scope to stack-overflow only). ADR-0156, §16.
