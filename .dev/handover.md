# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8.
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Fresh-session start here

**Authoritative remaining-work source**:
[`phase9_close_master.md`](./phase9_close_master.md)
§5.3a (Phase A + Phase B 2-stage iteration discipline).

**Mandatory before any §9.x [x] flip**:
`bash scripts/check_phase9_close_invariants.sh --gate`.

**Gate state (mac-host)**: 18/18 passed.
**Win64 surface (originally-planned)**: ALL CLOSED — D-162 /
D-163 / D-164 / D-165 (cycle 9). The Win64 codegen redesign
per ADR-0105 / ADR-0106 is structurally complete.

## Remaining work — Phase 9 真スコープ (host-side library code)

Per ADR-0104 Revision 2026-05-23 + cycle 9 amendment. The 3
debts originally Track-D / v0.1.0 RC-scoped were promoted to
Phase 9 真スコープ ("Wasm 2.0 complete + Zig/C API complete at
Phase 9 release"). The remaining surface touches host-side
library code (`runtime/instance/instantiate.zig` + `Runtime.
globals` shape + `src/api/instance.zig`) — no new JIT codegen.

### Phase A — Mac + ubuntunote implementation (per-chunk gate)

Iterate FAST: per-chunk gate is Mac + ubuntu only. ADR-0049
windowsmini deferral applies; per-chunk windowsmini reconcile
costs 8-15 min/iter and is NOT required for host-side library
code. Phase B (below) bundles the Win64 verification once.

Tackle in this order (autonomous-eligible, ROI-descending):

1. **A1. D-157** — `assert_unlinkable` non-func import-type
   checking. Extend `runtime/instance/instantiate.zig` to
   verify table / memory / global import types at bind time
   (mirror of existing func-import-type check). Exit: 56
   `SKIP-NO-LINK-TYPECHECK` → 0 on Mac + ubuntu. **Highest-ROI
   starter** (mechanical, clear exit, no API surface change).
2. **A2. D-139** — c_api Instance lifecycle audit + coverage.
   Audit which `wasm_instance_new` / `setupRuntime` behaviours
   lack spec-corpus coverage; add paired in-source `test "..."`
   blocks in `src/api/instance.zig` per audited behaviour. Exit:
   audit doc filed + tests PASS on Mac + ubuntu.
3. **A3. D-079 (ii)** — c_api v128 cross-module imports. Extend
   `Runtime.globals: []*Value` (ADR-0052 §3 scalar-only) to
   v128-aware; plumb into `instantiate.zig` cross-module import
   wiring. Exit: new in-source test in `src/api/instance.zig`
   PASSes on Mac + ubuntu. Last because Runtime.globals refactor
   is widest in scope (ADR-0052 §3 amend may be needed).

### Phase B — windowsmini reconcile (single shot after A1+A2+A3)

After ALL of A1+A2+A3 land [x] with Mac + ubuntu green:

1. **B1**: `bash scripts/run_remote_windows.sh test-all` ONCE.
   Expected: identical PASS counts (+ newly-passing
   assert_unlinkable fixtures); 0 `SKIP-NO-LINK-TYPECHECK`
   emission; new c_api tests PASS on Win64. If a Win64-specific
   issue surfaces, fix in same Phase B window (no need to roll
   back; structural redesign risk is low for host-side library
   code).
2. **B2**: Once B1 green: §9.13-0 / §9.12-F / §9.12-I [x]
   re-flip with cited SHAs + SHA-backfill pass for the
   §9.x rows with bare Status column.

### §9.13 (hard gate) — user touchpoint

ADR-0105 + ADR-0106 `Proposed → Accepted` flip via collab
review per Track D. **User-gated** — sole remaining non-
autonomous step after Phase A + B complete.

## Closed this session (2026-05-23)

- ✅ **R3 / D-162, R2, R1, D-094, D-164**.
- ✅ **D-163** SKIP-WIN64-CALL-INDIRECT-TRAP arm retired
  (`0de438a6`); R3 broader trap-path fix repaired.
- ✅ **D-165** Win64 internal JIT-to-JIT MEMORY-class + cap
  fix (`75f96dee` + `99a047f6`). Real trigger: pick0's 2nd
  i64-result silently truncated by Win64 cap=1 in
  `captureCallResult`. Mac + windowsmini isolated PASS.

## Cycle 9 debug-workflow codification

- `debug_jit_auto/SKILL.md` Recipes 15-17 (cmd /c
  orchestration, JIT bytes dump, manifest-bisect via
  `test/private/d-165/`); `windows_ssh_setup.md` cmd /c
  short-circuit; `build.zig` `installArtifact` for stable
  `zig-out/bin/` paths; lessons 2026-05-23-*.

windowsmini SSH-reachable, autonomous-eligible per ADR-0049.

## See

- [`phase9_close_master.md`](./phase9_close_master.md) §5.3a + §6.
- ADR-0104 Revision 2026-05-23 (scope expansion + 2-phase).
- `.dev/debt.md` D-157 / D-079 / D-139 (`now`, Phase 9 scope).
