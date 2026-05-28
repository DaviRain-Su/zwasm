//! arm64 emit handler for `br_on_null` — Wasm 3.0 function-references
//! §3.3.8.7. Pop a ref; if null, branch to label at `payload` depth
//! (passing the label's k expected values from below the ref on the
//! operand stack); if non-null, push ref back as a (non-null) typed
//! ref and fall through.
//!
//! First-cut scope: forward-block targets only. Function-return
//! (payload == labels.items.len) + loop targets return
//! `Error.UnsupportedOp`. Filed under D-NNN (handover bundle memo);
//! covers the most common Wasm 3.0 usage shape.
//!
//! Pattern (mirrors br_if's CBZ-skip + merge + B path at
//! op_control.zig:348-358, but with X-form CMP (funcref is u64;
//! CBNZ is W-form / wrong width) + inverted condition + push src
//! back for non-null fall-through):
//!
//! ```
//!     CMP Xn, #0
//!     B.NE skip_byte  ; if non-null, skip the merge+B
//!     <captureOrEmitBlockMergeMov tgt_idx>  ; place label values
//!     B → label fixup (append to labels[tgt_idx].pending, kind=.b_uncond)
//!     skip_byte:
//!     <push src vreg back to pushed_vregs>
//! ```
//!
//! No usesRuntimePtr concern: this uses label fixups (the existing
//! br_if machinery), not bounds_fixups → trap stub not triggered →
//! R15 (x86_64) / X19 (arm64) not implicitly required. (Contrast
//! ref.as_non_null which DOES append to bounds_fixups and required
//! the cycle-51b D-180 whitelist fix.)

const std = @import("std");
const meta = @import("../../../../../instruction/wasm_3_0/br_on_null.zig");
const ctx_mod = @import("../../ctx.zig");
const gpr = @import("../../gpr.zig");
const inst = @import("../../inst.zig");
const merge_mov = @import("../../op_control_merge_mov.zig");
const zir = @import("../../../../../ir/zir.zig");

pub const op_tag = meta.op_tag;
pub const wasm_level = meta.wasm_level;
pub const wasi_level = meta.wasi_level;

pub fn emit(ctx: *ctx_mod.EmitCtx, ins: *const zir.ZirInstr) ctx_mod.Error!void {
    if (ctx.pushed_vregs.items.len < 1) return ctx_mod.Error.AllocationMissing;
    const src = ctx.pushed_vregs.pop().?;
    const xn = try gpr.gprLoadSpilled(ctx.allocator, ctx.buf, ctx.alloc, ctx.spill_base_off, src, 0);

    // First-cut: only forward-block targets supported.
    if (ins.payload >= ctx.labels.items.len) return ctx_mod.Error.UnsupportedOp;
    const tgt_idx: usize = @intCast(ctx.labels.items.len - 1 - @as(usize, @intCast(ins.payload)));
    if (ctx.labels.items[tgt_idx].kind != .block) return ctx_mod.Error.UnsupportedOp;

    // CMP Xn, #0 (X-form null check).
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encCmpImmX(xn, 0));
    // B.NE skip_byte placeholder — if non-null, skip past the merge
    // + label-branch and fall through to push-src-back.
    const bne_at: u32 = @intCast(ctx.buf.items.len);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encBCond(.ne, 0));

    // Branch-taken (null) path: place label's k expected values in
    // their target positions, then unconditional B → label fixup.
    _ = try merge_mov.captureOrEmitBlockMergeMov(ctx, tgt_idx);
    const b_at: u32 = @intCast(ctx.buf.items.len);
    try gpr.writeU32(ctx.allocator, ctx.buf, inst.encB(0));
    try ctx.labels.items[tgt_idx].pending.append(ctx.allocator, .{ .byte_offset = b_at, .kind = .b_uncond });

    // Patch B.NE skip disp to land at the fall-through target
    // (current buf end).
    const skip_byte: u32 = @intCast(ctx.buf.items.len);
    const bne_disp_words: i19 = @intCast(@divExact(@as(i32, @intCast(skip_byte)) - @as(i32, @intCast(bne_at)), 4));
    std.mem.writeInt(u32, ctx.buf.items[bne_at..][0..4], inst.encBCond(.ne, bne_disp_words), .little);

    // Non-null fall-through: push src vreg back so the ref stays on
    // the operand stack for the next consumer (typed as non-null per
    // Wasm spec, though zwasm v2 keeps the type stack generic-funcref
    // per ADR-0123 D2 — no validator narrowing needed).
    try ctx.pushed_vregs.append(ctx.allocator, src);
}
