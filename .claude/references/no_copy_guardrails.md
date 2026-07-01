Loaded on demand from `.claude/rules/no_copy_from_v1.md`; not auto-loaded.

# No copy-paste from v1 — rationale, examples, exceptions

The gate-rule preserves the prohibition itself. This file holds the
"why", worked OK / NOT-OK examples, reviewer checklist, and the
exception list for externally-authored artefacts.

## Why (in order of importance)

1. **Implicit-contract sprawl** — v1's idioms carry assumptions about
   layer boundaries, error sets, and runtime invariants that were
   never written down. Copy-paste imports those assumptions silently.
   Re-derivation surfaces them as questions.
2. **W54-class regression risk** — v1's post-hoc layered optimisations
   (W43 / W44 / W45 / W54 hoist / coalescer) accumulated into a
   fragile lattice. v2's day-1 ZIR substrate makes the same
   optimisations clean adds (Phase 15). Copy-paste defeats this by
   re-introducing the lattice.
3. **Knowledge compression** — re-derivation is what makes the project
   teachable. The result lives in v2 because someone understood why,
   not because someone clipboarded it.

## Examples

### OK

> "I read v1's `validate.zig` § type-stack tracking. The MVP-level
> idea is the same in v2: explicit `ArrayList(ValType)` push/pop with
> polymorphic markers for `else` and `end`. I re-derived the structure
> here, splitting the per-feature handlers into
> `src/feature/<feature>/validate.zig` per ROADMAP §4.5."

### NOT OK

> "Ported `validate.zig` from v1 with minor renames."

If the diff between v1 and v2 is "minor renames", you bypassed the
redesign step.

## Reviewer checklist

- [ ] If a chunk of code looks suspiciously similar to a v1 source
      file, ask the implementer: "what did Step 0 surface that v1
      doesn't have?"
- [ ] If the answer is "nothing — it's the same shape", ask: "where's
      the ROADMAP principle citation that justifies the v1 idiom?"
      (Guard 1 in `textbook_survey.md`).
- [ ] If both are missing, request a re-implementation.

## Exception: spec testsuite, sample wasm, third-party SDKs

This rule applies to **zwasm-authored source**. Things that are
externally authored and exempt:

- WebAssembly spec testsuite `.wast` / `.wasm` (vendored verbatim).
- WASI testsuite (vendored verbatim).
- Realworld sample sources (TinyGo / Rust / emcc binaries) —
  externally produced, copied as snapshots.
- `include/wasm.h` — fetched verbatim from upstream
  `WebAssembly/wasm-c-api`.

These are not "v1 source"; they are upstream artifacts that v1 also
consumed. v2 fetches them fresh from the same upstream.
