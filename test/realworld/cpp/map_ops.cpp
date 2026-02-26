// map_ops.cpp — std::map insert, lookup, iterate
#include <cstdio>
#include <map>
#include <string>

int main() {
    std::map<int, std::string> m;

    // Insert 500 entries
    for (int i = 0; i < 500; i++) {
        m[i] = "val_" + std::to_string(i * i);
    }

    // Lookup check
    int found = 0;
    for (int i = 0; i < 500; i += 3) {
        auto it = m.find(i);
        if (it != m.end()) found++;
    }

    // Iterate and compute string length sum
    size_t total_len = 0;
    for (const auto &kv : m) {
        total_len += kv.second.size();
    }

    // Erase half
    for (int i = 0; i < 500; i += 2) {
        m.erase(i);
    }

    std::printf("entries: %zu found: %d len: %zu after_erase: %zu\n",
                (size_t)500, found, total_len, m.size());
    return 0;
}
