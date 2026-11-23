---
id: ldmatrix
title: ldmatrix, a warp's load of 8x8 matrices from shared memory
kind: construct
ref: PTX ISA 9.5 #9.7.16.5.15
quote: ""
lean: MojoProof.Sem.ldm, MojoProof.Sem.ldm_inv, MojoProof.Sem.ldmatrix, MojoProof.Sem.ldmatrix_gather, MojoProof.Sem.ldmatrix_fragA, MojoProof.Sem.ldmatrix_fragB_cols, MojoProof.Sem.ldmatrix_fragB, MojoProof.Sem.ldmatrix_fragBt
corpus: none
tests: MojoProofTest.TensorCore.isa_inv, MojoProofTest.TensorCore.mixed_not_inv, MojoProofTest.TensorCore.rows16, MojoProofTest.TensorCore.loads16, MojoProofTest.TensorCore.loadsB2
upstream:
depends: shared-memory
level: L1
---

# ldmatrix

**The rule.** `ldmatrix.sync.aligned.m8n8.x<q>[.trans].b16` loads `q` (1, 2 or 4) 8×8 matrices
of 16-bit elements from shared memory into the lanes' registers, lane `8 m + i` giving the
address of row `i` of matrix `m`, transposed with `.trans`.

**In Lean.** The destination layout `MojoProof.Sem.ldm q t` is a bijection for every `q` and
both values of `.trans` (`MojoProof.Sem.ldm_inv`); read in that layout, the loaded registers
are the stacked tile at the rows' addresses (`MojoProof.Sem.ldmatrix_gather`), and read in the
layouts `mma` reads, `ldmatrix.x<2c>` and `ldmatrix.x<c>.trans` load the A and B operands of a
16-bit `mma` (`MojoProof.Sem.ldmatrix_fragA`, `MojoProof.Sem.ldmatrix_fragB`), and
`ldmatrix.x<c>` loads B from its transpose (`MojoProof.Sem.ldmatrix_fragBt`), for every count;
`ldmatrix.x<ch>.trans` loads `h` B operands side by side
(`MojoProof.Sem.ldmatrix_fragB_cols`). The grid does not dispatch `ldmatrix` to it yet (a run
reaching it is unsupported), and the importer recognises only `.x4`.

**Out of scope.** `.m16n16` and `.b8` shapes, and the `stmatrix` store.

**Open.** The grid's dispatch under `MojoProof.Sem.Grid.warpReady`, and the importer's `.x1`
and `.x2`. L2: no recorded GPU run. L3: no proved kernel uses it. Ref: quote to be added.
