// string_processing.c — String manipulation stress test
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUF_SIZE 4096
#define ITERATIONS 1000

int main(void) {
    char buf[BUF_SIZE];
    int total_len = 0;

    for (int iter = 0; iter < ITERATIONS; iter++) {
        // Build a string by concatenation
        buf[0] = '\0';
        for (int i = 0; i < 20; i++) {
            char chunk[64];
            snprintf(chunk, sizeof(chunk), "item_%d_", iter * 20 + i);
            if (strlen(buf) + strlen(chunk) < BUF_SIZE - 1) {
                strcat(buf, chunk);
            }
        }
        total_len += (int)strlen(buf);

        // Reverse the string in-place
        int len = (int)strlen(buf);
        for (int i = 0; i < len / 2; i++) {
            char tmp = buf[i];
            buf[i] = buf[len - 1 - i];
            buf[len - 1 - i] = tmp;
        }

        // Count occurrences of '_'
        int count = 0;
        for (int i = 0; i < len; i++) {
            if (buf[i] == '_') count++;
        }
        total_len += count;
    }

    printf("string processing total: %d\n", total_len);
    return 0;
}
