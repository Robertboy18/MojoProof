import MojoProof.Kernels.Vadd
import MojoProofTest.Sym
import MojoProofTest.SymLoop

/-!
# `mojo_kernel` on `vector_addition`, on a loop, and its refusals

* `vadd_paths_cmd`: the paths `mojo_kernel` generates for `vector_addition` (`Kernels.vadd.paths`,
  MojoProof/Kernels/Vadd.lean) are `%4 → %21 → %31` and `%4 → %30 → %31` with the
  summaries `sym_summary` gives (MojoProofTest/Sym.lean), in that order.
* `short_clauses`: three clauses for `vector_addition`'s four parameters are refused, so a launch
  built from the clauses passes one value per parameter; `kind_twin`: the count's parameter named
  as a buffer is refused; `ptr_twin`: a buffer's parameter, `byval` of a struct, named by the
  `pointers` clause (a plain pointer's) is refused;
  `map2_twin`: the `map2` clause on clauses of another shape (an input named as an output) is
  refused. The `map2` clause on `vector_addition` itself generates `Kernels.vadd.ret` and
  `Kernels.vadd.correct`, used by `correct23` (MojoProofTest/Kernel.lean) and checked against
  the statements of MojoProofTest/Ops.lean.
* `loop_refused`: a kernel whose block `%loop` branches to itself, with no loop clause, is refused,
  naming the block and the clause that would cover it.
* `cntk`: the loop clause on the counting loop `cnt` of MojoProofTest/SymLoop.lean
  (`for i in [0, n): p[i] = i`, header block 1), with the precondition `cntPre` (`%n = nOf V` at
  most `2 ^ 60`, `%p` at offset 0 of block `bOf V`, room for the cells), the invariant `cntInv`
  (SymLoop's `invN`), the trip count `nOf` and the postcondition `cntPost` (cell `j` holds `j` for
  `j < nOf V`), and a tactic that closes the four obligations by SymLoop's `invN_entry`,
  `invN_step` and `invN_exit`, with `mojo_kernel.share`, so that its blocks' summaries are
  SymLoop's `cntE`, `cntH`, `cntB` and `Kernels.vadd.b3`. `cntk_chains`: the generated sequence of
  loops is SymLoop's `cntL.chain`. `cntk_three`: `cntk.loop` at SymLoop's `start 3` (`%n = 3`,
  `%p` at `outC`'s block), its precondition evaluated, gives the run through the loop to `ret`.
* `cnt_open`: the loop clause with a tactic that closes the round's obligation alone is refused,
  naming the three obligations it leaves (an open goal for the discharger), and adds nothing.
* `paren`: the `map2` clause with the kernel given as the term `(Kernels.vadd.fn_0)`, on
  `parenProg` (`vector_addition`'s program with another digest): the command elaborates the term
  to the constant and generates `paren.ret` and `paren.correct`, whose statement an `example` pins;
  its summaries, paths and arguments are the library's (with the option `mojo_kernel.share`,
  `kernelDef` shares them in a test module too), so the command adds none.
  `app_refused`: with `map2`, a kernel term that is not a constant (`id Kernels.vadd.fn_0`) is
  refused; `globals_refused`: with `map2`, a program with a global (`globalProg`) is refused,
  naming the global.
* A refused command adds nothing: no `b<i>` or `args` of `map2_twin`, `ptr_twin`, `loop_refused`,
  `app_refused` or `globals_refused`, and no summary, path, chain or obligation of `cnt_open`, is
  declared (checked on the environment by `#eval`).

Each test covers the kernel named, not every program.
-/

namespace MojoProofTest.KernelCmd

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.Sym

/-- **The generated paths** of `vector_addition` are its two paths from the entry, through `%21`
and through `%30`, with the summaries `sym_summary` gives. -/
theorem vadd_paths_cmd : Kernels.vadd.paths =
    [(Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddIn,
      (Kernels.vadd.fn_0.b_0.label, Kernels.vadd.b0.obls, Kernels.vadd.b0) :: vaddOut] := rfl

-- `short_clauses`: `vector_addition` has 4 parameters; 3 clauses are refused.
/--
error: mojo_kernel: parameter a3 is named by 0 clauses, not 1 (Kernels.vadd.fn_0)
-/
#guard_msgs in
mojo_kernel short_clauses := Kernels.vadd.prog Kernels.vadd.fn_0
  reads a := a0, b := a1
  writes out := a2

-- `kind_twin`: the count's parameter `a3` named as a buffer is refused.
/--
error: mojo_kernel: clause out := a3: a3 is not byval of a buffer struct (Kernels.vadd.fn_0)
-/
#guard_msgs in
mojo_kernel kind_twin := Kernels.vadd.prog Kernels.vadd.fn_0
  reads a := a0, b := a1
  writes out := a3
  scalars n := a2

-- `ptr_twin`: the output `a2`, `byval` of a buffer struct, named as a plain pointer is refused.
/--
error: mojo_kernel: clause out := a2: a2 is not a pointer without byval (Kernels.vadd.fn_0)
-/
#guard_msgs in
mojo_kernel ptr_twin := Kernels.vadd.prog Kernels.vadd.fn_0
  reads a := a0, b := a1
  scalars n := a3
  pointers out := a2

-- `map2_twin`: the `map2` clause with the input `b` named as a second output is refused.
/--
error: mojo_kernel: map2 needs reads a0, a1, writes a2, scalars a3, an i32 (Kernels.vadd.fn_0)
-/
#guard_msgs in
mojo_kernel map2_twin := Kernels.vadd.prog Kernels.vadd.fn_0
  reads a := a0
  writes b := a1, out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) Kernels.vadd.bytes

/-- A kernel of two blocks with no instruction: `entry` branches to `loop`, which branches to
itself. -/
def loopFn : Func :=
  { Func.ofTerm (.br 1) with
    names := #["entry", "loop"], blocks := #[⟨0, #[], .br 1⟩, ⟨1, #[], .br 1⟩] }

-- `loop_refused`: `loopFn`'s block `%loop` branches to itself, a loop.
/--
error: mojo_kernel: loop at block %loop (block 1 of loopFn) with no loop clause; give its precondition, invariant, trip count and postcondition by loop 1 := pre inv trips post
-/
#guard_msgs in
mojo_kernel loop_refused := (Program.ofFunc loopFn) loopFn

open MojoProofTest.SymLoop (cnt cntP cntL Cells invN invN_entry invN_step invN_exit)

/-- The bound `%n` (register 7) of valuation `V` as a natural number (0 if it is not a bit
vector). -/
def nOf (V : Valuation) : Nat :=
  match V.regs 7 with
  | some (.bits _ x) => x.toNat
  | _ => 0

/-- The block of the pointer `%p` (register 8) of valuation `V` (0 if it is not a pointer). -/
def bOf (V : Valuation) : Nat :=
  match V.regs 8 with
  | some (.ptr q) => q.block
  | _ => 0

/-- The precondition of the counting loop at its entry valuation `V`: `V` is in `cntP` and `cnt`,
`%n` is the `i64` `nOf V ≤ 2 ^ 60`, `%p` is at offset 0 of block `bOf V`, and that block has room
for `nOf V` cells (`Cells` with no cell written). -/
def cntPre (V : Valuation) : Prop :=
  V.ctx.prog = cntP ∧ V.fn = cnt ∧ nOf V ≤ 2 ^ 60 ∧
    V.regs 7 = some (.bits 64 (BitVec.ofNat 64 (nOf V))) ∧ V.regs 8 = some (.ptr ⟨bOf V, 0⟩) ∧
    Cells V.ctx.who (nOf V) (bOf V) 0 V.mem

/-- The invariant of round `i` from entry valuation `V`: SymLoop's `invN` at `V`'s context, bound
and block. -/
def cntInv (V : Valuation) : Nat → Valuation → Prop := invN V.ctx (nOf V) (bOf V)

/-- The postcondition from entry valuation `V`: cell `j` of block `bOf V` holds the `i64` `j` for
every `j < nOf V`. -/
def cntPost (V : Valuation) (me : Mem) : Prop :=
  ∀ j < nOf V, me.load cntP.layout V.ctx.who 1 (.int 64) ⟨bOf V, 8 * j⟩ (some 8) =
    .ok (.bits 64 (BitVec.ofNat 64 j))

-- `cntk`: the loop clause on the counting loop, header block 1; the tactic closes the path into
-- the loop and the invariant at round 0 by `invN_entry`, a round by `invN_step` and the path out
-- by `invN_exit`. With `mojo_kernel.share`, its blocks' summaries are SymLoop's `cntE`, `cntH`,
-- `cntB` and the library's `Kernels.vadd.b3` (the block `ret void`).
set_option mojo_kernel.share true in
mojo_kernel cntk := cntP cnt
  loop 1 := cntPre cntInv nOf cntPost by
    intro V hV
    obtain ⟨hP, hfn, hn, h7, h8, hm⟩ := hV
    first
      | obtain ⟨hW, hd, hpc, -⟩ := invN_entry (c := V.ctx) (k := V.k) (m := V.mem)
          (f := ⟨V.fn, 0, 0, V.regs, V.prods, [], none⟩) hfn h7 h8 hm
        rw [← hfn] at hpc
        exact ⟨hW, hd, hpc⟩
      | exact (invN_entry (c := V.ctx) (k := V.k) (m := V.mem)
          (f := ⟨V.fn, 0, 0, V.regs, V.prods, [], none⟩) hfn h7 h8 hm).2.2.2
      | (intro i hi W hW; exact invN_step hP hn hi hW)
      | (intro W hW; exact invN_exit hn hW)

/-- **The generated sequence of loops** of the counting loop is SymLoop's `cntL.chain`: the entry
block, the loop at header 1 entered at position 1, the round `1 → 2` and the path out `1 → 3`, with
the summaries of `cnt`'s blocks. -/
theorem cntk_chains : cntk.chains = [cntL.chain] := rfl

/-- **The loop clause's run at `%n = 3`**: from SymLoop's `start 3` (`%n = 3`, `%p` at offset 0 of
`outC`'s block of three cells), whose precondition the kernel evaluates, `cntk.loop` runs the
counting loop to `ret` with a memory whose cells 0 to 2 hold 0 to 2 (`cntPost`). It covers this one
valuation. -/
theorem cntk_three : ∃ C ∈ cntk.chains, RetLs (cntPost (SymLoop.start 3)) C.loops
    (SymLoop.start 3) C.l C.ds C.S C.E :=
  cntk.loop (SymLoop.start 3) ⟨rfl, rfl, by decide +kernel, rfl, rfl,
    ⟨by decide +kernel, _, rfl, rfl, rfl, rfl, rfl, by decide +kernel, rfl, nofun⟩⟩ fun _ h => h

-- `cnt_open`: a tactic that closes the round's obligation alone; the command names the three
-- obligations it leaves and adds nothing.
/--
error: mojo_kernel: the loop clause's tactic does not close cnt_open.entry (the path into the loop), cnt_open.init (the invariant at round 0), cnt_open.exit (the path out) for the loop at block %hdr (block 1 of cnt); the command adds nothing
-/
#guard_msgs in
mojo_kernel cnt_open := cntP cnt
  loop 1 := cntPre cntInv nOf cntPost by
    intro V hV
    obtain ⟨hP, -, hn, -, -, -⟩ := hV
    intro i hi W hW
    exact invN_step hP hn hi hW

/-- `vector_addition`'s program with another digest: a program of the same kernel that is not
`Kernels.vadd.prog`, so that the theorems `mojo_kernel paren` generates are not the library's. -/
def parenProg : Program := { Kernels.vadd.prog with sha256 := "paren" }

-- `paren`: the kernel as a parenthesized term, which the command elaborates to its constant;
-- with `mojo_kernel.share`, its definitions are the library's.
set_option mojo_kernel.share true in
mojo_kernel paren := parenProg (Kernels.vadd.fn_0)
  reads a := a0, b := a1
  writes out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) Kernels.vadd.bytes

/-- `paren.covers` is about the library's paths `Kernels.vadd.paths`: the command shares them. -/
example : coversEntry parenProg Kernels.vadd.fn_0 Kernels.vadd.paths = true := paren.covers

/-- **The statement of `paren.correct`**: `Kernel.sound_map2` on `parenProg` and the constant
`Kernels.vadd.fn_0`, for every valid launch whose grid and block have side 1 in `y` and `z`,
alignment that 4 divides, blocks, count, tensors, caller's memory of `Map2.Pre` and oracle, with
the library's arguments `Kernels.vadd.args` and tail `Kernels.vadd.argTail`. It is about this one
kernel. -/
example {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 4 ∣ al) {a b out n N : Nat}
    {x y : TorchLean.Tensor _ [N]} {m : Mem}
    (hP : Map2.Pre parenProg.layout (.fp .float) (Val.ofFloat .float) al Kernels.vadd.argTail m
      a b out n x y) {ω : Nat → Nat → Nat} :
    Kernel.Sound parenProg Kernels.vadd.fn_0 L (Kernels.vadd.args a b out (BitVec.ofNat 32 n)) m
      (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m out (fun i => 4 * i) (Kernels.vadd.bytes ω x y n)
        (volume L.grid * volume L.block)) :=
  paren.correct hL hg hb hal hP

-- `app_refused`: with `map2`, a kernel term that does not elaborate to a constant is refused.
/--
error: mojo_kernel: map2 needs the kernel as a constant; (id Kernels.vadd.fn_0) does not elaborate to one
-/
#guard_msgs in
mojo_kernel app_refused := Kernels.vadd.prog (id Kernels.vadd.fn_0)
  reads a := a0, b := a1
  writes out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) Kernels.vadd.bytes

/-- `vector_addition`'s program with one global, `@g`, an `i32` of address space 1. -/
def globalProg : Program :=
  { Kernels.vadd.prog with
    module := { Kernels.vadd.prog.module with
      globals := #[⟨"g", [], 1, false, .int 32, none, some 4⟩] } }

-- `globals_refused`: with `map2`, a program with globals is refused, naming them.
/--
error: mojo_kernel: map2 needs a program without globals; globalProg has [@g] (Kernels.vadd.fn_0)
-/
#guard_msgs in
mojo_kernel globals_refused := globalProg Kernels.vadd.fn_0
  reads a := a0, b := a1
  writes out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) Kernels.vadd.bytes

-- A refused command adds nothing, and `paren` (with `mojo_kernel.share`) adds none of the
-- library's definitions again: none of these names is declared.
#guard_msgs in
#eval show Lean.Elab.Command.CommandElabM Unit from do
  for c in [`map2_twin.b0, `map2_twin.b3, `map2_twin.args, `map2_twin.paths, `ptr_twin.b0,
      `ptr_twin.paths, `ptr_twin.args, `loop_refused.b0,
      `loop_refused.b1, `app_refused.b0, `globals_refused.b0, `globals_refused.paths,
      `paren.b0, `paren.paths, `paren.args, `paren.argTy, `paren.argTail, `cnt_open.b0,
      `cnt_open.paths, `cnt_open.covers, `cnt_open.chains, `cnt_open.coversChains,
      `cnt_open.step, `cnt_open.loop] do
    if (← Lean.getEnv).contains (`MojoProofTest.KernelCmd ++ c) then
      throwError "{c} is declared"

end MojoProofTest.KernelCmd
