import MojoProofTest.SymRun
import MojoProofTest.Confluence
import MojoProof.Kernels.Vadd
import MojoProof.Sym.Sched

/-!
# The sequential schedule on a concrete grid of two `vector_addition` threads

An instance of `Seq.done` (MojoProof/Sym/Sched.lean), whose runs come from `Block.sound_retWith`
on the path `%4 → %21 → %31` with the summaries `Kernels.vadd.b0`, then `vaddIn`'s (accepted by
`vadd_paths`, MojoProofTest/Sym.lean). The launch `Confluence.two`
(MojoProofTest/Confluence.lean) is one block of two threads; thread `i`'s context `ctx2 i` is
`ctx0` (MojoProofTest/SymRun.lean) with the special registers `Launch.env` gives thread `i`. The
grid `grid2` has both threads at the kernel's entry with element count 2 (`frame4 2`) on memory
`mem4`.

* `vadd2_grid`: thread 0 runs the path `%4 → %21 → %31` to its end from `mem4`, then thread 1 from
  the memory thread 0 left; by `Seq.done` the grid steps from `grid2` to a done grid (the core's
  `Done` at `sig`), and cells 0 and 1 of the output there hold the FloatLib sums of cells 0 and 1 of
  the inputs. Thread 1's path premises (`WalkWith false`) are decided on the memory thread 0's
  effects leave, by the kernel's evaluation of those effects.
* `vadd2_grid_twin`: with thread 0 alone (`ns = [0]`, which does not name thread 1), the grid
  `Seq.grid` reaches is not done, whatever its memory: the premise of `Seq.done` that `ns` names
  every thread is needed.

Each result covers the grid named, not all programs.
-/

namespace MojoProofTest.SymSched

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.Sym MojoProofTest.SymRun
open GPUProof
open FloatLib.Floats.Formats.BinaryInterchange

/-- The context of thread number `i` of `Confluence.two` (one block of two threads,
MojoProofTest/Confluence.lean): `ctx0` with the special registers that `Launch.env` gives thread
`i`, named as thread `i` of block `i / 2`. -/
def ctx2 (i : Nat) : Ctx :=
  { ctx0 with env := Confluence.two.env i, who := ⟨i, i / 2⟩ }

/-- The grid: threads 0 and 1 at the kernel's entry with element count 2, on memory `mem4`. -/
def grid2 : Grid := ⟨#[.run ⟨[frame4 2], 0⟩, .run ⟨[frame4 2], 0⟩], mem4⟩

/-- Cells 0 and 1 of the output (block 3) in memory `m` hold the FloatLib sums `Model.add` of
cells 0 and 1 of the inputs. -/
def sums2 (m : Mem) : Bool := (List.range 2).all fun i =>
  match m.load Kernels.vadd.prog.layout ⟨0, 0⟩ 0 (.fp .float) ⟨3, 4 * i⟩ (some 4) with
  | .ok v => decide (v.float? .float = some (Model.add (Model.ofNatBits (inA.getD i 0))
      (Model.ofNatBits (inB.getD i 0))))
  | .error _ => false

/-- **Two threads in turn reach a done grid.** From `grid2`, threads 0 and 1 of `Confluence.two`
run in turn, each alone to its `ret` (`Seq.done` with `Block.sound_retWith`): the grid steps to a
done grid, whose output cells 0 and 1 hold the sums of the inputs' cells 0 and 1. -/
theorem vadd2_grid : ∃ z, (∃ k, Path (Grid.Step Confluence.two ctx2) k grid2 z) ∧
    GPUProof.Done sig (z, Confluence.two, ctx2) ∧
    sums2 z.mem = true := by
  have e₀ (V : Valuation) : V.intoWith false Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 =
      V.after Kernels.vadd.b0 := rfl
  have e₁ (V : Valuation) : V.intoWith false Kernels.vadd.fn_0.b_1.label Kernels.vadd.b1 =
      V.after Kernels.vadd.b1 := rfl
  have hc :
      (match SEff.run ((Valuation.entry (ctx2 0) 0 mem4 (frame4 2)).lastWith false
            Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).1
          (vals ((Valuation.entry (ctx2 0) 0 mem4 (frame4 2)).lastWith false
            Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).1
            ((Valuation.entry (ctx2 0) 0 mem4 (frame4 2)).lastWith false
              Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).2.2.nodes)
          ((Valuation.entry (ctx2 0) 0 mem4 (frame4 2)).lastWith false
            Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).2.2.effs with
        | .ok me =>
          decide (WalkWith false (Valuation.entry (ctx2 1) 0 me (frame4 2))
            ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddIn)) &&
          match SEff.run ((Valuation.entry (ctx2 1) 0 me (frame4 2)).lastWith false
                Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).1
              (vals ((Valuation.entry (ctx2 1) 0 me (frame4 2)).lastWith false
                Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).1
                ((Valuation.entry (ctx2 1) 0 me (frame4 2)).lastWith false
                  Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).2.2.nodes)
              ((Valuation.entry (ctx2 1) 0 me (frame4 2)).lastWith false
                Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).2.2.effs with
            | .ok me' => sums2 me'
            | .error _ => false
        | .error _ => false) = true := by
    simp only [sums2, WalkWith, Valuation.lastWith, vaddIn, e₀, e₁, Valuation.after, vals,
      SNode.eval.eq_def, Mem.load, Layout.decode.eq_def]
    iterate 6 (unfold Layout.decodeFields Layout.decode)
    decide +kernel
  have hw : WalkWith false (Valuation.entry (ctx2 0) 0 mem4 (frame4 2))
      ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddIn) := by
    simp only [WalkWith, vaddIn, e₀, e₁, Valuation.after, vals, SNode.eval.eq_def, Mem.load,
      Layout.decode.eq_def]
    iterate 6 (unfold Layout.decodeFields Layout.decode)
    decide +kernel
  obtain ⟨_, me₀, hS₀, hm₀, hst₀⟩ := Block.sound_retWith (c := ctx2 0) (t := ⟨[frame4 2], 0⟩)
    (m := mem4) (f := frame4 2) (S := Kernels.vadd.b0) (ds := Kernels.vadd.b0.obls) (ps := vaddIn)
    rfl vadd_paths.1 rfl rfl rfl rfl hw rfl rfl
  rw [Valuation.allocsWith_nil _ vadd_paths.1, List.nil_append] at hst₀
  erw [hm₀] at hc
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
  obtain ⟨hw₁, hc⟩ := hc
  obtain ⟨_, me₁, hS₁, hm₁, hst₁⟩ := Block.sound_retWith (c := ctx2 1) (t := ⟨[frame4 2], 0⟩)
    (m := me₀) (f := frame4 2) (S := Kernels.vadd.b0) (ds := Kernels.vadd.b0.obls) (ps := vaddIn)
    rfl vadd_paths.1 rfl rfl rfl rfl hw₁ rfl rfl
  rw [Valuation.allocsWith_nil _ vadd_paths.1, List.nil_append] at hst₁
  erw [hm₁] at hc
  have r₀ : Runs (ctx2 0) ⟨[frame4 2], 0⟩ mem4 me₀ := ⟨_, _, hS₀, hst₀⟩
  have r₁ : Runs (ctx2 1) ⟨[frame4 2], 0⟩ me₀ me₁ := ⟨_, _, hS₁, hst₁⟩
  obtain ⟨E₀, e₀⟩ := r₀.trace
  obtain ⟨E₁, e₁⟩ := r₁.trace
  obtain ⟨z, hp, hd, hz, -⟩ := Seq.done (L := Confluence.two) (g := grid2)
    (.cons r₀ e₀ (.cons r₁ e₁ (.nil _)) : Seq ctx2 (fun _ => ⟨[frame4 2], 0⟩) [0, 1] mem4 _ me₁)
    (by decide) (fun n hn => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hn
      rcases hn with rfl | rfl <;> rfl) rfl
    (fun j hj => by simp only [grid2, List.size_toArray, List.length_cons, List.length_nil] at hj
                    simp only [List.mem_cons, List.not_mem_nil]; omega)
  exact ⟨z, hp, hd, hz ▸ hc⟩

/-- **The twin**: with thread 0 alone, the grid `Seq.grid` reaches from `grid2` (thread 0 done,
thread 1 unchanged) is not done, whatever its memory. -/
theorem vadd2_grid_twin (m : Mem) :
    ¬ GPUProof.Done sig
      (⟨[0].foldl (fun ts n => ts.set! n .done) grid2.threads, m⟩, Confluence.two, ctx2) := by
  intro h
  have hs : ([0].foldl (fun ts n => ts.set! n .done) grid2.threads).size ≤
      volume Confluence.two.grid * volume Confluence.two.block :=
    (foldl_set_size (fun _ => .done) [0] grid2.threads).trans_le (by decide)
  replace h := Grid.Done.all (by exact hs) h
  have e := foldl_done_getElem? [0] grid2.threads 1
  have h₁ : grid2.threads[1]? = some (.run ⟨[frame4 2], 0⟩) := rfl
  simp only [List.mem_singleton, Nat.one_ne_zero, ↓reduceIte, h₁] at e
  obtain ⟨hl, e⟩ := Array.getElem?_eq_some_iff.1 e
  have h' := (Array.all_eq_true.1 h) 1 hl
  rw [e] at h'
  exact absurd h' (by decide)

end MojoProofTest.SymSched
