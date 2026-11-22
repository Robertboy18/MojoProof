import Lean
import MojoProof.Sym.Block
import MojoProof.Sym.Kernel
import MojoProof.Sem.Index
import MojoProof.Sem.Precond
import MojoProof.Sem.Buffer
import MojoProof.Sem.FloatRel

/-!
# The obligations of a block summary, node by node

A block summary (`Summary`, MojoProof/Sym/Checker.lean) carries obligations (`Cond`) on the values
of its node table (`vals V S.nodes`): a node evaluates without a fault, a branch condition is a
word, the memory effects run. A path of summaries is walked (`Walk`) when each block's
obligations hold and each exit goes to the next block. The lemmas here reduce these, for every
valuation, program and table, to the semantics' operations on the operands' values, one lemma
per node kind; the tactic mojo_obl (MojoProof/Sym/Obl.lean) chains them over concrete
summaries.

The table, for every valuation `V` and table `ns`:

* `vals_getElem?_eval`: entry `j` of `vals V ns` is `r` when node `j` evaluates to `r` on the
  values of the nodes before it.
* `SVal.eval_node`, `SVal.eval_node_take`: an operand that is node `i` has its entry's value, on
  the table's values and on the values of its first `j > i` nodes; `SVal.eval_reg`: an entry
  register has its value.

The node kinds, for every valuation and node values:

* `SNode.eval_bin`, `SNode.eval_cast`, `SNode.eval_extract`: on words (an aggregate for
  `extractvalue`), the node is what the semantics' `intBin`, `intCast`, `extractV` give of them
  (the closed values follow from MojoProof/Sem/Index.lean's `intBin_add_ofNat` and the others
  under their no-wrap conditions).
* `SNode.eval_icmpV`: an integer comparison node is what `icmpV` gives of its operands' values;
  `SNode.eval_icmp`, `SNode.eval_icmp_slt_ofNat`, `SNode.eval_icmp_ult_ofNat`: of two words of its
  width, `Val.ofBool` of the predicate, and of two small natural numbers' words, of their order
  (`ICmp.slt_ofNat`, `ICmp.ult_ofNat`).
* `SNode.eval_load`, `SNode.eval_load_at`: a `load` node is the value `Mem.load` reads, when that
  read succeeds and the value is defined if the statement says `noundef`.
* `SNode.eval_gep_at`: a `getelementptr` node with one index is what the semantics' `gep` gives
  of its operands' values.
* `SNode.eval_fbin_ofFloat`: a float operator node on two floats of its type, with no
  `fmul contract` factors and without `nnan`, `ninf`, `nsz`, `reassoc`, `arcp` and `afn`, is the
  IEEE operation's result through `deliver` at the node's oracle number.
* `withAttrs_ofNat`: return attributes that are each `noundef` or a `range` of the word's width
  containing `[lo, hi)`, of size below `2 ^ w` (`keepsWord`, a check the kernel evaluates), keep
  every word `k < 2 ^ w` with `lo ≤ k < hi`, for every layout and memory.
  `SNode.eval_sreg`, `SNode.eval_sreg_at`: so a special-register call node evaluates to the
  register's value as a 32-bit word, when the register is in `[r.lo, r.hi d)` (what
  `Launch.sreg_bound` gives on every thread of a valid launch) and the declaration's attributes
  pass `keepsWord`.

The buffers, for every layout and memories with the same blocks:

* `addr_buffer`, `gep_buffer`: in a buffer (`Mem.Buffer`) that fits (its generic address plus its
  size at most `2 ^ (l.ptr 0).1`, 2 to the generic pointer width, which is `Mem.Fits` unfolded),
  offset `o < size` has address `g + o`, and a `getelementptr` from `⟨c, 0⟩` by `K` elements of
  type `src` is `⟨c, K * l.size src⟩`.
* `load_buffer`, `store_buffer`: a load of element `K` of a buffer holding a 1-D tensor `x`
  (`Mem.Holds`, `rowMajor_one`) gives `x K`; a store of an encodable value into element `K` of a
  writable buffer succeeds.

The effects, the exits and the path, for every valuation:

* `SEff.apply_load`, `SEff.apply_load_at`, `SEff.apply_store_ex`, `SEff.foldlM_cons_ok`,
  `SEff.foldlM_cons_ex`, `SEff.foldlM_nil_ex`, `SEff.run_of_fold_ex`: a `load` effect logs its
  access, a `store` effect that writes runs, and a run of effects that each apply runs.
* `Valuation.stmt_of_fn`: the statement of a valuation whose function is `fn` is `fn`'s.
* `Valuation.after_regs_some`, `Valuation.after_regs_none`, `Valuation.after_mem_fold`: the
  registers and memory after a block (the memory by `Valuation.after_mem`).
* `Exit.target_br`, `Exit.target_cond_true`, `Exit.target_cond_false`: a branch goes to its
  target; a conditional branch on `Val.ofBool b` goes where `b` says.
* `Cond.holds_ok`, `Cond.holds_bool`, `Cond.holds_ofBool`, `Cond.holds_mem`: the obligations from
  the values; `Walk.nil'`, `Walk.one`, `Walk.cons2`: a path from its blocks' obligations and exits.

The edges into blocks with `phi`s (`Exit.phi`, `Valuation.into`), for every program, valuation,
label and summary:

* `SVal.eval_int_ofNat`, `evalV_int_ofNat`, `evalV_loc`: an integer constant of a natural number
  is its word; a local operand is its register's value.
* `Exit.dest_of_target`, `Exit.dest_phi_eval`, `Exit.dest_phi_true`, `Exit.dest_phi_false`,
  `Exit.dest_phi_ofBool_true`, `Exit.dest_phi_ofBool_false`: an exit with a target goes there,
  and a branch into blocks with `phi`s goes where its condition's low bit says; `Exit.pc_of_fn`:
  the position it enters at depends only on the function.
* `enter_of_find`, `mapM_phiVal`, `foldl_set_regs`, `enter_of_phiOps`: `enter` into a block whose
  `phi`s have operands `ops` for the edge (`phiOps`, `phiOpsL`), with values `xs` (`evalOps`),
  succeeds, and the frame it gives has those registers set to `xs` (`setRegs`).
* `Valuation.into_regs_phi`: so the registers after an edge into blocks with `phi`s are
  `Valuation.after`'s with the `phi`s' registers set, and at another register `Valuation.after`'s
  (`setRegs_of_forall_ne`); `Valuation.into_regs_br`,
  `Valuation.into_regs_cond`: after another edge they are `Valuation.after`'s;
  `Valuation.into_mem`: the memory is `Valuation.after`'s.
* `WalkI.nil'`, `WalkI.one`, `WalkI.cons2`: a path with `phi`s from its blocks' obligations and
  exits; `forall_lt_zero'`, `forall_lt_succ'`: a statement for every number below a literal from
  each of them (a loop's rounds).

Tests: MojoProofTest/Obl.lean, through mojo_obl.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-! ## The table -/

/-- **Entry `j` from its node.** For every valuation `V`, table `ns` and result `r`: if node `j`
of `ns` is `nd` and `nd` evaluates to `r` on the values of the nodes before it, entry `j` of the
values is `r`. -/
theorem vals_getElem?_eval {V : Valuation} {ns : List SNode} {j : Nat} {nd : SNode}
    {r : Except Fault Val} (hn : ns[j]? = some nd) (he : nd.eval V (vals V (ns.take j)) = r) :
    (vals V ns)[j]? = some r := by
  rw [vals_getElem?, hn]
  exact congrArg some he

/-- An operand that is node `i` has value `v` when entry `i` of the node values is `.ok v`, for
every valuation and node values. -/
theorem SVal.eval_node {V : Valuation} {vs : List (Except Fault Val)} {i : Nat} {v : Val}
    (h : vs[i]? = some (.ok v)) : (SVal.node i).eval V vs = .ok v := by
  simp only [SVal.eval, h, Option.getD_some]

/-- On the values of the first `j` nodes of a table, an operand that is node `i < j` has its
entry's value in the whole table's, for every valuation and table. -/
theorem SVal.eval_node_take {V : Valuation} {ns : List SNode} {i j : Nat} {v : Val}
    (hij : i < j) (h : (vals V ns)[i]? = some (.ok v)) :
    (SVal.node i).eval V (vals V (ns.take j)) = .ok v := by
  rw [vals_getElem? V ns i] at h
  refine SVal.eval_node ?_
  rw [vals_getElem?, List.getElem?_take_of_lt hij, List.take_take]
  rw [Nat.min_eq_left (Nat.le_of_lt hij)]
  exact h

/-- An operand that is entry register `r` has its value, for every valuation and node values. -/
theorem SVal.eval_reg {V : Valuation} {vs : List (Except Fault Val)} {r : Nat} {v : Val}
    (h : V.regs r = some v) : (SVal.reg r).eval V vs = .ok v := by
  simp only [SVal.eval, h]
  rfl

/-! ## Node kinds -/

/-- An integer operator node on two words of its width is what `intBin` gives of them, for every
valuation, operator, flags, node values and result. -/
theorem SNode.eval_bin {V : Valuation} {vs : List (Except Fault Val)} {op : BinOp}
    {fl : IntFlags} {w : Nat} {a b : SVal} {x y : BitVec w} {r : Except Fault Val}
    (ha : a.eval V vs = .ok (.bits w x)) (hb : b.eval V vs = .ok (.bits w y))
    (h : intBin w op fl (.bits w x) (.bits w y) = r) : (SNode.bin op fl w a b).eval V vs = r := by
  subst h
  simp only [SNode.eval, ha, hb]
  rfl

/-- An integer cast node on a word is what `intCast` gives of it, for every valuation, cast, node
values and result. -/
theorem SNode.eval_cast {V : Valuation} {vs : List (Except Fault Val)} {op : CastOp}
    {w w' : Nat} {a : SVal} {x : BitVec w'} {r : Except Fault Val}
    (ha : a.eval V vs = .ok (.bits w' x)) (h : intCast op w (.bits w' x) = r) :
    (SNode.cast op w a).eval V vs = r := by
  subst h
  simp only [SNode.eval, ha]
  rfl

/-- An `extractvalue` node is what `extractV` gives of its operand's value, for every valuation,
indices, node values and result. -/
theorem SNode.eval_extract {V : Valuation} {vs : List (Except Fault Val)} {is : List Nat}
    {a : SVal} {v : Val} {r : Except Fault Val} (ha : a.eval V vs = .ok v)
    (h : extractV v is = r) : (SNode.extract is a).eval V vs = r := by
  subst h
  simp only [SNode.eval, ha]
  rfl

/-- An integer comparison node is what `icmpV` gives of its operands' values, at a valuation
whose program is `P` and memory `M`, for every predicate, width, node values and result. -/
theorem SNode.eval_icmpV {V : Valuation} {vs : List (Except Fault Val)} {P : Program} {M : Mem}
    {p : ICmp} {w : Nat} {a b : SVal} {u u' : Val} {r : Except Fault Val} (hP : V.ctx.prog = P)
    (hM : V.mem = M) (ha : a.eval V vs = .ok u) (hb : b.eval V vs = .ok u')
    (h : icmpV P.layout M p (.int w) u u' = r) : (SNode.icmp p w a b).eval V vs = r := by
  subst hP hM h
  simp only [SNode.eval, ha, hb]
  rfl

/-- An integer comparison node on two words of its width is `Val.ofBool` of the predicate, for
every valuation, predicate and node values. -/
theorem SNode.eval_icmp {V : Valuation} {vs : List (Except Fault Val)} {p : ICmp} {w : Nat}
    {a b : SVal} {x y : BitVec w} (ha : a.eval V vs = .ok (.bits w x))
    (hb : b.eval V vs = .ok (.bits w y)) :
    (SNode.icmp p w a b).eval V vs = .ok (.ofBool (p.holds x y)) := by
  refine SNode.eval_icmpV rfl rfl ha hb ?_
  show ((if h : w = w then pure (Val.ofBool (p.holds x (y.cast h)))
    else throw (Fault.unsupported "icmp operands of different widths")) : Except Fault Val) = _
  rw [dite_eq_left rfl, BitVec.cast_eq]
  rfl

/-- **A `load` node.** For every valuation and node values: if the statement at `(lbl, pc)` is a
`load` of type `t` through address space `a`, the operand is the pointer `q`, `Mem.load` reads
`v` there from the entry memory, and `v` is defined if the statement's metadata says `noundef`,
the node evaluates to `v`. -/
theorem SNode.eval_load {V : Valuation} {vs : List (Except Fault Val)} {lbl pc : Nat} {p : SVal}
    {dst : Option Nat} {vol : Bool} {t : Ty} {a : Nat} {pv : Value} {al : Option Nat}
    {md : List (String × Nat)} {q : Ptr} {v : Val}
    (hs : V.stmt lbl pc = some ⟨dst, .load vol t (.mk (.ptr a) pv) al, md⟩)
    (hp : p.eval V vs = .ok (.ptr q))
    (hl : V.mem.load V.ctx.prog.layout V.ctx.who a t q
      (some (al.getD (V.ctx.prog.layout.align t))) = .ok v)
    (hu : (md.any (·.1 == "noundef") && !v.defined) = false) :
    (SNode.load lbl pc p).eval V vs = .ok v := by
  simp only [SNode.eval, hs]
  refine Except.bind_eq_ok.2 ⟨.ptr q, hp, Except.bind_eq_ok.2 ⟨q, rfl,
    Except.bind_eq_ok.2 ⟨v, hl, ?_⟩⟩⟩
  simp only [hu]
  rfl

/-- A fold in `Except` whose step keeps `x` on every element returns `x`. -/
theorem foldlM_fix {ε α β : Type} {f : β → α → Except ε β} {x : β} :
    ∀ {as : List α}, (∀ a ∈ as, f x a = .ok x) → as.foldlM f x = .ok x
  | [], _ => rfl
  | a :: as, h => by
    rw [List.foldlM_cons, h a (by simp)]
    exact foldlM_fix fun b hb => h b (List.mem_cons_of_mem a hb)

/-- Whether return attribute `a` keeps every word of width `w` in `[lo, hi)`: `noundef`, or a
`range` of width `w` containing `[lo, hi)` of size below `2 ^ w`. -/
def keepsWord (w lo hi : Nat) (a : Attr) : Bool :=
  match a with
  | .flag s => decide (s = "noundef")
  | .range (.int w') l h => decide (w' = w ∧ l ≤ lo ∧ (hi : Int) ≤ h ∧ h - l < 2 ^ w)
  | _ => false

/-- **Return attributes on a word in range.** For every layout and memory, width `w`, bounds
`lo`, `hi` and attributes that each pass `keepsWord w lo hi`: `withAttrs` returns every word
`k < 2 ^ w` with `lo ≤ k < hi` unchanged. -/
theorem withAttrs_ofNat {l : Layout} {m : Mem} {w k lo hi : Nat} {attrs : List Attr}
    (hw : k < 2 ^ w) (hk : lo ≤ k ∧ k < hi) (ha : ∀ a ∈ attrs, keepsWord w lo hi a = true) :
    withAttrs l m (.int w) attrs (.bits w (BitVec.ofNat w k)) =
      .ok (.bits w (BitVec.ofNat w k)) := by
  have hd : (Val.bits w (BitVec.ofNat w k)).defined = true := rfl
  simp only [withAttrs]
  rw [foldlM_fix]
  · refine Except.bind_eq_ok.2 ⟨_, rfl, ?_⟩
    simp only [hd, Bool.not_true, Bool.and_false]
    rfl
  · intro a hA'
    have hA := ha a hA'
    cases a
    case flag s =>
      have hs : s = "noundef" := of_decide_eq_true hA
      subst hs
      rfl
    case range t lo' hi' =>
      cases t
      case int w' =>
        obtain ⟨e, h1, h2, h3⟩ := of_decide_eq_true hA
        subst w'
        have hb : (BitVec.ofNat w k).toNat = k := by
          rw [BitVec.toNat_ofNat, Nat.mod_eq_of_lt hw]
        have hp : (k : Int) < 2 ^ w := by exact_mod_cast hw
        have hne : ¬ (lo' = hi' ∧ lo' ≠ 0) := fun e => by omega
        have hlt : (((BitVec.ofNat w k).toNat : Int) - lo') % (2 ^ w : Int) <
            (hi' - lo') % (2 ^ w : Int) := by
          rw [hb, Int.emod_eq_of_lt (by omega) (by omega), Int.emod_eq_of_lt (by omega) (by omega)]
          omega
        dsimp only
        rw [ite_eq_right (fun e : w ≠ w => e rfl), ite_eq_right hne, ite_eq_left hlt]
        rfl
      all_goals cases hA
    all_goals cases hA

/-- **A special-register call node.** For every valuation and node values: if the statement at
`(lbl, pc)` calls `g` with no arguments, the program `P` declares `g` as `fn` returning `i32`
with attributes that pass `keepsWord 32 r.lo (r.hi d)`, its intrinsic table maps `g` to register
`r` in dimension `d`, `r.hi d ≤ 2 ^ 32`, and the register of the context's thread is in
`[r.lo, r.hi d)`, the node evaluates to that register's value as a 32-bit word. -/
theorem SNode.eval_sreg {V : Valuation} (vs : List (Except Fault Val)) {lbl pc : Nat}
    {P : Program} {dst : Option Nat} {fm : FastMath} {ty : Ty} {md : List (String × Nat)}
    {g : String} {fn : Func} {r : SReg} {d : Dim} (hP : V.ctx.prog = P)
    (hs : V.stmt lbl pc = some ⟨dst, .call fm ty (.fn g) [], md⟩)
    (hf : P.module.funcs.find? (·.name == g) = some fn)
    (hl : P.intrinsics.lookup g = some (.sreg r d)) (hr : fn.ret = .int 32)
    (hA : ∀ a ∈ fn.retAttrs, keepsWord 32 r.lo (r.hi d) a = true) (hk : r.hi d ≤ 2 ^ 32)
    (hb : r.lo ≤ V.ctx.env.sreg r d ∧ V.ctx.env.sreg r d < r.hi d) :
    (SNode.call lbl pc).eval V vs = .ok (.bits 32 (BitVec.ofNat 32 (V.ctx.env.sreg r d))) := by
  subst hP
  simp only [SNode.eval, hs, hf, hl, hr]
  exact withAttrs_ofNat (by omega) hb hA

/-! ## Effects and exits -/

/-- The statement at `(lbl, pc)` of a valuation whose function is `fn` is `fn`'s. -/
theorem Valuation.stmt_of_fn {V : Valuation} {fn : Func} {lbl pc : Nat} {st : Stmt}
    (hF : V.fn = fn) (h : (fn.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) = some st) :
    V.stmt lbl pc = some st := by
  rw [Valuation.stmt, hF]
  exact h

/-- **A `load` effect** through the pointer `q` logs its access, on every memory, for every
valuation and node values. -/
theorem SEff.apply_load {V : Valuation} {vs : List (Except Fault Val)} {m : Mem} {lbl pc : Nat}
    {p : SVal} {dst : Option Nat} {vol : Bool} {t : Ty} {a : Nat} {pv : Value} {al : Option Nat}
    {md : List (String × Nat)} {q : Ptr}
    (hs : V.stmt lbl pc = some ⟨dst, .load vol t (.mk (.ptr a) pv) al, md⟩)
    (hp : p.eval V vs = .ok (.ptr q)) :
    (SEff.load lbl pc p).apply V vs m = .ok (m.log (.access ⟨V.ctx.who, q,
      V.ctx.prog.layout.stored t, false, none, md.any (·.1 == "invariant.load")⟩)) := by
  simp only [SEff.apply, hs]
  exact Except.bind_eq_ok.2 ⟨_, hp, rfl⟩

/-- A run of effects `e :: es` from memory `m`, where `e` applies to `m` giving `m₁`, and `es`
runs from `m₁` to `m₂`, gives `m₂`, for every valuation and node values. -/
theorem SEff.foldlM_cons_ok {V : Valuation} {vs : List (Except Fault Val)} {e : SEff}
    {es : List SEff} {m m₁ m₂ : Mem} (h : e.apply V vs m = .ok m₁)
    (h' : es.foldlM (SEff.apply V vs) m₁ = .ok m₂) :
    (e :: es).foldlM (SEff.apply V vs) m = .ok m₂ := by
  rw [List.foldlM_cons, h]
  exact h'

/-- A conditional branch whose condition is a word goes to `d` if its low bit is set, else to
`e`, for every valuation and node values. -/
theorem Exit.target_cond {V : Valuation} {vs : List (Except Fault Val)} {c : SVal}
    {d e w : Nat} {b : BitVec w} (h : c.eval V vs = .ok (.bits w b)) :
    (Exit.cond c d e).target V vs = some (if b.getLsbD 0 then d else e) := by
  simp only [Exit.target, h]

/-! ## Buffers -/

/-- The generic address of offset `o < size` in a buffer that fits is its base `g` plus `o`, for
every layout, memory, buffer and offset; `g + size ≤ 2 ^ (l.ptr 0).1` (the generic pointer width)
and `al ∣ g`. -/
theorem addr_buffer {l : Layout} {m : Mem} {c size al o : Nat} {w : Bool}
    (hB : m.Buffer c size al w)
    (hF : ∃ blk, m.blocks c = some blk ∧ blk.gaddr + size ≤ 2 ^ (l.ptr 0).1) (ho : o < size) :
    ∃ g, m.addr l 0 ⟨c, (o : Int)⟩ = .ok (g + o) ∧ g + size ≤ 2 ^ (l.ptr 0).1 ∧ al ∣ g := by
  obtain ⟨blk, hb, hsp, -, -, -, -, -, hga⟩ := hB
  obtain ⟨blk', hb', hg⟩ := hF
  rw [hb] at hb'
  cases hb'
  have hlt : blk.gaddr + o < 2 ^ (l.ptr 0).1 := by omega
  by_cases h0 : c = 0
  · subst h0
    refine ⟨0, ?_, by omega, Nat.dvd_zero al⟩
    have h1 : ((o : Int) % 2 ^ (l.ptr 0).1) = o :=
      Int.emod_eq_of_lt (by omega) (by exact_mod_cast (show o < 2 ^ (l.ptr 0).1 by omega))
    simp only [Mem.addr, ite_true, h1, Int.toNat_natCast, Nat.zero_add]
    rfl
  · refine ⟨blk.gaddr, ?_, hg, hga⟩
    have h1 : (((blk.gaddr : Int) + o) % 2 ^ (l.ptr 0).1) = ((blk.gaddr + o : Nat) : Int) := by
      rw [Int.emod_eq_of_lt (by omega) (by exact_mod_cast hlt)]
      push_cast; rfl
    simp only [Mem.addr, h0, ite_false, Mem.block, hb, hsp]
    simp only [show ¬ (0 = 1) from by decide, ite_false, or_true, ite_true, h1, Int.toNat_natCast]
    rfl

/-- Two memories with the same blocks give every pointer the same address. -/
theorem Mem.addr_blocks {l : Layout} {M m : Mem} (h : M.blocks = m.blocks) (a : Nat) (p : Ptr) :
    M.addr l a p = m.addr l a p := by
  simp only [Mem.addr, Mem.block, h]

/-- **A `getelementptr` into a buffer.** For every layout, memories with the same blocks, flags,
element type `src`, buffer `c` of `size` bytes that fits, width `w` and index `K` with
`K * l.size src < size`, `w ≤ (l.ptr 0).1` (the generic pointer width), `2 * K < 2 ^ w` and
`2 * (K * l.size src) < 2 ^ (l.ptr 0).1`: the `gep` in memory `M`, address space 0, from
`⟨c, 0⟩` by the `w`-bit word `K` is the pointer `⟨c, K * l.size src⟩`. -/
theorem gep_buffer {l : Layout} {M m : Mem} {fl : GepFlags} {src : Ty} {c size al K w : Nat}
    {wr : Bool} (hMb : M.blocks = m.blocks) (hB : m.Buffer c size al wr)
    (hF : ∃ blk, m.blocks c = some blk ∧ blk.gaddr + size ≤ 2 ^ (l.ptr 0).1)
    (hw : w ≤ (l.ptr 0).1) (hK : 2 * K < 2 ^ w) (hs : 2 * (K * l.size src) < 2 ^ (l.ptr 0).1)
    (hin : K * l.size src < size) :
    gep l M fl src 0 [.bits w (BitVec.ofNat w K)] (.ptr ⟨c, 0⟩) =
      .ok (.ptr ⟨c, ((K * l.size src : Nat) : Int)⟩) := by
  obtain ⟨g, hg, hgs, -⟩ := addr_buffer (o := 0) hB hF (by omega)
  obtain ⟨blk, hb, -, -, -, -, hsz, -, -⟩ := hB
  have hA : M.addr l 0 ⟨c, 0⟩ = .ok g := by rw [Mem.addr_blocks hMb]; simpa using hg
  have hti : (BitVec.ofNat w K).toInt = K := BitVec.toInt_ofNat_of_lt hK
  have htn : (BitVec.ofNat w K).toNat = K := by
    rw [BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega)]
  have hMB : M.block ⟨c, 0⟩ = some blk := by simp [Mem.block, hMb, hb]
  have hpow : (2 : Int) ^ (l.ptr 0).1 = ((2 ^ (l.ptr 0).1 : Nat) : Int) := by push_cast; rfl
  have hout : outS (l.ptr 0).1 ((K * l.size src : Nat) : Int) = false := outS_of_lt hs
  have hbm : Int.bmod ((K * l.size src : Nat) : Int) (2 ^ (l.ptr 0).1) =
      ((K * l.size src : Nat) : Int) := by
    generalize hWd : 2 ^ (l.ptr 0).1 = W at hs
    have hx0 : (0 : Int) ≤ ((K * l.size src : Nat) : Int) := by omega
    have hxW : ((K * l.size src : Nat) : Int) < (W : Int) := by omega
    rw [Int.bmod_def, Int.emod_eq_of_lt hx0 hxW, ite_eq_left (by omega)]
  have hKW : K < 2 ^ (l.ptr 0).1 := by
    have := Nat.pow_le_pow_right (by decide : 0 < 2) hw
    omega
  have hgK : ¬ ((g : Int) + ((K * l.size src : Nat) : Int) ≥ 2 ^ (l.ptr 0).1) := by
    rw [hpow]; omega
  have hgK' : ¬ (((K * l.size src : Nat) : Int) ≥ 2 ^ (l.ptr 0).1) := by
    rw [hpow]; omega
  have hsz' : ¬ (((K * l.size src : Nat) : Int) > blk.size) := by omega
  simp [gep, gepPtr, hw, hti, htn, hA, hMB, gepSteps, gepSteps.into, bind, Except.bind,
    pure, Except.pure, hKW]
  have e : ((K : Int) * (l.size src : Int)) = ((K * l.size src : Nat) : Int) := by push_cast; rfl
  rw [e, hbm]
  split
  · next hc =>
    exfalso
    rw [hpow] at hc
    rcases hc with (⟨-, h | h | h⟩ | ⟨-, h | h⟩) | ⟨-, h | h | h⟩
    all_goals first | omega | (rw [hout] at h; cases h)
  · rfl


/-- The row-major offset of element `K` of a one-dimensional tensor is `K` elements. -/
theorem rowMajor_one {l : Layout} {t : Ty} {N K : Nat} (hK : K < N) :
    rowMajor (s := [N]) l t 0 (⟨K, hK⟩, ()) = K * l.size t := by
  have h0 : (TorchLean.Shape.Coord.linearize (s := []) ()).val = 0 := by
    have := (TorchLean.Shape.Coord.linearize (s := []) ()).isLt
    simp [TorchLean.Shape.size] at this
    omega
  have h1 := TorchLean.Shape.Coord.linearize_cons_val (n := N) (s := []) ⟨K, hK⟩ ()
  unfold rowMajor
  erw [h1, h0]
  simp [TorchLean.Shape.size]

/-- **A load from a buffer holding a tensor.** For every layout, memories with the same blocks,
buffer `c` of `size` bytes that fits and holds the 1-D tensor `x` row-major, alignment `A`
dividing the buffer's and the element size, and element `K < N` within the buffer: the load of
element `K` gives `x K`, for every thread. -/
theorem load_buffer {α : Type} [TorchLean.Storage α] {l : Layout} {M m : Mem}
    {c size al A K N : Nat} {wr : Bool} {t : Ty} {enc : α → Val} {x : TorchLean.Tensor α [N]}
    {who : Who} (hMb : M.blocks = m.blocks) (hB : m.Buffer c size al wr)
    (hF : ∃ blk, m.blocks c = some blk ∧ blk.gaddr + size ≤ 2 ^ (l.ptr 0).1)
    (hH : m.Holds l c t enc (rowMajor l t 0) x) (hA : A ∣ al)
    (hAs : A ∣ l.size t) (hK : K < N) (hin : K * l.size t < size) :
    M.load l who 0 t ⟨c, ((K * l.size t : Nat) : Int)⟩ (some A) = .ok (enc (x (⟨K, hK⟩, ()))) := by
  obtain ⟨g, hg, -, hga⟩ := addr_buffer hB hF hin
  obtain ⟨blk, hb, -, hl, ho, -, -, -, -⟩ := hB
  obtain ⟨blk', hb', hh⟩ := hH
  rw [hb] at hb'
  cases hb'
  have hb2 : M.blocks c = some blk := by rw [hMb]; exact hb
  have e := rowMajor_one (l := l) (t := t) hK
  have := Mem.load_holds (l := l) (w := who) (a := 0) (al := some A) hb2 hh hl (by rw [ho]; rfl)
    (⟨K, hK⟩, ()) (ad := g + K * l.size t) (by rw [e, Mem.addr_blocks hMb]; exact hg)
    (by
      intro k hk
      cases hk
      exact Nat.mod_eq_zero_of_dvd
        (Nat.dvd_add (Nat.dvd_trans hA hga) (Nat.dvd_mul_left_of_dvd hAs K)))
  rw [e] at this
  exact this

/-- **A store into a writable buffer.** For every layout, memories with the same blocks, writable
buffer `c` of `size` bytes that fits, alignment `A` dividing the buffer's and the element size,
value `v` the layout encodes, and element `K` within the buffer: the store of `v` at element `K`
succeeds, for every thread. -/
theorem store_buffer {l : Layout} {M m : Mem} {c size al A K : Nat} {t : Ty} {v : Val} {who : Who}
    (hMb : M.blocks = m.blocks) (hB : m.Buffer c size al true)
    (hF : ∃ blk, m.blocks c = some blk ∧ blk.gaddr + size ≤ 2 ^ (l.ptr 0).1)
    (hA : A ∣ al) (hAs : A ∣ l.size t) (he : (l.encode t v).isSome = true)
    (hin : K * l.size t < size) (hin' : K * l.size t + l.size t ≤ size) :
    ∃ M', M.store l who 0 t v ⟨c, ((K * l.size t : Nat) : Int)⟩ (some A) = .ok M' := by
  obtain ⟨bs, he⟩ := Option.isSome_iff_exists.1 he
  obtain ⟨g, hg, -, hga⟩ := addr_buffer hB hF hin
  obtain ⟨blk, hb, -, hl, ho, hro, hsz, -, -⟩ := hB
  have hlen := Layout.encode_length l t v bs he
  have hst := Layout.stored_le_size l t
  have hb2 : M.blocks c = some blk := by rw [hMb]; exact hb
  have hc := Mem.check_ok (l := l) (w := who) (a := 0) (n := bs.length) (al := some A)
    (p := ⟨c, ((K * l.size t : Nat) : Int)⟩) hb2 hl (by rw [ho]; rfl) (Int.natCast_nonneg _)
    (by simp only; omega) (by rw [Mem.addr_blocks hMb]; exact hg)
    (by
      intro k hk
      cases hk
      exact Nat.mod_eq_zero_of_dvd
        (Nat.dvd_add (Nat.dvd_trans hA hga) (Nat.dvd_mul_left_of_dvd hAs K)))
  have hw := Mem.write_of_check hc (by rw [hro]; rfl)
  exact ⟨_, by simp only [Mem.store, he, hw]; rfl⟩

/-! ## Statements, registers and memory along a path -/

/-- After a block, a register the block sets to operand `x` has `x`'s value on the block's node
values (`vals V S.nodes`), for every valuation and summary. -/
theorem Valuation.after_regs_some {V : Valuation} {S : Summary} {r : Nat} {x : SVal} {v : Val}
    (hl : S.regs.lookup r = some x) (hx : x.eval V (vals V S.nodes) = .ok v) :
    (V.after S).regs r = some v := by
  simp only [Valuation.after, regVal, hl, hx]
  rfl

/-- After a block, a register the block does not set has its value at the block entry, for every
valuation and summary. -/
theorem Valuation.after_regs_none {V : Valuation} {S : Summary} {r : Nat} {v : Val}
    (hl : S.regs.lookup r = none) (h : V.regs r = some v) : (V.after S).regs r = some v := by
  simp only [Valuation.after, regVal, hl, h]

/-- After a block whose effects' fold from the valuation's memory `M` gives `M'`, the memory is
`M'`, for every valuation and summary (`Valuation.after_mem` on the fold). -/
theorem Valuation.after_mem_fold {V : Valuation} {S : Summary} {M M' : Mem} (hM : V.mem = M)
    (h : S.effs.foldlM (SEff.apply V (vals V S.nodes)) M = .ok M') : (V.after S).mem = M' :=
  Valuation.after_mem (by rw [SEff.run, hM]; exact h)

/-! ## Obligations and paths -/

/-- An operand with a value meets `Cond.ok`. -/
theorem Cond.holds_ok {V : Valuation} {vs : List (Except Fault Val)} {x : SVal} {v : Val}
    (h : x.eval V vs = .ok v) : (Cond.ok x).Holds V vs := ⟨v, h⟩

/-- An operand whose value is a word meets `Cond.bool`. -/
theorem Cond.holds_bool {V : Valuation} {vs : List (Except Fault Val)} {x : SVal} {w : Nat}
    {b : BitVec w} (h : x.eval V vs = .ok (.bits w b)) : (Cond.bool x).Holds V vs := ⟨w, b, h⟩

/-- An operand whose value is a boolean meets `Cond.bool`. -/
theorem Cond.holds_ofBool {V : Valuation} {vs : List (Except Fault Val)} {x : SVal} {b : Bool}
    (h : x.eval V vs = .ok (.ofBool b)) : (Cond.bool x).Holds V vs := ⟨1, _, h⟩

/-- Effects that run meet `Cond.mem`. -/
theorem Cond.holds_mem {V : Valuation} {vs : List (Except Fault Val)} {es : List SEff}
    (h : ∃ M, SEff.run V vs es = .ok M) : (Cond.mem es).Holds V vs := h

/-- Every predicate holds of every obligation of the empty list. -/
theorem forall_mem_nil' (P : Cond → Prop) : ∀ d ∈ ([] : List Cond), P d :=
  fun _ h => absurd h List.not_mem_nil

/-- A predicate holds of every obligation of `d :: ds` if it holds of `d` and of those of `ds`. -/
theorem forall_mem_cons' {P : Cond → Prop} {d : Cond} {ds : List Cond} (h : P d)
    (t : ∀ x ∈ ds, P x) : ∀ x ∈ d :: ds, P x :=
  List.forall_mem_cons.2 ⟨h, t⟩

/-- The empty path walks from every valuation. -/
theorem Walk.nil' (V : Valuation) : Walk V [] := trivial

/-- A path of one block walks if its obligations hold. -/
theorem Walk.one {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    (h : ∀ d ∈ ds, d.Holds V (vals V S.nodes)) : Walk V [(l, ds, S)] := h

/-- A path of two blocks or more walks if the first block's obligations hold, its exit goes to
the second block's label, and the rest walks from the valuation after the first block. -/
theorem Walk.cons2 {V : Valuation} {l l' : Nat} {ds ds' : List Cond} {S S' : Summary}
    {ps : List (Nat × List Cond × Summary)} (h1 : ∀ d ∈ ds, d.Holds V (vals V S.nodes))
    (h2 : S.exit.target V (vals V S.nodes) = some l')
    (h3 : Walk (V.after S) ((l', ds', S') :: ps)) :
    Walk V ((l, ds, S) :: (l', ds', S') :: ps) := ⟨h1, h2, h3⟩

/-! ## Runs of effects -/

/-- Effects whose fold from the valuation's memory succeeds run. -/
theorem SEff.run_of_fold_ex {V : Valuation} {vs : List (Except Fault Val)} {es : List SEff}
    {M : Mem} (hM : V.mem = M) (h : ∃ M', es.foldlM (SEff.apply V vs) M = .ok M') :
    ∃ M', SEff.run V vs es = .ok M' := by
  rw [SEff.run, hM]
  exact h

/-- No effects leave the memory unchanged. -/
theorem SEff.foldlM_nil_ok {V : Valuation} {vs : List (Except Fault Val)} (M : Mem) :
    ([] : List SEff).foldlM (SEff.apply V vs) M = .ok M := rfl

/-- Effects `e :: es` run from `m` if `e` gives `m₁` and `es` run from `m₁`. -/
theorem SEff.foldlM_cons_ex {V : Valuation} {vs : List (Except Fault Val)} {e : SEff}
    {es : List SEff} {m m₁ : Mem} (h : e.apply V vs m = .ok m₁)
    (h' : ∃ m₂, es.foldlM (SEff.apply V vs) m₁ = .ok m₂) :
    ∃ m₂, (e :: es).foldlM (SEff.apply V vs) m = .ok m₂ := by
  obtain ⟨m₂, h₂⟩ := h'
  exact ⟨m₂, SEff.foldlM_cons_ok h h₂⟩

/-- Effects `e :: es` run from `m` if `e` runs from `m` and `es` run from every memory. -/
theorem SEff.foldlM_cons_all {V : Valuation} {vs : List (Except Fault Val)} {e : SEff}
    {es : List SEff} {m : Mem} (h : ∃ m₁, e.apply V vs m = .ok m₁)
    (h' : ∀ m₁, ∃ m₂, es.foldlM (SEff.apply V vs) m₁ = .ok m₂) :
    ∃ m₂, (e :: es).foldlM (SEff.apply V vs) m = .ok m₂ := by
  obtain ⟨m₁, h₁⟩ := h
  exact SEff.foldlM_cons_ex h₁ (h' m₁)

/-- **A `store` effect** of `x` through `q` succeeds when the semantics' store of `x` at `q` (at
the statement's type and alignment) succeeds, for every valuation, node values and memory, at a
valuation whose function is `F` and program is `P`. -/
theorem SEff.apply_store_ex {V : Valuation} {vs : List (Except Fault Val)} {m : Mem}
    {P : Program} {F : Func} {lbl pc : Nat} {v p : SVal} {dst : Option Nat} {vol : Bool} {t : Ty}
    {pv : Value} {a : Nat} {pv' : Value} {al : Option Nat} {md : List (String × Nat)} {x : Val}
    {q : Ptr} (hF : V.fn = F) (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .store vol (.mk t pv) (.mk (.ptr a) pv') al, md⟩)
    (hv : v.eval V vs = .ok x) (hp : p.eval V vs = .ok (.ptr q))
    (h : ∃ M', m.store P.layout V.ctx.who a t x q (some (al.getD (P.layout.align t))) = .ok M') :
    ∃ M', (SEff.store lbl pc v p).apply V vs m = .ok M' := by
  subst hP
  simp only [SEff.apply, Valuation.stmt_of_fn hF hs, hv, hp]
  exact h

/-! ## Node kinds at a known program -/

/-- **A `load` node**, at a valuation whose function is `F` and program is `P`. -/
theorem SNode.eval_load_at {V : Valuation} {vs : List (Except Fault Val)} {P : Program}
    {F : Func} {lbl pc : Nat} {p : SVal} {dst : Option Nat} {vol : Bool} {t : Ty} {a : Nat}
    {pv : Value} {al : Option Nat} {md : List (String × Nat)} {q : Ptr} {v : Val}
    (hF : V.fn = F) (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .load vol t (.mk (.ptr a) pv) al, md⟩)
    (hp : p.eval V vs = .ok (.ptr q))
    (hl : V.mem.load P.layout V.ctx.who a t q (some (al.getD (P.layout.align t))) = .ok v)
    (hu : (md.any (·.1 == "noundef") && !v.defined) = false) :
    (SNode.load lbl pc p).eval V vs = .ok v := by
  subst hP
  exact SNode.eval_load (Valuation.stmt_of_fn hF hs) hp hl hu

/-- **A `load` effect**, at a valuation whose function is `F`. -/
theorem SEff.apply_load_at {V : Valuation} {vs : List (Except Fault Val)} {m : Mem} {F : Func}
    {lbl pc : Nat} {p : SVal} {dst : Option Nat} {vol : Bool} {t : Ty} {a : Nat} {pv : Value}
    {al : Option Nat} {md : List (String × Nat)} {q : Ptr} (hF : V.fn = F)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .load vol t (.mk (.ptr a) pv) al, md⟩)
    (hp : p.eval V vs = .ok (.ptr q)) :
    (SEff.load lbl pc p).apply V vs m = .ok (m.log (.access ⟨V.ctx.who, q,
      V.ctx.prog.layout.stored t, false, none, md.any (·.1 == "invariant.load")⟩)) :=
  SEff.apply_load (Valuation.stmt_of_fn hF hs) hp

/-- **A `getelementptr` node** with one index is what `gep` gives of its operands' values, at a
valuation whose function is `F` and program is `P`, for every result. -/
theorem SNode.eval_gep_at {V : Valuation} {vs : List (Except Fault Val)} {P : Program}
    {F : Func} {lbl pc : Nat} {base idx : SVal} {dst : Option Nat} {fl : GepFlags} {src : Ty}
    {a : Nat} {pv : Value} {ix : TValue} {md : List (String × Nat)} {i b : Val}
    (hF : V.fn = F) (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .gep fl src (.mk (.ptr a) pv) [ix], md⟩)
    (hi : idx.eval V vs = .ok i) (hb : base.eval V vs = .ok b) {r : Except Fault Val}
    (h : MojoProof.Sem.gep P.layout V.mem fl src a [i] b = r) :
    (SNode.gep lbl pc base idx).eval V vs = r := by
  subst hP h
  simp only [SNode.eval, Valuation.stmt_of_fn hF hs, hi, hb]
  rfl

/-- **A special-register call node**, at a valuation whose function is `F`, program `P` and
environment `E`. -/
theorem SNode.eval_sreg_at {V : Valuation} {vs : List (Except Fault Val)} {lbl pc : Nat}
    {P : Program} {F : Func} {E : Env} {dst : Option Nat} {fm : FastMath} {ty : Ty}
    {md : List (String × Nat)} {g : String} {fn : Func} {r : SReg} {d : Dim} (hF : V.fn = F)
    (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .call fm ty (.fn g) [], md⟩)
    (hf : P.module.funcs.find? (·.name == g) = some fn)
    (hl : P.intrinsics.lookup g = some (.sreg r d)) (hr : fn.ret = .int 32)
    (hA : ∀ a ∈ fn.retAttrs, keepsWord 32 r.lo (r.hi d) a = true) (hk : r.hi d ≤ 2 ^ 32)
    (hE : V.ctx.env = E) (hb : r.lo ≤ E.sreg r d ∧ E.sreg r d < r.hi d) :
    (SNode.call lbl pc).eval V vs = .ok (.bits 32 (BitVec.ofNat 32 (E.sreg r d))) := by
  subst hE
  exact SNode.eval_sreg vs hP (Valuation.stmt_of_fn hF hs) hf hl hr hA hk hb

/-- **A float operator node** on two floats of its type, with no `fmul contract` factors and
flags without `nnan`, `ninf`, `nsz`, `reassoc`, `arcp` and `afn`: the IEEE operation through
`deliver` at the node's oracle number, for every valuation and node values. -/
theorem SNode.eval_fbin_ofFloat {V : Valuation} {vs : List (Except Fault Val)} {op : FBinOp}
    {fm : FastMath} {ft : FloatTy} {n : Nat} {a b : SVal}
    {u u' : FloatLib.Floats.Formats.BinaryInterchange.Model ft.fmt}
    {f : FloatLib.Floats.Formats.BinaryInterchange.Model ft.fmt →
      FloatLib.Floats.Formats.BinaryInterchange.Model ft.fmt →
      FloatLib.Floats.Formats.BinaryInterchange.Model ft.fmt}
    (ha : a.eval V vs = .ok (.ofFloat ft u))
    (hb : b.eval V vs = .ok (.ofFloat ft u')) (hpa : a.prods V = none) (hpb : b.prods V = none)
    (hf : MojoProof.Sem.fbin op = some f) (hc : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = false)
    (hn : fm.nnan = false) (hi : fm.ninf = false) :
    (SNode.fbin op fm ft n a b).eval V vs =
      .ok (.ofFloat ft (deliver (f u u') (V.ctx.oracle (Nat.pair (V.k + n) 0) / 3))) := by
  simp only [SNode.eval, ha, hb, bind, Except.bind, hpa, hpb, laneOf, Option.map_none]
  exact floatBin_ofFloat hf hc hn hi u u' _

/-! ## Exits and comparisons -/

/-- An unconditional branch goes to its label. -/
theorem Exit.target_br {V : Valuation} {vs : List (Except Fault Val)} {d : Nat} :
    (Exit.br d).target V vs = some d := rfl

/-- A conditional branch on a true boolean goes to its first label. -/
theorem Exit.target_cond_true {V : Valuation} {vs : List (Except Fault Val)} {c : SVal}
    {d e : Nat} {b : Bool} (h : c.eval V vs = .ok (.ofBool b)) (hb : b = true) :
    (Exit.cond c d e).target V vs = some d := by
  subst hb
  exact (Exit.target_cond h).trans rfl

/-- A conditional branch on a false boolean goes to its second label. -/
theorem Exit.target_cond_false {V : Valuation} {vs : List (Except Fault Val)} {c : SVal}
    {d e : Nat} {b : Bool} (h : c.eval V vs = .ok (.ofBool b)) (hb : b = false) :
    (Exit.cond c d e).target V vs = some e := by
  subst hb
  exact (Exit.target_cond h).trans rfl

/-- `icmp slt` of the words of `a` and `b` with `2 a`, `2 b` below `2 ^ w` is `a < b`. -/
theorem ICmp.slt_ofNat {w a b : Nat} (ha : 2 * a < 2 ^ w) (hb : 2 * b < 2 ^ w) :
    ICmp.slt.holds (BitVec.ofNat w a) (BitVec.ofNat w b) = decide (a < b) := by
  simp only [ICmp.holds, BitVec.slt, BitVec.toInt_ofNat_of_lt ha, BitVec.toInt_ofNat_of_lt hb]
  simp

/-- `icmp ult` of the words of `a` and `b` below `2 ^ w` is `a < b`. -/
theorem ICmp.ult_ofNat {w a b : Nat} (ha : a < 2 ^ w) (hb : b < 2 ^ w) :
    ICmp.ult.holds (BitVec.ofNat w a) (BitVec.ofNat w b) = decide (a < b) := by
  simp only [ICmp.holds, BitVec.ult, BitVec.toNat_ofNat, Nat.mod_eq_of_lt ha, Nat.mod_eq_of_lt hb]

/-- No effects run from every memory. -/
theorem SEff.foldlM_nil_ex {V : Valuation} {vs : List (Except Fault Val)} (M : Mem) :
    ∃ M', ([] : List SEff).foldlM (SEff.apply V vs) M = .ok M' := ⟨M, rfl⟩

/-- An `icmp slt` node on the words of `x` and `y`, both with `2 x`, `2 y` below `2 ^ w`, is the
boolean `x < y`, for every valuation and node values. -/
theorem SNode.eval_icmp_slt_ofNat {V : Valuation} {vs : List (Except Fault Val)} {w : Nat}
    {a b : SVal} {x y : Nat} (ha : a.eval V vs = .ok (.bits w (BitVec.ofNat w x)))
    (hb : b.eval V vs = .ok (.bits w (BitVec.ofNat w y))) (hx : 2 * x < 2 ^ w)
    (hy : 2 * y < 2 ^ w) :
    (SNode.icmp .slt w a b).eval V vs = .ok (.ofBool (decide (x < y))) := by
  rw [SNode.eval_icmp ha hb, ICmp.slt_ofNat hx hy]

/-- An `icmp ult` node on the words of `x` and `y` below `2 ^ w` is the boolean `x < y`, for every
valuation and node values. -/
theorem SNode.eval_icmp_ult_ofNat {V : Valuation} {vs : List (Except Fault Val)} {w : Nat}
    {a b : SVal} {x y : Nat} (ha : a.eval V vs = .ok (.bits w (BitVec.ofNat w x)))
    (hb : b.eval V vs = .ok (.bits w (BitVec.ofNat w y))) (hx : x < 2 ^ w) (hy : y < 2 ^ w) :
    (SNode.icmp .ult w a b).eval V vs = .ok (.ofBool (decide (x < y))) := by
  rw [SNode.eval_icmp ha hb, ICmp.ult_ofNat hx hy]

/-! ## Edges into blocks with `phi`s -/

/-- An integer constant operand `.int w k` of a natural number `k` is the word
`BitVec.ofNat w k`, for every valuation and node values. -/
theorem SVal.eval_int_ofNat {V : Valuation} {vs : List (Except Fault Val)} (w k : Nat) :
    (SVal.int w (Int.ofNat k)).eval V vs = .ok (.bits w (BitVec.ofNat w k)) := by
  simp only [SVal.eval, pure, Except.pure, Except.ok.injEq, Val.bits.injEq, heq_eq_eq, true_and]
  exact BitVec.ofInt_natCast w k

/-- An exit with a target (`Exit.target`) goes there (`Exit.dest`), for every valuation and node
values. -/
theorem Exit.dest_of_target {V : Valuation} {vs : List (Except Fault Val)} {x : Exit} {d : Nat}
    (h : x.target V vs = some d) : x.dest V vs = some d := by
  cases x with
  | phi => simp [Exit.target] at h
  | _ => exact h

/-- A branch into blocks with `phi`s whose condition is a word goes to `d` if its low bit is set,
else to `e`, for every valuation and node values. -/
theorem Exit.dest_phi_eval {V : Valuation} {vs : List (Except Fault Val)} {c : SVal}
    {d e w : Nat} {b : BitVec w} (h : c.eval V vs = .ok (.bits w b)) :
    (Exit.phi c d e).dest V vs = some (if b.getLsbD 0 then d else e) := by
  simp only [Exit.dest, h]

/-- `Exit.dest_phi_eval` with the low bit set: the branch goes to `d`. -/
theorem Exit.dest_phi_true {V : Valuation} {vs : List (Except Fault Val)} {c : SVal}
    {d e w : Nat} {b : BitVec w} (h : c.eval V vs = .ok (.bits w b)) (hb : b.getLsbD 0 = true) :
    (Exit.phi c d e).dest V vs = some d := by
  rw [Exit.dest_phi_eval h, hb]; rfl

/-- `Exit.dest_phi_eval` with the low bit clear: the branch goes to `e`. -/
theorem Exit.dest_phi_false {V : Valuation} {vs : List (Except Fault Val)} {c : SVal}
    {d e w : Nat} {b : BitVec w} (h : c.eval V vs = .ok (.bits w b)) (hb : b.getLsbD 0 = false) :
    (Exit.phi c d e).dest V vs = some e := by
  rw [Exit.dest_phi_eval h, hb]; rfl

/-- A branch into blocks with `phi`s on the boolean `b` goes to `d` when `b` is true. -/
theorem Exit.dest_phi_ofBool_true {V : Valuation} {vs : List (Except Fault Val)} {c : SVal}
    {d e : Nat} {b : Bool} (h : c.eval V vs = .ok (.ofBool b)) (hb : b = true) :
    (Exit.phi c d e).dest V vs = some d := by
  subst hb; exact Exit.dest_phi_true h rfl

/-- A branch into blocks with `phi`s on the boolean `b` goes to `e` when `b` is false. -/
theorem Exit.dest_phi_ofBool_false {V : Valuation} {vs : List (Except Fault Val)} {c : SVal}
    {d e : Nat} {b : Bool} (h : c.eval V vs = .ok (.ofBool b)) (hb : b = false) :
    (Exit.phi c d e).dest V vs = some e := by
  subst hb; exact Exit.dest_phi_false h rfl

/-- The position an exit enters block `d` at is the same for equal functions. -/
theorem Exit.pc_of_fn {x : Exit} {fn F : Func} {d p : Nat} (hF : fn = F) (h : x.pc F d = p) :
    x.pc fn d = p := hF ▸ h

/-- The empty path with `phi`s has its premises. -/
theorem WalkI.nil' (V : Valuation) : WalkI V [] := trivial

/-- A path with `phi`s of one block has its premises if the block's obligations hold. -/
theorem WalkI.one {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    (h : ∀ d ∈ ds, d.Holds V (vals V S.nodes)) : WalkI V [(l, ds, S)] := h

/-- A path with `phi`s of two blocks or more has its premises if the first block's obligations
hold, its exit goes to the second block's label (`Exit.dest`), and the rest has them from the
valuation the edge gives (`Valuation.into`). -/
theorem WalkI.cons2 {V : Valuation} {l l' : Nat} {ds ds' : List Cond} {S S' : Summary}
    {ps : List (Nat × List Cond × Summary)} (h1 : ∀ d ∈ ds, d.Holds V (vals V S.nodes))
    (h2 : S.exit.dest V (vals V S.nodes) = some l')
    (h3 : WalkI (V.into l S) ((l', ds', S') :: ps)) :
    WalkI V ((l, ds, S) :: (l', ds', S') :: ps) := ⟨h1, h2, h3⟩

/-- A predicate holds of every number below 0. -/
theorem forall_lt_zero' (P : Nat → Prop) : ∀ i < 0, P i := fun _ h => absurd h (Nat.not_lt_zero _)

/-- A predicate holds of every number below `n + 1` if it holds below `n` and at `n`. -/
theorem forall_lt_succ' {P : Nat → Prop} {n : Nat} (h : ∀ i < n, P i) (hn : P n) :
    ∀ i < n + 1, P i := fun i hi =>
  (Nat.lt_succ_iff_lt_or_eq.1 hi).elim (h i) fun e => e ▸ hn

/-- The memory at the entry of the block an edge goes to is `Valuation.after`'s, for every
valuation, label and summary. -/
theorem Valuation.into_mem (V : Valuation) (l : Nat) (S : Summary) :
    (V.into l S).mem = (V.after S).mem := by
  unfold Valuation.into
  split
  · split <;> rfl
  · rfl

/-- The registers at the entry of the block a `br` goes to are `Valuation.after`'s. -/
theorem Valuation.into_regs_br {V : Valuation} {l d r : Nat} {S : Summary} {v : Val}
    (hx : S.exit = .br d) (h : (V.after S).regs r = some v) : (V.into l S).regs r = some v := by
  unfold Valuation.into
  split
  · rename_i hp _; rw [hx] at hp; cases hp
  · exact h

/-- The registers at the entry of the block a conditional branch goes to are
`Valuation.after`'s. -/
theorem Valuation.into_regs_cond {V : Valuation} {l d e r : Nat} {c : SVal} {S : Summary}
    {v : Val} (hx : S.exit = .cond c d e) (h : (V.after S).regs r = some v) :
    (V.into l S).regs r = some v := by
  unfold Valuation.into
  split
  · rename_i hp _; rw [hx] at hp; cases hp
  · exact h

/-- Whether statement `st` is a `phi` (the test `enter` takes the head of a block with). -/
def isPhi (st : Stmt) : Bool := st.inst matches .phi _ _

/-- The value `enter` gives `phi` statement `st` for the edge from block `l` in scope `s`. -/
def phiVal (s : Scope) (l : Nat) (st : Stmt) : Except Fault Val := do
  st.checkMd
  match st.inst with
  | .phi t inc => match inc.find? (·.2 == l) with
    | some (v, _) => evalV s t v
    | none => throw (.unsupported "phi without the incoming edge")
  | _ => throw (.unsupported "phi")

/-- `enter` into a block `b` of the frame's function, with its `phi`s' values (`phiVal`) and the
frame they set, for every scope, frame and block. -/
theorem enter_of_find {s : Scope} {f : Frame} {d : Nat} {b : LLVM.Block}
    (hb : f.fn.blocks.find? (·.label == d) = some b) :
    enter s f d = (do
      let vals ← (b.stmts.toList.takeWhile isPhi).mapM (phiVal s f.label)
      return { ((b.stmts.toList.takeWhile isPhi).zip vals).foldl
          (fun f (st, v) => f.set st.res (some v) none) f with
        label := d, pc := (b.stmts.toList.takeWhile isPhi).length }) := by
  unfold enter
  rw [hb]
  rfl

/-- The operands of the `phi`s `sts` for the edge from block `l`: each one's register, type and
incoming value; `none` when one has metadata, is not a `phi` or has no operand for `l`. -/
def phiOpsL (l : Nat) : List Stmt → Option (List (Option Nat × Ty × Value))
  | [] => some []
  | st :: sts => match st.md, st.inst with
    | [], .phi t inc => match inc.find? (·.2 == l), phiOpsL l sts with
      | some (v, _), some ops => some ((st.res, t, v) :: ops)
      | _, _ => none
    | _, _ => none

/-- The operands of the `phi`s at the head of block `d` of `fn` for the edge from block `l`
(`phiOpsL`); `none` when `fn` has no block `d`. -/
def phiOps (fn : Func) (l d : Nat) : Option (List (Option Nat × Ty × Value)) :=
  match fn.blocks.find? (·.label == d) with
  | some b => phiOpsL l (b.stmts.toList.takeWhile isPhi)
  | none => none

/-- The values of the operands `ops` in scope `s`, in order (`evalV`). -/
def evalOps (s : Scope) : List (Option Nat × Ty × Value) → Except Fault (List Val)
  | [] => .ok []
  | (_, t, v) :: ops => match evalV s t v, evalOps s ops with
    | .ok x, .ok xs => .ok (x :: xs)
    | .error e, _ => .error e
    | _, .error e => .error e

/-- No operands have no values. -/
theorem evalOps_nil (s : Scope) : evalOps s [] = .ok [] := rfl

/-- The values of `(o, t, v) :: ops` are `v`'s and those of `ops`. -/
theorem evalOps_cons {s : Scope} {o : Option Nat} {t : Ty} {v : Value} {x : Val}
    {ops : List (Option Nat × Ty × Value)} {xs : List Val} (h : evalV s t v = .ok x)
    (h' : evalOps s ops = .ok xs) : evalOps s ((o, t, v) :: ops) = .ok (x :: xs) := by
  simp only [evalOps, h, h']

/-- Registers `g` with `rs` set to `xs`, in order (a later one wins), up to the shorter list; a
`none` register sets nothing. -/
def setRegs : List (Option Nat) → List Val → (Nat → Option Val) → Nat → Option Val
  | some r :: rs, x :: xs, g => setRegs rs xs (fun s => if s = r then some x else g s)
  | none :: rs, _ :: xs, g => setRegs rs xs g
  | _, _, g => g

/-- Registers `g` with `rs` set to `xs` (`setRegs`) are `g`'s at a register `r` that `rs` does
not set (no `some r` in `rs`), for every list of values. -/
theorem setRegs_of_forall_ne : ∀ {rs : List (Option Nat)} {xs : List Val}
    {g : Nat → Option Val} {r : Nat}, (∀ o ∈ rs, o ≠ some r) → setRegs rs xs g r = g r
  | [], xs, _, _, _ => by cases xs <;> rfl
  | some _ :: _, [], _, _, _ => rfl
  | some s :: rs, x :: xs, g, r, h => by
    have hs : r ≠ s := fun e => h (some s) (by simp) (by rw [e])
    show setRegs rs xs (fun t => if t = s then some x else g t) r = g r
    rw [setRegs_of_forall_ne fun o ho => h o (List.mem_cons_of_mem _ ho)]
    exact if_neg hs
  | none :: _, [], _, _, _ => rfl
  | none :: rs, _ :: xs, g, r, h => by
    show setRegs rs xs g r = g r
    exact setRegs_of_forall_ne fun o ho => h o (List.mem_cons_of_mem _ ho)

/-- A local operand is the register's value in the scope. -/
theorem evalV_loc {s : Scope} {t : Ty} {r : Nat} {x : Val} (h : s.regs r = some x) :
    evalV s t (.loc r) = .ok x := by
  simp only [evalV, h]; rfl

/-- An integer constant of a natural number at an integer type is its word. -/
theorem evalV_int_ofNat (s : Scope) (w k : Nat) :
    evalV s (.int w) (.int (Int.ofNat k)) = .ok (.bits w (BitVec.ofNat w k)) := by
  simp only [evalV, pure, Except.pure, Except.ok.injEq, Val.bits.injEq, heq_eq_eq, true_and]
  exact BitVec.ofInt_natCast w k

/-- `phiVal` on the `phi`s with operands `ops` (`phiOpsL`) whose values are `xs`: the values are
`xs`, and the registers of `ops` are the statements'. -/
theorem mapM_phiVal {s : Scope} {l : Nat} :
    ∀ {sts : List Stmt} {ops : List (Option Nat × Ty × Value)} {xs : List Val},
    phiOpsL l sts = some ops → evalOps s ops = .ok xs →
    sts.mapM (phiVal s l) = .ok xs ∧ ops.map (·.1) = sts.map (·.res)
  | [], ops, xs, h, hx => by
    simp only [phiOpsL, Option.some.injEq] at h
    subst h
    simp only [evalOps, Except.ok.injEq] at hx
    subst hx
    exact ⟨rfl, rfl⟩
  | st :: sts, ops, xs, h, hx => by
    unfold phiOpsL at h
    split at h
    · rename_i t inc hmd hinst
      split at h
      · rename_i v w ops' hf hrest
        simp only [Option.some.injEq] at h
        subst h
        unfold evalOps at hx
        split at hx
        · rename_i x xs' hv hxs
          simp only [Except.ok.injEq] at hx
          subst hx
          obtain ⟨hm, hr⟩ := mapM_phiVal hrest hxs
          have hst : phiVal s l st = .ok x := by
            simp only [phiVal, Stmt.checkMd, hmd, hinst, hf]
            exact hv
          refine ⟨?_, ?_⟩
          · rw [List.mapM_cons, hst, hm]; rfl
          · simp only [List.map_cons, hr]
        · cases hx
        · cases hx
      · cases h
    · cases h

/-- The registers of the frame that setting `sts`' results to `xs` in order gives (as `enter`
does) are `setRegs`. -/
theorem foldl_set_regs : ∀ (sts : List Stmt) (xs : List Val) (f : Frame),
    ((sts.zip xs).foldl (fun f (st, v) => f.set st.res (some v) none) f).regs =
      setRegs (sts.map (·.res)) xs f.regs
  | [], _, f => by simp [setRegs]
  | _ :: _, [], f => by cases h : (‹Stmt›).res <;> simp [setRegs, h]
  | st :: sts, x :: xs, f => by
    rw [List.zip_cons_cons, List.foldl_cons, foldl_set_regs sts xs, List.map_cons]
    cases h : st.res with
    | none => simp only [Frame.set, h, setRegs]
    | some r => simp only [Frame.set, h, setRegs]

/-- **`enter` from the `phi` operands.** For every scope, frame and block `d`: when the `phi`s at
the head of block `d` of the frame's function have operands `ops` for the edge from the frame's
block (`phiOps`), with values `xs` in the scope, `enter` succeeds, and the registers of the frame
it gives are the frame's with the `phi`s' registers set to `xs` (`setRegs`). -/
theorem enter_of_phiOps {s : Scope} {f : Frame} {d : Nat} {ops : List (Option Nat × Ty × Value)}
    {xs : List Val} (hops : phiOps f.fn f.label d = some ops) (hxs : evalOps s ops = .ok xs) :
    ∃ f', enter s f d = .ok f' ∧ f'.regs = setRegs (ops.map (·.1)) xs f.regs := by
  unfold phiOps at hops
  split at hops
  · rename_i b hb
    obtain ⟨hm, hr⟩ := mapM_phiVal hops hxs
    rw [enter_of_find hb, hm]
    exact ⟨_, rfl, by rw [hr]; exact foldl_set_regs _ _ f⟩
  · cases hops

/-- **The registers after an edge into blocks with `phi`s.** For every valuation `V`, block `l`
and summary `S` whose exit is a branch into blocks with `phi`s that goes to `d` (`Exit.dest`):
when the function is `F` and the `phi`s of block `d` of `F` have operands `ops` for the edge from
`l` (`phiOps`), with values `xs` in the scope of the edge's step (as `Valuation.into` evaluates
them), each register of `Valuation.into` is `Valuation.after`'s with the `phi`s' registers set to
`xs` (`setRegs`). -/
theorem Valuation.into_regs_phi {V : Valuation} {l : Nat} {S : Summary} {x : SVal} {a b d : Nat}
    {F : Func} {ops : List (Option Nat × Ty × Value)} {xs : List Val}
    (hx : S.exit = .phi x a b) (hd : S.exit.dest V (vals V S.nodes) = some d) (hF : V.fn = F)
    (hops : phiOps F l d = some ops)
    (hxs : evalOps (V.ctx.scope (V.after S).mem (V.frameAt l S) (V.k + S.len)) ops = .ok xs)
    (r : Nat) : (V.into l S).regs r = setRegs (ops.map (·.1)) xs (V.after S).regs r := by
  have hops' : phiOps (V.frameAt l S).fn (V.frameAt l S).label d = some ops := by
    simp only [Valuation.frameAt]; rw [hF]; exact hops
  obtain ⟨f', he, hr⟩ := enter_of_phiOps hops' hxs
  have : V.into l S = { V.after S with regs := f'.regs, prods := f'.prods } := by
    rw [Valuation.into, hd]; simp only [hx, he]
  rw [this]
  exact congrFun hr r

end MojoProof.Sym
