import MojoProof.Sem.Schedule
import MojoProof.Sem.Rel

/-!
# Values, memories and grids equal but for payload (T3b's relations)

The relations of docs/proofs/payload.md section T3b, for a set `pay` of payload blocks:

- `Val.Skel`: two values are equal after `Val.erase`, which replaces every data word by the zero
  word of its width, through vectors and aggregates: equal but for their data words, at any depth;
- `MemByte.Skel`: two bytes are equal after `MemByte.erase`: equal, or both data bytes;
- `Block.SkelEq`: two blocks are equal in every field but `bytes`, and their bytes are
  payload-related, and equal if the block is not payload;
- `Mem.SkelEq`: two memories have one `next` and one trace, and at every number both have no block
  or related blocks;
- for a labelling `lab` (`Labels`, the payload registers of each function), `Frame.Skel`: two
  frames are equal but for their registers and the operands of their `fmul contract` results,
  which are payload-related at the payload registers and equal at the others; `Thread.Skel`: two
  threads have one step count and frames related pairwise; `Status.Skel`: two statuses have one
  constructor, related threads, and, waiting, one intrinsic and declaration and arguments that
  are equal, or equal after `Intrinsic.eraseArgs` (which erases a shuffle's exchanged value) if
  the call's result register is payload (`Thread.payRes`);
- `Grid.SkelRel`: two grids have statuses related at every number and memories related by
  `Mem.SkelEq`.

`Val.Skel` is reflexive and symmetric (`Val.Skel.refl`, `Val.Skel.symm`), and so are `Mem.SkelEq`,
for every set of payload blocks (`Mem.SkelEq.refl`, `Mem.SkelEq.symm`), `Thread.Skel` and
`Status.Skel`, for every labelling (`Thread.Skel.refl`, `Thread.Skel.symm`, `Status.Skel.refl`,
`Status.Skel.symm`), and `Grid.SkelRel`, for both (`Grid.SkelRel.refl`, `Grid.SkelRel.symm`).

The lemmas about `Option.Rel`, `Except.Rel` and `List.Forall₂` used below, for every relation,
are in MojoProof/Sem/Rel.lean.

The memory operations respect `Mem.SkelEq`, for every layout, set of payload blocks and pair of
related memories (`Except.Rel R`: one fault, or results related by `R`):
- `Layout.encode_erase`: for every type and value, the bytes of a value, erased, are those of the
  value erased; `Layout.decode_erase`: for every data type (`Ty.data`: integers of whole bytes and
  floats, through vectors, arrays and structs) and at most `l.stored t` bytes, the value they
  hold, erased, is that of the bytes erased;
- `Mem.set_skel`, `Mem.log_skel`, `Mem.alloc_skel`, `Mem.setLive_skel`: setting related blocks
  at one number, recording an event, an allocation (which gives one block number) and setting a
  block live or dead give related memories; `Mem.foldl_setLive_skel`: so does setting the blocks
  of one list live or dead in turn (a return's cleanup of its frame's `allocas`);
- `Mem.check_skel`: an access check gives one fault, or related blocks at one offset;
- `Mem.load_skel`: a load gives one fault, or related values, equal if the block is not payload,
  if the type is a data type when the block is payload;
- `Mem.store_skel`: a store of related values, equal if the block is not payload, gives one fault
  or related memories.

Evaluating an operand reads the registers only at those it mentions, and no oracle number, since
a constant expression casts only as LangRef admits (`evalV_regs`, `castV_ch`). So for every
scope, type, two oracles and set `p` of registers, with related memories and registers equal
outside `p`, an operand that mentions no register of `p` (`Value.mentions p`) gives one result,
and so do a typed operand and a list of them (`evalV_skel`; `Val.namesIn_top` gives
`evalV_shape`'s premise for all block numbers).

For all lane functions that give related results on related lanes, two oracle numbers allowed,
`lanes` on related values gives related results (`lanes_skel`, by `Except.Rel.mapM`,
`Except.Rel.bind`, `Except.Rel.map`, `List.Forall₂.zipIdx`, and `Val.skel_vec`: a value related to
a vector is a vector related to it lane by lane), and so does
`lanes2` with two-operand lane functions, also with second operands that must be equal
(`lanes2_skel`, with `List.Forall₂.zip`). `intCast` is such a function, for every cast and width
(`intCast_skel`), and so is `intBin`, for every width and every operator and flags of `Op.Total`
(`BinOp.total`), the second operand equal if the operator reads its value (`BinOp.skelB`: a shift
amount or a divisor; `intBin_skel`). `icmpV` on related values gives related results for every
layout, predicate and type and memories related for some set of payload blocks (`icmpV_skel`, by
`Mem.addr_shape` and `Except.Rel.refl`); so do `floatBin` on scalars, for every float type and
operator, any factors and two oracle numbers, and `fcmpV` and `fnegV`, for every predicate and
type, all with flags without `nnan` and `ninf` (`floatBin_skel`, `fcmpV_skel`, which is by
`floats2_skel`, `fnegV_skel`).

The other value instructions on related values give related results: `selectV`, for every type
and condition (`selectV_skel`); `extractE` and `insertE` (with related elements), for every type
and index, and `shuffleV`, for every type and mask (`extractE_skel`, `insertE_skel`,
`shuffleV_skel`, by `List.Forall₂.getElem?`, `List.Forall₂.set` and `Option.Rel.getD`);
`extractV` and `insertV` (with related elements), for every list of indices (`extractV_skel`,
`insertV_skel`, by `Val.skel_agg`); and `castV`, for every layout, cast and two types, any oracle
numbers and memories related for some set of payload blocks (`castV_skel`, by `floatCast_skel`,
`intToFloat_skel`, `bitcast_skel`, which is by `toBitList_skel` and `ofBitList_skel`, and
`Mem.addr_shape`).

The `maxnum` and `minnum` intrinsic calls on related values, for every type, two contexts and two
scopes, and flags without `nnan` and `ninf`, give one fault, or two results with related values
that leave the scopes' memories unchanged (`fminmax_skel`, by `floats2_skel`, `withFlags_some` and
`Val.ofFloat_skel`); so does `rsqrt.approx`, whatever its operand's word and the two choices
(`rsqrt_skel`, by the definitions of `withFlags` and `FastMath.poisons`).

The parameter and return attributes on related values, for every layout, type and list of
attributes, memories related for some set of payload blocks, and no `range` attribute or equal
values, give one fault, or related values (`withAttrs_skel`, by `Except.Rel.foldlM`,
`Val.Skel.defined`, which is by `Val.defined_erase`, and `Mem.addr_shape`).

T3b (`Grid.skel_lockstep`), under which the skeleton relation is a lockstep bisimulation between
two payloads with one address choice, is proved in MojoProof/Sem/SkelStep.lean.

Instances in MojoProofTest/Skeleton.lean:
- `skel_vals`: two aggregates whose data words differ, inside a vector with a pointer lane and
  outside, are related, and two pointers to different blocks, words of two widths, or a word and
  `poison` are not;
- `skel_pay`: two memories that differ in a data byte of block 1 are related when block 1 is
  payload, and not when it is not;
- `skel_thread`: two threads that differ in a data word of register 0 are related when register 0
  is payload, and not when it is not;
- `skel_grid`: two grids of such threads and memories are related; two threads waiting at a
  shuffle whose exchanged values differ are related when its result register is payload, and not
  when it is not, nor when their lane operands differ;
- `decode_twins`, `load_skel`, `store_skel`: the twins of the two premises of
  `Layout.decode_erase` (an `i1` from a data byte, not `Ty.data`, and an `i8` from more than
  `l.stored t` bytes, erased, differ from the values of the bytes erased) and of `Ty.data` in
  `Mem.load_skel` (the `i1` loads from `memX 1` and `memX 2` are not related), an instance of
  `Mem.load_skel` and of `Mem.store_skel`, and the twin of the premise that the stored values are
  equal when the block is not payload;
- `alloc_skel`: the instances of `Mem.alloc_skel` and `Mem.setLive_skel` on `memX 1` and
  `memX 2`;
- `eval_skel`: the instance of `evalV_skel` (with two oracles), and the twin of its premise that
  the registers the operand mentions are equal; `fpext_twin`: why operands must be oracle-free
  (the `fpext` instruction of a NaN gives two words under two oracle numbers), and that the same
  `fpext` as a constant expression, which LangRef does not allow, is refused;
- `trunc_skel`: the instance of `lanes_skel` with `intCast_skel`, and the twin of its premise: a
  lane function that makes `poison` of the word 1 gives results that are not related;
- `pair_skel`: the instance of `lanes2_skel`, and the twin of its premise;
- `bin_skel`: the instance of `intBin_skel` with `lanes2_skel` (`add` of related vectors, `shl`
  of related vectors by one amount), and the twins of its premises: `or disjoint` of related
  words gives a word and `poison`, `sdiv` of related words by -1 faults and gives a word
  (`BinOp.total`), and `shl` of one vector by two amounts gives a word lane and a `poison` lane
  (`BinOp.skelB`);
- `icmp_skel`: the instance of `icmpV_skel` (on words and on pointers), and the twins of its
  premises: a pointer comparison faults on a memory with no block 1 and gives `true` on `memX 1`,
  and `icmp eq` of an `i8` gives `true` with an `i8` and faults with an `i16`;
- `float_skel`: the instances of `floatBin_skel` (a NaN result under two oracle numbers),
  `fcmpV_skel` and `fnegV_skel`, and the twins of their premises: with `nnan`, a NaN operand
  gives `poison` and 0 a word; with `ninf`, likewise an infinite operand;
- `select_skel`: the instance of `selectV_skel`, and the twin of its premise that the two
  conditions are one: `true` and `false` select results that are not related;
- `elem_skel`, `shuffle_skel`, `value_skel`: the instances of `extractE_skel`, `insertE_skel`,
  `shuffleV_skel`, `extractV_skel` and `insertV_skel`, and the twins of their premises that the
  two indices, masks or index lists are one: two of them give results that are not related;
- `cast_skel`: the instances of `castV_skel` (`fpext` under two oracle numbers, `bitcast` and
  `ptrtoint`), and the twin of its premise that the memories are related: `ptrtoint` faults on a
  memory with no block 1 and gives a word on `memX 1`;
- `maxnum_skel`: the instance of `fminmax_skel`, and the twins of its premises that the flags have
  no `nnan` and no `ninf`: with `nnan`, a NaN operand gives `poison` and 0 a word; with `ninf`,
  likewise an infinite operand;
- `approx_skel`: the instance of `rsqrt_skel` (1 and 4 under two oracle numbers give the words of
  1 and 0.5), and the twins of its premises on the flags: with `nnan`, `rsqrt.approx` of -1 gives
  `poison` and of 1 a word; with `ninf`, likewise `+0`;
- `attrs_skel`: the instances of `withAttrs_skel` (`noundef` on related words, `nonnull` on a
  pointer), and the twin of its premise that no attribute is a `range` or the values are equal:
  `range i8 0, 2` gives a word on the word 1 and `poison` on the word 2;
- `addr_twin`, the twin of T3b's premise that the two runs have one address choice
  (two runs whose address choices differ): from one grid, thread 0's `alloca` under contexts that
  differ only in the address choices gives memories that are not related, for every set of payload
  blocks.
-/

namespace MojoProof.LLVM

mutual
  /-- Whether the values of type `t` are data words only, at any depth: its scalars are integers
  of whole bytes or floats (no pointers, no `i1`). -/
  def Ty.data : Ty → Bool
    | .int w => w % 8 == 0
    | .fp _ => true
    | .vec _ t | .arr _ t => t.data
    | .struct fs => Ty.dataAll fs
    | _ => false

  /-- `Ty.data` of each type. -/
  def Ty.dataAll : List Ty → Bool
    | [] => true
    | t :: ts => t.data && Ty.dataAll ts
end

/-- Whether integer operator `op` with flags `fl` is in `Op.Total` (docs/proofs/payload.md, (O3)):
no flag, and not `sdiv` or `srem` (which fault on the minimum divided by -1, reading both
operands). -/
def BinOp.total (op : BinOp) (fl : IntFlags) : Bool := fl == {} && op != .sdiv && op != .srem

/-- Whether `Op.Total` requires the second operand of integer operator `op` to be skeleton: the
shifts (an amount of at least the width gives `poison`), `udiv` and `urem` (a divisor of 0
faults). -/
def BinOp.skelB : BinOp → Bool
  | .shl | .lshr | .ashr | .udiv | .urem => true
  | _ => false

end MojoProof.LLVM

namespace MojoProof.Sem

mutual
  /-- `v` with every data word replaced by the zero word of its width, through vectors and
  aggregates: what the skeleton sees of a value. -/
  def Val.erase : Val → Val
    | .bits w _ => .bits w 0
    | .vec xs => .vec (Val.eraseAll xs)
    | .agg xs => .agg (Val.eraseAll xs)
    | v => v

  /-- `Val.erase` on each value. -/
  def Val.eraseAll : List Val → List Val
    | [] => []
    | x :: xs => x.erase :: Val.eraseAll xs
end

/-- Payload-related values: equal but for their data words, which have one width. Pointers,
`poison` and `undef` are equal; vectors and aggregates are related element by element, at any
depth. -/
def Val.Skel (x y : Val) : Prop := x.erase = y.erase

/-- Every value is payload-related to itself. -/
theorem Val.Skel.refl (x : Val) : x.Skel x := rfl

/-- For every two values, the relation is symmetric. -/
theorem Val.Skel.symm {x y : Val} (h : x.Skel y) : y.Skel x := Eq.symm h

/-- For every value, its erasure is defined (`Val.defined`: no `poison` or `undef`, at any depth)
exactly when the value is. -/
theorem Val.defined_erase (v : Val) : v.erase.defined = v.defined :=
  Val.rec (motive_1 := fun v => v.erase.defined = v.defined)
    (motive_2 := fun xs => Val.allDefined (Val.eraseAll xs) = Val.allDefined xs)
    (fun _ _ => rfl) (fun _ => rfl) rfl rfl
    (fun _ h => by simp only [Val.erase, Val.defined, h])
    (fun _ h => by simp only [Val.erase, Val.defined, h]) rfl
    (fun _ _ h₁ h₂ => by simp only [Val.eraseAll, Val.allDefined, h₁, h₂]) v

/-- Related values are both defined or both not. -/
theorem Val.Skel.defined {x y : Val} (h : x.Skel y) : x.defined = y.defined := by
  rw [← Val.defined_erase x, h, Val.defined_erase]

/-- A data byte becomes the zero byte; the others stay. -/
def MemByte.erase : MemByte → MemByte
  | .byte _ => .byte 0
  | b => b

/-- Payload-related bytes: equal after `MemByte.erase`, that is equal or both data bytes. -/
def MemByte.Skel (b₁ b₂ : MemByte) : Prop := b₁.erase = b₂.erase

/-- Blocks equal in every field but `bytes`, whose bytes are payload-related, and equal unless
`p` (the block is payload). -/
structure Block.SkelEq (p : Prop) (B₁ B₂ : Block) : Prop where
  /-- Builds `Block.SkelEq` from its three fields. -/
  mk ::
  /-- The blocks are equal in every field but `bytes`. -/
  shape : { B₁ with bytes := fun _ => .undef } = { B₂ with bytes := fun _ => .undef }
  /-- The bytes at each offset are payload-related. -/
  bytes : ∀ i, (B₁.bytes i).Skel (B₂.bytes i)
  /-- Unless the block is payload, the bytes are equal. -/
  same : ¬ p → ∀ i, B₁.bytes i = B₂.bytes i

/-- Memories equal but for the data bytes of the blocks `pay`: one `next`, one trace, and at every
number both no block or blocks related by `Block.SkelEq`. -/
structure Mem.SkelEq (pay : Nat → Prop) (m₁ m₂ : Mem) : Prop where
  /-- Builds `Mem.SkelEq` from its three fields. -/
  mk ::
  /-- One `next`. -/
  next : m₁.next = m₂.next
  /-- One trace. -/
  trace : m₁.trace = m₂.trace
  /-- At every number, both no block or blocks related by `Block.SkelEq`. -/
  blocks : ∀ b, Option.Rel (Block.SkelEq (pay b)) (m₁.blocks b) (m₂.blocks b)

/-- For every set of payload blocks, every memory is related to itself. -/
theorem Mem.SkelEq.refl (pay : Nat → Prop) (m : Mem) : m.SkelEq pay m where
  next := rfl
  trace := rfl
  blocks _ := .refl (fun _ => ⟨rfl, fun _ => rfl, fun _ _ => rfl⟩) _

/-- For every set of payload blocks, the relation is symmetric. -/
theorem Mem.SkelEq.symm {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) :
    m₂.SkelEq pay m₁ where
  next := h.next.symm
  trace := h.trace.symm
  blocks b := (h.blocks b).symm fun hB =>
    ⟨hB.shape.symm, fun i => (hB.bytes i).symm, fun hp i => (hB.same hp i).symm⟩

/-- A labelling: the payload registers of each function (by name), and whether its result is
payload. -/
structure Labels where
  /-- Builds a labelling from its payload registers and results. -/
  mk ::
  /-- `reg f r`: whether register `r` of the function named `f` is payload. -/
  reg : String → Nat → Bool
  /-- `ret f`: whether the result of the function named `f` is payload. -/
  ret : String → Bool

/-- `R` on a payload register (`p`), equality on the others. -/
def Labels.Rel {α : Type} (p : Bool) (R : α → α → Prop) (x y : α) : Prop :=
  if p then R x y else x = y

/-- Frames equal in every field but `regs` and `prods`, whose registers and operands of
`fmul contract` results are payload-related at the payload registers of the function and equal at
the others. -/
structure Frame.Skel (lab : Labels) (f₁ f₂ : Frame) : Prop where
  /-- Builds `Frame.Skel` from its three fields. -/
  mk ::
  /-- The frames are equal in every field but `regs` and `prods`. -/
  shape : { f₁ with regs := fun _ => none, prods := fun _ => none } =
    { f₂ with regs := fun _ => none, prods := fun _ => none }
  /-- Each register is unset in both, or set in both to values payload-related at a payload
  register and equal at the others. -/
  regs : ∀ r, Option.Rel (Labels.Rel (lab.reg f₁.fn.name r) Val.Skel) (f₁.regs r) (f₂.regs r)
  /-- The same for the operands of `fmul contract` results, component by component. -/
  prods : ∀ r, Option.Rel (Labels.Rel (lab.reg f₁.fn.name r) fun a b => a.1.Skel b.1 ∧ a.2.Skel b.2)
    (f₁.prods r) (f₂.prods r)

/-- Threads with one step count and frames related pairwise by `Frame.Skel`. -/
structure Thread.Skel (lab : Labels) (t₁ t₂ : Thread) : Prop where
  /-- Builds `Thread.Skel` from its two fields. -/
  mk ::
  /-- One step count. -/
  k : t₁.k = t₂.k
  /-- As many frames, related pairwise by `Frame.Skel`. -/
  frames : List.Forall₂ (Frame.Skel lab) t₁.frames t₂.frames

/-- `Labels.Rel` of a reflexive relation is reflexive. -/
theorem Labels.Rel.refl {α : Type} {R : α → α → Prop} (hR : ∀ x, R x x) (p : Bool) (x : α) :
    Labels.Rel p R x x := by
  cases p
  · exact rfl
  · exact hR x

/-- `Labels.Rel` of a symmetric relation is symmetric. -/
theorem Labels.Rel.symm {α : Type} {R : α → α → Prop} {p : Bool} {x y : α}
    (h : Labels.Rel p R x y) (hR : ∀ {x y}, R x y → R y x) : Labels.Rel p R y x := by
  cases p
  · exact Eq.symm h
  · exact hR h

/-- For every labelling, every thread is related to itself. -/
theorem Thread.Skel.refl (lab : Labels) (t : Thread) : t.Skel lab t where
  k := rfl
  frames := List.forall₂_same.2 fun _ _ =>
    ⟨rfl, fun _ => .refl (Labels.Rel.refl Val.Skel.refl _) _,
      fun _ => .refl (Labels.Rel.refl (fun a => ⟨.refl a.1, .refl a.2⟩) _) _⟩

/-- For every labelling, the relation is symmetric. -/
theorem Thread.Skel.symm {lab : Labels} {t₁ t₂ : Thread} (h : t₁.Skel lab t₂) : t₂.Skel lab t₁ where
  k := h.k.symm
  frames := by
    have hf := h.frames
    generalize t₁.frames = l₁ at hf ⊢
    generalize t₂.frames = l₂ at hf ⊢
    induction hf with
    | nil => exact .nil
    | @cons f₁ f₂ _ _ hF _ ih =>
      have e : f₂.fn.name = f₁.fn.name := congrArg (·.fn.name) hF.shape.symm
      refine .cons ⟨hF.shape.symm, fun r => ?_, fun r => ?_⟩ ih
      · rw [e]
        exact (hF.regs r).symm fun h => h.symm Val.Skel.symm
      · rw [e]
        exact (hF.prods r).symm fun h => h.symm fun h => ⟨h.1.symm, h.2.symm⟩

/-- Whether the statement thread `t` is at has a payload result register under `lab` (the
register `Thread.resume` sets). -/
def Thread.payRes (lab : Labels) (t : Thread) : Bool :=
  match t.frames with
  | f :: _ => (((f.fn.blocks.find? (·.label == f.label)).bind fun b =>
      b.stmts[f.pc]?.bind (·.res)).map (lab.reg f.fn.name)).getD false
  | [] => false

/-- Related threads are at statements whose results are both payload or both not. -/
theorem Thread.Skel.payRes {lab : Labels} {t₁ t₂ : Thread} (h : t₁.Skel lab t₂) :
    t₁.payRes lab = t₂.payRes lab := by
  have hf := h.frames
  unfold Thread.payRes
  generalize t₁.frames = l₁ at hf ⊢
  generalize t₂.frames = l₂ at hf ⊢
  cases hf with
  | nil => rfl
  | @cons f₁ f₂ _ _ hF _ =>
    have e₁ : f₁.fn = f₂.fn := congrArg (·.fn) hF.shape
    have e₂ : f₁.label = f₂.label := congrArg (·.label) hF.shape
    have e₃ : f₁.pc = f₂.pc := congrArg (·.pc) hF.shape
    simp only [e₁, e₂, e₃]

/-- What the skeleton sees of the arguments of a waiting call to `i`: a shuffle's exchanged value
(its second argument) erased by `Val.erase`, the other arguments as they are. They decide which
threads take part and which lane each reads, so they are skeleton. -/
def _root_.MojoProof.LLVM.Intrinsic.eraseArgs : LLVM.Intrinsic → List Val → List Val
  | .shfl _, m :: a :: r => m :: a.erase :: r
  | _, xs => xs

/-- Statuses with one constructor: running threads related by `Thread.Skel`; waiting threads
related by `Thread.Skel`, at one intrinsic and declaration, with arguments equal after
`Intrinsic.eraseArgs` if the call's result is payload (`Thread.payRes`) and equal if not; or two
returned threads. -/
def Status.Skel (lab : Labels) : Status → Status → Prop
  | .run t₁, .run t₂ => t₁.Skel lab t₂
  | .wait t₁ i₁ a₁ f₁, .wait t₂ i₂ a₂ f₂ =>
    t₁.Skel lab t₂ ∧ i₁ = i₂ ∧ f₁ = f₂ ∧
      Labels.Rel (t₁.payRes lab) (fun a b => i₁.eraseArgs a = i₁.eraseArgs b) a₁ a₂
  | .done, .done => True
  | _, _ => False

/-- For every labelling, every status is related to itself. -/
theorem Status.Skel.refl (lab : Labels) : ∀ s : Status, s.Skel lab s
  | .run t => Thread.Skel.refl lab t
  | .wait t _ _ _ => ⟨.refl lab t, rfl, rfl, by cases t.payRes lab <;> exact rfl⟩
  | .done => trivial

/-- For every labelling, the relation on statuses is symmetric. -/
theorem Status.Skel.symm {lab : Labels} {s₁ s₂ : Status} (h : s₁.Skel lab s₂) :
    s₂.Skel lab s₁ := by
  cases s₁ <;> cases s₂ <;> simp only [Status.Skel] at h ⊢
  · exact h.symm
  · obtain ⟨ht, rfl, rfl, e⟩ := h
    exact ⟨ht.symm, rfl, rfl, ht.payRes ▸ e.symm Eq.symm⟩

/-- The skeleton relation on grids (T3b in docs/proofs/payload.md): grids whose threads are
related by `Status.Skel lab` at every number (so they have as many threads) and whose memories are
related by `Mem.SkelEq pay`. -/
structure Grid.SkelRel (lab : Labels) (pay : Nat → Prop) (g₁ g₂ : Grid) : Prop where
  /-- Builds `Grid.SkelRel` from its two fields. -/
  mk ::
  /-- At every number, both no thread or threads related by `Status.Skel`. -/
  threads : ∀ n : Nat, Option.Rel (Status.Skel lab) g₁.threads[n]? g₂.threads[n]?
  /-- The memories are related by `Mem.SkelEq`. -/
  mem : g₁.mem.SkelEq pay g₂.mem

/-- For every labelling and set of payload blocks, every grid is related to itself. -/
theorem Grid.SkelRel.refl (lab : Labels) (pay : Nat → Prop) (g : Grid) : g.SkelRel lab pay g :=
  ⟨fun _ => .refl (Status.Skel.refl lab) _, .refl pay g.mem⟩

/-- For every labelling and set of payload blocks, the relation is symmetric. -/
theorem Grid.SkelRel.symm {lab : Labels} {pay : Nat → Prop} {g₁ g₂ : Grid}
    (h : g₁.SkelRel lab pay g₂) : g₂.SkelRel lab pay g₁ :=
  ⟨fun n => (h.threads n).symm Status.Skel.symm, h.mem.symm⟩

open LLVM


/-- `Val.eraseAll` is `Val.erase` on each value. -/
theorem Val.eraseAll_eq (xs : List Val) : Val.eraseAll xs = xs.map Val.erase := by
  induction xs with
  | nil => rfl
  | cons x xs ih => exact congrArg (x.erase :: ·) ih

/-- For every layout and type whose values' bytes, erased, are those of the values erased, so
are the bytes of every list of values at every stride. -/
theorem Layout.encodeAll_erase {l : Layout} {t : Ty}
    (ht : ∀ v, (l.encode t v).map (·.map MemByte.erase) =
      (l.encode t v.erase).map (·.map MemByte.erase)) :
    ∀ (xs : List Val) (stride : Nat), (l.encodeAll t xs stride).map (·.map MemByte.erase) =
      (l.encodeAll t (xs.map Val.erase) stride).map (·.map MemByte.erase)
  | [], _ => by simp only [List.map_nil]
  | x :: xs, stride => by
    simp only [Layout.encodeAll, List.map_cons]
    refine Option.map_bind_bind (ht x) (encodeAll_erase ht xs stride) fun hb hr => ?_
    have e := congrArg List.length hb
    simp only [List.length_map] at e
    simp only [List.map_append, hb, hr, e]

/-- For every layout and fields whose values' bytes, erased, are those of the values erased, so
are the bytes of every list of field values from every offset. -/
theorem Layout.encodeFields_erase {l : Layout} :
    ∀ {fs : List Ty}, (∀ t ∈ fs, ∀ v, (l.encode t v).map (·.map MemByte.erase) =
      (l.encode t v.erase).map (·.map MemByte.erase)) →
    ∀ (off : Nat) (xs : List Val), (l.encodeFields off fs xs).map (·.map MemByte.erase) =
      (l.encodeFields off fs (xs.map Val.erase)).map (·.map MemByte.erase)
  | [], _, _, xs => by cases xs <;> simp [Layout.encodeFields]
  | t :: ts, ht, off, [] => by simp [Layout.encodeFields]
  | t :: ts, ht, off, x :: xs => by
    simp only [Layout.encodeFields, List.map_cons]
    refine Option.map_bind_bind (ht t List.mem_cons_self x)
      (encodeFields_erase (fun t' h' => ht t' (List.mem_cons_of_mem _ h')) _ xs) fun hb hr => ?_
    have e := congrArg List.length hb
    simp only [List.length_map] at e
    simp only [List.map_append, hb, hr, e]

/-- For every layout, type and value, the bytes of a value, erased, are those of the value
erased (`none` for both or neither). -/
theorem Layout.encode_erase (l : Layout) : ∀ (t : Ty) (v : Val),
    (l.encode t v).map (·.map MemByte.erase) = (l.encode t v.erase).map (·.map MemByte.erase)
  | _, .poison | _, .undef | _, .ptr _ => rfl
  | t, .bits w b => by
    cases t <;> simp only [Val.erase, Layout.encode] <;> split <;>
      simp [leBytes, MemByte.erase, Function.comp_def, List.map_const']
  | t, .vec xs => by
    have hn : (Val.eraseAll xs).length = xs.length := by simp [Val.eraseAll_eq]
    cases t
    case vec n t =>
      simp only [Val.erase, Layout.encode, hn]
      split
      · rw [Val.eraseAll_eq]
        exact encodeAll_erase (fun v => encode_erase l t v) xs 0
      · rfl
    all_goals simp [Val.erase, Layout.encode]
  | t, .agg xs => by
    have hn : (Val.eraseAll xs).length = xs.length := by simp [Val.eraseAll_eq]
    cases t
    case arr n t =>
      simp only [Val.erase, Layout.encode, hn]
      split
      · rw [Val.eraseAll_eq]
        exact encodeAll_erase (fun v => encode_erase l t v) xs _
      · rfl
    case struct fs =>
      simp only [Val.erase, Layout.encode, Option.map_map, Val.eraseAll_eq]
      have h := encodeFields_erase (fs := fs) (fun t _ v => encode_erase l t v) 0 xs
      generalize l.encodeFields 0 fs xs = a at h ⊢
      generalize l.encodeFields 0 fs (xs.map Val.erase) = a' at h ⊢
      cases a <;> cases a' <;> simp_all [MemByte.erase]
    all_goals simp [Val.erase, Layout.encode]

/-- A scalar of `w` bits from at most `w / 8` bytes, erased, is that of the bytes erased. -/
theorem Layout.scalarOf_erase {w : Nat} {bs : List MemByte} (h : 8 * bs.length ≤ w) :
    (scalarOf w bs).map Val.erase = (scalarOf w (bs.map MemByte.erase)).map Val.erase := by
  have hc : ∀ b : MemByte, (b = .poison ∨ b = .undef) →
      (bs.map MemByte.erase).contains b = bs.contains b := by
    clear h
    rintro b (rfl | rfl) <;> induction bs with
      | nil => rfl
      | cons a bs ih => cases a <;> simp_all [MemByte.erase]
  have ho : ofLeBytes (bs.map MemByte.erase) = (ofLeBytes bs).map fun _ => 0 := by
    clear h hc
    induction bs with
    | nil => rfl
    | cons a bs ih =>
      cases a <;> simp [ofLeBytes, MemByte.erase, ih, Option.map_map, Function.comp_def]
  have hl : ∀ {n}, ofLeBytes bs = some n → n < 2 ^ w := by
    intro n hn
    refine lt_of_lt_of_le ?_ (Nat.pow_le_pow_right (by decide) h)
    clear h hc ho
    induction bs generalizing n with
    | nil => cases hn; simp
    | cons a bs ih =>
      cases a <;> simp only [ofLeBytes, Option.map_eq_some_iff, reduceCtorEq] at hn
      obtain ⟨m, hm, rfl⟩ := hn
      have h1 := ih hm
      have h2 : (‹BitVec 8›).toNat < 256 := (‹BitVec 8›).isLt
      rw [List.length_cons, Nat.mul_add_one, Nat.pow_add, show 2 ^ 8 = 256 from rfl]
      omega
  unfold scalarOf
  rw [hc _ (.inl rfl), hc _ (.inr rfl), ho]
  split_ifs
  · rfl
  · rfl
  · cases e : ofLeBytes bs with
    | none => rfl
    | some n => simp [hl e, Val.erase]

/-- For every decoder `dec` whose value of at most `k` bytes, erased, is that of the bytes
erased, so are the `n` elements it reads from `k` bytes each at every stride and offset of every
bytes. -/
theorem Layout.decodeAll_erase {dec : List MemByte → Option Val} {k : Nat}
    (ht : ∀ {bs : List MemByte}, bs.length ≤ k →
      (dec bs).map Val.erase = (dec (bs.map MemByte.erase)).map Val.erase) :
    ∀ (n stride o : Nat) (bs : List MemByte),
      (Layout.decodeAll dec k n stride o bs).map Val.eraseAll =
        (Layout.decodeAll dec k n stride o (bs.map MemByte.erase)).map Val.eraseAll
  | 0, _, _, _ => by simp only [Layout.decodeAll]
  | n + 1, stride, o, bs => by
    simp only [Layout.decodeAll, Layout.slice, ← List.map_drop, ← List.map_take]
    exact Option.map_bind_bind (ht (List.length_take_le _ _)) (decodeAll_erase ht n stride _ bs)
      fun hx hr => congrArg₂ List.cons hx hr

/-- For every layout and fields of data types (`Ty.dataAll`) whose values of at most their stored
size, erased, are those of the bytes erased, so are the field values from every offset of every
bytes. -/
theorem Layout.decodeFields_erase {l : Layout} :
    ∀ {fs : List Ty}, Ty.dataAll fs → (∀ t ∈ fs, t.data → ∀ {bs : List MemByte},
      bs.length ≤ l.stored t →
        (l.decode t bs).map Val.erase = (l.decode t (bs.map MemByte.erase)).map Val.erase) →
    ∀ (off : Nat) (bs : List MemByte), (l.decodeFields off fs bs).map Val.eraseAll =
      (l.decodeFields off fs (bs.map MemByte.erase)).map Val.eraseAll
  | [], _, _, _, _ => by simp only [Layout.decodeFields]
  | t :: ts, hd, ht, off, bs => by
    simp only [Ty.dataAll, Bool.and_eq_true] at hd
    simp only [Layout.decodeFields, Layout.slice, ← List.map_drop, ← List.map_take]
    exact Option.map_bind_bind (ht t List.mem_cons_self hd.1 (List.length_take_le _ _))
      (decodeFields_erase hd.2 (fun t' h' => ht t' (List.mem_cons_of_mem _ h')) _ bs)
      fun hx hr => congrArg₂ List.cons hx hr

/-- For every layout and data type (`Ty.data`), the value that at most `l.stored t` bytes hold,
erased, is that of the bytes erased (`none` for both or neither). -/
theorem Layout.decode_erase (l : Layout) : ∀ (t : Ty) {bs : List MemByte}, t.data →
    bs.length ≤ l.stored t →
      (l.decode t bs).map Val.erase = (l.decode t (bs.map MemByte.erase)).map Val.erase
  | .int w, bs, ht, hn => by
    simp only [Ty.data, beq_iff_eq] at ht
    simp only [Layout.stored, Layout.storeSize, Layout.scalarBits] at hn
    simp only [Layout.decode]
    exact scalarOf_erase (by omega)
  | .fp f, bs, _, hn => by
    have := f.bitWidth_mod
    simp only [Layout.stored, Layout.storeSize, Layout.scalarBits] at hn
    simp only [Layout.decode]
    exact scalarOf_erase (by omega)
  | .vec n t, bs, ht, _ => by
    simp only [Layout.decode]
    split
    · have h := decodeAll_erase (dec := l.decode t) (k := l.stored t)
        (fun {bs} hn => decode_erase l t (bs := bs) ht hn) n (l.scalarBits t / 8) 0 bs
      generalize Layout.decodeAll (l.decode t) (l.stored t) n _ 0 bs = a at h ⊢
      generalize Layout.decodeAll (l.decode t) (l.stored t) n _ 0 (bs.map MemByte.erase) = a'
        at h ⊢
      cases a <;> cases a' <;> simp_all [Val.erase]
    · rfl
  | .arr n t, bs, ht, _ => by
    simp only [Layout.decode]
    have h := decodeAll_erase (dec := l.decode t) (k := l.stored t)
      (fun {bs} hn => decode_erase l t (bs := bs) ht hn) n (l.size t) 0 bs
    generalize Layout.decodeAll (l.decode t) (l.stored t) n _ 0 bs = a at h ⊢
    generalize Layout.decodeAll (l.decode t) (l.stored t) n _ 0 (bs.map MemByte.erase) = a'
      at h ⊢
    cases a <;> cases a' <;> simp_all [Val.erase]
  | .struct fs, bs, ht, _ => by
    simp only [Layout.decode]
    have h := decodeFields_erase (fs := fs) ht (fun t _ ht' _ hn => decode_erase l t ht' hn) 0 bs
    generalize l.decodeFields 0 fs bs = a at h ⊢
    generalize l.decodeFields 0 fs (bs.map MemByte.erase) = a' at h ⊢
    cases a <;> cases a' <;> simp_all [Val.erase]
  | .void, _, ht, _ | .ptr _, _, ht, _ | .label, _, ht, _ | .metadata, _, ht, _ => nomatch ht

/-- For every set of payload blocks, related memories have blocks of one shape at every number. -/
theorem Mem.SkelEq.sameShape {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂)
    (S : Nat → Prop) : m₁.SameShape S m₂ :=
  fun b _ => (h.blocks b).map_eq fun hB => (congrArg Block.shape hB.shape :)

/-- For every set of payload blocks, related memories with related blocks set at one number are
related. -/
theorem Mem.set_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) {b : Nat}
    {B₁ B₂ : Block} (hB : B₁.SkelEq (pay b) B₂) : (m₁.set b B₁).SkelEq pay (m₂.set b B₂) where
  next := h.next
  trace := h.trace
  blocks c := by
    simp only [Mem.set]
    split
    · rename_i hc
      subst hc
      exact .some hB
    · exact h.blocks c

/-- For every set of payload blocks, related memories with one event recorded are related. -/
theorem Mem.log_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) (e : Event) :
    (m₁.log e).SkelEq pay (m₂.log e) :=
  ⟨h.next, congrArg (e :: ·) h.trace, h.blocks⟩

/-- For every set of payload blocks, an allocation in related memories gives related memories and
one block number. -/
theorem Mem.alloc_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) (l : Layout)
    (space size align : Nat) (live readOnly : Bool) (owner : Owner) (addr gaddr : Nat)
    (init : List MemByte) (num : Option Nat) :
    (m₁.alloc l space size align live readOnly owner addr gaddr init num).1.SkelEq pay
      (m₂.alloc l space size align live readOnly owner addr gaddr init num).1 ∧
    (m₁.alloc l space size align live readOnly owner addr gaddr init num).2 =
      (m₂.alloc l space size align live readOnly owner addr gaddr init num).2 := by
  have hB : ∀ (p : Prop) (B : Block), B.SkelEq p B := fun _ _ => ⟨rfl, fun _ => rfl, fun _ _ => rfl⟩
  cases num with
  | none =>
    refine ⟨?_, h.next⟩
    simp only [Mem.alloc]
    rw [← h.next]
    exact ⟨rfl, h.trace, (Mem.set_skel h (hB _ _)).blocks⟩
  | some b => exact ⟨Mem.set_skel h (hB _ _), rfl⟩

/-- For every set of payload blocks, setting a block live or dead in related memories gives
related memories. -/
theorem Mem.setLive_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) (b : Nat)
    (live : Bool) : (m₁.setLive b live).SkelEq pay (m₂.setLive b live) := by
  have hb := h.blocks b
  unfold Mem.setLive
  generalize m₁.blocks b = o₁ at hb ⊢
  generalize m₂.blocks b = o₂ at hb ⊢
  cases hb with
  | none => exact h
  | @some B₁ B₂ hB =>
    refine Mem.set_skel h ⟨(congrArg (fun B : Block => { B with live }) hB.shape :), fun i => ?_,
      fun hp i => ?_⟩
    · cases live
      · exact hB.bytes i
      · exact rfl
    · cases live
      · exact hB.same hp i
      · exact rfl

/-- For every set of payload blocks, list of block numbers and liveness, setting the blocks of the
list live or dead in turn (`List.foldl` of `Mem.setLive`, as a return does with its frame's
`allocas`) in related memories gives related memories. -/
theorem Mem.foldl_setLive_skel {pay : Nat → Prop} (bs : List Nat) (live : Bool) :
    ∀ {m₁ m₂ : Mem}, m₁.SkelEq pay m₂ → (bs.foldl (fun m b => m.setLive b live) m₁).SkelEq pay
      (bs.foldl (fun m b => m.setLive b live) m₂) := by
  induction bs with
  | nil => exact fun h => h
  | cons b bs ih => exact fun h => ih (Mem.setLive_skel h b live)

/-- For every set of payload blocks, an access check in related memories gives one fault, or
related blocks at one offset. -/
theorem Mem.check_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) (l : Layout)
    (w : Who) (a : Nat) (p : Ptr) (n : Nat) (al : Option Nat) :
    Except.Rel (fun r₁ r₂ => r₁.2 = r₂.2 ∧ r₁.1.SkelEq (pay p.block) r₂.1)
      (m₁.check l w a p n al) (m₂.check l w a p n al) := by
  have ha := Mem.addr_shape (h.sameShape fun _ => True) (p := p) trivial l a
  have hb := h.blocks p.block
  simp only [Mem.check, Mem.block, ha]
  generalize m₁.blocks p.block = o₁ at hb ⊢
  generalize m₂.blocks p.block = o₂ at hb ⊢
  cases hb with
  | none => exact .error _
  | @some B₁ B₂ hB =>
    have hl : B₁.live = B₂.live := (congrArg Block.live hB.shape :)
    have ho : B₁.owner = B₂.owner := (congrArg Block.owner hB.shape :)
    have hs : B₁.size = B₂.size := (congrArg Block.size hB.shape :)
    simp only [hl, ho, hs, bind, Except.bind, pure, Except.pure]
    repeat' split
    all_goals first | exact .error _ | exact .ok ⟨rfl, hB⟩

/-- For every set of payload blocks, a load from related memories gives one fault, or related
values, equal if the block is not payload; the type is a data type (`Ty.data`) if it is. -/
theorem Mem.load_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) {t : Ty} {p : Ptr}
    (ht : pay p.block → t.data) (l : Layout) (w : Who) (a : Nat) (al : Option Nat) :
    Except.Rel (fun v₁ v₂ => v₁.Skel v₂ ∧ (¬ pay p.block → v₁ = v₂))
      (m₁.load l w a t p al) (m₂.load l w a t p al) := by
  have hc := Mem.check_skel h l w a p (l.stored t) al
  simp only [Mem.load, bind, Except.bind]
  generalize m₁.check l w a p (l.stored t) al = c₁ at hc ⊢
  generalize m₂.check l w a p (l.stored t) al = c₂ at hc ⊢
  cases hc with
  | error e => exact .error e
  | @ok r₁ r₂ hr =>
    obtain ⟨B₁, o⟩ := r₁
    obtain ⟨B₂, o'⟩ := r₂
    obtain ⟨ho, hB⟩ := hr
    simp only at ho
    subst ho
    have hn : ∀ B : Block, (B.read o (l.stored t)).length ≤ l.stored t := fun B => by
      simp [Block.read]
    have hr : (B₁.read o (l.stored t)).map MemByte.erase =
        (B₂.read o (l.stored t)).map MemByte.erase := by
      simp only [Block.read, List.map_map]
      exact List.map_congr_left fun i _ => hB.bytes (o + i)
    have hs : ¬ pay p.block → B₁.read o (l.stored t) = B₂.read o (l.stored t) := fun hp => by
      simp only [Block.read]
      exact List.map_congr_left fun i _ => hB.same hp (o + i)
    have hd : (l.decode t (B₁.read o (l.stored t))).map Val.erase =
        (l.decode t (B₂.read o (l.stored t))).map Val.erase ∧
        (¬ pay p.block → l.decode t (B₁.read o (l.stored t)) = l.decode t (B₂.read o (l.stored t))) := by
      refine ⟨?_, fun hp => by rw [hs hp]⟩
      by_cases hp : pay p.block
      · rw [l.decode_erase t (ht hp) (hn B₁), l.decode_erase t (ht hp) (hn B₂), hr]
      · rw [hs hp]
    simp only
    generalize l.decode t (B₁.read o (l.stored t)) = d₁ at hd ⊢
    generalize l.decode t (B₂.read o (l.stored t)) = d₂ at hd ⊢
    cases d₁ <;> cases d₂ <;>
      simp only [Option.map_none, Option.map_some, reduceCtorEq, Option.some.injEq, false_and]
        at hd
    · exact .error _
    · exact .ok hd

/-- For every set of payload blocks, a store of related values, equal if the block is not
payload, to related memories gives one fault, or related memories. -/
theorem Mem.store_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (h : m₁.SkelEq pay m₂) {v₁ v₂ : Val}
    {p : Ptr} (hv : v₁.Skel v₂) (hp : ¬ pay p.block → v₁ = v₂) (l : Layout) (w : Who) (a : Nat)
    (t : Ty) (al : Option Nat) (op : Option RmwOp) :
    Except.Rel (Mem.SkelEq pay) (m₁.store l w a t v₁ p al op) (m₂.store l w a t v₂ p al op) := by
  have he : (l.encode t v₁).map (·.map MemByte.erase) =
      (l.encode t v₂).map (·.map MemByte.erase) := by
    rw [l.encode_erase t v₁, l.encode_erase t v₂, show v₁.erase = v₂.erase from hv]
  have hs : ¬ pay p.block → l.encode t v₁ = l.encode t v₂ := fun hn => by rw [hp hn]
  have hg : ∀ (bs : List MemByte) k,
      (bs.getD k .poison).erase = ((bs.map MemByte.erase)[k]?).getD .poison := fun bs k => by
    rw [List.getD_eq_getElem?_getD, List.getElem?_map]
    cases bs[k]? <;> rfl
  simp only [Mem.store, Mem.write, bind, Except.bind, pure, Except.pure]
  generalize l.encode t v₁ = e₁ at he hs ⊢
  generalize l.encode t v₂ = e₂ at he hs ⊢
  cases e₁ <;> cases e₂ <;>
    simp only [Option.map_none, Option.map_some, reduceCtorEq, Option.some.injEq] at he
  · exact .error _
  · rename_i bs₁ bs₂
    have hn : bs₁.length = bs₂.length := by simpa using congrArg List.length he
    have hc := Mem.check_skel h l w a p bs₂.length al
    simp only
    rw [hn]
    generalize m₁.check l w a p bs₂.length al = c₁ at hc ⊢
    generalize m₂.check l w a p bs₂.length al = c₂ at hc ⊢
    cases hc with
    | error e => exact .error e
    | @ok r₁ r₂ hr =>
      obtain ⟨B₁, o⟩ := r₁
      obtain ⟨B₂, o'⟩ := r₂
      obtain ⟨ho, hB⟩ := hr
      simp only at ho
      subst ho
      have hro : B₁.readOnly = B₂.readOnly := (congrArg Block.readOnly hB.shape :)
      simp only [hro]
      cases B₂.readOnly
      · refine .ok (Mem.log_skel (Mem.set_skel (B₁ := B₁.put o bs₁) (B₂ := B₂.put o bs₂) h
          ⟨hB.shape, fun i => ?_, fun hq i => ?_⟩) _)
        · simp only [MemByte.Skel, Block.put, hn]
          split
          · rw [hg, hg, he]
          · exact hB.bytes i
        · obtain rfl : bs₁ = bs₂ := Option.some.inj (hs hq)
          simp only [Block.put]
          split
          · rfl
          · exact hB.same hq i
      · exact .error _

/-- Every value names only numbers of the set of all block numbers. -/
theorem Val.namesIn_top (v : Val) : v.NamesIn fun _ => True :=
  Val.rec (motive_1 := fun v => v.NamesIn fun _ => True)
    (motive_2 := fun xs => Val.AllNamesIn (fun _ => True) xs) (fun _ _ => trivial)
    (fun _ => trivial) trivial trivial (fun _ h => h) (fun _ h => h) trivial
    (fun _ _ h₁ h₂ => ⟨h₁, h₂⟩) v

/-- For every cast but `fpext` and `fptrunc` (so every cast LangRef admits in a constant
expression, `CastOp.const`), layout, memory, types and value, `castV` reads no oracle number. -/
theorem castV_ch {op : CastOp} (h : (op matches .fpext | .fptrunc) = false) (l : Layout)
    (m : Mem) (s : Ty) (x : Val) (t : Ty) (ch ch' : Nat → Nat) :
    castV l m op s x t ch = castV l m op s x t ch' := by
  cases op <;> first
    | (simp at h; done)
    | (unfold castV; split <;> first | rfl | contradiction)

mutual
/-- For every scope, type, oracle numbers and set `p` of registers, with registers equal outside
`p`, evaluating an operand that mentions no register of `p` (`Value.mentions`) gives one result:
it reads the registers only at those it mentions, and no oracle number (`castV_ch`). -/
theorem evalV_regs {s : Scope} {r : Nat → Option Val} {ch : Nat → Nat} {p : Nat → Bool}
    (hr : ∀ n, p n = false → r n = s.regs n) (t : Ty) :
    ∀ v : Value, v.mentions p = false → evalV { s with regs := r, ch := ch } t v = evalV s t v
  | .loc n, h => by simp only [evalV, hr n (by simpa [Value.mentions] using h)]
  | .glob _, _ | .int _, _ | .float _, _ | .null, _ | .undef, _ | .poison, _ | .zero, _ => rfl
  | .vec es, h | .arr es, h | .struct es, h => by
    simp only [evalV, evalTVs_regs (ch := ch) hr es (by simpa [Value.mentions] using h)]
  | .splat e, h => by
    simp only [evalV, evalTV_regs (ch := ch) hr e (by simpa [Value.mentions] using h)]
  | .gep fl src b idx, h => by
    simp only [Value.mentions, Bool.or_eq_false_iff] at h
    have hb := evalTV_regs (ch := ch) hr b h.1
    have hi := evalTVs_regs (ch := ch) hr idx h.2
    rcases b with ⟨_ | _ | _ | a | _ | _ | _ | _ | _, vb⟩
    case ptr => simp only [evalV, hb, hi]
    all_goals rfl
  | .cast op v ty, h => by
    have hv := evalTV_regs (ch := ch) hr v (by simpa [Value.mentions] using h)
    rcases v with ⟨st, vv⟩
    by_cases hc : op.const
    · simp only [evalV, hc, ↓reduceIte, hv, castV_ch (op := op)
        (by cases op <;> first | rfl | (simp [CastOp.const] at hc)) _ _ _ _ _ ch s.ch]
    · simp only [evalV, hc, Bool.false_eq_true, ↓reduceIte]

/-- `evalV_regs` for a typed operand. -/
theorem evalTV_regs {s : Scope} {r : Nat → Option Val} {ch : Nat → Nat} {p : Nat → Bool}
    (hr : ∀ n, p n = false → r n = s.regs n) :
    ∀ v : TValue, v.mentions p = false → evalTV { s with regs := r, ch := ch } v = evalTV s v
  | .mk t v, h => by simpa only [evalTV] using evalV_regs hr t v h

/-- `evalV_regs` for a list of typed operands. -/
theorem evalTVs_regs {s : Scope} {r : Nat → Option Val} {ch : Nat → Nat} {p : Nat → Bool}
    (hr : ∀ n, p n = false → r n = s.regs n) :
    ∀ vs : List TValue, TValue.anyMentions p vs = false →
      evalTVs { s with regs := r, ch := ch } vs = evalTVs s vs
  | [], _ => rfl
  | e :: es, h => by
    simp only [TValue.anyMentions, Bool.or_eq_false_iff] at h
    simp only [evalTVs, evalTV_regs (ch := ch) hr e h.1, evalTVs_regs (ch := ch) hr es h.2]
end

/-- For every set of payload blocks, scope, oracle numbers and set `p` of registers: with related
memories, and registers equal outside `p`, evaluating an operand (typed, or a list of typed
operands) that mentions no register of `p`, at any type, gives one result, whatever the oracle
numbers (the skeleton operands of `evalV_skel` in docs/proofs/payload.md). -/
theorem evalV_skel {pay : Nat → Prop} {s : Scope} {m : Mem} {r : Nat → Option Val}
    {ch : Nat → Nat} {p : Nat → Bool} (hm : s.mem.SkelEq pay m)
    (hr : ∀ n, p n = false → r n = s.regs n) :
    (∀ t v, v.mentions p = false →
      evalV { s with mem := m, regs := r, ch := ch } t v = evalV s t v) ∧
    (∀ v : TValue, v.mentions p = false →
      evalTV { s with mem := m, regs := r, ch := ch } v = evalTV s v) ∧
    (∀ vs, TValue.anyMentions p vs = false →
      evalTVs { s with mem := m, regs := r, ch := ch } vs = evalTVs s vs) := by
  have hs : Scope.NamesIn (fun _ => True) { s with regs := r, ch := ch } :=
    ⟨trivial, fun _ v _ => Val.namesIn_top v, fun _ _ _ => trivial⟩
  exact ⟨fun t v h => ((evalV_shape hs (hm.sameShape _) t v).1).trans (evalV_regs hr t v h),
    fun v h => ((evalTV_shape hs (hm.sameShape _) v).1).trans (evalTV_regs hr v h),
    fun vs h => ((evalTVs_shape hs (hm.sameShape _) vs).1).trans (evalTVs_regs hr vs h)⟩

/-- Lists are related element by element by `Val.Skel` exactly when they have one erasure. -/
theorem Val.forall₂_skel : ∀ {xs ys : List Val},
    List.Forall₂ Val.Skel xs ys ↔ xs.map Val.erase = ys.map Val.erase
  | [], [] => ⟨fun _ => rfl, fun _ => .nil⟩
  | _ :: _, _ :: _ => List.forall₂_cons.trans
    ⟨fun h => congrArg₂ List.cons h.1 (Val.forall₂_skel.1 h.2),
      fun h => ⟨(List.cons.inj h).1, Val.forall₂_skel.2 (List.cons.inj h).2⟩⟩
  | [], _ :: _ | _ :: _, [] => ⟨nofun, nofun⟩

/-- A vector `xs` is related to `y` exactly when `y` is a vector `ys` with `xs` and `ys` related
lane by lane. -/
theorem Val.skel_vec {xs : List Val} {y : Val} :
    Val.Skel (.vec xs) y ↔ ∃ ys, y = .vec ys ∧ List.Forall₂ Val.Skel xs ys := by
  rcases y with _ | _ | _ | _ | ys | _ <;>
    simp [Val.Skel, Val.erase, Val.eraseAll_eq, Val.forall₂_skel]

/-- An aggregate `xs` is related to `y` exactly when `y` is an aggregate `ys` with `xs` and `ys`
related element by element. -/
theorem Val.skel_agg {xs : List Val} {y : Val} :
    Val.Skel (.agg xs) y ↔ ∃ ys, y = .agg ys ∧ List.Forall₂ Val.Skel xs ys := by
  rcases y with _ | _ | _ | _ | _ | ys <;>
    simp [Val.Skel, Val.erase, Val.eraseAll_eq, Val.forall₂_skel]

/-- For all lane functions that give related results on related lanes (lane by lane, two oracle
numbers allowed), `lanes` on related values gives related results: one fault, or values related
by `Val.Skel` (the vector rows of `Op.total_skel` in docs/proofs/payload.md). -/
theorem lanes_skel {f g : Nat → Val → Except Fault Val}
    (hf : ∀ i x y, x.Skel y → Except.Rel Val.Skel (f i x) (g i y)) {x y : Val} (h : x.Skel y) :
    Except.Rel Val.Skel (lanes f x) (lanes g y) := by
  rcases x with _ | _ | _ | _ | xs | _ <;> rcases y with _ | _ | _ | _ | ys | _
  all_goals try first
    | exact hf 0 _ _ h
    | (exfalso; simp [Val.Skel, Val.erase] at h; done)
  obtain ⟨_, ⟨⟩, hxy⟩ := Val.skel_vec.1 h
  exact (Except.Rel.mapM (S := Val.Skel) (f := fun p : Val × Nat => f p.2 p.1)
    (g := fun p : Val × Nat => g p.2 p.1) (fun p q hpq => by
      obtain ⟨x, i⟩ := p
      obtain ⟨y, j⟩ := q
      obtain ⟨h₁, rfl⟩ := hpq
      exact hf i x y h₁) (hxy.zipIdx 0)).map fun _ _ hr => Val.skel_vec.2 ⟨_, rfl, hr⟩

/-- For every proposition `P` and all two-operand lane functions that give related results on
related lanes whose second lanes are equal if `P` (two oracle numbers allowed), `lanes2` on related
values whose second values are equal if `P` gives related results: one fault, or values related
by `Val.Skel` (the vector part of the two-operand rows of `Op.total_skel`; `P` says that the
second operand is skeleton). -/
theorem lanes2_skel {P : Prop} {f g : Nat → Val → Val → Except Fault Val}
    (hf : ∀ i x₁ x₂ y₁ y₂, x₁.Skel x₂ → y₁.Skel y₂ → (P → y₁ = y₂) →
      Except.Rel Val.Skel (f i x₁ y₁) (g i x₂ y₂))
    {x₁ x₂ y₁ y₂ : Val} (hx : x₁.Skel x₂) (hy : y₁.Skel y₂) (hP : P → y₁ = y₂) :
    Except.Rel Val.Skel (lanes2 f x₁ y₁) (lanes2 g x₂ y₂) := by
  by_cases hv : (∃ xs, x₁ = .vec xs) ∧ ∃ ys, y₁ = .vec ys
  · obtain ⟨⟨xs₁, rfl⟩, ⟨ys₁, rfl⟩⟩ := hv
    obtain ⟨xs₂, rfl, hx'⟩ := Val.skel_vec.1 hx
    obtain ⟨ys₂, rfl, hy'⟩ := Val.skel_vec.1 hy
    simp only [lanes2, hx'.length_eq, hy'.length_eq]
    by_cases hc : xs₂.length = ys₂.length
    · simp only [hc, ↓reduceIte]
      have hy'' : List.Forall₂ (fun a b => a.Skel b ∧ (P → a = b)) ys₁ ys₂ := by
        by_cases p : P
        · cases hP p
          exact List.forall₂_same.2 fun _ _ => ⟨rfl, fun _ => rfl⟩
        · exact hy'.imp fun _ _ h => ⟨h, fun q => absurd q p⟩
      exact (Except.Rel.mapM (S := Val.Skel)
        (f := fun p : (Val × Val) × Nat => f p.2 p.1.1 p.1.2)
        (g := fun p : (Val × Val) × Nat => g p.2 p.1.1 p.1.2) (fun p q hpq => by
          obtain ⟨⟨x, y⟩, i⟩ := p
          obtain ⟨⟨x', y'⟩, j⟩ := q
          obtain ⟨⟨h₁, h₂, h₃⟩, rfl⟩ := hpq
          exact hf i x x' y y' h₁ h₂ h₃)
        ((hx'.zip hy'').zipIdx 0)).map fun _ _ hr => Val.skel_vec.2 ⟨_, rfl, hr⟩
    · simp only [hc, ↓reduceIte]
      exact .error _
  · have hv' : ¬ ((∃ xs, x₂ = .vec xs) ∧ ∃ ys, y₂ = .vec ys) := by
      rintro ⟨⟨xs₂, rfl⟩, ⟨ys₂, rfl⟩⟩
      obtain ⟨xs₁, rfl, -⟩ := Val.skel_vec.1 hx.symm
      obtain ⟨ys₁, rfl, -⟩ := Val.skel_vec.1 hy.symm
      exact hv ⟨⟨_, rfl⟩, ⟨_, rfl⟩⟩
    have e : ∀ {f : Nat → Val → Val → Except Fault Val} {x y : Val},
        ¬ ((∃ xs, x = .vec xs) ∧ ∃ ys, y = .vec ys) → lanes2 f x y = f 0 x y :=
      fun {f x y} h => by
        rcases x with _ | _ | _ | _ | xs | _ <;> rcases y with _ | _ | _ | _ | ys | _
        all_goals first | rfl | exact absurd ⟨⟨_, rfl⟩, ⟨_, rfl⟩⟩ h
    rw [e hv, e hv']
    exact hf 0 _ _ _ _ hx hy hP

/-- For every integer cast and width, `intCast` on related scalars gives related results: one
fault, or values related by `Val.Skel` (the `trunc`, `zext` and `sext` row of `Op.total_skel`). -/
theorem intCast_skel (op : CastOp) (w : Nat) {x y : Val} (h : x.Skel y) :
    Except.Rel Val.Skel (intCast op w x) (intCast op w y) := by
  rcases x with _ | _ | _ | _ | _ | _ <;> rcases y with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at h; done)
  all_goals try (obtain rfl : _ = _ := (Val.bits.inj h).1; cases op)
  all_goals first | exact .ok rfl | exact .error _

/-- For every width, and every integer operator and flags of `Op.Total` (`BinOp.total`), `intBin`
on related scalars, the second equal if the operator reads its value (`BinOp.skelB`: a shift
amount or a divisor), gives related results: one fault, or values related by `Val.Skel` (the row
of the integer binary operators of `Op.total_skel`). -/
theorem intBin_skel (w : Nat) {op : BinOp} {fl : IntFlags} (hop : op.total fl = true)
    {x₁ x₂ y₁ y₂ : Val} (hx : x₁.Skel x₂) (hy : y₁.Skel y₂) (hb : op.skelB = true → y₁ = y₂) :
    Except.Rel Val.Skel (intBin w op fl x₁ y₁) (intBin w op fl x₂ y₂) := by
  obtain ⟨rfl, hs, hr⟩ : fl = {} ∧ op ≠ .sdiv ∧ op ≠ .srem := by
    simpa [BinOp.total, and_assoc] using hop
  have hd : op.divides = true → y₁ = y₂ := fun h =>
    hb (by cases op <;> simp_all [BinOp.divides, BinOp.skelB])
  rcases x₁ with _ | _ | _ | _ | _ | _ <;> rcases x₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hx; done)
  all_goals rcases y₁ with _ | _ | _ | _ | _ | _ <;> rcases y₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hy; done)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hx)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hy)
  all_goals try exact .error _
  -- a `poison` second operand: one fault, or `poison`
  all_goals try (simp only [intBin]; split_ifs <;> first | exact .error _ | exact .ok rfl)
  -- two words: with no flag, the condition for `poison` reads only the second word
  · simp only [intBin]
    split_ifs with h
    · obtain ⟨rfl, rfl⟩ := h
      simp only [BitVec.cast_eq]
      cases op
      all_goals first | exact absurd rfl hs | exact absurd rfl hr | try cases hb rfl
      all_goals simp only [intBits, Bool.false_and, Bool.or_false, Bool.false_eq_true,
        ↓reduceIte]
      all_goals try split_ifs
      all_goals first | exact .ok rfl | exact .error _
    · exact .error _
  -- `poison` and a word: a divisor is skeleton
  · by_cases hdv : op.divides = true
    · cases hd hdv
      simp only [intBin]
      split_ifs <;> first | exact .error _ | exact .ok rfl
    · simp only [intBin, hdv]
      exact .ok rfl

/-- For every layout, predicate and type, and memories related for some set of payload blocks,
`icmpV` on related values gives related results: one fault, or values related by `Val.Skel` (the
`icmp` row of `Op.total_skel`). Words of one width give `i1` words; related pointers are equal and
have one address (`Mem.addr_shape`). -/
theorem icmpV_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (hm : m₁.SkelEq pay m₂) (l : Layout)
    (p : ICmp) (t : Ty) {x₁ x₂ y₁ y₂ : Val} (hx : x₁.Skel x₂) (hy : y₁.Skel y₂) :
    Except.Rel Val.Skel (icmpV l m₁ p t x₁ y₁) (icmpV l m₂ p t x₂ y₂) := by
  refine lanes2_skel (P := False) (fun _ a₁ a₂ b₁ b₂ ha hb _ => ?_) hx hy False.elim
  rcases a₁ with _ | _ | _ | _ | _ | _ <;> rcases a₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at ha; done)
  all_goals rcases b₁ with _ | _ | _ | _ | _ | _ <;> rcases b₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hb; done)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj ha)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hb)
  all_goals try exact .error _
  all_goals try exact .ok rfl
  -- two words
  · simp only [strict2]
    split_ifs <;> first | exact .ok rfl | exact .error _
  -- two pointers
  · obtain rfl := Val.ptr.inj ha
    obtain rfl := Val.ptr.inj hb
    simp only [strict2]
    generalize t.elt = e
    cases e
    all_goals try exact .error _
    simp only [Mem.addr_shape (hm.sameShape fun _ => True) trivial]
    exact Except.Rel.refl Val.Skel.refl _

/-- For every float type and operator, and flags without `nnan` and `ninf`, `floatBin` on related
scalars, with any `fmul contract` factors and two oracle numbers, gives related results: one
fault, or values related by `Val.Skel` (the `fadd`, `fsub`, `fmul` and `fdiv` row of
`Op.total_skel`). A word of the type gives a word of the type (`Val.ofFloat`); `nsz`, `arcp`,
`afn` and `reassoc` fault on both sides (`FastMath.check`), and `frem` too (`fbin`). -/
theorem floatBin_skel (t : FloatTy) (op : FBinOp) {fm : FastMath} (hn : fm.nnan = false)
    (hi : fm.ninf = false) {x₁ x₂ y₁ y₂ : Val} (hx : x₁.Skel x₂) (hy : y₁.Skel y₂)
    (px₁ py₁ px₂ py₂ : Option (Val × Val)) (n₁ n₂ : Nat) :
    Except.Rel Val.Skel (floatBin t op fm x₁ y₁ px₁ py₁ n₁)
      (floatBin t op fm x₂ y₂ px₂ py₂ n₂) := by
  by_cases hf : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = true
  · simp only [floatBin, FastMath.check, hf, ↓reduceIte]
    exact .error _
  rcases x₁ with _ | _ | _ | _ | _ | _ <;> rcases x₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hx; done)
  all_goals rcases y₁ with _ | _ | _ | _ | _ | _ <;> rcases y₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hy; done)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hx)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hy)
  all_goals simp only [floatBin, FastMath.check, hf, Bool.false_eq_true, ↓reduceIte, pure_bind,
    withFlags, FastMath.poisons, hn, hi, Bool.false_and, Bool.or_false, Val.float?]
  all_goals try exact .error _
  all_goals try exact .ok rfl
  all_goals split_ifs
  all_goals try exact .error _
  all_goals cases fbin (fmt := t.fmt) op <;> first | exact .error _ | exact .ok rfl

open FloatLib.Floats.Formats.BinaryInterchange in
/-- For every float type, and two-operand functions on its floats whose results are related for
all operands, `floats2` on related values gives related results: one fault, or values related by
`Val.Skel`. -/
theorem floats2_skel (t : FloatTy) {f g : Model t.fmt → Model t.fmt → Val}
    (hfg : ∀ a b a' b', (f a b).Skel (g a' b')) {x₁ x₂ y₁ y₂ : Val} (hx : x₁.Skel x₂)
    (hy : y₁.Skel y₂) : Except.Rel Val.Skel (floats2 t f x₁ y₁) (floats2 t g x₂ y₂) := by
  rcases x₁ with _ | _ | _ | _ | _ | _ <;> rcases x₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hx; done)
  all_goals rcases y₁ with _ | _ | _ | _ | _ | _ <;> rcases y₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hy; done)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hx)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hy)
  all_goals simp only [floats2, strict2, Val.float?]
  all_goals try exact .error _
  all_goals try exact .ok rfl
  all_goals split_ifs
  all_goals first | exact .error _ | exact .ok (hfg _ _ _ _)

open FloatLib.Floats.Formats.BinaryInterchange in
/-- For every float format, and flags without `nnan` and `ninf`, `withFlags` gives the IEEE 754
result for all operands. -/
theorem withFlags_some {fmt : FloatFormat} {fm : FastMath} (hn : fm.nnan = false)
    (hi : fm.ninf = false) (args : List (Model fmt)) (r : Model fmt) :
    withFlags fm args r = some r := by
  simp [withFlags, FastMath.poisons, hn, hi]

open FloatLib.Floats.Formats.BinaryInterchange in
/-- For every float type, the scalars of two floats of the type are related. -/
theorem Val.ofFloat_skel (t : FloatTy) (a b : Model t.fmt) :
    (Val.ofFloat t a).Skel (Val.ofFloat t b) := rfl

/-- For every predicate and type, and flags without `nnan` and `ninf`, `fcmpV` on related values
gives related results: one fault, or values related by `Val.Skel` (the `fcmp` row of
`Op.total_skel`). Floats of the type give `i1` words; `nsz`, `arcp`, `afn` and `reassoc` fault on
both sides (`FastMath.check`). -/
theorem fcmpV_skel {fm : FastMath} (hn : fm.nnan = false) (hi : fm.ninf = false) (p : FCmp)
    (t : Ty) {x₁ x₂ y₁ y₂ : Val} (hx : x₁.Skel x₂) (hy : y₁.Skel y₂) :
    Except.Rel Val.Skel (fcmpV fm p t x₁ y₁) (fcmpV fm p t x₂ y₂) := by
  by_cases hf : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = true
  · simp only [fcmpV, FastMath.check, hf, ↓reduceIte]
    exact .error _
  simp only [fcmpV, FastMath.check, hf, Bool.false_eq_true, ↓reduceIte, pure_bind]
  split
  · refine lanes2_skel (P := False) (fun _ _ _ _ _ ha hb _ => floats2_skel _ (fun _ _ _ _ => ?_)
      ha hb) hx hy False.elim
    simp only [FastMath.poisons, hn, hi, Bool.false_and, Bool.or_false, Bool.false_eq_true,
      ↓reduceIte]
    rfl
  · exact .error _

/-- For every type, and flags without `nnan` and `ninf`, `fnegV` on related values gives related
results: one fault, or values related by `Val.Skel` (the `fneg` row of `Op.total_skel`). -/
theorem fnegV_skel {fm : FastMath} (hn : fm.nnan = false) (hi : fm.ninf = false) (t : Ty)
    {x₁ x₂ : Val} (hx : x₁.Skel x₂) :
    Except.Rel Val.Skel (fnegV fm t x₁) (fnegV fm t x₂) := by
  by_cases hf : (fm.nsz || fm.reassoc || fm.arcp || fm.afn) = true
  · simp only [fnegV, FastMath.check, hf, ↓reduceIte]
    exact .error _
  simp only [fnegV, FastMath.check, hf, Bool.false_eq_true, ↓reduceIte, pure_bind]
  split
  · refine lanes_skel (fun _ a₁ a₂ ha => ?_) hx
    rcases a₁ with _ | _ | _ | _ | _ | _ <;> rcases a₂ with _ | _ | _ | _ | _ | _
    all_goals try (exfalso; simp [Val.Skel, Val.erase] at ha; done)
    all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj ha)
    all_goals simp only [withFlags, FastMath.poisons, hn, hi, Bool.false_and,
      Bool.or_false, Bool.false_eq_true, ↓reduceIte, Val.float?]
    all_goals try exact .error _
    all_goals try exact .ok rfl
    split_ifs
    all_goals first | exact .error _ | exact .ok rfl
  · exact .error _

/-- For every type and condition, `selectV` on related values gives related results: one fault,
or values related by `Val.Skel` (the `select` row of `Op.total_skel`, whose condition is skeleton
by (O1)). -/
theorem selectV_skel (t : Ty) (c : Val) {a₁ a₂ b₁ b₂ : Val} (ha : a₁.Skel a₂)
    (hb : b₁.Skel b₂) : Except.Rel Val.Skel (selectV t c a₁ b₁) (selectV t c a₂ b₂) := by
  have pick : ∀ (c : Val) (ty : Ty) {a₁ a₂ b₁ b₂ : Val}, a₁.Skel a₂ → b₁.Skel b₂ →
      Except.Rel Val.Skel (selectV.pick c a₁ b₁ ty) (selectV.pick c a₂ b₂ ty) := by
    intro c ty a₁ a₂ b₁ b₂ ha hb
    rcases c with _ | _ | _ | _ | _ | _ <;> simp only [selectV.pick]
    all_goals try exact .error _
    · split_ifs
      exacts [.ok ha, .ok hb]
    · exact .ok (Val.Skel.refl _)
  by_cases hv : (∃ cs, c = .vec cs) ∧ (∃ xs, a₁ = .vec xs) ∧ ∃ ys, b₁ = .vec ys
  · obtain ⟨⟨cs, rfl⟩, ⟨xs₁, rfl⟩, ⟨ys₁, rfl⟩⟩ := hv
    obtain ⟨xs₂, rfl, hx⟩ := Val.skel_vec.1 ha
    obtain ⟨ys₂, rfl, hy⟩ := Val.skel_vec.1 hb
    simp only [selectV, hx.length_eq, hy.length_eq]
    split_ifs
    · refine (Except.Rel.mapM (S := Val.Skel)
        (f := fun p : Val × Val × Val => selectV.pick p.1 p.2.1 p.2.2 t.elt)
        (g := fun p : Val × Val × Val => selectV.pick p.1 p.2.1 p.2.2 t.elt) (fun p q hpq => ?_)
        (((List.forall₂_same (Rₐ := (· = ·))).2 fun _ _ => rfl).zip (hx.zip hy))).map
          fun _ _ hr => Val.skel_vec.2 ⟨_, rfl, hr⟩
      obtain ⟨c, a, b⟩ := p
      obtain ⟨c', a', b'⟩ := q
      obtain ⟨rfl, h₁, h₂⟩ := hpq
      exact pick c t.elt h₁ h₂
    · exact .error _
  · have hv' : ¬ ((∃ cs, c = .vec cs) ∧ (∃ xs, a₂ = .vec xs) ∧ ∃ ys, b₂ = .vec ys) := by
      rintro ⟨⟨cs, rfl⟩, ⟨xs₂, rfl⟩, ⟨ys₂, rfl⟩⟩
      obtain ⟨xs₁, rfl, -⟩ := Val.skel_vec.1 ha.symm
      obtain ⟨ys₁, rfl, -⟩ := Val.skel_vec.1 hb.symm
      exact hv ⟨⟨_, rfl⟩, ⟨_, rfl⟩, ⟨_, rfl⟩⟩
    have e : ∀ {a b : Val}, ¬ ((∃ cs, c = .vec cs) ∧ (∃ xs, a = .vec xs) ∧ ∃ ys, b = .vec ys) →
        selectV t c a b = selectV.pick c a b t := fun {a b} h => by
      rcases c with _ | _ | _ | _ | cs | _ <;> try rfl
      rcases a with _ | _ | _ | _ | xs | _ <;> try rfl
      rcases b with _ | _ | _ | _ | ys | _ <;> try rfl
      exact absurd ⟨⟨_, rfl⟩, ⟨_, rfl⟩, ⟨_, rfl⟩⟩ h
    rw [e hv, e hv']
    exact pick c t ha hb

/-- For every type and index, `extractE` on related values gives related results: one fault, or
values related by `Val.Skel` (the `extractelement` row of `Op.total_skel`, whose index is
skeleton). -/
theorem extractE_skel (t : Ty) {v₁ v₂ : Val} (hv : v₁.Skel v₂) (i : Val) :
    Except.Rel Val.Skel (extractE t v₁ i) (extractE t v₂ i) := by
  rcases v₁ with _ | _ | _ | _ | xs₁ | _
  all_goals try (rcases v₂ with _ | _ | _ | _ | _ | _ <;> first
    | (exfalso; simp [Val.Skel, Val.erase] at hv; done) | exact .error _)
  obtain ⟨xs₂, rfl, hx⟩ := Val.skel_vec.1 hv
  rcases i with _ | _ | _ | _ | _ | _
  all_goals try exact .error _
  · exact .ok ((hx.getElem? _).getD (Val.Skel.refl _))
  · exact .ok (Val.Skel.refl _)

/-- For every type and index, `insertE` on related values and related elements gives related
results: one fault, or values related by `Val.Skel` (the `insertelement` row of `Op.total_skel`,
whose index is skeleton). -/
theorem insertE_skel (t : Ty) {v₁ v₂ e₁ e₂ : Val} (hv : v₁.Skel v₂) (he : e₁.Skel e₂) (i : Val) :
    Except.Rel Val.Skel (insertE t v₁ e₁ i) (insertE t v₂ e₂ i) := by
  rcases v₁ with _ | _ | _ | _ | xs₁ | _
  all_goals try (rcases v₂ with _ | _ | _ | _ | _ | _ <;> first
    | (exfalso; simp [Val.Skel, Val.erase] at hv; done) | exact .error _)
  obtain ⟨xs₂, rfl, hx⟩ := Val.skel_vec.1 hv
  rcases i with _ | _ | _ | _ | _ | _
  all_goals try exact .error _
  · simp only [insertE, hx.length_eq]
    split_ifs
    · exact .ok (Val.skel_vec.2 ⟨_, rfl, hx.set he _⟩)
    · exact .ok (Val.Skel.refl _)
  · exact .ok (Val.Skel.refl _)

/-- For every type and mask, `shuffleV` on related values gives related results: one fault, or
values related by `Val.Skel` (the `shufflevector` row of `Op.total_skel`, whose mask is
skeleton). -/
theorem shuffleV_skel (t : Ty) {a₁ a₂ b₁ b₂ : Val} (ha : a₁.Skel a₂) (hb : b₁.Skel b₂)
    (m : Val) : Except.Rel Val.Skel (shuffleV t a₁ b₁ m) (shuffleV t a₂ b₂ m) := by
  rcases a₁ with _ | _ | _ | _ | xs₁ | _
  all_goals try (rcases a₂ with _ | _ | _ | _ | _ | _ <;> first
    | (exfalso; simp [Val.Skel, Val.erase] at ha; done) | exact .error _)
  obtain ⟨xs₂, rfl, hx⟩ := Val.skel_vec.1 ha
  rcases b₁ with _ | _ | _ | _ | ys₁ | _
  all_goals try (rcases b₂ with _ | _ | _ | _ | _ | _ <;> first
    | (exfalso; simp [Val.Skel, Val.erase] at hb; done) | exact .error _)
  obtain ⟨ys₂, rfl, hy⟩ := Val.skel_vec.1 hb
  rcases m with _ | _ | _ | _ | ms | _
  all_goals try exact .error _
  refine (Except.Rel.mapM (S := Val.Skel) (fun k _ e => ?_)
    ((List.forall₂_same (Rₐ := (· = ·))).2 fun _ _ => rfl)).map
      fun _ _ hr => Val.skel_vec.2 ⟨_, rfl, hr⟩
  subst e
  rcases k with _ | _ | _ | _ | _ | _
  all_goals try exact .error _
  all_goals try exact .ok (Val.Skel.refl _)
  exact .ok (((List.rel_append hx hy).getElem? _).getD (Val.Skel.refl _))

/-- For every list of indices, `extractV` on related values gives related results: one fault, or
values related by `Val.Skel` (the `extractvalue` row of `Op.total_skel`). -/
theorem extractV_skel : ∀ (is : List Nat) {v₁ v₂ : Val}, v₁.Skel v₂ →
    Except.Rel Val.Skel (extractV v₁ is) (extractV v₂ is)
  | [], _, _, hv => .ok hv
  | i :: is, v₁, v₂, hv => by
    rcases v₁ with _ | _ | _ | _ | _ | xs₁
    all_goals try (rcases v₂ with _ | _ | _ | _ | _ | _ <;> first
      | (exfalso; simp [Val.Skel, Val.erase] at hv; done) | exact .error _)
    obtain ⟨xs₂, rfl, hx⟩ := Val.skel_agg.1 hv
    simp only [extractV]
    have h := hx.getElem? i
    revert h
    generalize xs₁[i]? = o₁
    generalize xs₂[i]? = o₂
    rintro (h | _)
    · exact extractV_skel is h
    · exact .error _

/-- For all related elements and every list of indices, `insertV` on related values gives related
results: one fault, or values related by `Val.Skel` (the `insertvalue` row of `Op.total_skel`). -/
theorem insertV_skel {e₁ e₂ : Val} (he : e₁.Skel e₂) : ∀ (is : List Nat) {v₁ v₂ : Val},
    v₁.Skel v₂ → Except.Rel Val.Skel (insertV v₁ e₁ is) (insertV v₂ e₂ is)
  | [], _, _, _ => .ok he
  | i :: is, v₁, v₂, hv => by
    rcases v₁ with _ | _ | _ | _ | _ | xs₁
    all_goals try (rcases v₂ with _ | _ | _ | _ | _ | _ <;> first
      | (exfalso; simp [Val.Skel, Val.erase] at hv; done) | exact .error _)
    obtain ⟨xs₂, rfl, hx⟩ := Val.skel_agg.1 hv
    simp only [insertV]
    have h := hx.getElem? i
    revert h
    generalize xs₁[i]? = o₁
    generalize xs₂[i]? = o₂
    rintro (h | _)
    · exact (insertV_skel he is h).bind fun _ _ hr => .ok (Val.skel_agg.2 ⟨_, rfl, hx.set hr i⟩)
    · exact .error _

/-- For all float types and two oracle numbers, `floatCast` on related values gives related
results: one fault, or values related by `Val.Skel` (with `lanes_skel`, the `fpext` and `fptrunc`
row of `Op.total_skel`). -/
theorem floatCast_skel (s t : FloatTy) {x₁ x₂ : Val} (hx : x₁.Skel x₂) (n₁ n₂ : Nat) :
    Except.Rel Val.Skel (floatCast s t x₁ n₁) (floatCast s t x₂ n₂) := by
  rcases x₁ with _ | _ | _ | _ | _ | _ <;> rcases x₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hx; done)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hx)
  all_goals simp only [floatCast, Val.float?]
  all_goals try exact .error _
  all_goals try exact .ok rfl
  split_ifs <;> first | exact .error _ | exact .ok rfl

/-- For every signedness and float type, `intToFloat` on related values gives related results: one
fault, or values related by `Val.Skel` (with `lanes_skel`, the `sitofp` and `uitofp` row of
`Op.total_skel`). -/
theorem intToFloat_skel (signed : Bool) (t : FloatTy) {x₁ x₂ : Val} (hx : x₁.Skel x₂) :
    Except.Rel Val.Skel (intToFloat signed t x₁) (intToFloat signed t x₂) := by
  rcases x₁ with _ | _ | _ | _ | _ | _ <;> rcases x₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hx; done)
  all_goals first | exact .error _ | exact .ok (Val.ofFloat_skel _ _ _) | exact .ok rfl

/-- For every layout and type, `toBitList` of related values gives one fault, or bit lists whose
bits are present (`Option.isSome`) at the same places. -/
theorem toBitList_skel (l : Layout) (s : Ty) {x₁ x₂ : Val} (hx : x₁.Skel x₂) :
    Except.Rel (fun bs₁ bs₂ : List (Option Bool) => bs₁.map Option.isSome = bs₂.map Option.isSome)
      (toBitList l s x₁) (toBitList l s x₂) := by
  have scalar : ∀ w {x₁ x₂ : Val}, x₁.Skel x₂ →
      Except.Rel (fun bs₁ bs₂ : List (Option Bool) => bs₁.map Option.isSome = bs₂.map Option.isSome)
        (toBitList.scalarBitList w x₁) (toBitList.scalarBitList w x₂) := by
    intro w x₁ x₂ hx
    rcases x₁ with _ | _ | _ | _ | _ | _ <;> rcases x₂ with _ | _ | _ | _ | _ | _
    all_goals try (exfalso; simp [Val.Skel, Val.erase] at hx; done)
    all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hx)
    all_goals simp only [toBitList.scalarBitList]
    all_goals try exact .error _
    all_goals try exact .ok rfl
    split_ifs
    · exact .ok (by simp)
    · exact .error _
  by_cases hv : (∃ n e, s = .vec n e) ∧ ∃ xs, x₁ = .vec xs
  · obtain ⟨⟨n, e, rfl⟩, ⟨xs₁, rfl⟩⟩ := hv
    obtain ⟨xs₂, rfl, hxs⟩ := Val.skel_vec.1 hx
    simp only [toBitList]
    refine (Except.Rel.mapM (fun _ _ h => scalar _ h) hxs).bind fun ps₁ ps₂ hp => .ok ?_
    simp only [List.map_flatten]
    congr 1
    induction hp with
    | nil => rfl
    | cons h _ ih => simp only [List.map_cons, h, ih]
  · have hv' : ¬ ((∃ n e, s = .vec n e) ∧ ∃ xs, x₂ = .vec xs) := by
      rintro ⟨⟨n, e, rfl⟩, ⟨xs₂, rfl⟩⟩
      obtain ⟨xs₁, rfl, -⟩ := Val.skel_vec.1 hx.symm
      exact hv ⟨⟨_, _, rfl⟩, ⟨_, rfl⟩⟩
    have e : ∀ {x : Val}, ¬ ((∃ n e, s = .vec n e) ∧ ∃ xs, x = .vec xs) →
        toBitList l s x = toBitList.scalarBitList (l.scalarBits s) x := fun {x} h => by
      cases s <;> try rfl
      cases x <;> try rfl
      exact absurd ⟨⟨_, _, rfl⟩, ⟨_, rfl⟩⟩ h
    rw [e hv, e hv']
    exact scalar _ hx

/-- For every layout and type, `ofBitList` of bit lists whose bits are present (`Option.isSome`) at
the same places gives related values. -/
theorem ofBitList_skel (l : Layout) (t : Ty) {bs₁ bs₂ : List (Option Bool)}
    (h : bs₁.map Option.isSome = bs₂.map Option.isSome) :
    Val.Skel (ofBitList l t bs₁) (ofBitList l t bs₂) := by
  have hs : ∀ bs : List (Option Bool), (bs.mapM id).isSome = (bs.map Option.isSome).all id := by
    intro bs
    induction bs with
    | nil => rfl
    | cons a as ih =>
      rcases a with _ | a
      · rfl
      · rw [List.map_cons, List.all_cons, ← ih, List.mapM_cons]
        cases List.mapM id as <;> rfl
  have scalar : ∀ w {bs₁ bs₂ : List (Option Bool)}, bs₁.map Option.isSome = bs₂.map Option.isSome →
      Val.Skel (ofBitList.scalar w bs₁) (ofBitList.scalar w bs₂) := by
    intro w bs₁ bs₂ h
    have := (hs bs₁).trans ((congrArg (List.all · id) h).trans (hs bs₂).symm)
    unfold ofBitList.scalar
    rcases h₁ : bs₁.mapM id with _ | _ <;> rcases h₂ : bs₂.mapM id with _ | _ <;>
      simp only [h₁, h₂, Option.isSome_none, Option.isSome_some] at this
    all_goals first | rfl | cases this
  cases t with
  | vec n e =>
    refine Val.skel_vec.2 ⟨_, rfl, ?_⟩
    rw [List.forall₂_map_left_iff, List.forall₂_map_right_iff]
    exact List.forall₂_same.2 fun i _ => scalar _ (by simp only [List.map_take, List.map_drop, h])
  | _ => exact scalar _ h

/-- For every layout and two types, `bitcast` on related values gives related results: one fault,
or values related by `Val.Skel` (the `bitcast` row of `Op.total_skel`, for all types, not only
data types). -/
theorem bitcast_skel (l : Layout) (s t : Ty) {x₁ x₂ : Val} (hx : x₁.Skel x₂) :
    Except.Rel Val.Skel (bitcast l s t x₁) (bitcast l s t x₂) := by
  unfold bitcast
  split
  · exact .ok hx
  · refine (toBitList_skel l s hx).bind fun bs₁ bs₂ h => ?_
    have hl : bs₁.length = bs₂.length := by simpa using congrArg List.length h
    simp only [hl]
    split_ifs
    · exact .ok (ofBitList_skel l t h)
    · exact .error _

/-- For every layout, cast and two types, any oracle numbers, and memories related for some set of
payload blocks, `castV` on related values gives related results: one fault, or values related by
`Val.Skel` (the cast rows of `Op.total_skel`: `trunc`, `zext`, `sext`, `fpext`, `fptrunc`,
`sitofp`, `uitofp` and `bitcast`; also `ptrtoint` and `addrspacecast`, by `Mem.addr_shape`). -/
theorem castV_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (hm : m₁.SkelEq pay m₂) (l : Layout)
    (op : CastOp) (s t : Ty) {x₁ x₂ : Val} (hx : x₁.Skel x₂) (ch₁ ch₂ : Nat → Nat) :
    Except.Rel Val.Skel (castV l m₁ op s x₁ t ch₁) (castV l m₂ op s x₂ t ch₂) := by
  unfold castV
  split
  all_goals try exact lanes_skel (fun _ _ _ h => intCast_skel _ _ h) hx
  all_goals try exact lanes_skel (fun _ _ _ h => floatCast_skel _ _ h _ _) hx
  all_goals try exact lanes_skel (fun _ _ _ h => intToFloat_skel _ _ h) hx
  all_goals try exact bitcast_skel l _ _ hx
  all_goals try exact .error _
  all_goals refine lanes_skel (fun _ a₁ a₂ ha => ?_) hx
  all_goals rcases a₁ with _ | _ | _ | _ | _ | _ <;> rcases a₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at ha; done)
  all_goals try exact .error _
  all_goals try exact .ok rfl
  all_goals obtain rfl := Val.ptr.inj ha
  all_goals simp only [Mem.addr_shape (hm.sameShape fun _ => True) trivial]
  all_goals exact Except.Rel.refl Val.Skel.refl _

/-- For every `max` flag (`maxnum` or `minnum`) and type, two contexts and two scopes, and flags
without `nnan` and `ninf`, the intrinsic on related values gives one fault, or two results with
related values that leave the scopes' memories unchanged (the `maxnum` and `minnum` row of
`Op.total_skel`). -/
theorem fminmax_skel {fm : FastMath} (hn : fm.nnan = false) (hi : fm.ninf = false) (c₁ c₂ : Ctx)
    (s₁ s₂ : Scope) (max : Bool) (t : Ty) {x₁ x₂ y₁ y₂ : Val} (hx : x₁.Skel x₂) (hy : y₁.Skel y₂) :
    Except.Rel (Option.Rel fun r₁ r₂ => Option.Rel Val.Skel r₁.1 r₂.1 ∧ r₁.2 = s₁.mem ∧
        r₂.2 = s₂.mem)
      (intrinsic c₁ s₁ fm (.fminmax max t) [x₁, y₁])
      (intrinsic c₂ s₂ fm (.fminmax max t) [x₂, y₂]) := by
  simp only [intrinsic]
  split
  · refine (lanes2_skel (P := False) (fun _ _ _ _ _ ha hb _ => floats2_skel _ (fun _ _ _ _ => ?_)
      ha hb) hx hy False.elim).bind fun _ _ h => .ok (.some ⟨.some h, rfl, rfl⟩)
    simp only [withFlags_some hn hi]
    exact Val.ofFloat_skel _ _ _
  · exact .error _

/-- For every two contexts and two scopes, and flags without `nnan` and `ninf`, the
`rsqrt.approx` intrinsic on related values gives one fault, or two results with related values
that leave the scopes' memories unchanged (the `rsqrt.approx` row of `Op.total_skel`): two words of
32 bits give two floats, whatever the two words and choices are, and `poison` gives `poison`. -/
theorem rsqrt_skel {fm : FastMath} (hn : fm.nnan = false) (hi : fm.ninf = false) (c₁ c₂ : Ctx)
    (s₁ s₂ : Scope) {x₁ x₂ : Val} (hx : x₁.Skel x₂) :
    Except.Rel (Option.Rel fun r₁ r₂ => Option.Rel Val.Skel r₁.1 r₂.1 ∧ r₁.2 = s₁.mem ∧
        r₂.2 = s₂.mem)
      (intrinsic c₁ s₁ fm .rsqrtApprox [x₁]) (intrinsic c₂ s₂ fm .rsqrtApprox [x₂]) := by
  rcases x₁ with _ | _ | _ | _ | _ | _ <;> rcases x₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hx; done)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hx)
  all_goals simp only [intrinsic, Val.float?, withFlags, FastMath.poisons, hn, hi, Bool.false_and,
    Bool.or_false, Bool.false_eq_true, ↓reduceIte, Option.elim]
  all_goals try exact .ok (.some ⟨.some rfl, rfl, rfl⟩)
  all_goals try exact .error _
  split_ifs
  all_goals simp only []
  all_goals first | exact .error _ | exact .ok (.some ⟨.some rfl, rfl, rfl⟩)

/-- For every layout, type and list of attributes and memories related for some set of payload
blocks, `withAttrs` on related values, if no attribute is a `range` or the values are equal, gives
one fault, or related values: `noundef` faults on both or neither (`Val.Skel.defined`), and
`nonnull` and `align` read the address of one pointer (`Mem.addr_shape`). -/
theorem withAttrs_skel {pay : Nat → Prop} {m₁ m₂ : Mem} (hm : m₁.SkelEq pay m₂) (l : Layout)
    (t : Ty) (attrs : List Attr) {x₁ x₂ : Val} (hx : x₁.Skel x₂)
    (hr : (∀ a ∈ attrs, a.name ≠ "range") ∨ x₁ = x₂) :
    Except.Rel Val.Skel (withAttrs l m₁ t attrs x₁) (withAttrs l m₂ t attrs x₂) := by
  have ha : ∀ s p, m₁.addr l s p = m₂.addr l s p := fun s p =>
    Mem.addr_shape (hm.sameShape fun _ => True) (p := p) trivial l s
  rw [show withAttrs l m₁ = withAttrs l m₂ from funext fun t => funext fun attrs => funext fun v =>
    by simp only [withAttrs, ha]]
  rcases hr with hr | rfl
  swap
  · exact Except.Rel.refl Val.Skel.refl _
  have check : ∀ v₁ v₂ : Val, v₁.Skel v₂ → Except.Rel Val.Skel
      (if (attrs.contains (.flag "noundef") && !v₁.defined) = true then
        throw (.ub "noundef value not defined") else pure v₁ : Except Fault Val)
      (if (attrs.contains (.flag "noundef") && !v₂.defined) = true then
        throw (.ub "noundef value not defined") else pure v₂) := by
    intro v₁ v₂ hv
    rw [hv.defined]
    split_ifs
    · exact .error _
    · exact .ok hv
  -- a vector of type `vec`, lane by lane, or one lane; then the step of each attribute
  by_cases hvec : (∃ n te, t = .vec n te) ∧ ∃ xs, x₁ = .vec xs
  on_goal 2 =>
    have hvec' : ¬ ((∃ n te, t = .vec n te) ∧ ∃ xs, x₂ = .vec xs) := by
      rintro ⟨⟨n, e, rfl⟩, ⟨xs₂, rfl⟩⟩
      obtain ⟨xs₁, rfl, -⟩ := Val.skel_vec.1 hx.symm
      exact hvec ⟨⟨_, _, rfl⟩, ⟨_, rfl⟩⟩
    simp only [withAttrs]
    split
    · exact absurd ⟨⟨_, _, rfl⟩, ⟨_, rfl⟩⟩ hvec
    split
    · exact absurd ⟨⟨_, _, rfl⟩, ⟨_, rfl⟩⟩ hvec'
    refine Except.Rel.bind (R := Val.Skel) (Except.Rel.foldlM (fun a ha v₁ v₂ hs => ?_) hx) check
  on_goal 1 =>
    obtain ⟨⟨n, te, rfl⟩, ⟨xs₁, rfl⟩⟩ := hvec
    obtain ⟨xs₂, rfl, hxs⟩ := Val.skel_vec.1 hx
    simp only [withAttrs]
    refine Except.Rel.bind (R := Val.Skel) (Except.Rel.map (Except.Rel.mapM (fun _ _ h =>
      Except.Rel.foldlM (fun a ha v₁ v₂ hs => ?_) h) hxs) fun _ _ h => Val.skel_vec.2 ⟨_, rfl, h⟩)
      check
  all_goals
    have hn := hr _ ha
    rcases v₁ with _ | _ | _ | _ | _ | _ <;> rcases v₂ with _ | _ | _ | _ | _ | _
    all_goals try (exfalso; simp [Val.Skel, Val.erase] at hs; done)
    all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hs)
    all_goals try (obtain rfl := Val.ptr.inj hs)
    all_goals try exact Except.Rel.refl Val.Skel.refl _
    all_goals split
    all_goals first
      | contradiction
      | (split <;> first
          | contradiction
          | exact .error _
          | exact .ok ‹_›
          | (exfalso; simp_all))

end MojoProof.Sem
