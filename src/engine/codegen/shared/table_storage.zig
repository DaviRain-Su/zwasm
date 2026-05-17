//! TODO(9.12-audit): table storage shape — see D-126 / ADR-0068.
//!
//! Single-site helper for the **dual-view table storage sync**
//! discipline established by ADR-0068 §A1. Every JIT op handler
//! that mutates a table slot (`emitTableSet` / `emitTableCopy` /
//! `emitTableInit` / `emitTableGrow` / `emitTableFill`) MUST
//! route its `tables_ptr[k].refs` write through `mirrorWrite*`
//! so the parallel `funcptrs` view (read by `call_indirect`'s
//! X26 fast path) stays in lockstep.
//!
//! Chunk α scope (this commit): the helper bodies are empty
//! stubs. The signatures + call-site discipline are landed so
//! chunk β (arm64) and chunk γ (x86_64) can wire the emit-time
//! mirror writes in one place without re-deriving the shape.
//! Contract fixtures under `test/edge_cases/p9/table_storage_sync/`
//! FAIL at this chunk's gate because the bodies don't yet emit
//! the triple-write; chunk β/γ greens them.
//!
//! The auto-loaded `.claude/rules/dual_view_table_sync.md`
//! codifies the "MUST go through mirrorWrite" reviewer rule.
//!
//! Zone 2 (engine/codegen/shared) — both arm64 and x86_64
//! emit modules import this for their per-op mutating handlers.

const std = @import("std");

/// Mirror write a single funcref-table slot. Called by
/// `emitTableSet` / `emitTableGrow`-init / `emitTableFill`-init
/// per arch. Once the chunk β/γ implementations land, the body
/// emits machine code that performs three stores (refs view,
/// funcptrs view, typeidx view) keyed by the same dst index.
///
/// Parameters (chunk α placeholder shape — concrete signature
/// settles in β when arm64 register conventions are spliced in):
///   - `ctx`: per-arch emit context (anyopaque until β picks
///     the concrete `EmitCtx` from arm64's op_table.zig).
///   - `tableidx`: target table index — selects the TableSlice
///     descriptor in `tables_ptr[k]`.
///
/// Chunk α body intentionally empty — see ADR-0068 §A4. The
/// signature exists so call-sites in chunk β/γ become a
/// single-line wire-up.
pub fn mirrorWriteOne(ctx: *anyopaque, tableidx: u32) void {
    // TODO(9.12-audit): table storage shape — see D-126 / ADR-0068.
    // Chunk β/γ replaces this stub with the arch-specific
    // triple-write emit. See `.claude/rules/dual_view_table_sync.md`.
    _ = ctx;
    _ = tableidx;
}

/// Mirror write a contiguous range of funcref-table slots.
/// Called by `emitTableCopy` / `emitTableInit`. Once chunks β/γ
/// land, the body emits a paired loop-body that copies refs +
/// funcptrs in lockstep.
///
/// Chunk α body intentionally empty.
pub fn mirrorWriteRange(ctx: *anyopaque, tableidx: u32) void {
    // TODO(9.12-audit): table storage shape — see D-126 / ADR-0068.
    _ = ctx;
    _ = tableidx;
}

test "mirrorWrite stubs are callable" {
    // Smoke test — the chunk α scaffold must compile + link from
    // both arm64 and x86_64 op_table.zig imports. Chunk β/γ
    // replaces the bodies with arch-specific emit logic; the
    // signatures should remain stable across that change.
    var dummy: u32 = 0;
    mirrorWriteOne(@ptrCast(&dummy), 0);
    mirrorWriteRange(@ptrCast(&dummy), 0);
    try std.testing.expect(true);
}
