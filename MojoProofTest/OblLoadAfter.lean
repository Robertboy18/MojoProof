import MojoProofTest.SymLane
import MojoProof.Sym.Obl
import MojoProofTest.Ops

/-!
# mojo_obl on a `load` after a `store`

A `load` after a `store` of its segment (`SNode.loadAfter`, MojoProof/Sym/LoadAfter.lean) is the
load from the memory the effects before it make. mojo_obl takes the effects from the last: a
`load` effect leaves the node as it is, a `store` at the load's pointer gives the stored value, a
`store` at a pointer apart from it is passed by, and with no effect left the node is the `load`
from the valuation's memory. The blocks here are hand-written twins of gevm_kernel's `%59`
(label `gevm.fn_0.b_5.label`, `gevm` of MojoProofTest/SymLane.lean) without its barrier: the
`store` of `%60` through `%64` (statement 5) and the `load` through `%66` (statement 9), both of
a binary32 in space 3 with alignment 4.

* `same`: after the `store` and a `load` effect, the `load` at the stored cell has a value (the
  stored float: `SNode.eval_loadAfter_log_ex`, `SNode.eval_loadAfter_store_codec`).
* `apart`: after the `store` to cell `i`, the `load` at cell `i' ≠ i` has a value (the entry
  memory's float at `i'`: `SNode.eval_loadAfter_apart_at`, `SNode.eval_loadAfter_nil` and the
  `load` node).
* `apart_open`: the twin of `apart`, `i ≠ i'` behind an irreducible definition
  (`MojoProofTest.Ops.Off`): the node's obligation is left open, as logged, and closed after
  `unfold`.

Tests of one program, gevm_kernel float32 `1308aaae`, at every context, memory and frame with
the stated registers; the lemmas (MojoProof/Sym/OblLemmas.lean) are for every program.
-/

namespace MojoProofTest.OblLoadAfter

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open FloatLib.Floats.Formats.BinaryInterchange

/-- The block of one node, the `load` of statement 9 of `%59` through `%66` after the effects
`es`, with no register, effect or obligation, which returns. -/
def afterB (es : List SEff) : Summary :=
  { nodes := [.loadAfter gevm.fn_0.b_5.label 9 (.reg 66) es], regs := [], effs := [], obls := [],
    exit := .ret, len := 1 }

/-- The `store` of statement 5 of `%59`: `%60` through `%64`. -/
def st5 : SEff := .store gevm.fn_0.b_5.label 5 (.reg 60) (.reg 64)

/-- **A `load` at the stored cell after a `store` and a `load` effect**: for every context `c` of
`gevm`'s program, step count `k`, memory `m`, frame `f` of its function, binary32 `z`, cell
`i < 1024` and shared block `b` that `m` has as a writable buffer of 4096 bytes aligned to 4,
owned by thread block `g` (which admits `c`'s thread), that fits in space 3, where `%60` is `z`
and `%64` and `%66` the pointer to cell `i` of `b`: the `load` of statement 9 after `st5` and the
`load` effect of statement 9 has a value (the stored `z`). -/
theorem same (c : Ctx) (hcp : c.prog = gevm.prog) (k : Nat) (m : Mem) (f : Frame)
    (hf : f.fn = gevm.fn_0) (z : Model FloatTy.float.fmt) (i : Nat) (hi : i < 1024) (b g : Nat)
    (h60 : f.regs 60 = some (Val.ofFloat .float z))
    (h64 : f.regs 64 = some (.ptr ⟨b, ((i * 4 : Nat) : Int)⟩))
    (h66 : f.regs 66 = some (.ptr ⟨b, ((i * 4 : Nat) : Int)⟩))
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1) :
    Cond.Holds (Valuation.entry c k m f)
      (vals (Valuation.entry c k m f) (afterB [st5, .load gevm.fn_0.b_5.label 9 (.reg 66)]).nodes)
      (.ok (.node 0)) := by
  mojo_obl

/-- **A `load` at another cell after a `store`**: for every context `c` of `gevm`'s program, step
count `k`, memory `m`, frame `f` of its function, binary32 `z`, cells `i, i' < 1024` with
`i ≠ i'`, shared block `b` as for `same`, holding the vector `A` of 1024 binary32, where `%60` is
`z`, `%64` the pointer to cell `i` of `b` and `%66` to cell `i'`: the `load` of statement 9 after
`st5` has a value (`A`'s at `i'`). -/
theorem apart (c : Ctx) (hcp : c.prog = gevm.prog) (k : Nat) (m : Mem) (f : Frame)
    (hf : f.fn = gevm.fn_0) (z : Model FloatTy.float.fmt) (i i' : Nat) (hi : i < 1024)
    (hi' : i' < 1024) (hne : i ≠ i') (b g : Nat)
    (h60 : f.regs 60 = some (Val.ofFloat .float z))
    (h64 : f.regs 64 = some (.ptr ⟨b, ((i * 4 : Nat) : Int)⟩))
    (h66 : f.regs 66 = some (.ptr ⟨b, ((i' * 4 : Nat) : Int)⟩))
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [1024])
    (hA : m.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A) :
    Cond.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) (afterB [st5]).nodes)
      (.ok (.node 0)) := by
  mojo_obl

/--
info: mojo_obl: open goal
  Cond.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) (afterB [st5]).nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `apart`**: `apart`'s premises with `i ≠ i'` stated as `Ops.Off i i'`; the
pointers are neither of one value nor, by `omega`, apart, so mojo_obl leaves the node's
obligation open, as logged, and closes it after `unfold Ops.Off`. -/
theorem apart_open (c : Ctx) (hcp : c.prog = gevm.prog) (k : Nat) (m : Mem) (f : Frame)
    (hf : f.fn = gevm.fn_0) (z : Model FloatTy.float.fmt) (i i' : Nat) (hi : i < 1024)
    (hi' : i' < 1024) (hne : Ops.Off i i') (b g : Nat)
    (h60 : f.regs 60 = some (Val.ofFloat .float z))
    (h64 : f.regs 64 = some (.ptr ⟨b, ((i * 4 : Nat) : Int)⟩))
    (h66 : f.regs 66 = some (.ptr ⟨b, ((i' * 4 : Nat) : Int)⟩))
    (hB : m.BufferIn 3 b 4096 4 (.cta g) true) (hin : (Owner.cta g).admits c.who = true)
    (hF : ∃ blk, m.blocks b = some blk ∧ blk.addr + 4096 ≤ 2 ^ (gevm.prog.layout.ptr 3).1)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [1024])
    (hA : m.Holds gevm.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor gevm.prog.layout (.fp .float) 0) A) :
    Cond.Holds (Valuation.entry c k m f) (vals (Valuation.entry c k m f) (afterB [st5]).nodes)
      (.ok (.node 0)) := by
  mojo_obl
  unfold Ops.Off at hne
  mojo_obl

end MojoProofTest.OblLoadAfter
