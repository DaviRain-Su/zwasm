/* zwasm v2 — C mini-consumer for the JIT-backed embedding API (ADR-0200).
 *
 * Demonstrates a first-party C embedder selecting the JIT engine per-instance
 * via the `zwasm_instance_new_ex` extension (include/zwasm.h), then driving it
 * through the *standard* wasm-c-api call path (instance_exports -> extern_as_func
 * -> func_call). One module exports both:
 *
 *   (func (export "add")   (param i32 i32) (result i32) ...)   ; multi-arg
 *   (func (export "lane0") (result i32) i32x4.extract_lane 0
 *                          (v128.const i32x4 42 0 0 0))         ; SIMD body
 *
 * `add(2,3) == 5` exercises the JIT multi-arg invoke; `lane0() == 42` proves a
 * SIMD body executes on the JIT (the user's "SIMD must be JIT" constraint, met
 * at a scalar boundary). Exit 0 on success. Run by `test-c-api-conformance`.
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <wasm.h>
#include <zwasm.h>

/* (module
 *   (func (export "add") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add)
 *   (func (export "lane0") (result i32)
 *     (i32x4.extract_lane 0 (v128.const i32x4 42 0 0 0)))) */
static const uint8_t kJitWasm[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x0b, 0x02, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x00, 0x01, 0x7f,
    0x03, 0x03, 0x02, 0x00, 0x01,
    0x07, 0x0f, 0x02, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00, 0x05, 0x6c, 0x61, 0x6e, 0x65, 0x30, 0x00, 0x01,
    0x0a, 0x21, 0x02,
    0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b,
    0x17, 0x00, 0xfd, 0x0c, 0x2a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfd, 0x1b, 0x00, 0x0b,
};

static wasm_func_t* export_func(const wasm_extern_vec_t* exports, size_t i) {
    if (i >= exports->size || !exports->data[i]) return NULL;
    if (wasm_extern_kind(exports->data[i]) != WASM_EXTERN_FUNC) return NULL;
    return wasm_extern_as_func(exports->data[i]);
}

int main(void) {
    int rc = 1;
    wasm_engine_t* engine = wasm_engine_new();
    wasm_store_t* store = engine ? wasm_store_new(engine) : NULL;
    wasm_module_t* module = NULL;
    wasm_instance_t* instance = NULL;
    wasm_extern_vec_t exports = { 0, NULL };
    if (!engine || !store) { fputs("engine/store new failed\n", stderr); goto cleanup; }

    wasm_byte_vec_t binary = { sizeof(kJitWasm), (wasm_byte_t*) kJitWasm };
    module = wasm_module_new(store, &binary);
    if (!module) { fputs("wasm_module_new failed\n", stderr); goto cleanup; }

    /* The JIT engine knob — the only zwasm-specific call; everything else is
     * stock wasm-c-api, so an embedder opts into JIT with one line. */
    wasm_extern_vec_t imports = { 0, NULL };
    wasm_trap_t* itrap = NULL;
    instance = zwasm_instance_new_ex(store, module, &imports, &itrap, ZWASM_ENGINE_JIT);
    if (!instance) { fputs("zwasm_instance_new_ex(JIT) failed\n", stderr); goto cleanup; }

    wasm_instance_exports(instance, &exports);
    wasm_func_t* add_fn = export_func(&exports, 0);
    wasm_func_t* lane0_fn = export_func(&exports, 1);
    if (!add_fn || !lane0_fn) { fputs("missing add/lane0 export\n", stderr); goto cleanup; }

    /* add(2, 3) == 5 — JIT multi-arg invoke. */
    wasm_val_t add_args_data[2] = {
        { .kind = WASM_I32, .of = { .i32 = 2 } },
        { .kind = WASM_I32, .of = { .i32 = 3 } },
    };
    wasm_val_vec_t add_args = { 2, add_args_data };
    wasm_val_t add_res_data[1];
    memset(add_res_data, 0, sizeof(add_res_data));
    wasm_val_vec_t add_res = { 1, add_res_data };
    if (wasm_func_call(add_fn, &add_args, &add_res)) { fputs("add trapped\n", stderr); goto cleanup; }
    if (add_res_data[0].kind != WASM_I32 || add_res_data[0].of.i32 != 5) {
        fprintf(stderr, "add(2,3) = %d != 5\n", add_res_data[0].of.i32);
        goto cleanup;
    }

    /* lane0() == 42 — SIMD body executes on the JIT, scalar boundary. */
    wasm_val_vec_t no_args = { 0, NULL };
    wasm_val_t lane_res_data[1];
    memset(lane_res_data, 0, sizeof(lane_res_data));
    wasm_val_vec_t lane_res = { 1, lane_res_data };
    if (wasm_func_call(lane0_fn, &no_args, &lane_res)) { fputs("lane0 trapped\n", stderr); goto cleanup; }
    if (lane_res_data[0].kind != WASM_I32 || lane_res_data[0].of.i32 != 42) {
        fprintf(stderr, "lane0() = %d != 42\n", lane_res_data[0].of.i32);
        goto cleanup;
    }

    printf("zwasm c_host (JIT): add(2,3)=%d lane0()=%d\n", add_res_data[0].of.i32, lane_res_data[0].of.i32);
    rc = 0;

cleanup:
    if (exports.data) wasm_extern_vec_delete(&exports);
    if (instance) wasm_instance_delete(instance);
    if (module) wasm_module_delete(module);
    if (store) wasm_store_delete(store);
    if (engine) wasm_engine_delete(engine);
    return rc;
}
