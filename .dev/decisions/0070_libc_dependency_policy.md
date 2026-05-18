# 0070 — libc dependency policy

- **Status**: Proposed
- **Date**: 2026-05-19
- **Author**: continue loop §9.12 substrate audit cycle
- **Tags**: phase-9, libc, dependency-boundary, posix, hygiene

## Context

The 2026-05-16 D-134 investigation (SIGSEGV recovery via `sigsetjmp` /
`siglongjmp`) surfaced a wider concern: zwasm v2's libc dependency surface
is under-managed. Phase 9 completion substrate audit (ADR-0062 §Q6) escalated
this to a formal decision gate. Concretely:

- **Zig 0.16 stdlib direction**: `std.posix.*` / `std.process.*` /
  `std.heap.*` / `std.Threaded` are explicitly designed to be
  buildable-without-libc. zwasm v2 is currently moving against this current —
  `flake.nix` + `build.zig` hard-require `-lc`, and signal handling fans
  through libc primitives.
- **Phase 10+ pressure**: AOT mode (Phase 12), embedded distribution
  (post-Phase-13), Windows-native compatibility (Phase 13+) each multiply the
  cost of carrying libc fanout. Unwinding the dependency post-Phase-10 is
  harder than gating new additions now.
- **Reference clone evidence**: wasmtime / wasmer / wasm3 each manage libc
  boundary explicitly; zwasm v1 did not (the substrate-audit retrospective
  marks this as one of v1's accumulated debts).

A full site inventory (`grep -rnE 'std\.c\.|@extern.*"c"|sigsetjmp|siglongjmp|
pthread_jit|sys_icache_invalidate' src/ test/ build.zig` plus DebugAllocator
scan) found **16 active call sites**, plus the `@extern(.{ .library_name = "c" })`
declarations for `sigsetjmp` / `siglongjmp` in
`test/spec/spec_assert_runner_base.zig`.

## Decision

Classify every `std.c.*` / `@extern("c")` / `pthread_*` / `sigsetjmp` / `siglongjmp`
call site in zwasm v2 into one of three categories, and gate new additions to
**necessary** behind ADR amendment.

### Categories — defined

| Category | Definition | Treatment |
|---|---|---|
| **necessary** | No Zig stdlib (`std.posix.*`, `std.process.*`, `std.heap.*`, `linux.*`) equivalent exists at Zig 0.16. Adding a Zig stdlib equivalent requires an upstream Zig issue / PR. | Retain; track upstream issue link in this ADR's "necessary watch list". New additions require ADR amendment. |
| **replaceable** | A clear `std.posix.*` / `std.process.*` equivalent exists at Zig 0.16. The migration is mechanical (drop-in symbol rename + small signature adjustments). | Migrate in §9.12-D sample-migration chunk OR debt-row-named follow-up. New additions are rejected by `scripts/check_libc_boundary.sh` unless ADR-justified. |
| **convenience** | Used only under Debug builds (e.g. `std.heap.DebugAllocator` requiring libc on Linux). Loss of the libc dependency would degrade development ergonomics without affecting Release semantics. | Permitted under Debug build only. Release-build libc fanout in this category is rejected. |

### Concrete inventory (2026-05-19 measurement)

#### Necessary set (6 unique symbols, ~8 sites)

| Symbol | Sites | Justification | Upstream watch |
|---|---|---|---|
| `pthread_jit_write_protect_np` | `src/platform/jit_mem.zig:144` (×2 calls — setExecutable / setWritable) | Darwin arm64 W^X toggle. POSIX has no equivalent; this is the canonical Apple-supplied API for JIT-with-hardened-runtime. | Zig stdlib has no plan to wrap; watch ziglang/zig for future Darwin JIT support. |
| `sys_icache_invalidate` | `src/platform/jit_mem.zig:145` | Darwin arm64 instruction cache invalidation. Cross-platform equivalent (`__builtin___clear_cache`) is Clang-builtin and not Zig-exposed. | Zig stdlib: track `@clearInstructionCache` builtin proposal. |
| `sigsetjmp` (linkage `@extern("c")`) | `test/spec/spec_assert_runner_base.zig:1826` | Signal-safe setjmp variant; glibc-mangled name. POSIX-mandated; no Zig stdlib equivalent. | Zig stdlib: no plan. Watch for builtin / std addition. |
| `siglongjmp` (linkage `@extern("c")`) | `test/spec/spec_assert_runner_base.zig:1834` | Signal-safe longjmp variant. Same as above. | Same as above. |
| `std.c.mmap` + `MAP` + `vm_prot_t` constants | `src/platform/jit_mem.zig:64-67` | Darwin `MAP_JIT` flag is required for arm64 hardened-runtime JIT. `std.posix.mmap` does not currently expose `MAP_JIT`. | Zig stdlib issue: file upstream for `MAP_JIT` constant. |
| `std.c.MAP_FAILED` | `src/platform/jit_mem.zig` (mmap return-value check) | Mmap sentinel. Tied to `std.c.mmap` use. | Resolved when `std.c.mmap` is replaced. |

#### Replaceable set (8 unique symbols, ~10 sites)

| Symbol | Sites | Migrate to | Migration note |
|---|---|---|---|
| `std.c.munmap` | `src/platform/jit_mem.zig:122` | `std.posix.munmap` | Drop-in. |
| `std.c.getenv` | `src/api/instance.zig:210` (`wasm_engine_new` C ABI export) | `std.process.getEnvVarOwned` / `std.process.Environ` | Zone 3 c_api entry; the env var read is one-shot at engine init. Care: c_api exports cannot easily allocate; provide a small POSIX-only `getenv` shim in `src/platform/env.zig`. |
| `std.c._exit` | `test/spec/spec_assert_runner_base.zig:2034` (signal handler) | `std.posix.exit` | Both are async-signal-safe. Trivial swap. |
| `std.c.pid_t` | `test/realworld/run_runner_jit.zig:91` | `std.posix.pid_t` | Type alias rename. |
| `std.c.kill` | `test/realworld/run_runner_jit.zig:101` | `std.posix.kill` | Async-signal-safe context preserved. |
| `std.c.fork` | `test/realworld/run_runner_jit.zig:137` | `std.posix.fork` | Drop-in. |
| `std.c.alarm` | `test/realworld/run_runner_jit.zig:165` | `std.posix.alarm` | Fixture-timeout signal handler; preserves behaviour. |
| `std.c.waitpid` | `test/realworld/run_runner_jit.zig:167` | `std.posix.waitpid` | Drop-in. |

Total replaceable sites: **10**. The §9.12-D sample-migration chunk converts
all 10 (sweep, not phased; 10 sites is a single-commit-sized cohort).

#### Convenience set (0 active sites)

`std.heap.DebugAllocator` is referenced in code comments at `src/engine/runner.zig:1943`
but is not an active call site (no `std.heap.DebugAllocator` instantiation in current
code). The convenience category is **declared but currently empty**; it exists to
absorb future Debug-only libc dependencies (e.g. if `std.heap.DebugAllocator` is
later selected on Linux Debug builds for leak detection).

### Enforcement

1. **`.claude/rules/libc_boundary.md`** — auto-load rule on `src/**/*.zig` editing.
   Codifies: before writing `std.c.<name>`, check `std.posix.<name>` /
   `std.process.<name>` first; cite this ADR; reviewer checklist for grep-able
   anti-patterns.
2. **`scripts/check_libc_boundary.sh`** — pre-commit gate. Greps for new
   `std.c.*` / `@extern("c")` / `pthread_*` sites and flags any that are not
   on this ADR's necessary list. Lands in §9.12-D.
3. **`audit_scaffolding §G.5` extension** — periodic audit that re-runs the
   grep against the active branch and reports drift against this ADR's
   inventory.
4. **ROADMAP §14 forbidden-list amendment** — add: "Unconscious libc fanout
   (new `std.c.*` calls without ADR justification or rule exception)" with
   cite to this ADR.
5. **§9.12-D sample-migration chunk** — converts the 10 replaceable sites in
   one commit; proves the rule has teeth.

## Alternatives considered

### Alternative A — Full libc-free build now (eliminate even the necessary set)

- **Sketch**: re-implement `sigsetjmp` / `siglongjmp` in inline assembly per
  target; replace `pthread_jit_write_protect_np` with a custom syscall wrapper;
  fork Zig stdlib to add `MAP_JIT`.
- **Why rejected**: the necessary set has no upstream-blessed Zig stdlib path
  *yet*. Re-implementing libc primitives in inline asm carries a substantial
  reliability risk (D-103 → D-134 lineage is already 3 distinct libc-bug
  cycles); the maintenance cost of forking Zig stdlib exceeds the value before
  Phase 13's Windows-native push makes it necessary. Defer to Phase 13.

### Alternative B — Keep current state; address libc fanout when Phase 12 / 13 demands

- **Sketch**: defer all libc-boundary work; let new `std.c.*` sites accumulate
  organically.
- **Why rejected**: every new site in Phase 10's GC / EH / tail-call / memory64
  implementation work is a new dependency to unwind in Phase 12. Phase 10's
  per-op file pattern (per ADR-0073) makes the rule's enforcement cheap —
  one file = one review point. Deferring loses the cheap enforcement window.

### Alternative C — Convenience category absorbs DebugAllocator now (proactive)

- **Sketch**: introduce `std.heap.DebugAllocator` in Debug builds across
  `src/engine/runner.zig` to gain leak-detection coverage; ADR-justify it as
  a convenience-category libc dependency.
- **Why deferred (not rejected)**: leak-detection coverage is a Phase 9b /
  Phase 11 concern; this ADR's scope is the dependency boundary itself.
  DebugAllocator adoption is a separate ADR if pursued.

### Alternative D — Per-target libc policy (Darwin allows more; Linux strict)

- **Sketch**: relax the necessary-set criterion on Darwin (where Apple's
  libc is the stable API surface) while keeping Linux strict (where `linux.*`
  syscall wrappers are preferable).
- **Why rejected**: cross-target consistency outweighs the small Darwin-only
  benefit. The necessary-set already names Darwin-specific symbols
  (`pthread_jit_write_protect_np`) without diluting the policy.

## Consequences

### Positive

- **Phase 12 AOT readiness**: AOT-mode binaries can be built with a minimal
  libc footprint; every `std.c.*` site is either justified or migrated.
- **Phase 13 Windows-native readiness**: `sigsetjmp` / `siglongjmp` are the
  only POSIX-specific dependencies that remain after §9.12-D; the Windows
  port writes a single SEH-shim file rather than touching N call sites.
- **Drift is caught at commit time**: `scripts/check_libc_boundary.sh` fires
  on PR; new sites surface in review, not at AOT-build time.
- **Inventory is concrete + tracked**: this ADR's tables are the single
  source of truth; audit can compare against grep output deterministically.

### Negative

- **§9.12-D adds 10 call-site migrations** to the §9.12 cohort; this is
  ~1 chunk of work.
- **`pthread_jit_write_protect_np` ties zwasm to Apple's hardened-runtime
  policy** — if Apple deprecates the API, the necessary watch list must
  re-open. Mitigation: maintain an upstream-watching note in this ADR.

### Neutral / follow-ups

- File the upstream Zig issue / PR for `MAP_JIT` in `std.posix.mmap` (a
  small, well-scoped contribution; track in a `private/notes/` followup).
- The convenience category has 0 active sites today; the policy slot is
  pre-declared for future use.
- A separate `.claude/rules/libc_boundary.md` skeleton already exists; it
  is filled in during §9.12-D.

## References

- ROADMAP §14 (forbidden list amendment to be added by §9.12-D commit), §11
  layers.
- ADR-0067 (ubuntunote host pivot; D-134 Rosetta) — one origin of libc
  reliability concerns.
- ADR-0071 (Phase 9 substrate audit resolution; Q6 referent).
- `.dev/phase9_completion_substrate_audit.md` §Q6.
- D-134 lineage (D-103 → d-29 → d-62 → d-65); the signal-recovery story
  driving the necessary set.
- Inventory survey: 2026-05-19 grep-based site enumeration (this ADR's
  tables are the captured result).

## Revision history

| Date       | SHA          | Note                                                          |
|------------|--------------|---------------------------------------------------------------|
| 2026-05-19 | `<backfill>` | Initial draft — Q6 deliverable with full inventory + 3-category policy. |
