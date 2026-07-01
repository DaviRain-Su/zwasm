/* zwasm v2 — C-API conformance: host callback under the JIT engine (D-478).
 *
 * The JIT analogue of `callback.c`: a host function created with
 * `wasm_func_new`, passed as an import, and invoked by a JIT-compiled guest's
 * `call`. The only zwasm-specific call is `zwasm_instance_new_ex(...JIT)`;
 * everything else is stock wasm-c-api, so an embedder gets host-import dispatch
 * under the JIT with one line.
 *
 *   (module
 *     (import "env" "h" (func (result i32)))
 *     (func (export "f") (result i32) (call 0)))
 *
 * The host `h` returns 42; the JIT-compiled `f()` must yield 42 — proving the
 * comptime host-bridge thunk (jit_host_bridge.zig) planted into the JIT dispatch
 * table reaches the embedder callback. 0-arg -> i32 is the first covered
 * signature (D-478 increment 1); wider arities follow. Exits 0 on success.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <wasm.h>
#include <zwasm.h>

static const uint8_t kCallbackWasm[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,             /* type ()->(i32) */
    0x02, 0x09, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x01, 0x68, 0x00, 0x00, /* import env.h */
    0x03, 0x02, 0x01, 0x00,                               /* func[1]: type 0 (defined) */
    0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x01,             /* export "f" -> funcidx 1 */
    0x0a, 0x06, 0x01, 0x04, 0x00, 0x10, 0x00, 0x0b,       /* body: call 0; end */
};

/* host callback (result i32): returns 42 */
static wasm_trap_t* ret42(const wasm_val_vec_t* args, wasm_val_vec_t* results) {
    (void) args;
    results->data[0].kind = WASM_I32;
    results->data[0].of.i32 = 42;
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

    /* host func ()->(i32) via wasm_func_new */
    ft = wasm_functype_new_0_1(wasm_valtype_new(WASM_I32));
    host_fn = wasm_func_new(store, ft, ret42);
    if (!host_fn) { fputs("wasm_func_new failed\n", stderr); goto cleanup; }

    wasm_byte_vec_t binary = { sizeof(kCallbackWasm), (wasm_byte_t*) kCallbackWasm };
    module = wasm_module_new(store, &binary);
    if (!module) { fputs("wasm_module_new failed\n", stderr); goto cleanup; }

    wasm_extern_t* import_externs[1] = { wasm_func_as_extern(host_fn) };
    wasm_extern_vec_t imports = { 1, import_externs };
    wasm_trap_t* itrap = NULL;
    instance = zwasm_instance_new_ex(store, module, &imports, &itrap, ZWASM_ENGINE_JIT);
    if (!instance) { fputs("zwasm_instance_new_ex(JIT) failed\n", stderr); goto cleanup; }

    wasm_instance_exports(instance, &exports);
    if (exports.size < 1 || !exports.data[0] ||
        wasm_extern_kind(exports.data[0]) != WASM_EXTERN_FUNC) {
        fputs("missing f export\n", stderr);
        goto cleanup;
    }
    wasm_func_t* f = wasm_extern_as_func(exports.data[0]);

    wasm_val_vec_t no_args = { 0, NULL };
    wasm_val_t res_data[1];
    memset(res_data, 0, sizeof(res_data));
    wasm_val_vec_t res = { 1, res_data };
    if (wasm_func_call(f, &no_args, &res)) { fputs("f() trapped\n", stderr); goto cleanup; }
    if (res_data[0].kind != WASM_I32 || res_data[0].of.i32 != 42) {
        fprintf(stderr, "f() = %d != 42\n", res_data[0].of.i32);
        goto cleanup;
    }

    printf("zwasm c_host (JIT host-callback): f()=%d\n", res_data[0].of.i32);
    rc = 0;

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
