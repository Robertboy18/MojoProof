import MojoProof.Tile.Map2
import MojoProof.Tile.Dot
import MojoProofTest.Kernel
import MojoProofTest.Matmul

/-!
# Tests of the tile layer

* `tile_map2`: the command that states and proves, for one kernel of `mojo_kernel`'s `map2`
  clause at floats, that it refines `map2 op` (`map2_refines` applied to the kernel's
  `correct`); `vadd_tile`, `vmul_tile` and `vsub_tile` are its three uses, each covering that
  kernel at every valid one-dimensional launch, alignment that 4 divides, memory of `Map2.Pre`,
  count, inputs and oracle;
* the computed step of each kernel's operation (`siteStep?`, evaluated by the kernel), and
  `vadd_tile`, `vmul_tile` and `vsub_tile` at two concrete launch sizes (`L23`, 6 threads, and
  `Confluence.two`, 2 threads) with their memories (`mem5` and `mem4` for `vadd` and `vsub`,
  `memV` for `vmul`);
* `map2 .fadd` run on concrete inputs of two sizes, its values and its access log evaluated by
  the kernel and by `#eval`, a fault, and a program written with `do`;
* the refusal of a wrong program: `vector_addition`'s paths have no `fsub` step, and the
  subtraction program's output differs from `vector_addition`'s at `x5`, `y5`;
* the tile matrix product: `dot_meets` at the 2 × 3 matrices `tA` and `tB` of
  MojoProofTest/Matmul.lean with the placement by rows at two sizes, all 3 columns
  (`meets_tA3`) and the first 2 (`meets_tA2`), and the run of `dot false` on them evaluated by the
  kernel at both sizes: with all 3 columns the cells are TorchLean's `tA tBᵀ`, `[[-2, 4], [-2, 13]]`
  (`Matmul.cells`), with 2 they are `[[1, 4], [4, 13]]`; the placement by rows, and a count past
  the matrices' columns that faults.
-/

namespace MojoProofTest.Tile

open MojoProof MojoProof.Sem MojoProof.Sym MojoProof.Tile MojoProofTest.Kernel
open FloatLib.Floats.Formats.BinaryInterchange

/-- `tile_map2 k op f` after a docstring: the theorem `k_tile` that for every valid
one-dimensional launch, alignment that 4 divides, memory of `Map2.Pre` (under the layout of
`Kernels.k.prog`), count `n`, inputs `x`, `y`, address choice, oracle `ω` and observation `B`
of a complete run of `Kernels.k` on `Kernels.vadd.args a b out n`, the run of `map2 op n` from
`inputs x y` at the tile oracle `oracle Kernels.k.paths ω` on all the launch's threads ends
without a fault, and its cell `k` of buffer 2 is the float at output cell `4 k` of `B` for every
thread `k < n`; by `map2_refines` with `f` the operation of `op` and the kernel's
`Kernels.k.correct`, the step of `op` evaluated by the kernel. -/
syntax (name := tileMap2) docComment "tile_map2 " ident term:max term:max : command

open Lean in
macro_rules
  | `($doc:docComment tile_map2 $kn:ident $op:term $f:term) => do
    let K (s : Name) : Ident := mkIdent (`Kernels ++ kn.getId ++ s)
    let prog := K `prog
    `($doc:docComment theorem $(mkIdent (kn.getId.appendAfter "_tile")) {L : Launch}
        (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1) (hb : L.block .y = 1 ∧ L.block .z = 1)
        {al : Nat} (hal : 4 ∣ al) {a b out n N : Nat}
        {x y : TorchLean.Tensor (Model LLVM.FloatTy.float.fmt) [N]} {m : Mem}
        (hP : Map2.Pre ($prog).layout (.fp .float) (Val.ofFloat .float) al Kernels.vadd.argTail m
          a b out n x y)
        {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
        (hB : Kernel.Obs $prog $(K `fn_0) L (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m
          (fun m => some m.blocks) ch ω B) :
        ∃ st, runAll (oracle $(K `paths) ω) (map2 $op n) (volume L.grid * volume L.block)
            (inputs x y) = .ok st ∧
          ∀ k, k < n → k < volume L.grid * volume L.block →
            Elem.word ($prog).layout .float out (fun i => 4 * i) B k = st.cells 2 k :=
      map2_refines (f := $f) ($(K `correct) hL hg hb hal hP) rfl (by decide +kernel)
        ⟨_, hP.bufs.2.2.choose_spec.1⟩ (apart_mul 4) hP.le rfl hB)

/-- **`vector_addition` refines `map2 .fadd`** (`tile_map2`): for every valid one-dimensional
launch, alignment that 4 divides, memory of `Map2.Pre`, count, inputs, address choice, oracle
and observation of a complete run, the tile run at `oracle Kernels.vadd.paths ω` ends without a
fault and its buffer 2 is the kernel's output at every thread below the count. -/
tile_map2 vadd .fadd Model.add

/-- **`vector_multiply` refines `map2 .fmul`** (`tile_map2`), with the scope of `vadd_tile`. -/
tile_map2 vmul .fmul Model.mul

/-- **`vector_subtraction` refines `map2 .fsub`** (`tile_map2`), with the scope of
`vadd_tile`. -/
tile_map2 vsub .fsub Model.sub

/-! ## The computed steps -/

example : siteStep? Kernels.vadd.paths .fadd = some 23 := by decide +kernel
example : siteStep? Kernels.vmul.paths .fmul = some 23 := by decide +kernel
example : siteStep? Kernels.vsub.paths .fsub = some 23 := by decide +kernel

/-- `vadd_tile` at a concrete launch: 2 blocks of 3 threads, count 5, inputs `x5` and `y5` at
blocks 1 and 2 and the output at block 3 of `mem5` (`pre5`). -/
example {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun m => some m.blocks) ch ω B) :
    ∃ st, runAll (oracle Kernels.vadd.paths ω) (map2 .fadd 5) 6 (inputs x5 y5) = .ok st ∧
      ∀ k, k < 5 → k < 6 →
        Elem.word Kernels.vadd.prog.layout .float 3 (fun i => 4 * i) B k = st.cells 2 k :=
  vadd_tile valid23 ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre5 hB

/-- `vadd_tile` at a second size: one block of 2 threads, count 4, inputs `x5` and `y5` and an
output of 4 floats (`mem4`, `pre4`); threads 2 and 3 do not run. -/
example {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vadd.prog Kernels.vadd.fn_0 Confluence.two
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 4)) mem4 (fun m => some m.blocks) ch ω B) :
    ∃ st, runAll (oracle Kernels.vadd.paths ω) (map2 .fadd 4) 2 (inputs x5 y5) = .ok st ∧
      ∀ k, k < 4 → k < 2 →
        Elem.word Kernels.vadd.prog.layout .float 3 (fun i => 4 * i) B k = st.cells 2 k :=
  vadd_tile (launch2_valid (by decide)) ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre4 hB

/-- `vmul_tile` at `L23` (6 threads), count 5, inputs `x5` and `x5` at blocks 1 and 2 and the
output at block 3 of `memV` (`preV`). -/
example {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vmul.prog Kernels.vmul.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) memV (fun m => some m.blocks) ch ω B) :
    ∃ st, runAll (oracle Kernels.vmul.paths ω) (map2 .fmul 5) 6 (inputs x5 x5) = .ok st ∧
      ∀ k, k < 5 → k < 6 →
        Elem.word Kernels.vmul.prog.layout .float 3 (fun i => 4 * i) B k = st.cells 2 k :=
  vmul_tile valid23 ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) preV hB

/-- `vmul_tile` at a second launch size, `Confluence.two` (2 threads), with the same count and
memory: threads 2 to 4 do not run. -/
example {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vmul.prog Kernels.vmul.fn_0 Confluence.two
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) memV (fun m => some m.blocks) ch ω B) :
    ∃ st, runAll (oracle Kernels.vmul.paths ω) (map2 .fmul 5) 2 (inputs x5 x5) = .ok st ∧
      ∀ k, k < 5 → k < 2 →
        Elem.word Kernels.vmul.prog.layout .float 3 (fun i => 4 * i) B k = st.cells 2 k :=
  vmul_tile (launch2_valid (by decide)) ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) preV hB

/-- `vsub_tile` at `L23`, count 5 and `mem5` (`pre5`, whose layout is `vector_subtraction`'s). -/
example {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vsub.prog Kernels.vsub.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun m => some m.blocks) ch ω B) :
    ∃ st, runAll (oracle Kernels.vsub.paths ω) (map2 .fsub 5) 6 (inputs x5 y5) = .ok st ∧
      ∀ k, k < 5 → k < 6 →
        Elem.word Kernels.vsub.prog.layout .float 3 (fun i => 4 * i) B k = st.cells 2 k :=
  vsub_tile valid23 ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre5 hB

/-- `vsub_tile` at a second size: `Confluence.two`, count 4 and `mem4` (`pre4`). -/
example {ch : Nat → Nat} {ω : Nat → Nat → Nat} {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs Kernels.vsub.prog Kernels.vsub.fn_0 Confluence.two
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 4)) mem4 (fun m => some m.blocks) ch ω B) :
    ∃ st, runAll (oracle Kernels.vsub.paths ω) (map2 .fsub 4) 2 (inputs x5 y5) = .ok st ∧
      ∀ k, k < 4 → k < 2 →
        Elem.word Kernels.vsub.prog.layout .float 3 (fun i => 4 * i) B k = st.cells 2 k :=
  vsub_tile (launch2_valid (by decide)) ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre4 hB

/-! ## Runs on concrete inputs -/

/-- The words of cells `0` to `n - 1` of buffer 2 after the run of `map2 op n` on `T` threads
from `inputs x y` at the tile oracle 0 (`none` on a fault). -/
def cells2 {N : Nat} (op : LLVM.FBinOp) (n T : Nat)
    (x y : TorchLean.Tensor (Model LLVM.FloatTy.float.fmt) [N]) : Option (List (Option Nat)) :=
  (runAll (fun _ => 0) (map2 op n) T (inputs x y)).toOption.map fun s =>
    (List.range n).map fun k => (s.cells 2 k).map Model.toNatBits

/-- `1 + 32`, `2 + 16`, `4 + 8`, `8 + 4`, `16 + 2`: `x5 + y5` cell by cell, on 6 threads. -/
example : cells2 .fadd 5 6 x5 y5 = some [some 0x42040000, some 0x41900000, some 0x41400000,
    some 0x41400000, some 0x41900000] := by
  decide +kernel

/-- Count 2 on 2 threads: `1 + 32`, `2 + 16`. -/
example : cells2 .fadd 2 2 x5 y5 = some [some 0x42040000, some 0x41900000] := by
  decide +kernel

/-- Count 5 on 3 threads: threads 3 and 4 do not run, so their cells are not set. -/
example : cells2 .fadd 5 3 x5 y5 = some [some 0x42040000, some 0x41900000, some 0x41400000, none,
    none] := by
  decide +kernel

/-- The access log of `map2 .fadd 2` on 2 threads, latest first: each thread loads its cell of
buffers 0 and 1 and stores its cell of buffer 2, all in phase 0. -/
example : ((runAll (fun _ => 0) (map2 .fadd 2) 2 (inputs x5 y5)).toOption.map (·.log)) =
    some [⟨1, 2, 1, true, 0⟩, ⟨1, 1, 1, false, 0⟩, ⟨1, 0, 1, false, 0⟩, ⟨0, 2, 0, true, 0⟩,
      ⟨0, 1, 0, false, 0⟩, ⟨0, 0, 0, false, 0⟩] := by
  decide +kernel

/-- info: some [some 1107558400, some 1099956224, some 1094713344, some 1094713344,
some 1099956224] -/
#guard_msgs (whitespace := lax) in
#eval cells2 .fadd 5 6 x5 y5

/-- A count past the inputs' length faults: thread 5 loads a cell of buffer 0 that was never
set. -/
example : cells2 .fadd 6 6 x5 y5 = none := by decide +kernel

/-- `frem` has no IEEE operation, so `map2 .frem` stops with `ub`. -/
example : cells2 .frem 1 1 x5 y5 = none := by decide +kernel

/-- A program written with `do`: load cell 0 of buffer 0 (5), ask for the choice at a site (7),
store their sum in cell 0 of buffer 1. -/
example : (run1 (V := Nat) (fun _ => 7) 0 (do
      let v : Nat ← .vis (.load 0 0) .ret
      let j : Nat ← .vis (.choose ⟨0, 0, .fadd, 0⟩) .ret
      .vis (.store 1 0 (v + j)) .ret)
    ⟨fun b c => if b = 0 ∧ c = 0 then some 5 else none, [], 0⟩).toOption.map (·.2.cells 1 0) =
    some (some 12) := by
  decide

/-! ## A wrong program is refused -/

/-- `vector_addition`'s paths have no `fsub`, so `map2_refines` gives nothing for the
subtraction program at its paths. -/
example : siteStep? Kernels.vadd.paths .fsub = none := by decide +kernel

/-- The subtraction program's output at `x5`, `y5` differs from the addition program's, which
`vadd_tile` relates to `vector_addition`'s, already at cell 0 (`1 - 32` against `1 + 32`). -/
example : cells2 .fsub 5 6 x5 y5 ≠ cells2 .fadd 5 6 x5 y5 := by decide +kernel

/-! ## The tile matrix product -/

/-- `dot_meets` at the 2 × 3 binary32 matrices `tA`, `tB` with all 3 columns: for every flag and
tile oracle, the run of `dot c 3 (byRows 2 2)` on 4 threads from `mats tA tB` ends without a
fault and each of the 4 cells holds a word that meets TorchLean's product (`Meets`). -/
theorem meets_tA3 (c : Bool) (q : Site → Nat) :
    ∃ st, runAll q (dot c 3 (byRows 2 2)) 4 (mats Matmul.tA Matmul.tB) = .ok st ∧
      ∀ t r col, t < 4 → byRows 2 2 t = some (r, col) → ∃ v,
        st.cells 2 (Nat.pair r col) = some v ∧
        Meets Matmul.tA Matmul.tB le_rfl le_rfl r col c (dotOracle q t (Nat.pair r col)) v :=
  dot_meets c le_rfl le_rfl Matmul.tA Matmul.tB (byRows_inj 2 2) q 4

/-- `dot_meets` at `tA`, `tB` with the first 2 of their 3 columns, with the scope of
`meets_tA3`. -/
theorem meets_tA2 (c : Bool) (q : Site → Nat) :
    ∃ st, runAll q (dot c 2 (byRows 2 2)) 4 (mats Matmul.tA Matmul.tB) = .ok st ∧
      ∀ t r col, t < 4 → byRows 2 2 t = some (r, col) → ∃ v,
        st.cells 2 (Nat.pair r col) = some v ∧
        Meets Matmul.tA Matmul.tB (by decide : 2 ≤ 3) (by decide) r col c
          (dotOracle q t (Nat.pair r col)) v :=
  dot_meets c (by decide) (by decide) Matmul.tA Matmul.tB (byRows_inj 2 2) q 4

/-- The words of the cells `(t / p, t % p)`, `t < m p`, of buffer 2 after the run of
`dot c K (byRows m p)` on `m p` threads from `mats A B` at the tile oracle 0 (`none` on a
fault). -/
def dotWords {fmt : FloatFormat} {m p sA sB : Nat} (c : Bool) (K : Nat)
    (A : TorchLean.Tensor (Model fmt) [m, sA]) (B : TorchLean.Tensor (Model fmt) [p, sB]) :
    Option (List (Option Nat)) :=
  (runAll (fun _ => 0) (dot c K (byRows m p)) (m * p) (mats A B)).toOption.map fun s =>
    (List.range (m * p)).map fun t => (s.cells 2 (Nat.pair (t / p) (t % p))).map Model.toNatBits

/-- With all 3 columns, the cells are TorchLean's `tA tBᵀ` (`Matmul.cells`): `-2`, `4`, `-2`,
`13`. -/
example : dotWords false 3 Matmul.tA Matmul.tB =
    some [some 0xc0000000, some 0x40800000, some 0xc0000000, some 0x41500000] := by
  decide +kernel

/-- With the first 2 columns: `1 + 0`, `2 + 2`, `4 + 0`, `8 + 5`. -/
example : dotWords false 2 Matmul.tA Matmul.tB =
    some [some 0x3f800000, some 0x40800000, some 0x40800000, some 0x41500000] := by
  decide +kernel

/-- info: some [some 3221225472, some 1082130432, some 3221225472, some 1095761920] -/
#guard_msgs (whitespace := lax) in
#eval dotWords false 3 Matmul.tA Matmul.tB

/-- A count past the 3 columns faults: thread 0 loads cell `(0, 3)` of buffer 0, never set. -/
example : dotWords false 4 Matmul.tA Matmul.tB = none := by decide +kernel

/-- The placement by rows of 2 × 2 cells: threads 0 to 3 at `(0, 0)`, `(0, 1)`, `(1, 0)`,
`(1, 1)`, thread 4 at none. -/
example : (List.range 5).map (fun t => (byRows 2 2 t).map fun x => (x.1.val, x.2.val)) =
    [some (0, 0), some (0, 1), some (1, 0), some (1, 1), none] := by
  decide

end MojoProofTest.Tile
