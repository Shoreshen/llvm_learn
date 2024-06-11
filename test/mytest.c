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
// #include <stdio.h>
#include "mytest.h"
char* dddddd();
char* aaa = "test_runing";

void __attribute__((noinline, optnone)) run_on_npu(volatile char* str)
{
    return;
}
void __attribute__((noinline, optnone)) push_to_npu_buffer(volatile int a)
{
    return;
}
int _start()
{
    int a = 23;
    push_to_npu_buffer(a);
    run_on_npu(
        "add ra, 17 , 1\n"
        "dddbaaa\n"
    );
    dddddd();
    return 0;
}
char* dddddd()
{
    aaa[0] = 0;
    return aaa + 1;
} 