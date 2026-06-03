# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Current state

- **Phase**: **12 IN-PROGRESS — AOT compilation mode** (Phase 11 DONE 2026-06-03; widget advanced). Phase 11 =
  WASI 0.1 full + bench infra + SIMD gap profile, closed at `bbc4900b` with the 3-host `test-all` reconcile GREEN.
- **§11 close**: §11.1 (WASI, incl. Windows realworld subset) / §11.2 (bench, Mac+Linux) / §11.3 (SIMD gap ✓) /
  §11.P all `[x]`. §11.4 → Phase 15 (ADR-0135). **Bench re-scoped to 2-host** (Mac+Linux) per **ADR-0137**:
  hyperfine absent on windowsmini (native zig.exe, no nix shell; not autonomously provisionable) → Windows bench
  *timing* deferred to **D-249** (correctness reconcile unaffected).
- **11.P-win64-jit bundle CLOSED** (`bbc4900b`, windowsmini run-2 GREEN — zero crashes across 50131 lines): the
  §11.P windowsmini reconcile surfaced Phase-10 EH/GC-on-JIT bugs on the Win64 ABI (first Win64 run since §11.1).
  Fixed + verified: (1) 15 GC/EH emit files hardcoded SysV arg regs → `abi.current.arg_gprs[]` (cycle-1, ≤4-arg);
  (2) 6 ≥5-arg array ops → `gc_marshal.routeArg` stack-spill + `computeOutgoingMaxBytes` Win64 shadow/stack
  reservation (cycle-2, ex-D-248); (3) throw_trampoline Win64 test-wrapper RSP 16-byte parity (`subq/addq $8`).
  All SysV-no-op (Mac+ubuntu green throughout). Lesson:
  `2026-06-03-win64-jit-trampoline-arg-marshal-hardcoded-sysv`.
- **3-host invariant RESTORED**: Mac aarch64 + ubuntunote x86_64-SysV + windowsmini x86_64-Win64 all GREEN.

## Next task (autonomous)

**NEXT** = Phase-12 boundary work IN PROGRESS this turn: (1) `audit_scaffolding` (MANDATORY phase-boundary) — run
+ fix any `block` locally; (2) backfill §11 SHA pointers; (3) **open Phase 12** — expand the §12 task table
(AOT: `.cwasm` loader vs `format.zig` CwasmHeader/FuncMeta/Reloc shapes; AOT/JIT differential equivalence;
cross-compile `.cwasm`; cold-start bench-delta ≥30% — the ADR-0040 deferred obligation; GC stack-map section
gated on `needs_gc_heap`, the GC-root part itself Phase-15 per ADR-0135). Substrate inherited from §9.8b/8b.3
(`src/engine/codegen/aot/{format,serialise,produce}.zig` + `src/cli/compile.zig`). Then §12.1 Step 0 survey.

## Deferred / open debt (none a Phase-12 blocker)

- **D-249** Windows bench timing (hyperfine on windowsmini / native path) — perf-completeness only, ADR-0137.
- **D-245** host→JIT callee-saved: arm64 + x86_64-SysV no-arg-void fixed; win64 + arg'd variants = remainder.
- **D-246** §11.3 arm64 dot/extmul JIT-emit hole → Phase 15. **D-211** GC-on-JIT precise rooting → Phase 15.
- **D-238** x86_64-SysV cross-instance EH thunk. **D-244** SIMD interp-free (partial). D-210/D-234/D-237/D-229/
  D-231/D-204/D-209/D-213 (note).

## Step 0.7 (next resume)

This turn closes Phase 11 (docs-only flips + ADR-0137 + D-249 + lesson) → no new code, so no gate kick needed for
the close commits (ubuntu+windowsmini already GREEN on the code at `bbc4900b`). If Phase-12 code lands later this
turn, kick ubuntu vs the final HEAD. Prior verified: ubuntu `bbc4900b` OK + windowsmini run-2 `bbc4900b` OK.

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile: `zig build test
-Dtarget=x86_64-windows-gnu` (compile-only; run-error = compile passed). 3-host reconcile = phase boundary.

## Key refs

- ROADMAP §12 (AOT — Goal + exit criteria at line ~1432); Phase Status widget (Phase 11 DONE / 12 IN-PROGRESS).
- ADR-0137 (Windows bench re-scope); ADR-0040/0039 (AOT substrate from §9.8b); ADR-0117 (GC stack-map for AOT).
- Lessons: `2026-06-03-win64-jit-trampoline-arg-marshal-hardcoded-sysv`, `2026-06-03-windowsmini-reconciliation-
  catches-os-only-compile-drift`, `2026-06-03-host-to-jit-must-preserve-callee-saved`.
