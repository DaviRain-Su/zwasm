# feature/component

Reserved subsystem slot per ADR-0023 §3 P-H + §3 reference table.

**Campaign OPENING (2026-06-07, ADR-0170)** — the full wasmtime-equivalent
Component Model + WASI-P2 campaign is now active. This slot opens in plan
chunk **A1**, which adds `decode.zig` and flips the `-Denable=component`
build gate. Until A1 lands, the directory stays README-only and
`-Denable=component` is still rejected at build configuration time.

Driver: [`../../../.dev/component_model_plan.md`](../../../.dev/component_model_plan.md)
(work sequence + reference chains). Decision: ADR-0170. Spec phase:
`.dev/proposal_watch.md`.
