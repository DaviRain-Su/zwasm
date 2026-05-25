# clang `__attribute__((musttail))` fixtures (Phase 10 / TC)

**Toolchain**: clang 18+ with `__attribute__((musttail))` —
the C surface for proper tail calls (lowers to Wasm 3.0
`return_call`).

**Planned fixtures** (per design plan §4.3):
- `cps_continuation.c.wasm` — continuation-passing style; the
  tail-call disposition is structurally required (without it
  the call chain would stack-overflow at large input)

**Build command (when impl ships)**:
```sh
clang -target wasm32 -mtail-call <src>.c -o <name>.c.wasm
```

The `musttail` attribute makes the tail-call disposition a
hard compile-time requirement; if clang cannot lower the call
as tail-call, it's a compile error. Verifies ADR-0112 D6
(safepoint-free invariant) end-to-end.

**Status**: SKIP-P10-TC-GAP until 10.TC impl row lands.
