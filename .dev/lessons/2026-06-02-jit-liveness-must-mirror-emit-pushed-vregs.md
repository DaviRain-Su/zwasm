# JIT liveness stack-effect MUST mirror each op's emit `pushed_vregs` exactly

2026-06-02. The spec-corpus JIT mode rejected gc/funcref modules with
`liveness: UnsupportedOp[stackEffect-missing] op=X` — the liveness pass (which
computes vreg live-ranges for regalloc) lacked entries for `ref.as_non_null`,
`any.convert_extern`, `br_on_cast`, `br_on_null`, `br_on_non_null`, etc. These
ops lower + emit fine; only liveness was missing → module-compile-reject.

## The trap: liveness pop/push must equal the emit's pushed_vregs delta

Liveness simulates the operand stack to assign vreg NUMBERS. The per-arch emit
ALSO manipulates `pushed_vregs`. If the two disagree on how many vregs an op
pops/pushes, the vreg numbering **desyncs** → regalloc aliases slots → silent
miscompile (wrong values / SEGV), NOT a clean error. So each liveness entry must
be derived from the op's ACTUAL emit, not from spec stack-types alone.

Per-op models (read from the arm64 `ops/wasm_3_0/*.zig` headers):

| op | emit operand model | liveness |
|---|---|---|
| `ref.as_non_null` | pop ref, push non-null ref | 1→1 (stackEffect) ✓ done `e2701f0d` |
| `br_on_cast` / `br_on_cast_fail` | **PEEK** (ref stays; carried to label + fallthrough) | TRANSPARENT, like `local.tee` (mark used, no pop/push) |
| `br_on_null` | **pop + push-back** (non-null fallthrough re-pushes the ref) | 1→1 (pop, push fresh vreg) |
| `br_on_non_null` | **pop** (branch carries ref on non-null; null fallthrough discards) | 1→0 (pop, mark used) |
| `any.convert_extern` / `extern.convert_any` | **no emit handler yet** (pure reinterpret) | needs emit FIRST, then 1→1 |

## Takeaways

- A "missing liveness entry" is NOT a free 1-line add — verify the op's emit
  `pushed_vregs` (peek vs pop vs pop+push) and mirror it. The transparent
  (PEEK) ops must use the `local.tee` special case, NOT generic 1→1 (which
  closes the old vreg + fabricates a fresh one → reuse window).
- Co-occurring-barrier rule (cf. `2026-06-02-spec-jit-skips-weight-by-root-cause`):
  ref.as_non_null co-occurs with the ref-BRANCH ops in every module, so fixing
  it alone flipped 0 corpus asserts. Bundle the whole ref-branch family in one
  chunk so modules actually JIT-compile.
- Branch ref-ops are conditional (fallthrough continues) → like `br_if` they do
  NOT close vregs above the target (only unconditional `br` does).
