import MojoProof.Sem.Eval
import TorchLean.Tensor.Rep

/-!
# Tensors in memory

The relation between memory bytes and TorchLean tensors that kernel preconditions and
observations are stated with.

* A codec for type `t` is an injective map `enc : α → Val` whose values are defined (no scalar
  is poison or `undef`) and encode to `l.stored t` bytes that decode back to them
  (`Layout.Codec`). Integers of every width (`Layout.Codec.int`) and the FloatLib values of
  every float type (`Layout.Codec.float`) are codecs.
* `Block.Holds l t enc off x blk`: for every coordinate `i` of tensor `x`, the `l.stored t` bytes
  of block `blk` from offset `off i` lie inside the block and decode at type `t` to `enc (x i)`;
  `Mem.Holds` says it of block number `b` of a memory. The offsets are a parameter: `rowMajor`
  is TorchLean's own order, `base + linearize i * l.size t`.
* `tensorBytes l t enc x`: the bytes of `x` in row-major order, as `Layout.encode` writes an array
  of `Shape.size s` elements of type `t`.
* `Mem.tensor`: the observation of an output buffer, the tensor a block holds. Through a codec a
  block holds at most one tensor (`Block.holds_inj`), so the observation is that tensor
  (`Mem.tensor_eq`, `Mem.holds_of_tensor`), and its elements are defined values.

Proved here, for every layout, type, codec, shape, offset map and tensor:
* lookup (`Mem.load_holds`): a load of type `t` from offset `off i` of a block that holds `x`,
  which `Mem.check` admits, returns `enc (x i)`;
* update (`Block.holds_put`): writing the encoding of `enc v` at `off j`, when offsets are at
  least `l.stored t` bytes apart (`Apart`), gives a block that holds `x.set j v`;
  `Mem.write_of_check` is the write a store makes;
* written tiles give the tensor (docs/proofs/layout-tiles.md): a block whose bytes at each
  tile `off i` lie in it and are the encoding of `enc (f i)` holds `ofFn f`
  (`Block.holds_of_tiles`; the premise is per tile, with no order); so writing those encodings
  tile by tile, in any order and with repetitions, gives a block that holds `ofFn f` when the
  tiles are apart and in the block (`Block.holds_puts`, from `Block.read_puts`: after such
  writes a tile holds its last bytes, or the block's own if it was not written);
* stride arithmetic, proved once (`stride_lt`): offsets at stride `w` are `n ≤ w` apart
  (`apart_stride`; at base 0 and `n = w`, the cells `w i` of `w` bytes, `apart_mul`), and stay
  apart under an injective reindexing (`Apart.comp`); so row-major
  offsets are `l.stored t` apart (`apart_rowMajor`) and lie in `Shape.size s` elements
  (`rowMajor_inb`);
* frame (`Block.holds_put_apart`, `Mem.holds_set`): writing bytes outside every element, or
  setting another block, keeps `Holds`;
* construction (`Mem.holds_alloc`): the block `Mem.alloc` makes with `tensorBytes` holds `x`
  row-major, for every shape and input, so this part of a precondition is always satisfiable;
* round trips: `scalarOf_leBytes`, and `Layout.stored_le_size` (a value fits its allocation size);
* sizes (`Layout.encode_length`): every encoding of a value of type `t` has `l.stored t`
  bytes, for every layout, type and value, so a store writes and logs the bytes a load of its
  type reads; with `Layout.encodeAll_length` and `Layout.encodeFields_length` for the elements
  and fields of aggregates.
-/

namespace MojoProof.Sem

open LLVM TorchLean

variable {α : Type}

/-- The `n + 1` little-endian bytes of `x` are its low byte, then the `n` bytes of `x >>> 8`. -/
theorem leBytes_succ (n x : Nat) :
    leBytes (n + 1) x = .byte (BitVec.ofNat 8 x) :: leBytes n (x >>> 8) := by
  apply List.ext_getElem (by simp [leBytes])
  intro k _ _
  cases k with
  | zero => simp [leBytes]
  | succ k =>
    simp only [leBytes, List.getElem_map, List.getElem_range, List.getElem_cons_succ]
    rw [← Nat.shiftRight_add, show 8 * (k + 1) = 8 + 8 * k by omega]

/-- The `n` little-endian bytes of `x` read back as `x` modulo `2 ^ (8 * n)`, for every `n` and
`x`. -/
theorem ofLeBytes_leBytes (n x : Nat) : ofLeBytes (leBytes n x) = some (x % 2 ^ (8 * n)) := by
  induction n generalizing x with
  | zero => simp [leBytes, ofLeBytes, Nat.mod_one]
  | succ n ih =>
    rw [leBytes_succ, ofLeBytes, ih]
    simp only [Option.map_some, BitVec.toNat_ofNat, Option.some.injEq]
    rw [show 8 * (n + 1) = 8 + 8 * n by omega, Nat.pow_add, Nat.mod_mul,
      Nat.shiftRight_eq_div_pow]

/-- Every little-endian byte of a number is a data byte (not poison or `undef`). -/
theorem mem_leBytes {n x : Nat} {c : MemByte} (h : c ∈ leBytes n x) : ∃ b, c = .byte b := by
  obtain ⟨_, _, hi⟩ := List.mem_map.mp h
  exact ⟨_, hi.symm⟩

/-- The little-endian bytes of a word of `w` bits, `w ≤ 8 * n`, read back as that word. -/
theorem Layout.scalarOf_leBytes {w n : Nat} (b : BitVec w) (h : w ≤ 8 * n) :
    scalarOf w (leBytes n b.toNat) = some (.bits w b) := by
  have hb : b.toNat < 2 ^ (8 * n) := lt_of_lt_of_le b.isLt (Nat.pow_le_pow_right (by decide) h)
  have hp : MemByte.poison ∉ leBytes n b.toNat := fun h => by
    obtain ⟨_, h⟩ := mem_leBytes h; cases h
  have hu : MemByte.undef ∉ leBytes n b.toNat := fun h => by
    obtain ⟨_, h⟩ := mem_leBytes h; cases h
  simp [scalarOf, hp, hu, ofLeBytes_leBytes, Nat.mod_eq_of_lt hb, b.isLt]

/-- Every float type's width is a whole number of bytes. -/
theorem _root_.MojoProof.LLVM.FloatTy.bitWidth_mod (f : FloatTy) : f.fmt.bitWidth % 8 = 0 := by
  cases f <;> rfl

namespace Layout

/-- `enc` is a codec for type `t`: it is injective, its values are defined (no scalar is poison
or `undef`), and every `enc a` encodes to `l.stored t` bytes that decode back to `enc a`. -/
structure Codec (l : Layout) (t : Ty) (enc : α → Val) : Prop where
  /-- Builds `Layout.Codec` from its three fields. -/
  mk ::
  /-- `enc` is injective. -/
  inj : Function.Injective enc
  /-- No `enc a` has a poison or `undef` scalar. -/
  defined : ∀ a, (enc a).defined = true
  /-- `enc a` encodes to `l.stored t` bytes that decode back to `enc a`. -/
  round : ∀ a, ∃ bs,
    l.encode t (enc a) = some bs ∧ bs.length = l.stored t ∧ l.decode t bs = some (enc a)

/-- Integers of width `w` are a codec for `iN`. -/
theorem Codec.int (l : Layout) (w : Nat) : l.Codec (.int w) (Val.bits w) where
  inj _ _ h := by cases h; rfl
  defined _ := rfl
  round b := ⟨leBytes ((w + 7) / 8) b.toNat, by simp [encode],
    by simp [leBytes, stored, storeSize, scalarBits],
    by simp only [decode]; exact scalarOf_leBytes (n := (w + 7) / 8) b (by omega)⟩

/-- The FloatLib values of float type `f` are a codec for it. -/
theorem Codec.float (l : Layout) (f : FloatTy) : l.Codec (.fp f) (Val.ofFloat f) where
  inj a b h := by simpa using congrArg (Val.float? f) h
  defined _ := rfl
  round x := by
    have h := f.bitWidth_mod
    exact ⟨leBytes (f.fmt.bitWidth / 8) x.toBits.toNat, by simp [Val.ofFloat, encode],
      by simp [leBytes, stored, storeSize, scalarBits]; omega,
      by simp only [decode, Val.ofFloat]
         exact scalarOf_leBytes (n := f.fmt.bitWidth / 8) x.toBits (by omega)⟩

/-- Rounding up to a multiple of `a` gives at least `n`, for every `n` and `a`, `a = 0` included. -/
theorem roundUp_ge (n a : Nat) : n ≤ roundUp n a := by
  unfold roundUp
  split
  · exact le_rfl
  · rename_i ha
    have h1 := Nat.div_add_mod (n + a - 1) a
    have h2 := Nat.mod_lt (n + a - 1) (Nat.pos_of_ne_zero ha)
    rw [Nat.mul_comm] at h1
    generalize (n + a - 1) / a * a = p at *
    generalize (n + a - 1) % a = r at *
    omega

/-- A value occupies at most the allocation size of its type. -/
theorem stored_le_size (l : Layout) (t : Ty) : l.stored t ≤ l.size t := by
  cases t <;> simp only [stored, size] <;>
    first | exact le_rfl | exact roundUp_ge _ _ | simp [storeSize, scalarBits]

/-- Elements of type `t` padded to `stride` bytes take `max (l.stored t) stride` bytes each, if
every encoding of a value of `t` has `l.stored t` bytes. -/
theorem encodeAll_length {l : Layout} {t : Ty}
    (ht : ∀ v bs, l.encode t v = some bs → bs.length = l.stored t) :
    ∀ {xs : List Val} {stride : Nat} {bs : List MemByte}, l.encodeAll t xs stride = some bs →
      bs.length = xs.length * max (l.stored t) stride
  | [], _, _, h => by simp [encodeAll] at h; simp [← h]
  | x :: xs, stride, bs, h => by
    simp only [encodeAll, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨b, hb, rest, hr, rfl⟩ := h
    have := ht _ _ hb
    simp only [List.length_append, List.length_replicate, encodeAll_length ht hr,
      List.length_cons, this]
    rw [Nat.succ_mul]
    omega

mutual
/-- Every encoding of a value of type `t` has `l.stored t` bytes. -/
theorem encode_length (l : Layout) : ∀ (t : Ty) (v : Val) (bs : List MemByte),
    l.encode t v = some bs → bs.length = l.stored t
  | .vec n t, v, bs, h => by
    cases v
    case vec xs =>
      simp only [encode] at h
      split at h
      · rename_i hc
        obtain ⟨hn, hs, h8⟩ := hc
        rw [encodeAll_length (encode_length l t) h, hn, Nat.max_zero]
        have hb : ∀ sb, sb % 8 = 0 → n * ((sb + 7) / 8) = (n * sb + 7) / 8 := fun sb h => by
          obtain ⟨k, rfl⟩ := Nat.dvd_of_mod_eq_zero h
          rw [show (8 * k + 7) / 8 = k by omega, show n * (8 * k) + 7 = 7 + 8 * (n * k) by ring,
            Nat.add_mul_div_left _ _ (by norm_num)]
          simp
        cases t <;> simp [Ty.scalar] at hs <;>
          simp only [stored, storeSize, scalarBits] at h8 ⊢ <;> exact hb _ h8
      · simp at h
    case poison | undef => simp [encode] at h; simp [← h]
    all_goals simp [encode] at h
  | .arr n t, v, bs, h => by
    cases v
    case agg xs =>
      simp only [encode] at h
      split at h
      · rename_i hn
        rw [encodeAll_length (encode_length l t) h, hn, Nat.max_eq_right (l.stored_le_size t)]
        rfl
      · simp at h
    case poison | undef => simp [encode] at h; simp [← h]
    all_goals simp [encode] at h
  | .struct fs, v, bs, h => by
    cases v
    case agg xs =>
      simp only [encode, Option.map_eq_some_iff] at h
      obtain ⟨b, hb, rfl⟩ := h
      have := encodeFields_length l fs 0 xs b hb
      have := roundUp_ge (l.fieldsEnd 0 fs) (l.alignAll fs)
      simp only [List.length_append, List.length_replicate, stored, size]
      omega
    case poison | undef => simp [encode] at h; simp [← h]
    all_goals simp [encode] at h
  | .fp f, v, bs, h => by
    have := f.bitWidth_mod
    cases v
    case bits w b =>
      simp only [encode] at h
      split at h
      · rename_i hw
        subst hw
        simp only [Option.some.injEq] at h
        subst h
        simp [leBytes, stored, storeSize, scalarBits]
        omega
      · simp at h
    case poison | undef => simp [encode] at h; simp [← h]
    all_goals simp [encode] at h
  | .int _, v, bs, h | .ptr _, v, bs, h | .void, v, bs, h | .label, v, bs, h
  | .metadata, v, bs, h => by
    cases v <;> simp [encode, stored, storeSize, scalarBits, leBytes] at h ⊢ <;> simp [← h]

/-- Fields `fs` laid out from offset `off` end at `l.fieldsEnd off fs`. -/
theorem encodeFields_length (l : Layout) : ∀ (fs : List Ty) (off : Nat) (xs : List Val)
    (bs : List MemByte), l.encodeFields off fs xs = some bs → off + bs.length = l.fieldsEnd off fs
  | [], off, xs, bs, h => by
    cases xs <;> simp [encodeFields] at h
    simp [← h, fieldsEnd]
  | t :: ts, off, xs, bs, h => by
    cases xs with
    | nil => simp [encodeFields] at h
    | cons x xs =>
      simp only [encodeFields, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
        Option.some.injEq] at h
      obtain ⟨b, hb, rest, hr, rfl⟩ := h
      have h1 := encode_length l t x b hb
      have h2 := encodeFields_length l ts _ xs rest hr
      have h3 := roundUp_ge off (l.align t)
      have h4 := l.stored_le_size t
      simp only [List.length_append, List.length_replicate, fieldsEnd]
      omega
end

/-- For a codec `enc` of type `t` and a stride of at least `l.stored t` bytes: the elements
`as.map enc` encode, at that stride, to `as.length * stride` bytes, and element `k`'s
`l.stored t` bytes at offset `k * stride` decode to `enc as[k]`, for every list `as`. -/
theorem encodeAll_spec {l : Layout} {t : Ty} {enc : α → Val} (hc : l.Codec t enc) {stride : Nat}
    (hst : l.stored t ≤ stride) : ∀ as : List α, ∃ out,
      l.encodeAll t (as.map enc) stride = some out ∧ out.length = as.length * stride ∧
      ∀ k (hk : k < as.length), l.decode t (slice out (k * stride) (l.stored t)) = some (enc as[k])
  | [] => ⟨[], by simp [encodeAll]⟩
  | a :: as => by
    obtain ⟨bs, he, hl, hd⟩ := hc.round a
    obtain ⟨out, ho, hol, hk⟩ := encodeAll_spec hc hst as
    refine ⟨bs ++ List.replicate (stride - bs.length) MemByte.undef ++ out, ?_, ?_, ?_⟩
    · simp [encodeAll, he, ho]
    · simp only [List.length_append, List.length_replicate, hol, List.length_cons]
      rw [Nat.succ_mul]
      omega
    · intro k hk'
      cases k with
      | zero =>
        simp only [slice, Nat.zero_mul, List.drop_zero, List.getElem_cons_zero]
        rw [List.append_assoc, ← hl, List.take_left]
        exact hd
      | succ k =>
        have hdrop : (bs ++ List.replicate (stride - bs.length) MemByte.undef ++ out).drop
            ((k + 1) * stride) = out.drop (k * stride) := by
          rw [Nat.succ_mul, Nat.add_comm, ← List.drop_drop, List.drop_left' (by simp; omega)]
        simp only [slice, hdrop, List.getElem_cons_succ]
        exact hk k (by simpa using hk')

end Layout

variable [Storage α] {s : Shape}

/-- The bytes of tensor `x` in row-major order: `Shape.size s` elements of type `t`, each padded
to `l.size t` bytes, as `Layout.encode` writes an array (empty if an element has no encoding). -/
def tensorBytes (l : Layout) (t : Ty) (enc : α → Val) (x : Tensor α s) : List MemByte :=
  (l.encode (.arr (Shape.size s) t) (.agg (List.ofFn fun k => enc (x.getFlat k)))).getD []

/-- Row-major offsets from `base`: element `i` at `base + linearize i * l.size t`. -/
def rowMajor (l : Layout) (t : Ty) (base : Nat) (i : Shape.Coord s) : Nat :=
  base + (Shape.Coord.linearize i).val * l.size t

/-- The arithmetic of strides, proved once: element `a` of stride `w` ends where element `a + 1`
starts, so before element `b` for every `b > a`. -/
theorem stride_lt (w : Nat) {a b : Nat} (h : a < b) : a * w + w ≤ b * w := by
  have := Nat.mul_le_mul_right w (Nat.succ_le_of_lt h)
  rwa [Nat.succ_mul] at this

/-- Offsets `off` are at least `n` bytes apart. -/
def Apart {ι : Type} (off : ι → Nat) (n : Nat) : Prop :=
  ∀ i j, i ≠ j → off i + n ≤ off j ∨ off j + n ≤ off i

/-- Reindexing offsets that are apart by an injective map keeps them apart. -/
theorem Apart.comp {ι κ : Type} {off : ι → Nat} {n : Nat} (h : Apart off n) {g : κ → ι}
    (hg : Function.Injective g) : Apart (off ∘ g) n :=
  fun i j hij => h (g i) (g j) (hg.ne hij)

/-- Offsets at stride `w` from `base` are `n` apart for every `n ≤ w`. -/
theorem apart_stride (base : Nat) {n w : Nat} (h : n ≤ w) :
    Apart (fun k : Nat => base + k * w) n := fun i j hij => by
  dsimp only
  rcases Nat.lt_or_gt_of_ne hij with hl | hl
  · have := stride_lt w hl; omega
  · have := stride_lt w hl; omega

/-- Cells `w i` of `w` bytes are apart (`Apart`), for every width `w` (`apart_stride`). -/
theorem apart_mul (w : Nat) : Apart (fun i : Nat => w * i) w :=
  fun i j hij => by
    simpa only [Nat.zero_add, Nat.mul_comm] using apart_stride 0 (Nat.le_refl w) i j hij

/-- Row-major offsets are `l.stored t` apart: `apart_stride` through `linearize`. -/
theorem apart_rowMajor (l : Layout) (t : Ty) (base : Nat) :
    Apart (rowMajor (s := s) l t base) (l.stored t) :=
  (apart_stride base (l.stored_le_size t)).comp (g := fun i => (Shape.Coord.linearize i).val)
    fun _ _ h => Shape.Coord.linearize_injective (Fin.ext h)

/-- Every row-major element lies in the `Shape.size s` elements from `base`. -/
theorem rowMajor_inb (l : Layout) (t : Ty) (base : Nat) (i : Shape.Coord s) :
    rowMajor l t base i + l.stored t ≤ base + Shape.size s * l.size t := by
  have := stride_lt (l.size t) (Shape.Coord.linearize i).isLt
  have := l.stored_le_size t
  simp only [rowMajor]
  omega

/-- Block `blk` holds tensor `x` through codec `enc` for type `t` at offsets `off`: for every
coordinate `i`, the `l.stored t` bytes from `off i` lie in the block and decode to `enc (x i)`. -/
def Block.Holds (l : Layout) (t : Ty) (enc : α → Val) (off : Shape.Coord s → Nat)
    (x : Tensor α s) (blk : Block) : Prop :=
  ∀ i, off i + l.stored t ≤ blk.size ∧ l.decode t (blk.read (off i) (l.stored t)) = some (enc (x i))

/-- Block number `b` of `m` exists and holds tensor `x` (`Block.Holds`). -/
def Mem.Holds (l : Layout) (m : Mem) (b : Nat) (t : Ty) (enc : α → Val)
    (off : Shape.Coord s → Nat) (x : Tensor α s) : Prop :=
  ∃ blk, m.blocks b = some blk ∧ blk.Holds l t enc off x

variable {l : Layout} {t : Ty} {enc : α → Val} {off : Shape.Coord s → Nat} {x : Tensor α s}

/-- Reading the bytes just written at offset `o` gives them back. -/
theorem Block.read_put_self (blk : Block) (o : Nat) (bs : List MemByte) :
    (blk.put o bs).read o bs.length = bs := by
  apply List.ext_getElem (by simp [read])
  intro k h _
  simp only [read, List.length_map, List.length_range] at h
  simp [read, put, h]

/-- Writing bytes at offset `o` keeps the `n` bytes at `o'` when the two ranges are apart. -/
theorem Block.read_put_apart (blk : Block) {o o' n : Nat} (bs : List MemByte)
    (h : o' + n ≤ o ∨ o + bs.length ≤ o') : (blk.put o bs).read o' n = blk.read o' n := by
  apply List.ext_getElem (by simp [read])
  intro k hk _
  simp only [read, List.length_map, List.length_range] at hk
  simp only [read, put, List.getElem_map, List.getElem_range]
  rw [ite_eq_right (by omega)]

/-- Frame: writing bytes that miss every element keeps `Holds`. -/
theorem Block.holds_put_apart {blk : Block} (h : blk.Holds l t enc off x) {o : Nat}
    (bs : List MemByte) (hap : ∀ i, off i + l.stored t ≤ o ∨ o + bs.length ≤ off i) :
    (blk.put o bs).Holds l t enc off x := fun i => by
  rw [Block.Holds] at h
  refine ⟨(h i).1, ?_⟩
  rw [Block.read_put_apart _ _ (hap i)]
  exact (h i).2

/-- Update: for a codec (`Layout.Codec`) and offsets `l.stored t` bytes apart, writing the
encoding of `enc v` at `off j` in a block that holds `x` gives a block that holds `x.set j v`. -/
theorem Block.holds_put {blk : Block} (h : blk.Holds l t enc off x) (hc : l.Codec t enc)
    (hap : Apart off (l.stored t)) (j : Shape.Coord s) (v : α) {bs : List MemByte}
    (hbs : l.encode t (enc v) = some bs) :
    (blk.put (off j) bs).Holds l t enc off (x.set j v) := fun i => by
  obtain ⟨bs', he, hl, hd⟩ := hc.round v
  rw [hbs, Option.some.injEq] at he
  subst he
  refine ⟨(h i).1, ?_⟩
  by_cases hij : i = j
  · subst hij
    rw [← hl, Block.read_put_self, Tensor.Rep.get_set_self]
    exact hd
  · rw [Block.read_put_apart _ _ (by have := hap i j hij; omega),
      Tensor.Rep.get_set_ne x v (Ne.symm hij)]
    exact (h i).2

/-- Written tiles give the tensor: if the `l.stored t` bytes at each tile `off i` lie in the
block and are the encoding of `enc (f i)`, the block holds `ofFn f`. The premise is per tile; it
says nothing of the order the tiles were written in. -/
theorem Block.holds_of_tiles {blk : Block} (hc : l.Codec t enc) {f : Shape.Coord s → α}
    (hin : ∀ i, off i + l.stored t ≤ blk.size)
    (hw : ∀ i, l.encode t (enc (f i)) = some (blk.read (off i) (l.stored t))) :
    blk.Holds l t enc off (Tensor.Rep.ofFn f) := fun i => by
  obtain ⟨bs, he, _, hd⟩ := hc.round (f i)
  rw [hw i, Option.some.injEq] at he
  rw [Tensor.Rep.get_ofFn, he]
  exact ⟨hin i, hd⟩

/-- Writes of `n` bytes `bs i` at offsets `off i` that are `n` apart, for the indices of `is` in
its order: the `n` bytes at `off i` are then `bs i` if `i` is in `is`, and the block's own if
not. -/
theorem Block.read_puts {ι : Type} [DecidableEq ι] {off : ι → Nat} {n : Nat}
    (hap : Apart off n) {bs : ι → List MemByte} (hl : ∀ i, (bs i).length = n) (is : List ι)
    (blk : Block) (i : ι) :
    (is.foldl (fun b j => b.put (off j) (bs j)) blk).read (off i) n =
      if i ∈ is then bs i else blk.read (off i) n := by
  induction is generalizing blk with
  | nil => rfl
  | cons j is ih =>
    rw [List.foldl_cons, ih]
    by_cases hi : i ∈ is
    · simp [hi]
    · by_cases hij : i = j
      · subst hij
        simp only [hi, ite_false, List.mem_cons_self, ite_true]
        rw [← hl i, Block.read_put_self]
      · rw [ite_eq_right hi, ite_eq_right (by simp [hij, hi]), Block.read_put_apart]
        have := hap i j hij
        rw [hl j]
        omega

/-- Writes in any order give the tensor: writing the encoding of `enc (f i)` at each tile
`off i` of a list `is` that contains every coordinate, in any order and with repetitions, gives a
block that holds `ofFn f`, when the tiles are `l.stored t` bytes apart and in the block. -/
theorem Block.holds_puts {blk : Block} (hc : l.Codec t enc) (hap : Apart off (l.stored t))
    (hin : ∀ i, off i + l.stored t ≤ blk.size) {f : Shape.Coord s → α}
    {bs : Shape.Coord s → List MemByte}
    (hbs : ∀ i, l.encode t (enc (f i)) = some (bs i)) {is : List (Shape.Coord s)}
    (hall : ∀ i, i ∈ is) :
    (is.foldl (fun b i => b.put (off i) (bs i)) blk).Holds l t enc off (Tensor.Rep.ofFn f) := by
  have hl i : (bs i).length = l.stored t := by
    obtain ⟨bs', he, hl, _⟩ := hc.round (f i)
    rw [hbs i, Option.some.injEq] at he
    rw [he, hl]
  have hsize : ∀ (is' : List (Shape.Coord s)) (b : Block),
      (is'.foldl (fun b i => b.put (off i) (bs i)) b).size = b.size := fun is' => by
    induction is' with
    | nil => intro _; rfl
    | cons j is' ih => intro b; rw [List.foldl_cons, ih]; rfl
  refine Block.holds_of_tiles hc (fun i => by rw [hsize]; exact hin i) fun i => ?_
  rw [Block.read_puts hap hl, ite_eq_left (hall i)]
  exact hbs i

/-- Through a codec, a block holds at most one tensor at given offsets. -/
theorem Block.holds_inj {blk : Block} (hc : l.Codec t enc) {y : Tensor α s}
    (hx : blk.Holds l t enc off x) (hy : blk.Holds l t enc off y) : x = y :=
  Tensor.Rep.ext fun i => hc.inj (Option.some.inj (((hx i).2).symm.trans (hy i).2))

/-- The tensor block `b` of `m` holds through `enc` at offsets `off` (`Mem.Holds`), if any: the
observation of an output buffer. Through a codec it is the tensor the block holds
(`Mem.tensor_eq`), whose elements are defined values. -/
noncomputable def Mem.tensor (l : Layout) (m : Mem) (b : Nat) (t : Ty) (enc : α → Val)
    (off : Shape.Coord s → Nat) : Option (Tensor α s) :=
  open Classical in
  if h : ∃ x, m.Holds l b t enc off x then some h.choose else none

/-- For a codec `enc`: if block `b` holds the tensor `x`, the observation `Mem.tensor` is `x`. -/
theorem Mem.tensor_eq {m : Mem} {b : Nat} (hc : l.Codec t enc) (h : m.Holds l b t enc off x) :
    m.tensor l b t enc off = some x := by
  have he : ∃ x, m.Holds l b t enc off x := ⟨x, h⟩
  rw [Mem.tensor, dite_eq_left he]
  obtain ⟨blk, hb, hx⟩ := h
  obtain ⟨blk', hb', hy⟩ := he.choose_spec
  rw [hb] at hb'
  cases hb'
  exact congrArg some (Block.holds_inj hc hy hx)

/-- If the observation `Mem.tensor` is `x`, block `b` holds `x`. -/
theorem Mem.holds_of_tensor {m : Mem} {b : Nat} (h : m.tensor l b t enc off = some x) :
    m.Holds l b t enc off x := by
  rw [Mem.tensor] at h
  split at h
  · rename_i he
    cases h
    exact he.choose_spec
  · cases h

/-- Frame: setting another block keeps `Holds`. -/
theorem Mem.holds_set {m : Mem} {b b' : Nat} (blk' : Block) (hb : b ≠ b')
    (h : m.Holds l b t enc off x) : (m.set b' blk').Holds l b t enc off x := by
  obtain ⟨blk, hm, hh⟩ := h
  exact ⟨blk, by simp [Mem.set, hb, hm], hh⟩

/-- An access of `n` bytes at `p` passes `Mem.check`, giving the block and the offset, when the
block exists, is live, admits the accessor, the bytes lie in it, and its address is a multiple of
the alignment `al` if there is one. -/
theorem Mem.check_ok {m : Mem} {w : Who} {a n ad : Nat} {p : Ptr} {al : Option Nat}
    {blk : Block} (hb : m.blocks p.block = some blk) (hl : blk.live = true)
    (hw : blk.owner.admits w = true) (h0 : 0 ≤ p.off) (hn : p.off + n ≤ blk.size)
    (ha : m.addr l a p = .ok ad) (hal : ∀ k ∈ al, ad % k = 0) :
    m.check l w a p n al = .ok (blk, p.off.toNat) := by
  cases al with
  | none => simp [check, block, hb, hl, hw, h0, hn, ha, bind, Except.bind, pure, Except.pure]
  | some k =>
    simp [check, block, hb, hl, hw, h0, hn, ha, hal k rfl, bind, Except.bind, pure, Except.pure]

/-- A load of type `t` whose check passes gives the value its `l.stored t` bytes decode to. -/
theorem Mem.load_of_check {m : Mem} {w : Who} {a : Nat} {p : Ptr} {al : Option Nat}
    {blk : Block} {o : Nat} {v : Val} (hc : m.check l w a p (l.stored t) al = .ok (blk, o))
    (hd : l.decode t (blk.read o (l.stored t)) = some v) : m.load l w a t p al = .ok v := by
  simp [load, hc, hd, bind, Except.bind, pure, Except.pure]

/-- The write a store makes, when `Mem.check` admits it and the block is writable. -/
theorem Mem.write_of_check {m : Mem} {w : Who} {a : Nat} {p : Ptr} {al : Option Nat}
    {blk : Block} {o : Nat} {bs : List MemByte} (hc : m.check l w a p bs.length al = .ok (blk, o))
    (hr : blk.readOnly = false) : m.write l w a p bs al = .ok (m.set p.block (blk.put o bs)) := by
  simp [write, hc, hr, bind, Except.bind, pure, Except.pure]

/-- Lookup: a load of type `t` from element `i` of a block that holds `x` returns `enc (x i)`,
when the block is live, its owner admits the thread and the address is aligned. -/
theorem Mem.load_holds {m : Mem} {b : Nat} {blk : Block} (hb : m.blocks b = some blk)
    (h : blk.Holds l t enc off x) (hl : blk.live = true) {w : Who}
    (hw : blk.owner.admits w = true) (i : Shape.Coord s) {a ad : Nat} {al : Option Nat}
    (ha : m.addr l a ⟨b, off i⟩ = .ok ad) (hal : ∀ k ∈ al, ad % k = 0) :
    m.load l w a t ⟨b, off i⟩ al = .ok (enc (x i)) := by
  have hc := Mem.check_ok (n := l.stored t) hb hl hw (by simp)
    (by show ((off i : Nat) : Int) + _ ≤ _; exact_mod_cast (h i).1) ha hal
  exact Mem.load_of_check hc (by simpa using (h i).2)

/-- The `n` bytes at offset `o` of a block made from `init` are `init`'s slice there, when they lie
in `init`. -/
theorem read_alloc (init : List MemByte) {o n : Nat} (h : o + n ≤ init.length) :
    (List.range n).map (fun i => init.getD (o + i) .undef) = Layout.slice init o n := by
  apply List.ext_getElem (by simp [Layout.slice]; omega)
  intro k hk _
  simp only [List.length_map, List.length_range] at hk
  simp [Layout.slice, show o + k < init.length by omega]

/-- Construction: the block `Mem.alloc` makes with `tensorBytes` holds `x` row-major. -/
theorem Mem.holds_alloc (hc : l.Codec t enc) (x : Tensor α s) (m : Mem)
    (space align : Nat) (live readOnly : Bool) (owner : Owner) (addr gaddr : Nat) :
    let r := m.alloc l space (Shape.size s * l.size t) align live readOnly owner addr gaddr
      (tensorBytes l t enc x)
    r.1.Holds l r.2 t enc (rowMajor l t 0) x := by
  intro r
  obtain ⟨out, ho, hol, hk⟩ :=
    Layout.encodeAll_spec hc (l.stored_le_size t) (List.ofFn x.getFlat)
  have hbytes : tensorBytes l t enc x = out := by
    rw [List.map_ofFn] at ho
    show (l.encode (.arr _ t) (.agg (List.ofFn (enc ∘ x.getFlat)))).getD [] = out
    simp [Layout.encode, ho]
  refine ⟨_, ite_eq_left rfl, fun i => ?_⟩
  have hi := (Shape.Coord.linearize i).isLt
  have hle := rowMajor_inb l t 0 i
  simp only [rowMajor, Nat.zero_add, List.length_ofFn] at hol hk hle ⊢
  refine ⟨hle, ?_⟩
  simp only [Block.read, hbytes, ByteTree.bytesOf_eq]
  rw [read_alloc out (by rw [hol]; exact hle)]
  simpa [Tensor.Rep.get] using hk _ hi

end MojoProof.Sem
