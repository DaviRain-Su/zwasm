# D-489 localized: x86_64-jit miscompiles the SECOND printf (3-arg), not the first

**Date**: 2026-06-21
**Method**: `ZWASM_DEBUG=wasi.iovec` (new permanent primitive, fd.zig fdWrite
entry + ciovec trace) — engine-independent ground truth, diffed interp vs
x86_64-jit on tinygo_json.

## The divergence (exact)

INTERP (correct) makes **3** `fd_write` calls:
- `buf=90512 len=47` — `json: {...}\n`
- `buf=90512 len=29` — `name=Alice age=30 city=Tokyo\n`
- `buf=90512 len=14` — `roundtrip: OK\n`

x86_64-JIT makes **exactly 1** `fd_write` (`buf=90512 len=47`, byte-identical to
interp's first) then **diverges**: stdout shows `%!(EXTRA string=Alice, int=30,
string=Tokyo)` + `roundtrip: FAIL`, and the 2nd/3rd `fd_write` NEVER fire.

## What this rules in / out

- **printf #1 works byte-perfectly** → basic memory/string/print codegen on
  x86_64 is CORRECT. The bug is NOT a broad memory-access or string-load defect.
- **printf #2 is miscompiled**: `name=%s age=%d city=%s` — 3 verbs, mixed types.
  Go's fmt emits `%!(EXTRA ...)` = it found FEWER format verbs than args. The arg
  **values + types are correct** (`string=Alice, int=30, string=Tokyo`), so the
  defect corrupts the **format-verb scan / arg-count**, NOT the argument values.
- **printf#1 vs #2 delta = arg count (1 → 3)**: the 3-arg path builds a larger
  `[]interface{}` varargs slice + iterates it in fmt. Higher register pressure →
  **fits the x86_64 spill-pressure hypothesis** (4 allocatable GPRs). Build-mode-
  independent (Debug + ReleaseFast both repro) → deterministic codegen defect.

## Next probe (campaign step 2)

Find the guest function that builds printf#2's varargs slice / runs the fmt
verb-scan, and trace its computed slice-LENGTH or loop-counter jit-vs-interp
(a wrong length/counter makes fmt see "extra" args). The miscompiled value is a
scalar (length/index) produced under the heavier 3-arg frame. See D-489.
