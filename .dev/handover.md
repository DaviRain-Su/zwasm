# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## Active rework campaign

(ADR-0153 structural rework campaign — runs AUTONOMOUSLY; "hard gate" = self-enforced ordering, not a user stop.
Read [`REWORK.md`](../.claude/skills/continue/REWORK.md). Bundle mode nests inside a phase for continuity.)

- **Campaign-ID**: regalloc-resident-locals (D-265) — the single-pass baseline 完成形 (keep hot locals
  register-resident, as v1 does; within P3/P6, NOT an optimising tier). This IS the §15.P parity-achievement work.
- **Phase**: **IV — implementation. ✅ STAGES 1+2 (arm64) + 4 REDO (x86_64) LANDED** — register-homing on BOTH
  backends. 1=`a64c72a1` (arm64 call-free, w45_addi **2.30×→0.97×**), 2=`5d1dd221` (arm64 across-calls), 4-redo=
  **`e8b7ad10`** (x86_64; the first try `f31affa1` was reverted `9d15daf7` after ubuntu caught i64+recursive
  miscompiles). **Root causes (OUR logic — they reproduced under Rosetta x86_64-macos, NOT the D-148 Zig-backend
  class)**: x86_64 allocatable GPRs (RBX/R12-R14) are ALL C-ABI callee-saved but JIT fns never push/restore them.
  Fix: (1) prologue snapshots home regs + every return path restores (emit.zig+op_control.zig); (2) the first try's
  "callee-saved→no-spill" op_call no-op was WRONG (JIT callees don't honor callee-saved) → real spill/reload around
  every CALL. New fixtures `homed_i64_loop` + `homed_local_recursive_call`. **Rosetta-VERIFIED** (edge p9=82/0,
  rust_fib=55, fac correct, wasm-2.0-assert 25437/0); arm64 byte-identical. **x86_64-LINUX (ubuntu) RUN UNVERIFIED.**
- **Phase I result**: D-265 = v2-jit ~2.3× slower than v1 when a loop body reads a loop-carried local (A/B:
  `a=a+i` 2.30× vs `a=a+CONST` 0.96×; not memory/ALU — confounded earlier). MECHANISM (`emit.zig:910-968`): every
  `local.get` = `next_vreg++` + `LDR [SP,#local_off]`; no residency cache. ROI ceiling = v1 parity (known
  achievable). Blast-radius = ZIR-lowering + `ir/liveness.zig` + `shared/regalloc.zig` + arm64+x86_64 emit
  (`alloc.slots` indexed by a pre-emit vreg stream → reuse must be modelled in the regalloc pass). W45 folded
  (v128 loop 2× faster). Repro: `private/spikes/s15p-parity/`.
- **ROI target**: w45_addi 2.3× → ≤1.1× vs v1; full test net + the Phase-II adversarial net green.
- **Correctness net** (test-only chunks; NO redesign code until green): ✅ stale-register-after-`local.set` +
  loop-carried-local + multi-local-pressure (the 3 landed fixtures). **GcRef-in-register-at-collection (D-261)**:
  the JIT path can't trigger GC yet (D-258 open; conservative scan = native stack only, not JIT regs) → the JIT
  adversarial test is **D-258-blocked**; it converts to a **Phase III DESIGN CONSTRAINT** (rework MUST keep
  GcRefs slot-resident across any potential collection point — register-residency for non-ref locals, ref-locals
  spill at collection sites), with the JIT adversarial test deferred to when D-258 lands.
- **NEXT (clear-session resume) — verify stage-4-redo `e8b7ad10` on x86_64-LINUX (ubuntu), then close the
  campaign**. The session that landed it was wrapped up (context grown) WITHOUT kicking ubuntu, so there is **no
  `/tmp/ubuntu.log` for `e8b7ad10`** — Step 0.7 cannot mechanically verify yet. **FIRST ACTION**: `bash
  scripts/run_remote_ubuntu.sh test-all > /tmp/ubuntu.log 2>&1` (bg) against HEAD `e8b7ad10`, then verify GREEN
  (the homed fixtures + fac/rust_fib now run HOMED on x86_64-linux there). Mac + Rosetta x86_64-macos are already
  green. **If ubuntu GREEN** → register-homed i32/i64 locals on BOTH backends = **D-265 campaign exit MET** →
  **Phase V**: measure x86_64 ROI (ubuntu w45_addi-style bench), ADR-0149/0150 Revision (regalloc headroom real on
  loop-locals) + ADR-0151 W45 note (matters for scalars), close the campaign + §15.P, flip ROADMAP. **If ubuntu
  RED** → apply the D-148 diagnostic below (Debug-vs-Release on x86_64-linux; if it's a Zig self-hosted-Debug
  backend bug → LLVM workaround, not logic; else fix the logic — Rosetta repros our-logic bugs). Deferred: stage 3
  (fp/v128 thin ROI), stage 2b (GC trampolines, D-258/D-261). All autonomous.

## Current state

- **Phase 15 (Performance parity with v1) IN-PROGRESS.** Phases 0-14 DONE. **§15.1** GC reclamation DONE
  (`be4357be`; ADR-0146/0147/0148; carve-outs → D-211/D-258). **§15.2/15.3** regalloc-axis perf — measured-folded
  (ADR-0149/0150) — but the "~0 headroom" claim is being REVISED (D-265: real headroom on loop-locals). **§15.4**
  SIMD coverage+ports DONE (D-246 `1029e5b4`; ADR-0151). **§15.5** D-245 win64 trampoline DONE (`510ffce9` +
  D-260 fix `3a778080`, test-all 3-host green). **§15.6** ClojureWasm CI ⏸ DEFERRED (ADR-0152 → D-264; cw is its
  own in-progress v1 redesign). **§15.P** parity MEASURED (`s15p_parity_vs_v1.md`) → the remaining work = the
  **D-265 rework campaign** (`## Active rework campaign` above). Runs fully autonomously per the philosophy.

## Step 0.7 (next resume)

**D-265 x86_64 BUG DIAGNOSTIC (user's compiler-bug lens, [[feedback_arch_env_compiler_bug_lens]])**: the ubuntu
fail is x86_64-LINUX **Debug** (`standardOptimizeOption` default) = the self-hosted backend D-148 found buggy
(Zig#35343: x86_64-linux Debug miscompile; arm64 + LLVM/Release PASS; workaround `.use_llvm=true`). D-148's repro
PASSES under Rosetta x86_64-MACOS (Debug+Release) → **Rosetta tests x86_64-macos, NOT x86_64-linux** (diff target →
diff self-hosted codegen). DIAGNOSTIC when the x86_64-homing subagent reports: (a) fac/rust_fib reproduce under
Rosetta x86_64-macos → OUR emit logic (fix it); (b) NOT reproducible under Rosetta but ubuntu-Debug fails →
Zig x86_64-linux-Debug backend bug → fix = LLVM workaround (`.use_llvm=true` on the x86_64 path), NOT logic. Confirm
on ubuntu: x86_64-linux Debug-fail + ReleaseFast-pass = Zig bug.

D-265 STAGE 4 REDO is COMMITTED (`e8b7ad10`) + Mac/Rosetta-green, but **x86_64-LINUX (ubuntu) is UNVERIFIED — no
ubuntu kick was run for it** (session wrapped up, context grown). **Clear-session FIRST ACTION = kick ubuntu
test-all against `e8b7ad10`** (see NEXT) — that IS the deferred Step 0.7. Revert `e8b7ad10` on ubuntu-red (or
apply the D-148 diagnostic above if it looks like a Zig-backend bug). The bugs the redo fixed DID reproduce under
Rosetta = our-logic, so ubuntu is expected green. (`a64c72a1`/`5d1dd221`/`7152021c` 2-host; `e8b7ad10` Mac+Rosetta,
ubuntu pending.) **NOTE** (lesson
`gate-tail-vs-exit-code`): benign `failed command: …--listen=-` / SlotOverflow / `arm64/emit: failing op` next to
a passing run = error-path noise — EXIT authoritative. **D-262 process fix**: any NEW per-arch emit chunk → run
`run_remote_ubuntu test-all` (NOT narrow `test`) before discharge (cross-compile ≠ cross-run).

**Gate hygiene**: Step-5 Mac = `bash scripts/mac_gate.sh`. Win64 cross-compile = `zig build test
-Dtarget=x86_64-windows-gnu`. windowsmini exec = `run_remote_windows.sh` (phase boundary).

## Deferred / open debt

- **STRUCTURAL RISKS (2026-06-04 retrospective, hub: lesson `session-retrospective-structural-risks`)** —
  the highest-stakes/most-orphan-prone: **D-261** (NOW, top stakes) GC-on-JIT conservative rooting has NO
  adversarial test → latent UAF (+ D-258). **D-262** (NOW) x86_64/win64 emit under-verified by the gate
  topology (cross-compile≠cross-run; D-260 symptom). **D-263** (NOW) parity-vs-v1 — MEASURED at §15.P
  (`bench/results/s15p_parity_vs_v1.md`); surfaced **D-265**. **D-210** (blocked-by) cohort root fix recurring at
  4 seams (D-142/206/210/245) — decide root-vs-patch.
- **D-265** (NOW, §15.P bundle) v2-jit ~2.3× slower when a loop body reads a loop-carried local (regalloc
  spill; bisected; contradicts §15.2/15.3 folds) — confirm mechanism + measure fix. **D-258** (NOW)
  JIT-trampoline GC collect trigger. **D-211** (blocked-by) precise GcRootMap.
  **D-257** (partial) 10 lesson `Citing`. **D-259** (note) spillBytes footprint. **D-255** C-API WASI io.
  **D-254** rust 3-OS. **D-253** §13.2 host_info. **D-251** WASI in AOT. **D-249** win bench. **D-238** x86_64
  EH thunk. D-234/237/229/231/204/209/213.

## Key refs

- ROADMAP §15 task table (15.1 DONE → 15.2 coalescer → … 15.5 D-245 … 15.6 ClojureWasm). Phase Status
  widget (14 DONE / 15 IN-PROGRESS). ADR-0146/0147/0148 (§15.1 GC); ADR-0128 §2 (non-moving conservative
  rooting); ADR-0036/0037/0038/0040 (coalescer + class-aware substrate); ADR-0135 (GC re-sequence).
