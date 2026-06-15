# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state — Phase-17 完成形 steady-state; branch GREEN, 3-host-verified (`04985b17`)

**完成形 plateau reached (this session)** — surface-audit sweep (diag/CLI/C-API/Zig-API/docs) + debt-ledger
sweep all CLEAN: (a) **diag F5a** — `popExpect` (`dc463af5`) + all 12 isRef gates (`4edf267d`); F1/F3/F5b
(`240f97de`), F6 top-level (`098d2036`). (b) **CLI** `--version` identity (`73fd1fa2`) + Exit-codes (`7e2d90fc`).
(c) **C-API** `zwasm_instance_get_func` + conformance test (`c40caca9`). (d) **Zig-API** `Instance.call`
(`4843488f`) + deinit docs (`8bb4bf41`). (e) **README** flags + Rust example (`5d7334eb`). **Debt sweep: ZERO
dischargeable** (ledger healthy). 3-host GREEN (Mac `test` 2876/0, ubuntu `OK b66f0342`, win baseline a722c2d8).

**Validator diag at principled stop (this turn)**: tried extending F5a to GC ref-head sites (precise "expected
a struct/array reference") — green, but **reverted**: it pushed `validator.zig` 3393→3424 over its deliberate
3400 cap (ADR-0099). Bumping/splitting the validator for LOW-value invalid-module diags isn't justified →
popExpect+isRef is the stop point (D-334 row Round-updated). Do NOT re-attempt in-place.

**Verified this turn**: scaffolding-drift audit = CLEAN (only this header SHA lagged, now fixed); **perf
pillar already addressed** — D-265 (deterministic-slot regalloc 2.3× miss) was reworked + CLOSED earlier via
register-homed locals (ADR-0154/0155, closed per ADR-0156); perf is deliberately NOT target-gated (bench
README / ROADMAP §12.1, Goodhart). So there is no known open perf deficiency and no perf-baseline lead.

**ROADMAP+debt+ADR re-organization COMPLETE (user-directed 2026-06-15, modelled on ClojureWasm's ADR-0142;
ADR-0186)** — zwasm was at the 完成形 plateau but §9 still read as a forward phase-queue with drift:
- **Chunk 1 (`b80f5224`)**: §9 gained **§9.0 completion-grade model** (plateau + 3 live fronts A/B/C +
  genuinely-future bucket; Phase 0-16 numbers kept as anchors); "Post-completion v0.2.0 line" stub → §9.0
  pointer; drift fixed (P2 CLI=run+compile, §3.1 version-gate removed, P14 D-265-rework reality).
- **Chunk 2 (`0df27418`)**: debt re-placed — each of 47 rows tagged `front:` (A-diag-tail 1 / B-hardening 39 /
  C-dogfooding 1 / future-bucket 4 / parked 2); taxonomy in the conventions block.
- **Chunk 3**: ADR status-hygiene audited → corpus CLEAN (no mis-statused ADR).
- **Chunk 4 — POSTURE RECALIBRATION (user-directed, anti「先回しロック化」; ADR-0186 Rev1)**: the initial §9.0
  over-deferred (future/parked read as "locked"). Corrected: **`/continue` drives ALL fronts + future bucket +
  hard/parked autonomously; ONLY tag-cut is user-reserved** (ADR-0156); hardness → plan a campaign, never
  defer-lock. **cw dogfooding = DONE** (ADR-0168), Front C satisfied (was mis-framed as "waiting"). **WASI 0.3
  ratified 2026-06-11** (CM-async, separable from core stack-switching) → **promoted to actionable Front D /
  §1.2 floor / D-335** (spec cloned to `~/Documents/OSS/WASI/`, wasmtime→43+). proposal_watch updated.

**NEXT — actively drive Front D = WASI 0.3 (D-335), the real feature campaign.** Delta survey done (~5600 LOC,
critical path A→B→C→D→E→F→G; D = async task/waitable runtime = HIGH-risk crux). **START at Unit A**:
`stream<T>`/`future<T>` valtype (0x66/0x65) + async functype (0x43) decode+validate in
`src/feature/component/{types,decode}.zig` (~400 LOC, LOW risk, gates the rest). TDD + `zig build test` +
component corpus; bundle-mode per unit; 3-host at milestones. Other fronts (A diag-tail / B debt-discharge) are
opportunistic; parked D-330/D-331 are hard-but-loop-tacklable (don't re-run the blanket fixes that thrash).
Verify any prior remote kick at Step 0.7.

## Active bundle

- **Bundle-ID**: wasi03-D-335 (§9.0 Front D; WASI 0.3 / Preview 3; units A→G)
- **Cycles-remaining**: ~7+ (≥1 per unit; D = async task/waitable runtime is multi-cycle)
- **Continuity-memo**: critical path **A→B→C→D(crux)→E→F→G** (full plan in **D-335**). CM-async
  (`async` func / `stream<T>` / `future<T>`), **NOT** core stack-switching. Spec:
  `~/Documents/OSS/{WASI, WebAssembly/component-model}` (design/mvp/{Binary,CanonicalABI,Concurrency}.md);
  ref impl `~/Documents/OSS/wasmtime` (43+). Builds on shipped CM substrate `src/feature/component/` +
  `src/api/component_wasi_p2.zig` (P3 coexists with P2, does not replace it).
- **Exit-condition**: a WASI-0.3 async/stream/future component runs end-to-end through zwasm (new P3
  corpus green, 3-host); each unit lands green per D-335 along the way.
- **Current unit — A (START HERE)**: `stream<T>`/`future<T>` valtype (0x66/0x65) + async functype (0x43)
  **decode + validate** in `src/feature/component/{types,decode}.zig` (~400 LOC, LOW risk). Done = green
  decode/validate test → mark D-335 unit-A, retarget this bundle's Current-unit to B (canon builtins).

## Long-tail (debt-tracked / parked — NOT active; see §9.0 fronts + debt.yaml)

- **JIT-correctness** (front B / parked): D-330 c_sha256 `\n` (parked — conflicting-constraint, blanket fix
  thrashes; full findings in D-330 Round 5 + `private/notes/{c_sha256_trace,d330-emit-align-design}.md`; do
  NOT re-run the blanket fix) · D-331(A) go runtime-corruption (infra-blocked) · D-331(B)/D-289 go_regex emit
  (parked) · D-333 (br_table, folds into D-330's deeper fix). Realworld corpus 50/50 interp; JIT run-stage
  opt-in (`ZWASM_JIT_RUN=1`). Trace: `ZWASM_DEBUG=jit.dump` + `scripts/jit_value_trace.sh` (Recipe 18).
- Prior agenda (2026-06-14 realworld-reproduction) folded into front B: Phase A infra DONE, Phase B JIT
  bug-hunt = the JIT-correctness debt above; plan in [`realworld_reproduction_plan.md`](realworld_reproduction_plan.md).

## State (all 3-host green; release = USER-ONLY, ADR-0156)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip. **WASI 0.1** complete; **0.2/CM**
  default-ON (ADR-0182/0183; corpus 158/0/0). Sandboxing triad everywhere.
- **Surfaces**: C-API 293/293 (+preopen_dir/inherit_env, ADR-0184) · Zig-API
  complete (+`WasiConfig.{envs,preopens,io}` — full WASI parity) · lean CLI ·
  memory-safety sound · dogfooded into cw (consumer-side). Runners ReleaseSafe (ADR-0177,
  Rev 2026-06-14 floored `core_comp` too; `check_releasesafe_runners.sh` guards it).
- **EH**: cross-instance exception-handling on JIT works on BOTH arches (arm64 `4f73d9ee`
  + x86_64 D-238/ADR-0185 `c534afca`). Interp + JIT EH spec corpus green.
- **Debt**: 48 entries, **one `now`** (D-335 = WASI 0.3 Front-D campaign, the Active bundle); rest are
  front-tagged (A/B/C/D-wasi03/future-bucket/parked per §9.0 + debt conventions). D-330/D-331 parked.
- **Realworld corpus**: 50 fixtures (c/cpp/rust/tinygo/go), interp 50/50; JIT run-stage
  opt-in (`ZWASM_JIT_RUN=1`) — the Phase-B signal source. cljw fixtures retired.
- **Tag**: `v2.0.0-alpha.3` tag-only (no Release → Latest stays v1.11.0), USER-ONLY.

## Key refs

- [`realworld_reproduction_plan.md`](realworld_reproduction_plan.md) — the ACTIVE
  AGENDA's full plan. [`flake.nix`](../flake.nix) `devShells.gen` — fixture toolchains.
- [`docs/zig_api_design.md`](../docs/zig_api_design.md) · **ADR-0185** (x86_64 EH
  frame-walk) · **0177** (ReleaseSafe runners) · **0156** (NO autonomous release) ·
  **0153** (rework) · **0109** (Linker/facade API).
- lessons [`releasesafe-runner-floor-audit`] · [`global-predicate-cannot-replace-local-codemap`].
