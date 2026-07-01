//! Central op registry for the comptime dispatcher — pure data.
//!
//! Extracted from `dispatch_collector.zig` per ADR-0082 to surface
//! the 35-LOC dispatcher framework that was buried under ~900 LOC of
//! `@import` declarations + the `collected_ops` tuple. The dispatcher
//! framework + comptime helpers + tests remain in
//! `dispatch_collector.zig`; this file is the data side of the split.
//!
//! Pattern: one `const <op> = @import("../instruction/wasm_X_Y/<op>.zig")`
//! line per migrated per-op module, then `pub const collected_ops`
//! tuple referencing them. `dispatch_collector.zig` re-exports
//! `collected_ops` so external callers (feature_level_check.zig,
//! validator, lower, codegen) reach it via `dispatch_collector.collected_ops`
//! unchanged.
//!
//! Zone 1 (`src/ir/`). No imports beyond per-op file paths (those
//! files declare their own dependencies).

const i32_add = @import("../instruction/wasm_1_0/i32_add.zig");
const i32_sub = @import("../instruction/wasm_1_0/i32_sub.zig");
const i32_mul = @import("../instruction/wasm_1_0/i32_mul.zig");
const i32_and = @import("../instruction/wasm_1_0/i32_and.zig");
const i32_or = @import("../instruction/wasm_1_0/i32_or.zig");
const i32_xor = @import("../instruction/wasm_1_0/i32_xor.zig");

const i64_add = @import("../instruction/wasm_1_0/i64_add.zig");
const i64_sub = @import("../instruction/wasm_1_0/i64_sub.zig");
const i64_mul = @import("../instruction/wasm_1_0/i64_mul.zig");
const i64_and = @import("../instruction/wasm_1_0/i64_and.zig");
const i64_or = @import("../instruction/wasm_1_0/i64_or.zig");
const i64_xor = @import("../instruction/wasm_1_0/i64_xor.zig");

const i32_eq = @import("../instruction/wasm_1_0/i32_eq.zig");
const i32_ne = @import("../instruction/wasm_1_0/i32_ne.zig");
const i32_lt_s = @import("../instruction/wasm_1_0/i32_lt_s.zig");
const i32_lt_u = @import("../instruction/wasm_1_0/i32_lt_u.zig");
const i32_gt_s = @import("../instruction/wasm_1_0/i32_gt_s.zig");
const i32_gt_u = @import("../instruction/wasm_1_0/i32_gt_u.zig");
const i32_le_s = @import("../instruction/wasm_1_0/i32_le_s.zig");
const i32_le_u = @import("../instruction/wasm_1_0/i32_le_u.zig");
const i32_ge_s = @import("../instruction/wasm_1_0/i32_ge_s.zig");
const i32_ge_u = @import("../instruction/wasm_1_0/i32_ge_u.zig");

const i64_eq = @import("../instruction/wasm_1_0/i64_eq.zig");
const i64_ne = @import("../instruction/wasm_1_0/i64_ne.zig");
const i64_lt_s = @import("../instruction/wasm_1_0/i64_lt_s.zig");
const i64_lt_u = @import("../instruction/wasm_1_0/i64_lt_u.zig");
const i64_gt_s = @import("../instruction/wasm_1_0/i64_gt_s.zig");
const i64_gt_u = @import("../instruction/wasm_1_0/i64_gt_u.zig");
const i64_le_s = @import("../instruction/wasm_1_0/i64_le_s.zig");
const i64_le_u = @import("../instruction/wasm_1_0/i64_le_u.zig");
const i64_ge_s = @import("../instruction/wasm_1_0/i64_ge_s.zig");
const i64_ge_u = @import("../instruction/wasm_1_0/i64_ge_u.zig");

const i32_eqz = @import("../instruction/wasm_1_0/i32_eqz.zig");
const i64_eqz = @import("../instruction/wasm_1_0/i64_eqz.zig");
const i32_shl = @import("../instruction/wasm_1_0/i32_shl.zig");
const i32_shr_s = @import("../instruction/wasm_1_0/i32_shr_s.zig");
const i32_shr_u = @import("../instruction/wasm_1_0/i32_shr_u.zig");
const i32_rotl = @import("../instruction/wasm_1_0/i32_rotl.zig");
const i32_rotr = @import("../instruction/wasm_1_0/i32_rotr.zig");
const i64_shl = @import("../instruction/wasm_1_0/i64_shl.zig");
const i64_shr_s = @import("../instruction/wasm_1_0/i64_shr_s.zig");
const i64_shr_u = @import("../instruction/wasm_1_0/i64_shr_u.zig");
const i64_rotl = @import("../instruction/wasm_1_0/i64_rotl.zig");
const i64_rotr = @import("../instruction/wasm_1_0/i64_rotr.zig");

const i32_clz = @import("../instruction/wasm_1_0/i32_clz.zig");
const i32_ctz = @import("../instruction/wasm_1_0/i32_ctz.zig");
const i32_popcnt = @import("../instruction/wasm_1_0/i32_popcnt.zig");
const i64_clz = @import("../instruction/wasm_1_0/i64_clz.zig");
const i64_ctz = @import("../instruction/wasm_1_0/i64_ctz.zig");
const i64_popcnt = @import("../instruction/wasm_1_0/i64_popcnt.zig");

const i32_extend8_s = @import("../instruction/wasm_2_0/i32_extend8_s.zig");
const i32_extend16_s = @import("../instruction/wasm_2_0/i32_extend16_s.zig");
const i64_extend8_s = @import("../instruction/wasm_2_0/i64_extend8_s.zig");
const i64_extend16_s = @import("../instruction/wasm_2_0/i64_extend16_s.zig");
const i64_extend32_s = @import("../instruction/wasm_2_0/i64_extend32_s.zig");

const i32_trunc_sat_f32_s = @import("../instruction/wasm_2_0/i32_trunc_sat_f32_s.zig");
const i32_trunc_sat_f32_u = @import("../instruction/wasm_2_0/i32_trunc_sat_f32_u.zig");
const i32_trunc_sat_f64_s = @import("../instruction/wasm_2_0/i32_trunc_sat_f64_s.zig");
const i32_trunc_sat_f64_u = @import("../instruction/wasm_2_0/i32_trunc_sat_f64_u.zig");
const i64_trunc_sat_f32_s = @import("../instruction/wasm_2_0/i64_trunc_sat_f32_s.zig");
const i64_trunc_sat_f32_u = @import("../instruction/wasm_2_0/i64_trunc_sat_f32_u.zig");
const i64_trunc_sat_f64_s = @import("../instruction/wasm_2_0/i64_trunc_sat_f64_s.zig");
const i64_trunc_sat_f64_u = @import("../instruction/wasm_2_0/i64_trunc_sat_f64_u.zig");

const v128_not = @import("../instruction/wasm_2_0/v128_not.zig");
const v128_and = @import("../instruction/wasm_2_0/v128_and.zig");
const v128_or = @import("../instruction/wasm_2_0/v128_or.zig");
const v128_xor = @import("../instruction/wasm_2_0/v128_xor.zig");
const v128_andnot = @import("../instruction/wasm_2_0/v128_andnot.zig");
const v128_bitselect = @import("../instruction/wasm_2_0/v128_bitselect.zig");

const i8x16_add = @import("../instruction/wasm_2_0/i8x16_add.zig");
const i8x16_sub = @import("../instruction/wasm_2_0/i8x16_sub.zig");
const i16x8_add = @import("../instruction/wasm_2_0/i16x8_add.zig");
const i16x8_sub = @import("../instruction/wasm_2_0/i16x8_sub.zig");
const i16x8_mul = @import("../instruction/wasm_2_0/i16x8_mul.zig");
const i32x4_add = @import("../instruction/wasm_2_0/i32x4_add.zig");
const i32x4_sub = @import("../instruction/wasm_2_0/i32x4_sub.zig");
const i32x4_mul = @import("../instruction/wasm_2_0/i32x4_mul.zig");
const i64x2_add = @import("../instruction/wasm_2_0/i64x2_add.zig");
const i64x2_sub = @import("../instruction/wasm_2_0/i64x2_sub.zig");

const i8x16_neg = @import("../instruction/wasm_2_0/i8x16_neg.zig");
const i8x16_abs = @import("../instruction/wasm_2_0/i8x16_abs.zig");
const i16x8_neg = @import("../instruction/wasm_2_0/i16x8_neg.zig");
const i16x8_abs = @import("../instruction/wasm_2_0/i16x8_abs.zig");
const i32x4_neg = @import("../instruction/wasm_2_0/i32x4_neg.zig");
const i32x4_abs = @import("../instruction/wasm_2_0/i32x4_abs.zig");
const i64x2_neg = @import("../instruction/wasm_2_0/i64x2_neg.zig");
const i64x2_abs = @import("../instruction/wasm_2_0/i64x2_abs.zig");

const i8x16_eq = @import("../instruction/wasm_2_0/i8x16_eq.zig");
const i8x16_ne = @import("../instruction/wasm_2_0/i8x16_ne.zig");
const i8x16_lt_s = @import("../instruction/wasm_2_0/i8x16_lt_s.zig");
const i8x16_lt_u = @import("../instruction/wasm_2_0/i8x16_lt_u.zig");
const i8x16_gt_s = @import("../instruction/wasm_2_0/i8x16_gt_s.zig");
const i8x16_gt_u = @import("../instruction/wasm_2_0/i8x16_gt_u.zig");
const i8x16_le_s = @import("../instruction/wasm_2_0/i8x16_le_s.zig");
const i8x16_le_u = @import("../instruction/wasm_2_0/i8x16_le_u.zig");
const i8x16_ge_s = @import("../instruction/wasm_2_0/i8x16_ge_s.zig");
const i8x16_ge_u = @import("../instruction/wasm_2_0/i8x16_ge_u.zig");

const i16x8_eq = @import("../instruction/wasm_2_0/i16x8_eq.zig");
const i16x8_ne = @import("../instruction/wasm_2_0/i16x8_ne.zig");
const i16x8_lt_s = @import("../instruction/wasm_2_0/i16x8_lt_s.zig");
const i16x8_lt_u = @import("../instruction/wasm_2_0/i16x8_lt_u.zig");
const i16x8_gt_s = @import("../instruction/wasm_2_0/i16x8_gt_s.zig");
const i16x8_gt_u = @import("../instruction/wasm_2_0/i16x8_gt_u.zig");
const i16x8_le_s = @import("../instruction/wasm_2_0/i16x8_le_s.zig");
const i16x8_le_u = @import("../instruction/wasm_2_0/i16x8_le_u.zig");
const i16x8_ge_s = @import("../instruction/wasm_2_0/i16x8_ge_s.zig");
const i16x8_ge_u = @import("../instruction/wasm_2_0/i16x8_ge_u.zig");

const i32x4_eq = @import("../instruction/wasm_2_0/i32x4_eq.zig");
const i32x4_ne = @import("../instruction/wasm_2_0/i32x4_ne.zig");
const i32x4_lt_s = @import("../instruction/wasm_2_0/i32x4_lt_s.zig");
const i32x4_lt_u = @import("../instruction/wasm_2_0/i32x4_lt_u.zig");
const i32x4_gt_s = @import("../instruction/wasm_2_0/i32x4_gt_s.zig");
const i32x4_gt_u = @import("../instruction/wasm_2_0/i32x4_gt_u.zig");
const i32x4_le_s = @import("../instruction/wasm_2_0/i32x4_le_s.zig");
const i32x4_le_u = @import("../instruction/wasm_2_0/i32x4_le_u.zig");
const i32x4_ge_s = @import("../instruction/wasm_2_0/i32x4_ge_s.zig");
const i32x4_ge_u = @import("../instruction/wasm_2_0/i32x4_ge_u.zig");

const i64x2_eq = @import("../instruction/wasm_2_0/i64x2_eq.zig");
const i64x2_ne = @import("../instruction/wasm_2_0/i64x2_ne.zig");
const i64x2_lt_s = @import("../instruction/wasm_2_0/i64x2_lt_s.zig");
const i64x2_gt_s = @import("../instruction/wasm_2_0/i64x2_gt_s.zig");
const i64x2_le_s = @import("../instruction/wasm_2_0/i64x2_le_s.zig");
const i64x2_ge_s = @import("../instruction/wasm_2_0/i64x2_ge_s.zig");

const i8x16_swizzle = @import("../instruction/wasm_2_0/i8x16_swizzle.zig");
const i8x16_popcnt = @import("../instruction/wasm_2_0/i8x16_popcnt.zig");
const i32x4_dot_i16x8_s = @import("../instruction/wasm_2_0/i32x4_dot_i16x8_s.zig");
const i16x8_q15mulr_sat_s = @import("../instruction/wasm_2_0/i16x8_q15mulr_sat_s.zig");
const f32x4_convert_i32x4_s = @import("../instruction/wasm_2_0/f32x4_convert_i32x4_s.zig");
const f32x4_convert_i32x4_u = @import("../instruction/wasm_2_0/f32x4_convert_i32x4_u.zig");
const f64x2_convert_low_i32x4_s = @import("../instruction/wasm_2_0/f64x2_convert_low_i32x4_s.zig");
const f64x2_promote_low_f32x4 = @import("../instruction/wasm_2_0/f64x2_promote_low_f32x4.zig");
const f32x4_demote_f64x2_zero = @import("../instruction/wasm_2_0/f32x4_demote_f64x2_zero.zig");
const i32x4_trunc_sat_f32x4_s = @import("../instruction/wasm_2_0/i32x4_trunc_sat_f32x4_s.zig");
const i32x4_trunc_sat_f32x4_u = @import("../instruction/wasm_2_0/i32x4_trunc_sat_f32x4_u.zig");

const i16x8_extmul_low_i8x16_s = @import("../instruction/wasm_2_0/i16x8_extmul_low_i8x16_s.zig");
const i16x8_extmul_high_i8x16_s = @import("../instruction/wasm_2_0/i16x8_extmul_high_i8x16_s.zig");
const i16x8_extmul_low_i8x16_u = @import("../instruction/wasm_2_0/i16x8_extmul_low_i8x16_u.zig");
const i16x8_extmul_high_i8x16_u = @import("../instruction/wasm_2_0/i16x8_extmul_high_i8x16_u.zig");
const i32x4_extmul_low_i16x8_s = @import("../instruction/wasm_2_0/i32x4_extmul_low_i16x8_s.zig");
const i32x4_extmul_high_i16x8_s = @import("../instruction/wasm_2_0/i32x4_extmul_high_i16x8_s.zig");
const i32x4_extmul_low_i16x8_u = @import("../instruction/wasm_2_0/i32x4_extmul_low_i16x8_u.zig");
const i32x4_extmul_high_i16x8_u = @import("../instruction/wasm_2_0/i32x4_extmul_high_i16x8_u.zig");
const i64x2_extmul_low_i32x4_s = @import("../instruction/wasm_2_0/i64x2_extmul_low_i32x4_s.zig");
const i64x2_extmul_high_i32x4_s = @import("../instruction/wasm_2_0/i64x2_extmul_high_i32x4_s.zig");
const i64x2_extmul_low_i32x4_u = @import("../instruction/wasm_2_0/i64x2_extmul_low_i32x4_u.zig");
const i64x2_extmul_high_i32x4_u = @import("../instruction/wasm_2_0/i64x2_extmul_high_i32x4_u.zig");
const i16x8_extadd_pairwise_i8x16_s = @import("../instruction/wasm_2_0/i16x8_extadd_pairwise_i8x16_s.zig");
const i16x8_extadd_pairwise_i8x16_u = @import("../instruction/wasm_2_0/i16x8_extadd_pairwise_i8x16_u.zig");
const i32x4_extadd_pairwise_i16x8_s = @import("../instruction/wasm_2_0/i32x4_extadd_pairwise_i16x8_s.zig");
const i32x4_extadd_pairwise_i16x8_u = @import("../instruction/wasm_2_0/i32x4_extadd_pairwise_i16x8_u.zig");

const i8x16_narrow_i16x8_s = @import("../instruction/wasm_2_0/i8x16_narrow_i16x8_s.zig");
const i8x16_narrow_i16x8_u = @import("../instruction/wasm_2_0/i8x16_narrow_i16x8_u.zig");
const i16x8_narrow_i32x4_s = @import("../instruction/wasm_2_0/i16x8_narrow_i32x4_s.zig");
const i16x8_narrow_i32x4_u = @import("../instruction/wasm_2_0/i16x8_narrow_i32x4_u.zig");
const i16x8_extend_low_i8x16_s = @import("../instruction/wasm_2_0/i16x8_extend_low_i8x16_s.zig");
const i16x8_extend_high_i8x16_s = @import("../instruction/wasm_2_0/i16x8_extend_high_i8x16_s.zig");
const i16x8_extend_low_i8x16_u = @import("../instruction/wasm_2_0/i16x8_extend_low_i8x16_u.zig");
const i16x8_extend_high_i8x16_u = @import("../instruction/wasm_2_0/i16x8_extend_high_i8x16_u.zig");
const i32x4_extend_low_i16x8_s = @import("../instruction/wasm_2_0/i32x4_extend_low_i16x8_s.zig");
const i32x4_extend_high_i16x8_s = @import("../instruction/wasm_2_0/i32x4_extend_high_i16x8_s.zig");
const i32x4_extend_low_i16x8_u = @import("../instruction/wasm_2_0/i32x4_extend_low_i16x8_u.zig");
const i32x4_extend_high_i16x8_u = @import("../instruction/wasm_2_0/i32x4_extend_high_i16x8_u.zig");
const i64x2_extend_low_i32x4_s = @import("../instruction/wasm_2_0/i64x2_extend_low_i32x4_s.zig");
const i64x2_extend_high_i32x4_s = @import("../instruction/wasm_2_0/i64x2_extend_high_i32x4_s.zig");
const i64x2_extend_low_i32x4_u = @import("../instruction/wasm_2_0/i64x2_extend_low_i32x4_u.zig");
const i64x2_extend_high_i32x4_u = @import("../instruction/wasm_2_0/i64x2_extend_high_i32x4_u.zig");

const v128_any_true = @import("../instruction/wasm_2_0/v128_any_true.zig");
const i8x16_all_true = @import("../instruction/wasm_2_0/i8x16_all_true.zig");
const i16x8_all_true = @import("../instruction/wasm_2_0/i16x8_all_true.zig");
const i32x4_all_true = @import("../instruction/wasm_2_0/i32x4_all_true.zig");
const i64x2_all_true = @import("../instruction/wasm_2_0/i64x2_all_true.zig");
const i8x16_bitmask = @import("../instruction/wasm_2_0/i8x16_bitmask.zig");
const i16x8_bitmask = @import("../instruction/wasm_2_0/i16x8_bitmask.zig");
const i32x4_bitmask = @import("../instruction/wasm_2_0/i32x4_bitmask.zig");
const i64x2_bitmask = @import("../instruction/wasm_2_0/i64x2_bitmask.zig");

const f32x4_eq = @import("../instruction/wasm_2_0/f32x4_eq.zig");
const f32x4_ne = @import("../instruction/wasm_2_0/f32x4_ne.zig");
const f32x4_lt = @import("../instruction/wasm_2_0/f32x4_lt.zig");
const f32x4_gt = @import("../instruction/wasm_2_0/f32x4_gt.zig");
const f32x4_le = @import("../instruction/wasm_2_0/f32x4_le.zig");
const f32x4_ge = @import("../instruction/wasm_2_0/f32x4_ge.zig");
const f64x2_eq = @import("../instruction/wasm_2_0/f64x2_eq.zig");
const f64x2_ne = @import("../instruction/wasm_2_0/f64x2_ne.zig");
const f64x2_lt = @import("../instruction/wasm_2_0/f64x2_lt.zig");
const f64x2_gt = @import("../instruction/wasm_2_0/f64x2_gt.zig");
const f64x2_le = @import("../instruction/wasm_2_0/f64x2_le.zig");
const f64x2_ge = @import("../instruction/wasm_2_0/f64x2_ge.zig");

const f32x4_abs = @import("../instruction/wasm_2_0/f32x4_abs.zig");
const f32x4_neg = @import("../instruction/wasm_2_0/f32x4_neg.zig");
const f32x4_sqrt = @import("../instruction/wasm_2_0/f32x4_sqrt.zig");
const f32x4_ceil = @import("../instruction/wasm_2_0/f32x4_ceil.zig");
const f32x4_floor = @import("../instruction/wasm_2_0/f32x4_floor.zig");
const f32x4_trunc = @import("../instruction/wasm_2_0/f32x4_trunc.zig");
const f32x4_nearest = @import("../instruction/wasm_2_0/f32x4_nearest.zig");
const f64x2_abs = @import("../instruction/wasm_2_0/f64x2_abs.zig");
const f64x2_neg = @import("../instruction/wasm_2_0/f64x2_neg.zig");
const f64x2_sqrt = @import("../instruction/wasm_2_0/f64x2_sqrt.zig");
const f64x2_ceil = @import("../instruction/wasm_2_0/f64x2_ceil.zig");
const f64x2_floor = @import("../instruction/wasm_2_0/f64x2_floor.zig");
const f64x2_trunc = @import("../instruction/wasm_2_0/f64x2_trunc.zig");
const f64x2_nearest = @import("../instruction/wasm_2_0/f64x2_nearest.zig");

const f32x4_add = @import("../instruction/wasm_2_0/f32x4_add.zig");
const f32x4_sub = @import("../instruction/wasm_2_0/f32x4_sub.zig");
const f32x4_mul = @import("../instruction/wasm_2_0/f32x4_mul.zig");
const f32x4_div = @import("../instruction/wasm_2_0/f32x4_div.zig");
const f32x4_min = @import("../instruction/wasm_2_0/f32x4_min.zig");
const f32x4_max = @import("../instruction/wasm_2_0/f32x4_max.zig");
const f32x4_pmin = @import("../instruction/wasm_2_0/f32x4_pmin.zig");
const f32x4_pmax = @import("../instruction/wasm_2_0/f32x4_pmax.zig");
const f64x2_add = @import("../instruction/wasm_2_0/f64x2_add.zig");
const f64x2_sub = @import("../instruction/wasm_2_0/f64x2_sub.zig");
const f64x2_mul = @import("../instruction/wasm_2_0/f64x2_mul.zig");
const f64x2_div = @import("../instruction/wasm_2_0/f64x2_div.zig");
const f64x2_min = @import("../instruction/wasm_2_0/f64x2_min.zig");
const f64x2_max = @import("../instruction/wasm_2_0/f64x2_max.zig");
const f64x2_pmin = @import("../instruction/wasm_2_0/f64x2_pmin.zig");
const f64x2_pmax = @import("../instruction/wasm_2_0/f64x2_pmax.zig");

const i8x16_add_sat_s = @import("../instruction/wasm_2_0/i8x16_add_sat_s.zig");
const i8x16_add_sat_u = @import("../instruction/wasm_2_0/i8x16_add_sat_u.zig");
const i8x16_sub_sat_s = @import("../instruction/wasm_2_0/i8x16_sub_sat_s.zig");
const i8x16_sub_sat_u = @import("../instruction/wasm_2_0/i8x16_sub_sat_u.zig");
const i8x16_avgr_u = @import("../instruction/wasm_2_0/i8x16_avgr_u.zig");
const i16x8_add_sat_s = @import("../instruction/wasm_2_0/i16x8_add_sat_s.zig");
const i16x8_add_sat_u = @import("../instruction/wasm_2_0/i16x8_add_sat_u.zig");
const i16x8_sub_sat_s = @import("../instruction/wasm_2_0/i16x8_sub_sat_s.zig");
const i16x8_sub_sat_u = @import("../instruction/wasm_2_0/i16x8_sub_sat_u.zig");
const i16x8_avgr_u = @import("../instruction/wasm_2_0/i16x8_avgr_u.zig");

const i8x16_min_s = @import("../instruction/wasm_2_0/i8x16_min_s.zig");
const i8x16_min_u = @import("../instruction/wasm_2_0/i8x16_min_u.zig");
const i8x16_max_s = @import("../instruction/wasm_2_0/i8x16_max_s.zig");
const i8x16_max_u = @import("../instruction/wasm_2_0/i8x16_max_u.zig");
const i16x8_min_s = @import("../instruction/wasm_2_0/i16x8_min_s.zig");
const i16x8_min_u = @import("../instruction/wasm_2_0/i16x8_min_u.zig");
const i16x8_max_s = @import("../instruction/wasm_2_0/i16x8_max_s.zig");
const i16x8_max_u = @import("../instruction/wasm_2_0/i16x8_max_u.zig");
const i32x4_min_s = @import("../instruction/wasm_2_0/i32x4_min_s.zig");
const i32x4_min_u = @import("../instruction/wasm_2_0/i32x4_min_u.zig");
const i32x4_max_s = @import("../instruction/wasm_2_0/i32x4_max_s.zig");
const i32x4_max_u = @import("../instruction/wasm_2_0/i32x4_max_u.zig");

const i8x16_shl = @import("../instruction/wasm_2_0/i8x16_shl.zig");
const i8x16_shr_s = @import("../instruction/wasm_2_0/i8x16_shr_s.zig");
const i8x16_shr_u = @import("../instruction/wasm_2_0/i8x16_shr_u.zig");
const i16x8_shl = @import("../instruction/wasm_2_0/i16x8_shl.zig");
const i16x8_shr_s = @import("../instruction/wasm_2_0/i16x8_shr_s.zig");
const i16x8_shr_u = @import("../instruction/wasm_2_0/i16x8_shr_u.zig");
const i32x4_shl = @import("../instruction/wasm_2_0/i32x4_shl.zig");
const i32x4_shr_s = @import("../instruction/wasm_2_0/i32x4_shr_s.zig");
const i32x4_shr_u = @import("../instruction/wasm_2_0/i32x4_shr_u.zig");
const i64x2_shl = @import("../instruction/wasm_2_0/i64x2_shl.zig");
const i64x2_shr_s = @import("../instruction/wasm_2_0/i64x2_shr_s.zig");
const i64x2_shr_u = @import("../instruction/wasm_2_0/i64x2_shr_u.zig");

const call = @import("../instruction/wasm_1_0/call.zig");
const call_indirect = @import("../instruction/wasm_1_0/call_indirect.zig");

const ref_is_null = @import("../instruction/wasm_1_0/ref_is_null.zig");
const i8x16_splat = @import("../instruction/wasm_2_0/i8x16_splat.zig");
const i16x8_splat = @import("../instruction/wasm_2_0/i16x8_splat.zig");
const i32x4_splat = @import("../instruction/wasm_2_0/i32x4_splat.zig");
const i64x2_splat = @import("../instruction/wasm_2_0/i64x2_splat.zig");
const f32x4_splat = @import("../instruction/wasm_2_0/f32x4_splat.zig");
const f64x2_splat = @import("../instruction/wasm_2_0/f64x2_splat.zig");

const i32_trunc_f32_s = @import("../instruction/wasm_1_0/i32_trunc_f32_s.zig");
const i32_trunc_f32_u = @import("../instruction/wasm_1_0/i32_trunc_f32_u.zig");
const i64_trunc_f32_s = @import("../instruction/wasm_1_0/i64_trunc_f32_s.zig");
const i64_trunc_f32_u = @import("../instruction/wasm_1_0/i64_trunc_f32_u.zig");
const i32_trunc_f64_s = @import("../instruction/wasm_1_0/i32_trunc_f64_s.zig");
const i32_trunc_f64_u = @import("../instruction/wasm_1_0/i32_trunc_f64_u.zig");
const i64_trunc_f64_s = @import("../instruction/wasm_1_0/i64_trunc_f64_s.zig");
const i64_trunc_f64_u = @import("../instruction/wasm_1_0/i64_trunc_f64_u.zig");

const block = @import("../instruction/wasm_1_0/block.zig");
const loop = @import("../instruction/wasm_1_0/loop.zig");
const br_if = @import("../instruction/wasm_1_0/br_if.zig");
const br_table = @import("../instruction/wasm_1_0/br_table.zig");
const if_ = @import("../instruction/wasm_1_0/if_.zig");
const else_ = @import("../instruction/wasm_1_0/else_.zig");

const memory_fill = @import("../instruction/wasm_1_0/memory_fill.zig");
const memory_copy = @import("../instruction/wasm_1_0/memory_copy.zig");
const memory_init = @import("../instruction/wasm_1_0/memory_init.zig");

const i32_load = @import("../instruction/wasm_1_0/i32_load.zig");
const i32_load8_s = @import("../instruction/wasm_1_0/i32_load8_s.zig");
const i32_load8_u = @import("../instruction/wasm_1_0/i32_load8_u.zig");
const i32_load16_s = @import("../instruction/wasm_1_0/i32_load16_s.zig");
const i32_load16_u = @import("../instruction/wasm_1_0/i32_load16_u.zig");
const i32_store = @import("../instruction/wasm_1_0/i32_store.zig");
const i32_store8 = @import("../instruction/wasm_1_0/i32_store8.zig");
const i32_store16 = @import("../instruction/wasm_1_0/i32_store16.zig");
const i64_load = @import("../instruction/wasm_1_0/i64_load.zig");
const i64_load8_s = @import("../instruction/wasm_1_0/i64_load8_s.zig");
const i64_load8_u = @import("../instruction/wasm_1_0/i64_load8_u.zig");
const i64_load16_s = @import("../instruction/wasm_1_0/i64_load16_s.zig");
const i64_load16_u = @import("../instruction/wasm_1_0/i64_load16_u.zig");
const i64_load32_s = @import("../instruction/wasm_1_0/i64_load32_s.zig");
const i64_load32_u = @import("../instruction/wasm_1_0/i64_load32_u.zig");
const i64_store = @import("../instruction/wasm_1_0/i64_store.zig");
const i64_store8 = @import("../instruction/wasm_1_0/i64_store8.zig");
const i64_store16 = @import("../instruction/wasm_1_0/i64_store16.zig");
const i64_store32 = @import("../instruction/wasm_1_0/i64_store32.zig");
const f32_load = @import("../instruction/wasm_1_0/f32_load.zig");
const f32_store = @import("../instruction/wasm_1_0/f32_store.zig");
const f64_load = @import("../instruction/wasm_1_0/f64_load.zig");
const f64_store = @import("../instruction/wasm_1_0/f64_store.zig");

const global_get = @import("../instruction/wasm_1_0/global_get.zig");
const global_set = @import("../instruction/wasm_1_0/global_set.zig");
const table_get = @import("../instruction/wasm_1_0/table_get.zig");
const table_set = @import("../instruction/wasm_1_0/table_set.zig");
const table_size = @import("../instruction/wasm_1_0/table_size.zig");
const table_grow = @import("../instruction/wasm_1_0/table_grow.zig");
const table_fill = @import("../instruction/wasm_1_0/table_fill.zig");
const table_copy = @import("../instruction/wasm_1_0/table_copy.zig");
const table_init = @import("../instruction/wasm_1_0/table_init.zig");

const i32_div_s = @import("../instruction/wasm_1_0/i32_div_s.zig");
const i32_div_u = @import("../instruction/wasm_1_0/i32_div_u.zig");
const i32_rem_s = @import("../instruction/wasm_1_0/i32_rem_s.zig");
const i32_rem_u = @import("../instruction/wasm_1_0/i32_rem_u.zig");
const i64_div_s = @import("../instruction/wasm_1_0/i64_div_s.zig");
const i64_div_u = @import("../instruction/wasm_1_0/i64_div_u.zig");
const i64_rem_s = @import("../instruction/wasm_1_0/i64_rem_s.zig");
const i64_rem_u = @import("../instruction/wasm_1_0/i64_rem_u.zig");

const i32_wrap_i64 = @import("../instruction/wasm_1_0/i32_wrap_i64.zig");
const i64_extend_i32_s = @import("../instruction/wasm_1_0/i64_extend_i32_s.zig");
const i64_extend_i32_u = @import("../instruction/wasm_1_0/i64_extend_i32_u.zig");

const f32_add = @import("../instruction/wasm_1_0/f32_add.zig");
const f32_sub = @import("../instruction/wasm_1_0/f32_sub.zig");
const f32_mul = @import("../instruction/wasm_1_0/f32_mul.zig");
const f32_div = @import("../instruction/wasm_1_0/f32_div.zig");
const f64_add = @import("../instruction/wasm_1_0/f64_add.zig");
const f64_sub = @import("../instruction/wasm_1_0/f64_sub.zig");
const f64_mul = @import("../instruction/wasm_1_0/f64_mul.zig");
const f64_div = @import("../instruction/wasm_1_0/f64_div.zig");

const f32_eq = @import("../instruction/wasm_1_0/f32_eq.zig");
const f32_ne = @import("../instruction/wasm_1_0/f32_ne.zig");
const f32_lt = @import("../instruction/wasm_1_0/f32_lt.zig");
const f32_gt = @import("../instruction/wasm_1_0/f32_gt.zig");
const f32_le = @import("../instruction/wasm_1_0/f32_le.zig");
const f32_ge = @import("../instruction/wasm_1_0/f32_ge.zig");
const f64_eq = @import("../instruction/wasm_1_0/f64_eq.zig");
const f64_ne = @import("../instruction/wasm_1_0/f64_ne.zig");
const f64_lt = @import("../instruction/wasm_1_0/f64_lt.zig");
const f64_gt = @import("../instruction/wasm_1_0/f64_gt.zig");
const f64_le = @import("../instruction/wasm_1_0/f64_le.zig");
const f64_ge = @import("../instruction/wasm_1_0/f64_ge.zig");

const f32_abs = @import("../instruction/wasm_1_0/f32_abs.zig");
const f32_neg = @import("../instruction/wasm_1_0/f32_neg.zig");
const f32_sqrt = @import("../instruction/wasm_1_0/f32_sqrt.zig");
const f32_ceil = @import("../instruction/wasm_1_0/f32_ceil.zig");
const f32_floor = @import("../instruction/wasm_1_0/f32_floor.zig");
const f32_trunc = @import("../instruction/wasm_1_0/f32_trunc.zig");
const f32_nearest = @import("../instruction/wasm_1_0/f32_nearest.zig");
const f64_abs = @import("../instruction/wasm_1_0/f64_abs.zig");
const f64_neg = @import("../instruction/wasm_1_0/f64_neg.zig");
const f64_sqrt = @import("../instruction/wasm_1_0/f64_sqrt.zig");
const f64_ceil = @import("../instruction/wasm_1_0/f64_ceil.zig");
const f64_floor = @import("../instruction/wasm_1_0/f64_floor.zig");
const f64_trunc = @import("../instruction/wasm_1_0/f64_trunc.zig");
const f64_nearest = @import("../instruction/wasm_1_0/f64_nearest.zig");

const f32_min = @import("../instruction/wasm_1_0/f32_min.zig");
const f32_max = @import("../instruction/wasm_1_0/f32_max.zig");
const f64_min = @import("../instruction/wasm_1_0/f64_min.zig");
const f64_max = @import("../instruction/wasm_1_0/f64_max.zig");
const f32_copysign = @import("../instruction/wasm_1_0/f32_copysign.zig");
const f64_copysign = @import("../instruction/wasm_1_0/f64_copysign.zig");

const f32_convert_i32_s = @import("../instruction/wasm_1_0/f32_convert_i32_s.zig");
const f32_convert_i32_u = @import("../instruction/wasm_1_0/f32_convert_i32_u.zig");
const f32_convert_i64_s = @import("../instruction/wasm_1_0/f32_convert_i64_s.zig");
const f32_convert_i64_u = @import("../instruction/wasm_1_0/f32_convert_i64_u.zig");
const f64_convert_i32_s = @import("../instruction/wasm_1_0/f64_convert_i32_s.zig");
const f64_convert_i32_u = @import("../instruction/wasm_1_0/f64_convert_i32_u.zig");
const f64_convert_i64_s = @import("../instruction/wasm_1_0/f64_convert_i64_s.zig");
const f64_convert_i64_u = @import("../instruction/wasm_1_0/f64_convert_i64_u.zig");

const i32_reinterpret_f32 = @import("../instruction/wasm_1_0/i32_reinterpret_f32.zig");
const i64_reinterpret_f64 = @import("../instruction/wasm_1_0/i64_reinterpret_f64.zig");
const f32_reinterpret_i32 = @import("../instruction/wasm_1_0/f32_reinterpret_i32.zig");
const f64_reinterpret_i64 = @import("../instruction/wasm_1_0/f64_reinterpret_i64.zig");
const f32_demote_f64 = @import("../instruction/wasm_1_0/f32_demote_f64.zig");
const f64_promote_f32 = @import("../instruction/wasm_1_0/f64_promote_f32.zig");

// Wasm 3.0 tail-call ops — §9.12-G Phase 10 prep. `wasm_level: .v3_0`
// triggers `enabledByBuild` to filter them out under -Dwasm=v2_0 or
// lower; the dispatcher then returns `UnsupportedOpForBuildLevel` per
// the comptime-reject contract at `d641dcd8`.
const return_call = @import("../instruction/wasm_3_0/return_call.zig");
const return_call_indirect = @import("../instruction/wasm_3_0/return_call_indirect.zig");
const return_call_ref = @import("../instruction/wasm_3_0/return_call_ref.zig");

// Wasm 3.0 exception-handling (EH) ops — same wasm_level: .v3_0 shape.
const try_table = @import("../instruction/wasm_3_0/try_table.zig");
const throw = @import("../instruction/wasm_3_0/throw.zig");
const throw_ref = @import("../instruction/wasm_3_0/throw_ref.zig");

// Wasm 3.0 typed function references — same wasm_level: .v3_0 shape.
const call_ref = @import("../instruction/wasm_3_0/call_ref.zig");
const br_on_null = @import("../instruction/wasm_3_0/br_on_null.zig");
const br_on_non_null = @import("../instruction/wasm_3_0/br_on_non_null.zig");
const ref_as_non_null = @import("../instruction/wasm_3_0/ref_as_non_null.zig");

// Wasm 3.0 GC — struct cohort. Same wasm_level: .v3_0 shape.
const struct_new = @import("../instruction/wasm_3_0/struct_new.zig");
const struct_new_default = @import("../instruction/wasm_3_0/struct_new_default.zig");
const struct_get = @import("../instruction/wasm_3_0/struct_get.zig");
const struct_get_s = @import("../instruction/wasm_3_0/struct_get_s.zig");
const struct_get_u = @import("../instruction/wasm_3_0/struct_get_u.zig");
const struct_set = @import("../instruction/wasm_3_0/struct_set.zig");

// Wasm 3.0 GC — array cohort (14 ops). Same wasm_level: .v3_0 shape.
const array_new = @import("../instruction/wasm_3_0/array_new.zig");
const array_new_default = @import("../instruction/wasm_3_0/array_new_default.zig");
const array_new_fixed = @import("../instruction/wasm_3_0/array_new_fixed.zig");
const array_new_data = @import("../instruction/wasm_3_0/array_new_data.zig");
const array_new_elem = @import("../instruction/wasm_3_0/array_new_elem.zig");
const array_get = @import("../instruction/wasm_3_0/array_get.zig");
const array_get_s = @import("../instruction/wasm_3_0/array_get_s.zig");
const array_get_u = @import("../instruction/wasm_3_0/array_get_u.zig");
const array_set = @import("../instruction/wasm_3_0/array_set.zig");
const array_len = @import("../instruction/wasm_3_0/array_len.zig");
const array_fill = @import("../instruction/wasm_3_0/array_fill.zig");
const array_copy = @import("../instruction/wasm_3_0/array_copy.zig");
const array_init_data = @import("../instruction/wasm_3_0/array_init_data.zig");
const array_init_elem = @import("../instruction/wasm_3_0/array_init_elem.zig");

// Wasm 3.0 GC — ref/cast cohort (8 ops). Same wasm_level: .v3_0 shape.
const ref_test = @import("../instruction/wasm_3_0/ref_test.zig");
const ref_test_null = @import("../instruction/wasm_3_0/ref_test_null.zig");
const ref_cast = @import("../instruction/wasm_3_0/ref_cast.zig");
const ref_cast_null = @import("../instruction/wasm_3_0/ref_cast_null.zig");
const br_on_cast = @import("../instruction/wasm_3_0/br_on_cast.zig");
const br_on_cast_fail = @import("../instruction/wasm_3_0/br_on_cast_fail.zig");
const any_convert_extern = @import("../instruction/wasm_3_0/any_convert_extern.zig");
const extern_convert_any = @import("../instruction/wasm_3_0/extern_convert_any.zig");

// Wasm 3.0 GC — i31 cohort (3 ops).
const ref_i31 = @import("../instruction/wasm_3_0/ref_i31.zig");
const i31_get_s = @import("../instruction/wasm_3_0/i31_get_s.zig");
const i31_get_u = @import("../instruction/wasm_3_0/i31_get_u.zig");

/// Tuple of all migrated per-op modules. Order is not load-bearing;
/// `dispatcher` uses `op_tag` for routing.
pub const collected_ops = .{
    i32_add,
    i32_sub,
    i32_mul,
    i32_and,
    i32_or,
    i32_xor,
    i64_add,
    i64_sub,
    i64_mul,
    i64_and,
    i64_or,
    i64_xor,
    i32_eq,
    i32_ne,
    i32_lt_s,
    i32_lt_u,
    i32_gt_s,
    i32_gt_u,
    i32_le_s,
    i32_le_u,
    i32_ge_s,
    i32_ge_u,
    i64_eq,
    i64_ne,
    i64_lt_s,
    i64_lt_u,
    i64_gt_s,
    i64_gt_u,
    i64_le_s,
    i64_le_u,
    i64_ge_s,
    i64_ge_u,
    i32_eqz,
    i64_eqz,
    i32_shl,
    i32_shr_s,
    i32_shr_u,
    i32_rotl,
    i32_rotr,
    i64_shl,
    i64_shr_s,
    i64_shr_u,
    i64_rotl,
    i64_rotr,
    i32_clz,
    i32_ctz,
    i32_popcnt,
    i64_clz,
    i64_ctz,
    i64_popcnt,
    i32_extend8_s,
    i32_extend16_s,
    i64_extend8_s,
    i64_extend16_s,
    i64_extend32_s,
    i32_div_s,
    i32_div_u,
    i32_rem_s,
    i32_rem_u,
    i64_div_s,
    i64_div_u,
    i64_rem_s,
    i64_rem_u,
    i32_wrap_i64,
    i64_extend_i32_s,
    i64_extend_i32_u,
    f32_add,
    f32_sub,
    f32_mul,
    f32_div,
    f64_add,
    f64_sub,
    f64_mul,
    f64_div,
    f32_eq,
    f32_ne,
    f32_lt,
    f32_gt,
    f32_le,
    f32_ge,
    f64_eq,
    f64_ne,
    f64_lt,
    f64_gt,
    f64_le,
    f64_ge,
    f32_abs,
    f32_neg,
    f32_sqrt,
    f32_ceil,
    f32_floor,
    f32_trunc,
    f32_nearest,
    f64_abs,
    f64_neg,
    f64_sqrt,
    f64_ceil,
    f64_floor,
    f64_trunc,
    f64_nearest,
    f32_min,
    f32_max,
    f64_min,
    f64_max,
    f32_copysign,
    f64_copysign,
    f32_convert_i32_s,
    f32_convert_i32_u,
    f32_convert_i64_s,
    f32_convert_i64_u,
    f64_convert_i32_s,
    f64_convert_i32_u,
    f64_convert_i64_s,
    f64_convert_i64_u,
    i32_trunc_sat_f32_s,
    i32_trunc_sat_f32_u,
    i32_trunc_sat_f64_s,
    i32_trunc_sat_f64_u,
    i64_trunc_sat_f32_s,
    i64_trunc_sat_f32_u,
    i64_trunc_sat_f64_s,
    i64_trunc_sat_f64_u,
    i32_reinterpret_f32,
    i64_reinterpret_f64,
    f32_reinterpret_i32,
    f64_reinterpret_i64,
    f32_demote_f64,
    f64_promote_f32,
    v128_not,
    v128_and,
    v128_or,
    v128_xor,
    v128_andnot,
    v128_bitselect,
    i8x16_add,
    i8x16_sub,
    i16x8_add,
    i16x8_sub,
    i16x8_mul,
    i32x4_add,
    i32x4_sub,
    i32x4_mul,
    i64x2_add,
    i64x2_sub,
    i8x16_neg,
    i8x16_abs,
    i16x8_neg,
    i16x8_abs,
    i32x4_neg,
    i32x4_abs,
    i64x2_neg,
    i64x2_abs,
    i8x16_eq,
    i8x16_ne,
    i8x16_lt_s,
    i8x16_lt_u,
    i8x16_gt_s,
    i8x16_gt_u,
    i8x16_le_s,
    i8x16_le_u,
    i8x16_ge_s,
    i8x16_ge_u,
    i16x8_eq,
    i16x8_ne,
    i16x8_lt_s,
    i16x8_lt_u,
    i16x8_gt_s,
    i16x8_gt_u,
    i16x8_le_s,
    i16x8_le_u,
    i16x8_ge_s,
    i16x8_ge_u,
    i32x4_eq,
    i32x4_ne,
    i32x4_lt_s,
    i32x4_lt_u,
    i32x4_gt_s,
    i32x4_gt_u,
    i32x4_le_s,
    i32x4_le_u,
    i32x4_ge_s,
    i32x4_ge_u,
    i64x2_eq,
    i64x2_ne,
    i64x2_lt_s,
    i64x2_gt_s,
    i64x2_le_s,
    i64x2_ge_s,
    i8x16_shl,
    i8x16_shr_s,
    i8x16_shr_u,
    i16x8_shl,
    i16x8_shr_s,
    i16x8_shr_u,
    i32x4_shl,
    i32x4_shr_s,
    i32x4_shr_u,
    i64x2_shl,
    i64x2_shr_s,
    i64x2_shr_u,
    i8x16_min_s,
    i8x16_min_u,
    i8x16_max_s,
    i8x16_max_u,
    i16x8_min_s,
    i16x8_min_u,
    i16x8_max_s,
    i16x8_max_u,
    i32x4_min_s,
    i32x4_min_u,
    i32x4_max_s,
    i32x4_max_u,
    i8x16_add_sat_s,
    i8x16_add_sat_u,
    i8x16_sub_sat_s,
    i8x16_sub_sat_u,
    i8x16_avgr_u,
    i16x8_add_sat_s,
    i16x8_add_sat_u,
    i16x8_sub_sat_s,
    i16x8_sub_sat_u,
    i16x8_avgr_u,
    f32x4_add,
    f32x4_sub,
    f32x4_mul,
    f32x4_div,
    f32x4_min,
    f32x4_max,
    f32x4_pmin,
    f32x4_pmax,
    f64x2_add,
    f64x2_sub,
    f64x2_mul,
    f64x2_div,
    f64x2_min,
    f64x2_max,
    f64x2_pmin,
    f64x2_pmax,
    f32x4_abs,
    f32x4_neg,
    f32x4_sqrt,
    f32x4_ceil,
    f32x4_floor,
    f32x4_trunc,
    f32x4_nearest,
    f64x2_abs,
    f64x2_neg,
    f64x2_sqrt,
    f64x2_ceil,
    f64x2_floor,
    f64x2_trunc,
    f64x2_nearest,
    f32x4_eq,
    f32x4_ne,
    f32x4_lt,
    f32x4_gt,
    f32x4_le,
    f32x4_ge,
    f64x2_eq,
    f64x2_ne,
    f64x2_lt,
    f64x2_gt,
    f64x2_le,
    f64x2_ge,
    v128_any_true,
    i8x16_all_true,
    i16x8_all_true,
    i32x4_all_true,
    i64x2_all_true,
    i8x16_bitmask,
    i16x8_bitmask,
    i32x4_bitmask,
    i64x2_bitmask,
    i8x16_narrow_i16x8_s,
    i8x16_narrow_i16x8_u,
    i16x8_narrow_i32x4_s,
    i16x8_narrow_i32x4_u,
    i16x8_extend_low_i8x16_s,
    i16x8_extend_high_i8x16_s,
    i16x8_extend_low_i8x16_u,
    i16x8_extend_high_i8x16_u,
    i32x4_extend_low_i16x8_s,
    i32x4_extend_high_i16x8_s,
    i32x4_extend_low_i16x8_u,
    i32x4_extend_high_i16x8_u,
    i64x2_extend_low_i32x4_s,
    i64x2_extend_high_i32x4_s,
    i64x2_extend_low_i32x4_u,
    i64x2_extend_high_i32x4_u,
    i16x8_extmul_low_i8x16_s,
    i16x8_extmul_high_i8x16_s,
    i16x8_extmul_low_i8x16_u,
    i16x8_extmul_high_i8x16_u,
    i32x4_extmul_low_i16x8_s,
    i32x4_extmul_high_i16x8_s,
    i32x4_extmul_low_i16x8_u,
    i32x4_extmul_high_i16x8_u,
    i64x2_extmul_low_i32x4_s,
    i64x2_extmul_high_i32x4_s,
    i64x2_extmul_low_i32x4_u,
    i64x2_extmul_high_i32x4_u,
    i16x8_extadd_pairwise_i8x16_s,
    i16x8_extadd_pairwise_i8x16_u,
    i32x4_extadd_pairwise_i16x8_s,
    i32x4_extadd_pairwise_i16x8_u,
    i8x16_swizzle,
    i8x16_popcnt,
    i32x4_dot_i16x8_s,
    i16x8_q15mulr_sat_s,
    f32x4_convert_i32x4_s,
    f32x4_convert_i32x4_u,
    f64x2_convert_low_i32x4_s,
    f64x2_promote_low_f32x4,
    f32x4_demote_f64x2_zero,
    i32x4_trunc_sat_f32x4_s,
    i32x4_trunc_sat_f32x4_u,
    global_get,
    global_set,
    table_get,
    table_set,
    table_size,
    table_grow,
    table_fill,
    table_copy,
    table_init,
    i32_load,
    i32_load8_s,
    i32_load8_u,
    i32_load16_s,
    i32_load16_u,
    i32_store,
    i32_store8,
    i32_store16,
    i64_load,
    i64_load8_s,
    i64_load8_u,
    i64_load16_s,
    i64_load16_u,
    i64_load32_s,
    i64_load32_u,
    i64_store,
    i64_store8,
    i64_store16,
    i64_store32,
    f32_load,
    f32_store,
    f64_load,
    f64_store,
    memory_fill,
    memory_copy,
    memory_init,
    call,
    call_indirect,
    block,
    loop,
    br_if,
    br_table,
    if_,
    else_,
    i32_trunc_f32_s,
    i32_trunc_f32_u,
    i64_trunc_f32_s,
    i64_trunc_f32_u,
    i32_trunc_f64_s,
    i32_trunc_f64_u,
    i64_trunc_f64_s,
    i64_trunc_f64_u,
    ref_is_null,
    i8x16_splat,
    i16x8_splat,
    i32x4_splat,
    i64x2_splat,
    f32x4_splat,
    f64x2_splat,

    // Wasm 3.0 tail-call (§9.12-G Phase 10 prep).
    return_call,
    return_call_indirect,
    return_call_ref,

    // Wasm 3.0 exception-handling (§9.12-G Phase 10 prep).
    try_table,
    throw,
    throw_ref,

    // Wasm 3.0 typed function references (§9.12-G Phase 10 prep).
    call_ref,
    br_on_null,
    br_on_non_null,
    ref_as_non_null,

    // Wasm 3.0 GC struct cohort (§9.12-G Phase 10 prep).
    struct_new,
    struct_new_default,
    struct_get,
    struct_get_s,
    struct_get_u,
    struct_set,

    // Wasm 3.0 GC array cohort (§9.12-G Phase 10 prep).
    array_new,
    array_new_default,
    array_new_fixed,
    array_new_data,
    array_new_elem,
    array_get,
    array_get_s,
    array_get_u,
    array_set,
    array_len,
    array_fill,
    array_copy,
    array_init_data,
    array_init_elem,

    // Wasm 3.0 GC ref/cast cohort (§9.12-G Phase 10 prep).
    ref_test,
    ref_test_null,
    ref_cast,
    ref_cast_null,
    br_on_cast,
    br_on_cast_fail,
    any_convert_extern,
    extern_convert_any,

    // Wasm 3.0 GC i31 cohort (§9.12-G Phase 10 prep).
    ref_i31,
    i31_get_s,
    i31_get_u,
};
