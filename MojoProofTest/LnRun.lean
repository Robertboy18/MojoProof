import MojoProofTest.LnRound
import MojoProofTest.GPUProof.ViewStride

/-!
# Layer norm's last loop, run for every row length: its stores are at `lnStores`' floats

Tests of one program, layer norm at block size 128 (MojoProofTest/SymSeg.lean's `ln`,
tests/corpus/layernorm/ln_rowwise_block_t0_r1_ax0_w1_bs128_847b1b53.nvptx.ll): the loop that
writes the normalized row, from its header `%469` after the `phi`s (:678-680, the loop index
`%471` at :679) to its exit test and branch (:684-690) and the path out `%482` into `%534`
(:692-693, :774), run by the symbolic layer (`Block.sound_edge`) for one thread, every row length
`n < 2 ^ 32`, every context (so every launch and thread) and every memory with the four row
buffers. MojoProofTest/LnRound.lean gives the premises of one round with the guard true and one
with it false; this file chains the rounds.

* `LnOut y ks m M`: `M` is `m` with 4 bytes put at byte `4 k` of block `y` for each `k` of `ks`
  in order, and no other block changed; `LnOut.refl`, `LnOut.trans`, and the buffers, fits and
  tensors of the other blocks it keeps (`LnOut.buffer`, `LnOut.fits`, `LnOut.holds`).
* `run_put`: a block's effects, loads and then one store of 4 bytes through `⟨y, 4 k⟩`, make
  `LnOut y [k]`.
* `AtHead`: the registers and memory at the header after its `phi`s at loop index `i`.
* `AtHead.roundT`, `AtHead.roundF`, `AtHead.exit`: the round with the guard (:708) true, with it
  false, and the path out: the round's premises, `AtHead` at `i + 128` and the memory's `LnOut`.
* `run_from` (the hand-proved run lemma, by induction on the fuel) and `run`: from the header at
  index 0, the thread reaches `%534` with its stores at `lnStores 128 n tid`'s floats
  (MojoProofTest/GPUProof/ViewStride.lean), in that order.
* `pre`, `entry_edge`, `run_entry`: the edge from `%453`'s branch (:675) into the header, whose
  `phi`s (:678-680) set `%470`, `%471` and `%472` to 0, and the run from that branch.

The value side (Welford's mean and deviation, the floats stored) is not here: the mean `%460` and
the inverse deviation `%464` are given registers (`AtHead`'s `mu` and `rs`) and the stored bytes
are given (`LnOut`'s lists of 4 bytes); the addresses and the guard are proved. Run theorems.
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

/-- **Memory `M` is `m` with floats stored at `ks` in block `y`**: every other block is `m`'s,
and block `y` is `m`'s with some 4-byte lists, one for each index of `ks`, put in order at byte
`4 k` (`putFloats`). For every block, list of indices and memories; the bytes stored are not
named. A test definition. -/
def LnOut (y : Nat) (ks : List Nat) (m M : Mem) : Prop :=
  (∀ q, q ≠ y → M.blocks q = m.blocks q) ∧
  ∃ bss : List (List MemByte), bss.length = ks.length ∧ (∀ bs ∈ bss, bs.length = 4) ∧
    M.blocks y = (m.blocks y).map (putFloats ks bss)

/-- No stores (`LnOut y []`) between two memories with the same blocks, for every block `y`. -/
theorem LnOut.refl {y : Nat} {m M : Mem} (h : M.blocks = m.blocks) : LnOut y [] m M := by
  refine ⟨fun q _ => by rw [h], [], rfl, by simp, ?_⟩
  rw [h]
  cases m.blocks y <;> rfl

/-- The stores of `ks` from `m` to `M` and then of `ks'` from `M` to `M'` are those of `ks ++ ks'`
from `m` to `M'`, for every block `y` and memories. -/
theorem LnOut.trans {y : Nat} {ks ks' : List Nat} {m M M' : Mem} (h : LnOut y ks m M)
    (h' : LnOut y ks' M M') : LnOut y (ks ++ ks') m M' := by
  obtain ⟨h1, bss, hl, hb, hy⟩ := h
  obtain ⟨h1', bss', hl', hb', hy'⟩ := h'
  refine ⟨fun q hq => (h1' q hq).trans (h1 q hq), bss ++ bss', by simp [hl, hl'], ?_, ?_⟩
  · intro bs hbs
    rcases List.mem_append.1 hbs with e | e
    exacts [hb bs e, hb' bs e]
  · rw [hy', hy, Option.map_map]
    congr 1
    funext B
    simp only [Function.comp, putFloats, List.zip_append hl.symm, List.foldl_append]

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

/-- Under `LnOut y ks m M`, each block `q` of `m` is in `M` with the same fields but its bytes,
for every block `y`, indices `ks` and memories. -/
theorem LnOut.keep {y : Nat} {ks : List Nat} {m M : Mem} (h : LnOut y ks m M) {q : Nat}
    {B : MojoProof.Sem.Block} (hq : m.blocks q = some B) :
    ∃ f, M.blocks q = some { B with bytes := f } := by
  by_cases e : q = y
  · subst e
    obtain ⟨-, bss, -, -, hy⟩ := h
    obtain ⟨f, hf⟩ := putFloats_eq ks bss B
    exact ⟨f, by rw [hy, hq, Option.map_some, hf]⟩
  · exact ⟨B.bytes, by rw [h.1 q e, hq]⟩

/-- Under `LnOut y ks m M`, a buffer of `m` (`Mem.Buffer`) is one of `M`, for every block `y`,
indices, memories, block `q`, size, alignment and writability. -/
theorem LnOut.buffer {y : Nat} {ks : List Nat} {m M : Mem} (h : LnOut y ks m M) {q s al : Nat}
    {w : Bool} (hb : m.Buffer q s al w) : M.Buffer q s al w := by
  obtain ⟨B, hB, hP⟩ := hb
  obtain ⟨f, hf⟩ := h.keep hB
  exact ⟨_, hf, hP⟩

/-- Under `LnOut y ks m M`, a block of `m` that fits its address space (`Mem.Fits`) fits it in
`M`, for every block `y`, indices, memories, layout, block `q` and size. -/
theorem LnOut.fits {y : Nat} {ks : List Nat} {m M : Mem} (h : LnOut y ks m M) {l : Layout}
    {q s : Nat} (hb : m.Fits l q s) : M.Fits l q s := by
  obtain ⟨B, hB, hP⟩ := hb
  obtain ⟨f, hf⟩ := h.keep hB
  exact ⟨_, hf, hP⟩

/-- Under `LnOut y ks m M`, a tensor that a block `q ≠ y` of `m` holds (`Mem.Holds`) is held by
`q` in `M`, for every indices, memories, layout, type, encoding, offsets and tensor. -/
theorem LnOut.holds {y : Nat} {ks : List Nat} {m M : Mem} (h : LnOut y ks m M) {q : Nat}
    (hq : q ≠ y) {s : TorchLean.Shape} {α : Type} {l : Layout} {t : Ty} {enc : α → Val}
    {off : TorchLean.Shape.Coord s → Nat} {X : TorchLean.Tensor α s}
    (hX : m.Holds l q t enc off X) : M.Holds l q t enc off X :=
  Mem.Holds.of_block (fun _ e => (h.1 q hq).trans e) hX

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

/-- **Loads and then one store of a float make `LnOut y [k]`.** For every valuation `V` of a
function `F` of a program `P`, node values, effects `es` that are all loads, and a statement
`(lbl, pc)` of `F` that is a `store` of a type of 4 stored bytes in `P`'s layout through a pointer
`p` that evaluates to `⟨y, 4 k⟩`: if the effects `es` and then that store run from `V`'s memory
to `M` (`SEff.run`), then `M` is `V`'s memory with 4 bytes put at byte `4 k` of `y`. The bytes
stored are not named. -/
theorem run_put {V : Valuation} {vs : List (Except Fault Val)} {P : Program} {F : Func}
    {es : List SEff} {lbl pc : Nat} {v p : SVal} {dst : Option Nat} {vol : Bool} {t : Ty}
    {pv : Value} {a : Nat} {pv' : Value} {al : Option Nat} {md : List (String × Nat)}
    {y k : Nat} {M : Mem} (hF : V.fn = F) (hP : V.ctx.prog = P)
    (hs : (F.blocks.find? (·.label == lbl)).bind (·.stmts[pc]?) =
      some ⟨dst, .store vol (.mk t pv) (.mk (.ptr a) pv') al, md⟩)
    (h4 : P.layout.stored t = 4)
    (hl : ∀ e ∈ es, ∃ a b q, e = .load a b q)
    (hp : p.eval V vs = .ok (.ptr ⟨y, ((4 * k : Nat) : Int)⟩))
    (h : SEff.run V vs (es ++ [.store lbl pc v p]) = .ok M) :
    LnOut y [k] V.mem M := by
  unfold SEff.run at h
  rw [List.foldlM_append] at h
  obtain ⟨m1, h1, h2⟩ := Except.bind_eq_ok.1 h
  have hb1 := fold_loads es hl V.mem m1 h1
  rw [List.foldlM_cons] at h2
  obtain ⟨m2, h3, h5⟩ := Except.bind_eq_ok.1 h2
  simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h5
  subst h5
  simp only [SEff.apply, Valuation.stmt_of_fn hF hs] at h3
  obtain ⟨x, -, h3⟩ := Except.bind_eq_ok.1 h3
  simp only [hp, bind, Except.bind, Val.addr?, pure, Except.pure] at h3
  obtain ⟨blk, bs, hc, -, he, rfl⟩ := Mem.store_inv h3
  have hy : m1.blocks y = some blk := (Mem.check_inv hc).1
  rw [hb1] at hy
  refine ⟨fun q hq => ?_, [bs], rfl, ?_, ?_⟩
  · simp only [Mem.log, Mem.set, hq, ↓reduceIte, hb1]
  · intro bs' hbs
    simp only [List.mem_singleton] at hbs
    subst hbs
    rw [Layout.encode_length _ _ _ _ he, hP, h4]
  · have e4 : (4 * (k : Int)).toNat = 4 * k := by omega
    simp [Mem.log, Mem.set, hy, putFloats, e4]

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

/-- **Layer norm's state at the loop's header.** Layer norm (the corpus file) at block size 128:
a valuation `W` of `ln.fn_0` at the header `%469` after its `phi`s (:678-680) with the loop index
`%471` the word of `i`, `%472` zero and `%470` some value, `tid` the word of `tid`, the row length
`%65` the word of `n`, the mean `%460` and the inverse deviation `%464` binary32 `mu` and `rs` with
no recorded product, the pointers `%466` (`y`, the output), `%467` (`g`), `%468` (`b`) and `%70`
(`x`) at offset 0 of buffers of `4 n` bytes (`y` writable, the others read-only) that fit, and
`x`, `g` and `b` holding the rows `X`, `G` and `Bt` (row-major binary32): the premises of
`round_true`, `round_false` (MojoProofTest/LnRound.lean) and `AtHead.exit`. A test definition. -/
structure AtHead (n tid i y g b x : Nat) (X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n])
    (mu rs : Model FloatTy.float.fmt) (W : Valuation) : Prop where
  /-- The state from its facts. -/
  mk ::
  /-- The program is layer norm's. -/
  prog : W.ctx.prog = ln.prog
  /-- The function is the kernel. -/
  fn : W.fn = ln.fn_0
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

/-- `AtHead` at index `i + 128` after a round. Layer norm (the corpus file) at block size 128,
for every row length, thread, index, blocks with `x`, `g` and `b` not `y`, tensors, `mu`, `rs`
and valuations `W` (with `AtHead` at `i`) and `W'` whose memory is `W`'s with stores into `y`
(`LnOut`): `AtHead` holds at `W'` and `i + 128` given `W'`'s program, function and registers. -/
theorem AtHead.next {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]}
    {mu rs : Model FloatTy.float.fmt} {W W' : Valuation} {ks : List Nat}
    (hA : AtHead n tid i y g b x X G Bt mu rs W) (hO : LnOut y ks W.mem W'.mem)
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
  ⟨prog, fn, r476, r478, r474, r24, r67, r462, r466, q462, q466, r468, r469, r470, r72,
    hO.buffer hA.by', hO.buffer hA.bg, hO.buffer hA.bb, hO.buffer hA.bx, hO.fits hA.fy,
    hO.fits hA.fg, hO.fits hA.fb, hO.fits hA.fx, hO.holds hxy hA.hX, hO.holds hgy hA.hG,
    hO.holds hby hA.hB⟩

/-- A round (`Valuation.roundWith`) keeps the context and the function, for every flag, header,
summary, path and valuation. -/
theorem round_ctx {c : Bool} {h : Nat} {S : Summary} {B : List (Nat × List Cond × Summary)}
    {W : Valuation} : (Valuation.roundWith c h S B W).ctx = W.ctx ∧
      (Valuation.roundWith c h S B W).fn = W.fn :=
  ⟨(Valuation.roundWith_k c h S B 1 W).1, (Valuation.roundWith_k c h S B 1 W).2.1⟩

/-- **The round with the guard true, with its store.** Layer norm (the corpus file) at block
size 128, for every row length `n < 2 ^ 32`, thread `tid < 1024`, index `i` with `i + tid < n`
(the guard :708 true), blocks with `x`, `g` and `b` not `y`, tensors, `mu`, `rs` and valuation `W`
with `AtHead` at `i`: the round on `lnT`'s path (`%469`, `%483`, `%484`, `%495`, `%496`, `%529`,
`%532`) has its premises (`round_true`), `AtHead` holds after it at `i + 128`, and its memory is
`W`'s with 4 bytes stored at float `i + tid` of `y` (the store at :722, through the
`getelementptr` of :700). A run theorem's premise (IR :677-772); the bytes stored are not
named. -/
theorem AtHead.roundT {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : AtHead n tid i y g b x X G Bt mu rs W) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) (hg : i + tid < n) :
    RoundWith true lnT.h lnT.p lnT.dh lnT.H lnT.B W ∧
      AtHead n tid (i + 128) y g b x X G Bt mu rs
        (Valuation.roundWith true lnT.h lnT.H lnT.B W) ∧
      LnOut y [i + tid] W.mem (Valuation.roundWith true lnT.h lnT.H lnT.B W).mem := by
  have hR := MojoProofTest.LnRound.round_true n tid i y g b x W X G Bt mu rs hA.prog hA.fn
    hA.r476 hA.r478 hA.r24 hA.r67 hA.r462 hA.r466 hA.q462 hA.q466 hA.r468 hA.r469 hA.r470 hA.r72
    hA.by' hA.bg hA.bb hA.bx hA.fy hA.fg hA.fb hA.fx hA.hX hA.hG hA.hB ht hn hg
  have hA0 := hA
  obtain ⟨hP, hfn, h476, h478, -, h24, h67, h462, h466, hq462, hq466, h468, h469, h470, h72,
    hby', hbg, hbb, hbx, hfy, hfg, hfb, hfx, hX, hG, hB⟩ := hA0
  obl_have e3 : (vals W lnT.H.nodes)[3]?, e4 : (vals W lnT.H.nodes)[4]?
  have e5 : (vals W lnT.H.nodes)[5]? = some (.ok (.ofBool false)) :=
    vals_getElem?_eval rfl (eval_xor_true (SVal.eval_node_take (by decide) e4))
  have e6 : (vals W lnT.H.nodes)[6]? = some (.ok (.ofBool (decide (n ≤ i)))) :=
    vals_getElem?_eval rfl (eval_or_false (SVal.eval_node_take (by decide) e5)
      (SVal.eval_node_take (by decide) e3))
  have hO : LnOut y [i + tid] W.mem (Valuation.roundWith true lnT.h lnT.H lnT.B W).mem := by
    have hw : WalkWith true ((((W.intoWith true lnT.h lnT.H).intoWith true ln.fn_0.b_45.label
        b483).intoWith true ln.fn_0.b_46.label b484).intoWith true ln.fn_0.b_47.label b495)
        [(ln.fn_0.b_48.label, b496.obls, b496), (ln.fn_0.b_55.label, b529.obls, b529),
          (ln.fn_0.b_57.label, b532.obls, b532)] := hR.1.2.2.2.2.2.2.2.2
    obtain ⟨me, hme⟩ := hw.1 (.mem b496.effs) (by decide +kernel)
    obl_have em4 : ((((W.intoWith true lnT.h lnT.H).intoWith true ln.fn_0.b_45.label
        b483).intoWith true ln.fn_0.b_46.label b484).intoWith true ln.fn_0.b_47.label
        b495).mem,
      p490 : ((((W.intoWith true lnT.h lnT.H).intoWith true ln.fn_0.b_45.label
        b483).intoWith true ln.fn_0.b_46.label b484).intoWith true ln.fn_0.b_47.label
        b495).regs 490
    have hsz : ln.prog.layout.size (.fp .float) = 4 := by rfl
    have p490' : ((((W.intoWith true lnT.h lnT.H).intoWith true ln.fn_0.b_45.label
        b483).intoWith true ln.fn_0.b_46.label b484).intoWith true ln.fn_0.b_47.label
        b495).regs 490 = some (.ptr ⟨y, ((4 * (i + tid) : Nat) : Int)⟩) := by
      rw [p490, hsz, Nat.mul_comm]
    have hF4 : ((((W.intoWith true lnT.h lnT.H).intoWith true ln.fn_0.b_45.label
        b483).intoWith true ln.fn_0.b_46.label b484).intoWith true ln.fn_0.b_47.label
        b495).fn = ln.fn_0 :=
      (Valuation.intoWith_k _ _ _ _).2.1.trans <| (Valuation.intoWith_k _ _ _ _).2.1.trans <|
        (Valuation.intoWith_k _ _ _ _).2.1.trans <| (Valuation.intoWith_k _ _ _ _).2.1.trans hfn
    have hP4 : ((((W.intoWith true lnT.h lnT.H).intoWith true ln.fn_0.b_45.label
        b483).intoWith true ln.fn_0.b_46.label b484).intoWith true ln.fn_0.b_47.label
        b495).ctx.prog = ln.prog := by
      rw [(Valuation.intoWith_k _ _ _ _).1, (Valuation.intoWith_k _ _ _ _).1,
        (Valuation.intoWith_k _ _ _ _).1, (Valuation.intoWith_k _ _ _ _).1]
      exact hP
    have e1 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).mem = me := by
      show (((((((W.intoWith true lnT.h lnT.H).intoWith true ln.fn_0.b_45.label
        b483).intoWith true ln.fn_0.b_46.label b484).intoWith true ln.fn_0.b_47.label
        b495).intoWith true ln.fn_0.b_48.label b496).intoWith true ln.fn_0.b_55.label
        b529).intoWith true ln.fn_0.b_57.label b532).mem = me
      rw [mem_none rfl, mem_none rfl]
      exact mem_run hme
    have hes : b496.effs = [.load 501 0 (.reg 493), .load 501 1 (.reg 492),
        .load 501 2 (.reg 491)] ++ [.store 501 7 (.node 6) (.reg 490)] := by decide +kernel
    rw [hes] at hme
    have hO := run_put (es := [.load 501 0 (.reg 493), .load 501 1 (.reg 492),
      .load 501 2 (.reg 491)]) (lbl := 501) (pc := 7) hF4 hP4 (by rfl) (by rfl) (by
      intro e he
      simp only [List.mem_cons, List.mem_nil_iff, or_false] at he
      rcases he with rfl | rfl | rfl <;> exact ⟨_, _, _, rfl⟩) (SVal.eval_reg p490') hme
    rw [em4] at hO
    rw [e1]
    exact hO
  obl_have r476 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 476,
    r478 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 478,
    r474 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 474,
    r24 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 24,
    r67 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 67,
    r462 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 462,
    r466 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 466,
    q462 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).prods 462,
    q466 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).prods 466,
    r468 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 468,
    r469 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 469,
    r470 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 470,
    r72 : (Valuation.roundWith true lnT.h lnT.H lnT.B W).regs 72
  exact ⟨hR, hA.next hO hxy hgy hby (by rw [round_ctx.1]; exact hP) (round_ctx.2.trans hfn)
    r476 r478 ⟨_, r474⟩ r24 r67 r462 r466 q462 q466 r468 r469 r470 r72, hO⟩

/-- **The round with the guard false, with no store.** Layer norm (the corpus file) at block
size 128, for every row length `n < 2 ^ 32`, thread `tid < 1024`, index `i` with
`i < n ≤ i + tid` (the header goes on, the guard :708 false), blocks with `x`, `g` and `b` not
`y`, tensors, `mu`, `rs` and valuation `W` with `AtHead` at `i`: the round on `lnF`'s path
(`%469`, `%483`, `%484`, `%531`, `%532`) has its premises (`round_false`), `AtHead` holds after
it at `i + 128`, and its memory has `W`'s blocks (`LnOut y []`). A run theorem's premise
(IR :677-772). -/
theorem AtHead.roundF {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : AtHead n tid i y g b x X G Bt mu rs W) (ht : tid < 1024)
    (hn : n < 2 ^ 32) (hxy : x ≠ y) (hgy : g ≠ y) (hby : b ≠ y) (hi : i < n)
    (hg : n ≤ i + tid) :
    RoundWith true lnF.h lnF.p lnF.dh lnF.H lnF.B W ∧
      AtHead n tid (i + 128) y g b x X G Bt mu rs
        (Valuation.roundWith true lnF.h lnF.H lnF.B W) ∧
      LnOut y [] W.mem (Valuation.roundWith true lnF.h lnF.H lnF.B W).mem := by
  have hA0 := hA
  obtain ⟨hP, hfn, h476, h478, ⟨v, h474⟩, h24, h67, h462, h466, hq462, hq466, h468, h469, h470,
    h72, hby', hbg, hbb, hbx, hfy, hfg, hfb, hfx, hX, hG, hB⟩ := hA0
  have hR := MojoProofTest.LnRound.round_false n tid i y g b x W v hP hfn h476 h478 h474 h24 h67
    h468 h469 h470 h72 hby' hbg hbb hbx ht hn hi hg
  obl_have e3 : (vals W lnF.H.nodes)[3]?, e4 : (vals W lnF.H.nodes)[4]?
  have e5 : (vals W lnF.H.nodes)[5]? = some (.ok (.ofBool false)) :=
    vals_getElem?_eval rfl (eval_xor_true (SVal.eval_node_take (by decide) e4))
  have e6 : (vals W lnF.H.nodes)[6]? = some (.ok (.ofBool (decide (n ≤ i)))) :=
    vals_getElem?_eval rfl (eval_or_false (SVal.eval_node_take (by decide) e5)
      (SVal.eval_node_take (by decide) e3))
  obl_have fm : (Valuation.roundWith true lnF.h lnF.H lnF.B W).mem,
    r476 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 476,
    r478 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 478,
    r474 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 474,
    r24 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 24,
    r67 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 67,
    r462 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 462,
    r466 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 466,
    q462 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).prods 462,
    q466 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).prods 466,
    r468 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 468,
    r469 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 469,
    r470 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 470,
    r72 : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 72
  have r476' : (Valuation.roundWith true lnF.h lnF.H lnF.B W).regs 476 =
      some (.bits 64 (BitVec.ofNat 64 (i + 128))) := by
    rw [r476]
  have hO : LnOut y [] W.mem (Valuation.roundWith true lnF.h lnF.H lnF.B W).mem :=
    LnOut.refl (by rw [fm])
  exact ⟨hR, hA.next hO hxy hgy hby (by rw [round_ctx.1]; exact hP) (round_ctx.2.trans hfn)
    r476' r478 ⟨_, r474⟩ r24 r67 r462 r466 q462 q466 r468 r469 r470 r72, hO⟩

/-- **The path out of the loop.** Layer norm (the corpus file) at block size 128, for every row
length `n < 2 ^ 32`, index `i` with `n ≤ i < n + 128` (the exit test `icmp sge` at :684 true),
thread, blocks, tensors, `mu`, `rs` and valuation `W` with `AtHead` at `i`: the path `%469`,
`%482` has its premises and goes to `%534` at its first statement (`EdgeWith`, :677-693, :774),
and it keeps the memory. A run theorem's premise. -/
theorem AtHead.exit {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {W : Valuation} (hA : AtHead n tid i y g b x X G Bt mu rs W)
    (hn : n < 2 ^ 32) (hi : n ≤ i) (hi' : i < n + 128) :
    EdgeWith true ln.fn_0.b_58.label 0 W lnF.h lnF.dh lnF.H lnF.X ∧
      (Valuation.roundWith true lnF.h lnF.H lnF.X W).mem = W.mem := by
  obtain ⟨hP, hfn, h476, h478, ⟨v, h474⟩, h24, h67, h462, h466, hq462, hq466, h468, h469, h470,
    h72, hby', hbg, hbb, hbx, hfy, hfg, hfb, hfx, hX, hG, hB⟩ := hA
  obl_have e3 : (vals W lnF.H.nodes)[3]?, e4 : (vals W lnF.H.nodes)[4]?
  have e5 : (vals W lnF.H.nodes)[5]? = some (.ok (.ofBool false)) :=
    vals_getElem?_eval rfl (eval_xor_true (SVal.eval_node_take (by decide) e4))
  have e6 : (vals W lnF.H.nodes)[6]? = some (.ok (.ofBool (decide (n ≤ i)))) :=
    vals_getElem?_eval rfl (eval_or_false (SVal.eval_node_take (by decide) e5)
      (SVal.eval_node_take (by decide) e3))
  obl_have xm : (Valuation.roundWith true lnF.h lnF.H lnF.X W).mem
  exact ⟨by mojo_obl, xm⟩

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

/-- **The thread leaves the loop.** Layer norm (the corpus file) at block size 128, for every
context `c` of `ln.prog` (so every launch and thread), row length `n < 2 ^ 32`, index `i` with
`n ≤ i < n + 128`, thread state `t` whose innermost frame `f` is at the header `%469`'s statement
3 (after the `phi`s), and memory `m`, with `AtHead` at `i` at `f`'s entry valuation: the thread's
steps reach `%534`'s first statement (:774) in a frame above the same frames, with `f`'s caller's
register, and the memory's blocks are `m`'s. A run theorem (IR :677-693). -/
theorem run_exit {n tid i y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (hn : n < 2 ^ 32) (hi : n ≤ i) (hi' : i < n + 128)
    {t : Thread} {m : Mem} {f : Frame} {rest : List Frame} (hfr : t.frames = f :: rest)
    (hf : f.fn = ln.fn_0) (hl : f.label = ln.fn_0.b_43.label) (hp : f.pc = 3)
    (hA : AtHead n tid i y g b x X G Bt mu rs (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧ LnOut y [] m m' := by
  obtain ⟨hX, hm⟩ := hA.exit hn hi hi'
  obtain ⟨t', m', f', hS, ht', hf', hl', hp', -, -, hd', hV⟩ :=
    Block.sound_edge (alloca := false) hc cov_X hfr hf hl hp hX.1 hX.2.1
  have hp₂ : ((Valuation.entry c t.k m f).lastWith true lnF.h lnF.H lnF.X).2.2.exit.pc f.fn
      ln.fn_0.b_58.label = 0 := hX.2.2
  rw [hf] at hp₂
  have e : m' = (Valuation.roundWith true lnF.h lnF.H lnF.X (Valuation.entry c t.k m f)).mem :=
    congrArg Valuation.mem hV
  refine ⟨t', m', f', hS, ht', hf', hl', hp'.trans hp₂, hd', LnOut.refl ?_⟩
  rw [e, hm]
  rfl

/-- **Layer norm's last loop runs from index `i` with fuel `K`.** Layer norm (the corpus file) at
block size 128, for every context `c` of `ln.prog` (so every launch and thread), thread index
`tid < 1024`, row length `n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`,
`mu`, `rs`, fuel `K` and index `i` with `n ≤ i + 128 K` and `i < n + 128`, thread state `t` whose
innermost frame `f` is at the header `%469`'s statement 3 (after the `phi`s, :678-680), and memory
`m`, with `AtHead` at `i` at `f`'s entry valuation: the thread's steps reach `%534`'s first
statement (:774) in a frame above the same frames, with `f`'s caller's register, and the memory
is `m` with 4 bytes stored at each float of `lnLoop 128 n tid K i` of `y`, in that order, and no
other block changed (`LnOut`). By induction on `K`: each round by `Block.sound_edge` with
`AtHead.roundT` or `AtHead.roundF`, the last by `run_exit`. A run theorem (IR :677-772); the
bytes stored are not named. -/
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
        LnOut y (lnLoop 128 n tid K i) m m' := by
  intro K
  induction K with
  | zero =>
    intro i hK hi t m f rest hfr hf hl hp hA
    exact run_exit hc hn (by omega) hi hfr hf hl hp hA
  | succ K ih =>
    intro i hK hi t m f rest hfr hf hl hp hA
    by_cases h0 : n ≤ i
    · have e : lnLoop 128 n tid (K + 1) i = [] := by simp [lnLoop, h0]
      rw [e]
      exact run_exit hc hn h0 hi hfr hf hl hp hA
    by_cases hg : i + tid < n
    · obtain ⟨hR, hA', hO⟩ := hA.roundT ht hn hxy hgy hby hg
      obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hf₁, hl₁, hp₁, -, -, hd₁, hV₁⟩ :=
        Block.sound_edge (alloca := false) hc cov_T hfr hf hl hp hR.1 hR.2.1
      have hp₂ : ((Valuation.entry c t.k m f).lastWith true lnT.h lnT.H lnT.B).2.2.exit.pc f.fn
          lnT.h = 3 := hR.2.2
      rw [hf] at hp₂
      have e₁ : m₁ =
          (Valuation.roundWith true lnT.h lnT.H lnT.B (Valuation.entry c t.k m f)).mem :=
        congrArg Valuation.mem hV₁
      rw [← hV₁] at hA'
      obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hf₂, hl₂, hp₃, hd₂, hO₂⟩ :=
        ih (i + 128) (by omega) (by omega) ht₁ hf₁ hl₁ (hp₁.trans hp₂) hA'
      have e : lnLoop 128 n tid (K + 1) i = [i + tid] ++ lnLoop 128 n tid K (i + 128) := by
        simp [lnLoop, h0, hg]
      rw [e]
      have hO₁ : LnOut y [i + tid] m m₁ := by rw [e₁]; exact hO
      exact ⟨t₂, m₂, f₂, hS₁.trans hS₂, ht₂, hf₂, hl₂, hp₃, hd₂.trans hd₁, hO₁.trans hO₂⟩
    · obtain ⟨hR, hA', hO⟩ := hA.roundF ht hn hxy hgy hby (by omega) (by omega)
      obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hf₁, hl₁, hp₁, -, -, hd₁, hV₁⟩ :=
        Block.sound_edge (alloca := false) hc cov_F hfr hf hl hp hR.1 hR.2.1
      have hp₂ : ((Valuation.entry c t.k m f).lastWith true lnF.h lnF.H lnF.B).2.2.exit.pc f.fn
          lnF.h = 3 := hR.2.2
      rw [hf] at hp₂
      have e₁ : m₁ =
          (Valuation.roundWith true lnF.h lnF.H lnF.B (Valuation.entry c t.k m f)).mem :=
        congrArg Valuation.mem hV₁
      rw [← hV₁] at hA'
      obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hf₂, hl₂, hp₃, hd₂, hO₂⟩ :=
        ih (i + 128) (by omega) (by omega) ht₁ hf₁ hl₁ (hp₁.trans hp₂) hA'
      have e : lnLoop 128 n tid (K + 1) i = [] ++ lnLoop 128 n tid K (i + 128) := by
        simp [lnLoop, h0, hg]
      rw [e]
      have hO₁ : LnOut y [] m m₁ := by rw [e₁]; exact hO
      exact ⟨t₂, m₂, f₂, hS₁.trans hS₂, ht₂, hf₂, hl₂, hp₃, hd₂.trans hd₁, hO₁.trans hO₂⟩

/-- **Layer norm's last loop: the stores are at `lnStores`' floats.** Layer norm (the corpus
file) at block size 128, for every context `c` of `ln.prog` (so every launch and thread), thread
index `tid < 1024`, row length `n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`,
`Bt`, `mu`, `rs`, thread state `t` whose innermost frame `f` is at the header `%469`'s statement 3
after the `phi`s with the loop index `%471` zero (:679), and memory `m`, with `AtHead` at index 0
at `f`'s entry valuation: the thread's steps reach `%534`'s first statement (:774, past the exit
test and branch :684-690 and `%482`) in a frame above the same frames, with `f`'s caller's
register, and the memory is `m` with 4 bytes stored at each float of `lnStores 128 n tid` of `y`
(the floats `128 j + tid < n`, `lnStores_eq`), in that order, and no other block changed
(`LnOut`). `run_from` at `K = n`, `i = 0`. A run theorem (IR :677-774); the bytes stored are not
named, and the mean and inverse deviation are given registers. -/
theorem run {n tid y g b x : Nat}
    {X G Bt : TorchLean.Tensor (Model FloatTy.float.fmt) [n]} {mu rs : Model FloatTy.float.fmt}
    {c : Ctx} (hc : c.prog = ln.prog) (ht : tid < 1024) (hn : n < 2 ^ 32) (hxy : x ≠ y)
    (hgy : g ≠ y) (hby : b ≠ y) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (hfr : t.frames = f :: rest) (hf : f.fn = ln.fn_0) (hl : f.label = ln.fn_0.b_43.label)
    (hp : f.pc = 3) (hA : AtHead n tid 0 y g b x X G Bt mu rs (Valuation.entry c t.k m f)) :
    ∃ t' m' f', Steps c t m t' m' ∧ t'.frames = f' :: rest ∧ f'.fn = ln.fn_0 ∧
      f'.label = ln.fn_0.b_58.label ∧ f'.pc = 0 ∧ f'.dest = f.dest ∧
      LnOut y (lnStores 128 n tid) m m' :=
  run_from hc ht hn hxy hgy hby n 0 (by omega) (by omega) hfr hf hl hp hA

/-- Layer norm's `%453` from its branch (statement 21, :675): `br label %469`, into the loop. -/
sym_summary pre := ln.prog ln.fn_0 ln.fn_0.b_42.label 21

/-- The path checker with `phi`s and `fmul contract` (`coversPathAt`, no `alloca`) accepts
`%453` from its branch. By `decide +kernel`. -/
theorem cov_E : coversPathAt false true ln.prog ln.fn_0 21
    [(ln.fn_0.b_42.label, pre.obls, pre)] = true := by
  decide +kernel

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

/-- **Layer norm's last loop from its entry.** Layer norm (the corpus file) at block size 128, for
every context `c` of `ln.prog` (so every launch and thread), thread index `tid < 1024`, row length
`n < 2 ^ 32`, blocks with `x`, `g` and `b` not `y`, rows `X`, `G`, `Bt`, `mu`, `rs`, thread state
`t` whose innermost frame `f` is at `%453`'s branch into the loop (:675) and memory `m`, with
`entry_edge`'s registers and memory at `f`'s entry valuation (the thread index `tid`, the row
length `%65` the word of `n`, the mean `%460` and inverse deviation `%464`, the pointers `%466`
(`y`), `%467` (`g`), `%468` (`b`) and `%70` (`x`) to buffers of `4 n` bytes that fit, `x`, `g`
and `b` holding `X`, `G` and `Bt`): the thread's steps reach `%534`'s first statement (:774) in a
frame above the same frames, with `f`'s caller's register, and the memory is `m` with 4 bytes
stored at each float of `lnStores 128 n tid` of `y`, in that order, and no other block changed
(`LnOut`). `entry_edge` by `Block.sound_edge`, then `run`. A run theorem (IR :675-774); the bytes
stored are not named, and the mean and inverse deviation are given registers. -/
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
      LnOut y (lnStores 128 n tid) m m' := by
  obtain ⟨hE, hA, hm⟩ := entry_edge (W := Valuation.entry c t.k m f) hc hf h24 h67 h462 h466 hq462
    hq466 h468 h469 h470 h72 hby' hbg hbb hbx hfy hfg hfb hfx hX hG hB
  obtain ⟨t₁, m₁, f₁, hS₁, ht₁, hf₁, hl₁, hp₁, -, -, hd₁, hV₁⟩ :=
    Block.sound_edge (alloca := false) hc cov_E hfr hf hl hp hE.1 hE.2.1
  have hp₂ : ((Valuation.entry c t.k m f).lastWith true ln.fn_0.b_42.label pre []).2.2.exit.pc
      f.fn lnT.h = 3 := hE.2.2
  rw [hf] at hp₂
  have e₁ : m₁ =
      (Valuation.roundWith true ln.fn_0.b_42.label pre [] (Valuation.entry c t.k m f)).mem :=
    congrArg Valuation.mem hV₁
  rw [← hV₁] at hA
  obtain ⟨t₂, m₂, f₂, hS₂, ht₂, hf₂, hl₂, hp₃, hd₂, hO₂⟩ :=
    run hc ht hn hxy hgy hby ht₁ hf₁ hl₁ (hp₁.trans hp₂) hA
  have hO₁ : LnOut y [] m m₁ := LnOut.refl (by rw [e₁, hm]; rfl)
  exact ⟨t₂, m₂, f₂, hS₁.trans hS₂, ht₂, hf₂, hl₂, hp₃, hd₂.trans hd₁, hO₁.trans hO₂⟩

end MojoProofTest.LnRun
