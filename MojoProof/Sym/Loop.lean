import MojoProof.Sym.Info
import MojoProof.Sym.Sched

/-!
# Loops

`Block.sound_loop`: soundness of a loop for every trip count, by induction on it. `Round.of_inv`,
`Block.sound_loop_inv`, `Chain.reach`, `Runs.of_chain` and `Runs.of_loop`: the same from an
invariant, and a thread through a sequence of loops, with loops nested in their rounds, or
through one loop, to its end. All are proved once for every program, function, path, list of
loops, nesting, trip count and invariant.

A loop is a path `(h, ds, S) :: B` of the control-flow graph that starts at its header `h`,
entered at position `p` (after its `phi`s). It runs through the body to the latch, whose exit
goes back to `h` (the back edge; `Exit.phi` when `h` starts with `phi`s, which the step sets).
`Valuation.round` is the valuation after a path's last edge: `Valuation.into` of its last block
from that block's entry valuation (`Valuation.lastI`). For a loop path this is the header's
valuation after one round. `Edge h p` is the premise of a path and its last edge: the path's
premises hold (`WalkI`), and its last block's exit goes to `h` (`Exit.dest`) at position `p`
(`Exit.pc`). `Round` is `Edge` of a loop path back to its own header. `Back h p J` is `Edge h p`
and `J` at the valuation after the edge.

Loops nest. A loop `L : LoopSeg` has a loop path from its header `L.h`, the loops
`L.inner` that each round runs after the loop path, and a path out. A round runs the loop path,
whose last exit goes to the first nested loop's header, then each nested loop, whose path out
goes to the next nested loop's header or, for the last, back to `L.h`. With no nested loop the
loop path's last exit goes back to `L.h` (a straight loop). `Chain F Ls V l ds S E`, an inductive
predicate, is a run from valuation `V` at the path `(l, ds, S) :: E` through the loops `Ls` in
order to a last path at whose entry valuation `F` holds: each loop entered by the path before it
(`Edge`), run from an invariant whose rounds are `Chain`s through its nested loops ending with
`Back` to its header, and left by its path out.

The results hold for every program `P`, every context of `P`, and every thread whose innermost
frame `f` runs `fn` on memory `m`. In each, the frames reached keep `f`'s `alloca` blocks and
caller's register.

* `Block.sound_edge`: take a path that the path checker with `phi`s accepts (`coversPathI`) and
  whose last exit goes to `d`. If the path's premises hold, the thread's steps reach block `d` at
  position `Exit.pc fn d`, with entry valuation `Valuation.round` of `f`'s.
* `Block.sound_rounds`: take a block `h`, a position `p`, an invariant `I` indexed by the round
  number and a trip count `n`. If each round `i < n` takes every thread at `h`'s position `p`
  with `I i` at its entry valuation to that position again with `I (i + 1)`, then the rounds
  take a thread there with `I 0` to that position with `I n` (induction on `n`).
* `Block.sound_loop`: take a loop path accepted from `p`, a trip count `n`, and a thread at block
  `h`'s position `p`. If the premises of rounds 0 to `n - 1` hold (`Round` at `round^[i]` of the
  entry valuation), the thread's steps reach `h`'s position `p` again, with entry valuation
  `round^[n]` of the first (`Block.sound_rounds`, each round by `Block.sound_edge`). The trip
  count is a premise: the theorem says nothing about termination.
* `Round.of_inv`: suppose an invariant `I i` (indexed by the round number `i`) holds at round 0,
  and for every `i < n` and every valuation `W`, `I i W` gives `Round` at `W` and
  `I (i + 1) (round W)`. Then the premises of rounds 0 to `n - 1` hold, and so does `I n` after
  them. An invariant `J` that does not depend on the round is `fun _ => J`.
* `Block.sound_loop_inv`: `Block.sound_loop` with its premises from `Round.of_inv`. The valuation
  reached satisfies `I n`.
* `Chain.reach`: take loops `Ls` after a path `(l, ds, S) :: E` such that the path checker with
  `phi`s accepts the path, the paths of every round with its nested loops, and every path out
  (`coversChain`, with `LoopSeg.coversRound` for a round). Take a thread at block `l`'s position
  `p0` with `Chain F Ls` at its entry valuation. Its steps reach the first block of a last path
  that the checker accepts, with `F` at its entry valuation. The proof is by induction on
  `Chain`: `Block.sound_edge` into each loop, `Block.sound_rounds` through its rounds (each by
  the induction hypothesis and `Block.sound_edge` of its `Back`), and the induction hypothesis on
  its path out.
* `Runs.of_chain`: `RetLs Q` is `Chain` whose last path runs to `ret` with a memory of `Q`
  (`Ret`). A thread with one frame at the path's first block and `RetLs` at its entry valuation
  runs to its end (`Runs`), leaving that memory with `f`'s `alloca` blocks dead (`Chain.reach`,
  then `Block.sound_retI`). `Runs.of_loop` is `Runs.of_chain` with one loop (`LoopPaths extends
  LoopSeg`; `LoopPaths.covers` and `RetL` are `coversChain` and `RetLs` of `[L.toLoopSeg]`).
* `Chain.of_iter`: `Chain` through a first loop with the invariant "the `i`-th iterate of a
  function `g` from the header's entry valuation", from the `Chain`s of the rounds at the
  iterates (each ending with `Back` to the header at `g` of its first valuation) and the `Chain` of
  the path out at the `n`-th iterate. `Chain.of_rounds`: for a loop with no nested loop, with `g`
  the loop path's `Valuation.round`, from the premises of the rounds at the iterates. On a
  concrete valuation and trip count they are closed propositions that the kernel decides.
* `Runs.of_chains` and `Runs.of_loops`: the same for the threads `Grid.start` makes (one frame at
  the first block, position 0, no `alloca` blocks), with the starts and paths checked by one
  closed Boolean (`coversChains` for sequences of loops `LoopChain`, `coversLoops` for one loop
  each): the thread runs to its end, leaving a memory of `Q`. This is the form of the per-thread
  premise of `Seq.start_sound_inv`, as `Runs.of_ret` gives for straight-line paths.
  `Runs.of_loops` is `Runs.of_chains` at `LoopPaths.chain`.

`backEdges fn`: the branches of `fn` from a block to a block at the same or an earlier position
in its block order, as pairs of labels (latch, header), as `#mojo_info` lists them
(MojoProof/Sym/Info.lean); `cutPoints fn`: the labels of their targets, the headers, where a
loop's rounds start.

Steps of an invariant's preservation proof, for every valuation, summary, layout and memory (used
by the counting loop of MojoProofTest/SymLoop.lean for every trip count):
* `Valuation.into_of_enter`: across an edge into blocks with `phi`s (`Exit.phi`), the target's
  entry valuation has the registers of the frame `enter` gives;
* `Mem.addr_own`: a pointer's address in its block's own address space;
* `Mem.store_of_check`: the memory a store makes when `Mem.check` admits it and the block is
  writable (with `Block.read_put_self` and `Block.read_put_apart` of MojoProof/Sem/Buffer.lean,
  load after store).
* `Mem.foldl_setLive_blocks`, `Mem.foldl_setLive_load`: setting the liveness of a list of blocks
  (the cleanup of a frame's `alloca` blocks by `ret`) keeps every other block and its loads, so
  the memory `Runs` ends with has the output cells of blocks outside the frame's `alloca` blocks.

What is automated, and what is not. The loop checks (`coversChain`, `coversChains`,
`coversLoops`) are closed Booleans that the kernel evaluates (`decide +kernel`). On a concrete
valuation and trip count, `Chain.of_rounds` turns a loop with no nested loop into closed
propositions that the kernel decides. Nothing here finds an invariant or proves its preservation
for every trip count: that proof is written by hand for each loop (as `cnt_retL` in
MojoProofTest/SymLoop.lean, for the summaries of its one function). The trip count is a premise,
so nothing here proves termination. The kernel theorem `Kernel.sound_of_chains` takes for each
thread a path to a `ret` (`Ret`) or a sequence of loops (`RetLs`, through `Runs.of_chains`), and
the command `mojo_kernel` builds it for loops in sequence from one `loop` clause per loop, with
the invariant and trip count given by the user; it refuses a nested loop and a loop without a
clause. No kernel of the library is proved that way.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The back edges of `fn`: `(l, d)` for a branch from block `l` to block `d` at the same or an
earlier position in `fn`'s block order. -/
def backEdges (fn : Func) : List (Nat × Nat) :=
  let pos (l : Nat) : Nat := (fn.blocks.toList.findIdx? (·.label == l)).getD 0
  fn.blocks.toList.zipIdx.flatMap fun (b, i) =>
    (succs b.term).filterMap fun d => if pos d ≤ i then some (b.label, d) else none

/-- The labels of the loop headers of `fn` (the targets of its back edges): the cut points. -/
def cutPoints (fn : Func) : List Nat := ((backEdges fn).map (·.2)).eraseDups

/-- The valuation after the last edge of the path `(h, _, S) :: B` from valuation `V` at its first
block: `Valuation.into` of the path's last block from its entry valuation. For a loop path from
the header `h`, the valuation at the header after one round. -/
def Valuation.round (h : Nat) (S : Summary) (B : List (Nat × List Cond × Summary))
    (V : Valuation) : Valuation :=
  (V.lastI h S B).1.into (V.lastI h S B).2.1 (V.lastI h S B).2.2

/-- The premises of the path `(l, ds, S) :: E` from valuation `V` at its first block and of its
last edge into block `h` at position `p`: the path's premises hold (`WalkI`), and its last
block's exit goes to `h` (`Exit.dest`) at position `p` (`Exit.pc`). -/
def Edge (h p : Nat) (V : Valuation) (l : Nat) (ds : List Cond) (S : Summary)
    (E : List (Nat × List Cond × Summary)) : Prop :=
  WalkI V ((l, ds, S) :: E) ∧
    (V.lastI l S E).2.2.exit.dest (V.lastI l S E).1
      (vals (V.lastI l S E).1 (V.lastI l S E).2.2.nodes) = some h ∧
    (V.lastI l S E).2.2.exit.pc V.fn h = p

/-- Whether a path's premises hold and its last edge goes to block `h` at position `p`, decided
by evaluating them (the kernel reduces it on a concrete valuation). -/
instance Edge.dec (h p : Nat) (V : Valuation) (l : Nat) (ds : List Cond) (S : Summary)
    (E : List (Nat × List Cond × Summary)) : Decidable (Edge h p V l ds S E) :=
  inferInstanceAs (Decidable (WalkI V ((l, ds, S) :: E) ∧
    (V.lastI l S E).2.2.exit.dest (V.lastI l S E).1
      (vals (V.lastI l S E).1 (V.lastI l S E).2.2.nodes) = some h ∧
    (V.lastI l S E).2.2.exit.pc V.fn h = p))

/-- The premises of one round of the loop path `(h, ds, S) :: B` from header valuation `V`: the
path's (`WalkI`), and the latch's exit goes to `h` (`Exit.dest`) at position `p` (`Exit.pc`);
`Edge` of the path into its own first block. -/
def Round (h p : Nat) (ds : List Cond) (S : Summary) (B : List (Nat × List Cond × Summary))
    (V : Valuation) : Prop :=
  Edge h p V h ds S B

/-- Whether a round's premises hold, decided by evaluating them (`Edge.dec`). -/
instance Round.dec (h p : Nat) (ds : List Cond) (S : Summary)
    (B : List (Nat × List Cond × Summary)) (V : Valuation) : Decidable (Round h p ds S B V) :=
  Edge.dec h p V h ds S B

/-- The end of a round of a loop with header `h`, entered at position `p`: the path
`(l, ds, S) :: E` from valuation `V` and its last edge go back to `h` at `p` (`Edge`), and `J`
holds at the header's entry valuation after it (`Valuation.round`). -/
def Back (h p : Nat) (J : Valuation → Prop) (V : Valuation) (l : Nat) (ds : List Cond)
    (S : Summary) (E : List (Nat × List Cond × Summary)) : Prop :=
  Edge h p V l ds S E ∧ J (Valuation.round l S E V)

/-- **A path and its last edge.** Take a program, a function and a path `(l, ds, S) :: ps` that the
path checker with `phi`s accepts from position `p0` (`coversPathI`). Take a context of the
program and a thread whose innermost frame `f` is at block `l`'s position `p0`. Suppose the
path's premises hold (`WalkI`) and its last block's exit goes to `d` (`Exit.dest`). Then the
thread's steps reach a frame of the function above the same frames, at block `d`'s position
`Exit.pc fn d` (after `d`'s `phi`s for `Exit.phi`), with `f`'s `alloca` blocks and caller's
register. Its entry valuation is `Valuation.round l S ps` of `f`'s (`Block.sound_pathI`, then
`Ends.edge`). -/
theorem Block.sound_edge {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} {l p0 d : Nat} {ds : List Cond} {S : Summary}
    {ps : List (Nat × List Cond × Summary)} (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hd : ((Valuation.entry c t.k m f).lastI l S ps).2.2.exit.dest
      ((Valuation.entry c t.k m f).lastI l S ps).1
      (vals ((Valuation.entry c t.k m f).lastI l S ps).1
        ((Valuation.entry c t.k m f).lastI l S ps).2.2.nodes) = some d) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = d ∧
      f'.pc = ((Valuation.entry c t.k m f).lastI l S ps).2.2.exit.pc fn d ∧
      f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      Valuation.entry c t'.k m' f' = Valuation.round l S ps (Valuation.entry c t.k m f) := by
  have hE := Block.sound_pathI hP ps hc ht hfn hl hp hW
  have hk := Valuation.lastI_k (Valuation.entry c t.k m f) l S ps
  show ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = d ∧
      f'.pc = ((Valuation.entry c t.k m f).lastI l S ps).2.2.exit.pc fn d ∧
      f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      Valuation.entry c t'.k m' f' = ((Valuation.entry c t.k m f).lastI l S ps).1.into
        ((Valuation.entry c t.k m f).lastI l S ps).2.1
        ((Valuation.entry c t.k m f).lastI l S ps).2.2
  revert hd hE hk
  generalize (Valuation.entry c t.k m f).lastI l S ps = q
  obtain ⟨W, l', S'⟩ := q
  rintro hd hE ⟨hWc, hWfn, -⟩
  obtain ⟨t₁, m₁, f', hS₁, hst₁, hfn', hl', hp', hal', hde', hV⟩ := Ends.edge (c := c) hWc hE hd
  exact ⟨_, m₁, f', Steps.trans_step hS₁ hst₁ (.refl _ _), rfl, hfn'.trans (hWfn.trans hfn), hl',
    hp'.trans (congrArg (fun g => S'.exit.pc g d) (hWfn.trans hfn)), hal', hde', hV⟩

/-- **Rounds from an invariant, by induction on the trip count.** Take a context, function `fn`,
frames `rest`, block `h`, position `p`, invariant `I` indexed by the round number and trip count
`n`. Suppose that for every `i < n`, every thread whose innermost frame `f` runs `fn` above
`rest` at `h`'s position `p`, with `I i` at its entry valuation, steps to a frame of `fn` above
`rest` at `h`'s position `p`, with `f`'s `alloca` blocks and caller's register and `I (i + 1)` at
its entry valuation. Then every such thread with `I 0` steps to such a frame with `I n`. For
every context, function, block, invariant and trip count; a round is one loop path
(`Block.sound_loop`) or runs nested loops (`Chain.reach`). -/
theorem Block.sound_rounds {c : Ctx} {fn : Func} {rest : List Frame} {h p : Nat}
    (I : Nat → Valuation → Prop) (n : Nat)
    (hr : ∀ i < n, ∀ (t : Thread) (m : Mem) (f : Frame), t.frames = f :: rest → f.fn = fn →
      f.label = h → f.pc = p → I i (Valuation.entry c t.k m f) →
      ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = h ∧
        f'.pc = p ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
        I (i + 1) (Valuation.entry c t'.k m' f'))
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = h) (hp : f.pc = p) (h0 : I 0 (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = h ∧
      f'.pc = p ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      I n (Valuation.entry c t'.k m' f') := by
  induction n with
  | zero => exact ⟨t, m, f, .refl t m, ht, hfn, hl, hp, rfl, rfl, h0⟩
  | succ n ih =>
    obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hfn₁, hl₁, hp₁, hal₁, hde₁, hI₁⟩ :=
      ih fun i hi => hr i (by omega)
    obtain ⟨t', m', f', hS, ht', hfn', hl', hp', hal, hde, hI⟩ :=
      hr n (by omega) t₁ m₁ f₁ ht₁ hfn₁ hl₁ hp₁ hI₁
    exact ⟨t', m', f', hS₁.trans hS, ht', hfn', hl', hp', hal.trans hal₁, hde.trans hde₁, hI⟩

/-- **Soundness of a loop, by induction on the trip count** (see the module docstring). This
holds for every program, function, trip count `n`, context of the program, and loop path
`(h, ds, S) :: B` that the path checker with `phi`s accepts from position `p`. Take a thread
whose innermost frame `f` is at block `h`'s position `p`. If the premises of the first `n` rounds
hold (`Round` at `Valuation.round`'s iterates), the thread's steps reach `h`'s position `p`
again. The frame there runs the same function, has `f`'s `alloca` blocks and caller's register,
and its entry valuation is the `n`-th iterate (`Block.sound_rounds` with the invariant "the
`i`-th iterate", each round by `Block.sound_edge`). -/
theorem Block.sound_loop {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} {h p : Nat} {ds : List Cond} {S : Summary}
    {B : List (Nat × List Cond × Summary)} (hc : coversPathI P fn p ((h, ds, S) :: B) = true) :
    ∀ (n : Nat) {t : Thread} {m : Mem} {f : Frame}, t.frames = f :: rest → f.fn = fn →
      f.label = h → f.pc = p →
      (∀ i < n, Round h p ds S B ((Valuation.round h S B)^[i] (Valuation.entry c t.k m f))) →
      ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = h ∧
        f'.pc = p ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
        Valuation.entry c t'.k m' f' = (Valuation.round h S B)^[n] (Valuation.entry c t.k m f) := by
  intro n t m f ht hfn hl hp hR
  refine Block.sound_rounds
    (fun i W => W = (Valuation.round h S B)^[i] (Valuation.entry c t.k m f)) n
    (fun i hi t' m' f' ht' hfn' hl' hp' hV => ?_) ht hfn hl hp rfl
  replace hV : Valuation.entry c t'.k m' f' =
      (Valuation.round h S B)^[i] (Valuation.entry c t.k m f) := hV
  obtain ⟨hW, hd, hpc⟩ := hR i hi
  rw [← hV] at hW hd hpc
  obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hfn₁, hl₁, hp₁, hal₁, hde₁, hV₁⟩ :=
    Block.sound_edge hP hc ht' hfn' hl' hp' hW hd
  refine ⟨t₁, m₁, f₁, hS₁, ht₁, hfn₁, hl₁, hp₁.trans (by rw [← hfn']; exact hpc), hal₁, hde₁, ?_⟩
  show _ = _
  rw [hV₁, hV, Function.iterate_succ_apply']

/-- **The premises of every round from an invariant.** Take a loop path `(h, ds, S) :: B`, a trip
count `n`, an invariant `I` indexed by the round number, and a valuation `V` with `I 0 V`.
Suppose that for every `i < n` and every valuation `W`, `I i W` gives the premises of a round
from `W` (`Round`) and `I (i + 1)` after it (`Valuation.round`). Then the premises of rounds 0 to
`n - 1` hold at `Valuation.round`'s iterates from `V`, and `I n` holds at the `n`-th (induction on
the round). This is for every loop path, trip count, invariant and valuation; an invariant `J`
that does not depend on the round is `fun _ => J`. -/
theorem Round.of_inv {h p : Nat} {ds : List Cond} {S : Summary}
    {B : List (Nat × List Cond × Summary)} (I : Nat → Valuation → Prop) {n : Nat} {V : Valuation}
    (h0 : I 0 V)
    (hI : ∀ i < n, ∀ W, I i W → Round h p ds S B W ∧ I (i + 1) (Valuation.round h S B W)) :
    (∀ i < n, Round h p ds S B ((Valuation.round h S B)^[i] V)) ∧
      I n ((Valuation.round h S B)^[n] V) := by
  have inv : ∀ i, i ≤ n → I i ((Valuation.round h S B)^[i] V) := by
    intro i
    induction i with
    | zero => exact fun _ => h0
    | succ i ih =>
      intro hi
      rw [Function.iterate_succ_apply']
      exact (hI i (by omega) _ (ih (by omega))).2
  exact ⟨fun i hi => (hI i hi _ (inv i (by omega))).1, inv n (Nat.le_refl n)⟩

/-- **Soundness of a loop from an invariant.** This holds for every program, function, trip count
`n`, invariant `I` indexed by the round number, context of the program, and loop path
`(h, ds, S) :: B` that the path checker with `phi`s accepts from position `p`. Take a thread
whose innermost frame `f` is at block `h`'s position `p`. Suppose `I 0` holds at `f`'s entry
valuation, and for every `i < n` and valuation `W`, `I i W` gives `Round` at `W` and
`I (i + 1) (Valuation.round h S B W)`. Then the thread's steps reach `h`'s position `p` again,
in a frame of the function with `f`'s `alloca` blocks and caller's register whose entry
valuation satisfies `I n` (`Round.of_inv`, `Block.sound_loop`). -/
theorem Block.sound_loop_inv {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} {h p : Nat} {ds : List Cond} {S : Summary}
    {B : List (Nat × List Cond × Summary)} (hc : coversPathI P fn p ((h, ds, S) :: B) = true)
    (I : Nat → Valuation → Prop) (n : Nat) {t : Thread} {m : Mem} {f : Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = h) (hp : f.pc = p)
    (h0 : I 0 (Valuation.entry c t.k m f))
    (hI : ∀ i < n, ∀ W, I i W → Round h p ds S B W ∧ I (i + 1) (Valuation.round h S B W)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = h ∧
      f'.pc = p ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
      I n (Valuation.entry c t'.k m' f') := by
  obtain ⟨hR, hn⟩ := Round.of_inv I h0 hI
  obtain ⟨t', m', f', hS, ht', hfn', hl', hp', hal, hde, hV⟩ :=
    Block.sound_loop hP hc n ht hfn hl hp hR
  refine ⟨t', m', f', hS, ht', hfn', hl', hp', hal, hde, ?_⟩
  rw [hV]
  exact hn

/-- One loop on a path of a function: the loop path `(h, dh, H) :: B` from its header `h` (at
position `p`, after its `phi`s), the loops `inner` nested in it, and the path `(h, dh, H) :: X`
from the header out of the loop. A round runs the loop path and then the nested loops in order:
the loop path's last exit goes to the first nested loop's header, each nested loop's path out to
the next one's header, and the last one's back to `h`; with no nested loop, the loop path's last
exit goes back to `h`. -/
structure LoopSeg where
  /-- The loop from its header, entry position, header's conditions and summary, loop path, path
  out and nested loops. -/
  mk ::
  /-- The header. -/
  h : Nat
  /-- The position at which the header's rounds start (after its `phi`s). -/
  p : Nat
  /-- The header's conditions. -/
  dh : List Cond
  /-- The header's summary from position `p`. -/
  H : Summary
  /-- The rest of the loop path, to the latch or to the first nested loop's header. -/
  B : List (Nat × List Cond × Summary)
  /-- The rest of the path out of the loop: to the next loop's header, back to the header of the
  loop this one is nested in, or to a `ret`. -/
  X : List (Nat × List Cond × Summary)
  /-- The loops nested in a round, in the order a round runs them. -/
  inner : List LoopSeg

/-- The paths of a loop of a function: the entry path `(l, ds, S) :: E` from block `l` to the
header `h`, and the loop's paths (`LoopSeg`), the path out of the loop going to a `ret`. -/
structure LoopPaths extends LoopSeg where
  /-- The loop's paths from the loop (`LoopSeg`) and the entry path's first block, conditions,
  summary and rest. -/
  mk ::
  /-- The entry path's first block. -/
  l : Nat
  /-- Its conditions. -/
  ds : List Cond
  /-- Its summary. -/
  S : Summary
  /-- The rest of the entry path, to the block whose exit goes to the header. -/
  E : List (Nat × List Cond × Summary)

/-- The loop of a loop's paths: its header, loop path, path out and nested loops (`LoopSeg`). -/
add_decl_doc LoopPaths.toLoopSeg

/-- The paths of a sequence of loops of a function: the entry path `(l, ds, S) :: E` from block
`l` to the first loop's header, and the loops in the order the thread runs them (`LoopSeg`), each
loop's path out going to the next loop's header and the last one's to a `ret`. -/
structure LoopChain where
  /-- The paths of a sequence of loops from the entry path's first block, conditions, summary
  and rest, and the loops. -/
  mk ::
  /-- The entry path's first block. -/
  l : Nat
  /-- Its conditions. -/
  ds : List Cond
  /-- Its summary. -/
  S : Summary
  /-- The rest of the entry path, to the block whose exit goes to the first loop's header. -/
  E : List (Nat × List Cond × Summary)
  /-- The loops. -/
  loops : List LoopSeg

/-- A loop's paths as a sequence of one loop. -/
def LoopPaths.chain (L : LoopPaths) : LoopChain := ⟨L.l, L.ds, L.S, L.E, [L.toLoopSeg]⟩

mutual
/-- The path checker with `phi`s accepts the paths of the loops `Ls` of `fn` after the path
`(l, ds, S) :: E` (`coversPathI`): that path from position `p0`, and for each loop the paths of
its rounds (`LoopSeg.coversRound`) and its path out from the header's position, the path out
taking the place of `(l, ds, S) :: E` for the next loop. With no loop, the path `(l, ds, S) :: E`
alone. -/
def coversChain (P : Program) (fn : Func) :
    Nat → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → List LoopSeg → Bool
  | p0, l, ds, S, E, [] => coversPathI P fn p0 ((l, ds, S) :: E)
  | p0, l, ds, S, E, L :: Ls => coversPathI P fn p0 ((l, ds, S) :: E) &&
      L.coversRound P fn && coversChain P fn L.p L.h L.dh L.H L.X Ls

/-- The path checker with `phi`s accepts the paths of a round of loop `L` of `fn`: the loop path
from the header's position and the paths of the nested loops after it (`coversChain`). -/
def LoopSeg.coversRound (P : Program) (fn : Func) : LoopSeg → Bool
  | ⟨h, p, dh, H, B, _, inner⟩ => coversChain P fn p h dh H B inner
end

/-- The path checker with `phi`s accepts the paths of loop `L` of `fn`: the entry path from
position `p0`, the paths of a round (the loop path and the nested loops') and the exit path from
the header's position `L.p` (`coversChain` of the one loop). -/
def LoopPaths.covers (P : Program) (fn : Func) (p0 : Nat) (L : LoopPaths) : Bool :=
  coversChain P fn p0 L.l L.ds L.S L.E [L.toLoopSeg]

/-- A run from valuation `V` at the entry of the path `(l, ds, S) :: E` through the loops `Ls` in
order to a last path at whose entry valuation `F` holds. With no loop, `F` holds of the path
(`Chain.last`). With a first loop `L` (`Chain.loop`), for some invariant `I` indexed by the round
number and trip count `n`:
- the path's premises hold and its last edge goes to the header `L.h` at position `L.p`
  (`Edge`), and `I 0` holds at the header's entry valuation (`Valuation.round` of the path);
- for every `i < n` and valuation `W` of `I i`, the round from `W` runs the loop path and the
  nested loops `L.inner` to a last path whose edge goes back to `L.h` at `L.p` with `I (i + 1)`
  after it (`Chain` with `Back`);
- from every valuation of `I n`, the path out of `L` runs through the other loops `Ls`. -/
inductive Chain :
    (Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop) →
    List LoopSeg → Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) →
    Prop
  /-- No loop: `F` holds of the path. -/
  | last {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
      {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
      {E : List (Nat × List Cond × Summary)} :
      F V l ds S E → Chain F [] V l ds S E
  /-- A first loop `L`: entered by the path, run for `n` rounds from the invariant `I`, and left
  by its path out. -/
  | loop {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
      {L : LoopSeg} {Ls : List LoopSeg} {V : Valuation} {l : Nat} {ds : List Cond}
      {S : Summary} {E : List (Nat × List Cond × Summary)} (I : Nat → Valuation → Prop)
      (n : Nat) :
      Edge L.h L.p V l ds S E → I 0 (Valuation.round l S E V) →
      (∀ i < n, ∀ W, I i W → Chain (Back L.h L.p (I (i + 1))) L.inner W L.h L.dh L.H L.B) →
      (∀ W, I n W → Chain F Ls W L.h L.dh L.H L.X) → Chain F (L :: Ls) V l ds S E

/-- A run from valuation `V` at the entry of the path `(l, ds, S) :: E`, through the loops `Ls`
in order (each with the loops nested in its rounds), to `ret`, leaving a memory of `Q`: `Chain`
whose last path runs to `ret` (`Ret`). With no loop, `Ret V Q ((l, ds, S) :: E)`. -/
abbrev RetLs (Q : Mem → Prop) (Ls : List LoopSeg) (V : Valuation) (l : Nat) (ds : List Cond)
    (S : Summary) (E : List (Nat × List Cond × Summary)) : Prop :=
  Chain (fun V l ds S E => Ret V Q ((l, ds, S) :: E)) Ls V l ds S E

/-- A run of loop `L` from valuation `V` at its entry path's first block to `ret`, leaving a
memory of `Q` (`RetLs` of the one loop): the entry path's premises and its edge to the header at
position `L.p`, an invariant `I` and trip count `n` with `I 0` at the header and preserved by
every round `i < n`, and from every valuation of `I n` the exit path to `ret` with a memory of `Q`
(`Ret`). The analogue for loops of `Ret`. -/
def RetL (V : Valuation) (Q : Mem → Prop) (L : LoopPaths) : Prop :=
  RetLs Q [L.toLoopSeg] V L.l L.ds L.S L.E

/-- **A thread through a sequence of loops, with nested loops, to its last path.** This holds for
every program, function `fn`, context of the program, frames `rest`, predicate `F`, list `Ls` of
loops, path `(l, ds, S) :: E` before them and position `p0`, when the path checker with `phi`s
accepts the paths (`coversChain`: the path from `p0`, the paths of every round with its nested
loops, and every path out). Take a thread `t` whose innermost frame `f` runs `fn` above `rest` at
block `l`'s position `p0`, on memory `m`, such that `Chain F Ls` holds at `f`'s entry valuation.
Then `t`'s steps reach a frame of `fn` above `rest`, with `f`'s `alloca` blocks and caller's
register, at the first block `l'` of a last path `(l', ds', S') :: E'` at its position `p'`, which
the checker accepts from `p'` and at whose entry valuation `F` holds. The proof is by induction on
`Chain`: `Block.sound_edge` into each loop, `Block.sound_rounds` through its rounds (each by the
induction hypothesis to its `Back` and `Block.sound_edge` of that), and the induction hypothesis
on its path out. -/
theorem Chain.reach {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P) {rest : List Frame}
    {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
    {Ls : List LoopSeg} {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} (h : Chain F Ls V l ds S E) :
    ∀ {p0 : Nat} {t : Thread} {m : Mem} {f : Frame}, coversChain P fn p0 l ds S E Ls = true →
      t.frames = f :: rest → f.fn = fn → f.label = l → f.pc = p0 →
      Valuation.entry c t.k m f = V →
      ∃ t' m' f' p' l' ds' S' E', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧
        f'.label = l' ∧ f'.pc = p' ∧ f'.allocas = f.allocas ∧ f'.dest = f.dest ∧
        coversPathI P fn p' ((l', ds', S') :: E') = true ∧
        F (Valuation.entry c t'.k m' f') l' ds' S' E' := by
  induction h with
  | last hF =>
    intro p0 t m f hc ht hfn hl hp hV
    subst hV
    simp only [coversChain] at hc
    exact ⟨t, m, f, p0, _, _, _, _, .refl t m, ht, hfn, hl, hp, rfl, rfl, hc, hF⟩
  | @loop F L Ls V l ds S E I n hE h0 _ _ ihr ihx =>
    intro p0 t m f hc ht hfn hl hp hV
    subst hV
    simp only [coversChain, Bool.and_eq_true] at hc
    obtain ⟨⟨hcE, hcR⟩, hcX⟩ := hc
    replace hcR : coversChain P fn L.p L.h L.dh L.H L.B L.inner = true := by
      cases L
      exact hcR
    obtain ⟨hW, hd, hpc⟩ := hE
    obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hfn₁, hl₁, hp₁, hal₁, hde₁, hV₁⟩ :=
      Block.sound_edge hP hcE ht hfn hl hp hW hd
    obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hfn₂, hl₂, hp₂, hal₂, hde₂, hI₂⟩ :=
      Block.sound_rounds (c := c) (fn := fn) (rest := rest) (h := L.h) (p := L.p) I n
        (fun i hi t m f ht hfn hl hp hI => by
          obtain ⟨t', m', f', p', l', ds', S', E', hS, ht', hfn', hl', hp', hal, hde, hc', hB⟩ :=
            ihr i hi _ hI hcR ht hfn hl hp rfl
          obtain ⟨⟨hW', hd', hpc'⟩, hJ⟩ := hB
          obtain ⟨t'', m'', f'', hS', ht'', hfn'', hl'', hp'', hal', hde', hV'⟩ :=
            Block.sound_edge hP hc' ht' hfn' hl' hp' hW' hd'
          exact ⟨t'', m'', f'', hS.trans hS', ht'', hfn'', hl'',
            hp''.trans (by rw [← hfn']; exact hpc'), hal'.trans hal, hde'.trans hde,
            by rw [hV']; exact hJ⟩)
        ht₁ hfn₁ hl₁ (hp₁.trans (by rw [← hfn]; exact hpc)) (by rw [hV₁]; exact h0)
    obtain ⟨t', m', f', p', l', ds', S', E', hS, ht', hfn', hl', hp', hal, hde, hc', hF⟩ :=
      ihx _ hI₂ hcX ht₂ hfn₂ hl₂ hp₂ rfl
    exact ⟨t', m', f', p', l', ds', S', E', hS₁.trans (hS₂.trans hS), ht', hfn', hl', hp',
      hal.trans (hal₂.trans hal₁), hde.trans (hde₂.trans hde₁), hc', hF⟩

/-- **A first loop from the iterates of a function.** For every predicate `F`, loop `L`, list
`Ls` of loops after it, path `(l, ds, S) :: E` before it, valuation `V`, function `g` on
valuations and trip count `n`, with `V₀ = Valuation.round l S E V` the header's entry valuation:
if the path's premises hold at `V` and its last edge goes to `L.h` at position `L.p` (`Edge`),
for every `i < n` the round from `g^[i] V₀` runs through the nested loops `L.inner` and back to
`L.h` with the header's valuation `g (g^[i] V₀)` after it (`Chain` with `Back`), and the path out
runs through `Ls` from `g^[n] V₀`, then `Chain F (L :: Ls)` holds at `V`, with the invariant
`fun i W => W = g^[i] V₀`. On a concrete valuation, function and trip count the premises of the
edges are closed propositions that the kernel decides (`Edge.dec`). -/
theorem Chain.of_iter
    {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
    {L : LoopSeg} {Ls : List LoopSeg} {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} (g : Valuation → Valuation) (n : Nat)
    (he : Edge L.h L.p V l ds S E)
    (hr : ∀ i < n, Chain (Back L.h L.p (· = g (g^[i] (Valuation.round l S E V)))) L.inner
      (g^[i] (Valuation.round l S E V)) L.h L.dh L.H L.B)
    (hx : Chain F Ls (g^[n] (Valuation.round l S E V)) L.h L.dh L.H L.X) :
    Chain F (L :: Ls) V l ds S E :=
  .loop (fun i W => W = g^[i] (Valuation.round l S E V)) n he rfl
    (fun i hi W hW => by
      subst hW
      simp only [Function.iterate_succ_apply']
      exact hr i hi)
    (fun W hW => by subst hW; exact hx)

/-- **A first loop with no nested loop from its rounds.** For every predicate `F`, loop `L` with
no nested loop, list `Ls` of loops after it, path `(l, ds, S) :: E` before it, valuation `V` and
trip count `n`: if the path's premises hold at `V` and its last edge goes to `L.h` at position
`L.p` (`Edge`), the premises of rounds 0 to `n - 1` hold at the iterates of the header's entry
valuation (`Round`), and the path out runs through `Ls` from the `n`-th iterate, then
`Chain F (L :: Ls)` holds at `V` (`Chain.of_iter` with `Valuation.round` of the loop path). On a
concrete valuation and trip count the first premise is a closed proposition that the kernel
decides (`Edge.dec`, `Round.dec`). -/
theorem Chain.of_rounds
    {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
    {L : LoopSeg} {Ls : List LoopSeg} {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} (hL : L.inner = []) (n : Nat)
    (h : Edge L.h L.p V l ds S E ∧ ∀ i < n, Round L.h L.p L.dh L.H L.B
      ((Valuation.round L.h L.H L.B)^[i] (Valuation.round l S E V)))
    (hx : Chain F Ls ((Valuation.round L.h L.H L.B)^[n] (Valuation.round l S E V)) L.h L.dh L.H
      L.X) :
    Chain F (L :: Ls) V l ds S E :=
  Chain.of_iter _ n h.1 (fun i hi => by rw [hL]; exact .last ⟨h.2 i hi, rfl⟩) hx

/-- **A thread through a sequence of loops to its end.** This holds for every program, function
`fn`, context of the program, list `Ls` of loops (each with the loops nested in its rounds), path
`(l, ds, S) :: E` before them, position `p0` and predicate `Q` on memories, when the path checker
with `phi`s accepts the paths (`coversChain`). Take a thread `t` with one frame `f` of `fn` at
block `l`'s position `p0`, on memory `m`, such that the run through the loops goes from `f`'s
entry valuation to `ret` with a memory `me` of `Q` (`RetLs`: each loop entered from the path
before it, run from its invariant through its nested loops, and left by its path out). Then `t`
runs to its end (`Runs`), leaving `me` with `f`'s `alloca` blocks dead: `me` itself when `f` has
none, as for `Grid.start`'s frames (`Chain.reach` to the last path, then `Block.sound_retI`). -/
theorem Runs.of_chain {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P) {Q : Mem → Prop} :
    ∀ (Ls : List LoopSeg) {p0 l : Nat} {ds : List Cond} {S : Summary}
      {E : List (Nat × List Cond × Summary)}, coversChain P fn p0 l ds S E Ls = true →
      ∀ {t : Thread} {m : Mem} {f : Frame}, t.frames = [f] → f.fn = fn → f.label = l →
        f.pc = p0 → RetLs Q Ls (Valuation.entry c t.k m f) l ds S E →
        ∃ me, Runs c t m (f.allocas.foldl (fun m b => m.setLive b false) me) ∧ Q me := by
  intro Ls p0 l ds S E hc t m f ht hfn hl hp hR
  obtain ⟨t', m', f', p', l', ds', S', E', hS, ht', hfn', hl', hp', hal, -, hc', hW, hret, me,
    hme, hQ⟩ := Chain.reach hP hR hc ht hfn hl hp rfl
  obtain ⟨fe, me', hS', hrun, hst⟩ := Block.sound_retI hP hc' ht' hfn' hl' hp' hW hret
  obtain rfl : me = me' := Except.ok.inj (hme.symm.trans hrun)
  rw [hal] at hst
  exact ⟨me, ⟨_, _, hS.trans hS', hst⟩, hQ⟩

/-- **A thread through a loop to its end.** This holds for every program, function `fn`, context
of the program, loop `L` of `fn` whose paths the path checker with `phi`s accepts
(`LoopPaths.covers`, the entry path from position `p0`), and predicate `Q` on memories. Take a
thread `t` with one frame `f` of `fn` at block `L.l`'s position `p0`, on memory `m`, such that
`L` runs from `f`'s entry valuation to `ret` with a memory `me` of `Q` (`RetL`: the entry path's
premises and its edge to the header, an invariant `I` and trip count `n` with `I 0` at the
header, preserved by every round `i < n`, and from `I n` the exit path to `ret`). Then `t` runs
to its end (`Runs`), leaving `me` with `f`'s `alloca` blocks dead: `Runs.of_chain` with the one
loop. -/
theorem Runs.of_loop {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P) {p0 : Nat}
    {L : LoopPaths} (hc : L.covers P fn p0 = true) {t : Thread} {m : Mem} {f : Frame}
    (ht : t.frames = [f]) (hfn : f.fn = fn) (hl : f.label = L.l) (hp : f.pc = p0)
    {Q : Mem → Prop} (hR : RetL (Valuation.entry c t.k m f) Q L) :
    ∃ me, Runs c t m (f.allocas.foldl (fun m b => m.setLive b false) me) ∧ Q me :=
  Runs.of_chain hP [L.toLoopSeg] hc ht hfn hl hp hR

/-- Every sequence of loops of `Cs` starts at the label of `fn`'s first block, and its paths are
accepted by the path checker with `phi`s, the entry path from position 0 (`coversChain`): the
analogue for loops of `coversEntry` (MojoProof/Sym/Kernel.lean), a closed Boolean that the kernel
decides on a concrete program. -/
def coversChains (P : Program) (fn : Func) (Cs : List LoopChain) : Bool :=
  Cs.all fun C => decide (fn.blocks[0]?.map (·.label) = some C.l) &&
    coversChain P fn 0 C.l C.ds C.S C.E C.loops

/-- `coversChains` of the loops of `loops`, each a sequence of one loop (`LoopPaths.chain`). -/
def coversLoops (P : Program) (fn : Func) (loops : List LoopPaths) : Bool :=
  coversChains P fn (loops.map LoopPaths.chain)

/-- **A kernel's thread through a sequence of loops to its end**, in the form of
`Grid.start_thread`'s threads (MojoProof/Sym/Kernel.lean): for every program `P`, kernel `fn`,
context of `P`, list `Cs` of sequences of loops that `coversChains` accepts, predicate `Q`, and
thread `t` with one frame `f` of `fn` at the label of `fn`'s first block, position 0, with no
`alloca` blocks, on memory `m`: if some sequence of `Cs` runs from `f`'s entry valuation to `ret`
with a memory of `Q` (`RetLs`), `t` runs to its end (`Runs`) leaving a memory of `Q`
(`Runs.of_chain`). The analogue for loops of `Runs.of_ret`: with `Q = P (k + 1)` its conclusion
is the premise `Seq.start_sound_inv` takes for thread `k`. -/
theorem Runs.of_chains {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {Cs : List LoopChain} (hc : coversChains P fn Cs = true) {t : Thread} {m : Mem}
    {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = fn)
    (hl : fn.blocks[0]?.map (·.label) = some f.label) (hp : f.pc = 0) (ha : f.allocas = [])
    {Q : Mem → Prop}
    (hR : ∃ C ∈ Cs, RetLs Q C.loops (Valuation.entry c t.k m f) C.l C.ds C.S C.E) :
    ∃ m', Runs c t m m' ∧ Q m' := by
  obtain ⟨C, hC, hR⟩ := hR
  have h := List.all_eq_true.1 hc C hC
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨me, hr, hq⟩ :=
    Runs.of_chain hP C.loops h.2 ht hfn (Option.some.inj (hl.symm.trans h.1)) hp hR
  rw [ha] at hr
  exact ⟨me, hr, hq⟩

/-- **A kernel's thread through a loop to its end**: `Runs.of_chains` for loops of one loop each
(`coversLoops`, `RetL`), for every program, kernel, context, list of loops, predicate and thread
as there. -/
theorem Runs.of_loops {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {loops : List LoopPaths} (hc : coversLoops P fn loops = true) {t : Thread} {m : Mem}
    {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = fn)
    (hl : fn.blocks[0]?.map (·.label) = some f.label) (hp : f.pc = 0) (ha : f.allocas = [])
    {Q : Mem → Prop} (hR : ∃ L ∈ loops, RetL (Valuation.entry c t.k m f) Q L) :
    ∃ m', Runs c t m m' ∧ Q m' :=
  Runs.of_chains hP hc ht hfn hl hp ha
    (hR.elim fun L ⟨hL, h⟩ => ⟨L.chain, List.mem_map_of_mem hL, h⟩)

/-- **An edge into blocks with `phi`s**, for every valuation `V` at the entry of block `l` and
summary `S` of `l` whose exit is `Exit.phi` and goes to `d'` (`Exit.dest`): when `enter` gives
frame `f` from `Valuation.frameAt`'s frame (setting `d'`'s `phi`s), the entry valuation of `d'`
(`Valuation.into`) is `Valuation.after`'s with `f`'s registers and `fmul contract` operands. -/
theorem Valuation.into_of_enter {V : Valuation} {l : Nat} {S : Summary} {x : SVal}
    {d e d' : Nat} (hx : S.exit = .phi x d e) (hd : S.exit.dest V (vals V S.nodes) = some d')
    {f : Frame}
    (hf : enter (V.ctx.scope (V.after S).mem (V.frameAt l S) (V.k + S.len)) (V.frameAt l S) d' =
      .ok f) :
    V.into l S = { V.after S with regs := f.regs, prods := f.prods } := by
  rw [Valuation.into, hd]
  simp only [hx, hf]

/-- The address of a pointer in its block's own address space, for every layout `l`, memory `m`
and pointer `p` whose block (not the null block 0) is `blk`: `blk`'s base plus `p`'s offset,
modulo `2 ^` the space's pointer width. -/
theorem _root_.MojoProof.Sem.Mem.addr_own {l : Layout} {m : Mem} {p : Ptr} {blk : Sem.Block}
    (hb : m.blocks p.block = some blk) (h0 : p.block ≠ 0) :
    m.addr l blk.space p = .ok ((((blk.addr : Int) + p.off) % 2 ^ (l.ptr blk.space).1).toNat) := by
  simp [Mem.addr, Mem.block, hb, h0, pure, Except.pure]

/-- **A store that `Mem.check` admits**, for every layout `l`, memory `m`, thread `w`, address
space `a`, type `t`, value `v`, pointer `p` and alignment `al`: when `v` encodes to the bytes `bs`
(`Layout.encode`), the check of `l.stored t` bytes gives block `blk` at offset `o`, and `blk` is
writable, the store puts `bs` at `o` in `blk` and logs the access. -/
theorem _root_.MojoProof.Sem.Mem.store_of_check {l : Layout} {m : Mem} {w : Who} {a : Nat}
    {t : Ty} {v : Val} {p : Ptr} {al : Option Nat} {blk : Sem.Block} {o : Nat}
    {bs : List MemByte} (hbs : l.encode t v = some bs)
    (hc : m.check l w a p (l.stored t) al = .ok (blk, o)) (hr : blk.readOnly = false) :
    m.store l w a t v p al = .ok ((m.set p.block (blk.put o bs)).log
      (.access ⟨w, p, bs.length, true, none, false⟩)) := by
  rw [← l.encode_length _ _ _ hbs] at hc
  simp [Mem.store, hbs, Mem.write_of_check hc hr, bind, Except.bind, pure, Except.pure]

/-- **Liveness changes keep the other blocks.** Setting the liveness of the blocks of `bs` in turn
(`Mem.setLive`; with `false`, the cleanup of a frame's `alloca` blocks by `ret`) leaves every
block `b ∉ bs` as it was, for every memory, list and liveness. -/
theorem _root_.MojoProof.Sem.Mem.foldl_setLive_blocks {b : Nat} {v : Bool} :
    ∀ {bs : List Nat} {m : Mem}, b ∉ bs →
      (bs.foldl (fun m b => m.setLive b v) m).blocks b = m.blocks b
  | [], _, _ => rfl
  | a :: bs, m, h => by
    have hab : b ≠ a := by
      rintro rfl
      exact h List.mem_cons_self
    rw [List.foldl_cons,
      MojoProof.Sem.Mem.foldl_setLive_blocks fun hm => h (List.mem_cons_of_mem _ hm)]
    unfold Mem.setLive
    split
    · simp only [Mem.set, hab, ite_false]
    · rfl

/-- **Liveness changes keep the loads of the other blocks**: for every memory, list `bs`,
liveness, layout, thread, address space, type, pointer `p` whose block is not in `bs`, and
alignment, a load through `p` after setting the liveness of the blocks of `bs` in turn gives what
it gives before (`Mem.foldl_setLive_blocks`). So the memory a thread leaves by `ret` has the loads
of every block outside its frame's `alloca` blocks. -/
theorem _root_.MojoProof.Sem.Mem.foldl_setLive_load {bs : List Nat} {v : Bool} {m : Mem}
    {p : Ptr} (h : p.block ∉ bs) (l : Layout) (w : Who) (a : Nat) (t : Ty) (al : Option Nat) :
    (bs.foldl (fun m b => m.setLive b v) m).load l w a t p al = m.load l w a t p al := by
  simp only [Mem.load, Mem.check, Mem.block, Mem.addr, MojoProof.Sem.Mem.foldl_setLive_blocks h]

end MojoProof.Sym
