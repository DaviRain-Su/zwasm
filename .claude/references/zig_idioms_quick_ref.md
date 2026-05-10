Loaded on demand from `.claude/rules/zig_tips.md`; not auto-loaded.

# Zig 0.16 idioms — quick reference

Project-canonical idiom guide. See `zig_tips.md` (gate) for the
load-bearing summary; this file holds full examples + lint-gate
rationale per ADR-0009.

## Empty `catch`: `catch {}` is the only form Zig 0.16 accepts

```zig
something() catch |_| {};                // ERROR: discard of error capture; omit it instead
something() catch |err| { _ = err; };    // ERROR: error set is discarded
something() catch {};                    // OK
```

If `catch {}` is genuinely the right pattern (best-effort I/O), leave the
bare form and add a comment explaining *why* swallowing is fine. zlinter's
`no_swallow_error` is **not enabled** because it is mutually unsatisfiable
with the compiler. See `private/zlinter-builtins-survey-2026-05-03.md`.

## Optionals: `x.?`, not `x orelse unreachable`

`.?` triggers identical safety checks in safe builds, costs the same in
release, and is shorter. Lint chain enforces (ADR-0009 / Phase B,
`no_orelse_unreachable`).

## Exhaustive enum `switch`: list every tag, no `else`

For non-extensible enums, enumerate every tag. Adding a new tag later
raises a missing-case error at every switch — exactly the W54-class
regression v2 exists to prevent. `else =>` is gate-rejected by
`require_exhaustive_enum_switch`. Use `else =>` only on non-exhaustive
enums (`enum(T) { ..., _ }`) or external enums whose tag set we don't own.

## Empty function / `if` body: comment inside

```zig
fn nopOp(_: *InterpCtx, _: *const ZirInstr) anyerror!void {
    // Wasm `nop` — intentionally empty.
}
```

Lint enforces `no_empty_block`. The friction is the point.

## Short identifiers (`i`, `n`, `rt`, `ea`) are fine

`declaration_naming` (length ≥ 3) is **not enabled**. WebAssembly / IR /
register-allocator code uses math conventions.

## Inferred error sets at the implementation layer are fine

`pub fn main(init: std.process.Init) !void` and `anyerror!T` propagation
through the interpreter are intentional — wide error sets re-introduce
the W54 Implicit Contract Sprawl. `no_inferred_error_unions` is **not
enabled**.

## `undefined` for fixed-size stack buffers is the canonical idiom

```zig
var operand_buf: [max_operand_stack]Value = undefined;
```

Zero-init wastes work; the cursor / index bookkeeping guarantees no
read-before-write. `no_undefined` is **not enabled**.

## Lint gate (ADR-0009) — what's actually enforced

`zig build lint -- --max-warnings 0` runs five rules:

| Rule                             | What it catches                           |
|----------------------------------|-------------------------------------------|
| `no_deprecated`                  | any stdlib `/// Deprecated:` reference    |
| `no_orelse_unreachable`          | `x orelse unreachable` instead of `x.?`   |
| `no_empty_block`                 | empty `{}` body without an inside comment |
| `require_exhaustive_enum_switch` | `else =>` on a non-extensible enum        |
| `no_unused`                      | unused `const`, function, import          |

Mac-host only. For not-enabled rules + rationale see
`private/zlinter-builtins-survey-2026-05-03.md`.

## Tagged union: `switch`, not `==`

```zig
return switch (self) { .nil => true, else => false };  // OK
return self == .nil;                                    // unreliable
```

Initialise with type annotation: `const nil: Value = .nil;` (not `Value.nil`).

## ArrayList / HashMap: `.empty` + per-call allocator

```zig
var list: std.ArrayList(u8) = .empty;
defer list.deinit(allocator);
try list.append(allocator, 42);
const v = list.pop();   // returns ?T
```

Same for `HashMap`: `.empty`, `put(alloc, k, v)`, `deinit(alloc)`.

## stdout via `std.Io.File`

```zig
var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
const stdout = &stdout_writer.interface;
try stdout.print("hello {s}\n", .{"world"});
try stdout.flush();    // do not forget
```

`writer(io, buf)` requires `io` (`std.Io`) — get it from `std.process.Init`
(Juicy Main) or `Runtime.io`.

## `*std.Io.Writer` for writer params

Type-erased writer; replaces `anytype` for writer parameters and avoids
"unable to resolve inferred error set" with recursion. Tests:
`var w: std.Io.Writer = .fixed(&buf);` then `w.buffered()`.

Allocating writer:

```zig
var aw: std.Io.Writer.Allocating = .init(allocator);
errdefer aw.deinit();
try form.format(&aw.writer);
return aw.toOwnedSlice();
```

## `@branchHint` (not `@branch`) — inside the branch body

```zig
if (cond) {
    @branchHint(.likely);
} else {
    @branchHint(.unlikely);
    return error.Fail;
}
```

## Cross-platform footgun: `STDIN_FILENO` on Windows

`std.posix.STDIN_FILENO` (and `STDOUT/STDERR_FILENO`) falls back to
`else => 0` (a `comptime_int`) on every non-Linux target — NOT a
`fd_t`-typed constant. On Windows, `fd_t = HANDLE = *anyopaque`, so
passing `STDIN_FILENO` where `fd_t` is expected fails to compile.

For tests that need a placeholder fd:

```zig
const fd: std.posix.fd_t = undefined;     // adapts to both shapes
```

Real fd values for production paths come from `std.fs.File.handle` etc.

## Variable shadowing

Zig disallows locals shadowing struct method names. Rename the local.

## `comptime StaticStringMap`

```zig
const keywords = std.StaticStringMap(Keyword).initComptime(.{
    .{ "if",  .if_kw  },
    .{ "def", .def_kw },
});
```

## `ArenaAllocator` for phase-based memory

```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const alloc = arena.allocator();
```

## Doc comments

- `//!` — module-level (top of file). ZLS hover on module.
- `///` — declaration-level (on `pub` types/fns/fields).
- `//`  — inline notes (inside bodies only).

Every file gets `//!`. Every `pub` gets `///` unless the name is
self-evident. No decorative banners.

## `packed struct(<width>)` / `extern struct`

`packed struct(u8)` for bit-precise layout (e.g. `HeapHeader.flags`).
`extern struct` (C ABI) for top-level layout that crosses
language / Wasm boundaries.
