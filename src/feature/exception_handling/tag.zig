//! Wasm 3.0 EH `TagInstance` — per-instance tag identity heap object
//! (ADR-0114 D1). A tag's IDENTITY is its `*TagInstance` ADDRESS, not
//! its contents: a cross-module import copies the source instance's
//! pointer (so two modules sharing an imported tag compare equal),
//! while structurally-identical tags from independent modules get
//! distinct addresses → distinct exception classes. throw/catch match
//! by pointer (`exc.tag == rt.tags[catch_tag_idx]`), which is correct
//! across module boundaries where the index-based key is not.
//!
//! Zone 1 (`src/feature/exception_handling/`); see ROADMAP §4.1 / §A1.

/// `typeidx` is retained for diagnostics / future type-aware paths;
/// the identity is the pointer, never the field contents.
pub const TagInstance = struct {
    typeidx: u32,
};
