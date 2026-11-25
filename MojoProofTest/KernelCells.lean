import MojoProofTest.Kernel
import MojoProofTest.ScheduleOwned

/-!
# The kernel theorem with loops, at a launch of six threads with colliding cells

An instance of `Kernel.sound_cells` with every premise closed: the kernel `kc`, written here as a
hand-built `Func` (as `MojoProofTest/SymLoop.lean` writes `cnt`), whose threads each count `%i`
from 0 to `%n` in a loop and then, if `%tid.x < %n`, store `%i` to cell `%ctaid.x * %n + %tid.x`
of an `i32` array. On the launch `L23` (two blocks of three threads) with `%n = 2`, threads with
`%tid.x = 2` skip the store, and the cell of thread 2 (block 0, which skips) is the cell of thread 3
(block 1), so the cells are apart only on the storing threads (`apartC`, `not_apartC`): the case
`Kernel.sound_elem` excludes. The storing threads' cells are apart at every block size and row
length (`apart_blocks`; `apartC` and `apart_8_5` are its instances).

* `kernelProof` and the tactic kernel_check of this file: they close a goal by evaluation in the
  kernel with its local context reverted, so the goal may mention a memory the evaluation does
  not inspect.
* `kc`, `kcP`, its block summaries and the two sequences of loops `chains` (`chains_covers`).
* The launch: `outM`, `argsC`, `cellC`, `bsC`, the start `startC` (six threads, `sizeC`; one
  frame each, `framesC`, by `Grid.start_thread`) and the output block it keeps (`blkC`).
* `mem_eta`, `ret_storeWith` and `ret_of`: each thread's run on a memory of `Elem` and `Elem.Only`,
  symbolic but for its output block.
* `kernelC`: the kernel theorem. It covers this one program, launch, argument list, memory,
  address choice and oracle.
-/

namespace MojoProofTest.KernelCells

open Lean Meta Elab Tactic in
/-- The proof of proposition `p` that the kernel checks by evaluation: for a conjunction, the
pair of its sides' proofs; for an equation, `Eq.refl` of its left side (the kernel reduces both
sides to the same term); for another proposition, its `Decidable` instance reduced to `isTrue`
(`of_decide_eq_true`, as `decide` builds it). -/
partial def kernelProof (p : Expr) : MetaM Expr := do
  let p ← whnfR p
  match p.getAppFnArgs with
  | (``And, #[a, b]) => return mkApp4 (mkConst ``And.intro) a b (← kernelProof a) (← kernelProof b)
  | (``Eq, #[_, a, _]) => mkEqRefl a
  | _ => mkDecideProof p

open Lean Meta Elab Tactic in
/-- `kernel_check` closes the main goal by evaluation in the kernel alone (`kernelProof`): it
reverts the goal's local context, proves the closed statement for all values of the reverted
variables and hypotheses, and adds the proof as an auxiliary theorem that only the kernel checks
(`mkAuxLemma`, as `decide +kernel` does). The kernel must reduce the proof without inspecting
the reverted variables, so it succeeds when the evaluation does not depend on them. Unlike
`decide +kernel`, the goal may mention such variables, and its equations need no `DecidableEq`. -/
elab "kernel_check" : tactic => do
  let g ← getMainGoal
  let g ← g.cleanup
  let (xs, g) ← g.revert (clearAuxDeclsInsteadOfRevert := true) (← g.getDecl).lctx.getFVarIds
  g.withContext do
    let t ← instantiateMVars (← g.getType)
    if t.hasMVar then
      throwError "kernel_check: the goal has metavariables{indentExpr t}"
    let pf ← forallBoundedTelescope t (some xs.size) fun ys body => do
      mkLambdaFVars ys (← kernelProof body)
    let lvls := (← Term.getLevelNames).reverse.filter (collectLevelParams {} t).params.contains
    let n ← withOptions (Elab.async.set · false) <| mkAuxLemma lvls t pf
    g.assign (mkConst n (lvls.map .param))
  replaceMainGoal []

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.ScheduleOwned (tidName)
open MojoProofTest.Kernel (ch₀ ω₀ L23)

/-- The special register `%ctaid.x`'s intrinsic. -/
def ctaidName : String := "llvm.nvvm.read.ptx.sreg.ctaid.x"

/-- `declare i32 @name()`: the declaration of a special register's intrinsic. -/
def sreg (name : String) : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .int 32, name, params := [],
    group := none, names := #[], blocks := #[] }

/-- The kernel `@kc(i32 %n, ptr addrspace(1) %p)`: thread `(b, t)` (`%ctaid.x`, `%tid.x`) counts
`%i` from 0 to `%n` (`for i in [0, n)`), then, if `t < n` (`icmp ult`), stores `%i` (so `n`) to
cell `b * n + t` of the `i32` array at `%p`. Blocks: the entry `0`; the header `1`
(`%i = phi i32 [0, %0], [%i1, %2]`, `icmp slt %i, %n`); the body `2` (`%i1 = add nsw %i, 1`, the
back edge); the test `3`; the store `4`; the skip `5`. -/
def kc : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "kc",
    params := [⟨.int 32, [], some 6⟩, ⟨.ptr 1, [], some 7⟩], group := none,
    names := #["entry", "hdr", "body", "test", "st", "skip", "n", "p", "b", "t", "i", "c", "i1",
      "d", "r", "x", "q"],
    blocks := #[
      ⟨0, #[{ res := some 8, inst := .call {} (.int 32) (.fn ctaidName) [] },
        { res := some 9, inst := .call {} (.int 32) (.fn tidName) [] }], .br 1⟩,
      ⟨1, #[{ res := some 10, inst := .phi (.int 32) [(.int 0, 0), (.loc 12, 2)] },
        { res := some 11, inst := .icmp .slt (.int 32) (.loc 10) (.loc 6) }],
        .condBr (.loc 11) 2 3⟩,
      ⟨2, #[{ res := some 12, inst := .bin .add { nsw := true } (.int 32) (.loc 10) (.int 1) }],
        .br 1⟩,
      ⟨3, #[{ res := some 13, inst := .icmp .ult (.int 32) (.loc 9) (.loc 6) }],
        .condBr (.loc 13) 4 5⟩,
      ⟨4, #[{ res := some 14, inst := .bin .mul {} (.int 32) (.loc 8) (.loc 6) },
        { res := some 15, inst := .bin .add {} (.int 32) (.loc 14) (.loc 9) },
        { res := some 16,
          inst := .gep {} (.int 32) (.mk (.ptr 1) (.loc 7)) [.mk (.int 32) (.loc 15)] },
        { res := none,
          inst := .store false (.mk (.int 32) (.loc 10)) (.mk (.ptr 1) (.loc 16)) (some 4) }],
        .ret none⟩,
      ⟨5, #[], .ret none⟩] }

/-- The program of `kc` and the declarations of `%tid.x` and `%ctaid.x`, with the default data
layout. -/
def kcP : Program :=
  { module := { (default : Module) with funcs := #[kc, sreg tidName, sreg ctaidName] },
    sha256 := "", layout := {},
    intrinsics := [(tidName, .sreg .tid .x), (ctaidName, .sreg .ctaid .x)],
    kernels := ["kc"] }

/-- The entry block: the two special registers, then `br` to the header. -/
sym_summary kcE := kcP kc 0 0

/-- The header from position 1, after its `phi`. -/
sym_summary kcH := kcP kc 1 1

/-- The body. -/
sym_summary kcB := kcP kc 2 0

/-- The test `t < n`. -/
sym_summary kcT := kcP kc 3 0

/-- The store and `ret`. -/
sym_summary kcS := kcP kc 4 0

/-- The loop to the store: header `1` at position 1, loop path `1 → 2`, path out `1 → 3 → 4`. -/
def loopS : LoopSeg :=
  ⟨1, 1, kcH.obls, kcH, [(2, kcB.obls, kcB)], [(3, kcT.obls, kcT), (4, kcS.obls, kcS)], []⟩

/-- The loop to the skip: as `loopS` with path out `1 → 3 → 5` (block 5's summary, `ret void`
alone, is `Kernels.vadd.b3`). -/
def loopN : LoopSeg :=
  { loopS with X := [(3, kcT.obls, kcT), (5, Kernels.vadd.b3.obls, Kernels.vadd.b3)] }

/-- The sequence of loops from the entry block to the store: the loop `loopS`. -/
def chainS : LoopChain := ⟨0, kcE.obls, kcE, [], [loopS]⟩

/-- The sequence of loops from the entry block to the skip: the loop `loopN`. -/
def chainN : LoopChain := ⟨0, kcE.obls, kcE, [], [loopN]⟩

/-- The two sequences of loops from the entry block. -/
def chains : List LoopChain := [chainS, chainN]

/-- `coversChains` accepts both: they start at `kc`'s first block, and the path checker with
`phi`s accepts the entry block, the loop path and both paths out. -/
theorem chains_covers : coversChains kcP kc chains = true := by
  decide +kernel

/-! ## The launch -/

/-- The caller's memory: one global block of four `i32` cells (16 bytes, aligned to 4), and its
number. -/
def outM : Mem × Nat := ({} : Mem).alloc kcP.layout 1 16 4 true false .all 1 1

/-- The arguments: `%n = 2` and `%p` at offset 0 of `outM`'s block. -/
def argsC : List Val := [.bits 32 (BitVec.ofNat 32 2), .ptr ⟨outM.2, 0⟩]

/-- Thread `k`'s cell: offset `4 * (b * 2 + t)` for block `b = k / 3` and thread `t = k % 3` of
`L23` (two blocks of three threads), the cell `b * n + t` that `kc` stores to at `%n = 2`. -/
def cellC (k : Nat) : Nat := 4 * (k / 3 * 2 + k % 3)

/-- Thread `k`'s bytes: the `i32` 2 if it stores (`t = k % 3 < 2 = n`), none if it skips. -/
def bsC (k : Nat) : Option (List MemByte) :=
  if k % 3 < 2 then kcP.layout.encode (.int 32) (.bits 32 (BitVec.ofNat 32 2)) else none

/-- **The cells of the storing threads are apart, at every block size**: for every block size
`t`, bound `n` and width `w`, the cells `w * (k / t * n + k % t)` (block `k / t`, position
`k % t`, row length `n`) of the threads `k` with `k % t < n` are `w` bytes apart: two of them with
one cell have one block and one position, so are one thread. -/
theorem apart_blocks (t n w : Nat) :
    Apart (fun i : {i // i % t < n} => w * (i.1 / t * n + i.1 % t)) w := by
  rintro ⟨i, hi⟩ ⟨j, hj⟩ hij
  have hne : i / t * n + i % t ≠ j / t * n + j % t := by
    intro e
    have hq : i / t = j / t := by
      rcases Nat.lt_trichotomy (i / t) (j / t) with h | h | h
      · have := Nat.mul_le_mul_right n (Nat.succ_le_of_lt h)
        rw [Nat.succ_mul] at this
        omega
      · exact h
      · have := Nat.mul_le_mul_right n (Nat.succ_le_of_lt h)
        rw [Nat.succ_mul] at this
        omega
    have hr : i % t = j % t := by
      rw [hq] at e
      omega
    exact hij (Subtype.ext (show i = j from calc
      i = t * (i / t) + i % t := (Nat.div_add_mod i t).symm
      _ = t * (j / t) + j % t := by rw [hq, hr]
      _ = j := Nat.div_add_mod j t))
  rcases Nat.lt_or_gt_of_ne hne with h | h
  · left
    have := Nat.mul_le_mul_left w (Nat.succ_le_of_lt h)
    rwa [Nat.mul_succ] at this
  · right
    have := Nat.mul_le_mul_left w (Nat.succ_le_of_lt h)
    rwa [Nat.mul_succ] at this

/-- The cells of the storing threads (`k % 3 < 2`) are 4 bytes apart: `apart_blocks` at blocks of
3 threads, rows of 2 and width 4. -/
theorem apartC : Apart (fun i : {i // i % 3 < 2} => cellC i) 4 :=
  apart_blocks 3 2 4

/-- `apart_blocks` at blocks of 8 threads, rows of 5 and width 8: a test at a second size. -/
theorem apart_8_5 : Apart (fun i : {i // i % 8 < 5} => 8 * (i.1 / 8 * 5 + i.1 % 8)) 8 :=
  apart_blocks 8 5 8

/-- **The twin of the restricted cells**: the cells of all threads are not apart, since thread 2
(block 0, `t = 2`, which skips) and thread 3 (block 1, `t = 0`) have cell 8, so
`Kernel.sound_elem`'s premise `Apart cell w` fails here. -/
theorem not_apartC : ¬ Apart cellC 4 := fun h => absurd (h 2 3 (by decide)) (by decide)

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The start's grid and contexts on `L23`, `argsC` and `outM` at `ch₀` and `ω₀` (the empty grid
if it faults). -/
def runC : Grid × (Nat → Ctx) :=
  match Grid.start kcP kc L23 argsC outM.1 ch₀ ω₀ with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => SymRun.ctx0)

/-- The start's grid. -/
def gC : Grid := runC.1

/-- The start's contexts. -/
def cC : Nat → Ctx := runC.2

/-- **The launch starts**, with grid `gC` and contexts `cC` (evaluated). -/
theorem startC : Grid.start kcP kc L23 argsC outM.1 ch₀ ω₀ = .ok (gC, cC) := rfl

/-- The start has six threads. -/
theorem sizeC : gC.threads.size = 6 := by decide +kernel

/-- The frame of thread `k` of the start (a frame of `kc` with no register if it has none). -/
def frC (k : Nat) : Frame :=
  ((Grid.thread gC k).frames.head?).getD ⟨kc, 0, 0, fun _ => none, fun _ => none, [], none⟩

/-- Each thread of the start has the one frame `frC k`: an instance of `Grid.start_thread` (every
start's thread has one frame) at `startC`. -/
theorem framesC : ∀ k < 6, (Grid.thread gC k).frames = [frC k] := fun k hk =>
  have ⟨_, e, _⟩ := Grid.start_thread startC (sizeC ▸ hk); by simp [frC, e]

/-- The start keeps the caller's output block (`Grid.start_blocks`). -/
theorem blkC : gC.mem.blocks outM.2 = outM.1.blocks outM.2 := Grid.start_blocks startC rfl

/-- `outM` has no pointer byte. -/
theorem outM_bytesIn : outM.1.BytesIn outM.1.Known :=
  Mem.alloc_bytesIn (fun _ _ _ _ _ h => by cases h) (init := []) (fun _ _ h => by cases h)
    _ _ _ _ _ _ _ _ _ _

/-! ## Per-thread runs by evaluation on a symbolic memory -/

/-- A memory is itself with block `b` replaced by its value `x`: for every memory, block number
and value. With `x` closed, evaluation reads block `b` of the right side without inspecting
`m`. -/
theorem mem_eta {m : Mem} {b : Nat} {x : Option Sem.Block} (h : m.blocks b = x) :
    m = { m with blocks := fun b' => if b' = b then x else m.blocks b' } := by
  cases m
  congr 1
  funext b'
  split <;> simp_all

/-- A path whose last block's one effect is a store of thread `k` to its cell ends in `Elem`
after `k + 1` threads and `Elem.Only`, with or without `fmul contract`: for every flag
`contract`, memory `m` of `Elem` after `k` threads and `Elem.Only out T`, valuation `W` and path
`(l, ds, S) :: ps`, if the path's premises hold (`WalkWith contract`), its last exit is `ret`, its
last valuation (`Valuation.lastWith contract`) has memory `m`, its last effects are the one store
at `(lbl, pc)` of value `v` to pointer `p`, that store succeeds, the statement there stores a
value of type `t`, the thread is `k`, `v` is `x` with bytes `bs k`, `p` is `k`'s cell, `t` fills
at most `w` bytes and `k` is in `T`, then the path is a `RetWith contract` to such a memory
(`Elem.apply_store`, `Elem.Only.apply`). -/
theorem ret_storeWith {contract : Bool} {m₀ : Mem} {out w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {k : Nat} {T : Nat → Prop} {m : Mem}
    (hE : Elem m₀ out w cell bs k m) (hO : Elem.Only out T m) {W : Valuation} {l : Nat}
    {ds : List Cond} {S : Summary} {ps : List (Nat × List Cond × Summary)} {lbl pc : Nat}
    {v p : SVal} {x : Val} {r : Option Nat} {vol : Bool} {t : Ty} {tv : Value} {a : Nat}
    {pv : Value} {al : Option Nat} {md : List (String × Nat)}
    (H : WalkWith contract W ((l, ds, S) :: ps) ∧ (W.lastWith contract l S ps).2.2.exit = .ret ∧
      (W.lastWith contract l S ps).1.mem = m ∧
      (W.lastWith contract l S ps).2.2.effs = [.store lbl pc v p] ∧
      (SEff.apply (W.lastWith contract l S ps).1
        (vals (W.lastWith contract l S ps).1 (W.lastWith contract l S ps).2.2.nodes) m
        (.store lbl pc v p)).isOk = true ∧
      (W.lastWith contract l S ps).1.stmt lbl pc =
        some ⟨r, .store vol ⟨t, tv⟩ ⟨.ptr a, pv⟩ al, md⟩ ∧
      (W.lastWith contract l S ps).1.ctx.who.thread = k ∧
      v.eval (W.lastWith contract l S ps).1
        (vals (W.lastWith contract l S ps).1 (W.lastWith contract l S ps).2.2.nodes) = .ok x ∧
      p.eval (W.lastWith contract l S ps).1
        (vals (W.lastWith contract l S ps).1 (W.lastWith contract l S ps).2.2.nodes) =
        .ok (.ptr ⟨out, cell k⟩) ∧
      (W.lastWith contract l S ps).1.ctx.prog.layout.encode t x = bs k ∧
      (W.lastWith contract l S ps).1.ctx.prog.layout.stored t ≤ w ∧ T k) :
    RetWith contract W (fun me => Elem m₀ out w cell bs (k + 1) me ∧ Elem.Only out T me)
      ((l, ds, S) :: ps) := by
  obtain ⟨hw, hx, hm, he, hok, hs, hk, hv, hp, hen, hl, hT⟩ := H
  subst hm
  cases ha : SEff.apply (W.lastWith contract l S ps).1
      (vals (W.lastWith contract l S ps).1 (W.lastWith contract l S ps).2.2.nodes)
      (W.lastWith contract l S ps).1.mem (.store lbl pc v p) with
  | error => rw [ha] at hok; cases hok
  | ok me =>
    refine ⟨hw, hx, me, ?_, hE.apply_store ha hs hk hv hp hen hl,
      hO.apply (by rw [hk]; exact hT) ha⟩
    rw [SEff.run, he, List.foldlM_cons, ha]
    rfl

/-- A path to `ret` whose effects leave memory `m` of `Q` is a `Ret` to `Q`: for every valuation,
predicate, path and memory, from the path's premises (`WalkWith false`), its last exit `ret` and
its last effects' run to `m` (`Ret`'s fields with the memory given). -/
theorem ret_of {W : Valuation} {Q : Mem → Prop} {l : Nat} {ds : List Cond} {S : Summary}
    {ps : List (Nat × List Cond × Summary)} {m : Mem} (hQ : Q m)
    (H : WalkWith false W ((l, ds, S) :: ps) ∧ (W.lastWith false l S ps).2.2.exit = .ret ∧
      SEff.run (W.lastWith false l S ps).1
        (vals (W.lastWith false l S ps).1 (W.lastWith false l S ps).2.2.nodes)
        (W.lastWith false l S ps).2.2.effs = .ok m) :
    Ret W Q ((l, ds, S) :: ps) :=
  ⟨H.1, H.2.1, m, H.2.2, hQ⟩

/-! ## The kernel theorem -/

/-- **The kernel theorem for a kernel whose threads each run a counted loop and then store one
cell, at a launch of six threads** (`Kernel.sound_cells`, every premise closed). `kc` on `L23`
(two blocks of three threads) with `%n = 2` and `%p` at offset 0 of `outM`'s block, at the
admission of `ch₀` and `ω₀` alone, is sound (`Kernel.Sound`) for the observation of the blocks and
`Elem.Out`: `outM`'s block ends with the bytes `bsC k` (the `i32` 2 for the threads with
`k % 3 < 2`, nothing for the others) put in turn at cells `cellC k`. The cells are apart only on
the storing threads (`apartC`; thread 2, which skips, shares thread 3's cell: `not_apartC`). Each
thread's run (two rounds of the loop, then the store or the skip) is proved for every memory of
`Elem` and `Elem.Only` by evaluation in the kernel with that memory symbolic but its output block
(`mem_eta`, `kernel_check`). It covers this one program, launch, argument list, memory, address
choice and oracle. -/
theorem kernelC : Kernel.Sound kcP kc L23 argsC outM.1 (fun ch o => ch = ch₀ ∧ o = ω₀)
    (fun m => some m.blocks)
    (Elem.Out outM.1 outM.2 cellC bsC (volume L23.grid * volume L23.block)) := by
  refine Kernel.sound_cells (paths := []) (chains := chains) (S := fun k => k % 3 < 2) rfl
    chains_covers outM_bytesIn (by rintro _ _ ⟨rfl, rfl⟩; exact ⟨_, _, startC⟩) apartC ?_
  rintro _ _ g c ⟨rfl, rfl⟩ h
  rw [startC] at h
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj h)
  intro k hk m' f hE hO hf
  rw [sizeC] at hk
  obtain ⟨rfl, -⟩ := List.cons.inj (hf.symm.trans (framesC k hk))
  have hc := hE.cells.trans (congrArg (Option.map _) blkC)
  rw [mem_eta hc] at hE hO ⊢
  refine .inr ?_
  by_cases hS : k % 3 < 2
  · refine ⟨chainS, by simp [chains], ?_⟩
    interval_cases k <;> first
      | omega
      | exact ChainWith.of_rounds (contract := false) (by rfl) 2 (by kernel_check)
          (ChainWith.last (ret_storeWith
          (contract := false) (lbl := 4) (pc := 3) (v := .reg 10) (p := .node 2)
          (x := .bits 32 (BitVec.ofNat 32 2)) (r := none) (vol := false) (t := .int 32)
          (tv := .loc 10) (a := 1) (pv := .loc 16) (al := some 4) (md := []) hE hO
          (by kernel_check)))
  · refine ⟨chainN, by simp [chains], ?_⟩
    interval_cases k <;> first
      | omega
      | exact ChainWith.of_rounds (contract := false) (by rfl) 2 (by kernel_check)
          (ChainWith.last (ret_of ⟨hE.skip rfl, hO⟩ (by kernel_check)))

end MojoProofTest.KernelCells
