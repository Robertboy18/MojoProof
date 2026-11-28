import MojoProof.Sym.Slot
import MojoProof.Sym.WaitVia

/-!
# The blocks a sequence of lanes keeps, and a run's final memory

The facts a warp's run needs about its lanes run in turn, each changing only its own blocks:

* `Mem.SameOff.chain`: memories `mm a`, `mm (a + 1)`, ..., each with its predecessor's blocks
  outside a set `T i`, have `mm a`'s blocks outside the sets' union;
* `Mem.Buffer.of_store`, `Mem.Fits.of_store`: a store into a buffer keeps it a buffer, and
  fitting (a store changes only the block's bytes, `Mem.store_blocks_self`);
* `RunsVia.final`: a run through waits has a final memory that meets its final predicate.

And the facts a warp's premises need about the grid's start (`Grid.start`): its memory has no
block from `next` on if the caller's has none and the globals are as `Grid.start_ok` asks
(`Grid.start_free`, through `launchArgs_free`), and thread `n`'s `alloca` addresses are the
address choices `ch (Nat.pair 1 (Nat.pair n j))` (`Grid.start_addr`).

For every program, context, thread, memories and sets of block numbers.
-/

namespace MojoProof.Sem
open MojoProof.LLVM

/-- **The blocks a sequence of memories keeps**: for every memories `mm`, sets `T`, start `a`
and count `d`: if each `mm (i + 1)` from `i = a` on has `mm i`'s blocks outside `T i`, then
`mm (a + d)` has `mm a`'s blocks outside the union of `T i` for `a ≤ i < a + d`. -/
theorem Mem.SameOff.chain {mm : Nat → Mem} {T : Nat → Nat → Prop} (a : Nat)
    (h : ∀ i, a ≤ i → (mm i).SameOff (T i) (mm (i + 1))) :
    ∀ d, (mm a).SameOff (fun q => ∃ i, a ≤ i ∧ i < a + d ∧ T i q) (mm (a + d))
  | 0 => fun _ _ => rfl
  | d + 1 => ((Mem.SameOff.chain a h d).mono fun _ ⟨i, h1, h2, hT⟩ => ⟨i, h1, by omega, hT⟩).trans
      ((h (a + d) (by omega)).mono fun _ hT => ⟨a + d, by omega, by omega, hT⟩)

/-- **A store keeps a buffer**: for every layout, memories `m`, `m'`, thread, space, type, value,
pointer `p`, alignment and operation with `m'` the store's memory, and every size, alignment and
writability: a buffer at `p`'s block in `m` (`Mem.Buffer`) is one in `m'`. -/
theorem Mem.Buffer.of_store {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    {size al' : Nat} {wr : Bool} (hb : m.Buffer p.block size al' wr) :
    m'.Buffer p.block size al' wr := by
  obtain ⟨B, bs, h1, h2⟩ := Mem.store_blocks_self h
  obtain ⟨blk, hb, hP⟩ := hb
  rw [h1] at hb
  cases hb
  exact ⟨_, h2, hP⟩

/-- **A store keeps a block fitting**: for every layouts `l`, `l'`, memories `m`, `m'`, thread,
space, type, value, pointer `p`, alignment and operation with `m'` the store's memory, and every
size: if `p`'s block fits in `m` (`Mem.Fits`), it fits in `m'`. -/
theorem Mem.Fits.of_store {l l' : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    {size : Nat} (hf : m.Fits l' p.block size) : m'.Fits l' p.block size := by
  obtain ⟨B, bs, h1, h2⟩ := Mem.store_blocks_self h
  obtain ⟨blk, hb, hP⟩ := hf
  rw [h1] at hb
  cases hb
  exact ⟨_, h2, hP⟩

end MojoProof.Sem

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **A run has a final memory**: for every context `c`, final predicate `Q`, waits `ws`, thread
`t` and memory `m`: if `t` runs from `m` through `ws` to its end with `Q` (`RunsVia`), some memory
meets `Q`. -/
theorem RunsVia.final {c : Ctx} {Q : Mem → Prop} :
    ∀ {ws : List ((Thread → Intrinsic → List Val → Mem → Prop) × (Option Val × Mem))}
      {t : Thread} {m : Mem}, RunsVia c Q ws t m → ∃ m', Q m'
  | [], _, _, h => by
    obtain ⟨m', -, hq⟩ := h
    exact ⟨m', hq⟩
  | (_, _) :: _, _, _, h => by
    obtain ⟨_, _, _, _, _, _, _, hr⟩ := h
    exact RunsVia.final hr

/-- **The arguments keep `Mem.FreeAbove`.** For every layout, memory `m` with `Mem.FreeAbove`,
thread number, kernel, argument values and address choice: if `launchArgs` returns `r`, its
memory has `Mem.FreeAbove` (each `byval` copy is a launch allocation, `allocNext_res`, and the
other arguments do not change the memory). -/
theorem launchArgs_free {l : Layout} {m : Mem} {n : Nat} {fn : Func} {args : List Val}
    {ch : Nat → Nat} {r : Mem × List Val} (hx : launchArgs l m n fn args ch = .ok r)
    (h : m.FreeAbove) : r.1.FreeAbove := by
  unfold launchArgs at hx
  split at hx
  swap
  · cases hx
  refine foldlM_idx_inv (P := fun _ (r : Mem × List Val) => r.1.FreeAbove) _
    (fun _ pvi b b' _ hy hb => ?_) hx h
  obtain ⟨m1, acc⟩ := b
  obtain ⟨⟨p, v⟩, i⟩ := pvi
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hy
  split at hy
  · split at hy
    · split at hy
      · cases hy
      · rename_i w hw
        obtain ⟨r, hr, hA⟩ := allocNext_res hb hw
        cases hr
        cases hy
        exact hA
    · cases hy
  · split at hy
    · cases hy
    · cases hy
      exact hb

/-- **The start's memory has no block from `next` on.** For every program, kernel, launch,
argument values, memory `m` with `Mem.FreeAbove`, address choice and oracle whose start gives
`(g, c)`, if every global is in address space 3 and either has no initializer and is not
`constant` or is initialized with `undef` (as in `Grid.start_ok`): `g`'s memory has
`Mem.FreeAbove` (`sharedFold_res`, `launchArgs_free`). -/
theorem Grid.start_free {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hg : ∀ g ∈ prog.module.globals.toList,
      g.addrSpace = 3 ∧ (g.init = none ∧ g.isConst = false ∨ g.init = some .undef))
    (hm : m.FreeAbove) : g.mem.FreeAbove := by
  unfold Grid.start at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  rename_i v1 h1
  obtain ⟨r1, hr1, hA1⟩ := sharedFold_res hg _ _ hm h1
  cases hr1
  split at h
  · cases h
  rename_i v2 h2
  cases h
  have := foldlM_idx_inv (P := fun _ (r : Mem × Array Status) => r.1.FreeAbove) _
    (fun _ _ b b' _ hy hb => ?_) h2 hA1
  · exact this
  obtain ⟨m1, ts⟩ := b
  simp only [pure, Except.pure] at hy
  split at hy
  · cases hy
  rename_i v hv
  split at hy
  · cases hy
  cases hy
  exact launchArgs_free hv hb

/-- **The start's `alloca` addresses.** For every program, kernel, launch, argument values,
memory, address choice `ch` and oracle whose start gives `(g, c)`, and every thread number `n`:
thread `n`'s context takes its `alloca` addresses from `ch (Nat.pair 1 (Nat.pair n j))`. -/
theorem Grid.start_addr {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (n : Nat) :
    (c n).addr = fun j => ch (Nat.pair 1 (Nat.pair n j)) := by
  unfold Grid.start at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  cases h
  rfl

end MojoProof.Sym
