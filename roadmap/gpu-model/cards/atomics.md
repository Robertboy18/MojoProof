---
id: atomics
title: atomics, atomicrmw with a commutative operation and an unused result
kind: construct
ref: LLVM LangRef 24.0.0git #atomicrmw-instruction
quote: ""
lean: MojoProof.LLVM.RmwOp, MojoProof.LLVM.Stmt.checkAtomic, MojoProof.Sem.rmw, MojoProof.Sem.rmw_comm, MojoProof.Sem.exec_atomic, MojoProof.Sem.step_atomic, MojoProof.Sem.Grid.advance_atomic_comm
corpus: none
tests: MojoProofTest.Atomics, MojoProofTest.Confluence.atomic_comm, MojoProofTest.Confluence.atomic_diamond
upstream:
depends: launch
level: L1
---

# Atomics

**The rule.** `atomicrmw op ptr, v seq_cst` reads the value at `ptr`, writes `op` of it and
`v`, and returns the old value, as one indivisible step.

**In Lean.** The semantics admits `atomicrmw` only `seq_cst` at system scope, with an
operation that commutes and associates and with the result unused (`Stmt.checkAtomic`); then
two atomic updates commute (`MojoProof.Sem.rmw_comm`, `Grid.advance_atomic_comm`). The parser
refuses atomic loads and stores, and other atomic instructions are not in the subset.

**Open.** L2: no recorded GPU run. L3: no proved kernel has an atomic (the reduction does).
Ref: quote to be added.
