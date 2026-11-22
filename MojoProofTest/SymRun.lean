import MojoProofTest.Sym
import MojoProofTest.Labels
import MojoProof.Sym.PtrMem

/-!
# `Block.sound` on concrete runs of `vector_addition`'s blocks `%21` and `%4`, and along its paths

A concrete instance of the premise `hds` of `vadd21_sound` (MojoProofTest/Sym.lean), and of its
conclusion. The context `ctx0` runs `vector_addition` with every special register, skeleton and
oracle choice 0 (oracle 0 makes `fadd contract` the separately rounded sum). The memory `mem0`
holds three global blocks of four binary32 cells: the inputs `inA` (block 1) and `inB` (block 2),
read-only, and the output (block 3), writable and undefined. The frame `frame0 i out` is at block
`%21`'s entry, with `%19 = i` (the element index), `%10` and `%8` pointing at the inputs and `%6`
at block `out`.

* `vadd21_hds`: for every index `i < 4`, every obligation of block `%21`'s summary holds on the
  values of its table under `frame0 i 3` (by `decide +kernel`).
* `vadd21_cell`: for every index `i < 4`, the thread's steps from `frame0 i 3` reach the block's
  end (at step count `Kernels.vadd.b1.len`), and cell `i` of the output holds the FloatLib sum
  `Model.add` of cells `i` of the inputs (`vadd21_sound` with `vadd21_hds`, and the kernel's
  evaluation of the summary's effects).
* `vadd21_hds_twins`: the obligations fail with the index out of range (`i = 4`: the first
  load reads past the block) and with the output buffer missing (`%6` pointing at block 7, which
  `mem0` does not have), by `decide +kernel`.
* `vadd4_hds`: the premise `hds` of `Block.sound` on the entry block `%4` (`vadd4_covers`,
  MojoProofTest/Sym.lean), whose statements 7, 9 and 11 call the special registers `tid.x`,
  `ctaid.x` and `ntid.x`. The context `ctx4 i` is thread number `i` of the launch `launch4` of
  one block of four threads (`ctx0` with the special registers `Launch.env` gives thread `i`);
  the memory `mem4` adds to `mem0` the three argument blocks 4, 5
  and 6, which hold pointers to the inputs and the output; the frame `frame4 n` is at `%4`'s entry
  with `%0`, `%1`, `%2` pointing at the argument blocks and the element count `%3 = n`. For every
  `i < 4`, every obligation holds at `frame4 4` under `ctx4 i`.
* `vadd4_hds_twin`: under `ctx0`, whose special registers are all 0 (not those of a valid
  launch), so `ntid.x = 0`, outside the range
  `[1, 1025)` that the declaration of `@llvm.nvvm.read.ptx.sreg.ntid.x` gives its result, the call
  at statement 11 has a poison result that its `noundef` attribute makes undefined behavior, and
  the obligations fail.
* `vadd_walk`: the premise `Walk` of `vadd_ret` (`Block.sound_ret` on the kernel's paths,
  MojoProofTest/Sym.lean): for every `i < 4`, at `frame4 4` under `ctx4 i`, the premises of the
  path `%4 → %21 → %31` hold (every block's obligations under its entry valuation
  `Valuation.after`, the registers, memory and step count of the block before; `%4`'s branch to
  `%21`); and thread 3 with element count 2 (`frame4 2` under `ctx4 3`) meets those of
  `%4 → %30 → %31`. Its twin `vadd_walk_twin`: that thread fails the premises of the path through
  `%21` (its branch goes to `%30`).
* `vadd_cell`: for every `i < 4`, thread `i`'s steps from the kernel's entry block (`frame4 4`
  under `ctx4 i`, memory `mem4`) run `%4`, `%21` and `%31` to the `ret`, whose step is `.done`,
  and cell `i` of the output holds the sum of cells `i` of the inputs (`vadd_ret` with
  `vadd_walk`).
* `vadd21_ptrs`: the pointer facts of `Block.sound_ptrs` on block `%21`: for every
  `i < 4`, thread `i`'s steps from `frame0 i 3` reach the statement of each `load` node and of
  the `store` effect, whose pointer operand evaluates in the thread's scope there to cell `i` of
  an input (block 1 or 2) and of the output (block 3).
* `vadd21_memNext_twin` (`Ptrs.loadsOk`, MojoProof/Sym/PtrMem.lean): with no register
  labelled payload and block 1 (input `inA`) payload, `Valuation.LoadsOk` fails on `%21`'s table,
  so for every `i < 4` thread `i` reaches a statement where `Labels.MemNext` fails (its first
  `load` reads block 1).
* `store_pathMem` (`Labels.MemOk.steps` and `Block.sound_pathMem`, MojoProof/Sym/PtrMem.lean):
  for every launch, the thread of `storeGrid` (MojoProofTest/Labels.lean), which stores the
  payload register 0 into block 1, meets the memory premises of its block (`st01`,
  `Valuation.PathMem`) under `lab0` with block 1 payload, from `store_ok`'s `Labels.MemOk`; its
  twin: with no payload block they fail.

Each evaluated proposition is proved by `decide +kernel` alone, with no rewriting before it:
the kernel unfolds `vals`, `SNode.eval`, `Mem.load` and `Layout.decode` (its value on a
float type is `scalarOf` of the bytes), and along a path `Walk`, `Valuation.after`,
`Valuation.last` and the path, whose registers are values of `%4`'s table.
Block `%4` loads structures `{ ptr, { { {} }, { {} } } }`, whose decoding goes through
`Layout.decodeFields`; it recurses structurally on the type and the field list, so the kernel
evaluates it with the rest.

Each result covers the contexts, memories and frames named, not all programs.
-/

namespace MojoProofTest.SymRun

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.Sym
open FloatLib.Floats.Formats.BinaryInterchange

/-- The first input: the binary32 words of 1, 2, 3 and 4. -/
def inA : List Nat := [0x3f800000, 0x40000000, 0x40400000, 0x40800000]

/-- The second input: the binary32 words of 0.5, 0.25, 0.125 and 0.0625. -/
def inB : List Nat := [0x3f000000, 0x3e800000, 0x3e000000, 0x3d800000]

/-- The context: `vector_addition`, no globals, every special register 0, thread 0 of block 0,
every skeleton and oracle choice 0. -/
def ctx0 : Ctx := ⟨Kernels.vadd.prog, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩, fun _ => 0,
  fun _ => 0⟩

/-- The memory: blocks 1 and 2 hold `inA` and `inB` (16 bytes each, global, read-only), block 3
is the output (16 bytes, global, writable, undefined). -/
def mem0 : Mem :=
  let L := Kernels.vadd.prog.layout
  let m₁ := (({} : Mem).alloc L 1 16 16 true true .all 1 1 (inA.flatMap (leBytes 4))).1
  let m₂ := (m₁.alloc L 1 16 16 true true .all 2 2 (inB.flatMap (leBytes 4))).1
  (m₂.alloc L 1 16 16 true false .all 3 3).1

/-- The frame at block `%21`'s entry with index `%19 = i`, the inputs at `%10` and `%8` and the
output pointer `%6` at block `out`. -/
def frame0 (i out : Nat) : Frame :=
  ⟨Kernels.vadd.fn_0, Kernels.vadd.fn_0.b_1.label, 0,
    fun r => if r = local? "19" then some (.bits 64 (BitVec.ofNat 64 i))
      else if r = local? "10" then some (.ptr ⟨1, 0⟩)
      else if r = local? "8" then some (.ptr ⟨2, 0⟩)
      else if r = local? "6" then some (.ptr ⟨out, 0⟩)
      else none,
    fun _ => none, [], none⟩

/-- **`hds` holds**: for every index `i < 4`, every obligation of block `%21`'s summary holds on
the values of its table at `frame0 i 3`. -/
theorem vadd21_hds : ∀ i < 4, ∀ d ∈ Kernels.vadd.b1.obls,
    d.Holds (Valuation.entry ctx0 0 mem0 (frame0 i 3))
      (vals (Valuation.entry ctx0 0 mem0 (frame0 i 3)) Kernels.vadd.b1.nodes) := by
  decide +kernel

/-- **The output cell**: for every index `i < 4`, the steps from `frame0 i 3` reach the end of
block `%21`, and cell `i` of the output holds the sum of cells `i` of the inputs. -/
theorem vadd21_cell : ∀ i < 4, ∃ fe me,
    Steps ctx0 ⟨[frame0 i 3], 0⟩ mem0 ⟨[fe], 0 + Kernels.vadd.b1.len⟩ me ∧
    me.load Kernels.vadd.prog.layout ctx0.who 0 (.fp .float) ⟨3, 4 * i⟩ (some 4) =
      .ok (.ofFloat .float (Model.add (Model.ofNatBits (inA.getD i 0))
        (Model.ofNatBits (inB.getD i 0)))) := by
  have hc : ∀ i < 4,
      (match SEff.run (Valuation.entry ctx0 0 mem0 (frame0 i 3))
          (vals (Valuation.entry ctx0 0 mem0 (frame0 i 3)) Kernels.vadd.b1.nodes)
          Kernels.vadd.b1.effs with
        | .ok me =>
          match me.load Kernels.vadd.prog.layout ctx0.who 0 (.fp .float) ⟨3, 4 * i⟩ (some 4) with
          | .ok v => decide (v.float? .float = some (Model.add (Model.ofNatBits (inA.getD i 0))
              (Model.ofNatBits (inB.getD i 0))))
          | .error _ => false
        | .error _ => false) = true := by
    decide +kernel
  intro i hi
  obtain ⟨fe, me, hS, hm⟩ := vadd21_sound (c := ctx0) (t := ⟨[frame0 i 3], 0⟩) (m := mem0)
    (f := frame0 i 3) (rest := []) rfl rfl rfl rfl rfl (vadd21_hds i hi)
  refine ⟨fe, me, hS, ?_⟩
  have hm' : SEff.run (Valuation.entry ctx0 0 mem0 (frame0 i 3))
      (vals (Valuation.entry ctx0 0 mem0 (frame0 i 3)) Kernels.vadd.b1.nodes)
      Kernels.vadd.b1.effs = .ok me := hm
  have h := hc i hi
  rw [hm'] at h
  dsimp only at h
  split at h
  next v hv => rw [hv, Val.float?_eq_some.1 (of_decide_eq_true h)]
  next => exact absurd h (by decide)

/-- **The twins**: the obligations fail at index 4 (out of range) and with `%6` pointing at block
7, which `mem0` does not have. -/
theorem vadd21_hds_twins :
    ¬ (∀ d ∈ Kernels.vadd.b1.obls, d.Holds (Valuation.entry ctx0 0 mem0 (frame0 4 3))
      (vals (Valuation.entry ctx0 0 mem0 (frame0 4 3)) Kernels.vadd.b1.nodes)) ∧
    ¬ (∀ d ∈ Kernels.vadd.b1.obls, d.Holds (Valuation.entry ctx0 0 mem0 (frame0 2 7))
      (vals (Valuation.entry ctx0 0 mem0 (frame0 2 7)) Kernels.vadd.b1.nodes)) := by
  decide +kernel

/-- The launch of one block of four threads: grid `(1, 1, 1)`, block `(4, 1, 1)`. -/
def launch4 : Launch := ⟨fun _ => 1, fun | .x => 4 | _ => 1, 0⟩

/-- The context of thread number `i` of `launch4`: `ctx0` with the special registers that
`Launch.env` gives thread `i` (`tid = (i % 4, 0, 0)`, `ntid = (4, 1, 1)`, `ctaid = (i / 4, 0, 0)`,
`nctaid = (1, 1, 1)`, `laneid = i % 4`), named as thread `i` of block `i / 4`, as `Grid.start`
names it. -/
def ctx4 (i : Nat) : Ctx :=
  { ctx0 with env := launch4.env i, who := ⟨i, i / 4⟩ }

/-- `mem0` with the three argument blocks 4, 5 and 6 (8 bytes, global, read-only), which hold
pointers to the inputs (blocks 1 and 2) and to the output (block 3). -/
def mem4 : Mem :=
  let arg (m : Mem) (a p : Nat) := (m.alloc Kernels.vadd.prog.layout 1 8 8 true true .all a a
    ((List.range 8).map (.ptr ⟨p, 0⟩ ·))).1
  arg (arg (arg mem0 10 1) 11 2) 12 3

/-- The frame at the entry block `%4` with element count `%3 = n` and the arguments `%0`, `%1`,
`%2` pointing at the argument blocks 4, 5 and 6. -/
def frame4 (n : Nat) : Frame :=
  ⟨Kernels.vadd.fn_0, Kernels.vadd.fn_0.b_0.label, 0,
    fun r => if r = local? "0" then some (.ptr ⟨4, 0⟩)
      else if r = local? "1" then some (.ptr ⟨5, 0⟩)
      else if r = local? "2" then some (.ptr ⟨6, 0⟩)
      else if r = local? "3" then some (.bits 32 (BitVec.ofNat 32 n))
      else none,
    fun _ => none, [], none⟩

/-- **`hds` at the entry block**: for every thread index `i < 4`, every obligation of block
`%4`'s summary, its three special-register calls included, holds on the values of its table at
`frame4 4` under `ctx4 i`. -/
theorem vadd4_hds : ∀ i < 4, ∀ d ∈ Kernels.vadd.b0.obls,
    d.Holds (Valuation.entry (ctx4 i) 0 mem4 (frame4 4))
      (vals (Valuation.entry (ctx4 i) 0 mem4 (frame4 4)) Kernels.vadd.b0.nodes) := by
  decide +kernel

/-- **The twin**: under `ctx0` (`ntid.x = 0`, outside the range the declaration of `ntid.x`
gives), the obligations of block `%4`'s summary fail at `frame4 4`. -/
theorem vadd4_hds_twin :
    ¬ (∀ d ∈ Kernels.vadd.b0.obls, d.Holds (Valuation.entry ctx0 0 mem4 (frame4 4))
      (vals (Valuation.entry ctx0 0 mem4 (frame4 4)) Kernels.vadd.b0.nodes)) := by
  decide +kernel

/-- **The path premises**: for every thread index `i < 4`, at `frame4 4` under `ctx4 i`, the
premises of the path `%4 → %21 → %31` hold (`Walk`: each block's obligations under its entry
valuation, `%4`'s branch to `%21`, `%21`'s to `%31`); and thread 3 with element count 2
(`frame4 2` under `ctx4 3`) meets those of the path `%4 → %30 → %31`. With `vadd_ret`, these
run the threads to their `ret`. -/
theorem vadd_walk : (∀ i < 4, Walk (Valuation.entry (ctx4 i) 0 mem4 (frame4 4))
      ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddIn)) ∧
    Walk (Valuation.entry (ctx4 3) 0 mem4 (frame4 2))
      ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddOut) := by
  decide +kernel

/-- **The twin**: thread 3 with element count 2 (`frame4 2` under `ctx4 3`) has index 3, not
below the count: block `%4`'s branch goes to `%30`, and the premises of the path through `%21`
fail. -/
theorem vadd_walk_twin : ¬ Walk (Valuation.entry (ctx4 3) 0 mem4 (frame4 2))
    ((Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddIn) := by
  decide +kernel

/-- **The output cell at the return**: for every thread index `i < 4`, the steps of thread `i`
from `frame4 4` (the entry block `%4`) run the path `%4 → %21 → %31` to its `ret`, the next step
returns (`.done`), and cell `i` of the output holds the sum of cells `i` of the inputs
(`vadd_ret` with `vadd_walk`, and the kernel's evaluation of the path's effects). -/
theorem vadd_cell : ∀ i < 4, ∃ fe me,
    Steps (ctx4 i) ⟨[frame4 4], 0⟩ mem4 ⟨[fe], 0 + pathLen Kernels.vadd.b0 vaddIn⟩ me ∧
    step (ctx4 i) ⟨[fe], 0 + pathLen Kernels.vadd.b0 vaddIn⟩ me = .ok (.done me) ∧
    me.load Kernels.vadd.prog.layout (ctx4 i).who 0 (.fp .float) ⟨3, 4 * i⟩ (some 4) =
      .ok (.ofFloat .float (Model.add (Model.ofNatBits (inA.getD i 0))
        (Model.ofNatBits (inB.getD i 0)))) := by
  have hc : ∀ i < 4,
      (match SEff.run ((Valuation.entry (ctx4 i) 0 mem4 (frame4 4)).last
            Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).1
          (vals ((Valuation.entry (ctx4 i) 0 mem4 (frame4 4)).last
            Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).1
            ((Valuation.entry (ctx4 i) 0 mem4 (frame4 4)).last
              Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).2.2.nodes)
          ((Valuation.entry (ctx4 i) 0 mem4 (frame4 4)).last
            Kernels.vadd.fn_0.b_0.label Kernels.vadd.b0 vaddIn).2.2.effs with
        | .ok me =>
          match me.load Kernels.vadd.prog.layout (ctx4 i).who 0 (.fp .float) ⟨3, 4 * i⟩
              (some 4) with
          | .ok v => decide (v.float? .float = some (Model.add (Model.ofNatBits (inA.getD i 0))
              (Model.ofNatBits (inB.getD i 0))))
          | .error _ => false
        | .error _ => false) = true := by
    decide +kernel
  intro i hi
  obtain ⟨fe, me, hS, hm, hst⟩ := vadd_ret (c := ctx4 i) (t := ⟨[frame4 4], 0⟩) (m := mem4)
    (f := frame4 4) rfl (.inl rfl) rfl rfl rfl rfl (vadd_walk.1 i hi)
  refine ⟨fe, me, hS, hst, ?_⟩
  have h := hc i hi
  dsimp only at hm
  rw [hm] at h
  dsimp only at h
  split at h
  next v hv => rw [hv, Val.float?_eq_some.1 (of_decide_eq_true h)]
  next => exact absurd h (by decide)


/-- Whether a value is the pointer to cell `i` (offset `4 * i`) of block `b`. -/
def cellIs (b i : Nat) : Except Fault Val → Bool
  | .ok (.ptr q) => decide (q = ⟨b, 4 * i⟩)
  | _ => false

/-- `cellIs b i` decides the pointer to cell `i` of block `b`. -/
theorem cellIs_eq {b i : Nat} {pv : Except Fault Val} :
    cellIs b i pv = true ↔ pv = .ok (.ptr ⟨b, 4 * i⟩) := by
  constructor
  · intro h
    unfold cellIs at h
    split at h
    · rw [of_decide_eq_true h]
    · cases h
  · rintro rfl
    exact decide_eq_true rfl

/-- The pointer terms of block `%21`'s summary at `frame0 i 3`: each `load` node's, on the values
of the nodes before it, is cell `i` of block 1 or 2; the `store` effect's, on the table's, is
cell `i` of block 3. -/
theorem vadd21_ptrval : ∀ i < 4,
    (∀ j < Kernels.vadd.b1.nodes.length, (match Kernels.vadd.b1.nodes[j]? with
      | some (.load _ _ p) =>
        cellIs 1 i (p.eval (Valuation.entry ctx0 0 mem0 (frame0 i 3))
            (vals (Valuation.entry ctx0 0 mem0 (frame0 i 3)) (Kernels.vadd.b1.nodes.take j))) ||
          cellIs 2 i (p.eval (Valuation.entry ctx0 0 mem0 (frame0 i 3))
            (vals (Valuation.entry ctx0 0 mem0 (frame0 i 3)) (Kernels.vadd.b1.nodes.take j)))
      | _ => true) = true) ∧
    (Kernels.vadd.b1.effs.all fun
      | .store _ _ _ p => cellIs 3 i (p.eval (Valuation.entry ctx0 0 mem0 (frame0 i 3))
          (vals (Valuation.entry ctx0 0 mem0 (frame0 i 3)) Kernels.vadd.b1.nodes))
      | _ => true) = true := by
  decide +kernel

/-- `Block.sound_ptrs` on block `%21` at `frame0 i 3`, for every `i < 4`. -/
theorem vadd21_q : ∀ i < 4, Ptrs ctx0 ⟨[frame0 i 3], 0⟩ mem0 []
    (Valuation.entry ctx0 0 mem0 (frame0 i 3), Kernels.vadd.fn_0.b_1.label, Kernels.vadd.b1) :=
  fun i hi => (Block.sound_ptrs vadd21_covers (c := ctx0) (t := ⟨[frame0 i 3], 0⟩) (m := mem0)
    (f := frame0 i 3) (rest := []) rfl rfl rfl rfl rfl (vadd21_hds i hi)).2

/-- **The pointer facts on block `%21`**: for every index `i < 4`, the steps of the thread
from `frame0 i 3` reach the statement of each `load` node of the summary, whose pointer operand
evaluates in the thread's scope there to cell `i` of an input (block 1 or 2), and the statement
of its `store` effect, whose pointer operand evaluates to cell `i` of the output (block 3). -/
theorem vadd21_ptrs : ∀ i < 4,
    (∀ (j l pc : Nat) (p : SVal), Kernels.vadd.b1.nodes[j]? = some (.load l pc p) →
      ∃ b, (b = 1 ∨ b = 2) ∧
        PtrAt ctx0 ⟨[frame0 i 3], 0⟩ mem0 [] Kernels.vadd.fn_0 l pc true (.ok (.ptr ⟨b, 4 * i⟩))) ∧
    ∀ l pc v p, SEff.store l pc v p ∈ Kernels.vadd.b1.effs →
      PtrAt ctx0 ⟨[frame0 i 3], 0⟩ mem0 [] Kernels.vadd.fn_0 l pc false
        (.ok (.ptr ⟨3, 4 * i⟩)) := by
  intro i hi
  obtain ⟨hL, hS⟩ := vadd21_q i hi
  obtain ⟨hv₁, hv₂⟩ := vadd21_ptrval i hi
  refine ⟨fun j l pc p hn => ?_, fun l pc v p hm => ?_⟩
  · have h := hv₁ j (List.getElem?_eq_some_iff.1 hn).1
    rw [hn] at h
    rcases Bool.or_eq_true_iff.1 h with h | h
    · exact ⟨1, .inl rfl, cellIs_eq.1 h ▸ hL j l pc p hn⟩
    · exact ⟨2, .inr rfl, cellIs_eq.1 h ▸ hL j l pc p hn⟩
  · have h := List.all_eq_true.1 hv₂ _ hm
    exact cellIs_eq.1 h ▸ (hS l pc v p hm).1

/-- The labelling with no payload register and no payload return. -/
def labNone : Labels := { reg := fun _ _ => false, ret := fun _ => false }

/-- Some `load` node of block `%21`'s summary has, at `frame0 i 3`, the pointer value of cell
`i` of block 1, for every `i < 4`. -/
theorem vadd21_load1 : ∀ i < 4, ∃ j < Kernels.vadd.b1.nodes.length,
    (match Kernels.vadd.b1.nodes[j]? with
    | some (.load _ _ p) => cellIs 1 i (p.eval (Valuation.entry ctx0 0 mem0 (frame0 i 3))
        (vals (Valuation.entry ctx0 0 mem0 (frame0 i 3)) (Kernels.vadd.b1.nodes.take j)))
    | _ => false) = true := by
  decide +kernel

/-- **The negative twin** (`Ptrs.loadsOk` with `vadd21_q`): with no register labelled payload
(`labNone`) and block 1 (the input `inA`) payload, for every `i < 4` some state that thread `i`'s
steps from `frame0 i 3` reach fails `Labels.MemNext`: the first `load` reads block 1. -/
theorem vadd21_memNext_twin : ∀ i < 4, ¬ ∀ t' m',
    Steps ctx0 ⟨[frame0 i 3], 0⟩ mem0 t' m' → labNone.MemNext (· = 1) ctx0 m' t' := by
  intro i hi hM
  have hL := Ptrs.loadsOk (vadd21_q i hi) hM
  obtain ⟨j, -, h⟩ := vadd21_load1 i hi
  split at h
  next l pc p hn =>
    exact hL j l pc p ⟨1, 4 * i⟩ hn (by cases resReg _ l pc <;> rfl) (cellIs_eq.1 h) rfl
  next => cases h

/-- The summary of `kernel #[store01]`'s block (MojoProofTest/Labels.lean): the `store` of
register 0 through the pointer in register 1, then `ret void`. -/
sym_summary st01 := (MojoProofTest.Labels.cS 0).prog
  (MojoProofTest.Pending.kernel #[MojoProofTest.Labels.store01]) 0 0

open MojoProofTest.Labels in
/-- **From `Labels.MemOk` to `Valuation.PathMem`** (`Labels.MemOk.steps`,
`Block.sound_pathMem`): for every launch `L`, under `lab0` (register 0 payload) with block 1
payload, `storeGrid` meets `Labels.MemOk` (`store_ok`, MojoProofTest/Labels.lean), so its thread,
at `storeAt 0` on `storeGrid`'s memory, meets the memory premises of the one-block path through
`kernel #[store01]`'s block (`st01`) from its entry valuation: its `store` of the payload term
`.reg 0` writes into block 1. The twin: with no payload block, those premises fail. -/
theorem store_pathMem (L : Launch) :
    (Valuation.entry (cS 0) 0 storeGrid.mem (storeAt 0)).PathMem lab0 (· = 1) 0 st01 [] ∧
      ¬ (Valuation.entry (cS 0) 0 storeGrid.mem (storeAt 0)).PathMem lab0 (fun _ => False) 0
        st01 [] :=
  ⟨Block.sound_pathMem (ds := st01.obls) (t := ⟨[storeAt 0], 0⟩) rfl (by decide +kernel)
      (by decide +kernel) rfl rfl rfl rfl (by decide +kernel)
      fun _ _ hS => (store_ok L).2.1.steps (n := 0) .refl rfl hS,
    fun h => h.2 0 0 (.reg 0) (.reg 1) ⟨1, 0⟩ (.head _) rfl rfl⟩

end MojoProofTest.SymRun
