// qsort_test.c — sorting with function pointers (bubble sort to avoid libc qsort)
#include <stdio.h>

typedef int (*compare_fn)(int, int);

int cmp_asc(int a, int b) { return a - b; }
int cmp_desc(int a, int b) { return b - a; }

void sort(int *arr, int n, compare_fn cmp) {
    for (int i = 0; i < n - 1; i++) {
        for (int j = 0; j < n - 1 - i; j++) {
            if (cmp(arr[j], arr[j + 1]) > 0) {
                int tmp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = tmp;
            }
        }
    }
}

int main(void) {
    int arr[200];
    // Fill with pseudo-random values (LCG)
    unsigned int seed = 42;
    for (int i = 0; i < 200; i++) {
        seed = seed * 1103515245 + 12345;
        arr[i] = (int)((seed >> 16) & 0x7FFF);
    }

    // Sort ascending
    sort(arr, 200, cmp_asc);
    int sorted = 1;
    for (int i = 1; i < 200; i++) {
        if (arr[i] < arr[i - 1]) { sorted = 0; break; }
    }
    printf("ascending: %s\n", sorted ? "OK" : "FAIL");
    printf("first: %d last: %d\n", arr[0], arr[199]);

    // Sort descending
    sort(arr, 200, cmp_desc);
    sorted = 1;
    for (int i = 1; i < 200; i++) {
        if (arr[i] > arr[i - 1]) { sorted = 0; break; }
    }
    printf("descending: %s\n", sorted ? "OK" : "FAIL");

    // Checksum
    long checksum = 0;
    for (int i = 0; i < 200; i++) checksum += arr[i];
    printf("checksum: %ld\n", checksum);

    return 0;
}
