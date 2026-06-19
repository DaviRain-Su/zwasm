# Host-fn thunks straddle TWO distinct `Value` unions

**Observed**: D-305(a) generic `defineFuncRaw` (2026-06-20). A new
runtime-arity host fn that receives the popped operands as a `[]Value`
hit `expected '*const fn(... []const runtime.value.Value ...)', found
'... []const zwasm.Value ...'`.

**Why**: there are two unrelated `Value` types, reached by different
import paths:

- `runtime/value.zig` `Value` — an **`extern union`** (untagged;
  `.f32: f32`, `bits64`/`bits128` accessors). This is the **operand
  stack** currency: `rt.popOperand()` / `rt.pushOperand()` and every
  comptime thunk (`host_func_marshal.thunkFor`) work in it.
- `zwasm.zig` `Value` (re-exported as the public `Value`) — a
  **`union(enum)`** (tagged; `.f32: u32` bits). This is the **public /
  Instance API** currency: `Instance.invoke(name, args, results)` takes
  `[]const zwasm.Value`.

The old per-arity boundary trampolines never saw this because they took
`u32`/`i32` scalars — the comptime thunk did `runtimeToZig` (operand →
scalar) on the way in and `zigToRuntime` on the way out, so the host fn
only ever touched scalars. A generic Value-slice host fn exposes the
operand union directly, so it must **bridge** at the `invoke` boundary.

**How to apply**: a runtime-arity / Value-slice host fn signature uses
`runtime.Value` (that is what `rawThunk` pops). To call `Instance.invoke`
from inside it, copy field-by-field into a `zwasm.Value` buffer. For an
all-i32 boundary (the cross-component flat case) the bridge is one line:
`out[i] = .{ .i32 = in[i].i32 }`. Do NOT `@bitCast` the whole union (the
tag layout differs); copy the field you mean. See [[D-305]] /
`component_graph.boundaryMarshal`.
