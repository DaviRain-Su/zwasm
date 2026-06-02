# Detection without enforcement: a correct gate wired to a dead caller

2026-06-02. The user's "is level-separation real or 半規約頼み?" audit found the
sharpest failure was not in the code but in the *enforcement wiring*.

`scripts/check_build_dce.sh` is correct: in `--gate` mode it builds the 6
`-Dwasm × -Dwasi` combos and `nm | grep -E wasm_3_0` each, exiting non-zero on a
leak. It DID flag every leak (v1_0 + v2_0 carry `wasm_3_0` symbols). But:

- `--gate` (the only non-zero-exit mode) is invoked ONLY by
  `scripts/check_subrow_exit.sh`.
- `check_subrow_exit.sh` is invoked by **nothing** — not `gate_commit.sh`, not
  `gate_merge.sh`, not `GATE.md`, not CI. `grep -rln check_subrow_exit` →
  self-reference only.
- `dispatch_consistency_audit` runs it in `--sample` mode, which prints the FAIL
  row but **always exits 0** (the gate-exit guard is `MODE == "--gate"`).

So a real guarantee (ADR-0073 "no 2.0/3.0 symbol in a v1_0 binary") had a correct
detector that **never blocked**, and the leaks accumulated unnoticed across phases.
This is exactly "半規約頼み" at the infra level: the convention holds where
followed, but nothing forces it.

**Rules:**

1. A gate script's existence ≠ enforcement. After writing/reading one, run
   `grep -rln <script> scripts/ .claude/ .github/` and confirm a *routinely-run*
   caller (gate_commit / gate_merge / CI / a `/continue` step). An orphan gate is
   worse than none — it reads as "covered" in audits while enforcing nothing.
2. A check that prints FAIL but exits 0 (sample/report mode used where gate mode
   was meant) is a silent no-op. Audit the exit-code path, not just the output.
3. When a guarantee is "X is absent from the binary", the truth-test is `nm` on a
   real build, not a shape/metadata audit. `dispatch_consistency_audit` (counts +
   `wasm_level` tags) passed every axis while the binary leaked — shape ≠
   containment. (`check_build_dce.sh` had the right test; it just wasn't run.)

Resolution: ADR-0130 (fix the leaks by comptime-gating + revive the gate into
`gate_merge.sh`). Interp leak fixed same day; JIT-emit leaks → D-230. Same family
as the gate-coverage lesson in D-228 (`test-all` ⊉ `test` → stale assert
false-greened both hosts) — both are "the gate didn't run what you assumed".
