import MojoProof.Sym.OblHave
import MojoProof.Sym.Payload
import MojoProof.Sym.SchedWait
import MojoProof.Sym.Command

/-!
# A thread through a block's collective calls, and the tactic mojo_seg

Every result here is for every program, context, thread, memory and delivered values.

A block whose statements call collectives (the barrier, warp shuffles) has the summaries of its
segments (`summarizeSegs`, `Seg.through`, MojoProof/Sym/Segment.lean): each segment's run to its
call, the thread resumed there with the value and memory the collective delivers, and the block's
end after the last call. Each segment's obligations are at the entry valuation of the frame it
starts at; here they are at the valuation the thread resumes at (`Valuation.resume`,
MojoProof/Sym/OblLemmas.lean), the registers after the previous segment's statements with the
call's register set to the delivered value, so `mojo_obl` reads them as it reads a block's.

* `SegSummary.toSummary`: a segment's summary as a block summary (exit `ret`), for `mojo_obl`;
  `SState.toSummary`: a lifetime marker's segment as one.
* `RunsVia`: a thread's run through collective calls, one wait per delivered value, then to its
  end on a memory of a final predicate.
* `Valuation.entry_set`: the entry valuation of a frame with a register set reads only its
  function, registers and operands, so the frame a call or a marker resumes to has the entry
  valuation `Valuation.resume` of the segment's.
* `RunsVia.of_wait`: a run to a collective call, a predicate on the call and the memory at it,
  and a continuation from the resumed frame give `RunsVia`. `RunsVia.of_through` is its case at
  `Seg.Through`: a segment's obligations at a valuation equal to its frame's entry valuation
  continue `Seg.Through` into `RunsVia`, with the next frame's entry valuation `Valuation.resume`
  of it.
* `RunsVia.of_ends`: after the last call, the block's obligations, its exit and a returning path
  from its target (`RetWith`, `Runs.of_retWith`) end the run.
* `Piece.fires` and `RunsVia.of_fires`: the segments of a block through its collectives and
  lifetime markers (`Piece.ThroughTo`, MojoProof/Sym/Segment.lean), each one's premises at the
  valuation the previous one resumes to and a final check, as one closed Boolean on a concrete
  valuation and deliveries; it gives `RunsVia` through the collectives, then the continuation's
  run through the waits after them (none: to the thread's end).
* `RunsVia.of_chain`: a thread through a sequence of loops whose last path out stops after its
  last edge (`ChainWith.enter`, MojoProof/Sym/Loop.lean) runs through the waits that a
  continuation from the frame entered runs through.
* `mojo_seg`: `RunsVia.of_through` at the latest `Seg.Through` hypothesis, the obligations by
  `mojo_obl`.
* `sym_segs n := P fn lbl p0 ps`: the segments `summarizeSegs` gives, as quoted definitions (as
  `sym_summary` quotes a block's summary), so that `mojo_obl` reads their tables without
  evaluating the summarizer.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **A segment's summary as a block summary**: the node table, register entries, memory effects,
obligations and number of statements of segment summary `S`, with exit `ret` (the statement at
the end of a segment is a collective call, which no block exit runs). For every segment summary;
`mojo_obl` reads the obligations of `S.toSummary`, and `Valuation.resume` its registers. -/
def SegSummary.toSummary (S : SegSummary) : Summary :=
  ⟨S.nodes, S.regs, S.effs, S.obls, .ret, S.len⟩

/-- **A lifetime marker's segment as a block summary**: the node table, register entries, memory
effects and obligations of state `σ` after `n` statements, with exit `ret` (a lifetime marker
ends the segment), for `Valuation.resume` after the marker. For every state and number. -/
def SState.toSummary (σ : SState) (n : Nat) : Summary :=
  ⟨σ.nodes, σ.regs, σ.effs, σ.obls, .ret, n⟩

/-- **A thread's run through collective calls**: from thread `t` on memory `m`, for each pair
`(P, d)` of `ws` in turn, a run to a collective call (`ToWait`), the thread `u` waiting at
intrinsic `i` with arguments `xs` on memory `m₁` such that `P u i xs m₁` (so `P` can state the
instruction `u.at` the thread waits at), the thread then resumed with the delivered value `d.1`
(`Thread.resume`) on the delivered memory `d.2`; after the last pair, a run to the thread's end
(`Runs`) on a memory of `Q`. For every context, final predicate, list of pairs, thread and
memory. -/
def RunsVia (c : Ctx) (Q : Mem → Prop) :
    List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem)) → Thread → Mem →
      Prop
  | [], t, m => ∃ m', Runs c t m m' ∧ Q m'
  | (P, d) :: ws, t, m => ∃ u i xs e m₁, ToWait c t m (.wait u i xs e) m₁ ∧ P u i xs m₁ ∧
      RunsVia c Q ws (u.resume d.1) d.2

/-- **Steps before a run through collective calls**: for every context `c`, final predicate `Q`,
list of pairs `ws`, threads `t`, `t'` and memories `m`, `m'`, if `t` on `m` steps to `t'` on `m'`
(`Steps`), a run through `ws` from `t'` on `m'` (`RunsVia`) is one from `t` on `m`: the steps come
before the run to the first wait (`ToWait`), or with no wait left, before the run to the end
(`Runs`). -/
theorem RunsVia.of_steps {c : Ctx} {Q : Mem → Prop}
    {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    {t t' : Thread} {m m' : Mem} (hS : Steps c t m t' m') (h : RunsVia c Q ws t' m') :
    RunsVia c Q ws t m := by
  match ws, h with
  | [], ⟨m'', ⟨t'', m₁, hS', hst⟩, hQ⟩ => exact ⟨m'', ⟨t'', m₁, hS.trans hS', hst⟩, hQ⟩
  | (_, _) :: _, ⟨u, i, xs, e, m₁, ⟨u', i', ys, d', he, hS', hst⟩, hP, hr⟩ =>
    exact ⟨u, i, xs, e, m₁, ⟨u', i', ys, d', he, hS.trans hS', hst⟩, hP, hr⟩

/-- **The entry valuation of a set frame reads its function, registers and operands**: for
every context `c`, step count `k`, memory `m`, frames `f` and `g` with one function, registers
and `fmul contract` operands, register `r`, value `v` and position `p`, `f` with `r` set to `v`
(`Frame.set`) at position `p` and `g` with `r` set to `v` have one entry valuation. At `g` the
frame `Valuation.resume` reads (`Valuation.frameAtWith true`), it is the entry valuation of the
frame a call or a lifetime marker resumes to. -/
theorem Valuation.entry_set {c : Ctx} {k : Nat} {m : Mem} {f g : Frame} (hfn : f.fn = g.fn)
    (hr : ∀ s, f.regs s = g.regs s) (hp : ∀ s, f.prods s = g.prods s) (r : Option Nat)
    (v : Option Val) (p : Nat) :
    Valuation.entry c k m { f.set r v none with pc := p } =
      Valuation.entry c k m { g.set r v none with fn := g.fn } := by
  obtain ⟨fn, l, q, rs, ps, al, de⟩ := f
  obtain ⟨fn', l', q', rs', ps', al', de'⟩ := g
  obtain rfl : fn = fn' := hfn
  obtain rfl : rs = rs' := funext hr
  obtain rfl : ps = ps' := funext hp
  rcases r with _ | r <;> rcases v with _ | v <;> rfl

/-- **A run to a collective call into `RunsVia`**, for every context `c`, block `lbl`, frames
`rest`, segment summary `S`, delivery `d`, thread `t` on memory `m` with frame `f` of function
`fn` at position `p`, blocks `al`, predicate `T` on the thread and frame the call resumes to, and
predicates `P` and `Q`: if the thread's steps reach a frame `fe` waiting at `S`'s collective with
the facts of `Waits` (`fe`'s `alloca` blocks `al`) and the thread resumed with `d.1` has frame
`fr` with `T`, `P` holds of every thread at the call (`u.at` is `fn`'s name, `lbl` and
`p + S.len`), `S`'s collective, the values of its arguments and the memory its effects make, and
every frame `fr` of `fn` at position `p + S.len + 1` with `alloca` blocks `al` and thread `t'` with
`T`, whose entry valuation is `Valuation.resume S.toSummary r d` of `f`'s for the register `r` of
the call (`resReg`), continue into `RunsVia` on `d.2`, the thread runs through the call into
them. `RunsVia.of_through` and `RunsVia.of_fires` are its cases at a segment's run. -/
theorem RunsVia.of_wait {c : Ctx} {lbl : Nat} {rest : List Frame} {S : SegSummary}
    {d : Option Val × Mem} {t : Thread} {m : Mem} {f : Frame} {fn : Func} {p : Nat}
    {al : List Nat} {T : Thread → Frame → Prop} {P : Thread → Intrinsic → List Val → Mem → Prop}
    {Q : Mem → Prop} {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    (hfn : f.fn = fn) (hp : f.pc = p)
    (h : ∃ fe me xs e, Steps c t m ⟨fe :: rest, t.k + S.len⟩ me ∧ fe.fn = f.fn ∧
      fe.label = lbl ∧ fe.pc = f.pc + S.len ∧ fe.allocas = al ∧ fe.dest = f.dest ∧
      (∀ r, fe.regs r = regVal (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes) S.regs r) ∧
      (∀ r, fe.prods r = regProdIn (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes) S.nodes S.regs r) ∧
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) S.effs =
        .ok me ∧
      S.args.mapM (·.eval (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes)) = .ok xs ∧
      step c ⟨fe :: rest, t.k + S.len⟩ me = .ok (.wait S.call.intr xs e) ∧
      ∃ fr, Thread.resume ⟨fe :: rest, t.k + S.len⟩ d.1 = ⟨fr :: rest, t.k + S.len + 1⟩ ∧
        T ⟨fr :: rest, t.k + S.len + 1⟩ fr)
    (hP : ∀ u me xs, u.at = some (fn.name, lbl, p + S.len) →
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) S.nodes) S.effs =
        .ok me →
      S.args.mapM (·.eval (Valuation.entry c t.k m f)
        (vals (Valuation.entry c t.k m f) S.nodes)) = .ok xs → P u S.call.intr xs me)
    (hn : ∀ fr t', t'.frames = fr :: rest → fr.fn = fn → fr.pc = p + S.len + 1 →
      fr.allocas = al → T t' fr →
      Valuation.entry c t'.k d.2 fr =
        (Valuation.entry c t.k m f).resume S.toSummary (resReg fn lbl (p + S.len)) d →
      RunsVia c Q ws t' d.2) :
    RunsVia c Q ((P, d) :: ws) t m := by
  obtain ⟨fe, me, xs, e, hS, hfe, hle, hpc, hal, -, hrg, hpr, hm, has, hst, fr, hres, hT⟩ := h
  have hat : Thread.at ⟨fe :: rest, t.k + S.len⟩ = some (fn.name, lbl, p + S.len) := by
    show some (fe.fn.name, fe.label, fe.pc) = _
    rw [hfe, hle, hpc, hfn, hp]
  refine ⟨_, _, _, _, _, ⟨_, _, _, _, rfl, hS, hst⟩, hP _ me xs hat hm has, ?_⟩
  have hr : ((fe.fn.blocks.find? (·.label == fe.label)).bind fun b =>
      b.stmts[fe.pc]?.bind (·.res)) = resReg fn lbl (p + S.len) := by
    rw [hfe, hle, hpc, hfn, hp, resReg]
    cases fn.blocks.find? (·.label == lbl) <;> rfl
  have e : Thread.resume ⟨fe :: rest, t.k + S.len⟩ d.1 =
      ⟨{ fe.set (resReg fn lbl (p + S.len)) d.1 none with pc := fe.pc + 1 } :: rest,
        t.k + S.len + 1⟩ := by
    show (⟨{ fe.set _ d.1 none with pc := fe.pc + 1 } :: rest, t.k + S.len + 1⟩ : Thread) = _
    rw [hr]
  rw [hres]
  rw [e] at hres
  injection hres with h1
  injection h1 with h2
  subst h2
  exact hn _ _ rfl (by unfold Frame.set; split <;> exact hfe.trans hfn)
    (by show fe.pc + 1 = _; rw [hpc, hp]) (by unfold Frame.set; split <;> exact hal) hT
    (Valuation.entry_set (g := (Valuation.entry c t.k m f).frameAtWith true 0 S.toSummary) hfe hrg
      hpr _ d.1 _)

/-- **A segment's run into `RunsVia`**, for every context `c`, block `lbl`, frames `rest`,
summaries `L`, `S` and `Ss`, delivered values `w` (with `w 0 = d` and the rest `w'`), thread `t`
on memory `m` with frame `f` of function `fn` at position `p` with `alloca` blocks `al`,
valuation `V` equal to `f`'s entry valuation, and predicates `P` and `Q`: from the run of the
segments (`Seg.Through`), if `S`'s obligations hold at `V`, `P` holds of every thread at the call
(`u.at` is `fn`'s name, `lbl` and `p + S.len`), `S`'s collective, the values of its arguments and
the memory its effects make, and every frame `fr` of `fn` at position
`p + S.len + 1` with `alloca` blocks `al` and thread `t'` the thread resumes with, whose entry
valuation is `V.resume S.toSummary r d` for the register `r` of the call (`resReg`), continue
into `RunsVia` of the other segments, the thread runs through the call into them
(`RunsVia.of_wait`). -/
theorem RunsVia.of_through {c : Ctx} {lbl : Nat} {rest : List Frame} {L : Summary}
    {S : SegSummary} {Ss : List SegSummary} {w w' : Nat → Option Val × Mem}
    {d : Option Val × Mem} {t : Thread} {m : Mem} {f : Frame} {fn : Func} {p : Nat}
    {al : List Nat} {V : Valuation} {P : Thread → Intrinsic → List Val → Mem → Prop}
    {Q : Mem → Prop} {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    (h : Seg.Through c lbl rest L (S :: Ss) w t m f) (hV : Valuation.entry c t.k m f = V)
    (hfn : f.fn = fn) (hp : f.pc = p) (ha : f.allocas = al) (hw : w 0 = d)
    (hw' : (fun i => w (i + 1)) = w')
    (hds : ∀ x ∈ S.toSummary.obls, x.Holds V (vals V S.toSummary.nodes))
    (hP : ∀ u me xs, u.at = some (fn.name, lbl, p + S.len) →
      SEff.run V (vals V S.nodes) S.effs = .ok me →
      S.args.mapM (·.eval V (vals V S.nodes)) = .ok xs → P u S.call.intr xs me)
    (hn : ∀ fr t', t'.frames = fr :: rest → fr.fn = fn → fr.pc = p + S.len + 1 →
      fr.allocas = al → Seg.Through c lbl rest L Ss w' t' d.2 fr →
      Valuation.entry c t'.k d.2 fr = V.resume S.toSummary (resReg fn lbl (p + S.len)) d →
      RunsVia c Q ws t' d.2) :
    RunsVia c Q ((P, d) :: ws) t m := by
  subst hV hw hw' ha
  exact RunsVia.of_wait (T := fun t' fr => Seg.Through c lbl rest L Ss (fun i => w (i + 1)) t'
    (w 0).2 fr) hfn hp (h hds) hP hn

/-- **The run after a block's last collective call**, for every program `P`, function `fn`,
context `c` of `P`, thread `t` whose only frame is `f`, with no `alloca` blocks, on memory `m`,
valuation `V` equal to `f`'s entry valuation, block `lbl` with summary `L`, target `dst`, path
`ps` and predicate `Q`: from the run of the block's statements after its last call
(`Seg.Through` with no segment left), if `L`'s obligations hold at `V`, `L`'s exit goes to `dst`,
the path `ps` starts at `dst`, `coversPathWith` accepts it from the position the edge enters at,
and it returns on a memory of `Q` from the valuation the edge enters with (`RetWith`), the thread
runs to its end on a memory of `Q`. `Ends.edge`, then `Runs.of_retWith`. -/
theorem RunsVia.of_ends {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P) {lbl : Nat}
    {L : Summary} {w : Nat → Option Val × Mem} {t : Thread} {m : Mem} {f : Frame}
    {V : Valuation} {dst : Nat} {ps : List (Nat × List Cond × Summary)} {Q : Mem → Prop}
    (h : Seg.Through c lbl [] L [] w t m f) (hV : Valuation.entry c t.k m f = V)
    (hfn : f.fn = fn) (ha : f.allocas = [])
    (hds : ∀ x ∈ L.obls, x.Holds V (vals V L.nodes))
    (hd : L.exit.dest V (vals V L.nodes) = some dst)
    (hc : coversPathWith false P fn (L.exit.pc fn dst) ps = true)
    (hl : ps.head?.map (·.1) = some dst) (hR : RetWith false (V.into lbl L) Q ps) :
    RunsVia c Q [] t m := by
  subst hV
  obtain ⟨t₁, m₁, f', hS, hst, hfn', hl', hp', ha', -, hE⟩ := Ends.edge rfl (h hds) hd
  have hE' : Valuation.entry c ((Valuation.entry c t.k m f).k + L.len + 1) m₁ f' =
      (Valuation.entry c t.k m f).into lbl L := hE
  have hR' : RetWith false (Valuation.entry c ((Valuation.entry c t.k m f).k + L.len + 1) m₁ f')
      Q ps := by rw [hE']; exact hR
  obtain ⟨m', ⟨t₂, m₂, hS₂, hd₂⟩, hq⟩ := Runs.of_retWith hP hc
    (t := ⟨[f'], (Valuation.entry c t.k m f).k + L.len + 1⟩) (m := m₁) rfl (hfn'.trans hfn)
    (by rw [hl', hl]) (by rw [hp']; exact congrArg (L.exit.pc · dst) hfn) (ha'.trans ha) hR'
  exact ⟨m', ⟨t₂, m₂, hS.trans_step hst hS₂, hd₂⟩, hq⟩

/-- **The premises of a block's segments on one valuation**, a closed Boolean on a concrete one:
for function `fn`, block `lbl`, final check `F`, segments `Ss` (`summarizePieces`) from position
`p`, deliveries `ds` (one per collective, in order) and valuation `V` at the first segment's
start. A collective's segment `S`: its obligations hold at `V`, and the rest holds at
`V.resume S.toSummary r d` for the call's register `r` (`resReg`) and the first delivery `d`. A
lifetime marker's segment of `n` statements: its obligations hold at `V` (the pointer's term
evaluates and the effects run), the effects make a memory `me` on which the pointer, a pointer
`q`, is into a block the thread owns, and the rest holds at
`V.resume (σ.toSummary n) none (none, me.setLive q.block start)`. With no segment left, no
delivery is left and `F V`. For every function, block, check, list of segments, position, list of
deliveries and valuation. -/
def Piece.fires (fn : Func) (lbl : Nat) (F : Valuation → Bool) :
    List Piece → Nat → List (Option Val × Mem) → Valuation → Bool
  | [], _, ds, V => ds.isEmpty && F V
  | .coll _ :: _, _, [], _ => false
  | .coll S :: Ss, p, d :: ds, V => decide (∀ x ∈ S.obls, x.Holds V (vals V S.nodes)) &&
      Piece.fires fn lbl F Ss (p + S.len + 1) ds
        (V.resume S.toSummary (resReg fn lbl (p + S.len)) d)
  | .life σ start x n :: Ss, p, ds, V =>
      decide (∀ d ∈ Cond.ok x :: .mem σ.effs :: σ.obls, d.Holds V (vals V σ.nodes)) &&
      match SEff.run V (vals V σ.nodes) σ.effs, x.eval V (vals V σ.nodes) with
      | .ok me, .ok (.ptr q) =>
        ((me.block q).any fun b => b.owner == .thread V.ctx.who.thread) &&
          Piece.fires fn lbl F Ss (p + n + 1) ds
            (V.resume (σ.toSummary n) none (none, me.setLive q.block start))
      | _, _ => false

/-- **A block's segments run into `RunsVia`**, for every context `c`, block `lbl`, frames
`rest`, continuation `K`, function `fn`, check `F`, predicate `Q`, list `ws` of waits after the
block's and default delivery `d₀`: if `K` and `F` at the entry valuation of a frame give a run
through `ws` (`RunsVia`; with `ws` empty, to the thread's end on a memory of `Q`), then for every
segments `Ss`, position `p`, deliveries `ds` and thread `t` on memory `m` with frame `f` of `fn`
at position `p` that runs the segments to `K` with the `i`-th collective delivering
`ds.getD i d₀` (`Piece.ThroughTo`), if `Piece.fires` holds at `f`'s entry valuation, the thread
runs through one wait per delivery, each wait's predicate `True`, and then through `ws`
(`RunsVia`). By induction on `Ss`: `RunsVia.of_wait` at a collective, the step past the marker
(`intrinsic_lifetime_ptr`) and `Valuation.entry_set` at a lifetime marker. -/
theorem RunsVia.of_fires {c : Ctx} {lbl : Nat} {rest : List Frame}
    {K : Thread → Mem → Frame → Prop} {fn : Func} {F : Valuation → Bool} {Q : Mem → Prop}
    {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    {d₀ : Option Val × Mem}
    (hK : ∀ t m f, K t m f → F (Valuation.entry c t.k m f) = true → RunsVia c Q ws t m) :
    ∀ {Ss : List Piece} {p : Nat} {ds : List (Option Val × Mem)} {t : Thread} {m : Mem}
      {f : Frame}, Piece.ThroughTo c lbl rest K Ss (fun i => ds.getD i d₀) t m f → f.fn = fn →
      f.pc = p → Piece.fires fn lbl F Ss p ds (Valuation.entry c t.k m f) = true →
      RunsVia c Q (ds.map (fun d => (fun _ _ _ _ => True, d)) ++ ws) t m := by
  intro Ss
  induction Ss with
  | nil =>
    intro p ds t m f h _ _ hF
    simp only [Piece.fires, Bool.and_eq_true, List.isEmpty_iff] at hF
    obtain ⟨rfl, hF⟩ := hF
    exact hK t m f h hF
  | cons P Ss ih =>
    intro p ds t m f h hfn hp hF
    cases P with
    | coll S =>
      cases ds with
      | nil => simp [Piece.fires] at hF
      | cons d ds =>
        simp only [Piece.fires, Bool.and_eq_true, decide_eq_true_eq] at hF
        obtain ⟨hds, hF⟩ := hF
        rw [List.map_cons, List.cons_append]
        refine RunsVia.of_wait (T := fun t' fr => Piece.ThroughTo c lbl rest K Ss
          (fun i => ds.getD i d₀) t' d.2 fr) hfn hp (h hds) (fun _ _ _ _ _ _ => trivial) ?_
        intro fr t' _ hfr hpr _ hT hV
        exact ih hT hfr hpr (by rw [hV]; exact hF)
    | life σ start x n =>
      simp only [Piece.fires, Bool.and_eq_true, decide_eq_true_eq] at hF
      obtain ⟨hds, hF⟩ := hF
      split at hF
      · rename_i me q hm hx
        simp only [Bool.and_eq_true] at hF
        obtain ⟨ho, hF⟩ := hF
        obtain ⟨fe, me', v, hS, hfe, -, hpc, -, -, hrg, hpr, hm', hx', hst⟩ := h hds
        obtain rfl : me' = me := Except.ok.inj (hm'.symm.trans hm)
        obtain rfl : v = .ptr q := Except.ok.inj (hx'.symm.trans hx)
        obtain ⟨hs, hT⟩ := hst _ (intrinsic_lifetime_ptr ho)
        refine RunsVia.of_steps (hS.trans_step hs (.refl _ _))
          (ih hT (hfe.trans hfn) (by show fe.pc + 1 = _; rw [hpc, hp]) ?_)
        exact (congrArg (Piece.fires fn lbl F Ss (p + n + 1) ds)
          (Valuation.entry_set (c := c) (k := t.k + n + 1) (m := me'.setLive q.block start)
            (g := (Valuation.entry c t.k m f).frameAtWith true 0 (σ.toSummary n)) hfe hrg hpr
            none none (fe.pc + 1))).trans hF
      · cases hF

/-- **A thread through a sequence of loops into a continuation**, for every flag `alloca` and
`contract`, program, function `fn`, context `c` of the program, frames `rest`, block `d`,
position `q`, predicate `J` on valuations, list `Ls` of loops, path `(l, ds, S) :: E` before
them, position `p0`, final predicate `Q` and list `ws` of waits, when the chain checker accepts
the paths (`coversChainAt alloca contract`): if every thread whose innermost frame runs `fn`
above `rest` at block `d`'s position `q` with `J` at its entry valuation runs through `ws`
(`RunsVia`), then so does every thread whose innermost frame `f` runs `fn` above `rest` at block
`l`'s position `p0` with `ChainWith contract (BackWith contract d q J) Ls` at `f`'s entry
valuation: the chain's last path out stops after its last edge, into `d` at `q`
(`ChainWith.enter`, then `RunsVia.of_steps`). -/
theorem RunsVia.of_chain {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} {d q : Nat} {J : Valuation → Prop}
    {Ls : List LoopSeg} {p0 l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} {Q : Mem → Prop}
    {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    (hc : coversChainAt alloca contract P fn p0 l ds S E Ls = true)
    (hK : ∀ t m f, t.frames = f :: rest → f.fn = fn → f.label = d → f.pc = q →
      J (Valuation.entry c t.k m f) → RunsVia c Q ws t m)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = l) (hp : f.pc = p0)
    (h : ChainWith contract (BackWith contract d q J) Ls (Valuation.entry c t.k m f) l ds S E) :
    RunsVia c Q ws t m :=
  let ⟨_, _, _, hS, ht', hfn', hl', hp', _, _, hJ⟩ := ChainWith.enter hP hc ht hfn hl hp h
  RunsVia.of_steps hS (hK _ _ _ ht' hfn' hl' hp' hJ)

/-- **`mojo_seg`** runs a thread through its next collective call: on a goal
`RunsVia c Q ((P, d) :: ws) t m`, `RunsVia.of_through` at the latest hypothesis
`Seg.Through c lbl rest L (S :: Ss) w t m f`, at the valuation of the latest hypothesis
`Valuation.entry c t.k m f = V` (the previous call's `Valuation.resume`, else the entry
valuation), with the latest hypotheses on `f`'s function, position and `alloca` blocks, the
delivered values `w 0` and `fun i => w (i + 1)` by `rfl` (a list's `getD`, as
`fun i => [d₀, …].getD i d₀`), and `P` by `decide`, else, for `P` as `fun _ i _ _ => i = cl.intr`
(`Intrinsic` has no decidable equality), by the kernel's decision that the summary's collective is
`cl`, the barrier or a shuffle of a mode, with, for `P` as
`fun u i _ _ => u.at = some (n, lbl, q) ∧ i = cl.intr`, the kernel's decision that `q` is the
call's position (`RunsVia.of_through`'s `u.at`) first; it introduces
the frame, thread and facts of the continuation, anonymous, for the next `mojo_seg`, and runs
`mojo_obl` on the segment's obligations, whose goals left open (logged as `mojo_obl` logs them)
come before the continuation. For every program; it fails when `P` or a hypothesis it looks for
is not there. -/
syntax (name := mojoSeg) "mojo_seg" : tactic

macro_rules
  | `(tactic| mojo_seg) => `(tactic| (
      first
        | refine RunsVia.of_through ‹Seg.Through _ _ _ _ (_ :: _) _ _ _ _›
            (by first | assumption | rfl) ‹_› ‹_› ‹_› rfl rfl ?_
            (fun _ _ _ hat _ _ => by
              (try dsimp only)
              (try refine ⟨hat.trans (by decide +kernel), ?_⟩)
              first
                | decide +kernel
                | exact congrArg Coll.intr (a₂ := Coll.barrier) (by decide +kernel)
                | exact congrArg Coll.intr (a₂ := Coll.shfl .bfly) (by decide +kernel)
                | exact congrArg Coll.intr (a₂ := Coll.shfl .idx) (by decide +kernel)
                | exact congrArg Coll.intr (a₂ := Coll.shfl .up) (by decide +kernel)
                | exact congrArg Coll.intr (a₂ := Coll.shfl .down) (by decide +kernel)) ?_
        | fail "mojo_seg: no Seg.Through hypothesis with a segment and its frame's facts, or the \
            predicate on the collective is not decided"
      rotate_left
      intro _ _ _ _ _ _ _ _
      rotate_left
      mojo_obl))

section SymSegs

open Lean Elab Command Meta

deriving instance ToExpr for Coll
deriving instance ToExpr for SegSummary

/-- The term of a collective call (`Coll`), as `sym_segs` quotes it. -/
add_decl_doc instToExprColl

/-- The term of a segment summary (`SegSummary`), as `sym_segs` quotes it. -/
add_decl_doc instToExprSegSummary

/-- `sym_segs n := P fn lbl p0 ps` defines, in the current namespace, `n_0`, …, `n_k :
SegSummary` as the segments `summarizeSegs P fn lbl p0 ps` gives (the segment to each collective
call at the positions `ps`, in order), computed when the command is elaborated and quoted, as
`sym_summary` defines a block's summary; an optional doc comment before the command becomes each
definition's docstring, followed by the segment's number and call position. An error if
`summarizeSegs` gives `none`. Nothing here is trusted: a theorem uses the segments through
`summarizeSegs P fn lbl p0 ps = some ([n_0, …, n_k], L)`, which the kernel evaluates
(`decide +kernel`), so a wrong quotation makes the theorem fail, not hold. -/
syntax (name := symSegs) (docComment)? "sym_segs " ident " := " term:max term:max term:max
  term:max term:max : command

/-- Elaborates `sym_segs`; `unsafe` because it evaluates the segments. -/
@[command_elab symSegs] unsafe def elabSymSegs : CommandElab := fun stx => do
  let ns ← getCurrNamespace
  let base := stx[2].getId
  liftTermElabM do
    let P ← Term.elabTermEnsuringType stx[4] (mkConst ``MojoProof.LLVM.Program)
    let fn ← Term.elabTermEnsuringType stx[5] (mkConst ``MojoProof.LLVM.Func)
    let lbl ← Term.elabTermEnsuringType stx[6] (mkConst ``Nat)
    let p0 ← Term.elabTermEnsuringType stx[7] (mkConst ``Nat)
    let ps ← Term.elabTermEnsuringType stx[8] (mkApp (mkConst ``List [.zero]) (mkConst ``Nat))
    Term.synthesizeSyntheticMVarsNoPostponing
    let e ← instantiateMVars (mkAppN (mkConst ``summarizeSegs) #[P, fn, lbl, p0, ps])
    let ty := mkApp (mkConst ``Option [.zero]) (mkApp2 (mkConst ``Prod [.zero, .zero])
      (mkApp (mkConst ``List [.zero]) (mkConst ``SegSummary)) (mkConst ``Summary))
    let calls ← evalExpr (List Nat) (mkApp (mkConst ``List [.zero]) (mkConst ``Nat)) ps
    match ← evalExpr (Option (List SegSummary × Summary)) ty e with
    | none => throwError "sym_segs: block {stx[6]} of {stx[5]} from position {stx[7]} with calls \
        at {stx[8]} is outside the checker's fragment"
    | some (Ss, _) =>
      let doc ← match stx[0].getOptional? with
        | some d => pure (some (← getDocStringText ⟨d⟩))
        | none => pure none
      for (S, i) in Ss.zipIdx do
        let name := ns ++ Name.mkSimple s!"{base}_{i}"
        addAndCompile <| .defnDecl
          { name, levelParams := [], type := mkConst ``SegSummary, value := toExpr S,
            hints := .abbrev, safety := .safe }
        enableRealizationsForConst name
        if let some d := doc then
          let d := String.ofList (d.toList.reverse.dropWhile Char.isWhitespace).reverse
          addDocStringCore name s!"{d} Segment {i}, to the call at position {calls.getD i 0}."

end SymSegs

end MojoProof.Sym
