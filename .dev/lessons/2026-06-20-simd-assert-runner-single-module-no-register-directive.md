# simd_assert_runner is single-module → wast `(register …)` is the one legit residual skip

**Context**: D-467 unskipped the entire simd invoke-boundary gap (271 → 1
`skip-impl`). The lone survivor is `skip-impl directive-register` in
`simd_linking/manifest.txt`.

**Observation**: `simd_assert_runner.zig` compiles + invokes ONE module per
assert (one `CompiledWasm`, one shared `growable_memory` / scratch-globals
pool). The wast `(register "name" $module)` directive binds a prior module
instance under an import name so a *later* module can import from it
(cross-module linking). The single-module JIT runner has no multi-module
instance registry, so the distiller emits `skip-impl directive-register`
rather than a live assert. This is a genuine wast-feature limit, not an
entry.zig marshalling gap — every v128 *call-boundary* shape (splat,
multi-scalar constructor, load/store-lane, extract/replace-lane) is now live.

**Rule**: a `directive-register` skip in the simd corpus is correct residue;
don't try to "fix" it by widening entry.zig. Modelling it would need a
multi-module instance registry in the assert runner (out of scope for the
single-module spec-assert harness; the full `.wast` linking suite is covered
by the dedicated multi-module runners).

Discharge commit: `feat(p17): D-467 unskip load/store-lane …`.
