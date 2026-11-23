---
id: tiled-matmul
title: tiled_matmul_kernel, a matmul by shared-memory tiles (TorchLean.Tensor.matmul)
kind: kernel
ref: modular/modular@bbc13a71:max/examples/gpu-block-and-warp/tiled_matmul.mojo:78
quote: "def tiled_matmul_kernel("
lean: TorchLean.Tensor.matmul
corpus: tests/corpus/tiled_matmul
tests: MojoProofTest.Mutate, MojoProofTest.Corpus
upstream:
depends: shared-memory, barriers, launch
level: L0
---

# The tiled matmul

**The rule.** Each block loads tiles of A and B into shared memory, waits at a barrier,
accumulates the tiles' products, and waits again before the next tiles.

**What is in the code.** One corpus file. It imports. The block checker takes its blocks %40
and %47, each with a `getelementptr` on a shared-memory global
(`MojoProof.Sym.SNode.eval_globalAt`), and refuses its block %67 at its barrier call
(MojoProofTest.Mutate pins the refusal); the statements up to a barrier are a segment
(`MojoProof.Sym.summarizeTo`, `MojoProof.Sym.Seg.sound`; tested on the gemv kernels only), and no
schedule through a barrier is proved.

**Open.** Every level above L0.
