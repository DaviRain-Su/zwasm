// unique_ptr_test.cpp — RAII, unique_ptr, move semantics
#include <cstdio>
#include <memory>
#include <vector>

struct Widget {
    int id;
    int value;
    Widget(int i, int v) : id(i), value(v) {}
};

int main() {
    std::vector<std::unique_ptr<Widget>> widgets;

    // Create 500 widgets
    for (int i = 0; i < 500; i++) {
        widgets.push_back(std::make_unique<Widget>(i, i * i % 997));
    }

    // Move to another vector (even-indexed only)
    std::vector<std::unique_ptr<Widget>> selected;
    for (size_t i = 0; i < widgets.size(); i += 2) {
        selected.push_back(std::move(widgets[i]));
    }

    // Count non-null in original
    int null_count = 0;
    for (const auto &w : widgets) {
        if (!w) null_count++;
    }

    // Sum values in selected
    long long sum = 0;
    for (const auto &w : selected) {
        if (w) sum += w->value;
    }

    std::printf("selected: %zu null_in_orig: %d sum: %lld\n",
                selected.size(), null_count, sum);
    return 0;
}
