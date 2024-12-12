
struct test_struct {
    int a;
    long b;
    char c;
} tt;

void test(int a, int b, int *y)
{
    *y = a + b;
    tt.a = a;
    tt.b = b;
    tt.c = 'c';
}
