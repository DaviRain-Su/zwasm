/* zwasm v2 — C-API conformance: call a funcref returned from a call (D-269B)
 *
 * The sibling of funcref_table_call.c (path A). Here the funcref is
 * obtained from a CALL RESULT's `of.ref`, the standard wasm-c-api way
 * a host receives a reference value:
 *
 *   wasm_func_call(get, {}, results)        // results[0] : funcref
 *   wasm_ref_as_func(results[0].of.ref)     // -> wasm_func_t*
 *   wasm_func_call(f, ...)                   // -> 42
 *
 *   (module
 *     (func (;0;) (result i32) (i32.const 42))
 *     (func (export "get") (result funcref) (ref.func 0)))
 *
 * Exits 0 iff the returned funcref is a usable, callable reference —
 * i.e. `marshalValOut` hands the embedder an owned `wasm_ref_t*` in
 * `of.ref`, not a raw `*FuncEntity` payload (D-269 path B). The module
 * also exports a table so a single binary covers both, but this test
 * exercises only the call-result path; export order: [0]=get, [1]=t.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <wasm.h>

static const uint8_t kFuncrefWasm[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x09, 0x02, 0x60,
    0x00, 0x01, 0x7f, 0x60, 0x00, 0x01, 0x70, 0x03, 0x03, 0x02, 0x00, 0x01,
    0x04, 0x05, 0x01, 0x70, 0x01, 0x01, 0x01, 0x07, 0x0b, 0x02, 0x03, 0x67,
    0x65, 0x74, 0x00, 0x01, 0x01, 0x74, 0x01, 0x00, 0x09, 0x07, 0x01, 0x00,
    0x41, 0x00, 0x0b, 0x01, 0x00, 0x0a, 0x0b, 0x02, 0x04, 0x00, 0x41, 0x2a,
    0x0b, 0x04, 0x00, 0xd2, 0x00, 0x0b,
};

int main(void) {
    int rc = 1;
    wasm_engine_t* engine = wasm_engine_new();
    wasm_store_t* store = engine ? wasm_store_new(engine) : NULL;
    wasm_module_t* module = NULL;
    wasm_instance_t* instance = NULL;
    wasm_extern_vec_t exports = { 0, NULL };
    if (!engine || !store) { fputs("engine/store new failed\n", stderr); goto cleanup; }

    wasm_byte_vec_t binary = { sizeof(kFuncrefWasm), (wasm_byte_t*) kFuncrefWasm };
    module = wasm_module_new(store, &binary);
    if (!module) { fputs("wasm_module_new failed\n", stderr); goto cleanup; }

    wasm_extern_vec_t imports = { 0, NULL };
    instance = wasm_instance_new(store, module, &imports, NULL);
    if (!instance) { fputs("wasm_instance_new failed\n", stderr); goto cleanup; }

    wasm_instance_exports(instance, &exports);
    if (exports.size < 1 || !exports.data[0]) { fputs("no exports\n", stderr); goto cleanup; }
    wasm_func_t* getf = wasm_extern_as_func(exports.data[0]);
    if (!getf) { fputs("export[0] not a func\n", stderr); goto cleanup; }

    /* Call get() -> funcref result, read via results[0].of.ref. */
    wasm_val_vec_t gargs = { 0, NULL };
    wasm_val_t gres[1];
    memset(gres, 0, sizeof(gres));
    wasm_val_vec_t gresults = { 1, gres };
    wasm_trap_t* gtrap = wasm_func_call(getf, &gargs, &gresults);
    if (gtrap) { fputs("get() trapped\n", stderr); wasm_trap_delete(gtrap); goto cleanup; }
    if (gres[0].kind != WASM_FUNCREF) { fprintf(stderr, "result kind %d != WASM_FUNCREF\n", gres[0].kind); goto cleanup; }
    if (!gres[0].of.ref) { fputs("get() returned null funcref\n", stderr); goto cleanup; }

    wasm_func_t* f = wasm_ref_as_func(gres[0].of.ref);
    if (!f) { fputs("call-result funcref (of.ref) not recoverable as a callable func\n", stderr); goto cleanup; }

    wasm_val_vec_t args = { 0, NULL };
    wasm_val_t rdata[1];
    memset(rdata, 0, sizeof(rdata));
    wasm_val_vec_t results = { 1, rdata };
    wasm_trap_t* trap = wasm_func_call(f, &args, &results);
    if (trap) { fputs("calling the result funcref trapped\n", stderr); wasm_trap_delete(trap); goto cleanup; }

    printf("zwasm c_api_conformance/funcref_result_call: get()()=%d\n", rdata[0].of.i32);
    rc = (rdata[0].kind == WASM_I32 && rdata[0].of.i32 == 42) ? 0 : 2;

    /* Adversarial (D-269B): of.ref is a caller-owned wasm_ref_t*.
     * (1) idempotent double-delete — wasm_val_delete nulls of.ref, so a
     *     second delete is a no-op, not a double-free.
     * (2) repeated alloc/free — every call-result ref is paired with a
     *     delete; under -Dsanitize=address this catches leak/UAF. */
    wasm_val_delete(&gres[0]);
    wasm_val_delete(&gres[0]);
    for (int k = 0; rc == 0 && k < 64; k++) {
        wasm_val_t lr[1];
        memset(lr, 0, sizeof(lr));
        wasm_val_vec_t lrv = { 1, lr };
        wasm_trap_t* lt = wasm_func_call(getf, &gargs, &lrv);
        if (lt) { wasm_trap_delete(lt); rc = 3; break; }
        if (!(lr[0].kind == WASM_FUNCREF && lr[0].of.ref && wasm_ref_as_func(lr[0].of.ref))) { rc = 4; }
        wasm_val_delete(&lr[0]);
    }

cleanup:
    if (exports.data) wasm_extern_vec_delete(&exports);
    if (instance) wasm_instance_delete(instance);
    if (module) wasm_module_delete(module);
    if (store) wasm_store_delete(store);
    if (engine) wasm_engine_delete(engine);
    return rc;
}
