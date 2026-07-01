# Cross-compile the TESTS for windows before de-skipping windows paths

`zig build -Dtarget=x86_64-windows-gnu` builds only the binaries — test
blocks are NOT analyzed for the target. Removing a comptime
`if (windows) return skip...` guard exposes the remainder of the test
body to windows semantic analysis for the first time; any
posix-only construct in it (here: `std.posix.POLL`, which on windows
resolves through std.c to a `ws2_32.POLL` that does not exist in pinned
0.16) becomes a NATIVE-windows compile error that the binary
cross-compile cannot see.

Cheap gate that catches it from the Mac:
`zig build test -Dtarget=x86_64-windows-gnu` — compile errors surface
before the (expected, harmless) "unable to execute binaries from the
target" spawn failures. Run it whenever a diff removes a windows skip
or adds windows-reachable test code.

Observed: ADR-0180 Phase-2 impl-4 (8c0bb8f1) removed the D-319 skips;
the next windowsmini batch went red on the test compile while all 47
runnable suites were green. Fix: tests use the module's comptime-gated
POLL_IN/POLL_OUT, never raw `posix.POLL.*` (1e62...).
