---
paths:
  - "src/**"
  - "test/**"
  - "bench/**"
  - ".dev/reliability-*"
---

# Reliability Work Rules

Active when on `strictly-check/reliability-*` branches.
Plan: `@./.dev/reliability-plan.md`. Progress: `@./.dev/reliability-handover.md`.

## Principles

1. **Priority A > B > C** — Correctness > Features > Performance.
   A: spec/test/real-world fully working on arm64+amd64.
   B: Implement missing features (GC JIT, etc.).
   C: Target wasmtime 1x, accept 1.5x. Single-pass limits allow 2-3x.
2. **Zero tolerance** — every test failure is a bug. No "known limitations".
3. **Cross-platform** — Mac aarch64 + Ubuntu x86_64 must both pass.
4. **Fair benchmarks** — all scripts: 5 runs / 3 warmup. No legacy defaults.

## Benchmark Recording — MUST DO

**Every optimization/JIT/VM commit MUST record benchmarks.**
This is the #1 lesson from reliability-003: regressions went unnoticed while
optimizations were stacked on top.

```bash
# Quick check (regression detection)
bash bench/run_bench.sh --quick

# Official record (mandatory for opt/JIT/VM commits)
bash bench/record.sh --id=ID --reason="REASON"

# Cross-runtime (when adding benchmark items or major changes)
bash bench/record_comparison.sh
```

**If a benchmark regresses >10% vs previous history.yaml entry, STOP and fix.**

## Investigation — Go Wide

- **wasmtime/cranelift**: `~/Documents/OSS/wasmtime/` — always check first.
  Key paths: `cranelift/codegen/src/isa/aarch64/` (ARM64),
  `cranelift/codegen/src/isa/x64/` (x86_64), `cranelift/codegen/src/opts/`.
- **Clone more if needed**: `~/Documents/OSS/` — wasm3, wasmer, wazero, etc.
- **Web search**: Use WebFetch/WebSearch for specs, blog posts, papers.
- **zware**: `~/Documents/OSS/zware/` (Zig idioms).

## Experiment-First

- **Try boldly, revert cleanly.** Tests + benchmarks are the safety net.
- **Multiple approaches in sequence.** List 2-3 candidates, try lightest first.
- **Regressions are the only hard stop.** test pass + spec pass +
  no benchmark regression = safe to keep. Otherwise revert completely.
- **No partial fixes.** Every fix must be clean and spec-compliant.

## Branch Strategy

- Branches: `strictly-check/reliability-001`, `-002`, `-003`, ...
- Each branch = one **regression-free improvement unit**
- Merge to main after Merge Gate → create next branch → continue
