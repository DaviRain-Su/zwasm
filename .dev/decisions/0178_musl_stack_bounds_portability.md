# 0178 — Gate `pthread_getattr_np` behind glibc; portable musl stack-bounds fallback

- **Status**: Accepted
- **Date**: 2026-06-08
- **Author**: Claude (demand-driven resume — cljw v1 handoff)
- **Tags**: platform, libc, portability, musl, stack-probe, gc

## Context

ClojureWasm v1 (cljw, the dogfooding consumer) reported that its
`x86_64-linux-musl` ReleaseSafe edge-deploy build failed to link zwasm:

```
error: undefined symbol: pthread_getattr_np
  note: referenced by feature.gc.collector_mark_sweep…walkRootsImpl
  note: referenced by interp.mvp.invoke
```

(handoff `zwasm_v2_handoff_2026-06-08.md` §A1, the #1 blocker for a
wasm-enabled single-static-binary edge deploy). `src/platform/stack_limit.zig`
used `pthread_getattr_np` + `pthread_attr_getstack` for the Linux thread-stack
query feeding (1) the JIT-prologue stack-probe (`computeStackLimit`, ADR-0105)
and (2) the conservative GC native-stack root scan (`nativeStackHigh`,
ADR-0128). `pthread_getattr_np` is a glibc `_np` (non-portable) extension; it
does not reliably link on musl under cljw's `-mcpu baseline` configuration.
These symbols were on ADR-0070's necessary list (added by ADR-0105 D1) with no
musl guard.

Web survey (2026-06-08) confirmed the portable answer: glibc's *own*
`pthread_getattr_np` parses `/proc/self/maps` for the main thread and reports
the low-end as `stack_top - RLIMIT_STACK`; the LLVM sanitizers
(`GetThreadStackTopAndBottom`) do the same. So `/proc/self/maps` + `getrlimit`
is the documented main-thread method, not a workaround.

## Decision

`comptime`-gate the glibc `pthread_*` path behind `builtin.abi.isGnu()` so the
`_np` symbol is never *referenced* — hence never linked — on non-glibc Linux.
For musl/other libc, fall back to deriving the main-thread stack top from
`/proc/self/maps` (`[stack]` mapping) and the overflow low-end as
`top - RLIMIT_STACK`, using raw `std.os.linux.*` syscalls (off the ADR-0070
libc boundary — no `std.c`/`@extern("c")`/`pthread_*`). Degrade to the
existing `disabled`/`0` sentinel when `/proc` is absent or the stack rlimit is
unbounded (`RLIM_INFINITY`); both consumers already handle that sentinel
(JIT prologue relies on the OS guard page; GC keeps the precise interp walk).

Precise for the main thread — the realistic single-static-binary edge case
cljw ships. Non-main musl threads return the sentinel (`[stack]` labels only
the main stack). The glibc and Mac/Windows paths are unchanged.

## Alternatives considered

### Alternative A — Use the live `/proc` `[stack]` mapping low directly

- **Sketch**: return the currently-mapped `[stack]` low + headroom.
- **Why rejected**: the main-thread stack grows on demand; the live mapping
  only reflects pages faulted in so far, so its low sits far *above* the true
  grow-limit. Runtime check on real Linux: live low `0x…24fb000` vs true low
  `0x…1520000` (16 MiB rlimit). Using it would trap valid deep recursion
  prematurely. `top - RLIMIT_STACK` is what glibc reports.

### Alternative B — Keep `pthread_getattr_np`; rely on musl providing it

- **Sketch**: musl does ship `src/thread/pthread_getattr_np.c`, so do nothing.
- **Why rejected**: it empirically does not link in cljw's real build
  (`-mcpu baseline`), and depending on an `_np` extension for a portable
  target is fragile by definition. Gating is strictly safer for the libc
  policy (fewer non-portable references on musl).

### Alternative C — Return `disabled` on all non-glibc Linux

- **Sketch**: skip the precise query entirely on musl.
- **Why rejected**: loses the JIT stack-overflow guard and GC conservative
  scan on the exact target (musl edge) where they add value, when a precise,
  industry-standard main-thread method exists at negligible cost. Violates the
  completeness design-priority. Disabled remains only the last-resort fallback.

## Consequences

- **Positive**: cljw's musl ReleaseSafe `-Dwasm` build links (verified). Stack
  probe + GC scan stay precise on the musl main thread. Fewer non-portable
  libc references; `pthread_getattr_np` is no longer linked on musl.
- **Negative**: non-main musl threads get the sentinel (no precise probe).
  Acceptable: edge binaries run wasm on the main thread; degradation is safe.
- **Neutral / follow-ups**: the `'x86-64' is not a recognized processor`
  warning in cljw's `-mcpu baseline` build is a zig-internal compiler-rt/musl
  assembly warning (non-fatal, exit 0), not a zwasm issue. ADR-0070 necessary
  list + ADR-0105 amended with revision pointers to this ADR.

## References

- ROADMAP §4 (Zone 0 platform), §14 (no unconscious libc fanout)
- Related ADRs: 0070 (libc boundary), 0105 (JIT prologue stack-probe),
  0128/0167 (GC native-stack scan / interp limit), 0156 (no autonomous release)
- cljw handoff: `ClojureWasmFromScratch/private/notes/zwasm_v2_handoff_2026-06-08.md` §A1
- glibc `nptl/pthread_getattr_np.c`; LLVM `sanitizer_linux_libcdep.cpp`
  `GetThreadStackTopAndBottom`
