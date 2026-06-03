/* zwasm v2 — C-API conformance: host callback (§13.4)
 *
 * Validates the §13.2 host-function machinery end-to-end through the
 * real wasm-c-api C ABI (not just Zig tests): a host callback created
 * with `wasm_func_new`, passed as an import, and invoked by the guest's
 * `call`. Mirrors the upstream wasm-c-api `callback` example shape.
 *
 *   (module
 *     (import "env" "h" (func (param i32) (result i32)))
 *     (func (export "f") (param i32) (result i32) (local.get 0) (call 0)))
 *
 * The host `h` returns arg + 1; `f(41)` must yield 42. Exits 0 on success.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <wasm.h>

static const uint8_t kCallbackWasm[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x06, 0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f, /* type (i32)->(i32) */
    0x02, 0x09, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x01, 0x68, 0x00, 0x00, /* import env.h */
    0x03, 0x02, 0x01, 0x00, /* func[1]: type 0 (defined) */
    0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x01, /* export "f" -> funcidx 1 */
    0x0a, 0x08, 0x01, 0x06, 0x00, 0x20, 0x00, 0x10, 0x00, 0x0b, /* local.get 0; call 0 */
};

/* host callback: results[0] = args[0] + 1 */
static wasm_trap_t* add_one(const wasm_val_vec_t* args, wasm_val_vec_t* results) {
    results->data[0].kind = WASM_I32;
    results->data[0].of.i32 = args->data[0].of.i32 + 1;
    return NULL;
}

int main(void) {
    int rc = 1;
    wasm_engine_t* engine = wasm_engine_new();
    wasm_store_t* store = engine ? wasm_store_new(engine) : NULL;
    wasm_functype_t* ft = NULL;
    wasm_func_t* host_fn = NULL;
    wasm_module_t* module = NULL;
    wasm_instance_t* instance = NULL;
    wasm_extern_vec_t exports = { 0, NULL };
    if (!engine || !store) { fputs("engine/store new failed\n", stderr); goto cleanup; }

    /* host func (i32)->(i32) via wasm_func_new */
    ft = wasm_functype_new_1_1(wasm_valtype_new(WASM_I32), wasm_valtype_new(WASM_I32));
    host_fn = wasm_func_new(store, ft, add_one);
    if (!host_fn) { fputs("wasm_func_new failed\n", stderr); goto cleanup; }

    wasm_byte_vec_t binary = { sizeof(kCallbackWasm), (wasm_byte_t*) kCallbackWasm };
    module = wasm_module_new(store, &binary);
    if (!module) { fputs("wasm_module_new failed\n", stderr); goto cleanup; }

    wasm_extern_t* import_externs[1] = { wasm_func_as_extern(host_fn) };
    wasm_extern_vec_t imports = { 1, import_externs };
    instance = wasm_instance_new(store, module, &imports, NULL);
    if (!instance) { fputs("wasm_instance_new failed\n", stderr); goto cleanup; }

    wasm_instance_exports(instance, &exports);
    if (exports.size < 1 || !exports.data[0]) { fputs("no exports\n", stderr); goto cleanup; }
    wasm_func_t* f = wasm_extern_as_func(exports.data[0]);
    if (!f) { fputs("export not a func\n", stderr); goto cleanup; }

    wasm_val_t args_data[1] = { { .kind = WASM_I32, .of = { .i32 = 41 } } };
    wasm_val_vec_t args = { 1, args_data };
    wasm_val_t results_data[1];
    memset(results_data, 0, sizeof(results_data));
    wasm_val_vec_t results = { 1, results_data };

    wasm_trap_t* trap = wasm_func_call(f, &args, &results);
    if (trap) { fputs("guest call trapped\n", stderr); wasm_trap_delete(trap); goto cleanup; }

    printf("zwasm c_api_conformance/callback: f(41) = %d\n", results_data[0].of.i32);
    rc = (results_data[0].kind == WASM_I32 && results_data[0].of.i32 == 42) ? 0 : 2;

cleanup:
    if (exports.data) wasm_extern_vec_delete(&exports);
    if (instance) wasm_instance_delete(instance);
    if (module) wasm_module_delete(module);
    if (host_fn) wasm_func_delete(host_fn);
    if (ft) wasm_functype_delete(ft);
    if (store) wasm_store_delete(store);
    if (engine) wasm_engine_delete(engine);
    return rc;
}
