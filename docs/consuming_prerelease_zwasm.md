# Consuming pre-tag zwasm reproducibly (for cljw / ClojureWasmFromScratch and others)

> **Doc-state**: ACTIVE. Audience: any downstream that depends on `zwasm`
> BEFORE a published tag — primarily cljw (`build.zig.zon` `.zwasm`). Written
> 2026-06-15 to answer: *"if we reference the `zwasm-from-scratch` branch HEAD
> instead of a tag and push, can we prevent 'it doesn't build for others'?"*

## TL;DR

**Yes — preventable, WITHOUT a tag.** The reproducibility lever is a **fixed
commit hash + content hash** in `build.zig.zon`, not a tag per se. A tag is just
a human-friendly *name* for a commit; Zig's package manager pins by the content
`.hash` either way. The two things that DO break other people's builds:

1. `.path = "../zwasm_from_scratch"` — a **local filesystem** ref. Unpublishable;
   anyone who clones cljw without your local zwasm tree fails immediately. This is
   the current co-dev form — it MUST change before cljw is pushed for others.
2. A **bare moving branch ref** (`#zwasm-from-scratch`) with no recorded content
   hash — a moving target; a re-`zig fetch --save` re-pins to whatever HEAD is
   then (the overnight loop advances it). Non-reproducible.

## Situation (2026-06-15)

- zwasm is **pre-tag**. Dev happens on branch `zwasm-from-scratch`
  (`git@github.com:clojurewasm/zwasm.git`), pushed continuously (incl. an
  overnight autonomous loop). **`--force` is forbidden** (project rule) → every
  pushed commit stays fetchable forever; history is append-only.
- cljw's `build.zig.zon` `.zwasm` is **lazy** (`b.lazyDependency`; only `-Dwasm` /
  `-Dzwasm-spike` resolve it — the default build + gate never fetch it). Its
  "proper" pinned form is the `v2.0.0-alpha.2` dogfood tag; it is currently
  switched to `.path` for relative-path co-development.
- cljw consumes zwasm **interp-only** (the Zig facade + C-API NEVER make a JIT
  instance). zwasm HEAD churns overnight but only in JIT-internal / test / env /
  docs surfaces — **the interp/C-API/facade surface is additive-stable**, so
  bumping the pin forward is low-risk (no signature breaks this session).

## Policy / approach

To let others build cljw reproducibly while zwasm is still pre-tag:

1. **Pin a specific zwasm commit, not the branch name, not `.path`.** In cljw's
   `build.zig.zon`:
   ```zig
   .zwasm = .{
       .url = "git+https://github.com/clojurewasm/zwasm.git#<FULL_COMMIT_SHA>",
       .hash = "<content-hash zig fetch records>",
       .lazy = true,
   },
   ```
   Produce it with `zig fetch --save=zwasm "git+https://github.com/clojurewasm/zwasm.git#<SHA>"`.
   The recorded `.hash` is what makes it reproducible — Zig validates fetched
   content against it; a moved branch would hash-mismatch rather than silently
   drift.
2. A **commit-hash pin ≡ a tag pin** for reproducibility. Cut the tag later
   (user-only, ADR-0156) for ergonomics; until then a SHA pin is functionally
   identical. Do NOT block on the tag for "others can build it".

## Requirements / caveats (true for SHA-pin AND tag)

- [x] **Pushed**: the pinned commit must be on `origin/zwasm-from-scratch` (the
  loop pushes every turn). Verify the SHA exists on origin before pinning.
- [x] **No force-push** (project rule) → the commit never disappears.
- [ ] **Read access** to `github.com/clojurewasm/zwasm` for whoever builds cljw
  (grant access if the repo is private, or make it public). The git+https URL +
  their git creds. *This is the one genuinely external requirement.*
- [ ] **Zig 0.16.0** toolchain parity on the builder's machine (orthogonal to the
  pin; the same constraint a tag carries).
- [ ] **Transitive deps**: fetching zwasm also fetches zwasm's own deps. Today
  that is only `zlinter` (`git+...#<sha>` + hash — already reproducible) and it is
  a lint-time dep; confirm it stays out of the consumer's required graph (lazy /
  not imported by the embedding API path) so a consumer isn't forced to fetch it.

## Recommendation

- **For cljw co-development now**: keep `.path` (fast local iteration) — but it is
  NOT pushable.
- **Before pushing cljw for others to build**: swap `.path` → a SHA pin (above) of
  a pushed `zwasm-from-scratch` commit. That alone prevents "doesn't build for
  others", no tag required.
- **When zwasm cuts the next dogfood tag** (user-only): switch the SHA pin to the
  tag for readability. Same reproducibility, friendlier diff.
