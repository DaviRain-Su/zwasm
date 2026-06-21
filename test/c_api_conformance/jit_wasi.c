/* zwasm v2 — JIT + WASI host-fn dispatch (ADR-0200 / D-478 item 1).
 *
 * A JIT-backed instance with a WASI host attached must dispatch WASI host
 * functions for real (not the compute-only no-op stub). The guest imports
 * `clock_time_get`, calls it into linear memory, and returns the loaded i64:
 *
 *   (func (export "now") (result i64)
 *     (i32.const 0)(i64.const 0)(i32.const 0)(call $clock_time_get)(drop)
 *     (i64.load))
 *
 * With the host wired, the realtime clock writes nonzero nanoseconds → now() > 0.
 * Without it (the pre-D-478 gap), the stub no-ops and now() == 0. Run by
 * `test-c-api-conformance`.
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <wasm.h>
#include <wasi.h>
#include <zwasm.h>

/* (module
 *   (import "wasi_snapshot_preview1" "clock_time_get" (func (param i32 i64 i32) (result i32)))
 *   (memory 1)
 *   (func (export "now") (result i64)
 *     i32.const 0 i64.const 0 i32.const 0 call 0 drop i64.load)) */
static const uint8_t kClockWasm[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x0c, 0x02, 0x60, 0x03, 0x7f, 0x7e, 0x7f, 0x01, 0x7f, 0x60, 0x00, 0x01, 0x7e,
    0x02, 0x29, 0x01,
    0x16, 0x77, 0x61, 0x73, 0x69, 0x5f, 0x73, 0x6e, 0x61, 0x70, 0x73, 0x68, 0x6f, 0x74, 0x5f, 0x70, 0x72, 0x65, 0x76, 0x69, 0x65, 0x77, 0x31,
    0x0e, 0x63, 0x6c, 0x6f, 0x63, 0x6b, 0x5f, 0x74, 0x69, 0x6d, 0x65, 0x5f, 0x67, 0x65, 0x74,
    0x00, 0x00,
    0x03, 0x02, 0x01, 0x01,
    0x05, 0x03, 0x01, 0x00, 0x01,
    0x07, 0x07, 0x01, 0x03, 0x6e, 0x6f, 0x77, 0x00, 0x01,
    0x0a, 0x12, 0x01, 0x10, 0x00, 0x41, 0x00, 0x42, 0x00, 0x41, 0x00, 0x10, 0x00, 0x1a, 0x41, 0x00, 0x29, 0x03, 0x00, 0x0b,
};

int main(void) {
    int rc = 1;
    wasm_engine_t* engine = wasm_engine_new();
    wasm_store_t* store = engine ? wasm_store_new(engine) : NULL;
    wasm_module_t* module = NULL;
    wasm_instance_t* instance = NULL;
    wasm_extern_vec_t exports = { 0, NULL };
    if (!engine || !store) { fputs("engine/store new failed\n", stderr); goto cleanup; }

    /* Attach a default WASI host to the store (engine io is wired in). */
    zwasm_wasi_config_t* cfg = zwasm_wasi_config_new();
    if (!cfg) { fputs("wasi config new failed\n", stderr); goto cleanup; }
    zwasm_store_set_wasi(store, cfg); /* takes ownership */

    wasm_byte_vec_t binary = { sizeof(kClockWasm), (wasm_byte_t*) kClockWasm };
    module = wasm_module_new(store, &binary);
    if (!module) { fputs("wasm_module_new failed\n", stderr); goto cleanup; }

    wasm_extern_vec_t imports = { 0, NULL };
    wasm_trap_t* itrap = NULL;
    instance = zwasm_instance_new_ex(store, module, &imports, &itrap, ZWASM_ENGINE_JIT);
    if (!instance) { fputs("zwasm_instance_new_ex(JIT) failed\n", stderr); goto cleanup; }

    wasm_instance_exports(instance, &exports);
    if (exports.size < 1 || !exports.data[0] || wasm_extern_kind(exports.data[0]) != WASM_EXTERN_FUNC) {
        fputs("missing now export\n", stderr);
        goto cleanup;
    }
    wasm_func_t* now_fn = wasm_extern_as_func(exports.data[0]);

    wasm_val_vec_t no_args = { 0, NULL };
    wasm_val_t res_data[1];
    memset(res_data, 0, sizeof(res_data));
    wasm_val_vec_t res = { 1, res_data };
    if (wasm_func_call(now_fn, &no_args, &res)) { fputs("now() trapped\n", stderr); goto cleanup; }

    if (res_data[0].kind != WASM_I64 || res_data[0].of.i64 <= 0) {
        fprintf(stderr, "now() = %lld <= 0 (WASI clock host not wired under JIT)\n",
                (long long) res_data[0].of.i64);
        goto cleanup;
    }

    printf("zwasm c_api_conformance/jit_wasi: clock_time_get under JIT → %lld ns\n",
           (long long) res_data[0].of.i64);
    rc = 0;

cleanup:
    if (exports.data) wasm_extern_vec_delete(&exports);
    if (instance) wasm_instance_delete(instance);
    if (module) wasm_module_delete(module);
    if (store) wasm_store_delete(store);
    if (engine) wasm_engine_delete(engine);
    return rc;
}
