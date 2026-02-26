// integer_overflow.c — integer arithmetic edge cases (unsigned wrapping, division)
#include <stdio.h>
#include <stdint.h>
#include <limits.h>

int main(void) {
    // Unsigned overflow wrapping
    uint32_t u = UINT32_MAX;
    u += 1;
    printf("uint32 wrap: %u\n", u); // 0

    // Signed overflow (implementation-defined in C, but consistent in wasm)
    int32_t s = INT32_MAX;
    uint32_t result = (uint32_t)s + 1; // avoid UB, cast first
    printf("int32 max+1 as uint: %u\n", result); // 2147483648

    // Division edge cases
    printf("div: %d\n", 100 / 7);    // 14
    printf("mod: %d\n", 100 % 7);    // 2
    printf("neg div: %d\n", -100 / 7); // -14
    printf("neg mod: %d\n", -100 % 7); // -2

    // 64-bit multiply
    uint64_t a = 0xFFFFFFFF;
    uint64_t b = 0xFFFFFFFF;
    uint64_t product = a * b;
    printf("64bit mul: %llu\n", (unsigned long long)product); // 18446744065119617025

    // Shift edge cases
    printf("lsh: %u\n", 1u << 31);  // 2147483648
    printf("rsh: %u\n", UINT32_MAX >> 16); // 65535

    return 0;
}
