import MojoProofTest.SymRun
import MojoProof.Kernels.Vadd

/-!
# Special-register call nodes on every valuation

The closed equation of a call node `.call lbl pc` (`SNode.eval`, MojoProof/Sym/Term.lean) that
reads a special register, for every valuation, and its three instances in block `%4` of
`vector_addition`: the nodes that read the thread, which a proof of the kernel for every thread
of a launch evaluates on an abstract valuation.

* `range_attrs`: the return attributes `noundef`, `range(i32 lo, hi)` with `lo < hi` and
  `hi - lo < 2 ^ 32` (`withAttrs`, MojoProof/Sem/Thread.lean) return every 32-bit value in
  `[lo, hi)` unchanged. Its twins: `range_attrs_wide`, at `hi - lo = 2 ^ 32` a value in
  `[lo, hi)` is undefined behavior; `range_attrs_out`, a value outside `[lo, hi)` is.
* `call_sreg`: for every valuation, a call node whose statement calls, with no arguments, a
  declared function that the intrinsic table maps to special register `r` in dimension `d`, whose
  return type is `i32` and return attributes `noundef`, `range(i32 lo, hi)`, evaluates to that
  register's value when the value is in `[lo, hi)`.
* `call47`, `call49`, `call411`: the nodes `(4, 7)` (`tid.x`), `(4, 9)` (`ctaid.x`) and
  `(4, 11)` (`ntid.x`) of `vector_addition`, for every valuation of the kernel whose register is
  in the range the kernel declares.
* `vadd4_calls`: by `vals_getElem?` (MojoProof/Sym/Term.lean), on every such valuation, entries
  7, 9 and 11 of the values of block `%4`'s table are those registers' values, so three of the
  block's 18 obligations, `.ok (.node 7)`, `.ok (.node 9)` and `.ok (.node 11)`, hold.
  `vadd4_calls_launch`: the same on every valuation whose registers are those of a thread of a
  valid launch (`Launch.sreg_bound` gives the ranges).
-/

namespace MojoProofTest.SymCall

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.Sym

/-- **The range attribute on a value in range.** For every layout and memory, and every `lo < hi`
with `hi - lo < 2 ^ 32`: the return attributes `noundef`, `range(i32 lo, hi)` return every 32-bit
value `b` with `lo ≤ b.toNat < hi` unchanged. -/
theorem range_attrs (l : Layout) (m : Mem) (lo hi : Int) (b : BitVec 32)
    (hlh : lo < hi) (hh : hi - lo < 2 ^ 32) (hb : lo ≤ b.toNat ∧ (b.toNat : Int) < hi) :
    withAttrs l m (.int 32) [.flag "noundef", .range (.int 32) lo hi] (.bits 32 b) =
      .ok (.bits 32 b) := by
  have hk : ((b.toNat : Int) - lo) % 4294967296 < (hi - lo) % 4294967296 := by omega
  have hne : ¬ (lo = hi ∧ lo ≠ 0) := fun e => by omega
  simp [withAttrs, List.foldlM, hk, hne, Val.defined]
  rfl

/-- **The twin of `range_attrs`' premise `hi - lo < 2 ^ 32`**: with `range(i32 0, 2 ^ 32)` the
range test `(b - lo) % 2 ^ 32 < (hi - lo) % 2 ^ 32` fails on the value 5, which is in
`[0, 2 ^ 32)`, so `noundef` makes it undefined behavior. -/
theorem range_attrs_wide (l : Layout) (m : Mem) :
    withAttrs l m (.int 32) [.flag "noundef", .range (.int 32) 0 (2 ^ 32)] (.bits 32 5) =
      .error (.ub "noundef value not defined") := rfl

/-- **The twin of `range_attrs`' premise that the value is in range**: with `tid.x`'s attributes
`range(i32 0, 1024)`, the value 1024 is poison, so `noundef` makes it undefined behavior. -/
theorem range_attrs_out (l : Layout) (m : Mem) :
    withAttrs l m (.int 32) [.flag "noundef", .range (.int 32) 0 1024] (.bits 32 1024) =
      .error (.ub "noundef value not defined") := rfl

/-- **A special-register call node.** For every valuation `V` and node values `vs`: if the
statement at position `pc` of block `lbl` calls `g` with no arguments, `g` is declared as `fn`
with return type `i32` and return attributes `noundef`, `range(i32 lo, hi)` (`lo < hi`,
`hi - lo < 2 ^ 32`), the intrinsic table maps `g` to special register `r` in dimension `d`, and
that register's value is below `2 ^ 32` and in `[lo, hi)`, then the node `.call lbl pc` evaluates
to the register's value as a 32-bit value. -/
theorem call_sreg {V : Valuation} (vs : List (Except Fault Val)) {lbl pc : Nat} {dst fm ty md}
    {g : String} {fn : Func} {r d} {lo hi : Int}
    (hs : V.stmt lbl pc = some ⟨dst, .call fm ty (.fn g) [], md⟩)
    (hf : V.ctx.prog.module.funcs.find? (·.name == g) = some fn)
    (hl : V.ctx.prog.intrinsics.lookup g = some (.sreg r d))
    (hr : fn.ret = .int 32) (ha : fn.retAttrs = [.flag "noundef", .range (.int 32) lo hi])
    (hlh : lo < hi) (hh : hi - lo < 2 ^ 32) (hn : V.ctx.env.sreg r d < 2 ^ 32)
    (hb : lo ≤ V.ctx.env.sreg r d ∧ (V.ctx.env.sreg r d : Int) < hi) :
    SNode.eval V vs (.call lbl pc) = .ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg r d))) := by
  simp only [SNode.eval, hs, hf, hl, hr, ha]
  exact range_attrs _ _ _ _ _ hlh hh (by rw [BitVec.toNat_ofNat, Nat.mod_eq_of_lt hn]; exact hb)

/-- **The node `(4, 7)` of `vector_addition`** (`tid.x`, `range(i32 0, 1024)`), on every
valuation of the kernel whose `tid.x` is below 1024. -/
theorem call47 (V : Valuation) (vs : List (Except Fault Val)) (hf : V.fn = Kernels.vadd.fn_0)
    (hP : V.ctx.prog = Kernels.vadd.prog) (h : V.ctx.env.sreg .tid .x < 1024) :
    SNode.eval V vs (.call 4 7) = .ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg .tid .x))) := by
  have hs : V.stmt 4 7 =
      some ⟨some 12, .call {} (.int 32) (.fn "llvm.nvvm.read.ptx.sreg.tid.x") [], []⟩ := by
    rw [Valuation.stmt, hf]; rfl
  obtain ⟨fn, hfn, hr, ha⟩ : ∃ fn,
      Kernels.vadd.prog.module.funcs.find? (·.name == "llvm.nvvm.read.ptx.sreg.tid.x") = some fn ∧
        fn.ret = .int 32 ∧ fn.retAttrs = [.flag "noundef", .range (.int 32) 0 1024] :=
    ⟨_, rfl, rfl, rfl⟩
  exact call_sreg vs hs (by rw [hP]; exact hfn) (by rw [hP]; rfl) hr ha (by decide) (by decide)
    (by omega) (by omega)

/-- **The node `(4, 9)` of `vector_addition`** (`ctaid.x`, `range(i32 0, 2147483647)`), on
every valuation of the kernel whose `ctaid.x` is below 2147483647. -/
theorem call49 (V : Valuation) (vs : List (Except Fault Val)) (hf : V.fn = Kernels.vadd.fn_0)
    (hP : V.ctx.prog = Kernels.vadd.prog) (h : V.ctx.env.sreg .ctaid .x < 2147483647) :
    SNode.eval V vs (.call 4 9) =
      .ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg .ctaid .x))) := by
  have hs : V.stmt 4 9 =
      some ⟨some 14, .call {} (.int 32) (.fn "llvm.nvvm.read.ptx.sreg.ctaid.x") [], []⟩ := by
    rw [Valuation.stmt, hf]; rfl
  obtain ⟨fn, hfn, hr, ha⟩ : ∃ fn,
      Kernels.vadd.prog.module.funcs.find? (·.name == "llvm.nvvm.read.ptx.sreg.ctaid.x") =
        some fn ∧ fn.ret = .int 32 ∧
        fn.retAttrs = [.flag "noundef", .range (.int 32) 0 2147483647] :=
    ⟨_, rfl, rfl, rfl⟩
  exact call_sreg vs hs (by rw [hP]; exact hfn) (by rw [hP]; rfl) hr ha (by decide) (by decide)
    (by omega) (by omega)

/-- **The node `(4, 11)` of `vector_addition`** (`ntid.x`, `range(i32 1, 1025)`), on every
valuation of the kernel whose `ntid.x` is in `[1, 1024]`. -/
theorem call411 (V : Valuation) (vs : List (Except Fault Val)) (hf : V.fn = Kernels.vadd.fn_0)
    (hP : V.ctx.prog = Kernels.vadd.prog)
    (h : 1 ≤ V.ctx.env.sreg .ntid .x ∧ V.ctx.env.sreg .ntid .x ≤ 1024) :
    SNode.eval V vs (.call 4 11) =
      .ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg .ntid .x))) := by
  have hs : V.stmt 4 11 =
      some ⟨some 16, .call {} (.int 32) (.fn "llvm.nvvm.read.ptx.sreg.ntid.x") [], []⟩ := by
    rw [Valuation.stmt, hf]; rfl
  obtain ⟨fn, hfn, hr, ha⟩ : ∃ fn,
      Kernels.vadd.prog.module.funcs.find? (·.name == "llvm.nvvm.read.ptx.sreg.ntid.x") =
        some fn ∧ fn.ret = .int 32 ∧ fn.retAttrs = [.flag "noundef", .range (.int 32) 1 1025] :=
    ⟨_, rfl, rfl, rfl⟩
  exact call_sreg vs hs (by rw [hP]; exact hfn) (by rw [hP]; rfl) hr ha (by decide) (by decide)
    (by omega) (by omega)

/-- **`%4`'s call nodes in its table.** On every valuation of `vector_addition` whose `tid.x`
is below 1024, `ctaid.x` below 2147483647 and `ntid.x` in `[1, 1024]`, entries 7, 9 and 11 of
the values of block `%4`'s table (`Kernels.vadd.b0`, MojoProof/Kernels/Vadd.lean) are the values
of `tid.x`, `ctaid.x` and `ntid.x` (`vals_getElem?` and `call47`, `call49`, `call411`), so the
block's obligations `.ok (.node 7)`, `.ok (.node 9)` and `.ok (.node 11)` hold there. -/
theorem vadd4_calls (V : Valuation) (hf : V.fn = Kernels.vadd.fn_0)
    (hP : V.ctx.prog = Kernels.vadd.prog) (ht : V.ctx.env.sreg .tid .x < 1024)
    (hc : V.ctx.env.sreg .ctaid .x < 2147483647)
    (hn : 1 ≤ V.ctx.env.sreg .ntid .x ∧ V.ctx.env.sreg .ntid .x ≤ 1024) :
    (vals V Kernels.vadd.b0.nodes)[7]? =
      some (.ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg .tid .x)))) ∧
    (vals V Kernels.vadd.b0.nodes)[9]? =
      some (.ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg .ctaid .x)))) ∧
    (vals V Kernels.vadd.b0.nodes)[11]? =
      some (.ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg .ntid .x)))) ∧
    ∀ j ∈ [7, 9, 11], Cond.Holds V (vals V Kernels.vadd.b0.nodes) (.ok (.node j)) := by
  have h7 : (vals V Kernels.vadd.b0.nodes)[7]? =
      some (.ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg .tid .x)))) := by
    rw [vals_getElem?, show Kernels.vadd.b0.nodes[7]? = some (.call 4 7) from rfl]
    exact congrArg some (call47 V _ hf hP ht)
  have h9 : (vals V Kernels.vadd.b0.nodes)[9]? =
      some (.ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg .ctaid .x)))) := by
    rw [vals_getElem?, show Kernels.vadd.b0.nodes[9]? = some (.call 4 9) from rfl]
    exact congrArg some (call49 V _ hf hP hc)
  have h11 : (vals V Kernels.vadd.b0.nodes)[11]? =
      some (.ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg .ntid .x)))) := by
    rw [vals_getElem?, show Kernels.vadd.b0.nodes[11]? = some (.call 4 11) from rfl]
    exact congrArg some (call411 V _ hf hP hn)
  refine ⟨h7, h9, h11, fun j hj => ?_⟩
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hj
  rcases hj with rfl | rfl | rfl
  · exact ⟨_, by simp only [SVal.eval, h7, Option.getD_some]; rfl⟩
  · exact ⟨_, by simp only [SVal.eval, h9, Option.getD_some]; rfl⟩
  · exact ⟨_, by simp only [SVal.eval, h11, Option.getD_some]; rfl⟩

/-- **`%4`'s call nodes on every thread of every valid launch.** For every valid launch `L`
(`Launch.Valid`), every thread number `n` and every valuation of `vector_addition` whose
registers are thread `n`'s (`Launch.env`): entries 7, 9 and 11 of the values of block `%4`'s
table are thread `n`'s `tid.x`, `ctaid.x` and `ntid.x`, and the obligations `.ok (.node 7)`,
`.ok (.node 9)` and `.ok (.node 11)` hold (`vadd4_calls`, its register ranges by
`Launch.sreg_bound`). -/
theorem vadd4_calls_launch {L : Launch} (hL : L.Valid) (n : Nat) (V : Valuation)
    (hf : V.fn = Kernels.vadd.fn_0) (hP : V.ctx.prog = Kernels.vadd.prog)
    (he : V.ctx.env = L.env n) :
    (vals V Kernels.vadd.b0.nodes)[7]? =
      some (.ok (.bits 32 (BitVec.ofNat 32 ((L.env n).sreg .tid .x)))) ∧
    (vals V Kernels.vadd.b0.nodes)[9]? =
      some (.ok (.bits 32 (BitVec.ofNat 32 ((L.env n).sreg .ctaid .x)))) ∧
    (vals V Kernels.vadd.b0.nodes)[11]? =
      some (.ok (.bits 32 (BitVec.ofNat 32 ((L.env n).sreg .ntid .x)))) ∧
    ∀ j ∈ [7, 9, 11], Cond.Holds V (vals V Kernels.vadd.b0.nodes) (.ok (.node j)) := by
  obtain ⟨-, ht⟩ := L.sreg_bound hL n .tid .x
  obtain ⟨-, hc⟩ := L.sreg_bound hL n .ctaid .x
  obtain ⟨hn₁, hn₂⟩ := L.sreg_bound hL n .ntid .x
  simp only [SReg.lo, SReg.hi, Launch.maxGrid, Launch.maxBlock] at ht hc hn₁ hn₂
  rw [← he] at ht hc hn₁ hn₂ ⊢
  exact vadd4_calls V hf hP ht (by omega) ⟨hn₁, by omega⟩

end MojoProofTest.SymCall
