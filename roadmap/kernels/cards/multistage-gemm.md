---
id: multistage-gemm
title: multistage_gemm, the tiled tensor-core GEMM with asynchronous copies (TorchLean.Tensor.matmul)
kind: kernel
ref: modular/modular@bbc13a71:max/kernels/src/linalg/matmul/gpu/__init__.mojo:2492
quote: "def multistage_gemm["
lean: TorchLean.Tensor.matmul
corpus: tests/corpus/mgemm/g_multistage_gemm_*
tests: MojoProofTest.Corpus
upstream: https://github.com/modular/modular/issues/7735
depends: mma, ldmatrix, cp-async, shared-memory, barriers, split-k-reduce
level: L0
---

# The multistage GEMM

**The rule.** C = A B, computed by tiles: copies of tiles of A and B into shared memory
(cp.async), loads of fragments (ldmatrix), and tensor-core multiply-accumulates (mma), over
several stages in flight.

**What is in the code.** 24 corpus specializations of `multistage_gemm_kernel` and of its
split-k form (float32, bfloat16 and float8 inputs, with and without an epilogue function). 22
import: the importer accepts their inline asm `cp.async.cg.shared.global` copies
(MojoProof/LLVM/Asm.lean) and refuses the 2 float8 ones at a `cvt.rn.satfinite.e4m3x2.f32`
(tests/corpus/REFUSALS.tsv). exec faults at the copies, and the evaluator has no grid semantics
for `ldmatrix` and `mma` yet (their models, `MojoProof.Sem.mmaStep`, `MojoProof.Sem.ldmatrix`
and `MojoProof.Sem.Async`, are not dispatched).

**Open.** The grid's dispatch of the copies, `ldmatrix` and `mma` to their models, then every
level above L0.
