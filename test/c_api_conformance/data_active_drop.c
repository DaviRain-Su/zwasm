/* zwasm v2 — C-API conformance: active data segments are dropped at
 * instantiation (Wasm spec §4.5.4 step 15). ADR-0192 (wasmtime
 * misc_testsuite/memory_init differential).
 *
 * Regression: the C-API instantiate path (instantiateRuntime) wrote an
 * active data segment to memory but forgot to mark it dropped (the elem
 * path already did). So a later `memory.init` referencing the active
 * segment read its still-present bytes instead of seeing a 0-length
 * source — no out-of-bounds trap. The native engine paths (setupRuntime /
 * populateDataSegments) already dropped correctly, so the synthetic spec
 * suite (which runs them) never caught the C-API divergence.
 *
 *   (module
 *     (memory 1)
 *     (data (i32.const 0) "hi2")            ;; active → dropped at instantiate
 *     (func (export "test") (result i32)
 *       (memory.init 0 (i32.const 10) (i32.const 1) (i32.const 1))  ;; src OOB on
 *       (i32.const 0)))                                              ;; the empty seg
 *
 * Exits 0 iff calling "test" TRAPS (out-of-bounds) — i.e. the active
 * segment was dropped. Pre-fix it returned 0 (no trap).
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include <wasm.h>

static const uint8_t kWasm[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x05, 0x03, 0x01, 0x00, 0x01,
    0x07, 0x08, 0x01, 0x04, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x0c, 0x01,
    0x01, 0x0a, 0x10, 0x01, 0x0e, 0x00, 0x41, 0x0a, 0x41, 0x01, 0x41, 0x01,
    0xfc, 0x08, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x0b, 0x09, 0x01, 0x00, 0x41,
    0x00, 0x0b, 0x03, 0x68, 0x69, 0x32,
};

int main(void) {
    int rc = 1;
    wasm_engine_t* engine = wasm_engine_new();
    wasm_store_t* store = engine ? wasm_store_new(engine) : NULL;
    wasm_module_t* module = NULL;
    wasm_instance_t* instance = NULL;
    wasm_extern_vec_t exports = { 0, NULL };
    if (!engine || !store) { fputs("engine/store new failed\n", stderr); goto cleanup; }

    wasm_byte_vec_t binary = { sizeof(kWasm), (wasm_byte_t*) kWasm };
    module = wasm_module_new(store, &binary);
    if (!module) { fputs("wasm_module_new failed\n", stderr); goto cleanup; }

    wasm_extern_vec_t imports = { 0, NULL };
    instance = wasm_instance_new(store, module, &imports, NULL);
    if (!instance) { fputs("wasm_instance_new failed\n", stderr); goto cleanup; }

    wasm_instance_exports(instance, &exports);
    if (exports.size < 1 || !exports.data[0]) { fputs("no exports\n", stderr); goto cleanup; }
    wasm_func_t* testf = wasm_extern_as_func(exports.data[0]);
    if (!testf) { fputs("export[0] not a func\n", stderr); goto cleanup; }

    wasm_val_t rdata[1] = { { .kind = WASM_I32 } };
    wasm_val_vec_t args = { 0, NULL };
    wasm_val_vec_t results = { 1, rdata };
    wasm_trap_t* trap = wasm_func_call(testf, &args, &results);
    if (!trap) {
        fputs("FAIL: memory.init from a dropped active data segment did NOT trap "
              "(active segment not dropped at instantiation)\n", stderr);
        goto cleanup;
    }
    /* Correct: the active segment was dropped, so memory.init src is OOB. */
    wasm_trap_delete(trap);
    rc = 0;

cleanup:
    if (exports.data) wasm_extern_vec_delete(&exports);
    if (instance) wasm_instance_delete(instance);
    if (module) wasm_module_delete(module);
    if (store) wasm_store_delete(store);
    if (engine) wasm_engine_delete(engine);
    return rc;
}
