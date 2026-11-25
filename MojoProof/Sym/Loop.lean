import MojoProof.Sym.Path
import MojoProof.Sym.Info
import MojoProof.Sym.Sched

/-!
# Loops

`Block.sound_loop`: soundness of a loop for every trip count, by induction on it. `Round.of_inv`,
`Block.sound_loop_inv`, `ChainWith.reach`, `Runs.of_chainWith` and `Runs.of_loop`: the same from
an invariant, and a thread through a sequence of loops, with loops nested in their rounds, or
through one loop, to its end. All are proved once for every program, function, path, list of
loops, nesting, trip count and invariant, and for blocks with and without `alloca` and
`fmul contract`.

A loop is a path `(h, ds, S) :: B` of the control-flow graph that starts at its header `h`,
entered at position `p` (after its `phi`s). It runs through the body to the latch, whose exit
goes back to `h` (the back edge; `Exit.phi` when `h` starts with `phi`s, which the step sets).
`Valuation.roundWith contract` is the valuation after a path's last edge:
`Valuation.intoWith contract` of its last block from that block's entry valuation
(`Valuation.lastWith contract`). For a loop path this is the header's valuation after one round.
`EdgeWith contract h p` is the premise of a path and its last edge: the path's premises hold
(`WalkWith contract`), and its last block's exit goes to `h` (`Exit.dest`) at position `p`
(`Exit.pc`). `RoundWith` is `EdgeWith` of a loop path back to its own header. `BackWith contract
h p J` is `EdgeWith contract h p` and `J` at the valuation after the edge.

Loops nest. A loop `L : LoopSeg` has a loop path from its header `L.h`, the loops
`L.inner` that each round runs after the loop path, and a path out. A round runs the loop path,
whose last exit goes to the first nested loop's header, then each nested loop, whose path out
goes to the next nested loop's header or, for the last, back to `L.h`. With no nested loop the
loop path's last exit goes back to `L.h` (a straight loop). `ChainWith contract F Ls V l ds S E`,
an inductive predicate, is a run from valuation `V` at the path `(l, ds, S) :: E` through the
loops `Ls` in order to a last path at whose entry valuation `F` holds: each loop entered by the
path before it (`EdgeWith contract`), run from an invariant whose rounds are `ChainWith`s through
its nested loops ending with `BackWith contract` to its header, and left by its path out.

With and without `fmul contract` (docs/proofs/contract.md). The path checker and the path
valuations take a flag `contract` (`coversPathWith`, `WalkWith`, `Valuation.lastWith` of
MojoProof/Sym/Path.lean): with it, a block may fuse a product into a `fadd contract`
(`coversWith … true`) and each block after the first is entered through
`Valuation.intoWith true`. Here `Valuation.roundWith`, `EdgeWith`, `RoundWith`, `BackWith`,
`coversChainWith`, `LoopSeg.coversRoundWith`, `ChainWith`, `RetLsWith` and `coversChainsWith`
take the flag, and the theorems below are proved once for both values. `Valuation.round`, `Edge`,
`Round`, `coversChain`, `LoopSeg.coversRound`, `coversChains` and `RetLs` are their cases without
the flag, by definition; the cases without the flag of `ChainWith` and `BackWith` are
`ChainWith false` and `BackWith false` themselves. `LoopSeg` and `LoopChain` are data and take no
flag.

With and without `alloca`. The path checker takes a second flag `alloca` (`coversPathAt alloca
contract`, MojoProof/Sym/Path.lean): with it, a block's summary may allocate (`summarizeAt true`),
and the frame after a path has the path's `alloca` blocks (`Valuation.allocsWith`) in front of
its own. Here `coversChainAt`, `LoopSeg.coversRoundAt` and `coversChainsAt` take it, and
`coversChainWith`, `LoopSeg.coversRoundWith` and `coversChainsWith` are their cases with the flag
off, by definition. The theorems below take it too: a frame reached has some blocks `bs` in front
of `f`'s `alloca` blocks, `bif alloca then bs else []`, none with the flag off
(`Valuation.allocsWith_cond`, `allocas_trans`), and `bs` is exactly the blocks the memory reached
adds to the start memory `m` (`Mem.Adds`, MojoProof/Sym/Path.lean): the numbers where `m` has no
block and the memory reached has one.

The results hold for every flag, every program `P`, every context of `P`, and every thread
whose innermost frame `f` runs `fn` on memory `m`. In each, the frames reached keep `f`'s
`alloca` blocks, after the blocks of the paths run, and caller's register.

* `Block.sound_edge`: take a path that the path checker with `phi`s accepts
  (`coversPathAt alloca contract`) and whose last exit goes to `d`. If the path's premises hold
  (`WalkWith contract`), the thread's steps reach block `d` at position `Exit.pc fn d`, with
  entry valuation `Valuation.roundWith contract` of `f`'s and the path's `alloca` blocks
  (`Valuation.allocsWith`) in front of `f`'s, and these are the blocks the memory there adds to
  `m` (`Mem.Adds`).
* `BackWith.enter`: a path that the checker accepts, from a thread at its first block with
  `BackWith contract d q J` at its entry valuation, steps through its last edge to a frame at
  block `d`'s position `q` with `J` at its entry valuation (`Block.sound_edge`).
* `Block.sound_rounds`: take a block `h`, a position `p`, an invariant `I` indexed by the round
  number and a trip count `n`. If each round `i < n` takes every thread at `h`'s position `p` with
  `I i` at its entry valuation to that position again with `I (i + 1)`, then the rounds take a
  thread there with `I 0` to that position with `I n` (induction on `n`).
* `Block.sound_loop`: take a loop path accepted from `p`, a trip count `n`, and a thread at block
  `h`'s position `p`. If the premises of rounds 0 to `n - 1` hold (`RoundWith contract` at
  `roundWith contract^[i]` of the entry valuation), the thread's steps reach `h`'s position `p`
  again, with entry valuation `roundWith contract^[n]` of the first (`Block.sound_rounds`, each
  round by `BackWith.enter`). The trip count is a premise: the theorem says nothing about
  termination.
* `Valuation.roundWith_k`: `i` rounds keep the context and the function and add
  `i * (pathLen S B + 1)` to the step count, so the oracle number of an operation in round `i` is
  a function of `i`.
* `Round.of_inv`: suppose an invariant `I i` (indexed by the round number `i`) holds at round 0, and
  for every `i < n` and every valuation `W`, `I i W` gives `RoundWith contract` at `W` and
  `I (i + 1) (roundWith contract W)`. Then the premises of rounds 0 to `n - 1` hold, and so does
  `I n` after them. An invariant `J` that does not depend on the round is `fun _ => J`.
* `Block.sound_loop_inv`: `Block.sound_loop` with its premises from `Round.of_inv`. The valuation
  reached satisfies `I n`.
* `ChainWith.reach`: take loops `Ls` after a path `(l, ds, S) :: E`
  such that the path checker with `phi`s accepts the path, the paths of every round with its nested
  loops, and every path out (`coversChainAt alloca contract`, with
  `LoopSeg.coversRoundAt alloca contract` for a round). Take a thread at block `l`'s position `p0`
  with `ChainWith contract F Ls` at its entry valuation. Its steps reach the first block of a last
  path that the checker accepts, with `F` at its entry valuation. The proof is by induction on
  `ChainWith`: `Block.sound_edge` into each loop, `Block.sound_rounds` through its rounds (each by
  the induction hypothesis and `BackWith.enter`), and the induction hypothesis on its path out.
* `ChainWith.enter`: a chain whose last path out stops after its last edge, into block `d` at
  position `q` with `J` after it (`ChainWith contract` with `BackWith contract d q J`), takes the
  thread to a frame at `d`'s position `q` with `J` at its entry valuation, with the paths'
  `alloca` blocks as in `ChainWith.reach` (`ChainWith.reach`, then `BackWith.enter`). A
  continuation from that frame, as the segments of a block with collectives, joins it
  (`RunsVia.of_chain`, MojoProof/Sym/OblSeg.lean).
* `Runs.of_chainWith`: `RetLsWith contract Q` is
  `ChainWith contract` whose last path runs to `ret` with a memory of `Q` (`RetWith contract`).
  A thread with one frame at the path's first block and `RetLsWith contract` at its entry
  valuation runs to its end (`Runs`), leaving that memory `me` with the `alloca` blocks of the
  paths run and `f`'s dead (`ChainWith.reach`, then `Block.sound_retWith`); the paths' blocks are
  exactly those `me` adds to `m` (`Mem.Adds`). `Runs.of_loop` is
  `Runs.of_chainWith` without the flags with one loop (`LoopPaths extends LoopSeg`;
  `LoopPaths.covers` and `RetL` are `coversChain` and `RetLs` of `[L.toLoopSeg]`).
* `ChainWith.of_iter`: `ChainWith` through a first loop with the
  invariant "the `i`-th iterate of a function `g` from the header's entry valuation", from the
  `ChainWith`s of the rounds at the iterates (each ending with `BackWith` to the header at `g` of
  its first valuation) and the `ChainWith` of the path out at the `n`-th iterate.
  `ChainWith.of_rounds`: for a loop with no nested loop,
  with `g` the loop path's `Valuation.roundWith contract`, from the premises
  of the rounds at the iterates. On a concrete valuation and trip count they are closed
  propositions that the kernel decides.
* `Runs.of_chainsAt`, `Runs.of_chainsWith` and `Runs.of_loops`: the same for the
  threads `Grid.start` makes (one frame at the first block, position 0, no `alloca` blocks), with
  the starts and paths checked by one closed Boolean (`coversChainsAt alloca contract` for
  sequences of loops `LoopChain`, `coversLoops` for one loop each): the thread runs to its end,
  leaving a memory of `Q` with the `alloca` blocks of the paths run dead (`Runs.of_chainsAt`, the
  blocks that memory adds to `m`; none with the flag `alloca` off, `Runs.of_chainsWith`).
  `Runs.of_chainsDead`: for a predicate `R` that reads only the blocks of `m`, `next` and the
  trace, the memory the thread leaves has `R` when the last path's memory has it, has the blocks
  of `m` as that memory has them, and every block the run adds dead. This is the form of the
  per-thread premise of
  `Seq.start_sound_inv`, as `Runs.of_ret` gives for straight-line paths (`Runs.of_retWith` with
  the flag). `Runs.of_loops` is `Runs.of_chainsWith` without the flags at `LoopPaths.chain`.

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
  the memory `Runs` ends with has the output cells of blocks outside the frame's `alloca` blocks;
  `Mem.load_of_block`: a load reads only its pointer's block;
* `Mem.setLive_false_blocks`, `Mem.foldl_setLive_false`, `Mem.Adds.foldl_setLive`: setting
  blocks dead keeps their bytes, and setting dead the blocks a memory adds to `m` leaves `m`'s
  blocks as they are.

What is automated, and what is not. The loop checks (`coversChain`, `coversChains`,
`coversLoops`) are closed Booleans that the kernel evaluates (`decide +kernel`). On a concrete
valuation and trip count, `ChainWith.of_rounds` turns a loop with no nested loop into closed
propositions that the kernel decides. Nothing here finds an invariant or proves its preservation
for every trip count: that proof is written by hand for each loop (as `cnt_retL` in
MojoProofTest/SymLoop.lean, for the summaries of its one function). The trip count is a premise,
so nothing here proves termination. The kernel theorem `Kernel.sound_of_chains` takes for each
thread a path to a `ret` (`Ret`) or a sequence of loops (`RetLs`, through `Runs.of_chainsWith`), and
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
block, with every block after the first entered through `Valuation.intoWith contract`:
`Valuation.intoWith contract` of the path's last block from its entry valuation
(`Valuation.lastWith contract`). For a loop path from the header `h`, the valuation at the header
after one round. -/
def Valuation.roundWith (contract : Bool) (h : Nat) (S : Summary)
    (B : List (Nat × List Cond × Summary)) (V : Valuation) : Valuation :=
  (V.lastWith contract h S B).1.intoWith contract (V.lastWith contract h S B).2.1
    (V.lastWith contract h S B).2.2

/-- **The step count of rounds**: for every flag, label, summary, path, valuation and number `i`,
`i` rounds (`Valuation.roundWith contract`'s `i`-th iterate) keep the context and the function and
add `i` times the path's length plus one (its last branch) to the step count
(`Valuation.lastWith_k`, `Valuation.intoWith_k`). An operation at offset `n` of a block of round
`i` thus has the oracle number of step `V.k + i * (pathLen S B + 1) + …`, a function of the step
count alone. -/
theorem Valuation.roundWith_k (contract : Bool) (h : Nat) (S : Summary)
    (B : List (Nat × List Cond × Summary)) :
    ∀ (i : Nat) (V : Valuation), ((Valuation.roundWith contract h S B)^[i] V).ctx = V.ctx ∧
      ((Valuation.roundWith contract h S B)^[i] V).fn = V.fn ∧
      ((Valuation.roundWith contract h S B)^[i] V).k = V.k + i * (pathLen S B + 1)
  | 0, _ => ⟨rfl, rfl, by simp⟩
  | i + 1, V => by
    obtain ⟨h1, h2, h3⟩ :=
      Valuation.roundWith_k contract h S B i (Valuation.roundWith contract h S B V)
    obtain ⟨e1, e2, e3⟩ := Valuation.lastWith_k contract V h S B
    obtain ⟨f1, f2, f3⟩ := Valuation.intoWith_k contract (V.lastWith contract h S B).1
      (V.lastWith contract h S B).2.1 (V.lastWith contract h S B).2.2
    rw [Function.iterate_succ_apply]
    refine ⟨h1.trans (f1.trans e1), h2.trans (f2.trans e2), ?_⟩
    rw [h3]
    show (Valuation.intoWith contract _ _ _).k + _ = _
    rw [f3, Nat.add_assoc, e3, Nat.succ_mul]
    omega

/-- The premises of the path `(l, ds, S) :: E` from valuation `V` at its first block and of its
last edge into block `h` at position `p`, with or without `fmul contract`: the path's premises
hold (`WalkWith contract`), and its last block's exit goes to `h` (`Exit.dest`) at position `p`
(`Exit.pc`). -/
def EdgeWith (contract : Bool) (h p : Nat) (V : Valuation) (l : Nat) (ds : List Cond)
    (S : Summary) (E : List (Nat × List Cond × Summary)) : Prop :=
  WalkWith contract V ((l, ds, S) :: E) ∧
    (V.lastWith contract l S E).2.2.exit.dest (V.lastWith contract l S E).1
      (vals (V.lastWith contract l S E).1 (V.lastWith contract l S E).2.2.nodes) = some h ∧
    (V.lastWith contract l S E).2.2.exit.pc V.fn h = p

/-- Whether `EdgeWith contract` holds, decided by evaluating it (the kernel reduces it on a
concrete valuation). -/
instance EdgeWith.dec (contract : Bool) (h p : Nat) (V : Valuation) (l : Nat) (ds : List Cond)
    (S : Summary) (E : List (Nat × List Cond × Summary)) :
    Decidable (EdgeWith contract h p V l ds S E) :=
  inferInstanceAs (Decidable (WalkWith contract V ((l, ds, S) :: E) ∧
    (V.lastWith contract l S E).2.2.exit.dest (V.lastWith contract l S E).1
      (vals (V.lastWith contract l S E).1 (V.lastWith contract l S E).2.2.nodes) = some h ∧
    (V.lastWith contract l S E).2.2.exit.pc V.fn h = p))

/-- The premises of one round of the loop path `(h, ds, S) :: B` from header valuation `V`, with
or without `fmul contract`: `EdgeWith contract` of the path into its own first block. -/
def RoundWith (contract : Bool) (h p : Nat) (ds : List Cond) (S : Summary)
    (B : List (Nat × List Cond × Summary)) (V : Valuation) : Prop :=
  EdgeWith contract h p V h ds S B

/-- Whether a round's premises hold, decided by evaluating them (`EdgeWith.dec`). -/
instance RoundWith.dec (contract : Bool) (h p : Nat) (ds : List Cond) (S : Summary)
    (B : List (Nat × List Cond × Summary)) (V : Valuation) :
    Decidable (RoundWith contract h p ds S B V) :=
  EdgeWith.dec contract h p V h ds S B

/-- The end of a round of a loop with header `h`, entered at position `p`, with or without
`fmul contract`: the path `(l, ds, S) :: E` from valuation `V` and its last edge go back to `h`
at `p` (`EdgeWith contract`), and `J` holds at the header's entry valuation after it
(`Valuation.roundWith contract`). -/
def BackWith (contract : Bool) (h p : Nat) (J : Valuation → Prop) (V : Valuation) (l : Nat)
    (ds : List Cond) (S : Summary) (E : List (Nat × List Cond × Summary)) : Prop :=
  EdgeWith contract h p V l ds S E ∧ J (Valuation.roundWith contract l S E V)

/-- The valuation after the last edge of the path `(h, _, S) :: B` from valuation `V` at its first
block: `Valuation.roundWith` without `fmul contract`. For a loop path from the header `h`, the
valuation at the header after one round. -/
def Valuation.round (h : Nat) (S : Summary) (B : List (Nat × List Cond × Summary))
    (V : Valuation) : Valuation :=
  Valuation.roundWith false h S B V

/-- The premises of the path `(l, ds, S) :: E` from valuation `V` at its first block and of its
last edge into block `h` at position `p`: `EdgeWith` without `fmul contract`. -/
def Edge (h p : Nat) (V : Valuation) (l : Nat) (ds : List Cond) (S : Summary)
    (E : List (Nat × List Cond × Summary)) : Prop :=
  EdgeWith false h p V l ds S E

/-- Whether a path's premises hold and its last edge goes to block `h` at position `p`, decided
by evaluating them (`EdgeWith.dec`). -/
instance Edge.dec (h p : Nat) (V : Valuation) (l : Nat) (ds : List Cond) (S : Summary)
    (E : List (Nat × List Cond × Summary)) : Decidable (Edge h p V l ds S E) :=
  EdgeWith.dec false h p V l ds S E

/-- The premises of one round of the loop path `(h, ds, S) :: B` from header valuation `V`:
`RoundWith` without `fmul contract`. -/
def Round (h p : Nat) (ds : List Cond) (S : Summary) (B : List (Nat × List Cond × Summary))
    (V : Valuation) : Prop :=
  RoundWith false h p ds S B V

/-- Whether a round's premises hold, decided by evaluating them (`RoundWith.dec`). -/
instance Round.dec (h p : Nat) (ds : List Cond) (S : Summary)
    (B : List (Nat × List Cond × Summary)) (V : Valuation) : Decidable (Round h p ds S B V) :=
  RoundWith.dec false h p ds S B V

/-- **A path and its last edge, with or without `alloca` and `fmul contract`.** Take flags
`alloca` and `contract`, a program, a function and a path `(l, ds, S) :: ps` that
`coversPathAt alloca contract` accepts from position `p0`. Take a context of the program and a
thread whose innermost frame `f` is at block `l`'s position `p0`. Suppose the path's premises hold
(`WalkWith contract`) and its last block's exit goes to `d` (`Exit.dest`). Then the thread's steps
reach a frame of the function above the same frames, at block `d`'s position `Exit.pc fn d` (after
`d`'s `phi`s for `Exit.phi`), with the path's `alloca` blocks (`Valuation.allocsWith contract`)
in front of `f`'s and `f`'s caller's register, on a memory that adds exactly those blocks to
`m` (`Mem.Adds`). Its entry valuation is `Valuation.roundWith contract l S ps` of `f`'s
(`Block.sound_pathAt_ptrs`, then `Ends.edgeWith`). With the flag `alloca` off the path has no
`alloca` blocks (`Valuation.allocsWith_nil`). -/
theorem Block.sound_edge {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} {l p0 d : Nat} {ds : List Cond} {S : Summary}
    {ps : List (Nat × List Cond × Summary)}
    (hc : coversPathAt alloca contract P fn p0 ((l, ds, S) :: ps) = true)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkWith contract (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hd : ((Valuation.entry c t.k m f).lastWith contract l S ps).2.2.exit.dest
      ((Valuation.entry c t.k m f).lastWith contract l S ps).1
      (vals ((Valuation.entry c t.k m f).lastWith contract l S ps).1
        ((Valuation.entry c t.k m f).lastWith contract l S ps).2.2.nodes) = some d) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = d ∧
      f'.pc = ((Valuation.entry c t.k m f).lastWith contract l S ps).2.2.exit.pc fn d ∧
      f'.allocas = (Valuation.entry c t.k m f).allocsWith contract l S ps ++ f.allocas ∧
      m.Adds ((Valuation.entry c t.k m f).allocsWith contract l S ps) m' ∧ f'.dest = f.dest ∧
      Valuation.entry c t'.k m' f' =
        Valuation.roundWith contract l S ps (Valuation.entry c t.k m f) := by
  have hE := Block.sound_pathAt_ptrs hP ps hc ht hfn hl hp hW
  have hk := Valuation.lastWith_k contract (Valuation.entry c t.k m f) l S ps
  show ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = d ∧
      f'.pc = ((Valuation.entry c t.k m f).lastWith contract l S ps).2.2.exit.pc fn d ∧
      f'.allocas = (Valuation.entry c t.k m f).allocsWith contract l S ps ++ f.allocas ∧
      m.Adds ((Valuation.entry c t.k m f).allocsWith contract l S ps) m' ∧ f'.dest = f.dest ∧
      Valuation.entry c t'.k m' f' =
        ((Valuation.entry c t.k m f).lastWith contract l S ps).1.intoWith contract
          ((Valuation.entry c t.k m f).lastWith contract l S ps).2.1
          ((Valuation.entry c t.k m f).lastWith contract l S ps).2.2
  revert hd hE hk
  generalize (Valuation.entry c t.k m f).lastWith contract l S ps = q
  obtain ⟨W, l', S'⟩ := q
  rintro hd ⟨hE, -, hA⟩ ⟨hWc, hWfn, -⟩
  obtain ⟨t₁, m₁, f', hS₁, hst₁, hfn', hl', hp', hal', hde', hV⟩ :=
    Ends.edgeWith (c := c) hWc hE hd
  obtain ⟨-, me, -, -, -, -, -, -, -, hrun, -⟩ := hE
  have hm : m₁ = me := (congrArg Valuation.mem hV).trans
    ((Valuation.intoWith_mem contract W l' S').trans (Valuation.after_mem hrun))
  subst hm
  exact ⟨_, m₁, f', Steps.trans_step hS₁ hst₁ (.refl _ _), rfl, hfn'.trans (hWfn.trans hfn), hl',
    hp'.trans (congrArg (fun g => S'.exit.pc g d) (hWfn.trans hfn)), hal', hA m₁ hrun, hde', hV⟩

/-- **Blocks in front of blocks in front of a frame's**, for every flag `alloca`, lists `as`,
`bs`, `cs` of blocks and memories `m₀`, `m₁`, `m₂`: if `bs` is some blocks in front of `as` that
`m₁` adds to `m₀` (`Mem.Adds`) and `cs` some blocks in front of `bs` that `m₂` adds to `m₁`, each
list of blocks empty when the flag is off (`bif alloca then xs else []`), then `cs` is some
blocks in front of `as` that `m₂` adds to `m₀`, empty when the flag is off (`Mem.Adds.trans`).
The frames a run of a chain of paths reaches thus have the `alloca` blocks of every path before
them in front of the first frame's, on a memory that adds exactly them, none with the flag
off. -/
theorem allocas_trans {alloca : Bool} {as bs cs : List Nat} {m₀ m₁ m₂ : Mem}
    (h₁ : ∃ xs, bs = (bif alloca then xs else []) ++ as ∧
      m₀.Adds (bif alloca then xs else []) m₁)
    (h₂ : ∃ xs, cs = (bif alloca then xs else []) ++ bs ∧
      m₁.Adds (bif alloca then xs else []) m₂) :
    ∃ xs, cs = (bif alloca then xs else []) ++ as ∧ m₀.Adds (bif alloca then xs else []) m₂ := by
  obtain ⟨xs, rfl, hx⟩ := h₁
  obtain ⟨ys, rfl, hy⟩ := h₂
  refine ⟨ys ++ xs, ?_⟩
  cases alloca
  · exact ⟨rfl, hx.trans hy⟩
  · exact ⟨(List.append_assoc ys xs as).symm, hx.trans hy⟩

/-- **A path's `alloca` blocks, empty with the flag off**: for every flag `alloca` and
`contract`, program, function and path `(l, ds, S) :: ps` that `coversPathAt alloca contract`
accepts, every valuation `V`, lists `as`, `as'` of blocks and memories `m`, `m'`: if `as'` is the
path's `alloca` blocks (`Valuation.allocsWith contract`) in front of `as` and `m'` adds them to
`m` (`Mem.Adds`), then `as'` is some blocks in front of `as` that `m'` adds to `m`, empty when the
flag is off (`Valuation.allocsWith_nil`). -/
theorem Valuation.allocsWith_cond {alloca contract : Bool} {P : Program} {fn : Func}
    {ps : List (Nat × List Cond × Summary)} {l p0 : Nat} {ds : List Cond} {S : Summary}
    (hc : coversPathAt alloca contract P fn p0 ((l, ds, S) :: ps) = true) {V : Valuation}
    {as as' : List Nat} {m m' : Mem} (ha : as' = V.allocsWith contract l S ps ++ as)
    (hm : m.Adds (V.allocsWith contract l S ps) m') :
    ∃ xs, as' = (bif alloca then xs else []) ++ as ∧ m.Adds (bif alloca then xs else []) m' := by
  cases alloca
  · rw [Valuation.allocsWith_nil ps hc V] at ha hm
    exact ⟨[], ha, hm⟩
  · exact ⟨_, ha, hm⟩

/-- **A path through its last edge into the block it enters, with or without `alloca` and
`fmul contract`.** This holds for every flag `alloca` and `contract`, program, function `fn`,
context of the program, frames `rest`, block `d`, position `q`, predicate `J` on valuations and
path `(l, ds, S) :: E` that `coversPathAt alloca contract` accepts from position `p0`. Take a
thread whose innermost frame `f` runs `fn` above `rest` at block `l`'s position `p0`, on memory
`m`, with `BackWith contract d q J` at `f`'s entry valuation: the path's premises, its last edge
to `d` at `q`, and `J` after it. Then the thread's steps reach a frame of `fn` above `rest` at
block `d`'s position `q`, with some blocks (the path's `alloca` blocks; none with the flag
`alloca` off) in front of `f`'s `alloca` blocks, on a memory that adds exactly them to `m`
(`Mem.Adds`), with `f`'s caller's register and `J` at its entry valuation (`Block.sound_edge`,
`Valuation.allocsWith_cond`). -/
theorem BackWith.enter {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} {d q p0 l : Nat} {J : Valuation → Prop}
    {ds : List Cond} {S : Summary} {E : List (Nat × List Cond × Summary)}
    (hc : coversPathAt alloca contract P fn p0 ((l, ds, S) :: E) = true)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = l) (hp : f.pc = p0)
    (hB : BackWith contract d q J (Valuation.entry c t.k m f) l ds S E) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = d ∧
      f'.pc = q ∧ (∃ bs, f'.allocas = (bif alloca then bs else []) ++ f.allocas ∧
        m.Adds (bif alloca then bs else []) m') ∧
      f'.dest = f.dest ∧ J (Valuation.entry c t'.k m' f') := by
  obtain ⟨⟨hW, hd, hpc⟩, hJ⟩ := hB
  obtain ⟨t', m', f', hS, ht', hfn', hl', hp', hal, hA, hde, hV⟩ :=
    Block.sound_edge hP hc ht hfn hl hp hW hd
  exact ⟨t', m', f', hS, ht', hfn', hl', hp'.trans (by rw [← hfn]; exact hpc),
    Valuation.allocsWith_cond hc hal hA, hde, by rw [hV]; exact hJ⟩

/-- **Rounds from an invariant, by induction on the trip count.** Take a flag `alloca`, a
context, function `fn`, frames `rest`, block `h`, position `p`, invariant `I` indexed by the round
number and trip count `n`. Suppose that for every `i < n`, every thread whose innermost frame `f`
runs `fn` above `rest` at `h`'s position `p`, with `I i` at its entry valuation, steps to a frame
of `fn` above `rest` at `h`'s position `p`, with some blocks in front of `f`'s `alloca` blocks
(none with the flag off), `f`'s caller's register and `I (i + 1)` at its entry valuation. Then
every such thread with `I 0` steps to such a frame with `I n`, its `alloca` blocks some blocks in
front of the first frame's, none with the flag off (`allocas_trans`). For every flag, context,
function, block, invariant and trip count; a round is one loop path (`Block.sound_loop`) or runs
nested loops (`ChainWith.reach`). -/
theorem Block.sound_rounds {alloca : Bool} {c : Ctx} {fn : Func} {rest : List Frame} {h p : Nat}
    (I : Nat → Valuation → Prop) (n : Nat)
    (hr : ∀ i < n, ∀ (t : Thread) (m : Mem) (f : Frame), t.frames = f :: rest → f.fn = fn →
      f.label = h → f.pc = p → I i (Valuation.entry c t.k m f) →
      ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = h ∧
        f'.pc = p ∧ (∃ bs, f'.allocas = (bif alloca then bs else []) ++ f.allocas ∧
          m.Adds (bif alloca then bs else []) m') ∧
        f'.dest = f.dest ∧ I (i + 1) (Valuation.entry c t'.k m' f'))
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = h) (hp : f.pc = p) (h0 : I 0 (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = h ∧
      f'.pc = p ∧ (∃ bs, f'.allocas = (bif alloca then bs else []) ++ f.allocas ∧
        m.Adds (bif alloca then bs else []) m') ∧
      f'.dest = f.dest ∧ I n (Valuation.entry c t'.k m' f') := by
  induction n with
  | zero =>
    exact ⟨t, m, f, .refl t m, ht, hfn, hl, hp,
      ⟨[], by cases alloca <;> exact ⟨rfl, Mem.Adds.nil⟩⟩, rfl, h0⟩
  | succ n ih =>
    obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hfn₁, hl₁, hp₁, hal₁, hde₁, hI₁⟩ :=
      ih fun i hi => hr i (by omega)
    obtain ⟨t', m', f', hS, ht', hfn', hl', hp', hal, hde, hI⟩ :=
      hr n (by omega) t₁ m₁ f₁ ht₁ hfn₁ hl₁ hp₁ hI₁
    exact ⟨t', m', f', hS₁.trans hS, ht', hfn', hl', hp', allocas_trans hal₁ hal,
      hde.trans hde₁, hI⟩

/-- **Soundness of a loop, by induction on the trip count, with or without `alloca` and
`fmul contract`** (see the module docstring). This holds for every flag `alloca` and `contract`,
program, function, trip count `n`, context of the program, and loop path `(h, ds, S) :: B` that
`coversPathAt alloca contract` accepts from position `p`. Take a thread whose innermost frame `f`
is at block `h`'s position `p`. If the premises of the first `n` rounds hold (`RoundWith contract`
at `Valuation.roundWith contract`'s iterates), the thread's steps reach `h`'s position `p` again.
The frame there runs the same function, has some blocks (the rounds' `alloca` blocks; none with
the flag `alloca` off) in front of `f`'s `alloca` blocks and `f`'s caller's register, and its
entry valuation is the `n`-th iterate (`Block.sound_rounds` with the invariant "the `i`-th
iterate", each round by `BackWith.enter`). -/
theorem Block.sound_loop {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} {h p : Nat} {ds : List Cond} {S : Summary}
    {B : List (Nat × List Cond × Summary)}
    (hc : coversPathAt alloca contract P fn p ((h, ds, S) :: B) = true) :
    ∀ (n : Nat) {t : Thread} {m : Mem} {f : Frame}, t.frames = f :: rest → f.fn = fn →
      f.label = h → f.pc = p →
      (∀ i < n, RoundWith contract h p ds S B
        ((Valuation.roundWith contract h S B)^[i] (Valuation.entry c t.k m f))) →
      ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = h ∧
        f'.pc = p ∧ (∃ bs, f'.allocas = (bif alloca then bs else []) ++ f.allocas ∧
          m.Adds (bif alloca then bs else []) m') ∧
        f'.dest = f.dest ∧ Valuation.entry c t'.k m' f' =
          (Valuation.roundWith contract h S B)^[n] (Valuation.entry c t.k m f) := by
  intro n t m f ht hfn hl hp hR
  refine Block.sound_rounds
    (fun i W => W = (Valuation.roundWith contract h S B)^[i] (Valuation.entry c t.k m f)) n
    (fun i hi t' m' f' ht' hfn' hl' hp' hV => ?_) ht hfn hl hp rfl
  replace hV : Valuation.entry c t'.k m' f' =
      (Valuation.roundWith contract h S B)^[i] (Valuation.entry c t.k m f) := hV
  refine BackWith.enter (J := fun W =>
      W = (Valuation.roundWith contract h S B)^[i + 1] (Valuation.entry c t.k m f))
    hP hc ht' hfn' hl' hp' ⟨by rw [hV]; exact hR i hi, ?_⟩
  show _ = _
  rw [hV, Function.iterate_succ_apply']

/-- **The premises of every round from an invariant, with or without `fmul contract`.** Take a
flag `contract`, a loop path `(h, ds, S) :: B`, a trip count `n`, an invariant `I` indexed by the
round number, and a valuation `V` with `I 0 V`. Suppose that for every `i < n` and every
valuation `W`, `I i W` gives the premises of a round from `W` (`RoundWith contract`) and
`I (i + 1)` after it (`Valuation.roundWith contract`). Then the premises of rounds 0 to `n - 1`
hold at `Valuation.roundWith contract`'s iterates from `V`, and `I n` holds at the `n`-th
(induction on the round). This is for every flag, loop path, trip count, invariant and
valuation; an invariant `J` that does not depend on the round is `fun _ => J`. -/
theorem Round.of_inv {contract : Bool} {h p : Nat} {ds : List Cond} {S : Summary}
    {B : List (Nat × List Cond × Summary)} (I : Nat → Valuation → Prop) {n : Nat} {V : Valuation}
    (h0 : I 0 V)
    (hI : ∀ i < n, ∀ W, I i W →
      RoundWith contract h p ds S B W ∧ I (i + 1) (Valuation.roundWith contract h S B W)) :
    (∀ i < n, RoundWith contract h p ds S B ((Valuation.roundWith contract h S B)^[i] V)) ∧
      I n ((Valuation.roundWith contract h S B)^[n] V) := by
  have inv : ∀ i, i ≤ n → I i ((Valuation.roundWith contract h S B)^[i] V) := by
    intro i
    induction i with
    | zero => exact fun _ => h0
    | succ i ih =>
      intro hi
      rw [Function.iterate_succ_apply']
      exact (hI i (by omega) _ (ih (by omega))).2
  exact ⟨fun i hi => (hI i hi _ (inv i (by omega))).1, inv n (Nat.le_refl n)⟩

/-- **Soundness of a loop from an invariant, with or without `alloca` and `fmul contract`.**
This holds for every flag `alloca` and `contract`, program, function, trip count `n`, invariant
`I` indexed by the round number, context of the program, and loop path `(h, ds, S) :: B` that
`coversPathAt alloca contract` accepts from position `p`. Take a thread whose innermost frame `f`
is at block `h`'s position `p`. Suppose `I 0` holds at `f`'s entry valuation, and for every
`i < n` and valuation `W`, `I i W` gives `RoundWith contract` at `W` and
`I (i + 1) (Valuation.roundWith contract h S B W)`. Then the thread's steps reach `h`'s position
`p` again, in a frame of the function with some blocks (none with the flag `alloca` off) in front
of `f`'s `alloca` blocks, exactly the blocks the memory `m'` reached adds to `m` (`Mem.Adds`), and
`f`'s caller's register, whose entry valuation satisfies `I n` (`Round.of_inv`,
`Block.sound_loop`). -/
theorem Block.sound_loop_inv {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} {h p : Nat} {ds : List Cond} {S : Summary}
    {B : List (Nat × List Cond × Summary)}
    (hc : coversPathAt alloca contract P fn p ((h, ds, S) :: B) = true)
    (I : Nat → Valuation → Prop) (n : Nat) {t : Thread} {m : Mem} {f : Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = h) (hp : f.pc = p)
    (h0 : I 0 (Valuation.entry c t.k m f))
    (hI : ∀ i < n, ∀ W, I i W →
      RoundWith contract h p ds S B W ∧ I (i + 1) (Valuation.roundWith contract h S B W)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = h ∧
      f'.pc = p ∧ (∃ bs, f'.allocas = (bif alloca then bs else []) ++ f.allocas ∧
        m.Adds (bif alloca then bs else []) m') ∧
      f'.dest = f.dest ∧ I n (Valuation.entry c t'.k m' f') := by
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
/-- **The chain checker, with or without `alloca` and `fmul contract`**: the path checker with
`phi`s and the flags `alloca` and `contract` accepts the paths of the loops `Ls` of `fn` after the
path `(l, ds, S) :: E` (`coversPathAt alloca contract`): that path from position `p0`, and for each
loop of `Ls` the paths of its rounds (`LoopSeg.coversRoundAt alloca contract`) and its path out
from the header's position, the path out taking the place of `(l, ds, S) :: E` for the next loop.
With no loop, the path `(l, ds, S) :: E` alone. With the flag `alloca` on a block of any of the
paths may have `alloca`s. -/
def coversChainAt (alloca contract : Bool) (P : Program) (fn : Func) :
    Nat → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → List LoopSeg → Bool
  | p0, l, ds, S, E, [] => coversPathAt alloca contract P fn p0 ((l, ds, S) :: E)
  | p0, l, ds, S, E, L :: Ls => coversPathAt alloca contract P fn p0 ((l, ds, S) :: E) &&
      LoopSeg.coversRoundAt alloca contract P fn L &&
      coversChainAt alloca contract P fn L.p L.h L.dh L.H L.X Ls

/-- The path checker with `phi`s and the flags `alloca` and `contract` accepts the paths of a
round of loop `L` of `fn`: the loop path from the header's position and the paths of the nested
loops after it (`coversChainAt alloca contract`). -/
def LoopSeg.coversRoundAt (alloca contract : Bool) (P : Program) (fn : Func) : LoopSeg → Bool
  | ⟨h, p, dh, H, B, _, inner⟩ => coversChainAt alloca contract P fn p h dh H B inner
end

/-- **The chain checker without `alloca`, with or without `fmul contract`**: `coversChainAt`
with the flag `alloca` off, each path accepted by `coversPathWith contract`. -/
def coversChainWith (contract : Bool) (P : Program) (fn : Func) :
    Nat → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → List LoopSeg → Bool :=
  coversChainAt false contract P fn

/-- The path checker with `phi`s and the flag `contract` accepts the paths of a round of loop `L`
of `fn`: `LoopSeg.coversRoundAt` with the flag `alloca` off. -/
def LoopSeg.coversRoundWith (contract : Bool) (P : Program) (fn : Func) : LoopSeg → Bool :=
  LoopSeg.coversRoundAt false contract P fn

/-- The path checker with `phi`s accepts the paths of the loops `Ls` of `fn` after a path:
`coversChainWith` without `fmul contract`. -/
def coversChain (P : Program) (fn : Func) :
    Nat → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → List LoopSeg → Bool :=
  coversChainWith false P fn

/-- The path checker with `phi`s accepts the paths of a round of loop `L` of `fn`:
`LoopSeg.coversRoundWith` without `fmul contract`. -/
def LoopSeg.coversRound (P : Program) (fn : Func) : LoopSeg → Bool :=
  LoopSeg.coversRoundWith false P fn

/-- The path checker with `phi`s accepts the paths of loop `L` of `fn`: the entry path from
position `p0`, the paths of a round (the loop path and the nested loops') and the exit path from
the header's position `L.p` (`coversChain` of the one loop). -/
def LoopPaths.covers (P : Program) (fn : Func) (p0 : Nat) (L : LoopPaths) : Bool :=
  coversChain P fn p0 L.l L.ds L.S L.E [L.toLoopSeg]

/-- A run from valuation `V` at the entry of the path `(l, ds, S) :: E` through the loops `Ls` in
order to a last path at whose entry valuation `F` holds, with or without `fmul contract` (every
block after a path's first entered through `Valuation.intoWith contract`), for every flag,
predicate, list of loops, valuation and path. With no loop, `F` holds of the path
(`ChainWith.last`). With a first loop `L` (`ChainWith.loop`), for some invariant `I` indexed by
the round number and trip count `n`:
- the path's premises hold and its last edge goes to the header `L.h` at position `L.p`
  (`EdgeWith contract`), and `I 0` holds at the header's entry valuation
  (`Valuation.roundWith contract` of the path);
- for every `i < n` and valuation `W` of `I i`, the round from `W` runs the loop path and the
  nested loops `L.inner` to a last path whose edge goes back to `L.h` at `L.p` with `I (i + 1)`
  after it (`ChainWith contract` with `BackWith contract`);
- from every valuation of `I n`, the path out of `L` runs through the other loops `Ls`.
Without the flag it is `ChainWith false`; no second inductive is defined for that case. -/
inductive ChainWith (contract : Bool) :
    (Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop) →
    List LoopSeg → Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) →
    Prop
  /-- No loop: `F` holds of the path. -/
  | last {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
      {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
      {E : List (Nat × List Cond × Summary)} :
      F V l ds S E → ChainWith contract F [] V l ds S E
  /-- A first loop `L`: entered by the path (`EdgeWith`), run for `n` rounds from the invariant
  `I` (each to its `BackWith`), and left by its path out. -/
  | loop {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
      {L : LoopSeg} {Ls : List LoopSeg} {V : Valuation} {l : Nat} {ds : List Cond}
      {S : Summary} {E : List (Nat × List Cond × Summary)} (I : Nat → Valuation → Prop)
      (n : Nat) :
      EdgeWith contract L.h L.p V l ds S E → I 0 (Valuation.roundWith contract l S E V) →
      (∀ i < n, ∀ W, I i W → ChainWith contract (BackWith contract L.h L.p (I (i + 1))) L.inner W
        L.h L.dh L.H L.B) →
      (∀ W, I n W → ChainWith contract F Ls W L.h L.dh L.H L.X) →
      ChainWith contract F (L :: Ls) V l ds S E

/-- A run from valuation `V` at the entry of the path `(l, ds, S) :: E`, through the loops `Ls`
in order (each with the loops nested in its rounds), to `ret`, leaving a memory of `Q`, with or
without `fmul contract`: `ChainWith contract` whose last path runs to `ret` (`RetWith contract`),
for every flag, predicate, list of loops, valuation and path. With no loop,
`RetWith contract V Q ((l, ds, S) :: E)`. -/
abbrev RetLsWith (contract : Bool) (Q : Mem → Prop) (Ls : List LoopSeg) (V : Valuation) (l : Nat)
    (ds : List Cond) (S : Summary) (E : List (Nat × List Cond × Summary)) : Prop :=
  ChainWith contract (fun V l ds S E => RetWith contract V Q ((l, ds, S) :: E)) Ls V l ds S E

/-- A run from valuation `V` at the entry of the path `(l, ds, S) :: E`, through the loops `Ls`
in order (each with the loops nested in its rounds), to `ret`, leaving a memory of `Q`:
`RetLsWith` without `fmul contract`, for every predicate, list of loops, valuation and path. With
no loop, `Ret V Q ((l, ds, S) :: E)`. -/
abbrev RetLs (Q : Mem → Prop) (Ls : List LoopSeg) (V : Valuation) (l : Nat) (ds : List Cond)
    (S : Summary) (E : List (Nat × List Cond × Summary)) : Prop :=
  RetLsWith false Q Ls V l ds S E

/-- A run of loop `L` from valuation `V` at its entry path's first block to `ret`, leaving a
memory of `Q` (`RetLs` of the one loop): the entry path's premises and its edge to the header at
position `L.p`, an invariant `I` and trip count `n` with `I 0` at the header and preserved by
every round `i < n`, and from every valuation of `I n` the exit path to `ret` with a memory of `Q`
(`Ret`). The analogue for loops of `Ret`. -/
def RetL (V : Valuation) (Q : Mem → Prop) (L : LoopPaths) : Prop :=
  RetLs Q [L.toLoopSeg] V L.l L.ds L.S L.E

/-- **A thread through a sequence of loops, with nested loops, to its last path, with or without
`alloca` and `fmul contract`.** This holds for every flag `alloca` and `contract`, program,
function `fn`, context of the program, frames `rest`, predicate `F`, list `Ls` of loops, path
`(l, ds, S) :: E` before them and position `p0`, when the path checker with `phi`s and the flags
accepts the paths (`coversChainAt alloca contract`: the path from `p0`, the paths of every round
with its nested loops, and every path out). Take a thread `t` whose innermost frame `f` runs `fn`
above `rest` at block `l`'s position `p0`, on memory `m`, such that `ChainWith contract F Ls`
holds at `f`'s entry valuation. Then `t`'s steps reach a frame of `fn` above `rest`, with some
blocks (the `alloca` blocks of the paths run; none with the flag `alloca` off) in front of `f`'s
`alloca` blocks and `f`'s caller's register, at the first block `l'` of a last path
`(l', ds', S') :: E'` at its position `p'`, which the checker accepts from `p'` and at whose entry
valuation `F` holds. The proof is by induction on `ChainWith`: `Block.sound_edge` into each loop,
`Block.sound_rounds` through its rounds (each by the induction hypothesis to its `BackWith` and
`BackWith.enter` of that), and the induction hypothesis on its path out, the blocks collected
by `Valuation.allocsWith_cond` and `allocas_trans`. -/
theorem ChainWith.reach {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame}
    {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
    {Ls : List LoopSeg} {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} (h : ChainWith contract F Ls V l ds S E) :
    ∀ {p0 : Nat} {t : Thread} {m : Mem} {f : Frame},
      coversChainAt alloca contract P fn p0 l ds S E Ls = true →
      t.frames = f :: rest → f.fn = fn → f.label = l → f.pc = p0 →
      Valuation.entry c t.k m f = V →
      ∃ t' m' f' p' l' ds' S' E', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧
        f'.label = l' ∧ f'.pc = p' ∧
        (∃ bs, f'.allocas = (bif alloca then bs else []) ++ f.allocas ∧
          m.Adds (bif alloca then bs else []) m') ∧ f'.dest = f.dest ∧
        coversPathAt alloca contract P fn p' ((l', ds', S') :: E') = true ∧
        F (Valuation.entry c t'.k m' f') l' ds' S' E' := by
  induction h with
  | last hF =>
    intro p0 t m f hc ht hfn hl hp hV
    subst hV
    simp only [coversChainAt] at hc
    exact ⟨t, m, f, p0, _, _, _, _, .refl t m, ht, hfn, hl, hp,
      ⟨[], by cases alloca <;> exact ⟨rfl, Mem.Adds.nil⟩⟩, rfl, hc, hF⟩
  | @loop F L Ls V l ds S E I n hE h0 _ _ ihr ihx =>
    intro p0 t m f hc ht hfn hl hp hV
    subst hV
    simp only [coversChainAt, Bool.and_eq_true] at hc
    obtain ⟨⟨hcE, hcR⟩, hcX⟩ := hc
    replace hcR : coversChainAt alloca contract P fn L.p L.h L.dh L.H L.B L.inner = true := by
      cases L
      exact hcR
    obtain ⟨hW, hd, hpc⟩ := hE
    obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hfn₁, hl₁, hp₁, hal₁, hA₁, hde₁, hV₁⟩ :=
      Block.sound_edge hP hcE ht hfn hl hp hW hd
    obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hfn₂, hl₂, hp₂, hal₂, hde₂, hI₂⟩ :=
      Block.sound_rounds (alloca := alloca) (c := c) (fn := fn) (rest := rest) (h := L.h)
        (p := L.p) I n
        (fun i hi t m f ht hfn hl hp hI => by
          obtain ⟨t', m', f', p', l', ds', S', E', hS, ht', hfn', hl', hp', hal, hde, hc', hB⟩ :=
            ihr i hi _ hI hcR ht hfn hl hp rfl
          obtain ⟨t'', m'', f'', hS', ht'', hfn'', hl'', hp'', hal', hde', hJ⟩ :=
            BackWith.enter hP hc' ht' hfn' hl' hp' hB
          exact ⟨t'', m'', f'', hS.trans hS', ht'', hfn'', hl'', hp'', allocas_trans hal hal',
            hde'.trans hde, hJ⟩)
        ht₁ hfn₁ hl₁ (hp₁.trans (by rw [← hfn]; exact hpc)) (by rw [hV₁]; exact h0)
    obtain ⟨t', m', f', p', l', ds', S', E', hS, ht', hfn', hl', hp', hal, hde, hc', hF⟩ :=
      ihx _ hI₂ hcX ht₂ hfn₂ hl₂ hp₂ rfl
    exact ⟨t', m', f', p', l', ds', S', E', hS₁.trans (hS₂.trans hS), ht', hfn', hl', hp',
      allocas_trans (allocas_trans (Valuation.allocsWith_cond hcE hal₁ hA₁) hal₂) hal,
      hde.trans (hde₂.trans hde₁), hc', hF⟩

/-- **A thread through a sequence of loops into the block the last path out enters, with or
without `alloca` and `fmul contract`.** This holds for every flag `alloca` and `contract`,
program, function `fn`, context of the program, frames `rest`, block `d`, position `q`,
predicate `J` on valuations, list `Ls` of loops, path `(l, ds, S) :: E` before them and position
`p0`, when the path checker with `phi`s and the flags accepts the paths (`coversChainAt alloca
contract`). Take a thread `t` whose innermost frame `f` runs `fn` above `rest` at block `l`'s
position `p0`, on memory `m`, such that the run through the loops goes from `f`'s entry
valuation to a last path that stops after its last edge, into `d` at `q` with `J` after it
(`ChainWith contract` with `BackWith contract d q J`). Then `t`'s steps reach a frame of `fn`
above `rest` at block `d`'s position `q`, with some blocks (the `alloca` blocks of the paths
run; none with the flag `alloca` off) in front of `f`'s `alloca` blocks, on a memory that adds
exactly them to `m` (`Mem.Adds`), with `f`'s caller's register and `J` at its entry valuation.
`ChainWith.reach` to the last path, then `BackWith.enter`, the blocks collected by
`allocas_trans`. -/
theorem ChainWith.enter {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} {d q : Nat} {J : Valuation → Prop}
    {Ls : List LoopSeg} {p0 l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)}
    (hc : coversChainAt alloca contract P fn p0 l ds S E Ls = true)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = l) (hp : f.pc = p0)
    (h : ChainWith contract (BackWith contract d q J) Ls (Valuation.entry c t.k m f) l ds S E) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = fn ∧ f'.label = d ∧
      f'.pc = q ∧ (∃ bs, f'.allocas = (bif alloca then bs else []) ++ f.allocas ∧
        m.Adds (bif alloca then bs else []) m') ∧
      f'.dest = f.dest ∧ J (Valuation.entry c t'.k m' f') := by
  obtain ⟨t₁, m₁, f₁, p₁, l₁, ds₁, S₁, E₁, hS, ht₁, hfn₁, hl₁, hp₁, hal, hde, hc₁, hB⟩ :=
    ChainWith.reach hP h hc ht hfn hl hp rfl
  obtain ⟨t', m', f', hS', ht', hfn', hl', hp', hal', hde', hJ⟩ :=
    BackWith.enter hP hc₁ ht₁ hfn₁ hl₁ hp₁ hB
  exact ⟨t', m', f', hS.trans hS', ht', hfn', hl', hp', allocas_trans hal hal', hde'.trans hde,
    hJ⟩

/-- **A first loop from the iterates of a function, with or without `fmul contract`.** For every
flag `contract`, predicate `F`, loop `L`, list `Ls` of loops after it, path `(l, ds, S) :: E` before
it, valuation `V`, function `g` on valuations and trip count `n`, with `V₀ = Valuation.roundWith
contract l S E V` the header's entry valuation: if the path's premises hold at `V` and its last edge
goes to `L.h` at position `L.p` (`EdgeWith contract`), for every `i < n` the round from `g^[i] V₀`
runs through the nested loops `L.inner` and back to `L.h` with the header's valuation `g (g^[i] V₀)`
after it (`ChainWith contract` with `BackWith`), and the path out runs through `Ls` from `g^[n] V₀`,
then `ChainWith contract F (L :: Ls)` holds at `V`, with the invariant `fun i W => W = g^[i] V₀`. On
a concrete valuation, function and trip count the premises of the edges are closed propositions that
the kernel decides (`EdgeWith.dec`). -/
theorem ChainWith.of_iter {contract : Bool}
    {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
    {L : LoopSeg} {Ls : List LoopSeg} {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} (g : Valuation → Valuation) (n : Nat)
    (he : EdgeWith contract L.h L.p V l ds S E)
    (hr : ∀ i < n, ChainWith contract
      (BackWith contract L.h L.p (· = g (g^[i] (Valuation.roundWith contract l S E V)))) L.inner
      (g^[i] (Valuation.roundWith contract l S E V)) L.h L.dh L.H L.B)
    (hx : ChainWith contract F Ls (g^[n] (Valuation.roundWith contract l S E V)) L.h L.dh L.H
      L.X) :
    ChainWith contract F (L :: Ls) V l ds S E :=
  .loop (fun i W => W = g^[i] (Valuation.roundWith contract l S E V)) n he rfl
    (fun i hi W hW => by
      subst hW
      simp only [Function.iterate_succ_apply']
      exact hr i hi)
    (fun W hW => by subst hW; exact hx)

/-- **A first loop with no nested loop from its rounds, with or without `fmul contract`.** For
every flag `contract`, predicate `F`, loop `L` with no nested loop, list `Ls` of loops after it,
path `(l, ds, S) :: E` before it, valuation `V` and trip count `n`: if the path's premises hold at
`V` and its last edge goes to `L.h` at position `L.p` (`EdgeWith contract`), the premises of
rounds 0 to `n - 1` hold at the iterates of the header's entry valuation (`RoundWith contract`),
and the path out runs through `Ls` from the `n`-th iterate, then `ChainWith contract F (L :: Ls)`
holds at `V` (`ChainWith.of_iter` with `Valuation.roundWith contract` of the loop path). On a
concrete valuation and trip count the first premise is a closed proposition that the kernel
decides (`EdgeWith.dec`, `RoundWith.dec`). -/
theorem ChainWith.of_rounds {contract : Bool}
    {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
    {L : LoopSeg} {Ls : List LoopSeg} {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} (hL : L.inner = []) (n : Nat)
    (h : EdgeWith contract L.h L.p V l ds S E ∧ ∀ i < n, RoundWith contract L.h L.p L.dh L.H L.B
      ((Valuation.roundWith contract L.h L.H L.B)^[i] (Valuation.roundWith contract l S E V)))
    (hx : ChainWith contract F Ls
      ((Valuation.roundWith contract L.h L.H L.B)^[n] (Valuation.roundWith contract l S E V))
      L.h L.dh L.H L.X) :
    ChainWith contract F (L :: Ls) V l ds S E :=
  ChainWith.of_iter _ n h.1 (fun i hi => by rw [hL]; exact .last ⟨h.2 i hi, rfl⟩) hx

/-- **A thread through a sequence of loops to its end, with or without `alloca` and
`fmul contract`.** This holds for every flag `alloca` and `contract`, program, function `fn`,
context of the program, list `Ls` of loops (each with the loops nested in its rounds), path
`(l, ds, S) :: E` before them, position `p0` and predicate `Q` on memories, when the path checker
with `phi`s and the flags accepts the paths (`coversChainAt alloca contract`). Take a thread `t`
with one frame `f` of `fn` at block `l`'s position `p0`, on memory `m`, such that the run through
the loops goes from `f`'s entry valuation to `ret` with a memory `me` of `Q` (`RetLsWith contract`:
each loop entered from the path before it, run from its invariant through its nested loops, and
left by its path out). Then `t` runs to its end (`Runs`), leaving `me` with some blocks `bs` and
`f`'s `alloca` blocks dead, where `bs` is exactly the blocks `me` adds to `m` (`Mem.Adds`: the
`alloca` blocks of the paths run; none with the flag `alloca` off). The proof is
`ChainWith.reach` to the last path, then `Block.sound_retWith`, the blocks collected by
`Valuation.allocsWith_cond` and `allocas_trans`. -/
theorem Runs.of_chainWith {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {Q : Mem → Prop} :
    ∀ (Ls : List LoopSeg) {p0 l : Nat} {ds : List Cond} {S : Summary}
      {E : List (Nat × List Cond × Summary)},
      coversChainAt alloca contract P fn p0 l ds S E Ls = true →
      ∀ {t : Thread} {m : Mem} {f : Frame}, t.frames = [f] → f.fn = fn → f.label = l →
        f.pc = p0 → RetLsWith contract Q Ls (Valuation.entry c t.k m f) l ds S E →
        ∃ bs me, Runs c t m (((bif alloca then bs else []) ++ f.allocas).foldl
          (fun m b => m.setLive b false) me) ∧ Q me ∧ m.Adds (bif alloca then bs else []) me := by
  intro Ls p0 l ds S E hc t m f ht hfn hl hp hR
  obtain ⟨t', m', f', p', l', ds', S', E', hS, ht', hfn', hl', hp', hal, -, hc', hW, hret, me,
    hme, hQ⟩ := ChainWith.reach hP hR hc ht hfn hl hp rfl
  obtain ⟨fe, me', hS', hrun, hst⟩ := Block.sound_retWith hP hc' ht' hfn' hl' hp' hW rfl hret
  obtain rfl : me = me' := Except.ok.inj (hme.symm.trans hrun)
  obtain ⟨xs, hxs, hA⟩ := allocas_trans hal (Valuation.allocsWith_cond hc' (as := f'.allocas) rfl
    ((Block.sound_pathAt_ptrs hP E' hc' ht' hfn' hl' hp' hW).2.2 me hme))
  rw [hxs] at hst
  exact ⟨xs, me, ⟨_, _, hS.trans hS', hst⟩, hQ, hA⟩

/-- **A thread through a loop to its end.** This holds for every program, function `fn`, context
of the program, loop `L` of `fn` whose paths the path checker with `phi`s accepts
(`LoopPaths.covers`, the entry path from position `p0`), and predicate `Q` on memories. Take a
thread `t` with one frame `f` of `fn` at block `L.l`'s position `p0`, on memory `m`, such that
`L` runs from `f`'s entry valuation to `ret` with a memory `me` of `Q` (`RetL`: the entry path's
premises and its edge to the header, an invariant `I` and trip count `n` with `I 0` at the
header, preserved by every round `i < n`, and from `I n` the exit path to `ret`). Then `t` runs
to its end (`Runs`), leaving `me` with `f`'s `alloca` blocks dead: `Runs.of_chainWith` without
`alloca` and `fmul contract`, with the one loop. -/
theorem Runs.of_loop {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P) {p0 : Nat}
    {L : LoopPaths} (hc : L.covers P fn p0 = true) {t : Thread} {m : Mem} {f : Frame}
    (ht : t.frames = [f]) (hfn : f.fn = fn) (hl : f.label = L.l) (hp : f.pc = p0)
    {Q : Mem → Prop} (hR : RetL (Valuation.entry c t.k m f) Q L) :
    ∃ me, Runs c t m (f.allocas.foldl (fun m b => m.setLive b false) me) ∧ Q me :=
  let ⟨_, me, h, hq, _⟩ := Runs.of_chainWith (alloca := false) (contract := false) hP
    [L.toLoopSeg] hc ht hfn hl hp hR
  ⟨me, h, hq⟩

/-- Every sequence of loops of `Cs` starts at the label of `fn`'s first block, and its paths are
accepted by the path checker with `phi`s and the flags `alloca` and `contract`, the entry path
from position 0 (`coversChainAt alloca contract`): the analogue for loops of `coversEntryWith`
(MojoProof/Sym/Kernel.lean), a closed Boolean that the kernel decides on a concrete program. -/
def coversChainsAt (alloca contract : Bool) (P : Program) (fn : Func) (Cs : List LoopChain) :
    Bool :=
  Cs.all fun C => decide (fn.blocks[0]?.map (·.label) = some C.l) &&
    coversChainAt alloca contract P fn 0 C.l C.ds C.S C.E C.loops

/-- Every sequence of loops of `Cs` starts at the label of `fn`'s first block, and its paths are
accepted by the path checker with `phi`s and the flag `contract`: `coversChainsAt` with the flag
`alloca` off. -/
def coversChainsWith (contract : Bool) (P : Program) (fn : Func) (Cs : List LoopChain) : Bool :=
  coversChainsAt false contract P fn Cs

/-- Every sequence of loops of `Cs` starts at the label of `fn`'s first block, and its paths are
accepted by the path checker with `phi`s: `coversChainsWith` without `fmul contract`, the analogue
for loops of `coversEntry`. -/
def coversChains (P : Program) (fn : Func) (Cs : List LoopChain) : Bool :=
  coversChainsWith false P fn Cs

/-- `coversChains` of the loops of `loops`, each a sequence of one loop (`LoopPaths.chain`). -/
def coversLoops (P : Program) (fn : Func) (loops : List LoopPaths) : Bool :=
  coversChains P fn (loops.map LoopPaths.chain)

/-- **A kernel's thread through a sequence of loops to its end, with or without `alloca` and
`fmul contract`**, in the form of `Grid.start_thread`'s threads (MojoProof/Sym/Kernel.lean): for
every flag `alloca` and `contract`, program `P`, kernel `fn`, context of `P`, list `Cs` of
sequences of loops that `coversChainsAt alloca contract` accepts, predicate `Q`, and thread `t`
with one frame `f` of `fn` at the label of `fn`'s first block, position 0, with no `alloca`
blocks, on memory `m`: if some sequence of `Cs` runs from `f`'s entry valuation to `ret` with a
memory `me` of `Q` (`RetLsWith contract`), `t` runs to its end (`Runs`) leaving `me` with some
blocks `bs` dead, where `bs` is exactly the blocks `me` adds to `m` (`Mem.Adds`: the `alloca`
blocks of the paths run, none with the flag `alloca` off; `Runs.of_chainWith`).
`Runs.of_chainsDead` is the memory this leaves. -/
theorem Runs.of_chainsAt {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {Cs : List LoopChain} (hc : coversChainsAt alloca contract P fn Cs = true)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = fn)
    (hl : fn.blocks[0]?.map (·.label) = some f.label) (hp : f.pc = 0) (ha : f.allocas = [])
    {Q : Mem → Prop}
    (hR : ∃ C ∈ Cs, RetLsWith contract Q C.loops (Valuation.entry c t.k m f) C.l C.ds C.S C.E) :
    ∃ bs me, Runs c t m ((bif alloca then bs else []).foldl (fun m b => m.setLive b false) me) ∧
      Q me ∧ m.Adds (bif alloca then bs else []) me := by
  obtain ⟨C, hC, hR⟩ := hR
  have h := List.all_eq_true.1 hc C hC
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨bs, me, hr, hq, hA⟩ :=
    Runs.of_chainWith hP C.loops h.2 ht hfn (Option.some.inj (hl.symm.trans h.1)) hp hR
  rw [ha, List.append_nil] at hr
  exact ⟨bs, me, hr, hq, hA⟩

/-- **A kernel's thread through a sequence of loops to its end, with or without `fmul contract`**:
`Runs.of_chainsAt` with the flag `alloca` off, whose paths have no `alloca` blocks, for every
flag `contract`, program, kernel, context, list of sequences of loops that `coversChainsWith
contract` accepts, predicate `Q` and thread as there: `t` runs to its end leaving a memory of `Q`.
The analogue for loops of `Runs.of_ret`: with `Q = P (k + 1)` its conclusion is the premise
`Seq.start_sound_inv` takes for thread `k`. -/
theorem Runs.of_chainsWith {contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {Cs : List LoopChain} (hc : coversChainsWith contract P fn Cs = true)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = fn)
    (hl : fn.blocks[0]?.map (·.label) = some f.label) (hp : f.pc = 0) (ha : f.allocas = [])
    {Q : Mem → Prop}
    (hR : ∃ C ∈ Cs, RetLsWith contract Q C.loops (Valuation.entry c t.k m f) C.l C.ds C.S C.E) :
    ∃ m', Runs c t m m' ∧ Q m' :=
  let ⟨_, me, hr, hq, _⟩ := Runs.of_chainsAt (alloca := false) hP hc ht hfn hl hp ha hR
  ⟨me, hr, hq⟩

/-- **A kernel's thread with `alloca`s to its end**: for every flag `alloca` and `contract`,
program, function and path `(l, ds, S) :: ps` that `coversPathAt alloca contract` accepts (the
first block from position `p0`), every context of the program and thread whose only frame `f` is
at block `l`'s position `p0`, with memory `m`: if the path runs from `f`'s entry valuation to
`ret` with a memory `me` of `Q` (`RetWith contract`), `t` runs to its end (`Runs`) leaving `me`
with the path's `alloca` blocks (`Valuation.allocsWith contract`) and `f`'s dead
(`Block.sound_retWith` with no caller frame). `Runs.of_retWith` is the case of a path without
`alloca`. -/
theorem Runs.of_retAt {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {p0 l : Nat} {ds : List Cond} {S : Summary}
    {ps : List (Nat × List Cond × Summary)}
    (hc : coversPathAt alloca contract P fn p0 ((l, ds, S) :: ps) = true) {t : Thread} {m : Mem}
    {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    {Q : Mem → Prop} (hR : RetWith contract (Valuation.entry c t.k m f) Q ((l, ds, S) :: ps)) :
    ∃ me, Runs c t m (((Valuation.entry c t.k m f).allocsWith contract l S ps ++
      f.allocas).foldl (fun m b => m.setLive b false) me) ∧ Q me := by
  obtain ⟨hW, hret, me, hm, hq⟩ := hR
  obtain ⟨fe, me', hS, hm', hst⟩ := Block.sound_retWith hP hc ht hfn hl hp hW rfl hret
  obtain rfl : me = me' := Except.ok.inj (hm.symm.trans hm')
  exact ⟨me, ⟨_, _, hS, hst⟩, hq⟩

/-- **A kernel's thread along a path to its end, with or without `fmul contract`**: for every
flag `contract`, program `P`, kernel `fn`, context of `P`, path `ps` that
`coversPathWith contract` accepts from position `p0`, predicate `Q`, and thread `t` with one
frame `f` of `fn` at the path's first block and position `p0`, with no `alloca` blocks, on memory
`m`: if the path runs from `f`'s entry valuation to `ret` with a memory of `Q`
(`RetWith contract`), `t` runs to its end (`Runs`) leaving a memory of `Q` (`Runs.of_retAt`
with the flag `alloca` off, whose path has no `alloca` blocks, `Valuation.allocsWith_nil`). -/
theorem Runs.of_retWith {contract : Bool} {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {p0 : Nat} {ps : List (Nat × List Cond × Summary)}
    (hc : coversPathWith contract P fn p0 ps = true) {t : Thread} {m : Mem} {f : Frame}
    (ht : t.frames = [f]) (hfn : f.fn = fn) (hl : ps.head?.map (·.1) = some f.label)
    (hp : f.pc = p0) (ha : f.allocas = []) {Q : Mem → Prop}
    (hR : RetWith contract (Valuation.entry c t.k m f) Q ps) : ∃ m', Runs c t m m' ∧ Q m' := by
  rcases ps with _ | ⟨⟨l, ds, S⟩, ps⟩
  · exact (hR : False).elim
  obtain ⟨me, hr, hq⟩ :=
    Runs.of_retAt (alloca := false) hP hc ht hfn (by simpa using hl.symm) hp hR
  rw [Valuation.allocsWith_nil ps hc, ha] at hr
  exact ⟨me, hr, hq⟩

/-- **A kernel's thread through a loop to its end**: `Runs.of_chainsWith` without `fmul contract`
for loops of one loop each (`coversLoops`, `RetL`, `LoopPaths.chain`), for every program, kernel,
context, list of loops, predicate and thread as there. -/
theorem Runs.of_loops {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P)
    {loops : List LoopPaths} (hc : coversLoops P fn loops = true) {t : Thread} {m : Mem}
    {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = fn)
    (hl : fn.blocks[0]?.map (·.label) = some f.label) (hp : f.pc = 0) (ha : f.allocas = [])
    {Q : Mem → Prop} (hR : ∃ L ∈ loops, RetL (Valuation.entry c t.k m f) Q L) :
    ∃ m', Runs c t m m' ∧ Q m' :=
  Runs.of_chainsWith (contract := false) hP hc ht hfn hl hp ha
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
  have hf' : enter (V.ctx.scope (V.afterWith false S).mem (V.frameAtWith false l S)
      (V.k + S.len)) (V.frameAtWith false l S) d' = .ok f := hf
  show V.intoWith false l S = { V.afterWith false S with regs := f.regs, prods := f.prods }
  rw [Valuation.intoWith, hd]
  simp only [hx, hf']

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

/-- A load reads only its pointer's block: on two memories with the same block there, every load
through the pointer gives the same result, for every layout, thread, space, type and alignment. -/
theorem Mem.load_of_block {l : Layout} {m m' : Mem} {p : Ptr}
    (h : m'.blocks p.block = m.blocks p.block) (w : Who) (a : Nat) (t : Ty) (al : Option Nat) :
    m'.load l w a t p al = m.load l w a t p al := by
  simp only [Mem.load, Mem.check, Mem.block, Mem.addr, h]

/-- **Liveness changes keep the loads of the other blocks**: for every memory, list `bs`,
liveness, layout, thread, address space, type, pointer `p` whose block is not in `bs`, and
alignment, a load through `p` after setting the liveness of the blocks of `bs` in turn gives what
it gives before (`Mem.foldl_setLive_blocks`). So the memory a thread leaves by `ret` has the loads
of every block outside its frame's `alloca` blocks. -/
theorem _root_.MojoProof.Sem.Mem.foldl_setLive_load {bs : List Nat} {v : Bool} {m : Mem}
    {p : Ptr} (h : p.block ∉ bs) (l : Layout) (w : Who) (a : Nat) (t : Ty) (al : Option Nat) :
    (bs.foldl (fun m b => m.setLive b v) m).load l w a t p al = m.load l w a t p al :=
  MojoProof.Sym.Mem.load_of_block (MojoProof.Sem.Mem.foldl_setLive_blocks h) w a t al

/-- **Setting a block dead**: for every memory `m` and numbers `a`, `b`, after
`Mem.setLive a false` the block at `b` is `m`'s, dead (its bytes kept) when `b = a`. -/
theorem _root_.MojoProof.Sem.Mem.setLive_false_blocks (m : Mem) (a b : Nat) :
    (m.setLive a false).blocks b =
      if b = a then (m.blocks b).map ({ · with live := false }) else m.blocks b := by
  unfold Mem.setLive
  split
  · rename_i blk hblk
    by_cases e : b = a
    · subst e
      simp [Mem.set, hblk]
    · simp [Mem.set, e]
  · rename_i hn
    by_cases e : b = a
    · subst e
      simp [hn]
    · simp [e]

/-- **Setting blocks dead in turn** (`ret`'s cleanup of a frame's `alloca` blocks): for every
number `b`, list `bs` and memory `m`, the block at `b` is `m`'s, dead (its bytes kept) when
`b ∈ bs` (`Mem.setLive_false_blocks`). -/
theorem _root_.MojoProof.Sem.Mem.foldl_setLive_false (b : Nat) :
    ∀ (bs : List Nat) (m : Mem), (bs.foldl (fun m b => m.setLive b false) m).blocks b =
      if b ∈ bs then (m.blocks b).map ({ · with live := false }) else m.blocks b
  | [], m => by simp
  | a :: bs, m => by
    simp only [List.foldl_cons]
    rw [MojoProof.Sem.Mem.foldl_setLive_false b bs, MojoProof.Sem.Mem.setLive_false_blocks]
    by_cases ha : b = a
    · subst ha
      by_cases hb : b ∈ bs
      · simp only [hb, List.mem_cons_self, ↓reduceIte]
        cases m.blocks b <;> rfl
      · simp only [hb, List.mem_cons_self, ↓reduceIte]
    · by_cases hb : b ∈ bs
      · simp only [hb, ha, List.mem_cons_of_mem _ hb, ↓reduceIte]
      · have hb' : b ∉ a :: bs := fun h => (List.mem_cons.1 h).elim ha hb
        simp only [hb, ha, hb', ↓reduceIte]

/-- **`ret`'s cleanup of the blocks a run adds**: for every memories `m`, `me`, list `bs` of the
blocks `me` adds to `m` (`Mem.Adds`) and number `b`, after setting the blocks of `bs` dead in
turn the block at `b` is `me`'s, dead (its bytes kept) when `m` has none there
(`Mem.foldl_setLive_false`). So the blocks of `m` are as in `me`, and every block the run adds is
dead. -/
theorem _root_.MojoProof.Sem.Mem.Adds.foldl_setLive {m me : Mem} {bs : List Nat}
    (h : m.Adds bs me) (b : Nat) : (bs.foldl (fun m b => m.setLive b false) me).blocks b =
      if (m.blocks b).isSome then me.blocks b
      else (me.blocks b).map ({ · with live := false }) := by
  rw [MojoProof.Sem.Mem.foldl_setLive_false]
  by_cases hm : (m.blocks b).isSome
  · have hb : b ∉ bs := fun hb => by simp [((h.new b).1 hb).1] at hm
    simp only [hb, hm, ↓reduceIte]
  · have hm0 : m.blocks b = none := by simpa using hm
    simp only [hm, ↓reduceIte, Bool.false_eq_true]
    by_cases hb : b ∈ bs
    · simp only [hb, ↓reduceIte]
    · simp only [hb, ↓reduceIte]
      cases e : me.blocks b with
      | none => rfl
      | some _ => exact absurd ((h.new b).2 ⟨hm0, by simp [e]⟩) hb

/-- **The memory a kernel's thread through a sequence of loops leaves**: for every flag `alloca`
and `contract`, program, kernel, context, list `Cs` of sequences of loops, thread and memory `m`
as in `Runs.of_chainsAt`, predicate `Q` and predicate `R` that reads only the blocks of `m`,
`next` and the trace (memories that agree there agree on `R`): if some sequence of `Cs` runs from
`f`'s entry valuation to `ret` with a memory `me` of `Q` and `R`, `t` runs to its end leaving a
memory `m'` of `R` whose block at every number is `me`'s, dead where `m` has none. So the blocks
of `m` are as the run leaves them, and every block the run adds is dead
(`Runs.of_chainsAt`, `Mem.Adds.foldl_setLive`). -/
theorem Runs.of_chainsDead {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {Cs : List LoopChain} (hc : coversChainsAt alloca contract P fn Cs = true)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = fn)
    (hl : fn.blocks[0]?.map (·.label) = some f.label) (hp : f.pc = 0) (ha : f.allocas = [])
    {Q R : Mem → Prop}
    (hRm : ∀ m₁ m₂ : Mem, (∀ b, (m.blocks b).isSome → m₁.blocks b = m₂.blocks b) →
      m₁.next = m₂.next → m₁.trace = m₂.trace → R m₁ → R m₂)
    (hR : ∃ C ∈ Cs, RetLsWith contract (fun me => Q me ∧ R me) C.loops
      (Valuation.entry c t.k m f) C.l C.ds C.S C.E) :
    ∃ me m', Runs c t m m' ∧ Q me ∧ R m' ∧ ∀ b, m'.blocks b =
      if (m.blocks b).isSome then me.blocks b
      else (me.blocks b).map ({ · with live := false }) := by
  obtain ⟨bs, me, hr, ⟨hq, hR'⟩, hA⟩ := Runs.of_chainsAt hP hc ht hfn hl hp ha hR
  refine ⟨me, _, hr, hq, hRm me _ (fun b hb => ?_) (Mem.foldl_setLive_keeps me _ false).next.symm
    (Mem.foldl_setLive_trace me _ false).symm hR', hA.foldl_setLive⟩
  simp only [hA.foldl_setLive, hb, ↓reduceIte]

end MojoProof.Sym
