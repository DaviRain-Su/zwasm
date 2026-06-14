// fasta.c — embenchen / Benchmarks Game "fasta" kernel: the canonical
// linear-congruential pseudo-random generator (IM/IA/IC) driving a weighted
// nucleotide selection. Prints a checksum (deterministic) for byte-diff vs
// wasmtime. Modern emcc -sSTANDALONE_WASM (WASI) regeneration, not legacy env-shim.
#include <stdio.h>

#define IM 139968
#define IA 3877
#define IC 29573

static int last = 42;

static double gen_random(double max) {
    last = (last * IA + IC) % IM;
    return max * last / IM;
}

int main(void) {
    // Weighted alphabet (cumulative probabilities) — the IUB table.
    const char syms[] = "acgtBDHKMNRSVWY";
    const double probs[] = {
        0.27, 0.39, 0.51, 0.63, 0.69, 0.75, 0.81, 0.87,
        0.90, 0.93, 0.96, 0.975, 0.99, 0.9975, 1.0,
    };
    const int nsyms = 15;

    unsigned long checksum = 0;
    int counts[15] = {0};
    for (long i = 0; i < 2000000; i++) {
        double r = gen_random(1.0);
        int j = 0;
        while (j < nsyms && r >= probs[j]) j++;
        counts[j]++;
        checksum = (checksum * 31 + (unsigned char)syms[j]) & 0xffffffff;
    }
    printf("fasta checksum: %lu\n", checksum);
    for (int j = 0; j < nsyms; j++) printf("%c:%d ", syms[j], counts[j]);
    printf("\n");
    return 0;
}
