# 2026-06-12 — Host memory exhaustion (138 GB) → layered reap/bound defenses

**Incident**: the Mac (48 GB RAM) ran out of application memory —
~138 GB ≈ 48 GB RAM + ~90 GB swap (all remaining disk) dirtied over
hours — and had to be hard-rebooted at 14:11. Per the user, the
dominant cause was AI-session work on the **ClojureWasmFromScratch**
side, not zwasm. A same-class precursor existed on this side too: an
8.5 h zig process overnight (21:27→05:54, resource diag in
`/Library/Logs/DiagnosticReports/`).

**zwasm-side audit result (Explore fan-out + manual)**: no unbounded
allocation path capable of >GB-class growth was found in test/e2e
infra. Spec/assert runners hold ~67 MB static growable-memory buffers
× 6 parallel runners + per-module arenas (freed per case); JIT code
buffers are corpus-bounded; the D-311 seed-flaky tests crash
(EXC_BAD_ACCESS at 0xAAAA…) rather than balloon. JIT guest mem-cap is
the known D-314 #3c-2 follow-up.

**Defense gaps found & closed** (the hang/orphan class is real even if
the leak was external):

1. `scripts/gate_commit.sh` — `zig build test`/`test-edge-cases`/`lint`
   ran unbounded; a hung test (e.g. an uninterruptible JIT loop,
   pre-D-314) orphans for hours. Now `bounded()` (timeout 1800/900/900,
   `-k 30`).
2. `scripts/orphan_guard.sh` — now also reaps LOCAL `zig build` /
   `.zig-cache/o/*` test binaries / `zig-out/bin/*` with **ppid==1**
   on every remote-gate kick (= every loop turn); the 30-min
   SessionStart backstop was the only prior cover.
3. `~/.claude/hooks/cleanup_orphans.sh` (my-mac-settings) — added
   `.zig-cache/o/` + `zig-out/bin/zwasm` patterns AND a
   **memory-runaway guard**: dev-tool-shaped process with RSS > 16 GiB
   for > 5 min is reaped regardless of the 30-min cutoff. Covers ALL
   projects (incl. CWFS) at every SessionStart.

**Forensics recipe** (what actually worked, post-reboot): `last reboot`
for the timeline; `~/Library/Logs/DiagnosticReports/*.ips` (crash) +
`/Library/Logs/DiagnosticReports/*.diag` (resource: long-lived PIDs,
disk-writes) for per-process evidence; `df -h` to bound how big swap
COULD have been (free disk = swap ceiling); `vm.swapusage`/`ps -axo
rss=` for live state. Unified-log jetsam queries returned nothing for
the prior boot — don't rely on them.
