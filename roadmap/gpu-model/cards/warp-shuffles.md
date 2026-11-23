---
id: warp-shuffles
title: warp shuffles, shfl.sync of an i32 across the lanes of a warp
kind: construct
ref: PTX ISA 9.5 #9.7.10.6
quote: ""
lean: MojoProof.LLVM.Shfl, MojoProof.LLVM.Intrinsic.shflName, MojoProof.LLVM.Intrinsic.shfl_args, MojoProof.Sem.shflSource, MojoProof.Sem.shfl_erase, MojoProof.Sym.Seg.sound
corpus: none
tests: MojoProofTest.Confluence.shfl_diamond, MojoProofTest.Confluence.shfl_value, MojoProofTest.Confluence.shfls_same, MojoProofTest.SymSeg.gemv_segments
upstream:
depends: launch
level: L1
---

# Warp shuffles

**The rule.** `llvm.nvvm.shfl.sync.<mode>.i32` gives each lane of the warp the operand of a
source lane computed from the mode (`idx`, `up`, `down`, `bfly`), the lane operand and the
clamp; a lane whose source is out of range gets its own operand.

**In Lean.** With the full member mask and the whole warp taking part, the shuffle completes
when every lane waits at it with the same mode and mask, and each lane gets the operand of
the source lane `MojoProof.Sem.shflSource` computes. Another mask is unsupported. A shuffle
orders no memory access. The block checker's summary of a block stops at a shuffle; the
statements up to it are a segment (`summarizeTo`), and a thread's steps over a segment reach the
shuffle's wait, with its operands' values (`MojoProof.Sym.Seg.sound`, for every program; tested
at the gemv kernels' reductions). No schedule through a shuffle is proved.

**Out of scope.** Partial member masks, and shuffles of other types than `i32`.

**Open.** L2: no recorded GPU run. L3: no proved kernel shuffles. Ref: quote to be added.
