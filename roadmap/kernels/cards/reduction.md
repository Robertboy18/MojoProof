---
id: reduction
title: sum_kernel, a block sum in shared memory with one atomic add per block (TorchLean.Tensor.sum)
kind: kernel
ref: modular/modular@bbc13a71:max/examples/gpu-functions/reduction.mojo:78
quote: "sums[unsafe_offset=tid] += sums[unsafe_offset=tid + active_threads]"
lean: TorchLean.Tensor.sum
corpus: tests/corpus/reduction
tests: MojoProofTest.Eval, MojoProofTest.Atomics, MojoProofTest.Shared
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
so there is no L2 evidence. The kernel adds `i32` words (`add <4 x i32>`, `atomicrmw add … i32`):
after every block's `atomicrmw add` the output word is the start word plus the blocks' words
modulo 2³², for every order of the blocks (`MojoProof.Sem.rmw_add_perm`), so no float bound
applies. The shared-memory halving tree is race free, and one run decides every schedule, on
every run with its access pattern (`MojoProof.Sem.Grid.sound_halving`, docs/proofs/reduction.md;
one hand-built kernel's run: `MojoProofTest.Shared.red_sound`); that the kernel's runs have the
pattern is not proved. For a float specialization, the halving tree in each block and the atomic
adds in the schedule's order form one tree whose leaves are a permutation of the inputs, which
`MojoProof.Float.sum_error` bounds for every order (the halving tree's leaves and depth are
`MojoProof.Float.leaves_halve` and `MojoProof.Float.depth_halve`).

**Open.** Every level above L0.
