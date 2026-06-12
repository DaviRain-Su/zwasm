# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **ROADMAP widget: Phase 16 = DONE, Phase 17 = IN-PROGRESS** (v0.2 feature
  line; NOW-pointer = the CM + WASI-P2 wasmtime-equivalent campaign,
  user-directed 2026-06-07, driver `component_model_plan.md`). The recent
  user-directed pivots (security → JIT-correctness → D-314 sandboxing) are
  all COMPLETE, so per resume rules (ROADMAP wins over this file) an
  unattended `/continue` resumes the **CM campaign at the plan's Work
  sequence** — the "Parked" note at the bottom predates those pivots'
  completion. If the user prefers debt work instead, the candidates are in
  NEXT below.
- Last: **E3-CM-validation bundle CLOSED** — validator rules 5–8 landed this
  session (kebab @2b2eaeac, outer-alias count, export-type-named with
  `TypeInfo.type_space`, case-insensitive dup-names) on top of rules 1–4;
  corpus runner **18 pass / 0 fail / 2 reasoned skip-impl** (triage in
  `component_model_plan.md` E3 row). Mac test-all+lint green per chunk.
- **NEXT (CM campaign)**: E2 Go proof bundle — see `## Active bundle`.
  Then: WASI-P2 boundary fixtures (E3 remainder) · D3-8 sockets
  (spike-first). Secondary (user-redirect only): D-318, D-314, D-251.

## Active bundle

- **Bundle-ID**: e2-go-wasip2-host (campaign E2 Go proof)
- **Cycles-remaining**: ~3
- **Continuity-memo**: toolchain gate DISSOLVED — tinygo 0.40.1 in the gen
  shell builds `-target=wasip2` natively (no wit-bindgen-go needed; go.mod
  must pin `go 1.25`, the shell's go1.26 trips tinygo). The built hello
  component (730 KB, /tmp/tinygo_hello) wires-FAILs `UnsupportedWasiImport`:
  ~12 unclassified funcs — chunk A (mechanical, P1 facilities exist):
  random.get-random-u64 + descriptor.{stat-at,create-directory-at,link-at,
  readlink-at,remove-directory-at,rename-at,symlink-at,sync-data,
  unlink-file-at} → adapter table + trampolines + `wasi_p2_fs_path` fixture;
  chunk B: read-directory + directory-entry-stream resource (cursor state in
  WasiP2Ctx, rep = state index); chunk C: commit Go fixture + e2e + README.
- **Exit-condition**: tinygo-built `wasi_p2_hello_go.wasm` runs e2e through
  `zwasm run` printing "hello" (cross-toolchain proof beside Rust @96e1ccce).

## Sandboxing bundle d314-jit-sandbox — CLOSED 2026-06-12

Exit-condition MET and exceeded: a JIT looping/recursive fn traps when the host
raises the flag — and the full triad now spans both engines + CLI + C-API.

- **#3a interrupt**: prologue polls both arches (`c1a9da15`/`6d56f517`); loop
  back-edge polls + x86_64 R15-forcing (`72801881`); arm64 br_table-to-loop +
  honest RUNNING-loop thread-raiser tests, hang-as-failure (`b365c190`).
- **#3b fuel-on-JIT** (`a6d7ae72`): `fuel_metered`/`fuel_cell` polls beside the
  interrupt polls; units = poll-site crossings (v1 parity, ADR-0179 rev); kind
  17 = `TrapKind.out_of_fuel` wired interp+JIT+runner; new `encSubMem64Disp32Imm8`.
- **#3c-2 mem-cap-on-JIT** (`866d784e`): `MemGrowCtx.host_max_pages` +
  `JitInstance.setMemoryPagesLimit` (host-side only).
- **#3a-4 CLI** (`ce2ded2b`): `--fuel`/`--timeout`/`--max-memory` on both
  engines (io-event-loop timer → shared interrupt flag; cwasm/component refuse
  loudly); **C-API** (`f1a88e77`): `zwasm_instance_*` setters + `zwasm_trap_kind`
  in new `src/api/zwasm_ext.zig` + real `include/zwasm.h` (naming rev in
  ADR-0179: instance-level over v1's config-level).
- Follow-ons re-scoped into the **D-314 `note` row** (epoch counter, JIT
  table-elems limit, cwasm/component limits, facade-JIT routing, poll
  code-size measurement). Facade stays interp-only (live security posture).

**GATE NOTE (D-311 residual)**: the 3 raw-entry-call tests crash seed-flakily in
`zig build test`; NEW variant: under the build-runner `--listen` IPC the unit
binary can crash AT EXIT after all results stream back OK — zig prints
`failed command:` but exits 0; standalone = green. Don't chase as a new bug;
3-host test-all is the authority (`releasesafe_jit_failures.md`).

## JIT-correctness pass (2026-06-12) — LANDED, 2-host green

wasm-3.0 JIT mode = assert_return 880/0 on BOTH arm64 + x86_64, matching interp
(`e758412a..9a9b46de`). Shipped: GC-ref-through-table corruption `9a9b46de`;
memory64 `ea+size` overflow `fc5be95e` (D-234 reopened+fixed); capture-allocator
`008dc3be`; D-237 double-free `314a0c97`; 36 stale multi-memory skips `93792696`.
**D-318** (note): Rosetta x86_64-macos FULL corpus-JIT SEGVs (local-diagnostic
only). Remaining jit-mode skips are eligibility-gated, NOT correctness.

**Prior passes (green, pushed; detail in git log)**: embedder-hardening
`14de5430..d6699b00` (InstantiateOpts budgets, decoder robustness, D-315/D-316,
Actions SHA-pinned); Tier-1 — static-lib `45438b7a` (D-312), ADR-0179 design +
interp sandboxing triad (`1001fa0e`/`460210f1`/`7216e7b1`/`58479dd6`),
migration-guide Phase B/D, musl (ADR-0178). Host-infra hardening 2026-06-12
`3e501d9c` (gate timeouts, orphan reaps — host memory-exhaustion incident,
lesson `host-memory-exhaustion-defenses`).

**Documented follow-ons (need a user decision / focused effort)**:
- **#1 C-API WASI preopen — D-251**: pure C-API has no `std.Io` to open dirs;
  needs an io-acquisition ADR. CLI `--dir` + Zig API cover preopen today.
- **Tier-2 #5** ILP32/watchOS (static-lib target + #97 accommodations).

## State at pause

- **Core Wasm 1.0/2.0/3.0**: 100% spec, 0 skip, 3-host green. **v0.2 features**
  (atomics / wide-arith / custom-page-sizes / relaxed-SIMD) complete + official
  corpora. **WASI 0.1** complete. **Sandboxing triad on both engines + CLI/C-API.**
- **Component Model + WASI Preview 2** (opt-in `-Dcomponent`): a real Rust
  wasm32-wasip2 component runs e2e (ADR-0170/0175); E1 spec-corpus runner;
  structural validation rules 1-4 (ADR-0176).
- **Surfaces**: C-API 293/293 gap-free + zwasm.h extensions · Zig-API complete ·
  CLI (`run`/`compile` + sandbox flags, intentionally lean) · memory-safety
  sound · dogfooded into cw v1.
- **Test iteration**: integration runners ReleaseSafe (ADR-0177); unit
  `zig build test` Debug; `test-all` auto-fast.
- Debt ledger **54 entries**, **zero `now` rows**; D-314 re-scoped to `note`
  (follow-on list). Rest `blocked-by`/`note` = long-tail.

**Parked (demand-driven)**: WASI-P2 sockets; Go/tinygo proof; 32
`blocked-by` debt (call_ref / future proposals). (CM deeper conformance is
NO LONGER parked — it is the ROADMAP Phase-17 NOW-pointer, see Current
state.)

## Key refs

- [`docs/handoff_cw_v1.md`](../docs/handoff_cw_v1.md) — consumer-side handoff.
- **ADR-0179** (sandboxing, Revisions 2026-06-12) · **ADR-0156** (no release) ·
  **ADR-0153** (rework posture) · **ADR-0174** (windows gate) ·
  **ADR-0170/0176/0177** (CM / validation / runners).
- [`component_model_plan.md`](component_model_plan.md) ·
  [`releasesafe_jit_failures.md`](releasesafe_jit_failures.md) (D-311 residual).
