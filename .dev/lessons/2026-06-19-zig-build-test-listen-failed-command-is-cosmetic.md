# `zig build test` prints "failed command: …--listen=-" but exits 0

**Observation.** `zig build test` (and `test-all`) routinely prints

```
+- run test w
x
failed command: ./.zig-cache/o/<hash>/test --cache-dir=… --seed=… --listen=-
```

yet the **process exit code is 0** (verified: `zig build test; echo $?` → 0
with that line present). The tests all passed; the line is a Zig build-runner
quirk of the `--listen=-` test protocol, not a failure.

**Why it kept biting.** Step 0.7 (`tail /tmp/ubuntu.log` / `/tmp/win.log`) shows
this "failed command" line on ALL three hosts and locally. Read literally it
looks like a red gate, and it triggered repeated investigation across turns
(is it a real x86_64/Win64 unit failure? a regression from my diff?). It is
none of those — it's printed on SUCCESS too.

**Rules.**
1. "failed command: …test…--listen=-" in a `test`/`test-all` log is NOT a
   failure signal by itself. The reliable signals are: the **exit-code-based**
   `[run_remote_*] OK|FAIL` terminal line, and the per-suite `N passed, 0 failed`
   summaries. A genuine test failure ALSO prints a NAMED failing test
   (`FAIL <name>` / an assertion / a panic with a test name) before the line —
   grep for that, not the bare "failed command".
2. To check a real unit-test verdict directly, run the test binary itself
   (`./.zig-cache/o/<hash>/test`) — it prints `N passed; M skipped; K failed`.
   (Find the right one: multiple test binaries exist per `zig build`; the big
   suite is the one whose `strings` contains a known test name.)
3. Don't revert a commit pair on this line alone (D3 is about REAL ubuntu
   failures). Distinguish: crash signature (ntdll/0x7ff/SIGSEGV) or `Double free`
   or a named `FAIL` = real; bare "failed command …--listen=-" with green
   summaries = cosmetic.

Verified 2026-06-19 (`zig build test` REAL EXIT CODE = 0 with the line present).
