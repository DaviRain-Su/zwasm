# JIT spec-corpus `--fail-detail`: split stderr (`2>/dev/null`) or the detail is mangled

2026-06-02. Diagnosing the convert+RTT regression needed the per-assert JIT fail
detail (`JITval`/`JITfail` lines) from the Wasm 3.0 assert runner. Two false
dead-ends wasted a chunk of a cycle:

1. **`zig build test-spec-wasm-3.0-assert -- --fail-detail`** — the build step
   did not forward `b.args`, so `--fail-detail` never reached the runner; AND
   `addRunArtifact` suppresses run-artifact stdout on success (exit 0). Net: no
   detail. (Adding `if (b.args) |a| run.addArgs(a)` fixes forwarding but not the
   success-suppression — not worth it.)
2. **Direct exe with `2>&1`** — `ZWASM_SPEC_ENGINE=jit <exe> <corpus> --fail-detail
   > log 2>&1`. The JIT emit/compile path emits heavy **`std.debug.print`
   diagnostics to stderr** ("arm64/emit: failing op …", "compileWasm: func[…] →
   UnsupportedOp", "… StackTypeMismatch") for every modrej/failing module. Under
   `2>&1` these splice mid-line into the buffered stdout, corrupting the
   `[proposal] … JIT: return …` summaries and the `JITval` lines so exact-pattern
   greps match nothing. It LOOKS like lost output (only first+last proposal
   survive intact) but it is interleave corruption, not loss.

## Recipe (reliable)

```sh
EXE=$(/bin/ls -t .zig-cache/o/*/zwasm-spec-wasm-3-0-assert | head -1)   # alias-safe
ZWASM_SPEC_ENGINE=jit "$EXE" test/spec/wasm-3.0-assert --fail-detail > /tmp/d.log 2>/dev/null
grep -E "JITval|JITfail" /tmp/d.log | grep "gc/"
```

- `2>/dev/null` (or `2>/tmp/err.log`) — the stderr emit-noise is the corruptor.
- `/bin/ls` bypasses the shell `ls -F` alias that appends `*` to the exe path
  (otherwise the path has a trailing `*` → exec fails 127).
- The runner's buffered `File.Writer` flushes fine on its own — no per-proposal
  flush needed once stderr is split (verified: 6/6 proposals, 53 JITval).

Same family as `2026-05-31-spec-jit-corpus-fails-are-gaps-not-stale-state`
(measure the real signal, don't trust a corrupted/absent one).
