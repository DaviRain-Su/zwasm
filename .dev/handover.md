# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase 16 = Completion finalization (完成形) IN-PROGRESS — NOT a release march (ADR-0156).** Phases 0–15
  DONE. **The loop never tags/publishes/cuts over; release is manual user-only; no release gate exists.**
  Goal = clean design + lightweight-fast + full-featured + 100% spec across the runtime AND the surfaces
  (C/Zig/CLI), to あるべき論 + industry standards, **breaking v1 allowed, v1 full-parity NOT a goal**.
- **✅ §16.6 memory-safety DONE (ADR-0160; cf21b11c, ubuntu test-all green).** **D-258** wired
  `root_scope.maybeCollectJit` (conservative-native-stack-scan-only; pure-JIT ⇒ all live GcRefs on the native
  stack at the trampoline CALL) into both JIT GC-alloc trampolines; **D-261** adversarial survival test (held
  local across a collect-forcing struct.new → A.field=42 survives; UAF would slot-reuse → 0) — GREEN Mac +
  x86_64. Latent GC-on-JIT UAF gap closed. Residual **D-276** (callee-saved-register-resident worst case not
  independently forced). Bundle 16.6-gc-on-jit-memsafety closed.
- **✅ §16.5 dogfooding DONE — full facade proven externally (c1-c6); D-272 CLOSED.** External
  `build.zig.zon` path-dep consumer (`examples/zig_dep/`). **c1 (`3bfa460a`)** found+fixed a real bug: `build.zig`
  made `core` via `b.createModule` (private) with **no `b.addModule`**, so `dep.module("zwasm")` panicked —
  `zig_host` only shared the in-repo private module, so ADR-0109's external-consumability was never exercised. Now
  `b.addModule("zwasm", …)`. **c2 (`713fe524`)** host imports (Linker/Caller/`defineFunc`; shipped `b10922d2`,
  survey wrongly read pending). **c3 (`804a7133`)** Memory. **c4 (`27b3274a`)** + **c5 (`c992899f`)** closed
  **D-272**: `Instance.global(name)`/`table(name)` facades (get/set/!Immutable; size/get/set/grow) + shared
  `value_conv.zig`. T1.14/T1.15 tests. Consumer runs clean: add=42/go=11/mem=1234/counter=42/table[1]=0xcafe sz=4.
  c6 sweep: multi-result ✓ (T1.6), Engine config honestly-empty, no CLI-only-vs-API gap. Open notes: **D-274**
  (consuming pulls the zlinter lint tool — make lazy), **D-275** (`Module.instantiate` coarse error — minor).
- **✅ §16.4 CLI surface review DONE (ADR-0159).** Surface locked at **`run` + `compile`** + `--version`/`--help`/
  `help` + unknown-subcommand error (testable `cli/dispatch.zig`); 5 dead stubs removed; §10.1/§10.2/§10.3
  reconciled to code-as-truth (`--engine` per ADR-0136). Flag-parity gap debt-tracked **D-273**.
- **✅ §16.2 C-API** (`e9367bb2`): `include/wasm.h` byte-identical to upstream; implemented all 129 missing extern
  fns → **gap 0 (293/293)** (`scripts/capi_surface_gap.sh`). Residual semantic limits honest+debt-noted: val
  `of.ref`=raw (D-269), standalone `_copy`→null (D-253-D), serialize=source-bytes (D-271). **✅ §16.1** migration
  guide (`58a483e8`). **✅ §16.3** Zig-API facade confirmed minimal/clean (no code change); D-267 reconciled
  (ADR-0025→ADR-0109); Zig Global/Table accessors = optional gap D-272.

## NEXT (autonomous — §16.7 docs is the LAST Phase-16 item; ADR-0156)

- **§16.7 docs finalization — NEXT.** Match the now-SETTLED surface, not a moving target: `README.md` (install,
  3-line run/compile happy paths, Wasm proposal/tier table §11, 3-OS matrix), `docs/reference/` (API ref for the
  settled C/Zig/CLI surface), `docs/tutorial/`, `CHANGELOG.md`. Surface to document: C-API gap=0 (§16.2); Zig
  facade Engine/Module/Instance/Linker/Caller/Memory/Global/Table (§16.3-5, ADR-0109); CLI = run+compile +
  `--version`/`--help` (§16.4, ADR-0159); GC-on-JIT memory-safe (§16.6). **Step 0**: survey existing
  `README.md`/`docs/` state + an industry README (wasmtime/wazero) for shape. Doc chunks; **NOT a release**
  (ADR-0156 — docs ≠ tag/publish; the loop never cuts over). When §16.7 lands, Phase 16's surface/safety/docs are
  all 完成形 — the loop keeps refining + paying debt (D-269/273-276), never "ready to release?".
- Backlog notes (not blockers): **D-269** funcref opaque `?u64`; **D-273** CLI flag parity; **D-274** zlinter
  eager fetch; **D-275** `Module.instantiate` coarse error; **D-276** D-261 register-resident strengthening;
  `examples/` not fmt-gated by `gate_commit.sh`.

## Step 0.7 (next resume)

**§16.6 ubuntu `test-all` verified GREEN** at `cf21b11c` (last cycle) — conservative GC-on-JIT rooting holds on
Linux x86_64 too; bundle closed, §16.6 [x]. **This cycle's commit (the §16.6 close) is doc-only** (ROADMAP [x] +
handover bundle-removal) → no new ubuntu kick. §16.7 is doc-only too. **Gate**: Step-5 Mac =
`bash scripts/mac_gate.sh`. windowsmini = Phase 16 completion boundary (3-host reconcile when Phase 16 closes).

## Deferred / open debt

- **Memory-safety (§16.6)** — **D-258 + D-261 DONE on Mac** (collect trigger wired + adversarial survival test
  green); awaiting ubuntu `test-all`. Residual **D-276** (callee-saved-register-resident worst case not forced).
- **Surface residuals** — **D-274** consuming zwasm transitively fetches zlinter (make lazy; §16.5). **D-273**
  CLI flag gap vs wasmtime (`--invoke` args/result-print, `--env`/`--fuel`/`--timeout`) — §16.5. **D-272** Zig
  Global/Table accessors (§16.5). **D-269** val `of.ref`=raw. **D-253** ref machinery (incl. D-253-D
  standalone-copy). **D-271** serialize=source-bytes (no AOT cache). **D-255** C-API WASI io. **D-251** WASI in AOT.
- **D-210** cohort root fix (D-142/206/210/245). **D-211** GcRootMap. **D-257** 10 lesson `Citing` backfill.
  **D-254** rust 3-OS. **D-249** win bench. **D-238** x86_64 EH thunk. **D-266/D-259** notes.

## Key refs

- ROADMAP §16 (16.1–16.4 ✅ → 16.5 dogfooding → 16.6 memory-safety → 16.7 docs; NO release gate). §1.2 (完成形
  industry-standard surfaces). ADR-0156 (endgame); **ADR-0159 (§16.4 CLI = run+compile)**; ADR-0157/0158 (C-API
  split + ref model); ADR-0109 (Zig facade); ADR-0136 (`run --engine`). `scripts/capi_surface_gap.sh` (gap=0).
