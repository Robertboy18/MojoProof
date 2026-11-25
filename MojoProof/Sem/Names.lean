import MojoProof.Sem.Schedule

/-!
# The numbers that values and memory name

The parts of the closed-grid invariant (MojoProof/Sem/Closed.lean) about values and memory. A
number is *known* to a memory (`Mem.Known`) if it is below `next` or has a block. A known number
with no block is below `next` (`Mem.Known.below`), and a memory that keeps every block of another
(`Mem.Keeps`) knows every number the other knows (`Mem.Keeps.known`). `Mem.BytesIn S m`: every
pointer byte below the size of a block of `m` names a number of `S`.

Values (section Values): a lemma per operation, here and, for casts and `getelementptr`, in
MojoProof/Sem/Schedule.lean: its result names only numbers its operands name, or none.

The memory (section Memory), for every layout: if `S` has null's number 0, a load from a memory
with `Mem.BytesIn S` gives a value that names only numbers of `S` (`Mem.load_namesIn`, by
`decode_namesIn`). A store of a value that names only numbers of `S` keeps `Mem.BytesIn S`
(`Mem.store_bytesIn`, by `encode_namesIn`), and so do an allocation whose initial bytes name only
numbers of `S` and changes of liveness (`Mem.alloc_bytesIn`, `Mem.foldl_setLive_bytesIn`). The
number of an allocation's block is known after it (`Mem.alloc_known`).

`Mem.Known` and `Mem.BytesIn` are defined in MojoProof/Sem/SigDef.lean, with `sig`, which
reaches them.
-/

namespace MojoProof.Sem

open FloatLib.Floats.Formats.BinaryInterchange LLVM

section Values

variable {S T : Nat → Prop}

/-- A value that names only numbers of `S` names only numbers of every `T` that has every
number of `S`. -/
theorem Val.NamesIn.mono (h : ∀ b, S b → T b) : ∀ {v : Val}, v.NamesIn S → v.NamesIn T
  | .ptr _, hv => h _ hv
  | .vec _, hv | .agg _, hv =>
    Val.allNamesIn_iff.2 fun x hx => Val.NamesIn.mono h (Val.allNamesIn_iff.1 hv x hx)
  | .bits .., _ | .poison, _ | .undef, _ => trivial

/-- An integer operation (`intBin`) that succeeds gives a value that names no number: it
names only numbers of every `S`. -/
theorem intBin_namesIn {w : Nat} {op : BinOp} {fl : IntFlags} {x y v : Val}
    (h : intBin w op fl x y = .ok v) : v.NamesIn S := by
  simp only [intBin, intBits, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at h
  repeat' split at h
  all_goals cases h
  all_goals trivial

/-- A float operation (`floatBin`) that succeeds gives a value that names no number: it names
only numbers of every `S`. -/
theorem floatBin_namesIn {t : FloatTy} {op : FBinOp} {fm : FastMath} {x y v : Val}
    {px py : Option (Val × Val)} {n : Nat} (h : floatBin t op fm x y px py n = .ok v) :
    v.NamesIn S := by
  simp only [floatBin, bind, Except.bind, pure, Except.pure, throw, throwThe,
    MonadExceptOf.throw] at h
  repeat' split at h
  all_goals cases h
  all_goals trivial

/-- `lanes2 F` (`F` lane by lane on two vectors, or `F 0` on two other values) that succeeds
on operands that name only numbers of `S` gives a value that does, if every result of `F` on such
operands does. -/
theorem lanes2_namesIn {F : Nat → Val → Val → Except Fault Val}
    (hF : ∀ i x y w, F i x y = .ok w → x.NamesIn S → y.NamesIn S → w.NamesIn S) {x y z : Val}
    (h : lanes2 F x y = .ok z) (hx : x.NamesIn S) (hy : y.NamesIn S) : z.NamesIn S := by
  unfold lanes2 at h
  split at h
  · simp only [Functor.map, Except.map, throw, throwThe, MonadExceptOf.throw] at h
    split at h
    · split at h
      · cases h
      · cases h
        refine Val.allNamesIn_iff.2 (mapM_mem ‹_› fun p hm w hw => ?_)
        obtain ⟨⟨u, v⟩, i⟩ := p
        have hm' := List.of_mem_zip (List.fst_mem_of_mem_zipIdx hm)
        exact hF i u v w hw (Val.allNamesIn_iff.1 hx u hm'.1) (Val.allNamesIn_iff.1 hy v hm'.2)
    · cases h
  · exact hF 0 _ _ _ h hx hy

/-- `strict2 F` (a fault on undef, poison on poison, `F` otherwise) that succeeds on operands
that name only numbers of `S` gives a value that does, if every result of `F` on such operands
does. -/
theorem strict2_namesIn {F : Val → Val → Except Fault Val}
    (hF : ∀ x y w, F x y = .ok w → x.NamesIn S → y.NamesIn S → w.NamesIn S) {x y w : Val}
    (h : strict2 F x y = .ok w) (hx : x.NamesIn S) (hy : y.NamesIn S) : w.NamesIn S := by
  unfold strict2 at h
  split at h
  all_goals first | (cases h; done) | (cases h; trivial) | exact hF _ _ _ h hx hy

/-- `floats2 t f` (`f` on two floats of type `t`, through `strict2`) that succeeds on operands
that name only numbers of `S` gives a value that does, if every value of `f` does. -/
theorem floats2_namesIn {t : FloatTy} {f : Model t.fmt → Model t.fmt → Val}
    (hf : ∀ a b, (f a b).NamesIn S) {x y w : Val} (h : floats2 t f x y = .ok w)
    (hx : x.NamesIn S) (hy : y.NamesIn S) : w.NamesIn S :=
  strict2_namesIn (fun x y w h _ _ => by
    simp only [pure, Except.pure] at h
    split at h
    · cases h
      exact hf _ _
    · cases h) h hx hy

/-- An `icmp` (`icmpV`) that succeeds on operands that name only numbers of `S` gives a value
that does. -/
theorem icmpV_namesIn {l : Layout} {m : Mem} {p : ICmp} {t : Ty} {x y v : Val}
    (h : icmpV l m p t x y = .ok v) (hx : x.NamesIn S) (hy : y.NamesIn S) : v.NamesIn S := by
  unfold icmpV at h
  refine lanes2_namesIn (fun i x y w hw hx hy => ?_) h hx hy
  refine strict2_namesIn (fun x y w hw _ _ => ?_) hw hx hy
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hw
  repeat' split at hw
  all_goals cases hw
  all_goals trivial

/-- An `fcmp` (`fcmpV`) that succeeds on operands that name only numbers of `S` gives a value
that does. -/
theorem fcmpV_namesIn {fm : FastMath} {p : FCmp} {t : Ty} {x y v : Val}
    (h : fcmpV fm p t x y = .ok v) (hx : x.NamesIn S) (hy : y.NamesIn S) : v.NamesIn S := by
  simp only [fcmpV, bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · refine lanes2_namesIn (fun i x y w hw hx hy => ?_) h hx hy
      refine floats2_namesIn (fun a b => ?_) hw hx hy
      split <;> trivial
    · cases h

/-- An `fneg` (`fnegV`) that succeeds on an operand that names only numbers of `S` gives a value
that does. -/
theorem fnegV_namesIn {fm : FastMath} {t : Ty} {x v : Val} (h : fnegV fm t x = .ok v)
    (hx : x.NamesIn S) : v.NamesIn S := by
  simp only [fnegV, bind, Except.bind] at h
  split at h
  · cases h
  · split at h
    · refine lanes_namesIn (fun i u w hw _ => ?_) hx h
      simp only [pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hw
      repeat' split at hw
      all_goals cases hw
      all_goals trivial
    · cases h

/-- A `select` (`selectV`) that succeeds, with two choices that name only numbers of `S`, gives
a value that does, for every condition. -/
theorem selectV_namesIn {t : Ty} {c a b v : Val} (h : selectV t c a b = .ok v)
    (ha : a.NamesIn S) (hb : b.NamesIn S) : v.NamesIn S := by
  have pick : ∀ {c a b : Val} {ty : Ty} {w : Val}, selectV.pick c a b ty = .ok w →
      a.NamesIn S → b.NamesIn S → w.NamesIn S := by
    intro c a b ty w h ha hb
    simp only [selectV.pick, pure, Except.pure] at h
    split at h
    · cases h
      split
      · exact ha
      · exact hb
    · cases h
      exact fill_namesIn (x := .poison) trivial _
    all_goals cases h
  unfold selectV at h
  split at h
  · simp only [Functor.map, Except.map, throw, throwThe, MonadExceptOf.throw] at h
    split at h
    · split at h
      · cases h
      · cases h
        refine Val.allNamesIn_iff.2 (mapM_mem ‹_› fun q hq w hw => ?_)
        obtain ⟨c, a, b⟩ := q
        have h1 := List.of_mem_zip hq
        have h2 := List.of_mem_zip h1.2
        exact pick hw (Val.allNamesIn_iff.1 ha _ h2.1) (Val.allNamesIn_iff.1 hb _ h2.2)
    · cases h
  · exact pick h ha hb

/-- An `extractvalue` (`extractV`) that succeeds on a value that names only numbers of `S`
gives a value that does. -/
theorem extractV_namesIn : ∀ {v w : Val} {is : List Nat}, extractV v is = .ok w → v.NamesIn S →
    w.NamesIn S
  | _, _, [], h, hv => by
    cases h
    exact hv
  | .agg xs, w, i :: is, h, hv => by
    simp only [extractV] at h
    split at h
    · exact extractV_namesIn h (Val.allNamesIn_iff.1 hv _ (List.mem_of_getElem? ‹_›))
    · cases h
  | .bits .., _, _ :: _, h, _ | .ptr _, _, _ :: _, h, _ | .poison, _, _ :: _, h, _
  | .undef, _, _ :: _, h, _ | .vec _, _, _ :: _, h, _ => by cases h

/-- An `insertvalue` (`insertV`) that succeeds, of a value that names only numbers of `S` into
one that does, gives a value that does. -/
theorem insertV_namesIn : ∀ {v e w : Val} {is : List Nat}, insertV v e is = .ok w →
    v.NamesIn S → e.NamesIn S → w.NamesIn S
  | _, _, _, [], h, _, he => by
    cases h
    exact he
  | .agg xs, e, w, i :: is, h, hv, he => by
    simp only [insertV, bind, Except.bind, pure, Except.pure] at h
    split at h
    · rename_i x hx
      split at h
      · cases h
      · rename_i r hr
        cases h
        simp only [Val.NamesIn, Val.allNamesIn_iff]
        intro y hy
        rcases List.mem_or_eq_of_mem_set hy with hy | rfl
        · exact Val.allNamesIn_iff.1 hv y hy
        · exact insertV_namesIn hr (Val.allNamesIn_iff.1 hv x (List.mem_of_getElem? hx)) he
    · cases h
  | .bits .., _, _, _ :: _, h, _, _ | .ptr _, _, _, _ :: _, h, _, _
  | .poison, _, _, _ :: _, h, _, _ | .undef, _, _, _ :: _, h, _, _
  | .vec _, _, _, _ :: _, h, _, _ => by cases h

/-- Member `k` of `xs`, or `d` if there is none, names only numbers of `S` if every member of
`xs` and `d` do. -/
theorem getD_namesIn {xs : List Val} {d : Val} (hxs : ∀ x ∈ xs, x.NamesIn S) (hd : d.NamesIn S)
    (k : Nat) : (xs[k]?.getD d).NamesIn S := by
  cases hx : xs[k]? with
  | none => exact hd
  | some x => exact hxs x (List.mem_of_getElem? hx)

/-- An `extractelement` (`extractE`) that succeeds on a vector that names only numbers of `S`
gives a value that does, for every index. -/
theorem extractE_namesIn {t : Ty} {v i w : Val} (h : extractE t v i = .ok w) (hv : v.NamesIn S) :
    w.NamesIn S := by
  unfold extractE at h
  split at h
  · cases h
    exact getD_namesIn (Val.allNamesIn_iff.1 hv) (fill_namesIn (x := .poison) trivial _) _
  · cases h
    exact fill_namesIn (x := .poison) trivial _
  · cases h

/-- An `insertelement` (`insertE`) that succeeds, of a value that names only numbers of `S`
into a vector that does, gives a value that does, for every index. -/
theorem insertE_namesIn {t : Ty} {v e i w : Val} (h : insertE t v e i = .ok w)
    (hv : v.NamesIn S) (he : e.NamesIn S) : w.NamesIn S := by
  unfold insertE at h
  split at h
  · cases h
    split
    · simp only [Val.NamesIn, Val.allNamesIn_iff]
      intro y hy
      rcases List.mem_or_eq_of_mem_set hy with hy | rfl
      · exact Val.allNamesIn_iff.1 hv y hy
      · exact he
    · exact fill_namesIn (x := .poison) trivial _
  · cases h
    exact fill_namesIn (x := .poison) trivial _
  · cases h

/-- A `shufflevector` (`shuffleV`) that succeeds on two vectors that name only numbers of `S`
gives a value that does, for every mask. -/
theorem shuffleV_namesIn {t : Ty} {a b k w : Val} (h : shuffleV t a b k = .ok w)
    (ha : a.NamesIn S) (hb : b.NamesIn S) : w.NamesIn S := by
  unfold shuffleV at h
  split at h
  · simp only [Functor.map, Except.map] at h
    split at h
    · cases h
    · cases h
      refine Val.allNamesIn_iff.2 (mapM_mem ‹_› fun q _ w hw => ?_)
      simp only [pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hw
      split at hw
      · cases hw
        refine getD_namesIn (fun x hx => ?_) (fill_namesIn (x := .poison) trivial _) _
        rcases List.mem_append.1 hx with hx | hx
        · exact Val.allNamesIn_iff.1 ha x hx
        · exact Val.allNamesIn_iff.1 hb x hx
      all_goals cases hw
      all_goals exact fill_namesIn (x := .poison) trivial _
  · cases h

/-- A value that names only numbers of `S`, under attributes (`withAttrs`), gives a value that
does, if it succeeds. -/
theorem withAttrs_namesIn {l : Layout} {m : Mem} {t : Ty} {attrs : List Attr} {v w : Val}
    (h : withAttrs l m t attrs v = .ok w) (hv : v.NamesIn S) : w.NamesIn S := by
  simp only [withAttrs, bind, Except.bind, pure, Except.pure, Functor.map, Except.map] at h
  repeat' split at h
  all_goals cases h
  all_goals first
    | cases ‹throw _ = Except.ok _›
    | (refine foldlM_inv (P := fun r : Val => r.NamesIn S) (fun b a b' hs hb => ?_) _ _ ‹_› hv
       repeat' split at hs
       all_goals cases hs
       all_goals first | exact hb | trivial)
    | (rename_i hl _
       split at hl
       · cases hl
       · cases hl
         refine Val.allNamesIn_iff.2 (mapM_mem ‹_› fun x hx y hy => ?_)
         refine foldlM_inv (P := fun r => r.NamesIn S) (fun b a b' hs hb => ?_) _ _ hy
           (Val.allNamesIn_iff.1 hv x hx)
         repeat' split at hs
         all_goals cases hs
         all_goals first | exact hb | trivial)

/-- A signed or unsigned integer minimum or maximum (`intMinMax`) that succeeds on operands that
name only numbers of `S` gives a value that does. -/
theorem intMinMax_namesIn {signed max : Bool} {x y v : Val} (h : intMinMax signed max x y = .ok v)
    (hx : x.NamesIn S) (hy : y.NamesIn S) : v.NamesIn S :=
  strict2_namesIn (fun x y w hw _ _ => by
    simp only [pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hw
    repeat' split at hw
    all_goals cases hw
    all_goals trivial) h hx hy

/-- An `atomicrmw` update (`rmw`) that succeeds on a value and an operand that name only numbers
of `S` gives a value that does. -/
theorem rmw_namesIn {w : Nat} {op : RmwOp} {x y v : Val} (h : rmw w op x y = .ok v)
    (hx : x.NamesIn S) (hy : y.NamesIn S) : v.NamesIn S := by
  cases op <;> simp only [rmw] at h
  all_goals first | exact intBin_namesIn h | exact intMinMax_namesIn h hx hy | cases h

/-- Every value that `Option.mapM` returns is a result of the function on the option's value. -/
theorem Option.mapM_namesIn {α : Type} {F : α → Except Fault Val} {v : Option α} {w : Option Val}
    (h : v.mapM F = .ok w) (hF : ∀ x, v = some x → ∀ y, F x = .ok y → y.NamesIn S) :
    ∀ y, w = some y → y.NamesIn S := by
  cases v with
  | none =>
    simp only [Option.mapM_none, pure, Except.pure, Except.ok.injEq] at h
    subst h
    intro y hy
    cases hy
  | some x =>
    simp only [Option.mapM_some, Functor.map, Except.map] at h
    split at h
    · cases h
    · cases h
      rintro y ⟨⟩
      exact hF x rfl _ ‹_›

end Values

section Memory

variable {S T : Nat → Prop}

/-- A memory that keeps every block of `m` knows every number `m` knows. -/
theorem Mem.Keeps.known {m m' : Mem} (h : m.Keeps m') : ∀ b, m.Known b → m'.Known b := by
  rintro b (hb | hb)
  · left
    rw [h.next]
    exact hb
  · right
    obtain ⟨x, hx⟩ := Option.isSome_iff_exists.1 hb
    have := h.blocks b x hx
    cases hy : m'.blocks b <;> simp_all

/-- A known number with no block is below `next`. -/
theorem Mem.Known.below {m : Mem} {b : Nat} (h : m.Known b) (hn : m.blocks b = none) :
    b < m.next :=
  h.resolve_right (by simp [hn])

/-- If every pointer byte of `m` names a number of `S` (below the size of its block), it names
a number of every `T` that has every number of `S`. -/
theorem Mem.BytesIn.mono {m : Mem} (h : ∀ b, S b → T b) (hm : m.BytesIn S) : m.BytesIn T :=
  fun c b i p j hc hi hp => h _ (hm c b i p j hc hi hp)

/-- A scalar decoded from bytes (`Layout.scalarOf`) names no number: it names only numbers of
every `S`. -/
theorem scalarOf_namesIn {w : Nat} {bs : List MemByte} {v : Val}
    (h : Layout.scalarOf w bs = some v) : v.NamesIn S := by
  unfold Layout.scalarOf at h
  split at h
  · cases h
    trivial
  · split at h
    · cases h
      trivial
    · obtain ⟨n, -, rfl⟩ := Option.map_eq_some_iff.1 h
      split <;> trivial

/-- A pointer decoded from bytes (`Layout.ptrOf`) names only numbers of `S` if `S` has null's
number 0 and the block of every pointer byte of the bytes. -/
theorem ptrOf_namesIn (h0 : S 0) {bs : List MemByte}
    (hbs : ∀ p j, MemByte.ptr p j ∈ bs → S p.block) {v : Val} (h : Layout.ptrOf bs = some v) :
    v.NamesIn S := by
  unfold Layout.ptrOf at h
  split at h
  · cases h
    trivial
  · split at h
    · cases h
      trivial
    · split at h
      · split at h
        · cases h
          exact hbs _ 0 List.mem_cons_self
        · cases h
      · split at h
        · cases h
          exact h0
        · cases h

/-- For every decoder `dec` that names only blocks of `S` on bytes whose pointer bytes are of `S`,
and every count, stride and offset: the values `Layout.decodeAll` decodes from such bytes name
only blocks of `S`. -/
theorem decodeAll_namesIn {dec : List MemByte → Option Val} {k : Nat}
    (ht : ∀ bs v, (∀ p j, MemByte.ptr p j ∈ bs → S p.block) → dec bs = some v →
      v.NamesIn S) :
    ∀ (n stride o : Nat) {bs : List MemByte} {xs : List Val},
      (∀ p j, MemByte.ptr p j ∈ bs → S p.block) → Layout.decodeAll dec k n stride o bs = some xs →
        Val.AllNamesIn S xs
  | 0, _, _, _, _, _, h => by
    simp only [Layout.decodeAll, Option.some.injEq] at h
    subst h
    trivial
  | n + 1, stride, o, bs, xs, hb, h => by
    simp only [Layout.decodeAll, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨x, hx, rest, hr, rfl⟩ := h
    exact ⟨ht _ _ (fun p j hp => hb p j (List.mem_of_mem_drop (List.mem_of_mem_take hp))) hx,
      decodeAll_namesIn ht n stride _ hb hr⟩

/-- For every layout and field types `fs` each of whose decodings names only blocks of `S` on
bytes whose pointer bytes are of `S`, and every offset: the fields `Layout.decodeFields` decodes
from such bytes name only blocks of `S`. -/
theorem decodeFields_namesIn {l : Layout} :
    ∀ {fs : List Ty}, (∀ t ∈ fs, ∀ bs v, (∀ p j, MemByte.ptr p j ∈ bs → S p.block) →
      l.decode t bs = some v → v.NamesIn S) →
    ∀ (off : Nat) {bs : List MemByte} {xs : List Val}, (∀ p j, MemByte.ptr p j ∈ bs → S p.block) →
      l.decodeFields off fs bs = some xs → Val.AllNamesIn S xs
  | [], _, _, _, _, _, h => by
    simp only [Layout.decodeFields, Option.some.injEq] at h
    subst h
    trivial
  | t :: ts, ht, off, bs, xs, hb, h => by
    simp only [Layout.decodeFields, Option.bind_eq_bind, Option.bind_eq_some_iff,
      Option.pure_def, Option.some.injEq] at h
    obtain ⟨x, hx, rest, hr, rfl⟩ := h
    exact ⟨ht t List.mem_cons_self _ _
      (fun p j hp => hb p j (List.mem_of_mem_drop (List.mem_of_mem_take hp))) hx,
      decodeFields_namesIn (fun t' h' => ht t' (List.mem_cons_of_mem _ h')) _ hb hr⟩

/-- A value decoded from bytes whose pointers name numbers of `S` names only numbers of `S`. -/
theorem decode_namesIn (l : Layout) (h0 : S 0) : ∀ (t : Ty) {bs : List MemByte} {v : Val},
    (∀ p j, MemByte.ptr p j ∈ bs → S p.block) → l.decode t bs = some v → v.NamesIn S
  | .int _, _, _, _, h => scalarOf_namesIn (by simpa only [Layout.decode] using h)
  | .fp _, _, _, _, h => scalarOf_namesIn (by simpa only [Layout.decode] using h)
  | .ptr _, _, _, hb, h => ptrOf_namesIn h0 hb (by simpa only [Layout.decode] using h)
  | .vec n t, _, _, hb, h => by
    simp only [Layout.decode] at h
    split at h
    · obtain ⟨xs, hxs, rfl⟩ := Option.map_eq_some_iff.1 h
      exact decodeAll_namesIn (fun _ _ => decode_namesIn l h0 t) _ _ _ hb hxs
    · cases h
  | .arr n t, _, _, hb, h => by
    simp only [Layout.decode] at h
    obtain ⟨xs, hxs, rfl⟩ := Option.map_eq_some_iff.1 h
    exact decodeAll_namesIn (fun _ _ => decode_namesIn l h0 t) _ _ _ hb hxs
  | .struct fs, _, _, hb, h => by
    simp only [Layout.decode] at h
    obtain ⟨xs, hxs, rfl⟩ := Option.map_eq_some_iff.1 h
    exact decodeFields_namesIn (fun t _ _ _ => decode_namesIn l h0 t) _ hb hxs
  | .void, _, _, _, h | .label, _, _, _, h | .metadata, _, _, _, h => by
    simp [Layout.decode] at h

/-- For every layout and type `t` whose encoding of a value that names only numbers of `S` has
pointer bytes only to blocks of `S`: the bytes that `Layout.encodeAll` gives for values that name
only numbers of `S`, at every stride, have pointer bytes only to blocks of `S`. -/
theorem encodeAll_namesIn {l : Layout} {t : Ty}
    (ht : ∀ v bs, l.encode t v = some bs → v.NamesIn S → ∀ p j, MemByte.ptr p j ∈ bs →
      S p.block) :
    ∀ {xs : List Val} {stride : Nat} {bs : List MemByte}, l.encodeAll t xs stride = some bs →
      Val.AllNamesIn S xs → ∀ p j, MemByte.ptr p j ∈ bs → S p.block
  | [], _, bs, h, _, p, j, hp => by
    simp only [Layout.encodeAll, Option.some.injEq] at h
    subst h
    simp at hp
  | x :: xs, stride, bs, h, ⟨hx, hxs⟩, p, j, hp => by
    simp only [Layout.encodeAll, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
      Option.some.injEq] at h
    obtain ⟨b, hb, rest, hr, rfl⟩ := h
    simp only [List.mem_append, List.mem_replicate, reduceCtorEq, and_false, or_false] at hp
    rcases hp with hp | hp
    · exact ht x b hb hx p j hp
    · exact encodeAll_namesIn ht hr hxs p j hp

/-- For every layout and field types `fs` each of whose encodings of a value that names only
numbers of `S` has pointer bytes only to blocks of `S`: the bytes that `Layout.encodeFields` gives
for fields that name only numbers of `S`, at every offset, have pointer bytes only to blocks of
`S`. -/
theorem encodeFields_namesIn {l : Layout} :
    ∀ {fs : List Ty}, (∀ t ∈ fs, ∀ v bs, l.encode t v = some bs → v.NamesIn S →
      ∀ p j, MemByte.ptr p j ∈ bs → S p.block) →
    ∀ {off : Nat} {xs : List Val} {bs : List MemByte}, l.encodeFields off fs xs = some bs →
      Val.AllNamesIn S xs → ∀ p j, MemByte.ptr p j ∈ bs → S p.block
  | [], _, off, xs, bs, h, _, p, j, hp => by
    cases xs <;> simp [Layout.encodeFields] at h
    subst h
    simp at hp
  | t :: ts, ht, off, xs, bs, h, hxs, p, j, hp => by
    cases xs with
    | nil => simp [Layout.encodeFields] at h
    | cons x xs =>
      simp only [Layout.encodeFields, Option.bind_eq_bind, Option.bind_eq_some_iff,
        Option.pure_def, Option.some.injEq] at h
      obtain ⟨b, hb, rest, hr, rfl⟩ := h
      obtain ⟨hx, hxs⟩ := hxs
      simp only [List.mem_append, List.mem_replicate, reduceCtorEq, and_false, or_false,
        false_or] at hp
      rcases hp with hp | hp
      · exact ht t List.mem_cons_self _ _ hb hx p j hp
      · exact encodeFields_namesIn (fun t' h' => ht t' (List.mem_cons_of_mem _ h')) hr hxs p j
          hp

/-- The bytes of a value that names only numbers of `S` hold pointers only to numbers of `S`. -/
theorem encode_namesIn (l : Layout) : ∀ (t : Ty) {v : Val} {bs : List MemByte},
    l.encode t v = some bs → v.NamesIn S → ∀ p j, MemByte.ptr p j ∈ bs → S p.block
  | .vec n t, v, bs, h, hv, p, j, hp => by
    cases v
    case vec xs =>
      simp only [Layout.encode] at h
      split at h
      · exact encodeAll_namesIn (fun _ _ => encode_namesIn l t) h hv p j hp
      · cases h
    case poison | undef => simp [Layout.encode] at h; subst h; simp at hp
    all_goals simp [Layout.encode] at h
  | .arr n t, v, bs, h, hv, p, j, hp => by
    cases v
    case agg xs =>
      simp only [Layout.encode] at h
      split at h
      · exact encodeAll_namesIn (fun _ _ => encode_namesIn l t) h hv p j hp
      · cases h
    case poison | undef => simp [Layout.encode] at h; subst h; simp at hp
    all_goals simp [Layout.encode] at h
  | .struct fs, v, bs, h, hv, p, j, hp => by
    cases v
    case agg xs =>
      simp only [Layout.encode, Option.map_eq_some_iff] at h
      obtain ⟨b, hb, rfl⟩ := h
      simp only [List.mem_append, List.mem_replicate, reduceCtorEq, and_false, or_false] at hp
      exact encodeFields_namesIn (fun t _ _ _ => encode_namesIn l t) hb hv p j hp
    case poison | undef => simp [Layout.encode] at h; subst h; simp at hp
    all_goals simp [Layout.encode] at h
  | .int w, v, bs, h, _, p, j, hp | .fp w, v, bs, h, _, p, j, hp => by
    cases v
    case bits w' b =>
      simp only [Layout.encode] at h
      split at h
      · simp only [Option.some.injEq] at h
        subst h
        simp [leBytes] at hp
      · cases h
    case poison | undef => simp [Layout.encode] at h; subst h; simp at hp
    all_goals simp [Layout.encode] at h
  | .ptr a, v, bs, h, hv, p, j, hp => by
    cases v
    case ptr q =>
      simp only [Layout.encode, Option.some.injEq] at h
      subst h
      obtain ⟨i, -, he⟩ := List.mem_map.1 hp
      cases he
      exact hv
    case poison | undef => simp [Layout.encode] at h; subst h; simp at hp
    all_goals simp [Layout.encode] at h
  | .void, v, bs, h, _, p, j, hp | .label, v, bs, h, _, p, j, hp
  | .metadata, v, bs, h, _, p, j, hp => by
    cases v <;> simp [Layout.encode] at h <;> (subst h; simp at hp)

/-- A check of an access of `n` bytes that succeeds gives a block and an offset `o` with
`o + n` at most the block's size. -/
theorem Mem.check_size {l : Layout} {m : Mem} {w : Who} {a n : Nat} {p : Ptr} {al : Option Nat}
    {b : Block} {o : Nat} (h : m.check l w a p n al = .ok (b, o)) : o + n ≤ b.size := by
  cases hb : m.blocks p.block with
  | none => simp [Mem.check, Mem.block, hb] at h
  | some b' =>
    simp only [Mem.check, Mem.block, hb, bind, Except.bind, pure, Except.pure] at h
    repeat' split at h
    all_goals first | cases ‹throw _ = Except.ok _› | (cases h; omega) | cases h

/-- If `S` has null's number 0, a load from a memory whose pointer bytes name numbers of `S`
gives a value that names only numbers of `S`. -/
theorem Mem.load_namesIn (h0 : S 0) {m : Mem} (hm : m.BytesIn S) {l : Layout} {w : Who}
    {a : Nat} {t : Ty} {p : Ptr} {al : Option Nat} {v : Val} (h : m.load l w a t p al = .ok v) :
    v.NamesIn S := by
  unfold Mem.load at h
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at h
  split at h
  · cases h
  · rename_i r hc
    obtain ⟨b, o⟩ := r
    dsimp only at h
    split at h
    · cases h
      refine decode_namesIn l h0 t (fun q j hq => ?_) ‹_›
      obtain ⟨i, hi, he⟩ := List.mem_map.1 hq
      have := Mem.check_size hc
      have := List.mem_range.1 hi
      exact hm _ _ _ q j (Mem.check_block hc).1 (by omega) he
    · cases h

/-- If `l.getD k d` (member `k` of `l`, or `d`) is `x` and `x` is not `d`, then `x` is a
member of `l`. -/
theorem mem_of_getD {α : Type} {l : List α} {k : Nat} {d x : α} (h : l.getD k d = x)
    (hx : x ≠ d) : x ∈ l := by
  rw [List.getD_eq_getElem?_getD] at h
  cases hk : l[k]? with
  | none =>
    simp only [hk, Option.getD_none] at h
    exact absurd h.symm hx
  | some y =>
    simp only [hk, Option.getD_some] at h
    subst h
    exact List.mem_of_getElem? hk

/-- Setting block `b` of a memory with `Mem.BytesIn S` to a block whose pointer bytes below its
size name numbers of `S` keeps `Mem.BytesIn S`. -/
theorem Mem.set_bytesIn {m : Mem} (hm : m.BytesIn S) {b : Nat} {blk : Block}
    (hblk : ∀ i p j, i < blk.size → blk.bytes i = .ptr p j → S p.block) :
    (m.set b blk).BytesIn S := by
  intro c x i p j hc hi hp
  simp only [Mem.set] at hc
  split at hc
  · cases hc
    exact hblk i p j hi hp
  · exact hm c x i p j hc hi hp

/-- A write that succeeds, of bytes whose pointer bytes name numbers of `S`, to a memory with
`Mem.BytesIn S`, keeps `Mem.BytesIn S`. -/
theorem Mem.write_bytesIn {m m' : Mem} {l : Layout} {w : Who} {a : Nat} {p : Ptr}
    {bs : List MemByte} {al : Option Nat} (h : m.write l w a p bs al = .ok m') (hm : m.BytesIn S)
    (hbs : ∀ p j, MemByte.ptr p j ∈ bs → S p.block) : m'.BytesIn S := by
  unfold Mem.write at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  split at h
  · cases h
  · rename_i r hc
    obtain ⟨b, o⟩ := r
    dsimp only at h
    split at h
    · cases h
    · cases h
      refine Mem.set_bytesIn hm (fun i q j hi hq => ?_)
      simp only [Block.put] at hi hq
      split at hq
      · exact hbs q j (mem_of_getD hq (by simp))
      · exact hm _ _ i q j (Mem.check_block hc).1 hi hq

/-- A store of a value that names only numbers of `S` keeps that every pointer byte names a
number of `S`. -/
theorem Mem.store_bytesIn {m m' : Mem} {l : Layout} {w : Who} {a : Nat} {t : Ty} {v : Val}
    {p : Ptr} {al : Option Nat} {op : Option RmwOp} (h : m.store l w a t v p al op = .ok m')
    (hm : m.BytesIn S) (hv : v.NamesIn S) : m'.BytesIn S := by
  unfold Mem.store at h
  cases hbs : l.encode t v with
  | none => simp [hbs] at h
  | some bs =>
    simp only [hbs, bind, Except.bind, pure, Except.pure] at h
    split at h
    · cases h
    · cases h
      have := Mem.write_bytesIn ‹_› hm (encode_namesIn l t hbs hv)
      exact this

/-- Making a block live (with undefined bytes) or dead keeps `Mem.BytesIn S`. -/
theorem Mem.setLive_bytesIn {m : Mem} (hm : m.BytesIn S) (b : Nat) (live : Bool) :
    (m.setLive b live).BytesIn S := by
  unfold Mem.setLive
  split
  · rename_i blk hb
    refine Mem.set_bytesIn hm (fun i p j hi hp => ?_)
    cases live
    · simp only [Bool.false_eq_true, ↓reduceIte] at hp
      exact hm b blk i p j hb hi hp
    · simp at hp
  · exact hm

/-- `P` holds after a left fold over `xs` if it holds at the start and every step on a member of
`xs` with `Q` keeps it. -/
theorem foldl_inv {α β : Type} {f : β → α → β} {P : β → Prop} {Q : α → Prop}
    (hP : ∀ b a, Q a → P b → P (f b a)) :
    ∀ (xs : List α) (b : β), (∀ a ∈ xs, Q a) → P b → P (xs.foldl f b)
  | [], _, _, hb => hb
  | a :: xs, b, hq, hb =>
    foldl_inv hP xs (f b a) (fun x hx => hq x (List.mem_cons_of_mem a hx))
      (hP b a (hq a List.mem_cons_self) hb)

/-- Making each block of `bs` live or dead in turn keeps `Mem.BytesIn S`. -/
theorem Mem.foldl_setLive_bytesIn {m : Mem} (hm : m.BytesIn S) (bs : List Nat) (live : Bool) :
    (bs.foldl (fun m b => m.setLive b live) m).BytesIn S :=
  foldl_inv (P := Mem.BytesIn S) (Q := fun _ => True) (fun _ b _ h => Mem.setLive_bytesIn h b live)
    bs m (fun _ _ => trivial) hm

/-- An allocation with initial bytes whose pointer bytes name numbers of `S`, on a memory with
`Mem.BytesIn S`, keeps `Mem.BytesIn S`, for every layout, space, size, alignment, flags, owner,
addresses and number. -/
theorem Mem.alloc_bytesIn {m : Mem} (hm : m.BytesIn S) {init : List MemByte}
    (hinit : ∀ p j, MemByte.ptr p j ∈ init → S p.block) (l : Layout)
    (space size align : Nat) (live readOnly : Bool) (owner : Owner) (addr gaddr : Nat)
    (num : Option Nat) :
    (m.alloc l space size align live readOnly owner addr gaddr init num).1.BytesIn S := by
  unfold Mem.alloc
  cases num <;> exact Mem.set_bytesIn hm (fun i p j _ hp => hinit p j (mem_of_getD
    (show init.getD i .undef = .ptr p j by simpa only [ByteTree.bytesOf_eq] using hp) (by simp)))

/-- The number of an allocation's block is known in the memory after it. -/
theorem Mem.alloc_known (l : Layout) (m : Mem) (space size align : Nat) (live readOnly : Bool)
    (owner : Owner) (addr gaddr : Nat) (init : List MemByte) (num : Option Nat) :
    (m.alloc l space size align live readOnly owner addr gaddr init num).1.Known
      (m.alloc l space size align live readOnly owner addr gaddr init num).2 := by
  unfold Mem.alloc
  cases num <;> simp [Mem.Known, Mem.set]

end Memory

end MojoProof.Sem
