#!/usr/bin/env python3
"""zwasm-JIT vs wasmtime differential — a SIMD-aware exec oracle.

The interp-vs-JIT exec-fuzz (`test/fuzz/fuzz_exec.zig`) uses the interp as its
oracle, but the interp is NON-SIMD (JIT-only SIMD, by design). So JIT SIMD
codegen has no in-tree differential oracle. wasmtime supports SIMD, so this
runs each 0-param scalar-result export under BOTH `zwasm run --engine jit` and
`wasmtime run` and compares the value / trap.

USAGE: `python3 scripts/fuzz_wasmtime_diff.py <corpus-dir>`  (needs wasmtime +
wasm-tools on PATH — both in `nix develop .#gen`). Pass a dir of `.wasm`.

KNOWN LIMITATION (verified 2026-06-20, lesson `wasmtime-jit-differential-wrapper-
blocked`): `compileWasm` compiles the WHOLE module, and the host-invoke
`wrapper_thunk` (ADR-0106) only supports a SUBSET of function signatures
(0/1/3-param, results all-GPR or all-XMM). A `wasm-tools smith` module almost
always contains at least one function with an unsupported sig (f32/v128 result,
2/4+ params), so the whole module returns `UnsupportedOp` and NO export is
invokable — this tool reports `compared=0` on raw smith corpora. It works on
CURATED corpora whose every function has a wrapper-supported sig (e.g.
`test/fuzz/corpus/exec_seed/` → compared=6, 0 mismatch). To use it for SIMD
fuzzing, either broaden `wrapper_thunk` or hand-curate wrapper-friendly modules.
The JIT SIMD body codegen itself is verified correct (matches wasmtime on
wrapper-friendly funcs; simd_assert 25075/0).
"""
import subprocess, glob, re, sys, struct, math, os, shutil


def find_zwasm():
    hits = glob.glob(".zig-cache/o/*/zwasm")
    if not hits:
        sys.exit("zwasm binary not built — run `zig build` first")
    return max(hits, key=os.path.getmtime)


def inv(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return (r.returncode, r.stdout.strip(), r.stderr.strip())
    except Exception:
        return (-1, "", "<timeout>")


def norm(s):
    s = s.strip().splitlines()[-1] if s.strip() else ""
    if re.fullmatch(r"-?\d+", s):
        return ("i", int(s))
    try:
        f = float(s)
        return ("f", "nan" if math.isnan(f) else struct.pack("<d", f).hex())
    except Exception:
        return None


def main():
    corpus = sys.argv[1] if len(sys.argv) > 1 else "test/fuzz/corpus/exec_seed"
    if not shutil.which("wasmtime") or not shutil.which("wasm-tools"):
        sys.exit("need wasmtime + wasm-tools on PATH (nix develop .#gen)")
    zwasm = find_zwasm()
    compared = mism = 0
    mm = []
    for f in sorted(glob.glob(corpus + "/*.wasm")):
        pr = subprocess.run(["wasm-tools", "print", f], capture_output=True, text=True).stdout
        for n in re.findall(r'\(export "([A-Za-z0-9_]+)" \(func', pr):
            wrc, wo, we = inv(["wasmtime", "run", "--invoke", n, f])
            zrc, zo, ze = inv([zwasm, "run", "--engine", "jit", "--invoke", n, f])
            if "unsupportedop" in (zo + ze).lower():
                continue  # wrapper_thunk sig limitation — not a divergence
            wl = (wo + we).lower()
            wt_trap = wrc != 0 or any(t in wl for t in ("trap", "unreachable", "out of bounds", "divide by zero"))
            zw_trap = zrc != 0 or "trap" in (zo + ze).lower()
            if wt_trap or zw_trap:
                if wt_trap != zw_trap:
                    compared += 1
                    mism += 1
                    mm.append(f"{os.path.basename(f)}::{n} TRAP-DIVERGE wt_trap={wt_trap} zw_trap={zw_trap}")
                continue
            nw, nz = norm(wo), norm(zo)
            if nw is None or nz is None:
                continue
            compared += 1
            if nw != nz:
                mism += 1
                mm.append(f"{os.path.basename(f)}::{n} wt={wo[-30:]!r} zw={zo[-30:]!r}")
    print(f"compared={compared} mismatch={mism}")
    for m in mm[:30]:
        print(m)
    sys.exit(1 if mism else 0)


if __name__ == "__main__":
    main()
