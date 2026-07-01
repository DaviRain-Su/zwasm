# windowsmini tool updates: registry PATH is durable, but sshd caches it until reboot

**Date**: 2026-06-14 · **Context**: user directive to keep all hosts' tools current.
windowsmini (native, no nix) tools updated via `scripts/windows/install_tools.ps1`.

## Observation

Two distinct gotchas surfaced updating windowsmini's native toolchain (wasmtime
42→45, wasm-tools 1.246→1.251, +wasmer 7.1):

1. **`Update-UserPath` only appended** — a version bump created the new
   `<name>-<newver>` stamped dir and added it to User PATH, but the old
   `<name>-<oldver>` entry kept its EARLIER PATH position and won the `where
   <tool>` lookup. The bump silently had no effect. Fix: `Remove-StalePathEntries`
   drops every User-PATH entry under `zwasm-tools\` whose stamped leaf is
   `<name>-*` (for each tool being installed) BEFORE re-adding the current one.

2. **Windows OpenSSH sshd caches its environment.** After `install_tools.ps1`
   wrote the corrected User PATH (verified via `reg query HKCU\Environment /v
   Path` — the registry was correct: `wasmtime-45.0.0`, stale `42.0.1` gone), a
   FRESH ssh session STILL resolved wasmtime 42. The sshd service spawns login
   shells inheriting the SERVICE's cached environment block, not a fresh
   per-login registry read. New ssh sessions (incl. the gate) see the change
   only after **windowsmini reboots** (or sshd restarts).

## Rule

1. **Verify a windows tool update by absolute path, not `<tool> --version`** on a
   fresh ssh session: `%LOCALAPPDATA%\zwasm-tools\<name>-<ver>\<tool>.exe
   --version`. The PATH-resolved version lags until reboot; the absolute path
   proves the install is good.
2. **Don't autonomously `Restart-Service sshd` over ssh** to force activation —
   the restart process is a child of the ssh session and is KILLED when sshd
   stops (stop-but-not-start = bricked channel). Safe detached restart needs
   admin + a scheduled task. The registry state is durable; recommend a **reboot**
   for activation (the gate keeps working on the prior tool version meanwhile —
   e.g. the realworld diff still MATCHED under wasmtime 42).
3. Read windows User PATH with `reg query HKCU\Environment /v Path` (cmd) — the
   `[Environment]::GetEnvironmentVariable(...)` PowerShell form mangles under
   ssh→PowerShell double-quote escaping (see windowsmini-ssh-quoting-traps).
