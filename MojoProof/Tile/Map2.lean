import MojoProof.Tile.Basic
import MojoProof.Sym.Kernel
import MojoProof.Sym.LoopFacts

/-!
# The element-wise tile program and the kernels of `mojo_kernel`'s `map2` clause

This module relates the tile program of a binary float map to every kernel whose theorem is the
conclusion of `Kernel.sound_map2`. It defines:

* `map2 op n`: thread `k < n` loads cell `k` of buffers 0 and 1, asks for the float choice at
  the site (`k`, `k`, `op`, 0), and stores the IEEE operation `fbin op` of the two values,
  delivered at the choice's number divided by 3 (`deliver`, as the LLVM semantics decodes an
  oracle number), in cell `k` of buffer 2; the other threads do nothing;
* `inputs x y`: the state whose buffers 0 and 1 hold the tensors `x` and `y`;
* `opSteps`, `siteStep?`, `oracle`: the steps, counted from the thread's entry, at which a
  path's blocks run a float operation (from `pathOff` and the node's offset), the one step of an
  operation that every path which has it agrees on (`none` if there is none or they differ),
  and the tile oracle that a kernel's oracle `ω` gives through that step (`ω` at the site's
  thread and that step).

It proves:

* `map2_run`: for every float format, operation with an IEEE operation, count `n` at most the
  tensors' length, tensors, tile oracle and number `T` of threads, `map2 op n` runs from
  `inputs x y` without a fault, leaves buffers 0 and 1 as they were, and holds at cell `k` of
  buffer 2, for every `k < n`, `k < T`, the operation on cell `k` of `x` and of `y` delivered at
  the site's number divided by 3;
* `map2_refines`: for every program, kernel, launch, arguments, memory, admission, layout, float
  type, operation, tensors, count, number of threads and path list whose computed step for the
  operation (`siteStep?`) is the step `s` of the kernel's theorem, `Kernel.Sound` for
  `Elem.Out` with `Elem.map2`'s bytes at the oracle numbers of step `s` gives that every
  observation of a complete run (`Kernel.Obs`) at an admitted choice and oracle `ω` holds at the
  output cell of every thread `k < n`, `k < T` the value of cell `k` of buffer 2 of the run of
  `map2 op n` from `inputs x y` at tile oracle `oracle paths ω`. It covers every kernel of the
  clause.
-/

namespace MojoProof.Tile

open MojoProof.Sem MojoProof.Sym FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange

/-- **The element-wise program of a binary float operation** `op` for count `n`, thread `k`: if
`k < n` and `op` has an IEEE operation `f` (`fbin`), load cell `k` of buffers 0 and 1 (`a`,
`b`), ask for the choice `j` at site (`k`, `k`, `op`, 0) and store `deliver (f a b) (j / 3)` in
cell `k` of buffer 2; if `op` has none, `ub`; if `k ≥ n`, nothing. -/
def map2 {fmt : FloatFormat} (op : LLVM.FBinOp) (n k : Nat) : Prog (TileE (Model fmt)) Unit :=
  if k < n then
    match fbin op with
    | some f =>
      .vis (.load 0 k) fun a => .vis (.load 1 k) fun b => .vis (.choose ⟨k, k, op, 0⟩) fun j =>
        .vis (.store 2 k (deliver (f a b) (j / 3))) fun _ => .ret ()
    | none => .vis (.ub "a float operation with no IEEE operation") Empty.elim
  else .ret ()

/-- The state whose buffer 0 holds the tensor `x` and buffer 1 the tensor `y` at cells `0` to
`N - 1`, with no other cell set, an empty log and phase 0. -/
def inputs {fmt : FloatFormat} {N : Nat} (x y : TorchLean.Tensor (Model fmt) [N]) :
    St (Model fmt) where
  cells b c :=
    if h : c < N then
      if b = 0 then some (x (⟨c, h⟩, PUnit.unit))
      else if b = 1 then some (y (⟨c, h⟩, PUnit.unit)) else none
    else none
  log := []
  phase := 0

/-- **`map2 op n` runs and stores the delivered results.** For every float format, operation
`op` with IEEE operation `f` (`fbin op = some f`), count `n ≤ N`, tensors `x` and `y` of length
`N`, tile oracle `q` and number `T`: the run of threads `0` to `T - 1` from `inputs x y` ends in
a state `s` without a fault, whose cells outside buffer 2 are those of `inputs x y`, and whose
cell `k` of buffer 2 is `deliver (f x_k y_k) (q ⟨k, k, op, 0⟩ / 3)` for every `k < n`,
`k < T`. -/
theorem map2_run {fmt : FloatFormat} {op : LLVM.FBinOp} {f : Model fmt → Model fmt → Model fmt}
    (hf : fbin op = some f) {N n : Nat} (hn : n ≤ N) (x y : TorchLean.Tensor (Model fmt) [N])
    (q : Site → Nat) (T : Nat) :
    ∃ s, runAll q (map2 op n) T (inputs x y) = .ok s ∧
      (∀ b c, b ≠ 2 → s.cells b c = (inputs x y).cells b c) ∧
      ∀ k (hk : k < n), k < T → s.cells 2 k =
        some (deliver (f (x (⟨k, by omega⟩, PUnit.unit)) (y (⟨k, by omega⟩, PUnit.unit)))
          (q ⟨k, k, op, 0⟩ / 3)) := by
  induction T with
  | zero => exact ⟨_, rfl, fun _ _ _ => rfl, fun _ _ h => absurd h (Nat.not_lt_zero _)⟩
  | succ T ih =>
    obtain ⟨s, hs, h01, h2⟩ := ih
    by_cases hT : T < n
    · have hTN : T < N := by omega
      have ha : s.cells 0 T = some (x (⟨T, hTN⟩, PUnit.unit)) := by
        rw [h01 0 T (by decide)]
        simp [inputs, hTN]
      have hb : s.cells 1 T = some (y (⟨T, hTN⟩, PUnit.unit)) := by
        rw [h01 1 T (by decide)]
        simp [inputs, hTN]
      obtain ⟨s', h1, hc⟩ : ∃ s', run1 q T (map2 op n T) s = .ok ((), s') ∧ ∀ b c,
          s'.cells b c = if b = 2 ∧ c = T then
            some (deliver (f (x (⟨T, hTN⟩, PUnit.unit)) (y (⟨T, hTN⟩, PUnit.unit)))
              (q ⟨T, T, op, 0⟩ / 3))
          else s.cells b c := by
        unfold map2
        rw [ite_eq_left hT, hf]
        simp only [run1, ha, hb]
        exact ⟨_, rfl, fun _ _ => rfl⟩
      refine ⟨s', ?_, fun b c hb => ?_, fun k hk hkT => ?_⟩
      · simp only [runAll, hs, h1]
        rfl
      · rw [hc, ite_eq_right fun h => hb h.1]
        exact h01 b c hb
      · rw [hc]
        by_cases hkT' : k = T
        · subst hkT'
          rw [ite_eq_left ⟨rfl, rfl⟩]
        · rw [ite_eq_right fun h => hkT' h.2]
          exact h2 k hk (by omega)
    · refine ⟨s, ?_, h01, fun k hk hkT => h2 k hk (by omega)⟩
      simp only [runAll, hs]
      unfold map2
      rw [ite_eq_right hT]
      rfl

/-- The steps, counted from the thread's entry, at which the blocks of the path `ps` run the
float operation `op`: for block `i` of the path (`S` the first block's summary) and every node
of its summary that is an `op` (`SNode.fbin` or `SNode.fbinP`) `n` steps after the block's
entry, the step `pathOff S ps i + n` (the path being
`(_, _, S) :: ps`); in the order of the blocks and nodes. -/
def opSteps (op : LLVM.FBinOp) : List (Nat × List Cond × Summary) → List Nat
  | [] => []
  | (_, _, S) :: ps => (S :: ps.map (·.2.2)).zipIdx.flatMap fun (B, i) =>
    B.nodes.filterMap fun
      | .fbin o _ _ n _ _ | .fbinP o _ _ n _ _ _ _ =>
        if o = op then some (pathOff S ps i + n) else none
      | _ => none

/-- The step of the float operation `op` on the paths `paths`: `some s` if the paths run `op`
(`opSteps`) and every step at which they do is `s`, else `none`. -/
def siteStep? (paths : List (List (Nat × List Cond × Summary))) (op : LLVM.FBinOp) : Option Nat :=
  match paths.flatMap (opSteps op) with
  | s :: ss => if ss.all (· == s) then some s else none
  | [] => none

/-- The tile oracle a kernel's oracle `ω` gives on the paths `paths`: at a site, the kernel's
oracle number for the site's thread at the step `s` of the site's operation,
`ω thread (Nat.pair s 0)` (`siteStep?`, 0 if none); the site's cell and term do not enter. -/
def oracle (paths : List (List (Nat × List Cond × Summary))) (ω : Nat → Nat → Nat) (s : Site) :
    Nat :=
  ω s.thread (Nat.pair ((siteStep? paths s.op).getD 0) 0)

/-- **A kernel of the `map2` clause refines the element-wise tile program.** For every program,
kernel, launch, arguments, memory `m` with a block `out`, admission, cells `cell` that are
`l.stored (.fp ft)` bytes apart, layout `l`, float type `ft`, operation `op` with IEEE operation
`f`, count `n ≤ N`, tensors `x` and `y`, number `T`, oracle `ω` and paths whose computed step
of `op` is `s` (`siteStep? paths op = some s`): if the kernel is sound (`Kernel.Sound`) for
`Elem.Out` after `T` threads with the bytes `Elem.map2` of `f` at the oracle numbers
`ω k (Nat.pair s 0) / 3` (the conclusion of `Kernel.sound_map2`), then for every admitted
address choice at `ω` and every observation `B` of a complete run (`Kernel.Obs`), the run of
`map2 op n` from `inputs x y` at the tile oracle `oracle paths ω` ends without a fault in a
state whose cell `k` of buffer 2 is the float at thread `k`'s output cell of `B`, for every
`k < n`, `k < T`. It covers every kernel with such a theorem. -/
theorem map2_refines {prog : LLVM.Program} {fn : LLVM.Func} {L : Launch} {args : List Val}
    {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {out : Nat} {cell : Nat → Nat}
    {l : Layout} {ft : LLVM.FloatTy} {op : LLVM.FBinOp}
    {f : Model ft.fmt → Model ft.fmt → Model ft.fmt} {N : Nat}
    {x y : TorchLean.Tensor (Model ft.fmt) [N]} {n T s : Nat}
    {paths : List (List (Nat × List Cond × Summary))} {ω : Nat → Nat → Nat}
    (h : Kernel.Sound prog fn L args m adm (fun m => some m.blocks)
      (Elem.Out m out cell (Elem.map2 l ft f (fun k => ω k (Nat.pair s 0) / 3) x y n) T))
    (hf : fbin op = some f) (hs : siteStep? paths op = some s)
    (hb : ∃ blk, m.blocks out = some blk) (hap : Apart cell (l.stored (.fp ft))) (hn : n ≤ N)
    {ch : Nat → Nat} (ha : adm ch ω) {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs prog fn L args m (fun m => some m.blocks) ch ω B) :
    ∃ st, runAll (oracle paths ω) (map2 op n) T (inputs x y) = .ok st ∧
      ∀ k, k < n → k < T → Elem.word l ft out cell B k = st.cells 2 k := by
  obtain ⟨st, hr, -, h2⟩ := map2_run hf hn x y (oracle paths ω) T
  refine ⟨st, hr, fun k hk hkT => ?_⟩
  rw [(Kernel.Sound.obs h ha hB).map2_word hb hap hk (by omega) hkT, h2 k hk hkT]
  simp only [oracle, hs, Option.getD_some]

end MojoProof.Tile
