import MojoProof.Sym.Checker
import MojoProof.Sem.Skeleton
import MojoProof.Sem.Frame

/-!
# The statements `exec` runs, and the shape of the memory the effects make

Lemmas about `exec` (MojoProof/Sem/Thread.lean) at each statement of the block checker's
fragment, for every context, scope, step count, frame and statement: the frame and memory
`exec` gives when the statement's operands evaluate to given values (`exec_bin`, `exec_icmp`,
`exec_cast`, `exec_extract`, `exec_insertvalue`, `exec_extractelement`, `exec_insertelement`,
`exec_gep`, `exec_load`, `exec_store`, `exec_fbin`, `exec_fbinC`, `exec_nullary`, `exec_sreg`,
`exec_laneid`, `exec_select`, `exec_minmax`, `exec_alloca`), and `castOk_iff`, the casts `castV`
evaluates. And the shape of the memory a block's effects make (`SEff.run_shape`): every block but
those its `alloca`s make keeps its address and size (`Mem.write_shape`, `Mem.store_shape`), so a
statement that reads only those gives on it what it gives on the entry memory; and the effects
keep `next` (`SEff.run_next`), so an `alloca` numbers its block as on the entry memory.
`SState.stmt_sound` (MojoProof/Sym/Block.lean) uses them.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The `fmul contract` operands an operand carries in frame `f`: a register's. -/
def valProd (f : Frame) : Value → Option (Val × Val)
  | .loc r => f.prods r
  | _ => none

/-! ### The statements `exec` runs -/

/-- `exec` of an integer operator. -/
theorem exec_bin {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {op fl t a b x y r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .bin op fl t a b)
    (ha : evalV s t a = .ok x) (hb : evalV s t b = .ok y)
    (hr : lanes2 (fun _ => intBin (c.prog.layout.scalarBits t.elt) op fl) x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, ha, hb, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of an `icmp`. -/
theorem exec_icmp {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {p t a b x y r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .icmp p t a b)
    (ha : evalV s t a = .ok x) (hb : evalV s t b = .ok y)
    (hr : icmpV c.prog.layout s.mem p t x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, ha, hb, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of a cast. -/
theorem exec_cast {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {op t a ty x r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .cast op (.mk t a) ty)
    (ha : evalV s t a = .ok x) (hr : castV c.prog.layout s.mem op t x ty s.ch = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, ha, hr, bind, Except.bind, pure, Except.pure]

/-- **`castOk` is `castV`'s cases**: for every layout `l`, memory `m`, cast operator `op`, source
type `s`, target type `t` and choices `ch`, `castOk op s t` is `false` if and only if `castV`
faults with its unsupported-cast message (`fptoui`, `fptosi`, `inttoptr` or ill-typed) on every
operand. When it is `true`, `castV` takes the operand `poison` to `poison`, or (a `bitcast`
between types of different sizes) to another fault. So the checker's cast case
(`SState.stmt`), which requires `castOk`, refuses exactly the operators and types of `castV`'s
last case. -/
theorem castOk_iff {l : Layout} {m : Mem} {op : CastOp} {s t : Ty} {ch : Nat → Nat} :
    castOk op s t = false ↔ ∀ x, castV l m op s x t ch =
      .error (.unsupported "cast (fptoui, fptosi, inttoptr, or ill-typed)") := by
  refine ⟨fun h x => ?_, fun h => ?_⟩
  · unfold castV
    split <;> first | rfl | simp_all [castOk]
  · cases hc : castOk op s t
    · rfl
    · have hb : toBitList l s .poison = .ok (List.replicate (l.scalarBits s) none) := by
        cases s <;> rfl
      have h := h .poison
      revert h
      unfold castV
      split <;> simp_all [castOk, lanes, intCast, floatCast, intToFloat, bitcast, pure,
        Except.pure]
      split
      · simp
      · simp only [bind, Except.bind]
        split_ifs
        · simp
        · intro h
          injection h with h
          injection h with h
          exact absurd h (by decide)

/-- `exec` of an `extractvalue`. -/
theorem exec_extract {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {t a is x r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .extractvalue (.mk t a) is)
    (ha : evalV s t a = .ok x) (hr : extractV x is = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, ha, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of an `insertvalue`. -/
theorem exec_insertvalue {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {t a te e is x y r} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .insertvalue (.mk t a) (.mk te e) is)
    (ha : evalV s t a = .ok x) (he : evalV s te e = .ok y) (hr : insertV x y is = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, ha, he, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of an `extractelement`. -/
theorem exec_extractelement {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {t v ti i x y r} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .extractelement (.mk t v) (.mk ti i))
    (hv : evalV s t v = .ok x) (hidx : evalV s ti i = .ok y) (hr : extractE t x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, hv, hidx, hr, evalTV, bind, Except.bind, pure, Except.pure]

/-- `exec` of an `insertelement`. -/
theorem exec_insertelement {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {t v te e ti i x y z r} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .insertelement (.mk t v) (.mk te e) (.mk ti i))
    (hv : evalV s t v = .ok x) (he : evalV s te e = .ok y) (hidx : evalV s ti i = .ok z)
    (hr : insertE t x y z = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, hv, he, hidx, hr, evalTV, bind, Except.bind, pure, Except.pure]

/-- `exec` of a `getelementptr`. -/
theorem exec_gep {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {fl src a b idx is pv r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .gep fl src (.mk (.ptr a) b) idx)
    (hidx : evalTVs s idx = .ok is) (hb : evalV s (.ptr a) b = .ok pv)
    (hr : MojoProof.Sem.gep c.prog.layout s.mem fl src a is pv = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, hidx, hb, hr, bind, Except.bind, pure, Except.pure]

/-- `exec` of a `load`. -/
theorem exec_load {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {vol t a p al pv q v}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .load vol t (.mk (.ptr a) p) al)
    (hp : evalV s (.ptr a) p = .ok pv) (hq : pv.addr? = .ok q)
    (hv : s.mem.load c.prog.layout c.who a t q (some (al.getD (c.prog.layout.align t))) = .ok v)
    (hu : (st.md.any (·.1 == "noundef") && !v.defined) = false) :
    exec c s k f st = .ok (.next { f.set st.res (some v) none with pc := f.pc + 1 }
      (s.mem.log (.access ⟨c.who, q, c.prog.layout.stored t, false, none,
        st.md.any (·.1 == "invariant.load")⟩))) := by
  simp only [exec, hmd, hi, hp, hq, hv, hu, bind, Except.bind, pure, Except.pure,
    Bool.false_eq_true, ↓reduceIte]

/-- `exec` of a `store`. -/
theorem exec_store {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {vol t v a p al x pv q m'} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .store vol (.mk t v) (.mk (.ptr a) p) al) (hx : evalV s t v = .ok x)
    (hp : evalV s (.ptr a) p = .ok pv) (hq : pv.addr? = .ok q)
    (hm : s.mem.store c.prog.layout c.who a t x q (some (al.getD (c.prog.layout.align t))) =
      .ok m') :
    exec c s k f st = .ok (.next { f with pc := f.pc + 1 } m') := by
  simp only [exec, hmd, hi, hx, hp, hq, hm, bind, Except.bind, pure, Except.pure]

/-- **A write keeps the shape**: for every layout, memory, thread, address space, pointer `p`,
bytes and alignment, a write that succeeds leaves every block number with the shape
(`Block.shape`: space, size and addresses) it has, or with no block where it has none: it sets
only `p`'s block, which its check found, to that block with other bytes. -/
theorem Mem.write_shape {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {p : Ptr}
    {bs : List MemByte} {al : Option Nat} (h : m.write l w a p bs al = .ok m') (S : Nat → Prop) :
    m.SameShape S m' := by
  unfold Mem.write at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  split at h
  · cases h
  · rename_i r hc
    split at h
    · cases h
    · cases h
      intro b _
      by_cases hb : b = p.block
      · subst hb
        simp [Mem.set, (Mem.check_block hc).1]
        rfl
      · simp [Mem.set, hb]

/-- **A store keeps the shape**: for every layout, memory, thread, address space, type, value,
pointer, alignment and read-modify-write operation, a store that succeeds leaves every block
number with the shape (`Block.shape`) it has, or with no block where it has none
(`Mem.write_shape`; the trace entry changes no block). -/
theorem Mem.store_shape {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    (S : Nat → Prop) : m.SameShape S m' := by
  unfold Mem.store at h
  split at h
  · obtain ⟨m₁, hw, h⟩ := Except.bind_eq_ok.1 h
    cases h
    exact Mem.write_shape hw S
  · cases h

/-- **A block's effects keep the shape**: for every valuation `V`, node values `vs`, effects `es`
that run (`SEff.run`) to memory `m` and set of block numbers `S` without a block the effects
allocate (`SEff.blocks`), `m` has the entry memory's shape at every number of `S`
(`Mem.SameShape`, `Block.shape`), a number with no block included: a `load`'s effect adds a trace
entry, a `store`'s is a store (`Mem.store_shape`), and an `alloca`'s sets only its own block. So a
statement that reads only the blocks' addresses and sizes (`getelementptr`, `icmp`, `ptrtoint`, a
special register) gives on `m` what it gives on the entry memory, on values that name no block an
`alloca` made (all values when the effects have no `alloca`'s, `SEff.blocks_eq_nil`). -/
theorem SEff.run_shape {V : Valuation} {vs : List (Except Fault Val)} {es : List SEff} {m : Mem}
    (h : SEff.run V vs es = .ok m) (S : Nat → Prop) (hS : ∀ b ∈ SEff.blocks V es, ¬ S b) :
    V.mem.SameShape S m := by
  induction es using List.reverseRecOn generalizing m with
  | nil =>
    simp only [SEff.run, List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact fun _ _ => rfl
  | append_singleton es e ih =>
    obtain ⟨m₀, h₀, he⟩ := SEff.run_snoc h
    rw [SEff.blocks_snoc] at hS
    refine fun b hb => (ih h₀ (fun b' hb' => hS b' (List.mem_append_right _ hb')) b hb).trans ?_
    cases e with
    | load lbl pc p =>
      simp only [SEff.apply] at he
      split at he
      · obtain ⟨x, -, he⟩ := Except.bind_eq_ok.1 he
        obtain ⟨q, -, he⟩ := Except.bind_eq_ok.1 he
        cases he
        rfl
      · cases he
    | store lbl pc v p =>
      simp only [SEff.apply] at he
      split at he
      · obtain ⟨x, -, he⟩ := Except.bind_eq_ok.1 he
        obtain ⟨y, -, he⟩ := Except.bind_eq_ok.1 he
        obtain ⟨q, -, he⟩ := Except.bind_eq_ok.1 he
        exact Mem.store_shape he S b hb
      · cases he
    | alloca lbl pc n cnt =>
      have hne : b ≠ V.mem.fresh V.ctx.who.thread (V.k + n) := fun hb' =>
        hS _ (List.mem_append_left _ (by simp [SEff.block?])) (hb' ▸ hb)
      simp only [SEff.apply] at he
      split at he
      · obtain ⟨c, -, he⟩ := Except.bind_eq_ok.1 he
        split at he
        · cases he
        · cases he
          simp [Mem.alloc, Mem.set, hne]
      · cases he

/-- **A block's effects keep `next`**: for every valuation `V`, node values `vs` and effects `es`
that run (`SEff.run`) to memory `m`, `m.next = V.mem.next`: a `load`'s effect adds a trace entry,
a `store`'s sets a block, an `alloca`'s sets the block of the number it is given
(`Mem.alloc` with `num`). So an `alloca` after them numbers its block as on the entry memory
(`Mem.fresh`). -/
theorem SEff.run_next {V : Valuation} {vs : List (Except Fault Val)} {es : List SEff} {m : Mem}
    (h : SEff.run V vs es = .ok m) : m.next = V.mem.next := by
  induction es using List.reverseRecOn generalizing m with
  | nil =>
    simp only [SEff.run, List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h
    subst h
    rfl
  | append_singleton es e ih =>
    obtain ⟨m₀, h₀, he⟩ := SEff.run_snoc h
    refine Eq.trans ?_ (ih h₀)
    cases e with
    | load lbl pc p =>
      simp only [SEff.apply] at he
      split at he
      · obtain ⟨x, -, he⟩ := Except.bind_eq_ok.1 he
        obtain ⟨q, -, he⟩ := Except.bind_eq_ok.1 he
        cases he
        rfl
      · cases he
    | store lbl pc v p =>
      simp only [SEff.apply] at he
      split at he
      · obtain ⟨x, -, he⟩ := Except.bind_eq_ok.1 he
        obtain ⟨y, -, he⟩ := Except.bind_eq_ok.1 he
        obtain ⟨q, -, he⟩ := Except.bind_eq_ok.1 he
        unfold Mem.store at he
        split at he
        · obtain ⟨m₁, hw, he⟩ := Except.bind_eq_ok.1 he
          cases he
          unfold Mem.write at hw
          simp only [bind, Except.bind, pure, Except.pure] at hw
          split at hw
          · cases hw
          · split at hw
            · cases hw
            · cases hw
              rfl
        · cases he
      · cases he
    | alloca lbl pc n cnt =>
      simp only [SEff.apply] at he
      split at he
      · obtain ⟨c, -, he⟩ := Except.bind_eq_ok.1 he
        split at he
        · cases he
        · cases he
          rfl
      · cases he

/-- `exec` of an `alloca`: for every context, scope, step count and frame, a statement whose
metadata `checkMd` accepts, of type `t`, count `cnt` and alignment `al`, whose count evaluates to
`n` elements, at a block number `s.mem.fresh` of the thread and step count that has no block: a
block of `n` elements of `t` at that number, live unless the function starts the register's
lifetime (`lifetimeStarted`), the register its pointer at offset 0, and the number in front of the
frame's `allocas`. -/
theorem exec_alloca {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {t : Ty}
    {cnt : Option TValue} {al : Option Nat} {n : Nat}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .alloca t cnt al) (hn1 : cnt = none → n = 1)
    (hn : ∀ ct cv, cnt = some (.mk ct cv) →
      ∃ (w : Nat) (b : BitVec w), evalV s ct cv = .ok (.bits w b) ∧ b.toNat = n)
    (hb : (s.mem.blocks (s.mem.fresh c.who.thread k)).isSome = false) :
    exec c s k f st = .ok (.next { f.set st.res (some (.ptr ⟨s.mem.fresh c.who.thread k, 0⟩))
        none with pc := f.pc + 1, allocas := s.mem.fresh c.who.thread k :: f.allocas }
      (s.mem.alloc c.prog.layout c.prog.layout.allocaSpace (n * c.prog.layout.size t)
        (al.getD (c.prog.layout.align t)) (!(st.res.any (lifetimeStarted c f.fn))) false
        (.thread c.who.thread) (c.addr (Nat.pair k 0)) (c.addr (Nat.pair k 1))
        (num := some (s.mem.fresh c.who.thread k))).1) := by
  cases cnt with
  | none =>
    obtain rfl := hn1 rfl
    simp only [exec, hmd, hi, hb, bind, Except.bind, pure, Except.pure, Mem.alloc,
      Bool.false_eq_true, ↓reduceIte]
  | some x =>
    obtain ⟨ct, cv⟩ := x
    obtain ⟨w, b, he, rfl⟩ := hn ct cv rfl
    simp only [exec, hmd, hi, he, hb, bind, Except.bind, pure, Except.pure, Mem.alloc,
      Bool.false_eq_true, ↓reduceIte]

/-- `exec` of a float operator: for every context, scope, step count and frame, a statement whose
metadata `checkMd` accepts, on floats `ft`, whose operands evaluate to `x` and `y` and on which
`floatBin` gives `r` lane by lane with the operands' `fmul contract` operands in the frame: the
register is `r`, with the `fmul contract` operands `(x, y)` when the statement is
`fmul contract`, none otherwise. -/
theorem exec_fbinC {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {op fm t ft a b x y r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .fbin op fm t a b) (he : t.elt = .fp ft)
    (ha : evalV s t a = .ok x) (hb : evalV s t b = .ok y)
    (hr : lanes2 (fun i u v => floatBin ft op fm u v (laneOf (valProd f a) i)
      (laneOf (valProd f b) i) (s.ch i)) x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r)
      (if op == .fmul && fm.contract then some (x, y) else none) with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, he, ha, hb, bind, Except.bind, pure, Except.pure]
  split
  · rename_i e' heq
    cases hr.symm.trans heq
  · rename_i r' heq
    cases hr.symm.trans heq
    rfl

/-- `exec` of a float operator but `fmul contract` (`exec_fbinC`, with no `fmul contract`
operands). -/
theorem exec_fbin {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {op fm t ft a b x y r}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .fbin op fm t a b) (he : t.elt = .fp ft)
    (hc : (op == .fmul && fm.contract) = false)
    (ha : evalV s t a = .ok x) (hb : evalV s t b = .ok y)
    (hr : lanes2 (fun i u v => floatBin ft op fm u v (laneOf (valProd f a) i)
      (laneOf (valProd f b) i) (s.ch i)) x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  rw [exec_fbinC hmd hi he ha hb hr, hc]
  rfl

/-- **`exec` of a call of an intrinsic with no arguments**: for every context, scope, step count
and frame, a statement whose metadata `checkMd` accepts that calls, with no arguments and no
fast-math flags, a declaration that `P.intrinsics` names `i`, has no blocks and whose attributes
`Func.check` accepts, where `intrinsic` gives the value `v` on the same memory, `v` is defined
(`ownUndef` is false) and the return attributes keep `v` as `w`, sets its register to `w` and moves
to the next statement, on the same memory. -/
theorem exec_nullary {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {fm ty g fn i v w}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .call fm ty (.fn g) [])
    (hfn : c.prog.module.funcs.find? (·.name == g) = some fn)
    (hg : c.prog.intrinsics.lookup g = some i) (hfm : (fm == {}) = true)
    (hd : fn.blocks.isEmpty = true) (hc : fn.check c.prog.module (some i) = .ok ())
    (hv : intrinsic c s fm i [] = .ok (some (some v, s.mem))) (hu : ownUndef c s i [] = false)
    (hw : withAttrs c.prog.layout s.mem fn.ret fn.retAttrs v = .ok w) :
    exec c s k f st = .ok (.next { f.set st.res (some w) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, hfn, hg, hfm, hd, hc, hv, hw, hu, List.mapM_nil,
    List.zip_nil_right, List.all_nil, Bool.true_or, Bool.not_true, Bool.and_false,
    Option.mapM_some, Functor.map, Except.map, bind, Except.bind, pure, Except.pure,
    Bool.false_eq_true, ↓reduceIte]

/-- `exec` of a call of a special register: a declaration that `P.intrinsics` names `sreg r d`,
with no arguments and no fast-math flags, whose attributes `Func.check` accepts
(`exec_nullary`). -/
theorem exec_sreg {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {fm ty g fn r d w}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .call fm ty (.fn g) [])
    (hfn : c.prog.module.funcs.find? (·.name == g) = some fn)
    (hg : c.prog.intrinsics.lookup g = some (.sreg r d)) (hfm : (fm == {}) = true)
    (hd : fn.blocks.isEmpty = true) (hc : fn.check c.prog.module (some (.sreg r d)) = .ok ())
    (hw : withAttrs c.prog.layout s.mem fn.ret fn.retAttrs
      (.bits 32 (BitVec.ofNat 32 (c.env.sreg r d))) = .ok w) :
    exec c s k f st = .ok (.next { f.set st.res (some w) none with pc := f.pc + 1 } s.mem) :=
  exec_nullary hmd hi hfn hg hfm hd hc rfl rfl hw

/-- `exec` of a call of the lane number: for every context, scope, step count and frame, a
statement whose metadata `checkMd` accepts that calls, with no arguments and no fast-math flags,
a declaration that `P.intrinsics` names `laneid`, whose attributes `Func.check` accepts and whose
return attributes keep the context's `%laneid` as `w`, sets its register to `w` and moves to the
next statement, on the same memory (`exec_nullary`). -/
theorem exec_laneid {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {fm ty g fn w}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .call fm ty (.fn g) [])
    (hfn : c.prog.module.funcs.find? (·.name == g) = some fn)
    (hg : c.prog.intrinsics.lookup g = some .laneid) (hfm : (fm == {}) = true)
    (hd : fn.blocks.isEmpty = true) (hc : fn.check c.prog.module (some .laneid) = .ok ())
    (hw : withAttrs c.prog.layout s.mem fn.ret fn.retAttrs
      (.bits 32 (BitVec.ofNat 32 c.env.laneid)) = .ok w) :
    exec c s k f st = .ok (.next { f.set st.res (some w) none with pc := f.pc + 1 } s.mem) :=
  exec_nullary hmd hi hfn hg hfm hd hc rfl rfl hw

/-- `exec` of a `select`: for every context, scope, step count and frame, a statement whose
metadata `checkMd` accepts, whose condition and operands evaluate, and on which `selectV` gives
`r`, sets its register to `r` and moves to the next statement, on the same memory. -/
theorem exec_select {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {ct cv t a tb b x y z r} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .select (.mk ct cv) (.mk t a) (.mk tb b))
    (hc : evalV s ct cv = .ok x) (ha : evalV s t a = .ok y) (hb : evalV s t b = .ok z)
    (hr : selectV t x y z = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  simp only [exec, hmd, hi, hc, ha, hb, hr, bind, Except.bind, pure, Except.pure]

/-- For every layout, memory, type and value, `withAttrs` with no attribute gives the value. -/
theorem withAttrs_nil (l : Layout) (m : Mem) (t : Ty) (v : Val) :
    withAttrs l m t [] v = .ok v := by
  have hm : ∀ xs : List Val, xs.mapM (fun x => (pure x : Except Fault Val)) = .ok xs := by
    intro xs
    induction xs with
    | nil => rfl
    | cons x xs ih => rw [List.mapM_cons, ih]; rfl
  unfold withAttrs
  simp only [List.foldlM_nil]
  split
  · rw [hm]; rfl
  · rfl

/-- For every signedness and direction, a result of `intMinMax` is defined exactly when both
operands are (a `poison` operand gives `poison`; `undef` and other operands fault). -/
theorem intMinMax_defined {signed max : Bool} {x y r : Val}
    (h : intMinMax signed max x y = .ok r) : r.defined = (x.defined && y.defined) := by
  rcases x with _ | _ | _ | _ | _ | _ <;> rcases y with _ | _ | _ | _ | _ | _ <;>
    simp only [intMinMax, strict2] at h <;>
    (try split at h) <;> cases h <;> simp [Val.defined]

/-- For every signedness and direction, a result of `intMinMax` is that of `lanes2` on it (two
vectors fault in `intMinMax`, so `lanes2` applies it to the operands). -/
theorem lanes2_intMinMax {signed max : Bool} {x y r : Val}
    (h : intMinMax signed max x y = .ok r) :
    lanes2 (fun _ => intMinMax signed max) x y = .ok r := by
  cases x <;> cases y <;> first | exact h | cases h

/-- `exec` of a call of an integer maximum or minimum: for every context, scope, step count and
frame, a statement whose metadata `checkMd` accepts and that calls a declaration that
`c.prog.intrinsics` names `minmax sg mx t`, with two parameters, no fast-math flags and no
parameter, return or call-site attributes, whose attributes `Func.check` accepts, on two operands
that evaluate and on which `intMinMax sg mx` gives `r`, sets its register to `r` and moves to the
next statement, on the same memory. -/
theorem exec_minmax {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {fm ty g ta a tb b fn sg mx t x y r} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .call fm ty (.fn g) [(.mk ta a, []), (.mk tb b, [])])
    (hfn : c.prog.module.funcs.find? (·.name == g) = some fn)
    (hg : c.prog.intrinsics.lookup g = some (.minmax sg mx t)) (hfm : (fm == {}) = true)
    (hd : fn.blocks.isEmpty = true) (hra : fn.retAttrs = []) (hl : fn.params.length = 2)
    (hpa : fn.params.all (·.attrs.isEmpty) = true)
    (hc : fn.check c.prog.module (some (.minmax sg mx t)) = .ok ())
    (ha : evalV s ta a = .ok x) (hb : evalV s tb b = .ok y) (hr : intMinMax sg mx x y = .ok r) :
    exec c s k f st = .ok (.next { f.set st.res (some r) none with pc := f.pc + 1 } s.mem) := by
  obtain ⟨p, q, hpq⟩ := List.length_eq_two.1 hl
  rw [hpq] at hpa
  simp only [List.all_cons, List.all_nil, Bool.and_true, Bool.and_eq_true, List.isEmpty_iff]
    at hpa
  obtain ⟨hp, hq⟩ := hpa
  have hlr := lanes2_intMinMax hr
  have hu : ownUndef c s (.minmax sg mx t) [x, y] = !(x.defined && y.defined) := by
    simp only [ownUndef, intrinsic, hlr, ← intMinMax_defined hr, bind, Except.bind, pure,
      Except.pure]
  cases hxy : (x.defined && y.defined) <;>
  simp [exec, hmd, hi, hfn, hg, hfm, hd, hc, hpq, hp, hq, hra, ha, hb, hu, hxy, hlr, evalTV,
    withAttrs_nil, intrinsic, bind, Except.bind, pure, Except.pure]

end MojoProof.Sym
