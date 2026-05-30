// clang -O0 floating-point: f64 array on the shadow stack, accumulate (f64.add),
// multiply (f64.mul), then truncate to i32 (i32.trunc_f64_s). Distinct codegen
// cell (FP) vs the integer fixtures. a=[1.5,2.5,3.0,4.0]; sum=11.0; *7.0=77.0;
// (int)=77.
int test(void) {
    double a[4] = {1.5, 2.5, 3.0, 4.0};
    double sum = 0.0;
    for (int i = 0; i < 4; i++) sum += a[i];
    return (int)(sum * 7.0);
}
