# D-489: arm64 cannot be pressure-matched to x86_64 to reproduce the miscompile

**Date**: 2026-06-21
**Context**: D-489 (x86_64-jit miscompile of tinygo_json) — attempt to make the
bug reproducible under the arm64 lldb value-trace harness (`jit_value_trace.sh`,
arm64-only) by shrinking arm64's allocatable GPR pool to x86_64's count.

## What was tried

Set `arm64/abi.zig:allocatable_caller_saved_scratch_gprs = {}` (was {9,10,11,12,13}),
dropping arm64 allocatable from 8 → 3 (x86_64 has 4) to force x86_64-like spill
pressure on tinygo_json.

## Why it's blocked

The build fails at **comptime**, not runtime:
- `op_memory.zig:63` / `op_table.zig:72` directly index
  `allocatable_caller_saved_scratch_gprs[0]` (empty-array index error).
- `regalloc_compute.zig:79` — `op_scratch_reservation_table[188][3]` asserts
  `slot 3 < force_spill_threshold`, but the shrunk pool drops the threshold to 3
  → `@compileError` (ADR-0077).

arm64's deterministic **op_scratch_reservation_table** (ADR-0077) statically
reserves up to 4 scratch slots per op, structurally requiring ≥~7-8 allocatable
GPRs. x86_64 uses a different model: 4 allocatable + 2 spill-stage (R10/R11),
no per-op reservation table.

## Takeaway (load-bearing for D-489)

The two arches have **structurally distinct spill/scratch models** — arm64's
reservation-table approach cannot be reduced to x86_64's register economy. So a
spill-staging defect on x86_64 would **not** reproduce on arm64 even at matched
pressure. **D-489 must be debugged ON x86_64** (gdb on ubuntu native x86_64, or
an x86_64 value-trace differential) — the arm64 lldb harness is not applicable.
Next probe: x86_64-native value trace, NOT another arm64 angle.
