//! Component-Model validation (ADR-0176) — structural-first, incremental.
//!
//! Walks the decoded `TypeInfo` (NO re-parse — the deliberate divergence from
//! wasm-tools, which interleaves validate-with-decode) and rejects invalid
//! components before instantiation, mirroring wasmtime's reject-invalid
//! behaviour (ADR-0170 wasmtime-equivalent goal). Each rule lands as one TDD
//! chunk under the E3-CM-validation bundle, driven by the official
//! `WebAssembly/component-model/test/wasm-tools` `assert_invalid` corpus.
//!
//! Rule 1 (this file's first rule): **type-index bounds** for value types.
//! Every `ValType.type_index` (recursively inside a top-level deftype) and
//! every `own`/`borrow` resource-type index must be `<` the type-index-space
//! length. Catches the most-frequent corpus category ("type index out of
//! bounds", ~39 cases).
//!
//! Zone 1 (`feature/component/`): pure logic, no host orchestration (ADR-0172).

const std = @import("std");
const decode = @import("decode.zig");
const types = @import("types.zig");

const TypeInfo = types.TypeInfo;
const DefType = types.DefType;
const ValType = types.ValType;
const Error = types.Error;

/// Component-Model spec (Binary.md / validation) — reject a component whose
/// decoded `TypeInfo` violates a structural rule. Called after
/// `decodeTypeInfo()`, before instantiation.
pub fn validate(info: *const TypeInfo) Error!void {
    // Bounds-check against the TRUE type-index-space size (type defs + type
    // aliases + type imports + type exports), NOT `deftypes.len` — a valid
    // reference to an aliased/imported type lives past the type-section count.
    const type_space_len = info.type_space_len;
    // Rule 1 refinement: a type-section def may only reference STRICTLY
    // EARLIER type indices (definition order) — its bound is its own
    // position in the type index space, not the final space size (the
    // corpus "(type (option 0))" self-/forward-reference class). Aliased/
    // imported/exported types referenced from elsewhere still bound by the
    // final size below.
    for (info.type_space.items, 0..) |entry, pos| {
        switch (entry) {
            .def => |d| try checkDefTypeIndices(info.deftypes.items[d], @intCast(pos)),
            .named => {},
        }
    }
    for (info.deftypes.items) |dt| {
        try checkDefTypeLabels(dt);
        try checkDefTypeOuterAliases(dt, 1);
        try checkDefTypeDeclDups(dt);
    }
    try checkInstances(info);
    try checkCanons(info, type_space_len);
    try checkAliases(info);
    for (info.imports.items) |imp| {
        try checkExternDesc(imp.desc, type_space_len);
        try checkExternName(imp.name);
    }
    for (info.exports.items) |ex| {
        if (ex.desc) |d| try checkExternDesc(d, type_space_len);
        try checkExternName(ex.name);
        // Export sortidx bounds for the tracked index spaces (corpus
        // "module/instance index out of bounds" top-level classes).
        switch (ex.sort) {
            .core => |cs| if (cs == .module and ex.index >= info.core_module_count) return Error.InvalidSort,
            .component => if (ex.index >= info.component_count) return Error.InvalidSort,
            .instance => if (ex.index >= info.instance_origins.items.len) return Error.InvalidSort,
            .func => if (ex.index >= info.component_funcs.items.len) return Error.InvalidSort,
            .type => if (ex.index >= info.type_space_len) return Error.InvalidSort,
            .value => {}, // value index space not tracked — deferred
        }
    }
    try checkExportedTypes(info);
    try checkDuplicateNames(info);
}

/// Rule 8 extension: name uniqueness INSIDE nested instance/component type
/// scopes — import/export decls in one scope conflict case-insensitively
/// (corpus "(type (component (import \"a\")(import \"A\")))" class). Each
/// scope is independent; nested type_defs recurse.
fn checkDefTypeDeclDups(dt: DefType) Error!void {
    switch (dt) {
        .instance_type => |it| {
            for (it.decls, 0..) |decl, i| {
                if (decl == .type_def) try checkDefTypeDeclDups(decl.type_def.*);
                const name = instanceDeclName(decl) orelse continue;
                try checkExternName(name);
                for (it.decls[0..i]) |prev| {
                    const pn = instanceDeclName(prev) orelse continue;
                    if (std.ascii.eqlIgnoreCase(name, pn)) return Error.InvalidName;
                }
            }
        },
        .component_type => |ct| {
            for (ct.decls, 0..) |decl, i| {
                const inner = componentDeclInstanceDecl(decl);
                if (inner != null and inner.? == .type_def) try checkDefTypeDeclDups(inner.?.type_def.*);
                const name = componentDeclName(decl) orelse continue;
                try checkExternName(name);
                for (ct.decls[0..i]) |prev| {
                    const pn = componentDeclName(prev) orelse continue;
                    if (std.ascii.eqlIgnoreCase(name, pn)) return Error.InvalidName;
                }
            }
        },
        .value, .func, .enum_, .flags, .record, .list, .tuple, .variant, .option, .result, .own, .borrow => {},
    }
}

fn instanceDeclName(decl: types.InstanceDecl) ?[]const u8 {
    return switch (decl) {
        .export_decl => |d| d.name,
        .type_def, .alias => null,
    };
}

fn componentDeclName(decl: types.ComponentDecl) ?[]const u8 {
    return switch (decl) {
        .import_decl => |d| d.name,
        .instance_decl => |id| instanceDeclName(id),
    };
}

fn componentDeclInstanceDecl(decl: types.ComponentDecl) ?types.InstanceDecl {
    return switch (decl) {
        .import_decl => null,
        .instance_decl => |id| id,
    };
}

/// Rule 9: instantiate-section bounds + names (corpus instantiate.wast
/// "index out of bounds" / argument-conflict classes). Definition order:
/// an instantiate/inline-export may only reference EARLIER instances (its
/// own position is the bound); module/component operands bound by their
/// section counts; instantiation-arg names must not conflict
/// (case-insensitive); component-level inline-export names are extern
/// names. Non-instance arg sorts keep gross final-space bounds where
/// tracked (false-negative at worst).
fn checkInstances(info: *const TypeInfo) Error!void {
    for (info.core_instances.items, 0..) |ci, i| {
        switch (ci) {
            .instantiate => |it| {
                if (it.module >= info.core_module_count) return Error.InvalidInstance;
                for (it.args, 0..) |arg, ai| {
                    if (arg.instance >= i) return Error.InvalidInstance;
                    for (it.args[0..ai]) |prev| {
                        if (std.ascii.eqlIgnoreCase(arg.name, prev.name)) return Error.InvalidName;
                    }
                }
            },
            .inline_exports => |exps| for (exps, 0..) |e, ei| {
                switch (e.sort) {
                    .func => if (e.index >= info.core_funcs.items.len) return Error.InvalidInstance,
                    .table => if (e.index >= info.core_tables.items.len) return Error.InvalidInstance,
                    else => {}, // memory/global/... core spaces not tracked — deferred
                }
                for (exps[0..ei]) |prev| {
                    if (std.ascii.eqlIgnoreCase(e.name, prev.name)) return Error.InvalidName;
                }
            },
        }
    }
    for (info.component_instances.items, 0..) |ci, i| {
        switch (ci) {
            .instantiate => |it| {
                if (it.component >= info.component_count) return Error.InvalidInstance;
                for (it.args, 0..) |arg, ai| {
                    if (std.meta.activeTag(arg.sort) == .instance and arg.index >= i) return Error.InvalidInstance;
                    for (it.args[0..ai]) |prev| {
                        if (std.ascii.eqlIgnoreCase(arg.name, prev.name)) return Error.InvalidName;
                    }
                }
            },
            .inline_exports => |exps| for (exps, 0..) |e, ei| {
                try checkExternName(e.name);
                if (std.meta.activeTag(e.sort) == .instance and e.index >= i) return Error.InvalidInstance;
                for (exps[0..ei]) |prev| {
                    if (std.ascii.eqlIgnoreCase(e.name, prev.name)) return Error.InvalidName;
                }
            },
        }
    }
}

/// Rule 8: name uniqueness, ASCII-case-insensitive — kebab labels compare
/// case-insensitively per the Explainer.md `label` semantics, so `A-b`
/// conflicts with `a-B` (corpus "...conflicts with previous name...",
/// naming.wast). Checked within top-level import names, within export names
/// (the two namespaces are separate — an import and an export may share a
/// name), and within each deftype's label set (func params, record fields,
/// variant cases, enum/flags labels). O(n²) pairwise keeps the validator
/// allocation-free; the lists are small.
fn checkDuplicateNames(info: *const TypeInfo) Error!void {
    for (info.imports.items, 0..) |imp, i| {
        for (info.imports.items[0..i]) |prev| {
            if (std.ascii.eqlIgnoreCase(imp.name, prev.name)) return Error.InvalidName;
        }
    }
    for (info.exports.items, 0..) |ex, i| {
        for (info.exports.items[0..i]) |prev| {
            if (std.ascii.eqlIgnoreCase(ex.name, prev.name)) return Error.InvalidName;
        }
    }
    for (info.deftypes.items) |dt| try checkDefTypeLabelDups(dt);
}

fn checkDefTypeLabelDups(dt: DefType) Error!void {
    switch (dt) {
        .func => |ft| for (ft.params, 0..) |p, i| {
            for (ft.params[0..i]) |prev| {
                if (std.ascii.eqlIgnoreCase(p.name, prev.name)) return Error.InvalidName;
            }
        },
        .record => |rec| for (rec.fields, 0..) |f, i| {
            for (rec.fields[0..i]) |prev| {
                if (std.ascii.eqlIgnoreCase(f.name, prev.name)) return Error.InvalidName;
            }
        },
        .variant => |v| for (v.cases, 0..) |c, i| {
            for (v.cases[0..i]) |prev| {
                if (std.ascii.eqlIgnoreCase(c.name, prev.name)) return Error.InvalidName;
            }
        },
        .enum_ => |e| try checkLabelSliceDups(e.labels),
        .flags => |fl| try checkLabelSliceDups(fl.labels),
        .value, .list, .tuple, .option, .result, .own, .borrow => {},
        .instance_type, .component_type => {},
    }
}

fn checkLabelSliceDups(labels: []const []const u8) Error!void {
    for (labels, 0..) |l, i| {
        for (labels[0..i]) |prev| {
            if (std.ascii.eqlIgnoreCase(l, prev)) return Error.InvalidName;
        }
    }
}

/// Rule 7: a type export must be "valid to be used as export"
/// (type-export-restrictions.wast). When the exported index is a local
/// structural def, every type reference inside it must resolve to a NAMED
/// type-space entry (minted by a type import/export/alias) — referencing an
/// anonymous local def leaks a nameless type. `.named` exports re-export an
/// already-vetted name and pass. Nested instance/component type scopes stay
/// deferred (consistent with rule 1).
fn checkExportedTypes(info: *const TypeInfo) Error!void {
    const entries = info.type_space.items;
    for (info.exports.items) |ex| {
        if (std.meta.activeTag(ex.sort) != .type) continue;
        if (ex.index >= entries.len) return Error.InvalidTypeIndex;
        switch (entries[ex.index]) {
            .named => {},
            .def => |d| try checkDefTypeRefsNamed(info, info.deftypes.items[d]),
        }
    }
}

fn checkDefTypeRefsNamed(info: *const TypeInfo, dt: DefType) Error!void {
    switch (dt) {
        .value => |vt| try checkValTypeNamed(info, vt),
        .func => |ft| {
            for (ft.params) |p| try checkValTypeNamed(info, p.ty);
            if (ft.result) |r| try checkValTypeNamed(info, r);
        },
        .record => |rec| for (rec.fields) |f| try checkValTypeNamed(info, f.ty),
        .tuple => |t| for (t.types) |vt| try checkValTypeNamed(info, vt),
        .list => |l| try checkValTypeNamed(info, l.element.*),
        .option => |o| try checkValTypeNamed(info, o.payload.*),
        .variant => |v| for (v.cases) |c| {
            if (c.payload) |p| try checkValTypeNamed(info, p);
        },
        .result => |res| {
            if (res.ok) |ok| try checkValTypeNamed(info, ok);
            if (res.err) |er| try checkValTypeNamed(info, er);
        },
        .own, .borrow => |idx| try checkRefNamed(info, idx),
        .enum_, .flags => {},
        // Nested type scopes — deferred (consistent with rule 1).
        .instance_type, .component_type => {},
    }
}

fn checkValTypeNamed(info: *const TypeInfo, vt: ValType) Error!void {
    switch (vt) {
        .primitive => {},
        .type_index => |idx| try checkRefNamed(info, idx),
    }
}

fn checkRefNamed(info: *const TypeInfo, idx: u32) Error!void {
    if (idx >= info.type_space.items.len) return Error.InvalidTypeIndex;
    if (std.meta.activeTag(info.type_space.items[idx]) != .named) return Error.InvalidExternDesc;
}

/// Rule 5: name format. Every label-carrying deftype member (func param,
/// record field, variant case, enum/flags label) must be in kebab case per
/// the Explainer.md `label` grammar. Nested `instance`/`component` type
/// scopes are deferred (consistent with rule 1 — never a false-positive).
fn checkDefTypeLabels(dt: DefType) Error!void {
    switch (dt) {
        .func => |ft| for (ft.params) |p| try checkLabel(p.name),
        .record => |rec| for (rec.fields) |f| try checkLabel(f.name),
        .variant => |v| for (v.cases) |c| try checkLabel(c.name),
        .enum_ => |e| for (e.labels) |l| try checkLabel(l),
        .flags => |fl| for (fl.labels) |l| try checkLabel(l),
        .value, .list, .tuple, .option, .result, .own, .borrow => {},
        .instance_type, .component_type => {},
    }
}

/// Rule 5: import/export name format (Explainer.md `importname`/`exportname`).
/// Dispatches on the name's shape:
/// - `=`-carrying forms (`locked-dep=…`/`unlocked-dep=…`/`url=…`/`integrity=…`)
///   are accepted unchecked — their grammars are deferred (false-negative at
///   worst, never a false-positive).
/// - `:`-carrying `interfacename` (`namespace:package/interface@version`):
///   each `:`/`/` segment before the `@` must be a label. (The spec restricts
///   namespace/package to lowercase; the general label check is deliberately
///   more permissive — deferred refinement, false-negative direction only.
///   The `@version` semver grammar is likewise deferred.)
/// - `[constructor]l` / `[method]l.l` / `[static]l.l`: label parts checked;
///   other bracket forms (async) are deferred.
/// - anything else is a `plainname` → plain kebab label.
fn checkExternName(name: []const u8) Error!void {
    if (name.len == 0) return Error.InvalidName;
    if (std.mem.findScalar(u8, name, '=') != null) return;
    if (std.mem.findScalar(u8, name, ':') != null) {
        const base = if (std.mem.findScalar(u8, name, '@')) |at| name[0..at] else name;
        var it = std.mem.splitAny(u8, base, ":/");
        while (it.next()) |segment| try checkLabel(segment);
        return;
    }
    if (name[0] == '[') {
        const close = std.mem.findScalar(u8, name, ']') orelse return Error.InvalidName;
        const kind = name[1..close];
        const rest = name[close + 1 ..];
        if (std.mem.eql(u8, kind, "constructor")) return checkLabel(rest);
        if (std.mem.eql(u8, kind, "method") or std.mem.eql(u8, kind, "static")) {
            const dot = std.mem.findScalar(u8, rest, '.') orelse return Error.InvalidName;
            try checkLabel(rest[0..dot]);
            return checkLabel(rest[dot + 1 ..]);
        }
        return; // other bracket forms (async lift/lower) — deferred
    }
    return checkLabel(name);
}

/// Explainer.md `label` grammar: `label ::= <fragment> ('-' <fragment>)*`
/// where the first fragment is `[a-z][0-9a-z]*` or `[A-Z][0-9A-Z]*` (starts
/// with a letter) and later fragments are `[0-9a-z]+` or `[0-9A-Z]+` (may
/// start with a digit). Mixing cases WITHIN a fragment, empty fragments
/// (leading/trailing/double `-`), and the empty label are invalid.
fn checkLabel(label: []const u8) Error!void {
    if (label.len == 0) return Error.InvalidName;
    var it = std.mem.splitScalar(u8, label, '-');
    var first = true;
    while (it.next()) |fragment| {
        if (fragment.len == 0) return Error.InvalidName;
        if (first and std.ascii.isDigit(fragment[0])) return Error.InvalidName;
        var all_lower = true;
        var all_upper = true;
        for (fragment) |ch| {
            if (!(std.ascii.isDigit(ch) or std.ascii.isLower(ch))) all_lower = false;
            if (!(std.ascii.isDigit(ch) or std.ascii.isUpper(ch))) all_upper = false;
        }
        if (!all_lower and !all_upper) return Error.InvalidName;
        first = false;
    }
}

/// Rule 4: an import/export `externdesc` that ascribes a type must reference an
/// in-bounds type. `func`/`component`/`instance` are type indices (the ascribed
/// def-type); `type_bound (eq i)` references type `i`; `value` carries a valtype.
/// `core_module` (core-module index space) is deferred — the count is not yet
/// surfaced on `TypeInfo` (a false-negative at worst, never a false-positive).
fn checkExternDesc(desc: types.ExternDesc, type_space_len: u32) Error!void {
    switch (desc) {
        .func, .component, .instance => |idx| if (idx >= type_space_len) return Error.InvalidExternDesc,
        .type_bound => |tb| switch (tb) {
            .eq => |idx| if (idx >= type_space_len) return Error.InvalidExternDesc,
            .sub_resource => {},
        },
        .value_bound => |vb| if (vb) |vt| try checkValType(vt, type_space_len),
        .core_module => {}, // core-module index space count not yet on TypeInfo — deferred
    }
}

/// Rule 3: an `alias` of an instance export must name an in-bounds instance.
/// `core_export` → core-instance space (`core_instances`), `component_export` →
/// component-instance space (`instance_origins`). Bounds are the final space
/// size — a gross OOB (the corpus "instance index out of bounds" category) is
/// caught; definition-order forward-reference refinement + export-name existence
/// are deferred (a false-negative at worst, never a false-positive).
/// Rule 6 (top-level half): an `outer` alias count must be `<` the number of
/// enclosing component scopes — the top level is ONE scope (count 0 = the
/// current component), so any count ≥ 1 is the corpus "invalid outer alias
/// count" category. The target index's existence at the aliased scope is
/// deferred (index-bounds refinement).
fn checkAliases(info: *const TypeInfo) Error!void {
    const core_inst_len: u32 = @intCast(info.core_instances.items.len);
    const comp_inst_len: u32 = @intCast(info.instance_origins.items.len);
    for (info.aliases.items) |al| switch (al.target) {
        .core_export => |ce| if (ce.instance >= core_inst_len) return Error.InvalidAlias,
        .component_export => |ce| if (ce.instance >= comp_inst_len) return Error.InvalidAlias,
        .outer => |o| {
            if (o.count >= 1) return Error.InvalidAlias;
            // count 0 = the current component: existence is checkable for the
            // sorts whose spaces are tracked (others stay deferred).
            switch (al.sort) {
                .type => if (o.index >= info.type_space_len) return Error.InvalidAlias,
                .component => if (o.index >= info.component_count) return Error.InvalidAlias,
                .core => |cs| if (cs == .module and o.index >= info.core_module_count) return Error.InvalidAlias,
                else => {},
            }
        },
    };
}

/// Rule 6 (nested half): walk nested `instance`/`component` type scopes,
/// tracking depth = the number of enclosing component scopes at the decl site
/// (top level = 1; each nested instance/component type adds one). An `outer`
/// alias decl whose count ≥ depth skips past the outermost scope — the corpus
/// "invalid outer alias count" category.
fn checkDefTypeOuterAliases(dt: DefType, depth: u32) Error!void {
    switch (dt) {
        .instance_type => |it| for (it.decls) |decl| try checkInstanceDeclOuterAlias(decl, depth + 1),
        .component_type => |ct| for (ct.decls) |decl| switch (decl) {
            .import_decl => {},
            .instance_decl => |id| try checkInstanceDeclOuterAlias(id, depth + 1),
        },
        .value, .func, .enum_, .flags, .record, .list, .tuple, .variant, .option, .result, .own, .borrow => {},
    }
}

fn checkInstanceDeclOuterAlias(decl: types.InstanceDecl, depth: u32) Error!void {
    switch (decl) {
        .type_def => |td| try checkDefTypeOuterAliases(td.*, depth),
        .alias => |al| switch (al.target) {
            .outer => |o| if (o.count >= depth) return Error.InvalidAlias,
            .component_export, .core_export => {},
        },
        .export_decl => {},
    }
}

/// Rule 2: bounds-check every index a `canon` definition references against its
/// index space — `lift` (core-func + component-func type), `lower` (component
/// func), and the resource builtins (type). The core-/component-func lists ARE
/// their index spaces (every minting form appends), so `.items.len` is exact
/// here (unlike `deftypes.len` for the type space — see rule 1).
fn checkCanons(info: *const TypeInfo, type_space_len: u32) Error!void {
    const core_func_len: u32 = @intCast(info.core_funcs.items.len);
    const comp_func_len: u32 = @intCast(info.component_funcs.items.len);
    for (info.canons.items) |c| switch (c) {
        .lift => |l| {
            if (l.core_func >= core_func_len) return Error.InvalidCanon;
            if (l.type_index >= type_space_len) return Error.InvalidTypeIndex;
        },
        .lower => |l| if (l.func >= comp_func_len) return Error.InvalidCanon,
        .resource_new, .resource_drop, .resource_rep => |t| if (t >= type_space_len) return Error.InvalidTypeIndex,
    };
}

/// Rule 1: bounds-check every type-index a top-level deftype references against
/// the type-index-space length. Nested `instance`/`component` type scopes carry
/// their own index spaces and are deferred to a later rule (no false positives).
fn checkDefTypeIndices(dt: DefType, type_space_len: u32) Error!void {
    switch (dt) {
        .value => |vt| try checkValType(vt, type_space_len),
        .func => |ft| {
            for (ft.params) |p| try checkValType(p.ty, type_space_len);
            if (ft.result) |r| try checkValType(r, type_space_len);
        },
        .record => |rec| for (rec.fields) |f| try checkValType(f.ty, type_space_len),
        .tuple => |t| for (t.types) |vt| try checkValType(vt, type_space_len),
        .list => |l| try checkValType(l.element.*, type_space_len),
        .option => |o| try checkValType(o.payload.*, type_space_len),
        .variant => |v| for (v.cases) |c| {
            if (c.payload) |p| try checkValType(p, type_space_len);
        },
        .result => |res| {
            if (res.ok) |ok| try checkValType(ok, type_space_len);
            if (res.err) |er| try checkValType(er, type_space_len);
        },
        .own, .borrow => |idx| if (idx >= type_space_len) return Error.InvalidTypeIndex,
        // No type-index references in their immediate form:
        .enum_, .flags => {},
        // Nested type scopes — deferred to a later structural rule.
        .instance_type, .component_type => {},
    }
}

fn checkValType(vt: ValType, type_space_len: u32) Error!void {
    switch (vt) {
        .primitive => {},
        .type_index => |idx| if (idx >= type_space_len) return Error.InvalidTypeIndex,
    }
}

/// Decode a component binary (magic + layer preamble prepended) and validate.
fn validateBytes(bytes: []const u8) !void {
    var comp = try decode.decode(std.testing.allocator, bytes);
    defer comp.deinit(std.testing.allocator);
    var info = try types.decodeTypeInfo(std.testing.allocator, &comp);
    defer info.deinit();
    try validate(&info);
}

test "rule 7: exported local type may reference named types only" {
    const preamble = [_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x0d, 0x00, 0x01, 0x00 };
    // type[0] = (record (field "f" u32)) — local def.
    const type_a = [_]u8{ 0x01, 0x72, 0x01, 0x01, 'f', 0x79 };
    // (export "t" (type 0)) — mints type[1] as NAMED.
    const export_t = [_]u8{ 0x01, 0x00, 0x01, 't', 0x03, 0x00, 0x00 };

    // VALID: type[2] = (record (field "g" (type 1))) references the NAMED
    // export-minted index; exporting it is allowed.
    const type_named_ref = [_]u8{ 0x01, 0x72, 0x01, 0x01, 'g', 0x01 };
    const export_g2 = [_]u8{ 0x01, 0x00, 0x01, 'g', 0x03, 0x02, 0x00 };
    const valid = preamble ++
        [_]u8{ 7, type_a.len } ++ type_a ++
        [_]u8{ 11, export_t.len } ++ export_t ++
        [_]u8{ 7, type_named_ref.len } ++ type_named_ref ++
        [_]u8{ 11, export_g2.len } ++ export_g2;
    try validateBytes(&valid);

    // INVALID: type[2] = (record (field "g" (type 0))) references the
    // anonymous local def — "type not valid to be used as export".
    const type_local_ref = [_]u8{ 0x01, 0x72, 0x01, 0x01, 'g', 0x00 };
    const invalid = preamble ++
        [_]u8{ 7, type_a.len } ++ type_a ++
        [_]u8{ 11, export_t.len } ++ export_t ++
        [_]u8{ 7, type_local_ref.len } ++ type_local_ref ++
        [_]u8{ 11, export_g2.len } ++ export_g2;
    try std.testing.expectError(Error.InvalidExternDesc, validateBytes(&invalid));
}

test "rule 8: case-insensitive label duplicates" {
    try checkLabelSliceDups(&.{ "a", "b", "a-b" });
    try std.testing.expectError(Error.InvalidName, checkLabelSliceDups(&.{ "a-B-c-D", "A-b-C-d" }));
    try std.testing.expectError(Error.InvalidName, checkLabelSliceDups(&.{ "x", "y", "x" }));
}

test "rule 5: label grammar boundaries" {
    // Valid: single word, multi-fragment, acronym fragment, digit-led later fragment.
    try checkLabel("a");
    try checkLabel("foo-bar");
    try checkLabel("foo-BAR2");
    try checkLabel("a-1");
    try checkLabel("WASI");
    // Invalid: empty, case-mix within a fragment, empty fragments, digit-led first.
    try std.testing.expectError(Error.InvalidName, checkLabel(""));
    try std.testing.expectError(Error.InvalidName, checkLabel("TyPeS"));
    try std.testing.expectError(Error.InvalidName, checkLabel("Foo"));
    try std.testing.expectError(Error.InvalidName, checkLabel("foo--bar"));
    try std.testing.expectError(Error.InvalidName, checkLabel("-foo"));
    try std.testing.expectError(Error.InvalidName, checkLabel("foo-"));
    try std.testing.expectError(Error.InvalidName, checkLabel("1foo"));
    try std.testing.expectError(Error.InvalidName, checkLabel("foo_bar"));
}

test "rule 5: extern name forms" {
    // interfacename: segments label-checked, @version skipped.
    try checkExternName("wasi:cli/environment@0.2.3");
    try checkExternName("wasi:io/streams");
    try std.testing.expectError(Error.InvalidName, checkExternName("wasi:cLi/x"));
    // bracket forms.
    try checkExternName("[constructor]blob");
    try checkExternName("[method]blob.get-size");
    try checkExternName("[static]blob.merge");
    try std.testing.expectError(Error.InvalidName, checkExternName("[method]no-dot"));
    try std.testing.expectError(Error.InvalidName, checkExternName("[constructor]Bad"));
    // deferred `=` forms accepted unchecked.
    try checkExternName("unlocked-dep=<a:b/c>");
    // plainname falls through to the label grammar.
    try checkExternName("hello");
    try std.testing.expectError(Error.InvalidName, checkExternName("NevEr"));
    try std.testing.expectError(Error.InvalidName, checkExternName(""));
}
