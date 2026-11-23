import MojoProofTest.NaiveSound
import MojoProof.Sym.Ops

/-!
# The naive matmul kernel's threads out of bounds: `NaiveSpec.RunOut`

`runOut` proves `NaiveSpec.RunOut` for the naive matmul kernel (`naive`, MojoProofTest/SymPhi.lean)
for every oracle `ω`, launch `L`, sizes `m`, `n`, `K`, blocks `bC`, `bA`, `bB` and tensors `A`,
`B`: every thread `k` of `L` out of bounds (`¬ NaiveSpec.S L m n k`) whose entry facts are
`NaiveSpec.At` runs `NaiveThread.skipN` to `ret` (`RetWith true`) from a memory of `Elem` after
`k` threads whose accesses to `bC` are all by threads in bounds (`Elem.Only`), to a memory of
`Elem` after `k + 1` threads with the same property.

The proof is `naive.out`, the run of a thread out of bounds that the `mat` clause of
`mojo_kernel` generates (MojoProofTest/NaiveSound.lean), at `At`'s facts (`NaiveSpec.At.entry`),
the sizes below `2 ^ 31` (`NaiveSpec.dims_lt`) and no bytes of a thread out of bounds
(`NaiveSpec.bytes_out`). This is one program, `naive`, for every launch, size, block, tensor,
memory, frame and thread out of bounds. An `example` after it tests mojo_ret's goals 1 and 3
(`Elem` and `Elem.Only` after the entry block's effects) on the same threads.

A concrete instance: `runsZ`, at the start `startZ` of `naive` on `launch2 1 1 2 2` with
`m = n = 0`, `K = 2` and the memory `memZ` (three empty global buffers, `A` and `B` read-only),
where `At` holds for every thread (`atZ`). The launch of `NaiveThread.startN` does not meet `At`
(its buffers are smaller than `At` asks, and its `A` and `B` are writable), so
`NaiveThread.skip_threads` is not a corollary of `runOut`.
-/

namespace MojoProofTest.NaiveOut

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymPhi
  MojoProofTest.NaiveThread MojoProofTest.NaiveSpec
open FloatLib.Floats.Formats.BinaryInterchange

/-- **The naive kernel's threads out of bounds** (`NaiveSpec.RunOut`), for this one program,
`naive`, and all its admitted launches and inputs: for every oracle `ω`, launch `L`, sizes `m`,
`n`, `K`, blocks `bC`, `bA`, `bB` and tensors `A`, `B`, every thread `k` out of bounds with the
entry facts `At` (struct pointers `p0`, `p1`, `p2`, context `c`, memory `m'`, frame `f`), a
memory of `Elem m₀ bC 4 (cell L) (bytes ω L K A B)` after `k` threads and every access to `bC`
by a thread in bounds runs `skipN` to `ret` with a memory of `Elem` after `k + 1` threads whose
accesses to `bC` are by threads in bounds. It is `naive.out` at `At`'s facts. -/
theorem runOut (ω : Nat → Nat → Nat) (L : Launch) {m n : Nat} (K bC bA bB : Nat)
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768])
    (B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]) :
    RunOut ω L K bC bA bB A B := fun _ _ _ _ _ _ _ _ hS hA =>
  NaiveSound.naive.out hA.valid (dims_lt hA.dims) (bytes_out ω L K A B) hA.thread hS hA.entry

/-- **mojo_ret's goals 1 and 3 on naive's entry block** (a test of the tactic,
MojoProof/Sym/Ops.lean): for every thread `k` out of bounds with the entry facts `At`, a memory
of `Elem` after `k` threads with `Elem.Only`, and every memory `me` that the entry block `%6`'s
effects give (three loads of the struct arguments, none from `bC`), `me` meets `Elem` after
`k + 1` threads (`Elem.skip`, `bytes_out`) and `Elem.Only`. `naive.out` proves these by
`RetWith.of_first` instead. -/
example {ω : Nat → Nat → Nat} {L : Launch} {m n K bC bA bB p0 p1 p2 k : Nat}
    {A : TorchLean.Tensor (Model FloatTy.float.fmt) [m, 768]}
    {B : TorchLean.Tensor (Model FloatTy.float.fmt) [n, 768]} {c : Ctx} {m₀ m' me : Mem}
    {f : Frame} (hS : ¬ S L m n k) (hA : At L K bC bA bB p0 p1 p2 A B k c m' f)
    (hE : Elem m₀ bC 4 (cell L) (bytes ω L K A B) k m') (hO : Elem.Only bC (S L m n) m')
    (hme : SEff.run (Valuation.entry c 0 m' f) (vals (Valuation.entry c 0 m' f)
      SymSelect.entry.nodes) SymSelect.entry.effs = .ok me) :
    Elem m₀ bC 4 (cell L) (bytes ω L K A B) (k + 1) me ∧ Elem.Only bC (S L m n) me := by
  obtain ⟨-, -, -, -, -, -, ⟨_, _, _, _, _, _⟩, -, -, -, -, -, -⟩ := hA
  exact ⟨Elem.skip (by mojo_ret) (bytes_out ω L K A B k hS), by mojo_ret⟩

/-- The caller's memory of a launch of `naive` with `m = n = 0`: block 1 (`C`, writable), block 2
(`A`) and block 3 (`B`, both read-only), each of 0 bytes, global, live and admitting every thread,
at the addresses of `NaiveThread.memN`. -/
def memZ : Mem :=
  let l := naive.prog.layout
  let m := (({} : Mem).alloc l 1 0 16 true false .all 0x10000 0x10000).1
  let m := (m.alloc l 1 0 16 true true .all 0x100 0x100).1
  (m.alloc l 1 0 16 true true .all 0x200 0x200).1

/-- The launch's arguments: `C`, `A`, `B` (blocks 1, 2, 3), then the `i32`s `m = 0`, `n = 0` and
`K = 2`. -/
def argsZ : List Val :=
  [tens 1, tens 2, tens 3, .bits 32 (BitVec.ofNat 32 0), .bits 32 (BitVec.ofNat 32 0),
    .bits 32 (BitVec.ofNat 32 2)]

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a start without this.
unseal Array.anyM.loop

/-- The start's grid and contexts on `launch2 1 1 2 2` (one block of 2 × 2 threads), `argsZ` and
`memZ` at the address choice 0 and the oracle `ωN` (the empty grid if it faults). -/
def runZ : Grid × (Nat → Ctx) :=
  match Grid.start naive.prog naive.fn_0 (launch2 1 1 2 2) argsZ memZ (fun _ => 0) ωN with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => SymRun.ctx0)

/-- The start's grid. -/
def gZ : Grid := runZ.1

/-- The start's contexts. -/
def cZ : Nat → Ctx := runZ.2

/-- **The launch starts**, with grid `gZ` and contexts `cZ` (evaluated). -/
theorem startZ :
    Grid.start naive.prog naive.fn_0 (launch2 1 1 2 2) argsZ memZ (fun _ => 0) ωN = .ok (gZ, cZ) :=
  rfl

/-- Thread `k`'s frame at the start. -/
def frZ (k : Nat) : Frame :=
  ((Grid.thread gZ k).frames.head?).getD ⟨naive.fn_0, 0, 0, fun _ => none, fun _ => none, [], none⟩

/-- `launch2 1 1 2 2` is valid (`launch2_valid`): every side is 1 or 2, and a block has 4
threads. For this one launch. -/
theorem validZ : (launch2 1 1 2 2).Valid :=
  launch2_valid (by decide)

/-- **`At` holds at the start `startZ`** (a concrete instance of `runOut`'s premise): for every
pair of tensors `A`, `B` with no rows and each of the four threads `k` of `launch2 1 1 2 2`,
`At` with `K = 2`, buffers `bC = 1`, `bA = 2`, `bB = 3` and struct copies `5 + 3 k`, `6 + 3 k`,
`7 + 3 k` holds at thread `k`'s context `cZ k`, the start's memory and frame `frZ k`. For this
program, launch, memory and address choice only. -/
theorem atZ (A B : TorchLean.Tensor (Model FloatTy.float.fmt) [0, 768]) (k : Nat) (hk : k < 4) :
    At (launch2 1 1 2 2) 2 1 2 3 (5 + 3 * k) (6 + 3 * k) (7 + 3 * k) A B k (cZ k) gZ.mem
      (frZ k) := by
  obtain rfl | rfl | rfl | rfl : k = 0 ∨ k = 1 ∨ k = 2 ∨ k = 3 := by omega
  all_goals
    exact ⟨validZ, ⟨rfl, rfl⟩, by decide, by decide, (Grid.start_ctx startZ _).1 ▸ ⟨rfl, rfl, rfl⟩,
      rfl, ⟨rfl, rfl, rfl, by decide, by decide, by decide⟩, ⟨rfl, rfl, rfl⟩, ⟨rfl, rfl, rfl⟩,
      by decide, ⟨⟨_, rfl, by decide⟩, ⟨_, rfl, by decide⟩, ⟨_, rfl, fun i => i.1.elim0⟩⟩,
      ⟨⟨_, rfl, by decide⟩, ⟨_, rfl, by decide⟩, ⟨_, rfl, fun i => i.1.elim0⟩⟩,
      ⟨_, rfl, by decide⟩, ⟨_, rfl, by decide⟩⟩

/-- **The threads of the start `startZ` run to their end, by `runOut`**: for every oracle `ω`,
pair of tensors `A`, `B` with no rows and each of the four threads `k` of `launch2 1 1 2 2` (all
out of bounds, since `m = n = 0`), the thread runs from `Grid.start`'s entry frame to its end
(`Runs`, by `Runs.of_retWith`) with a memory that meets `Elem` after `k + 1` threads from the
start's memory and whose accesses to `C` are by threads in bounds (none). The start's memory
meets `Elem` after `k` threads (no thread puts bytes, `Elem.zero`, `Elem.skip`) and `Elem.Only`
(its trace is empty). For this program, launch, memory and address choice only. -/
theorem runsZ (ω : Nat → Nat → Nat) (A B : TorchLean.Tensor (Model FloatTy.float.fmt) [0, 768])
    (k : Nat) (hk : k < 4) :
    ∃ m', Runs (cZ k) (Grid.thread gZ k) gZ.mem m' ∧
      Elem gZ.mem 1 4 (cell (launch2 1 1 2 2)) (bytes ω (launch2 1 1 2 2) 2 A B) (k + 1) m' ∧
      Elem.Only 1 (S (launch2 1 1 2 2) 0 0) m' := by
  have hS : ∀ j, ¬ S (launch2 1 1 2 2) 0 0 j := fun _ h => Nat.not_lt_zero _ h.2.1
  have hE : ∀ j, Elem gZ.mem 1 4 (cell (launch2 1 1 2 2)) (bytes ω (launch2 1 1 2 2) 2 A B) j
      gZ.mem := by
    intro j
    induction j with
    | zero => exact Elem.zero rfl
    | succ j ih => exact Elem.skip ih (bytes_out _ _ _ _ _ _ (hS j))
  obtain ⟨ps, hps, h⟩ := runOut ω (launch2 1 1 2 2) 2 1 2 3 A B k _ _ _ (cZ k) gZ.mem gZ.mem
    (frZ k) (hS k) (atZ A B k hk) (hE k) fun a ha => by
      rw [show gZ.mem.trace = [] from rfl] at ha
      cases ha
  rw [List.mem_singleton] at hps
  subst hps
  obtain rfl | rfl | rfl | rfl : k = 0 ∨ k = 1 ∨ k = 2 ∨ k = 3 := by omega
  all_goals
    exact Runs.of_retWith (f := frZ _) (Grid.start_ctx startZ _).1 skipN_covers
      rfl rfl rfl rfl rfl h

end MojoProofTest.NaiveOut
