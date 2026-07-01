# 0157 — Split `src/api/handles.zig` out of `instance.zig`

- **Status**: Accepted
- **Date**: 2026-06-05
- **Author**: §16.2 C-API completion (D-270)
- **Tags**: file-size, api, c-api, ADR-0099, D-270, D-269
- **Per**: ADR-0099 (file-size split-smell policy: ≥1 positive AND 0 negative + split-ADR for a hard-cap split)

## Context

`src/api/instance.zig` sat at **3299/3300** lines — its per-file override cap
(ADR-0099 Revision 2026-05-24). §16.2 C-API completion (D-269) chunk C+D already
had to relocate out (config→`config.zig`, val→`vec.zig`) because any addition
exceeds the cap. Chunk E (host_info trio for func/global/table/memory/ref/extern)
must add a `host_info: ?*anyopaque` + finalizer **field** to each handle struct —
and those structs are DEFINED in instance.zig, so even the fields blow the cap
(D-270). The file cannot grow; a split is forced.

## Decision

Carve the **C-API handle struct catalog** out of instance.zig into a new
`src/api/handles.zig`: the opaque entity handles (`Func` / `Global` / `Table` /
`Memory` / `Ref` / `Extern`), the value shapes (`Val` / `ValKind` /
`ExternKind`), and the host-func callback payload (`HostFuncPayload` +
`WasmFuncCallback[Env]`). instance.zig keeps the accessor / marshal / constructor
functions and re-exports each type (`pub const Func = handles.Func;` …) so
`instance.<T>` keeps resolving for siblings (module_introspect / extern_new /
wasm.zig) and this file's own code — **zero churn at call sites**.

Result: instance.zig 3299 → 3081 (−218, ample headroom for chunk E which now
grows handles.zig, at 262 lines). 3-host-relevant suites green (Mac test-all +
lint; ubuntu next cycle).

## Why this split passes ADR-0099 (≥1 positive, 0 negative)

- **P2 (pure-data)**: the extracted unit is 100% pure type definitions — no
  logic, no methods (the C-API uses free functions, which stay in instance.zig).
  A cohesive pure-data catalog is the textbook P2 case.
- **P3 (deep interface, independent cadence)**: these handle types are the C-API
  data model referenced across 4 files (instance / module_introspect / extern_new
  / wasm); they change on the C-API-model cadence (e.g. adding host_info), distinct
  from the accessor logic.
- **0 negatives**:
  - **N1 (helper-circular)** — NO. handles.zig depends one-way on `runtime` /
    `runtime_instance` / `zir` (for `Instance`/`Store`/`Value`/`ValType`, which are
    `runtime.*` aliases — NOT on instance.zig). The ValVec/Trap refs in the
    host-callback typedef ride the *existing* pointer-only `vec`↔`wasm`↔`instance`
    import cycle that Zig 0.16 already resolves (vec.zig doc). handles.zig calls no
    instance.zig helper.
  - **N2 (forced pub-leak)** — NO. Only `pub` types move; no private helper fn is
    pub-leaked.
  - **N3 (shallow)** — NO. 262 LOC ≫ 100.
  - **N4 (test-dup)** — NO. Tests stay in instance.zig (they exercise the exported
    C symbols, which remain there).

## Cycle-safety (the load-bearing check)

No struct-layout cycle: every handle→Instance/Store/Func/… reference is a
**pointer** (`?*T`) or slice — no by-value nesting. `Instance` does not embed any
handle by value. So the import graph cycles are all pointer-only, which Zig 0.16
resolves (same mechanism the pre-existing vec↔wasm↔instance cycle relies on).

## Note (corrects a survey miss)

A Step-0 survey initially recommended REJECT, asserting an N1 cycle (handles.zig
would re-import instance.zig). That was wrong: `Instance`/`Store` are `runtime.*`
aliases, so handles.zig imports `runtime` directly and never instance.zig. The
recheck (instance.zig:79-101 aliases) confirmed one-way dependency.
