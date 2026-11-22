import MojoProof.Sym.RuleAttr
import MojoProof.Sym.Block

/-!
# The block checker's rule table

The rules and refusals of the block checker (`SState.stmt` and `SState.exitAt`,
MojoProof/Sym/Checker.lean) for every constructor of `Inst` (19), `Term` (5) and `Intrinsic` (17),
by `@[mojo_rule]` and mojo_refuse (MojoProof/Sym/RuleAttr.lean). The rules are the lemmas of
MojoProof/Sym/Block.lean, tagged here from another module: `exec_bin`, `exec_icmp`, `exec_cast`,
`exec_extract`, `exec_gep`, `exec_load`, `exec_store`, `exec_fbin`, `exec_fbinC` (with `fmul
contract`, in the fragment of `coversC`), `exec_select`, `exec_sreg` and `exec_minmax` (a
statement's step), and `SState.exit_sound` and `SState.exitAt_sound` (a terminator's step). A
refusal's reason is the case of `SState.stmt` or `SState.exitAt` that gives `none`. The last
command, `mojo_rules_complete Inst Term Intrinsic`, fails the build when a constructor has neither a
rule nor a refusal: a constructor added to `Inst`, `Term` or `Intrinsic` needs an entry here.
-/

namespace MojoProof.Sym

open MojoProof.LLVM

attribute [mojo_rule Inst.bin] exec_bin
attribute [mojo_rule Inst.icmp "on an integer type, before any store"] exec_icmp
attribute [mojo_rule Inst.cast "trunc, zext and sext"] exec_cast
attribute [mojo_rule Inst.extractvalue] exec_extract
attribute [mojo_rule Inst.gep "one index, before any store"] exec_gep
attribute [mojo_rule Inst.load "before any store"] exec_load
attribute [mojo_rule Inst.store] exec_store
attribute [mojo_rule Inst.fbin "on a float element type, but fmul contract"] exec_fbin
attribute [mojo_rule Inst.fbin "on a float element type, fmul contract included, with coversC"]
  exec_fbinC
attribute [mojo_rule Inst.select "of integers"] exec_select
attribute [mojo_rule Inst.call Intrinsic.sreg
  "a special register: no arguments, no fast-math flags, before any store"] exec_sreg
attribute [mojo_rule Inst.call Intrinsic.minmax
  "two arguments, no flags or attributes, before or after a store"] exec_minmax
attribute [mojo_rule Term.ret "ret void"] SState.exit_sound
attribute [mojo_rule Term.br Term.condBr "into blocks that start without a phi"] SState.exit_sound
attribute [mojo_rule Term.br Term.condBr "into blocks that start with phis"] SState.exitAt_sound

mojo_refuse Inst.icmp "on a non-integer type, or after a store" :
  "SState.stmt takes icmp on an integer type before the block's first store only"
mojo_refuse Inst.cast "the other casts" : "SState.stmt takes trunc, zext and sext only"
mojo_refuse Inst.gep "not one index, or after a store" :
  "SState.stmt takes a gep with one index before the block's first store only"
mojo_refuse Inst.load "after a store" :
  "SState.stmt takes a load before the block's first store only"
mojo_refuse Inst.fbin "fmul contract without coversC, or a non-float element type" :
  "SState.stmt takes a contracted fmul only with its contract flag and no fbin on a non-float \
  element type"
mojo_refuse Inst.select "of floats, pointers or vectors" :
  "SState.stmt takes select of integers only"
mojo_refuse Inst.fneg Inst.fcmp Inst.alloca Inst.insertvalue Inst.extractelement
  Inst.insertelement Inst.shufflevector Inst.atomicrmw : "SState.stmt has no case for it"
mojo_refuse Inst.phi : "set on the edge into its block (SState.phiConds), not by SState.stmt"
mojo_refuse Inst.call "another callee, arguments, fast-math flags, or after a store" :
  "SState.stmt takes calls of special registers and of minmax only"
mojo_refuse Term.ret "ret with a value" : "SState.exit takes ret void only"
mojo_refuse Term.br Term.condBr "a condition or phi operand outside the fragment" :
  "SState.exitAt gives none"
mojo_refuse Term.switch Term.unreachable : "SState.exitAt has no case for it"
mojo_refuse Intrinsic.minmax "with other arguments, flags or attributes" :
  "SState.stmt takes minmax with two arguments and no flags or attributes only"
mojo_refuse Intrinsic.laneid Intrinsic.barrier Intrinsic.shfl Intrinsic.fminmax
  Intrinsic.rsqrtApprox Intrinsic.lifetime Intrinsic.reduceAnd Intrinsic.extract
  Intrinsic.stepvector Intrinsic.griddepWait Intrinsic.griddepLaunch Intrinsic.cpAsyncCommit
  Intrinsic.cpAsyncWait Intrinsic.ldmatrix Intrinsic.mma :
  "SState.stmt takes calls of special registers and of minmax only"

mojo_rules_complete Inst Term Intrinsic

end MojoProof.Sym
