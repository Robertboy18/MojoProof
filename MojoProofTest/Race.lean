import MojoProof.Sym.Race

/-!
# Tests of the tactic mojo_race: `vector_addition`'s accesses on every launch

`vadd_owned` is about an access template, not about a run: the list of six accesses that thread
`k` of `vector_addition` makes on its active path (`%4 → %21 → %31`, taken when `k < n`) on a
one-dimensional launch, where the thread's index is `k` and its CTA `k / volume L.block`: the three
loads of its `byval` argument structs (blocks `p0`, `p1`, `p2`), the two `!invariant.load` loads
at offset `4 k` of the inputs `a` and `b`, and the store at offset `4 k` of `out`. mojo_race
proves, for every launch, `k` and blocks with the stated distinctness, that each access of that
literal list is owned by the elementwise discipline with cells `4 k` of 4 bytes; it has no
execution premise (that a run makes these accesses is not proved here), no bound `k < n` and no
1-D hypothesis, which only say when the template is the thread's. The other tests: the cells are
apart (`vadd_apart`), the stores of two threads do not conflict (`vadd_stores`) and their loads do
not either (`vadd_loads`), and `Grid.owned_sound`'s `hX`, `hL`, `hI` and `hO` for the thread map,
no local blocks, owned traces and the cells `4 k` clipped to `4 n` (`vadd_hX`, `vadd_hL`, `vadd_hI`,
`vadd_hO`); `hX` also for the tile map through the index word on a valid 1-D launch whose trace's
threads are below the thread count (`vadd_hX_index`).

The twin: with `tid.x` alone as the index, on a launch with two blocks of `B`
threads, threads `t` and `B + t` store to the same cell. mojo_race leaves the goal that their stores
do not conflict open, naming both accesses (`#guard_msgs`, on an `example`), and `twin_clash`
shows that they do conflict.
-/

namespace MojoProofTest.Race

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym

/-- **Cells `4 k` are 4 bytes apart.** -/
theorem vadd_apart : Apart (fun k => 4 * k) 4 := by
  mojo_race

/-- **The active-path access template of `vector_addition` is owned**: for every launch `L`,
number `k`, input blocks `a`, `b`, output block `out` and argument blocks `p0`, `p1`, `p2` other
than `out`, each access of the literal list (the accesses thread `k` makes on path `%4 → %21 →
%31` of a 1-D launch, as thread `k` of CTA `k / volume L.block`; no run is assumed) is
`Elem.Own out 4 (4 * ·)`: the store to `out` is in cell `4 k`, the other accesses read, and the
`!invariant.load` loads are not to `out`. -/
theorem vadd_owned (L : Launch) (k a b out p0 p1 p2 : Nat) (hne : a ≠ b ∧ a ≠ out ∧ b ≠ out)
    (hp : p0 ≠ out ∧ p1 ≠ out ∧ p2 ≠ out) :
    ∀ x ∈ [(⟨⟨k, k / volume L.block⟩, ⟨p2, 0⟩, 8, false, none, false⟩ : Access),
        ⟨⟨k, k / volume L.block⟩, ⟨p1, 0⟩, 8, false, none, false⟩,
        ⟨⟨k, k / volume L.block⟩, ⟨p0, 0⟩, 8, false, none, false⟩,
        ⟨⟨k, k / volume L.block⟩, ⟨a, ((4 * k : Nat) : Int)⟩, 4, false, none, true⟩,
        ⟨⟨k, k / volume L.block⟩, ⟨b, ((4 * k : Nat) : Int)⟩, 4, false, none, true⟩,
        ⟨⟨k, k / volume L.block⟩, ⟨out, ((4 * k : Nat) : Int)⟩, 4, true, none, false⟩],
      Elem.Own out 4 (fun k => 4 * k) x := by
  mojo_race

/-- **The stores of two threads do not conflict**, for every launch, pair of threads `i ≠ j` and
output block. -/
theorem vadd_stores (L : Launch) (i j out : Nat) (hij : i ≠ j) :
    Access.conflict ⟨⟨i, i / volume L.block⟩, ⟨out, ((4 * i : Nat) : Int)⟩, 4, true, none, false⟩
      ⟨⟨j, j / volume L.block⟩, ⟨out, ((4 * j : Nat) : Int)⟩, 4, true, none, false⟩ = false := by
  mojo_race

/-- **The loads of element `k` of an input by two threads do not conflict** (both read), for
every launch, pair of threads and input block, even at one offset. -/
theorem vadd_loads (L : Launch) (i j a o : Nat) :
    (⟨⟨i, i / volume L.block⟩, ⟨a, (o : Int)⟩, 4, false, none, true⟩ : Access).conflict
      ⟨⟨j, j / volume L.block⟩, ⟨a, (o : Int)⟩, 4, false, none, true⟩ = false := by
  mojo_race

/-- **`hX` of `Grid.owned_sound`** for the thread map `own t = t` (the index of thread `t` on a
1-D launch, `Launch.index_oneDim`), for every trace and tiling. -/
theorem vadd_hX (tr : List Event) (T : Nat → Option (Tiling Nat)) :
    ∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.ptr.block = e.ptr.block →
      T a.ptr.block ≠ none → (fun t : Nat => t) a.who.thread = (fun t : Nat => t) e.who.thread →
        a.who.thread = e.who.thread := by
  mojo_race

/-- **`hX` of `Grid.owned_sound`** for the tile map through the index (thread `t`'s i64 word of
`ctaid.x * ntid.x + tid.x`, the word `vector_addition` indexes with), for every valid launch
whose grid and block have side 1 in `y` and `z`, every trace whose threads are below the thread
count and every tiling (`Launch.thread_eq_of_index`). -/
theorem vadd_hX_index (L : Launch) (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) (tr : List Event)
    (T : Nat → Option (Tiling (BitVec 64)))
    (hv : ∀ a, Event.access a ∈ tr → a.who.thread < volume L.grid * volume L.block) :
    ∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.ptr.block = e.ptr.block →
      T a.ptr.block ≠ none →
      (fun t => BitVec.ofNat 64 ((L.env t).sreg .ctaid .x * (L.env t).sreg .ntid .x +
          (L.env t).sreg .tid .x)) a.who.thread =
        (fun t => BitVec.ofNat 64 ((L.env t).sreg .ctaid .x * (L.env t).sreg .ntid .x +
          (L.env t).sreg .tid .x)) e.who.thread →
        a.who.thread = e.who.thread := by
  mojo_race

/-- **`hL` of `Grid.owned_sound`** with no block local to a thread, for every trace. -/
theorem vadd_hL (tr : List Event) :
    ∀ a w, Event.access a ∈ tr → (fun _ _ : Nat => False) a.ptr.block w → a.who.thread = w := by
  mojo_race

/-- **`hI` of `Grid.owned_sound`** for every trace whose accesses are owned (as `vadd_owned`
shows of `vector_addition`'s), for every output block. -/
theorem vadd_hI (tr : List Event) (out : Nat)
    (H : ∀ a, Event.access a ∈ tr → Elem.Own out 4 (fun k => 4 * k) a) :
    ∀ a e, Event.access a ∈ tr → Event.access e ∈ tr → a.invariant = true → e.write = true →
      a.ptr.block ≠ e.ptr.block := by
  mojo_race

/-- **`hO` of `Grid.owned_sound`** for the tiling of `out` by the cells `4 k` of 4 bytes clipped
to `4 n` (`Tiling.clip`, at `vadd_apart`) and the thread numbers as tiles, for every trace whose
accesses are owned and whose accesses to `out` end by `4 n` (`out`'s buffer of `n` floats), every
output block, count and local-block relation. -/
theorem vadd_hO (tr : List Event) (out n : Nat) (loc : Nat → Nat → Prop)
    (H : ∀ a, Event.access a ∈ tr → Elem.Own out 4 (fun k => 4 * k) a)
    (hb : ∀ a, Event.access a ∈ tr → a.ptr.block = out → a.ptr.off + a.len ≤ 4 * n) :
    ∀ a, Event.access a ∈ tr → (∀ w, ¬ loc a.ptr.block w) →
      Owned (fun b => if b = out then some (Tiling.clip (fun k => 4 * k) 4 (4 * n) vadd_apart)
        else none) (fun t => t) a := by
  mojo_race

/-- **The twin's collision**: with `tid.x` alone as the index, threads `t` and `B + t` of a launch
with two blocks of `B` threads store to the same cell `4 t`, so their stores conflict. -/
theorem twin_clash (B t out : Nat) :
    (⟨⟨t, 0⟩, ⟨out, ((4 * t : Nat) : Int)⟩, 4, true, none, false⟩ : Access).conflict
      ⟨⟨B + t, 1⟩, ⟨out, ((4 * t : Nat) : Int)⟩, 4, true, none, false⟩ = true := by
  simp [Access.conflict, Access.overlaps]

/--
info: mojo_race: open goal
  { who := { thread := t, cta := 0 }, ptr := { block := out, off := ↑(4 * t) }, len := 4,
          write := true, atomic := none, invariant := false }.conflict
      { who := { thread := B + t, cta := 1 }, ptr := { block := out, off := ↑(4 * t) }, len := 4,
        write := true, atomic := none, invariant := false } =
    false
---
error: unsolved goals
B t out : ℕ
⊢ { who := { thread := t, cta := 0 }, ptr := { block := out, off := ↑(4 * t) }, len := 4,
          write := true, atomic := none, invariant := false }.conflict
      { who := { thread := B + t, cta := 1 }, ptr := { block := out, off := ↑(4 * t) }, len := 4,
        write := true, atomic := none, invariant := false } =
    false
-/
#guard_msgs (whitespace := lax) in
/-- The twin: mojo_race leaves open, naming both stores, the goal that
threads `t` and `B + t` (blocks 0 and 1, `tid.x = t` in both) do not conflict, which
`twin_clash` refutes. An `example`, so that no declaration with the open goal enters the
environment. -/
example (B t out : Nat) :
    (⟨⟨t, 0⟩, ⟨out, ((4 * t : Nat) : Int)⟩, 4, true, none, false⟩ : Access).conflict
      ⟨⟨B + t, 1⟩, ⟨out, ((4 * t : Nat) : Int)⟩, 4, true, none, false⟩ = false := by
  mojo_race

end MojoProofTest.Race
