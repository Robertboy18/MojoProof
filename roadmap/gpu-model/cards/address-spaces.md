---
id: address-spaces
title: address spaces, the generic, global, shared and local spaces of a pointer
kind: construct
ref: LLVM NVPTXUsage 24.0.0git #address-spaces
quote: ""
lean: MojoProof.Sem.Block.space, MojoProof.LLVM.Global.addrSpace, MojoProof.Sem.Layout.allocaSpace
corpus: none
tests: MojoProofTest.Eval
upstream:
level: L1
---

# Address spaces

**The rule.** NVPTX numbers its address spaces: 0 generic, 1 global, 3 shared, 4 constant,
5 local. A pointer's type carries its space, and `addrspacecast` converts between them.

**In Lean.** Every memory block has a space (`MojoProof.Sem.Block.space`); a global variable
has one (`LLVM.Global.addrSpace`), and the data layout gives the space of `alloca`
(`Layout.allocaSpace`).

**Out of scope.** The constant space's caching, and distributed shared memory.

**Open.** L2: no recorded GPU run. L3: the proved kernels (vadd, vmul) use generic pointers
only. Ref: quote to be added.
