# Session handover

> ≤ 100 lines. Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **10 IN-PROGRESS — autonomous CORRECTNESS substantially COMPLETE**
  (Phase 9 = DONE 2026-05-24). All 4 proposals verified green except deep/deferred
  residuals (see §10 map + D-202 debt).
- **HEAD**: `a4bd9bbb` (cyc239, **D-202 PHASE B-finality**). Session: cyc232
  cross-module `return_call`; cyc233 EH×TC; cyc234-235 stale-debt correction (ADRs
  0115/0116/0123/0126 Accepted, D-195 discharged, corpora GREEN); cyc236 D-202
  PHASE A (linker cross-module subtyping, `.30/.48/.50` link, ubuntu-verified);
  **cyc239 D-202 PHASE B-finality** — `ExportType.func` → `ExportFuncType{sig,final}`,
  exporter func finality threaded to the C-API Linker, which now rejects a FINAL
  import resolving against an open `(sub …)` exporter → **assert_unlinkable 5→4**,
  no regression.
- **10.P: 16 PASS / 8 SKIP / 0 FAIL → close-eligible.**
- **nix**: dev shell active (zig 0.16.0 / wabt / wasmtime).

## Step 0.7 (next resume — DO FIRST)

- cyc239 (`a4bd9bbb`) is a multi-file linker/instance code change → ubuntu kicked
  this turn. Next resume `tail -3 /tmp/ubuntu.log`, expect `OK (HEAD=<turn-final>)`
  — verifies assert_unlinkable 5→4 + no regression on x86_64. On FAIL: revert the
  turn's commits; last ubuntu-green = `ebca32b0` (PHASE A).

## Active task — Phase 10 autonomous correctness substantially COMPLETE  **NEXT**

**D-202 PHASE B-finality LANDED cyc239** (`a4bd9bbb`): assert_unlinkable 5→4. The
remaining **PHASE C = the other 4 assert_unlinkable** (`.36/.42/.52/.54` or subset)
differ by DECLARED-SUPERTYPE / cross-module canonical type-identity, NOT just the
finality bool → **D-202 debt row** (needs threading the exporter supertype chain +
a cross-`Types` `canonicalEqual`; more involved than the finality bool; fresh
context). 

**cyc241**: drafted **ADR-0127** (Proposed) — the D-202 PHASE C design (cross-module
func import type-identity: structural subtyping AND `canonicalEqual`-cross-`Types`
OR supertype-reach; no-regression set = multi-mem 407 + EH 34 + `.30/.48/.50`). The
design is now nailed; impl is de-risked.

**Honest state**: this very long session (cyc232-241) drove Phase 10's clean
autonomous correctness to substantial completion (cross-module TC, EH×TC,
stale-debt correction, D-202 PHASE A + B-finality, PHASE C ADR). The remaining
AUTONOMOUS items are all fresh-context/dedicated-effort or low-value: **D-202 PHASE
C impl** (per ADR-0127 — cross-`Types` canonicalEqual extension + exporter
supertype threading; regression-risky → best fresh context, or after user-Accepts
ADR-0127); gc per-op-file migration (refactor); gc_stress / eh_frequency runner
(involved/perf). The HIGH-VALUE move — formal Phase 10 close (→ Phase 11;
close-eligible, 0 FAIL) — is USER-GATED. Next driving chunk = **D-202 PHASE C impl
per ADR-0127** when context is fresh; else gc per-op migration. Re-armable to the
Phase-10 close at any user signal.

(Prior context — cyc234-235 stale-debt correction, retained for the lesson):
**the debt ledger was STALE and mis-routed the loop 3×.** Ground-truth (ADR Status
+ live corpus, NOT debt prose):
- ADR-0115 / 0116 / **0123 / 0126 are all ACCEPTED** (0123 "user-delegated
  autonomous flip" 2026-05-28). There is NO pending user ADR flip. Debt rows
  D-195 / D-198 saying "gated on ADR-XXXX Accept" are STALE.
- **function-references corpus GREEN** (ubuntu `return 39/0, trap 4/0,
  invalid 18/0, skip 1`) — **D-195 is DISCHARGED** (typed-funcref ValType
  `0x63/0x64` parser landed, `zir.zig:191`). Debt row stale.
- **GC corpus** GREEN except: `.17` (deferred multi-mechanism rabbit hole) +
  the **D-202 cross-module negatives** (`gc/type-subtyping.30/.48/.50`
  instantiate `SignatureMismatch`, `.35/.36/.42/.52/.54` assert_unlinkable
  wrongly-link).
- Lesson to write: *verify ADR Status + live corpus before trusting a debt
  row's "blocked-by ADR flip" framing* — three candidate chunks this session
  (D-195, the GC ADRs, the gc per-op "migration") were stale/misread.

So Phase 10 is NOT at a bucket-3 user-touchpoint — **D-202 is genuine open
AUTONOMOUS correctness work** (ADRs accepted; impl-only).

Resume Step 1b routes to the Active bundle above for the next step + discharge
D-195 (stale) / reconcile D-198 alongside. NOTE smell: `runner.zig` 1168 lines
(soft WARN) — future test sibling extraction.
**Formal Phase 10 close** (→ Phase 11) is a separate high-value user decision
(close-eligible, 0 FAIL); re-armable at any user signal. NOT a blocker on D-202.

## §10 close map + open

10.P close-eligible (0 FAIL). realworld/p10 matrix 45/55 (0 FAIL, 10 WASI-skip).
10.TC row `[ ]` (emit + spec + realworld clang_musttail + cross-module + EH×TC
all DONE; sole residual = `wasm_of_ocaml` triple-crown capstone, deferred to GC+EH
+toolchain — flip 10.TC `[x]` then). 10.E (EH) + 10.G (GC) are the large open
Phase-10 areas (GC has ADR-gated residuals D-195/D-198/D-202; D-179 wabt bake). gc
.17 funcref-RTT (D-198) deep defer; funcrefs 34/39 (5 RTT-gated); 10 SKIP-WASI →
Phase 11. D-197 (validate-error surfacing); D-209 (>4GiB memory64 offset, payload
u32); D-210 (cross-module proper-tail-call defer — arm64 prologue cohort-save).

## Key refs

- ADR-0066 (cross-module bridge thunk; cohort save/restore); ADR-0112 + Amendment
  2026-05-30 (cross-module tail-call = call-and-return); ADR-0111 (memory64);
  ADR-0114 (EH). `abi_callee_saved_pinning.md` (pinned cohort discipline).
- Lessons: `2026-05-30-{cross-module-tail-call-cohort-asymmetry,
  jit-funcref-tail-call-codegen-recipe, clang-wasm-realworld-toolchain-recipe}`.
  ROADMAP §10; `.dev/phase_log/phase10.md`.
