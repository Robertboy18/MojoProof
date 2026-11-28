import MojoProofTest.LnRound
import MojoProofTest.GPUProof.ViewStride
import MojoProof.Sym.SegTrace
import MojoProof.Float.Norm

/-!
# Layer norm's last loop, run for every block size and row length: its accesses and final blocks

Tests of layer norm's family (the corpus files ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024},
MojoProofTest/LnRound.lean's `lnFam`: the bs128 file's program `ln.prog`,
MojoProofTest/SymSeg.lean's `ln`, with the loop's step as the block size `B`): the loop that writes
the normalized row, from its header `%469` after the `phi`s (:678-680, the loop index `%471` at
:679) to its exit test and branch (:684-690) and the path out `%482` into `%534` (:692-693, :774),
run by the symbolic layer (`Block.sound_edge`) for one thread, every block size `B` with
`0 < B ≤ 2 ^ 32` and the covers `LnCovers B`, every row length `n < 2 ^ 32`, every context of
`ln.prog` (so every launch and thread) and every memory with the four row buffers, in the family's
function `lnFam.fn B`. At 128 that is the corpus file's own function (`lnFam.prog_corpus`), and the
theorems named without `B` are the instances at 128 (their statements are those of the bs128 file).
MojoProofTest/LnRound.lean gives the premises of one round with the guard true and one with it
false; this file chains the rounds. MojoProofTest/LnFamily.lean evaluates the premises at the bs64,
bs256 and bs1024 files. Each run theorem has two conclusions about the memory, and a third about
the floats stored:

* `LnTrace w y g b x ks m M`, the run's accesses: `M`'s trace (`Mem.trace`, newest first) is
  `m`'s with, in front, the accesses of the rounds of `ks`, newest first: the reverse of
  `ks.flatMap (lnAcc w y g b x)`, which lists them in the order of the run, for each `k` of `ks`
  in turn thread `w`'s reads of 4 bytes at float `k` of `x`, `g` and `b` (the loads :715-717) and
  then its write of 4 bytes at float `k` of `y` (the store :722); and no other event (no barrier,
  no atomic, no other access). `LnTrace.refl`, `LnTrace.trans`; `lnAcc_writes`: the writes of
  that list, in the order of the run, are the 4-byte writes at `ks`' floats of `y`, in `ks`'
  order; `LnTrace.ext`: its events in `Ext`'s form. This is the conclusion that gives the order
  and the number of the stores. The trace records no value.
* `LnOut y R ks m M`, the final blocks: `M`'s blocks are `m`'s but block `y`, which is `m`'s with
  byte lists put at byte `4 k` for each `k` of `ks` in turn (`putFloats`), each related to its `k`
  by `R`. It constrains the blocks only, not the trace: `LnOut y R [] m (m.log e)` holds for every
  event `e`, a write outside `y` among them (MojoProofTest/LnRunTest.lean). `LnOut.refl`,
  `LnOut.trans`, the buffers, fits and tensors of the other blocks it keeps (`LnOut.buffer`,
  `LnOut.fits`, `LnOut.holds`), and `LnOut.read`: at indices without repetition, the final 4
  bytes at each float `k` of `ks` are related to `k` by `R`, and those at every other float are
  the first memory's.
* `LnBytes X G Bt mu rs`, the `R` of the run theorems, the floats stored: the bytes at float `k`
  are the binary32 encoding of `lnVal X[k] G[k] Bt[k] mu rs` under some oracle numbers, `%503`
  (:718-721) by MojoProof/Sem/Float.lean's rules: `((X[k] - mu) * rs) * G[k] + Bt[k]` with each
  step rounded and its last `fadd contract` either fused with the product `%502`'s factors
  (`Model.fma`, oracle number `≡ 1 mod 3`) or rounded apart (`contract`, Float.lean:115).
  `lnVal_cases`: up to NaN payloads (`NaNEq`), the fused or the unfused result. A context's oracle
  fixes one; the theorems, for every context, leave both. `lnVal_finite`: a finite `lnVal` is
  exactly MojoProof/Float/Norm.lean's `lnOut`, fused when `o % 3 = 1`; `lnVal_error`: it is then
  within `lnOut_error`'s bound `lnErr` of the real `(X[k] - μ₀) · w · G[k] + Bt[k]` when `mu` is
  within `e` of `μ₀` and `rs` within relative error `κ` of `w`; `LnBytes.error`: the same of the
  float in `LnBytes`' bytes.

The theorems:

* `run_put`: a block's effects, loads and then one store of 4 bytes of a value `w` through
  `⟨y, 4 k⟩`, make `LnOut y R [k]` for every `R` that holds of `k` and `w`'s encoding, and put in
  front of the trace (newest first) the reverse of the loads' accesses followed by the store's
  write, their order in the run.
* `LnHead B`: the registers and memory at the header after its `phi`s at loop index `i`, in the
  family's function `lnFam.fn B`; `AtHead` is it at 128 (an `abbrev`), whose function
  `lnFam.fn 128` is the bs128 file's function (`lnFam.prog_corpus`).
* `LnHead.roundT`, `LnHead.roundF`, `LnHead.exit`: the round with the guard (:708) true, with it
  false, and the path out: the round's premises, `LnHead` at `i + B` and the memory's `LnOut`
  at `LnBytes` and `LnTrace` (`[i + tid]` with the guard true, `LnHead.roundT_out`, the stored
  node `%503` evaluated by `obl_have` from the loads' values that `LnHead`'s tensors give, the
  loads' statements by `fnB_496`; `[]` with it false, whose path `%484`, `%531`, `%532`
  (:698-709, :767-772) has no load or store; the path out keeps the whole memory).
  `AtHead.roundT`, `AtHead.roundF`, `AtHead.exit` are their instances at 128.
* `LnCovers B`: the path checker's covers of the two rounds, the path out and the edge in, at
  `lnFam.fn B`, the run theorems' premise; `covers_128` (the checker at 128, `cov_T`, `cov_F`,
  `cov_X`, `cov_E`).
* `run_fromB` (the hand-proved run lemma, by induction on the fuel) and `runB`: from the header at
  index 0, the thread reaches `%534` with `LnTrace` and `LnOut` at `lnStores B n tid`
  (MojoProofTest/GPUProof/ViewStride.lean); `run_exitB` is the last step.
* `pre`, `entry_edgeB`, `run_entryB`: the edge from `%453`'s branch (:675) into the header, whose
  `phi`s (:678-680) set `%470`, `%471` and `%472` to 0, and the run from that branch.
* `run_exit`, `run_from`, `run`, `entry_edge`, `run_entry`: the instances at 128, in the bs128
  file's function with `lnStores 128 n tid`.

Welford's mean and deviation are not here: the mean `%460` and the inverse deviation `%464` are
given registers (`AtHead`'s `mu` and `rs`), and `LnBytes` names the floats stored in terms of them;
`lnVal_error` takes their accuracy as its premise. The addresses, the guard, the order of the
accesses and the bytes stored are proved. Run theorems; MojoProofTest/LnRunTest.lean applies
`run_entry` at `n = 300`.
-/

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymSeg
open MojoProofTest.LnRound
open FloatLib.Floats.Formats.BinaryInterchange

namespace MojoProofTest.LnRun

open MojoProofTest.GPUProof.ViewStride (lnLoop lnStores)

/-- A block with the 4-byte float writes of `ks` and `bss` made in order: the bytes `bss[j]` at
byte `4 ks[j]`, for every list of float indices, byte lists and block (the shorter list's length
of writes). A test definition. -/
def putFloats (ks : List Nat) (bss : List (List MemByte)) (B : MojoProof.Sem.Block) :
    MojoProof.Sem.Block :=
  (ks.zip bss).foldl (fun B kb => B.put (4 * kb.1) kb.2) B

/-- **Memory `M`'s blocks are `m`'s with floats put at `ks` in block `y`**: every other block is
`m`'s, and block `y` is `m`'s with byte lists, one for each index `k` of `ks` and related to it by
`R` (`List.Forall₂`), put in turn at byte `4 k` (`putFloats`). For every block, relation, list of
indices and memories. A relation of the final blocks only: it constrains neither the trace nor
the number or order of the run's stores (a store that rewrites a byte's old value, or an event
logged without a store, is not seen; `LnTrace` is the trace's). The run theorems take `R` to be
`LnBytes`, which names the bytes. A test definition. -/
def LnOut (y : Nat) (R : Nat → List MemByte → Prop) (ks : List Nat) (m M : Mem) : Prop :=
  (∀ q, q ≠ y → M.blocks q = m.blocks q) ∧
  ∃ bss : List (List MemByte), List.Forall₂ R ks bss ∧
    M.blocks y = (m.blocks y).map (putFloats ks bss)

-- `LnOut` at 67bd004 (its body below, written out) is `LnOut` at `R := fun _ bs => bs.length = 4`.
-- The old statements below write the old `LnOut y` as `LnOut y (fun _ bs => bs.length = 4)`.
example (y : Nat) (ks : List Nat) (m M : Mem) :
    ((∀ q, q ≠ y → M.blocks q = m.blocks q) ∧
      ∃ bss : List (List MemByte), bss.length = ks.length ∧ (∀ bs ∈ bss, bs.length = 4) ∧
        M.blocks y = (m.blocks y).map (putFloats ks bss)) ↔
      LnOut y (fun _ bs => bs.length = 4) ks m M := by
  have e : ∀ (ks : List Nat) (bss : List (List MemByte)),
      List.Forall₂ (fun _ bs => bs.length = 4) ks bss ↔
        bss.length = ks.length ∧ ∀ bs ∈ bss, bs.length = 4 := by
    intro ks
    induction ks with
    | nil => intro bss; cases bss <;> simp
    | cons k ks ih =>
      intro bss
      cases bss with
      | nil => simp
      | cons bs bss =>
        simp only [List.forall₂_cons, ih, List.length_cons, Nat.add_right_cancel_iff,
          List.mem_cons, forall_eq_or_imp]
        tauto
  simp only [LnOut, e, and_assoc]

/-- `LnOut` at a weaker relation: `LnOut y R ks m M` gives `LnOut y R' ks m M` when `R` implies
`R'`, for every block, relations, indices and memories (`List.Forall₂.imp`). -/
theorem LnOut.imp {y : Nat} {R R' : Nat → List MemByte → Prop} {ks : List Nat} {m M : Mem}
    (h : LnOut y R ks m M) (hR : ∀ k bs, R k bs → R' k bs) : LnOut y R' ks m M :=
  ⟨h.1, h.2.elim fun bss h => ⟨bss, h.1.imp hR, h.2⟩⟩

/-- `LnOut y R []` (the same blocks) between two memories with the same blocks, for every block `y`
and relation `R`; their traces may differ. -/
theorem LnOut.refl {y : Nat} {R : Nat → List MemByte → Prop} {m M : Mem}
    (h : M.blocks = m.blocks) : LnOut y R [] m M := by
  refine ⟨fun q _ => by rw [h], [], .nil, ?_⟩
  rw [h]
  cases m.blocks y <;> rfl

-- `LnOut.refl` at 67bd004: `LnOut.refl` at four-byte lists.
example {y : Nat} {m M : Mem} (h : M.blocks = m.blocks) :
    LnOut y (fun _ bs => bs.length = 4) [] m M :=
  LnOut.refl h

/-- The floats put at `ks` from `m` to `M` and then at `ks'` from `M` to `M'` are those put at
`ks ++ ks'` from `m` to `M'`, for every block `y`, relation and memories. -/
theorem LnOut.trans {y : Nat} {R : Nat → List MemByte → Prop} {ks ks' : List Nat} {m M M' : Mem}
    (h : LnOut y R ks m M) (h' : LnOut y R ks' M M') : LnOut y R (ks ++ ks') m M' := by
  obtain ⟨h1, bss, hR, hy⟩ := h
  obtain ⟨h1', bss', hR', hy'⟩ := h'
  refine ⟨fun q hq => (h1' q hq).trans (h1 q hq), bss ++ bss', List.rel_append hR hR', ?_⟩
  rw [hy', hy, Option.map_map]
  congr 1
  funext B
  simp only [Function.comp, putFloats, List.zip_append hR.length_eq, List.foldl_append]

-- `LnOut.trans` at 67bd004: `LnOut.trans` at four-byte lists.
example {y : Nat} {ks ks' : List Nat} {m M M' : Mem}
    (h : LnOut y (fun _ bs => bs.length = 4) ks m M)
    (h' : LnOut y (fun _ bs => bs.length = 4) ks' M M') :
    LnOut y (fun _ bs => bs.length = 4) (ks ++ ks') m M' :=
  h.trans h'

/-- `putFloats` changes only a block's bytes, for every list of indices, byte lists and block. -/
theorem putFloats_eq (ks : List Nat) (bss : List (List MemByte)) (B : MojoProof.Sem.Block) :
    ∃ f, putFloats ks bss B = { B with bytes := f } := by
  unfold putFloats
  generalize ks.zip bss = L
  induction L generalizing B with
  | nil => exact ⟨B.bytes, rfl⟩
  | cons kb L ih =>
    obtain ⟨f, hf⟩ := ih (B.put (4 * kb.1) kb.2)
    exact ⟨f, hf⟩

/-- Under `LnOut y R ks m M`, each block `q` of `m` is in `M` with the same fields but its bytes,
for every block `y`, relation, indices `ks` and memories. -/
theorem LnOut.keep {y : Nat} {R : Nat → List MemByte → Prop} {ks : List Nat} {m M : Mem}
    (h : LnOut y R ks m M) {q : Nat}
    {B : MojoProof.Sem.Block} (hq : m.blocks q = some B) :
    ∃ f, M.blocks q = some { B with bytes := f } := by
  by_cases e : q = y
  · subst e
    obtain ⟨-, bss, -, hy⟩ := h
    obtain ⟨f, hf⟩ := putFloats_eq ks bss B
    exact ⟨f, by rw [hy, hq, Option.map_some, hf]⟩
  · exact ⟨B.bytes, by rw [h.1 q e, hq]⟩

-- `LnOut.keep` at 67bd004: `LnOut.keep` at four-byte lists.
example {y : Nat} {ks : List Nat} {m M : Mem} (h : LnOut y (fun _ bs => bs.length = 4) ks m M)
    {q : Nat} {B : MojoProof.Sem.Block} (hq : m.blocks q = some B) :
    ∃ f, M.blocks q = some { B with bytes := f } :=
  h.keep hq

/-- Under `LnOut y R ks m M`, a buffer of `m` (`Mem.Buffer`) is one of `M`, for every block `y`,
relation, indices, memories, block `q`, size, alignment and writability. -/
theorem LnOut.buffer {y : Nat} {R : Nat → List MemByte → Prop} {ks : List Nat} {m M : Mem}
    (h : LnOut y R ks m M) {q s al : Nat} {w : Bool} (hb : m.Buffer q s al w) :
    M.Buffer q s al w := by
  obtain ⟨B, hB, hP⟩ := hb
  obtain ⟨f, hf⟩ := h.keep hB
  exact ⟨_, hf, hP⟩

-- `LnOut.buffer` at 67bd004: `LnOut.buffer` at four-byte lists.
example {y : Nat} {ks : List Nat} {m M : Mem} (h : LnOut y (fun _ bs => bs.length = 4) ks m M)
    {q s al : Nat} {w : Bool} (hb : m.Buffer q s al w) : M.Buffer q s al w :=
  h.buffer hb

/-- Under `LnOut y R ks m M`, a block of `m` that fits its address space (`Mem.Fits`) fits it in
`M`, for every block `y`, relation, indices, memories, layout, block `q` and size. -/
theorem LnOut.fits {y : Nat} {R : Nat → List MemByte → Prop} {ks : List Nat} {m M : Mem}
    (h : LnOut y R ks m M) {l : Layout} {q s : Nat} (hb : m.Fits l q s) : M.Fits l q s := by
  obtain ⟨B, hB, hP⟩ := hb
  obtain ⟨f, hf⟩ := h.keep hB
  exact ⟨_, hf, hP⟩

-- `LnOut.fits` at 67bd004: `LnOut.fits` at four-byte lists.
example {y : Nat} {ks : List Nat} {m M : Mem} (h : LnOut y (fun _ bs => bs.length = 4) ks m M)
    {l : Layout} {q s : Nat} (hb : m.Fits l q s) : M.Fits l q s :=
  h.fits hb

/-- Under `LnOut y R ks m M`, a tensor that a block `q ≠ y` of `m` holds (`Mem.Holds`) is held by
`q` in `M`, for every relation, indices, memories, layout, type, encoding, offsets and tensor. -/
theorem LnOut.holds {y : Nat} {R : Nat → List MemByte → Prop} {ks : List Nat} {m M : Mem}
    (h : LnOut y R ks m M) {q : Nat}
    (hq : q ≠ y) {s : TorchLean.Shape} {α : Type} {l : Layout} {t : Ty} {enc : α → Val}
    {off : TorchLean.Shape.Coord s → Nat} {X : TorchLean.Tensor α s}
    (hX : m.Holds l q t enc off X) : M.Holds l q t enc off X :=
  Mem.Holds.of_block (fun _ e => (h.1 q hq).trans e) hX

-- `LnOut.holds` at 67bd004: `LnOut.holds` at four-byte lists.
example {y : Nat} {ks : List Nat} {m M : Mem} (h : LnOut y (fun _ bs => bs.length = 4) ks m M)
    {q : Nat} (hq : q ≠ y) {s : TorchLean.Shape} {α : Type} {l : Layout} {t : Ty}
    {enc : α → Val} {off : TorchLean.Shape.Coord s → Nat} {X : TorchLean.Tensor α s}
    (hX : m.Holds l q t enc off X) : M.Holds l q t enc off X :=
  h.holds hq hX

/-- `putFloats` at indices other than `k` keeps a block's 4 bytes at byte `4 k`, for every
relation `R` whose lists have 4 bytes, indices `ks` without `k`, byte lists related to them by `R`
and block. -/
theorem putFloats_read_apart {R : Nat → List MemByte → Prop}
    (hR : ∀ k bs, R k bs → bs.length = 4) {k : Nat} {ks : List Nat} {bss : List (List MemByte)}
    (h : List.Forall₂ R ks bss) : k ∉ ks → ∀ B : MojoProof.Sem.Block,
      (putFloats ks bss B).read (4 * k) 4 = B.read (4 * k) 4 := by
  induction h with
  | nil => intro _ B; rfl
  | @cons k' bs ks bss h _ ih =>
    intro hk B
    obtain ⟨hk1, hk2⟩ := not_or.1 (List.mem_cons.not.1 hk)
    show (putFloats ks bss (B.put (4 * k') bs)).read (4 * k) 4 = _
    rw [ih hk2, Block.read_put_apart _ _ (by rw [hR _ _ h]; omega)]

/-- **The final bytes of block `y`, float by float.** Under `LnOut y R ks m M`, with `R`'s lists
of 4 bytes and `ks` without repetition: if `m`'s block `y` is `B`, then `M` has a block `y` whose
4 bytes at byte `4 k` (`Block.read`) are related to `k` by `R` for every index `k` of `ks`, and
are `B`'s for every other `k` (`putFloats_read_apart`). For every block, relation, indices and
memories. -/
theorem LnOut.read {y : Nat} {R : Nat → List MemByte → Prop} {ks : List Nat} {m M : Mem}
    (h : LnOut y R ks m M) (hR : ∀ k bs, R k bs → bs.length = 4) (hd : ks.Nodup)
    {B : MojoProof.Sem.Block} (hB : m.blocks y = some B) :
    ∃ B', M.blocks y = some B' ∧ (∀ k ∈ ks, R k (B'.read (4 * k) 4)) ∧
      ∀ k, k ∉ ks → B'.read (4 * k) 4 = B.read (4 * k) 4 := by
  obtain ⟨-, bss, hr, hy⟩ := h
  rw [hB, Option.map_some] at hy
  refine ⟨_, hy, fun k hk => ?_, fun k hk => putFloats_read_apart hR hr hk B⟩
  clear hy hB
  induction hr generalizing B with
  | nil => cases hk
  | @cons k' bs ks bss h hs ih =>
    obtain ⟨hn, hd⟩ := List.nodup_cons.1 hd
    show R k ((putFloats ks bss (B.put (4 * k') bs)).read (4 * k) 4)
    by_cases e : k = k'
    · subst e
      have h4 := Block.read_put_self B (4 * k) bs
      rw [hR _ _ h] at h4
      rw [putFloats_read_apart hR hs hn, h4]
      exact h
    · exact ih hd (List.mem_of_ne_of_mem e hk)

/-- **The float layer norm stores at a column, under oracle numbers.** For every binary32 input
`x`, weight `g`, bias `bt`, mean `mu`, inverse deviation `rs` and oracle numbers `d₀`, `d₁`,
`d₂`, `o`: the value of `%503` (IR :718-721) by MojoProof/Sem/Float.lean's rules. `%500 = x - mu`
(`fsub contract` of operands with no recorded product, so never fused, `contract_none`), `%501 =
%500 * rs` and `%502 = %501 * g` (`fmul contract`, each recorded as a product), each through
`deliver` (a NaN result's payload chosen by `d₀`, `d₁`, `d₂`); `%503 = %502 + bt` by `contract`
(Float.lean:115) with `%502`'s factors `(%501, g)` and oracle number `o`, through `deliver` at
`o / 3`. A test definition. -/
def lnVal (x g bt mu rs : Model FloatTy.float.fmt) (d₀ d₁ d₂ o : Nat) : Model FloatTy.float.fmt :=
  deliver (contract false (deliver ((deliver ((deliver (x.sub mu) d₀).mul rs) d₁).mul g) d₂) bt
    (some (deliver ((deliver (x.sub mu) d₀).mul rs) d₁, g)) none o) (o / 3)

/-- **The fused and the unfused results.** For every binary32 input `x`, weight `g`, bias `bt`,
mean `mu`, inverse deviation `rs` and oracle numbers, with `p` the rounded `(x - mu) * rs`
(`%501`, NaN-equal to FloatLib's `(x - mu) * rs`, `NaNEq`): `lnVal` is NaN-equal to the fused
`Model.fma p g bt` (one rounding of `p * g + bt`) if `o % 3 = 1`, and to the unfused
`(p * g) + bt` (`Model.mul`, then `Model.add`) otherwise (`contract`'s cases, Float.lean:124).
So a run that fixes the oracle fixes one of the two, and a statement over every context leaves
both, each up to NaN payloads. -/
theorem lnVal_cases (x g bt mu rs : Model FloatTy.float.fmt) (d₀ d₁ d₂ o : Nat) :
    NaNEq (deliver ((deliver (x.sub mu) d₀).mul rs) d₁) ((x.sub mu).mul rs) ∧
      (o % 3 = 1 ∧ NaNEq (lnVal x g bt mu rs d₀ d₁ d₂ o)
          (Model.fma (deliver ((deliver (x.sub mu) d₀).mul rs) d₁) g bt) ∨
        o % 3 ≠ 1 ∧ NaNEq (lnVal x g bt mu rs d₀ d₁ d₂ o)
          (((deliver ((deliver (x.sub mu) d₀).mul rs) d₁).mul g).add bt)) := by
  have hd : ∀ (r : Model FloatTy.float.fmt) (k : Nat), NaNEq (deliver r k) r := fun r k => by
    cases hr : r.isNaN
    · exact .inl (deliver_of_isNaN_eq_false hr k)
    · exact .inr ⟨isNaN_deliver hr k, hr⟩
  have tr : ∀ {a b c : Model FloatTy.float.fmt}, NaNEq a b → NaNEq b c → NaNEq a c :=
    fun h1 h2 => (GPUProof.UpToNaN.equivalence _).trans h1 h2
  refine ⟨tr (hd _ _) (NaNEq.op (op := .fmul) rfl (hd _ _) (.inl rfl)), ?_⟩
  by_cases ho : o % 3 = 1
  · refine .inl ⟨ho, ?_⟩
    have e : lnVal x g bt mu rs d₀ d₁ d₂ o =
        deliver (Model.fma (deliver ((deliver (x.sub mu) d₀).mul rs) d₁) g bt) (o / 3) := by
      simp [lnVal, contract, ho]
    rw [e]
    exact hd _ _
  · refine .inr ⟨ho, ?_⟩
    have e : lnVal x g bt mu rs d₀ d₁ d₂ o = deliver
        ((deliver ((deliver ((deliver (x.sub mu) d₀).mul rs) d₁).mul g) d₂).add bt) (o / 3) := by
      rcases (by omega : o % 3 = 0 ∨ o % 3 = 2) with h | h <;> simp [lnVal, contract, h]
    rw [e]
    exact tr (hd _ _) (NaNEq.op (op := .fadd) rfl (hd _ _) (.inl rfl))

/-- **A finite float stored is the float library's layer norm output.** For every binary32 input
`x`, weight `g`, bias `bt`, mean `mu`, inverse deviation `rs` and oracle numbers: if
`lnVal x g bt mu rs d₀ d₁ d₂ o` is finite, it is `MojoProof.Float.lnOut fused x mu rs g bt`
(MojoProof/Float/Norm.lean, `((x - mu) * rs) * g + bt` by `Model.sub`, `Model.mul` and either
`Model.mul` and `Model.add` or one `Model.fma`), fused exactly when `o % 3 = 1`. The proof: the
results of the computation the oracle selects are then finite, so not NaN, and `deliver` keeps
each (`deliver_of_isNaN_eq_false`). Fused, these are the `fma`'s result and its factor `%501` and
`%501`'s factor `%500` (FloatLib's `Model.isFinite_of_isFinite_fma` and `_mul`); the separately
rounded product `%502` is not part of that result, and it may be infinite then
(MojoProofTest/LnRunTest.lean's `lnVal_inf`). Unfused, these are each rounded step, `%503`,
`%502`, `%501` and `%500` (`_add` and `_mul`). -/
theorem lnVal_finite {x g bt mu rs : Model FloatTy.float.fmt} {d₀ d₁ d₂ o : Nat}
    (h : (lnVal x g bt mu rs d₀ d₁ d₂ o).isFinite = true) :
    lnVal x g bt mu rs d₀ d₁ d₂ o = MojoProof.Float.lnOut (o % 3 == 1) x mu rs g bt := by
  have hI : FloatTy.float.fmt.isIEEE = true := rfl
  have fd : ∀ {r : Model FloatTy.float.fmt} {k : Nat}, (deliver r k).isFinite = true →
      deliver r k = r ∧ r.isFinite = true := by
    intro r k hk
    cases hr : r.isNaN
    · have e := deliver_of_isNaN_eq_false hr k
      exact ⟨e, e ▸ hk⟩
    · have e := isNaN_deliver hr k
      rw [Model.isNaN_eq_false_of_isFinite_eq_true _ hk] at e
      cases e
  unfold lnVal at h ⊢
  obtain ⟨e3, h3⟩ := fd h
  rw [e3]
  by_cases ho : o % 3 = 1
  · simp only [contract, ho, Bool.false_eq_true, ↓reduceIte] at h3 ⊢
    obtain ⟨e1, h1⟩ := fd (Model.isFinite_of_isFinite_fma hI h3).1
    obtain ⟨e0, -⟩ := fd (Model.isFinite_of_isFinite_mul hI h1).1
    rw [e1, e0]
    simp [MojoProof.Float.lnOut]
  · have hc : ∀ a : Model FloatTy.float.fmt,
        contract false a bt (some (deliver ((deliver (x.sub mu) d₀).mul rs) d₁, g)) none o =
          a.add bt := by
      intro a
      rcases (by omega : o % 3 = 0 ∨ o % 3 = 2) with h' | h' <;> simp [contract, h']
    rw [hc] at h3 ⊢
    obtain ⟨e2, h2⟩ := fd (Model.isFinite_of_isFinite_add hI h3).1
    obtain ⟨e1, h1⟩ := fd (Model.isFinite_of_isFinite_mul hI h2).1
    obtain ⟨e0, -⟩ := fd (Model.isFinite_of_isFinite_mul hI h1).1
    rw [e2, e1, e0]
    simp [MojoProof.Float.lnOut, ho]

/-- **The error of a finite float stored.** For every binary32 input `x`, weight `g`, bias `bt`,
mean word `mu`, inverse deviation word `rs`, oracle numbers and reals `μ₀`, `w`, `e`, `κ` with
`mu` within `e` of `μ₀` and `rs` within relative error `κ` of `w`: if `lnVal x g bt mu rs d₀ d₁
d₂ o` is finite, it is within FloatLib's mixed error `(u, lnErr u η e κ w g (x - μ₀))` of
`(x - μ₀) · w · g + bt`, `u` and `η` binary32's unit roundoff and underflow allowance, fused or
not. `lnVal_finite`, then `MojoProof.Float.lnOut_error`. Nothing is claimed of an infinite or NaN
float; how close `mu` and `rs` are to the row's mean and `1 / √(var + ε)` is the premise. -/
theorem lnVal_error {x g bt mu rs : Model FloatTy.float.fmt} {d₀ d₁ d₂ o : Nat} {μ₀ w e κ : ℝ}
    (hμ : |mu.toReal - μ₀| ≤ e) (hr : FloatLib.Numerics.MixedError rs.toReal w κ 0)
    (h : (lnVal x g bt mu rs d₀ d₁ d₂ o).isFinite = true) :
    FloatLib.Numerics.MixedError (lnVal x g bt mu rs d₀ d₁ d₂ o).toReal
      ((x.toReal - μ₀) * w * g.toReal + bt.toReal) (Model.unitRoundoffAt FloatTy.float.fmt)
      (MojoProof.Float.lnErr (Model.unitRoundoffAt FloatTy.float.fmt)
        (Model.underflowErrorAt FloatTy.float.fmt) e κ w g.toReal (x.toReal - μ₀)) := by
  have hI : FloatTy.float.fmt.isIEEE = true := rfl
  have e := lnVal_finite h
  rw [e] at h ⊢
  exact MojoProof.Float.lnOut_error hI _ hμ hr h

/-- **The bytes of layer norm's float at column `k`.** For every row length `n`, binary32 rows
`X`, `G`, `Bt`, mean `mu`, inverse deviation `rs`, index `k` and bytes `bs`: `k < n` and `bs` is
the layout's encoding (`Layout.encode` at `float`, the encoding `Mem.Holds` reads) of
`lnVal X[k] G[k] Bt[k] mu rs` under some oracle numbers. A test definition. -/
def LnBytes {n : Nat} (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n])
    (mu rs : Model FloatTy.float.fmt) (k : Nat) (bs : List MemByte) : Prop :=
  ∃ h : k < n, ∃ d₀ d₁ d₂ o, ln.prog.layout.encode (.fp .float) (.ofFloat .float
    (lnVal (TorchLean.Tensor.Rep.get X (⟨k, h⟩, ())) (TorchLean.Tensor.Rep.get G (⟨k, h⟩, ()))
      (TorchLean.Tensor.Rep.get Bt (⟨k, h⟩, ())) mu rs d₀ d₁ d₂ o)) = some bs

/-- `LnBytes`' lists have 4 bytes (`Layout.encode_length`), for every row length, rows, `mu`, `rs`
and index. -/
theorem LnBytes.length {n : Nat} {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]}
    {mu rs : Model FloatTy.float.fmt} (k : Nat) (bs : List MemByte)
    (h : LnBytes X G Bt mu rs k bs) : bs.length = 4 := by
  obtain ⟨_, _, _, _, _, he⟩ := h
  exact Layout.encode_length _ _ _ _ he

/-- **The error of the float in `LnBytes`' bytes.** For every row length `n`, binary32 rows `X`,
`G`, `Bt`, words `mu`, `rs`, index `k` and bytes `bs` with `LnBytes X G Bt mu rs k bs`, and reals
`μ₀`, `w`, `e`, `κ` with `mu` within `e` of `μ₀` and `rs` within relative error `κ` of `w`:
`k < n` and `bs` is the binary32 encoding of a float that, if finite, is within FloatLib's mixed
error `(u, lnErr u η e κ w G[k] (X[k] - μ₀))` of `(X[k] - μ₀) · w · G[k] + Bt[k]`
(`lnVal_error`). -/
theorem LnBytes.error {n : Nat} {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]}
    {mu rs : Model FloatTy.float.fmt} {k : Nat} {bs : List MemByte}
    (h : LnBytes X G Bt mu rs k bs) {μ₀ w e κ : ℝ} (hμ : |mu.toReal - μ₀| ≤ e)
    (hr : FloatLib.Numerics.MixedError rs.toReal w κ 0) :
    ∃ hn : k < n, ∃ v : Model FloatTy.float.fmt,
      ln.prog.layout.encode (.fp .float) (.ofFloat .float v) = some bs ∧
      (v.isFinite = true → FloatLib.Numerics.MixedError v.toReal
        (((TorchLean.Tensor.Rep.get X (⟨k, hn⟩, ())).toReal - μ₀) * w *
            (TorchLean.Tensor.Rep.get G (⟨k, hn⟩, ())).toReal +
          (TorchLean.Tensor.Rep.get Bt (⟨k, hn⟩, ())).toReal)
        (Model.unitRoundoffAt FloatTy.float.fmt)
        (MojoProof.Float.lnErr (Model.unitRoundoffAt FloatTy.float.fmt)
          (Model.underflowErrorAt FloatTy.float.fmt) e κ w
          (TorchLean.Tensor.Rep.get G (⟨k, hn⟩, ())).toReal
          ((TorchLean.Tensor.Rep.get X (⟨k, hn⟩, ())).toReal - μ₀))) := by
  obtain ⟨hn, d₀, d₁, d₂, o, he⟩ := h
  exact ⟨hn, _, he, lnVal_error hμ hr⟩

/-- The accesses of layer norm's round at float `k` (IR :714-723), in the order of the run:
thread `w`'s reads of 4 bytes at byte `4 k` of `x` (`%497`, :715), of `g` (`%498`, :716) and of
`b` (`%499`, :717), the last two marked `!invariant.load`, and then its write of 4 bytes there in
`y` (:722); none atomic. For every thread, blocks and index. A test definition. -/
def lnAcc (w : Who) (y g b x k : Nat) : List Access :=
  [⟨w, ⟨x, ((4 * k : Nat) : Int)⟩, 4, false, none, false⟩,
    ⟨w, ⟨g, ((4 * k : Nat) : Int)⟩, 4, false, none, true⟩,
    ⟨w, ⟨b, ((4 * k : Nat) : Int)⟩, 4, false, none, true⟩,
    ⟨w, ⟨y, ((4 * k : Nat) : Int)⟩, 4, true, none, false⟩]

/-- **Memory `M`'s trace is `m`'s with the rounds of `ks` in front.** `M.trace` (`Mem.trace`,
newest first) is `m.trace` with, in front, the reverse of `ks.flatMap (lnAcc w y g b x)`: that
list has the accesses of each `k` of `ks` in turn, in the order of the run, so the prefix is
newest first (one round's is `[write y, read b, read g, read x]`, the last round's write the
newest event); and no other event: no barrier, no atomic and no access but those. For every
thread, blocks, list of indices and memories. With `lnAcc_writes`, the writes, in the order of the
run, are exactly the 4-byte writes at `ks`' floats of `y`, in `ks`' order; the values read and
written are not recorded. A test definition. -/
def LnTrace (w : Who) (y g b x : Nat) (ks : List Nat) (m M : Mem) : Prop :=
  M.trace = ((ks.flatMap (lnAcc w y g b x)).map .access).reverse ++ m.trace

/-- `LnTrace w y g b x []` (no event) between two memories with the same trace, for every thread
and blocks; their blocks may differ. -/
theorem LnTrace.refl {w : Who} {y g b x : Nat} {m M : Mem} (h : M.trace = m.trace) :
    LnTrace w y g b x [] m M := by
  simp [LnTrace, h]

/-- The rounds of `ks` from `m` to `M` and then of `ks'` from `M` to `M'` are those of `ks ++ ks'`
from `m` to `M'`, for every thread, blocks and memories. -/
theorem LnTrace.trans {w : Who} {y g b x : Nat} {ks ks' : List Nat} {m M M' : Mem}
    (h : LnTrace w y g b x ks m M) (h' : LnTrace w y g b x ks' M M') :
    LnTrace w y g b x (ks ++ ks') m M' := by
  rw [LnTrace, h', h, List.flatMap_append, List.map_append, List.reverse_append,
    List.append_assoc]

/-- The writes among the rounds' accesses of `ks` in the order of the run (`ks.flatMap lnAcc`,
whose reverse `LnTrace` puts in front of the trace) are thread `w`'s 4-byte non-atomic writes at
byte `4 k` of `y` for `k` in `ks`, in `ks`' order, for every thread, blocks and list of
indices. -/
theorem lnAcc_writes (w : Who) (y g b x : Nat) (ks : List Nat) :
    (ks.flatMap (lnAcc w y g b x)).filter (·.write) =
      ks.map fun k => ⟨w, ⟨y, ((4 * k : Nat) : Int)⟩, 4, true, none, false⟩ := by
  induction ks with
  | nil => rfl
  | cons k ks ih => simp [List.flatMap_cons, ih, lnAcc]

/-- `LnTrace` in `Ext`'s form: the events put in front of `m`'s trace are all accesses of 4 bytes
by thread `w`, none atomic, the writes in block `y` and the reads in `x`, `g` or `b`. For every
thread, blocks, indices and memories. -/
theorem LnTrace.ext {w : Who} {y g b x : Nat} {ks : List Nat} {m M : Mem}
    (h : LnTrace w y g b x ks m M) :
    Ext (fun e => ∃ a, e = .access a ∧ a.who = w ∧ a.len = 4 ∧ a.atomic = none ∧
      (a.write = true → a.ptr.block = y) ∧
      (a.write = false → a.ptr.block = x ∨ a.ptr.block = g ∨ a.ptr.block = b)) m M := by
  refine ⟨_, h, fun e he => ?_⟩
  obtain ⟨a, ha, rfl⟩ := List.mem_map.1 (List.mem_reverse.1 he)
  obtain ⟨k, -, hk⟩ := List.mem_flatMap.1 ha
  simp only [lnAcc, List.mem_cons, List.mem_nil_iff, or_false] at hk
  rcases hk with rfl | rfl | rfl | rfl <;> simp

/-- A run of loads (`SEff.load`) from `m` to `m'` keeps the blocks, for every valuation, node
values, list of effects that are all loads and memories (a load only logs its access). -/
theorem fold_loads {V : Valuation} {vs : List (Except Fault Val)} :
    ∀ (es : List SEff), (∀ e ∈ es, ∃ a b p, e = .load a b p) → ∀ (m m' : Mem),
      es.foldlM (SEff.apply V vs) m = .ok m' → m'.blocks = m.blocks := by
  intro es
  induction es with
  | nil =>
    intro _ m m' h
    simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h
    rw [h]
  | cons e es ih =>
    intro hl m m' h
    rw [List.foldlM_cons] at h
    obtain ⟨m1, h1, h2⟩ := Except.bind_eq_ok.1 h
    refine (ih (fun e' he' => hl e' (List.mem_cons_of_mem _ he')) m1 m' h2).trans ?_
    obtain ⟨a, b, p, rfl⟩ := hl e (by simp)
    rw [SEff.apply] at h1
    split at h1
    · obtain ⟨x, -, h1⟩ := Except.bind_eq_ok.1 h1
      obtain ⟨q, -, h1⟩ := Except.bind_eq_ok.1 h1
      simp only [pure, Except.pure, Except.ok.injEq] at h1
      subst h1
      rfl
    · simp [throw, throwThe, MonadExceptOf.throw] at h1

/-- **Loads and then one store of a float make `LnOut y R [k]` and log their accesses.** For every
valuation `V` of a function `F` of a program `P`, node values, effects `es` that are all loads,
a statement `(lbl, pc)` of `F` that is a `store` of a type `t` of 4 stored bytes in `P`'s layout
of a value `v` that evaluates to `w` through a pointer `p` that evaluates to `⟨y, 4 k⟩`, and
relation `R` that holds of `k` and every encoding of `w` at `t`: if the effects `es` and then that
store run from `V`'s memory to `M` (`SEff.run`), then `M`'s blocks are `V`'s memory's with `w`'s
bytes (`Layout.encode`) put at byte `4 k` of `y` (`LnOut y R [k]`), and `M`'s trace is `V`'s
memory's with, in front, the reverse of the loads' accesses `acs` (`SEff.access`) followed by
thread `V.ctx.who`'s non-atomic write of 4 bytes at `⟨y, 4 k⟩` (their order in the run; the trace
is newest first). -/
theorem run_put {V : Valuation} {vs : List (Except Fault Val)} {P : Program} {F : Func}
    {es : List SEff} {lbl pc : Nat} {v p : SVal} {dst : Option Nat} {vol : Bool} {t : Ty}
    {pv : Value} {a : Nat} {pv' : Value} {al : Option Nat} {md : List (String × Nat)}
    {y k : Nat} {w : Val} {R : Nat → List MemByte → Prop} {M : Mem} (hF : V.fn = F)
    (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .store vol (.mk t pv) (.mk (.ptr a) pv') al, md⟩)
    (h4 : P.layout.stored t = 4)
    (hl : ∀ e ∈ es, ∃ a b q, e = .load a b q) (hv : v.eval V vs = .ok w)
    (hR : ∀ bs, P.layout.encode t w = some bs → R k bs)
    (hp : p.eval V vs = .ok (.ptr ⟨y, ((4 * k : Nat) : Int)⟩))
    (h : SEff.run V vs (es ++ [.store lbl pc v p]) = .ok M) :
    LnOut y R [k] V.mem M ∧ ∃ acs, es.mapM (SEff.access V vs) = .ok acs ∧
      M.trace = ((acs ++ [(⟨V.ctx.who, ⟨y, ((4 * k : Nat) : Int)⟩, 4, true, none, false⟩ :
        Access)]).map Event.access).reverse ++ V.mem.trace := by
  refine ⟨?_, ?_⟩
  · unfold SEff.run at h
    rw [List.foldlM_append] at h
    obtain ⟨m1, h1, h2⟩ := Except.bind_eq_ok.1 h
    have hb1 := fold_loads es hl V.mem m1 h1
    rw [List.foldlM_cons] at h2
    obtain ⟨m2, h3, h5⟩ := Except.bind_eq_ok.1 h2
    simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h5
    subst h5
    simp only [SEff.apply, Valuation.stmt_of_fn hF hs] at h3
    obtain ⟨x, hx, h3⟩ := Except.bind_eq_ok.1 h3
    rw [hv] at hx
    obtain rfl : w = x := Except.ok.inj hx
    simp only [hp, bind, Except.bind, Val.addr?, pure, Except.pure] at h3
    obtain ⟨blk, bs, hc, -, he, rfl⟩ := Mem.store_inv h3
    have hy : m1.blocks y = some blk := (Mem.check_inv hc).1
    rw [hb1] at hy
    refine ⟨fun q hq => ?_, [bs], .cons (hR bs (by rw [← hP]; exact he)) .nil, ?_⟩
    · simp only [Mem.log, Mem.set, hq, ↓reduceIte, hb1]
    · have e4 : (4 * (k : Int)).toNat = 4 * k := by omega
      simp [Mem.log, Mem.set, hy, putFloats, e4]
  · have hA : SEff.allocates (es ++ [.store lbl pc v p]) = false := by
      simp only [SEff.allocates, List.any_eq_false]
      intro e he
      rcases List.mem_append.1 he with he | he
      · obtain ⟨_, _, _, rfl⟩ := hl e he
        exact Bool.false_ne_true
      · rw [List.mem_singleton] at he
        subst he
        exact Bool.false_ne_true
    obtain ⟨acs, has, htr⟩ := SEff.foldlM_trace hA h
    rw [List.mapM_append] at has
    obtain ⟨as₁, h₁, has⟩ := Except.bind_eq_ok.1 has
    obtain ⟨as₂, h₂, has⟩ := Except.bind_eq_ok.1 has
    have hst : SEff.access V vs (.store lbl pc v p) =
        .ok ⟨V.ctx.who, ⟨y, ((4 * k : Nat) : Int)⟩, 4, true, none, false⟩ := by
      subst hP
      simp only [SEff.access, Valuation.stmt_of_fn hF hs, hp, bind, Except.bind, Val.addr?, pure,
        Except.pure, h4]
    simp only [List.mapM_cons, List.mapM_nil, hst, bind, Except.bind, pure, Except.pure,
      Except.ok.injEq] at h₂
    simp only [pure, Except.pure, Except.ok.injEq] at has
    subst h₂ has
    exact ⟨as₁, h₁, htr⟩

-- `run_put` at 67bd004: the run's success gives the stored value `w` (`v.eval V vs = .ok w`, the
-- store's first step), and `w`'s encoding at `t` has `P.layout.stored t = 4` bytes
-- (`Layout.encode_length`), so `run_put` at four-byte lists, its first conjunct.
example {V : Valuation} {vs : List (Except Fault Val)} {P : Program} {F : Func}
    {es : List SEff} {lbl pc : Nat} {v p : SVal} {dst : Option Nat} {vol : Bool} {t : Ty}
    {pv : Value} {a : Nat} {pv' : Value} {al : Option Nat} {md : List (String × Nat)}
    {y k : Nat} {M : Mem} (hF : V.fn = F) (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .store vol (.mk t pv) (.mk (.ptr a) pv') al, md⟩)
    (h4 : P.layout.stored t = 4)
    (hl : ∀ e ∈ es, ∃ a b q, e = .load a b q)
    (hp : p.eval V vs = .ok (.ptr ⟨y, ((4 * k : Nat) : Int)⟩))
    (h : SEff.run V vs (es ++ [.store lbl pc v p]) = .ok M) :
    LnOut y (fun _ bs => bs.length = 4) [k] V.mem M := by
  have hw : ∃ w, v.eval V vs = .ok w := by
    unfold SEff.run at h
    rw [List.foldlM_append] at h
    obtain ⟨m1, -, h2⟩ := Except.bind_eq_ok.1 h
    rw [List.foldlM_cons] at h2
    obtain ⟨m2, h3, -⟩ := Except.bind_eq_ok.1 h2
    simp only [SEff.apply, Valuation.stmt_of_fn hF hs] at h3
    obtain ⟨w, hw, -⟩ := Except.bind_eq_ok.1 h3
    exact ⟨w, hw⟩
  obtain ⟨w, hv⟩ := hw
  exact (run_put hF hP hs h4 hl hv (fun _ he => (Layout.encode_length _ _ _ _ he).trans h4) hp
    h).1

/-- Entering a block whose summary has no effects keeps the memory, for every flag, valuation,
label and summary with `S.effs = []`. -/
theorem mem_none {c : Bool} {V : Valuation} {l : Nat} {S : Summary} (h : S.effs = []) :
    (V.intoWith c l S).mem = V.mem :=
  (Valuation.intoWith_mem c V l S).trans (Valuation.after_mem (by rw [h]; rfl))

/-- Entering a block after its summary's effects run to `me` gives the memory `me`, for every
flag, valuation, label and summary. -/
theorem mem_run {c : Bool} {V : Valuation} {l : Nat} {S : Summary} {me : Mem}
    (h : SEff.run V (vals V S.nodes) S.effs = .ok me) : (V.intoWith c l S).mem = me :=
  (Valuation.intoWith_mem c V l S).trans (Valuation.after_mem h)

/-- **Layer norm's state at the loop's header, at every block size.** Layer norm's last loop (the
corpus files ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B`: a
valuation `W` of layer norm's program and of the family's function `lnFam.fn B`
(MojoProofTest/LnRound.lean: the bs128 file's kernel with the step `%473`'s constant `B`) at the
header `%469` after its `phi`s with the loop index `%471` the word of `i`, `%472` zero and `%470`
some value, the thread index, the row length `n`, the mean `%460` and inverse deviation `%464` with
no recorded product and the four row pointers with their buffers, fits and rows. The premises of
`round_trueB`, `round_falseB` and `LnHead.exit`; `AtHead` is `LnHead` at 128. A test
definition. -/
structure LnHead (B n tid i y g b x : Nat)
    (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]) (mu rs : Model FloatTy.float.fmt)
    (W : Valuation) : Prop where
  /-- The state from its facts. -/
  mk ::
  /-- The program is layer norm's. -/
  prog : W.ctx.prog = ln.prog
  /-- The function is the family's at `B`. -/
  fn : W.fn = lnFam.fn B
  /-- The loop index `%471` is `i`. -/
  r476 : W.regs 476 = some (.bits 64 (BitVec.ofNat 64 i))
  /-- `%472` is zero. -/
  r478 : W.regs 478 = some (.bits 64 (BitVec.ofNat 64 0))
  /-- `%470` has a value. -/
  r474 : ∃ v, W.regs 474 = some v
  /-- The thread index is `tid`. -/
  r24 : W.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid))
  /-- The row length `%65` is `n`. -/
  r67 : W.regs 67 = some (.bits 64 (BitVec.ofNat 64 n))
  /-- The mean `%460` is `mu`. -/
  r462 : W.regs 462 = some (.ofFloat .float mu)
  /-- The inverse deviation `%464` is `rs`. -/
  r466 : W.regs 466 = some (.ofFloat .float rs)
  /-- No product is recorded for the mean. -/
  q462 : W.prods 462 = none
  /-- No product is recorded for the inverse deviation. -/
  q466 : W.prods 466 = none
  /-- The output pointer `%466`. -/
  r468 : W.regs 468 = some (.ptr ⟨y, 0⟩)
  /-- The weight pointer `%467`. -/
  r469 : W.regs 469 = some (.ptr ⟨g, 0⟩)
  /-- The bias pointer `%468`. -/
  r470 : W.regs 470 = some (.ptr ⟨b, 0⟩)
  /-- The input pointer `%70`. -/
  r72 : W.regs 72 = some (.ptr ⟨x, 0⟩)
  /-- `y` is a writable buffer of `4 n` bytes. -/
  by' : W.mem.Buffer y (n * 4) 4 true
  /-- `g` is a read-only buffer of `4 n` bytes. -/
  bg : W.mem.Buffer g (n * 4) 4 false
  /-- `b` is a read-only buffer of `4 n` bytes. -/
  bb : W.mem.Buffer b (n * 4) 4 false
  /-- `x` is a read-only buffer of `4 n` bytes. -/
  bx : W.mem.Buffer x (n * 4) 4 false
  /-- `y`'s bytes fit the address space. -/
  fy : W.mem.Fits ln.prog.layout y (n * 4)
  /-- `g`'s bytes fit the address space. -/
  fg : W.mem.Fits ln.prog.layout g (n * 4)
  /-- `b`'s bytes fit the address space. -/
  fb : W.mem.Fits ln.prog.layout b (n * 4)
  /-- `x`'s bytes fit the address space. -/
  fx : W.mem.Fits ln.prog.layout x (n * 4)
  /-- `x` holds the row `X`. -/
  hX : W.mem.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
    (rowMajor ln.prog.layout (.fp .float) 0) X
  /-- `g` holds the weight `G`. -/
  hG : W.mem.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
    (rowMajor ln.prog.layout (.fp .float) 0) G
  /-- `b` holds the bias `Bt`. -/
  hB : W.mem.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
    (rowMajor ln.prog.layout (.fp .float) 0) Bt

/-- `LnHead` at index `i + B` after a round. Layer norm's last loop (the corpus files
ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B`, for the family's
function `lnFam.fn B`, every row length, thread, index, blocks with `x`, `g` and `b` not `y`,
tensors, `mu`, `rs` and valuations `W` (with `LnHead` at `i`) and `W'` whose memory is `W`'s with
stores into `y` (`LnOut`): `LnHead` holds at `W'` and `i + B` given `W'`'s program, function and
registers. -/
theorem LnHead.next {B n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]}
    {mu rs : Model FloatTy.float.fmt} {W W' : Valuation} {R : Nat → List MemByte → Prop}
    {ks : List Nat} (hA : LnHead B n tid i y g b x X G Bt mu rs W) (hO : LnOut y R ks W.mem W'.mem)
    (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y)
    (prog : W'.ctx.prog = ln.prog) (fn : W'.fn = lnFam.fn B)
    (r476 : W'.regs 476 = some (.bits 64 (BitVec.ofNat 64 (i + B))))
    (r478 : W'.regs 478 = some (.bits 64 (BitVec.ofNat 64 0)))
    (r474 : ∃ v, W'.regs 474 = some v)
    (r24 : W'.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (r67 : W'.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (r462 : W'.regs 462 = some (.ofFloat .float mu))
    (r466 : W'.regs 466 = some (.ofFloat .float rs))
    (q462 : W'.prods 462 = none) (q466 : W'.prods 466 = none)
    (r468 : W'.regs 468 = some (.ptr ⟨y, 0⟩)) (r469 : W'.regs 469 = some (.ptr ⟨g, 0⟩))
    (r470 : W'.regs 470 = some (.ptr ⟨b, 0⟩)) (r72 : W'.regs 72 = some (.ptr ⟨x, 0⟩)) :
    LnHead B n tid (i + B) y g b x X G Bt mu rs W' :=
  ⟨prog, fn, r476, r478, r474, r24, r67, r462, r466, q462, q466, r468, r469, r470, r72,
    hO.buffer hA.by', hO.buffer hA.bg, hO.buffer hA.bb, hO.buffer hA.bx, hO.fits hA.fy,
    hO.fits hA.fg, hO.fits hA.fb, hO.fits hA.fx, hO.holds hxy hA.hX, hO.holds hgy hA.hG,
    hO.holds hby hA.hB⟩

/-- **Layer norm's state at the loop's header.** Layer norm (the corpus file) at block size 128:
`LnHead` at 128, a valuation `W` of `lnFam.fn 128` (which is `ln.fn_0`, `lnFam.prog_corpus`) at
the header `%469` after its `phi`s (:678-680) with the loop index `%471` the word of `i`, `%472`
zero and `%470` some value, `tid` the word of `tid`, the row length `%65` the word of `n`, the mean
`%460` and the inverse deviation `%464` binary32 `mu` and `rs` with no recorded product, the
pointers `%466` (`y`, the output), `%467` (`g`), `%468` (`b`) and `%70` (`x`) at offset 0 of
buffers of `4 n` bytes (`y` writable, the others read-only) that fit, and `x`, `g` and `b` holding
the rows `X`, `G` and `Bt` (row-major binary32): the premises of `round_true`, `round_false`
(MojoProofTest/LnRound.lean) and `AtHead.exit`. A test definition. -/
abbrev AtHead (n tid i y g b x : Nat) (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n])
    (mu rs : Model FloatTy.float.fmt) (W : Valuation) : Prop :=
  LnHead 128 n tid i y g b x X G Bt mu rs W

-- `AtHead.fn` at 01391ef (a field of the structure `AtHead`): `LnHead.fn` at 128 with
-- `lnFam.prog_corpus`.
example {n tid i y g b x : Nat} {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]}
    {mu rs : Model FloatTy.float.fmt} {W : Valuation} (hA : AtHead n tid i y g b x X G Bt mu rs W) :
    W.fn = ln.fn_0 :=
  hA.fn.trans lnFam.prog_corpus.2

/-- `AtHead` at index `i + 128` after a round. Layer norm (the corpus file) at block size 128,
for every row length, thread, index, blocks with `x`, `g` and `b` not `y`, tensors, `mu`, `rs`
and valuations `W` (with `AtHead` at `i`) and `W'` whose memory is `W`'s with stores into `y`
(`LnOut`): `AtHead` holds at `W'` and `i + 128` given `W'`'s program, function and registers
(`LnHead.next` at 128). -/
theorem AtHead.next {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]}
    {mu rs : Model FloatTy.float.fmt} {W W' : Valuation} {R : Nat → List MemByte → Prop}
    {ks : List Nat} (hA : AtHead n tid i y g b x X G Bt mu rs W) (hO : LnOut y R ks W.mem W'.mem)
    (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y)
    (prog : W'.ctx.prog = ln.prog) (fn : W'.fn = ln.fn_0)
    (r476 : W'.regs 476 = some (.bits 64 (BitVec.ofNat 64 (i + 128))))
    (r478 : W'.regs 478 = some (.bits 64 (BitVec.ofNat 64 0)))
    (r474 : ∃ v, W'.regs 474 = some v)
    (r24 : W'.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (r67 : W'.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (r462 : W'.regs 462 = some (.ofFloat .float mu))
    (r466 : W'.regs 466 = some (.ofFloat .float rs))
    (q462 : W'.prods 462 = none) (q466 : W'.prods 466 = none)
    (r468 : W'.regs 468 = some (.ptr ⟨y, 0⟩)) (r469 : W'.regs 469 = some (.ptr ⟨g, 0⟩))
    (r470 : W'.regs 470 = some (.ptr ⟨b, 0⟩)) (r72 : W'.regs 72 = some (.ptr ⟨x, 0⟩)) :
    AtHead n tid (i + 128) y g b x X G Bt mu rs W' :=
  LnHead.next hA hO hxy hgy hby prog (fn.trans lnFam.prog_corpus.2.symm) r476 r478 r474 r24 r67
    r462 r466 q462 q466 r468 r469 r470 r72

-- `AtHead.next` at 67bd004: `AtHead.next` at four-byte lists.
example {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]}
    {mu rs : Model FloatTy.float.fmt} {W W' : Valuation} {ks : List Nat}
    (hA : AtHead n tid i y g b x X G Bt mu rs W)
    (hO : LnOut y (fun _ bs => bs.length = 4) ks W.mem W'.mem)
    (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y)
    (prog : W'.ctx.prog = ln.prog) (fn : W'.fn = ln.fn_0)
    (r476 : W'.regs 476 = some (.bits 64 (BitVec.ofNat 64 (i + 128))))
    (r478 : W'.regs 478 = some (.bits 64 (BitVec.ofNat 64 0)))
    (r474 : ∃ v, W'.regs 474 = some v)
    (r24 : W'.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (r67 : W'.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (r462 : W'.regs 462 = some (.ofFloat .float mu))
    (r466 : W'.regs 466 = some (.ofFloat .float rs))
    (q462 : W'.prods 462 = none) (q466 : W'.prods 466 = none)
    (r468 : W'.regs 468 = some (.ptr ⟨y, 0⟩)) (r469 : W'.regs 469 = some (.ptr ⟨g, 0⟩))
    (r470 : W'.regs 470 = some (.ptr ⟨b, 0⟩)) (r72 : W'.regs 72 = some (.ptr ⟨x, 0⟩)) :
    AtHead n tid (i + 128) y g b x X G Bt mu rs W' :=
  hA.next hO hxy hgy hby prog fn r476 r478 r474 r24 r67 r462 r466 q462 q466 r468 r469 r470 r72

/-- A round (`Valuation.roundWith`) keeps the context and the function, for every flag, header,
summary, path and valuation. -/
theorem round_ctx {c : Bool} {h : Nat} {S : Summary} {B : List (Nat × List Cond × Summary)}
    {W : Valuation} : (Valuation.roundWith c h S B W).ctx = W.ctx ∧
      (Valuation.roundWith c h S B W).fn = W.fn :=
  ⟨(Valuation.roundWith_k c h S B 1 W).1, (Valuation.roundWith_k c h S B 1 W).2.1⟩

/-- The family's function `lnFam.fn B` has the bs128 file's block `%496` (`ln.fn_0.b_48`, label
501) at that label, for every block size `B` (the family changes only the header `%469`). By
`rfl`. A fact about the function's blocks. -/
theorem fnB_496 (B : Nat) :
    (lnFam.fn B).blocks.find? (·.label == 501) = some ln.fn_0.b_48 := by
  rfl

/-- The memory and trace of the round with the guard true, at every block size (`LnHead.roundT`'s
last two conjuncts, from its first). Layer norm's last loop (the corpus files
ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B`, for the family's
function `lnFam.fn B` (in a context of `ln.prog`), every row length `n < 2 ^ 32`, thread
`tid < 1024`, index `i` with `i + tid < n`, blocks, tensors, `mu`, `rs` and valuation `W`
with `LnHead` at `i` and the round's premises (`RoundWith`, `round_trueB`): the round's memory's
blocks are `W`'s with the bytes of `lnVal X[i + tid] G[i + tid] Bt[i + tid] mu rs` put at float
`i + tid` of `y` (`LnOut` at `LnBytes`), and its trace is `W`'s with the round's accesses at float
`i + tid` in front, newest first (`LnTrace`). A run theorem's premise (IR :714-723 of each file). -/
theorem LnHead.roundT_out {B n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : LnHead B n tid i y g b x X G Bt mu rs W) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hg : i + tid < n)
    (hR : RoundWith true (lnTB B).h (lnTB B).p (lnTB B).dh (lnTB B).H (lnTB B).B W) :
    LnOut y (LnBytes X G Bt mu rs) [i + tid] W.mem
      (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).mem ∧
      LnTrace W.ctx.who y g b x [i + tid] W.mem
      (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).mem := by
  have hA0 := hA
  obtain ⟨hP, hfn, h476, h478, -, h24, h67, h462, h466, hq462, hq466, h468, h469, h470, h72,
    hby', hbg, hbb, hbx, hfy, hfg, hfb, hfx, hX, hG, hB⟩ := hA0
  obl_have e3 : (vals W (lnTB B).H.nodes)[3]?, e4 : (vals W (lnTB B).H.nodes)[4]?
  have e5 : (vals W (lnTB B).H.nodes)[5]? = some (.ok (.ofBool false)) :=
    vals_getElem?_eval rfl (eval_xor_true (SVal.eval_node_take (by decide) e4))
  have e6 : (vals W (lnTB B).H.nodes)[6]? = some (.ok (.ofBool (decide (n ≤ i)))) :=
    vals_getElem?_eval rfl (eval_or_false (SVal.eval_node_take (by decide) e5)
      (SVal.eval_node_take (by decide) e3))
  have hw : WalkWith true ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495)
      [(ln.fn_0.b_48.label, b496.obls, b496), (ln.fn_0.b_55.label, b529.obls, b529),
        (ln.fn_0.b_57.label, b532.obls, b532)] := hR.1.2.2.2.2.2.2.2.2
  obtain ⟨me, hme⟩ := hw.1 (.mem b496.effs) (by decide +kernel)
  obl_have em4 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).mem,
    p490 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).regs 490,
    p491 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).regs 491,
    p492 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).regs 492,
    p493 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).regs 493,
    v6 : (vals ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495) b496.nodes)[6]?
  have hsz : ln.prog.layout.size (.fp .float) = 4 := by rfl
  have p490' : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).regs 490 = some (.ptr ⟨y, ((4 * (i + tid) : Nat) : Int)⟩) := by
    rw [p490, hsz, Nat.mul_comm]
  have p491' : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).regs 491 = some (.ptr ⟨b, ((4 * (i + tid) : Nat) : Int)⟩) := by
    rw [p491, hsz, Nat.mul_comm]
  have p492' : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).regs 492 = some (.ptr ⟨g, ((4 * (i + tid) : Nat) : Int)⟩) := by
    rw [p492, hsz, Nat.mul_comm]
  have p493' : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).regs 493 = some (.ptr ⟨x, ((4 * (i + tid) : Nat) : Int)⟩) := by
    rw [p493, hsz, Nat.mul_comm]
  have hF4 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).fn = lnFam.fn B :=
    (Valuation.intoWith_k _ _ _ _).2.1.trans <| (Valuation.intoWith_k _ _ _ _).2.1.trans <|
      (Valuation.intoWith_k _ _ _ _).2.1.trans <| (Valuation.intoWith_k _ _ _ _).2.1.trans hfn
  have hC4 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).ctx = W.ctx := by
    rw [(Valuation.intoWith_k _ _ _ _).1, (Valuation.intoWith_k _ _ _ _).1,
      (Valuation.intoWith_k _ _ _ _).1, (Valuation.intoWith_k _ _ _ _).1]
  have hP4 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).ctx.prog = ln.prog := by
    rw [hC4]
    exact hP
  have e1 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).mem = me := by
    show (((((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).intoWith true ln.fn_0.b_48.label b496).intoWith true
      ln.fn_0.b_55.label b529).intoWith true ln.fn_0.b_57.label b532).mem = me
    rw [mem_none rfl, mem_none rfl]
    exact mem_run hme
  have hes : b496.effs = [.load 501 0 (.reg 493), .load 501 1 (.reg 492),
      .load 501 2 (.reg 491)] ++ [.store 501 7 (.node 6) (.reg 490)] := by decide +kernel
  rw [hes] at hme
  obtain ⟨hO, acs, hacs, htr⟩ := run_put (es := [.load 501 0 (.reg 493),
    .load 501 1 (.reg 492), .load 501 2 (.reg 491)]) (lbl := 501) (pc := 7)
    (R := LnBytes X G Bt mu rs) hF4 hP4 (by rw [fnB_496]; rfl)
    (by rfl) (by
    intro e he
    simp only [List.mem_cons, List.mem_nil_iff, or_false] at he
    rcases he with rfl | rfl | rfl <;> exact ⟨_, _, _, rfl⟩) (SVal.eval_node v6)
    (fun bs hbs => by unfold LnBytes; exact ⟨hg, _, _, _, _, hbs⟩) (SVal.eval_reg p490') hme
  have s0 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).stmt 501 0 =
      some ⟨some 503, .load false (.fp .float) (.mk (.ptr 0) (.loc 493)) (some 4), []⟩ :=
    Valuation.stmt_of_fn hF4 (by rw [fnB_496]; rfl)
  have s1 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).stmt 501 1 =
      some ⟨some 504, .load false (.fp .float) (.mk (.ptr 0) (.loc 492)) (some 4),
        [("invariant.load", 1)]⟩ :=
    Valuation.stmt_of_fn hF4 (by rw [fnB_496]; rfl)
  have s2 : ((((W.intoWith true (lnTB B).h (lnTB B).H).intoWith true
      ln.fn_0.b_45.label b483).intoWith true ln.fn_0.b_46.label b484).intoWith true
      ln.fn_0.b_47.label b495).stmt 501 2 =
      some ⟨some 505, .load false (.fp .float) (.mk (.ptr 0) (.loc 491)) (some 4),
        [("invariant.load", 1)]⟩ :=
    Valuation.stmt_of_fn hF4 (by rw [fnB_496]; rfl)
  have h4 : ln.prog.layout.stored (.fp .float) = 4 := by rfl
  simp only [List.mapM_cons, List.mapM_nil, SEff.access, s0, s1, s2, SVal.eval_reg p491',
    SVal.eval_reg p492', SVal.eval_reg p493', hC4, hP, h4, bind, Except.bind, Val.addr?, pure,
    Except.pure, Except.ok.injEq, List.any_nil, List.any_cons, beq_self_eq_true,
    Bool.true_or] at hacs
  subst hacs
  rw [em4, hC4] at htr
  rw [em4] at hO
  rw [e1]
  exact ⟨hO, htr⟩

/-- **The round with the guard true, with its store, at every block size.** Layer norm's last loop
(the corpus files ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B` with
`B ≤ 2 ^ 32`, for the family's function `lnFam.fn B` (in a context of `ln.prog`), every row length
`n < 2 ^ 32`, thread `tid < 1024`, index `i` with `i + tid < n` (the guard :708 true), blocks with
`x`, `g` and `b` not `y`, tensors, `mu`, `rs` and valuation `W` with `LnHead` at `i`: the round on
`lnTB B`'s path (`%469`, `%483`, `%484`, `%495`, `%496`, `%529`, `%532`) has its premises
(`round_trueB`), `LnHead` holds after it at `i + B`, its memory's blocks are `W`'s with the bytes of
`lnVal X[i + tid] G[i + tid] Bt[i + tid] mu rs`, under the context's oracle numbers, put at float
`i + tid` of `y` (`LnOut` at `LnBytes`), and its trace is `W`'s with the round's accesses at float
`i + tid` in front, newest first (`LnTrace`): in the order of the run, the loads of `x`, `g` and `b`
and then the store, the round's only effects. A run theorem's premise (IR :677-772 of each file);
`mu`, `rs` are given registers. `AtHead.roundT` is its instance at 128. -/
theorem LnHead.roundT {B n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : LnHead B n tid i y g b x X G Bt mu rs W) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hBs : B ≤ 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y)
    (hg : i + tid < n) :
    RoundWith true (lnTB B).h (lnTB B).p (lnTB B).dh (lnTB B).H (lnTB B).B W ∧
      LnHead B n tid (i + B) y g b x X G Bt mu rs
        (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W) ∧
      LnOut y (LnBytes X G Bt mu rs) [i + tid] W.mem
        (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).mem ∧
      LnTrace W.ctx.who y g b x [i + tid] W.mem
        (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).mem := by
  have hR := MojoProofTest.LnRound.round_trueB B n tid i y g b x W X G Bt mu rs hA.prog hA.fn
    hA.r476 hA.r478 hA.r24 hA.r67 hA.r462 hA.r466 hA.q462 hA.q466 hA.r468 hA.r469 hA.r470 hA.r72
    hA.by' hA.bg hA.bb hA.bx hA.fy hA.fg hA.fb hA.fx hA.hX hA.hG hA.hB ht hn hBs hg
  have hA0 := hA
  obtain ⟨hP, hfn, h476, h478, -, h24, h67, h462, h466, hq462, hq466, h468, h469, h470, h72,
    hby', hbg, hbb, hbx, hfy, hfg, hfb, hfx, hX, hG, hB⟩ := hA0
  obl_have e3 : (vals W (lnTB B).H.nodes)[3]?, e4 : (vals W (lnTB B).H.nodes)[4]?
  have e5 : (vals W (lnTB B).H.nodes)[5]? = some (.ok (.ofBool false)) :=
    vals_getElem?_eval rfl (eval_xor_true (SVal.eval_node_take (by decide) e4))
  have e6 : (vals W (lnTB B).H.nodes)[6]? = some (.ok (.ofBool (decide (n ≤ i)))) :=
    vals_getElem?_eval rfl (eval_or_false (SVal.eval_node_take (by decide) e5)
      (SVal.eval_node_take (by decide) e3))
  have hO := hA.roundT_out ht hn hg hR
  obl_have r476 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 476,
    r478 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 478,
    r474 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 474,
    r24 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 24,
    r67 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 67,
    r462 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 462,
    r466 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 466,
    q462 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).prods 462,
    q466 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).prods 466,
    r468 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 468,
    r469 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 469,
    r470 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 470,
    r72 : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 72
  have r476' : (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B W).regs 476 =
      some (.bits 64 (BitVec.ofNat 64 (i + B))) := by
    rw [r476]
  exact ⟨hR, hA.next hO.1 hxy hgy hby (by rw [round_ctx.1]; exact hP) (round_ctx.2.trans hfn)
    r476' r478 ⟨_, r474⟩ r24 r67 r462 r466 q462 q466 r468 r469 r470 r72, hO⟩

/-- **The round with the guard true, with its store.** Layer norm (the corpus file) at block size
128, for every row length `n < 2 ^ 32`, thread `tid < 1024`, index `i` with `i + tid < n` (the guard
:708 true), blocks with `x`, `g` and `b` not `y`, tensors, `mu`, `rs` and valuation `W` with
`AtHead` at `i`: the round on `lnT`'s path (`%469`, `%483`, `%484`, `%495`, `%496`, `%529`, `%532`)
has its premises (`round_true`), `AtHead` holds after it at `i + 128`, its memory's blocks are `W`'s
with the bytes of `lnVal X[i + tid] G[i + tid] Bt[i + tid] mu rs`, under the context's oracle
numbers, put at float `i + tid` of `y` (`LnOut` at `LnBytes`; `%503`, :718-721, stored at :722
through the `getelementptr` of :700), and its trace is `W`'s with the round's accesses at float
`i + tid` in front, newest first (`LnTrace`): in the order of the run, the loads of `x`, `g` and `b`
(:715-717, through the `getelementptr`s of :701-703) and then the store, the round's only effects
(IR :714-723; its other blocks have none). A run theorem's premise (IR :677-772); `mu`, `rs` are
given registers. -/
theorem AtHead.roundT {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : AtHead n tid i y g b x X G Bt mu rs W) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) (hg : i + tid < n) :
    RoundWith true lnT.h lnT.p lnT.dh lnT.H lnT.B W ∧
      AtHead n tid (i + 128) y g b x X G Bt mu rs
        (Valuation.roundWith true lnT.h lnT.H lnT.B W) ∧
      LnOut y (LnBytes X G Bt mu rs) [i + tid] W.mem
        (Valuation.roundWith true lnT.h lnT.H lnT.B W).mem ∧
      LnTrace W.ctx.who y g b x [i + tid] W.mem
        (Valuation.roundWith true lnT.h lnT.H lnT.B W).mem := by
  have h := LnHead.roundT (hA := hA) ht hn (by omega) hxy hgy hby hg
  rw [lnTB_128] at h
  exact h

-- `AtHead.roundT` at 67bd004: `AtHead.roundT`'s first three conjuncts, the third at four-byte
-- lists (`LnOut.imp`, `LnBytes.length`).
example {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : AtHead n tid i y g b x X G Bt mu rs W) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) (hg : i + tid < n) :
    RoundWith true lnT.h lnT.p lnT.dh lnT.H lnT.B W ∧
      AtHead n tid (i + 128) y g b x X G Bt mu rs
        (Valuation.roundWith true lnT.h lnT.H lnT.B W) ∧
      LnOut y (fun _ bs => bs.length = 4) [i + tid] W.mem
        (Valuation.roundWith true lnT.h lnT.H lnT.B W).mem :=
  have h := hA.roundT ht hn hxy hgy hby hg
  ⟨h.1, h.2.1, h.2.2.1.imp LnBytes.length⟩

/-- **The round with the guard false, with no store, at every block size.** Layer norm's last loop
(the corpus files ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B` with
`B ≤ 2 ^ 32`, for the family's function `lnFam.fn B` (in a context of `ln.prog`), every row length
`n < 2 ^ 32`, thread `tid < 1024`, index `i` with `i < n ≤ i + tid` (the header goes on, the guard
:708 false), blocks with `x`, `g` and `b` not `y`, tensors, `mu`, `rs` and valuation `W` with
`LnHead` at `i`: the round on `lnFB B`'s path (`%469`, `%483`, `%484`, `%531`, `%532`) has its
premises (`round_falseB`), `LnHead` holds after it at `i + B`, and its memory has `W`'s blocks
(`LnOut` at `[]`) and `W`'s trace (`LnTrace` at `[]`): the path's blocks have no load, store,
barrier or atomic. A run theorem's premise (IR :677-772 of each file). `AtHead.roundF` is its
instance at 128. -/
theorem LnHead.roundF {B n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : LnHead B n tid i y g b x X G Bt mu rs W) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hBs : B ≤ 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) (hi : i < n)
    (hg : n ≤ i + tid) :
    RoundWith true (lnFB B).h (lnFB B).p (lnFB B).dh (lnFB B).H (lnFB B).B W ∧
      LnHead B n tid (i + B) y g b x X G Bt mu rs
        (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W) ∧
      LnOut y (LnBytes X G Bt mu rs) [] W.mem
        (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).mem ∧
      LnTrace W.ctx.who y g b x [] W.mem
        (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).mem := by
  have hA0 := hA
  obtain ⟨hP, hfn, h476, h478, ⟨v, h474⟩, h24, h67, h462, h466, hq462, hq466, h468, h469, h470,
    h72, hby', hbg, hbb, hbx, hfy, hfg, hfb, hfx, hX, hG, hB⟩ := hA0
  have hR := MojoProofTest.LnRound.round_falseB B n tid i y g b x W v hP hfn h476 h478 h474 h24
    h67 h468 h469 h470 h72 hby' hbg hbb hbx ht hn hBs hi hg
  obl_have e3 : (vals W (lnFB B).H.nodes)[3]?, e4 : (vals W (lnFB B).H.nodes)[4]?
  have e5 : (vals W (lnFB B).H.nodes)[5]? = some (.ok (.ofBool false)) :=
    vals_getElem?_eval rfl (eval_xor_true (SVal.eval_node_take (by decide) e4))
  have e6 : (vals W (lnFB B).H.nodes)[6]? = some (.ok (.ofBool (decide (n ≤ i)))) :=
    vals_getElem?_eval rfl (eval_or_false (SVal.eval_node_take (by decide) e5)
      (SVal.eval_node_take (by decide) e3))
  obl_have fm : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).mem,
    r476 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 476,
    r478 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 478,
    r474 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 474,
    r24 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 24,
    r67 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 67,
    r462 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 462,
    r466 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 466,
    q462 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).prods 462,
    q466 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).prods 466,
    r468 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 468,
    r469 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 469,
    r470 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 470,
    r72 : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 72
  have r476' : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).regs 476 =
      some (.bits 64 (BitVec.ofNat 64 (i + B))) := by
    rw [r476]
  have hO : LnOut y (LnBytes X G Bt mu rs) [] W.mem
        (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).mem ∧
      LnTrace W.ctx.who y g b x [] W.mem
        (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B W).mem :=
    ⟨LnOut.refl (by rw [fm]), LnTrace.refl (by rw [fm])⟩
  exact ⟨hR, hA.next hO.1 hxy hgy hby (by rw [round_ctx.1]; exact hP) (round_ctx.2.trans hfn)
    r476' r478 ⟨_, r474⟩ r24 r67 r462 r466 q462 q466 r468 r469 r470 r72, hO⟩

/-- **The round with the guard false, with no store.** Layer norm (the corpus file) at block
size 128, for every row length `n < 2 ^ 32`, thread `tid < 1024`, index `i` with
`i < n ≤ i + tid` (the header goes on, the guard :708 false), blocks with `x`, `g` and `b` not
`y`, tensors, `mu`, `rs` and valuation `W` with `AtHead` at `i`: the round on `lnF`'s path
(`%469`, `%483`, `%484`, `%531`, `%532`) has its premises (`round_false`), `AtHead` holds after
it at `i + 128`, and its memory has `W`'s blocks (`LnOut` at `[]`) and `W`'s trace (`LnTrace`
at `[]`): the path's blocks `%484` (:698-709), `%531` and `%532` (:767-772) have no load, store,
barrier or atomic. A run theorem's premise (IR :677-772). -/
theorem AtHead.roundF {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : AtHead n tid i y g b x X G Bt mu rs W) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) (hi : i < n)
    (hg : n ≤ i + tid) :
    RoundWith true lnF.h lnF.p lnF.dh lnF.H lnF.B W ∧
      AtHead n tid (i + 128) y g b x X G Bt mu rs
        (Valuation.roundWith true lnF.h lnF.H lnF.B W) ∧
      LnOut y (LnBytes X G Bt mu rs) [] W.mem (Valuation.roundWith true lnF.h lnF.H lnF.B W).mem ∧
      LnTrace W.ctx.who y g b x [] W.mem (Valuation.roundWith true lnF.h lnF.H lnF.B W).mem := by
  have h := LnHead.roundF (hA := hA) ht hn (by omega) hxy hgy hby hi hg
  rw [lnFB_128] at h
  exact h

-- `AtHead.roundF` at 67bd004: `AtHead.roundF`'s first three conjuncts, the third at four-byte
-- lists (`LnOut.imp`, `LnBytes.length`).
example {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : AtHead n tid i y g b x X G Bt mu rs W) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) (hi : i < n)
    (hg : n ≤ i + tid) :
    RoundWith true lnF.h lnF.p lnF.dh lnF.H lnF.B W ∧
      AtHead n tid (i + 128) y g b x X G Bt mu rs
        (Valuation.roundWith true lnF.h lnF.H lnF.B W) ∧
      LnOut y (fun _ bs => bs.length = 4) [] W.mem
        (Valuation.roundWith true lnF.h lnF.H lnF.B W).mem :=
  have h := hA.roundF ht hn hxy hgy hby hi hg
  ⟨h.1, h.2.1, h.2.2.1.imp LnBytes.length⟩

/-- **The path out of the loop, at every block size.** Layer norm's last loop (the corpus files
ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B` with
`B ≤ 2 ^ 32`, for the family's function `lnFam.fn B` (in a context of `ln.prog`), every row length
`n < 2 ^ 32`, index `i` with `n ≤ i < n + B` (the exit test `icmp sge` at :684 true), thread,
blocks, tensors, `mu`, `rs` and valuation `W` with `LnHead` at `i`: the path `%469`, `%482` has
its premises and goes to `%534` at its first statement (`EdgeWith`, :677-693, :774), and it keeps
the memory: the path has no load, store, barrier or atomic. A run theorem's premise.
`AtHead.exit` is its instance at 128. -/
theorem LnHead.exit {B n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : LnHead B n tid i y g b x X G Bt mu rs W)
    (hn : n < 2 ^ 32) (hBs : B ≤ 2 ^ 32) (hi : n ≤ i) (hi' : i < n + B) :
    EdgeWith true ln.fn_0.b_58.label 0 W (lnFB B).h (lnFB B).dh (lnFB B).H (lnFB B).X ∧
      (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).X W).mem = W.mem := by
  obtain ⟨hP, hfn, h476, h478, ⟨v, h474⟩, h24, h67, h462, h466, hq462, hq466, h468, h469, h470,
    h72, hby', hbg, hbb, hbx, hfy, hfg, hfb, hfx, hX, hG, hB⟩ := hA
  obl_have e3 : (vals W (lnFB B).H.nodes)[3]?, e4 : (vals W (lnFB B).H.nodes)[4]?
  have e5 : (vals W (lnFB B).H.nodes)[5]? = some (.ok (.ofBool false)) :=
    vals_getElem?_eval rfl (eval_xor_true (SVal.eval_node_take (by decide) e4))
  have e6 : (vals W (lnFB B).H.nodes)[6]? = some (.ok (.ofBool (decide (n ≤ i)))) :=
    vals_getElem?_eval rfl (eval_or_false (SVal.eval_node_take (by decide) e5)
      (SVal.eval_node_take (by decide) e3))
  obl_have xm : (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).X W).mem
  exact ⟨by mojo_obl, xm⟩

/-- **The path out of the loop.** Layer norm (the corpus file) at block size 128, for every row
length `n < 2 ^ 32`, index `i` with `n ≤ i < n + 128` (the exit test `icmp sge` at :684 true),
thread, blocks, tensors, `mu`, `rs` and valuation `W` with `AtHead` at `i`: the path `%469`,
`%482` has its premises and goes to `%534` at its first statement (`EdgeWith`, :677-693, :774),
and it keeps the memory, its blocks and its trace (so `LnOut` at `[]` and `LnTrace` at `[]`): the
path has no load, store, barrier or atomic. A run theorem's premise. -/
theorem AtHead.exit {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : AtHead n tid i y g b x X G Bt mu rs W)
    (hn : n < 2 ^ 32) (hi : n ≤ i) (hi' : i < n + 128) :
    EdgeWith true ln.fn_0.b_58.label 0 W lnF.h lnF.dh lnF.H lnF.X ∧
      (Valuation.roundWith true lnF.h lnF.H lnF.X W).mem = W.mem := by
  have h := LnHead.exit (hA := hA) hn (by omega) hi hi'
  rw [lnFB_128] at h
  exact h

/-- The path checker with `phi`s and `fmul contract` (`coversPathAt`, no `alloca`) accepts
`lnT`'s round from the header's statement 3. By `decide +kernel`. -/
theorem cov_T : coversPathAt false true ln.prog ln.fn_0 3 ((lnT.h, lnT.dh, lnT.H) :: lnT.B) =
    true := by
  decide +kernel

/-- The path checker with `phi`s and `fmul contract` (`coversPathAt`, no `alloca`) accepts
`lnF`'s round from the header's statement 3. By `decide +kernel`. -/
theorem cov_F : coversPathAt false true ln.prog ln.fn_0 3 ((lnF.h, lnF.dh, lnF.H) :: lnF.B) =
    true := by
  decide +kernel

/-- The path checker with `phi`s and `fmul contract` (`coversPathAt`, no `alloca`) accepts the
path out of the loop, `%469` from statement 3 and `%482`. By `decide +kernel`. -/
theorem cov_X : coversPathAt false true ln.prog ln.fn_0 3 ((lnF.h, lnF.dh, lnF.H) :: lnF.X) =
    true := by
  decide +kernel

/-- Layer norm's `%453` from its branch (statement 21, :675): `br label %469`, into the loop. -/
sym_summary pre := ln.prog ln.fn_0 ln.fn_0.b_42.label 21

/-- The path checker with `phi`s and `fmul contract` (`coversPathAt`, no `alloca`) accepts
`%453` from its branch. By `decide +kernel`. -/
theorem cov_E : coversPathAt false true ln.prog ln.fn_0 21
    [(ln.fn_0.b_42.label, pre.obls, pre)] = true := by
  decide +kernel

/-- **The covers of layer norm's last loop at block size `B`.** The path checker with `phi`s and
`fmul contract` (`coversPathAt`, no `alloca`) accepts, in `ln.prog` with the family's function
`lnFam.fn B`, the two rounds `lnTB B` and `lnFB B` and the path out of the loop from the header
`%469`'s statement 3, and the edge into the loop from `%453`'s branch (statement 21): the covers
the run theorems at every block size take as a premise (the checker computes them at a numeral:
`covers_128` and MojoProofTest/LnFamily.lean). A test definition. -/
structure LnCovers (B : Nat) : Prop where
  /-- The covers from the four checks. -/
  mk ::
  /-- The round with the guard true. -/
  T : coversPathAt false true ln.prog (lnFam.fn B) 3
    (((lnTB B).h, (lnTB B).dh, (lnTB B).H) :: (lnTB B).B) = true
  /-- The round with the guard false. -/
  F : coversPathAt false true ln.prog (lnFam.fn B) 3
    (((lnFB B).h, (lnFB B).dh, (lnFB B).H) :: (lnFB B).B) = true
  /-- The path out of the loop. -/
  X : coversPathAt false true ln.prog (lnFam.fn B) 3
    (((lnFB B).h, (lnFB B).dh, (lnFB B).H) :: (lnFB B).X) = true
  /-- The edge into the loop. -/
  E : coversPathAt false true ln.prog (lnFam.fn B) 21
    [(ln.fn_0.b_42.label, pre.obls, pre)] = true

/-- The covers at block size 128 are `cov_T`, `cov_F`, `cov_X` and `cov_E` (`lnTB_128`,
`lnFB_128`, `lnFam.prog_corpus`). -/
theorem covers_128 : LnCovers 128 :=
  ⟨by rw [lnTB_128, lnFam.prog_corpus.2]; exact cov_T,
    by rw [lnFB_128, lnFam.prog_corpus.2]; exact cov_F,
    by rw [lnFB_128, lnFam.prog_corpus.2]; exact cov_X,
    by rw [lnFam.prog_corpus.2]; exact cov_E⟩

/-- **The thread leaves the loop, at every block size.** Layer norm's last loop (the corpus files
ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B` with
`B ≤ 2 ^ 32` and the covers `LnCovers B`, for the family's function `lnFam.fn B`, every context
`c` of `ln.prog` (so every launch and thread), row length `n < 2 ^ 32`, index `i` with
`n ≤ i < n + B`, thread state `t` whose innermost frame `f` is at the header `%469`'s statement 3,
and memory `m`, with `LnHead` at `i` at `f`'s entry valuation: the thread's steps reach `%534`'s
first statement in a frame above the same frames, with `f`'s caller's register, and the memory's
blocks and trace are `m`'s (`LnOut` at `[]`, `LnTrace` at `[]`). A run theorem (IR :677-693);
`run_exit` is its instance at 128. -/
theorem run_exitB {B n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (hcv : LnCovers B) (hn : n < 2 ^ 32) (hBs : B ≤ 2 ^ 32)
    (hi : n ≤ i) (hi' : i < n + B) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hfr : t.frames = f :: rest) (hf : f.fn = lnFam.fn B) (hl : f.label = ln.fn_0.b_43.label)
    (hp : f.pc = 3) (hA : LnHead B n tid i y g b x X G Bt mu rs (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = lnFam.fn B ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) [] m m' ∧ LnTrace c.who y g b x [] m m' := by
  obtain ⟨hX, hm⟩ := hA.exit hn hBs hi hi'
  obtain ⟨t', m', f', hS, ht', hf', hl', hp', -, -, hd', hV⟩ :=
    Block.sound_edge (alloca := false) hc hcv.X hfr hf hl hp hX.1 hX.2.1
  have hp₂ : ((Valuation.entry c t.k m f).lastWith true (lnFB B).h (lnFB B).H
      (lnFB B).X).2.2.exit.pc f.fn ln.fn_0.b_58.label = 0 := hX.2.2
  rw [hf] at hp₂
  have e : m' =
      (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).X (Valuation.entry c t.k m f)).mem :=
    congrArg Valuation.mem hV
  have e' : m' = m := by rw [e, hm]; rfl
  subst e'
  exact ⟨t', m', f', hS, ht', hf', hl', hp'.trans hp₂, hd', LnOut.refl rfl, LnTrace.refl rfl⟩

/-- **The thread leaves the loop.** Layer norm (the corpus file) at block size 128, for every
context `c` of `ln.prog` (so every launch and thread), row length `n < 2 ^ 32`, index `i` with
`n ≤ i < n + 128`, thread state `t` whose innermost frame `f` is at the header `%469`'s statement
3 (after the `phi`s), and memory `m`, with `AtHead` at `i` at `f`'s entry valuation: the thread's
steps reach `%534`'s first statement (:774) in a frame above the same frames, with `f`'s caller's
register, and the memory's blocks and trace are `m`'s (`LnOut` at `[]`, `LnTrace` at `[]`). A
run theorem (IR :677-693). -/
theorem run_exit {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (hn : n < 2 ^ 32) (hi : n ≤ i) (hi' : i < n + 128)
    {t : Thread} {m : Mem} {f : Frame} {rest : List Frame} (hfr : t.frames = f :: rest)
    (hf : f.fn = ln.fn_0) (hl : f.label = ln.fn_0.b_43.label) (hp : f.pc = 3)
    (hA : AtHead n tid i y g b x X G Bt mu rs (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) [] m m' ∧ LnTrace c.who y g b x [] m m' := by
  obtain ⟨t', m', f', hS, h1, h2, h3⟩ := run_exitB hc covers_128 hn (by omega) hi hi' hfr
    (hf.trans lnFam.prog_corpus.2.symm) hl hp hA
  exact ⟨t', m', f', hS, h1, h2.trans lnFam.prog_corpus.2, h3⟩

-- `run_exit` at 67bd004: `run_exit` without its `LnTrace` conjunct, its `LnOut` at four-byte
-- lists (`LnOut.imp`, `LnBytes.length`).
example {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (hn : n < 2 ^ 32) (hi : n ≤ i) (hi' : i < n + 128)
    {t : Thread} {m : Mem} {f : Frame} {rest : List Frame} (hfr : t.frames = f :: rest)
    (hf : f.fn = ln.fn_0) (hl : f.label = ln.fn_0.b_43.label) (hp : f.pc = 3)
    (hA : AtHead n tid i y g b x X G Bt mu rs (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (fun _ bs => bs.length = 4) [] m m' :=
  have ⟨t', m', f', hS, h1, h2, h3, h4, h5, hO, _⟩ := run_exit hc hn hi hi' hfr hf hl hp hA
  ⟨t', m', f', hS, h1, h2, h3, h4, h5, hO.imp LnBytes.length⟩

/-- **Layer norm's last loop runs from index `i` with fuel `K`, at every block size.** Layer norm's
last loop (the corpus files ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size
`B` with `B ≤ 2 ^ 32` and the covers `LnCovers B`, for the family's function `lnFam.fn B`, every
context `c` of `ln.prog` (so every launch and thread), thread index `tid < 1024`, row length
`n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`, `mu`, `rs`, fuel `K` and
index `i` with `n ≤ i + B K` and `i < n + B`, thread state `t` whose innermost frame `f` is at the
header `%469`'s statement 3, and memory `m`, with `LnHead` at `i` at `f`'s entry valuation: the
thread's steps reach `%534`'s first statement in a frame above the same frames, with `f`'s caller's
register; the memory's trace is `m`'s with thread `c.who`'s accesses of the rounds at the floats of
`lnLoop B n tid K i` in front, newest first (`LnTrace`), and its blocks are `m`'s with the bytes of
`lnVal X[k] G[k] Bt[k] mu rs` put at each of those floats `k` of `y`, in turn, and no other block
changed (`LnOut` at `LnBytes`). By induction on `K`: each round by `Block.sound_edge` with
`LnHead.roundT` or `LnHead.roundF`, the last by `run_exitB`. A run theorem (IR :677-772); `mu` and
`rs` are given registers. `run_from` is its instance at 128. -/
theorem run_fromB {B n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (hcv : LnCovers B) (ht : tid < 1024) (hn : n < 2 ^ 32)
    (hBs : B ≤ 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) :
    ∀ (K i : Nat), n ≤ i + B * K → i < n + B → ∀ {t : Thread} {m : Mem} {f : Frame}
      {rest : List Frame}, t.frames = f :: rest → f.fn = lnFam.fn B →
      f.label = ln.fn_0.b_43.label → f.pc = 3 →
      LnHead B n tid i y g b x X G Bt mu rs (Valuation.entry c t.k m f) →
      ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = lnFam.fn B ∧
        f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
        LnOut y (LnBytes X G Bt mu rs) (lnLoop B n tid K i) m m' ∧
        LnTrace c.who y g b x (lnLoop B n tid K i) m m' := by
  intro K
  induction K with
  | zero =>
    intro i hK hi t m f rest hfr hf hl hp hA
    exact run_exitB hc hcv hn hBs (by omega) hi hfr hf hl hp hA
  | succ K ih =>
    intro i hK hi t m f rest hfr hf hl hp hA
    by_cases h0 : n ≤ i
    · have e : lnLoop B n tid (K + 1) i = [] := by simp [lnLoop, h0]
      rw [e]
      exact run_exitB hc hcv hn hBs h0 hi hfr hf hl hp hA
    by_cases hg : i + tid < n
    · obtain ⟨hR, hA', hO, hT⟩ := hA.roundT ht hn hBs hxy hgy hby hg
      obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hf₁, hl₁, hp₁, -, -, hd₁, hV₁⟩ :=
        Block.sound_edge (alloca := false) hc hcv.T hfr hf hl hp hR.1 hR.2.1
      have hp₂ : ((Valuation.entry c t.k m f).lastWith true (lnTB B).h (lnTB B).H
          (lnTB B).B).2.2.exit.pc f.fn (lnTB B).h = 3 := hR.2.2
      rw [hf] at hp₂
      have e₁ : m₁ =
          (Valuation.roundWith true (lnTB B).h (lnTB B).H (lnTB B).B
            (Valuation.entry c t.k m f)).mem :=
        congrArg Valuation.mem hV₁
      rw [← hV₁] at hA'
      obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hf₂, hl₂, hp₃, hd₂, hO₂, hT₂⟩ :=
        ih (i + B) (by rw [Nat.mul_add_one] at hK; omega) (by omega) ht₁ hf₁ hl₁ (hp₁.trans hp₂)
          hA'
      have e : lnLoop B n tid (K + 1) i = [i + tid] ++ lnLoop B n tid K (i + B) := by
        simp [lnLoop, h0, hg]
      rw [e]
      have hO₁ : LnOut y (LnBytes X G Bt mu rs) [i + tid] m m₁ := by rw [e₁]; exact hO
      have hT₁ : LnTrace c.who y g b x [i + tid] m m₁ := by rw [e₁]; exact hT
      exact ⟨t₂, m₂, f₂, hS₁.trans hS₂, ht₂, hf₂, hl₂, hp₃, hd₂.trans hd₁, hO₁.trans hO₂,
        hT₁.trans hT₂⟩
    · obtain ⟨hR, hA', hO, hT⟩ := hA.roundF ht hn hBs hxy hgy hby (by omega) (by omega)
      obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hf₁, hl₁, hp₁, -, -, hd₁, hV₁⟩ :=
        Block.sound_edge (alloca := false) hc hcv.F hfr hf hl hp hR.1 hR.2.1
      have hp₂ : ((Valuation.entry c t.k m f).lastWith true (lnFB B).h (lnFB B).H
          (lnFB B).B).2.2.exit.pc f.fn (lnFB B).h = 3 := hR.2.2
      rw [hf] at hp₂
      have e₁ : m₁ =
          (Valuation.roundWith true (lnFB B).h (lnFB B).H (lnFB B).B
            (Valuation.entry c t.k m f)).mem :=
        congrArg Valuation.mem hV₁
      rw [← hV₁] at hA'
      obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hf₂, hl₂, hp₃, hd₂, hO₂, hT₂⟩ :=
        ih (i + B) (by rw [Nat.mul_add_one] at hK; omega) (by omega) ht₁ hf₁ hl₁ (hp₁.trans hp₂)
          hA'
      have e : lnLoop B n tid (K + 1) i = [] ++ lnLoop B n tid K (i + B) := by
        simp [lnLoop, h0, hg]
      rw [e]
      have hO₁ : LnOut y (LnBytes X G Bt mu rs) [] m m₁ := by rw [e₁]; exact hO
      have hT₁ : LnTrace c.who y g b x [] m m₁ := by rw [e₁]; exact hT
      exact ⟨t₂, m₂, f₂, hS₁.trans hS₂, ht₂, hf₂, hl₂, hp₃, hd₂.trans hd₁, hO₁.trans hO₂,
        hT₁.trans hT₂⟩

/-- **Layer norm's last loop runs from index `i` with fuel `K`.** Layer norm (the corpus file) at
block size 128, for every context `c` of `ln.prog` (so every launch and thread), thread index
`tid < 1024`, row length `n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`,
`mu`, `rs`, fuel `K` and index `i` with `n ≤ i + 128 K` and `i < n + 128`, thread state `t` whose
innermost frame `f` is at the header `%469`'s statement 3 (after the `phi`s, :678-680), and memory
`m`, with `AtHead` at `i` at `f`'s entry valuation: the thread's steps reach `%534`'s first
statement (:774) in a frame above the same frames, with `f`'s caller's register; the memory's
trace (newest first) is `m`'s with thread `c.who`'s accesses of the rounds at the floats of
`lnLoop 128 n tid K i` in front, newest first (`LnTrace`: the reverse of those accesses in the
order of the run; the order and number of the stores, and that there is no other event), and its
blocks are `m`'s with the bytes of `lnVal X[k] G[k] Bt[k] mu rs` put at
each of those floats `k` of `y`, in turn, and no other block changed (`LnOut` at `LnBytes`: the
final bytes, `LnOut.read`). By induction on `K`: each round by `Block.sound_edge` with
`AtHead.roundT` or `AtHead.roundF`, the last by `run_exit`. A run theorem (IR :677-772); `mu` and
`rs` are given registers. -/
theorem run_from {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32) (hxy : x ≠ y)
    (hgy : g ≠ y) (hby : b ≠ y) :
    ∀ (K i : Nat), n ≤ i + 128 * K → i < n + 128 → ∀ {t : Thread} {m : Mem} {f : Frame}
      {rest : List Frame}, t.frames = f :: rest → f.fn = ln.fn_0 →
      f.label = ln.fn_0.b_43.label → f.pc = 3 →
      AtHead n tid i y g b x X G Bt mu rs (Valuation.entry c t.k m f) →
      ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
        f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
        LnOut y (LnBytes X G Bt mu rs) (lnLoop 128 n tid K i) m m' ∧
        LnTrace c.who y g b x (lnLoop 128 n tid K i) m m' := by
  intro K i hK hi t m f rest hfr hf hl hp hA
  obtain ⟨t', m', f', hS, h1, h2, h3⟩ := run_fromB hc covers_128 ht hn (by omega) hxy hgy hby K i
    hK hi hfr (hf.trans lnFam.prog_corpus.2.symm) hl hp hA
  exact ⟨t', m', f', hS, h1, h2.trans lnFam.prog_corpus.2, h3⟩

-- `run_from` at 67bd004: `run_from` without its `LnTrace` conjunct, its `LnOut` at four-byte
-- lists (`LnOut.imp`, `LnBytes.length`).
example {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32) (hxy : x ≠ y)
    (hgy : g ≠ y) (hby : b ≠ y) :
    ∀ (K i : Nat), n ≤ i + 128 * K → i < n + 128 → ∀ {t : Thread} {m : Mem} {f : Frame}
      {rest : List Frame}, t.frames = f :: rest → f.fn = ln.fn_0 →
      f.label = ln.fn_0.b_43.label → f.pc = 3 →
      AtHead n tid i y g b x X G Bt mu rs (Valuation.entry c t.k m f) →
      ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
        f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
        LnOut y (fun _ bs => bs.length = 4) (lnLoop 128 n tid K i) m m' := by
  intro K i hK hi t m f rest hfr hf hl hp hA
  obtain ⟨t', m', f', hS, h1, h2, h3, h4, h5, hO, -⟩ :=
    run_from hc ht hn hxy hgy hby K i hK hi hfr hf hl hp hA
  exact ⟨t', m', f', hS, h1, h2, h3, h4, h5, hO.imp LnBytes.length⟩

/-- **Layer norm's last loop: its accesses are `lnStores`' rounds, at every block size.** Layer
norm's last loop (the corpus files ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block
size `B` with `0 < B`, `B ≤ 2 ^ 32` and the covers `LnCovers B`, for the family's function
`lnFam.fn B`, every context `c` of `ln.prog` (so every launch and thread), thread index
`tid < 1024`, row length `n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`,
`mu`, `rs`, thread state `t` whose innermost frame `f` is at the header `%469`'s statement 3 with
the loop index `%471` zero, and memory `m`, with `LnHead` at index 0 at `f`'s entry valuation: the
thread's steps reach `%534`'s first statement in a frame above the same frames, with `f`'s caller's
register; the memory's trace is `m`'s with, in front, thread `c.who`'s accesses of the rounds at the
floats of `lnStores B n tid` (the floats `B j + tid < n`, `lnStores_eq`), newest first, and no other
event (`LnTrace`), and its blocks are `m`'s with the bytes of `lnVal X[k] G[k] Bt[k] mu rs` put at
each of those floats `k` of `y`, in turn, and no other block changed (`LnOut` at `LnBytes`).
`run_fromB` at `K = n`, `i = 0` (`0 < B`: `n ≤ B n`). A run theorem (IR :677-774); the mean and
inverse deviation are given registers. `run` is its instance at 128. -/
theorem runB {B n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (hcv : LnCovers B) (hB0 : 0 < B) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hBs : B ≤ 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) {t : Thread}
    {m : Mem} {f : Frame} {rest : List Frame} (hfr : t.frames = f :: rest)
    (hf : f.fn = lnFam.fn B) (hl : f.label = ln.fn_0.b_43.label) (hp : f.pc = 3)
    (hA : LnHead B n tid 0 y g b x X G Bt mu rs (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = lnFam.fn B ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) (lnStores B n tid) m m' ∧
      LnTrace c.who y g b x (lnStores B n tid) m m' :=
  run_fromB hc hcv ht hn hBs hxy hgy hby n 0
    (by rw [Nat.zero_add]; exact Nat.le_mul_of_pos_left n hB0) (by omega) hfr hf hl hp hA

/-- **Layer norm's last loop: its accesses are `lnStores`' rounds.** Layer norm (the corpus
file) at block size 128, for every context `c` of `ln.prog` (so every launch and thread), thread
index `tid < 1024`, row length `n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`,
`Bt`, `mu`, `rs`, thread state `t` whose innermost frame `f` is at the header `%469`'s statement 3
after the `phi`s with the loop index `%471` zero (:679), and memory `m`, with `AtHead` at index 0
at `f`'s entry valuation: the thread's steps reach `%534`'s first statement (:774, past the exit
test and branch :684-690 and `%482`) in a frame above the same frames, with `f`'s caller's
register; the memory's trace (newest first) is `m`'s with, in front, thread `c.who`'s accesses
of the rounds at the floats of `lnStores 128 n tid` (the floats `128 j + tid < n`,
`lnStores_eq`), newest first: the reverse of the run's order, in which each round reads `x`, `g`
and `b` there and then writes `y` there; and no other event (`LnTrace`, the order and number of
the stores), and its blocks are `m`'s with the bytes of
`lnVal X[k] G[k] Bt[k] mu rs` (some oracle numbers) put at each of those floats `k` of `y`, in turn,
and no other block changed (`LnOut` at `LnBytes`, the final bytes). `run_from` at `K = n`,
`i = 0`. A run theorem (IR :677-774); the mean and inverse deviation are given registers. -/
theorem run {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32) (hxy : x ≠ y)
    (hgy : g ≠ y) (hby : b ≠ y) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hfr : t.frames = f :: rest) (hf : f.fn = ln.fn_0) (hl : f.label = ln.fn_0.b_43.label)
    (hp : f.pc = 3) (hA : AtHead n tid 0 y g b x X G Bt mu rs (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) (lnStores 128 n tid) m m' ∧
      LnTrace c.who y g b x (lnStores 128 n tid) m m' := by
  obtain ⟨t', m', f', hS, h1, h2, h3⟩ := runB hc covers_128 (by omega) ht hn (by omega) hxy hgy
    hby hfr (hf.trans lnFam.prog_corpus.2.symm) hl hp hA
  exact ⟨t', m', f', hS, h1, h2.trans lnFam.prog_corpus.2, h3⟩

-- `run` at 67bd004: `run` without its `LnTrace` conjunct, its `LnOut` at four-byte lists
-- (`LnOut.imp`, `LnBytes.length`).
example {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32) (hxy : x ≠ y)
    (hgy : g ≠ y) (hby : b ≠ y) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hfr : t.frames = f :: rest) (hf : f.fn = ln.fn_0) (hl : f.label = ln.fn_0.b_43.label)
    (hp : f.pc = 3) (hA : AtHead n tid 0 y g b x X G Bt mu rs (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (fun _ bs => bs.length = 4) (lnStores 128 n tid) m m' :=
  have ⟨t', m', f', hS, h1, h2, h3, h4, h5, hO, _⟩ := run hc ht hn hxy hgy hby hfr hf hl hp hA
  ⟨t', m', f', hS, h1, h2, h3, h4, h5, hO.imp LnBytes.length⟩

/-- **The edge into the loop, at every block size.** Layer norm's last loop (the corpus files
ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B`, for the family's
function `lnFam.fn B` (in a context of `ln.prog`), every row length, thread index, blocks,
tensors, `mu`, `rs` and valuation `W` at `%453`'s branch (:675) with `LnHead`'s registers and
memory but the loop's three `phi`s: the edge to the header `%469` has its premises and goes to its
statement 3 (`EdgeWith`), `LnHead` holds at index 0 after it (the `phi`s at :678-680 set `%470`,
`%471` and `%472` to 0), and it keeps the memory. A run theorem's premise (IR :675-680);
`entry_edge` is its instance at 128. -/
theorem entry_edgeB {B n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hP : W.ctx.prog = ln.prog) (hfn : W.fn = lnFam.fn B)
    (h24 : W.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (h67 : W.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : W.regs 462 = some (.ofFloat .float mu))
    (h466 : W.regs 466 = some (.ofFloat .float rs))
    (hq462 : W.prods 462 = none) (hq466 : W.prods 466 = none)
    (h468 : W.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : W.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : W.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : W.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby : W.mem.Buffer y (n * 4) 4 true) (hbg : W.mem.Buffer g (n * 4) 4 false)
    (hbb : W.mem.Buffer b (n * 4) 4 false) (hbx : W.mem.Buffer x (n * 4) 4 false)
    (hfy : W.mem.Fits ln.prog.layout y (n * 4)) (hfg : W.mem.Fits ln.prog.layout g (n * 4))
    (hfb : W.mem.Fits ln.prog.layout b (n * 4)) (hfx : W.mem.Fits ln.prog.layout x (n * 4))
    (hX : W.mem.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : W.mem.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : W.mem.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt) :
    EdgeWith true lnT.h 3 W ln.fn_0.b_42.label pre.obls pre [] ∧
      LnHead B n tid 0 y g b x X G Bt mu rs
        (Valuation.roundWith true ln.fn_0.b_42.label pre [] W) ∧
      (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).mem = W.mem := by
  obl_have em : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).mem,
    r476 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 476,
    r478 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 478,
    r474 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 474,
    r24 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 24,
    r67 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 67,
    r462 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 462,
    r466 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 466,
    q462 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).prods 462,
    q466 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).prods 466,
    r468 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 468,
    r469 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 469,
    r470 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 470,
    r72 : (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).regs 72
  refine ⟨by mojo_obl, ⟨by rw [round_ctx.1]; exact hP, round_ctx.2.trans hfn, r476, r478,
    ⟨_, r474⟩, r24, r67, r462, r466, q462, q466, r468, r469, r470, r72, ?_, ?_, ?_, ?_, ?_, ?_,
    ?_, ?_, ?_, ?_, ?_⟩, em⟩ <;> rw [em] <;> assumption

/-- **The edge into the loop.** Layer norm (the corpus file) at block size 128, for every row
length, thread index, blocks, tensors, `mu`, `rs` and valuation `W` of `ln.fn_0` at `%453`'s
branch (:675) with `AtHead`'s registers and memory but the loop's three `phi`s: the edge to the
header `%469` has its premises and goes to its statement 3 (`EdgeWith`), `AtHead` holds at
index 0 after it (the `phi`s at :678-680 set `%470`, `%471` and `%472` to 0), and it keeps the
memory. A run theorem's premise (IR :675-680). -/
theorem entry_edge {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hP : W.ctx.prog = ln.prog) (hfn : W.fn = ln.fn_0)
    (h24 : W.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (h67 : W.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : W.regs 462 = some (.ofFloat .float mu))
    (h466 : W.regs 466 = some (.ofFloat .float rs))
    (hq462 : W.prods 462 = none) (hq466 : W.prods 466 = none)
    (h468 : W.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : W.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : W.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : W.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby : W.mem.Buffer y (n * 4) 4 true) (hbg : W.mem.Buffer g (n * 4) 4 false)
    (hbb : W.mem.Buffer b (n * 4) 4 false) (hbx : W.mem.Buffer x (n * 4) 4 false)
    (hfy : W.mem.Fits ln.prog.layout y (n * 4)) (hfg : W.mem.Fits ln.prog.layout g (n * 4))
    (hfb : W.mem.Fits ln.prog.layout b (n * 4)) (hfx : W.mem.Fits ln.prog.layout x (n * 4))
    (hX : W.mem.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : W.mem.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : W.mem.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt) :
    EdgeWith true lnT.h 3 W ln.fn_0.b_42.label pre.obls pre [] ∧
      AtHead n tid 0 y g b x X G Bt mu rs
        (Valuation.roundWith true ln.fn_0.b_42.label pre [] W) ∧
      (Valuation.roundWith true ln.fn_0.b_42.label pre [] W).mem = W.mem := by
  have h := entry_edgeB (B := 128) hP (hfn.trans lnFam.prog_corpus.2.symm) h24 h67 h462 h466 hq462
    hq466 h468 h469 h470 h72 hby hbg hbb hbx hfy hfg hfb hfx hX hG hB
  exact h

/-- **Layer norm's last loop from its entry, at every block size.** Layer norm's last loop (the
corpus files ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}) at every block size `B` with
`0 < B`, `B ≤ 2 ^ 32` and the covers `LnCovers B`, for the family's function `lnFam.fn B`, every
context `c` of `ln.prog` (so every launch and thread), thread index `tid < 1024`, row length
`n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`, `mu`, `rs`, thread state
`t` whose innermost frame `f` is at `%453`'s branch into the loop (:675) and memory `m`, with
`entry_edgeB`'s registers and memory at `f`'s entry valuation (the thread index `tid`, the row
length `%65` the word of `n`, the mean `%460` and inverse deviation `%464`, the pointers `%466`
(`y`), `%467` (`g`), `%468` (`b`) and `%70` (`x`) to buffers of `4 n` bytes that fit, `x`, `g` and
`b` holding `X`, `G` and `Bt`): the thread's steps reach `%534`'s first statement (:774) in a frame
above the same frames, with `f`'s caller's register; the memory's trace is `m`'s with, in front,
thread `c.who`'s accesses of the rounds at the floats of `lnStores B n tid`, newest first, and no
other event (`LnTrace`), and its blocks are `m`'s with the bytes of `lnVal X[k] G[k] Bt[k] mu rs`
put at each of those floats `k` of `y`, in turn, and no other block changed (`LnOut` at `LnBytes`).
`entry_edgeB` by `Block.sound_edge`, then `runB`. A run theorem (IR :675-774); the mean and inverse
deviation are given registers. `run_entry` is its instance at 128. -/
theorem run_entryB {B n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (hcv : LnCovers B) (hB0 : 0 < B) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hBs : B ≤ 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) {t : Thread}
    {m : Mem} {f : Frame} {rest : List Frame} (hfr : t.frames = f :: rest)
    (hf : f.fn = lnFam.fn B) (hl : f.label = ln.fn_0.b_42.label) (hp : f.pc = 21)
    (h24 : f.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (h67 : f.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : f.regs 462 = some (.ofFloat .float mu))
    (h466 : f.regs 466 = some (.ofFloat .float rs))
    (hq462 : f.prods 462 = none) (hq466 : f.prods 466 = none)
    (h468 : f.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : f.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : f.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : f.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby' : m.Buffer y (n * 4) 4 true) (hbg : m.Buffer g (n * 4) 4 false)
    (hbb : m.Buffer b (n * 4) 4 false) (hbx : m.Buffer x (n * 4) 4 false)
    (hfy : m.Fits ln.prog.layout y (n * 4)) (hfg : m.Fits ln.prog.layout g (n * 4))
    (hfb : m.Fits ln.prog.layout b (n * 4)) (hfx : m.Fits ln.prog.layout x (n * 4))
    (hX : m.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : m.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : m.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = lnFam.fn B ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) (lnStores B n tid) m m' ∧
      LnTrace c.who y g b x (lnStores B n tid) m m' := by
  obtain ⟨hE, hA, hm⟩ := entry_edgeB (W := Valuation.entry c t.k m f) hc hf h24 h67 h462 h466 hq462
    hq466 h468 h469 h470 h72 hby' hbg hbb hbx hfy hfg hfb hfx hX hG hB
  obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hf₁, hl₁, hp₁, -, -, hd₁, hV₁⟩ :=
    Block.sound_edge (alloca := false) hc hcv.E hfr hf hl hp hE.1 hE.2.1
  have hp₂ : ((Valuation.entry c t.k m f).lastWith true ln.fn_0.b_42.label pre []).2.2.exit.pc
      f.fn lnT.h = 3 := hE.2.2
  rw [hf] at hp₂
  have e₁ : m₁ =
      (Valuation.roundWith true ln.fn_0.b_42.label pre [] (Valuation.entry c t.k m f)).mem :=
    congrArg Valuation.mem hV₁
  rw [← hV₁] at hA
  obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hf₂, hl₂, hp₃, hd₂, hO₂, hT₂⟩ :=
    runB hc hcv hB0 ht hn hBs hxy hgy hby ht₁ hf₁ hl₁ (hp₁.trans hp₂) hA
  have e₂ : m₁ = m := by rw [e₁, hm]; rfl
  subst e₂
  exact ⟨t₂, m₂, f₂, hS₁.trans hS₂, ht₂, hf₂, hl₂, hp₃, hd₂.trans hd₁, hO₂, hT₂⟩

/-- **Layer norm's last loop from its entry.** Layer norm (the corpus file) at block size 128, for
every context `c` of `ln.prog` (so every launch and thread), thread index `tid < 1024`, row length
`n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`, `mu`, `rs`, thread state
`t` whose innermost frame `f` is at `%453`'s branch into the loop (:675) and memory `m`, with
`entry_edge`'s registers and memory at `f`'s entry valuation (the thread index `tid`, the row
length `%65` the word of `n`, the mean `%460` and inverse deviation `%464`, the pointers `%466`
(`y`), `%467` (`g`), `%468` (`b`) and `%70` (`x`) to buffers of `4 n` bytes that fit, `x`, `g`
and `b` holding `X`, `G` and `Bt`): the thread's steps reach `%534`'s first statement (:774) in a
frame above the same frames, with `f`'s caller's register; the memory's trace (newest first) is
`m`'s with, in front, thread `c.who`'s accesses of the rounds at the floats of
`lnStores 128 n tid`, newest first (the reverse of their order in the run), and no other event
(`LnTrace`: the order and number of the stores, each 4 bytes at its float of `y`), and its
blocks are `m`'s with the bytes of `lnVal X[k] G[k] Bt[k] mu rs` (some
oracle numbers) put at each of those floats `k` of `y`, in turn, and no other block changed
(`LnOut` at `LnBytes`: the final bytes, `LnOut.read`; up to NaN payloads the fused or the unfused
result, `lnVal_cases`). `entry_edge` by `Block.sound_edge`, then `run`. A run theorem
(IR :675-774); the mean and inverse deviation are given registers. -/
theorem run_entry {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32) (hxy : x ≠ y)
    (hgy : g ≠ y) (hby : b ≠ y) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hfr : t.frames = f :: rest) (hf : f.fn = ln.fn_0) (hl : f.label = ln.fn_0.b_42.label)
    (hp : f.pc = 21)
    (h24 : f.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (h67 : f.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : f.regs 462 = some (.ofFloat .float mu))
    (h466 : f.regs 466 = some (.ofFloat .float rs))
    (hq462 : f.prods 462 = none) (hq466 : f.prods 466 = none)
    (h468 : f.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : f.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : f.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : f.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby' : m.Buffer y (n * 4) 4 true) (hbg : m.Buffer g (n * 4) 4 false)
    (hbb : m.Buffer b (n * 4) 4 false) (hbx : m.Buffer x (n * 4) 4 false)
    (hfy : m.Fits ln.prog.layout y (n * 4)) (hfg : m.Fits ln.prog.layout g (n * 4))
    (hfb : m.Fits ln.prog.layout b (n * 4)) (hfx : m.Fits ln.prog.layout x (n * 4))
    (hX : m.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : m.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : m.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (LnBytes X G Bt mu rs) (lnStores 128 n tid) m m' ∧
      LnTrace c.who y g b x (lnStores 128 n tid) m m' := by
  obtain ⟨t', m', f', hS, h1, h2, h3⟩ := run_entryB hc covers_128 (by omega) ht hn (by omega) hxy
    hgy hby hfr (hf.trans lnFam.prog_corpus.2.symm) hl hp h24 h67 h462 h466 hq462 hq466 h468 h469
    h470 h72 hby' hbg hbb hbx hfy hfg hfb hfx hX hG hB
  exact ⟨t', m', f', hS, h1, h2.trans lnFam.prog_corpus.2, h3⟩

-- `run_entry` at 67bd004: `run_entry` without its `LnTrace` conjunct, its `LnOut` at four-byte
-- lists (`LnOut.imp`, `LnBytes.length`).
example {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32) (hxy : x ≠ y)
    (hgy : g ≠ y) (hby : b ≠ y) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hfr : t.frames = f :: rest) (hf : f.fn = ln.fn_0) (hl : f.label = ln.fn_0.b_42.label)
    (hp : f.pc = 21)
    (h24 : f.regs 24 = some (.bits 64 (BitVec.ofNat 64 tid)))
    (h67 : f.regs 67 = some (.bits 64 (BitVec.ofNat 64 n)))
    (h462 : f.regs 462 = some (.ofFloat .float mu))
    (h466 : f.regs 466 = some (.ofFloat .float rs))
    (hq462 : f.prods 462 = none) (hq466 : f.prods 466 = none)
    (h468 : f.regs 468 = some (.ptr ⟨y, 0⟩)) (h469 : f.regs 469 = some (.ptr ⟨g, 0⟩))
    (h470 : f.regs 470 = some (.ptr ⟨b, 0⟩)) (h72 : f.regs 72 = some (.ptr ⟨x, 0⟩))
    (hby' : m.Buffer y (n * 4) 4 true) (hbg : m.Buffer g (n * 4) 4 false)
    (hbb : m.Buffer b (n * 4) 4 false) (hbx : m.Buffer x (n * 4) 4 false)
    (hfy : m.Fits ln.prog.layout y (n * 4)) (hfg : m.Fits ln.prog.layout g (n * 4))
    (hfb : m.Fits ln.prog.layout b (n * 4)) (hfx : m.Fits ln.prog.layout x (n * 4))
    (hX : m.Holds ln.prog.layout x (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) X)
    (hG : m.Holds ln.prog.layout g (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) G)
    (hB : m.Holds ln.prog.layout b (.fp .float) (Val.ofFloat .float)
      (rowMajor ln.prog.layout (.fp .float) 0) Bt) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (fun _ bs => bs.length = 4) (lnStores 128 n tid) m m' :=
  have ⟨t', m', f', hS, h1, h2, h3, h4, h5, hO, _⟩ := run_entry hc ht hn hxy hgy hby hfr hf hl hp
    h24 h67 h462 h466 hq462 hq466 h468 h469 h470 h72 hby' hbg hbb hbx hfy hfg hfb hfx hX hG hB
  ⟨t', m', f', hS, h1, h2, h3, h4, h5, hO.imp LnBytes.length⟩

end MojoProofTest.LnRun
