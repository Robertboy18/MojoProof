---
id: swizzle
title: `Swizzle` is `x ^ ((x & mask) >> shift)` and needs `abs(shift) >= bits`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/swizzle.mojo:381
quote: "return offset ^ shiftr(offset & self.yyy_mask, self.shift)"
lean: GPUProof.Layout.Swizzle, GPUProof.Layout.Swizzle.call, GPUProof.Layout.Swizzle.mask, GPUProof.Layout.shiftr, GPUProof.Layout.Swizzle.shiftr_and_mask, GPUProof.Layout.Swizzle.call_call
corpus: none
tests: MojoProofTest.GPUProof.LayoutLaws, MojoProofTest.LayoutConformance
upstream:
level: L1
---
# `Swizzle` is `x ^ ((x & mask) >> shift)` and needs `abs(shift) >= bits`

## Rule

`Swizzle.__call__` (swizzle.mojo:369) is the quoted line. The constructor's condition is `abs(shift) >= bits` (line 332), so the bits the mask selects and the bits they are XORed into do not overlap. That is what makes the swizzle its own inverse.

## In scope

Every bits, base and shift with `abs(shift) >= bits`: the swizzle is a bijection and its own inverse.

## Out of scope

Swizzles with `abs(shift) < bits`.

## In MojoProof

`Swizzle` and `Swizzle.call` transcribe the swizzle. `Swizzle.call_call`: when `bits ≤ |shift|`, the swizzle is its own inverse, hence a bijection, for every value, base and shift, positive or negative (`Swizzle.shiftr_and_mask` is the step). The condition is needed: `Swizzle(2, 0, 1)` applied twice to 6 gives 7 (MojoProofTest.LayoutLaws, by `decide`); the constructor's check of the condition does not run when the swizzle is evaluated at compile time, and the conformance test's compiled code gives the same values.
