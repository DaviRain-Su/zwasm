// FILE-SIZE-EXEMPT: ADR-0106 path (a) wrapper-thunk substrate — per-arch emit (x86_64 SysV/Win64, arm64 AAPCS64) + paired byte tests change in lockstep per TDD discipline; extraction would create N3-shallow test-only or per-arch siblings per ADR-0099 D2.
//! Buffer-write entry wrapper thunk (ADR-0106 cycle 3e
//! foundation).
//!
//! Per the cycle 3e design spike at
//! `private/spikes/adr-0106-cycle3e-call-lowering/SPIKE.md`
//! §"REVISED APPROACH", the cycle 3e implementation pivots
//! from "in-body buffer_write epilogue" to "per-function
//! wrapper thunk":
//!
//! - **Function body**: unchanged, compiled with default
//!   `.register_write` epilogue. Intra-module dispatch
//!   (Wasm `call N` / `call_indirect`) routes through
//!   `funcptr_base[i]` = body address, preserving register
//!   convention internally.
//! - **Wrapper thunk** (this file): a JIT-emitted machine-
//!   code thunk per multi-result function. Zig-side
//!   signature `fn(rt, results, args) callconv(.c) ErrCode`
//!   — single u32 return, no hidden RCX pointer issue on
//!   Win64. Internally calls the function body via raw
//!   assembly (no `callconv(.c)` at the internal call →
//!   no Win64 ABI rules → no struct-return ABI mismatch).
//!
//! Per-arch emit (Phase 2' a-e) is COMPLETE: x86_64 SysV +
//! arm64 AAPCS64 each cover the 2-int register-class shape
//! and 3-int MEMORY-class shape — the 3 sig shapes that hit
//! the `SKIP-WIN64-MULTI-RESULT` arm in
//! `spec_assert_runner_base.zig`. Each wrapper byte sequence
//! is unit-tested against expected bytes.
//!
//! ## Phase 2'g integration plan (linker hookup)
//!
//! Subsequent cycles wire this module into the production
//! compile path:
//!
//! 1. Extend `shared/linker.zig::link()` with an optional
//!    `wrapper_specs: ?[]const WrapperSpec` parameter (where
//!    `WrapperSpec = struct { func_idx: u32, sig: FuncType }`).
//!    When non-null + non-empty:
//!    - After laying out function bodies (current pass), call
//!      `wrapper_thunk.emit(allocator, .{ .sig, .body_offset =
//!      func_offsets[idx], .thunk_offset = block_size_so_far })`
//!      per spec.
//!    - Append wrapper bytes to `block.bytes`.
//!    - Populate `thunk_offsets[idx] = thunk_offset` for each
//!      spec'd function; `NO_THUNK` for the rest.
//!    - Skip the pass entirely when wrapper_specs == null (or
//!      `wrapper_thunk.emit` returns `Error.UnsupportedOp` for
//!      every spec — e.g. arch/shape unsupported).
//!
//! 2. Extend `shared/compile.zig::compileOne` to detect when
//!    the function's sig hits a supported wrapper shape
//!    (`results.len in {2, 3}` + all GPR-class) and append to
//!    the wrapper_specs slice.
//!
//! 3. Spec runner's 3 multi-result callsites in
//!    `test/spec/spec_assert_runner_non_simd.zig` (lines
//!    767/817/892) gated on `builtin.os.tag == .windows`:
//!    - Use `module.entry_buf(func_idx, BufferWriteFn)` to
//!      get the wrapper pointer.
//!    - Invoke via `entry_buffer_write.invokeMultiResultNoArgs`.
//!    - Unpack results from `TypedResult` array.
//!
//! 4. Remove the `SKIP-WIN64-MULTI-RESULT` arm in
//!    `spec_assert_runner_base.zig` (lines 3055-3082). After
//!    Phase 2'g lands, Win64 multi-result fixtures route
//!    through the wrapper thunk (currently the same as the
//!    existing per-shape `callI32i32i32NoArgs` etc but with
//!    the buffer-write boundary intercept).
//!
//! 5. Phase boundary windowsmini reconciliation runs
//!    `bash scripts/run_remote_windows.sh test-all` to
//!    verify the Win64 path. If wrapper byte sequence has a
//!    bug specific to Win64 (e.g. shadow space alignment),
//!    surface via test FAIL at that point.
//!
//! Zone 2 (`src/engine/codegen/shared/`) — same as
//! `entry_buffer_write.zig` + `result_abi.zig`.

const std = @import("std");
const builtin = @import("builtin");

const jit_abi = @import("jit_abi.zig");
const FuncType = @import("../../../ir/zir.zig").FuncType;

/// Wrapper thunk emit parameters. The caller (cycle 3e
/// `compileWasm` + linker) builds this per multi-result
/// function it wants to wrap.
pub const EmitParams = struct {
    /// Wasm function signature — params + results define
    /// how the wrapper loads args from `[R8/RDX/X2 + 8*i]`
    /// and stores results to `[RDX/RSI/X1 + 8*i]`.
    sig: FuncType,
    /// Byte offset of the function body within the linker's
    /// linked code blob. The wrapper's internal CALL/BL
    /// reaches this address (PC-relative on arm64, RIP-
    /// relative + indirect on x86_64).
    body_offset: u32,
    /// Self-offset where the wrapper itself lives within
    /// the linked code blob. Needed to compute the
    /// body_offset - thunk_offset displacement for the
    /// internal CALL/BL.
    thunk_offset: u32,
};

/// Per-arch emit result.
pub const EmitOutput = struct {
    /// Wrapper thunk machine-code bytes.
    bytes: []const u8,
};

/// Emit a wrapper thunk for the given function. Per-arch
/// dispatch happens here; the implementation is platform-
/// specific bytes-emit per the calling convention.
///
/// CYCLE 3e STATUS: stub returning Error.UnsupportedOp. The
/// actual emit logic for x86_64 + arm64 lands in Phase 2'
/// per the spike doc. This file provides the type + public
/// API foundation so callers + tests have a stable shape.
pub const Error = error{
    /// The function shape isn't supported by this arch's
    /// wrapper emit. Cycle 3e Phase 2' replaces this with
    /// the actual per-shape emit.
    UnsupportedOp,
    /// Allocator out of memory during byte buffer growth.
    OutOfMemory,
};

/// Emit a wrapper thunk for the given function. Per-arch
/// dispatch based on `builtin.cpu.arch` + `builtin.os.tag`.
///
/// CYCLE 3e Phase 2' (incremental): the only shape covered
/// in this commit is **x86_64 SysV, 3-int-result MEMORY-
/// class** (the `() → (i32, i32, i32)` SKIP arm shape).
/// Other shapes still return UnsupportedOp; subsequent
/// cycles add them per [`SPIKE.md`](../../../../private/spikes/adr-0106-cycle3e-call-lowering/SPIKE.md).
///
/// 3-int-result MEMORY-class wrapper (SysV) shape:
///
/// ```text
///     ; Wrapper entry (Zig caller passed: RDI=rt, RSI=results, RDX=args).
///     ; Body expects MEMORY-class layout: RDI=&result_buf, RSI=rt.
///     ; Args are 0 (the 3 SKIP-arm shapes all have empty params).
///     XCHG RDI, RSI            ; 48 87 FE  (3 bytes)
///     CALL body_offset         ; E8 d0 d1 d2 d3   (5 bytes; rel32 disp)
///     XOR EAX, EAX             ; 31 C0  (2 bytes; ErrCode_OK)
///     RET                      ; C3  (1 byte)
/// ```
///
/// Total: 11 bytes. Body writes 3 i32 results to
/// `[RDI+0/4/8]` directly via the MEMORY-class epilogue
/// (cycle-2c implementation); since RDI=results-buf for
/// us, the body fills the caller's buffer naturally.
///
/// Stack alignment: wrapper entry has RSP ≡ 8 (mod 16) per
/// SysV (after caller's CALL pushed return address). XCHG
/// doesn't change RSP. Wrapper's CALL pushes its own return
/// → body entry has RSP ≡ 0 (mod 16) which is SysV-correct
/// (body's PUSH RBP brings it back to ≡ 8).
pub fn emit(
    allocator: std.mem.Allocator,
    params: EmitParams,
) Error!EmitOutput {
    if (builtin.cpu.arch == .aarch64) {
        return emitAarch64(allocator, params);
    }
    if (builtin.cpu.arch != .x86_64) {
        return Error.UnsupportedOp;
    }
    if (builtin.os.tag == .windows) {
        return emitX8664Win64(allocator, params);
    }
    return emitX8664SysV(allocator, params);
}

/// x86_64 SysV wrapper emit. Public so byte-sequence unit tests exercise
/// it on Mac/Linux hosts (the bytes are host-independent; runtime execution
/// requires a SysV x86_64 host) — parity with the public `emitX8664Win64`.
/// D-229: supports the 1-param 2-GPR-result shape (arm64/Win64 parity) —
/// param0 is marshaled from args[0] (RDX) → the body's SysV slot (RSI).
pub fn emitX8664SysV(
    allocator: std.mem.Allocator,
    params: EmitParams,
) Error!EmitOutput {
    if (!all_gpr_class(params.sig.results)) return Error.UnsupportedOp;
    if (!all_gpr_class(params.sig.params)) return Error.UnsupportedOp;

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);

    // Classify shape: MEMORY-class (≥3 GPR results) vs register-class
    // (1-2 results in RAX/RDX). Per SysV §3.2.3.
    const n_results = params.sig.results.len;
    const n_params = params.sig.params.len;
    if (n_results == 3) {
        // 3-int MEMORY-class: body expects RDI=&buf, RSI=rt.
        // Wrapper: XCHG RDI, RSI ; CALL body ; XOR EAX, EAX ; RET.
        // 3-int MEMORY + a param is out of scope (matches arm64).
        if (n_params != 0) return Error.UnsupportedOp;
        try bytes.appendSlice(allocator, &.{ 0x48, 0x87, 0xFE });
        try emitCallRel32(allocator, &bytes, params, 3);
        try bytes.appendSlice(allocator, &.{ 0x31, 0xC0, 0xC3 });
        return .{ .bytes = try bytes.toOwnedSlice(allocator) };
    }

    // D-477 generic GPR register-class path — n_results ∈ {1,2}, n_params ≤ 5
    // (the SysV integer arg registers RSI,RDX,RCX,R8,R9 after RDI=rt; ≥6 params
    // need stack spill, deferred). Body returns result 0 in RAX, result 1 in
    // RDX. Save results_ptr (RSI) to STACK across the CALL (NOT a callee-saved
    // GPR — the body's regalloc may clobber RBX without a paired save for small
    // funcs; 2-int e2e ubuntu fault 0x77 history). Reproduces the prior 0/1-param
    // 2-result shapes byte-for-byte.
    if (n_results < 1 or n_results > 2 or n_params > 5) return Error.UnsupportedOp;

    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xEC, 0x08 }); // SUB RSP, 8 (SysV align)
    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x34, 0x24 }); // MOV [RSP], RSI (save results_ptr)
    var pre_len: u32 = 4 + 4;
    // Marshal args from [RDX + 8k] → SysV body slot. Param 1's dest is RDX
    // (the args_ptr base), so emit every k != 1 first then k == 1 LAST.
    var k: usize = 0;
    while (k < n_params) : (k += 1) {
        if (k == 1) continue;
        const ins = movParamSysV(k);
        try bytes.appendSlice(allocator, ins);
        pre_len += @intCast(ins.len);
    }
    if (n_params >= 2) {
        const ins = movParamSysV(1);
        try bytes.appendSlice(allocator, ins);
        pre_len += @intCast(ins.len);
    }
    try emitCallRel32(allocator, &bytes, params, pre_len);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8B, 0x34, 0x24 }); // MOV RSI, [RSP] (restore)
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xC4, 0x08 }); // ADD RSP, 8
    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x06 }); // MOV [RSI], RAX (result 0)
    if (n_results == 2) try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x56, 0x08 }); // MOV [RSI+8], RDX
    try bytes.appendSlice(allocator, &.{ 0x31, 0xC0, 0xC3 }); // XOR EAX,EAX ; RET

    return .{ .bytes = try bytes.toOwnedSlice(allocator) };
}

/// SysV `MOV <slot>, [RDX + 8*k]` — load arg `k` from the args buffer (base
/// RDX) into the register_write body's param slot. SysV int arg order after
/// RDI=rt: p0=RSI, p1=RDX, p2=RCX, p3=R8, p4=R9. k=0 uses disp-0 (mod=00,
/// 3 bytes); k≥1 uses disp8 (mod=01, 4 bytes).
fn movParamSysV(k: usize) []const u8 {
    return switch (k) {
        0 => &.{ 0x48, 0x8B, 0x32 }, // MOV RSI, [RDX]
        1 => &.{ 0x48, 0x8B, 0x52, 0x08 }, // MOV RDX, [RDX+8]
        2 => &.{ 0x48, 0x8B, 0x4A, 0x10 }, // MOV RCX, [RDX+16]
        3 => &.{ 0x4C, 0x8B, 0x42, 0x18 }, // MOV R8,  [RDX+24]
        4 => &.{ 0x4C, 0x8B, 0x4A, 0x20 }, // MOV R9,  [RDX+32]
        else => unreachable, // n_params ≤ 5 guarded by caller
    };
}

/// x86_64 Win64 wrapper emit. Public so byte-sequence unit
/// tests can exercise it on Mac/Linux hosts (the bytes are
/// host-independent; runtime execution requires Win64).
///
/// Win64 calling convention (per Microsoft x64 ABI):
/// - RCX = arg 0, RDX = arg 1, R8 = arg 2, R9 = arg 3.
/// - Return in RAX (≤ 8 bytes) or via hidden RCX (struct > 8).
/// - 32-byte shadow space reserved by caller below the return
///   address; called function may use it freely.
/// - RBX / RBP / RDI / RSI / R12..R15 callee-saved.
///
/// Wrapper Zig signature `fn(rt, results, args) callconv(.c)
/// u32`: ≤ 8-byte return → no hidden RCX → RCX = rt,
/// RDX = results, R8 = args, return in RAX.
///
/// Currently supports: 2-int register-class shape only. The
/// 3-int MEMORY-class Win64 shape requires the body-side
/// cycle 2c MEMORY-class extension (RCX hidden ptr, RDX rt)
/// which is out of scope for this cycle — see
/// `private/spikes/adr-0106-cycle3e-win64-wrapper/README.md`.
///
/// 2-int register-class shape (33 bytes):
///
/// ```text
///   SUB RSP, 0x28           ; 48 83 EC 28        — shadow(32) + 8 save = 40 bytes
///   MOV [RSP+0x20], RDX     ; 48 89 54 24 20     — save results ptr
///   CALL body                ; E8 + disp32
///   MOV R8, [RSP+0x20]      ; 4C 8B 44 24 20     — recover results in R8 (R8 is caller-saved; OK to use after CALL)
///   MOV [R8], RAX           ; 49 89 00           — result 0 → buf[0]
///   MOV [R8+8], RDX         ; 49 89 50 08        — result 1 → buf[8]
///   ADD RSP, 0x28           ; 48 83 C4 28
///   XOR EAX, EAX            ; 31 C0              — ErrCode_OK
///   RET                      ; C3
/// ```
///
/// Total: 4+5+5+5+3+4+4+2+1 = 33 bytes.
///
/// Stack alignment: Win64 expects body-entry RSP ≡ 8 (mod 16).
/// Wrapper-entry RSP ≡ 8 (mod 16) (caller's CALL pushed ret
/// addr). SUB RSP, 0x28 → RSP ≡ 8-40 ≡ 0 (mod 16). CALL
/// pushes 8 → body sees ≡ 8 (mod 16). ✓
///
/// Body's view at entry:
/// - RCX = rt (unchanged from wrapper's caller-supplied RCX).
/// - RDX = results (clobbered AFTER body; body may use as
///   scratch).
/// - R8 = args (clobbered; body may use).
///
/// Body returns: RAX = result 0, RDX = result 1 (Win64-violating
/// but JIT-emitted body chooses its own internal convention per
/// ADR-0106 path (a) wrapper design).
///
/// Body MUST be compiled with `result_abi = .register_write` AND
/// the body's cycle 2c emit must NOT route 2-int through Win64's
/// hidden-RCX path (= keep RAX/RDX register convention even on
/// Win64). 2-int Win64 goes through register_write naturally
/// (cycle 2c body emit handles both .sysv and .win64
/// MEMORY-class as of D-165 close 2026-05-23 — see
/// `x86_64/emit_setup.zig:104` Win64 arm + `emit.zig:209`
/// `return_is_memory_class` predicate).
pub fn emitX8664Win64(
    allocator: std.mem.Allocator,
    params: EmitParams,
) Error!EmitOutput {
    const n_params = params.sig.params.len;
    const n_results = params.sig.results.len;
    // FP params = a later D-477 slice (this thunk marshals GPR params only;
    // GPR/XMM RESULTS are both handled below).
    if (n_params != 0 and !all_gpr_class(params.sig.params)) return Error.UnsupportedOp;
    const results_all_gpr = all_gpr_class(params.sig.results);
    const results_all_xmm = all_xmm_class(params.sig.results);
    if (!results_all_gpr and !results_all_xmm) return Error.UnsupportedOp;
    // Win64 GPR arg registers after RCX=rt are RDX, R8, R9 → ≤3 register params.
    // ≥4 params need stack args above the 32B shadow space (defer to a later slice).
    if (n_params > 3) return Error.UnsupportedOp;

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);

    // 3-result MEMORY-class (GPR): body takes RCX=&results (hidden ptr), RDX=rt.
    // Only 0-arg + 1-arg supported; 2/3-arg MEMORY deferred (X8 collides with
    // param marshalling order — same deferral as arm64/SysV).
    if (n_results == 3 and results_all_gpr) {
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xEC, 0x28 }); // SUB RSP, 0x28
        if (n_params == 1) {
            // 1-arg: load a0 into R8 (body's a0 slot) while R8 still = args ptr,
            // then swap RCX↔RDX so body sees RCX=&results, RDX=rt.
            try bytes.appendSlice(allocator, &.{ 0x4D, 0x8B, 0x00 }); // MOV R8, [R8]  (a0)
            try bytes.appendSlice(allocator, &.{ 0x48, 0x87, 0xCA }); // XCHG RCX, RDX
            try emitCallRel32(allocator, &bytes, params, 4 + 3 + 3);
        } else if (n_params == 0) {
            try bytes.appendSlice(allocator, &.{ 0x48, 0x87, 0xCA }); // XCHG RCX, RDX
            try emitCallRel32(allocator, &bytes, params, 4 + 3);
        } else return Error.UnsupportedOp;
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xC4, 0x28 }); // ADD RSP, 0x28
        try bytes.appendSlice(allocator, &.{ 0x31, 0xC0, 0xC3 }); // XOR EAX,EAX ; RET
        return .{ .bytes = try bytes.toOwnedSlice(allocator) };
    }

    // 2-XMM register-class (f64,f64): 0-arg only — FP-param marshalling is a
    // later D-477 slice. Body writes XMM0/XMM1; store via MOVQ.
    if (n_results == 2 and results_all_xmm) {
        if (n_params != 0) return Error.UnsupportedOp;
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xEC, 0x28 }); // SUB RSP, 0x28
        try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x54, 0x24, 0x20 }); // MOV [RSP+0x20], RDX
        try emitCallRel32(allocator, &bytes, params, 4 + 5);
        try bytes.appendSlice(allocator, &.{ 0x4C, 0x8B, 0x44, 0x24, 0x20 }); // MOV R8, [RSP+0x20]
        try bytes.appendSlice(allocator, &.{ 0x66, 0x41, 0x0F, 0xD6, 0x00 }); // MOVQ [R8], XMM0
        try bytes.appendSlice(allocator, &.{ 0x66, 0x41, 0x0F, 0xD6, 0x48, 0x08 }); // MOVQ [R8+8], XMM1
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xC4, 0x28 }); // ADD RSP, 0x28
        try bytes.appendSlice(allocator, &.{ 0x31, 0xC0, 0xC3 }); // XOR EAX,EAX ; RET
        return .{ .bytes = try bytes.toOwnedSlice(allocator) };
    }

    // D-477 generic GPR register-class: n_params ≤ 3, n_results ∈ {1,2} GPR.
    // Body (register-write) takes RCX=rt, p0=RDX, p1=R8, p2=R9; returns r0=RAX,
    // r1=RDX. Wrapper entry (Win64): RCX=rt, RDX=results_ptr, R8=args_ptr. Save
    // results_ptr to the shadow slot, marshal args with the reorder (p2→R9 FIRST,
    // p0→RDX, p1→R8 LAST — R8 is the args base so it is consumed last), CALL, then
    // write results back. Reproduces the prior 0/1/3-arg 2-int shapes byte-for-byte
    // and adds 2-param + n_results==1. Alignment: entry RSP≡8, SUB 0x28→≡0, CALL→≡8.
    if ((n_results == 1 or n_results == 2) and results_all_gpr) {
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xEC, 0x28 }); // SUB RSP, 0x28
        try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x54, 0x24, 0x20 }); // MOV [RSP+0x20], RDX
        var pre_len: u32 = 4 + 5;
        if (n_params >= 3) {
            try bytes.appendSlice(allocator, &.{ 0x4D, 0x8B, 0x48, 0x10 }); // MOV R9, [R8+0x10] (p2)
            pre_len += 4;
        }
        if (n_params >= 1) {
            try bytes.appendSlice(allocator, &.{ 0x49, 0x8B, 0x10 }); // MOV RDX, [R8] (p0)
            pre_len += 3;
        }
        if (n_params >= 2) {
            try bytes.appendSlice(allocator, &.{ 0x4D, 0x8B, 0x40, 0x08 }); // MOV R8, [R8+0x08] (p1, last)
            pre_len += 4;
        }
        try emitCallRel32(allocator, &bytes, params, pre_len);
        try bytes.appendSlice(allocator, &.{ 0x4C, 0x8B, 0x44, 0x24, 0x20 }); // MOV R8, [RSP+0x20]
        try bytes.appendSlice(allocator, &.{ 0x49, 0x89, 0x00 }); // MOV [R8], RAX (r0)
        if (n_results == 2) try bytes.appendSlice(allocator, &.{ 0x49, 0x89, 0x50, 0x08 }); // MOV [R8+8], RDX (r1)
        try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xC4, 0x28 }); // ADD RSP, 0x28
        try bytes.appendSlice(allocator, &.{ 0x31, 0xC0, 0xC3 }); // XOR EAX,EAX ; RET
        return .{ .bytes = try bytes.toOwnedSlice(allocator) };
    }

    return Error.UnsupportedOp;
}

/// arm64 AAPCS64 wrapper emit (Mac aarch64).
///
/// AAPCS64 register usage: X0=rt, X1=results, X2=args (per ADR-0106
/// path (a)'s `fn(rt, results, args) callconv(.c) ErrCode`).
/// Body's MEMORY-class path (cycle 2c arm64 implementation) expects
/// X8=indirect-result-pointer + X0=rt; register-class path expects
/// X0=rt + result regs are X0/X1.
///
/// 3-int MEMORY-class shape (the `() → (i32, i32, i32)` SKIP shape):
///   MOV  X8, X1           ; results ptr into X8 hidden arg
///   ADRP X16, body        ; address-of-body high
///   ADD  X16, X16, body_lo
///   BLR  X16
///   MOV  W0, WZR          ; ErrCode_OK = 0
///   RET
///
/// For BLR-via-X16 setup the relative addressing math is more
/// complex than x86_64's CALL rel32. Use a simpler scheme: emit an
/// LDR-from-literal-pool that contains body_addr, then BLR. ~20 bytes.
/// Even simpler for relative-BL: arm64's B/BL is ±128MB range; for
/// in-module dispatch this is always reachable.
///
/// Simplest shape:
///   MOV  X8, X1                ; 0xAA0103E8  — 4 bytes (ORR X8, XZR, X1)
///   BL   body_offset            ; 0x94000000 | (imm26)  — 4 bytes
///   MOV  W0, WZR                ; 0x2A1F03E0  — 4 bytes (ORR W0, WZR, WZR)
///   RET                          ; 0xD65F03C0  — 4 bytes
///
/// Total: 16 bytes. `imm26` is the body-relative-to-call-site
/// displacement in 4-byte words, sign-extended.
fn emitAarch64(allocator: std.mem.Allocator, params: EmitParams) Error!EmitOutput {
    if (!all_gpr_class(params.sig.results)) return Error.UnsupportedOp;
    if (!all_gpr_class(params.sig.params)) return Error.UnsupportedOp;

    const n_results = params.sig.results.len;
    const n_params = params.sig.params.len;
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);

    if (n_results == 3) {
        // Param-bearing 3-result (MEMORY-class via X8) deferred — X8=results
        // collides with param marshalling order; needs the x86_64-style reorder.
        if (n_params != 0) return Error.UnsupportedOp;
        // 3-int MEMORY-class shape (24 bytes):
        //   STP X30, XZR, [SP, #-16]!  ; A9BF7FFE — save LR (BL clobbers X30)
        //   MOV X8, X1                  ; AA0103E8
        //   BL  body                    ; 94??????
        //   LDP X30, XZR, [SP], #16    ; A8C17FFE — restore LR
        //   MOV W0, WZR                 ; 2A1F03E0
        //   RET                          ; D65F03C0
        //
        // X30 (LR) must be saved across BL — BL writes its
        // return address to X30, clobbering the wrapper's own
        // return address (the caller's site). Without the
        // save/restore the wrapper's RET jumps back to the
        // wrapper's BL+4 instead of the caller, infinite loop
        // (observed 2026-05-23 cycle 3e Phase 2'd integration
        // attempt at 99% CPU for 31 min).
        try writeInsn(allocator, &bytes, 0xA9BF7FFE);
        try writeInsn(allocator, &bytes, 0xAA0103E8);
        try emitBLAarch64(allocator, &bytes, params, 8);
        try writeInsn(allocator, &bytes, 0xA8C17FFE);
        try writeInsn(allocator, &bytes, 0x2A1F03E0);
        try writeInsn(allocator, &bytes, 0xD65F03C0);
        return .{ .bytes = try bytes.toOwnedSlice(allocator) };
    }

    // D-477 generic GPR path — n_results ∈ {1,2}, n_params ≤ 7 (the AAPCS64
    // integer arg registers X1..X7 after X0=rt; ≥8 params need stack spill,
    // deferred). The buffer-write thunk receives rt=X0, results_ptr=X1,
    // args_ptr=X2; it stacks results_ptr+LR, marshals each arg from
    // [args_ptr + 8k] into the body's AAPCS slot X{k+1}, BLs the
    // register_write body, then stores each result reg X{i} → [results_ptr+8i].
    // Reproduces the prior hand-written 0/1-param 2-result shapes byte-for-byte.
    // 0-result deferred for cross-arch parity (x86_64 still requires ≥2 results);
    // a 0-result void multi-arg invoke routes via the dispatchVoid* helpers.
    if (n_results < 1 or n_results > 2 or n_params > 7) return Error.UnsupportedOp;

    // STP X1, X30, [SP, #-16]! — save results_ptr (X1) + LR (BL clobbers X30).
    try writeInsn(allocator, &bytes, 0xA9BF7BE1);
    // Marshal args. Param k → body slot X{k+1} via `LDR X{k+1}, [X2, #8k]`.
    // X2 is the args_ptr base, and param 1's destination is X2 itself — so
    // load every k != 1 first (ascending), then k == 1 LAST (its load
    // overwrites the base after all other reads are done).
    var k: usize = 0;
    while (k < n_params) : (k += 1) {
        if (k == 1) continue;
        try writeInsn(allocator, &bytes, ldrParamAarch64(k));
    }
    if (n_params >= 2) try writeInsn(allocator, &bytes, ldrParamAarch64(1));
    // BL body — pre-offset = STP (4) + one LDR (4) per param.
    try emitBLAarch64(allocator, &bytes, params, @intCast(4 + 4 * n_params));
    // LDP X9, X30, [SP], #16 — X9 = results_ptr, X30 = LR.
    try writeInsn(allocator, &bytes, 0xA8C17BE9);
    // Store result i (in X{i}) → [results_ptr + 8i]: `STR X{i}, [X9, #8i]`.
    var i: u32 = 0;
    while (i < n_results) : (i += 1) {
        try writeInsn(allocator, &bytes, 0xF9000000 | (i << 10) | (9 << 5) | i);
    }
    try writeInsn(allocator, &bytes, 0x2A1F03E0); // MOV W0, WZR (ErrCode_OK)
    try writeInsn(allocator, &bytes, 0xD65F03C0); // RET

    return .{ .bytes = try bytes.toOwnedSlice(allocator) };
}

/// AAPCS64 `LDR X{k+1}, [X2, #8*k]` — load arg `k` from the args buffer
/// (base X2) into the register_write body's param slot. Scaled imm12 = k.
fn ldrParamAarch64(k: usize) u32 {
    const t: u32 = @intCast(k + 1);
    const imm12: u32 = @intCast(k);
    return 0xF9400000 | (imm12 << 10) | (@as(u32, 2) << 5) | t;
}

/// Emit a 4-byte BL instruction. `pre_offset` is the number of
/// bytes emitted BEFORE this BL in the wrapper (used to compute
/// the wrapper-relative offset where the BL itself lives).
fn emitBLAarch64(
    allocator: std.mem.Allocator,
    bytes: *std.ArrayList(u8),
    params: EmitParams,
    pre_offset: u32,
) Error!void {
    const bl_site: i64 = @as(i64, @intCast(params.thunk_offset)) +
        @as(i64, @intCast(pre_offset));
    const disp_bytes: i64 = @as(i64, @intCast(params.body_offset)) - bl_site;
    if (@mod(disp_bytes, 4) != 0) return Error.UnsupportedOp;
    const disp_words: i32 = @intCast(@divExact(disp_bytes, 4));
    const imm26: u32 = @bitCast(disp_words);
    try writeInsn(allocator, bytes, 0x94000000 | (imm26 & 0x03FFFFFF));
}

fn writeInsn(allocator: std.mem.Allocator, bytes: *std.ArrayList(u8), word: u32) Error!void {
    var b: [4]u8 = undefined;
    std.mem.writeInt(u32, &b, word, .little);
    try bytes.appendSlice(allocator, &b);
}

fn all_gpr_class(results: []const @import("../../../ir/zir.zig").ValType) bool {
    for (results) |r| switch (r) {
        // 10.G op_gc cycle 2: i31ref is a u32 GcRef (low-bit-tagged
        // i32 per ADR-0116) — fits the gpr class like other reftypes.
        .i32, .i64, .ref => {},
        .f32, .f64, .v128 => return false,
    };
    return true;
}

fn all_xmm_class(results: []const @import("../../../ir/zir.zig").ValType) bool {
    for (results) |r| switch (r) {
        .f32, .f64 => {},
        .i32, .i64, .ref, .v128 => return false,
    };
    return true;
}

/// Emit `CALL rel32`. `instr_pre_len` is the number of bytes
/// emitted BEFORE this CALL in the wrapper (used to compute
/// the wrapper-relative offset where the disp32 is measured
/// from — which is the byte after the CALL = thunk_offset +
/// instr_pre_len + 5).
fn emitCallRel32(
    allocator: std.mem.Allocator,
    bytes: *std.ArrayList(u8),
    params: EmitParams,
    instr_pre_len: u32,
) Error!void {
    const call_site_after: i64 = @as(i64, @intCast(params.thunk_offset)) +
        @as(i64, @intCast(instr_pre_len)) + 5;
    const disp: i32 = @intCast(@as(i64, @intCast(params.body_offset)) - call_site_after);
    try bytes.append(allocator, 0xE8);
    var disp_bytes: [4]u8 = undefined;
    std.mem.writeInt(i32, &disp_bytes, disp, .little);
    try bytes.appendSlice(allocator, &disp_bytes);
}

const testing = std.testing;
const skip = @import("../../../test_support/skip.zig");

test "wrapper_thunk: emitX8664Win64 2-int register-class (i32, i64) (33 bytes)" {
    // Pure byte-sequence test — no host gating. The bytes are
    // independent of the host's cpu/os; runtime execution
    // requires Win64 (verified at Phase boundary windowsmini
    // reconciliation, not per-chunk).
    const results = [_]@TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32)){ .i32, .i64 };
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &results },
        .body_offset = 100,
        .thunk_offset = 0,
    };
    const out = try emitX8664Win64(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 33), out.bytes.len);
    // SUB RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xEC, 0x28 }, out.bytes[0..4]);
    // MOV [RSP+0x20], RDX
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x54, 0x24, 0x20 }, out.bytes[4..9]);
    // CALL body_offset(100) - (0 + 9 + 5) = 86
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[9]);
    const disp = std.mem.readInt(i32, out.bytes[10..14], .little);
    try testing.expectEqual(@as(i32, 86), disp);
    // MOV R8, [RSP+0x20]
    try testing.expectEqualSlices(u8, &.{ 0x4C, 0x8B, 0x44, 0x24, 0x20 }, out.bytes[14..19]);
    // MOV [R8], RAX
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x00 }, out.bytes[19..22]);
    // MOV [R8+8], RDX
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x50, 0x08 }, out.bytes[22..26]);
    // ADD RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xC4, 0x28 }, out.bytes[26..30]);
    // XOR EAX, EAX ; RET
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[30..33]);
}

test "wrapper_thunk: emitX8664Win64 3-int MEMORY-class (19 bytes)" {
    const results = [_]@TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32)){ .i32, .i32, .i32 };
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &results },
        .body_offset = 200,
        .thunk_offset = 0,
    };
    const out = try emitX8664Win64(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 19), out.bytes.len);
    // SUB RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xEC, 0x28 }, out.bytes[0..4]);
    // XCHG RCX, RDX
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x87, 0xCA }, out.bytes[4..7]);
    // CALL body_offset(200) - (0 + 7 + 5) = 188
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[7]);
    const disp = std.mem.readInt(i32, out.bytes[8..12], .little);
    try testing.expectEqual(@as(i32, 188), disp);
    // ADD RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xC4, 0x28 }, out.bytes[12..16]);
    // XOR EAX, EAX ; RET
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[16..19]);
}

test "wrapper_thunk: emitX8664Win64 1-arg 2-int register-class (i32) -> (i32, i32) (36 bytes)" {
    // D-167 spike step (1) — first per-shape Mac byte test
    // for 1-arg + 2-int-result Win64 wrapper. Byte sequence
    // from private/spikes/d167-win64-multi-arg-wrapper/README.md
    // "Win64 byte sequences (proven from cycle 21-24)".
    //
    // Body convention (ADR-0106 path (a)): RCX=rt, RDX=a0, body
    // writes RAX = result 0, RDX = result 1. Wrapper bridges
    // Win64 ABI (RCX=rt, RDX=results, R8=args) to body view by
    // saving results to shadow space, loading a0 from [R8], then
    // restoring R8 = results after CALL and writing RAX/RDX out.
    const ValType = @import("../../../ir/zir.zig").ValType;
    const params_arr = [_]ValType{.i32};
    const results = [_]ValType{ .i32, .i32 };
    const params: EmitParams = .{
        .sig = .{ .params = &params_arr, .results = &results },
        .body_offset = 200,
        .thunk_offset = 0,
    };
    const out = try emitX8664Win64(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 36), out.bytes.len);
    // SUB RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xEC, 0x28 }, out.bytes[0..4]);
    // MOV [RSP+0x20], RDX  (save results ptr to shadow space)
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x54, 0x24, 0x20 }, out.bytes[4..9]);
    // MOV RDX, [R8]  (load a0 — body expects RDX=a0)
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x8B, 0x10 }, out.bytes[9..12]);
    // CALL rel32: body_offset(200) - (0 + 12 + 5) = 183
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[12]);
    const disp = std.mem.readInt(i32, out.bytes[13..17], .little);
    try testing.expectEqual(@as(i32, 183), disp);
    // MOV R8, [RSP+0x20]  (restore results ptr into R8)
    try testing.expectEqualSlices(u8, &.{ 0x4C, 0x8B, 0x44, 0x24, 0x20 }, out.bytes[17..22]);
    // MOV [R8], RAX
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x00 }, out.bytes[22..25]);
    // MOV [R8+8], RDX
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x50, 0x08 }, out.bytes[25..29]);
    // ADD RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xC4, 0x28 }, out.bytes[29..33]);
    // XOR EAX, EAX ; RET
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[33..36]);
}

test "wrapper_thunk: emitX8664Win64 D-477 2-param 1-result (i32,i32)->i32 (36 bytes)" {
    // Pure byte test. Body: RCX=rt, RDX=p0, R8=p1; returns RAX. Wrapper saves
    // results_ptr (RDX) to shadow, loads p0→RDX then p1→R8 (R8=args base, last).
    const VT = @import("../../../ir/zir.zig").ValType;
    const p = [_]VT{ .i32, .i32 };
    const results = [_]VT{.i32};
    const out = try emitX8664Win64(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 100, .thunk_offset = 0 });
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 36), out.bytes.len);
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x54, 0x24, 0x20 }, out.bytes[4..9]); // MOV [RSP+0x20], RDX
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x8B, 0x10 }, out.bytes[9..12]); // MOV RDX, [R8] (p0)
    try testing.expectEqualSlices(u8, &.{ 0x4D, 0x8B, 0x40, 0x08 }, out.bytes[12..16]); // MOV R8, [R8+8] (p1, last)
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[16]); // CALL
    try testing.expectEqual(@as(i32, 79), std.mem.readInt(i32, out.bytes[17..21], .little)); // 100-(16+5)
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x00 }, out.bytes[26..29]); // MOV [R8], RAX (single result)
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[33..36]); // XOR EAX,EAX ; RET
}

test "wrapper_thunk: emitX8664Win64 D-477 2-param 2-result (40 bytes)" {
    const VT = @import("../../../ir/zir.zig").ValType;
    const p = [_]VT{ .i32, .i32 };
    const results = [_]VT{ .i32, .i32 };
    const out = try emitX8664Win64(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 100, .thunk_offset = 0 });
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 40), out.bytes.len);
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x8B, 0x10 }, out.bytes[9..12]); // p0→RDX
    try testing.expectEqualSlices(u8, &.{ 0x4D, 0x8B, 0x40, 0x08 }, out.bytes[12..16]); // p1→R8 last
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x00 }, out.bytes[26..29]); // MOV [R8], RAX
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x50, 0x08 }, out.bytes[29..33]); // MOV [R8+8], RDX
}

test "wrapper_thunk: emitX8664Win64 D-477 1-param 1-result (32 bytes)" {
    const VT = @import("../../../ir/zir.zig").ValType;
    const p = [_]VT{.i32};
    const results = [_]VT{.i32};
    const out = try emitX8664Win64(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 100, .thunk_offset = 0 });
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 32), out.bytes.len);
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x8B, 0x10 }, out.bytes[9..12]); // p0→RDX
    try testing.expectEqual(@as(i32, 83), std.mem.readInt(i32, out.bytes[13..17], .little)); // 100-(12+5)
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x00 }, out.bytes[22..25]); // MOV [R8], RAX
}

test "wrapper_thunk: emitX8664Win64 D-477 4-param → UnsupportedOp (≥4 = stack-spill, deferred)" {
    const VT = @import("../../../ir/zir.zig").ValType;
    const p = [_]VT{ .i32, .i32, .i32, .i32 };
    const results = [_]VT{.i32};
    try testing.expectError(Error.UnsupportedOp, emitX8664Win64(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 100, .thunk_offset = 0 }));
}

test "wrapper_thunk: emitX8664SysV 1-param 2-int register-class (i32) -> (i32, i32) (34 bytes, D-229)" {
    // D-229 — x86_64 SysV param-bearing wrapper thunk. Host-independent byte
    // test (emitX8664SysV is public, like emitX8664Win64). Body convention:
    // RDI=rt, RSI=param0; body writes RAX=result0, RDX=result1. Wrapper saves
    // results-ptr (RSI) to stack, marshals param0 = args[0] ([RDX]) into RSI,
    // CALLs body, restores RSI, writes RAX/RDX out.
    const ValType = @import("../../../ir/zir.zig").ValType;
    const params_arr = [_]ValType{.i32};
    const results = [_]ValType{ .i32, .i32 };
    const params: EmitParams = .{
        .sig = .{ .params = &params_arr, .results = &results },
        .body_offset = 200,
        .thunk_offset = 0,
    };
    const out = try emitX8664SysV(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 34), out.bytes.len);
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xEC, 0x08 }, out.bytes[0..4]); // SUB RSP, 8
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x34, 0x24 }, out.bytes[4..8]); // MOV [RSP], RSI
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x8B, 0x32 }, out.bytes[8..11]); // MOV RSI, [RDX] (param0)
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[11]); // CALL rel32
    const disp = std.mem.readInt(i32, out.bytes[12..16], .little);
    try testing.expectEqual(@as(i32, 184), disp); // body(200) - (0 + 11 + 5)
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x8B, 0x34, 0x24 }, out.bytes[16..20]); // MOV RSI, [RSP]
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xC4, 0x08 }, out.bytes[20..24]); // ADD RSP, 8
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x06 }, out.bytes[24..27]); // MOV [RSI], RAX
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x56, 0x08 }, out.bytes[27..31]); // MOV [RSI+8], RDX
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[31..34]); // XOR EAX,EAX ; RET
}

test "wrapper_thunk: emitX8664Win64 3-arg 2-int register-class (i64, i64, i32) -> (i64, i32) (44 bytes)" {
    // D-167 spike step (1) shape 2/3 — 3-arg + 2-int Win64
    // wrapper. Byte sequence from
    // private/spikes/d167-win64-multi-arg-wrapper/README.md
    // "Win64 byte sequences (proven from cycle 21-24)".
    //
    // Critical: a2 MUST be loaded FIRST into R9, then a0 into
    // RDX, then a1 into R8 LAST. Reason: wrapper-entry R8
    // holds args ptr; loading a1 into R8 overwrites it, so a2
    // (which lives at args[2] = [R8+16]) must be hoisted out
    // before that overwrite. Body view at entry: RCX=rt,
    // RDX=a0, R8=a1, R9=a2 (Win64 GPR arg slots 0-3).
    //
    // Concrete helper: `callI64i32_i64i64i32` — Value slot
    // size is 8 bytes, so args[0]=[R8], args[1]=[R8+8],
    // args[2]=[R8+16] regardless of i32/i64 distinction (i32
    // occupies low 32 bits; high bits zero per Wasm-Value
    // convention).
    const ValType = @import("../../../ir/zir.zig").ValType;
    const params_arr = [_]ValType{ .i64, .i64, .i32 };
    const results = [_]ValType{ .i64, .i32 };
    const params: EmitParams = .{
        .sig = .{ .params = &params_arr, .results = &results },
        .body_offset = 300,
        .thunk_offset = 0,
    };
    const out = try emitX8664Win64(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 44), out.bytes.len);
    // SUB RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xEC, 0x28 }, out.bytes[0..4]);
    // MOV [RSP+0x20], RDX  (save results ptr)
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x54, 0x24, 0x20 }, out.bytes[4..9]);
    // MOV R9, [R8+0x10]  (a2 FIRST — before R8 gets overwritten)
    try testing.expectEqualSlices(u8, &.{ 0x4D, 0x8B, 0x48, 0x10 }, out.bytes[9..13]);
    // MOV RDX, [R8]  (a0)
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x8B, 0x10 }, out.bytes[13..16]);
    // MOV R8, [R8+0x08]  (a1 LAST — R8 now reused for a1)
    try testing.expectEqualSlices(u8, &.{ 0x4D, 0x8B, 0x40, 0x08 }, out.bytes[16..20]);
    // CALL rel32: body_offset(300) - (0 + 20 + 5) = 275
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[20]);
    const disp = std.mem.readInt(i32, out.bytes[21..25], .little);
    try testing.expectEqual(@as(i32, 275), disp);
    // MOV R8, [RSP+0x20]
    try testing.expectEqualSlices(u8, &.{ 0x4C, 0x8B, 0x44, 0x24, 0x20 }, out.bytes[25..30]);
    // MOV [R8], RAX
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x00 }, out.bytes[30..33]);
    // MOV [R8+8], RDX
    try testing.expectEqualSlices(u8, &.{ 0x49, 0x89, 0x50, 0x08 }, out.bytes[33..37]);
    // ADD RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xC4, 0x28 }, out.bytes[37..41]);
    // XOR EAX, EAX ; RET
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[41..44]);
}

test "wrapper_thunk: emitX8664Win64 1-arg 3-int MEMORY-class (i32) -> (i32, i32, i64) (22 bytes)" {
    // D-167 spike step (1) shape 3/3 — 1-arg + 3-int Win64
    // MEMORY-class wrapper. Body uses Win64 MEMORY-class
    // convention: RCX = hidden ptr to results buf, RDX = rt,
    // R8 = a0 (Win64 GPR slot 2 for the first non-hidden
    // arg). Mirrors the existing 0-arg 3-int arm (19 bytes)
    // plus a `MOV R8, [R8]` that loads a0 from args[0] while
    // R8 still holds the args ptr — after the MOV, R8 holds
    // a0 and the args ptr is consumed.
    //
    // Body-side cycle 2c Win64 MEMORY-class emit landed at
    // D-165 close (see comment on 0-arg 3-int arm above).
    //
    // Concrete helper: `callI32i32i64_i32` — 1 i32 arg, 3
    // results (i32, i32, i64); the i64 result is what pushes
    // the result count past 2 and forces MEMORY-class on Win64.
    const ValType = @import("../../../ir/zir.zig").ValType;
    const params_arr = [_]ValType{.i32};
    const results = [_]ValType{ .i32, .i32, .i64 };
    const params: EmitParams = .{
        .sig = .{ .params = &params_arr, .results = &results },
        .body_offset = 400,
        .thunk_offset = 0,
    };
    const out = try emitX8664Win64(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 22), out.bytes.len);
    // SUB RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xEC, 0x28 }, out.bytes[0..4]);
    // MOV R8, [R8]  (a0 from args[0])
    try testing.expectEqualSlices(u8, &.{ 0x4D, 0x8B, 0x00 }, out.bytes[4..7]);
    // XCHG RCX, RDX  (swap rt ↔ results so body sees RCX=results, RDX=rt)
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x87, 0xCA }, out.bytes[7..10]);
    // CALL rel32: body_offset(400) - (0 + 10 + 5) = 385
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[10]);
    const disp = std.mem.readInt(i32, out.bytes[11..15], .little);
    try testing.expectEqual(@as(i32, 385), disp);
    // ADD RSP, 0x28
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xC4, 0x28 }, out.bytes[15..19]);
    // XOR EAX, EAX ; RET
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[19..22]);
}

test "wrapper_thunk: EmitParams + EmitOutput types present" {
    // Compile-time sanity: the types exist and have the
    // expected fields. Once Phase 2' lands, additional
    // tests verify byte-sequence correctness per arch.
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &.{} },
        .body_offset = 0,
        .thunk_offset = 0,
    };
    _ = params;
}

test "wrapper_thunk: end-to-end execution — () → (i32, i32, i32) via wrapper" {
    // D-193 triage (cycle 41): ungated. Body uses comptime arch
    // dispatch (arm64 vs x86_64 emit.zig) so Linux aarch64 / Mac
    // x86_64 / Linux x86_64 SysV all execute the right path. CI
    // matrix only runs Mac aarch64 + Linux x86_64 + Win — the
    // prior Mac-aarch64-only gate was overly cautious. Win
    // deferred per ADR-0122 phaseEnd batch.
    if (builtin.os.tag == .windows) return skip.phaseEnd(.win64);
    // Build ZirFunc: () → (i32, i32, i32); body = 11; 22; 33; end.
    const zir = @import("../../../ir/zir.zig");
    const ZirFunc = zir.ZirFunc;
    const regalloc = @import("regalloc.zig");
    const native_emit = if (builtin.cpu.arch == .aarch64)
        @import("../arm64/emit.zig")
    else
        @import("../x86_64/emit.zig");
    const jit_mem = @import("../../../platform/jit_mem.zig");
    const entry_buf = @import("entry_buffer_write.zig");

    const sig: zir.FuncType = .{ .params = &.{}, .results = &.{ .i32, .i32, .i32 } };
    var f = ZirFunc.init(0, sig, &.{});
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 11 });
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 22 });
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 33 });
    try f.instrs.append(testing.allocator, .{ .op = .end });
    f.liveness = .{ .ranges = &[_]zir.LiveRange{
        .{ .def_pc = 0, .last_use_pc = 3 },
        .{ .def_pc = 1, .last_use_pc = 3 },
        .{ .def_pc = 2, .last_use_pc = 3 },
    } };
    const slots = [_]u16{ 0, 1, 2 };
    // result_abi=.register_write (default): body uses MEMORY-class
    // for > 2 results per cycle 2c emit; wrapper bridges the
    // entry-helper-vs-MEMORY-class boundary.
    const alloc: regalloc.Allocation = .{
        .slots = &slots,
        .n_slots = 3,
        .result_abi = .register_write,
    };
    const sigs = [_]zir.FuncType{sig};
    const body_out = try native_emit.compile(testing.allocator, &f, alloc, &sigs, &.{}, 0, &.{}, &.{}, .i32, &.{}, false);
    defer native_emit.deinit(testing.allocator, body_out);

    // Wrapper goes IMMEDIATELY AFTER the body in JIT memory.
    const body_offset: u32 = 0;
    const thunk_offset: u32 = @intCast(body_out.bytes.len);

    const wrapper_out = try emit(testing.allocator, .{
        .sig = sig,
        .body_offset = body_offset,
        .thunk_offset = thunk_offset,
    });
    defer testing.allocator.free(wrapper_out.bytes);

    // Allocate JIT memory + copy body + wrapper.
    const total_size = body_out.bytes.len + wrapper_out.bytes.len;
    var block = try jit_mem.alloc(total_size);
    defer jit_mem.free(block);
    try jit_mem.setWritable(block);
    @memcpy(block.bytes[body_offset..][0..body_out.bytes.len], body_out.bytes);
    @memcpy(block.bytes[thunk_offset..][0..wrapper_out.bytes.len], wrapper_out.bytes);
    try jit_mem.setExecutable(block);

    // Wrapper's address = block.bytes.ptr + thunk_offset.
    const fn_ptr: entry_buf.BufferWriteFn = @ptrCast(@alignCast(block.bytes.ptr + thunk_offset));
    var rt: entry_buf.JitRuntime = .{
        .vm_base = undefined,
        .mem_limit = 0,
        .funcptr_base = undefined,
        .table_size = 0,
        .typeidx_base = undefined,
        .trap_flag = 0,
        .globals_base = undefined,
        .globals_count = 0,
        .host_dispatch_base = undefined,
        .host_dispatch_count = 0,
    };
    var args_buf: [1]u64 = .{0};
    var results_buf: [3]u64 = .{ 0, 0, 0 };
    try entry_buf.invokeBufferWrite(&rt, fn_ptr, &args_buf, &results_buf);
    try testing.expectEqual(@as(u32, 11), @as(u32, @intCast(results_buf[0] & 0xFFFFFFFF)));
    try testing.expectEqual(@as(u32, 22), @as(u32, @intCast(results_buf[1] & 0xFFFFFFFF)));
    try testing.expectEqual(@as(u32, 33), @as(u32, @intCast(results_buf[2] & 0xFFFFFFFF)));
}

test "wrapper_thunk: end-to-end execution — () → (i32, i64) via wrapper" {
    // D-193 triage (cycle 41): ungated. Body uses comptime arch
    // dispatch (arm64 vs x86_64 emit.zig) so Linux aarch64 / Mac
    // x86_64 / Linux x86_64 SysV all execute the right path. CI
    // matrix only runs Mac aarch64 + Linux x86_64 + Win — the
    // prior Mac-aarch64-only gate was overly cautious. Win
    // deferred per ADR-0122 phaseEnd batch.
    if (builtin.os.tag == .windows) return skip.phaseEnd(.win64);
    const zir = @import("../../../ir/zir.zig");
    const ZirFunc = zir.ZirFunc;
    const regalloc = @import("regalloc.zig");
    const native_emit = if (builtin.cpu.arch == .aarch64)
        @import("../arm64/emit.zig")
    else
        @import("../x86_64/emit.zig");
    const jit_mem = @import("../../../platform/jit_mem.zig");
    const entry_buf = @import("entry_buffer_write.zig");

    const sig: zir.FuncType = .{ .params = &.{}, .results = &.{ .i32, .i64 } };
    var f = ZirFunc.init(0, sig, &.{});
    defer f.deinit(testing.allocator);
    try f.instrs.append(testing.allocator, .{ .op = .@"i32.const", .payload = 0x77 });
    try f.instrs.append(testing.allocator, .{ .op = .@"i64.const", .payload = 0xABCDEF12 });
    try f.instrs.append(testing.allocator, .{ .op = .end });
    f.liveness = .{ .ranges = &[_]zir.LiveRange{
        .{ .def_pc = 0, .last_use_pc = 2 },
        .{ .def_pc = 1, .last_use_pc = 2 },
    } };
    const slots = [_]u16{ 0, 1 };
    const alloc: regalloc.Allocation = .{
        .slots = &slots,
        .n_slots = 2,
        .result_abi = .register_write,
    };
    const sigs = [_]zir.FuncType{sig};
    const body_out = try native_emit.compile(testing.allocator, &f, alloc, &sigs, &.{}, 0, &.{}, &.{}, .i32, &.{}, false);
    defer native_emit.deinit(testing.allocator, body_out);

    const body_offset: u32 = 0;
    const thunk_offset: u32 = @intCast(body_out.bytes.len);

    const wrapper_out = try emit(testing.allocator, .{
        .sig = sig,
        .body_offset = body_offset,
        .thunk_offset = thunk_offset,
    });
    defer testing.allocator.free(wrapper_out.bytes);

    const total_size = body_out.bytes.len + wrapper_out.bytes.len;
    var block = try jit_mem.alloc(total_size);
    defer jit_mem.free(block);
    try jit_mem.setWritable(block);
    @memcpy(block.bytes[body_offset..][0..body_out.bytes.len], body_out.bytes);
    @memcpy(block.bytes[thunk_offset..][0..wrapper_out.bytes.len], wrapper_out.bytes);
    try jit_mem.setExecutable(block);

    const fn_ptr: entry_buf.BufferWriteFn = @ptrCast(@alignCast(block.bytes.ptr + thunk_offset));
    var rt: entry_buf.JitRuntime = .{
        .vm_base = undefined,
        .mem_limit = 0,
        .funcptr_base = undefined,
        .table_size = 0,
        .typeidx_base = undefined,
        .trap_flag = 0,
        .globals_base = undefined,
        .globals_count = 0,
        .host_dispatch_base = undefined,
        .host_dispatch_count = 0,
    };
    var args_buf: [1]u64 = .{0};
    var results_buf: [2]u64 = .{ 0, 0 };
    try entry_buf.invokeBufferWrite(&rt, fn_ptr, &args_buf, &results_buf);
    try testing.expectEqual(@as(u32, 0x77), @as(u32, @intCast(results_buf[0] & 0xFFFFFFFF)));
    try testing.expectEqual(@as(u64, 0xABCDEF12), results_buf[1]);
}

test "wrapper_thunk: emit returns UnsupportedOp for 0-result sig" {
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &.{} },
        .body_offset = 0,
        .thunk_offset = 0,
    };
    const r = emit(testing.allocator, params);
    try testing.expectError(Error.UnsupportedOp, r);
}

test "wrapper_thunk: emit aarch64 2-int register-class (i32, i64) (28 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig:1041 (x86_64 SysV)
    if (comptime builtin.cpu.arch != .aarch64) return;
    const results = [_]@TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32)){ .i32, .i64 };
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &results },
        .body_offset = 256,
        .thunk_offset = 0,
    };
    const out = try emit(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 28), out.bytes.len);
    // STP X1, X30, [SP, #-16]!
    try testing.expectEqual(@as(u32, 0xA9BF7BE1), std.mem.readInt(u32, out.bytes[0..4], .little));
    // BL body_offset(256) - bl_site(4) = 252 bytes = 63 words → imm26 = 63
    const bl = std.mem.readInt(u32, out.bytes[4..8], .little);
    try testing.expectEqual(@as(u32, 0x94000000 | 63), bl);
    // LDP X9, X30, [SP], #16
    try testing.expectEqual(@as(u32, 0xA8C17BE9), std.mem.readInt(u32, out.bytes[8..12], .little));
    // STR X0, [X9, #0]
    try testing.expectEqual(@as(u32, 0xF9000120), std.mem.readInt(u32, out.bytes[12..16], .little));
    // STR X1, [X9, #8]
    try testing.expectEqual(@as(u32, 0xF9000521), std.mem.readInt(u32, out.bytes[16..20], .little));
    // MOV W0, WZR
    try testing.expectEqual(@as(u32, 0x2A1F03E0), std.mem.readInt(u32, out.bytes[20..24], .little));
    // RET
    try testing.expectEqual(@as(u32, 0xD65F03C0), std.mem.readInt(u32, out.bytes[24..28], .little));
}

test "wrapper_thunk: emit aarch64 1-param 2-int register-class (32 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig:1041 (x86_64 SysV)
    if (comptime builtin.cpu.arch != .aarch64) return;
    const VT = @TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32));
    const p = [_]VT{.i32};
    const results = [_]VT{ .i32, .i64 };
    const params: EmitParams = .{
        .sig = .{ .params = &p, .results = &results },
        .body_offset = 256,
        .thunk_offset = 0,
    };
    const out = try emit(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 32), out.bytes.len);
    // STP X1, X30, [SP, #-16]!
    try testing.expectEqual(@as(u32, 0xA9BF7BE1), std.mem.readInt(u32, out.bytes[0..4], .little));
    // LDR X1, [X2, #0]  — param0 from args buffer into the body's AAPCS slot
    try testing.expectEqual(@as(u32, 0xF9400041), std.mem.readInt(u32, out.bytes[4..8], .little));
    // BL body(256) - bl_site(8) = 248 bytes = 62 words → imm26 = 62
    try testing.expectEqual(@as(u32, 0x94000000 | 62), std.mem.readInt(u32, out.bytes[8..12], .little));
    // LDP X9, X30, [SP], #16
    try testing.expectEqual(@as(u32, 0xA8C17BE9), std.mem.readInt(u32, out.bytes[12..16], .little));
    // STR X0, [X9, #0] ; STR X1, [X9, #8]
    try testing.expectEqual(@as(u32, 0xF9000120), std.mem.readInt(u32, out.bytes[16..20], .little));
    try testing.expectEqual(@as(u32, 0xF9000521), std.mem.readInt(u32, out.bytes[20..24], .little));
    // MOV W0, WZR ; RET
    try testing.expectEqual(@as(u32, 0x2A1F03E0), std.mem.readInt(u32, out.bytes[24..28], .little));
    try testing.expectEqual(@as(u32, 0xD65F03C0), std.mem.readInt(u32, out.bytes[28..32], .little));
}

test "wrapper_thunk: emit aarch64 D-477 2-param 1-result (i32,i32)->i32 (32 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig (emitX8664SysV — x86_64 N-param parity is a later D-477 slice)
    if (comptime builtin.cpu.arch != .aarch64) return;
    const VT = @TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32));
    const p = [_]VT{ .i32, .i32 };
    const results = [_]VT{.i32};
    const out = try emit(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 256, .thunk_offset = 0 });
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 32), out.bytes.len);
    try testing.expectEqual(@as(u32, 0xA9BF7BE1), std.mem.readInt(u32, out.bytes[0..4], .little)); // STP X1,X30,[SP,#-16]!
    try testing.expectEqual(@as(u32, 0xF9400041), std.mem.readInt(u32, out.bytes[4..8], .little)); // LDR X1,[X2,#0]  (p0)
    try testing.expectEqual(@as(u32, 0xF9400442), std.mem.readInt(u32, out.bytes[8..12], .little)); // LDR X2,[X2,#8]  (p1, last)
    try testing.expectEqual(@as(u32, 0x94000000 | 61), std.mem.readInt(u32, out.bytes[12..16], .little)); // BL: (256-12)/4=61
    try testing.expectEqual(@as(u32, 0xA8C17BE9), std.mem.readInt(u32, out.bytes[16..20], .little)); // LDP X9,X30,[SP],#16
    try testing.expectEqual(@as(u32, 0xF9000120), std.mem.readInt(u32, out.bytes[20..24], .little)); // STR X0,[X9,#0]
    try testing.expectEqual(@as(u32, 0x2A1F03E0), std.mem.readInt(u32, out.bytes[24..28], .little)); // MOV W0,WZR
    try testing.expectEqual(@as(u32, 0xD65F03C0), std.mem.readInt(u32, out.bytes[28..32], .little)); // RET
}

test "wrapper_thunk: emit aarch64 D-477 3-param 1-result — load order p0,p2,p1 (36 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig (emitX8664SysV — x86_64 N-param parity is a later D-477 slice)
    if (comptime builtin.cpu.arch != .aarch64) return;
    const VT = @TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32));
    const p = [_]VT{ .i32, .i32, .i32 };
    const results = [_]VT{.i32};
    const out = try emit(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 256, .thunk_offset = 0 });
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 36), out.bytes.len);
    try testing.expectEqual(@as(u32, 0xA9BF7BE1), std.mem.readInt(u32, out.bytes[0..4], .little));
    // p0→X1, then p2→X3 (skips p1), then p1→X2 LAST — the base X2 survives every read.
    try testing.expectEqual(@as(u32, 0xF9400041), std.mem.readInt(u32, out.bytes[4..8], .little)); // LDR X1,[X2,#0]
    try testing.expectEqual(@as(u32, 0xF9400843), std.mem.readInt(u32, out.bytes[8..12], .little)); // LDR X3,[X2,#16]
    try testing.expectEqual(@as(u32, 0xF9400442), std.mem.readInt(u32, out.bytes[12..16], .little)); // LDR X2,[X2,#8]
    try testing.expectEqual(@as(u32, 0x94000000 | 60), std.mem.readInt(u32, out.bytes[16..20], .little)); // BL: (256-16)/4=60
    try testing.expectEqual(@as(u32, 0xA8C17BE9), std.mem.readInt(u32, out.bytes[20..24], .little));
    try testing.expectEqual(@as(u32, 0xF9000120), std.mem.readInt(u32, out.bytes[24..28], .little));
    try testing.expectEqual(@as(u32, 0x2A1F03E0), std.mem.readInt(u32, out.bytes[28..32], .little));
    try testing.expectEqual(@as(u32, 0xD65F03C0), std.mem.readInt(u32, out.bytes[32..36], .little));
}

test "wrapper_thunk: emit aarch64 D-477 4-param 1-result (40 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig (emitX8664SysV — x86_64 N-param parity is a later D-477 slice)
    if (comptime builtin.cpu.arch != .aarch64) return;
    const VT = @TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32));
    const p = [_]VT{ .i32, .i32, .i32, .i32 };
    const results = [_]VT{.i32};
    const out = try emit(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 256, .thunk_offset = 0 });
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 40), out.bytes.len);
    try testing.expectEqual(@as(u32, 0xF9400041), std.mem.readInt(u32, out.bytes[4..8], .little)); // p0→X1
    try testing.expectEqual(@as(u32, 0xF9400843), std.mem.readInt(u32, out.bytes[8..12], .little)); // p2→X3
    try testing.expectEqual(@as(u32, 0xF9400C44), std.mem.readInt(u32, out.bytes[12..16], .little)); // p3→X4
    try testing.expectEqual(@as(u32, 0xF9400442), std.mem.readInt(u32, out.bytes[16..20], .little)); // p1→X2 LAST
    try testing.expectEqual(@as(u32, 0x94000000 | 59), std.mem.readInt(u32, out.bytes[20..24], .little)); // BL: (256-20)/4=59
}

test "wrapper_thunk: emit aarch64 D-477 8-param → UnsupportedOp (no stack-spill yet)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig (emitX8664SysV — x86_64 N-param parity is a later D-477 slice)
    if (comptime builtin.cpu.arch != .aarch64) return;
    const VT = @TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32));
    const p = [_]VT{ .i32, .i32, .i32, .i32, .i32, .i32, .i32, .i32 };
    const results = [_]VT{.i32};
    try testing.expectError(Error.UnsupportedOp, emit(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 256, .thunk_offset = 0 }));
}

test "wrapper_thunk: emit aarch64 3-int MEMORY-class (24 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig:1041 (x86_64 SysV)
    if (comptime builtin.cpu.arch != .aarch64) return;
    const i32_results = [_]@TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32)){ .i32, .i32, .i32 };
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &i32_results },
        .body_offset = 64,
        .thunk_offset = 0,
    };
    const out = try emit(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 24), out.bytes.len);
    // STP X30, XZR, [SP, #-16]!
    try testing.expectEqual(@as(u32, 0xA9BF7FFE), std.mem.readInt(u32, out.bytes[0..4], .little));
    // MOV X8, X1
    try testing.expectEqual(@as(u32, 0xAA0103E8), std.mem.readInt(u32, out.bytes[4..8], .little));
    // BL body_offset(64) - bl_site(8) = +56 bytes = +14 words → imm26 = 14
    const bl = std.mem.readInt(u32, out.bytes[8..12], .little);
    try testing.expectEqual(@as(u32, 0x94000000 | 14), bl);
    // LDP X30, XZR, [SP], #16
    try testing.expectEqual(@as(u32, 0xA8C17FFE), std.mem.readInt(u32, out.bytes[12..16], .little));
    // MOV W0, WZR
    try testing.expectEqual(@as(u32, 0x2A1F03E0), std.mem.readInt(u32, out.bytes[16..20], .little));
    // RET
    try testing.expectEqual(@as(u32, 0xD65F03C0), std.mem.readInt(u32, out.bytes[20..24], .little));
}

test "wrapper_thunk: emit x86_64 SysV 2-int register-class (i32, i64) (31 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig:986 (aarch64)
    if (comptime builtin.cpu.arch != .x86_64) return;
    if (builtin.os.tag == .windows) return skip.phaseEnd(.win64);
    const results = [_]@TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32)){ .i32, .i64 };
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &results },
        .body_offset = 200,
        .thunk_offset = 100,
    };
    const out = try emit(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 31), out.bytes.len);
    // SUB RSP, 8
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xEC, 0x08 }, out.bytes[0..4]);
    // MOV [RSP], RSI
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x34, 0x24 }, out.bytes[4..8]);
    // CALL opcode + disp32 = 200 - (100 + 8 + 5) = 87
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[8]);
    const disp = std.mem.readInt(i32, out.bytes[9..13], .little);
    try testing.expectEqual(@as(i32, 87), disp);
    // MOV RSI, [RSP] ; ADD RSP, 8
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x8B, 0x34, 0x24 }, out.bytes[13..17]);
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xC4, 0x08 }, out.bytes[17..21]);
    // MOV [RSI], RAX ; MOV [RSI+8], RDX
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x06 }, out.bytes[21..24]);
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x56, 0x08 }, out.bytes[24..28]);
    // XOR EAX, EAX ; RET
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[28..31]);
}

test "wrapper_thunk: emit x86_64 SysV D-477 2-param 1-result (34 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig (emitAarch64 N-param)
    if (comptime builtin.cpu.arch != .x86_64) return;
    if (builtin.os.tag == .windows) return skip.phaseEnd(.win64);
    const VT = @TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32));
    const p = [_]VT{ .i32, .i32 };
    const results = [_]VT{.i32};
    const out = try emit(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 200, .thunk_offset = 100 });
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 34), out.bytes.len);
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xEC, 0x08 }, out.bytes[0..4]); // SUB RSP,8
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x34, 0x24 }, out.bytes[4..8]); // MOV [RSP],RSI
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x8B, 0x32 }, out.bytes[8..11]); // MOV RSI,[RDX] (p0)
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x8B, 0x52, 0x08 }, out.bytes[11..15]); // MOV RDX,[RDX+8] (p1, last)
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[15]); // CALL
    try testing.expectEqual(@as(i32, 80), std.mem.readInt(i32, out.bytes[16..20], .little)); // 200-(100+15+5)
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x8B, 0x34, 0x24 }, out.bytes[20..24]); // MOV RSI,[RSP]
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x83, 0xC4, 0x08 }, out.bytes[24..28]); // ADD RSP,8
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x89, 0x06 }, out.bytes[28..31]); // MOV [RSI],RAX
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[31..34]); // XOR EAX,EAX ; RET
}

test "wrapper_thunk: emit x86_64 SysV D-477 4-param 1-result — load order p0,p2,p3,p1 (42 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig (emitAarch64 N-param)
    if (comptime builtin.cpu.arch != .x86_64) return;
    if (builtin.os.tag == .windows) return skip.phaseEnd(.win64);
    const VT = @TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32));
    const p = [_]VT{ .i32, .i32, .i32, .i32 };
    const results = [_]VT{.i32};
    const out = try emit(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 200, .thunk_offset = 100 });
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 42), out.bytes.len);
    // p0→RSI, p2→RCX, p3→R8 (skip p1), then p1→RDX LAST — RDX (args base) survives.
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x8B, 0x32 }, out.bytes[8..11]); // MOV RSI,[RDX]
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x8B, 0x4A, 0x10 }, out.bytes[11..15]); // MOV RCX,[RDX+16]
    try testing.expectEqualSlices(u8, &.{ 0x4C, 0x8B, 0x42, 0x18 }, out.bytes[15..19]); // MOV R8,[RDX+24]
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x8B, 0x52, 0x08 }, out.bytes[19..23]); // MOV RDX,[RDX+8] (last)
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[23]); // CALL
    try testing.expectEqual(@as(i32, 72), std.mem.readInt(i32, out.bytes[24..28], .little)); // 200-(100+23+5)
}

test "wrapper_thunk: emit x86_64 SysV D-477 6-param → UnsupportedOp (no stack-spill yet)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig (emitAarch64 8-param guard)
    if (comptime builtin.cpu.arch != .x86_64) return;
    if (builtin.os.tag == .windows) return skip.phaseEnd(.win64);
    const VT = @TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32));
    const p = [_]VT{ .i32, .i32, .i32, .i32, .i32, .i32 };
    const results = [_]VT{.i32};
    try testing.expectError(Error.UnsupportedOp, emit(testing.allocator, .{ .sig = .{ .params = &p, .results = &results }, .body_offset = 200, .thunk_offset = 100 }));
}

test "wrapper_thunk: emit x86_64 SysV 3-int-result MEMORY-class (11 bytes)" {
    // SIBLING-AT: src/engine/codegen/shared/wrapper_thunk.zig:986 (aarch64)
    if (comptime builtin.cpu.arch != .x86_64) return;
    if (builtin.os.tag == .windows) return skip.phaseEnd(.win64);
    const i32_results = [_]@TypeOf(@as(@import("../../../ir/zir.zig").ValType, .i32)){ .i32, .i32, .i32 };
    const params: EmitParams = .{
        .sig = .{ .params = &.{}, .results = &i32_results },
        .body_offset = 100,
        .thunk_offset = 50,
    };
    const out = try emit(testing.allocator, params);
    defer testing.allocator.free(out.bytes);
    try testing.expectEqual(@as(usize, 11), out.bytes.len);
    // XCHG RDI, RSI
    try testing.expectEqualSlices(u8, &.{ 0x48, 0x87, 0xFE }, out.bytes[0..3]);
    // CALL opcode
    try testing.expectEqual(@as(u8, 0xE8), out.bytes[3]);
    // disp32 = body_offset(100) - (thunk_offset(50) + 3 + 5) = 42
    const disp = std.mem.readInt(i32, out.bytes[4..8], .little);
    try testing.expectEqual(@as(i32, 42), disp);
    // XOR EAX, EAX + RET
    try testing.expectEqualSlices(u8, &.{ 0x31, 0xC0, 0xC3 }, out.bytes[8..11]);
}

// Reference jit_abi so the import survives `zig build test`
// even though Phase 2' is the consumer.
comptime {
    _ = jit_abi;
    _ = builtin;
}
