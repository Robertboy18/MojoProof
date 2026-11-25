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

The memory both kernels' preconditions are met on, for every layout, alignment, number of
blocks `k`, sizes, read-only flags, initial bytes and address choices: `Mem.allocs` makes `k` live
global blocks owned by all threads from the empty memory, and `Mem.allocs_spec` proves it closed
under every list of values naming blocks 1 to `k` and each block a `Mem.Buffer` that fits
(`Mem.Fits`) when the initial bytes hold no pointer and the addresses leave room. `Mem.three` and
`Mem.three_spec` are the two at `k = 3`; `Map2.pre_mem` and `Mat.pre_mem` are corollaries of
`Mem.three_spec`.

The precondition of a matmul kernel `C[r][c] = Σₖ<K A[r][k] B[c][k]` (`r < m`, `c < n`) over
row-major buffers with row strides `sA`, `sB`, `sC`, for every layout, element type with a codec,
sizes, strides and block numbering: `Mat.Pre` says the caller's memory is closed under the
arguments `Mat.args` (the output first, then the two inputs, then the i32 `m`, `n`, `K`, as the
naive matmul kernel takes them), has three distinct buffers (two read-only inputs of `m * sA` and
`n * sB` elements holding the tensors row-major from offset 0, one writable output of `m * sC`
elements) that fit, `n ≤ sC`, `K ≤ sA`, `K ≤ sB`, and `m * sC`, `m * sA`, `n * sB` below `2 ^ 31`.
`Mat.mem` builds such a memory by `Mem.three`, and `Mat.pre_mem` proves it meets `Mat.Pre`.

`Mem.Buffer`, `Mem.Fits` and `Mem.Holds` at block `q` read only block `q`, so each holds in every
memory with the same block `q` (`Mem.Buffer.of_block`, `Mem.Fits.of_block`, `Mem.Holds.of_block`).
A store that succeeds at a pointer into block `p.block ≠ q` keeps block `q` (`Mem.store_blocks`),
so the three at `q` carry over (`Mem.Buffer.store`, `Mem.Fits.store`, `Mem.Holds.store`);
`Mem.log` changes only the trace, so they carry over a log by definition.
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
      have hp' : init.getD i .undef = .ptr p j := by simpa only [ByteTree.bytesOf_eq] using hp
      exact Nat.lt_succ_of_lt (hinit p j (mem_of_getD hp' (by simp)))
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

/-- `Mem.Buffer` at block `q` reads only block `q`: it holds in every memory that has `m`'s block
`q`, for every memory, block number, size, alignment and writability. -/
theorem Mem.Buffer.of_block {m m' : Mem} {q size al : Nat} {w : Bool}
    (hq : ∀ x, m.blocks q = some x → m'.blocks q = some x) (h : m.Buffer q size al w) :
    m'.Buffer q size al w := by
  obtain ⟨blk, hb, hP⟩ := h
  exact ⟨blk, hq _ hb, hP⟩

/-- `Mem.Fits` at block `q` reads only block `q`: it holds in every memory that has `m`'s block
`q`, for every layout, memory, block number and size. -/
theorem Mem.Fits.of_block {l : Layout} {m m' : Mem} {q size : Nat}
    (hq : ∀ x, m.blocks q = some x → m'.blocks q = some x) (h : m.Fits l q size) :
    m'.Fits l q size := by
  obtain ⟨blk, hb, hP⟩ := h
  exact ⟨blk, hq _ hb, hP⟩

/-- `Mem.Holds` at block `q` reads only block `q`: it holds in every memory that has `m`'s block
`q`, for every layout, memory, block number, element type, encoder, offsets and tensor. -/
theorem Mem.Holds.of_block {s : Shape} {l : Layout} {m m' : Mem} {q : Nat} {t : Ty}
    {enc : α → Val} {off : Shape.Coord s → Nat} {x : Tensor α s}
    (hq : ∀ y, m.blocks q = some y → m'.blocks q = some y) (h : m.Holds l q t enc off x) :
    m'.Holds l q t enc off x := by
  obtain ⟨blk, hb, hP⟩ := h
  exact ⟨blk, hq _ hb, hP⟩

/-- **A store keeps the other blocks**: for every layout, memory, thread, address space, type,
value, pointer `p`, alignment and atomic operation, if the store succeeds with memory `m'`, then
every block number `q ≠ p.block` has the same block in `m'` as in `m`. -/
theorem Mem.store_blocks {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    {q : Nat} (hq : p.block ≠ q) : m'.blocks q = m.blocks q := by
  unfold Mem.store at h
  cases hbs : l.encode t v with
  | none => simp [hbs] at h
  | some bs =>
    simp only [hbs, bind, Except.bind, pure, Except.pure] at h
    split at h
    · cases h
    · rename_i m₁ hw
      cases h
      unfold Mem.write at hw
      simp only [bind, Except.bind, pure, Except.pure] at hw
      split at hw
      · cases hw
      · split at hw
        · cases hw
        · cases hw
          simp [Mem.log, Mem.set, Ne.symm hq]

/-- A `Mem.Buffer` at a block other than the one a store that succeeds writes is one after it
(`Mem.store_blocks`, `Mem.Buffer.of_block`), for every store and buffer. -/
theorem Mem.Buffer.store {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    {q : Nat} (hq : p.block ≠ q) {size al' : Nat} {wr : Bool} (hb : m.Buffer q size al' wr) :
    m'.Buffer q size al' wr :=
  hb.of_block fun _ hx => (Mem.store_blocks h hq).trans hx

/-- `Mem.Fits` at a block other than the one a store that succeeds writes holds after it
(`Mem.store_blocks`, `Mem.Fits.of_block`), for every store, layout and size. -/
theorem Mem.Fits.store {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    {q : Nat} (hq : p.block ≠ q) {l' : Layout} {size : Nat} (hb : m.Fits l' q size) :
    m'.Fits l' q size :=
  hb.of_block fun _ hx => (Mem.store_blocks h hq).trans hx

/-- `Mem.Holds` at a block other than the one a store that succeeds writes holds after it
(`Mem.store_blocks`, `Mem.Holds.of_block`), for every store, layout, element type, encoder,
offsets and tensor. -/
theorem Mem.Holds.store {l : Layout} {m m' : Mem} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    {q : Nat} (hq : p.block ≠ q) {l' : Layout} {t' : Ty} {enc : α → Val} {s : Shape}
    {off : Shape.Coord s → Nat} {x : Tensor α s} (hb : m.Holds l' q t' enc off x) :
    m'.Holds l' q t' enc off x :=
  hb.of_block fun _ hx => (Mem.store_blocks h hq).trans hx

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

/-- `k` live global blocks owned by all threads, from the empty memory, for every layout,
alignment `al`, block count `k`, sizes `S`, read-only flags `R`, initial bytes `I` and address
choices `A`, `G`: block `i + 1` (for `i < k`, allocated in the order of `i`) of `S i` bytes,
read-only exactly if `R i`, whose first bytes are `I i` and the others undefined, at address
`A i * al` in space 1 and `G i * al` in the generic space (wrapped to the pointer widths). At
`k = 3` it unfolds to `Mem.three`. -/
def Mem.allocs (l : Layout) (al : Nat) : (k : Nat) → (Fin k → Nat) → (Fin k → Bool) →
    (Fin k → List MemByte) → (Fin k → Nat) → (Fin k → Nat) → Mem
  | 0, _, _, _, _, _ => {}
  | k + 1, S, R, I, A, G =>
    ((Mem.allocs l al k (S ∘ Fin.castSucc) (R ∘ Fin.castSucc) (I ∘ Fin.castSucc)
      (A ∘ Fin.castSucc) (G ∘ Fin.castSucc)).alloc l 1 (S (Fin.last k)) al true (R (Fin.last k))
      .all (A (Fin.last k)) (G (Fin.last k)) (I (Fin.last k))).1

/-- **`k` global blocks are closed fitting buffers**, for every layout, alignment `al`, block
count `k`, sizes `S`, read-only flags `R`, initial bytes `I` holding no pointer byte, sizes
`n i ≤ S i` and address choices with `A i * al < 2 ^ w₁` and `G i * al + n i ≤ 2 ^ w₀` (`w₁`,
`w₀` the pointer widths of space 1 and of the generic space): `Mem.allocs` is closed under every
list of values naming numbers up to `k` (`Val.bounds vs ≤ k + 1`), and its block `i + 1` is a
`Mem.Buffer` of `n i` bytes at addresses `al` divides, writable exactly if not `R i`, that fits
below `2 ^ w₀` for `n i` bytes (`Mem.Fits`). `Mem.three_spec` is its instance at `k = 3`. -/
theorem Mem.allocs_spec (l : Layout) (al : Nat) {k : Nat} (S : Fin k → Nat) (R : Fin k → Bool)
    {I : Fin k → List MemByte} (hI : ∀ i p j, MemByte.ptr p j ∉ I i) {A G n : Fin k → Nat}
    (hn : ∀ i, n i ≤ S i) (hA : ∀ i, A i * al < 2 ^ (l.ptr 1).1)
    (hG : ∀ i, G i * al + n i ≤ 2 ^ (l.ptr 0).1) :
    (∀ vs : List Val, Val.bounds vs ≤ k + 1 → (Mem.allocs l al k S R I A G).Closed vs) ∧
      ∀ i : Fin k, (Mem.allocs l al k S R I A G).Buffer (i.val + 1) (n i) al (!R i) ∧
        (Mem.allocs l al k S R I A G).Fits l (i.val + 1) (n i) := by
  have hnext : ∀ k S R I A G, (Mem.allocs l al k S R I A G).next = k + 1 := by
    intro k
    induction k with
    | zero => intro _ _ _ _ _; rfl
    | succ k ih => intro S R I A G; exact congrArg (· + 1) (ih _ _ _ _ _)
  induction k with
  | zero => exact ⟨fun vs hv => { Mem.closed_empty with vals := hv }, fun i => i.elim0⟩
  | succ k ih =>
    obtain ⟨hc, hb⟩ := ih (S ∘ Fin.castSucc) (R ∘ Fin.castSucc) (I := I ∘ Fin.castSucc)
      (fun i => hI _) (A := A ∘ Fin.castSucc) (G := G ∘ Fin.castSucc) (n := n ∘ Fin.castSucc)
      (fun i => hn _) (fun i => hA _) (fun i => hG _)
    have hm := hnext k (S ∘ Fin.castSucc) (R ∘ Fin.castSucc) (I ∘ Fin.castSucc)
      (A ∘ Fin.castSucc) (G ∘ Fin.castSucc)
    refine ⟨fun vs hv => ?_, fun i => ?_⟩
    · exact (hc [] (by simp [Val.bounds])).alloc l 1 _ al true _ .all _ _
        (fun p j hp => absurd hp (hI _ p j)) (by rw [hm]; exact hv)
    · have hq : ∀ q, q ≠ k + 1 → ∀ x, (Mem.allocs l al k (S ∘ Fin.castSucc) (R ∘ Fin.castSucc)
          (I ∘ Fin.castSucc) (A ∘ Fin.castSucc) (G ∘ Fin.castSucc)).blocks q = some x →
          (Mem.allocs l al (k + 1) S R I A G).blocks q = some x := fun q hq x hx => by
        show (if q = _ then _ else _) = _
        rw [hm]
        simpa [hq] using hx
      refine Fin.lastCases ?_ (fun i => ?_) i
      · have ha : al ∣ A (Fin.last k) * al % 2 ^ (l.ptr 1).1 := by
          rw [Nat.mod_eq_of_lt (hA _)]; exact Nat.dvd_mul_left al _
        have hg : al ∣ G (Fin.last k) * al % 2 ^ (l.ptr 0).1 := by
          rcases Nat.lt_or_eq_of_le (le_trans (Nat.le_add_right _ _) (hG (Fin.last k))) with h | h
          · rw [Nat.mod_eq_of_lt h]; exact Nat.dvd_mul_left al _
          · rw [h, Nat.mod_self]; exact Nat.dvd_zero al
        have hf : G (Fin.last k) * al % 2 ^ (l.ptr 0).1 + n (Fin.last k) ≤ 2 ^ (l.ptr 0).1 :=
          le_trans (Nat.add_le_add_right (Nat.mod_le _ _) _) (hG _)
        have he : (Mem.allocs l al (k + 1) S R I A G).blocks (k + 1) = some
            { space := 1, size := S (Fin.last k), live := true, readOnly := R (Fin.last k),
              owner := .all, bytes := ByteTree.bytesOf (I (Fin.last k)),
              addr := A (Fin.last k) * al % 2 ^ (l.ptr 1).1,
              gaddr := G (Fin.last k) * al % 2 ^ (l.ptr 0).1 } := by
          show (if k + 1 = _ then _ else _) = _
          rw [hm]
          simp
        exact ⟨⟨_, he, rfl, rfl, rfl, (Bool.not_not _).symm, hn _, ha, hg⟩, ⟨_, he, hf⟩⟩
      · have hi : (i.castSucc.val + 1) ≠ k + 1 := by simp only [Fin.val_castSucc]; omega
        exact ⟨Mem.Buffer.of_block (hq _ hi) (hb i).1, Mem.Fits.of_block (hq _ hi) (hb i).2⟩

/-- Three live global blocks owned by all threads, from the empty memory, for every layout,
alignment `al`, sizes `S`, read-only flags `R`, initial bytes `I` and address choices `A`, `G`:
block `i + 1` (for `i < 3`) of `S i` bytes, read-only exactly if `R i`, whose first bytes are
`I i` and the others undefined, at address `A i * al` in space 1 and `G i * al` in the generic
space (wrapped to the pointer widths): `Mem.allocs` at `k = 3`, unrolled. -/
def Mem.three (l : Layout) (al : Nat) (S : Fin 3 → Nat) (R : Fin 3 → Bool)
    (I : Fin 3 → List MemByte) (A G : Fin 3 → Nat) : Mem :=
  let m₁ := (({} : Mem).alloc l 1 (S 0) al true (R 0) .all (A 0) (G 0) (I 0)).1
  let m₂ := (m₁.alloc l 1 (S 1) al true (R 1) .all (A 1) (G 1) (I 1)).1
  (m₂.alloc l 1 (S 2) al true (R 2) .all (A 2) (G 2) (I 2)).1

/-- **Three global blocks are closed fitting buffers**, for every layout, alignment `al`, sizes
`S`, read-only flags `R`, initial bytes `I` holding no pointer byte, sizes `n i ≤ S i` and address
choices with `A i * al < 2 ^ w₁` and `G i * al + n i ≤ 2 ^ w₀` (`w₁`, `w₀` the pointer widths of
space 1 and of the generic space): `Mem.three` is closed under every list of values naming numbers
up to 3 (`Val.bounds vs ≤ 4`), and its block `i + 1` is a `Mem.Buffer` of `n i` bytes at addresses
`al` divides, writable exactly if not `R i`, that fits below `2 ^ w₀` for `n i` bytes
(`Mem.Fits`): `Mem.allocs_spec` at `k = 3`, since `Mem.three` unfolds to `Mem.allocs` at 3. -/
theorem Mem.three_spec (l : Layout) (al : Nat) (S : Fin 3 → Nat) (R : Fin 3 → Bool)
    {I : Fin 3 → List MemByte} (hI : ∀ i p j, MemByte.ptr p j ∉ I i) {A G n : Fin 3 → Nat}
    (hn : ∀ i, n i ≤ S i) (hA : ∀ i, A i * al < 2 ^ (l.ptr 1).1)
    (hG : ∀ i, G i * al + n i ≤ 2 ^ (l.ptr 0).1) :
    (∀ vs : List Val, Val.bounds vs ≤ 4 → (Mem.three l al S R I A G).Closed vs) ∧
      ∀ i : Fin 3, (Mem.three l al S R I A G).Buffer (i.val + 1) (n i) al (!R i) ∧
        (Mem.three l al S R I A G).Fits l (i.val + 1) (n i) :=
  Mem.allocs_spec l al S R hI hn hA hG

/-- The caller memory `Map2.args` names: from the empty memory, blocks 1 and 2 in space 1 holding
`tensorBytes l t enc x` and `tensorBytes l t enc y` (read-only), and block 3 of `no` undefined
elements (writable), all live and owned by all threads, block `i + 1` at address `A i * al` in
space 1 and `G i * al` in the generic space (wrapped to the pointer widths). It is `Mem.three` at
these sizes, flags and bytes, by unfolding. -/
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
tail value `z` naming no block: `Map2.mem` meets `Map2.Pre` at blocks 1, 2 and 3 (`Mem.three_spec`
and `Mem.holds_alloc`). -/
theorem Map2.pre_mem {l : Layout} {t : Ty} {enc : α → Val} (hc : l.Codec t enc)
    (hn : ∀ v, (enc v).NamesIn fun _ => False) (al : Nat) {N : Nat} (x y : Tensor α [N])
    {n no : Nat} (hN : n ≤ N) (h31 : n < 2 ^ 31) (hno : n ≤ no) (A G : Fin 3 → Nat)
    (hA : ∀ i, A i * al < 2 ^ (l.ptr 1).1) (hG : ∀ i, G i * al + n * l.size t ≤ 2 ^ (l.ptr 0).1)
    {z : Val} (hz : z.bound = 0) :
    Map2.Pre l t enc al z (Map2.mem l t enc al x y no A G) 1 2 3 n x y := by
  have hs : n * l.size t ≤ Shape.size [N] * l.size t :=
    Nat.mul_le_mul_right _ (by simpa [Shape.size] using hN)
  have h := Mem.three_spec l al ![Shape.size [N] * l.size t, Shape.size [N] * l.size t,
    no * l.size t] ![true, true, false] (I := ![tensorBytes l t enc x, tensorBytes l t enc y, []])
    (fun i p j hp => by
      fin_cases i <;> simp at hp
      exacts [tensorBytes_namesIn hn x p j hp, tensorBytes_namesIn hn y p j hp])
    (n := fun _ => n * l.size t) (fun i => by
      fin_cases i
      exacts [hs, hs, Nat.mul_le_mul_right _ hno]) hA hG
  obtain ⟨bx, hbx, hx⟩ := Mem.holds_alloc hc x ({} : Mem) 1 al true true .all (A 0) (G 0)
  obtain ⟨b', hby, hy⟩ := Mem.holds_alloc hc y
    (({} : Mem).alloc l 1 (Shape.size [N] * l.size t) al true true .all (A 0) (G 0)
      (tensorBytes l t enc x)).1 1 al true true .all (A 1) (G 1)
  exact ⟨h.1 _ (by simp only [Map2.args, Val.bounds, Val.bound, hz]; omega), by decide,
    ⟨(h.2 0).1, (h.2 1).1, (h.2 2).1⟩, ⟨bx, hbx, hx⟩, ⟨b', hby, hy⟩, hN, h31,
    ⟨(h.2 0).2, (h.2 1).2, (h.2 2).2⟩⟩

/-- The arguments of a matmul kernel over blocks `o` (output), `a`, `b` (inputs), as the naive
matmul kernel of tests/corpus/mgemm takes them (three `byval` structures `{ ptr, u }`, `%0` the
output, `%1`, `%2`, then `i32 %3`, `%4`, `%5`): three structures `.agg [.ptr ⟨_, 0⟩, z]` for `o`,
`a`, `b`, then the i32 words of `m`, `n` and `K`. -/
def Mat.args (z : Val) (o a b m n K : Nat) : List Val :=
  [.agg [.ptr ⟨o, 0⟩, z], .agg [.ptr ⟨a, 0⟩, z], .agg [.ptr ⟨b, 0⟩, z],
    .bits 32 (BitVec.ofNat 32 m), .bits 32 (BitVec.ofNat 32 n), .bits 32 (BitVec.ofNat 32 K)]

/-- **The precondition of a matmul kernel** `C[r][c] = Σₖ<K A[r][k] B[c][k]` for `r < m`,
`c < n`, over row-major buffers with row strides `sA`, `sB`, `sC`, for every layout, element type
`t` with encoder `enc`, alignment `al`, tail value `z`, memory, block numbers, sizes, strides and
tensors `x` (`m × sA`) and `y` (`n × sB`): `mem` is closed under the arguments
(`Mat.args z o a b m n K`), so `mem.BytesIn mem.Known` is `closed.bytesIn`
(`Mem.Closed.bytesIn`, which is how `Kernel.sound_map2` gets it from `Map2.Pre`); `o`, `a` and
`b` are distinct; `a` and `b` are read-only and `o` writable live global buffers owned by all
threads of `m * sA`, `n * sB` and `m * sC` elements at addresses `al` divides (`Mem.Buffer`); `a`
holds `x` and `b` holds `y` row-major from offset 0 (`Mem.Holds`); `n ≤ sC`, `K ≤ sA`, `K ≤ sB`;
`m * sC`, `m * sA` and `n * sB` are below `2 ^ 31`, so the i32 offsets `r * sC + c`,
`r * sA + k` and `c * sB + k` are nonnegative; and the three buffers' bytes have generic addresses
that do not wrap `2 ^ w` (`Mem.Fits`). -/
structure Mat.Pre (l : Layout) (t : Ty) (enc : α → Val) (al : Nat) (z : Val) (mem : Mem)
    (o a b m n K sA sB sC : Nat) (x : Tensor α [m, sA]) (y : Tensor α [n, sB]) : Prop where
  /-- Builds `Mat.Pre` from its eight fields. -/
  mk ::
  /-- `mem` is closed under the arguments. -/
  closed : mem.Closed (Mat.args z o a b m n K)
  /-- The three buffers are distinct blocks. -/
  ne : o ≠ a ∧ o ≠ b ∧ a ≠ b
  /-- `a` and `b` are read-only buffers of `m * sA` and `n * sB` elements and `o` a writable one
  of `m * sC` elements, at addresses `al` divides. -/
  bufs : mem.Buffer a (m * sA * l.size t) al false ∧ mem.Buffer b (n * sB * l.size t) al false ∧
    mem.Buffer o (m * sC * l.size t) al true
  /-- `a` holds `x` row-major from offset 0. -/
  x : mem.Holds l a t enc (rowMajor l t 0) x
  /-- `b` holds `y` row-major from offset 0. -/
  y : mem.Holds l b t enc (rowMajor l t 0) y
  /-- A row of `C` has room for `n` cells, and a row of `A` and of `B` for `K` elements. -/
  le : n ≤ sC ∧ K ≤ sA ∧ K ≤ sB
  /-- The three buffers' element counts fit a nonnegative `i32`. -/
  lt : m * sC < 2 ^ 31 ∧ m * sA < 2 ^ 31 ∧ n * sB < 2 ^ 31
  /-- The bytes of each buffer have generic addresses that do not wrap. -/
  fits : mem.Fits l a (m * sA * l.size t) ∧ mem.Fits l b (n * sB * l.size t) ∧
    mem.Fits l o (m * sC * l.size t)

/-- The caller memory `Mat.args` names: `Mem.three` with block 1 the output, `m * sC` undefined
elements (writable), and blocks 2 and 3 the bytes `tensorBytes l t enc x` and
`tensorBytes l t enc y` (read-only), block `i + 1` at addresses `A i * al` and `G i * al`. -/
def Mat.mem (l : Layout) (t : Ty) (enc : α → Val) (al : Nat) {m n sA sB : Nat}
    (x : Tensor α [m, sA]) (y : Tensor α [n, sB]) (sC : Nat) (A G : Fin 3 → Nat) : Mem :=
  Mem.three l al ![m * sC * l.size t, Shape.size [m, sA] * l.size t,
    Shape.size [n, sB] * l.size t] ![false, true, true]
    ![[], tensorBytes l t enc x, tensorBytes l t enc y] A G

/-- **The matmul precondition is satisfiable**, for every layout, element type with a codec whose
values name no block, alignment, sizes `m`, `n`, `K`, strides with `n ≤ sC`, `K ≤ sA`, `K ≤ sB`
and `m * sC`, `m * sA`, `n * sB` below `2 ^ 31`, inputs `x` (`m × sA`) and `y` (`n × sB`),
address choices `A`, `G` with `A i * al < 2 ^ w₁` and `G i * al` plus the bytes of block `i + 1`
at most `2 ^ w₀`, and tail value `z` naming no block: `Mat.mem` meets `Mat.Pre` at the output
block 1 and the input blocks 2 and 3 (`Mem.three_spec` and `Mem.holds_alloc`). -/
theorem Mat.pre_mem {l : Layout} {t : Ty} {enc : α → Val} (hc : l.Codec t enc)
    (hn : ∀ v, (enc v).NamesIn fun _ => False) (al : Nat) {m n sA sB : Nat}
    (x : Tensor α [m, sA]) (y : Tensor α [n, sB]) {K sC : Nat} (hle : n ≤ sC ∧ K ≤ sA ∧ K ≤ sB)
    (hlt : m * sC < 2 ^ 31 ∧ m * sA < 2 ^ 31 ∧ n * sB < 2 ^ 31) (A G : Fin 3 → Nat)
    (hA : ∀ i, A i * al < 2 ^ (l.ptr 1).1)
    (hG : ∀ i, G i * al + ![m * sC, m * sA, n * sB] i * l.size t ≤ 2 ^ (l.ptr 0).1)
    {z : Val} (hz : z.bound = 0) :
    Mat.Pre l t enc al z (Mat.mem l t enc al x y sC A G) 1 2 3 m n K sA sB sC x y := by
  have h := Mem.three_spec l al ![m * sC * l.size t, Shape.size [m, sA] * l.size t,
    Shape.size [n, sB] * l.size t] ![false, true, true]
    (I := ![[], tensorBytes l t enc x, tensorBytes l t enc y])
    (fun i p j hp => by
      fin_cases i <;> simp at hp
      exacts [tensorBytes_namesIn hn x p j hp, tensorBytes_namesIn hn y p j hp])
    (n := fun i => ![m * sC, m * sA, n * sB] i * l.size t) (fun i => by
      fin_cases i <;> simp [Shape.size, Nat.mul_assoc]) hA hG
  let m₁ := (({} : Mem).alloc l 1 (m * sC * l.size t) al true false .all (A 0) (G 0)).1
  obtain ⟨bx, hbx, hx⟩ := Mem.holds_alloc hc x m₁ 1 al true true .all (A 1) (G 1)
  obtain ⟨b', hby, hy⟩ := Mem.holds_alloc hc y
    (m₁.alloc l 1 (Shape.size [m, sA] * l.size t) al true true .all (A 1) (G 1)
      (tensorBytes l t enc x)).1 1 al true true .all (A 2) (G 2)
  exact ⟨h.1 _ (by simp only [Mat.args, Val.bounds, Val.bound, hz]; omega), by decide,
    ⟨(h.2 1).1, (h.2 2).1, (h.2 0).1⟩, ⟨bx, hbx, hx⟩, ⟨b', hby, hy⟩, hle, hlt,
    ⟨(h.2 1).2, (h.2 2).2, (h.2 0).2⟩⟩

end MojoProof.Sem
