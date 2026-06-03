# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **13 IN-PROGRESS — C API full (wasm-c-api conformance)**. **Phase 12 (AOT) DONE** — §12.P closed
  (ADR-0141): `.cwasm` compile/run loader (§12.1) + JIT↔AOT differential (§12.2) + toolchain cross-compile
  (§12.3) + stateful-COMPUTE exec — globals/memory/tables/`call_indirect` (§12.3b) + cold-start ≥30% (§12.4:
  6/6 SIMD fixtures 33-37% AOT-faster). **Deferred to Phase 15**: §12.5 stack-map (co-defines with the GC
  `GcRootMap` shape, ADR-0141, with §11.4 rooting). **Deferred D-251**: WASI/host imports in AOT (parity with
  JIT compute-only, ADR-0140 — lands with JIT-WASI d-3 / D-244).
- **Phase 13 opened**; §13.0/§13.1 [x] (gap audit `.dev/phase13_capi_gap.md`). **§13.2 in progress** in
  `src/api/types.zig` (re-exported via `api/wasm.zig`): (a) type constructors `7ac09d80` — valtype/functype/
  globaltype/tabletype/memorytype `_new/_delete/_copy` + queries + valtype_vec; (b) externtype + import/export
  `6f721b6b` — externtype is the shared `kind`-header the 4 types embed, so `as_externtype`/`externtype_as_*`
  are zero-alloc reinterpret casts (`@ptrCast(@alignCast(...))` on downcast); importtype/exporttype + their
  vecs (consume name byte-vecs + own the externtype). Upstream ownership throughout. 🔒 = END conformance gate.
- §13.2 (c) **module_imports** `80131306` + (d) **module_exports** `befd8acd` — `api/module_introspect.zig`
  (extracted per ADR-0099 §D2 P3 / D-171; instance.zig 3207→3044). imports → importtype_vec; exports → idx
  resolved via per-kind index space. Shared externtype builders + `valKindOf`. Tags skipped (no tagtype).
- §13.2 (e) **frames + trap_origin/trace** `d3819d32` — `api/trap_surface.zig`: `wasm_frame_*` + frame_vec;
  `trap_origin`→null, `trap_trace`→empty (zwasm Trap is single-flag, no stack capture; ADR-0022/D-022).
- **§13.3 partial** `47298cd1`: `wasm_config` `set_args`/`set_envs`/`inherit_stdio` C builders (`api/wasi.zig`)
  over existing `Host` methods (set_* dupe; inherit_stdio no-op — `Host.init` wires fd 0/1/2). Void ABI OOM-degrades.
- **§13.2 extern conversions COMPLETE**: `wasm_extern_as_*_const` + `wasm_extern_type` (`63dab69d`); `wasm_{func,
  global,table,memory}_as_extern[_const]` (`0fc0aac5`, new `api/extern_new.zig`) — entity→Extern WRAP caching a
  borrowed-view Extern (`extern_view`); `Extern.borrowed` makes `extern_delete` a no-op (no double-free).
- **§13.2 host-entity construction DONE** (all 4): `wasm_global_new` (`5faef5d9`), `wasm_memory_new` (`a1c9fbfe`),
  `wasm_table_new` (`08d5fd23`), `wasm_func_new[_with_env]` (`c712eac1`, **closes D-252**). Each is a host-owned
  standalone entity (own backing + `store`); importable via the buildBindings host-entity arm — global cell /
  memory bytes / table refs shared with the guest, and a host func callback invoked by the guest's `call` (a
  runtime-arity HostCall thunk marshalling operand-stack ↔ wasm_val_vec ↔ C callback). All tested e2e.
  instance.zig exempt cap raised 3200→3300 (ADR-0099 amend); now 3297/3300 (tight — foreign lands in extern_new.zig).
- **§13.2 ref ops** (D-253): base `wasm_ref_copy`/`_same` (`9e634743`); funcref cross-cast (`8775e30f`); **`wasm_foreign`
  + host_info + as_ref/ref_as_foreign** (`410a5023`, host opaque externref; Ref gained `store` for the instance-less
  path). **§13.2 load-bearing surface COMPLETE.** Remaining D-253: per-entity host_info-bulk (C, blocked by
  instance.zig 3299/3300 cap → needs a side-table or cap relief) + degenerate instance/extern as_ref (E) — §13.4-driven.

## Next task (autonomous)

Two open tracks, both within Phase 13's surface (pick either; runtime-entity is higher-value but needs design):

1. **§13.3 remainder** — `preopen_dir` (posix-open host dir → `Host.addPreopen`; bool; `std.posix.fd_t` differs
   on Windows) is the self-contained one. **`inherit_argv`/`inherit_env` need an ADR-0070 (libc boundary)
   amendment FIRST**: Zig 0.16's process API is capability-based (argv/env arrive via the `Init` token to
   `main`, cli/main.zig:43/58) — a C-library context (`libzwasm.so`, Zig startup never runs) can't reach it, so
   inherit needs platform C APIs (`_NSGetArgv` / `/proc/self/cmdline` / `GetCommandLineW`) or the C `environ`
   global = new libc sites (§14 "unconscious libc fanout"). Do the ADR-0070 amend as Step 1 of that chunk.
2. **§13.4 — assess close / more examples.** §13.4 scaffolded + 4 conformance examples pass (Mac+ubuntu test-all):
   `callback` (host func), `global_import`/`memory_import`/`table_import` (`22ef63ae`) — the full host-entity surface
   through the real C ABI. NEXT options: (a) a trap-propagation example (guest `unreachable` → C `wasm_trap_t*` +
   `wasm_trap_message`) — validates the trap surface through C; (b) a multi-value / multi-arg func example; then
   **assess marking §13.4 [x]** (it has wasm-c-api-shaped ports + zwasm-specific tests, fail=0 2-host; 3-host
   windowsmini = phase boundary). Add each as a `conformance_cases` entry in build.zig. (§13.3 wasi remainder still
   ADR-0070-blocked.) **WATCH: instance.zig 3299/3300 — further growth needs extraction, not a 3rd exempt bump.**

gap: `.dev/phase13_capi_gap.md`.

## Phase-12 close note

Phase 12 closed `0810b339` (ADR-0141). audit_scaffolding ran (0 block; `private/audit-2026-06-03-p12close.md`).
**windowsmini 3-host reconcile GREEN** — `/tmp/win.log` 1748 lines, 0 failed/mismatched across edge-case/spec/
spec_assert/diff_runner + realworld (no Win64 drift; Phase 12 added no Win64-exec paths). §12 SHAs inline in row
prose. Standing `soon` (not Phase-12): 10 ADR + 10 lesson `<backfill>` markers; 8 files over soft cap.

## Deferred / open debt (none a Phase-13 blocker)

- **§12.5 / §11.4** GC stack-map (AOT) + precise rooting → Phase 15 (ADR-0141 / ADR-0135; D-211).
- **D-251** WASI/host imports in AOT — with JIT-WASI d-3 (D-244); ADR-0140.
- **D-249** Windows bench timing (hyperfine on windowsmini) — perf-completeness, ADR-0137.
- **D-245** host→JIT callee-saved (win64 + arg'd remainder). **D-246** §11.3 arm64 dot/extmul → Phase 15.
- **D-238** x86_64-SysV cross-instance EH thunk. D-210/D-234/D-237/D-229/D-231/D-204/D-209/D-213 (note).

## Step 0.7 (next resume)

This turn added 3 §13.4 conformance examples (global/memory/table host imports via the C ABI): all 4 pass
(`zig build test-c-api-conformance`). Test-only + build.zig (no src change). An ubuntu `test-all` is kicked
(conformance is in test-all) → next resume `tail /tmp/ubuntu.log` for OK. Prior ubuntu `7a7b0a8d` (test-all) OK; windowsmini `0810b339` GREEN.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile: `zig build test
-Dtarget=x86_64-windows-gnu` (compile-only). 3-host reconcile = phase boundary.

## Key refs

- ROADMAP §13 (C API — Goal/exit + §13 task table); Phase Status widget (Phase 12 DONE / 13 IN-PROGRESS).
- ADR-0141 (Phase-12 close, §12.5→P15); ADR-0140 (WASI defer, §12.4 compute-scope); ADR-0139 (P12 re-sequence);
  ADR-0138 (`.cwasm` v0.2/0.3). `api/wasm.zig` + `include/wasm.h` = §13 surface. `cli/run.zig` drives the C API.
