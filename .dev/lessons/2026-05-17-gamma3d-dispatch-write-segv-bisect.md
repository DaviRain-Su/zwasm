---
name: gamma3d-dispatch-write-segv-bisect
description: γ-3.d bisect on imports/imports.1 SEGV — handover prediction (spectest table/memory/global binding gap) refuted; the actual gap is a dispatch-write-triggered SEGV that sigsetjmp arming around on_module_loaded fails to catch
metadata:
  type: lesson
---

# Gamma-3.d imports.1 SEGV bisect — handover prediction refuted

`Citing:` `<backfill>` — refresh after the next γ-3.d landing commit.

## What the handover predicted

Pre-session handover described γ-3.d as "spectest table/memory/
global binding gap — currently `hasUnbindableImports` trips on
`.table/.memory/.global => return true`". Implication: imports.1
fails because it has non-func imports that aren't yet backed.

## What live evidence showed

Running with a temporary `hasUnbindableImports` relaxation (allow
non-spectest func imports whose module is `registered`) reproduces
the SEGV deterministically at `imports/imports.1.wasm` per the
existing in-handler `[γ-4 DIAG]` trace.

`wasm-objdump -x imports.1.wasm` shows the actual shape:

- 18 imports, **all of `.func` kind** — 14 are `spectest.print_*`
  (handled by `hostImportTrapStub`), 1 is
  `test.func-i64->i64` (the registered alias from imports.0), 3
  more spectest funcs.
- 0 table/memory/global imports.

Therefore the "spectest table/memory/global binding gap" narrative
was the wrong hypothesis. imports.1's only non-spectest import is
the registered func, which γ-3.b/β-2b's bridge thunk path covers.

## Bisect inside `resolveCrossModuleImports`

Three probe configurations against the same source layout:

1. **Skip resolver entirely** → exit 1 (no SEGV). Many fixtures
   regress functionally (the relaxation propagates) but the SEGV
   is absent.
2. **Call `entry_ptr.ensureCompiledAndRt` for `test` only** → no
   SEGV (exit 1).
3. **ensure + `jit_mem.setWritable(arena)` + `emitThunk(slot, ...)`
   without dispatch write** → no SEGV (exit 1).
4. **Add `new_dispatch[10] = @intFromPtr(slot.ptr)`** → SEGV
   reproduces (exit 142, "[γ-4 DIAG] SEGV after .module
   imports/imports.1.wasm").

The single offending operation is the heap write of the bridge
thunk address into the dispatch slot. The dispatch slice was
allocated as `gpa.alloc(usize, 18)`; the write at index 10 is in
bounds and to writable heap memory. Yet the next instruction
(`callbacks.on_module_loaded(gpa, wasm_bytes, &compiled, stdout,
name)`) does not enter the function body — the very first
statement (a raw `write(2, msg, len)` via `extern "c" fn write`)
does not produce output before the signal handler fires.

The vtable's function pointer load was verified at the call site
(`callbacks.on_module_loaded` printed `0x1048ef3b0`, a plausible
.text address). Bracketing the call with a per-iteration
`sigsetjmp` arm + `sigsegv_armed.store(true)` did **NOT** catch
the SEGV — the sigsegvHandler took the unarmed branch and ran
`_exit(142)`. This last fact is the load-bearing surprise: the
existing arming pattern (mirrored from
`spec_assert_runner_non_simd.zig::nonSimdOnModuleLoaded`'s start-
fn block, lines 265–276) is supposed to be the recovery
mechanism, and it failed on this specific call site.

## Hypotheses to pursue next

1. **Mac aarch64 Pointer Authentication (PAC)**: the indirect
   call via `callbacks.on_module_loaded` (a `*const fn` value
   on runCorpus's stack frame) might be auth-failing somehow
   after the heap-side write. If true, the SEGV is a PAC trap
   delivered before the call lands, and the handler's
   `sigsegv_armed.load(.acquire)` might be reading false because
   of when the trap fires vs the arm store ordering.
2. **siglongjmp restore-to-fork**: if the SIGSEGV is delivered
   on the altstack (`SA.ONSTACK` is set on this runner per
   `spec_assert_runner_base.zig` line ~1773) AND the trap site
   is mid-call-instruction, restoring registers may corrupt the
   thread state such that `sigsegv_armed.store(true)`'s
   effect is invisible. The d-65 → d-68 D-134 lesson chain
   noted cross-thread siglongjmp as POSIX-undefined; here the
   thread is the same but the call boundary is the suspect.
3. **Layout-coincidence between dispatch heap and `callbacks`
   stack slot**: `new_dispatch.ptr=0x111880000`,
   `arena.bytes.ptr=0x108be8000`, stack lives much higher.
   Direct overlap unlikely, but a JIT-MAP guard page or page-
   level interaction might still be at play.

## Steps the next investigator should take

1. Run **on ubuntunote (Linux x86_64)** with the same probe patch.
   If imports.1 also SEGVs there → it's a generic resolver/
   dispatch bug. If not → confirms Mac aarch64 specificity (PAC
   / JIT W^X / signal-delivery race).
2. Run **with `lldb`** to capture the actual fault address +
   PC at the SEGV (requires SIP workaround on Mac; or
   alternatively use `LLDB_FREE_ROOT_CONFIG` / `csrutil`).
3. Add a `printf` of the dispatch SLICE before AND after the
   write (read it back), and the on_module_loaded function-
   pointer slot's bytes, to verify nothing else mutated.

## Why this lesson matters

This case is a worked example of why
[`no_handover_predictions.md`](../../.claude/rules/no_handover_predictions.md)
exists: the prior handover stated a confident-sounding hypothesis
that DID NOT match `wasm-objdump`'s actual imports.1 shape, and
the autonomous loop nearly committed work matching that wrong
hypothesis. Live measurement (wasm-objdump + DIAG probes) was
required to discover the actual gap.

It is also a worked example of why **sigsetjmp arming is not a
universal recovery primitive on Mac aarch64**: the existing
spec-assert-runner pattern fails to catch this particular SEGV.
Future γ work that depends on SEGV-recoverable cross-module
state-touching cannot assume sigsetjmp + armed handler will save
the runner.
