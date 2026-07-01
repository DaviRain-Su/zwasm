// primes.c — embenchen "primes" kernel: trial-division prime counting, a
// branch-and-integer-arithmetic-heavy compute loop. Prints the count
// (deterministic) for byte-diff vs wasmtime. Modern emcc -sSTANDALONE_WASM (WASI).
#include <stdio.h>

static int is_prime(int n) {
    if (n < 2) return 0;
    if (n % 2 == 0) return n == 2;
    for (int d = 3; d * d <= n; d += 2) {
        if (n % d == 0) return 0;
    }
    return 1;
}

int main(void) {
    int count = 0;
    long sum = 0;
    for (int n = 2; n < 200000; n++) {
        if (is_prime(n)) {
            count++;
            sum += n;
        }
    }
    printf("primes below 200000: %d (sum=%ld)\n", count, sum);
    return 0;
}
