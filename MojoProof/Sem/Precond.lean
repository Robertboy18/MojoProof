import MojoProof.Sem.Closed

/-!
# The precondition of a binary elementwise kernel, and its satisfiability

docs/proofs/precond.md. A kernel `out[i] = f(x[i], y[i])` for `i < n`, written in Mojo over
`LayoutTensor`s with a static layout, takes each buffer as a structure `{ ptr, u }` passed
`byval`, with `u` the layout's empty runtime part, and the element count as an `i32`
(`vector_addition`: `{ ptr, { { {} }, { {} } } }` three times, then `i32 %3`). The caller passes
values: `launchArgs` encodes each structure into a new block per thread, from which the kernel
loads it back.

Proved here, for every layout:
* pointers round-trip through memory bytes (`Layout.Codec.ptr`), and so does every structure of a
  pointer and a zero-size, defined tail (`Layout.Codec.ptrArg`), which covers the byval argument
  of every `LayoutTensor` with a static layout;
* an allocation at the next number keeps a memory closed (`Mem.Closed.alloc`), and a tensor's
  bytes hold pointers only to the blocks its elements name (`tensorBytes_namesIn`).

The precondition, for every layout, element type with a codec, length, inputs, element count and
block numbering: `Map2.Pre` says the caller's memory is closed under the arguments `Map2.args`,
has three distinct live global buffers owned by all threads (two read-only inputs holding the
tensors row-major from offset 0, one writable output), each of at least `n` elements at an
aligned address whose first `n` elements' generic addresses do not wrap (`Mem.Fits`), and `n` is
at most the length and below `2 ^ 31`. The precondition is satisfiable for every input:
`Map2.mem` builds such a memory from the empty one by three `Mem.alloc`, and `Map2.pre_mem` proves
it meets `Map2.Pre`, for every address choice the alignment divides whose generic addresses leave
room for the `n` elements below `2 ^ w`.
-/

namespace MojoProof.Sem

open LLVM TorchLean

namespace Layout

/-- Offset 0 is aligned for every alignment. -/
theorem roundUp_zero (a : Nat) : roundUp 0 a = 0 := by
  unfold roundUp
  split
  · rfl
  · rw [Nat.zero_add, Nat.div_eq_of_lt (by omega), Nat.zero_mul]

/-- The bytes `encode` gives a pointer `p`, `.ptr p 0`, ..., `.ptr p (n - 1)`, decode to `p`, for
every `n > 0`. -/
theorem ptrOf_range (p : Ptr) {n : Nat} (h : 0 < n) :
    ptrOf ((List.range n).map (MemByte.ptr p ·)) = some (.ptr p) := by
  obtain ⟨k, rfl⟩ : ∃ k, n = k + 1 := ⟨n - 1, by omega⟩
  have e : (List.range (k + 1)).map (MemByte.ptr p ·) =
      .ptr p 0 :: (List.range k).map (MemByte.ptr p ∘ Nat.succ) := by
    rw [List.range_succ_eq_map]
    simp [Function.comp_def]
  generalize (List.range k).map (MemByte.ptr p ∘ Nat.succ) = T at e
  have hr : MemByte.ptr p 0 :: T =
      (List.range (MemByte.ptr p 0 :: T).length).map (MemByte.ptr p ·) := by
    rw [← e, List.length_map, List.length_range]
  have hp : (MemByte.ptr p 0 :: T).contains .poison = false := by simp [← e]
  have hu : (MemByte.ptr p 0 :: T).contains .undef = false := by simp [← e]
  rw [e]
  unfold ptrOf
  simp only [hp, hu, Bool.false_eq_true, ↓reduceIte]
  exact ite_eq_left hr

/-- **Pointers round-trip.** For every layout and address space `a` whose pointers have at least
one byte, `Val.ptr` is a codec for `.ptr a`. -/
theorem Codec.ptr (l : Layout) (a : Nat) (h : 0 < l.storeSize (.ptr a)) :
    l.Codec (.ptr a) Val.ptr where
  inj _ _ h := Val.ptr.inj h
  defined _ := rfl
  round p := ⟨(List.range (l.storeSize (.ptr a))).map (MemByte.ptr p ·), by simp [encode],
    by simp only [List.length_map, List.length_range]; rfl,
    by simpa only [decode] using ptrOf_range p h⟩

/-- **A pointer with a zero-size tail round-trips.** For every layout, address space `a` whose
pointers have at least one byte, and type `u` of size 0 whose value `z` is defined, encodes to no
bytes and decodes from none: `p ↦ .agg [.ptr p, z]` is a codec for `.struct [.ptr a, u]`. Mojo
passes a `LayoutTensor` with a static layout as such a structure, `u` being the layout's empty
runtime part (`vector_addition`: `{ ptr, { { {} }, { {} } } }`). -/
theorem Codec.ptrArg (l : Layout) (a : Nat) {u : Ty} {z : Val} (h : 0 < l.storeSize (.ptr a))
    (hu : l.size u = 0) (hz : z.defined = true) (he : l.encode u z = some [])
    (hd : l.decode u [] = some z) :
    l.Codec (.struct [.ptr a, u]) (fun p : Ptr => Val.agg [.ptr p, z]) where
  inj p q h := by simpa using h
  defined _ := by simp [Val.defined, Val.allDefined, hz]
  round p := by
    have hs : l.stored u = 0 := by
      have := l.stored_le_size u
      omega
    obtain ⟨R, hR⟩ : ∃ R, l.encode (.struct [.ptr a, u]) (.agg [.ptr p, z]) =
        some ((List.range (l.storeSize (.ptr a))).map (MemByte.ptr p ·) ++ R) := by
      simp only [encode, encodeFields, he, roundUp_zero, Option.bind_eq_bind, Option.pure_def,
        Option.bind_some, Option.map_some, Nat.sub_self, List.replicate_zero, List.nil_append,
        List.append_assoc]
      exact ⟨_, rfl⟩
    refine ⟨_, hR, encode_length l _ _ _ hR, ?_⟩
    have h1 : slice ((List.range (l.storeSize (.ptr a))).map (MemByte.ptr p ·) ++ R) 0
        (l.stored (.ptr a)) = (List.range (l.storeSize (.ptr a))).map (MemByte.ptr p ·) := by
      simp only [slice, List.drop_zero]
      exact List.take_left' (by simp only [List.length_map, List.length_range]; rfl)
    have h2 : ∀ o, slice ((List.range (l.storeSize (.ptr a))).map (MemByte.ptr p ·) ++ R) o
        (l.stored u) = [] := fun o => by simp [slice, hs]
    simp only [decode, decodeFields, roundUp_zero, h1, h2, hd, ptrOf_range p h,
      Option.bind_eq_bind, Option.pure_def, Option.bind_some, Option.map_some]

end Layout

/-- **An allocation at the next number keeps a memory closed**: for every memory closed under
some values, every block made by `Mem.alloc` at the next number whose initial bytes hold pointers
only to numbers below `next`, and all values `vs'` naming numbers up to the new block's
(`Val.bounds vs' ≤ m.next + 1`), the memory after the allocation is closed under `vs'`. -/
theorem Mem.Closed.alloc {m : Mem} {vs : List Val} (h : m.Closed vs) (l : Layout)
    (space size align : Nat) (live readOnly : Bool) (owner : Owner) (addr gaddr : Nat)
    {init : List MemByte} (hinit : ∀ p j, MemByte.ptr p j ∈ init → p.block < m.next)
    {vs' : List Val} (hv : Val.bounds vs' ≤ m.next + 1) :
    (m.alloc l space size align live readOnly owner addr gaddr init).1.Closed vs' where
  pos := by simp [Mem.alloc]
  null := by
    have : (0 : Nat) ≠ m.next := by have := h.pos; omega
    simp [Mem.alloc, Mem.set, this, h.null]
  above c hc := by
    simp only [Mem.alloc] at hc ⊢
    simp only [Mem.set, ite_eq_right (show c ≠ m.next by omega)]
    exact h.above c (by omega)
  vals := by simpa [Mem.alloc] using hv
  bytes c b i p j hc hi hp := by
    simp only [Mem.alloc, Mem.set] at hc ⊢
    split at hc
    · cases hc
      exact Nat.lt_succ_of_lt (hinit p j (mem_of_getD hp (by simp)))
    · exact Nat.lt_succ_of_lt (h.bytes c b i p j hc hi hp)

variable {α : Type} [Storage α]

/-- The bytes of a tensor hold pointers only to numbers of `S`, for every layout, type, set `S`,
encoder whose values name only numbers of `S`, shape and tensor. -/
theorem tensorBytes_namesIn {S : Nat → Prop} {l : Layout} {t : Ty} {enc : α → Val} {s : Shape}
    (hn : ∀ v, (enc v).NamesIn S) (x : Tensor α s) :
    ∀ p j, MemByte.ptr p j ∈ tensorBytes l t enc x → S p.block := by
  intro p j hp
  unfold tensorBytes at hp
  cases he : l.encode (.arr (Shape.size s) t) (.agg (List.ofFn fun k => enc (x.getFlat k))) with
  | none => simp [he] at hp
  | some bs =>
    rw [he, Option.getD_some] at hp
    refine encode_namesIn l _ he (Val.allNamesIn_iff.2 fun v hv => ?_) p j hp
    obtain ⟨k, rfl⟩ := List.mem_ofFn.1 hv
    exact hn _

/-- The arguments of a binary elementwise kernel over blocks `a`, `b` (inputs) and `o` (output),
as Mojo passes `LayoutTensor`s with a static layout: three structures `.agg [.ptr ⟨_, 0⟩, z]`,
then the i32 element count `n`. -/
def Map2.args (z : Val) (a b o n : Nat) : List Val :=
  [.agg [.ptr ⟨a, 0⟩, z], .agg [.ptr ⟨b, 0⟩, z], .agg [.ptr ⟨o, 0⟩, z], .bits 32 (BitVec.ofNat 32 n)]

/-- Block `c` of `m` is a live global buffer (space 1) of at least `size` bytes, owned by all
threads, writable exactly if `w`, at addresses in its space and in the generic space that `al`
divides. -/
def Mem.Buffer (m : Mem) (c size al : Nat) (w : Bool) : Prop :=
  ∃ blk, m.blocks c = some blk ∧ blk.space = 1 ∧ blk.live = true ∧ blk.owner = .all ∧
    blk.readOnly = !w ∧ size ≤ blk.size ∧ al ∣ blk.addr ∧ al ∣ blk.gaddr

/-- Block `c` of `m` exists and its generic address `gaddr` plus `size` is at most `2 ^ w`, for
`w` the pointer width of address space 0 in layout `l`: the block's first `size` bytes have
generic addresses that do not wrap. `Mem.Buffer` and `Mem.Closed` do not say this; `Map2.Pre`
does, for its three buffers (field `fits`). -/
def Mem.Fits (l : Layout) (m : Mem) (c size : Nat) : Prop :=
  ∃ blk, m.blocks c = some blk ∧ blk.gaddr + size ≤ 2 ^ (l.ptr 0).1

/-- **The precondition of a binary elementwise kernel** `out[i] = f(x[i], y[i])` for `i < n`, for
every layout, element type `t` with encoder `enc`, alignment `al`, tail value `z`, memory, block
numbers, element count, length `N` and tensors: `m` is closed under the arguments
(`Map2.args z a b o n`); `a`, `b` and `o` are distinct; each is a live global buffer owned by all
threads of at least `n` elements at addresses `al` divides (`Mem.Buffer`), `a` and `b` read-only,
`o` writable; `a` holds `x` and `b` holds `y` row-major from offset 0 (`Mem.Holds`); `n ≤ N`, and
`n < 2 ^ 31`, so the i32 count is not negative; and the first `n` elements of each of `a`, `b`,
`o` have generic addresses that do not wrap `2 ^ w` (`Mem.Fits`, field `fits`), so an
`inbounds` `getelementptr` into them is not `poison`. -/
structure Map2.Pre (l : Layout) (t : Ty) (enc : α → Val) (al : Nat) (z : Val) (m : Mem)
    (a b o n : Nat) {N : Nat} (x y : Tensor α [N]) : Prop where
  /-- Builds `Map2.Pre` from its eight fields. -/
  mk ::
  /-- `m` is closed under the arguments. -/
  closed : m.Closed (Map2.args z a b o n)
  /-- The three buffers are distinct blocks. -/
  ne : a ≠ b ∧ a ≠ o ∧ b ≠ o
  /-- `a` and `b` are read-only and `o` writable buffers of `n` elements at addresses `al`
  divides. -/
  bufs : m.Buffer a (n * l.size t) al false ∧ m.Buffer b (n * l.size t) al false ∧
    m.Buffer o (n * l.size t) al true
  /-- `a` holds `x` row-major from offset 0. -/
  x : m.Holds l a t enc (rowMajor l t 0) x
  /-- `b` holds `y` row-major from offset 0. -/
  y : m.Holds l b t enc (rowMajor l t 0) y
  /-- The count is at most the tensors' length. -/
  le : n ≤ N
  /-- The count fits a nonnegative `i32`. -/
  lt : n < 2 ^ 31
  /-- The first `n` elements of each buffer have generic addresses that do not wrap. -/
  fits : m.Fits l a (n * l.size t) ∧ m.Fits l b (n * l.size t) ∧ m.Fits l o (n * l.size t)

/-- The caller memory `Map2.args` names: from the empty memory, blocks 1 and 2 in space 1 holding
`tensorBytes l t enc x` and `tensorBytes l t enc y` (read-only), and block 3 of `no` undefined
elements (writable), all live and owned by all threads, block `i + 1` at address `A i * al` in
space 1 and `G i * al` in the generic space (wrapped to the pointer widths). -/
def Map2.mem (l : Layout) (t : Ty) (enc : α → Val) (al : Nat) {N : Nat} (x y : Tensor α [N])
    (no : Nat) (A G : Fin 3 → Nat) : Mem :=
  let m₁ := (({} : Mem).alloc l 1 (Shape.size [N] * l.size t) al true true .all (A 0) (G 0)
    (tensorBytes l t enc x)).1
  let m₂ := (m₁.alloc l 1 (Shape.size [N] * l.size t) al true true .all (A 1) (G 1)
    (tensorBytes l t enc y)).1
  (m₂.alloc l 1 (no * l.size t) al true false .all (A 2) (G 2)).1

/-- **The precondition is satisfiable**, for every layout, element type with a codec whose values
name no block, alignment, length `N`, inputs `x` and `y`, element count `n ≤ N` with `n < 2 ^ 31`,
output length `no ≥ n`, address choices `A`, `G` whose addresses `A i * al` are below `2 ^ w₁`
and `G i * al` plus the `n` elements' bytes `n * l.size t` are at most `2 ^ w₀` (`w₁`, `w₀` the
pointer widths of space 1 and of the generic space; the second premise gives the field `fits`), and
tail value `z` naming no block: `Map2.mem` meets `Map2.Pre` at blocks 1, 2 and 3. -/
theorem Map2.pre_mem {l : Layout} {t : Ty} {enc : α → Val} (hc : l.Codec t enc)
    (hn : ∀ v, (enc v).NamesIn fun _ => False) (al : Nat) {N : Nat} (x y : Tensor α [N])
    {n no : Nat} (hN : n ≤ N) (h31 : n < 2 ^ 31) (hno : n ≤ no) (A G : Fin 3 → Nat)
    (hA : ∀ i, A i * al < 2 ^ (l.ptr 1).1) (hG : ∀ i, G i * al + n * l.size t ≤ 2 ^ (l.ptr 0).1)
    {z : Val} (hz : z.bound = 0) :
    Map2.Pre l t enc al z (Map2.mem l t enc al x y no A G) 1 2 3 n x y where
  closed := by
    have hb : ∀ (w : Tensor α [N]) (k : Nat), ∀ p j,
        MemByte.ptr p j ∈ tensorBytes l t enc w → p.block < k :=
      fun w _ p j hp => False.elim (tensorBytes_namesIn hn w p j hp)
    have h1 := Mem.closed_empty.alloc l 1 (Shape.size [N] * l.size t) al true true .all (A 0)
      (G 0) (hb x _) (vs' := []) (by simp [Val.bounds])
    have h2 := h1.alloc l 1 (Shape.size [N] * l.size t) al true true .all (A 1) (G 1) (hb y _)
      (vs' := []) (by simp [Val.bounds])
    exact h2.alloc l 1 (no * l.size t) al true false .all (A 2) (G 2) (init := []) (by simp) (by
      show Val.bounds (Map2.args z 1 2 3 n) ≤ 3 + 1
      simp only [Map2.args, Val.bounds, Val.bound, hz]
      omega)
  ne := by decide
  bufs := by
    have hs : Shape.size [N] = N := by simp [Shape.size]
    have hle : n * l.size t ≤ Shape.size [N] * l.size t := by
      rw [hs]
      exact Nat.mul_le_mul_right _ hN
    have hle' : n * l.size t ≤ no * l.size t := Nat.mul_le_mul_right _ hno
    have ha : ∀ i, al ∣ A i * al % 2 ^ (l.ptr 1).1 := fun i => by
      rw [Nat.mod_eq_of_lt (hA i)]; exact Nat.dvd_mul_left al (A i)
    have hg : ∀ i, al ∣ G i * al % 2 ^ (l.ptr 0).1 := fun i => by
      rcases Nat.lt_or_eq_of_le (le_trans (Nat.le_add_right _ _) (hG i)) with h | h
      · rw [Nat.mod_eq_of_lt h]; exact Nat.dvd_mul_left al (G i)
      · rw [h, Nat.mod_self]; exact Nat.dvd_zero al
    exact ⟨⟨_, rfl, rfl, rfl, rfl, rfl, hle, ha 0, hg 0⟩, ⟨_, rfl, rfl, rfl, rfl, rfl, hle, ha 1, hg 1⟩,
      ⟨_, rfl, rfl, rfl, rfl, rfl, hle', ha 2, hg 2⟩⟩
  x := by
    obtain ⟨blk, hb, hh⟩ := Mem.holds_alloc hc x ({} : Mem) 1 al true true .all (A 0) (G 0)
    exact ⟨blk, hb, hh⟩
  y := by
    obtain ⟨blk, hb, hh⟩ := Mem.holds_alloc hc y
      (({} : Mem).alloc l 1 (Shape.size [N] * l.size t) al true true .all (A 0) (G 0)
        (tensorBytes l t enc x)).1 1 al true true .all (A 1) (G 1)
    exact ⟨blk, hb, hh⟩
  le := hN
  lt := h31
  fits := by
    have hf : ∀ i, G i * al % 2 ^ (l.ptr 0).1 + n * l.size t ≤ 2 ^ (l.ptr 0).1 := fun i =>
      le_trans (Nat.add_le_add_right (Nat.mod_le _ _) _) (hG i)
    exact ⟨⟨_, rfl, hf 0⟩, ⟨_, rfl, hf 1⟩, ⟨_, rfl, hf 2⟩⟩

end MojoProof.Sem
