// SIMD benchmark: chained v128 operations (Q-cache stress test)
// Tests consecutive SIMD ops on the same registers — ideal for Q-cache.
// Usage: simd_chain.wasm
// Build: wasm32-wasi-clang -O2 -msimd128 -o simd_chain.wasm simd_chain.c

#include <wasm_simd128.h>
#include <stdint.h>
#include <stdio.h>

#define ARRAY_SIZE (1024 * 64)  // 64K floats = 256KB
#define ITERATIONS 100

static float data_a[ARRAY_SIZE] __attribute__((aligned(16)));
static float data_b[ARRAY_SIZE] __attribute__((aligned(16)));
static float data_c[ARRAY_SIZE] __attribute__((aligned(16)));

static void init(void) {
    for (int i = 0; i < ARRAY_SIZE; i++) {
        data_a[i] = (float)(i % 97) * 0.01f + 1.0f;
        data_b[i] = (float)(i % 53) * 0.01f + 0.5f;
    }
}

// Test 1: Vector FMA chain (a*b+c repeatedly) — tests register reuse
static float test_fma_chain(void) {
    for (int iter = 0; iter < ITERATIONS; iter++) {
        for (int i = 0; i < ARRAY_SIZE; i += 4) {
            v128_t va = wasm_v128_load(&data_a[i]);
            v128_t vb = wasm_v128_load(&data_b[i]);
            // Chain: c = a*b; c = c+a; c = c*b; c = c+a (4 dependent ops)
            v128_t vc = wasm_f32x4_mul(va, vb);
            vc = wasm_f32x4_add(vc, va);
            vc = wasm_f32x4_mul(vc, vb);
            vc = wasm_f32x4_add(vc, va);
            wasm_v128_store(&data_c[i], vc);
        }
    }
    return data_c[0];
}

// Test 2: Dot product (reduction) — tests extract_lane + accumulate
static float test_dot_product(void) {
    float total = 0.0f;
    for (int iter = 0; iter < ITERATIONS; iter++) {
        v128_t sum = wasm_f32x4_splat(0.0f);
        for (int i = 0; i < ARRAY_SIZE; i += 4) {
            v128_t va = wasm_v128_load(&data_a[i]);
            v128_t vb = wasm_v128_load(&data_b[i]);
            sum = wasm_f32x4_add(sum, wasm_f32x4_mul(va, vb));
        }
        total = wasm_f32x4_extract_lane(sum, 0) +
                wasm_f32x4_extract_lane(sum, 1) +
                wasm_f32x4_extract_lane(sum, 2) +
                wasm_f32x4_extract_lane(sum, 3);
    }
    return total;
}

// Test 3: Interleaved i32x4 + f32x4 ops — tests mixed SIMD types
static float test_mixed_types(void) {
    for (int iter = 0; iter < ITERATIONS; iter++) {
        for (int i = 0; i < ARRAY_SIZE; i += 4) {
            v128_t va = wasm_v128_load(&data_a[i]);
            v128_t vb = wasm_v128_load(&data_b[i]);
            // Float multiply
            v128_t vf = wasm_f32x4_mul(va, vb);
            // Reinterpret as int, do bitwise AND with mask
            v128_t vi = wasm_v128_and(vf, wasm_i32x4_splat(0x7FFFFFFF)); // abs via mask
            // Convert back to float context
            v128_t vr = wasm_f32x4_add(vi, va);
            wasm_v128_store(&data_c[i], vr);
        }
    }
    return data_c[0];
}

int main(void) {
    init();

    float r1 = test_fma_chain();
    printf("fma_chain:   %.6f\n", r1);

    float r2 = test_dot_product();
    printf("dot_product: %.6f\n", r2);

    float r3 = test_mixed_types();
    printf("mixed_types: %.6f\n", r3);

    return 0;
}
