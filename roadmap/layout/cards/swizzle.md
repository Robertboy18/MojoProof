---
id: swizzle
title: `Swizzle` is `x ^ ((x & mask) >> shift)` and needs `abs(shift) >= bits`
kind: construct
ref: modular/modular@bbc13a71:max/kernels/src/layout/swizzle.mojo:381
quote: "return offset ^ shiftr(offset & self.yyy_mask, self.shift)"
lean: not stated yet
corpus: none
tests: none
upstream:
level: L0
---
# `Swizzle` is `x ^ ((x & mask) >> shift)` and needs `abs(shift) >= bits`

## Rule

`Swizzle.__call__` (swizzle.mojo:369) is the quoted line. The constructor asserts `abs(shift) >= bits` (line 332), so the bits the mask selects and the bits they are XORed into do not overlap. That is what makes the swizzle its own inverse. Two points: the assert's message is "shift should be less than bits", the opposite of its condition, and both asserts are inside `if not __is_run_in_comptime_interpreter:` (line 327), so a swizzle built at compile time is not checked.

## In scope

Every bits, base and shift with `abs(shift) >= bits`: the swizzle is a bijection and its own inverse.

## Out of scope

Swizzles built at compile time with `abs(shift) < bits`, which are not checked (line 327).

## Open

A Lean statement that the swizzle is an involution under the condition, and a fix to the assert message. MojoProof states no layout law yet.
