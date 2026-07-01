// clang -O0: NO optimization → the local array `a` + loop vars spill to the
// shadow stack (__stack_pointer). Heaviest shadow-stack test + a different
// toolchain than rust. sum 5+2+8+1+9+3+7+4 = 39.
int test(void) {
    int a[8] = {5, 2, 8, 1, 9, 3, 7, 4};
    int sum = 0;
    for (int i = 0; i < 8; i++) sum += a[i];
    return sum;
}
