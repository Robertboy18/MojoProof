import MojoProof.Sem.SkelStep

/-!
# Contraction off (docs/proofs/contract-off.md)

`Inst.contractOff`, `Stmt.contractOff`, `Block.contractOff`, `Func.contractOff` and
`Module.contractOff` remove the `contract` flag from every float binary operation (`fadd`,
`fsub`, `fmul`, `fdiv`, `frem`) and change nothing else. `neverFuse o` is the oracle row whose
number at `p` is `3 * (o p / 3)`: the NaN choice of `o p` and remainder 0, at which `contract`
never fuses. The fragment `Stmt.fbinOracle`, `Func.fbinOracle`, `Program.fbinOracle` excludes the
other readers of an oracle number: `fpext`, `fptrunc`, and the intrinsics `maxnum`, `minnum` and
`rsqrt.approx`.

Proved here, for every program `P` and every program `Q` with `P`'s module with the flags
removed and `P`'s layout and intrinsics:

- `floatBin_contractOff`: one float operation without `contract` at `n` is the operation with
  its flags at `3 * (n / 3)`, whatever the factors (`floatBin_neverFuse`);
- `exec_contractOff`: one statement of the fragment, in a context of `Q` on a frame with its
  flags and factors removed (`Frame.contractOff`), is the statement in the context of `P` with the
  scope's oracle numbers `3 * (ch i / 3)`, its effect mapped by `Eff.contractOff`. The calls are
  `exec_contractOff_call` and its two cases, the casts `exec_contractOff_cast`;
- `step_contractOff`: one thread step of a thread whose frames' functions are of the fragment,
  under oracle row `neverFuse o` in a context of `P`, is the step of the thread with its frames
  mapped (`Thread.contractOff`) in the context of `Q` with row `o`, its result mapped by
  `Step.contractOff` (`enter_contractOff` for the block entered, `step_contractOff_inst` and
  `step_contractOff_term` for the two cases);
- `Grid.lockstep_contractOff`: for context families related by `CtxOff` (those of `P` with rows
  `neverFuse (ω n)`, those of `Q` with rows `ω n`), the relation "the second grid is the first
  with every frame mapped (`Grid.contractOff`), and every frame's function is of the fragment
  (`Grid.FbinOracle`)" is a lockstep bisimulation, hence `Grid.Sound.contractOff`;
- `Grid.start_contractOff`: the start of `fn.contractOff` in `Q` under `ω` is the start of `fn`
  in `P` under the rows `neverFuse (ω n)`, mapped;
- `Kernel.Sound.contractOff`: for `P` of the fragment (`Program.fbinOracle`) and a kernel of the
  fragment (`Func.fbinOracle`), `Kernel.Sound` of `fn` in `P` gives `Kernel.Sound` of
  `fn.contractOff` in `Q` for every oracle family whose never-fusing rows are admitted.

Not proved here: an instance (docs/proofs/contract-off.md).
-/

namespace MojoProof.Sem

open MojoProof.LLVM

/-- Instruction `i` with the `contract` flag removed if it is a float binary operation; every
other instruction is kept. -/
def _root_.MojoProof.LLVM.Inst.contractOff : Inst → Inst
  | .fbin op fm t a b => .fbin op { fm with contract := false } t a b
  | i => i

/-- Statement `st` with its instruction's `contract` flag removed (`Inst.contractOff`). -/
def _root_.MojoProof.LLVM.Stmt.contractOff (st : Stmt) : Stmt :=
  { st with inst := st.inst.contractOff }

/-- Block `b` with every statement's `contract` flag removed. -/
def _root_.MojoProof.LLVM.Block.contractOff (b : LLVM.Block) : LLVM.Block :=
  { b with stmts := (b.stmts.toList.map Stmt.contractOff).toArray }

/-- Function `fn` with every float binary operation's `contract` flag removed. -/
def _root_.MojoProof.LLVM.Func.contractOff (fn : Func) : Func :=
  { fn with blocks := (fn.blocks.toList.map LLVM.Block.contractOff).toArray }

/-- Module `md` with every function's float binary operations' `contract` flags removed. -/
def _root_.MojoProof.LLVM.Module.contractOff (md : LLVM.Module) : LLVM.Module :=
  { md with funcs := (md.funcs.toList.map Func.contractOff).toArray }

/-- The never-fusing oracle row of `o`: number `3 * (o p / 3)` at position `p`, the NaN choice
of `o p` (`floatBin` delivers at `n / 3`) with the remainder 0, at which `contract` does not
fuse. -/
def neverFuse (o : Nat → Nat) : Nat → Nat := fun p => 3 * (o p / 3)

/-- Statement `st` reads no oracle number unless it is a float binary operation or a call: it is
no `fpext` or `fptrunc`. -/
def _root_.MojoProof.LLVM.Stmt.fbinOracle (st : Stmt) : Bool :=
  !(st.inst matches .cast .fpext .. | .cast .fptrunc ..)

/-- Function `fn` has no `fpext` or `fptrunc` statement (`Stmt.fbinOracle`). -/
def _root_.MojoProof.LLVM.Func.fbinOracle (fn : Func) : Bool :=
  fn.blocks.all fun b => b.stmts.all Stmt.fbinOracle

/-- The only statements of program `P` that read an oracle number are its float binary
operations: no function has an `fpext` or `fptrunc` (`Func.fbinOracle`), and no intrinsic is
`maxnum`, `minnum` or `rsqrt.approx`. -/
def _root_.MojoProof.LLVM.Program.fbinOracle (P : Program) : Bool :=
  P.module.funcs.all Func.fbinOracle &&
    P.intrinsics.all fun p => !(p.2 matches .fminmax .. | .rsqrtApprox)

/-- Frame `f` of a run with contraction off: its function's `contract` flags removed and no
recorded factors. -/
def Frame.contractOff (f : Frame) : Frame :=
  { f with fn := f.fn.contractOff, prods := fun _ => none }

/-- The effect `e` with its frames and functions mapped as `Frame.contractOff` and
`Func.contractOff` do. -/
def Eff.contractOff : Eff → Eff
  | .next f m => .next f.contractOff m
  | .call g args => .call g.contractOff args
  | .wait i args fn => .wait i args fn.contractOff

/-- A block's statements with the flags removed are its statements mapped by `Stmt.contractOff`. -/
theorem _root_.MojoProof.LLVM.Block.contractOff_stmts (b : LLVM.Block) :
    b.contractOff.stmts = b.stmts.map Stmt.contractOff := by
  simp only [LLVM.Block.contractOff]
  rw [← Array.toList_map, Array.toArray_toList]

/-- A function's blocks with the flags removed are its blocks mapped by `Block.contractOff`. -/
theorem _root_.MojoProof.LLVM.Func.contractOff_blocks (fn : Func) :
    fn.contractOff.blocks = fn.blocks.map LLVM.Block.contractOff := by
  simp only [Func.contractOff]
  rw [← Array.toList_map, Array.toArray_toList]

/-- A module's functions with the flags removed are its functions mapped by `Func.contractOff`. -/
theorem _root_.MojoProof.LLVM.Module.contractOff_funcs (md : LLVM.Module) :
    md.contractOff.funcs = md.funcs.map Func.contractOff := by
  simp only [LLVM.Module.contractOff]
  rw [← Array.toList_map, Array.toArray_toList]

/-- The flags removed keep an instruction's operands. -/
theorem _root_.MojoProof.LLVM.Inst.contractOff_operands (i : Inst) :
    i.contractOff.operands = i.operands := by
  cases i <;> rfl

/-- The flags removed keep a function's emptiness. -/
theorem _root_.MojoProof.LLVM.Func.contractOff_isEmpty (fn : Func) :
    fn.contractOff.blocks.isEmpty = fn.blocks.isEmpty := by
  rw [Func.contractOff_blocks]
  simp [Array.isEmpty]

/-- The flags removed keep every register a function uses. -/
theorem _root_.MojoProof.LLVM.Func.contractOff_uses (fn : Func) :
    fn.contractOff.uses = fn.uses := by
  funext r
  simp only [Func.uses, Func.contractOff_blocks, Array.any_map, LLVM.Block.contractOff_stmts,
    Function.comp_def, Stmt.contractOff, Inst.contractOff_operands]
  rfl

/-- The flags removed keep a function's check. -/
theorem _root_.MojoProof.LLVM.Func.contractOff_check (md : LLVM.Module) (fn : Func)
    (i : Option Intrinsic) : fn.contractOff.check md.contractOff i = fn.check md i := by
  unfold Func.check
  rw [Func.contractOff_isEmpty]
  rfl

/-- The flags removed keep a statement's metadata check. -/
theorem _root_.MojoProof.LLVM.Stmt.contractOff_checkMd (st : Stmt) :
    st.contractOff.checkMd = st.checkMd := by
  obtain ⟨r, i, md⟩ := st
  cases i <;> rfl

/-- Removing the flags and the factors semiconjugates setting a register with factors `p` to
setting it with none: for every frame `f`, `(f.set r v p).contractOff = f.contractOff.set r v none`
(the frame with contraction off records no factor). -/
theorem Frame.contractOff_set (r : Option Nat) (v : Option Val) (p : Option (Val × Val)) :
    Function.Semiconj Frame.contractOff (·.set r v p) (·.set r v none) := by
  intro f
  rcases r with _ | r <;> rcases v with _ | v
  all_goals simp only [Frame.set, Frame.contractOff]
  simp only [Frame.mk.injEq, true_and, and_true]
  funext s
  split <;> rfl

mutual
/-- No operand mentions a register of the empty set. -/
theorem Value.mentions_none : ∀ v : Value, v.mentions (fun _ => false) = false
  | .loc _ | .glob _ | .int _ | .float _ | .null | .undef | .poison | .zero => rfl
  | .vec es | .arr es | .struct es => by
    simp only [Value.mentions]
    exact TValue.anyMentions_none es
  | .splat e | .cast _ e _ => by
    simp only [Value.mentions]
    exact TValue.mentions_none e
  | .gep _ _ b idx => by
    simp only [Value.mentions, TValue.mentions_none b, TValue.anyMentions_none idx, Bool.or_self]

/-- `Value.mentions_none` for a typed operand. -/
theorem TValue.mentions_none :
    ∀ v : TValue, v.mentions (fun _ => false) = false
  | .mk _ v => by simpa only [TValue.mentions] using Value.mentions_none v

/-- `Value.mentions_none` for a list of typed operands. -/
theorem TValue.anyMentions_none :
    ∀ vs : List TValue, TValue.anyMentions (fun _ => false) vs = false
  | [] => rfl
  | e :: es => by
    simp only [TValue.anyMentions, TValue.mentions_none e, TValue.anyMentions_none es, Bool.or_self]
end

/-- **Operands** read no oracle number: for every scope, oracle numbers, type and operand. -/
theorem evalV_ch (s : Scope) (ch : Nat → Nat) (t : Ty) (v : Value) :
    evalV { s with ch := ch } t v = evalV s t v :=
  evalV_regs (r := s.regs) (p := fun _ => false) (fun _ _ => rfl) t v (Value.mentions_none v)

/-- At a number `3 * (n / 3)` (remainder 0) `floatBin` does not fuse: the recorded factors are not
read. -/
theorem floatBin_neverFuse (t : FloatTy) (op : FBinOp) (fm : FastMath) (x y : Val)
    (px py : Option (Val × Val)) (n : Nat) :
    floatBin t op fm x y px py (3 * (n / 3)) = floatBin t op fm x y none none (3 * (n / 3)) := by
  have h3 : 3 * (n / 3) % 3 = 0 := Nat.mul_mod_right 3 _
  unfold floatBin
  cases op <;> simp [contract, h3]

/-- **One operation**: for every float type, operator, flags, operands, factors and oracle
number `n`, `floatBin` without `contract` at `n` is `floatBin` with the flags `fm` at
`3 * (n / 3)` (where, by `floatBin_neverFuse`, the factors are not read). -/
theorem floatBin_contractOff (t : FloatTy) (op : FBinOp) (fm : FastMath) (x y : Val)
    (px py : Option (Val × Val)) (n : Nat) :
    floatBin t op { fm with contract := false } x y px py n =
      floatBin t op fm x y none none (3 * (n / 3)) := by
  have h3 : 3 * (n / 3) % 3 = 0 := Nat.mul_mod_right 3 _
  have h3' : 3 * (n / 3) / 3 = n / 3 := by omega
  unfold floatBin
  simp only [h3']
  cases op <;> simp [contract, h3, FastMath.check, withFlags, FastMath.poisons, fbin]

/-! ### Fields the map keeps

These lemmas, and the field lemmas of the map below, are proved by `cases` and not by `rfl`:
`simp` uses a lemma proved by `rfl` as an unfolding, which leaves no mention of the lemma in the
proof term. -/

/-- The flags removed keep a function's name. -/
@[simp] theorem _root_.MojoProof.LLVM.Func.contractOff_name (fn : Func) :
    fn.contractOff.name = fn.name := by cases fn; rfl
/-- The flags removed keep a function's parameters. -/
@[simp] theorem _root_.MojoProof.LLVM.Func.contractOff_params (fn : Func) :
    fn.contractOff.params = fn.params := by cases fn; rfl
/-- The flags removed keep a function's return type. -/
@[simp] theorem _root_.MojoProof.LLVM.Func.contractOff_ret (fn : Func) :
    fn.contractOff.ret = fn.ret := by cases fn; rfl
/-- The flags removed keep a function's return attributes. -/
@[simp] theorem _root_.MojoProof.LLVM.Func.contractOff_retAttrs (fn : Func) :
    fn.contractOff.retAttrs = fn.retAttrs := by cases fn; rfl
/-- The flags removed keep a function's attributes, read in the module with the flags removed
(which keeps the attribute groups). -/
@[simp] theorem _root_.MojoProof.LLVM.Func.contractOff_attrs (md : LLVM.Module) (fn : Func) :
    fn.contractOff.attrs md.contractOff = fn.attrs md := by cases fn; rfl
/-- A statement's instruction with the flags removed. -/
@[simp] theorem _root_.MojoProof.LLVM.Stmt.contractOff_inst (st : Stmt) :
    st.contractOff.inst = st.inst.contractOff := by cases st; rfl
/-- The flags removed keep a statement's metadata. -/
@[simp] theorem _root_.MojoProof.LLVM.Stmt.contractOff_md (st : Stmt) :
    st.contractOff.md = st.md := by cases st; rfl
/-- The flags removed keep a statement's result register. -/
@[simp] theorem _root_.MojoProof.LLVM.Stmt.contractOff_res (st : Stmt) :
    st.contractOff.res = st.res := by cases st; rfl
/-- The flags removed keep a block's label. -/
@[simp] theorem _root_.MojoProof.LLVM.Block.contractOff_label (b : LLVM.Block) :
    b.contractOff.label = b.label := by cases b; rfl
/-- A frame's function with the flags removed. -/
@[simp] theorem Frame.contractOff_fn (f : Frame) :
    f.contractOff.fn = f.fn.contractOff := by cases f; rfl
/-- `Frame.contractOff` keeps the current block. -/
@[simp] theorem Frame.contractOff_label (f : Frame) :
    f.contractOff.label = f.label := by cases f; rfl
/-- `Frame.contractOff` keeps the position. -/
@[simp] theorem Frame.contractOff_pc (f : Frame) : f.contractOff.pc = f.pc := by cases f; rfl
/-- `Frame.contractOff` keeps the registers. -/
@[simp] theorem Frame.contractOff_regs (f : Frame) : f.contractOff.regs = f.regs := by cases f; rfl
/-- `Frame.contractOff` keeps the frame's `alloca` blocks. -/
@[simp] theorem Frame.contractOff_allocas (f : Frame) :
    f.contractOff.allocas = f.allocas := by cases f; rfl

/-- `evalV_ch` for a typed operand. -/
theorem evalTV_ch (s : Scope) (ch : Nat → Nat) (v : TValue) :
    evalTV { s with ch := ch } v = evalTV s v :=
  evalTV_regs (r := s.regs) (p := fun _ => false) (fun _ _ => rfl) v (TValue.mentions_none v)

/-- `evalV_ch` for a list of typed operands. -/
theorem evalTVs_ch (s : Scope) (ch : Nat → Nat) (vs : List TValue) :
    evalTVs { s with ch := ch } vs = evalTVs s vs :=
  evalTVs_regs (r := s.regs) (p := fun _ => false) (fun _ _ => rfl) vs (TValue.anyMentions_none vs)

/-- An intrinsic other than `maxnum`, `minnum` and `rsqrt.approx` reads no oracle number and no
program. -/
theorem intrinsic_contractOff (c : Ctx) (Q : Program) (o : Nat → Nat) (s : Scope)
    (ch : Nat → Nat) (fm : FastMath) {i : Intrinsic}
    (hi : (i matches .fminmax .. | .rsqrtApprox) = false) (args : List Val) :
    intrinsic { c with prog := Q, oracle := o } { s with ch := ch } fm i args =
      intrinsic c s fm i args := by
  unfold intrinsic
  split <;> first | rfl | (simp at hi)

/-- `intrinsic_contractOff` for `ownUndef`. -/
theorem ownUndef_contractOff (c : Ctx) (Q : Program) (o : Nat → Nat) (s : Scope)
    (ch : Nat → Nat) {i : Intrinsic} (hi : (i matches .fminmax .. | .rsqrtApprox) = false)
    (args : List Val) :
    ownUndef { c with prog := Q, oracle := o } { s with ch := ch } i args =
      ownUndef c s i args := by
  unfold ownUndef
  rw [intrinsic_contractOff c Q o s ch {} hi]

/-- The flags removed keep the calls of `llvm.lifetime.start`. -/
theorem lifetimeStarted_contractOff (c : Ctx) {Q : Program} (hi : Q.intrinsics = c.prog.intrinsics)
    (o : Nat → Nat) (fn : Func) :
    lifetimeStarted { c with prog := Q, oracle := o } fn.contractOff = lifetimeStarted c fn := by
  funext r
  simp only [lifetimeStarted, Func.contractOff_blocks, Array.any_map, LLVM.Block.contractOff_stmts,
    Function.comp_def, hi]
  congr 1
  funext b
  congr 1
  funext st
  obtain ⟨_, i, _⟩ := st
  cases i <;> rfl

/-- The flags removed keep the `atomicrmw` check. -/
theorem _root_.MojoProof.LLVM.Stmt.checkAtomic_contractOff (fn : Func) (st : Stmt) :
    st.contractOff.checkAtomic fn.contractOff = st.checkAtomic fn := by
  obtain ⟨r, i, md⟩ := st
  unfold Stmt.checkAtomic
  rw [Func.contractOff_uses]
  cases i <;> rfl

/-- Setting a register keeps the frame's block. -/
@[simp] theorem Frame.set_label (f : Frame) (r : Option Nat) (v : Option Val)
    (p : Option (Val × Val)) : (f.set r v p).label = f.label := by
  unfold Frame.set
  split <;> rfl

/-- `Frame.contractOff` of a frame with its position, label or blocks changed. -/
@[simp] theorem Frame.contractOff_upd (f : Frame) (l pc : Nat) (al : List Nat) :
    (Frame.mk f.fn l pc f.regs f.prods al f.dest).contractOff =
      Frame.mk f.contractOff.fn l pc f.contractOff.regs f.contractOff.prods al f.contractOff.dest :=
  by cases f; rfl

/-- The fragment's premise on the intrinsics, at every name the program maps to one. -/
def IntrinsicsOff (P : Program) : Prop :=
  ∀ g i, P.intrinsics.lookup g = some i → (i matches .fminmax .. | .rsqrtApprox) = false

/-- A statement with contraction off, at a cast other than `fpext` and `fptrunc`. -/
theorem exec_contractOff_cast {c : Ctx} {Q : Program} (hl : Q.layout = c.prog.layout)
    (o : Nat → Nat) (s : Scope) (ch : Nat → Nat) (k : Nat) (f : Frame) (res : Option Nat)
    {op : CastOp} (hop : (op matches .fpext | .fptrunc) = false) (tv : TValue) (ty : Ty)
    (md : List (String × Nat)) :
    exec { c with prog := Q, oracle := o } { s with ch := ch } k f.contractOff
        (Stmt.contractOff ⟨res, .cast op tv ty, md⟩) =
      (exec c s k f ⟨res, .cast op tv ty, md⟩).map Eff.contractOff := by
  have hset : ∀ (f : Frame) r v p, (f.set r v p).contractOff = f.contractOff.set r v none :=
    fun f r v p => Frame.contractOff_set r v p f
  obtain ⟨t, a⟩ := tv
  cases h : exec c s k f _ <;>
  · simp only [exec, bind, Except.bind, pure, Except.pure] at h
    simp only [exec, Stmt.contractOff, Inst.contractOff, bind, Except.bind, pure, Except.pure, hl,
      evalV_ch, castV_ch hop (ch := ch) (ch' := s.ch)]
    repeat' split at h
    all_goals cases h
    all_goals simp only [Except.map, Eff.contractOff,
      Frame.contractOff_upd, Frame.contractOff_pc, Frame.contractOff_label,
      Frame.contractOff_allocas,
      Frame.set_label, Frame.set_allocas, *]

/-- A statement with contraction off, at a call of a function `fn` of the module that is defined
or no intrinsic. -/
theorem exec_contractOff_found {c : Ctx} {Q : Program}
    (hQ : Q.module = c.prog.module.contractOff)
    (hl : Q.layout = c.prog.layout) (hi : Q.intrinsics = c.prog.intrinsics)
    (o : Nat → Nat) (s : Scope) (ch : Nat → Nat) (k : Nat)
    (f : Frame) (res : Option Nat) (fm : FastMath) (ret : Ty) (g : String)
    (args : List (TValue × List Attr)) (md : List (String × Nat)) {fn : Func}
    (hG : c.prog.module.funcs.find? (·.name == g) = some fn)
    (hL : fn.blocks.isEmpty = false ∨ c.prog.intrinsics.lookup g = none) :
    exec { c with prog := Q, oracle := o } { s with ch := ch } k f.contractOff
        ⟨res, .call fm ret (.fn g) args, md⟩ =
      (exec c s k f ⟨res, .call fm ret (.fn g) args, md⟩).map Eff.contractOff := by
  have hF : c.prog.module.contractOff.funcs.find? (·.name == g) = some fn.contractOff := by
    rw [LLVM.Module.contractOff_funcs, Array.find?_map, Function.comp_def]
    simp only [Func.contractOff_name, hG, Option.map_some]
  have hL' : fn.blocks.isEmpty = true → c.prog.intrinsics.lookup g = none :=
    fun h => hL.resolve_left (by simp [h])
  cases hE : fn.blocks.isEmpty
  all_goals
    have hE' := (Func.contractOff_isEmpty fn).trans hE
    cases h : exec c s k f _ <;>
    · simp only [exec, bind, Except.bind, pure, Except.pure, hG, hE, hL', Bool.not_true,
        Bool.not_false, Bool.false_eq_true, ↓reduceIte] at h
      simp only [exec, bind, Except.bind, pure, Except.pure, hl, hi, hQ, hF, hE', hE, hL',
        evalTV_ch, Func.contractOff_params, Bool.not_true, Bool.not_false, Bool.false_eq_true,
        ↓reduceIte]
      repeat' split at h
      all_goals cases h
      all_goals simp only [Except.map, Eff.contractOff, Bool.false_eq_true, ↓reduceIte, *]
      all_goals rfl

/-- A statement with contraction off, at a call of a declaration `fn` of the module that is
intrinsic `i`. -/
theorem exec_contractOff_intrinsic {c : Ctx} {Q : Program}
    (hQ : Q.module = c.prog.module.contractOff)
    (hl : Q.layout = c.prog.layout) (hi : Q.intrinsics = c.prog.intrinsics)
    (hI : IntrinsicsOff c.prog) (o : Nat → Nat) (s : Scope) (ch : Nat → Nat) (k : Nat)
    (f : Frame) (res : Option Nat) (fm : FastMath) (ret : Ty) (g : String)
    (args : List (TValue × List Attr)) (md : List (String × Nat)) {fn : Func} {i : Intrinsic}
    (hG : c.prog.module.funcs.find? (·.name == g) = some fn) (hE : fn.blocks.isEmpty = true)
    (hL : c.prog.intrinsics.lookup g = some i) :
    exec { c with prog := Q, oracle := o } { s with ch := ch } k f.contractOff
        ⟨res, .call fm ret (.fn g) args, md⟩ =
      (exec c s k f ⟨res, .call fm ret (.fn g) args, md⟩).map Eff.contractOff := by
  have hset : ∀ (f : Frame) r v p, (f.set r v p).contractOff = f.contractOff.set r v none :=
    fun f r v p => Frame.contractOff_set r v p f
  have hF : c.prog.module.contractOff.funcs.find? (·.name == g) = some fn.contractOff := by
    rw [LLVM.Module.contractOff_funcs, Array.find?_map, Function.comp_def]
    simp only [Func.contractOff_name, hG, Option.map_some]
  have hE' := (Func.contractOff_isEmpty fn).trans hE
  have e1 := intrinsic_contractOff c Q o s ch fm (hI g i hL)
  have e2 := ownUndef_contractOff c Q o s ch (hI g i hL)
  cases h : exec c s k f _ <;>
  · simp only [exec, bind, Except.bind, pure, Except.pure, hG, hE, hL, Bool.not_true,
      Bool.false_eq_true, ↓reduceIte] at h
    simp only [exec, bind, Except.bind, pure, Except.pure, hl, hi, hQ, hF, hE', hL, evalTV_ch,
      Func.contractOff_params, Func.contractOff_check, Func.contractOff_attrs,
      Func.contractOff_ret, Func.contractOff_retAttrs, e1, e2, Bool.not_true, Bool.false_eq_true,
      ↓reduceIte]
    repeat' split at h
    all_goals cases h
    all_goals simp only [Except.map, Eff.contractOff, Frame.contractOff_upd, Frame.contractOff_pc,
      Frame.contractOff_label, Frame.contractOff_allocas, Frame.set_label, Frame.set_allocas,
      Bool.false_eq_true, ↓reduceIte, *]

/-- A statement with contraction off, at a call. -/
theorem exec_contractOff_call {c : Ctx} {Q : Program} (hQ : Q.module = c.prog.module.contractOff)
    (hl : Q.layout = c.prog.layout) (hi : Q.intrinsics = c.prog.intrinsics)
    (hI : IntrinsicsOff c.prog) (o : Nat → Nat) (s : Scope) (ch : Nat → Nat) (k : Nat)
    (f : Frame) (res : Option Nat) (fm : FastMath) (ret : Ty) (g : String)
    (args : List (TValue × List Attr)) (md : List (String × Nat)) :
    exec { c with prog := Q, oracle := o } { s with ch := ch } k f.contractOff
        ⟨res, .call fm ret (.fn g) args, md⟩ =
      (exec c s k f ⟨res, .call fm ret (.fn g) args, md⟩).map Eff.contractOff := by
  rcases hG : c.prog.module.funcs.find? (·.name == g) with _ | fn
  · have hF : c.prog.module.contractOff.funcs.find? (·.name == g) = none := by
      rw [LLVM.Module.contractOff_funcs, Array.find?_map, Function.comp_def]
      simp only [Func.contractOff_name, hG, Option.map_none]
    cases h : exec c s k f _ <;>
    · simp only [exec, bind, Except.bind, hG] at h
      simp only [exec, bind, Except.bind, hQ, hF, evalTV_ch]
      repeat' split at h
      all_goals cases h
      all_goals simp only [Except.map, *]
      all_goals rfl
  cases hE : fn.blocks.isEmpty
  · exact exec_contractOff_found hQ hl hi o s ch k f res fm ret g args md hG (.inl hE)
  rcases hL : c.prog.intrinsics.lookup g with _ | i
  · exact exec_contractOff_found hQ hl hi o s ch k f res fm ret g args md hG (.inr hL)
  · exact exec_contractOff_intrinsic hQ hl hi hI o s ch k f res fm ret g args md hG hE hL

/-- **One statement.** For every context `c`, every program `Q` with the module of `c.prog` with
the flags removed, `c.prog`'s layout and intrinsics, where `c.prog` maps no name to `maxnum`,
`minnum` or `rsqrt.approx` (`IntrinsicsOff`), every oracle row `o` and every scope `s` whose
oracle numbers are `3 * (ch i / 3)`, every step number and frame, and every statement that is not
an `fpext` or `fptrunc` (`Stmt.fbinOracle`): `exec` of the statement with its flags removed on the
frame with its flags and factors removed (`Frame.contractOff`), in the context of `Q` with oracle
row `o` and the scope's oracle numbers `ch`, is the effect of `exec` in `c` and `s`, mapped by
`Eff.contractOff` (the same fault, the same memory). -/
theorem exec_contractOff {c : Ctx} {Q : Program} (hQ : Q.module = c.prog.module.contractOff)
    (hl : Q.layout = c.prog.layout) (hi : Q.intrinsics = c.prog.intrinsics)
    (hI : IntrinsicsOff c.prog) (o : Nat → Nat) {s : Scope} {ch : Nat → Nat}
    (hs : ∀ i, s.ch i = 3 * (ch i / 3)) (k : Nat) (f : Frame) {st : Stmt}
    (hst : st.fbinOracle = true) :
    exec { c with prog := Q, oracle := o } { s with ch := ch } k f.contractOff st.contractOff =
      (exec c s k f st).map Eff.contractOff := by
  have hset : ∀ (f : Frame) r v p, (f.set r v p).contractOff = f.contractOff.set r v none :=
    fun f r v p => Frame.contractOff_set r v p f
  obtain ⟨res, inst, md⟩ := st
  by_cases hc : ∃ fm ret g args, inst = .call fm ret (.fn g) args
  · obtain ⟨fm, ret, g, args, rfl⟩ := hc
    exact exec_contractOff_call hQ hl hi hI o s ch k f res fm ret g args md
  by_cases hk : ∃ op tv ty, inst = .cast op tv ty
  · obtain ⟨op, tv, ty, rfl⟩ := hk
    refine exec_contractOff_cast hl o s ch k f res ?_ tv ty md
    revert hst
    cases op <;> simp [LLVM.Stmt.fbinOracle]
  rcases inst with _ | _ | ⟨_, ⟨_, _⟩⟩ | _ | _ | ⟨_, ⟨_, _⟩, _⟩ | ⟨⟨_, _⟩, ⟨_, _⟩, ⟨_, _⟩⟩ | _ | _ |
    ⟨_, _, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, _⟩ |
    ⟨_, ⟨_, _⟩, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, _⟩ |
    ⟨_, _, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, _⟩ | ⟨⟨_, _⟩, _⟩ | ⟨⟨_, _⟩, ⟨_, _⟩, _⟩ |
    ⟨⟨_, _⟩, _⟩ | ⟨⟨_, _⟩, _, _⟩ | ⟨⟨_, _⟩, _, _⟩ | ⟨_, _, (_ | _), _⟩ |
    ⟨_, _, ⟨(_ | _ | _ | _ | _ | _ | _ | _ | _), _⟩, ⟨_, _⟩, _, _, _⟩ <;>
  first
  | exact absurd ⟨_, _, _, _, rfl⟩ hc
  | exact absurd ⟨_, _, _, rfl⟩ hk
  | cases h : exec c s k f _ <;>
    · simp only [exec, bind, Except.bind, pure, Except.pure, hs, floatBin_neverFuse] at h
      simp only [exec, Stmt.contractOff_checkMd, Stmt.contractOff_inst, Stmt.contractOff_res,
        Stmt.contractOff_md, Inst.contractOff, bind, Except.bind, pure, Except.pure,
        hl, evalV_ch, evalTV_ch, evalTVs_ch, floatBin_contractOff, lifetimeStarted_contractOff c hi,
        Stmt.checkAtomic_contractOff, Frame.contractOff_fn, Frame.contractOff_regs,
        Bool.and_false, Bool.false_eq_true, ↓reduceIte]
      repeat' split at h
      all_goals cases h
      all_goals simp only [Except.map, Eff.contractOff,
        Frame.contractOff_upd, Frame.contractOff_pc, Frame.contractOff_label,
        Frame.contractOff_allocas, Frame.set_label, Frame.set_allocas, Bool.false_eq_true,
        ↓reduceIte, *]
      all_goals rfl

/-! ### The thread step -/

/-- The flags removed keep the blocks' labels: a lookup by label finds the block with its flags
removed. -/
theorem _root_.MojoProof.LLVM.Func.contractOff_find (fn : Func) (d : Nat) :
    fn.contractOff.blocks.find? (·.label == d) =
      (fn.blocks.find? (·.label == d)).map LLVM.Block.contractOff := by
  rw [Func.contractOff_blocks, Array.find?_map]
  rfl

/-- The flags removed keep a function's entry block, with its flags removed. -/
theorem _root_.MojoProof.LLVM.Func.contractOff_entry (fn : Func) :
    fn.contractOff.blocks[0]? = fn.blocks[0]?.map LLVM.Block.contractOff := by
  rw [Func.contractOff_blocks, Array.getElem?_map]

/-- The flags removed keep a block's terminator. -/
@[simp] theorem _root_.MojoProof.LLVM.Block.contractOff_term (b : LLVM.Block) :
    b.contractOff.term = b.term := by cases b; rfl

/-- `Frame.contractOff` keeps the caller's result register. -/
@[simp] theorem Frame.contractOff_dest (f : Frame) : f.contractOff.dest = f.dest := by cases f; rfl

/-- The flags removed keep a block's leading statements of a predicate `p` that holds on no
statement the map changes and that the map keeps (as `enter`'s test for a `phi`). -/
theorem _root_.MojoProof.LLVM.Block.contractOff_takeWhile (b : LLVM.Block) {p : Stmt → Bool}
    (hp : ∀ st : Stmt, p st = true → st.contractOff = st)
    (hq : ∀ st : Stmt, p st.contractOff = p st) :
    b.contractOff.stmts.toList.takeWhile p = b.stmts.toList.takeWhile p := by
  rw [LLVM.Block.contractOff_stmts, Array.toList_map]
  induction b.stmts.toList with
  | nil => rfl
  | cons st l ih =>
    simp only [List.map_cons, List.takeWhile_cons, hq, ih]
    split
    · next h => rw [hp st h]
    · rfl

/-- **Entering a block** with contraction off: for every scope, oracle numbers `ch`, frame and
target, `enter` on the frame with its flags and factors removed, with the scope's oracle numbers
`ch`, is `enter` on the frame, mapped by `Frame.contractOff` (the `phi`s read no oracle number,
and the map keeps them and the blocks' labels). -/
theorem enter_contractOff (s : Scope) (ch : Nat → Nat) (f : Frame) (d : Nat) :
    enter { s with ch := ch } f.contractOff d = (enter s f d).map Frame.contractOff := by
  have hset : ∀ (f : Frame) r v p, (f.set r v p).contractOff = f.contractOff.set r v none :=
    fun f r v p => Frame.contractOff_set r v p f
  have hfold : ∀ (l : List (Stmt × Val)) (g : Frame),
      l.foldl (fun f x => f.set x.1.res (some x.2) none) g.contractOff =
        (l.foldl (fun f x => f.set x.1.res (some x.2) none) g).contractOff := by
    intro l
    induction l with
    | nil => intro g; rfl
    | cons x l ih =>
      intro g
      simp only [List.foldl_cons]
      rw [← hset, ih]
  simp only [enter, Frame.contractOff_fn, Func.contractOff_find, Frame.contractOff_label, evalV_ch]
  rcases hb : f.fn.blocks.find? (·.label == d) with _ | b
  · simp only [hb, Option.map_none]
    rfl
  simp only [hb, Option.map_some, bind, Except.bind, pure, Except.pure]
  rw [LLVM.Block.contractOff_takeWhile b]
  · split
    · rfl
    · simp only [hfold]
      rfl
  · intro ⟨r, i, md⟩ h
    cases i <;> first | rfl | exact absurd h Bool.false_ne_true
  · intro ⟨r, i, md⟩
    cases i <;> rfl

/-- The thread `t` with every frame mapped by `Frame.contractOff`. -/
def Thread.contractOff (t : Thread) : Thread := { t with frames := t.frames.map Frame.contractOff }

/-- The result of a step with its thread mapped by `Thread.contractOff` and the declaration of a
collective call by `Func.contractOff`. -/
def Step.contractOff : Step → Step
  | .next t m => .next t.contractOff m
  | .wait i args fn => .wait i args fn.contractOff
  | .done m => .done m

/-- The scope of a frame with contraction off, in a context of `Q` with oracle row `o`, is the
frame's scope in `c` with the oracle numbers of `o`. -/
theorem Ctx.scope_contractOff (c : Ctx) {Q : Program} (hl : Q.layout = c.prog.layout)
    (o : Nat → Nat) (m : Mem) (f : Frame) (k : Nat) :
    ({ c with prog := Q, oracle := o } : Ctx).scope m f.contractOff k =
      { c.scope m f k with ch := fun i => o (Nat.pair k i) } := by
  simp only [Ctx.scope, hl, Frame.contractOff_regs]

/-- A step at an instruction, with contraction off (the case `f.pc < b.stmts.size` of
`step_contractOff`). -/
theorem step_contractOff_inst {c : Ctx} {Q : Program} (hQ : Q.module = c.prog.module.contractOff)
    (hl : Q.layout = c.prog.layout) (hi : Q.intrinsics = c.prog.intrinsics)
    (hI : IntrinsicsOff c.prog) {o : Nat → Nat} (hc : c.oracle = neverFuse o) (f : Frame)
    (rest : List Frame) (k : Nat) (m : Mem) {b : LLVM.Block}
    (hb : f.fn.blocks.find? (·.label == f.label) = some b) (hpc : f.pc < b.stmts.size)
    (hst : b.stmts[f.pc].fbinOracle = true) :
    step { c with prog := Q, oracle := o } ⟨f.contractOff :: rest.map Frame.contractOff, k⟩ m =
      (step c ⟨f :: rest, k⟩ m).map Step.contractOff := by
  have hs : ∀ i, (c.scope m f k).ch i = 3 * ((fun i => o (Nat.pair k i)) i / 3) := fun i => by
    simp only [Ctx.scope, hc, neverFuse]
  have key := exec_contractOff hQ hl hi hI o hs k f hst
  have hany : ∀ g : Func, (f.contractOff :: rest.map Frame.contractOff).any
      (·.fn.name == g.contractOff.name) = (f :: rest).any (·.fn.name == g.name) := fun g => by
    rw [show f.contractOff :: rest.map Frame.contractOff = (f :: rest).map Frame.contractOff
      from rfl, List.any_map]
    rfl
  simp only [step, Ctx.scope_contractOff c hl, Frame.contractOff_fn, Frame.contractOff_label,
    Func.contractOff_find, hb, Option.map_some, LLVM.Block.contractOff_stmts, Array.size_map,
    Frame.contractOff_pc, hpc, ↓reduceDIte, Array.getElem_map, key]
  rcases he : exec c (c.scope m f k) k f b.stmts[f.pc] with e | ⟨f', m'⟩ | ⟨g, args⟩ | ⟨i, args, fn⟩
  · simp only [Except.map, bind, Except.bind]
  · simp only [Except.map, bind, Except.bind, pure, Except.pure]
    rfl
  · simp only [Except.map, Eff.contractOff, bind, Except.bind, pure, Except.pure,
      Func.contractOff_entry, hQ, Func.contractOff_check, Func.contractOff_attrs, hany,
      Func.contractOff_params, Stmt.contractOff_res]
    rcases hg : g.blocks[0]? with _ | e
    · simp only [Option.map_none]
      rfl
    simp only [Option.map_some, LLVM.Block.contractOff_label]
    rcases hck : g.check c.prog.module with e' | ⟨⟩
    · simp only
    simp only
    by_cases hr : ((g.attrs c.prog.module).contains (.flag "norecurse") &&
      (f :: rest).any (·.fn.name == g.name)) = true
    · simp only [hr, ↓reduceIte]
      rfl
    · simp only [hr, ↓reduceIte, Bool.false_eq_true]
      rfl
  · simp only [Except.map, bind, Except.bind, pure, Except.pure]
    rfl

/-- A step at a terminator, with contraction off (the case `¬ f.pc < b.stmts.size` of
`step_contractOff`). -/
theorem step_contractOff_term (c : Ctx) {Q : Program} (hl : Q.layout = c.prog.layout)
    (o : Nat → Nat) (f : Frame) (rest : List Frame) (k : Nat) (m : Mem) {b : LLVM.Block}
    (hb : f.fn.blocks.find? (·.label == f.label) = some b) (hpc : ¬ f.pc < b.stmts.size) :
    step { c with prog := Q, oracle := o } ⟨f.contractOff :: rest.map Frame.contractOff, k⟩ m =
      (step c ⟨f :: rest, k⟩ m).map Step.contractOff := by
  have hset : ∀ (f : Frame) r v p, (f.set r v p).contractOff = f.contractOff.set r v none :=
    fun f r v p => Frame.contractOff_set r v p f
  cases h : step c ⟨f :: rest, k⟩ m <;>
  · simp only [step, hb, hpc, ↓reduceDIte, bind, Except.bind, pure, Except.pure] at h
    simp only [step, Ctx.scope_contractOff c hl, Frame.contractOff_fn, Frame.contractOff_label,
      Func.contractOff_find, hb, Option.map_some, LLVM.Block.contractOff_stmts, Array.size_map,
      Frame.contractOff_pc, hpc, ↓reduceDIte, LLVM.Block.contractOff_term, enter_contractOff,
      evalV_ch, evalTV_ch, Func.contractOff_ret, Func.contractOff_retAttrs,
      Frame.contractOff_allocas, Frame.contractOff_dest, bind, Except.bind, pure, Except.pure]
    repeat' split at h
    all_goals cases h
    all_goals simp only [Except.map, List.map_cons, List.map_nil, Step.contractOff,
      Thread.contractOff, Frame.contractOff_upd, Frame.contractOff_pc, Frame.set_label,
      Frame.set_allocas, *]
    all_goals rfl

/-- **One thread step.** For every context `c` with oracle row `neverFuse o`, every program `Q`
with the module of `c.prog` with the flags removed, `c.prog`'s layout and intrinsics, where
`c.prog` maps no name to `maxnum`, `minnum` or `rsqrt.approx` (`IntrinsicsOff`), every thread
whose frames' functions are of the fragment (`Func.fbinOracle`) and every memory: the step of the
thread with its frames mapped by `Frame.contractOff`, in the context of `Q` with oracle row `o`,
is the thread's step in `c`, mapped by `Step.contractOff`. -/
theorem step_contractOff {c : Ctx} {Q : Program} (hQ : Q.module = c.prog.module.contractOff)
    (hl : Q.layout = c.prog.layout) (hi : Q.intrinsics = c.prog.intrinsics)
    (hI : IntrinsicsOff c.prog) {o : Nat → Nat} (hc : c.oracle = neverFuse o) (t : Thread)
    (m : Mem) (ht : ∀ f ∈ t.frames, f.fn.fbinOracle = true) :
    step { c with prog := Q, oracle := o } t.contractOff m = (step c t m).map Step.contractOff := by
  obtain ⟨_ | ⟨f, rest⟩, k⟩ := t
  · rfl
  rcases hb : f.fn.blocks.find? (·.label == f.label) with _ | b
  · simp only [Thread.contractOff, List.map_cons, step, Frame.contractOff_fn,
      Frame.contractOff_label, Func.contractOff_find, hb, Option.map_none]
    rfl
  by_cases hpc : f.pc < b.stmts.size
  · have hf := ht f List.mem_cons_self
    have hst : b.stmts[f.pc].fbinOracle = true :=
      Array.all_eq_true_iff_forall_mem.1
        (Array.all_eq_true_iff_forall_mem.1 hf b (Array.mem_of_find?_eq_some hb)) _
        (Array.getElem_mem hpc)
    exact step_contractOff_inst hQ hl hi hI hc f rest k m hb hpc hst
  · exact step_contractOff_term c hl o f rest k m hb hpc

/-! ### The grid -/

/-- A program of the fragment maps no name to `maxnum`, `minnum` or `rsqrt.approx`. -/
theorem IntrinsicsOff.of_fbinOracle {P : Program} (h : P.fbinOracle = true) : IntrinsicsOff P := by
  intro g i hg
  simp only [LLVM.Program.fbinOracle, Bool.and_eq_true, List.all_eq_true] at h
  obtain ⟨l₁, l₂, e, -⟩ := List.lookup_eq_some_iff.1 hg
  have hm : (g, i) ∈ P.intrinsics := by
    rw [e]
    exact List.mem_append_right _ List.mem_cons_self
  simpa only [Bool.not_eq_true'] using h.2 _ hm

/-- Every frame of thread `t` is of a function of the fragment (`Func.fbinOracle`). -/
def Thread.FbinOracle (t : Thread) : Prop := ∀ f ∈ t.frames, f.fn.fbinOracle = true

/-- A running or waiting thread state's frames are of functions of the fragment. -/
def Status.FbinOracle : Status → Prop
  | .run t | .wait t .. => t.FbinOracle
  | .done => True

/-- Every thread state of grid `g` meets `Status.FbinOracle`. -/
def Grid.FbinOracle (g : Grid) : Prop := ∀ (n : Nat) s, g.threads[n]? = some s → s.FbinOracle

/-- A step keeps `Thread.FbinOracle` in a context whose program is of the fragment: a statement
and a block entry keep the frame's function (`exec_fn`, `enter_fn`), a call pushes a frame of a
function of the module (`exec_call`), a return pops one. -/
theorem step_fbinOracle {c : Ctx} {t t' : Thread} {m m' : Mem} (hP : c.prog.fbinOracle = true)
    (hw : t.FbinOracle) (h : step c t m = .ok (.next t' m')) : t'.FbinOracle := by
  obtain ⟨fs, k⟩ := t
  cases fs with
  | nil => cases h
  | cons f rest =>
  have hf : f.fn.fbinOracle = true := hw f List.mem_cons_self
  have hr : ∀ g ∈ rest, g.fn.fbinOracle = true := fun g hg => hw g (List.mem_cons_of_mem _ hg)
  unfold step at h
  dsimp only at h
  generalize hB : f.fn.blocks.find? (·.label == f.label) = B at h
  cases B with
  | none => cases h
  | some b =>
  dsimp only at h
  by_cases hpc : f.pc < b.stmts.size
  · rw [dite_eq_left hpc] at h
    generalize hE : exec c (c.scope m f k) k f b.stmts[f.pc] = E at h
    cases E with
    | error => cases h
    | ok E =>
    cases E with
    | next f' m₁ =>
      cases h
      intro g hg
      rcases List.mem_cons.1 hg with rfl | hg
      · rw [(exec_fn hE).1]
        exact hf
      · exact hr g hg
    | wait => cases h
    | call g args =>
      obtain ⟨_, _, _, _, _, hgf, _⟩ := exec_call hE
      have hg : g.fbinOracle = true := by
        simp only [LLVM.Program.fbinOracle, Bool.and_eq_true, Array.all_eq_true_iff_forall_mem]
          at hP
        exact hP.1 g (Array.mem_of_find?_eq_some hgf)
      repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
      all_goals cases h
      all_goals
        intro g' hg'
        rcases List.mem_cons.1 hg' with rfl | hg'
        · exact hg
        · exact hw g' hg'
  · rw [dite_eq_right hpc] at h
    repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
    all_goals cases h
    all_goals intro g hg
    all_goals first
      | (rcases List.mem_cons.1 hg with rfl | hg
         · rw [(enter_fn ‹_›).1]
           exact hf
         · exact hr g hg)
      | (rcases List.mem_cons.1 hg with rfl | hg
         · simp only [Frame.set_fn]
           exact hr _ List.mem_cons_self
         · exact hr g (List.mem_cons_of_mem _ hg))

/-- A thread's step in a grid keeps `Grid.FbinOracle`, for contexts of one program of the
fragment. -/
theorem Grid.advance_fbinOracle {P : Program} {c : Nat → Ctx} (hp : ∀ n, (c n).prog = P)
    (hP : P.fbinOracle = true) {g g' : Grid} {n : Nat} (h : g.advance c n = .ok (some g'))
    (hg : g.FbinOracle) : g'.FbinOracle := by
  unfold Grid.advance at h
  split at h
  · rename_i t ht
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      split at h <;> cases h
      · exact set!_inv (P := fun _ (s : Status) => s.FbinOracle) hg
          (step_fbinOracle ((hp n).symm ▸ hP) (hg n _ ht) hr)
      · exact set!_inv (P := fun _ (s : Status) => s.FbinOracle) hg (hg n (.run t) ht)
      · exact set!_inv (P := fun _ (s : Status) => s.FbinOracle) hg trivial
  · cases h

/-- A fire keeps `Grid.FbinOracle`: the threads it resumes keep their frames' functions. -/
theorem Grid.fire_fbinOracle {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.fire L c n = .ok (some g')) (hg : g.FbinOracle) : g'.FbinOracle := by
  have hres : ∀ (t : Thread) v, t.FbinOracle → (t.resume v).FbinOracle := by
    rintro ⟨_ | ⟨f, rest⟩, k⟩ v ht
    · exact ht
    · intro g hg
      rcases List.mem_cons.1 hg with rfl | hg
      · simp only [Frame.set_fn]
        exact ht f List.mem_cons_self
      · exact ht g (List.mem_cons_of_mem _ hg)
  unfold Grid.fire at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | cases ‹throw _ = Except.ok _›
    | exact resumeAll_inv (P := fun _ s => s.FbinOracle) ‹_›
        (fun _ _ _ _ _ r h _ => hres _ r h) hg

/-- Thread state `s` with its thread mapped by `Thread.contractOff` and a collective call's
declaration by `Func.contractOff`. -/
def Status.contractOff : Status → Status
  | .run t => .run t.contractOff
  | .wait t i args fn => .wait t.contractOff i args fn.contractOff
  | .done => .done

/-- Grid `g` with every thread state mapped by `Status.contractOff`, and the same memory. -/
def Grid.contractOff (g : Grid) : Grid := { g with threads := g.threads.map Status.contractOff }

/-- The context families of a program `P` of the fragment and of a program `Q` with `P`'s module
with the flags removed and `P`'s layout and intrinsics: thread `n`'s context `c' n` is `c n` with
program `Q` and oracle row `ω n`, and `c n` has row `neverFuse (ω n)`. -/
structure CtxOff (P Q : Program) (ω : Nat → Nat → Nat) (c c' : Nat → Ctx) : Prop where
  /-- Builds `CtxOff` from its seven fields. -/
  mk ::
  /-- Every context of `c` is of program `P`. -/
  prog : ∀ n, (c n).prog = P
  /-- Thread `n`'s context in `c'` is its context in `c` with program `Q` and row `ω n`. -/
  ctx : ∀ n, c' n = { c n with prog := Q, oracle := ω n }
  /-- Thread `n`'s row in `c` is `neverFuse (ω n)`. -/
  oracle : ∀ n, (c n).oracle = neverFuse (ω n)
  /-- `Q`'s module is `P`'s with the flags removed. -/
  module : Q.module = P.module.contractOff
  /-- `Q` has `P`'s layout. -/
  layout : Q.layout = P.layout
  /-- `Q` has `P`'s intrinsics. -/
  intrinsics : Q.intrinsics = P.intrinsics
  /-- `P` is of the fragment. -/
  frag : P.fbinOracle = true

/-- The pending accesses of a statement with its flags removed, in a context of a program with
the same layout and any oracle row, on a scope with any oracle numbers, are the statement's: the
map keeps every `load`, `store` and `atomicrmw`, and pointer operands read no oracle number. -/
theorem Stmt.pending_contractOff (c : Ctx) {Q : Program} (hl : Q.layout = c.prog.layout)
    (o : Nat → Nat) (s : Scope) (ch : Nat → Nat) (st : Stmt) :
    st.contractOff.pending { c with prog := Q, oracle := o } { s with ch := ch } =
      st.pending c s := by
  obtain ⟨r, i, md⟩ := st
  cases i <;> simp only [LLVM.Stmt.pending, Stmt.contractOff, Inst.contractOff, evalV_ch, hl]

/-- The pending accesses of a thread with its frames mapped by `Frame.contractOff`, in a context
of a program with the same layout and any oracle row, are the thread's. -/
theorem Thread.pending_contractOff (c : Ctx) {Q : Program} (hl : Q.layout = c.prog.layout)
    (o : Nat → Nat) (t : Thread) (m : Mem) :
    t.contractOff.pending { c with prog := Q, oracle := o } m = t.pending c m := by
  obtain ⟨_ | ⟨f, rest⟩, k⟩ := t
  · rfl
  simp only [Thread.contractOff, List.map_cons, Thread.pending, Frame.contractOff_fn,
    Frame.contractOff_label, Func.contractOff_find, Frame.contractOff_pc]
  rcases hb : f.fn.blocks.find? (·.label == f.label) with _ | b
  · simp only [hb, Option.map_none]
  simp only [hb, Option.map_some, LLVM.Block.contractOff_stmts, Array.getElem?_map]
  rcases hs : b.stmts[f.pc]? with _ | st
  · simp only [Option.map_none]
  simp only [Option.map_some, Ctx.scope_contractOff c hl, Stmt.pending_contractOff c hl]

/-- **A thread's step in the grid.** For context families related by `CtxOff` and every grid
whose frames are of the fragment, thread `n`'s step in the grid mapped by `Grid.contractOff`
under `c'` is its step under `c`, mapped. -/
theorem Grid.advance_contractOff {P Q : Program} {ω : Nat → Nat → Nat} {c c' : Nat → Ctx}
    (h : CtxOff P Q ω c c') {g : Grid} (hg : g.FbinOracle) (n : Nat) :
    g.contractOff.advance c' n = (g.advance c n).map (Option.map Grid.contractOff) := by
  simp only [Grid.advance, Grid.contractOff, Array.getElem?_map]
  rcases ht : g.threads[n]? with _ | (t | ⟨t, i, args, fn⟩ | _)
  · rfl
  · have hQ : Q.module = (c n).prog.module.contractOff := by rw [h.prog n]; exact h.module
    have hl : Q.layout = (c n).prog.layout := by rw [h.prog n]; exact h.layout
    have hi : Q.intrinsics = (c n).prog.intrinsics := by rw [h.prog n]; exact h.intrinsics
    have hI : IntrinsicsOff (c n).prog := (h.prog n).symm ▸ IntrinsicsOff.of_fbinOracle h.frag
    have hs := step_contractOff hQ hl hi hI (h.oracle n) t g.mem (hg n _ ht)
    simp only [Option.map_some, Status.contractOff, h.ctx n, hs]
    rcases step (c n) t g.mem with e | (⟨t', m'⟩ | ⟨i, args, r⟩ | m') <;>
      simp only [Except.map, bind, Except.bind, pure, Except.pure, Step.contractOff,
        Option.map_some, Array.set!_eq_setIfInBounds, Grid.contractOff,
        Array.map_setIfInBounds, Status.contractOff]
  · rfl
  · rfl

/-- Grid `g` mapped by `Grid.contractOff` is done exactly when `g` is. -/
theorem Grid.done_contractOff (g : Grid) : g.contractOff.Done ↔ g.Done := by
  simp only [Grid.Done, Grid.contractOff, Array.all_map]
  apply Iff.of_eq
  congr 2
  funext s
  cases s <;> rfl

/-- For context families related by `CtxOff`, a race is enabled in grid `g` mapped by
`Grid.contractOff` under `c'` exactly when one is in `g` under `c`. -/
theorem Grid.raceEnabled_contractOff {P Q : Program} {ω : Nat → Nat → Nat} {c c' : Nat → Ctx}
    (h : CtxOff P Q ω c c') (g : Grid) : g.contractOff.RaceEnabled c' ↔ g.RaceEnabled c := by
  have hp : ∀ n (t : Thread), t.contractOff.pending (c' n) g.mem = t.pending (c n) g.mem :=
    fun n t => by
      rw [h.ctx n]
      exact Thread.pending_contractOff (c n) (by rw [h.prog n]; exact h.layout) _ t g.mem
  constructor
  · rintro ⟨n, t', ht, hr⟩
    simp only [Grid.contractOff, Array.getElem?_map] at ht
    rcases hs : g.threads[n]? with _ | (t | _ | _) <;>
      simp only [hs, Option.map_none, Option.map_some, Status.contractOff, reduceCtorEq,
        Option.some.injEq, Status.run.injEq] at ht
    subst ht
    refine ⟨n, t, hs, ?_⟩
    rw [← hp]
    exact hr
  · rintro ⟨n, t, ht, hr⟩
    refine ⟨n, t.contractOff, ?_, ?_⟩
    · simp only [Grid.contractOff, Array.getElem?_map, ht, Option.map_some, Status.contractOff]
    show racy (t.contractOff.pending (c' n) g.mem ++ g.mem.trace) = true
    rw [hp]
    exact hr

/-- `Thread.contractOff` keeps the instruction a thread is at. -/
theorem Thread.at_contractOff (t : Thread) : t.contractOff.at = t.at := by
  obtain ⟨_ | ⟨f, rest⟩, k⟩ := t <;> rfl

/-- Resuming with every value `v` commutes with `Thread.contractOff`: for every thread `t`,
`(t.resume v).contractOff = t.contractOff.resume v` (the map keeps the block, the position and
the call's result register). -/
theorem Thread.resume_contractOff (v : Option Val) :
    Function.Commute Thread.contractOff (Thread.resume · v) := by
  intro t
  refine Eq.symm (?_ : t.contractOff.resume v = (t.resume v).contractOff)
  have hset : ∀ (f : Frame) r v p, (f.set r v p).contractOff = f.contractOff.set r v none :=
    fun f r v p => Frame.contractOff_set r v p f
  have hset' : ∀ (f : Frame) r v, f.contractOff.set r v none = (f.set r v none).contractOff :=
    fun f r v => (hset f r v none).symm
  obtain ⟨_ | ⟨f, rest⟩, k⟩ := t
  · rfl
  simp only [Thread.contractOff, List.map_cons, Thread.resume, Frame.contractOff_fn,
    Frame.contractOff_label, Func.contractOff_find, Frame.contractOff_pc]
  rcases hb : f.fn.blocks.find? (·.label == f.label) with _ | b
  · simp only [hb, Option.map_none, Option.bind_none, hset']
    rfl
  simp only [hb, Option.map_some, Option.bind_some, LLVM.Block.contractOff_stmts,
    Array.getElem?_map]
  rcases hs : b.stmts[f.pc]? with _ | st
  · simp only [Option.map_none, Option.bind_none, hset']
    rfl
  simp only [Option.map_some, Option.bind_some, Stmt.contractOff_res, hset']
  rfl

/-- `resumeAll` on the thread states mapped by `Status.contractOff` gives the same fault, or the
states it gives, mapped. -/
theorem resumeAll_contractOff (l : Layout) (m : Mem) (ns : List Nat) (v : Nat → Option Val)
    (ts : Array Status) :
    Except.Rel (fun ts₁ ts₂ => ts₂ = ts₁.map Status.contractOff) (resumeAll l m ts ns v)
      (resumeAll l m (ts.map Status.contractOff) ns v) := by
  unfold resumeAll
  refine Except.Rel.foldlM (R := fun (x y : Array Status) => y = x.map Status.contractOff) ?_ rfl
  rintro k - x _ rfl
  simp only [Array.getElem?_map]
  rcases hx : x[k]? with _ | (t | ⟨t, i, a, fn⟩ | _)
  · simp only [Option.map_none]
    exact .ok rfl
  · simp only [Option.map_some, Status.contractOff]
    exact .ok rfl
  · simp only [Option.map_some, Status.contractOff, Func.contractOff_ret,
      Func.contractOff_retAttrs]
    have hres : ∀ (t : Thread) r, t.contractOff.resume r = (t.resume r).contractOff :=
      fun t r => (Thread.resume_contractOff r t).symm
    refine Except.Rel.bind (Except.Rel.refl (R := Eq) (fun _ => rfl) _) fun r _ e => ?_
    subst e
    exact .ok (by simp only [Array.set!_eq_setIfInBounds, Array.map_setIfInBounds,
      Status.contractOff, hres])
  · simp only [Option.map_some, Status.contractOff]
    exact .ok rfl

/-- **A collective call in the grid.** For context families related by `CtxOff`, thread `n`'s
collective call in grid `g` under `c` and in `g` mapped by `Grid.contractOff` under `c'` give one
fault, both none, or grids the second of which is the first mapped: the participants, their
positions (`Thread.at_contractOff`) and arguments are the same, and resuming commutes with the
map (`resumeAll_contractOff`). -/
theorem Grid.fire_contractOff {P Q : Program} {ω : Nat → Nat → Nat} {c c' : Nat → Ctx}
    (h : CtxOff P Q ω c c') (L : Launch) (g : Grid) (n : Nat) :
    Except.Rel (Option.Rel fun (g₁ g₂ : Grid) => g₂ = g₁.contractOff) (g.fire L c n)
      (g.contractOff.fire L c' n) := by
  have hl : (c' n).prog.layout = (c n).prog.layout := by
    rw [h.ctx n, h.prog n]
    exact h.layout
  have ht : ∀ k : Nat, Option.Rel (fun (s₁ s₂ : Status) => s₂ = s₁.contractOff) g.threads[k]?
      g.contractOff.threads[k]? := by
    intro k
    simp only [Grid.contractOff, Array.getElem?_map]
    cases g.threads[k]? with
    | none => exact .none
    | some s => exact .some rfl
  unfold Grid.fire
  rw [hl]
  have htn := ht n
  generalize g.threads[n]? = s₁ at htn ⊢
  generalize g.contractOff.threads[n]? = s₂ at htn ⊢
  cases htn with
  | none => exact .ok .none
  | @some x₁ x₂ hs =>
  subst hs
  cases x₁ with
  | run t => exact .ok .none
  | done => exact .ok .none
  | wait t i args fn =>
  dsimp only [Status.contractOff]
  cases i
  all_goals try exact .error _
  case barrier =>
    rcases args with _ | ⟨x, _ | ⟨y, r⟩⟩
    all_goals try exact .error _
    dsimp only
    generalize x.word? = w
    cases w with
    | none => exact .error _
    | some bar =>
    dsimp only
    refine Except.Rel.ite (fun _ => ?_) (fun _ => .error _)
    refine Except.Rel.bind (Except.Rel.mapM (R := Eq) (S := Eq) ?_
      ((List.forall₂_same (Rₐ := (· = ·))).2 fun _ _ => rfl)) ?_
    · intro k k' e
      rw [← e]
      have hk := ht k
      generalize g.threads[k]? = o₁ at hk ⊢
      generalize g.contractOff.threads[k]? = o₂ at hk ⊢
      cases hk with
      | none => exact .ok rfl
      | @some y₁ y₂ hy =>
      subst hy
      cases y₁ with
      | run => exact .ok rfl
      | done => exact .error _
      | wait u j b fn' =>
      dsimp only [Status.contractOff]
      cases j
      all_goals try exact .ok rfl
      rcases b with _ | ⟨x', _ | ⟨y', r'⟩⟩
      all_goals try exact .ok rfl
      dsimp only
      simp only [Thread.at_contractOff]
      exact .refl (fun _ => rfl) _
    · intro s₁ s₂ hs
      rw [List.forall₂_eq_eq_eq] at hs
      subst hs
      refine Except.Rel.ite (fun _ => ?_) (fun _ => .ok .none)
      exact Except.Rel.bind (resumeAll_contractOff _ _ _ _ _) fun _ _ e => .ok (.some (by
        subst e
        rfl))
  case shfl mode =>
    rcases args with _ | ⟨msk, _ | ⟨a, _ | ⟨b, _ | ⟨cc, _ | ⟨_, _⟩⟩⟩⟩⟩
    all_goals try exact .error _
    dsimp only
    generalize msk.word? = w
    cases w with
    | none => exact .error _
    | some mask =>
    dsimp only
    refine Except.Rel.ite (fun _ => ?_) (fun _ => .error _)
    generalize n - n % volume L.block % 32 = base
    refine Except.Rel.bind (Except.Rel.mapM (R := Eq) (S := Eq) ?_
      ((List.forall₂_same (Rₐ := (· = ·))).2 fun _ _ => rfl)) ?_
    · intro j j' e
      rw [← e]
      have hj := ht (base + j)
      generalize g.threads[base + j]? = o₁ at hj ⊢
      generalize g.contractOff.threads[base + j]? = o₂ at hj ⊢
      cases hj with
      | none => exact .ok rfl
      | @some y₁ y₂ hy =>
      subst hy
      cases y₁ with
      | run => exact .ok rfl
      | done => exact .error _
      | wait u j₁ b₁ fn' =>
      dsimp only [Status.contractOff]
      cases j₁
      all_goals try exact .error _
      rcases b₁ with _ | ⟨_, _ | ⟨_, _ | ⟨_, _ | ⟨_, _ | ⟨_, _⟩⟩⟩⟩⟩
      all_goals try exact .error _
      dsimp only
      simp only [Thread.at_contractOff]
      exact .refl (fun _ => rfl) _
    · intro ps₁ ps₂ hps
      rw [List.forall₂_eq_eq_eq] at hps
      subst hps
      generalize List.mapM (m := Option) id ps₁ = o
      cases o with
      | none => exact .ok .none
      | some parts =>
      dsimp only
      exact Except.Rel.bind (resumeAll_contractOff _ _ _ _ _) fun _ _ e => .ok (.some (by
        subst e
        rfl))

/-- **The lockstep bisimulation.** For every launch and context families related by `CtxOff`,
the relation "the second grid is the first mapped by `Grid.contractOff`, and the first's frames
are of the fragment" is a lockstep bisimulation (`Grid.Lockstep`) between `c` and `c'`. -/
theorem Grid.lockstep_contractOff {P Q : Program} {ω : Nat → Nat → Nat} {c c' : Nat → Ctx}
    (h : CtxOff P Q ω c c') (L : Launch) :
    Grid.Lockstep L c c' fun g₁ g₂ => g₁.FbinOracle ∧ g₂ = g₁.contractOff where
  advance := by
    rintro g₁ _ ⟨hg, rfl⟩ n
    rw [Grid.advance_contractOff h hg n]
    rcases ha : g₁.advance c n with _ | _ | g'
    · trivial
    · trivial
    · exact ⟨Grid.advance_fbinOracle h.prog h.frag ha hg, rfl⟩
  fire := by
    rintro g₁ _ ⟨hg, rfl⟩ n
    have hr := Grid.fire_contractOff h L g₁ n
    generalize hf : g₁.fire L c n = r₁ at hr ⊢
    generalize g₁.contractOff.fire L c' n = r₂ at hr ⊢
    cases hr with
    | error e => trivial
    | ok hr =>
      cases hr with
      | none => trivial
      | some e => exact ⟨Grid.fire_fbinOracle hf hg, e⟩
  done := by
    rintro g₁ _ ⟨-, rfl⟩
    exact (Grid.done_contractOff g₁).symm
  trace := by
    rintro g₁ _ ⟨-, rfl⟩
    rfl
  race := by
    rintro g₁ _ ⟨-, rfl⟩
    exact (Grid.raceEnabled_contractOff h g₁).symm

/-- **`Grid.Sound` with contraction off.** For every launch, context families related by
`CtxOff`, grid whose frames are of the fragment, observation and relation: if the grid is sound
under `c` (the contexts of `P` with rows `neverFuse (ω n)`), the grid mapped by `Grid.contractOff`
is sound under `c'` (the contexts of `Q` with rows `ω n`). -/
theorem Grid.Sound.contractOff {P Q : Program} {ω : Nat → Nat → Nat} {c c' : Nat → Ctx}
    (h : CtxOff P Q ω c c') {L : Launch} {g : Grid} (hg : g.FbinOracle) {β : Type}
    {obs : Mem → Option β} {R : β → Prop} (hs : Grid.Sound L c g obs R) :
    Grid.Sound L c' g.contractOff obs R :=
  (Grid.lockstep_contractOff h L).sound ⟨hg, rfl⟩ (fun ⟨_, e⟩ _ => by rw [e]; rfl) hs

/-! ### The start -/

/-- The flags removed keep a kernel's start: for every kernel `fn` and arguments `args`, the
thread at the start of `fn.contractOff` is the thread at the start of `fn` mapped by
`Thread.contractOff` (or both fail, with the same fault). -/
theorem Thread.start_contractOff (fn : Func) (args : List Val) :
    Thread.start fn.contractOff args = (Thread.start fn args).map Thread.contractOff := by
  unfold Thread.start
  rw [Func.contractOff_entry, Func.contractOff_params]
  cases fn.blocks[0]? <;> rfl

/-- **The start with contraction off.** For every program `P`, program `Q` with the module of
`P.contractOff` and the layout of `P`, kernel `fn`, launch, arguments, memory, address choices
`ch` and oracle family `ω`: the start of `fn.contractOff` in `Q` under `ω` and the start of `fn`
in `P` under the rows `neverFuse (ω n)` both fail, or both succeed, the first with the second's
grid mapped by `Grid.contractOff` and its contexts with program `Q` and rows `ω n`. -/
theorem Grid.start_contractOff {P Q : Program} (hQ : Q.module = P.module.contractOff)
    (hl : Q.layout = P.layout) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    (ch : Nat → Nat) (ω : Nat → Nat → Nat) :
    Except.Rel (fun r₁ r₂ : Grid × (Nat → Ctx) => r₂.1 = r₁.1.contractOff ∧
        ∀ n, r₂.2 n = { r₁.2 n with prog := Q, oracle := ω n })
      (Grid.start P fn L args m ch fun n => neverFuse (ω n))
      (Grid.start Q fn.contractOff L args m ch ω) := by
  unfold Grid.start
  dsimp only
  rw [hQ, hl, Func.contractOff_check]
  refine Except.Rel.bind_eq _ fun _ _ => ?_
  refine Except.Rel.bind_eq _ fun _ _ => ?_
  refine Except.Rel.bind (R := Eq) (.refl (fun _ => rfl) _) fun x y hxy => ?_
  subst hxy
  obtain ⟨a, tabs⟩ := x
  dsimp only
  refine Except.Rel.bind (R := fun r₁ r₂ : Mem × Array Status =>
    r₂ = (r₁.1, r₁.2.map Status.contractOff)) ?_ fun x y hxy => ?_
  · refine Except.Rel.foldlM (fun k _ x y hxy => ?_) (by rw [Array.map_empty])
    subst hxy
    obtain ⟨a₁, ts⟩ := x
    dsimp only
    refine Except.Rel.bind (R := Eq) (.refl (fun _ => rfl) _) fun x y hxy => ?_
    subst hxy
    obtain ⟨a₂, vs⟩ := x
    dsimp only
    rw [Thread.start_contractOff]
    cases Thread.start fn vs with
    | error e => exact .error e
    | ok t => exact .ok (by rw [Array.map_push]; rfl)
  subst hxy
  exact .ok ⟨rfl, fun _ => rfl⟩

/-- The start grid of a kernel of the fragment meets `Grid.FbinOracle`: its threads run the
kernel's entry frame alone. -/
theorem Grid.start_fbinOracle {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (hfn : fn.fbinOracle = true) :
    g.FbinOracle := by
  intro j s hs
  obtain ⟨-, as, t, ht, rfl⟩ := Grid.start_run h j s hs
  intro f hf
  unfold Thread.start at ht
  split at ht
  · cases ht
    simp only [List.mem_singleton] at hf
    subst hf
    exact hfn
  · cases ht

/-- **`Kernel.Sound` with contraction off.** For every program `P` of the fragment
(`Program.fbinOracle`), program `Q` with the module of `P.contractOff`, the layout of `P` and the
intrinsics of `P`, kernel `fn` with no `fpext` or `fptrunc` (`Func.fbinOracle`), launch,
arguments, memory, admissibility `adm`, observation and relation `R`: if `fn` is sound in `P`
for `adm`, then `fn.contractOff` is sound in `Q` for every address choices `ch` and oracle family
`ω` whose rows `neverFuse (ω n)` `adm` admits with `ch`. -/
theorem Kernel.Sound.contractOff {P Q : Program} (hQ : Q.module = P.module.contractOff)
    (hl : Q.layout = P.layout) (hi : Q.intrinsics = P.intrinsics) (hP : P.fbinOracle = true)
    {fn : Func} (hfn : fn.fbinOracle = true) {L : Launch} {args : List Val} {m : Mem}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
    {R : β → Prop} (h : Kernel.Sound P fn L args m adm obs R) :
    Kernel.Sound Q fn.contractOff L args m (fun ch ω => adm ch fun n => neverFuse (ω n)) obs R := by
  intro ch ω ha
  obtain ⟨g, c, hs, hg⟩ := h ch _ ha
  have hr := Grid.start_contractOff hQ hl fn L args m ch ω
  rw [hs] at hr
  generalize Grid.start Q fn.contractOff L args m ch ω = r at hr ⊢
  cases hr with
  | @ok _ r₂ hr =>
  obtain ⟨g₂, c₂⟩ := r₂
  obtain ⟨rfl, hc⟩ := hr
  have hC : CtxOff P Q ω c c₂ :=
    { prog := fun n => (Grid.start_ctx hs n).1
      ctx := hc
      oracle := fun n => (Grid.start_ctx hs n).2.2.2
      module := hQ
      layout := hl
      intrinsics := hi
      frag := hP }
  exact ⟨_, c₂, rfl, Grid.Sound.contractOff hC (Grid.start_fbinOracle hs hfn) hg⟩

end MojoProof.Sem
