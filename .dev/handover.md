# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state — Phase 17 completion-refinement; 4-front async-maturity campaign (user-steered 2026-06-16)

**WASI 0.3 / Preview 3 core DONE** (D-335, per-SHA detail in the debt row). The CM-async runtime runs an async
component from `zwasm run` + the embedder (`component.runWasiMain`): callback loop EXIT/YIELD/WAIT, both stream
directions COMPLETE (host sink/source), waitable-set, return-future — all e2e green, 3-host (ADR-0187 stackless, no
fibers; 0188 P3 runner; 0189 ζ2; 0190 host peers; 0191 WAIT path). Hardening: **D-337** future-drop-before-write
traps; **D-445 partial** async guest-faults → guest trap (not host panic). 18 async e2e fixtures green. Stackless
single-task CANNOT reach guest↔guest COMPLETION (lesson `2026-06-16-stackless-stream-completion-needs-host-peer`;
needs a scheduler/buffering — front ② item). (D-444 = p2-async file split deferred; D-445 remainder = host-FAILURE
error contract, ADR-grade.)

**NEW DIRECTION (4-front async-maturity + completion campaign).** Reference clones updated to latest 2026-06-16:
wasmtime @06-13 (`tests/misc_testsuite/component-model/async/` ~44 `.wast`); WASI @0.3.0 release; **wasi-testsuite
cloned** (`tests/rust/wasm32-wasip3`); wasm-tools/component-model refreshed (`implements.wast` new). Order ②→①→③→④:
- **② wasmtime async .wast gap-mining (ACTIVE — highest ROI)**: gap matrix in `private/notes/p17-wasmtime-async-gaps.md`.
  **DONE**: Gap A (`afcf889a`) — an async export declaring a result MUST call task.return before EXIT, else trap
  (`task-return-traps.wast`); `driveAsyncMain` checks `ctx.task_return` when `asyncExportExpectsResult`. copy-requires-
  IDLE (`05b35c28`): `StreamFutureEnd.copy` traps (CopyNotIdle→guest trap) on a non-IDLE end — 2nd concurrent copy or
  copy on a DONE end (spec `stream_copy`/`future_copy` `trap_if(state!=IDLE)`, `trap-if-done.wast`). **VERIFY
  EACH ROW vs spec** (lesson `2026-06-16-gap-matrix-subagent-verify-against-spec`): the matrix's "cancel-not-copying
  → returns 0" was WRONG (CanonicalABI `cancel_copy` traps; our `async_cancel_no_copy` already correct). NEXT:
  **front② TIER-1 DONE**; deferred **D-446** Gap B + **D-447** TIER-2/3 (design-grade). **front① official build
  BLOCKED → D-448**: wasm32-wasip3 rust-std absent from pinned stable (verified+reverted) + the suite needs
  Buck2/wit-bindgen-async/wkg (bleeding-edge, WASI 0.3 is 5 days old). **NEXT = front① via behavior-mirror**:
  hand-write wasip3 component `.wat` fixtures mirroring the suite's behaviors (`cli-exit`→exit(Err)=code 1;
  `cli-stdio-roundtrip`→stdin→stdout via streams; `cli-env`), assembled via wasm-tools (our async_*.wat style) —
  satisfies the user's "真似する" intent without the blocked official build. Then front ④ perf (no toolchain).
- **① WASI 0.3 conformance**: compile wasi-testsuite `rust/wasm32-wasip3` via `.#gen` (add wasm32-wasip3 target + wit
  deps), run as a conformance corpus.
- **③ real-world corpus 50→100**: add MoonBit/Grain/Kotlin (Wasm-GC) + AssemblyScript/Swift/Zig toolchains to
  `.#gen`, web-search real programs, compile+run. Folds in D-329/D-026/D-074/D-082 (corpus/provisioning debt).
- **④ perf rework (ADR-0153, single-pass-bounded)**: measure benches regressed by feature additions; optimise within
  §1.3/§3.2 (no optimising tier). Goal = lightweight-fast + no regression, NOT beating Cranelift/LLVM.

## Active bundle

- **Bundle-ID**: p17-async-maturity-4front (②wasmtime-gaps → ①wasip3-conformance → ③corpus-100 → ④perf-rework)
- **Cycles-remaining**: many (multi-front; ② TIER-1 DONE → ① active next)
- **Continuity-memo**: ② DONE (gap matrix `private/notes/p17-wasmtime-async-gaps.md`; Gap A `afcf889a` + copy-IDLE
  `05b35c28`; cancel verified; D-446/D-447 deferred). **① official build BLOCKED (D-448)** — wasip3 std not in
  pinned stable + Buck/wit-bindgen-async. **① via behavior-mirror**: hand-write wasip3 `.wat` fixtures from the
  suite's `src/bin/*.rs` + `.json` (operations: run/wait exit_code) at `~/Documents/OSS/wasi-testsuite/tests/rust/
  wasm32-wasip3/`, assembled via wasm-tools, run through driveAsyncMain/runWasiMain. zwasm stackless single-task
  (ADR-0187). Start with cli-exit (simplest). Spec: `~/Documents/OSS/{WASI,WebAssembly/component-model}`.
- **Exit-condition**: (front ①) a set of wasip3 cli-behavior `.wat` fixtures (cli-exit, cli-stdio-roundtrip, cli-env)
  green through zwasm 3-host, mirroring the wasi-testsuite `.json` expectations; new gaps → fixtures/debt.

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
- **Debt**: 49 entries, **one `now`** (D-335 = WASI 0.3 Front-D campaign / Active bundle); D-336 part-a done →
  now blocked-by (value index space). Rest front-tagged (A/B/C/D-wasi03/future-bucket/parked). D-330/D-331 parked.
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
