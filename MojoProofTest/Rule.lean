import MojoProof.Sym.Rules

/-!
# Tests of `@[mojo_rule]` (MojoProof/Sym/RuleAttr.lean, MojoProof/Sym/Rules.lean)

A test table over `TOp`, whose opcode `extra` has neither a rule nor a refusal: the completeness
check fails naming it, and passes once a refusal covers it. The library's table, which
MojoProof/Sym/Rules.lean checks complete, is checked again and printed (`#mojo_rules`): every
constructor of `Inst`, `Term` and `Intrinsic` with its rules and refusals. The failures: a key that
is not a constructor (in the attribute and in mojo_refuse) and a local attribute.
-/

namespace MojoProofTest.Rule

open MojoProof.Sym MojoProof.LLVM

/-- A test table's opcodes. -/
inductive TOp where
  /-- An opcode with a rule. -/
  | add
  /-- An opcode with a refusal. -/
  | mul
  /-- The extra opcode, with no entry until the last refusal. -/
  | extra

/-- The rule for `TOp.add`, tagged where it is declared. -/
@[mojo_rule TOp.add "every case"] theorem add_ne_mul : TOp.add ≠ TOp.mul := nofun

mojo_refuse TOp.mul : "the test table has no rule for it"

/-- error: mojo_rule: no rule and no refusal for [MojoProofTest.Rule.TOp.extra] -/
#guard_msgs in
mojo_rules_complete TOp

mojo_refuse TOp.extra "in the test" : "refused last"

mojo_rules_complete TOp

/--
info: TOp.add: MojoProofTest.Rule.add_ne_mul (every case)
TOp.mul: refused: the test table has no rule for it
TOp.extra: refused (in the test): refused last
-/
#guard_msgs in
#mojo_rules TOp

/-! The library's table. -/

mojo_rules_complete Inst Term Intrinsic

/--
info: Inst.bin: Sym.exec_bin
Inst.fbin: Sym.exec_fbin (on a float element type, but fmul contract); Sym.exec_fbinC (on a float
element type, fmul contract included, with coversC); refused (fmul contract without coversC, or a
non-float element type): SState.stmt takes a contracted fmul only with its contract flag and no fbin
on a non-float element type
Inst.fneg: refused: SState.stmt has no case for it
Inst.icmp: Sym.exec_icmp (on an integer type, before any store); refused (on a non-integer type, or
after a store): SState.stmt takes icmp on an integer type before the block's first store only
Inst.fcmp: refused: SState.stmt has no case for it
Inst.cast: Sym.exec_cast (the casts castV evaluates (castOk): not fptoui, fptosi or inttoptr;
ptrtoint before any store); refused (fptoui, fptosi, inttoptr, an ill-typed cast, or ptrtoint after
a store): SState.stmt takes the casts castOk admits (castOk_iff: those castV evaluates), and
ptrtoint before the block's first store only
Inst.select: Sym.exec_select (of integers); refused (of floats, pointers or vectors): SState.stmt
takes select of integers only
Inst.phi: refused: set on the edge into its block (SState.phiConds), not by SState.stmt
Inst.alloca: refused: SState.stmt has no case for it
Inst.load: Sym.exec_load (before or after a store; after one, the load from the memory the effects
before it make (SNode.loadAfter))
Inst.store: Sym.exec_store
Inst.gep: Sym.exec_gep (one index, before any store); refused (not one index, or after a store):
SState.stmt takes a gep with one index before the block's first store only
Inst.extractvalue: Sym.exec_extract
Inst.insertvalue: refused: SState.stmt has no case for it
Inst.extractelement: refused: SState.stmt has no case for it
Inst.insertelement: refused: SState.stmt has no case for it
Inst.shufflevector: refused: SState.stmt has no case for it
Inst.call: Sym.exec_sreg (a special register: no arguments, no fast-math flags, before any store);
Sym.exec_laneid (the lane number: no arguments, no fast-math flags, before any store);
Sym.exec_minmax (two arguments, no flags or attributes, before or after a store); refused (another
callee, arguments, fast-math flags, or after a store): SState.stmt takes calls of special registers
and of minmax only
Inst.atomicrmw: refused: SState.stmt has no case for it
Term.ret: Sym.SState.exit_sound (ret void); refused (ret with a value): SState.exit takes ret void
only
Term.br: Sym.SState.exit_sound (into blocks that start without a phi); Sym.SState.exitAt_sound (into
blocks that start with phis); refused (a condition or phi operand outside the fragment):
SState.exitAt gives none
Term.condBr: Sym.SState.exit_sound (into blocks that start without a phi); Sym.SState.exitAt_sound
(into blocks that start with phis); refused (a condition or phi operand outside the fragment):
SState.exitAt gives none
Term.switch: refused: SState.exitAt has no case for it
Term.unreachable: refused: SState.exitAt has no case for it
Intrinsic.sreg: Sym.exec_sreg (a special register: no arguments, no fast-math flags, before any
store)
Intrinsic.laneid: Sym.exec_laneid (the lane number: no arguments, no fast-math flags, before any
store)
Intrinsic.barrier: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.shfl: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.minmax: Sym.exec_minmax (two arguments, no flags or attributes, before or after a store);
refused (with other arguments, flags or attributes): SState.stmt takes minmax with two arguments and
no flags or attributes only
Intrinsic.fminmax: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.rsqrtApprox: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.lifetime: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.reduceAnd: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.extract: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.stepvector: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.griddepWait: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.griddepLaunch: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.cpAsyncCommit: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.cpAsyncWait: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.ldmatrix: refused: SState.stmt takes calls of special registers and of minmax only
Intrinsic.mma: refused: SState.stmt takes calls of special registers and of minmax only
-/
#guard_msgs (whitespace := lax) in
#mojo_rules Inst Term Intrinsic

/-! The failures. -/

/-- error: mojo_rule: MojoProofTest.Rule.TOp is not a constructor -/
#guard_msgs in
attribute [mojo_rule TOp] add_ne_mul

/-- error: mojo_rule: Nat.add is not a constructor -/
#guard_msgs in
mojo_refuse Nat.add : "not a constructor"

/-- error: mojo_rule: the attribute is global -/
#guard_msgs in
attribute [local mojo_rule TOp.add] add_ne_mul

end MojoProofTest.Rule
