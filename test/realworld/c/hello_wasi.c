// hello_wasi.c — Basic WASI: stdout, args, env vars
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {
    printf("Hello from C/WASI!\n");
    printf("argc = %d\n", argc);
    for (int i = 0; i < argc; i++) {
        printf("argv[%d] = %s\n", i, argv[i]);
    }

    const char *home = getenv("HOME");
    if (home) {
        printf("HOME = %s\n", home);
    } else {
        printf("HOME not set\n");
    }

    return 0;
}
