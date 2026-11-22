# Kernels

## Scope

The GPU kernels the project proves things about: the ones in the corpus (tests/corpus) and the
ones it means to add. A card is one kernel family, one source definition with all the
specializations the corpus has of it, and names the TorchLean operation the kernel computes.
Each card says whether what is proved covers one kernel or the family. Kernel cards climb the
kernel ladder of roadmap/README.md: L1 a GPU run (a conformance test, not a proof), L2 the
kernel theorem, L3 TorchLean over the reals, L4 an IEEE bound or the exact bits.

Reference: the Modular repository at commit bbc13a71 for the kernels from Modular (each card's
ref names the file and line, and its quote is that line), and this repository for
vector_multiply.

## Cards

- [vadd](cards/vadd.md): vector_addition, `TorchLean.Tensor.add`; the kernel theorem, the
  TorchLean equality and the rounding are proved for its one kernel.
- [vmul](cards/vmul.md): vector_multiply, `TorchLean.Tensor.mul`; as vadd, for its one kernel.
- [vsub](cards/vsub.md): the tutorial's vector subtraction, `TorchLean.Tensor.sub`; as vadd,
  for its one kernel, from one `mojo_kernel` command.
- [naive-matmul](cards/naive-matmul.md): matmul_kernel_naive, `TorchLean.Tensor.matmul`; 13
  specializations and 10 built without contraction; its blocks are checked, every thread runs
  to `ret` at one launch and, from premises, at every launch; no kernel theorem.
- [gemv](cards/gemv.md): gemv_kernel, `TorchLean.Tensor.matVecLoop`; no corpus file.
- [reduction](cards/reduction.md): sum_kernel, `TorchLean.Tensor.sum`; one corpus file.
- [layernorm](cards/layernorm.md): layer_norm_gpu, `TorchLean.Tensor.layerNorm`; 34
  specializations.
- [rms-norm](cards/rms-norm.md): rms_norm_gpu, `TorchLean.Tensor.rmsNorm`; no corpus file.
- [softmax](cards/softmax.md): softmax_kernel, `TorchLean.Tensor.softmax`; no corpus file.
- [multistage-gemm](cards/multistage-gemm.md): multistage_gemm, `TorchLean.Tensor.matmul`; 24
  specializations, all refused by the importer.
- [split-k-reduce](cards/split-k-reduce.md): the split-k GEMM's reduction,
  `TorchLean.Tensor.sum`; 12 specializations.
- [tiled-matmul](cards/tiled-matmul.md): tiled_matmul_kernel, `TorchLean.Tensor.matmul`; one
  corpus file.
- [layout-mma](cards/layout-mma.md): the layout tensor-core tests, `TorchLean.Tensor.matmul`;
  13 corpus files.

## Open

A kernel passes L0 only with a tracked record of a GPU run of it (L1), a conformance test of
the evaluator against the GPU and not a proof; STATUS.md lists the cards that have one. vadd,
vmul and vsub have their L2, L3 and L4 evidence. The next kernel theorems need the block checker to
take loops (the naive matmul), barriers (the reduction, the tiled matmul) and shuffles (layer
norm).
