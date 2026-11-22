---
id: vadd
title: vector_addition, the elementwise sum of two float32 vectors (TorchLean.Tensor.add)
kind: kernel
ref: modular/modular@bbc13a71:max/examples/gpu-functions/vector_addition.mojo:76
quote: "out_tensor[global_tid] = lhs_tensor[global_tid] + rhs_tensor[global_tid]"
lean: TorchLean.Tensor.add, MojoProof.Kernels.vadd.bytes, MojoProof.Kernels.vadd.correct
corpus: tests/corpus/vadd
tests: MojoProofTest.Kernel.vadd_real, MojoProofTest.Kernel.vadd_finEq, MojoProofTest.Kernel.vadd_stable
upstream:
depends: launch, binary-op-rounding, deliver
level: L4
evidence: L1: tests/gpu/vadd/record.txt; L2: MojoProof.Kernels.vadd.correct; L3: MojoProofTest.Kernel.vadd_real; L4: MojoProofTest.Kernel.vadd_real
---

# vector_addition

**The rule.** Thread `k` of the launch, for `k` below the length `n`, writes
`lhs[k] + rhs[k]` (binary32 addition) to `out[k]`, and nothing else.

**What is proved, for one kernel.** The corpus file is one specialization (float32, one
dimension). `MojoProof.Kernels.vadd.correct` is the kernel theorem (`Kernel.Sound`) for every
valid one-dimensional launch and every caller's memory of `Map2.Pre`: the run is memory safe and
race free, and output cell `k` holds `MojoProof.Kernels.vadd.bytes`, the bytes of the delivered
`Model.add` of the inputs' cells. `MojoProofTest.Kernel.vadd_real` adds that a finite output is
TorchLean's `x + y` at `k` and that its real value is the real sum rounded to binary32
(`Model.roundAt`). This is the L3 evidence (TorchLean) and the L4 evidence (the IEEE rounding,
exact for finite outputs).

**Out of scope.** Other element types and widths, other launch shapes than one dimension, and
the bits of a NaN output (they are the delivered NaN, whose payload `deliver` leaves open).

**The GPU run (L1).** tests/gpu/vadd/record.txt: on one A100 GPU, six launches of the corpus
file on recorded finite inputs; every word of the output buffer is the same on the GPU and in
the evaluator. This is a conformance test, not a proof: it covers those launches and inputs.

**Open.** No level is missing. The cases under "Out of scope" are not covered.
