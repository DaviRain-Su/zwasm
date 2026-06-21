/* zwasm v2 — C-API conformance: multi-arg host callbacks under JIT (D-478).
 *
 * Extends jit_callback.c (0-arg) to N-scalar-arg host imports: the JIT passes a
 * guest `call`'s args to the dispatch slot in NATIVE arg registers per the
 * callee's exact C signature, so the comptime host-bridge thunk
 * (jit_host_bridge.zig) is signature-specialized per (arg-kinds × result). This
 * exercises the i32×2 -> i32 and i64 -> i64 GP-scalar paths.
 *
 *   add:  (import "env" "h" (func (param i32 i32) (result i32)))
 *         (func (export "f") (param i32 i32) (result i32)
 *           local.get 0  local.get 1  call 0)        ; h(a,b)=a+b -> f(2,3)=5
 *
 *   dbl:  (import "env" "h" (func (param i64) (result i64)))
 *         (func (export "f") (param i64) (result i64)
 *           local.get 0  call 0)                      ; h(x)=x*2 -> f(21)=42
 *
 * Exits 0 on success. Run by `test-c-api-conformance`.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <wasm.h>
#include <zwasm.h>

/* (module (import "env" "h" (func (param i32 i32) (result i32)))
 *   (func (export "f") (param i32 i32) (result i32)
 *     local.get 0 local.get 1 call 0)) */
static const uint8_t kAddWasm[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f, /* type (i32 i32)->(i32) */
    0x02, 0x09, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x01, 0x68, 0x00, 0x00, /* import env.h */
    0x03, 0x02, 0x01, 0x00,                               /* func[1]: type 0 */
    0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x01,             /* export "f" -> 1 */
    0x0a, 0x0a, 0x01, 0x08, 0x00, 0x20, 0x00, 0x20, 0x01, 0x10, 0x00, 0x0b, /* l0 l1 call0 end */
};

/* (module (import "env" "h" (func (param i64) (result i64)))
 *   (func (export "f") (param i64) (result i64) local.get 0 call 0)) */
static const uint8_t kDblWasm[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x06, 0x01, 0x60, 0x01, 0x7e, 0x01, 0x7e,       /* type (i64)->(i64) */
    0x02, 0x09, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x01, 0x68, 0x00, 0x00, /* import env.h */
    0x03, 0x02, 0x01, 0x00,                               /* func[1]: type 0 */
    0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x01,             /* export "f" -> 1 */
    0x0a, 0x08, 0x01, 0x06, 0x00, 0x20, 0x00, 0x10, 0x00, 0x0b, /* l0 call0 end */
};

static wasm_trap_t* host_add(const wasm_val_vec_t* args, wasm_val_vec_t* results) {
    results->data[0].kind = WASM_I32;
    results->data[0].of.i32 = args->data[0].of.i32 + args->data[1].of.i32;
    return NULL;
}

static wasm_trap_t* host_dbl(const wasm_val_vec_t* args, wasm_val_vec_t* results) {
    results->data[0].kind = WASM_I64;
    results->data[0].of.i64 = args->data[0].of.i64 * 2;
    return NULL;
}

/* Build a JIT instance importing host_fn into "env"/"h", call export "f" with
 * `args`, return its single scalar result through `*out` (kind preserved).
 * Returns 1 on success, 0 on any failure. */
static int run_case(wasm_store_t* store, const uint8_t* wasm, size_t wasm_len,
                    wasm_functype_t* ft, wasm_func_callback_t cb,
                    wasm_val_vec_t* args, wasm_val_t* out) {
    int ok = 0;
    wasm_func_t* host_fn = wasm_func_new(store, ft, cb);
    wasm_module_t* module = NULL;
    wasm_instance_t* instance = NULL;
    wasm_extern_vec_t exports = { 0, NULL };
    if (!host_fn) goto done;

    wasm_byte_vec_t binary = { wasm_len, (wasm_byte_t*) wasm };
    module = wasm_module_new(store, &binary);
    if (!module) goto done;

    wasm_extern_t* import_externs[1] = { wasm_func_as_extern(host_fn) };
    wasm_extern_vec_t imports = { 1, import_externs };
    wasm_trap_t* itrap = NULL;
    instance = zwasm_instance_new_ex(store, module, &imports, &itrap, ZWASM_ENGINE_JIT);
    if (!instance) goto done;

    wasm_instance_exports(instance, &exports);
    if (exports.size < 1 || !exports.data[0] ||
        wasm_extern_kind(exports.data[0]) != WASM_EXTERN_FUNC) goto done;
    wasm_func_t* f = wasm_extern_as_func(exports.data[0]);

    wasm_val_t res_data[1];
    memset(res_data, 0, sizeof(res_data));
    wasm_val_vec_t res = { 1, res_data };
    if (wasm_func_call(f, args, &res)) goto done;
    *out = res_data[0];
    ok = 1;

done:
    if (exports.data) wasm_extern_vec_delete(&exports);
    if (instance) wasm_instance_delete(instance);
    if (module) wasm_module_delete(module);
    if (host_fn) wasm_func_delete(host_fn);
    return ok;
}

int main(void) {
    int rc = 1;
    wasm_engine_t* engine = wasm_engine_new();
    wasm_store_t* store = engine ? wasm_store_new(engine) : NULL;
    wasm_functype_t* ft_add = NULL;
    wasm_functype_t* ft_dbl = NULL;
    if (!engine || !store) { fputs("engine/store new failed\n", stderr); goto cleanup; }

    /* add(i32,i32)->i32: f(2,3) == 5 */
    wasm_valtype_t* add_ps[2] = { wasm_valtype_new(WASM_I32), wasm_valtype_new(WASM_I32) };
    wasm_valtype_vec_t add_params, add_results;
    wasm_valtype_vec_new(&add_params, 2, add_ps);
    wasm_valtype_t* add_r[1] = { wasm_valtype_new(WASM_I32) };
    wasm_valtype_vec_new(&add_results, 1, add_r);
    ft_add = wasm_functype_new(&add_params, &add_results);

    wasm_val_t add_args_data[2] = {
        { .kind = WASM_I32, .of = { .i32 = 2 } },
        { .kind = WASM_I32, .of = { .i32 = 3 } },
    };
    wasm_val_vec_t add_args = { 2, add_args_data };
    wasm_val_t add_out;
    memset(&add_out, 0, sizeof(add_out));
    if (!run_case(store, kAddWasm, sizeof(kAddWasm), ft_add, host_add, &add_args, &add_out)) {
        fputs("add case failed\n", stderr); goto cleanup;
    }
    if (add_out.kind != WASM_I32 || add_out.of.i32 != 5) {
        fprintf(stderr, "add f(2,3) = %d != 5\n", add_out.of.i32); goto cleanup;
    }

    /* dbl(i64)->i64: f(21) == 42 */
    ft_dbl = wasm_functype_new_1_1(wasm_valtype_new(WASM_I64), wasm_valtype_new(WASM_I64));
    wasm_val_t dbl_args_data[1] = { { .kind = WASM_I64, .of = { .i64 = 21 } } };
    wasm_val_vec_t dbl_args = { 1, dbl_args_data };
    wasm_val_t dbl_out;
    memset(&dbl_out, 0, sizeof(dbl_out));
    if (!run_case(store, kDblWasm, sizeof(kDblWasm), ft_dbl, host_dbl, &dbl_args, &dbl_out)) {
        fputs("dbl case failed\n", stderr); goto cleanup;
    }
    if (dbl_out.kind != WASM_I64 || dbl_out.of.i64 != 42) {
        fprintf(stderr, "dbl f(21) = %lld != 42\n", (long long) dbl_out.of.i64); goto cleanup;
    }

    printf("zwasm c_host (JIT N-arg): add(2,3)=%d dbl(21)=%lld\n",
           add_out.of.i32, (long long) dbl_out.of.i64);
    rc = 0;

cleanup:
    if (ft_add) wasm_functype_delete(ft_add);
    if (ft_dbl) wasm_functype_delete(ft_dbl);
    if (store) wasm_store_delete(store);
    if (engine) wasm_engine_delete(engine);
    return rc;
}
