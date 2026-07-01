# D-163 cycle 14: Win64 silent death — entry helper exonerated

> **Citing**: commit `8f59b8bb`. Predecessor:
> `2026-05-23-d163-static-jit-layout-verified.md`.

## What happened

Cycle 14 instrumented `invokeAndCheck` (`src/engine/codegen/
shared/entry.zig:162`) with a single POST stderr print after
the `@call(.auto, f, .{rt} ++ args)` JIT dispatch:

```zig
std.debug.print("[d-163e] flag={d}\n", .{rt.trap_flag});
```

(Single line; PRE elided because entry.zig was already at
EXEMPT-CAP 2500 lines per ADR-0099 — ADR-0105 D1 comment
inlined to make room for the POST line.)

windowsmini run with SKIP arm bypassed, against
`test/private/d-163/iso/call/`:

- 87 directives ran; for each, `[d-163e] flag=0` printed after
  return (or flag=1 for assert_exhaustion runaway / mutual-runaway
  via the kind=4 stack-overflow trap stub).
- For `[W4 DIR] call : assert_trap as-call_indirect-last ()`:
  the `[d-163e] flag=...` line **never appears**. Process
  exits 1 silently.

## What this means

The `@call(f, ...)` JIT dispatch **does not return** for
`as-call_indirect-last`. Death is in the JIT body itself OR in
the caller-side bounds-check trap-stub RET path. The entry
helper's post-return code (trap-flag check, Error.Trap return,
runner stdout printing) is **never reached** — entry helper
side is exonerated.

Combined with cycle 12's static-layout verification (H1/H3/H4
REJECTED — trap-stub byte layout is ABI-correct: SUB/ADD
match, R15 preserved, alignment OK), the failure is in
**runtime dispatch mechanics**, not byte shape.

Notably: the stack-overflow trap stub (kind=4, no `ADD RSP`
since probe fires before frame alloc) returns cleanly on
Win64 (entry helper sees flag=1 for `assert_exhaustion
runaway`). The bounds-check trap stub (kind=0, includes
`ADD RSP, 0x58`) does NOT — between bounds-check stub entry
and entry-helper post-call code, something kills the process.

## Remaining hypotheses

1. **The bounds-check trap stub itself crashes mid-execution**
   before RET. Test: add `MOV [R15+sentinel_off], 0xCAFEBABE`
   at the very start of the trap stub (offset 0xA7). After
   crash, check if rt.sentinel was written.
2. **The trap-stub RET succeeds but jumps to a bad return
   address.** Win64 SEH dispatcher or CET shadow stack may
   detect the unwind-frame-without-.pdata as a control-flow
   violation. Test: instrument the trap stub to write `RSP`
   before RET (capture stack pointer state).
3. **The intermediate CALL inside func56 (offset 0x3C —
   call to `$f306` to produce the OOB index) returns broken
   state on Win64.** Unlikely since `$f306` is a trivial
   leaf function and `-mid` (which also calls `$f306` but
   passes idx=0 to call_indirect) succeeds.

## Next probe (cycle 15)

Codegen-side instrumentation: in `op_control.zig::emitEndInter`
bounds-check trap stub emission, write a sentinel byte to a
JitRuntime field (e.g. `trap_stub_entry_count` mirror, or a
new field) at the START of the stub. If after crash the field
shows the sentinel value, we know the stub IS entered.

## Refs

- D-163 in `.dev/debt.md`.
- Predecessor lesson: `2026-05-23-d163-static-jit-layout-verified.md`.
- `src/engine/codegen/x86_64/op_control.zig::emitEndInter`
  (lines 1300+ — bounds-check trap stub emission).
- Cycle 14 diag commit (this one).
