---
name: regalloc-pool-size-mismatch
description: regalloc.max_reg_slots default must equal abi.allocatable_gprs.len; mismatch surfaces as SlotOverflow not UnsupportedOp
type: feedback
---

# Regalloc pool-size mismatch (root of §9.7 / 7.5 SlotOverflow)

When ARM64 reduced the GPR pool from X20..X23 → X20..X22 (per
ADR-0027), `abi.allocatable_gprs.len` dropped 9 → 8. But
`regalloc.Allocation.max_reg_slots: u8 = 9` was not updated to
match.

**Symptom**: regalloc assigns slot_id ∈ {0..8} as `.reg` per the
default. emit's `resolveGpr` calls `abi.slotToReg(8)` which hits
`if (slot_id >= allocatable_gprs.len) return null` → `Error.
SlotOverflow` (the `orelse` arm). The function looks like its
9-vreg working set should fit in regs but actually one slot
maps to nothing.

**Why this hid for so long**: most functions use ≤ 8 simultaneously-
live GPR vregs. Spec-jit-compile-runner's func[9] of `local_get.0
.wasm` (5 params + 4 locals + many local.gets / convert chain)
crosses 9. From there the misnamed `Error.SlotOverflow` (really
"slot id out of pool") propagates to compileWasm and looks like
"too many vregs" rather than a static config bug.

**Why:** ADR-0027 reduced callee-saved pool but max_reg_slots
default was a separate constant in shared/regalloc.zig and
nobody propagated. The two needed to stay in sync.

**How to apply:** When changing `abi.allocatable_gprs` (per-arch),
also update `regalloc.Allocation.max_reg_slots` default. Better:
make max_reg_slots derive from the arch's pool length at compile
time, or pass it explicitly per call. Class-aware regalloc (Phase
8 follow-up) is the structural fix.

**Discovered via:** chunk -o diagnostics. After fix, the failing
fixtures shift from `SlotOverflow` to `UnsupportedOp` (resolveGpr
now correctly identifies vreg 8 as `.spill`, and unmigrated
handlers reject). The D-034 chain (chunks -k/-l/-m/-n) already
handles the spill-aware path for ~90 ops; remaining offenders
are FP / call / select / float-ALU handlers (chunk -p).

## Citing

- discovery commit `<backfill>` (chunk -o)
- ADR-0027 (callee-saved pool reduction)
- structural-fix commit `f1c3ce3` (chunk-d036; class-aware
  Allocation API; D-036 closed; band-aid removed) — paired
  with ADR-0018 Revision history row 2026-05-06 (gap)
