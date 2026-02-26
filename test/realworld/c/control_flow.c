// control_flow.c — switch, nested loops, break/continue, goto
#include <stdio.h>

int classify(int n) {
    switch (n % 5) {
        case 0: return 0;
        case 1: return 1;
        case 2: return 4;
        case 3: return 9;
        case 4: return 16;
        default: return -1;
    }
}

int main(void) {
    // Switch dispatch
    int switch_sum = 0;
    for (int i = 0; i < 1000; i++)
        switch_sum += classify(i);
    printf("switch sum: %d\n", switch_sum);

    // Nested loops with break/continue
    int count = 0;
    for (int i = 0; i < 100; i++) {
        for (int j = 0; j < 100; j++) {
            if (j > i) break;
            if ((i + j) % 3 == 0) continue;
            count++;
        }
    }
    printf("nested count: %d\n", count);

    // Early return via goto cleanup
    int result = 0;
    for (int i = 1; i <= 100; i++) {
        result += i;
        if (result > 3000) goto done;
    }
done:
    printf("goto sum: %d\n", result);

    return 0;
}
