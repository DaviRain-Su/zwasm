// bitwise_ops.c — bitwise operation stress test
#include <stdio.h>
#include <stdint.h>

int main(void) {
    uint32_t a = 0xDEADBEEF;
    uint32_t b = 0xCAFEBABE;
    uint64_t checksum = 0;

    for (int i = 0; i < 10000; i++) {
        uint32_t x = a ^ b;
        uint32_t y = (a & b) | (~a & ~b);
        uint32_t z = (a << (i % 32)) | (b >> (i % 32));
        uint32_t w = (x ^ y ^ z) + (uint32_t)i;
        checksum += w;
        a = b;
        b = w;
    }

    printf("bitwise checksum: %llu\n", (unsigned long long)checksum);
    return 0;
}
