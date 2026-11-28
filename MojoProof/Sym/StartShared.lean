import MojoProof.Sym.Start

/-!
# The start's shared arrays: the table entry and the block of an internal shared global

`shared` (MojoProof/Sem/Grid.lean) allocates, for each block of threads, one block of memory for
each `internal` shared global of the module (an `undef` initializer), and the start
(`Grid.start`) gives every context of that block of threads the pointer to it (`Ctx.globals`).
Every result here is for every program, kernel, launch, argument values, memory, address choice
and oracle, and for every internal shared global whose name no other global of the module has.

* `sharedBlock`: the block `shared` allocates for such a global (address space 3, the global's
  size and alignment, owned by the block of threads, writable iff not `constant`, undefined
  bytes, its addresses from the address choice).
* `shared_global`: when `shared` succeeds, its table names the global at offset 0 of a block of
  its memory that is the global's `sharedBlock`.
* `Grid.start_shared`: when the launch starts, every context of block of threads `b` names the
  global at offset 0 of a block of the start's memory that is `b`'s `sharedBlock` of it, at the
  address choices `ch (Nat.pair (b + 2) j)`, and the blocks of different blocks of threads are
  different. `Mem.BufferIn` of the block and the bounds of its addresses follow by evaluating
  `sharedBlock`'s fields.

`shared_res` (MojoProof/Sem/Grid.lean) says when `shared` succeeds and `shared_blocks` that it
keeps every block of its memory; `shared_global` is the block it adds for one global.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **The block of an internal shared global.** For every layout `l`, block of threads `b`,
address choice `ch`, position `i` and global `gl`: the block `shared` allocates for an internal
shared global `gl` at position `i` of the module's globals, for block of threads `b` with address
choice `ch`: in address space 3, of
`l.size gl.ty` bytes, live, read-only exactly if `gl` is `constant`, owned by `b` (`.cta b`),
every byte undefined, at the addresses `ch (2 i + 2)` and `ch (2 i + 3)` times the global's
alignment (its `align`, else its type's), modulo `2 ^ w` (`Mem.alloc`, `w` the width of a
pointer of address space 3 and of the generic space). -/
def sharedBlock (l : Layout) (b : Nat) (ch : Nat → Nat) (i : Nat) (gl : Global) : Sem.Block :=
  { space := 3, size := l.size gl.ty, live := true, readOnly := gl.isConst, owner := .cta b,
    bytes := fun _ => .undef,
    addr := ch (2 * i + 2) * gl.align.getD (l.align gl.ty) % 2 ^ (l.ptr 3).1,
    gaddr := ch (2 * i + 3) * gl.align.getD (l.align gl.ty) % 2 ^ (l.ptr 0).1 }

/-- **`shared` allocates an internal shared global's block.** For every layout, list of globals
`gs`, dynamic size, block of threads `b`, address choice `ch` and memory: when `shared` succeeds
with memory `m'` and table `tab`, every global `gl` at position `i` of `gs` with an `undef`
initializer (internal), whose name no other global of `gs` has, is named in `tab` at offset 0 of a
block `q` of `m'`, and that block is `sharedBlock l b ch i gl`. -/
theorem shared_global {l : Layout} {gs : List Global} {dyn b : Nat} {ch : Nat → Nat}
    {m m' : Mem} {tab : List (String × Ptr)} (h : shared l gs dyn b ch m = .ok (m', tab))
    {i : Nat} {gl : Global} (hi : gs[i]? = some gl) (hu : gl.init = some .undef)
    (hn : ∀ j (hj : j < gs.length), gs[j].name = gl.name → j = i) :
    ∃ q, tab.lookup gl.name = some ⟨q, 0⟩ ∧ m'.blocks q = some (sharedBlock l b ch i gl) := by
  unfold shared at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  rename_i v hv
  have hlt : i < gs.length := (List.getElem?_eq_some_iff.1 hi).1
  refine foldlM_zipIdx_inv (P := fun k (r : Mem × List (String × Ptr)) => i < k →
      ∃ q, r.2.lookup gl.name = some ⟨q, 0⟩ ∧ r.1.blocks q = some (sharedBlock l b ch i gl)) gs
    (fun k g r r' hg hs hr => ?_) h (fun h0 => absurd h0 (Nat.not_lt_zero _)) hlt
  obtain ⟨m1, acc⟩ := r
  dsimp only at hr
  have hk : k < gs.length := (List.getElem?_eq_some_iff.1 hg).1
  have hne : k ≠ i → (gl.name == g.name) = false := fun hki => by
    rw [beq_eq_false_iff_ne]
    intro he
    exact hki (hn k hk (by rw [(List.getElem?_eq_some_iff.1 hg).2]; exact he.symm))
  simp only [pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hs
  split at hs
  · cases hs
  · split at hs
    · split at hs
      · cases hs
      · rename_i hgn _
        cases hs
        intro hik
        have hki : k ≠ i := by
          rintro rfl
          rw [hi] at hg
          cases hg
          rw [hu] at hgn
          cases hgn
        obtain ⟨q, h1, h2⟩ := hr (by omega)
        exact ⟨q, by rw [List.lookup_cons, hne hki]; exact h1, h2⟩
    · split at hs
      · cases hs
      · rename_i w hw
        cases hs
        intro hik
        by_cases hki : k = i
        · subst hki
          rw [hi] at hg
          cases hg
          refine ⟨w.2, by simp, ?_⟩
          unfold Mem.allocNext at hw
          split at hw
          · cases hw
          · cases hw
            simp [Mem.alloc, Mem.set, sharedBlock, ByteTree.bytesOf_eq]
        · obtain ⟨q, h1, h2⟩ := hr (by omega)
          exact ⟨q, by rw [List.lookup_cons, hne hki]; exact h1, Mem.allocNext_blocks hw h2⟩
    · cases hs

/-- **The start's shared arrays.** For every program, kernel, launch `L`, argument values,
memory, address choice `ch` and oracle with `Grid.start prog fn L args m ch oracle = .ok (g, c)`,
and every global `gl` at position `i` of the module's globals with an `undef` initializer (an
internal shared global) whose name no other global of the module has: there are block numbers
`q b` such that every context `c n` of a thread of block of threads `b = n / volume L.block <
volume L.grid` names `gl` at offset 0 of `q b`, the start's memory has at `q b` the block
`sharedBlock prog.layout b (fun j => ch (Nat.pair (b + 2) j)) i gl` (owned by `b`, of the
global's size, writable iff not `constant`, at the addresses `ch (Nat.pair (b + 2) (2 i + 2))`
and `ch (Nat.pair (b + 2) (2 i + 3))` times the alignment modulo the pointer widths), and the
blocks of two different blocks of threads are different. -/
theorem Grid.start_shared {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) {i : Nat} {gl : Global}
    (hi : prog.module.globals.toList[i]? = some gl) (hu : gl.init = some .undef)
    (hn : ∀ j (hj : j < prog.module.globals.toList.length),
      prog.module.globals.toList[j].name = gl.name → j = i) :
    ∃ q : Nat → Nat, (∀ n, n / volume L.block < volume L.grid →
        (c n).globals gl.name = some ⟨q (n / volume L.block), 0⟩) ∧
      (∀ b < volume L.grid, g.mem.blocks (q b) =
        some (sharedBlock prog.layout b (fun j => ch (Nat.pair (b + 2) j)) i gl)) ∧
      ∀ b < volume L.grid, ∀ b' < volume L.grid, q b = q b' → b = b' := by
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
  split at h
  · cases h
  rename_i v2 h2
  cases h
  rw [List.range_eq_range'] at h1
  have I := foldlM_range'_inv (P := fun k (r : Mem × List (List (String × Ptr))) =>
      r.2.length = k ∧ ∀ b < k, ∃ q, (r.2.getD b []).lookup gl.name = some ⟨q, 0⟩ ∧
        r.1.blocks q = some (sharedBlock prog.layout b (fun j => ch (Nat.pair (b + 2) j)) i gl))
    (fun k r r' hs hr => by
      obtain ⟨m1, acc⟩ := r
      obtain ⟨hlen, hr⟩ := hr
      dsimp only at hlen hr
      simp only [pure, Except.pure] at hs
      split at hs
      · cases hs
      · rename_i v hv
        cases hs
        refine ⟨by simp [hlen], fun b hb => ?_⟩
        by_cases hbk : b < k
        · obtain ⟨q, h1, h2⟩ := hr b hbk
          refine ⟨q, ?_, shared_blocks hv h2⟩
          rw [List.getD_append _ _ _ _ (by omega)]
          exact h1
        · obtain rfl : b = k := by omega
          obtain ⟨q, h1, h2⟩ := shared_global hv hi hu hn
          refine ⟨q, ?_, h2⟩
          rw [List.getD_append_right _ _ _ _ (by omega), hlen, Nat.sub_self]
          simpa using h1)
    _ 0 _ h1 ⟨rfl, fun b hb => absurd hb (Nat.not_lt_zero b)⟩
  rw [Nat.zero_add] at I
  have hm2 := fun q x (hq : v1.1.blocks q = some x) =>
    foldlM_inv (P := fun r => r.1.blocks q = some x) (fun r k r' hs hr => by
      simp only [pure, Except.pure] at hs
      split at hs
      · cases hs
      · rename_i v hv
        split at hs
        · cases hs
        · cases hs
          exact launchArgs_blocks hv hr) _ _ h2 hq
  have hq : ∀ b < volume L.grid, v2.1.blocks
      ((((v1.2.getD b []).lookup gl.name).map (·.block)).getD 0) =
        some (sharedBlock prog.layout b (fun j => ch (Nat.pair (b + 2) j)) i gl) := fun b hb => by
    obtain ⟨q, h1, h2⟩ := I.2 _ hb
    simp only [h1, Option.map_some, Option.getD_some]
    exact hm2 _ _ h2
  refine ⟨fun b => (((v1.2.getD b []).lookup gl.name).map (·.block)).getD 0, fun n hn => ?_,
    fun b hb => by simpa [Mem.compact_eq] using hq b hb, fun b hb b' hb' he => ?_⟩
  · obtain ⟨q, h1, -⟩ := I.2 _ hn
    show (v1.2.getD (n / volume L.block) []).lookup gl.name = _
    simp only [h1, Option.map_some, Option.getD_some]
  · have h2 : some (sharedBlock prog.layout b (fun j => ch (Nat.pair (b + 2) j)) i gl) =
        some (sharedBlock prog.layout b' (fun j => ch (Nat.pair (b' + 2) j)) i gl) := by
      rw [← hq b hb, ← hq b' hb']
      exact congrArg v2.1.blocks he
    simp only [Option.some.injEq, sharedBlock, Sem.Block.mk.injEq] at h2
    exact Owner.cta.inj h2.2.2.2.2.1

end MojoProof.Sym

