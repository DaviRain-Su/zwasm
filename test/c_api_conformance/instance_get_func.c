/* zwasm v2 — C-API conformance: zwasm_instance_get_func through the real ABI
 *
 * Exercises the zwasm-specific extension declared in zwasm.h (Phase-16
 * C-surface audit). The function resolves an instance + defined-function
 * index into a fresh, owned wasm_func_t* — a convenience over
 * wasm_instance_exports + wasm_extern_vec_t indexing. This test proves the
 * header declaration matches the exported symbol and the handle is callable:
 *
 *   (module (func (export "f") (result i32) (i32.const 42)))
 *   zwasm_instance_get_func(inst, 0) -> wasm_func_t*  // owned
 *   wasm_func_call(f, {}, results)                     // -> 42
 *
 * Exits 0 iff the resolved func returns 42, the null/out-of-range guards
 * return NULL, and wasm_func_delete releases the owned handle.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <wasm.h>
#include <zwasm.h>

static const uint8_t kModule[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x05, 0x01, 0x01, 0x66,
    0x00, 0x00, 0x0a, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2a, 0x0b,
};

int main(void) {
    int rc = 1;
    wasm_engine_t* engine = wasm_engine_new();
    wasm_store_t* store = engine ? wasm_store_new(engine) : NULL;
    wasm_module_t* module = NULL;
    wasm_instance_t* instance = NULL;
    wasm_func_t* f = NULL;
    if (!engine || !store) { fputs("engine/store new failed\n", stderr); goto cleanup; }

    wasm_byte_vec_t binary = { sizeof(kModule), (wasm_byte_t*) kModule };
    module = wasm_module_new(store, &binary);
    if (!module) { fputs("wasm_module_new failed\n", stderr); goto cleanup; }

    wasm_extern_vec_t imports = { 0, NULL };
    instance = wasm_instance_new(store, module, &imports, NULL);
    if (!instance) { fputs("wasm_instance_new failed\n", stderr); goto cleanup; }

    /* Null-tolerance + out-of-range guards return NULL (not a crash). */
    if (zwasm_instance_get_func(NULL, 0) != NULL) { fputs("null instance not NULL\n", stderr); goto cleanup; }
    if (zwasm_instance_get_func(instance, 9999) != NULL) { fputs("out-of-range idx not NULL\n", stderr); goto cleanup; }

    f = zwasm_instance_get_func(instance, 0);
    if (!f) { fputs("zwasm_instance_get_func(inst, 0) returned NULL\n", stderr); goto cleanup; }

    wasm_val_vec_t args = { 0, NULL };
    wasm_val_t rdata[1];
    memset(rdata, 0, sizeof(rdata));
    wasm_val_vec_t results = { 1, rdata };
    wasm_trap_t* trap = wasm_func_call(f, &args, &results);
    if (trap) { fputs("f() trapped\n", stderr); wasm_trap_delete(trap); goto cleanup; }

    printf("zwasm c_api_conformance/instance_get_func: f()=%d\n", rdata[0].of.i32);
    rc = (rdata[0].kind == WASM_I32 && rdata[0].of.i32 == 42) ? 0 : 2;

cleanup:
    if (f) wasm_func_delete(f);
    if (instance) wasm_instance_delete(instance);
    if (module) wasm_module_delete(module);
    if (store) wasm_store_delete(store);
    if (engine) wasm_engine_delete(engine);
    return rc;
}
