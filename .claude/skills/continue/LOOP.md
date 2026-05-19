# continue — loop mechanics

> Sibling of `SKILL.md`. Holds the policy sections that are read
> once per session (push policy, self-perpetuation, parallel
> test gate) so `SKILL.md` itself stays focused on the per-task
> TDD steps.
>
> If you are reading `SKILL.md` and it references "Push policy",
> "Self-perpetuation", or "Parallel test gate", the canonical
> text lives here.

## Parallel test gate — file-logged pipeline

**Per ADR-0049 + ADR-0067**: the autonomous loop's per-chunk
gate is **two-host** (Mac aarch64 + `ubuntunote` native Linux
x86_64 via SSH). The windowsmini Windows x86_64 gate is
**deferred to a Phase-boundary "Windows reconciliation" batch
step** — autonomous chunks must NOT fire
`bash scripts/run_remote_windows.sh test-all`, regardless of
`should_gate_windows.sh`'s output. The script remains as an
informational heuristic only.

The two cost shapes:

- **Mac**: native, fast (≤ 60 s typical). Run synchronously and
  fail-fast — there is no value in backgrounding it because the
  next steps (commit / push) need its result inline.
- **ubuntunote**: SSH-remote to native x86_64, ~3-5 min
  typical. Run per-chunk in the background. SysV x86_64 ground
  truth, no Rosetta abstraction (D-134 absent here per
  ADR-0067).

A13 release-tag pushes (to `main`) still require full 3-host
green via `scripts/gate_merge.sh` — that's user-driven, not
autonomous-loop scope.

### Mandatory shape of the gate

This shape is **load-bearing**. A loop iteration that runs
windowsmini per-chunk (or that re-invokes
`scripts/run_remote_ubuntu.sh` just to re-read its log) is in
violation of this skill, even when the run happens to succeed.

```bash
# 1. Mac local: lint + unit tests (cheap, fast-fail). FOREGROUND.
zig build test                         > /tmp/mac.log     2>&1
zig build lint -- --max-warnings 0     > /tmp/mac-lint.log 2>&1

# 2. Source commit (Step 6).
git add <source-files>
git commit -m "<conventional commit>"

# 3. Sync the bench CI bot's commits, then push.
#    The bot pushes `bench(ci): record <sha> [skip ci]` to
#    zwasm-from-scratch asynchronously after every loop push;
#    `--rebase --autostash` integrates those commits with zero
#    conflict (bench/results/*.yaml is disjoint from loop diffs)
#    and avoids the per-chunk non-fast-forward reject cycle.
git pull --rebase --autostash origin zwasm-from-scratch
git push origin zwasm-from-scratch

# 4. Kick ubuntunote (native x86_64 Linux) only — windowsmini
#    deferred per ADR-0049; OrbStack retired per ADR-0067 (D-134
#    closed: Rosetta translation race absent on native host).
bash scripts/run_remote_ubuntu.sh test-all > /tmp/ubuntu.log 2>&1   # run_in_background: true

# 5. WAIT for completion notification (do NOT poll). When it
#    fires, Read /tmp/ubuntu.log to inspect the tail. NEVER
#    re-invoke `scripts/run_remote_ubuntu.sh` just to extract
#    output — the log file already has everything.

# (windowsmini steps moved to the Phase-boundary "Windows
#  reconciliation" sub-step per ADR-0049.)
```

**Why this exact shape:**

1. **ubuntunote backgrounding is non-negotiable.** The command
   takes long enough (3-5 min including remote `git fetch` +
   incremental `zig build`) that running it in the foreground
   blocks the loop. Run it with `run_in_background: true`. The
   harness sends a single completion notification; that is the
   signal to inspect the log.
2. **All output → log file.** SSH redirects stdout+stderr to
   `/tmp/ubuntu.log`. The log is the single source of truth —
   read it with the Read tool when the notification fires.
   Re-running `scripts/run_remote_ubuntu.sh` to re-read output
   is forbidden regardless of how convenient grep would have
   been.
3. **No polling, no sleep.** Once backgrounded, the harness
   notifies on completion. Sleep loops, retry-on-blank-output
   loops, and eager `tail` re-runs are all loop-discipline
   violations.
4. **windowsmini is deferred per ADR-0049** — the gate runs
   once per Phase-boundary "Windows reconciliation" sub-step,
   not per chunk. The autonomous loop ignores
   `should_gate_windows.sh`'s gate-required output entirely.
5. **OrbStack is NOT a gate host** per ADR-0067 — D-134
   Rosetta-translation SIGSEGV race retired it. OrbStack stays
   as a Mac-local interactive scratch host
   (`.dev/orbstack_setup.md`); the autonomous loop never
   invokes `orb run …`.

### When to skip the parallel pattern (rare)

Stay strictly serial only when:

- The diff touches load-bearing infra (build.zig, runner glue,
  zone deps, ROADMAP) AND a regression on ubuntunote is
  plausible enough that you want a clean serial baseline.
- You are mid-incident (debugging a known regression) — running
  a clean serial baseline once is acceptable to localise.

In both cases, still log to file (`> /tmp/...log 2>&1`) so a
log-loss never forces a rerun.

### Re-runs are debt, not a tool

If a host's log shows a result you cannot interpret (truncated,
ambiguous, missing the failure line), the response is **Read
the log file again with offset/limit, or grep the file** —
never `scripts/run_remote_ubuntu.sh` a second time hoping for
cleaner output.

### Recovery on failure

- Mac green + ubuntunote red → land a fix-up commit on top
  (`fix(p<N>): <one-line> — fixes <prev-sha>`) and re-run the
  ubuntunote gate (one round). Do not amend the pushed commit —
  `git push --force` is forbidden (§14).
- After fix-up lands, optionally squash the chain to a single
  meaningful commit on the next chunk's pre-push (`git rebase
  -i` locally, then push) — only when the squash is
  mechanical. Skip when in doubt.

### Heisenbug streak tracking (per chunk)

D-134 (the canonical heisenbug example since d-64) was **closed
2026-05-17** by Ubuntu pivot per ADR-0067 — the Rosetta-
translation race that drove it is structurally absent on the
native `ubuntunote` host. Future heisenbug debt rows continue
to use the per-chunk streak-tracking discipline below.

For every active heisenbug debt row, record each per-chunk
ubuntunote outcome:

```bash
# After ubuntunote /tmp/ubuntu.log shows the outcome:
if grep -q '0 failed' /tmp/ubuntu.log; then
    bash scripts/track_heisenbug.sh <name> silent
else
    bash scripts/track_heisenbug.sh <name> segv   # or `fail` for non-SEGV
fi
```

The script appends to `private/heisenbug-<name>.log` (gitignored)
and prints `DISCHARGE CANDIDATE` when the streak threshold fires
(default 5 per `.claude/rules/heisenbug_discharge.md`). On
discharge candidacy: do NOT close the debt row autonomously —
walk the 4-condition checklist in the rule (streak, structural
commit diversity, instrumentation in place, root cause OR
ADR-rate-reduction), then surface to the user.

### Step 7 integration

The Step 6 source-commit + push happens **before** the
ubuntunote gate starts. Step 7's handover update + ROADMAP
`[x]` flip lands as a follow-up commit + push **after**
ubuntunote returns green. This keeps the gate's reference
state fresh and
amortises bookkeeping over the gate wait.

### Phase-boundary "Windows reconciliation" (per ADR-0049)

When a Phase closes (the last `[ ]` in §9.<N> flips to `[x]`),
**before** opening §9.<N+1> the loop must run a one-off
windowsmini reconciliation:

```bash
bash scripts/run_remote_windows.sh test-all > /tmp/win.log 2>&1
# Wait for completion notification, then Read /tmp/win.log.
# Categorise any FAIL: Win64-ABI vs WASI vs IPC-flake (D-028)
# vs other. Fix inline (small) or file debt entries (large).
# After the reconciliation reaches green:
bash scripts/should_gate_windows.sh --record   # mark HEAD as last-tested
```

Only after windowsmini is fully green does the next phase open.
This is a hard step; "skip and defer to release tag" is not an
option per ADR-0049's Alternative C rejection.

## Push policy — autonomous, no approval

`git push origin zwasm-from-scratch` does **not** require user
approval inside this skill. The loop pushes its own commits.
Specifically:

- Every commit lands on the local `zwasm-from-scratch` branch via
  the per-task TDD loop (Step 6).
- Push happens at the end of every Step 7, after `[x]` flip
  + handover update — push so the gone-from-local risk is
  bounded by one task. (Per ADR-0049 the windowsmini gate is
  deferred to Phase boundaries, so there's no per-chunk pre-
  push for windowsmini's git-fetch sync.)
- **Pre-push rebase is the default**. Always run `git pull
  --rebase --autostash origin zwasm-from-scratch` immediately
  before `git push`. The bench CI bot pushes
  `bench(ci): record <sha> [skip ci]` commits to the same branch
  asynchronously after every loop push, so the local branch is
  almost always behind by 1–3 such commits when Step 6 / Step 7
  fire. Bench commits only touch `bench/results/*.yaml` (disjoint
  from loop diffs in `src/`, `.dev/`, `scripts/`, `test/`), so
  the rebase is conflict-free in practice. `--autostash` covers
  any uncommitted scratch in the worktree.
- A non-fast-forward error after pre-push rebase indicates **non-
  bench commits arrived between the rebase and the push** (rare;
  e.g. a parallel manual push). Re-run the same `git pull
  --rebase --autostash + git push` once. Only stop and surface
  to the user if the rebase itself raises a conflict —
  conflicts are bucket-2 of the stop whitelist (load-bearing
  history work needs user input).
- Push is **never to `main`** and **never `--force` /
  `--force-with-lease`** (denied at the harness level too).
- `--no-verify`, `--no-gpg-sign`, and any pre-commit / pre-push
  hook bypass remain forbidden (ROADMAP §14).

This overrides the "explicit user approval" wording elsewhere; that
wording exists to forbid drive-by pushes outside this loop, not to
gate the loop itself.

## Git operations are serial — never parallel

Unlike the parallel test gate above, **git operations must run
strictly sequentially within the loop**. Never issue two `git`
invocations in the same Bash batch (`&&`, `;`, or two parallel
Bash tool calls in one assistant message), and never issue a
`git` command while another `git` (especially `git commit` whose
pre-commit gate runs `gate_commit.sh` for several minutes) is
in flight in the background.

**Why**: `.git/index.lock` is acquired by every state-mutating
git command (`add`, `commit`, `pull`, `push`, `fetch`, `reset`,
…) and held until the command returns. Concurrent acquisition
attempts crash with `fatal: Unable to create '.git/index.lock'`
and can leave a 0-byte stale lock behind that blocks subsequent
git commands until manually removed. The d-57 commit cycle
surfaced this when a `git add -A` raced with a still-flushing
prior git invocation; recovery required the user to approve
`rm .git/index.lock`, breaking autonomous flow.

**Discipline**:

- Step 6 source commit: one Bash call, runs `git add ... && git
  commit ...` in a single sequential pipeline. No parallel git
  in the same message.
- Step 7 chore commit + push: one Bash call, runs `git add ...
  && git commit ... && git pull --rebase ... && git push ...`
  sequentially. Never split across parallel Bash tool calls.
- `git status` / `git log` / `git diff` for inspection: safe to
  batch with each other (read-only, no lock acquisition), but
  must not be parallelised with any state-mutating git command.
- Background `run_in_background` Bash invocations: must not
  contain `git` commands at all. Backgrounded git would race
  the loop's own Step 6/7 sequence with no feedback.

**Stale-lock fallback**: `scripts/check_stale_git_lock.sh` runs
as a PreToolUse hook before every Bash invocation; it removes
`.git/index.lock` only when its mtime is > 60 s old. This
covers external concurrent git (editor integrations, MCP
tooling, bench CI bot) but does **not** excuse violating the
serial-git discipline within the loop — relying on the
fallback is debt, not a tool.

## Self-perpetuation — overnight loop

After every Step 7 commit lands and is pushed, the very last action
of the turn is to schedule the next iteration so the loop survives
without a fresh user message. **This is mandatory** — skipping it
silently re-introduces user-babysitting.

Use `ScheduleWakeup` with **`delaySeconds = 60` always**:

```
ScheduleWakeup(
  delaySeconds = 60,
  reason = "loop iteration <task-id> committed; re-arming for next task",
  prompt = "/continue"
)
```

`prompt = "/continue"` re-fires this skill from the resume
procedure on the next wakeup. (Do **not** pass
`<<autonomous-loop-dynamic>>` — that sentinel is for `/loop`
invocations started without any user prompt; this loop began
with the user's `/continue` and must be re-invoked the same
way.)

`ScheduleWakeup` is a deferred tool. On the first iteration of
a fresh session, load its schema via
`ToolSearch(query="select:ScheduleWakeup", max_results=1)` once
before the first call; subsequent calls in the same session do
not need re-loading.

If the user replies between iterations, that is automatic
intervention — the wakeup is consumed by the new turn and the
loop naturally resets to whatever the user said.

If a `ScheduleWakeup` call would be the second one of the same
turn (only one wakeup per turn is honoured), update the existing
one with `ScheduleWakeup` again instead of stacking.

End-of-turn checklist (every turn that ends with the task closed):

1. Step 6 commit landed.
2. Step 7 handover update + ROADMAP `[x]` flip committed.
3. `git push` succeeded.
4. `ScheduleWakeup` armed for the next iteration.
5. Final user-facing text is **one sentence** stating what just
   landed and what fires next. Do not write a long progress
   summary — it invites pause.

## Chunk granularity — when to bundle vs split

> Detail block extracted from SKILL.md at §9.12-A / A5b. SKILL.md
> retains a 6-line "Default + bundle/split criteria" summary; the
> historical examples and full criteria live here.

**Default chunk size for established-pattern emit/handler chunks:
5–15 ops.** Sub-1-op chunks are reserved for ADR-grade design
changes (new ABI surface, new scratch reservation, new shared
helper). The 7.7-fp + §9.7 / §9.9 retrospectives both surfaced
over-split anti-patterns where 1–4 op chunks dominated commit
overhead despite mechanical implementation; the §9.7 / §9.9
run alone landed ~25 chunks where ~6 would have served the same
purpose with materially less wall-clock per delivered op.

**Bundle into one chunk when ALL hold:**

- Same **dispatch helper consumer** (e.g. all `v128MemPrologue`
  consumers — load + load_splat + load_zero + load_lane +
  load_extend = ~24 ops in one chunk; all `emitV128IntBinop`
  consumers — int min/max + sat arith + avgr ~22 ops in one
  chunk). The criterion is "do these wrappers share the same
  shared helper?", not "do they share the same encoder family"
  — the latter is too narrow and was the binding constraint
  driving the over-split run.
- Same handler shape (only `op` field differs; switch arms
  inside the handler).
- Total source diff ≤ 800 LOC, total test diff ≤ 400 LOC (was
  400 / 250 — raised to match the actual cap above which
  reviewability deteriorates rather than the median chunk size).
- Boundary semantics across variants are coordinated (one ADR /
  one rationale comment covers the family).

**Split when ANY hold:**

- Implementation crosses an instruction class (GPR vs XMM
  pipeline, ALU vs memory, scalar vs SIMD).
- One variant requires a structurally different recipe
  (e.g. trunc-sat-u64's 2^63 split vs trunc-sat-u32's direct
  .q-form, or fmin/fmax NaN-correction vs pmin/pmax direct
  MINPS).
- ADR-grade design choice for one variant only (e.g. chunk
  introduces a new scratch-register reservation, new ABI
  contract, new shared helper that didn't exist before).
- Mid-cycle ratchet would push the diff > 1200 LOC including
  tests.

**Concrete examples (looking back at §9.7 + §9.9):**

| Group                                | Should have been | Was             |
|--------------------------------------|------------------|-----------------|
| 7.7-alu (i32 add/sub/mul/and/or/xor) | 1 chunk          | 1 chunk ✓       |
| 7.7-cmp + 7.7-eqz                    | 1 chunk          | 2 chunks (over) |
| trunc-sat-u32 + trunc-sat-u64        | 1 chunk          | 2 chunks (over) |
| trunc-trap-signed + trunc-sat-signed | 2 chunks         | 2 chunks ✓ (semantics differ) |
| fp-convert-simple + fp-convert-unsigned | 1 chunk       | 2 chunks (over) |
| 9.7-au (int min/max + sat + avgr 22 ops) | 1 chunk      | 1 chunk ✓       |
| 9.7-ax..bb (v128 mem family 22 ops)  | 1–2 chunks      | 5 chunks (over: ax/ay/az/ba/bb) |
| 9.9-a + 9.9-b (foundation + v128 ABI) | 1 chunk        | 2 chunks (over: ABI was small) |

When in doubt, **bundle**: the chunk-table row in handover.md
is a status marker, not a unit of work. One commit covering
"f32/f64 convert + reinterpret + promote/demote (10 ops)" or
"v128 memory family (load + store + splat ×4 + zero ×2 + lane
×8 + extend ×6 = 22 ops)" is more readable in `git log` than
ten 2-op commits, and the cumulative test-gate wall-clock
shrinks proportionally.

**Anti-pattern: "1 op = 1 chunk"** for ops that follow an
established pattern (existing helper, single-instruction
mapping, or copy of an immediately-adjacent variant). Each
extra commit adds ~5-10 min of wall-clock (test gate + push +
windowsmini if gated + handover + chore + re-arm) for ~1 min
of marginal review value when the implementation is mechanical.

## Subagent delegation cheatsheet

| Trigger                               | Action                                              |
|---------------------------------------|-----------------------------------------------------|
| Survey ≥ 1 reference codebase / OSS   | Step 0 — Explore subagent                           |
| Test output > 200 lines               | Step 5 — Bash subagent (run_in_background if long)  |
| Search across > 5 files               | Explore subagent                                    |
| Single-file edit, < 200 lines context | Stay in main                                        |

Default rule: **subagent fork on context isolation, not on
importance**.

## What NOT to invoke during the loop

- `simplify` per source commit — overkill; queue for occasional
  passes.
- `review` (PR-style) per commit — overkill; reserve for pre-push
  or pre-tag.
- `audit_scaffolding` per task — adaptive cadence (when scaffolding
  feels off, when refactors land, before release tags).

## Model selection (dual-model)

- **Per-task TDD loop (Steps 1–6)**: current session's model — Opus
  4.7 is fine.
- **Phase boundary chain (multi-agent fan-out, when invoked)**:
  prefer **Opus 4.6** for the long-context audit / simplify
  subagents — Opus 4.7's MRCR v2 retrieval is known to degrade
  above ~100k tokens versus 4.6. Sonnet 4.6 is a viable
  cost-efficient alternative.

When unsure, default to subagent inheriting the parent model; flip
to Opus 4.6 only if a long-context task underperforms.

## Anti-patterns observed in past sessions (do not repeat)

These are concrete failure modes from prior runs. Reading them once
beats inventing new ways to stop.

- **"Big next task, natural stop"** — picking up that the next
  task looks bigger and ending the turn so the user can issue
  another `/continue`. Forbidden — the whole point is no
  babysitting. Push the commit, re-arm, continue.
- **"N commits is enough"** — landing several tasks then writing
  a progress summary as a soft pause. Forbidden — write one
  sentence and re-arm.
- **"Push needs approval"** — interpreting CLAUDE.md's push
  language as a per-loop gate. Forbidden — push policy is
  autonomous inside this skill.
- **"windowsmini gate not exercised, defer"** — declaring local
  Mac + ubuntunote good and stopping until next session. **Per
  ADR-0049 this anti-pattern is now reversed**: deferring
  windowsmini per-chunk is the policy. The autonomous loop
  runs Mac + ubuntunote only and reconciles windowsmini at
  Phase boundaries.
- **"User can /continue when ready"** — the closing line that
  re-introduces babysitting. Forbidden — the closing line is the
  `ScheduleWakeup` and one short sentence.
- **"Auto-compact might be coming, safer to stop"** — forbidden;
  PostCompact recovers, the loop continues.
