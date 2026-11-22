---
id: reduction
title: sum_kernel, a block sum in shared memory with one atomic add per block (TorchLean.Tensor.sum)
kind: kernel
ref: modular/modular@bbc13a71:max/examples/gpu-functions/reduction.mojo:78
quote: "sums[unsafe_offset=tid] += sums[unsafe_offset=tid + active_threads]"
lean: TorchLean.Tensor.sum
corpus: tests/corpus/reduction
tests: MojoProofTest.Eval, MojoProofTest.Atomics
upstream:
depends: shared-memory, barriers, atomics, launch
level: L0
---

# The reduction

**The rule.** Each block sums its slice of the input in shared memory, halving the active
threads after each barrier, and thread 0 adds the block's sum to the result with an atomic add.

**What is in the code.** One corpus file. The evaluator runs it, and the atomics check
(`Stmt.checkAtomic`) passes on it (MojoProofTest.Eval).

**Not proved.** No kernel theorem: the block checker refuses barrier calls (MojoProof/Sym/Rules.lean),
so there is no L2 evidence. The atomic add makes the sum's order depend on the schedule, so the L3 statement
is about the sum over the reals, and an L4 statement needs a bound over every order.

**Open.** Every level above L0.
