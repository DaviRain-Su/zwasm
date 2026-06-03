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
- **§13.2 host-entity `_new` trio DONE**: `wasm_global_new` (`5faef5d9`, own `*Value`), `wasm_memory_new`
  (`a1c9fbfe`, own `*MemoryInstance`), `wasm_table_new` (`08d5fd23`, own `*TableInstance`). Each gained own-backing
  + `store` fields; accessors branch instance-vs-own-backing; importable via the buildBindings host-entity arm
  (`instance==null` → bind host backing) — all three shared with the guest (tested e2e: guest reads host state).
  instance.zig exempt cap raised 3200→3300 (ADR-0099 amend) for the runtime-entity accessor/binding surface.

## Next task (autonomous)

Two open tracks, both within Phase 13's surface (pick either; runtime-entity is higher-value but needs design):

1. **§13.3 remainder** — `preopen_dir` (posix-open host dir → `Host.addPreopen`; bool; `std.posix.fd_t` differs
   on Windows) is the self-contained one. **`inherit_argv`/`inherit_env` need an ADR-0070 (libc boundary)
   amendment FIRST**: Zig 0.16's process API is capability-based (argv/env arrive via the `Init` token to
   `main`, cli/main.zig:43/58) — a C-library context (`libzwasm.so`, Zig startup never runs) can't reach it, so
   inherit needs platform C APIs (`_NSGetArgv` / `/proc/self/cmdline` / `GetCommandLineW`) or the C `environ`
   global = new libc sites (§14 "unconscious libc fanout"). Do the ADR-0070 amend as Step 1 of that chunk.
2. **§13.2 remaining**: (a) **foreign** (`WASM_DECLARE_REF` — `wasm_ref` copy/same/get-set_host_info/as_ref/
   share/obtain + the per-entity `*_as_ref`/`*_ref` cross-casts; cross-cutting ref machinery, its own survey +
   chunk); (b) **`wasm_func_new[_with_env]`** = **D-252** (host-callback dispatch plumbing — a tagged Func variant
   + a buildBindings host-func arm wrapping the C callback as a HostCall, the cross_module.thunk pattern). Assess
   D-252 tractability now that the host-entity buildBindings arm + the entity-import pattern exist (the global/
   memory/table arms are the template; func adds the operand_buf↔wasm_val_vec marshalling). After §13.2: **§13.3**
   (wasi remainder — `inherit_argv/env` + `preopen_dir` need an ADR-0070 C-API io/process-provenance decision FIRST,
   see §13.3-partial note above), **§13.4** (`test/c_api_conformance/`), **§13.5** (examples).

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

This turn landed §13.2 `wasm_table_new` (importable, shared *TableInstance) + exempt cap 3200→3300: Mac test+lint+
zone green, instance.zig 3214/3300. An ubuntu `test` is kicked against this turn's HEAD → next resume `tail
/tmp/ubuntu.log` for OK (c_allocator refs + alias, host-portable). Prior ubuntu `0df6f4b2` OK; windowsmini `0810b339` GREEN.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile: `zig build test
-Dtarget=x86_64-windows-gnu` (compile-only). 3-host reconcile = phase boundary.

## Key refs

- ROADMAP §13 (C API — Goal/exit + §13 task table); Phase Status widget (Phase 12 DONE / 13 IN-PROGRESS).
- ADR-0141 (Phase-12 close, §12.5→P15); ADR-0140 (WASI defer, §12.4 compute-scope); ADR-0139 (P12 re-sequence);
  ADR-0138 (`.cwasm` v0.2/0.3). `api/wasm.zig` + `include/wasm.h` = §13 surface. `cli/run.zig` drives the C API.
