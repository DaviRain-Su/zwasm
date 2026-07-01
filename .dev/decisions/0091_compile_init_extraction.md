# 0091 — Extract post-compile init helpers to `compile_init.zig`

- **Status**: Closed (2026-05-21, draft + impl landed same cycle)
- **Date**: 2026-05-21
- **Author**: autonomous /continue loop (D-141 per-file ADR series, post-ADR-0090)
- **Tags**: file-layout, refactor, zone-2, engine, file-size-cap

## Context

`src/engine/compile.zig` is **1225 LOC** — 22% over soft cap.
Earlier analysis identified the file as containing one giant
`compileWasm` function (lines 29-903, ~875 LOC of orchestration)
+ a tail block of 13 post-compile init helpers (lines 900-1225,
~326 LOC). The tail block is structurally distinct from compileWasm:

- All top-level pub fns (no methods, no state shared with
  compileWasm).
- All are post-compile runtime helpers — `apply*` / `patch*` /
  `count*` / `declared*` consumed by the Instance lifecycle.
- `runner.zig` already re-exports a subset via `pub const X =
  compile_mod.X`.

Per the lesson [`2026-05-21-pure-data-extraction-via-reexport`](../lessons/2026-05-21-pure-data-extraction-via-reexport.md)
survey checklist:

1. **Does ONE block exceed 40% of file LOC?** The 326-LOC tail
   is 27% — below the 40% threshold, but cohesive. The 875-LOC
   compileWasm is 71% but its extraction is ADR-grade (phased
   sub-fn decomposition).
2. **Does it have methods?** No — 13 top-level pub fns.
3. **Callers reach via namespace or direct import?** Both —
   runner.zig re-exports via namespace pattern (`pub const
   applyDefinedGlobalsInit = compile_mod.applyDefinedGlobalsInit;`).

The tail block is a textbook re-export candidate.

## Decision

Move the 13 post-compile init helpers from compile.zig to a new
sibling `src/engine/compile_init.zig`. Re-export from
compile.zig so all callers (runner.zig + downstream) continue to
reach `compile.applyDefinedGlobalsInit` etc. identically.

| File | Contents | Approx LOC |
|---|---|---|
| `src/engine/compile.zig` (revised) | docstring + imports + `pub fn compileWasm` (~875 LOC orchestration) + re-export block for 13 init helpers. | ~917 |
| `src/engine/compile_init.zig` (new) | 28-line header + 13 init helpers (applyDefinedGlobalsInit / resolveFuncrefGlobals / applyTableInit{,Ctx} / applyTableInitForTable{,Ctx} / patchTableImportFuncptrs{,Ctx} / countDeclaredTables / declaredTableMin / declaredTableMax / applyActiveDataSegments{,Ctx}). | ~353 |

Re-export pattern (13 const aliases):

```zig
const compile_init = @import("compile_init.zig");
pub const applyDefinedGlobalsInit = compile_init.applyDefinedGlobalsInit;
pub const resolveFuncrefGlobals = compile_init.resolveFuncrefGlobals;
pub const applyTableInit = compile_init.applyTableInit;
pub const applyTableInitCtx = compile_init.applyTableInitCtx;
pub const applyTableInitForTable = compile_init.applyTableInitForTable;
pub const applyTableInitForTableCtx = compile_init.applyTableInitForTableCtx;
pub const patchTableImportFuncptrs = compile_init.patchTableImportFuncptrs;
pub const patchTableImportFuncptrsCtx = compile_init.patchTableImportFuncptrsCtx;
pub const countDeclaredTables = compile_init.countDeclaredTables;
pub const declaredTableMin = compile_init.declaredTableMin;
pub const declaredTableMax = compile_init.declaredTableMax;
pub const applyActiveDataSegments = compile_init.applyActiveDataSegments;
pub const applyActiveDataSegmentsCtx = compile_init.applyActiveDataSegmentsCtx;
```

**Zero caller migration** — `runner.zig`'s existing 8 re-exports
of these helpers continue to resolve through compile.zig's
re-export chain.

## Lint side-effect: 3 unused imports

Post-extraction the following imports became unused and were
removed:

- `compile_init.zig` (the new sibling): `leb128`, `compile_func`
  (only referenced inside the moved helpers... wait, they SHOULD
  be referenced — confirmed by re-checking; lint flagged them
  because the moved code path's specific paths weren't using
  these particular aliases in this slice. The aliases were
  carried over conservatively).
- `compile.zig`: `canonical_type` (only used by the moved
  helpers).

## Alternatives considered

### Alternative A — Phased compileWasm decomposition (parse / validate / lower / emit / link)

- **Sketch**: break compileWasm's 875-LOC body into 5 sub-fns
  with explicit phase boundaries.
- **Why rejected**: ADR-grade design choice; state-threading
  refactor needed (current compileWasm body has variables
  threaded across all phases). Deferred until §9.12-G design
  cycle.

### Alternative B — Keep monolith + FILE-SIZE-EXEMPT

- **Sketch**: compile.zig stays at 1225.
- **Why rejected**: the 326-LOC tail extraction is cheap (single
  cycle), proven pattern. Doing it improves compile.zig's
  remaining shape (compileWasm + tail helpers were unrelated
  semantically).

## Consequences

- **Positive**:
  - compile.zig drops 1225 → 917 LOC. Still over soft cap but
    -308 reduction.
  - The 13 init helpers become findable by file name (someone
    looking for "where are post-compile module-init helpers"
    reaches `compile_init.zig` immediately).
  - Zero caller migration cost.
  - D-141 compile.zig slot closes (compile.zig now sits at the
    second-tier over-cap range — 917 LOC vs the prior 1225;
    further extraction requires ADR-grade compileWasm
    decomposition).
- **Negative**:
  - compile.zig still over soft cap (917 > 1000 wait — actually
    UNDER soft cap now at 917 LOC). Cap threshold is 1000 per
    ROADMAP §A2; 917 < 1000 means D-141 compile.zig slot is
    effectively closed.
- **Neutral / follow-ups**:
  - Pattern composes cleanly with the 5 prior re-export
    extractions (ADR-0082/0086/0087/0088/0090) — this is the
    6th instance.

## References

- ADR-0090 — regalloc_shape_tags.zig (direct precedent; same
  re-export pattern for a top-level pub fn block).
- ADR-0082/0086/0087/0088 — the 4 earlier re-export
  applications.
- Lesson
  [`2026-05-21-pure-data-extraction-via-reexport`](../lessons/2026-05-21-pure-data-extraction-via-reexport.md)
  — survey checklist applied here.
- D-141 — file-size soft-cap proliferation.
- ROADMAP §A2 — file size soft (1000) / hard (2000) caps.

## Revision history

| Date       | SHA          | Note                                    |
|------------|--------------|-----------------------------------------|
| 2026-05-21 | `f1f95fed`   | Initial draft + impl landed same cycle. compile.zig 1225 → 917 LOC (-308; UNDER soft cap); compile_init.zig 353 LOC new. Zero caller migration. 3 unused imports removed post-extraction. Test gate cohort + lint green. D-141 compile.zig slot closes. |
