// matrix_multiply.c — Dense FP matrix multiplication (100x100)
#include <stdio.h>
#include <stdlib.h>

#define N 100

static double A[N][N], B[N][N], C[N][N];

int main(void) {
    // Initialize matrices
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            A[i][j] = (double)(i * N + j) / (N * N);
            B[i][j] = (double)(j * N + i) / (N * N);
            C[i][j] = 0.0;
        }
    }

    // Multiply: C = A * B
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            double sum = 0.0;
            for (int k = 0; k < N; k++) {
                sum += A[i][k] * B[k][j];
            }
            C[i][j] = sum;
        }
    }

    // Print checksum (sum of diagonal)
    double checksum = 0.0;
    for (int i = 0; i < N; i++) {
        checksum += C[i][i];
    }
    printf("matrix 100x100 checksum: %.6f\n", checksum);

    return 0;
}
