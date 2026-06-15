# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Active bundle — c_sha256 `\n` = GENERAL cross-call-live merge-temp regalloc bug (D-330)

- **Bundle-ID**: d330-crosscall-merge-temp
- **Cycles-remaining**: ~2-3 (liveness probe → fix → both-arch verify)
- **Continuity-memo**: c_sha256 `--engine jit` drops the final `\n` (106 vs 107). ROOT (Round-3 lldb,
  hard data; trace `private/notes/c_sha256_trace_2026-06-15.md`): NOT wpos, NOT a flush branch (both
  DISPROVEN). Verify line `puts("verify: OK")` = fputs + `putc('\n')`; the `putc('\n')` is SKIPPED by a
  mis-taken `i32.ne br_if`. The fputs select/if-result MERGE vreg lives in **X22**, LIVE ACROSS `call 10`;
  X22 is not prologue-preserved (ADR-0060) nor D-291-spilled (op_call.zig:86 = HOMED locals only) →
  clobbered to 0 → `(0!=10)` true → branch skips putc. `captureOrEmitBlockMergeMov`
  (op_control_merge_mov.zig:199-206) emits no taken-edge move (assumes the reg survives). GENERAL: any
  cross-call-live block/if-result merge temp in X20-22 / RBX-R14, not just this `\n`.
- **NEXT (probe-before-fix — regalloc=high-risk)**: ADR-0060 force-spill (regalloc_compute.zig:284) ALREADY
  spills cross-call vregs → dump func4's liveness range for the merge vreg vs `call 10` pc. Range NOT
  crossing → fix liveness.zig (extend merge-vreg range to post-block consumer); crossing-but-kept-in-reg →
  fix force-spill scan / merge capture. Correctness-first: RED edge fixture `(value)(call f)(if (result i32)
  (cond)(then value)(else other))` where value crosses the call AND feeds the captured merge → before the fix.
- **Exit-condition**: c_sha256 `--engine jit` = 107 bytes + edge fixture red→green + full test-net +
  both-arch (Mac arm64 + Rosetta x86_64) green.

## Just closed (detail in commits/debt)

**D-330 c_sha256**: 3 lldb runtime-trace rounds (`1cecf8bb` + this commit) LOCALIZED the long-parked `\n`
miscompile → the cross-call merge-temp bug above (was mis-pinned as wpos/flush 4× prior). **D-293 array_oob
COMPLETE** (`855ca5ca`+`dafab5ce`, 25437/0 3-host). Scaffolding audit (this resume): **0 block, healthy**.
Other long-tail: **go corruption** (non-deterministic, infra-blocked), **D-294-R2** (conformance-neutral CLI).
**Hosts**: ubuntunote+windowsmini ASLEEP this resume (No route to host) — verify gate at next Step 0.7.

## ACTIVE AGENDA (user-directed 2026-06-14) — real-world toolchain/bench reproduction

Project feature-complete + tag-ready (**tag = USER-ONLY, ADR-0156**). Plan:
[`realworld_reproduction_plan.md`](realworld_reproduction_plan.md) (supersedes ROADMAP §9 for these tasks).
Phase A reproduction infra DONE (A1 Zig `5c044967` / A2 embenchen `1aac480f` / A3 `--wasmer` `897b54d7` /
runtime bump wasmtime45+wasmer7.1; A4 rust=D-254, hyperfine=D-249). Phase B deep JIT bug-hunt SUSTAINED:
B1 `--jit` diff-lane `219dbd17` (REPORT-ONLY, 56/56). Tool currency 3-host DONE+VERIFIED (zig PINNED 0.16.0).

**JIT-correctness debt (each its own investigation)**: D-330 c_sha256 = the Active bundle above (was the
last diff-jit mismatch; corpus otherwise byte-exact). D-331(A) go_* runtime-corruption (panicmem teardown
deref; INFRA-BLOCKED — needs per-function interp-fallback bisect that doesn't exist). D-331(B)/D-289 go_regex
emit-side `vreg>=slots.len` (cap raised `682401fd`; remainder parked, recipe in debt). Earlier durable fixes:
D-330 coalescing `6790c204` + x86_64 fp-select `cccb2313`; sandbox triad `bd355258`+`fa4678f4` (D-314(b)/
D-332 closed); D-294 R1 `2a53213f`. Trace tooling: `ZWASM_DEBUG=jit.dump` + `scripts/jit_value_trace.sh`
(Recipe 18 + lesson `2026-06-15-lldb-value-trace-on-jit-code`).

## State (tag-ready baseline, all 3-host green)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip. **WASI 0.1** complete; **0.2/CM**
  default-ON (ADR-0182/0183; corpus 158/0/0). Sandboxing triad everywhere.
- **Surfaces**: C-API 293/293 (+preopen_dir/inherit_env, ADR-0184) · Zig-API
  complete (+`WasiConfig.{envs,preopens,io}` — full WASI parity) · lean CLI ·
  memory-safety sound · dogfooded into cw (consumer-side). Runners ReleaseSafe (ADR-0177,
  Rev 2026-06-14 floored `core_comp` too; `check_releasesafe_runners.sh` guards it).
- **EH**: cross-instance exception-handling on JIT works on BOTH arches (arm64 `4f73d9ee`
  + x86_64 D-238/ADR-0185 `c534afca`). Interp + JIT EH spec corpus green.
- **Debt**: 46 entries, **zero `now`**; all blocked-by are external (upstream
  Zig / hosts) / future-phase (11/12/14) / user-gated, or `note`/`partial` long-tail.
  D-330 = Active bundle; D-331 (go, primary+(A) FIXED, miscompile-next) parked.
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
