#ifndef CML_VECTOR_CUH_
#define CML_VECTOR_CUH_

#include <thrust/iterator/constant_iterator.h>
#include <thrust/transform.h>

#include <cstdio>

#include "cml_defs.cuh"
#include "cml_utils.cuh"

// Cuda Matrix Library
namespace cml {

// Vector Class
template <typename T>
struct vector {
  size_t size, stride;
  T* data;
};

// Helper methods
namespace {

template <typename T>
__global__ void __set_vector(T *data, T val, size_t stride, size_t size) {
  uint tid = blockIdx.x * blockDim.x + threadIdx.x;
  for (uint i = tid; i < size; i += gridDim.x * blockDim.x)
    data[i * stride] = val;
}

}  // namespace

template <typename T>
vector<T> vector_alloc(size_t n) {
  vector<T> vec;
  vec.size = n;
  vec.stride = 1;
  cudaError_t err = cudaMalloc(reinterpret_cast<void**>(&vec.data),
      n * sizeof(T));
  return vec;
}

template <typename T>
void vector_set_all(vector<T> *v, T x) {
  uint grid_dim = calc_grid_dim(v->size, kBlockSize);
  __set_vector<<<grid_dim, kBlockSize>>>(v->data, x, v->stride, v->size);
}

template <typename T>
vector<T> vector_calloc(size_t n) {
  vector<T> vec = vector_alloc<T>(n);
  vector_set_all(&vec, static_cast<T>(0));
  return vec;
}

template<typename T>
void vector_free(vector<T> *x) {
  cudaError_t err = cudaFree(x->data);
  CudaCheckError(err);
}

template <typename T>
vector<T> vector_subvector(vector<T> *vec, size_t offset, size_t n) {
  vector<T> subvec;
  subvec.size = n;
  subvec.data = vec->data + offset * vec->stride;
  subvec.stride = vec->stride;
  return subvec;
}

// TODO: Take stride into account.
template <typename T>
void vector_memcpy(vector<T> *x, const vector<T> *y) {
  cudaError_t err = cudaMemcpy(reinterpret_cast<void*>(x->data),
      reinterpret_cast<const void*>(y->data), x->size * sizeof(T),
      cudaMemcpyDefault);
  CudaCheckError(err);
}

template <typename T>
void vector_memcpy(vector<T> *x, const T *y) {
  cudaError_t err = cudaMemcpy(reinterpret_cast<void*>(x->data),
      reinterpret_cast<const void*>(y), x->size * sizeof(T), cudaMemcpyDefault);
  CudaCheckError(err);
}

template <typename T>
void vector_memcpy(T *x, const vector<T> *y) {
  cudaError_t err = cudaMemcpy(reinterpret_cast<void*>(x),
      reinterpret_cast<const void*>(y->data), y->size * sizeof(T),
      cudaMemcpyDefault);
  CudaCheckError(err);
}

template <typename T>
void print_vector(const vector<T> &x) {
  T* x_ = new T[x.size * x.stride];
  vector_memcpy(x_, &x);
  for (unsigned int i = 0; i < x.size; ++i)
    printf("%e ", x_[i * x.stride]);
  printf("\n");
  delete [] x_;
}

template <typename T>
void vector_scale(vector<T> *a, T x) {
  strided_range<thrust::device_ptr<T> > idx(
      thrust::device_pointer_cast(a->data),
      thrust::device_pointer_cast(a->data + a->stride * a->size), a->stride);
  thrust::transform(idx.begin(), idx.end(), thrust::constant_iterator<T>(x),
      idx.begin(), thrust::multiplies<T>());
}

template <typename T>
void vector_mul(vector<T> *a, const vector<T> *b) {
  strided_range<thrust::device_ptr<T> > idx_a(
      thrust::device_pointer_cast(a->data),
      thrust::device_pointer_cast(a->data + a->stride * a->size), a->stride);
  strided_range<thrust::device_ptr<T> > idx_b(
      thrust::device_pointer_cast(b->data),
      thrust::device_pointer_cast(b->data + b->stride * b->size), b->stride);
  thrust::transform(idx_a.begin(), idx_a.end(), idx_b.begin(), idx_a.begin(),
      thrust::multiplies<T>());
}

template <typename T>
void vector_div(vector<T> *a, const vector<T> *b) {
  strided_range<thrust::device_ptr<T> > idx_a(
      thrust::device_pointer_cast(a->data),
      thrust::device_pointer_cast(a->data + a->stride * a->size), a->stride);
  strided_range<thrust::device_ptr<T> > idx_b(
      thrust::device_pointer_cast(b->data),
      thrust::device_pointer_cast(b->data + b->stride * b->size), b->stride);
  thrust::transform(idx_a.begin(), idx_a.end(), idx_b.begin(), idx_a.begin(),
      thrust::divides<T>());
}

template <typename T>
void vector_add_constant(vector<T> *a, const T x) {
  strided_range<thrust::device_ptr<T> > idx(
      thrust::device_pointer_cast(a->data),
      thrust::device_pointer_cast(a->data + a->stride * a->size), a->stride);
  thrust::transform(idx.begin(), idx.end(), thrust::constant_iterator<T>(x),
      idx.begin(), thrust::plus<T>());
}

}  // namespace cml

#endif  // CML_VECTOR_CUH_

