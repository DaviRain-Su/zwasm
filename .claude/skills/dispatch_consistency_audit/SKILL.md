---
name: dispatch_consistency_audit
description: Audit Q3 C adoption's dispatch substrate consistency — three-way match of ZirOp tag count = per-op file count = 5-axis handler implementation count; `wasm_level` / `wasi_level` metadata consistency; sampling check that build-option DCE works as expected. Fires after §9.12-B completion and at periodic audit_scaffolding boundaries.
---

# dispatch_consistency_audit

> **Status**: skeleton (2026-05-19). Justified by ADR-0071 §Q3 + ADR-0073.
> Initial wire-up in §9.12-A; full functionality after §9.12-B completion.

## Purpose

Automatically audit the **consistency** of Q3 C adoption (per-op file +
comptime collector + build-option DCE). Skeleton of master plan §7.7
(Q3 C design consistency audit).

The dispatch substrate must be consistent along the following 3 axes:

1. **ZirOp tag count = per-op file count** — The number of ZirOp enum
   tags in `src/ir/zir.zig` matches the per-op file count under
   `src/instruction/wasm_X_Y/**/*.zig` (excluding placeholder files)
2. **5-axis handler completeness** — Each op file has all 5 axes of
   `pub const handlers = .{ .validate, .lower, .arm64, .x86_64, .interp }`
3. **feature_level metadata consistency** — Each op's `wasm_level` matches
   the spec definition (Wasm 1.0 ops are `.v1_0`, Wasm 2.0 SIMD ops are
   `.v2_0`, etc.)

In addition:

4. **build-option DCE verification** — No Wasm 2.0+ symbols are included
   in a `-Dwasm=v1_0` build (= sampling via `scripts/check_build_dce.sh`)

## When to invoke

- Immediately after §9.12-B (Q3 C adoption completion)
- Sanity check at each §9.12-* chunk close
- Integrated into `audit_scaffolding` boundary mandatory invocation
  (§H extension)
- Phase boundary (= just before ROADMAP §9.13 [x] flip)

Users may also manually invoke `/dispatch_consistency_audit`.

## Procedure

> Implementation after §9.12-B completion. Currently in skeleton stage,
> only the overview is provided.

1. Retrieve ZirOp tag enumeration (via `zig build` + comptime export)
2. List populated files (≥ 30 LOC and similar heuristics) under
   `src/instruction/wasm_X_Y/**/*.zig`
3. Set diff: tag set vs file set; missing report
4. Verify each file's `pub const handlers` field (5 axes; report missing)
5. Cross-check each file's `wasm_level` value against the spec
   correspondence table (e.g. `.dev/wasm_3_0_zirop_mapping.md`)
   (drift report)
6. Run `bash scripts/check_build_dce.sh --sample 5`; verify PASS
7. Write the results of the 4 checks above to
   `private/dispatch_audit-YYYY-MM-DD.md`

## Severity

- No corresponding file for a ZirOp tag → `block`
- Missing handler on any of the 5 axes → `block`
- feature_level metadata mismatch with spec → `block`
- build-option DCE sampling fail → `block`

All `block`. Because Q3 C adoption presupposes dispatch consistency.

## Related

- ADR-0071 §Q3 (Phase 9 complete substrate audit resolution)
- ADR-0073 (build-option DCE substrate)
- Master plan §7.7
- `scripts/check_build_dce.sh` (skeleton in §9.12-A)
- `audit_scaffolding §H` (new in §9.12-A)
