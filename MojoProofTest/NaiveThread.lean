import MojoProofTest.SymNaive
import MojoProofTest.SymSelect
import MojoProofTest.NaiveRun
import MojoProof.Sym.KernelMat
import MojoProof.Sym.LoopFacts

/-!
# The naive matmul kernel's thread: every thread from premises, and one launch

A thread of the naive matmul kernel (`naive`, MojoProofTest/SymPhi.lean) in bounds runs the path
`%6 → %45` into the loop head `%46`, the loop `naiveL` (`%46 → %50 → %52`, with `fmul contract`,
MojoProofTest/SymNaive.lean) once per element of its row, and the path out `%51 → %67 → %69`,
which stores the accumulator `%48` to its cell of `C` and returns.

## Every thread

* `chainN`, `chainN_covers`: that run as a sequence of loops (`LoopChain`), accepted by the path
  checker with `fmul contract` (`coversChainsWith true`).
* `head`, `round`, `latchAt`, `steps`: the entry valuations of `%46` after the path, of `%46`
  after a round and of the latch in a round; for every valuation the path adds 39 steps, a round
  18, and the latch is entered 3 steps after the head (`LoopSeg.steps_k`).
* `oN`, `Inv`: the oracle numbers of round `j`'s `fmul` and `fadd`, those of steps
  `k0 + 54 + 18 j` and `k0 + 55 + 18 j` (lane 0) for a thread whose entry valuation has step
  count `k0`; and the loop's invariant at the head of round `j`: `%47 = j` and `%48` holds
  `dotLoop` with `fmul contract` over the first `j` factor pairs under those numbers.
* `thread_run`: for every valuation of `naive`'s function, list of factor pairs (the trip count
  is its length), predicate on the head's valuations and predicate on the memory at the return,
  the thread runs `chainN` to `ret` (`RetLsWith true`, the per-thread premise of the kernel
  theorem with `fmul contract`), from premises: the entry block's obligations and branch into
  `%45`, the invariant at round 0, each round's premises and register updates, and the path
  out's premises. The proof is `RetLsWith.of_inv` (MojoProof/Sym/KernelMat.lean), the edge
  `%45 → %46` is `SymNaive.pre_edge`.
* `round_inv`: a round keeps `Inv` when the counter and the accumulator after it are those the
  round's premises give (`floatBin_dotStep`); from the round's premises, a predicate after it and
  those registers (`NaiveIn.round_in`'s conclusion) it gives the premises, `Inv` and the predicate
  after it, a round of `LoopInvWith` at the invariant `Inv ∧ G`.
* `skipN`, `skipN_covers`, `thread_skip`: a thread out of bounds runs `%6 → %44 → %69`, accepted
  by the path checker with `fmul contract`; for every valuation and predicate on the memory at
  the return, it runs that path to `ret` (`RetWith true`) from the entry block's obligations and
  branch into `%44`, with the memory of the entry block's three loads (no store runs).

## One launch

* `memN`, `argsN`, `ωN`, `runN`, `gN`, `cN`, `startN`, `frN`, `VN`, `psN`: a start of `naive`
  on one block of 2 × 2 threads with `m = n = 1` and `K = 2`, whose thread 0 (thread `(0, 0)`,
  the one in bounds) multiplies row 0 of `NaiveRun.aw` by row 0 of `NaiveRun.bw`, under an
  oracle that fuses the `fadd` at step 73.
* `reg_of_bits`, `reg_of_float`: a register's value from a `decide +kernel` check.
* `thread0_chain`, `thread0`: `thread_run`'s premises at thread 0, closed by `decide +kernel`, and
  the thread's run from `Grid.start`'s entry frame to `ret` (`Runs.of_chainsWith true`): cell
  `(0, 0)` holds `dotLoop` under the oracle numbers of steps 54, 55, 72 and 73, those of `oN`.
* `thread0_twin`: the invariant under the oracle numbers one step later fails.
* `skip_threads`: threads 1 to 3, out of bounds, run to their end by `thread_skip`, with the
  memory of their loads; thread 0's branch goes to `%45`, so `thread_skip`'s premise fails there.

`thread_run` and `thread_skip` cover every thread of every launch of `naive` whose premises hold,
in bounds and out of bounds. `thread0`, `thread0_twin` and `skip_threads` are tests: one launch,
memory, address choice and oracle. `memN` does not meet `NaiveSpec.At` (its blocks hold one and
two floats); MojoProofTest/NaiveStart.lean runs every thread of a start that does.
-/

namespace MojoProofTest.NaiveThread

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.SymNaive
open FloatLib.Floats.Formats.BinaryInterchange

/-! ## Every thread -/

/-- The naive kernel's sequence of loops from its entry: the path `%6 → %45` (the entry block
`SymSelect.entry`, then the preheader `pre`), then the loop `naiveL` with its path out
`%51 → %67 → %69`. -/
def chainN : LoopChain :=
  ⟨naive.fn_0.b_0.label, SymSelect.entry.obls, SymSelect.entry,
    [(naive.fn_0.b_2.label, pre.obls, pre)], [naiveL]⟩

/-- The path checker with `fmul contract` accepts `chainN` from the function's first block: the
path `%6 → %45` into `%46`'s position 2, the loop's round and its path out
(`coversChainsWith true`). -/
theorem chainN_covers : coversChainsWith true naive.prog naive.fn_0 [chainN] = true := by
  decide +kernel

/-- The entry valuation of the loop head `%46` (position 2) after the path `%6 → %45` from `V`
(`Valuation.roundWith true` of the path). -/
abbrev head (V : Valuation) : Valuation :=
  Valuation.roundWith true naive.fn_0.b_0.label SymSelect.entry
    [(naive.fn_0.b_2.label, pre.obls, pre)] V

/-- One round of `naiveL` with `fmul contract`: the entry valuation of `%46` after
`%46 → %50 → %52` from `W`. -/
abbrev round (W : Valuation) : Valuation :=
  Valuation.roundWith true naiveL.h naiveL.H naiveL.B W

/-- The entry valuation of the latch `%52` in the round from `W`. -/
abbrev latchAt (W : Valuation) : Valuation :=
  (W.lastWith true naiveL.h naiveL.H naiveL.B).1

/-- **The step counts of the thread's paths**, for all valuations `V`, `W` and every `j`: the
path `%6 → %45` keeps the context and the function and adds 39 steps (its 38 statements and
branches, then the branch into `%46`); `j` rounds keep them and add `18 * j`; the latch is
entered 3 steps after the head (`LoopSeg.steps_k` at `naiveL`). -/
theorem steps (V W : Valuation) (j : Nat) :
    (head V).ctx = V.ctx ∧ (head V).fn = V.fn ∧ (head V).k = V.k + 39 ∧
      (round^[j] W).ctx = W.ctx ∧ (round^[j] W).fn = W.fn ∧ (round^[j] W).k = W.k + 18 * j ∧
      (latchAt W).ctx = W.ctx ∧ (latchAt W).k = W.k + 3 :=
  LoopSeg.steps_k true _ _ _ naiveL (by decide +kernel) (by decide +kernel)
    (by decide +kernel) V W j

/-- The oracle numbers of round `j`'s `fmul` (`%65`, the latch's statement 12) and `fadd`
(`%66`, statement 13), lane 0, for a thread whose entry valuation has context `c` and step count
`k0`: `c`'s oracle at steps `k0 + 54 + 18 * j` and `k0 + 55 + 18 * j` (`steps`: the head of round
`j` is at `k0 + 39 + 18 * j`, its latch 3 steps later). -/
def oN (c : Ctx) (k0 j : Nat) : Nat × Nat :=
  (c.oracle (Nat.pair (k0 + 54 + 18 * j) 0), c.oracle (Nat.pair (k0 + 55 + 18 * j) 0))

/-- **The loop's invariant** at the head of round `j`: the counter `%47` is `j` and the
accumulator `%48` is the scalar of `dotLoop` with `fmul contract` from `+0` over the first `j`
pairs of `ps`, under the oracle numbers `o`. -/
def Inv (o : Nat → Nat × Nat) (ps : List (Model FloatFormat.binary32 × Model FloatFormat.binary32))
    (j : Nat) (W : Valuation) : Prop :=
  W.regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 j)) ∧
    W.regs (idx "48") = some (.ofFloat .float (dotLoop true o (Model.zero _ false) (ps.take j)))

/-- **A round keeps the loop's invariant.** For every valuation `V`, list `ps` of factor pairs,
round `j < ps.length`, head valuation `W` of round `j` (context `V`'s, step count
`(head V).k + j * (pathLen naiveL.H naiveL.B + 1)`, which is `V.k + 39 + 18 * j` by `steps`) where
`Inv` holds under the oracle numbers `oN V.ctx V.k`, and predicate `G` on valuations: if the
round's premises hold (`RoundWith true`), `G` holds after it, the counter `%47` is `j + 1` after
it and the accumulator `%48` after it is the `fadd` (with `fmul contract`'s factors) of the
accumulator before it and the `fmul` of pair `j` of `ps`, under the oracle numbers of the latch's
statements 12 and 13 (`NaiveIn.round_in`'s conclusion), then the round's premises hold, `Inv`
holds at round `j + 1` after the round (`round W`), and `G` holds after it. Those oracle numbers
are `oN V.ctx V.k j` (`steps`); `floatBin_dotStep` gives the accumulator. -/
theorem round_inv {V : Valuation}
    {ps : List (Model FloatFormat.binary32 × Model FloatFormat.binary32)} {j : Nat}
    {W : Valuation} {G : Valuation → Prop} (hc : W.ctx = V.ctx)
    (hI : Inv (oN V.ctx V.k) ps j W) (hj : j < ps.length)
    (hk : W.k = (head V).k + j * (pathLen naiveL.H naiveL.B + 1))
    (hR : RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B W ∧ G (round W) ∧
      (round W).regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 (j + 1))) ∧
      ∃ x v, W.regs (idx "48") = some x ∧ (round W).regs (idx "48") = some v ∧
        (floatBin .float .fmul { contract := true } (.ofFloat .float ps[j].1)
            (.ofFloat .float ps[j].2) none none
            (W.ctx.oracle (Nat.pair ((latchAt W).k + 12) 0)) >>= fun p =>
          floatBin .float .fadd { contract := true } x p none
            (some (.ofFloat .float ps[j].1, .ofFloat .float ps[j].2))
            (W.ctx.oracle (Nat.pair ((latchAt W).k + 13) 0))) = .ok v) :
    RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B W ∧
      Inv (oN V.ctx V.k) ps (j + 1) (round W) ∧ G (round W) := by
  have app : ∀ (o : Nat → Nat × Nat) (a : Model FloatFormat.binary32)
      (qs : List (Model FloatFormat.binary32 × Model FloatFormat.binary32)) ab,
      dotLoop true o a (qs ++ [ab]) = dotStep true (dotLoop true o a qs) ab (o qs.length) := by
    intro o a qs ab
    induction qs generalizing o a with
    | nil => rfl
    | cons x qs ih => exact ih _ _
  obtain ⟨hr, hG, h47', x, v, hx, hv, hfb⟩ := hR
  obtain ⟨-, -, hk1, -, -, -, -, l3⟩ := steps V W 1
  rw [show pathLen naiveL.H naiveL.B + 1 = 18 by decide +kernel] at hk
  have n1 : W.ctx.oracle (Nat.pair ((latchAt W).k + 12) 0) = (oN V.ctx V.k j).1 := by
    rw [show (latchAt W).k + 12 = V.k + 54 + 18 * j by omega, hc]
    rfl
  have n2 : W.ctx.oracle (Nat.pair ((latchAt W).k + 13) 0) = (oN V.ctx V.k j).2 := by
    rw [show (latchAt W).k + 13 = V.k + 55 + 18 * j by omega, hc]
    rfl
  rw [hI.2] at hx
  cases hx
  rw [n1, n2] at hfb
  have e := floatBin_dotStep (t := .float) (fm := { contract := true }) rfl rfl rfl
    (dotLoop true (oN V.ctx V.k) (Model.zero _ false) (ps.take j)) ps[j].1 ps[j].2
    (oN V.ctx V.k j).1 (oN V.ctx V.k j).2
  have hd : dotLoop true (oN V.ctx V.k) (Model.zero _ false) (ps.take (j + 1)) =
      dotStep true (dotLoop true (oN V.ctx V.k) (Model.zero _ false) (ps.take j)) ps[j]
        (oN V.ctx V.k j) := by
    rw [List.take_succ_eq_append_getElem hj, app, List.length_take,
      Nat.min_eq_left (Nat.le_of_lt hj)]
  refine ⟨hr, ⟨h47', ?_⟩, hG⟩
  rw [hv, Except.ok.inj (hfb.symm.trans e)]
  exact congrArg (fun x => some (Val.ofFloat .float x)) hd.symm

/-- **The naive thread's run, for every thread of every launch, from premises.** For every
valuation `V` of `naive`'s function (a thread's entry valuation at the first block, position 0),
list `ps` of factor pairs (`ps.length` the trip count `K`), predicate `G` on the head's
valuations and predicate `Q` on memories: suppose

* `hE`: the entry block's obligations hold at `V` and its branch goes to `%45` (the thread is in
  bounds);
* `h0`: at the loop head after `%6 → %45` the invariant `Inv` holds at round 0 (the `phi`s set
  `%47 = 0` and `%48 = +0`), and `G`;
* `hR`: at every head valuation `W` of round `j < ps.length` (context `V`'s, step count
  `V.k + 39 + 18 * j`) where `Inv` and `G` hold, the premises of the round hold (`RoundWith
  true`), `G` holds after it, the counter is `j + 1` after it, and the accumulator after it is
  the `fadd` (with `fmul contract`'s factors) of the accumulator before it and the `fmul` of
  pair `j` of `ps`, under the oracle numbers of the latch's statements 12 and 13 (the loads of
  the latch read pair `j`: the address arithmetic; `%47 < %16` and `%16 = smax(K, 0)`: the
  bound);
* `hX`: at the head after `ps.length` rounds where `Inv` and `G` hold, the path out
  `%46 → %51 → %67 → %69` returns with a memory of `Q` (`RetWith true`).

Then the thread's sequence of loops `chainN` runs from `V` to `ret` with a memory of `Q`
(`RetLsWith true`), the per-thread premise of `Kernel.sound_cellsWith`
(MojoProof/Sym/Kernel.lean) for `chains = [chainN]`. The proof is `RetLsWith.of_inv`
(MojoProof/Sym/KernelMat.lean) with the invariant `Inv ∧ G` under the oracle numbers
`oN V.ctx V.k`, the edge `%45 → %46` from `SymNaive.pre_edge` and each round's `Inv` from
`round_inv`; the step counts are `steps`. It holds for every valuation, trip count and
predicates; the premises are what the checker does not decide. -/
theorem thread_run {V : Valuation} (hfn : V.fn = naive.fn_0)
    (ps : List (Model FloatFormat.binary32 × Model FloatFormat.binary32))
    {G : Valuation → Prop} {Q : Mem → Prop}
    (hE : (∀ d ∈ SymSelect.entry.obls, d.Holds V (vals V SymSelect.entry.nodes)) ∧
      SymSelect.entry.exit.dest V (vals V SymSelect.entry.nodes) = some naive.fn_0.b_2.label)
    (h0 : Inv (oN V.ctx V.k) ps 0 (head V) ∧ G (head V))
    (hR : ∀ j (hj : j < ps.length) W, W.ctx = V.ctx → W.k = V.k + 39 + 18 * j →
      Inv (oN V.ctx V.k) ps j W → G W →
      RoundWith true naiveL.h naiveL.p naiveL.dh naiveL.H naiveL.B W ∧ G (round W) ∧
      (round W).regs (idx "47") = some (.bits 64 (BitVec.ofNat 64 (j + 1))) ∧
      ∃ x v, W.regs (idx "48") = some x ∧ (round W).regs (idx "48") = some v ∧
        (floatBin .float .fmul { contract := true } (.ofFloat .float ps[j].1)
            (.ofFloat .float ps[j].2) none none
            (W.ctx.oracle (Nat.pair ((latchAt W).k + 12) 0)) >>= fun p =>
          floatBin .float .fadd { contract := true } x p none
            (some (.ofFloat .float ps[j].1, .ofFloat .float ps[j].2))
            (W.ctx.oracle (Nat.pair ((latchAt W).k + 13) 0))) = .ok v)
    (hX : ∀ W, W.ctx = V.ctx → W.k = V.k + 39 + 18 * ps.length →
      Inv (oN V.ctx V.k) ps ps.length W → G W →
      RetWith true W Q ((naiveL.h, naiveL.dh, naiveL.H) :: naiveL.X)) :
    ∃ C ∈ [chainN], RetLsWith true Q C.loops V C.l C.ds C.S C.E := by
  have hf' : (V.intoWith true naive.fn_0.b_0.label SymSelect.entry).fn = naive.fn_0 :=
    (Valuation.intoWith_k true V _ _).2.1.trans hfn
  obtain ⟨p1, p2, p3⟩ := pre_edge true _ hf'
  have hk : ∀ j (W : Valuation), W.k = (head V).k + j * (pathLen naiveL.H naiveL.B + 1) →
      W.k = V.k + 39 + 18 * j := fun j W h => by
    rw [h, (steps V V 0).2.2.1, show pathLen naiveL.H naiveL.B + 1 = 18 by decide +kernel]
    omega
  rw [hf'] at p3
  refine ⟨chainN, List.mem_singleton_self _, RetLsWith.of_inv rfl ps.length
    (fun j W => Inv (oN V.ctx V.k) ps j W ∧ G W) ⟨⟨hE.1, hE.2, p1⟩, p2, by rw [hfn]; exact p3⟩
    h0 (fun j hj W hc hk' ⟨hI, hG⟩ => round_inv hc hI hj hk' (hR j hj W hc (hk j W hk') hI hG))
    fun W hc hk' ⟨hI, hG⟩ => hX W hc (hk _ W hk') hI hG⟩

/-- The path of a thread out of bounds: the entry block `%6` (`SymSelect.entry`), whose branch
goes to `%44`, then `%44` (`skip`: `br label %69`) and `%69` (`ret void`, `Kernels.vadd.b3`). -/
def skipN : List (Nat × List Cond × Summary) :=
  [(naive.fn_0.b_0.label, SymSelect.entry.obls, SymSelect.entry),
    (naive.fn_0.b_1.label, skip.obls, skip),
    (naive.fn_0.b_8.label, Kernels.vadd.b3.obls, Kernels.vadd.b3)]

/-- The path checker with `fmul contract` accepts `skipN` from the first block's position 0
(`coversPathWith true`). -/
theorem skipN_covers : coversPathWith true naive.prog naive.fn_0 0 skipN = true := by
  decide +kernel

/-- **A thread out of bounds, for every thread of every launch, from premises.** For every
valuation `V` (a thread's entry valuation at the first block, position 0) and predicate `Q` on
memories: if the entry block's obligations hold at `V`, its branch goes to `%44` (the thread's
row or column is out of bounds), and `Q` holds of the memory that the entry block's effects give
(its three loads of the arguments' structs, which add trace entries), then the path `skipN` runs
from `V` to `ret` with a memory of `Q` (`RetWith true`): no store runs. With `thread_run`, each
thread of a launch has one of the two forms of the kernel theorem's per-thread premise with
`fmul contract`, for `paths = [skipN]` and `chains = [chainN]`. The proof is `RetWith.of_first`
(MojoProof/Sym/KernelMat.lean): `%44` and `%69` have no effects, so the memory at the return is
the entry block's. -/
theorem thread_skip {V : Valuation} {Q : Mem → Prop}
    (hE : (∀ d ∈ SymSelect.entry.obls, d.Holds V (vals V SymSelect.entry.nodes)) ∧
      SymSelect.entry.exit.dest V (vals V SymSelect.entry.nodes) = some naive.fn_0.b_1.label)
    (hQ : ∀ me, SEff.run V (vals V SymSelect.entry.nodes) SymSelect.entry.effs = .ok me → Q me) :
    RetWith true V Q skipN := by
  have ho : skip.obls = [.mem []] ∧ Kernels.vadd.b3.obls = [.mem []] := by decide +kernel
  have hm : ∀ (W : Valuation) (S : Summary) (ds : List Cond), ds = [.mem []] →
      ∀ d ∈ ds, d.Holds W (vals W S.nodes) := by
    rintro W S _ rfl d hd
    rw [List.mem_singleton] at hd
    subst hd
    exact ⟨_, rfl⟩
  exact RetWith.of_first (by decide +kernel)
    ⟨hE.1, hE.2, hm _ _ _ ho.1, by rw [skip_body_covers.2.1]; rfl, hm _ _ _ ho.2⟩ hQ

/-! ## One launch -/

/-- The bytes of the binary32 word of `x` in `naive`'s layout. -/
def word (x : Model FloatFormat.binary32) : List MemByte :=
  (naive.prog.layout.encode (.fp .float) (.ofFloat .float x)).getD []

/-- The caller's memory of the launch: block 1 (`C`, one float at address `0x10000`), block 2
(`A`, elements 0 and 1 of row 0 of `NaiveRun.aw` at `0x100`) and block 3 (`B`, elements 0 and 1
of row 0 of `NaiveRun.bw` at `0x200`), global, live, admitting every thread. -/
def memN : Mem :=
  let l := naive.prog.layout
  let m := (({} : Mem).alloc l 1 4 16 true false .all 0x10000 0x10000).1
  let m := (m.alloc l 1 8 16 true false .all 0x100 0x100
    (word (NaiveRun.aw 0 0) ++ word (NaiveRun.aw 0 1))).1
  (m.alloc l 1 8 16 true false .all 0x200 0x200
    (word (NaiveRun.bw 0 0) ++ word (NaiveRun.bw 0 1))).1

/-- A tensor argument of `naive`: the pointer to block `b` and the struct's other fields (no
value). -/
def tens (b : Nat) : Val :=
  .agg [.ptr ⟨b, 0⟩, .agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]]

/-- The launch's arguments: `C`, `A`, `B` (blocks 1, 2, 3), then the `i32`s `m = 1`, `n = 1` and
`K = 2`. -/
def argsN : List Val :=
  [tens 1, tens 2, tens 3, .bits 32 (BitVec.ofNat 32 1), .bits 32 (BitVec.ofNat 32 1),
    .bits 32 (BitVec.ofNat 32 2)]

/-- The oracle: 2 (fuse the `fadd`) at step 73 of every thread, lane 0, 0 elsewhere
(`NaiveRun.fuseAt`): thread 0's round 1 fuses (`oN`). -/
def ωN : Nat → Nat → Nat := NaiveRun.fuseAt (55 + 18)

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a start without this.
unseal Array.anyM.loop

/-- The start's grid and contexts on `launch2 1 1 2 2` (one block of 2 × 2 threads), `argsN` and
`memN` at the address choice 0 and `ωN` (the empty grid if it faults). -/
def runN : Grid × (Nat → Ctx) :=
  match Grid.start naive.prog naive.fn_0 (launch2 1 1 2 2) argsN memN (fun _ => 0) ωN with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => SymRun.ctx0)

/-- The start's grid. -/
def gN : Grid := runN.1

/-- The start's contexts. -/
def cN : Nat → Ctx := runN.2

/-- **The launch starts**, with grid `gN` and contexts `cN` (evaluated). -/
theorem startN :
    Grid.start naive.prog naive.fn_0 (launch2 1 1 2 2) argsN memN (fun _ => 0) ωN = .ok (gN, cN) :=
  rfl

/-- Thread `k`'s frame at the start. -/
def frN (k : Nat) : Frame :=
  ((Grid.thread gN k).frames.head?).getD ⟨naive.fn_0, 0, 0, fun _ => none, fun _ => none, [], none⟩

/-- Thread `k`'s entry valuation: context `cN k`, step count 0, the start's memory, frame
`frN k`. -/
def VN (k : Nat) : Valuation := Valuation.entry (cN k) 0 gN.mem (frN k)

/-- Thread 0's factor pairs: elements 0 and 1 of row 0 of `A` and of `B`. -/
def psN : List (Model FloatFormat.binary32 × Model FloatFormat.binary32) :=
  [(NaiveRun.aw 0 0, NaiveRun.bw 0 0), (NaiveRun.aw 0 1, NaiveRun.bw 0 1)]

/-- A register holds the binary32 scalar of `x` when its value reads as `x`: for every valuation,
register and float (`Val.float?_eq_some`); the premise is a closed `Option` equation that the
kernel decides on a concrete valuation. -/
theorem reg_of_float {W : Valuation} {r : Nat} {x : Model FloatTy.float.fmt}
    (h : (W.regs r).map (·.float? .float) = some (some x)) :
    W.regs r = some (.ofFloat .float x) := by
  cases hr : W.regs r with
  | none => rw [hr] at h; cases h
  | some v => rw [hr] at h; exact congrArg some (Val.float?_eq_some.1 (Option.some.inj h))

/-- A register holds the word `b` of `w` bits when its value is a word of `w` bits with `b`'s
number: for every valuation, register, width and word; the premise is a closed `Option Bool`
equation that the kernel decides on a concrete valuation. -/
theorem reg_of_bits {W : Valuation} {r w : Nat} {b : BitVec w}
    (h : (W.regs r).map (fun v => match v with
      | .bits w' b' => decide (w' = w) && decide (b'.toNat = b.toNat)
      | _ => false) = some true) :
    W.regs r = some (.bits w b) := by
  cases hr : W.regs r with
  | none => rw [hr] at h; cases h
  | some v =>
    rw [hr] at h
    cases v with
    | bits w' b' =>
      simp only [Option.map_some, Option.some.injEq, Bool.and_eq_true, decide_eq_true_eq] at h
      obtain ⟨rfl, h⟩ := h
      rw [BitVec.eq_of_toNat_eq h]
    | _ => cases h

/-- The head valuations of thread 0's rounds 0, 1 and 2. -/
def GN (W : Valuation) : Prop := ∃ j ≤ 2, W = round^[j] (head (VN 0))

/-- Cell `(0, 0)` of `C` holds `dotLoop` with `fmul contract` from `+0` over `psN` under the
oracle numbers `oN (cN 0) 0`. -/
def QN (me : Mem) : Prop :=
  me.load naive.prog.layout (cN 0).who 0 (.fp .float) ⟨1, 0⟩ (some 4) =
    .ok (.ofFloat .float (dotLoop true (oN (cN 0) 0) (Model.zero _ false) psN))

/-- **The premises of `thread_run` at thread 0 of the launch**, closed by evaluation: the
thread's run from `VN 0` through `chainN` to `ret` leaves cell `(0, 0)` of `QN`. -/
theorem thread0_chain : ∃ C ∈ [chainN], RetLsWith true QN C.loops (VN 0) C.l C.ds C.S C.E := by
  have hE : EdgeWith true naiveL.h naiveL.p (VN 0) naive.fn_0.b_0.label SymSelect.entry.obls
      SymSelect.entry [(naive.fn_0.b_2.label, pre.obls, pre)] := by
    decide +kernel
  have hfix : ∀ j W, W.k = (VN 0).k + 39 + 18 * j → GN W → W = round^[j] (head (VN 0)) ∧ j ≤ 2 := by
    intro j W hk ⟨j', hj', hW⟩
    subst hW
    obtain ⟨-, -, hk0, -, -, hkj, -⟩ := steps (VN 0) (head (VN 0)) j'
    obtain rfl : j' = j := by omega
    exact ⟨rfl, hj'⟩
  refine thread_run (G := GN) rfl psN ⟨hE.1.1, hE.1.2.1⟩
    ⟨⟨reg_of_bits (by decide +kernel), reg_of_float (by decide +kernel)⟩, 0, by omega, rfl⟩ ?_ ?_
  · intro j hj W _ hk hI hG
    obtain ⟨rfl, -⟩ := hfix j W hk hG
    have hj2 : j < 2 := hj
    refine ⟨?_, ⟨j + 1, hj2, (Function.iterate_succ_apply' _ _ _).symm⟩, ?_, _, _, hI.2,
      reg_of_float ?_, floatBin_dotStep rfl rfl rfl _ _ _ _ _⟩
    · rcases (by omega : j = 0 ∨ j = 1) with rfl | rfl <;> decide +kernel
    · exact reg_of_bits (by rcases (by omega : j = 0 ∨ j = 1) with rfl | rfl <;> decide +kernel)
    · rcases (by omega : j = 0 ∨ j = 1) with rfl | rfl <;> decide +kernel +revert
  · intro W _ hk _ hG
    obtain ⟨rfl, -⟩ := hfix 2 W hk hG
    refine ⟨by decide +kernel, by decide +kernel, ?_⟩
    have hb : (match SEff.run ((round^[2] (head (VN 0))).lastWith true naiveL.h naiveL.H naiveL.X).1
          (vals ((round^[2] (head (VN 0))).lastWith true naiveL.h naiveL.H naiveL.X).1
            ((round^[2] (head (VN 0))).lastWith true naiveL.h naiveL.H naiveL.X).2.2.nodes)
          ((round^[2] (head (VN 0))).lastWith true naiveL.h naiveL.H naiveL.X).2.2.effs with
        | .ok me =>
          match me.load naive.prog.layout (cN 0).who 0 (.fp .float) ⟨1, 0⟩ (some 4) with
          | .ok v => decide (v.float? .float =
              some (dotLoop true (oN (cN 0) 0) (Model.zero FloatTy.float.fmt false) psN))
          | .error _ => false
        | .error _ => false) = true := by
      decide +kernel
    split at hb
    next me hme =>
      refine ⟨me, hme, ?_⟩
      unfold QN
      split at hb
      next v hv => rw [hv]; exact congrArg Except.ok (Val.float?_eq_some.1 (of_decide_eq_true hb))
      next => exact absurd hb (by decide)
    next => exact absurd hb (by decide)

/-- **The whole naive thread at one launch** (a test of `thread_run`, `chainN_covers` and
`Runs.of_chainsWith true`): at the start `startN` of `naive` on one block of 2 × 2 threads with
`m = n = 1`, `K = 2`, `memN` and the oracle `ωN`, thread 0 (thread `(0, 0)`, in bounds) runs from
`Grid.start`'s entry frame `frN 0` to `ret` (`Runs`), and cell `(0, 0)` of `C` then holds `dotLoop`
with `fmul contract` from `+0` over the pairs `psN` under the oracle numbers `oN (cN 0) 0`, those
of steps 54 and 55 for round 0 (the oracle gives 0 and 0) and 72 and 73 for round 1 (0 and 2: the
`fadd` fuses), derived from the step count (`steps`): the binary32 word `0xa8800000`,
`-2 ^ -46` (`(1 + 2 ^ -23) (1 - 2 ^ -23) - 1` rounded once). For this program, launch, memory,
address choice and oracle only. -/
theorem thread0 :
    (∃ m', Runs (cN 0) (Grid.thread gN 0) gN.mem m' ∧ QN m') ∧
      oN (cN 0) 0 0 = ((cN 0).oracle (Nat.pair 54 0), (cN 0).oracle (Nat.pair 55 0)) ∧
      oN (cN 0) 0 0 = (0, 0) ∧ oN (cN 0) 0 1 = (0, 2) ∧
      (dotLoop true (oN (cN 0) 0) (Model.zero _ false) psN).toNatBits = 0xa8800000 := by
  refine ⟨Runs.of_chainsWith (Grid.start_ctx startN 0).1 chainN_covers rfl rfl
    (by decide +kernel) rfl rfl thread0_chain, rfl, by decide +kernel, by decide +kernel,
    by decide +kernel⟩

/-- **The twin: the invariant at the wrong oracle position fails.** At thread 0's head after its
two rounds, `Inv` holds under the oracle numbers `oN (cN 0) 0` of `steps`, and fails under
`oN (cN 0) 1`, the positions one step later (55 and 56 for round 0, 73 and 74 for round 1):
there round 1's `fadd` reads 0 and does not fuse, and `dotLoop` gives `+0`, not the register's
`-2 ^ -46`. -/
theorem thread0_twin : Inv (oN (cN 0) 0) psN 2 (round^[2] (head (VN 0))) ∧
    ¬ Inv (oN (cN 0) 1) psN 2 (round^[2] (head (VN 0))) ∧
    (dotLoop true (oN (cN 0) 1) (Model.zero _ false) psN).toNatBits = 0 := by
  refine ⟨⟨reg_of_bits (by decide +kernel), reg_of_float (by decide +kernel)⟩, fun ⟨_, h⟩ => ?_,
    by decide +kernel⟩
  have e := congrArg (Option.map fun v => (v.float? .float).map Model.toNatBits) h
  revert e
  decide +kernel

/-- **The threads out of bounds at the launch** (a test of `thread_skip`, `skipN_covers` and
`Runs.of_retWith`): at the start `startN`, threads 1, 2 and 3 (out of bounds, since
`m = n = 1`) run from `Grid.start`'s entry frames to their end (`Runs`), with the memory that
the entry block's three loads give, so they store nothing; thread 0's entry branch goes to
`%45`, not `%44`, so `thread_skip`'s premise fails there. With `thread0`, every thread of the
launch runs to its end. For this program, launch, memory, address choice and oracle only. -/
theorem skip_threads :
    (∀ k, 1 ≤ k → k < 4 → ∃ m', Runs (cN k) (Grid.thread gN k) gN.mem m' ∧
      SEff.run (VN k) (vals (VN k) SymSelect.entry.nodes) SymSelect.entry.effs = .ok m') ∧
    SymSelect.entry.exit.dest (VN 0) (vals (VN 0) SymSelect.entry.nodes) =
      some naive.fn_0.b_2.label := by
  refine ⟨fun k h1 h4 => ?_, by decide +kernel⟩
  obtain rfl | rfl | rfl : k = 1 ∨ k = 2 ∨ k = 3 := by omega
  · exact Runs.of_retWith (f := frN 1) (Grid.start_ctx startN 1).1 skipN_covers rfl rfl rfl rfl rfl
      (thread_skip (by decide +kernel) fun _ h => h)
  · exact Runs.of_retWith (f := frN 2) (Grid.start_ctx startN 2).1 skipN_covers rfl rfl rfl rfl rfl
      (thread_skip (by decide +kernel) fun _ h => h)
  · exact Runs.of_retWith (f := frN 3) (Grid.start_ctx startN 3).1 skipN_covers rfl rfl rfl rfl rfl
      (thread_skip (by decide +kernel) fun _ h => h)

end MojoProofTest.NaiveThread
