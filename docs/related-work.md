# Related work

- [LARK](https://arxiv.org/abs/2611.02028) proves LLM-generated GPU kernels in Lean against PyTorch,
  over a hand-built machine model with exact arithmetic; MojoProof starts from the IR the compiler
  emits, with IEEE floats, and proves schedule independence instead of assuming it.
- [VeriTile](https://github.com/VeriInfra-Lab/VeriTile) reasons in Lean 4 about Triton-style kernels
  written in its own language, against specifications over the reals; MojoProof proves the compiled
  output, with floats.
- [TensorLean](https://tensorlean.ai) verifies production GPU kernels against tensor-level
  specifications; MojoProof does this for Mojo, from the LLVM IR the Mojo compiler emits.
- [Vellvm](https://github.com/vellvm/vellvm) is a formal semantics of sequential LLVM IR in Rocq;
  MojoProof's semantics is in Lean and covers GPU launches: threads, barriers, shuffles and races.
- [lean-mlir](https://github.com/opencompl/lean-mlir) gives MLIR dialects a semantics in Lean and
  verifies rewrites; MojoProof proves properties of whole compiled kernels.
- [GPUVerify](https://github.com/mc-imperial/gpuverify) checks CUDA and OpenCL kernels for races
  and barrier divergence automatically; MojoProof also proves what the kernel computes, with every
  proof checked by Lean's kernel.
- [Faial](https://gitlab.com/umb-svl/faial) finds and rules out data races in GPU kernels by static
  analysis; in MojoProof race freedom is one part of a kernel theorem.
- On the Modular forum, Maxim's talk
  [Can the Mojo compiler prove it?](https://forum.modular.com/t/november-community-meeting-can-the-mojo-compiler-prove-it/3678)
  checks contracts inside the Mojo compiler with Z3; MojoProof works outside the compiler, on its
  output.
- [Flare](https://forum.modular.com/t/flare-v0-13-0-and-httparena-results/3587) keeps hand-written
  Lean 4 models of its protocol code in step with the Mojo code through hashes and differential
  tests; MojoProof proves the code the compiler emits instead of a model of it.
