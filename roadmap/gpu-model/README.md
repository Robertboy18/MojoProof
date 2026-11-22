# The GPU model

## Scope

What the semantics says a GPU does beyond one thread's LLVM IR: the launch and its threads,
address spaces, shared memory, the barrier, warp shuffles, atomics, and the tensor-core and
asynchronous-copy operations the corpus's kernels call. Each card names the Lean declarations
that model the construct (`lean`), or `not stated yet` where the semantics has none. Construct
cards climb the construct ladder of roadmap/README.md: L1 modelled, L2 tested against a GPU, L3
used by a proved kernel.

Reference: the PTX ISA version 9.5 and LLVM 24.0.0git's LangRef, the versions docs/TRUST.md
records, and the NVPTX usage guide of the same LLVM version. No copy of them is in the repository, so every quote is empty
and each card says "quote to be added".

## Cards

- [launch](cards/launch.md): the grid, the blocks, their threads and special registers.
- [address-spaces](cards/address-spaces.md): the space of a pointer and of a memory block.
- [shared-memory](cards/shared-memory.md): the shared blocks of a block of threads.
- [barriers](cards/barriers.md): the block barrier and the happens-before it gives.
- [warp-shuffles](cards/warp-shuffles.md): `shfl.sync` with the full mask.
- [atomics](cards/atomics.md): `atomicrmw` with a commutative operation and an unused result.
- [mma](cards/mma.md): the tensor cores' multiply-accumulate; parsed, not modelled.
- [ldmatrix](cards/ldmatrix.md): a warp's load of matrices from shared memory; not modelled.
- [cp-async](cards/cp-async.md): asynchronous copies; their groups' commit and wait run as
  no-ops, the copies are refused.

## Open

No GPU run is recorded, so no construct is past L1. The launch is used by the proved kernels
(L3 evidence); the barrier, shuffles, shared memory and atomics wait for a proved kernel that
uses them; `mma`, `ldmatrix` and `cp.async` wait for a model.
