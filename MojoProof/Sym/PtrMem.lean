import MojoProof.Sym.Payload
import MojoProof.Sym.Sched

/-!
# The memory premises of a path from the labelling's memory hypothesis

The memory premises of the two-run theorem along a path (`Valuation.PathMem`, the premise `hm` of
`Block.sound_retI_rel`, MojoProof/Sym/Payload.lean: on each block, `Valuation.LoadsOk` and
`Valuation.StoresOk` of its summary, which read the summary's pointer terms) from the labelling's
memory hypothesis (`Labels.MemOk` and `Labels.MemNext`, MojoProof/Sem/Labels.lean, which read the
statements' pointer operands in the thread's scope), through the pointer facts that the block
checker proves (`Ptrs`, MojoProof/Sym/Block.lean). For every program, labelling, payload blocks
and path the checkers accept.

* `Ptrs.loadsOk`: for every labelling `lab`, payload blocks `pay`, context, thread `t` on memory
  `m` and block with entry valuation `V` and summary `S` whose pointer facts hold (`Ptrs`), if
  every state the thread's steps reach meets `Labels.MemNext`, each `load` node of `S`'s table
  whose result register `lab` does not label payload reads outside `pay` (`Valuation.LoadsOk`).
* `Ptrs.storesOk`: under the same premises, if `S`'s register entries agree with `lab`
  (`Summary.agrees`), each `store` effect of `S` whose stored term is payload writes into `pay`
  (`Valuation.StoresOk`): the statement's stored operand mentions a payload register
  (`StoreVal.mentions`).
* `Valuation.pathMem_of_ptrs`: from every valuation, on a path whose summaries pass the path
  checks (`pathOk`) and the pointer facts of whose blocks hold from the thread, `Labels.MemNext`
  at every state the thread's steps reach gives `Valuation.PathMem`.
* `Block.sound_pathMem`: for every program and path that the path checker with `phi`s
  (`coversPathI`) and `pathOk` accept, every context of the program and thread at the path's first
  block whose premises hold (`WalkI`), `Labels.MemNext` at every state the thread's steps reach
  gives `Valuation.PathMem` from the thread's entry valuation (`Block.sound_pathI_ptrs`).
* `Labels.MemOk.steps`: `Labels.MemOk` gives `Labels.MemNext` at every state that the steps of a
  running thread of a reachable grid reach (`Steps.grid`), so `Block.sound_pathMem` applies to
  each running thread of each grid a launch reaches.

Tests (MojoProofTest/SymRun.lean): `store_pathMem` (the chain from `Labels.MemOk` on a launch
of `kernel #[store01]` to `Valuation.PathMem` of its block, through `Ptrs.storesOk`, with its
twin) and `vadd21_memNext_twin` (`Ptrs.loadsOk`).
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- A stored operand `w` that the payload term `x` describes with register entries `regs`
(`StoreVal`) mentions a payload register, when every entry of `regs` to a payload term is of a
payload register. -/
theorem StoreVal.mentions {lab : Labels} {fn : Func} {ps : List Bool}
    {regs : List (Nat × SVal)} {x : SVal} {w : Value} (h : StoreVal regs x w)
    (hx : x.pay lab fn ps = true)
    (ha : ∀ r y, (r, y) ∈ regs → y.pay lab fn ps = true → lab.reg fn.name r = true) :
    w.mentions (lab.reg fn.name) = true := by
  unfold StoreVal at h
  split at h
  · rename_i r
    simp only [Value.mentions]
    rcases h with rfl | hr
    · exact hx
    · exact ha r x hr hx
  · obtain ⟨n, i, rfl⟩ := h
    simp [SVal.pay] at hx

/-- **`Labels.MemNext` gives `Valuation.LoadsOk`**: for every labelling `lab`, payload
blocks `pay`, context, thread `t` on memory `m` and block with entry valuation `V` and summary
`S` whose pointer facts hold (`Ptrs`, from `Block.sound_ptrs` or along a path from
`Block.sound_path_ptrs` and `Block.sound_pathI_ptrs`), if every state the thread's steps reach
meets `Labels.MemNext`, each `load` node of `S`'s table whose result register `lab` does not label
payload reads outside `pay`. For every valuation and summary whose pointer facts hold, which
`Block.sound_ptrs` gives for every block the checker accepts. -/
theorem Ptrs.loadsOk {lab : Labels} {pay : Nat → Prop} {c : Ctx} {t : Thread} {m : Mem}
    {rest : List Frame} {V : Valuation} {lbl : Nat} {S : Summary}
    (hQ : Ptrs c t m rest (V, lbl, S))
    (hM : ∀ t' m', Steps c t m t' m' → lab.MemNext pay c m' t') : V.LoadsOk lab pay S.nodes := by
  intro j l pc p q hn hres hp
  obtain ⟨f, k, m', b, st, hS, hfn, hl, hpc, hb, hst, a, q', vol, ty, al, hi, he⟩ :=
    hQ.1 j l pc p hn
  have h := hM _ _ hS f rest b st rfl (by rw [hfn, hl]; exact hb) (by rw [hpc]; exact hst)
  have hr : resReg V.fn l pc = st.res := by
    unfold resReg
    rw [hb]
    show (b.stmts[pc]?).bind (·.res) = _
    rw [hst]
    rfl
  rw [Labels.MemAt, hi] at h
  exact h (by rw [hfn, ← hr]; exact hres) q (he.trans hp)

/-- **`Labels.MemNext` gives `Valuation.StoresOk`**: for every labelling `lab`, payload
blocks `pay`, context, thread `t` on memory `m` and block with entry valuation `V` and summary
`S` whose pointer facts hold (`Ptrs`) and whose register entries agree with `lab`
(`Summary.agrees`), if every state the thread's steps reach meets `Labels.MemNext`, each `store`
effect of `S` whose stored term is payload (`SVal.pay`) writes into `pay`: the statement's stored
operand mentions a payload register (`StoreVal.mentions`), so `Labels.MemAt` puts its pointer
into `pay`. For every valuation and summary whose pointer facts hold, which `Block.sound_ptrs`
gives for every block the checker accepts. -/
theorem Ptrs.storesOk {lab : Labels} {pay : Nat → Prop} {c : Ctx} {t : Thread} {m : Mem}
    {rest : List Frame} {V : Valuation} {lbl : Nat} {S : Summary}
    (hQ : Ptrs c t m rest (V, lbl, S)) (ha : S.agrees lab V.fn = true)
    (hM : ∀ t' m', Steps c t m t' m' → lab.MemNext pay c m' t') : V.StoresOk lab pay S := by
  intro l pc v p q hm hv hp
  obtain ⟨⟨f, k, m', b, st, hS, hfn, hl, hpc, hb, hst, a, q', vol, w', al, hi, he⟩,
    b', st', vol', ty, w, ptr, al', hb', hst', hi', hw⟩ := hQ.2 l pc v p hm
  obtain rfl : b = b' := Option.some.inj (hb.symm.trans hb')
  obtain rfl : st = st' := Option.some.inj (hst.symm.trans hst')
  obtain ⟨-, rfl, -, -⟩ := Inst.store.inj (hi.symm.trans hi')
  have h := hM _ _ hS f rest b st rfl (by rw [hfn, hl]; exact hb) (by rw [hpc]; exact hst)
  rw [Labels.MemAt, hi] at h
  have hag : ∀ r y, (r, y) ∈ S.regs → y.pay lab V.fn (roles lab V.fn S.nodes) = true →
      lab.reg V.fn.name r = true := by
    intro r y hr hy
    simpa [hy] using List.all_eq_true.1 ha _ hr
  refine h ?_ q (he.trans hp)
  simp only [TValue.mentions, hfn]
  exact StoreVal.mentions hw hv hag

/-- **The memory premises along a path from `Labels.MemNext`**: for every labelling `lab`,
payload blocks `pay`, context, thread `t` on memory `m` and path `(l, S) :: ps` from valuation
`V` whose summaries pass the path checks (`pathOk`) and the pointer facts of whose blocks hold
(`Ptrs`, at each block's entry valuation `Valuation.blocksI`), if every state the thread's steps
reach meets `Labels.MemNext`, the memory premises of two runs along the path hold
(`Valuation.PathMem`: `Ptrs.loadsOk` and `Ptrs.storesOk` at each block). -/
theorem Valuation.pathMem_of_ptrs {lab : Labels} {pay : Nat → Prop} {c : Ctx} {t : Thread}
    {m : Mem} {rest : List Frame} (hM : ∀ t' m', Steps c t m t' m' → lab.MemNext pay c m' t') :
    ∀ (ps : List (Nat × List Cond × Summary)) {V : Valuation} {l : Nat} {S : Summary},
      pathOk lab V.fn l S ps = true → (∀ q ∈ V.blocksI l S ps, Ptrs c t m rest q) →
      V.PathMem lab pay l S ps
  | [], V, l, S, hk, hQ => by
    have hq := hQ _ (List.mem_singleton_self _)
    simp only [pathOk, Summary.agreesI, Bool.and_eq_true] at hk
    exact ⟨Ptrs.loadsOk hq hM, Ptrs.storesOk hq hk.1.2.1 hM⟩
  | (l', _, S') :: ps, V, l, S, hk, hQ => by
    have hq := hQ _ (List.mem_cons_self ..)
    simp only [pathOk, Summary.agreesI, Bool.and_eq_true] at hk
    refine ⟨⟨Ptrs.loadsOk hq hM, Ptrs.storesOk hq hk.1.1.2.1 hM⟩,
      Valuation.pathMem_of_ptrs hM ps (by rw [(V.into_k l S).2.1]; exact hk.2)
        fun q hm => hQ q (List.mem_cons_of_mem _ hm)⟩

/-- **The memory premises of a path the checkers accept**: for every program, function,
labelling `lab`, payload blocks `pay` and path `(l, ds, S) :: ps` that the path checker with
`phi`s accepts (`coversPathI`, the first block from position `p0`) and whose summaries pass the
path checks (`pathOk`), every context of the program and thread whose innermost frame `f` is at
block `l`'s position `p0`, with memory `m`, whose path premises hold from the entry valuation
(`WalkI`): if every state the thread's steps reach meets `Labels.MemNext`, the memory premises of
two runs along the path hold from the entry valuation (`Valuation.PathMem`), the premise `hm` of
`Block.sound_retI_rel` (`Block.sound_pathI_ptrs`, `Valuation.pathMem_of_ptrs`). -/
theorem Block.sound_pathMem {P : Program} {fn : Func} {lab : Labels} {pay : Nat → Prop}
    {c : Ctx} (hP : c.prog = P) {rest : List Frame} {ps : List (Nat × List Cond × Summary)}
    {l p0 : Nat} {ds : List Cond} {S : Summary} {t : Thread} {m : Mem} {f : Frame}
    (hc : coversPathI P fn p0 ((l, ds, S) :: ps) = true) (hk : pathOk lab fn l S ps = true)
    (ht : t.frames = f :: rest) (hfn : f.fn = fn) (hl : f.label = l) (hp : f.pc = p0)
    (hW : WalkI (Valuation.entry c t.k m f) ((l, ds, S) :: ps))
    (hM : ∀ t' m', Steps c t m t' m' → lab.MemNext pay c m' t') :
    (Valuation.entry c t.k m f).PathMem lab pay l S ps :=
  Valuation.pathMem_of_ptrs hM ps
    (by rw [show (Valuation.entry c t.k m f).fn = fn from hfn]; exact hk)
    (Block.sound_pathI_ptrs hP ps hc ht hfn hl hp hW).2

/-- **`Labels.MemOk` gives `Labels.MemNext` along a thread's steps**: for every labelling
`lab`, payload blocks `pay`, launch `L`, contexts `c` and grid `g₀` that meets `Labels.MemOk`,
every grid `g` that `g₀` reaches and running thread `t` of `g` at index `n`: every state that `t`'s
steps from `g`'s memory reach meets `Labels.MemNext` (`Steps.grid`: the grid with that state at
index `n` is reachable). -/
theorem _root_.MojoProof.Sem.Labels.MemOk.steps {lab : Labels} {pay : Nat → Prop} {L : Launch}
    {c : Nat → Ctx} {g₀ g : Grid} (h : lab.MemOk pay L c g₀)
    (hg : Relation.ReflTransGen (Grid.Step L c) g₀ g) {n : Nat} {t : Thread}
    (ht : g.threads[n]? = some (.run t)) {t' : Thread} {m' : Mem}
    (hS : Steps (c n) t g.mem t' m') : lab.MemNext pay (c n) m' t' := by
  obtain ⟨k, hp⟩ := Steps.grid (L := L) hS ht rfl
  exact h _ (hg.trans (Path.exists_iff.1 ⟨k, hp⟩)) n t'
    (by rw [Array.set!_eq_setIfInBounds,
      Array.getElem?_setIfInBounds_self_of_lt (Array.getElem?_eq_some_iff.1 ht).1])

end MojoProof.Sym
