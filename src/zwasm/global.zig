//! `Global` — typed accessor onto an instance's exported global per
//! ADR-0109 (D-272). Mirrors `Memory`: holds the runtime pointer plus
//! the export's cached valtype + mutability, and goes through the
//! shared `value_conv` for the runtime⇄facade `Value` mapping. Lifetime
//! ties to the owning `Instance` (the borrowed `*Runtime` stays valid
//! as long as the instance is alive).

const _runtime = @import("../runtime/runtime.zig");
const _zir = @import("../ir/zir.zig");
const _zwasm = @import("../zwasm.zig");
const _vc = @import("value_conv.zig");

pub const Global = struct {
    rt: *_runtime.Runtime,
    global_idx: u32,
    valtype: _zir.ValType,
    mutable: bool,

    pub const Error = error{Immutable};

    /// Wasm spec §4.5.5 (global.get) — read the current value.
    pub fn get(self: Global) _zwasm.Value {
        return _vc.runtimeToZwasm(self.rt.globals[self.global_idx].*, self.valtype);
    }

    /// Wasm spec §4.5.6 (global.set) — write a new value. Returns
    /// `error.Immutable` for a `const` global rather than silently
    /// dropping the write (the host chooses how to react).
    pub fn set(self: Global, val: _zwasm.Value) Error!void {
        if (!self.mutable) return error.Immutable;
        self.rt.globals[self.global_idx].* = _vc.zwasmToRuntime(val);
    }
};
