# Session handover

> ≤ 100 lines (soft) / 120 (hard). Canonical fresh-session entry point. Framing:
> [`handover_doc_discipline.md`](../.claude/rules/handover_doc_discipline.md).

## ACTIVE AGENDA (user-directed 2026-06-14) — real-world toolchain/bench reproduction

**Just closed**: **D-238 (x86_64 cross-instance EH on JIT parity) CLOSED** `c534afca`
(ADR-0185 Implemented; functional proof = `ZWASM_SPEC_ENGINE=jit` x86_64
exception-handling `34/0/0`; 3-host test-all green). **cljw guest-wasm RETIRED**
`02ef14b0` (user decision — cw won't emit wasm; cljw tests zwasm consumer-side).
Project is feature-complete + 3-host green + tag-ready (**tag = USER-ONLY, ADR-0156**).

**The agenda — drive via `/continue`. Authoritative plan (ordering + 2026 language
scope + the live JIT-trap inventory):**
[`realworld_reproduction_plan.md`](realworld_reproduction_plan.md) — its work sequence
supersedes ROADMAP §9 for these tasks. **User ordering: Phase A QUICK → Phase B
SUSTAINED**; the user assists when a toolchain needs installing.

- **Phase A — reproduction infra (QUICK; get it working)**:
  - **A1 (Zig half DONE `5c044967`)**: `zig_{hello,fib,prime_sieve}` wasm32-wasi added;
    interp 53/53, byte-diff 53/53 vs wasmtime, JIT-clean (+ fixed a diff_runner green-path
    flush bug `6995bbd3`). **AssemblyScript + WasmGC (Kotlin/Wasm/Dart) → D-324** (need
    `asc`/SDK provisioning + a call-export harness; AS dropped WASI).
  - **A2 (autonomous, NEXT)**: **embenchen** (emcc in `.#gen`) — the classic Emscripten
    bench; the find = the emscripten env-stub host-import gap (D-026/D-082).
  - **A3 (DONE `897b54d7`)**: **3-way differential** — opt-in `--wasmer` second-oracle
    lane (`zig build test-realworld-diff-wasmer`) vs wasmtime; REF-DISAGREE flags the
    divergence a single-reference gate misses. argv[0] CLI convention normalized.
    **Runtimes bumped to latest `074a885f`** (wasmtime 43→**45.0.0**, wasmer 5.0.4→**7.1.0**
    via nixpkgs 06-10): re-validated — zwasm == wasmtime45 == wasmer7.1 on 53/53, **0
    divergence** across a 2-major bump (lesson `reference-runtime-bump-divergence-capture`).
  - **A4 (user-assisted)**: remote provisioning — **D-254** (native rust on ubuntu +
    windows → 3-host rust differential; user chose (a)) + **D-249** (hyperfine on win).
- **Phase B — deep JIT bug-hunt (SUSTAINED; settle in)**:
  - **B1 = D-283**: triage + fix the live JIT signal (run `ZWASM_JIT_RUN=1` corpus:
    interp 55/55 but **JIT 35 pass / 11 trap / 9 compile-gap**). cljw-excluded set:
    **6 RUN-TRAP** (`tinygo_{fib,hello,json,sort}`, `rust_file_io`, `c_sha256_hash` —
    interp-passes ⇒ JIT miscompile / WASI-gap) + **9 COMPILE-OP** (ALL `go_*` —
    `UnsupportedOp` ⇒ unimplemented JIT op). Root-cause each cluster, fix, add boundary
    fixtures, enable `ZWASM_JIT_RUN=1` by default for the runnable set. Multi-cycle.

**Tool currency (user directive 2026-06-14) DONE+VERIFIED on ALL 3 hosts**: Mac+ubuntu via
flake (wasmtime 45, wasmer 7.1, nixpkgs 06-10, rust/zig-overlay 06-14; **zig PINNED 0.16.0**;
ubuntu gate green `fa0381cd`). windowsmini native via `install_tools.ps1` (wasmtime 45/
wasm-tools 1.251/+wasmer 7.1) — user REBOOTED 2026-06-14, verified ACTIVE (post-reboot ssh:
wasmtime 45.0.0/wasm-tools 1.251.0/wasmer 7.1.0/zig 0.16.0). windows gate re-validating with
wasmtime 45 (verify next Step 0.7). D-249 hyperfine-absent premise dissolved.

**A2 embenchen DONE `1aac480f`**: 3 benchmarks (fannkuch/fasta/primes) reproduced via MODERN
emcc `-sSTANDALONE_WASM`→WASI (NOT the legacy env-shim ABI of the vendored `embenchen_*`
fixtures, which stay Phase-11/D-026). The find: modern path Just Works — zwasm runs all 3
byte-identical to wasmtime under its existing WASI host, no shim. realworld_run 56/56, diff
56/56. windows gate green on the new wasmtime 45 toolchain (recorded 3bc17f04).

**Phase B / B1 = D-283 — JIT-DIFF LANE LANDED `219dbd17`.** `zig build test-realworld-diff-jit`
(WASI-aware `runWasmJitCaptured` + byte-diff vs wasmtime). Real signal replacing the false
12-trap framing: **`diff_runner [jit]: 45/56 matched, 2 mismatched, 9 skipped`**. The truth: 45
JIT-correct, 2 genuine miscompiles, 9 `go_*` compile-gaps. B1 bundle CLOSED (lane = the deliverable).

## Active bundle

- **Bundle-ID**: B2-D283-jit-miscompiles
- **Cycles-remaining**: ~3
- **Continuity-memo**: (INVESTIGATION cycle-1 done; cycle-2 = disassembly) 2 deterministic
  **CODEGEN** miscompiles (CONFIRMED codegen, not harness: the `--aot` lane mismatches IDENTICALLY
  — c_sha256_hash→91B, emcc_fasta→87B, same bytes as `--jit`; JIT+AOT share `compileWasm`, interp
  is correct). Precise localization (output diff vs interp):
  · **c_sha256_hash** `printf("input: %%s\n", input)` (sha256_hash.c:115) prints `input: ` then
    DROPS the `%%s` string + `\n` (16 bytes). BUT the SAME `input` ptr hashes correctly (line 112,
    strlen+loop) AND `printf("%%02x", hash[i])` (int vararg, line 118) prints correctly.
  · **emcc_fasta** `printf("%%c:%%d ", syms[j], counts[j])` (fasta.c:37): `%%c` (1st vararg) CORRECT,
    `%%d` (2nd vararg counts[j]) prints **0** for all — yet `%%lu` checksum (line 36) is correct.
  **CYCLE-2 ISOLATED (`private/spikes/jit-vararg/`)**: the bug is **plain `%s` (no precision)**.
  `printf("%s\n","hi")` → JIT empty + drops `\n`. REJECTED: H1 varargs (`%c %d %lu` 1–4 args ok),
  H2 array-store (`arr[i]++`→ok), AND `%.2s` (precision) → CORRECT, `fputs`/`puts` ok, standalone
  `strnlen(s,0x7FFFFFFF)`/`memchr(...,0x7FFFFFFF)` ok. CYCLE-2.5: a hand-written SWAR word-scan
  (`swar.c`) compiled -O2 RUNS CORRECT under --jit → generic SWAR is NOT the bug. Refined: the SAME
  vfprintf runs for `%.2s` (works) and `%s` (broken), differing only in precision (2 vs -1→PTRDIFF_MAX),
  so it is a **VALUE-DEPENDENT miscompile** on musl's actual `%s` path — an op wrong only for the
  -1/PTRDIFF_MAX-derived value (signed-cmp / select / shift on a large/neg i32?). Needs real-vfprintf
  disasm (debug_jit_auto), NOT a hand-rolled idiom. Separately: 9 `go_*` UnsupportedOp
  compile-gaps = debt-tracked op backlog (per-op, predicate clear).
- **Exit-condition**: both `c_sha256_hash` + `emcc_fasta` flip to MATCH in `test-realworld-diff-jit`
  (jit mismatched → 0); each fix carries a boundary fixture + a lesson on the miscompiled op/pattern.

**First action on resume**: B2 cycle-3 — `debug_jit_auto` disassemble the inlined-`strnlen` SWAR
word-scan in the plain-`%s` path (repro: `private/spikes/jit-vararg/repro2.wasm`, lines 1/2 drop
under --jit). Find the miscompiled i32 op in `(w-0x01010101)&~w&0x80808080`; OR reduce to a
hand-written word-scan `.wat`. On fix: boundary fixture + lesson. (A1 Zig + A2 embenchen + A3
wasmer-oracle + runtime-bump + tool-currency-3host + B1 jit-diff-lane all DONE; B2 cycle-2 isolated
plain-`%s`/inlined-SWAR — see Active bundle + spike README.)

## State (tag-ready baseline, all 3-host green)

- **Wasm 1.0/2.0/3.0**: 100% spec, 0 skip. **WASI 0.1** complete; **0.2/CM**
  default-ON (ADR-0182/0183; corpus 158/0/0). Sandboxing triad everywhere.
- **Surfaces**: C-API 293/293 (+preopen_dir/inherit_env, ADR-0184) · Zig-API
  complete (+`WasiConfig.{envs,preopens,io}` — full WASI parity) · lean CLI ·
  memory-safety sound · dogfooded into cw (consumer-side). Runners ReleaseSafe (ADR-0177,
  Rev 2026-06-14 floored `core_comp` too; `check_releasesafe_runners.sh` guards it).
- **EH**: cross-instance exception-handling on JIT works on BOTH arches (arm64 `4f73d9ee`
  + x86_64 D-238/ADR-0185 `c534afca`). Interp + JIT EH spec corpus green.
- **Debt**: 43 entries, **zero `now`**; all blocked-by are external (upstream
  Zig / hosts) / future-phase (11/12/14) / user-gated, or `note`/`partial` long-tail.
  D-283 (realworld-under-JIT) is the Phase-B anchor. D-026/D-082 (embenchen) feed Phase A.
- **Realworld corpus**: 50 fixtures (c/cpp/rust/tinygo/go), interp 50/50; JIT run-stage
  opt-in (`ZWASM_JIT_RUN=1`) — the Phase-B signal source. cljw fixtures retired.
- **Tag**: `v2.0.0-alpha.3` tag-only (no Release → Latest stays v1.11.0), USER-ONLY.

## Key refs

- [`realworld_reproduction_plan.md`](realworld_reproduction_plan.md) — the ACTIVE
  AGENDA's full plan. [`flake.nix`](../flake.nix) `devShells.gen` — fixture toolchains.
- [`docs/zig_api_design.md`](../docs/zig_api_design.md) · **ADR-0185** (x86_64 EH
  frame-walk) · **0177** (ReleaseSafe runners) · **0156** (NO autonomous release) ·
  **0153** (rework) · **0109** (Linker/facade API).
- lessons [`releasesafe-runner-floor-audit`] · [`global-predicate-cannot-replace-local-codemap`].
