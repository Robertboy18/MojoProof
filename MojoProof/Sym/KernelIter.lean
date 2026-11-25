import MojoProof.Sym.KernelMat
import MojoProof.Sym.LoopFacts
import MojoProof.Sym.OblHave

/-!
# A matmul kernel's loop at the heads of its rounds

docs/proofs/kernel.md. `RetLsWith.of_inv` (Sym/KernelMat.lean) asks for a loop's round at every
valuation where the invariant holds, so the invariant must carry every fact the round needs, the
registers that the loop keeps and the memory facts among them. Here the premises are stated at
the heads of the rounds themselves, the iterates `R^[i] V₀` of the round
`R = Valuation.roundWith contract L.h L.H L.B` from the header's entry valuation `V₀`, with the
facts `F` that hold at every one of them as a premise of each round and of the path out.

* `LoopIterWith`: the three premises at the iterates, with `F` at each.
* `LoopIterWith.toInv`: with `F` at every iterate, `LoopIterWith` gives `LoopInvWith`
  (Sym/KernelMat.lean) at the invariant `W = R^[i] V₀ ∧ I i W`. For every program and every loop.
* `RetLsWith.of_iter`: a thread's run through one loop with no nested loop from the edge into the
  loop, `F` at every iterate and `LoopIterWith` (`RetLsWith.of_inv` at `LoopIterWith.toInv`). For
  every program and every such loop.
* `LoopSeg.bases`: the registers a loop keeps that its loop path loads through, the registers
  `rs` of `LoopSeg.loadsFrom`.
* `Mat.Head`: the facts at a valuation of a matmul kernel that rounds which only read keep: its
  function, the three buffers of `Mat.Entry`, `Elem` and `Elem.Only` at the output block.
* `Mat.Head.iterate`: `Mat.Head` at `V` gives it at every iterate, for every loop whose loop path
  reads memory only through registers it keeps (`LoopSeg.loadsFrom`) whose values at `V` name
  blocks other than the output (`Valuation.iterate_blocks`, `Valuation.iterate_elem`,
  `Valuation.iterate_only`). For every program and every loop.

The `mat … inv` clause of `mojo_kernel` (Sym/KernelCmd.lean) states its `n.runInv` and
`n.sound_inv` over `LoopIterWith` at `F = Mat.Head …`, and proves `Mat.Head` at every iterate:
at the loop head by mojo_inv, then by `Mat.Head.iterate` at `LoopSeg.bases`. The registers that
the loop keeps are then those at the loop head (`LoopSeg.kept_round`; mojo_inv's first step on
an iterate), so an invariant need not carry them.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **The premises of a loop's run at the heads of its rounds, with or without
`fmul contract`.** For every flag `contract`, loop `L`, valuation `V`, path `(l, _, S) :: E`
before the loop, predicate `Q` on memories, trip count `n`, facts `F` on valuations and
invariant `I` indexed by the round, with `V₀ = Valuation.roundWith contract l S E V` the header's
entry valuation and `R = Valuation.roundWith contract L.h L.H L.B` the round:

* `head`: `I 0` holds at `V₀`;
* `round`: for every round `i < n`, if `R^[i] V₀` has `V`'s context and round `i`'s step count,
  and `F` and `I i` hold there, the premises of a round hold there (`RoundWith contract`) and
  `I (i + 1)` holds after it;
* `exit`: if `R^[n] V₀` has `V`'s context and round `n`'s step count, and `F` and `I n` hold
  there, the path out of the loop runs from it to `ret` with a memory of `Q`
  (`RetWith contract`).

`LoopInvWith` (Sym/KernelMat.lean) states the round and the path out at every valuation where
`I` holds; here they are at the iterates alone. -/
structure LoopIterWith (contract : Bool) (L : LoopSeg) (V : Valuation) (l : Nat) (S : Summary)
    (E : List (Nat × List Cond × Summary)) (Q : Mem → Prop) (n : Nat) (F : Valuation → Prop)
    (I : Nat → Valuation → Prop) : Prop where
  /-- Builds `LoopIterWith` from its fields. -/
  mk ::
  /-- `I 0` holds at the header's entry valuation after the path. -/
  head : I 0 (Valuation.roundWith contract l S E V)
  /-- For every round `i < n`, at the head of round `i` with `V`'s context and round `i`'s step
  count where `F` and `I i` hold, the premises of a round (`RoundWith contract`) and `I (i + 1)`
  after the round. -/
  round : ∀ i < n,
    ((Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V)).ctx =
      V.ctx →
    ((Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V)).k =
      (Valuation.roundWith contract l S E V).k + i * (pathLen L.H L.B + 1) →
    F ((Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V)) →
    I i ((Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V)) →
    RoundWith contract L.h L.p L.dh L.H L.B
        ((Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V)) ∧
      I (i + 1) (Valuation.roundWith contract L.h L.H L.B
        ((Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V)))
  /-- At the head of round `n` with `V`'s context and round `n`'s step count where `F` and `I n`
  hold, the path out of the loop to `ret` with a memory of `Q` (`RetWith contract`). -/
  exit :
    ((Valuation.roundWith contract L.h L.H L.B)^[n] (Valuation.roundWith contract l S E V)).ctx =
      V.ctx →
    ((Valuation.roundWith contract L.h L.H L.B)^[n] (Valuation.roundWith contract l S E V)).k =
      (Valuation.roundWith contract l S E V).k + n * (pathLen L.H L.B + 1) →
    F ((Valuation.roundWith contract L.h L.H L.B)^[n] (Valuation.roundWith contract l S E V)) →
    I n ((Valuation.roundWith contract L.h L.H L.B)^[n] (Valuation.roundWith contract l S E V)) →
    RetWith contract
      ((Valuation.roundWith contract L.h L.H L.B)^[n] (Valuation.roundWith contract l S E V)) Q
      ((L.h, L.dh, L.H) :: L.X)

/-- **The heads of the rounds as an invariant at every valuation, with or without
`fmul contract`.** For every flag `contract`, loop `L`, valuation `V`, path `(l, _, S) :: E`
before the loop, predicate `Q`, trip count `n`, facts `F` and invariant `I`: if `F` holds at the
head of every round (`R^[i] V₀`, as in `LoopIterWith`) and `LoopIterWith` holds, then
`LoopInvWith` holds at the invariant `W = R^[i] V₀ ∧ I i W` (a valuation of it is the head of
round `i`, and the round takes it to the head of round `i + 1`). For every program and every
loop. -/
theorem LoopIterWith.toInv {contract : Bool} {L : LoopSeg} {V : Valuation} {l : Nat}
    {S : Summary} {E : List (Nat × List Cond × Summary)} {Q : Mem → Prop} {n : Nat}
    {F : Valuation → Prop} {I : Nat → Valuation → Prop}
    (hF : ∀ i,
      F ((Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V)))
    (H : LoopIterWith contract L V l S E Q n F I) :
    LoopInvWith contract L V l S E Q n (fun i W => W =
      (Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V) ∧
        I i W) where
  head := ⟨rfl, H.head⟩
  round i hi W hc hk := fun ⟨hW, hI⟩ => by
    subst hW
    exact ⟨(H.round i hi hc hk (hF i) hI).1, (Function.iterate_succ_apply' _ i _).symm,
      (H.round i hi hc hk (hF i) hI).2⟩
  exit W hc hk := fun ⟨hW, hI⟩ => by
    subst hW
    exact H.exit hc hk (hF n) hI

/-- **A thread's run through one loop from its rounds' heads, with or without
`fmul contract`.** For every flag `contract`, predicate `Q` on memories, loop `L` with no nested
loop, path `(l, ds, S) :: E` before it, valuation `V`, trip count `n`, facts `F` and invariant
`I`: if the path's premises hold at `V` and its last edge goes to `L.h` at position `L.p`
(`EdgeWith contract`), `F` holds at the head of every round (`R^[i] V₀`, as in `LoopIterWith`)
and `LoopIterWith` holds, then the thread runs from `V` through the loop to `ret` with a memory
of `Q` (`RetLsWith contract Q [L]`). The proof is `RetLsWith.of_inv` at the invariant
`W = R^[i] V₀ ∧ I i W` (`LoopIterWith.toInv`). For every program and every loop with no nested
loop. -/
theorem RetLsWith.of_iter {contract : Bool} {Q : Mem → Prop} {L : LoopSeg} (hL : L.inner = [])
    {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} {n : Nat} {F : Valuation → Prop}
    {I : Nat → Valuation → Prop} (hE : EdgeWith contract L.h L.p V l ds S E)
    (hF : ∀ i,
      F ((Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V)))
    (H : LoopIterWith contract L V l S E Q n F I) : RetLsWith contract Q [L] V l ds S E :=
  RetLsWith.of_inv hL n _ hE (H.toInv hF).head (H.toInv hF).round (H.toInv hF).exit

/-- The registers that loop `L` of function `F` keeps (`LoopSeg.kept`) and that some load of its
loop path `L.H :: L.B` has as its pointer's base (`SVal.baseIn`), in `LoopSeg.kept`'s order: the
registers `rs` at which `LoopSeg.loadsFrom F L rs` holds when every load of the loop path has its
base in a register the loop keeps. A `List Nat`, evaluated. -/
def LoopSeg.bases (F : Func) (L : LoopSeg) : List Nat :=
  (L.kept F).filter fun r => (L.H :: L.B.map (·.2.2)).any fun S => S.effs.any fun
    | .load _ _ p => p.baseIn S.nodes [r]
    | .store .. | .alloca .. => false

/-- **The facts at a valuation of a matmul kernel that rounds which only read keep.** For program
`prog`, kernel `fn`, element type `t` with encoder `enc`, alignment `al`, block numbers `o`
(output), `a`, `b` (inputs), row stride `sC`, tensors `x` (`m × sA`) and `y` (`n × sB`), cell
width `w`, cells `cell`, bytes `bs`, count of threads `k`, memory `m₀` before the threads, set
`T` of threads and valuation `W`: `W`'s function is `fn`, on `W`'s memory the buffers of
`Mat.Entry` (`a` and `b` read-only holding `x` and `y`, `o` writable, the three fitting their
spaces), `Elem` after `k` threads at `o` and `Elem.Only` at `o` for `T`. The `mat … inv` clause
(Sym/KernelCmd.lean) gives it at the head of every round of the loop. -/
structure Mat.Head (prog : Program) (fn : Func) {α : Type} [TorchLean.Storage α] (t : Ty)
    (enc : α → Val) (al o a b sC : Nat) {m n sA sB : Nat} (x : TorchLean.Tensor α [m, sA])
    (y : TorchLean.Tensor α [n, sB]) (w : Nat) (cell : Nat → Nat)
    (bs : Nat → Option (List MemByte)) (k : Nat) (m₀ : Mem) (T : Nat → Prop) (W : Valuation) :
    Prop where
  /-- Builds `Mat.Head` from its fields. -/
  mk ::
  /-- `W`'s function is `fn`. -/
  func : W.fn = fn
  /-- `a` is a read-only buffer of `m * sA` elements aligned to `al` that fits its space and
  holds `x` row-major from offset 0. -/
  bufA : W.mem.Buffer a (m * sA * prog.layout.size t) al false ∧
    W.mem.Fits prog.layout a (m * sA * prog.layout.size t) ∧
    W.mem.Holds prog.layout a t enc (rowMajor prog.layout t 0) x
  /-- `b` is a read-only buffer of `n * sB` elements aligned to `al` that fits its space and
  holds `y` row-major from offset 0. -/
  bufB : W.mem.Buffer b (n * sB * prog.layout.size t) al false ∧
    W.mem.Fits prog.layout b (n * sB * prog.layout.size t) ∧
    W.mem.Holds prog.layout b t enc (rowMajor prog.layout t 0) y
  /-- `o` is a writable buffer of `m * sC` elements aligned to `al` that fits its space. -/
  bufC : W.mem.Buffer o (m * sC * prog.layout.size t) al true ∧
    W.mem.Fits prog.layout o (m * sC * prog.layout.size t)
  /-- The memory meets `Elem` after `k` threads at `o`. -/
  elem : Elem m₀ o w cell bs k W.mem
  /-- The memory's accesses to `o` are by threads of `T`. -/
  only : Elem.Only o T W.mem

/-- **Rounds that only read keep `Mat.Head`**: for every program, kernel `fn`, element type,
encoder, alignment, blocks, row stride, tensors, cell width, cells, bytes, count of threads,
memory `m₀`, set of threads, flag `c`, loop `L` and registers `rs` through which alone its loop
path reads memory and which it keeps (`LoopSeg.loadsFrom`), valuation `V` at which `Mat.Head`
holds and whose registers `rs` have values naming only blocks other than the output `o`, and
count `i`: `Mat.Head` holds after `i` rounds. The function by `Valuation.roundWith_k`, the
buffers by `Valuation.iterate_blocks` (`Mem.Buffer.of_block`, `Mem.Fits.of_block`,
`Mem.Holds.of_block`), `Elem` and `Elem.Only` by `Valuation.iterate_elem` and
`Valuation.iterate_only`. For every program and every loop (with nested loops, its loop path
alone). -/
theorem Mat.Head.iterate {prog : Program} {fn : Func} {α : Type} [TorchLean.Storage α] {t : Ty}
    {enc : α → Val} {al o a b sC : Nat} {m n sA sB : Nat} {x : TorchLean.Tensor α [m, sA]}
    {y : TorchLean.Tensor α [n, sB]} {w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {k : Nat} {m₀ : Mem} {T : Nat → Prop} {c : Bool}
    {L : LoopSeg} {rs : List Nat} (hL : L.loadsFrom fn rs = true) {V : Valuation}
    (hH : Mat.Head prog fn t enc al o a b sC x y w cell bs k m₀ T V)
    (hr : ∀ r ∈ rs, ∃ v, V.regs r = some v ∧ v.NamesIn (· ≠ o)) (i : Nat) :
    Mat.Head prog fn t enc al o a b sC x y w cell bs k m₀ T
      ((Valuation.roundWith c L.h L.H L.B)^[i] V) := by
  have hq (q : Nat) := Mem.blocks_keep (Valuation.iterate_blocks (c := c) hL hH.func
    (fun r h => by
      obtain ⟨v, hv, -⟩ := hr r h
      simp [hv]) i).1 q
  exact
    { func := (Valuation.roundWith_k c L.h L.H L.B i V).2.1.trans hH.func
      bufA := ⟨hH.bufA.1.of_block (hq _), hH.bufA.2.1.of_block (hq _),
        hH.bufA.2.2.of_block (hq _)⟩
      bufB := ⟨hH.bufB.1.of_block (hq _), hH.bufB.2.1.of_block (hq _),
        hH.bufB.2.2.of_block (hq _)⟩
      bufC := ⟨hH.bufC.1.of_block (hq _), hH.bufC.2.of_block (hq _)⟩
      elem := Valuation.iterate_elem hL hH.func hr hH.elem i
      only := Valuation.iterate_only hL hH.func hr hH.only i }

end MojoProof.Sym
