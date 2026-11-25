import MojoProof.Sym.Block

/-!
# Segments of a block that end at a collective call or a lifetime marker

A thread's step at a call of the barrier or of a warp shuffle is `.wait i args fn` (`step`,
`exec`: `intrinsic` gives no result for them), and the grid layer resumes the thread with the
call's value in its register (`Thread.resume`). So the block checker's summary of a whole block
(`summarize`, which ends at the terminator) does not reach past such a call. This module adds
the summary of a segment of a block that ends at one:

* `Coll`: the collectives a segment can end at (the barrier, a warp shuffle).
* `SState.waitAt`: the collective call a statement makes, with its argument terms.
* `SegSummary` and `summarizeTo P fn lbl p0 p1`: the summary of the statements at positions
  `p0 ≤ pc < p1` of block `lbl`, by the checker's statement case (`SState.run`), ending at the
  collective call at `p1` with its argument terms; a new structure, so `Exit` and `Summary` keep
  their constructors.
* `Seg.sound`: for every program, from a valuation meeting the summary's obligations, the
  thread's steps run the segment and reach the call's `.wait`, with the arguments' values
  (`Waits`). The segment after the last collective is `summarize P fn lbl (p1 + 1)` on the
  resumed thread (`Thread.resume_at`), so `Block.sound` covers it.
* `Seg.resume`: `Seg.sound` with the resumed position: the thread reaches the `.wait` of the
  segment's collective, and resumed with any value its frame is at `p1 + 1`, where the next
  segment starts.
* `summarizeSegs`, `Seg.Through` and `Seg.through`: the summaries of a block's segments that end
  at the collective calls at given positions, and of the rest after the last call; for every
  program, the thread runs them in turn (`Seg.Through`), with the values and memories the
  collectives deliver as parameters and each segment's obligations a premise at its start frame;
  `Seg.through` is `Piece.through` with collectives only.
* `SState.lifeAt`, `summarizeLife`, `Seg.life` and `Seg.lifetime`: a segment that ends at a call of
  `llvm.lifetime.start` or `llvm.lifetime.end`, whose effect (`Mem.setLive`, or none on
  `poison`) the summary's effects cannot replay; for every program, the thread's steps reach the
  marker on the memory the segment's effects make, and the step there moves, on the memory
  `intrinsic` gives, to the position after it, where the next segment starts (`exec_lifetime`;
  `withAttrs_args` for the parameter's `captures(none)`), with the frame's registers there
  (`Seg.life`; `Seg.lifetime` without them); `Seg.lifetime_ptr`, that memory on a pointer the
  thread owns (`Mem.setLive`, `intrinsic_lifetime_ptr`) and on `poison`.
* `Piece`, `summarizePiece`, `summarizePieces`, `Piece.ThroughTo`, `Piece.throughTo`,
  `Piece.Through` and `Piece.through`: a block through its collectives and its lifetime markers.
  The segments end at the calls at given positions, each a collective's (`summarizeTo`) or a
  lifetime marker's (`summarizeLife`), and the summary of the rest follows the last; for every
  program, the thread runs them in turn (`Piece.ThroughTo`): at a collective it waits and resumes
  with the delivered value and memory, at a marker it steps on the memory `intrinsic` gives, each
  segment's obligations are a premise at its start frame, and after the last call a continuation
  `K` holds of the thread, memory and frame reached, for every `K` that holds at the position
  after the last call (`Piece.throughTo`, `summarizePieces_last`). `Piece.Through` is
  `Piece.ThroughTo` whose continuation is the rest of the block to its end, and `Piece.through`
  is `Piece.throughTo` with `Block.sound_withAt` there. `summarizeSegs_pieces` and
  `Piece.Through.seg`: with collectives only, the same segments and `Seg.Through`.
* The `alloca` flag: `summarizeTo`, `summarizeLife`, `summarizePiece` and `summarizePieces` take
  the block checker's flag (`SState.alloca`, off by default), so a segment, and the rest after
  the last call (`summarizeAt`), may make `alloca`s (`SEff.alloca`); `Waits`, `Seg.life` and
  `Piece.Through` give the frame's `alloca` blocks as the segment's (`SEff.blocks`) followed by
  the entry frame's, and at the block's end `Piece.Through` gives `EndsAt false`
  (`Block.sound_withAt`). With the flag off a segment and the rest make none
  (`summarizeTo_allocates`, `summarizeSegs_allocates`), so `Seg.Through` keeps the entry frame's
  (`EndsAt.ends`).

Scope: every program (`Seg.sound`, `Seg.resume`, `Seg.through`, `Seg.life`, `Seg.lifetime`,
`Piece.throughTo`, `Piece.through`), with the flag on or off; the tests are the warp reductions
of tests/corpus/gemv/, the lifetime markers of tests/corpus/layernorm/ and of gemv_kernel's entry
block (MojoProofTest/SymSeg.lean).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- The collective calls a segment ends at (`summarizeTo`): the intrinsics at which `exec` gives
`.wait` and that the block checker summarizes up to. -/
inductive Coll where
  /-- `llvm.nvvm.barrier.cta.sync.aligned.all` (`Intrinsic.barrier`). -/
  | barrier
  /-- `llvm.nvvm.shfl.sync.<m>.i32` (`Intrinsic.shfl m`). -/
  | shfl (m : Shfl)
  deriving DecidableEq, Repr

/-- The intrinsic of a collective. -/
def Coll.intr : Coll → Intrinsic
  | .barrier => .barrier
  | .shfl m => .shfl m

/-- The collective intrinsic `i` is: the barrier and the warp shuffles; `none` for the others. -/
def Coll.of : Intrinsic → Option Coll
  | .barrier => some .barrier
  | .shfl m => some (.shfl m)
  | _ => none

/-- The collective `Coll.of` gives has the intrinsic it was given. -/
theorem Coll.of_intr {i : Intrinsic} {cl : Coll} (h : Coll.of i = some cl) : cl.intr = i := by
  cases i <;> first | (cases h; rfl) | cases h

/-- For every context, scope, flags and arguments, `intrinsic` gives no result at a collective
(the grid layer completes the call). -/
theorem Coll.intrinsic_none (cl : Coll) (c : Ctx) (s : Scope) (fm : FastMath) (vs : List Val) :
    intrinsic c s fm cl.intr vs = .ok none := by
  cases cl <;> rfl

/-- The entry of typed operand `a` (`SState.op` at its type). -/
def SState.tvOp (σ : SState) : TValue → Option SVal
  | .mk t v => σ.op t v

/-- The collective call statement `st` makes from state `σ`, with its argument terms: `st`'s
metadata passes `checkMd`, and it calls, with no fast-math flags and no call-site attributes, a
declaration (no blocks) of `P` that `P.intrinsics` names a collective (`Coll.of`), whose
parameters, as many as the arguments, have no attributes and whose attributes `Func.check`
accepts; and every argument has an entry (`SState.tvOp`). `none` otherwise. -/
def SState.waitAt (P : Program) (σ : SState) (st : Stmt) : Option (Coll × List SVal) :=
  if st.checkMd.isOk then
    match st.inst with
    | .call fm _ (.fn g) args =>
      match P.module.funcs.find? (·.name == g), P.intrinsics.lookup g with
      | some fn, some i => match Coll.of i with
        | some cl =>
          if (fm == {}) && fn.blocks.isEmpty && fn.params.length == args.length &&
              fn.params.all (·.attrs.isEmpty) && args.all (·.2.isEmpty) &&
              (fn.check P.module (some i)).isOk then
            match args.mapM fun a => σ.tvOp a.1 with
            | some xs => some (cl, xs)
            | none => none
          else none
        | none => none
      | _, _ => none
    | _ => none
  else none

/-- The summary of a segment that ends at a collective call: the node table (in order), the
registers the segment sets with their entries (latest first), its memory effects, its
obligations, the collective, the call's argument terms, and the number of statements it runs
before the call. -/
structure SegSummary where
  /-- The summary from its node table, register entries, memory effects, obligations,
  collective, argument terms and number of statements. -/
  mk ::
  /-- The node table, in order. -/
  nodes : List SNode
  /-- The registers set, latest first, with their entries. -/
  regs : List (Nat × SVal)
  /-- The memory effects, in order. -/
  effs : List SEff
  /-- The obligations. -/
  obls : List Cond
  /-- The collective the segment ends at. -/
  call : Coll
  /-- The terms of the call's arguments. -/
  args : List SVal
  /-- The number of statements run before the call. -/
  len : Nat
  deriving DecidableEq, Repr

/-- The summary of the statements at positions `p0 ≤ pc < p1` of block `lbl` of `fn` (run by
`SState.run` from the state with the block's float constants, `SState.start`, with the
`alloca` flag `alloca`, without `fmul contract`), ending at the collective call at position `p1`
(`SState.waitAt`); its obligations are that each argument term evaluates, that the effects run, and
the statements'.
`none` when `p1 < p0`, the block has no statement at `p1`, a statement before it is outside the
fragment, or the statement at `p1` is not such a call. -/
def summarizeTo (P : Program) (fn : Func) (lbl p0 p1 : Nat) (alloca : Bool := false) :
    Option SegSummary :=
  match fn.blocks.find? (·.label == lbl) with
  | some b => match b.stmts[p1]? with
    | some st => if p0 ≤ p1 then
        match SState.run false P lbl p0 ((b.stmts.toList.drop p0).take (p1 - p0)) 0
            { SState.start fn lbl p0 b with alloca } with
        | some σ => match σ.waitAt P st with
          | some (cl, xs) => some ⟨σ.nodes, σ.regs, σ.effs,
              xs.map .ok ++ .mem σ.effs :: σ.obls, cl, xs, p1 - p0⟩
          | none => none
        | none => none
      else none
    | none => none
  | none => none

/-- The segment with summary `S` of block `lbl`, entered with valuation `V`, reaches its
collective: the thread's steps from `t` on `m` reach step count `V.k + S.len`, with a frame `fe`
(above frames `rest`) of function `V.fn` at block `lbl`, `S.len` positions after frame `f`'s,
whose `alloca` blocks are the summary's (`SEff.blocks`) followed by `f`'s, whose caller's
register is `f`'s, whose registers and `fmul contract`
operands are the summary's (`regVal`, `regProdIn`), on the memory `me` the summary's effects make
(`SEff.run`); the call's argument terms have values `ws`, and the step there is the `.wait` of
the summary's collective on `ws`. -/
def Waits (c : Ctx) (t : Thread) (m : Mem) (f : Frame) (rest : List Frame) :
    Valuation × Nat × SegSummary → Prop
  | (V, lbl, S) => ∃ fe me ws fd, Steps c t m ⟨fe :: rest, V.k + S.len⟩ me ∧ fe.fn = V.fn ∧
      fe.label = lbl ∧ fe.pc = f.pc + S.len ∧ fe.allocas = SEff.blocks V S.effs ++ f.allocas ∧
      fe.dest = f.dest ∧ (∀ r, fe.regs r = regVal V (vals V S.nodes) S.regs r) ∧
      (∀ r, fe.prods r = regProdIn V (vals V S.nodes) S.nodes S.regs r) ∧
      SEff.run V (vals V S.nodes) S.effs = .ok me ∧
      S.args.mapM (·.eval V (vals V S.nodes)) = .ok ws ∧
      step c ⟨fe :: rest, V.k + S.len⟩ me = .ok (.wait S.call.intr ws fd)

/-- The typed operand whose entry `SState.tvOp` gives evaluates, in a scope with the frame's
registers, to the entry's value (`SState.op_eval`). -/
theorem SState.tvOp_eval {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame}
    {σ : SState} {mi : Mem} (hR : Rel V vs f σ fi mi) {s : Scope} (hs : s.regs = fi.regs)
    {a : TValue} {x : SVal} (h : σ.tvOp a = some x) {v : Val} (hv : x.eval V vs = .ok v) :
    evalTV s a = .ok v := by
  cases a with
  | mk t a => simpa only [evalTV] using SState.op_eval hR hs h hv

/-- Call arguments whose entries `SState.tvOp` gives and whose terms have values `ws` evaluate,
in a scope with the frame's registers, to `ws` (`SState.tvOp_eval`). -/
theorem SState.args_eval {V : Valuation} {vs : List (Except Fault Val)} {f fi : Frame}
    {σ : SState} {mi : Mem} (hR : Rel V vs f σ fi mi) {s : Scope} (hs : s.regs = fi.regs) :
    ∀ {args : List (TValue × List Attr)} {xs : List SVal} {ws : List Val},
      args.mapM (fun a => σ.tvOp a.1) = some xs → xs.mapM (·.eval V vs) = .ok ws →
      args.mapM (fun a => evalTV s a.1) = .ok ws
  | [], xs, ws, h, hw => by
    cases h
    cases hw
    rfl
  | a :: args, xs, ws, h, hw => by
    rw [List.mapM_cons] at h
    obtain ⟨x, hx, h⟩ := Option.bind_eq_some_iff.1 h
    obtain ⟨xs', hxs', h⟩ := Option.bind_eq_some_iff.1 h
    obtain rfl : x :: xs' = xs := Option.some.inj h
    rw [List.mapM_cons] at hw
    cases hx' : x.eval V vs with
    | error e => simp [hx', bind, Except.bind] at hw
    | ok w =>
      cases hr : xs'.mapM (·.eval V vs) with
      | error e => simp [hx', hr, bind, Except.bind] at hw
      | ok ws' =>
        simp only [hx', hr, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at hw
        subst hw
        rw [List.mapM_cons, SState.tvOp_eval hR hs hx hx', SState.args_eval hR hs hxs' hr]
        rfl

/-- Terms that each evaluate have values. -/
theorem SVal.mapM_ok {V : Valuation} {vs : List (Except Fault Val)} :
    ∀ {xs : List SVal}, (∀ x ∈ xs, ∃ v, x.eval V vs = .ok v) →
      ∃ ws, xs.mapM (·.eval V vs) = .ok ws
  | [], _ => ⟨[], rfl⟩
  | x :: xs, h => by
    obtain ⟨w, hw⟩ := h x List.mem_cons_self
    obtain ⟨ws, hws⟩ := SVal.mapM_ok fun y hy => h y (List.mem_cons_of_mem x hy)
    exact ⟨w :: ws, by simp only [List.mapM_cons, hw, hws, bind, Except.bind, pure, Except.pure]⟩

/-- For every layout and memory, the arguments `exec` passes to a declaration, with as many
parameters as arguments, at each of whose parameters `withAttrs` with its attributes keeps every
value, with no call-site attributes, are the arguments' values. -/
theorem mapM_withAttrs_keep {l : Layout} {m : Mem} {s : Scope} :
    ∀ {ps : List Param} {args : List (TValue × List Attr)} {vs : List Val},
      (∀ p ∈ ps, ∀ v, withAttrs l m p.ty p.attrs v = .ok v) → args.all (·.2.isEmpty) = true →
      ps.length = args.length → args.mapM (fun a => evalTV s a.1) = .ok vs →
      ((ps.zip vs).zip args).mapM
        (fun x => withAttrs l m x.1.1.ty (x.1.1.attrs ++ x.2.2) x.1.2) = .ok vs
  | [], [], vs, _, _, _, hv => by
    cases hv
    rfl
  | p :: ps, a :: args, vs, hp, ha, hl, hv => by
    simp only [List.all_cons, Bool.and_eq_true, List.isEmpty_iff] at ha
    rw [List.mapM_cons] at hv
    cases he : evalTV s a.1 with
    | error e => simp [he, bind, Except.bind] at hv
    | ok v =>
      cases hr : args.mapM (fun a => evalTV s a.1) with
      | error e => simp [he, hr, bind, Except.bind] at hv
      | ok ws =>
        simp only [he, hr, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at hv
        subst hv
        simp only [List.zip_cons_cons, List.mapM_cons, ha.1, List.append_nil,
          hp p List.mem_cons_self v,
          mapM_withAttrs_keep (fun q hq => hp q (List.mem_cons_of_mem p hq)) ha.2
            (Nat.succ.inj hl) hr, bind, Except.bind, pure, Except.pure]
  | [], _ :: _, _, _, _, hl, _ => by simp at hl
  | _ :: _, [], _, _, _, hl, _ => by simp at hl

/-- For every layout and memory, the arguments `exec` passes to a declaration whose parameters,
as many as the arguments, have no attributes, with no call-site attributes, are the arguments'
values: `withAttrs` with no attribute keeps each (`withAttrs_nil`). -/
theorem mapM_withAttrs_nil {l : Layout} {m : Mem} {s : Scope} {ps : List Param}
    {args : List (TValue × List Attr)} {vs : List Val} (hp : ps.all (·.attrs.isEmpty) = true)
    (ha : args.all (·.2.isEmpty) = true) (hl : ps.length = args.length)
    (hv : args.mapM (fun a => evalTV s a.1) = .ok vs) :
    ((ps.zip vs).zip args).mapM
      (fun x => withAttrs l m x.1.1.ty (x.1.1.attrs ++ x.2.2) x.1.2) = .ok vs :=
  mapM_withAttrs_keep (fun p h v => by
    rw [List.isEmpty_iff.1 (List.all_eq_true.1 hp p h)]
    exact withAttrs_nil ..) ha hl hv

/-- `exec` of a call that waits: for every context, scope, step count and frame, a statement
whose metadata `checkMd` accepts that calls, with no fast-math flags and no call-site
attributes, a declaration that `c.prog.intrinsics` names `i`, has no blocks, has as many
parameters as arguments and none with attributes, and whose attributes `Func.check` accepts, on
arguments with values `vs` at which `intrinsic` gives no result, is the `.wait` of `i` on `vs`
and the declaration. -/
theorem exec_call_wait {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {fm ty g args fn i vs}
    (hmd : st.checkMd = .ok ()) (hi : st.inst = .call fm ty (.fn g) args)
    (hfn : c.prog.module.funcs.find? (·.name == g) = some fn)
    (hg : c.prog.intrinsics.lookup g = some i) (hfm : (fm == {}) = true)
    (hd : fn.blocks.isEmpty = true) (hl : fn.params.length = args.length)
    (hpa : fn.params.all (·.attrs.isEmpty) = true) (has : args.all (·.2.isEmpty) = true)
    (hc : fn.check c.prog.module (some i) = .ok ())
    (hv : args.mapM (fun a => evalTV s a.1) = .ok vs) (hw : intrinsic c s fm i vs = .ok none) :
    exec c s k f st = .ok (.wait i vs fn) := by
  have hna : args.all (·.2.all (· == .flag "noundef")) = true :=
    List.all_eq_true.2 fun a ha => by
      have h := List.all_eq_true.1 has a ha
      simp only [List.isEmpty_iff] at h
      simp [h]
  have hwa := mapM_withAttrs_nil (l := c.prog.layout) (m := s.mem) hpa has hl hv
  simp only [exec, hmd, hi, hfn, hg, hfm, hd, hc, hv, hw, hna, hwa, Bool.true_or, Bool.not_true,
    bind, Except.bind, pure, Except.pure, Bool.false_eq_true, ↓reduceIte]
  -- no parameter is `immarg`
  split
  · rfl
  · rename_i h
    refine absurd (List.all_eq_true.2 fun x hx => ?_) h
    obtain ⟨p, ⟨t, a⟩, as⟩ := x
    have hp := List.all_eq_true.1 hpa p (List.of_mem_zip hx).1
    simp only [List.isEmpty_iff] at hp
    simp [hp]

/-- A step of a frame at a statement whose `exec` waits is that `.wait`. -/
theorem step_call_wait {c : Ctx} {fi : Frame} {rest : List Frame} {k : Nat} {m : Mem}
    {b : LLVM.Block} {st : Stmt} {i : Intrinsic} {vs : List Val} {fd : Func}
    (hb : fi.fn.blocks.find? (·.label == fi.label) = some b) (hst : b.stmts[fi.pc]? = some st)
    (he : exec c (c.scope m fi k) k fi st = .ok (.wait i vs fd)) :
    step c ⟨fi :: rest, k⟩ m = .ok (.wait i vs fd) := by
  obtain ⟨hpc, rfl⟩ := Array.getElem?_eq_some_iff.1 hst
  simp only [step, hb, hpc, ↓reduceDIte, he, bind, Except.bind, pure, Except.pure]

/-- **Soundness of a segment that ends at a collective**, for every program, function, block,
positions `p0` and `p1`, `alloca` flag and summary `S` that `summarizeTo` gives, every context `c`
of the program and thread whose innermost frame `f` runs `fn` at block `lbl` and position `p0`, with
memory `m`:
if every obligation of `S` holds under the entry valuation, the thread's steps run the
statements before `p1` and reach the `.wait` of the call at `p1`, with the arguments' values
(`Waits`), and `p0 + S.len = p1`. The next segment starts at `p1 + 1` on the resumed thread
(`Thread.resume_at`). -/
theorem Seg.sound {P : Program} {fn : Func} {lbl p0 p1 : Nat} {alloca : Bool} {S : SegSummary}
    (hS : summarizeTo P fn lbl p0 p1 alloca = some S) {c : Ctx} (hP : c.prog = P) {t : Thread}
    {m : Mem} {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    Waits c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧ p0 + S.len = p1 := by
  subst hP hfn hl hp
  obtain ⟨frames, k⟩ := t
  obtain rfl : frames = f :: rest := ht
  unfold summarizeTo at hS
  split at hS
  · rename_i b hb
    split at hS
    · rename_i st hst
      split at hS
      · rename_i h01
        split at hS
        · rename_i σ hσ
          split at hS
          · rename_i cl xs hw
            cases hS
            obtain ⟨-, -, ⟨ns, hns⟩, -⟩ := SState.run_mono hσ
            have hR0 : Rel (Valuation.entry c k m f) (vals (Valuation.entry c k m f) σ.nodes) f
                { SState.start f.fn f.label f.pc b with alloca } f m := by
              rw [hns]; exact Rel.startAt
            have hG : Good (Valuation.entry c k m f) (vals (Valuation.entry c k m f) σ.nodes) σ :=
              ⟨fun d hd => hds d (List.mem_append.2 (Or.inr (List.mem_cons_of_mem _ hd))),
                hds (.mem σ.effs) (List.mem_append.2 (Or.inr (List.Mem.head _))),
                [], (List.append_nil _).symm⟩
            obtain ⟨⟨fe, me, hSt, hR, hpc⟩, -, -⟩ := SState.run_ptrs
              (V := Valuation.entry c k m f) (rest := rest) (p0 := f.pc) hb rfl rfl
              ((b.stmts.toList.drop f.pc).take (p1 - f.pc)) 0 _ σ f m k (List.take_prefix _ _)
              rfl rfl hR0 hσ hG
            have hlt := (Array.getElem?_eq_some_iff.1 hst).1
            have hlen : ((b.stmts.toList.drop f.pc).take (p1 - f.pc)).length = p1 - f.pc := by
              simp only [List.length_take, List.length_drop, Array.length_toList]
              omega
            rw [hlen] at hSt hpc
            -- the call at `p1`
            unfold SState.waitAt at hw
            split at hw
            · rename_i hmd
              split at hw
              · rename_i fm ty g args hi
                split at hw
                · rename_i fd i hfd hg
                  split at hw
                  · rename_i cl' hcl
                    split at hw
                    · rename_i hcond
                      split at hw
                      · rename_i xs' hxs
                        cases hw
                        simp only [Bool.and_eq_true] at hcond
                        obtain ⟨⟨⟨⟨⟨hfm, hd⟩, hlp⟩, hpa⟩, has⟩, hc⟩ := hcond
                        obtain ⟨ws, hws⟩ := SVal.mapM_ok (V := Valuation.entry c k m f)
                          (vs := vals (Valuation.entry c k m f) σ.nodes) fun x hx =>
                          hds (.ok x) (List.mem_append.2 (Or.inl (List.mem_map.2 ⟨x, hx, rfl⟩)))
                        have he := exec_call_wait (s := c.scope me fe (k + (p1 - f.pc)))
                          (k := k + (p1 - f.pc)) (f := fe) (isOk_unit hmd) hi
                          hfd hg hfm hd (beq_iff_eq.1 hlp) hpa has (isOk_unit hc)
                          (SState.args_eval hR rfl hxs hws)
                          (by rw [← Coll.of_intr hcl]; exact Coll.intrinsic_none ..)
                        have hb' : fe.fn.blocks.find? (·.label == fe.label) = some b := by
                          rw [hR.fn, hR.label]; exact hb
                        have hst' : b.stmts[fe.pc]? = some st := by
                          rw [hpc, Nat.add_sub_cancel' h01]; exact hst
                        refine ⟨⟨fe, me, ws, fd, hSt, hR.fn, hR.label, hpc, hR.allocas, hR.dest,
                          hR.regs, hR.prods, hR.mem, hws, ?_⟩, Nat.add_sub_cancel' h01⟩
                        rw [Coll.of_intr hcl]
                        exact step_call_wait hb' hst' he
                      · cases hw
                    · cases hw
                  · cases hw
                · cases hw
              · cases hw
            · cases hw
          · cases hS
        · cases hS
      · cases hS
    · cases hS
  · cases hS

/-- **The thread a resume gives**: for every frame `fe` above frames `rest`, step count `k` and
value `v`, `Thread.resume` gives the thread at step count `k + 1` whose innermost frame `fr`,
above `rest`, is at the position after `fe`'s, with `fe`'s function, block, `alloca` blocks and
caller's register (the call's register set to `v`). So the segment after a collective at `p1`
starts at `p1 + 1` (`summarizeTo` or `summarize` there). -/
theorem Thread.resume_at (fe : Frame) (rest : List Frame) (k : Nat) (v : Option Val) :
    ∃ fr, Thread.resume ⟨fe :: rest, k⟩ v = ⟨fr :: rest, k + 1⟩ ∧ fr.fn = fe.fn ∧
      fr.label = fe.label ∧ fr.pc = fe.pc + 1 ∧ fr.allocas = fe.allocas ∧ fr.dest = fe.dest := by
  refine ⟨_, rfl, ?_, ?_, rfl, ?_, ?_⟩ <;> (unfold Frame.set; split <;> rfl)

/-- **The registers a resume keeps**: for every frame `fe` above frames `rest`, step count `k` and
value `v`, `Thread.resume` gives the thread at step count `k + 1` whose innermost frame `fr`,
above `rest`, has `fe`'s value at every register but the result of the statement at `fe`'s
position (the call's register, which `v` sets when both are there). -/
theorem Thread.resume_regs (fe : Frame) (rest : List Frame) (k : Nat) (v : Option Val) :
    ∃ fr, Thread.resume ⟨fe :: rest, k⟩ v = ⟨fr :: rest, k + 1⟩ ∧
      ∀ r, ((fe.fn.blocks.find? (·.label == fe.label)).bind
        fun b => b.stmts[fe.pc]?.bind (·.res)) ≠ some r → fr.regs r = fe.regs r := by
  refine ⟨_, rfl, fun r hr => ?_⟩
  show (Frame.set fe _ v none).regs r = fe.regs r
  generalize (fe.fn.blocks.find? (·.label == fe.label)).bind
    (fun b => b.stmts[fe.pc]?.bind (·.res)) = R at hr ⊢
  rcases R with _ | r' <;> rcases v with _ | v' <;> try rfl
  have hne : r ≠ r' := fun h => hr (h ▸ rfl)
  simp only [Frame.set, hne, ↓reduceIte]

/-- **A segment's run to its collective and the resumed position**, for every program, function,
block, positions `p0` and `p1`, collective `cl`, length `n` and summary `S` that `summarizeTo`
gives with collective `cl` and `n` statements, every context `c` of the program and thread whose
innermost frame `f` (above frames `rest`) runs `fn` at block `lbl` and position `p0`, with memory
`m`: if `S`'s obligations hold under the entry valuation, the thread's steps reach, at step
count `t.k + n`, a frame whose step is the `.wait` of `cl`, and for every value of the call the
resumed thread's frame runs `fn` at block `lbl`, position `p1 + 1`, where the next segment
starts. `Seg.sound` with `Thread.resume_at`; the shape premise `hsh` is the one a test decides. -/
theorem Seg.resume {P : Program} {fn : Func} {lbl p0 p1 n : Nat} {cl : Coll} {S : SegSummary}
    (hS : summarizeTo P fn lbl p0 p1 = some S)
    (hsh : (summarizeTo P fn lbl p0 p1).map (fun S => (S.call, S.len)) = some (cl, n)) {c : Ctx}
    (hP : c.prog = P) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    ∃ fe me ws fd, Steps c t m ⟨fe :: rest, t.k + n⟩ me ∧
      step c ⟨fe :: rest, t.k + n⟩ me = .ok (.wait cl.intr ws fd) ∧
      ∀ v, ∃ fr, Thread.resume ⟨fe :: rest, t.k + n⟩ v = ⟨fr :: rest, t.k + n + 1⟩ ∧
        fr.fn = fn ∧ fr.label = lbl ∧ fr.pc = p1 + 1 := by
  rw [hS] at hsh
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Option.some.inj hsh)
  obtain ⟨⟨fe, me, ws, fd, hSt, hfe, hle, hpc, -, -, -, -, -, -, hw⟩, hlen⟩ :=
    Seg.sound hS hP ht hfn hl hp hds
  refine ⟨fe, me, ws, fd, hSt, hw, fun v => ?_⟩
  obtain ⟨fr, hr, h1, h2, h3, -, -⟩ := Thread.resume_at fe rest (t.k + S.len) v
  exact ⟨fr, hr, h1.trans (hfe.trans hfn), h2.trans hle, by rw [h3, hpc, hp, hlen]⟩

/-- **A resumed segment's registers**, for every program, function, block, positions `p0` and
`p1` and summary `S` that `summarizeTo` gives, every context `c` of the program and thread whose
innermost frame `f` (above frames `rest`) runs `fn` at block `lbl` and position `p0`, with memory
`m`: if `S`'s obligations hold under the entry valuation, the thread's steps reach, at step
count `t.k + S.len`, a frame `fe`, and for every value of the call at `p1` the resumed thread's
frame has, at every register but the call's result, the value `S`'s registers give it under the
entry valuation (`regVal`). `Seg.sound`'s register conjunct with `Thread.resume_regs`. -/
theorem Seg.resume_regs {P : Program} {fn : Func} {lbl p0 p1 : Nat} {S : SegSummary}
    (hS : summarizeTo P fn lbl p0 p1 = some S) {c : Ctx} (hP : c.prog = P) {t : Thread}
    {m : Mem} {f : Frame} {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + S.len⟩ me ∧
      ∀ v, ∃ fr, Thread.resume ⟨fe :: rest, t.k + S.len⟩ v = ⟨fr :: rest, t.k + S.len + 1⟩ ∧
        ∀ r, ((fn.blocks.find? (·.label == lbl)).bind fun b => b.stmts[p1]?.bind (·.res)) ≠
            some r →
          fr.regs r = regVal (Valuation.entry c t.k m f)
            (vals (Valuation.entry c t.k m f) S.nodes) S.regs r := by
  obtain ⟨⟨fe, me, ws, fd, hSt, hfe, hle, hpc, -, -, hrg, -, -, -, -⟩, hlen⟩ :=
    Seg.sound hS hP ht hfn hl hp hds
  refine ⟨fe, me, hSt, fun v => ?_⟩
  obtain ⟨fr, hr, hfr⟩ := Thread.resume_regs fe rest (t.k + S.len) v
  have hf : fe.fn = fn := hfe.trans hfn
  have hq : fe.pc = p1 := by rw [hpc, hp, hlen]
  refine ⟨fr, hr, fun r hne => (hfr r ?_).trans (hrg r)⟩
  rw [hf, hle, hq]
  exact hne

/-- The summaries of the segments of block `lbl` of `fn` from position `p0` that end at the
collective calls at positions `ps` (`summarizeTo`, each segment from the position after the
previous call), and the summary of the statements after the last call (`summarize`). `none` when
one of them is `none`. -/
def summarizeSegs (P : Program) (fn : Func) (lbl : Nat) :
    Nat → List Nat → Option (List SegSummary × Summary)
  | p0, [] => (summarize P fn lbl p0).map fun L => ([], L)
  | p0, p1 :: ps => match summarizeTo P fn lbl p0 p1, summarizeSegs P fn lbl (p1 + 1) ps with
    | some S, some (Ss, L) => some (S :: Ss, L)
    | _, _ => none

/-- The run on one thread of the segments `Ss` of block `lbl`, then of its statements after the
last collective, with summary `L`, when the `i`-th collective delivers `w i` (the call's value
and the memory the thread resumes on), from thread `t` on memory `m` whose innermost frame `f` is
above frames `rest`. With a segment `S` first: if `S`'s obligations hold under `f`'s entry
valuation `V`, the thread's steps reach, at step count `t.k + S.len`, a frame `fe` on memory `me`
with the facts of `Waits` (function, block, position, `alloca` blocks, caller's register,
registers, `fmul contract` operands, memory, the arguments' values `ws`, and the step there the
`.wait` of `S`'s collective on `ws`), and the thread resumed there with `(w 0).1`, on memory
`(w 0).2`, runs the other segments with `w` shifted by one. With no segment left: if `L`'s
obligations hold under `V`, the block ends (`Ends`). -/
def Seg.Through (c : Ctx) (lbl : Nat) (rest : List Frame) (L : Summary) :
    List SegSummary → (Nat → Option Val × Mem) → Thread → Mem → Frame → Prop
  | [], _, t, m, f =>
    (∀ d ∈ L.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) L.nodes)) →
    Ends c t m f rest (Valuation.entry c t.k m f, lbl, L)
  | S :: Ss, w, t, m, f =>
    (∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) →
    ∃ fe me ws fd, Steps c t m ⟨fe :: rest, t.k + S.len⟩ me ∧ fe.fn = f.fn ∧ fe.label = lbl ∧
      fe.pc = f.pc + S.len ∧ fe.allocas = f.allocas ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes) S.regs r) ∧
      (∀ r, fe.prods r = regProdIn (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes) S.nodes S.regs r) ∧
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) S.effs =
        .ok me ∧
      S.args.mapM (·.eval (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes)) = .ok ws ∧
      step c ⟨fe :: rest, t.k + S.len⟩ me = .ok (.wait S.call.intr ws fd) ∧
      ∃ fr, Thread.resume ⟨fe :: rest, t.k + S.len⟩ (w 0).1 = ⟨fr :: rest, t.k + S.len + 1⟩ ∧
        Seg.Through c lbl rest L Ss (fun i => w (i + 1)) ⟨fr :: rest, t.k + S.len + 1⟩ (w 0).2 fr

/-! ## Lifetime markers

A call of `llvm.lifetime.start` or `llvm.lifetime.end` changes the memory outside the effects a
summary replays (`Mem.setLive` of the pointer's block, whose bytes are undefined when its lifetime
starts), so a segment ends at it, as at a collective, and the next segment starts after it, on the
memory the marker makes. -/

/-- Attributes that are all keywords with parenthesized keyword lists (`Attr.args`, such as
`captures(none)`) contain no bare keyword. -/
theorem contains_flag_of_args (n : String) :
    ∀ {as : List Attr}, as.all (· matches .args ..) = true → as.contains (.flag n) = false
  | [], _ => rfl
  | a :: as, ha => by
    simp only [List.all_cons, Bool.and_eq_true] at ha
    obtain ⟨h1, h2⟩ := ha
    cases a <;> simp at h1
    simp only [List.contains_cons, contains_flag_of_args n h2]
    rfl

/-- For every layout, memory, type that is not a vector, attributes that are all `Attr.args`
(such as `captures(none)`) and value, `withAttrs` gives the value. -/
theorem withAttrs_args (l : Layout) (m : Mem) {t : Ty} (ht : (t matches .vec ..) = false)
    {as : List Attr} (ha : as.all (· matches .args ..) = true) (v : Val) :
    withAttrs l m t as v = .ok v := by
  have hn := contains_flag_of_args "noundef" ha
  unfold withAttrs
  dsimp only
  split
  · simp at ht
  · rw [foldlM_fix]
    · simp only [hn, Bool.false_and, Bool.false_eq_true, ↓reduceIte, bind, Except.bind, pure,
        Except.pure]
    · intro a hm
      have := List.all_eq_true.1 ha a hm
      cases a <;> simp at this
      split <;> first | rfl | contradiction

/-- `intrinsic` of a lifetime marker on a pointer into a block of `s.mem` that the thread owns:
no value, and the memory with the block's lifetime started or ended (`Mem.setLive`). -/
theorem intrinsic_lifetime_ptr {c : Ctx} {s : Scope} {fm : FastMath} {start : Bool} {p : Ptr}
    (h : ((s.mem.block p).any fun b => b.owner == .thread c.who.thread) = true) :
    intrinsic c s fm (.lifetime start) [.ptr p] =
      .ok (some (none, s.mem.setLive p.block start)) := by
  simp only [intrinsic, h, ↓reduceIte, pure, Except.pure]

/-- `intrinsic` of a lifetime marker on `poison`: no value, and the same memory. -/
theorem intrinsic_lifetime_poison {c : Ctx} {s : Scope} {fm : FastMath} {start : Bool} :
    intrinsic c s fm (.lifetime start) [.poison] = .ok (some (none, s.mem)) := rfl

/-- The lifetime marker statement `st` makes from state `σ`, with its pointer's term: `st`'s
metadata passes `checkMd`, and it calls, with no fast-math flags and no call-site attributes,
on one argument with an entry (`SState.tvOp`), a declaration (no blocks) of `P` that
`P.intrinsics` names `lifetime start`, with as many parameters as arguments, each of a type that
is not a vector and with attributes that are all `Attr.args` (such as `captures(none)`), and
whose attributes `Func.check` accepts; `start` is whether it is `llvm.lifetime.start`. `none`
otherwise. -/
def SState.lifeAt (P : Program) (σ : SState) (st : Stmt) : Option (Bool × SVal) :=
  if st.checkMd.isOk then
    match st.inst with
    | .call fm _ (.fn g) args =>
      match P.module.funcs.find? (·.name == g), P.intrinsics.lookup g with
      | some fn, some (.lifetime start) =>
        if (fm == {}) && fn.blocks.isEmpty && fn.params.length == args.length &&
            fn.params.all (fun p => p.attrs.all (· matches .args ..) && !(p.ty matches .vec ..)) &&
            args.all (·.2.isEmpty) && (fn.check P.module (some (.lifetime start))).isOk then
          match args.mapM fun a => σ.tvOp a.1 with
          | some [x] => some (start, x)
          | _ => none
        else none
      | _, _ => none
    | _ => none
  else none

/-- `exec` of a lifetime marker: for every context, scope, step count and frame, a statement
whose metadata `checkMd` accepts that calls, with no fast-math flags and no call-site
attributes, a declaration that `c.prog.intrinsics` names `lifetime start`, has no blocks, has as
many parameters as arguments, each of a type that is not a vector and with attributes that are
all `Attr.args`, and whose attributes `Func.check` accepts, on an argument with value `x` at
which `intrinsic` gives no value and memory `m'`, sets no register and moves to the next
statement, on `m'`. -/
theorem exec_lifetime {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt}
    {fm ty g args fn start x m'} (hmd : st.checkMd = .ok ())
    (hi : st.inst = .call fm ty (.fn g) args)
    (hfn : c.prog.module.funcs.find? (·.name == g) = some fn)
    (hg : c.prog.intrinsics.lookup g = some (.lifetime start)) (hfm : (fm == {}) = true)
    (hd : fn.blocks.isEmpty = true) (hl : fn.params.length = args.length)
    (hpa : fn.params.all
      (fun p => p.attrs.all (· matches .args ..) && !(p.ty matches .vec ..)) = true)
    (has : args.all (·.2.isEmpty) = true)
    (hc : fn.check c.prog.module (some (.lifetime start)) = .ok ())
    (hv : args.mapM (fun a => evalTV s a.1) = .ok [x])
    (hm : intrinsic c s {} (.lifetime start) [x] = .ok (some (none, m'))) :
    exec c s k f st = .ok (.next { f.set st.res none none with pc := f.pc + 1 } m') := by
  obtain rfl : fm = {} := beq_iff_eq.1 hfm
  have hna : args.all (·.2.all (· == .flag "noundef")) = true :=
    List.all_eq_true.2 fun a ha => by
      have h := List.all_eq_true.1 has a ha
      simp only [List.isEmpty_iff] at h
      simp [h]
  have hwa := mapM_withAttrs_keep (l := c.prog.layout) (m := s.mem)
    (fun p h v => by
      have hp := List.all_eq_true.1 hpa p h
      simp only [Bool.and_eq_true, Bool.not_eq_true'] at hp
      exact withAttrs_args _ _ hp.2 hp.1 v) has hl hv
  have hu : ownUndef c s (.lifetime start) [x] = false := by
    simp only [ownUndef, hm]
  simp only [exec, hmd, hi, hfn, hg, hfm, hd, hc, hv, hm, hna, hwa, hu, Bool.true_or,
    Bool.not_true, Bool.and_false, Option.mapM_none, bind, Except.bind, pure, Except.pure,
    Bool.false_eq_true, ↓reduceIte]
  -- no parameter is `immarg`
  split
  · rfl
  · rename_i h
    refine absurd (List.all_eq_true.2 fun x hx => ?_) h
    obtain ⟨p, ⟨t, a⟩, as⟩ := x
    have hp := List.all_eq_true.1 hpa p (List.of_mem_zip hx).1
    simp only [Bool.and_eq_true] at hp
    simp [contains_flag_of_args "immarg" hp.1]

/-- The statements at positions `p0 ≤ pc < p1` of block `lbl` of `fn`, run as `summarizeTo` runs
them, ending at the lifetime marker at position `p1` (`SState.lifeAt`): the state after them,
whether the marker starts the lifetime, and the pointer's term. The segment's obligations are
that the term evaluates, that the state's effects run, and the state's. `none` when `p1 < p0`,
the block has no statement at `p1`, a statement before it is outside the fragment, or the
statement at `p1` is not such a call. -/
def summarizeLife (P : Program) (fn : Func) (lbl p0 p1 : Nat) (alloca : Bool := false) :
    Option (SState × Bool × SVal) :=
  match fn.blocks.find? (·.label == lbl) with
  | some b => match b.stmts[p1]? with
    | some st => if p0 ≤ p1 then
        match SState.run false P lbl p0 ((b.stmts.toList.drop p0).take (p1 - p0)) 0
            { SState.start fn lbl p0 b with alloca } with
        | some σ => match σ.lifeAt P st with
          | some (s, x) => some (σ, s, x)
          | none => none
        | none => none
      else none
    | none => none
  | none => none

/-- **Soundness of a segment that ends at a lifetime marker**, for every program, function,
block, positions `p0` and `p1`, state `σ`, flag `start` and pointer term `x` that
`summarizeLife` gives, every context `c` of the program and thread whose innermost frame `f`
(above frames `rest`) runs `fn` at block `lbl` and position `p0`, with memory `m`: `p0 ≤ p1`, and
if `x` evaluates, `σ`'s effects run and `σ`'s obligations hold under the entry valuation `V`, the
thread's steps reach, at step count `t.k + (p1 - p0)`, a frame `fe` at position `p1` of block
`lbl` of `fn`, with the state's `alloca` blocks (`SEff.blocks`) followed by `f`'s, `f`'s
caller's register and the state's registers and `fmul contract` operands (`regVal`, `regProdIn`), on
the memory `me` the effects make, `x` is a value `w`, and when `intrinsic` gives no value and memory
`m'` on `w` (`Mem.setLive` of its block,
`intrinsic_lifetime_ptr`, or `me` on `poison`) the step there moves, on `m'`, to `fe` at
position `p1 + 1`, where the next segment starts. -/
theorem Seg.life {P : Program} {fn : Func} {lbl p0 p1 : Nat} {alloca : Bool} {σ : SState}
    {start : Bool} {x : SVal} (hS : summarizeLife P fn lbl p0 p1 alloca = some (σ, start, x))
    {c : Ctx} (hP : c.prog = P) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ Cond.ok x :: .mem σ.effs :: σ.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) σ.nodes)) :
    p0 ≤ p1 ∧ ∃ fe me w, Steps c t m ⟨fe :: rest, t.k + (p1 - p0)⟩ me ∧ fe.fn = fn ∧
      fe.label = lbl ∧ fe.pc = p1 ∧
      fe.allocas = SEff.blocks (Valuation.entry c t.k m f) σ.effs ++ f.allocas ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) σ.nodes) σ.regs r) ∧
      (∀ r, fe.prods r = regProdIn (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) σ.nodes) σ.nodes σ.regs r) ∧
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) σ.nodes) σ.effs =
        .ok me ∧
      x.eval (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) σ.nodes) = .ok w ∧
      ∀ m', intrinsic c (c.scope me fe (t.k + (p1 - p0))) {} (.lifetime start) [w] =
          .ok (some (none, m')) →
        step c ⟨fe :: rest, t.k + (p1 - p0)⟩ me =
          .ok (.next ⟨{ fe with pc := p1 + 1 } :: rest, t.k + (p1 - p0) + 1⟩ m') := by
  subst hP hfn hl hp
  obtain ⟨frames, k⟩ := t
  obtain rfl : frames = f :: rest := ht
  unfold summarizeLife at hS
  split at hS
  · rename_i b hb
    split at hS
    · rename_i st hst
      split at hS
      · rename_i h01
        split at hS
        · rename_i σ' hσ
          split at hS
          · rename_i s' x' hw
            simp only [Option.some.injEq, Prod.mk.injEq] at hS
            obtain ⟨h1, h2, h3⟩ := hS
            subst σ' s' x'
            obtain ⟨-, -, ⟨ns, hns⟩, -⟩ := SState.run_mono hσ
            have hR0 : Rel (Valuation.entry c k m f) (vals (Valuation.entry c k m f) σ.nodes) f
                { SState.start f.fn f.label f.pc b with alloca } f m := by
              rw [hns]; exact Rel.startAt
            have hG : Good (Valuation.entry c k m f) (vals (Valuation.entry c k m f) σ.nodes) σ :=
              ⟨fun d hd => hds d (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ hd)),
                hds (.mem σ.effs) (List.mem_cons_of_mem _ List.mem_cons_self),
                [], (List.append_nil _).symm⟩
            obtain ⟨⟨fe, me, hSt, hR, hpc⟩, -, -⟩ := SState.run_ptrs
              (V := Valuation.entry c k m f) (rest := rest) (p0 := f.pc) hb rfl rfl
              ((b.stmts.toList.drop f.pc).take (p1 - f.pc)) 0 _ σ f m k (List.take_prefix _ _)
              rfl rfl hR0 hσ hG
            have hlt := (Array.getElem?_eq_some_iff.1 hst).1
            have hlen : ((b.stmts.toList.drop f.pc).take (p1 - f.pc)).length = p1 - f.pc := by
              simp only [List.length_take, List.length_drop, Array.length_toList]
              omega
            rw [hlen] at hSt hpc
            obtain ⟨w, hxw⟩ := hds (.ok x) List.mem_cons_self
            have hpc' : fe.pc = p1 := by rw [hpc, Nat.add_sub_cancel' h01]
            refine ⟨h01, fe, me, w, hSt, hR.fn, hR.label, hpc', hR.allocas, hR.dest,
              hR.regs, hR.prods, hR.mem, hxw, fun m' hm => ?_⟩
            -- the marker at `p1`
            unfold SState.lifeAt at hw
            split at hw
            · rename_i hmd
              split at hw
              · rename_i fm ty g args hi
                split at hw
                · rename_i fd start' hfd hg
                  split at hw
                  · rename_i hcond
                    split at hw
                    · rename_i x'' hxs
                      simp only [Option.some.injEq, Prod.mk.injEq] at hw
                      obtain ⟨h1, h2⟩ := hw
                      subst start' x''
                      simp only [Bool.and_eq_true] at hcond
                      obtain ⟨⟨⟨⟨⟨hfm, hd⟩, hlp⟩, hpa⟩, has⟩, hc⟩ := hcond
                      have he := exec_lifetime (s := c.scope me fe (k + (p1 - f.pc)))
                        (k := k + (p1 - f.pc)) (f := fe) (isOk_unit hmd) hi hfd hg hfm hd
                        (beq_iff_eq.1 hlp) hpa has (isOk_unit hc)
                        (SState.args_eval hR rfl hxs (by
                          simp only [List.mapM_cons, List.mapM_nil, hxw, bind, Except.bind,
                            pure, Except.pure])) hm
                      have hb' : fe.fn.blocks.find? (·.label == fe.label) = some b := by
                        rw [hR.fn, hR.label]; exact hb
                      have hst' : b.stmts[fe.pc]? = some st := by rw [hpc']; exact hst
                      have e : { fe.set st.res none none with pc := fe.pc + 1 } =
                          { fe with pc := p1 + 1 } := by
                        rw [hpc']; cases st.res <;> rfl
                      rw [← e]
                      exact step_stmt hb' hst' he
                    · cases hw
                  · cases hw
                · cases hw
              · cases hw
            · cases hw
          · cases hS
        · cases hS
      · cases hS
    · cases hS
  · cases hS

/-- `Seg.life` without `p0 ≤ p1` and the frame's `alloca` blocks, caller's register, registers and
`fmul contract` operands: for every program, function, block, positions `p0` and `p1`, state `σ`,
flag `start` and pointer term `x` that `summarizeLife` gives, every context `c` of the program and
thread whose innermost frame `f` (above frames `rest`) runs `fn` at block `lbl` and position `p0`,
with memory `m`: if `x` evaluates, `σ`'s effects run and `σ`'s obligations hold under the entry
valuation `V`, the thread's steps reach, at step count `t.k + (p1 - p0)`, a frame `fe` at position
`p1` of block `lbl` of `fn` on the memory `me` the effects make, `x` is a value `w`, and when
`intrinsic` gives no value and memory `m'` on `w` (`Mem.setLive` of its block,
`intrinsic_lifetime_ptr`, or `me` on `poison`) the step there moves, on `m'`, to a frame of `fn` at
block `lbl` and position `p1 + 1`, where the next segment starts. -/
theorem Seg.lifetime {P : Program} {fn : Func} {lbl p0 p1 : Nat} {alloca : Bool} {σ : SState}
    {start : Bool} {x : SVal} (hS : summarizeLife P fn lbl p0 p1 alloca = some (σ, start, x))
    {c : Ctx} (hP : c.prog = P) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ Cond.ok x :: .mem σ.effs :: σ.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) σ.nodes)) :
    ∃ fe me w, Steps c t m ⟨fe :: rest, t.k + (p1 - p0)⟩ me ∧ fe.fn = fn ∧ fe.label = lbl ∧
      fe.pc = p1 ∧
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) σ.nodes) σ.effs =
        .ok me ∧
      x.eval (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) σ.nodes) = .ok w ∧
      ∀ m', intrinsic c (c.scope me fe (t.k + (p1 - p0))) {} (.lifetime start) [w] =
          .ok (some (none, m')) →
        ∃ fr, step c ⟨fe :: rest, t.k + (p1 - p0)⟩ me =
            .ok (.next ⟨fr :: rest, t.k + (p1 - p0) + 1⟩ m') ∧
          fr.fn = fn ∧ fr.label = lbl ∧ fr.pc = p1 + 1 := by
  obtain ⟨-, fe, me, w, hSt, h1, h2, h3, -, -, -, -, h4, h5, h6⟩ := Seg.life hS hP ht hfn hl hp hds
  exact ⟨fe, me, w, hSt, h1, h2, h3, h4, h5, fun m' hm => ⟨_, h6 m' hm, h1, h2, rfl⟩⟩

/-- `Seg.lifetime` on the memory the marker makes: when the pointer's value is a pointer `q` into
a block of the memory `me` at the marker that the thread owns, the step there moves to `p1 + 1`
on `me` with `q`'s block's lifetime started or ended (`intrinsic_lifetime_ptr`), and when it is
`poison`, on `me` (`intrinsic_lifetime_poison`). -/
theorem Seg.lifetime_ptr {P : Program} {fn : Func} {lbl p0 p1 : Nat} {alloca : Bool}
    {σ : SState} {start : Bool} {x : SVal}
    (hS : summarizeLife P fn lbl p0 p1 alloca = some (σ, start, x)) {c : Ctx}
    (hP : c.prog = P) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0)
    (hds : ∀ d ∈ Cond.ok x :: .mem σ.effs :: σ.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) σ.nodes)) :
    ∃ fe me w, Steps c t m ⟨fe :: rest, t.k + (p1 - p0)⟩ me ∧ fe.fn = fn ∧ fe.label = lbl ∧
      fe.pc = p1 ∧
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) σ.nodes) σ.effs =
        .ok me ∧
      x.eval (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) σ.nodes) = .ok w ∧
      (∀ q, w = .ptr q → ((me.block q).any fun b => b.owner == .thread c.who.thread) = true →
        ∃ fr, step c ⟨fe :: rest, t.k + (p1 - p0)⟩ me =
            .ok (.next ⟨fr :: rest, t.k + (p1 - p0) + 1⟩ (me.setLive q.block start)) ∧
          fr.fn = fn ∧ fr.label = lbl ∧ fr.pc = p1 + 1) ∧
      (w = .poison → ∃ fr, step c ⟨fe :: rest, t.k + (p1 - p0)⟩ me =
            .ok (.next ⟨fr :: rest, t.k + (p1 - p0) + 1⟩ me) ∧
          fr.fn = fn ∧ fr.label = lbl ∧ fr.pc = p1 + 1) := by
  obtain ⟨fe, me, w, hSt, h1, h2, h3, h4, h5, h6⟩ := Seg.lifetime hS hP ht hfn hl hp hds
  refine ⟨fe, me, w, hSt, h1, h2, h3, h4, h5, fun q hq ho => ?_, fun hq => ?_⟩
  · subst hq
    exact h6 _ (intrinsic_lifetime_ptr (s := c.scope me fe (t.k + (p1 - p0))) ho)
  · subst hq
    exact h6 _ (intrinsic_lifetime_poison (s := c.scope me fe (t.k + (p1 - p0))))

/-! ## A block through its markers

The segments of a block, each ending at a collective call or at a lifetime marker, then the
statements after the last of them: the thread runs the block through them in turn. -/

/-- A segment of a block (`summarizePiece`): one that ends at a collective call, with its
summary (`summarizeTo`), or one that ends at a lifetime marker, with what `summarizeLife` gives
and its number of statements. -/
inductive Piece where
  /-- A segment that ends at a collective call, with its summary. -/
  | coll (S : SegSummary)
  /-- A segment of `len` statements that ends at a lifetime marker: the state after them,
  whether the marker starts the lifetime, and the pointer's term. -/
  | life (σ : SState) (start : Bool) (x : SVal) (len : Nat)

/-- The segment of block `lbl` of `fn` from position `p0` that ends at the call at position
`p1`: the collective's (`summarizeTo`) when it gives one, else the lifetime marker's
(`summarizeLife`, with `p1 - p0` statements); `none` when both are `none`. -/
def summarizePiece (P : Program) (fn : Func) (lbl p0 p1 : Nat) (alloca : Bool := false) :
    Option Piece :=
  match summarizeTo P fn lbl p0 p1 alloca with
  | some S => some (.coll S)
  | none => (summarizeLife P fn lbl p0 p1 alloca).map fun r => .life r.1 r.2.1 r.2.2 (p1 - p0)

/-- The segments of block `lbl` of `fn` from position `p0` that end at the collective calls and
lifetime markers at positions `ps` (`summarizePiece`, each from the position after the previous
call), and the summary of the statements after the last call to the block's terminator
(`summarizeAt` at `SState.exitAt`); each with the `alloca` flag. `none` when one of them is
`none`. -/
def summarizePieces (P : Program) (fn : Func) (lbl p0 : Nat) (ps : List Nat)
    (alloca : Bool := false) : Option (List Piece × Summary) :=
  match ps with
  | [] => (summarizeAt alloca P fn lbl p0 fun σ tm => σ.exitAt fn lbl tm).map fun L => ([], L)
  | p1 :: ps => match summarizePiece P fn lbl p0 p1 alloca,
      summarizePieces P fn lbl (p1 + 1) ps alloca with
    | some S, some (Ss, L) => some (S :: Ss, L)
    | _, _ => none

/-- The run on one thread of the segments `Ss` of block `lbl`, then the continuation `K` on the
thread, memory and frame after the last call, when the `i`-th collective delivers `w i` (the
call's value and the memory the thread resumes on), from thread `t` on memory `m` whose innermost
frame `f` is above frames `rest`; `V` is `f`'s entry valuation. With a collective's segment `S`
first, as `Seg.Through`: if `S`'s obligations hold under `V`, the thread's steps reach, at step
count `t.k + S.len`, a frame `fe` on memory `me` with the facts of `Waits`, and the thread resumed
there with `(w 0).1`, on memory `(w 0).2`, runs the other segments with `w` shifted by one. With a
lifetime marker's segment of `n` statements, state `σ`, flag `start` and pointer term `x` first:
if `x` evaluates, `σ`'s effects run and `σ`'s obligations hold under `V`, the thread's steps
reach, at step count `t.k + n`, a frame `fe` at position `f.pc + n` of `f`'s function and block
`lbl`, with `σ`'s `alloca` blocks followed by `f`'s, `f`'s caller's register and `σ`'s
registers and `fmul contract` operands, on the memory `me` `σ`'s effects make, `x` is a value `v`,
and for every memory `m'` that `intrinsic` gives with no value on `v` the step there moves, on
`m'`, to `fe` at the next position, from which the thread runs the other segments with the same
`w`. With no segment left: `K t m f`. -/
def Piece.ThroughTo (c : Ctx) (lbl : Nat) (rest : List Frame) (K : Thread → Mem → Frame → Prop) :
    List Piece → (Nat → Option Val × Mem) → Thread → Mem → Frame → Prop
  | [], _, t, m, f => K t m f
  | .coll S :: Ss, w, t, m, f =>
    (∀ d ∈ S.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) S.nodes)) →
    ∃ fe me ws fd, Steps c t m ⟨fe :: rest, t.k + S.len⟩ me ∧ fe.fn = f.fn ∧ fe.label = lbl ∧
      fe.pc = f.pc + S.len ∧
      fe.allocas = SEff.blocks (Valuation.entry c t.k m f) S.effs ++ f.allocas ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes) S.regs r) ∧
      (∀ r, fe.prods r = regProdIn (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes) S.nodes S.regs r) ∧
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) S.effs =
        .ok me ∧
      S.args.mapM (·.eval (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes)) = .ok ws ∧
      step c ⟨fe :: rest, t.k + S.len⟩ me = .ok (.wait S.call.intr ws fd) ∧
      ∃ fr, Thread.resume ⟨fe :: rest, t.k + S.len⟩ (w 0).1 = ⟨fr :: rest, t.k + S.len + 1⟩ ∧
        Piece.ThroughTo c lbl rest K Ss (fun i => w (i + 1)) ⟨fr :: rest, t.k + S.len + 1⟩
          (w 0).2 fr
  | .life σ start x n :: Ss, w, t, m, f =>
    (∀ d ∈ Cond.ok x :: .mem σ.effs :: σ.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) σ.nodes)) →
    ∃ fe me v, Steps c t m ⟨fe :: rest, t.k + n⟩ me ∧ fe.fn = f.fn ∧ fe.label = lbl ∧
      fe.pc = f.pc + n ∧
      fe.allocas = SEff.blocks (Valuation.entry c t.k m f) σ.effs ++ f.allocas ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) σ.nodes) σ.regs r) ∧
      (∀ r, fe.prods r = regProdIn (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) σ.nodes) σ.nodes σ.regs r) ∧
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) σ.nodes) σ.effs =
        .ok me ∧
      x.eval (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) σ.nodes) = .ok v ∧
      ∀ m', intrinsic c (c.scope me fe (t.k + n)) {} (.lifetime start) [v] =
          .ok (some (none, m')) →
        step c ⟨fe :: rest, t.k + n⟩ me =
          .ok (.next ⟨{ fe with pc := fe.pc + 1 } :: rest, t.k + n + 1⟩ m') ∧
        Piece.ThroughTo c lbl rest K Ss w ⟨{ fe with pc := fe.pc + 1 } :: rest, t.k + n + 1⟩ m'
          { fe with pc := fe.pc + 1 }

/-- The run on one thread of the segments `Ss` of block `lbl`, then of its statements after the
last call, with summary `L` (`Piece.ThroughTo` whose continuation is the block's end): with no
segment left, if `L`'s obligations hold under the entry valuation of the frame `f` reached, the
block ends with the blocks of `L`'s `alloca`s in front of `f`'s (`EndsAt false`). -/
def Piece.Through (c : Ctx) (lbl : Nat) (rest : List Frame) (L : Summary) :
    List Piece → (Nat → Option Val × Mem) → Thread → Mem → Frame → Prop :=
  Piece.ThroughTo c lbl rest fun t m f =>
    (∀ d ∈ L.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) L.nodes)) →
    EndsAt false c t m f rest (Valuation.entry c t.k m f, lbl, L)

/-- **The summary of the rest is at the position after the last call**: for every program,
function, block, flag, position `p0` and positions `ps`, if `summarizePieces` gives the segments
`Ss` and the summary `L`, then `L` is `summarizeAt`'s summary (exit `SState.exitAt`) from
`ps.foldl (fun _ p => p + 1) p0`, the position after the last of `ps` (`p0` when `ps` is
empty). -/
theorem summarizePieces_last {P : Program} {fn : Func} {lbl : Nat} {alloca : Bool} :
    ∀ {ps : List Nat} {p0 : Nat} {Ss : List Piece} {L : Summary},
      summarizePieces P fn lbl p0 ps alloca = some (Ss, L) →
      summarizeAt alloca P fn lbl (ps.foldl (fun _ p => p + 1) p0)
        (fun σ tm => σ.exitAt fn lbl tm) = some L
  | [], _, _, _, h => by
    obtain ⟨L', hL, he⟩ := Option.map_eq_some_iff.1 h
    cases he
    exact hL
  | p1 :: ps, p0, _, _, h => by
    unfold summarizePieces at h
    split at h
    · rename_i S Ss' L' hS hR
      cases h
      exact summarizePieces_last (ps := ps) (p0 := p1 + 1) hR
    · cases h

/-- **A block through its collectives and lifetime markers on one thread, to a continuation**, for
every flag `alloca`, program, function, block, position `p0`, positions `ps` of collective calls
and lifetime markers and segments `Ss` and summary `L` that `summarizePieces` gives with the flag,
every context `c` of the program, continuation `K` that holds of every thread, memory and frame
`f` (above frames `rest`) of `fn` at block `lbl` and position `ps.foldl (fun _ p => p + 1) p0`
(after the last call), values `w` the collectives deliver, and thread whose innermost frame `f`
(above frames `rest`) runs `fn` at block `lbl` and position `p0`, with memory `m`: the thread
runs the segments and then `K` holds (`Piece.ThroughTo`), each segment's obligations a premise at
its own start frame. By induction on `ps`: `Seg.sound` and `Thread.resume_at` at a collective,
`Seg.life` at a lifetime marker. -/
theorem Piece.throughTo {P : Program} {fn : Func} {lbl : Nat} {alloca : Bool} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} {K : Thread → Mem → Frame → Prop} {ps : List Nat} :
    ∀ {p0 : Nat} {Ss : List Piece} {L : Summary},
      summarizePieces P fn lbl p0 ps alloca = some (Ss, L) →
      (∀ t m f, t.frames = f :: rest → f.fn = fn → f.label = lbl →
        f.pc = ps.foldl (fun _ p => p + 1) p0 → K t m f) →
    ∀ (w : Nat → Option Val × Mem) {t : Thread} {m : Mem} {f : Frame}, t.frames = f :: rest →
      f.fn = fn → f.label = lbl → f.pc = p0 → Piece.ThroughTo c lbl rest K Ss w t m f := by
  induction ps with
  | nil =>
    intro p0 Ss L h hK w t m f ht hfn hl hp
    unfold summarizePieces at h
    obtain ⟨L', -, he⟩ := Option.map_eq_some_iff.1 h
    obtain ⟨rfl, rfl⟩ := Prod.mk.inj he
    exact hK t m f ht hfn hl hp
  | cons p1 ps ih =>
    intro p0 Ss L h hK w t m f ht hfn hl hp
    unfold summarizePieces at h
    split at h
    · rename_i S Ss' L' hS hR
      cases h
      unfold summarizePiece at hS
      split at hS
      · rename_i S hS
        cases hS
        intro hds
        obtain ⟨⟨fe, me, ws, fd, hSt, hfe, hle, hpc, ha, hd, hr, hpr, hm, hws, hw⟩, hlen⟩ :=
          Seg.sound hS hP ht hfn hl hp hds
        obtain ⟨fr, hres, h1, h2, h3, -, -⟩ := Thread.resume_at fe rest (t.k + S.len) (w 0).1
        refine ⟨fe, me, ws, fd, hSt, hfe, hle, hpc, ha, hd, hr, hpr, hm, hws, hw, fr, hres, ?_⟩
        exact ih hR hK (fun i => w (i + 1)) rfl (h1.trans (hfe.trans hfn)) (h2.trans hle)
          (by rw [h3, hpc, hp, hlen])
      · obtain ⟨⟨σ, s, x⟩, hL, he⟩ := Option.map_eq_some_iff.1 hS
        cases he
        intro hds
        obtain ⟨h01, fe, me, v, hSt, hfe, hle, hpc, ha, hd, hr, hpr, hm, hx, hst⟩ :=
          Seg.life hL hP ht hfn hl hp hds
        refine ⟨fe, me, v, hSt, hfe.trans hfn.symm, hle, by omega, ha, hd, hr, hpr, hm, hx,
          fun m' hi => ?_⟩
        rw [hpc]
        exact ⟨hst m' hi, ih hR hK w rfl hfe hle rfl⟩
    · cases h

/-- **A block through its collectives and lifetime markers on one thread**, for every flag
`alloca`, program, function, block, position `p0`, positions `ps` of collective calls and
lifetime markers and segments `Ss` and summary `L` that `summarizePieces` gives with the flag,
every context `c` of the program, values `w` the collectives deliver, and thread whose innermost
frame `f` (above frames `rest`) runs `fn` at block `lbl` and position `p0`, with memory `m`: the
thread runs the segments and then the rest of the block (`Piece.Through`), each segment's
obligations a premise at its own start frame. `Piece.throughTo` whose continuation is
`Block.sound_withAt` at the position after the last call (`summarizePieces_last`). -/
theorem Piece.through {P : Program} {fn : Func} {lbl : Nat} {alloca : Bool} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} {ps : List Nat} {p0 : Nat} {Ss : List Piece}
    {L : Summary} (h : summarizePieces P fn lbl p0 ps alloca = some (Ss, L))
    (w : Nat → Option Val × Mem) {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = f :: rest)
    (hfn : f.fn = fn) (hl : f.label = lbl) (hp : f.pc = p0) :
    Piece.Through c lbl rest L Ss w t m f := by
  unfold Piece.Through
  refine Piece.throughTo hP h ?_ w ht hfn hl hp
  intro t m f ht hfn hl hp hds
  have hc : coversAt alloca P fn lbl (ps.foldl (fun _ p => p + 1) p0)
      (fun σ tm => σ.exitAt fn lbl tm) L.obls L = true := by
    unfold coversAt
    rw [summarizePieces_last h]
    simp [List.isPrefixOf_iff_prefix]
  exact (Block.sound_withAt (contract := false) (ex := fun σ tm => σ.exitAt fn lbl tm) hc hP ht
    hfn hl hp hds fun hR hb hpc hx hcs => SState.exitAt_sound hR hb hpc
      (by rw [hR.fn, hR.label, hfn, hl]; exact hx) hcs).1

/-- A segment `summarizeTo` gives with the `alloca` flag off makes no `alloca`'s effect: for
every program, function, block and positions `p0` and `p1` (`SState.run_alloca`). -/
theorem summarizeTo_allocates {P : Program} {fn : Func} {lbl p0 p1 : Nat} {S : SegSummary}
    (h : summarizeTo P fn lbl p0 p1 = some S) : SEff.allocates S.effs = false := by
  unfold summarizeTo at h
  split at h
  · split at h
    · split at h
      · split at h
        · rename_i σ hσ
          split at h
          · cases h
            exact SState.run_alloca hσ rfl rfl
          · cases h
        · cases h
      · cases h
    · cases h
  · cases h

/-- The segments and the summary of the rest that `summarizeSegs` gives make no `alloca`'s
effect: for every program, function, block, position `p0` and positions `ps`
(`summarizeTo_allocates`, `summarizeWith_allocates`). -/
theorem summarizeSegs_allocates {P : Program} {fn : Func} {lbl : Nat} :
    ∀ {ps : List Nat} {p0 : Nat} {Ss : List SegSummary} {L : Summary},
      summarizeSegs P fn lbl p0 ps = some (Ss, L) →
      (∀ S ∈ Ss, SEff.allocates S.effs = false) ∧ SEff.allocates L.effs = false
  | [], _, Ss, L, h => by
    obtain ⟨L', hL, he⟩ := Option.map_eq_some_iff.1 h
    cases he
    exact ⟨by simp, summarizeWith_allocates hL⟩
  | p1 :: ps, p0, Ss, L, h => by
    unfold summarizeSegs at h
    split at h
    · rename_i S Ss' L' hS hR
      cases h
      refine ⟨fun S' hS' => ?_, (summarizeSegs_allocates hR).2⟩
      rcases List.mem_cons.1 hS' with rfl | hS'
      · exact summarizeTo_allocates hS
      · exact (summarizeSegs_allocates hR).1 S' hS'
    · cases h

/-- `summarizePieces` of positions at which `summarizeSegs` gives segments: for every program,
function, block, position `p0` and positions `ps`, the same segments as collectives
(`Piece.coll`) and the same summary of the rest. -/
theorem summarizeSegs_pieces {P : Program} {fn : Func} {lbl : Nat} :
    ∀ {ps : List Nat} {p0 : Nat} {Ss : List SegSummary} {L : Summary},
      summarizeSegs P fn lbl p0 ps = some (Ss, L) →
      summarizePieces P fn lbl p0 ps = some (Ss.map .coll, L)
  | [], p0, Ss, L, h => by
    obtain ⟨L', hL, he⟩ := Option.map_eq_some_iff.1 h
    obtain ⟨rfl, rfl⟩ := Prod.mk.inj he
    simp [summarizePieces,
      show summarizeAt false P fn lbl p0 (fun σ tm => σ.exitAt fn lbl tm) = some L' from hL]
  | p1 :: ps, p0, Ss, L, h => by
    unfold summarizeSegs at h
    split at h
    · rename_i S Ss' L' hS hR
      cases h
      simp [summarizePieces, summarizePiece, hS, summarizeSegs_pieces hR]
    · cases h

/-- The run through collectives only is `Seg.Through`: for every context, block, frames, summary
`L` and segments `Ss` that make no `alloca`'s effect (`SEff.allocates`), deliveries, thread,
memory and frame, `Piece.Through` of `Ss` as collectives (`Piece.coll`) gives `Seg.Through` of
`Ss` (`EndsAt.ends` at the end). -/
theorem Piece.Through.seg {c : Ctx} {lbl : Nat} {rest : List Frame} {L : Summary}
    (hL : SEff.allocates L.effs = false) :
    ∀ {Ss : List SegSummary} {w : Nat → Option Val × Mem} {t : Thread} {m : Mem} {f : Frame},
      (∀ S ∈ Ss, SEff.allocates S.effs = false) →
      Piece.Through c lbl rest L (Ss.map .coll) w t m f → Seg.Through c lbl rest L Ss w t m f
  | [], _, _, _, _, _, h => fun hds => (h hds).ends hL
  | _ :: _, _, _, _, _, ha, h => fun hds => by
    obtain ⟨fe, me, ws, fd, hSt, h1, h2, h3, h4, h5, h6, h7, h8, h9, h10, fr, hres, hT⟩ := h hds
    rw [SEff.blocks_eq_nil (ha _ List.mem_cons_self), List.nil_append] at h4
    exact ⟨fe, me, ws, fd, hSt, h1, h2, h3, h4, h5, h6, h7, h8, h9, h10, fr, hres,
      Piece.Through.seg hL (fun S hS => ha S (List.mem_cons_of_mem _ hS)) hT⟩

/-- **A block's segments on one thread**, for every program, function, block, position `p0`,
positions `ps` of collective calls and summaries `Ss` and `L` that `summarizeSegs` gives, every
context `c` of the program, values `w` the collectives deliver, and thread whose innermost frame
`f` (above frames `rest`) runs `fn` at block `lbl` and position `p0`, with memory `m`: the thread
runs the segments and then the rest of the block (`Seg.Through`), each segment's obligations a
premise at its own start frame. `Piece.through` with collectives only (`summarizeSegs_pieces`,
`Piece.Through.seg`). The delivered values are parameters; a schedule gives them. -/
theorem Seg.through {P : Program} {fn : Func} {lbl : Nat} {c : Ctx} (hP : c.prog = P)
    {rest : List Frame} {ps : List Nat} :
    ∀ {p0 : Nat} {Ss : List SegSummary} {L : Summary}, summarizeSegs P fn lbl p0 ps = some (Ss, L) →
    ∀ (w : Nat → Option Val × Mem) {t : Thread} {m : Mem} {f : Frame}, t.frames = f :: rest →
      f.fn = fn → f.label = lbl → f.pc = p0 → Seg.Through c lbl rest L Ss w t m f := by
  intro p0 Ss L h w t m f ht hfn hl hp
  obtain ⟨hA, hL⟩ := summarizeSegs_allocates h
  exact (Piece.through hP (summarizeSegs_pieces h) w ht hfn hl hp).seg hL hA

end MojoProof.Sym
