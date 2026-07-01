# Guile Hoot toolchain fixtures (Phase 10 / GC + TC)

**Toolchain**: Guile Hoot 0.8.0+ — Scheme-to-Wasm compiler (GNU
Guile target). Pairs with wasm_of_ocaml as a functional-language
realworld for GC + TC.

**Planned fixtures** (per design plan §4.3):
- `tail_factorial.scm.wasm` — Scheme tail-recursive factorial
  (verifies `return_call` proper tail call; ADR-0112)
- `list_manipulation.scm.wasm` — `cons`/`car`/`cdr` cycles
  (GC heap with shared cells)

**Build command (when impl ships)**:
```sh
guile-hoot compile <src>.scm -o <name>.scm.wasm
```

**Status**: SKIP-P10-{GC,TC}-GAP until 10.G + 10.TC impl rows land.
