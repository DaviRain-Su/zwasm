// struct_test.cpp — struct layout, alignment, nested structs
#include <cstdio>
#include <cstring>

struct Point {
    float x, y;
};

struct Rect {
    Point top_left;
    Point bottom_right;
};

struct Record {
    int id;
    char name[32];
    double score;
    Rect bounds;
};

float area(const Rect *r) {
    float w = r->bottom_right.x - r->top_left.x;
    float h = r->bottom_right.y - r->top_left.y;
    return w * h;
}

int main() {
    Record records[100];
    float total_area = 0.0f;

    for (int i = 0; i < 100; i++) {
        records[i].id = i;
        snprintf(records[i].name, 32, "item_%d", i);
        records[i].score = (double)i * 1.5;
        records[i].bounds.top_left = (Point){(float)i, (float)(i * 2)};
        records[i].bounds.bottom_right = (Point){(float)(i + 10), (float)(i * 2 + 20)};
        total_area += area(&records[i].bounds);
    }

    double score_sum = 0.0;
    for (int i = 0; i < 100; i++)
        score_sum += records[i].score;

    std::printf("records: 100 total_area: %.1f score_sum: %.1f\n", total_area, score_sum);
    std::printf("sizeof Record: %zu\n", sizeof(Record));
    std::printf("last name: %s\n", records[99].name);
    return 0;
}
