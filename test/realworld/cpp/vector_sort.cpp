// vector_sort.cpp — std::vector + std::sort stress test
#include <cstdio>
#include <vector>
#include <algorithm>
#include <cstdlib>

int main() {
    const int N = 10000;
    std::vector<int> v(N);

    // Fill with pseudo-random values
    unsigned int seed = 42;
    for (int i = 0; i < N; i++) {
        seed = seed * 1103515245 + 12345;
        v[i] = (int)(seed >> 16) & 0x7fff;
    }

    // Sort
    std::sort(v.begin(), v.end());

    // Verify sorted and compute checksum
    long long checksum = 0;
    for (int i = 0; i < N; i++) {
        checksum += v[i];
        if (i > 0 && v[i] < v[i - 1]) {
            std::printf("ERROR: not sorted at index %d\n", i);
            return 1;
        }
    }

    std::printf("vector sort checksum: %lld (N=%d)\n", checksum, N);
    return 0;
}
