# D-285 — JIT bulk-memory byte-loop codegen (phase-I investigation)

> **Doc-state**: ACTIVE — investigation findings for the D-285 fix.

Triggered by the ADR-0163 A all-engine matrix (2026-06-05): `shootout/memmove`
zwasm-jit (254 ms) is **slower than zwasm-interp** (138 ms) and ~15× wasmtime
(17 ms); `shootout/base64` zwasm-jit ~13× wasmtime — both far past the typical
1.5–3.9× single-pass-vs-optimizer gap.

## Mechanism (confirmed, both backends)

The JIT lowers `memory.copy` as a **byte-at-a-time loop**:

- **arm64** (`src/engine/codegen/arm64/op_memory.zig:670-680`): `.fwd_loop`
  `LDRB W15,[X16]; STRB W15,[X17]; ADD X17,#1; ADD X16,#1; SUB X14,#1; CBNZ`.
  One byte / iteration / ~6 instructions. Backward path (`:638-648`) identical.
- **x86_64** (`src/engine/codegen/x86_64/op_memory.zig:724-734`): `.fwd_loop`
  `MOVZX r11,byte[rdx+rax]; MOV byte[rcx+rax],r11b; ADD rcx,1; ADD rdx,1;
  ADD r10,-1; JNZ`. Same shape.

The **interpreter** uses `std.mem.copyForwards` / `copyBackwards`
(`src/instruction/wasm_2_0/bulk_memory.zig:75-77`) — element copies the Zig
optimizer can auto-vectorize. So on large copies the interp's vectorized copy
**beats** the JIT's scalar byte loop, producing the jit-slower-than-interp
paradox. wasmtime lowers `memory.copy` to a native `memmove` libcall → 17 ms.

`memmove.wasm`'s hot loop (func 12) calls `memory.copy` twice per iteration; the
workload is bulk-memory-bound, so the byte loop dominates wall-clock.

## Blast radius

- `memory.copy` on **both** backends (the two files above).
- **Likely the same** for `memory.fill` and `memory.init` (same emit family,
  `op_memory.zig`) — VERIFY in phase II, fix together if so.
- Any bulk-memory-heavy workload: memmove, base64 (uses copy/fill), realistic
  WASI programs doing buffer I/O / string ops.
- **NOT** affected: SIMD, scalar compute, control flow (the 1.5–3.9× there is
  the genuine single-pass trade, unrelated).

## Second finding — bench built ReleaseSafe (separate, fix first)

`scripts/run_bench.sh:201` builds zwasm **ReleaseSafe**, while the comparators
are release-optimized. This unfairly penalizes zwasm's interp loop + JIT-compile
(startup) — independent of D-285 (the JIT-emitted byte loop is the same machine
code either way, so jit *steady-state* barely moves, but interp + startup do).
The published all-engine matrix numbers therefore overstate zwasm's compute gap
and understate its startup win. **Fix run_bench to ReleaseFast (the fair,
s15p-aligned basis) before re-measuring.**

## ROI estimate

- memmove ~254 → target ≤ interp (138), realistically ~20–40 ms with a word-wise
  (8-byte) loop + byte tail → **6–12× on that fixture**; base64 similar.
- A JIT slower than its own interpreter is the embarrassing case this closes.
- Scope is small (2 emit fns, + fill/init if shared) → this is a **normal bounded
  TDD fix, NOT an ADR-0153 multi-phase campaign**.

## Fix options

1. **Word-wise loop + byte tail** (self-contained, recommended first): copy
   8 bytes/iter (`LDR/STR X` arm64; `MOV r64` x86_64) while `n >= 8`, then a
   byte tail for `n % 8`. Reuses the existing bounds-check + forward/backward
   direction logic untouched; only the inner loop changes. Backward path copies
   the high word-aligned tail-first. No new ABI / helper-call surface.
2. **Runtime memmove helper call** (what Cranelift does): emit a call to a host
   `memmove`. Fastest (native, SIMD-width) but needs a JIT→host call ABI for the
   helper + a libc-boundary review (ADR-0070). Heavier; defer unless (1) is
   insufficient.
3. `rep movsb` (x86) / arch DC ZVA (arm64): arch-specific, microarch-dependent;
   not portable across the two backends. Reject.

**Decision (phase III seed)**: option (1). Self-contained, both-backend-uniform,
no ABI/libc surface, stays within the single-pass no-optimizing-tier principle
(§1.3 — this is correct lowering of one op, not an optimizer). Correctness gate
(phase II): overlap (fwd/bwd), n=0, n<8, unaligned src/dst, exact-multiple-of-8,
1-byte, full-memory-span; adversarial overlap-by-1.

## Results (2026-06-05) — copy FIXED both backends

Word-wise lowering landed: arm64 (`4e6d17fc`) + x86_64 (`838de5a1`). memmove
zwasm-jit **254 → 38 ms (6.6×)** — now BEATS interp (141 ms; paradox resolved)
and is 2.3× wasmtime (was 15×), within the normal single-pass trade. Validated:
5 adversarial overlap/tail/word fixtures + 82 edge cases + spec `memory_copy.wast`
under `ZWASM_SPEC_ENGINE=jit` + full `zig build test`, green on arm64 (native) AND
x86_64 (Rosetta); cross-compiles clean for x86_64-linux.

**base64 RE-ATTRIBUTED — NOT a D-285 bug.** Post-copy-fix, base64 zwasm-jit was
unchanged (770 → 782 ms): its hot loop is 6-bit-grouping + table-lookup byte
processing, not `memory.copy`. The ~13× vs wasmtime is the **genuine single-pass-
vs-optimizer gap** (Cranelift vectorizes byte-shuffling; zwasm's single-pass JIT
does not), i.e. the §1.3 designed trade amplified for this workload class — not a
codegen defect. The docs' earlier "base64 = D-285 anomaly" framing is corrected.

**`memory.fill` + `memory.init` carry the SAME byte-loop pattern** (arm64
`op_memory.zig:538` / `:828`, x86_64 likewise) — same defect class, lower bench
impact (memmove improved 6.6× without them). Filed **D-286** as the follow-on
(fill needs a byte→word splat; init mirrors copy directly).

## Reproduction

```sh
nix develop .#bench --command \
  bash scripts/run_bench.sh --bench=shootout/memmove --engines=interp,jit,aot --compare=wasmtime
```
