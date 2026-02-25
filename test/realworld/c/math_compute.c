// math_compute.c — Math library functions (sin, cos, sqrt, pow)
#include <stdio.h>
#include <math.h>

#define ITERATIONS 100000

int main(void) {
    double sum = 0.0;

    for (int i = 1; i <= ITERATIONS; i++) {
        double x = (double)i / ITERATIONS * 3.14159265358979;
        sum += sin(x) * cos(x) + sqrt((double)i) + pow(x, 1.5);
    }

    printf("math compute result: %.6f\n", sum);
    return 0;
}
