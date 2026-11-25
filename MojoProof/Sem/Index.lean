import MojoProof.Sem.Spec
import MojoProof.Sem.Buffer
import GPUProof.MixedRadix

/-!
# The global thread index

The index a 1-D kernel computes, `ctaid.x * ntid.x + tid.x`, as the IR computes it in i64: the
special registers are i32 words, `tid.x` and `ctaid.x` are zero-extended and `ntid.x`
sign-extended to i64, then `mul` and `add`, with any flags (`nuw`, `nsw`). docs/proofs/index.md
has the informal argument. Proved here:

- the operations on words of natural numbers, for every width and all flags: `trunc` and `zext`
  of the word of `k < 2 ^ w` are the word of `k` (`intCast_ofNat`); `sext` of it is too if
  `2 k < 2 ^ w` (`intCast_sext_ofNat`), since its sign bit is clear (`BitVec.toInt_ofNat_of_lt`,
  `outS_of_lt`); `add` and `mul` of the words of `a` and `b` are the word of `a + b` and `a * b`
  when twice the result is below `2 ^ w`, and, for `mul`, twice each operand
  (`intBin_add_ofNat`, `intBin_mul_ofNat`): neither `nuw` nor `nsw` makes them poison. So `trunc`
  to `w'` and then `sext` back of the word of `k` with `2 k < 2 ^ w'` is the word of `k`
  (`intCast_trunc_sext`; the vector kernel's `%22`, `%23` with `w' = 32`). The facts of a word of
  `k` with `2 k < 2 ^ w` are the core's `GPUProof.WordFit` (GPUProof/MixedRadix.lean, through
  `GPUProof.WordFit.two_mul_lt_iff`): the signed value (`BitVec.toInt_ofNat_of_lt`), `sext`
  (`intCast_sext_ofNat`) and the two overflow tests of `add` (`intBin_add_ofNat`) are its fields
  `toInt`, `signExtend` and `add`. `trunc` and `zext` of a word of `k < 2 ^ w` and `mul` are
  proved here.
- `Launch.index_ops`, for every valid launch (`Launch.Valid`), thread number and dimension, and
  all flags: each of the five operations on the special registers' words gives the word of its
  natural-number result, so the IR's index is the i64 word of
  `ctaid d * ntid d + tid d`, which is below `2 ^ 42` (`Launch.index_lt`).
- `Launch.index_oneDim`, for every launch whose grid and block have size 1 in `y` and `z`, and
  every thread number below the launch's thread count: `ctaid.x * ntid.x + tid.x` is the thread
  number.
- `Launch.index_inj`, for every valid launch, two thread numbers and a dimension: equal i64 words
  of the index give equal `ctaid` and equal `tid` in that dimension (as `tid d < ntid d`).

On 2-D launches, with `Launch.index L n d` for `ctaid d * ntid d + tid d` of thread `n` (row
`Launch.index L n .x`, column `Launch.index L n .y`):

- `coord_linear`, `coord_inj`, for every box: a number below the box's volume is its coordinates'
  linear combination, so it is determined by its three coordinates; `coord_onto`: every point of
  the box is the coordinates of its linear combination, which is below the volume (the core's
  `GPUProof.MixedRadix.lt_prod` at the three digits).
- `Launch.env_inj`, for every launch: a thread below the thread count is determined by its six
  special registers (`ctaid` and `tid` in `x`, `y`, `z`).
- `Launch.thread_inj`, for every valid launch: threads below the thread count with equal i64 index
  words in all three dimensions are one thread; `Launch.xy_inj`, for every valid launch whose grid
  and block have side 1 in `z`: equal words in `x` and `y` suffice.
- `Launch.cell_inj`, `Launch.cell_apart`, for every such launch and every stride `s`: on threads
  below the thread count with column below `s`, `row * s + col` is injective, and for every base
  `b`, cell width `w` and predicate `p` selecting such threads, the cells
  `b + (row * s + col) * w` of distinct selected threads are `w` bytes apart;
  `Launch.apart_xy`, its form on the threads with row below `m` and column below `n ≤ s`
  (`Apart` on that subtype, the cell premise of `Kernel.sound_cellsWith`,
  MojoProof/Sym/Kernel.lean).
- `Launch.index_onto`, for every launch: every point `r` with `r d < L.grid d * L.block d` in each
  dimension is `Launch.index` of some thread below the thread count; `Launch.cell_onto`, for every
  valid launch: every cell `(r, c)` with `r < L.grid x * L.block x` and
  `c < L.grid y * L.block y` is the row and column of some thread below the thread count (no
  premise on `z`). `Launch.index_lt_mul`, for every launch with positive sides in `d`: every
  thread's index in `d` is below `L.grid d * L.block d`, so these bounds are sharp.

The instances (grid (2, 1, 1), block (4, 1, 1); grid and block (2, 2, 1)) and the twins (a 2-D
block, on which the index is not the thread number and not injective; a block of side 2 in `z`;
columns not below the stride; a row at the bound) are in MojoProofTest/Index.lean.
-/

namespace MojoProof.Sem

open LLVM

/-- The word of `k` has `k` as its signed value when `2 k < 2 ^ w` (its sign bit is clear), for
every width: the field `toInt` of the core's `GPUProof.WordFit`. -/
theorem _root_.BitVec.toInt_ofNat_of_lt {w k : Nat} (hk : 2 * k < 2 ^ w) :
    (BitVec.ofNat w k).toInt = k :=
  (GPUProof.WordFit.of_lt (GPUProof.WordFit.two_mul_lt_iff.1 hk)).toInt

/-- The natural number `k` with `2 k < 2 ^ w` is in the signed range of `w` bits, for every
width: `k < 2 ^ (w - 1)` (`GPUProof.WordFit.two_mul_lt_iff`). -/
theorem outS_of_lt {w k : Nat} (hk : 2 * k < 2 ^ w) : outS w k = false := by
  have hI : (k : Int) < 2 ^ (w - 1) := by exact_mod_cast GPUProof.WordFit.two_mul_lt_iff.1 hk
  have hP : (0 : Int) ≤ 2 ^ (w - 1) := by exact_mod_cast Nat.zero_le (2 ^ (w - 1))
  simp only [outS, Bool.not_eq_false', decide_eq_true_eq]
  constructor <;> omega

/-- `trunc` and `zext` to `w'` bits of the word of `k < 2 ^ w` give the word of `k`, for every
pair of widths. -/
theorem intCast_ofNat {op : CastOp} (hop : op = .trunc ∨ op = .zext) {w k : Nat} (w' : Nat)
    (hk : k < 2 ^ w) :
    intCast op w' (.bits w (BitVec.ofNat w k)) = .ok (.bits w' (BitVec.ofNat w' k)) := by
  have e : (BitVec.ofNat w k).setWidth w' = BitVec.ofNat w' k := by
    apply BitVec.eq_of_toNat_eq
    simp [BitVec.toNat_setWidth, Nat.mod_eq_of_lt hk]
  rcases hop with rfl | rfl <;> simp only [intCast, e] <;> rfl

/-- `sext` to `w'` bits of the word of `k` with `2 k < 2 ^ w` gives the word of `k`, for every
pair of widths: the sign bit is clear (the field `signExtend` of the core's `GPUProof.WordFit`). -/
theorem intCast_sext_ofNat {w k : Nat} (w' : Nat) (hk : 2 * k < 2 ^ w) :
    intCast .sext w' (.bits w (BitVec.ofNat w k)) = .ok (.bits w' (BitVec.ofNat w' k)) := by
  simp only [intCast, (GPUProof.WordFit.of_lt (GPUProof.WordFit.two_mul_lt_iff.1 hk)).signExtend w']
  rfl

/-- **`trunc`, then `sext` back, is the identity on small words.** For widths `w' ≤ w` and `k`
with `2 k < 2 ^ w'`, `trunc` to `w'` of the word of `k` is the word of `k`, and `sext` of that
back to `w` is the word of `k`. -/
theorem intCast_trunc_sext {w w' k : Nat} (hw : w' ≤ w) (hk : 2 * k < 2 ^ w') :
    intCast .trunc w' (.bits w (BitVec.ofNat w k)) = .ok (.bits w' (BitVec.ofNat w' k)) ∧
      intCast .sext w (.bits w' (BitVec.ofNat w' k)) = .ok (.bits w (BitVec.ofNat w k)) :=
  ⟨intCast_ofNat (.inl rfl) w' (by
    have := Nat.pow_le_pow_right (by omega : 0 < 2) hw
    omega), intCast_sext_ofNat w hk⟩

/-- `add` of the words of `a` and `b` with `2 (a + b) < 2 ^ w` is the word of `a + b`, for every
width and all flags: neither `nuw` nor `nsw` makes it poison (the field `add` of the core's
`GPUProof.WordFit`: no unsigned and no signed overflow). -/
theorem intBin_add_ofNat {w a b : Nat} (fl : IntFlags) (h : 2 * (a + b) < 2 ^ w) :
    intBin w .add fl (.bits w (BitVec.ofNat w a)) (.bits w (BitVec.ofNat w b)) =
      .ok (.bits w (BitVec.ofNat w (a + b))) := by
  obtain ⟨hu, hs, e⟩ := (GPUProof.WordFit.of_lt (GPUProof.WordFit.two_mul_lt_iff.1 h)).add a b rfl
  have h2 : outS w ((BitVec.ofNat w a).toInt + (BitVec.ofNat w b).toInt) = false := by
    simp only [BitVec.saddOverflow, Bool.or_eq_false_iff, decide_eq_false_iff_not] at hs
    simp only [outS, Bool.not_eq_false', decide_eq_true_eq]
    omega
  simp only [intBin, and_self, dite_true, BitVec.cast_eq, intBits, show
    decide ((BitVec.ofNat w a).toNat + (BitVec.ofNat w b).toNat ≥ 2 ^ w) = false from hu, h2, e,
    Bool.and_false, Bool.or_false]
  rfl

/-- `mul` of the words of `a` and `b` with `2 a`, `2 b` and `2 a b` below `2 ^ w` is the word of
`a b`, for every width and all flags: neither `nuw` nor `nsw` makes it poison. -/
theorem intBin_mul_ofNat {w a b : Nat} (fl : IntFlags) (ha : 2 * a < 2 ^ w) (hb : 2 * b < 2 ^ w)
    (h : 2 * (a * b) < 2 ^ w) :
    intBin w .mul fl (.bits w (BitVec.ofNat w a)) (.bits w (BitVec.ofNat w b)) =
      .ok (.bits w (BitVec.ofNat w (a * b))) := by
  have h1 : decide ((BitVec.ofNat w a).toNat * (BitVec.ofNat w b).toNat ≥ 2 ^ w) = false := by
    simp only [BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega : a < 2 ^ w),
      Nat.mod_eq_of_lt (by omega : b < 2 ^ w), decide_eq_false_iff_not]
    omega
  have h2 := outS_of_lt h
  push_cast at h2
  simp only [intBin, and_self, dite_true, BitVec.cast_eq, intBits, BitVec.toInt_ofNat_of_lt ha,
    BitVec.toInt_ofNat_of_lt hb, h1, h2, Bool.and_false, Bool.or_false, BitVec.ofNat_mul_ofNat]
  rfl

/-- The bounds of the special registers on a valid launch, for every thread number and
dimension: `tid d < 1024`, `ctaid d < 2 ^ 31` and `ntid d ≤ 1024`. -/
theorem Launch.sreg_lt {L : Launch} (h : L.Valid) (n : Nat) (d : Dim) :
    (L.env n).sreg .tid d < 1024 ∧ (L.env n).sreg .ctaid d < 2 ^ 31 ∧
      (L.env n).sreg .ntid d ≤ 1024 := by
  have hb : Launch.maxBlock d ≤ 1024 := by cases d <;> decide
  have hg : Launch.maxGrid d < 2 ^ 31 := by cases d <;> decide
  have t := (Launch.sreg_bound h n .tid d).2
  have c := (Launch.sreg_bound h n .ctaid d).2
  have k := (Launch.sreg_bound h n .ntid d).2
  simp only [SReg.hi] at t c k
  omega

/-- On a valid launch, for every thread number and dimension, `ctaid d * ntid d + tid d` is below
`2 ^ 42`. -/
theorem Launch.index_lt {L : Launch} (h : L.Valid) (n : Nat) (d : Dim) :
    (L.env n).sreg .ctaid d * (L.env n).sreg .ntid d + (L.env n).sreg .tid d < 2 ^ 42 := by
  obtain ⟨t, c, k⟩ := Launch.sreg_lt h n d
  have := Nat.mul_le_mul (Nat.le_of_lt c) k
  omega

/-- **The IR's index on words.** For every valid launch, thread number `n`, dimension `d`
and all flags `fl`, `fl'`: `zext` to i64 of the i32 words of `tid d` and `ctaid d`, `sext` of
that of `ntid d`, their `mul` and then the `add` of `tid d` give the i64 words of the natural
numbers, ending in that of `ctaid d * ntid d + tid d`. -/
theorem Launch.index_ops {L : Launch} (h : L.Valid) (n : Nat) (d : Dim) (fl fl' : IntFlags) :
    intCast .zext 64 (.bits 32 (BitVec.ofNat 32 ((L.env n).sreg .tid d))) =
        .ok (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .tid d))) ∧
      intCast .zext 64 (.bits 32 (BitVec.ofNat 32 ((L.env n).sreg .ctaid d))) =
        .ok (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ctaid d))) ∧
      intCast .sext 64 (.bits 32 (BitVec.ofNat 32 ((L.env n).sreg .ntid d))) =
        .ok (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ntid d))) ∧
      intBin 64 .mul fl (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ctaid d)))
          (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ntid d))) =
        .ok (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ctaid d * (L.env n).sreg .ntid d))) ∧
      intBin 64 .add fl'
          (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .ctaid d * (L.env n).sreg .ntid d)))
          (.bits 64 (BitVec.ofNat 64 ((L.env n).sreg .tid d))) =
        .ok (.bits 64 (BitVec.ofNat 64
          ((L.env n).sreg .ctaid d * (L.env n).sreg .ntid d + (L.env n).sreg .tid d))) := by
  obtain ⟨t, c, k⟩ := Launch.sreg_lt h n d
  have hi := Launch.index_lt h n d
  exact ⟨intCast_ofNat (.inr rfl) 64 (by omega), intCast_ofNat (.inr rfl) 64 (by omega),
    intCast_sext_ofNat 64 (by omega), intBin_mul_ofNat fl (by omega) (by omega) (by omega),
    intBin_add_ofNat fl' (by omega)⟩

/-- **On a 1-D launch the index is the thread number.** For every launch whose grid and
block have size 1 in `y` and `z`, and every thread number `n` below the launch's thread count
`volume L.grid * volume L.block`: `ctaid.x * ntid.x + tid.x` of thread `n` is `n`. -/
theorem Launch.index_oneDim {L : Launch} (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {n : Nat}
    (hn : n < volume L.grid * volume L.block) :
    (L.env n).sreg .ctaid .x * (L.env n).sreg .ntid .x + (L.env n).sreg .tid .x = n := by
  simp only [Launch.env, coord, volume, hg.1, hg.2, hb.1, hb.2, Nat.mul_one] at hn ⊢
  have hB : 0 < L.block .x := Nat.pos_of_ne_zero fun h0 => by simp [h0] at hn
  rw [Nat.mod_mod, Nat.mod_eq_of_lt ((Nat.div_lt_iff_lt_mul hB).2 hn)]
  exact Nat.div_add_mod' n _

/-- **The index is injective in its coordinates.** For every valid launch, thread numbers `n`,
`n'` and dimension `d`: if the i64 words of `ctaid d * ntid d + tid d` of the two threads are
equal, the threads have the same `ctaid d` and the same `tid d`, as `tid d < ntid d` and the
index is below `2 ^ 64` (`Launch.index_lt`). -/
theorem Launch.index_inj {L : Launch} (h : L.Valid) {n n' : Nat} (d : Dim)
    (he : BitVec.ofNat 64
        ((L.env n).sreg .ctaid d * (L.env n).sreg .ntid d + (L.env n).sreg .tid d) =
      BitVec.ofNat 64
        ((L.env n').sreg .ctaid d * (L.env n').sreg .ntid d + (L.env n').sreg .tid d)) :
    (L.env n).sreg .ctaid d = (L.env n').sreg .ctaid d ∧
      (L.env n).sreg .tid d = (L.env n').sreg .tid d := by
  have e := congrArg BitVec.toNat he
  rw [BitVec.toNat_ofNat, BitVec.toNat_ofNat,
    Nat.mod_eq_of_lt (by have := Launch.index_lt h n d; omega),
    Nat.mod_eq_of_lt (by have := Launch.index_lt h n' d; omega)] at e
  have hB := h.block_pos d
  have t : (L.env n).sreg .tid d < L.block d := coord_lt _ hB
  have t' : (L.env n').sreg .tid d < L.block d := coord_lt _ hB
  simp only [show ∀ m, (L.env m).sreg .ntid d = L.block d from fun _ => rfl] at e
  have hc : (L.env n).sreg .ctaid d = (L.env n').sreg .ctaid d := by
    have := congrArg (· / L.block d) e
    simp only [Nat.mul_add_div hB, Nat.div_eq_of_lt t, Nat.div_eq_of_lt t', Nat.add_zero,
      Nat.mul_comm _ (L.block d)] at this
    exact this
  refine ⟨hc, ?_⟩
  rw [hc, Nat.mul_comm] at e
  omega

/-- The global index of thread `n` of launch `L` in dimension `d`, `ctaid d * ntid d + tid d`:
the number whose i64 word the IR computes (`Launch.index_ops`). Unfolds by `rfl`. -/
def Launch.index (L : Launch) (n : Nat) (d : Dim) : Nat :=
  (L.env n).sreg .ctaid d * (L.env n).sreg .ntid d + (L.env n).sreg .tid d

/-- **A number is its coordinates' linear combination.** For every box `d` and `a < volume d`:
`a = coord x + d x * (coord y + d y * coord z)` (x fastest). -/
theorem coord_linear {d : Dim → Nat} {a : Nat} (h : a < volume d) :
    coord d a .x + d .x * (coord d a .y + d .y * coord d a .z) = a := by
  simp only [coord, volume] at h ⊢
  have hp : 0 < d .x * d .y := Nat.pos_of_ne_zero fun h0 => by simp [h0] at h
  rw [Nat.mod_eq_of_lt ((Nat.div_lt_iff_lt_mul hp).2 (by rw [Nat.mul_comm (d .z)]; exact h)),
    ← Nat.div_div_eq_div_mul, Nat.mod_add_div, Nat.mod_add_div]

/-- For every box `d`, two numbers below `volume d` with the same coordinates in `x`, `y` and `z`
are equal (`coord_linear`). -/
theorem coord_inj {d : Dim → Nat} {a b : Nat} (ha : a < volume d) (hb : b < volume d)
    (h : ∀ k, coord d a k = coord d b k) : a = b := by
  rw [← coord_linear ha, ← coord_linear hb, h .x, h .y, h .z]

/-- **Every point of a box is a number's coordinates** (the converse of `coord_linear`). For every
box `d` and point `p` with `p k < d k` in each dimension: `p x + d x * (p y + d y * p z)` is below
`volume d` (`GPUProof.MixedRadix.lt_prod`, the digits `p k` with radices `d k`) and has
coordinates `p`. -/
theorem coord_onto {d p : Dim → Nat} (hp : ∀ k, p k < d k) :
    p .x + d .x * (p .y + d .y * p .z) < volume d ∧
      ∀ k, coord d (p .x + d .x * (p .y + d .y * p .z)) k = p k := by
  have hx : 0 < d .x := Nat.lt_of_le_of_lt (Nat.zero_le _) (hp .x)
  have hy : 0 < d .y := Nat.lt_of_le_of_lt (Nat.zero_le _) (hp .y)
  have q : (p .x + d .x * (p .y + d .y * p .z)) / d .x = p .y + d .y * p .z := by
    rw [Nat.add_mul_div_left _ _ hx, Nat.div_eq_of_lt (hp .x), Nat.zero_add]
  refine ⟨?_, fun k => ?_⟩
  · have := GPUProof.MixedRadix.lt_prod
      (σ := fun v => [p .x, p .y, p .z, d .x, d .y, d .z].getD v 0)
      (x := ⟨[(.var 0, .var 3), (.var 1, .var 4), (.var 2, .var 5)]⟩) fun c hc => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at hc
        rcases hc with rfl | rfl | rfl <;> exact hp _
    simpa [GPUProof.MixedRadix.val, GPUProof.MixedRadix.radixProd, GPUProof.SizeExpr.eval, volume,
      Nat.mul_assoc] using this
  · cases k with
    | x => simp only [coord]; rw [Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt (hp .x)]
    | y => simp only [coord]; rw [q, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt (hp .y)]
    | z =>
      simp only [coord]
      rw [← Nat.div_div_eq_div_mul, q, Nat.add_mul_div_left _ _ hy, Nat.div_eq_of_lt (hp .y),
        Nat.zero_add, Nat.mod_eq_of_lt (hp .z)]

/-- **A thread is its six special registers.** For every launch and thread numbers `n`, `n'`
below the thread count `volume L.grid * volume L.block`: if the two threads have the same `ctaid`
and the same `tid` in every dimension, they are one thread. -/
theorem Launch.env_inj {L : Launch} {n n' : Nat} (hn : n < volume L.grid * volume L.block)
    (hn' : n' < volume L.grid * volume L.block)
    (hc : ∀ d, (L.env n).sreg .ctaid d = (L.env n').sreg .ctaid d)
    (ht : ∀ d, (L.env n).sreg .tid d = (L.env n').sreg .tid d) : n = n' := by
  have hB : 0 < volume L.block := Nat.pos_of_ne_zero fun h0 => by simp [h0] at hn
  have q : n / volume L.block = n' / volume L.block :=
    coord_inj ((Nat.div_lt_iff_lt_mul hB).2 hn) ((Nat.div_lt_iff_lt_mul hB).2 hn') hc
  have r : n % volume L.block = n' % volume L.block :=
    coord_inj (Nat.mod_lt n hB) (Nat.mod_lt n' hB) ht
  rw [← Nat.div_add_mod n (volume L.block), q, r, Nat.div_add_mod]

/-- **Equal index words in every dimension are one thread.** For every valid launch and thread
numbers `n`, `n'` below the thread count: if the i64 words of `Launch.index` of the two threads
are equal in `x`, `y` and `z`, they are one thread (`Launch.index_inj` in each dimension, then
`Launch.env_inj`). -/
theorem Launch.thread_inj {L : Launch} (h : L.Valid) {n n' : Nat}
    (hn : n < volume L.grid * volume L.block) (hn' : n' < volume L.grid * volume L.block)
    (he : ∀ d, BitVec.ofNat 64 (L.index n d) = BitVec.ofNat 64 (L.index n' d)) : n = n' :=
  Launch.env_inj hn hn' (fun d => (Launch.index_inj h d (he d)).1)
    fun d => (Launch.index_inj h d (he d)).2

/-- **On a launch of side 1 in `z`, the row and the column are the thread.** For every valid
launch whose grid and block have side 1 in `z`, and thread numbers `n`, `n'` below the thread
count: if the i64 words of `Launch.index` in `x` (the row) and in `y` (the column) of the two
threads are equal, they are one thread (`Launch.thread_inj`; in `z` every index is 0). -/
theorem Launch.xy_inj {L : Launch} (h : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
    {n n' : Nat} (hn : n < volume L.grid * volume L.block)
    (hn' : n' < volume L.grid * volume L.block)
    (hx : BitVec.ofNat 64 (L.index n .x) = BitVec.ofNat 64 (L.index n' .x))
    (hy : BitVec.ofNat 64 (L.index n .y) = BitVec.ofNat 64 (L.index n' .y)) : n = n' := by
  have z : ∀ m, L.index m .z = 0 := fun m => by
    simp [Launch.index, Launch.env, coord, hz.1, hz.2, Nat.mod_one]
  exact Launch.thread_inj h hn hn' fun | .x => hx | .y => hy | .z => by simp only [z]

/-- **Distinct threads have distinct cells.** For every valid launch whose grid and block have
side 1 in `z`, every stride `s`, and thread numbers `n`, `n'` below the thread count whose columns
(`Launch.index` in `y`) are below `s`: if `row * s + col` (`Launch.index` in `x`, then in `y`) is
the same for the two threads, they are one thread. -/
theorem Launch.cell_inj {L : Launch} (h : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
    {s n n' : Nat} (hn : n < volume L.grid * volume L.block)
    (hn' : n' < volume L.grid * volume L.block) (hs : L.index n .y < s) (hs' : L.index n' .y < s)
    (he : L.index n .x * s + L.index n .y = L.index n' .x * s + L.index n' .y) : n = n' := by
  have hr : L.index n .x = L.index n' .x := by
    by_contra hne
    rcases Nat.lt_or_gt_of_ne hne with hl | hl
    · have := stride_lt s hl; omega
    · have := stride_lt s hl; omega
  have hc : L.index n .y = L.index n' .y := by rw [hr] at he; omega
  exact Launch.xy_inj h hz hn hn' (congrArg _ hr) (congrArg _ hc)

/-- **The cells of the threads that write are apart.** For every valid launch whose grid and
block have side 1 in `z`, every stride `s`, base `b`, cell width `w`, and predicate `p` on thread
numbers such that `p n` gives `n` below the thread count and a column (`Launch.index` in `y`)
below `s`: for distinct threads `n`, `n'` with `p n` and `p n'`, the cells
`b + (row * s + col) * w` of the two threads are `w` bytes apart (`Launch.cell_inj`,
`apart_stride`). With `w = 4`, the 4-byte cells of a `float` matrix of row stride `s`. -/
theorem Launch.cell_apart {L : Launch} (h : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
    {s : Nat} {p : Nat → Prop}
    (hp : ∀ n, p n → n < volume L.grid * volume L.block ∧ L.index n .y < s) (b w : Nat) :
    ∀ n n', n ≠ n' → p n → p n' →
      b + (L.index n .x * s + L.index n .y) * w + w ≤
          b + (L.index n' .x * s + L.index n' .y) * w ∨
        b + (L.index n' .x * s + L.index n' .y) * w + w ≤
          b + (L.index n .x * s + L.index n .y) * w :=
  fun n n' hne h1 h2 => apart_stride b le_rfl _ _ fun e =>
    hne (Launch.cell_inj h hz (hp n h1).1 (hp n' h2).1 (hp n h1).2 (hp n' h2).2 e)

/-- **The 2-D cells of the threads in a corner of the launch are apart.** For every valid launch
`L` whose grid and block have side 1 in `z`, row stride `s`, bounds `m` on the row (`Launch.index`
in `x`) and `n ≤ s` on the column (`Launch.index` in `y`), and cell width `w`: on the threads
below the thread count whose row is below `m` and column below `n`, the cells
`(row * s + col) * w` are `w` bytes apart (`Apart` on that subtype, the premise of
`Kernel.sound_cellsWith`; `Launch.cell_apart`). With `w = 4` and `s` the row length, these are the
`float` cells of a matrix product's output that the threads inside the matrix store. It covers
every such launch, stride and bound. -/
theorem Launch.apart_xy {L : Launch} (h : L.Valid)
    (hz : L.grid .z = 1 ∧ L.block .z = 1) {s m n : Nat} (hn : n ≤ s) (w : Nat) :
    Apart (fun i : {k // k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
      L.index k .y < n} => (L.index i.1 .x * s + L.index i.1 .y) * w) w := by
  intro i j hij
  simpa using Launch.cell_apart h hz (s := s)
    (p := fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n)
    (fun k hk => ⟨hk.1, by omega⟩) 0 w i.1 j.1 (fun e => hij (Subtype.ext e)) i.2 j.2

/-- **Every index point is some thread's.** For every launch `L` and point `r` with
`r d < L.grid d * L.block d` in each dimension, some thread `n` below the thread count
`volume L.grid * volume L.block` has `Launch.index L n d = r d` in every dimension: the thread of
block point `r d / L.block d` and thread point `r d % L.block d` (`coord_onto`). No validity
premise: the bounds make every side positive. -/
theorem Launch.index_onto {L : Launch} {r : Dim → Nat} (hr : ∀ d, r d < L.grid d * L.block d) :
    ∃ n < volume L.grid * volume L.block, ∀ d, L.index n d = r d := by
  have hb : ∀ d, 0 < L.block d := fun d =>
    Nat.pos_of_ne_zero fun h0 => by have := hr d; simp [h0] at this
  obtain ⟨hB, eB⟩ := coord_onto (d := L.grid) (p := fun d => r d / L.block d)
    fun d => (Nat.div_lt_iff_lt_mul (hb d)).2 (hr d)
  obtain ⟨hT, eT⟩ := coord_onto (d := L.block) (p := fun d => r d % L.block d)
    fun d => Nat.mod_lt _ (hb d)
  generalize r .x / L.block .x + L.grid .x * (r .y / L.block .y + L.grid .y * (r .z / L.block .z))
    = B at hB eB
  generalize r .x % L.block .x + L.block .x * (r .y % L.block .y + L.block .y * (r .z % L.block .z))
    = T at hT eT
  have hv : 0 < volume L.block := Nat.lt_of_le_of_lt (Nat.zero_le _) hT
  refine ⟨volume L.block * B + T, ?_, fun d => ?_⟩
  · have := Nat.mul_le_mul_left (volume L.block) hB
    rw [Nat.mul_succ, Nat.mul_comm (volume L.block) (volume L.grid)] at this
    omega
  · show coord L.grid ((volume L.block * B + T) / volume L.block) d * L.block d +
      coord L.block ((volume L.block * B + T) % volume L.block) d = r d
    rw [Nat.mul_add_div hv, Nat.div_eq_of_lt hT, Nat.add_zero, Nat.mul_add_mod,
      Nat.mod_eq_of_lt hT, eB, eT]
    exact Nat.div_add_mod' (r d) (L.block d)

/-- **Every cell of a 2-D launch is some thread's.** For every valid launch, row `r` below
`L.grid x * L.block x` and column `c` below `L.grid y * L.block y`, some thread `n` below the
thread count has row `Launch.index L n .x = r` and column `Launch.index L n .y = c`
(`Launch.index_onto` at `(r, c, 0)`). No premise on `z`; with side 1 in `z` the thread is unique
(`Launch.xy_inj`). -/
theorem Launch.cell_onto {L : Launch} (h : L.Valid) {r c : Nat} (hr : r < L.grid .x * L.block .x)
    (hc : c < L.grid .y * L.block .y) :
    ∃ n < volume L.grid * volume L.block, L.index n .x = r ∧ L.index n .y = c :=
  let ⟨n, hn, e⟩ := Launch.index_onto (r := fun | .x => r | .y => c | .z => 0)
    fun | .x => hr | .y => hc | .z => Nat.mul_pos (h.grid_pos .z) (h.block_pos .z)
  ⟨n, hn, e .x, e .y⟩

/-- **The index bound is sharp.** For every launch whose grid and block have positive sides in
`d`, and every thread number `n` (below the thread count or not): `Launch.index L n d` is below
`L.grid d * L.block d`, as `ctaid d < L.grid d` and `tid d < L.block d` (`coord_lt`). -/
theorem Launch.index_lt_mul {L : Launch} {d : Dim} (hg : 0 < L.grid d) (hb : 0 < L.block d)
    (n : Nat) : L.index n d < L.grid d * L.block d := by
  have c : coord L.grid (n / volume L.block) d < L.grid d := coord_lt _ hg
  have t : coord L.block (n % volume L.block) d < L.block d := coord_lt _ hb
  have := Nat.mul_le_mul_right (L.block d) c
  rw [Nat.succ_mul] at this
  show coord L.grid (n / volume L.block) d * L.block d + coord L.block (n % volume L.block) d <
    L.grid d * L.block d
  omega

end MojoProof.Sem
