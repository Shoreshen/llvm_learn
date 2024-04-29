// #include <stdio.h>

// int main()
// {
//     int a = 23;
//     return 0;
// }

// long imul(long a, long b) 
// {
//     return a * b;
// }

// void test(int a, int *x, int *y)
// {
//     int b = a * x[0] + y[0];
//     int c = b + x[1];
//     int d = c * y[1];
//     y[2] = b + c + d;
// }

#include "mytest.h"

void run_on_npu_riscv()
{
    int a = 23;
    push_to_npu_buffer(a);
    run_on_npu(
        "add ra, 17 , 1\n"
        "dddbaaa\n"
    );
    return;
}


