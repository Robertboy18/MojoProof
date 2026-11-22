---
id: mma
title: mma, a warp's tensor-core multiply-accumulate
kind: construct
ref: PTX ISA 9.5 #9.7.16.5.14
quote: ""
lean: not stated yet
corpus: none
tests: none
upstream:
depends: launch
level: L0
---

# mma

**The rule.** `llvm.nvvm.mma.m<m>n<n>k<k>.row.col.<types>` multiplies an `m × k` and a
`k × n` tile, held in fragments across the warp's lanes, and adds an `m × n` accumulator.

**In the code.** The importer parses the intrinsic's shape and types (`MojoProof.LLVM.Mma`),
but the grid has no semantics for it (a run reaching it is unsupported), so it is not modelled.

**Open.** L1: the fragment layout and the products' rounding; everything above. Ref: the
section is the one docs/TRUST.md cites; quote to be added.
