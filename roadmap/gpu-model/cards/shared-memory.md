---
id: shared-memory
title: shared memory, the static and dynamic shared blocks of a block of threads
kind: construct
ref: PTX ISA 9.5 #shared-state-space
quote: ""
lean: MojoProof.Sem.shared, MojoProof.Sem.shared_blocks, MojoProof.Sem.shared_closed, MojoProof.Sem.Launch.dynShared, MojoProof.Sym.shared_res, MojoProof.Sym.SNode.eval_globalAt
corpus: none
tests: MojoProofTest.Eval, MojoProofTest.ScheduleOwned
upstream:
depends: address-spaces, launch
level: L1
---

# Shared memory

**The rule.** Each block of threads has its own shared memory: the module's shared globals
and, if the launch asks for it, a dynamic block. Its threads share it; other blocks do not see it.

**In Lean.** `MojoProof.Sem.shared` allocates a block of threads' shared globals and dynamic
block (`Launch.dynShared` bytes); `shared_blocks` and `shared_closed` keep the memory's
invariants. An `external constant` shared global is refused. The block checker takes a
`getelementptr`, `load` or `store` on a shared global (a `load` after a `store` too, as
`SNode.loadAfter`): its pointer is the node `SNode.globalAt`, whose value is the context's
address of the global, the one `Grid.start` gives the thread's block
(`MojoProof.Sym.SNode.eval_globalAt`, for every program). The node is skeleton (`SNode.pay`):
the two-run theorems take one table of globals, so a block that stores to a shared global can be
oblivious (layernorm's `%448`, `ln_store_oblivious` in MojoProofTest/SymSeg.lean).

**Open.** L2: no recorded GPU run. L3: no proved kernel uses shared memory yet (the reduction
and the tiled matmul do). Ref: quote to be added.
