// algorithm_test.cpp — std::transform, accumulate, count_if, partition
#include <cstdio>
#include <vector>
#include <algorithm>
#include <numeric>

int main() {
    std::vector<int> v(1000);
    // Fill with 0..999
    std::iota(v.begin(), v.end(), 0);

    // Transform: square each element mod 10007
    std::vector<int> squared(1000);
    std::transform(v.begin(), v.end(), squared.begin(),
                   [](int x) { return (x * x) % 10007; });

    // Accumulate
    long long sum = std::accumulate(squared.begin(), squared.end(), 0LL);

    // Count evens
    int evens = (int)std::count_if(squared.begin(), squared.end(),
                                   [](int x) { return x % 2 == 0; });

    // Partition: move values > 5000 to front
    auto mid = std::partition(squared.begin(), squared.end(),
                              [](int x) { return x > 5000; });
    int high_count = (int)(mid - squared.begin());

    // Reverse
    std::reverse(v.begin(), v.end());

    std::printf("sum: %lld evens: %d high: %d first: %d last: %d\n",
                sum, evens, high_count, v[0], v[999]);
    return 0;
}
