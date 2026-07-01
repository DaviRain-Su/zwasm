# Single-arg JIT spec dispatch reopens the state-bridge question (no-arg measurement didn't generalise)

2026-06-02. Lesson `2026-05-31-spec-jit-corpus-fails-are-gaps-not-stale-state`
concluded a shared-runtime state bridge was zero-yield: of 96 no-arg fails,
87 never executed (compile/setup rejects) and the 9 that ran didn't depend on
prior directives → a bridge flips 0. That measurement was **no-arg-only**, and
the conclusion does NOT generalise.

## What single-arg dispatch (`dc87b072`, runScalar1Export) measured

Mac aarch64 jit mode: `assert_return pass 54→82 (+28), fail 12→41`. Clean
`--fail-detail` taxonomy (stderr discarded — see pitfall below): the +29 are
**ALL `memory64/memory_grow64`**. Pattern: a manifest does `(invoke "grow" …)`
then `(assert_return (invoke "load_at_page_size" (i64 …)) …)`. JIT mode bypasses
the interp path entirely and recompiles+sets-up FRESH per assert, so the
intervening grow action is never replayed → the load is out-of-bounds → Trap →
fail. Data-segment-backed loads (`address64`: `8u_good1 i64:0 -> i32:97`) PASS,
because `setupRuntime` applies active data segments at instantiation.

## Why the prior conclusion didn't transfer

No-arg result functions in the corpus are overwhelmingly pure const-computers
`(func (result i32) …const-expr…)` — no instance-state read, so state-replay
buys nothing. **Single-arg (and wider) functions read memory/tables/globals**
that prior action directives mutate. The fraction of asserts whose correctness
depends on cross-directive state rises sharply with arity. The state bridge is
zero-yield for no-arg and the **gating lever** for single-arg+.

## Takeaways

- A failure-taxonomy measurement is scoped to the shape set it ran on. Don't
  promote a no-arg finding ("state doesn't matter") to a general rule; re-measure
  when the shape set widens. (This is the dual of the prior lesson's own rule.)
- Per-call-recompile spec mode is correct for stateless asserts and structurally
  cannot pass mutation-dependent sequences. Next lever: replay intervening
  `(invoke)` actions against a persistent per-module runtime, OR enumerate
  grow/store-dependent asserts as skips (D-214). The 29 are a single attributed
  cluster, not mystery miscompiles — the RED signal stays interpretable.

## Pitfall (diagnostic infra)

`--fail-detail` over `2>&1` is unreliable: the runner's buffered stdout
interleaves with raw stderr emit-diagnostics (`arm64/emit: failing op …`),
splicing/eating lines (counted 11 detail lines vs tallied 41 fails). Discard
stderr (`2>/dev/null`) — the in-memory counters, not the printed lines, are
authoritative.
