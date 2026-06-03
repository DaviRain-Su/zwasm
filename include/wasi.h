/**
 * \file wasi.h
 *
 * zwasm WASI 0.1 host-setup C API (project extension, not
 * upstream-portable).
 *
 * Per ADR-0005, this header is hand-authored — there is no
 * single canonical upstream `wasi.h` for host-side WASI
 * embedding (`WebAssembly/wasm-c-api` does not ship one;
 * runtime-specific `wasi.h`s like wasmtime's depend on
 * runtime-private build-config headers and are not "verbatim
 * vendorable").
 *
 * The functions here let a C host that already drives the
 * standard `wasm.h` surface (`wasm_engine_new` / `_store_new` /
 * `_module_new` / `_instance_new` / `_func_call`) opt-in to
 * WASI 0.1 hosting:
 *
 *   wasm_engine_t* engine = wasm_engine_new();
 *   wasm_store_t*  store  = wasm_store_new(engine);
 *   zwasm_wasi_config_t* cfg = zwasm_wasi_config_new();
 *   const char* args[] = { "prog", "--flag" };
 *   zwasm_wasi_config_set_args(cfg, 2, args);
 *   zwasm_wasi_config_inherit_stdio(cfg);
 *   zwasm_store_set_wasi(store, cfg);   // takes ownership of cfg
 *   wasm_instance_t* inst = wasm_instance_new(store, module, NULL, NULL);
 *
 * After `_set_wasi`, modules importing `wasi_snapshot_preview1.*`
 * resolve those imports against the configured host. Without
 * `_set_wasi`, modules that import WASI fail at
 * `wasm_instance_new` with a binding-error trap.
 *
 * Names use the `zwasm_` prefix to signal that these are
 * project extensions, not cross-runtime portable.
 *
 * Implementation lives in `src/wasi/host.zig` (Zone 2);
 * §9.4 / 4.1+ populates it.
 */

#ifndef ZWASM_WASI_H
#define ZWASM_WASI_H

#include "wasm.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Opaque WASI host-setup handle. Configured before
 * `wasm_instance_new` consumes a module that imports
 * `wasi_snapshot_preview1.*`; ownership transfers to the Store
 * via `zwasm_store_set_wasi`, after which the C host must NOT
 * call `zwasm_wasi_config_delete` on it.
 */
typedef struct zwasm_wasi_config_t zwasm_wasi_config_t;

zwasm_wasi_config_t* zwasm_wasi_config_new(void);
void                 zwasm_wasi_config_delete(zwasm_wasi_config_t*);

/**
 * Route the guest's stdin/stdout/stderr (fd 0/1/2) to the host
 * process's stdio. This is the default (`Host.init` installs the
 * three stdio fds), kept for API parity.
 *
 * Process argv / env inheritance (`inherit_argv` / `inherit_env`)
 * is deferred to post-v0.1 — a C-library context has no Zig-0.16
 * `Init` token for the process argv/env/io (ADR-0143 / D-255). Use
 * the explicit `set_args` / `set_envs` below instead.
 */
void zwasm_wasi_config_inherit_stdio(zwasm_wasi_config_t*);

/**
 * Explicit argv / envs override. Each `argv` / `keys` / `vals`
 * array is borrowed for the duration of the call only — the
 * config copies the strings.
 */
void zwasm_wasi_config_set_args(
    zwasm_wasi_config_t*,
    size_t argc,
    const char* const* argv);

void zwasm_wasi_config_set_envs(
    zwasm_wasi_config_t*,
    size_t count,
    const char* const* keys,
    const char* const* vals);

/*
 * Host-directory preopen (`zwasm_wasi_config_preopen_dir`) is
 * deferred to post-v0.1 (ADR-0143 / D-255): opening + serving a
 * preopen needs a library-side `std.Io` token the pure C-API does
 * not yet construct (the CLI's `--dir` has the ambient Init io).
 * Filesystem hosting via the C ABI lands with the io infra (D-251).
 */

/**
 * Install the WASI setup on a Store. Takes ownership of the
 * config — the C host must not call `zwasm_wasi_config_delete`
 * on the same pointer afterwards.
 *
 * Calling twice on the same Store replaces the previous setup
 * (the old config is freed by the binding). Pass `NULL` to
 * uninstall WASI hosting on a Store.
 */
void zwasm_store_set_wasi(wasm_store_t*, zwasm_wasi_config_t*);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // ZWASM_WASI_H
