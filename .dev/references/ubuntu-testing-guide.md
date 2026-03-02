# Ubuntu x86_64 Testing Guide (OrbStack)

How to run zwasm tests on the local OrbStack Ubuntu x86_64 VM.

## Connection

```bash
# Interactive shell
orb shell my-ubuntu-amd64

# One-shot command (used by Claude Code)
orb run -m my-ubuntu-amd64 bash -lc "COMMAND"
```

Claude Code uses stateless one-shot execution — each `orb run` starts a fresh shell.
Always use `bash -lc` to load `.bashrc` (PATH for zig, wasmtime, etc.).

## Sync Project

Rsync from Mac filesystem to VM-local storage for build performance:

```bash
orb run -m my-ubuntu-amd64 bash -lc "
  rsync -a --delete \
    --exclude='.zig-cache' --exclude='zig-out' \
    '/Users/shota.508/Documents/MyProducts/zwasm/' ~/zwasm/
"
```

Run sync before each test session to pick up latest changes.

## Test Commands

All commands run inside the VM at `~/zwasm/`:

```bash
# Unit tests
orb run -m my-ubuntu-amd64 bash -lc "cd ~/zwasm && zig build test"

# Spec tests (62,263 tests, ~2 min)
orb run -m my-ubuntu-amd64 bash -lc "cd ~/zwasm && python3 test/spec/run_spec.py --build --summary"

# E2E tests (792 tests)
orb run -m my-ubuntu-amd64 bash -lc "cd ~/zwasm && bash test/e2e/run_e2e.sh --convert --summary"

# Real-world compat (30 programs)
# Requires building wasm files first:
orb run -m my-ubuntu-amd64 bash -lc "cd ~/zwasm && export WASI_SDK_PATH=/opt/wasi-sdk && bash test/realworld/build_all.sh"
orb run -m my-ubuntu-amd64 bash -lc "cd ~/zwasm && bash test/realworld/run_compat.sh --verbose"

# Benchmarks
orb run -m my-ubuntu-amd64 bash -lc "cd ~/zwasm && bash bench/run_bench.sh --quick"
```

## Expected Results (Merge Gate)

| Suite      | Expectation                       |
| ---------- | --------------------------------- |
| Unit tests | all pass, 0 fail, 0 leak         |
| Spec tests | 62,263/62,263 (100%), 0 skip      |
| E2E        | 792/792, 0 fail, 0 leak          |
| Real-world | PASS=30, FAIL=0, CRASH=0         |
| Benchmarks | no regression vs Mac baseline     |

## Known Issues

- **Debug builds**: 11 tail-call tests timeout on Ubuntu (Rosetta overhead).
  Use ReleaseSafe for spec tests (the test scripts handle this automatically).
- **Long-running output**: SSH/orb run output can be slow/buffered.
  For long tests, launch in background and check periodically.
