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
* `Piece.walk` and `RunsVia.of_fires`: the segments of a block through its collectives and
  lifetime markers (`Piece.ThroughTo`, MojoProof/Sym/Segment.lean), each one's premises at the
  valuation the previous one resumes to, on a concrete valuation and deliveries, give the waits
  (`Piece.Wait`: each call's position, collective, argument values and memory), the valuation
  after the last segment (`Piece.after`, a function of the deliveries) and the `alloca` blocks
  the segments add (`Piece.allocs`); with a final check there (`Piece.fires`, a closed Boolean)
  it gives `RunsVia` through the waits, each wait's predicate stating its call's instruction,
  intrinsic, arguments and memory (`Piece.Wait.via`), then the continuation's run through the
  waits after them, a function of the valuation after the block's (none: to the thread's end), to
  a final predicate that is a function of that valuation and the frame's `alloca` blocks.
* `RunsVia.of_chain`: a thread through a sequence of loops whose last path out stops after its
  last edge (`ChainWith.enter`, MojoProof/Sym/Loop.lean) runs through the waits that a
  continuation from the frame entered runs through, the continuation told the frame's `alloca`
  blocks.
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

/-- **A wait of a block's segments**: the position `pos` of a collective call in its block, the
call `call`, the values `args` of its arguments, the memory `mem` its segment's effects make,
and the delivery `dlv` (value and memory) the thread resumes with. `Piece.walk` makes one per
collective segment. -/
structure Piece.Wait where
  /-- The wait at position `pos` of collective `call`, with arguments `args`, memory `mem` and
  delivery `dlv`. -/
  mk ::
  /-- The call's position in its block. -/
  pos : Nat
  /-- The collective. -/
  call : Coll
  /-- The values of the call's arguments. -/
  args : List Val
  /-- The memory at the call. -/
  mem : Mem
  /-- The value and memory delivered to the thread at the call. -/
  dlv : Option Val × Mem

/-- **The predicate and delivery of a wait** of function `fn`'s block `lbl`, for `RunsVia`: a
thread `u` waits at intrinsic `i` with arguments `xs` on memory `me` when `u.at` is `fn`'s name,
`lbl` and `w.pos`, `i` is `w.call`'s intrinsic, `xs` is `w.args` and `me` is `w.mem`; the
delivery is `w.dlv`. For every function, block and wait. -/
abbrev Piece.Wait.via (fn : Func) (lbl : Nat) (w : Piece.Wait) :
    (Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem) :=
  (fun u i xs me => u.at = some (fn.name, lbl, w.pos) ∧ i = w.call.intr ∧ xs = w.args ∧
    me = w.mem, w.dlv)

/-- **A block's segments on one valuation**, the one checker of `RunsVia.of_fires`: for function
`fn`, block `lbl`, segments `Ss` (`summarizePieces`) from position `p`, deliveries `ds` (one per
collective, in order) and valuation `V` at the first segment's start, the waits, the valuation
after the last segment and the `alloca` blocks the segments add (newest first, as a frame lists
them), or `none`. A collective's segment `S`: its obligations hold at `V`, its arguments evaluate
to `xs` and its effects make a memory `me` (both at `V`), the wait is
`⟨p + S.len, S.call, xs, me, d⟩` for the first delivery `d`, the rest is from
`V.resume S.toSummary r d` for the call's register `r` (`resReg`), and the segment's blocks
(`SEff.blocks V S.effs`) come after the rest's. A lifetime marker's segment of `n` statements:
its obligations hold at `V` (the pointer's term evaluates and the effects run), the effects make
a memory `me` on which the pointer, a pointer `q`, is into a block the thread owns, the rest is
from `V.resume (σ.toSummary n) none (none, me.setLive q.block start)`, and the segment's blocks
come after the rest's. With no segment left, no delivery is left, the valuation is `V` and there
is no block. For every function, block, list of segments, position, list of deliveries and
valuation. -/
def Piece.walk (fn : Func) (lbl : Nat) :
    List Piece → Nat → List (Option Val × Mem) → Valuation →
      Option (List Piece.Wait × Valuation × List Nat)
  | [], _, [], V => some ([], V, [])
  | [], _, _ :: _, _ => none
  | .coll _ :: _, _, [], _ => none
  | .coll S :: Ss, p, d :: ds, V =>
      if ∀ x ∈ S.obls, x.Holds V (vals V S.nodes) then
        match S.args.mapM (·.eval V (vals V S.nodes)), SEff.run V (vals V S.nodes) S.effs with
        | .ok xs, .ok me => (Piece.walk fn lbl Ss (p + S.len + 1) ds
            (V.resume S.toSummary (resReg fn lbl (p + S.len)) d)).map
              fun r => (⟨p + S.len, S.call, xs, me, d⟩ :: r.1, r.2.1,
                r.2.2 ++ SEff.blocks V S.effs)
        | _, _ => none
      else none
  | .life σ start x n :: Ss, p, ds, V =>
      if ∀ d ∈ Cond.ok x :: .mem σ.effs :: σ.obls, d.Holds V (vals V σ.nodes) then
        match SEff.run V (vals V σ.nodes) σ.effs, x.eval V (vals V σ.nodes) with
        | .ok me, .ok (.ptr q) =>
          if (me.block q).any fun b => b.owner == .thread V.ctx.who.thread then
            (Piece.walk fn lbl Ss (p + n + 1) ds
              (V.resume (σ.toSummary n) none (none, me.setLive q.block start))).map
                fun r => (r.1, r.2.1, r.2.2 ++ SEff.blocks V σ.effs)
          else none
        | _, _ => none
      else none

/-- **The waits of a block's segments**: `Piece.walk`'s waits, none when it gives `none`.
Irreducible, as are `Piece.after`, `Piece.allocs` and `Piece.fires`: a statement about concrete
segments and deliveries then elaborates without evaluating the walk, which the kernel still does
(`decide +kernel`). -/
@[irreducible]
def Piece.waits (fn : Func) (lbl : Nat) (Ss : List Piece) (p : Nat)
    (ds : List (Option Val × Mem)) (V : Valuation) : List Piece.Wait :=
  ((Piece.walk fn lbl Ss p ds V).map Prod.fst).getD []

/-- **The valuation after a block's segments**, as a function of the deliveries `ds`:
`Piece.walk`'s, `V` when it gives `none`. -/
@[irreducible]
def Piece.after (fn : Func) (lbl : Nat) (Ss : List Piece) (p : Nat)
    (ds : List (Option Val × Mem)) (V : Valuation) : Valuation :=
  ((Piece.walk fn lbl Ss p ds V).map (·.2.1)).getD V

/-- **The `alloca` blocks a block's segments add**, newest first: `Piece.walk`'s, none when it
gives `none`. -/
@[irreducible]
def Piece.allocs (fn : Func) (lbl : Nat) (Ss : List Piece) (p : Nat)
    (ds : List (Option Val × Mem)) (V : Valuation) : List Nat :=
  ((Piece.walk fn lbl Ss p ds V).map (·.2.2)).getD []

/-- **The premises of a block's segments and a final check on one valuation**, a closed Boolean
on a concrete one: `Piece.walk` gives the waits and a valuation, and the check `F` holds there.
For every function, block, check, list of segments, position, list of deliveries and
valuation. -/
@[irreducible]
def Piece.fires (fn : Func) (lbl : Nat) (F : Valuation → Bool) (Ss : List Piece) (p : Nat)
    (ds : List (Option Val × Mem)) (V : Valuation) : Bool :=
  ((Piece.walk fn lbl Ss p ds V).map fun r => F r.2.1).getD false

/-- **A block's segments run into `RunsVia`**, for every context `c`, block `lbl`, frames
`rest`, continuation `K`, function `fn`, check `F`, family `Q` of final predicates by a valuation
and a list of `alloca` blocks, family `G` of the waits after the block's by the valuation they
start at, and default delivery `d₀`: if `K` and `F` at the entry valuation `V` of a frame with
`alloca` blocks `A` give a run through `G V` to a memory of `Q V A` (`RunsVia`; with `G V` empty,
to the thread's end), then for every segments `Ss`, position `p`, deliveries `ds` and thread `t`
on memory `m` with frame `f` of `fn` at position `p` that runs the segments to `K` with the
`i`-th collective delivering `ds.getD i d₀` (`Piece.ThroughTo`), if `Piece.fires` holds at `f`'s
entry valuation, the thread runs through the waits of `Piece.waits` (each at its call's
instruction, intrinsic, argument values and the memory its segment's effects make, then resumed
with its delivery: `Piece.Wait.via`) and then through `G` at `Piece.after`, to a memory of `Q` at
`Piece.after` and the blocks `Piece.allocs` in front of `f`'s. By induction on `Ss`:
`RunsVia.of_wait` at a collective, the step past the marker (`intrinsic_lifetime_ptr`) and
`Valuation.entry_set` at a lifetime marker. -/
theorem RunsVia.of_fires {c : Ctx} {lbl : Nat} {rest : List Frame}
    {K : Thread → Mem → Frame → Prop} {fn : Func} {F : Valuation → Bool}
    {Q : Valuation → List Nat → Mem → Prop}
    {G : Valuation → List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    {d₀ : Option Val × Mem}
    (hK : ∀ t m f, K t m f → F (Valuation.entry c t.k m f) = true →
      RunsVia c (Q (Valuation.entry c t.k m f) f.allocas) (G (Valuation.entry c t.k m f)) t m) :
    ∀ {Ss : List Piece} {p : Nat} {ds : List (Option Val × Mem)} {t : Thread} {m : Mem}
      {f : Frame}, Piece.ThroughTo c lbl rest K Ss (fun i => ds.getD i d₀) t m f → f.fn = fn →
      f.pc = p → Piece.fires fn lbl F Ss p ds (Valuation.entry c t.k m f) = true →
      RunsVia c (Q (Piece.after fn lbl Ss p ds (Valuation.entry c t.k m f))
          (Piece.allocs fn lbl Ss p ds (Valuation.entry c t.k m f) ++ f.allocas))
        ((Piece.waits fn lbl Ss p ds (Valuation.entry c t.k m f)).map
          (Piece.Wait.via fn lbl) ++ G (Piece.after fn lbl Ss p ds (Valuation.entry c t.k m f)))
        t m := by
  have go : ∀ {Ss : List Piece} {p : Nat} {ds : List (Option Val × Mem)} {t : Thread} {m : Mem}
      {f : Frame} {W : List Piece.Wait} {V : Valuation} {A : List Nat},
      Piece.ThroughTo c lbl rest K Ss (fun i => ds.getD i d₀) t m f → f.fn = fn → f.pc = p →
      Piece.walk fn lbl Ss p ds (Valuation.entry c t.k m f) = some (W, V, A) → F V = true →
      RunsVia c (Q V (A ++ f.allocas)) (W.map (Piece.Wait.via fn lbl) ++ G V) t m := by
    intro Ss
    induction Ss with
    | nil =>
      intro p ds t m f W V A h _ _ hw hF
      cases ds with
      | nil =>
        obtain ⟨rfl, h2⟩ := Prod.mk.inj (Option.some.inj hw)
        obtain ⟨rfl, rfl⟩ := Prod.mk.inj h2
        exact hK t m f h hF
      | cons => cases hw
    | cons P Ss ih =>
      intro p ds t m f W V A h hfn hp hw hF
      cases P with
      | coll S =>
        cases ds with
        | nil => cases hw
        | cons d ds =>
          simp only [Piece.walk] at hw
          split at hw
          · rename_i hds
            split at hw
            · rename_i xs me hx hm
              cases hr : Piece.walk fn lbl Ss (p + S.len + 1) ds
                  ((Valuation.entry c t.k m f).resume S.toSummary (resReg fn lbl (p + S.len))
                    d) with
              | none => rw [hr] at hw; cases hw
              | some r =>
                obtain ⟨W', V', A'⟩ := r
                rw [hr] at hw
                obtain ⟨rfl, h2⟩ := Prod.mk.inj (Option.some.inj hw)
                obtain ⟨rfl, rfl⟩ := Prod.mk.inj h2
                rw [List.map_cons, List.cons_append, List.append_assoc]
                refine RunsVia.of_wait (T := fun t' fr => Piece.ThroughTo c lbl rest K Ss
                  (fun i => ds.getD i d₀) t' d.2 fr) hfn hp (h hds) ?_ ?_
                · intro u me' xs' hat hm' hx'
                  exact ⟨hat, rfl, Except.ok.inj (hx'.symm.trans hx),
                    Except.ok.inj (hm'.symm.trans hm)⟩
                · intro fr t' _ hfr hpr hal hT hV
                  rw [← hal]
                  exact ih hT hfr hpr (by rw [hV]; exact hr) hF
            · cases hw
          · cases hw
      | life σ start x n =>
        simp only [Piece.walk] at hw
        split at hw
        · rename_i hds
          split at hw
          · rename_i me q hm hx
            split at hw
            · rename_i ho
              cases hr : Piece.walk fn lbl Ss (p + n + 1) ds
                  ((Valuation.entry c t.k m f).resume (σ.toSummary n) none
                    (none, me.setLive q.block start)) with
              | none => rw [hr] at hw; cases hw
              | some r =>
                obtain ⟨W', V', A'⟩ := r
                rw [hr] at hw
                obtain ⟨rfl, h2⟩ := Prod.mk.inj (Option.some.inj hw)
                obtain ⟨rfl, rfl⟩ := Prod.mk.inj h2
                obtain ⟨fe, me', v, hS, hfe, -, hpc, hal, -, hrg, hpr, hm', hx', hst⟩ := h hds
                obtain rfl : me' = me := Except.ok.inj (hm'.symm.trans hm)
                obtain rfl : v = .ptr q := Except.ok.inj (hx'.symm.trans hx)
                obtain ⟨hs, hT⟩ := hst _ (intrinsic_lifetime_ptr ho)
                rw [List.append_assoc, ← hal]
                exact RunsVia.of_steps (hS.trans_step hs (.refl _ _))
                  (ih (f := { fe with pc := fe.pc + 1 }) hT (hfe.trans hfn)
                    (by show fe.pc + 1 = _; rw [hpc, hp])
                    ((congrArg (Piece.walk fn lbl Ss (p + n + 1) ds)
                      (Valuation.entry_set (c := c) (k := t.k + n + 1)
                        (m := me'.setLive q.block start)
                        (g := (Valuation.entry c t.k m f).frameAtWith true 0 (σ.toSummary n)) hfe
                        hrg hpr none none (fe.pc + 1))).trans hr) hF)
            · cases hw
          · cases hw
        · cases hw
  intro Ss p ds t m f h hfn hp hF
  unfold Piece.fires at hF
  unfold Piece.waits Piece.after Piece.allocs
  cases hw : Piece.walk fn lbl Ss p ds (Valuation.entry c t.k m f) with
  | none => rw [hw] at hF; cases hF
  | some r =>
    obtain ⟨W, V, A⟩ := r
    rw [hw] at hF
    exact go h hfn hp hw hF

/-- **A thread through a sequence of loops into a continuation**, for every flag `alloca` and
`contract`, program, function `fn`, context `c` of the program, frames `rest`, block `d`,
position `q`, predicate `J` on valuations, list `Ls` of loops, path `(l, ds, S) :: E` before
them, position `p0`, final predicate `Q` and list `ws` of waits, when the chain checker accepts
the paths (`coversChainAt alloca contract`): take a thread `t` whose innermost frame `f` runs
`fn` above `rest` at block `l`'s position `p0`, on memory `m`, with
`ChainWith contract (BackWith contract d q J) Ls` at `f`'s entry valuation. If every thread
whose innermost frame `f'` runs `fn` above `rest` at block `d`'s position `q`, with some blocks
(none with the flag `alloca` off) in front of `f`'s `alloca` blocks and `J` at its entry
valuation, runs through `ws` (`RunsVia`), then so does `t`: the chain's last path out stops
after its last edge, into `d` at `q` (`ChainWith.enter`, then `RunsVia.of_steps`). -/
theorem RunsVia.of_chain {alloca contract : Bool} {P : Program} {fn : Func} {c : Ctx}
    (hP : c.prog = P) {rest : List Frame} {d q : Nat} {J : Valuation → Prop}
    {Ls : List LoopSeg} {p0 l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} {Q : Mem → Prop}
    {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
    (hc : coversChainAt alloca contract P fn p0 l ds S E Ls = true)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = f :: rest) (hfn : f.fn = fn)
    (hl : f.label = l) (hp : f.pc = p0)
    (h : ChainWith contract (BackWith contract d q J) Ls (Valuation.entry c t.k m f) l ds S E)
    (hK : ∀ t' m' f', t'.frames = f' :: rest → f'.fn = fn → f'.label = d → f'.pc = q →
      (∃ bs, f'.allocas = (bif alloca then bs else []) ++ f.allocas) →
      J (Valuation.entry c t'.k m' f') → RunsVia c Q ws t' m') :
    RunsVia c Q ws t m :=
  let ⟨_, _, _, hS, ht', hfn', hl', hp', ⟨bs, hal, _⟩, _, hJ⟩ :=
    ChainWith.enter hP hc ht hfn hl hp h
  RunsVia.of_steps hS (hK _ _ _ ht' hfn' hl' hp' ⟨bs, hal⟩ hJ)

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
