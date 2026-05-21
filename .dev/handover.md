# Session handover

> ≤ 80 lines. No numeric predictions (per
> [`no_handover_predictions.md`](../.claude/rules/no_handover_predictions.md)).

## Cold-start procedure — §9.12-G CLOSED; §9.12-H next

§9.12-G (Phase 10 prep substrate) flipped to `[x]` this commit.
All exit criteria satisfied:

- 44 wasm_3_0 placeholders register `wasm_level: .v3_0` →
  dispatcher's build-level filter emits
  `Error.UnsupportedOpForBuildLevel` at comptime for `-Dwasm=v1_0`
  / `-Dwasm=v2_0` builds (dispatch_collector.zig test at line 459
  verifies the mechanism).
- `bash scripts/zone_check.sh --gate` exits 0 (BASELINE=0 + 0
  current violations).
- 19 inline c_api Instance-path test blocks (488 LOC, ~34% of
  api/instance.zig) cover null-arg / lifecycle / dispatch /
  marshaling / import binding / export discovery.

Future ZirOp additions (memory64 / relaxed-simd / multi-memory)
are properly tracked in `.dev/wasm_3_0_zirop_mapping.md` Coverage
gaps section as Phase 10-open work; they require a ZirOp slot
policy ADR (per-op vs index-type-dispatched shared slots), not
in §9.12-G scope.

**Next pickup: §9.12-H** — Bench baseline (Mac Wasm 2.0 +
wasmtime comparison).

1. Survey `scripts/run_bench.sh` for current `--compare` /
   `--capture-rss` flag state.
2. Extend with wasmtime-compare path on Mac aarch64
   ReleaseSafe; 26 fixtures × hyperfine `--warmup 3 --runs 5`.
3. Add separate `runtime: zwasm` / `wasmtime` rows to
   `bench/results/history.yaml`.
4. Partial D-074 resolution; wazero/wasmer/bun/node + `-Dwith-
   bench-compare` flag are deferred to Phase 11.
5. Exit: "p9-close: Wasm-2.0 baseline (Mac aarch64)" row in
   `bench/results/history.yaml`; zwasm vs wasmtime mean_ms
   ratio documented.

## §9.12-G sub-deliverable closure summary (this commit)

| # | Status | Where landed |
|---|---|---|
| (a) | ✅ | `c305deb1` — wasm_3_0_zirop_mapping currency refresh |
| (b) | ✅ | satisfied by current state — 44 placeholders cover GC/EH/tail-call/typed-funcref; memory64 (shared opcodes) / multi-memory (no new opcodes) / relaxed-simd (Phase-10-open) tracked in mapping doc |
| (c) | ✅ | `fa810b6d` — instance.zig FILE-SIZE-EXEMPT + audit |
| (d) | ✅ | pre-existed — main.zig:18,62-75 + run.zig:50-56 + 2 inline tests at run.zig:254,262 |
| (e) | ✅ | `038d861f` — check_wasm_h_upstream.sh; identical |
| (f) | ✅ | pre-existed — gate_commit.sh:92 already `--gate`-invokes |
| (g) | ✅ | `568bb888` — .dev/architecture/zone_layout.md |

## Recent reform context (file-size discipline)

Cycles C1..C6 (2026-05-21) landed ADR-0099 + 0100 + 0101 + rule +
script + lesson + init_expr.zig redesign. Reform complete;
planning artefacts archived at
`private/archive/2026-05-21-file-size-reform/`.

## Active `now` debts

- **D-055** (mechanical, multi-cycle): emit_test_int has 27 sites
  pending.

## Other queued work

1. **§9.12-H** — bench baseline (this cycle's pickup).
2. **§9.12-I** — ADR/lesson curation closure (Phase 9 close).
3. **D-055 continuation**.
4. **Phase 10 ZirOp slot policy ADR** — gates memory64 /
   relaxed-simd file-level placeholder additions.

## Active state (snapshot)

- §9.12-A enforcement: 11 items OK + `check_wasm_h_upstream.sh`.
- §9.12-F (D-141 + reform): closed.
- §9.12-G: **CLOSED** this commit.
- §9.12-H: next.
- §9.12-I: open.

## Open questions / blockers

- なし for §9.12-H entry.

## See

- [ROADMAP](./ROADMAP.md) §9.12-H scope + exit
- [`.dev/architecture/zone_layout.md`](./architecture/zone_layout.md)
- [`.dev/architecture/api_instance_audit.md`](./architecture/api_instance_audit.md)
- [`.dev/wasm_3_0_zirop_mapping.md`](./wasm_3_0_zirop_mapping.md)
- [`scripts/run_bench.sh`](../scripts/run_bench.sh) — extend at §9.12-H
- [`bench/results/history.yaml`](../bench/results/history.yaml)
- [`debt.md`](./debt.md), [`lessons/INDEX.md`](./lessons/INDEX.md)
