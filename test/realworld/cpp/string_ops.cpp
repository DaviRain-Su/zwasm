// string_ops.cpp — std::string operations stress test
#include <cstdio>
#include <string>

int main() {
    const int ITERATIONS = 5000;
    std::string result;

    for (int i = 0; i < ITERATIONS; i++) {
        std::string s = "Hello_";
        s += std::to_string(i);
        s += "_World";

        // find and replace
        auto pos = s.find("World");
        if (pos != std::string::npos) {
            s.replace(pos, 5, "WASM");
        }

        // substr
        if (s.size() > 5) {
            result += s.substr(0, 5);
        }
    }

    std::printf("string ops length: %zu\n", result.size());
    return 0;
}
