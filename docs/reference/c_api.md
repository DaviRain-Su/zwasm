# C API reference (wasm-c-api)

zwasm implements the standard **wasm-c-api** so a C host that drives any
wasm-c-api runtime (wasmtime, wasmer, …) drives zwasm unchanged. Three
headers in [`include/`](../../include/):

| Header                             | Origin                                                           | Status                                                                                                                                              |
|------------------------------------|------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| [`wasm.h`](../../include/wasm.h)   | Upstream `WebAssembly/wasm-c-api`, vendored read-only (ADR-0004) | **Complete** — every declared `extern` function is implemented (293/293; `scripts/capi_surface_gap.sh` enforces gap=0)                             |
| [`wasi.h`](../../include/wasi.h)   | Hand-authored project extension (ADR-0005)                       | WASI 0.1 host-setup (`zwasm_wasi_config_*`, `zwasm_store_set_wasi`) — no canonical upstream `wasi.h` exists                                        |
| [`zwasm.h`](../../include/zwasm.h) | Project extension slot                                           | **Reserved placeholder** — no extensions shipped (allocator injection / fuel / timeout / cancel / fast-path invoke are NOT implemented; see D-277) |

The header IS the reference — `wasm.h` is the upstream standard
documented at <https://github.com/WebAssembly/wasm-c-api>. This page
maps the families to zwasm specifics.

## Standard surface (`wasm.h`)

Full coverage of the wasm-c-api families:

- **Lifecycle**: `wasm_engine_new` / `wasm_store_new` / `wasm_module_new`
  (parse + validate) / `wasm_module_validate` / `wasm_instance_new` / the
  `_delete` for each.
- **Externals**: `wasm_func_*` (incl. host callbacks + `wasm_func_call`),
  `wasm_global_get`/`_set`, `wasm_table_get`/`_set`/`_grow`/`_size`,
  `wasm_memory_data`/`_size`/`_grow`.
- **Types**: `wasm_*type_*` (functype / globaltype / tabletype / memorytype
  / valtype / externtype / importtype / exporttype) + the tagtype family
  (EH).
- **Values + vectors**: `wasm_val_*`, `wasm_*_vec_new`/`_copy`/`_delete`.
- **Traps + frames**: `wasm_trap_*`, `wasm_frame_*`.
- **Refs + sharing**: `wasm_ref_*` (`_same`/`_as_*`/`_copy`), host_info
  accessors, `wasm_module_serialize`/`_deserialize`/`_share`/`_obtain`.

Residual *semantic* limits (functions exist + behave honestly, not
link-stubbed): `wasm_val` `of.ref` = raw payload (D-269); standalone /
instance / foreign `_copy` → null (D-253-D); `serialize` = source bytes,
no AOT cache (D-271). Audit: [`.dev/c_api_surface_audit_2026-06-04.md`](../../.dev/c_api_surface_audit_2026-06-04.md).

## WASI host-setup (`wasi.h`)

A C host that already drives `wasm.h` configures WASI via
`zwasm_wasi_config_new()` → `zwasm_wasi_config_set_args` /
`inherit_stdio` / … → `zwasm_store_set_wasi(store, cfg)` (takes
ownership). See the worked example in
[`include/wasi.h`](../../include/wasi.h) and
[`examples/c_host/`](../../examples/c_host/).

## Not shipped (`zwasm.h`)

`zwasm.h` is a reserved placeholder. The performance / control extensions
once sketched for it (allocator injection, fuel metering, wall-clock
timeout, cancellation, the kind-less `zwasm_func_call_fast` hot path) are
**not implemented** — they are post-v0.1.0 / evaluated-on-demand, in
keeping with the lightweight design. Tracked as **D-277**.
