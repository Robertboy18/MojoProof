import MojoProof.Kernels
import MojoProof.Sym.Info

/-!
# The casts the block checker refuses

The checker takes a cast other than `trunc`, `zext` and `sext` only when `castOk` admits its
operator and types (`SState.stmt`, MojoProof/Sym/Checker.lean), which is exactly where `castV`
does not fault with its unsupported-cast message on every operand (`castOk_iff`,
MojoProof/Sym/Block.lean). Tests on hand-built blocks: block `%30` of `vector_addition`
(Kernels.vadd.fn_0.b_2, no statements, a branch to `%31`) with one cast statement on the
kernel's registers `%25` (a `float`, register number 26) and `%19` (an `i64`, number 19), into
register number 28 (printed `%27`):

* `casts_refused`: the checker refuses the block at that statement (`refusal`,
  MojoProof/Sym/Info.lean) for `fptosi float` to `i32`, `fptoui float` to `i32`, `inttoptr i64`
  to `ptr` and the ill-typed `fpext i64` to `float`; `#mojo_info`'s line for each block names the
  statement, its opcode first (`blockLine`, pinned by `#guard_msgs`).
* `sitofp_taken`: the twin, `sitofp i64` to `float` in the same place is in the fragment.
* `fptosi_faults`: `castV` faults on every operand of the `fptosi` (`castOk_iff`), so the
  obligation the checker would have added for it could not hold.
* `bitcast_sizes`: `castOk` is `castV`'s case split, not the checks inside a case: the checker
  takes the ill-typed `bitcast i64` to `i32` in the same place, and `castV` faults on every
  operand of it, so the obligation the checker adds for it holds at no valuation (the summary is
  sound and proves no run there).

Tests of six one-statement blocks of one program; `castOk_iff` covers every operator and type.
-/

namespace MojoProofTest.SymCastOk

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

/-- Block `%30` of `vector_addition` (`Kernels.vadd.fn_0.b_2`) with the single statement `st`:
`st`, then its branch to `%31`. -/
def castBlock (st : Stmt) : LLVM.Block := { Kernels.vadd.fn_0.b_2 with stmts := #[st] }

/-- The statement that casts by `op` the register numbered `r`, of type `s`, to type `t`, into the
register numbered 28 (printed `%27` in `vector_addition`). -/
def castSt (op : CastOp) (s : Ty) (r : Nat) (t : Ty) : Stmt :=
  ⟨some 28, .cast op (.mk s (.loc r)) t, []⟩

/-- **The checker refuses `fptosi`, `fptoui`, `inttoptr` and an ill-typed cast**: in
`vector_addition`'s block `%30` with the single statement `%27 = fptosi float %25 to i32`,
`fptoui float %25 to i32`, `inttoptr i64 %19 to ptr` or `fpext i64 %19 to float`, the first
statement refused is statement 0. -/
theorem casts_refused :
    refusal Kernels.vadd.prog Kernels.vadd.fn_0
      (castBlock (castSt .fptosi (.fp .float) 26 (.int 32))) 0 = some 0 ∧
    refusal Kernels.vadd.prog Kernels.vadd.fn_0
      (castBlock (castSt .fptoui (.fp .float) 26 (.int 32))) 0 = some 0 ∧
    refusal Kernels.vadd.prog Kernels.vadd.fn_0
      (castBlock (castSt .inttoptr (.int 64) 19 (.ptr 0))) 0 = some 0 ∧
    refusal Kernels.vadd.prog Kernels.vadd.fn_0
      (castBlock (castSt .fpext (.int 64) 19 (.fp .float))) 0 = some 0 := by
  decide +kernel

/-- **The twin of `casts_refused`**: with `%27 = sitofp i64 %19 to float` the block is in the
fragment. -/
theorem sitofp_taken :
    refusal Kernels.vadd.prog Kernels.vadd.fn_0
      (castBlock (castSt .sitofp (.int 64) 19 (.fp .float))) 0 = none := by
  decide +kernel

/-- **`fptosi` faults on every operand**: for every layout, memory, operand and choices, `castV`
of `fptosi` from `float` to `i32` is its unsupported-cast fault (`castOk_iff`). -/
theorem fptosi_faults (l : Layout) (m : Mem) (x : Val) (ch : Nat → Nat) :
    castV l m .fptosi (.fp .float) x (.int 32) ch =
      .error (.unsupported "cast (fptoui, fptosi, inttoptr, or ill-typed)") :=
  castOk_iff.1 rfl x

/-- **A `bitcast` between sizes is taken and faults on every operand**: in `vector_addition`'s
block `%30` with the single statement `%27 = bitcast i64 %19 to i32` the checker refuses no
statement (`castOk` admits `bitcast` at every pair of types), and for every layout, memory,
operand and choices, `castV` of that `bitcast` faults. -/
theorem bitcast_sizes {l : Layout} {m : Mem} {ch : Nat → Nat} :
    refusal Kernels.vadd.prog Kernels.vadd.fn_0
        (castBlock (castSt .bitcast (.int 64) 19 (.int 32))) 0 = none ∧
      ∀ x, ∃ e, castV l m .bitcast (.int 64) x (.int 32) ch = .error e := by
  refine ⟨by decide +kernel, fun x => ?_⟩
  cases x
  case bits w b =>
    by_cases hw : w = 64
    · subst hw
      exact ⟨_, by
        simp [castV, bitcast, toBitList, toBitList.scalarBitList, Layout.scalarBits]; rfl⟩
    · exact ⟨_, by
        simp [castV, bitcast, toBitList, toBitList.scalarBitList, Layout.scalarBits, hw]; rfl⟩
  all_goals
    exact ⟨_, by simp [castV, bitcast, toBitList, toBitList.scalarBitList, Layout.scalarBits]; rfl⟩

/-- The line `#mojo_info` prints for block `castBlock st` of `vector_addition`. -/
def castLine (st : Stmt) : IO Unit :=
  IO.println (blockLine Kernels.vadd.prog Kernels.vadd.fn_0 (castBlock st))

/--
info:   %30: 1 statements, 0 phis, to [%31]; outside the fragment at statement 0: %27 = fptosi float %25 to i32
-/
#guard_msgs in
#eval castLine (castSt .fptosi (.fp .float) 26 (.int 32))

/--
info:   %30: 1 statements, 0 phis, to [%31]; outside the fragment at statement 0: %27 = fptoui float %25 to i32
-/
#guard_msgs in
#eval castLine (castSt .fptoui (.fp .float) 26 (.int 32))

/--
info:   %30: 1 statements, 0 phis, to [%31]; outside the fragment at statement 0: %27 = inttoptr i64 %19 to ptr
-/
#guard_msgs in
#eval castLine (castSt .inttoptr (.int 64) 19 (.ptr 0))

/--
info:   %30: 1 statements, 0 phis, to [%31]; outside the fragment at statement 0: %27 = fpext i64 %19 to float
-/
#guard_msgs in
#eval castLine (castSt .fpext (.int 64) 19 (.fp .float))

/-- info:   %30: 1 statements, 0 phis, to [%31]; in the fragment -/
#guard_msgs in
#eval castLine (castSt .sitofp (.int 64) 19 (.fp .float))

end MojoProofTest.SymCastOk
