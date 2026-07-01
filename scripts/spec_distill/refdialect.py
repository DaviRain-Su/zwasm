#!/usr/bin/env python3
"""Shared wasm-tools `json-from-wast` value-dialect formatter for the spec
distillers (`scripts/regen_spec_*_assert.sh`, `regen_wasmtime_misc.sh`).

ONE place to absorb wasm-tools JSON-shape evolution so a future tool/spec bump
is a single-file fix instead of editing N duplicated embedded-python bakers
(the pain surfaced by the 2026-06 re-vendor: the GC ref dialect broke every
distiller's `fmt`). The distillers import this:

    import sys, os
    sys.path.insert(0, os.path.join(REPO, "scripts/spec_distill"))
    from refdialect import fmt_value, kind_alias, is_ref_type

Scope: SCALAR (i32/i64/f32/f64) + REFERENCE values. v128 lane encoding stays
in the SIMD distiller (separate concern). Output tokens match the spec
assert-runner manifest grammar (`<kind>:<payload>`):

  i32:<u32>  i64:<u64>  f32:<bits-or-nan-token>  f64:<bits-or-nan-token>
  i64:0       — a null reference (the runner matches null as 0)
  i64:nonnull — any non-null reference (runner: got != 0)
  i64:<host>  — a host-bound externref/funcref with a pinned index

Reference encoding (ADR-0061 + the 2.0 baker's d-63 note): reftypes alias onto
the i64 GPR-class scalar path. A host-bound `ref.extern N` / `ref.func N` is
encoded `(1<<63) | (N+1)` so the u64 is never 0 (distinct from null) and sits
in an address-space-disjoint band from FuncEntity heap pointers.
"""

# Wasm 3.0 typed-null heap types (newer wasm-tools json-from-wast emits these
# with NO 'value' field; each denotes a null reference of that bottom type).
_NULL_REF_TYPES = (
    "refnull", "nullref", "nullfuncref", "nullexternref",
    "nullexnref", "nullcontref",
)
# Concrete reference value types (may carry a 'value', or be bare = any-non-null).
_REF_TYPES = ("funcref", "externref", "exnref", "contref", "anyref", "eqref")

NULL_TOKEN = "i64:0"
NONNULL_TOKEN = "i64:nonnull"


def is_ref_type(t):
    """True for any reference type tag (concrete or typed-null bottom)."""
    return t in _NULL_REF_TYPES or t in _REF_TYPES


def kind_alias(t):
    """Map a value's `type` to its dispatch CLASS for the (arg_kinds,
    result_kind) gate. Reftypes + typed-null heap types alias onto the i64
    GPR-class scalar path (ADR-0061); scalars map to themselves."""
    if is_ref_type(t):
        return "i64"
    return t


def fmt_value(v):
    """Format one wasm-tools json value dict → a runner manifest token.

    Raises ValueError on a genuinely-unknown shape (callers should let it
    propagate so a NEW unhandled dialect is LOUD, not silently mis-baked)."""
    t = v["type"]

    # Typed-null heap types: no 'value' → null reference → i64:0.
    if t in _NULL_REF_TYPES:
        return NULL_TOKEN

    # Concrete reference types.
    if t in _REF_TYPES:
        # Bare ref (no 'value') = "any non-null ref of this type" — the
        # canonical wast→json form cannot pin host-ref identity, so the
        # assertion degenerates to non-null (runner matches got != 0).
        if "value" not in v or v.get("value") is None:
            return NONNULL_TOKEN
        val = v["value"]
        if val == "null":
            return NULL_TOKEN
        n = int(val)
        host_ref = (1 << 63) | (n + 1)
        return "i64:{}".format(host_ref)

    # Scalars. i32/i64: wasm-tools may emit SIGNED (str or int); the manifest
    # + runner use UNSIGNED width-folded decimals.
    val = v["value"]
    if t in ("i32", "i64"):
        n = int(val)
        if n < 0:
            n += (1 << 32) if t == "i32" else (1 << 64)
        return "{}:{}".format(t, n)
    # f32/f64: bit-pattern decimals (identical across tools); nan:canonical /
    # nan:arithmetic tokens pass through unchanged for the runner's NaN matcher.
    if t in ("f32", "f64"):
        return "{}:{}".format(t, val)

    raise ValueError("refdialect.fmt_value: unhandled value shape {!r}".format(v))


def _selftest():
    cases = [
        # typed-null heap types → i64:0
        ({"type": "refnull"}, "i64:0"),
        ({"type": "nullref"}, "i64:0"),
        ({"type": "nullfuncref"}, "i64:0"),
        ({"type": "nullexternref"}, "i64:0"),
        ({"type": "nullexnref"}, "i64:0"),
        # bare concrete ref → any-non-null
        ({"type": "funcref"}, "i64:nonnull"),
        ({"type": "externref"}, "i64:nonnull"),
        ({"type": "exnref"}, "i64:nonnull"),
        # valued ref: explicit null vs host-bound index
        ({"type": "funcref", "value": "null"}, "i64:0"),
        ({"type": "externref", "value": "0"}, "i64:{}".format((1 << 63) | 1)),
        ({"type": "externref", "value": "2"}, "i64:{}".format((1 << 63) | 3)),
        ({"type": "funcref", "value": None}, "i64:nonnull"),
        # scalars: unsigned width-fold
        ({"type": "i32", "value": "-1"}, "i32:4294967295"),
        ({"type": "i32", "value": "42"}, "i32:42"),
        ({"type": "i64", "value": "-1"}, "i64:18446744073709551615"),
        ({"type": "i64", "value": 7}, "i64:7"),
        # fp: bit-pattern + nan token passthrough
        ({"type": "f32", "value": "1065353216"}, "f32:1065353216"),
        ({"type": "f64", "value": "nan:canonical"}, "f64:nan:canonical"),
    ]
    for v, want in cases:
        got = fmt_value(v)
        assert got == want, "fmt_value({!r}) = {!r}, want {!r}".format(v, got, want)
    # kind_alias
    assert kind_alias("funcref") == "i64"
    assert kind_alias("nullref") == "i64"
    assert kind_alias("anyref") == "i64"
    assert kind_alias("i32") == "i32"
    assert kind_alias("f64") == "f64"
    # is_ref_type
    assert is_ref_type("funcref") and is_ref_type("refnull")
    assert not is_ref_type("i32")
    # unknown shape is LOUD
    try:
        fmt_value({"type": "v128", "value": []})
        raise AssertionError("expected ValueError for v128")
    except ValueError:
        pass
    print("refdialect selftest: {} cases OK".format(len(cases)))


if __name__ == "__main__":
    _selftest()
