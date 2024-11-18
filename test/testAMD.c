#define __HIP_PLATFORM_AMD__
#include <hip/hip_runtime.h>
#include <time.h>

#define N 1000000

__global__ void vector_add(float *c, float *a, float *b, int n) {
  int tid = blockDim.x * blockIdx.x + threadIdx.x;
  if (tid < N) {
    c[tid] = a[tid] + b[tid];
  }
}

int main() {


  return 0;
}
