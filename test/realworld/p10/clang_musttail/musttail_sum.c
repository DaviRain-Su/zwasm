// clang __attribute__((musttail)) → Wasm 3.0 return_call.
// noinline self-recursive sum so clang -O2 IPSCCP keeps the call
// (recursion isn't constant-evaluated) → real return_call at runtime.
__attribute__((noinline)) static int sum_tail(int n, int acc) {
    if (n == 0) return acc;
    __attribute__((musttail)) return sum_tail(n - 1, acc + n);
}
int test(void) { return sum_tail(5, 0); }
