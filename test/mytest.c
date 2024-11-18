
void test(int a, int b, int *y)
{
    if (*y > 0) {
        *y = a + b;
    } else {
        *y = a - b;
    }
}
