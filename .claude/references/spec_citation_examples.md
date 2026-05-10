Loaded on demand from `.claude/rules/spec_citation.md`; not auto-loaded.

# Wasm spec citation — format examples, reviewer, audit, anti-patterns

The gate-rule holds the rule itself + the category table. This file
holds worked format examples, reviewer checklist, audit_scaffolding
mechanics, staleness handling, and forbidden anti-patterns.

## Format examples

### A validator handler

```zig
/// Wasm spec §3.4.4 (block) — push a control frame; pop / push
/// the param / result types per the blocktype. Multi-value
/// (Wasm 2.0) requires a typeidx-based blocktype that resolves
/// to a `FuncType` from the module type section.
fn opBlock(self: *Validator, op: ControlOp) Error!void {
```

### A per-arch emit handler

```zig
/// Wasm spec §4.4.1.1 (i32.add) — pops two i32, pushes their
/// sum mod 2^32. ARM64 lowering: `ADD Wd, Wn, Wm`
/// (Arm IHI 0055 §C6.2.4). The W-form variant zero-extends the
/// upper 32 bits of the X register so subsequent i32 reads see
/// a clean value (load-bearing for §3.3.1.4 type preservation).
pub fn emitI32Binary(ctx: *EmitCtx, ins: *const ZirInstr) Error!void {
```

### A parser decoder

```zig
/// Wasm spec §5.4.X (block type) — encoded as a signed LEB128.
/// Negative values are well-known type abbreviations
/// (-64 = empty, -1 = i32, ...); positive values are typeidx
/// into the module's type section.
fn readBlockType(self: *Validator) Error!BlockType {
```

## Reviewer checklist (apply during PR review and §F audit_scaffolding)

- [ ] Every newly added spec-semantic handler carries a `Wasm spec §X.Y` line
- [ ] If the handler implements a Wasm 2.0 / 3.0 proposal feature, the
      citation also names the proposal (`Wasm 2.0 multi-value §A.B`,
      `Wasm GC proposal §C.D`)
- [ ] If the docstring describes ONLY architectural encoding (no Wasm
      semantics), the function is in the "encoder" category and Wasm
      citation is correctly omitted
- [ ] When refactoring touches a handler, the spec citation is preserved
      (or updated if the spec section shifted in a proposal merge)

## How `audit_scaffolding` enforces this

The skill (`§G` per `audit_scaffolding`) periodically greps spec-
semantic files for handlers lacking a `Wasm spec §` citation:

```sh
grep -rEn '^pub fn emit|^pub fn op[A-Z]|^fn read[A-Z]' src/ \
  | while read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    fn=$(echo "$line" | sed 's/.*fn //; s/[ (].*//')
    # Check the docstring 5 lines above contains "Wasm spec §"
    ...
  done
```

This is an opportunistic audit — the rule itself is the primary
mechanism, the audit is the safety net.

## Stale-ness

When a Wasm proposal is merged into the core spec (e.g. multi-value
moved from "Wasm 2.0 multi-value proposal" to "Wasm spec §3.X" once
the proposal hit phase 5), citations should be updated to the merged
section number. The `audit_scaffolding §G` periodic re-walk catches
stale proposal citations.

## Why this rule, not an ADR

This is observational + prescriptive (a rule about how new code is
authored), not a load-bearing decision that gates downstream behaviour.
Per `lessons_vs_adr.md`, prescriptive rules of-the-project that don't
pick a code path live in `.claude/rules/`.

## Forbidden anti-patterns

- **Citing the ADR instead of the spec**: ADRs are project decisions;
  spec citations are upstream truths. ADR-0017's decision rests on
  Wasm spec §X.Y; the handler should cite the spec, not the ADR.
- **"Spec section TBD"**: surface as a debt entry naming the specific
  gap. Never land a handler with a placeholder citation.
- **Burying the citation in a separate `// FIXME(wasm-spec):`
  comment**: must be in the function's docstring (`///`), reachable
  from a reader who hovers the symbol.
