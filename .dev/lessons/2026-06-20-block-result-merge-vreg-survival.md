# Block-result merge vregs must survive an intervening call (D-330 + D-331A)

> **STATUS 2026-06-20: fix IDENTIFIED + arm64-correct, but REVERTED** — the
> `liveness.zig` change below closes D-330/D-331A on arm64 (c_sha256 107,
> go_hello prints) yet REGRESSES x86_64 `labels.wast switch` (`got 25, expected
> 50`): the `captureBlockMergeVregs` call fires on a single `depth` but `br_table`
> has MULTIPLE targets, so the multi-target br_table → block-result merge case is
> mishandled (x86_64 regalloc surfaces it; arm64 happened to allocate OK). The
> diff is preserved in commit `1c59101ff`. RE-LAND requires handling `br_table`
> (capture for every target depth) + verifying on x86_64 (Rosetta `-Dtarget=
> x86_64-macos` + ubuntu). The diagnosis + method below are CORRECT.


**The bug** (one root, two famous symptoms): a `block (result T)` reached by a
forward `br`/`br_if` plus a fall-through. The arm64/x86_64 emit captures the
result operands as the block's canonical merge vregs (`captureOrEmitBlockMergeMov`)
and `.end` homes the fall-through result into them. But **liveness** left those
captured vregs with a `[def, def]` range that DIES at the branch — so regalloc
was free to park the merge value in a **callee-saved register** (arm64 X20–X22 /
x86_64 RBX–R14). When an intervening `call` (e.g. `putchar`) clobbers that reg and
a later taken `br_if` jumps OVER `.end`'s home-MOV, the merge reg is left stale →
the post-block consumer reads garbage → wrong branch.

**Two symptoms, same bug**:
- D-330: c_sha256 dropped the final `\n` (`i32.ne(0,10)` instead of `(10,10)` → the
  `\n` putchar skipped; 106 B vs 107).
- D-331A: the whole Go runtime miscompiled under JIT (a `goargs`/`schedinit`
  branch went the wrong way → "unlock of unlocked lock" etc.). ~1.8M tokens over 6
  investigations chased it as a spill-hole / call-return / memory-load / vreg
  miscompile — it was this.

**The fix** (`src/ir/analysis/liveness.zig`, shared → both arches): mirror the
EXISTING if/else `merge_vregs` survival (D-093 d-11) for `block` merges —
`captureBlockMergeVregs` on the first forward `br`/`br_if`/`br_table` to a
`block(result>0)` (skip `loop`s), and at `.end` bump the merge vregs'
`last_use_pc` to `.end` + swap them onto the operand stack. This extends their
range across any intervening call, forcing a spill instead of a call-clobbered
callee-saved home. Closed both; realworld interp-vs-jit diff 55/56 → 56/56; no
golden-byte drift.

**Method lesson (the big one)**: 6 IR/source-level investigations DISPROVED their
own theories. What cracked it: **lldb instruction-level single-step** of the JIT'd
machine code (`ZWASM_DEBUG=jit.dump` → disasm via llvm-mc → `lldb` `si` watching
the reg that should hold 10 until it reads 0). The debt row's `D-330:1287`
hypothesis ("liveness range doesn't span the call → callee-saved park") was
CORRECT but stayed unconfirmed for months because source-level probes can't see a
register get clobbered by a call. Rule: for an elusive value-miscompile where a
value "should be X reads 0/wrong at a branch" and IR-level theories keep failing,
go straight to lldb single-step — don't keep hypothesizing. See
[[2026-06-20-elusive-jit-miscompile-techniques]], [[D-330]], [[D-331]].
