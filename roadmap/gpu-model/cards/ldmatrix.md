---
id: ldmatrix
title: ldmatrix, a warp's load of 8x8 matrices from shared memory
kind: construct
ref: PTX ISA 9.5 #9.7.16.5.15
quote: ""
lean: not stated yet
corpus: none
tests: none
upstream:
depends: shared-memory
level: L0
---

# ldmatrix

**The rule.** `llvm.nvvm.ldmatrix.sync.aligned.m8n8.x4[.trans].b16.p3` loads four 8×8
matrices of 16-bit elements from shared memory into the lanes' registers, transposed with
`.trans`.

**In the code.** The importer recognises the intrinsic; the grid has no semantics for it.

**Open.** L1 and above. Ref: quote to be added.
