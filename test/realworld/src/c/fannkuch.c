// fannkuch.c — the classic embenchen / Computer Language Benchmarks Game
// "fannkuch-redux" kernel: count pancake flips over all permutations of n.
// Deterministic stdout (checksum + max flips) for byte-diff vs wasmtime.
// Regenerated for v2 via modern emcc -sSTANDALONE_WASM (WASI), NOT the legacy
// emscripten env-shim ABI of the vendored embenchen_* fixtures (D-026, Phase 11).
#include <stdio.h>
#include <string.h>

static int fannkuch(int n) {
    int perm[32];
    int perm1[32];
    int count[32];
    int max_flips = 0;
    int checksum = 0;
    int sign = 1;
    int r;

    for (int i = 0; i < n; i++) perm1[i] = i;
    r = n;

    while (1) {
        while (r != 1) {
            count[r - 1] = r;
            r--;
        }

        memcpy(perm, perm1, n * sizeof(int));
        int flips = 0;
        int k;
        while ((k = perm[0]) != 0) {
            int k2 = (k + 1) >> 1;
            for (int i = 0; i < k2; i++) {
                int tmp = perm[i];
                perm[i] = perm[k - i];
                perm[k - i] = tmp;
            }
            flips++;
        }

        if (flips > max_flips) max_flips = flips;
        checksum += sign * flips;

        // Next permutation (Mislav Marohnić's array-rotation generator).
        while (1) {
            if (r == n) return max_flips ? (printf("checksum: %d\n", checksum), max_flips) : max_flips;
            int perm0 = perm1[0];
            int i = 0;
            while (i < r) {
                int j = i + 1;
                perm1[i] = perm1[j];
                i = j;
            }
            perm1[r] = perm0;
            count[r] -= 1;
            if (count[r] > 0) break;
            r++;
        }
        sign = -sign;
    }
}

int main(void) {
    int n = 9;
    int max_flips = fannkuch(n);
    printf("Pfannkuchen(%d) = %d\n", n, max_flips);
    return 0;
}
