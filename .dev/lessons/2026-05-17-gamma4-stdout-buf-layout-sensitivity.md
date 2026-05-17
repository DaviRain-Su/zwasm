---
name: gamma4-stdout-buf-layout-sensitivity
description: γ-4 (cross-module func-import relax) `_exit(142)` is layout-sensitive — re-builds with the same source flipped between green and crashing depending on `stdout_buf` size and incidental compile output. Bisect by stack layout is unreliable; needs in-handler last-module trace.
metadata:
  type: feedback
---

**Rule**: when γ-4-class fragility surfaces (`_exit(142)` past
the elem-corpus stdout flush horizon), **don't** try to localise
by varying `stdout_buf` size or per-corpus bisect. Both
techniques produce conflicting signals because the SEGV is
layout-sensitive, not source-determined-by-fixture.

**Why**: §9.9-III γ-4 retry post-γ-3.b-ii observed:

- `stdout_buf: [16]u8` build (binary `b0548a55a9b3...`): 5/5
  runs `exit=0` direct, but `zig build test-all` reported the
  same binary's run as exit=1.
- `stdout_buf: [1024]u8` build (`7e2555449544...`): 5/5 runs
  consistently `exit=142`.
- `stdout_buf: [4096]u8` build (`34b0f42541e2...`): 5/5 runs
  consistently `exit=142`.
- Re-build with `stdout_buf: [16]u8` (`7a4eb1ce2cc7...`): 5/5
  runs flipped to `exit=142` despite identical source-vs-the-
  first-buf=16 build.

So the same source produced both green and crashing binaries
across rebuilds. The crash is in some path γ-1..γ-3.b-ii
didn't fully cover, BUT the failing path's reproducibility is
deterministic-per-binary, not deterministic-per-source. Re-
compiles randomise the layout enough to flip the verdict.

Per-corpus bisect (running each of 84 subdirs as a separate
corpus) returned `exit=0` for ALL 84 subdirs individually,
yet the same binary fails the combined run. This eliminates
"corpus X has fixture Y that breaks" as the failure mode —
it's the iteration-order / accumulated-state interaction
that triggers the SEGV.

**How to apply**: when γ-4 retries again, **first** add an
in-handler last-module trace before chasing layout-bisect:

- Augment `sigsegvHandler` (`spec_assert_runner_base.zig`
  line ~1384) with an `async-signal-safe` print of the
  most-recent `.module` directive's file name (e.g. via
  a `pub var last_module_name: [256]u8 = undefined;` +
  `pub var last_module_name_len: u32 = 0;` that runCorpus
  updates at the `.module` arm; the handler reads + writes
  via `write(2)` to stderr).
- Pair with `lldb`/`gdb` against the failing-binary core
  dump (the runner already exits via `_exit(142)`, but a
  `setrlimit(RLIMIT_CORE, RLIM_INFINITY)` opt-in plus
  `sysctl debug.coredump_pattern` would capture the
  register state at SEGV time).

The current bisect-narrow comment in `hasUnbindableImports`
documents the punch-list in code. The handover names γ-3.c
(multi-table) as the next field-backing chunk, but γ-4 may
still fail post-γ-3.c — at that point fall back to the
in-handler trace before another bisect cycle.

**Where**: §9.9-III chunk (c)-2.3-γ-4 retry post-γ-3.b-ii
attempt. Verdict: skip the layout-bisect; reach for SIGSEGV
handler instrumentation next time.

**Related**: [[d134-rosetta-2-signal-translation-limit]] —
both share `_exit(142)` as the disambiguation exit code (by
design); the failure-mode-and-mitigation patterns differ
(D-134 was environmental — Rosetta translation race —
resolved via ubuntunote pivot; γ-4 is layout-sensitive on
native Mac aarch64 + likely Linux x86_64).
