# Session handover

> ≤ 100 lines. Canonical fresh-session entry point per ADR-0104
> + `.dev/phase9_close_master.md` §8 (ARCHIVED-IN-PLACE 2026-05-25; cite-only).
> Framing: [`handover_framing.md`](../.claude/rules/handover_framing.md).

## Current state

- **Phase**: **10 IN-PROGRESS** (Phase 9 = DONE 2026-05-24)。
- **Last commit**: `1a6c0dfc` — 10.T-5 realworld/p10 skeleton (6
  toolchain dirs + PROVENANCE.md + skip-list.yaml)。
- 10.T closed (all 5 sub-chunks shipped)。10.D 7/7 ADRs drafted
  (Accept pending)。
- **Mac `zig build test`**: green (1827/1841 substrate baseline)。

## Phase 10 progress

ROADMAP §10 = 13-row task table。10.0/10.C9/10.J/10.F/10.Z/10.T
done (6/13); 10.D blocked on user Accept (7 ADRs Proposed);
10.M/10.R/10.TC/10.E/10.G/10.P all blocked on 10.D.

## Bucket-3 stop — user touchpoint required

All autonomous prep walked; loop stops without re-arm per
`.claude/skills/continue/SKILL.md` stop bucket 3.

**Gating user touchpoint**: review + Accept-flip the 7 Phase 10
design ADRs at `Status: Proposed → Accepted`. After all 7 flip,
ROADMAP §12 (AOT) gets amended with "stack-map emission
compatible with GC root walker" exit criterion, then 10.D closes
and impl rows 10.M / 10.R / 10.TC / 10.E / 10.G unlock.

| ADR | Slug | Status | Proposed at |
|---|---|---|---|
| 0111 | memory64 design | Proposed | `c3895cd1` |
| 0112 | Tail Call design | Proposed | `8d535ec1` |
| 0113 | callsite_metadata + regalloc 3-axis | Proposed | `e527b52b` |
| 0114 | Exception Handling design | Proposed | `027ae91a` |
| 0115 | GC heap + collector design | Proposed | `f37f3e56` |
| 0116 | GC roots + RTT + i31 | Proposed | `698a8b8f` |
| 0117 | GC × EH × TC integration invariants | Proposed | `4561dfe1` |

## Autonomous prep walked this resume (do not re-walk)

- **Reference-repo enrichment**: each ADR cites design plan
  §3.x + industry precedents (wasmtime / wasmer / SpiderMonkey /
  V8 / WAMR / wasm3 / v1) in its `References` section. URLs to
  upstream proposal repos cited (`github.com/WebAssembly/<p>`).
- **Consequences refinement**: every ADR carries `Consequences`
  (Positive + Negative) + `Removal condition` against current
  code state — verified at draft time against the Phase 9 close
  state (10.J native facade complete, 10.F c_api accessors
  shipped, 10.Z ZirInstr.payload u64 widen).
- **WebFetch upstream specs**: each ADR cites upstream proposal
  URLs (memory64 / tail-call / EH / GC / function-references
  + GC § 4.3.7 RTT display / EH § 4.5.5 tag matching / TC § 7.1.13
  proper tail call).
- **10.T parallel autonomous track**: shipped 5 sub-chunks
  (`ad16c2cc` / `433967fb` / `9748e805` / `1e381c52` / `3fab618b` /
  `1a6c0dfc`) — corpus import + runner skeletons + bless
  workflow + realworld scaffolding. ROADMAP 10.T `[x]` flipped.

## Spike-path (not yet walked; opt-in by user)

If user wants deeper verification before Accept, the following
`private/spikes/<slug>/` prototypes would refine the ADRs (each
is autonomous if user requests a follow-on /continue cycle):

- `private/spikes/adr-0114-fp-walk-unwind/`: prototype the FP
  chain walker against Mac aarch64 / Linux x86_64 (verifies
  decision §5 — same-shape unwind across hosts).
- `private/spikes/adr-0113-callsite-refactor/`: prototype the
  1-edge → N-edge bounds_fixups refactor against the existing
  Phase 8 codegen (verifies behaviour-preserving claim of
  ADR-0113 D1).
- `private/spikes/adr-0116-rtt-display/`: prototype the 8-deep
  display vs walk-up fallback dispatch (verifies O(1)
  `ref.test` claim against synthetic depth-7 + depth-9 RTTs).

Not required for Accept; user discretion.

## To resume

Flip the 7 ADRs `Status: Proposed → Accepted` (or amend in
place if redesign needed) and re-invoke `/continue`. The loop
will resume at 10.M (memory64 impl) as the first unblocked
impl row, OR at a spike-cycle if user prefers spike-based
verification before unblocking impl.

## Key refs

- **ROADMAP §10**: [`ROADMAP.md`](./ROADMAP.md) lines 1338+
- **Phase 10 design plan**: [`phase10_design_plan_ja.md`](./phase10_design_plan_ja.md) §3.1-§3.5 (ADR-0111..0117 source-of-truth)
- **ADR drafts**: [`decisions/0111`](./decisions/0111_memory64_design.md) .. [`0117`](./decisions/0117_gc_eh_tc_integration_invariants.md)
- **`/continue` autonomous prep paths**: `.claude/skills/continue/SKILL.md`
- **Sub-chunk log**: [`phase_log/phase10.md`](./phase_log/phase10.md)
