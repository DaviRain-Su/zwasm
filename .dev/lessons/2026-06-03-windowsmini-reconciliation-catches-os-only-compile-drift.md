# windowsmini runs rarely → OS-only test-compile drift accumulates silently

**Date**: 2026-06-03 · **Context**: §11.P close — first windowsmini `test-all` since §11.1

## Observation

windowsmini is the **phase-boundary** host (ADR-0067 / D-134); per the skip policy the
autonomous `/continue` loop does NOT run it per-chunk. So it can go many commits / a whole
phase between runs. The §11.P reconciliation (first windowsmini run since the §11.1 file-I/O
work landed) immediately surfaced a **Windows-only test-build compile error** that Mac +
ubuntunote had been green on the whole time:

```
src/wasi/fd.zig:844: error: expected type '*anyopaque', found 'comptime_int'
  (calling addPreopen(host_fd: std.posix.fd_t, ...))
```

Root cause: **`std.posix.fd_t` is `i32` on POSIX but `*anyopaque` (a HANDLE) on Windows.** A
test wrote `addPreopen(99, ...)` — `99` (comptime_int) coerces to `i32` on Mac/Linux but NOT
to `*anyopaque` on Windows. The Mac/Linux test builds were green; the Windows test build
never compiled it until windowsmini ran. (The Windows *realworld run* itself PASSed — it was
purely the unit-test build.)

## Rule

- **A test that mentions a platform-divergent std type — `std.posix.fd_t`, `std.Io.File.Handle`,
  `std.posix.socket_t`, pointer-vs-int handles — must use a TYPED binding, never a bare
  literal.** `const fake_fd: std.posix.fd_t = undefined;` compiles on every OS; `99` only
  compiles where `fd_t` is an int. (Here the handle was "opaque to the call" — stored, never
  derefed — so `undefined` is correct.)
- **windowsmini drift is structural, not incidental.** Because it runs only at phase
  boundaries, EVERY OS-conditional bug (compile or runtime) since the last run lands at once.
  Budget the phase-close windowsmini batch to *find + fix* drift, not just to confirm green —
  the first run after a feature phase will usually surface ≥1 Windows-only issue.
- **Cross-compiling the LIB (`zig build -Dtarget=x86_64-windows-gnu`) does NOT catch this** —
  it builds the exe/lib, not the test blocks. To compile-check Windows tests locally:
  `zig build test -Dtarget=x86_64-windows-gnu`; the "host unable to execute … x86_64-windows"
  run error means the COMPILE passed (only the run-on-Mac step fails, which is expected).

## Production-code facet (2026-06-05, D-278 fd_datasync, `42e99737`)

Same root cause, NON-test side: a WASI handler called `std.posix.fdatasync(handle)`. Even
with a correctly-typed `fd_t`, the **`std.posix` fd-FUNCTIONS hardcode the POSIX `c_int` fd
ABI** — `fn fdatasync(fd: c_int)` — so a Windows HANDLE (`*anyopaque`) is rejected at the
call (`expected c_int, found *anyopaque`). Mac/ubuntu green; windowsmini build broke
(`zwasm-zig-facade-runner Debug native 1 errors`).

- **Rule: in production host code, prefer the cross-platform `std.Io.File` / `std.Io` wrappers
  over `std.posix.<fd_call>`.** `File.sync(io)` works on every OS; `std.posix.fdatasync/fsync/
  pread/...` assume POSIX int fds. (Fix: route `fd_datasync` through `File.sync` — datasync only
  *permits* skipping metadata, so a full sync is conformant.)
- **Unlike the test-literal case above, the LIB cross-compile DOES catch this**: `zig build
  -Dtarget=x86_64-windows-gnu` (seconds) would have caught it pre-push. **Run it before any push
  that touches platform-typed code (`src/wasi/`, `src/platform/`, anything using `std.posix`).**
  This push skipped it → a wasted windowsmini round-trip. (Memory `feedback_platform_gap_handling`.)

Related axis: [[2026-06-03-jitinstance-test-compiles-for-host-arch]] (arch-divergent test
emit — same family: a test green on one host/target, red on another, caught only when that
target actually builds/runs the tests).
