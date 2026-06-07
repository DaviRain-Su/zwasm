# Engine `invoke` is re-entrant (stack-disciplined) → host funcs may call `cabi_realloc` from within a trampoline

**Date**: 2026-06-07
**Context**: CM-D2-fs bundle — WASI-P2 `preopens.get-directories` returns a
`list<tuple<own<descriptor>,string>>`, so the host trampoline must allocate
guest memory via the guest's `cabi_realloc` *while the guest is mid-call*
(nested invoke). Feasibility was the bundle's load-bearing unknown.

**Finding**: `src/zwasm/instance.zig` `Instance.invoke` is manifestly
re-entrant-safe. It: (1) `op_base = rt.operand_len` (saves the current operand
top); (2) `pushFrame(.{ .operand_base = op_base, ... })`; (3) runs
`dispatch.run`; (4) `popFrame`; (5) reads results from `operand_buf[op_base+i]`
and restores `operand_len = op_base`. `locals` are freshly `alloc`'d per call
(not shared). The host-call path (`host_calls[idx]` thunk, lines 156–186) is
likewise `op_base` save/restore disciplined. So a nested `invoke` issued *from
inside a trampoline* (during an outer `invoke("run")`) pushes a fresh frame at
the current operand top, runs, pops, and restores — the shared `rt.operand_buf`
+ frame stack nest correctly.

**Implication**: WASI-P2 host functions that return lists/strings
(`get-directories`, `descriptor.read`, `environment.get-environment`) CAN
allocate guest memory via `cabi_realloc` called from *within* the trampoline
(nested guest invoke), with **no engine change**. `reallocViaGuest`
(`api/component.zig`) already re-invokes `cabi_realloc`, but only from host
orchestration *between* invokes; the *nested* case (trampoline → realloc during
an active guest call) is what this confirms.

**Rules**:
1. Before assuming re-entrancy un/safe, read the `invoke` frame discipline —
   the stack-relative `operand_base` + per-call freshly-allocated `locals` are
   the tell that nesting works.
2. Confirmed for the **interp** path (component runs use interp). JIT-nested
   re-entrancy was not evaluated (out of scope for the component path).
3. To use it: thread a realloc capability into `WasiP2Ctx` (set the instance
   ptr after `lk.instantiate`, before `m.invoke("run")`); the trampoline calls
   `m.invoke(realloc_name, ...)`. The fixture's `$libc` must export a real
   bump-allocator `cabi_realloc` (the current stub `$libc` exports memory only).
