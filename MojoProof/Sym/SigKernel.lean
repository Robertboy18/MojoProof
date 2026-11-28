import MojoProof.Sym.SigOneRun
import MojoProof.Sym.Start
import MojoProof.Sem.Shared
import MojoProof.Sem.Writes
import MojoProof.Sem.Determinism
import MojoProof.Sem.Precond
import MojoProof.Sym.SegTrace
import MojoProof.Sym.ShflDeliver

/-!
# A kernel's soundness at `sig` from its start, its run and its trace

For every program, kernel, launch, arguments, memory, address choice, oracle and contexts, the
steps of a kernel's theorem that are the same for every kernel:
- **the start** (`Grid.start_of_check`): `Grid.start` returns a grid and contexts when the
  decidable `startCheck` passes (the kernel's check, its globals in address space 3 with no
  initializer or `undef`, each parameter's attributes among those that keep every word
  (`keepsBits`) and not `byval`, each argument defined and not a vector, a body), the launch
  passes the kernel's launch check (`Func.checkLaunch`) and the memory is closed for the
  arguments; at a concrete kernel `startCheck` is closed by `kernel_rfl` for every argument value
  whose definedness reduces;
- **the assembly** (`kernel_sound_sig`): a start at each admitted choice and one run from it to a
  done grid that is not bad and whose observation meets the rule give `GPUProof.Kernel.Sound sig`,
  by Theorem 0 at `sig` (`sound_sig`, `GPUProof.Sound.of_one_run`);
- **back to the grid** (`Grid.Sound.of_sig`, `Kernel.Sound.of_sig`): a state sound at `sig` is a
  sound grid, and a kernel sound at `sig` is sound (`Kernel.Sound`, MojoProof/Sem/Spec.lean) at
  the admission of the pair of an address choice and an oracle, for an observation that reads only
  the blocks;
- **not bad** (`Grid.not_bad`, `Grid.start_kept`, `Grid.not_bad_cells`): a done grid reachable
  from the start's with no race and the promise of `!invariant.load` kept is not bad
  (`Grid.Done.bad_iff`); the promise is kept when no `!invariant.load` access is to a block that a
  write touches; and a trace whose accesses to blocks of threads' blocks in phase 0 stay in one
  cell per thread (`racy_cells`) and are reads in later phases, and whose other accesses are owned
  (`Owned`), has no race;
- **owners** (`Grid.start_reach_ctaOf`, `Grid.start_reach_buffer`, `Mem.Buffer.ne`): the start's
  blocks of threads' blocks stay theirs, a caller's buffer is no block of threads', and a
  read-only buffer is not a writable one;
- **the trace** (`Ext.store`): the memory after a store, or the memory itself if the store fails,
  extends the trace by the store's write (`Ext`).

The instances are gemv_kernel's and gevm_kernel's theorems (MojoProofTest/GemvSound.lean,
MojoProofTest/GevmSound.lean), which use `Grid.start_of_check`, `kernel_sound_sig` and
`Grid.not_bad`, and gevm's `grid_bad`, which uses `Grid.not_bad_cells`;
MojoProofTest/Theorem0.lean, which uses `sound_sig` and `Grid.Sound.of_sig`;
MojoProofTest/GemvObs.lean, whose observations of gemv_kernel's and gevm_kernel's theorems use
`Kernel.Sound.of_sig`; and gemv's `ext_out` and gevm's
`Warp.mout_ext` (MojoProofTest/GevmWarp1.lean), which use `Ext.store`.
-/

namespace MojoProof.Sem

open LLVM Relation
open GPUProof (Path)

/-! ### The start -/

/-- `Grid.start_ok`'s premise on a global, as a check: address space 3, and no initializer and
not `constant`, or initialized with `undef`. -/
def _root_.MojoProof.LLVM.Global.shared (g : Global) : Bool :=
  g.addrSpace == 3 && match g.init with
    | none => !g.isConst
    | some .undef => true
    | some _ => false

/-- A global that passes `Global.shared` meets `Grid.start_ok`'s premise on it. -/
theorem _root_.MojoProof.LLVM.Global.shared_ok {g : Global} (h : g.shared = true) :
    g.addrSpace = 3 ∧ (g.init = none ∧ g.isConst = false ∨ g.init = some .undef) := by
  unfold Global.shared at h
  simp only [Bool.and_eq_true, beq_iff_eq] at h
  refine ⟨h.1, ?_⟩
  have h2 := h.2
  revert h2
  rcases g.init with _ | x
  · simp
  · cases x <;> simp

/-- A parameter and its argument that `Grid.start` takes as it is: each of the parameter's
attributes keeps every word (`Sym.keepsBits`: not `range`, `nonnull` or `align`) and is not
`byval`, and the argument is defined and not a vector. -/
def _root_.MojoProof.LLVM.Param.takes (p : Param) (v : Val) : Bool :=
  p.attrs.all (fun a => Sym.keepsBits a && !(a matches .ty "byval" _)) && v.defined &&
    !(v matches .vec _)

/-- The checks of `Grid.start_ok`'s premises other than the memory's: the kernel passes its check
(`Func.check`), every global passes `Global.shared`, every parameter takes its argument
(`Param.takes`, the pairs of `List.zip`) and the kernel has a body. -/
def startCheck (prog : Program) (fn : Func) (args : List Val) : Bool :=
  (fn.check prog.module).toBool && prog.module.globals.toList.all Global.shared &&
    (fn.params.zip args).all (fun pv => pv.1.takes pv.2) && decide (0 < fn.blocks.size)

end MojoProof.Sem

namespace MojoProof.Sym

open LLVM Sem

/-- **The launch starts, from checks**: for every program, kernel `fn`, launch, arguments,
memory closed for them (`Mem.Closed`), address choice and oracle, if `startCheck` passes and the
launch passes the kernel's launch check (`Func.checkLaunch`: one argument per parameter, and the
block within the kernel's `nvvm.maxntid` or `nvvm.reqntid`), `Grid.start` returns a grid and
contexts. `Grid.start_ok`. -/
theorem Grid.start_of_check {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    (ch : Nat → Nat) (oracle : Nat → Nat → Nat) (hC : m.Closed args)
    (hl : fn.checkLaunch prog.module L.block args.length = .ok ())
    (hk : startCheck prog fn args = true) :
    ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c) := by
  simp only [startCheck, Bool.and_eq_true] at hk
  obtain ⟨⟨⟨hf, hg⟩, hp⟩, hb⟩ := hk
  have hp' : ∀ p v, (p, v) ∈ fn.params.zip args →
      p.attrs.all (fun a => keepsBits a && !(a matches .ty "byval" _)) = true ∧
        v.defined = true ∧ (v matches .vec _) = false := fun p v h => by
    have := List.all_eq_true.1 hp _ h
    simpa only [Param.takes, Bool.and_eq_true, Bool.not_eq_true', and_assoc] using this
  refine Sym.Grid.start_ok ch oracle ?_ hl hC
    (fun g h => Global.shared_ok (List.all_eq_true.1 hg g h))
    (fun p v h t ht => absurd (List.all_eq_true.1 (hp' p v h).1 _ ht) (by simp [keepsBits]))
    (fun p v h _ _ => ⟨v, withAttrs_keepsBits _ _ _ (List.all_eq_true.2 fun a ha =>
      ((Bool.and_eq_true _ _).mp (List.all_eq_true.1 (hp' p v h).1 a ha)).1) (hp' p v h).2.2
      (hp' p v h).2.1⟩)
    (of_decide_eq_true hb)
    (Func.byvalPlaced_of_none fun p v h t ht =>
      absurd (List.all_eq_true.1 (hp' p v h).1 _ ht) (by simp [keepsBits]))
  revert hf
  cases fn.check prog.module <;> simp [Except.toBool]

end MojoProof.Sym

namespace MojoProof.Sem

open LLVM Relation
open GPUProof (Path)

/-! ### Theorem 0 at `sig` -/

/-- **Theorem 0 at `sig` from a grid's run**, for every program, kernel, launch, arguments,
memory every pointer byte of whose blocks names a number below `next` or with a block, address
choice, oracle and observation that reads only the blocks: one run of `n` steps from the start's
grid to a grid `z` in which every thread has returned, that is not bad and whose observation is
`y` with `R y`, makes the start's state `(g₀, L, c)` sound at `sig` (`GPUProof.Sound`) for the
observation of its blocks. -/
theorem sound_sig {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) (hm : m.BytesIn m.Known)
    {β : Type} {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    {n : Nat} {z : Grid} (run : Path (Grid.Step L c) n g₀ z) (hz : GPUProof.Done sig (z, L, c))
    (hb : ¬ GPUProof.Bad sig (z, L, c))
    {y : β} (hy : obs z.mem = some y) (hR : R y) :
    GPUProof.Sound sig (g₀, L, c) (fun b => obs { blocks := b }) R := by
  have hs : sig.start (prog, fn) L args m (ch, oracle) = .ok (g₀, L, c) := by
    show (Grid.start prog fn L args m ch oracle).map _ = _
    rw [h]
    rfl
  have lift : ∀ {k a b}, Path (Grid.Step L c) k a b →
      Path (GPUProof.Step sig) k (a, L, c) (b, L, c) := by
    intro k a b hp
    induction hp with
    | nil => exact .nil _
    | cons hs' _ ih => exact .cons (sig_step_iff.2 ⟨_, rfl, hs'⟩) ih
  exact GPUProof.Sound.of_one_run hs hm (lift run) hz hb ((sig_obs hO (z, L, c)).symm.trans hy)
    hR

/-- **A kernel is sound at `sig` from one run at each admitted choice**, for every program,
kernel, launch, arguments, memory every pointer byte of whose blocks names a number below `next`
or with a block, admission, observation that reads only the blocks and rule: if the launch starts
at each admitted address choice and oracle, and from each such start one run reaches a grid in
which every thread has returned, that is not bad and whose observation meets the rule, the kernel
is sound at `sig` (`GPUProof.Kernel.Sound`). `sound_sig` at each start. -/
theorem kernel_sound_sig {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    (hm : m.BytesIn m.Known) {adm : (Nat → Nat) × (Nat → Nat → Nat) → Prop} {β : Type}
    {obs : Mem → Option β} {R : β → Prop}
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (hs : ∀ ω, adm ω → ∃ g₀ c, Grid.start prog fn L args m ω.1 ω.2 = .ok (g₀, c))
    (hr : ∀ ω g₀ c, adm ω → Grid.start prog fn L args m ω.1 ω.2 = .ok (g₀, c) →
      ∃ z, ReflTransGen (Grid.Step L c) g₀ z ∧ GPUProof.Done sig (z, L, c) ∧
        ¬ GPUProof.Bad sig (z, L, c) ∧ ∃ y, obs z.mem = some y ∧ R y) :
    GPUProof.Kernel.Sound sig (prog, fn) L args m adm (fun b => obs { blocks := b }) R := by
  intro ω hω
  obtain ⟨g₀, c, h⟩ := hs ω hω
  obtain ⟨z, hz, hd, hb, y, hy, hR⟩ := hr ω g₀ c hω h
  obtain ⟨_, run⟩ := Path.exists_iff.2 hz
  refine ⟨(g₀, L, c), ?_, sound_sig h hm hO run hd hb hy hR⟩
  show (Grid.start prog fn L args m ω.1 ω.2).map _ = _
  rw [h]
  rfl

/-! ### From soundness at `sig` back to the grid -/

/-- **A state sound at `sig` is a sound grid**, for every launch, contexts, grid, observation that
reads only the blocks and relation: if the state `(g₀, L, c)` is sound at `sig`
(`GPUProof.Sound`) for the observation of its blocks, the grid `g₀` is sound (`Grid.Sound`): its
five run fields by `Grid.Sound.of_clean` (the reachable states by `sig_reach_iff`), its
observations by `sig_obs`, the core's `Option.Rel Eq` of two observations their equality. -/
theorem Grid.Sound.of_sig {L : Launch} {g₀ : Grid} {c : Nat → Ctx} {β : Type}
    {obs : Mem → Option β} {R : β → Prop} (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (hS : GPUProof.Sound sig (g₀, L, c) (fun b => obs { blocks := b }) R) :
    Grid.Sound L c g₀ obs R := by
  have up : ∀ {g}, ReflTransGen (Grid.Step L c) g₀ g → GPUProof.Reach sig (g₀, L, c) (g, L, c) :=
    fun hg => sig_reach_iff.2 ⟨_, rfl, hg⟩
  have orel : ∀ {a b : Option β}, Option.Rel Eq a b → a = b := by
    intro a b h
    cases h with
    | some e => rw [e]
    | none => rfl
  refine Grid.Sound.of_clean hS.toClean (fun g g' hg hg' hd hd' => ?_) fun g hg hd => ?_
  · exact ((sig_obs hO (g, L, c)).trans
      (orel (hS.determinate _ _ (up hg) (up hg') hd hd'))).trans (sig_obs hO (g', L, c)).symm
  · obtain ⟨y', hy', hR'⟩ := hS.post _ (up hg) hd
    exact ⟨y', (sig_obs hO (g, L, c)).trans hy', hR'⟩

/-- **A kernel sound at `sig` is sound**, for every program, kernel, launch, arguments, memory,
admission `adm` of pairs of an address choice and an oracle family, observation `obs` that reads
only the blocks and relation `R`: if the kernel is sound at `sig` (`GPUProof.Kernel.Sound`) for
`adm` and the observation `obs` of the blocks, it is sound (`Kernel.Sound`) for the admission of
the pair `(ch, oracle)` by `adm`, `obs` and `R`. At each admitted pair the start at `sig` is the
grid's start with the launch and contexts (`sig.start`), and its state's soundness is the grid's
(`Grid.Sound.of_sig`). The program, kernel, launch, arguments, memory, admission and relation of
the premise are the conclusion's. -/
theorem Kernel.Sound.of_sig {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {adm : (Nat → Nat) × (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
    {R : β → Prop} (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (h : GPUProof.Kernel.Sound sig (prog, fn) L args m adm (fun b => obs { blocks := b }) R) :
    Kernel.Sound prog fn L args m (fun ch oracle => adm (ch, oracle)) obs R := by
  intro ch oracle ha
  obtain ⟨s₀, hs, hS⟩ := h (ch, oracle) ha
  have hs' : (Grid.start prog fn L args m ch oracle).map (fun gc => (gc.1, L, gc.2)) = .ok s₀ :=
    hs
  cases hg : Grid.start prog fn L args m ch oracle with
  | error e =>
    rw [hg] at hs'
    cases hs'
  | ok gc =>
    obtain ⟨g, c⟩ := gc
    rw [hg] at hs'
    simp only [Except.map, Except.ok.injEq] at hs'
    subst hs'
    exact ⟨g, c, rfl, Grid.Sound.of_sig hO hS⟩

/-! ### Not bad -/

/-- **A done grid with no race and the promise kept is not bad**, for every program, kernel,
launch, arguments, memory, address choice, oracle and grid `z` reachable from the start's:
`Grid.Done.bad_iff`. -/
theorem Grid.not_bad {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) {z : Grid}
    (hz : ReflTransGen (Grid.Step L c) g₀ z) (hd : GPUProof.Done sig (z, L, c))
    (hr : GPUProof.racy sig (z.mem.trace.map (Event.toCore L)).reverse = false)
    (hk : GPUProof.kept sig (z.mem.trace.map (Event.toCore L)).reverse = true) :
    ¬ GPUProof.Bad sig (z, L, c) := fun hb => by
  rw [Grid.Done.bad_iff (Grid.start_reach_size h hz).le hd, hr, hk] at hb
  simp at hb

/-- **The promise of `!invariant.load` is kept on a run** if no access with `!invariant.load` is
to a block that a write of the trace touches, for every program, kernel, launch, arguments,
memory, address choice, oracle and grid `z` reachable from the start's: `kept_of_split` with
`Trace.Shaped.writes` (`Grid.start_reach_shaped`). -/
theorem Grid.start_kept {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) {z : Grid}
    (hz : ReflTransGen (Grid.Step L c) g₀ z)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block) :
    GPUProof.kept sig (z.mem.trace.map (Event.toCore L)).reverse = true :=
  have hsh := (Grid.start_reach_shaped h hz 0).1
  kept_of_split (W := fun b => ∃ e, Event.access e ∈ z.mem.trace ∧ e.write = true ∧ e.ptr.block = b)
    (fun a ha hi ⟨e, he, hw, hb⟩ => hI a e ha he hi hw hb.symm)
    fun e he hw => let ⟨e', he', hw', hp⟩ := hsh.writes he hw; ⟨e', he', hw', by rw [hp]⟩

/-- **A done grid whose block-shared accesses stay in one cell per thread before the first
barrier and read after it, whose other accesses are owned and whose promise is kept, is not
bad**, for every program, kernel, launch, arguments, memory, address choice, oracle, grid `z`
reachable from the start's, cell width `w`, cell map `cell` one-to-one on the threads of a block
and owner map `G`: each access of phase 0 to a block of threads' block (`Mem.ctaOf`) lies in
cell `cell (thread % volume L.block)` of `w` bytes, each later access to one is a read, each
access to another block is owned (`Owned G id`), and no `!invariant.load` access is to a block a
write touches. `racy_cells`, `Grid.start_kept` and `Grid.not_bad`. -/
theorem Grid.not_bad_cells {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) {z : Grid}
    (hz : ReflTransGen (Grid.Step L c) g₀ z) (hd : GPUProof.Done sig (z, L, c))
    {w : Nat} {cell : Nat → Nat} (hv : 0 < volume L.block)
    (hc : ∀ i < volume L.block, ∀ j < volume L.block, cell i = cell j → i = j)
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases z.mem.trace).1, ∀ b, z.mem.ctaOf x.1.ptr.block = some b →
      (x.2 = 0 → ((cell (x.1.who.thread % volume L.block) * w : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((cell (x.1.who.thread % volume L.block) * w + w : Nat) : Int)) ∧
      (x.2 ≠ 0 → x.1.write = false))
    (hG : ∀ x ∈ (phases z.mem.trace).1, z.mem.ctaOf x.1.ptr.block = none → Owned G id x.1)
    (hI : ∀ a e, Event.access a ∈ z.mem.trace → Event.access e ∈ z.mem.trace →
      a.invariant = true → e.write = true → a.ptr.block ≠ e.ptr.block) :
    ¬ GPUProof.Bad sig (z, L, c) :=
  have hf := Grid.start_reach_fits h hz
  Grid.not_bad h hz hd (racy_cells hf.trace hf.2 hv hc (ofSh := z.mem.ctaOf)
    (fun x hx b e => by
      obtain ⟨hk, hb⟩ := Grid.start_reach_cta h hz _ (mem_phases hx)
      exact ⟨hb b e, by rw [← hk, hb b e], hS x hx b e⟩) hG) (Grid.start_kept h hz hI)

/-! ### Owners -/

/-- A block of threads' block at the start is that block of threads' on every run. -/
theorem Grid.start_reach_ctaOf {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) {z : Grid}
    (hz : ReflTransGen (Grid.Step L c) g₀ z) {b β : Nat} (hb : g₀.mem.ctaOf b = some β) :
    z.mem.ctaOf b = some β := by
  unfold Mem.ctaOf at hb ⊢
  cases hq : g₀.mem.blocks b with
  | none => rw [hq] at hb; cases hb
  | some x =>
    rw [hq] at hb
    obtain ⟨x', hx', ho', -⟩ := Grid.start_reach_above h hz hq fun w hw => by simp [hw] at hb
    rw [hx', Option.bind_some, ho']
    exact hb

/-- A caller's buffer is no block of threads' on every run. -/
theorem Grid.start_reach_buffer {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g₀ : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g₀, c)) {z : Grid}
    (hz : ReflTransGen (Grid.Step L c) g₀ z) {q s al : Nat} {w : Bool} (hq : m.Buffer q s al w) :
    z.mem.ctaOf q = none := by
  obtain ⟨x, hx, -, -, ho, -⟩ := hq
  obtain ⟨x', hx', ho', -⟩ := Grid.start_reach_above h hz (Grid.start_blocks h hx)
    fun w' e => by rw [ho] at e; cases e
  simp only [Mem.ctaOf, hx', Option.bind_some, ho', ho]

/-- A read-only buffer is not a writable one, for every memory, blocks, sizes and alignments. -/
theorem Mem.Buffer.ne {m : Mem} {q p s s' al al' : Nat} (hq : m.Buffer q s al false)
    (hp : m.Buffer p s' al' true) : q ≠ p := by
  intro e
  obtain ⟨x, hx, -, -, -, h1, -⟩ := hq
  obtain ⟨y, hy, -, -, -, h2, -⟩ := hp
  rw [e, hy] at hx
  cases hx
  rw [h1] at h2
  cases h2

end MojoProof.Sem

namespace MojoProof.Sym

open LLVM Sem

/-! ### The trace -/

/-- **A store, or the memory if it fails, extends the trace by the store's write**, for every
property `P` of events, layout, thread, memory, address space, type, value, pointer and
alignment: if the store's write access (`l.stored t` bytes at `p`, not atomic) is of `P`, the
memory after the store extends the memory's trace by events of `P` (`Mem.store_trace`). -/
theorem Ext.store {P : Event → Prop} {l : Layout} {w : Who} {m : Mem} {a : Nat} {t : Ty}
    {v : Val} {p : Ptr} {al : Option Nat} (hP : P (.access ⟨w, p, l.stored t, true, none, false⟩)) :
    Ext P m (match m.store l w a t v p al with
      | .ok m' => m'
      | .error _ => m) := by
  split
  · exact ⟨[_], Mem.store_trace ‹_›, fun e he => List.mem_singleton.1 he ▸ hP⟩
  · exact .refl _ _

end MojoProof.Sym
