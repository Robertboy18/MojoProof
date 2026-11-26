import MojoProofTest.GemvLoopTail

/-!
# gemv_kernel's stored word as the semantics' butterfly rounds

MojoProofTest/GemvLoopTail.lean's `to_ret` has lane 0 of gemv_kernel store `total c n x z₁ … z₅`:
the loop's sum `x` (`%79`) and the five values `z₁` to `z₅` that `%78`'s five `shfl.sync.bfly`
deliver, each added by an `fadd` that goes through `deliver` with its step's oracle number. This
file ties that word to the rounds of `MojoProof.Tile.bflyDeliver_holds`,
`bflyRoundsAt (fun r l x y => deliver (Model.add x y) (ob r l)) (bflyOffsets 5)`.

* `ofsAt`, `offsets`: the offsets of the five shuffles at statements 2, 6, 10, 14 and 18 of `%78`
  are `16, 8, 4, 2, 1`, which is `bflyOffsets 5` in order (by `decide +kernel` on the imported
  program), the order in which `bflyRoundsAt` applies them (the first offset first).
* `total_eq`: for every context, step `k0`, lane values `s`, oracle numbers `ob r l` that are
  `total`'s at lane 0 (round `r` is `total`'s `fadd` `i = r + 1`, whose number is
  `c.oracle (Nat.pair (k0 + 4 i - 1) 0) / 3`, so `4 i - 1 = 4 r + 3`), and deliveries `z r` that
  are lane 0's partner's value after the first `r` rounds (`bflyRoundsAt` at
  `(bflyOffsets 5).take r`, at lane `0 ^^^ (bflyOffsets 5)[r] = 2 ^ (4 - r)`), `total` at lane
  0's value `s 0` is lane 0's value after the five rounds (`MojoProof.Tile.bflyRoundsAt_take_succ`
  at each round).
* `rowWords`, `stored_holds`: at the run (`MojoProofTest.GemvLoop.run`'s `%79` at every lane as
  `s`, and `MojoProofTest.GemvLoop.pairs_eq`), lane 0's stored word is row `r` of words that meet
  the rule of `bflyDeliver_holds` at `k = 5`. The deliveries stay premises.
* `offered`, `shfls_offered`, `offered_eq`, `total_chain`: the value each lane offers at each
  shuffle, checked to be `shfls`' argument by `rfl`; if every shuffle delivers to each lane what
  its partner offers, the offered values are the lanes' values after the rounds before
  (`MojoProof.Tile.bflyRoundsAt_chain` over the 32 lanes at once), and every lane's `total` is
  its value after the five rounds (at lane 0, the word lane 0 stores).
* `cx`, `vS`, `zS`, `premises_vS`: the premises of `total_eq` at one example, decided; `A32`,
  `v32`, `I32`, `oZ`, `ob32`, `premises32`: those of `stored_holds` at size `1 × 32`, decided, with
  the stored word `2 ^ 24 + 2`; `zR`, `mutant_order`: the deliveries in the reversed round order,
  where the equation fails; `cn`, `vN`, `mutant_oracle`: the oracle numbers one off, where it
  fails at a NaN.

Tests of one program, gemv_kernel float32 `b79a852b`; `bflyRoundsAt_take_succ`,
`bflyRoundsAt_chain` and `bflyDeliver_holds` (MojoProof/Tile/MatVec.lean) are for every carrier
and format.
-/

namespace MojoProofTest.GemvLoopBfly

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
open MojoProofTest.GemvLoop MojoProofTest.GemvLoopTail
open FloatLib.Floats.Formats.BinaryInterchange

/-- The third operand of the `call` at statement `i` of gemv_kernel's `%78` (`b_10`) when it is an
integer constant (a `shfl.sync.bfly` call's offset), and `none` otherwise. A test definition. -/
def ofsAt (i : Nat) : Option Int :=
  match (gemv.fn_0.blocks.find? (·.label == gemv.fn_0.b_10.label)).bind (·.stmts[i]?) with
  | some ⟨_, .call _ _ _ args, _⟩ =>
    match args[2]? with
    | some (TValue.mk _ (Value.int n), _) => some n
    | _ => none
  | _ => none

/-- **`%78`'s offsets are `bflyOffsets 5`, in order** (test of gemv_kernel): the calls at
statements 2, 6, 10, 14 and 18 of `%78`, the five shuffles of `MojoProofTest.GemvLoopTail.thread`,
have the offsets `16, 8, 4, 2, 1`, which is `bflyOffsets 5` (`MojoProof.Sem.warpOffsets`). By
`decide +kernel`. -/
theorem offsets :
    [2, 6, 10, 14, 18].map ofsAt = (bflyOffsets 5).map fun m => some (m : Int) := by
  decide +kernel

/-- **`total` is lane 0's value after the semantics' five butterfly rounds** (test of one program,
gemv_kernel float32 `b79a852b`). For every context `c`, step `k0`, lane values `s` (binary32),
oracle numbers `ob r l` of round `r` at lane `l` and deliveries `z r` of round `r`: if at lane 0
`ob r 0` is `total`'s oracle number of round `r < 5`, `c.oracle (Nat.pair (k0 + 4 i - 1) 0) / 3`
at `i = r + 1` (`4 i - 1 = 4 r + 3`), and `z r` is lane 0's partner's value after the first `r`
rounds (`bflyRoundsAt` at `(bflyOffsets 5).take r`, at lane `0 ^^^ (bflyOffsets 5)[r]`, which is
`2 ^ (4 - r)`: lanes 16, 8, 4, 2, 1), then `total c k0 (s 0) (z 0) … (z 4)` is lane 0's value
after the five rounds `deliver (Model.add x y) (ob r l)` over `bflyOffsets 5`, the form of
`MojoProof.Tile.bflyDeliver_holds` at `k = 5`. The rounds' order is `%78`'s (`offsets`), and each
`fadd` adds the lane's own value first, as `bflyRoundsAt` does. `ob` at the other lanes is free:
it enters only through the deliveries. Proof: `MojoProof.Tile.bflyRoundsAt_take_succ` at each of
the five rounds, from the last. -/
theorem total_eq (c : Ctx) (k0 : Nat) (s : Nat → Model FloatTy.float.fmt)
    (ob : Nat → Nat → Nat) (hob : ∀ r < 5, ob r 0 = c.oracle (Nat.pair (k0 + (4 * r + 3)) 0) / 3)
    (z : Nat → Model FloatTy.float.fmt)
    (hz : ∀ r < 5, z r = bflyRoundsAt (fun r l x y => deliver (Model.add x y) (ob r l))
      ((bflyOffsets 5).take r) s (2 ^ (4 - r))) :
    total c k0 (s 0) (z 0) (z 1) (z 2) (z 3) (z 4) =
      bflyRoundsAt (fun r l x y => deliver (Model.add x y) (ob r l)) (bflyOffsets 5) s 0 := by
  have e : ∀ r < 5, bflyRoundsAt (fun r l x y => deliver (Model.add x y) (ob r l))
      ((bflyOffsets 5).take (r + 1)) s 0 = deliver (Model.add (bflyRoundsAt
        (fun r l x y => deliver (Model.add x y) (ob r l)) ((bflyOffsets 5).take r) s 0) (z r))
        (c.oracle (Nat.pair (k0 + (4 * r + 3)) 0) / 3) := by
    intro r hr
    have hl : r < (bflyOffsets 5).length := by simpa [bflyOffsets] using hr
    have hp : 0 ^^^ (bflyOffsets 5)[r] = 2 ^ (4 - r) := by
      rw [Nat.zero_xor]
      interval_cases r <;> rfl
    rw [MojoProof.Tile.bflyRoundsAt_take_succ _ _ r hl, hp, ← hz r hr, ← hob r hr]
  have e1 := e 0 (by decide)
  have e2 := e 1 (by decide)
  have e3 := e 2 (by decide)
  have e4 := e 3 (by decide)
  have e5 := e 4 (by decide)
  simp only [Nat.reduceAdd, Nat.reduceMul, List.take_zero] at e1 e2 e3 e4 e5
  rw [show bflyOffsets 5 = (bflyOffsets 5).take 5 from rfl, e5, e4, e3, e2, e1]
  rfl

/-- The words of `MojoProof.Tile.bflyDeliver_holds` at `k = 5` with the `contract` flag, for every
format, width, size, oracle sequences `o i l`, oracle numbers `ob i r l` and input words `I`: at
row `i`, lane 0's value after the five rounds `deliver (Model.add x y) (ob i r l)` over
`bflyOffsets 5`, from lane `l`'s `dotLoop true (o i l)` from `+0` over `stride 32 l` of the pairs
`(I (i, j), I j)` of row `i` and the vector. A test definition. -/
abbrev rowWords {fmt : FloatFormat} {bits : Nat} {σ : ℕ × ℕ} (o : Fin σ.1 → Nat → Nat → Nat × Nat)
    (ob : Fin σ.1 → Nat → Nat → Nat) (I : (MojoProof.Tile.matVecEnc fmt bits σ).inp.Words) :
    Fin σ.1 → Model fmt := fun i =>
  bflyRoundsAt (fun r l x y => deliver (Model.add x y) (ob i r l)) (bflyOffsets 5)
    (fun l => dotLoop true (o i l) (Model.zero fmt false)
      (stride (2 ^ 5) l (List.ofFn fun j => (I (.inl (i, j)), I (.inr j))))) 0

/-- **Lane 0's stored word meets `bflyDeliver_holds`'s rule at its row** (test of one program,
gemv_kernel float32 `b79a852b`). For every width `bits`, sizes `M`, `K`, matrix `A` (`M × K`),
vector `v`, input words `I` of `MojoProof.Tile.matVecEnc` at `(M, K)` that are `A`'s and `v`'s
entries, oracle sequences `o i l`, oracle numbers `ob i r l`, context `c`, step `k0`, row `r < M`
and deliveries `z j`, with `s l` the lane sum of `MojoProofTest.GemvLoop.run`'s `%79` at lane `l`,
`dotLoop true (o r l)` from `+0` over `stride 32 l (matVecPairs A v r)`: if `ob r j 0` is
`total`'s oracle number of round `j < 5` and `z j` is lane 0's partner's value after the first `j`
rounds over `s` (as in `total_eq`), then the words `rowWords o ob I` meet the rule of
`GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉)` (`bflyDeliver_holds` at
`k = 5`) and their row `r` is `total c k0 (s 0) (z 0) … (z 4)`, the word lane 0 stores in
`MojoProofTest.GemvLoopTail.to_ret` at `o r 0 = oG c t.k`, `k0` lane 0's step at `%78` and
`z₁ … z₅ = z 0 … z 4` (by `total_eq` and `MojoProofTest.GemvLoop.pairs_eq`). What stays a
premise: that the deliveries are the other lanes' values after the rounds before, which is the
warp at every `K` (`WarpRun.of_waits`, the lanes of one warp in turn), and that the other lanes'
sums are `run`'s at their oracle sequences. -/
theorem stored_holds (bits : Nat) {M K : Nat}
    (A : TorchLean.Tensor (Model FloatTy.float.fmt) [M, K])
    (v : TorchLean.Tensor (Model FloatTy.float.fmt) [K])
    (I : (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)).inp.Words)
    (hA : ∀ i j, I (.inl (i, j)) = TorchLean.Tensor.get2 A i j)
    (hv : ∀ j, I (.inr j) = v.getScalar j)
    (o : Fin M → Nat → Nat → Nat × Nat) (ob : Fin M → Nat → Nat → Nat) (c : Ctx) (k0 r : Nat)
    (hr : r < M)
    (hob : ∀ j < 5, ob ⟨r, hr⟩ j 0 = c.oracle (Nat.pair (k0 + (4 * j + 3)) 0) / 3)
    (z : Nat → Model FloatTy.float.fmt)
    (hz : ∀ j < 5, z j = bflyRoundsAt (fun j l x y => deliver (Model.add x y) (ob ⟨r, hr⟩ j l))
      ((bflyOffsets 5).take j) (fun l => dotLoop true (o ⟨r, hr⟩ l) (Model.zero _ false)
        (stride 32 l (matVecPairs A v ⟨r, hr⟩))) (2 ^ (4 - j))) :
    (GPUProof.Spec.matVec (GPUProof.laneVecGrade (2 ^ 5) 5 fun n => (n + 2 ^ 5 - 1) / 2 ^ 5)
        (GPUProof.laneVecGrade_mono _ _ _)).rule.Holds (M, K)
        (MojoProof.Tile.matVecEnc FloatTy.float.fmt bits (M, K)) I (rowWords o ob I) ∧
      rowWords o ob I ⟨r, hr⟩ = total c k0 (dotLoop true (o ⟨r, hr⟩ 0) (Model.zero _ false)
        (stride 32 0 (matVecPairs A v ⟨r, hr⟩))) (z 0) (z 1) (z 2) (z 3) (z 4) := by
  refine ⟨MojoProof.Tile.bflyDeliver_holds (fmt := FloatTy.float.fmt) (σ := (M, K)) rfl bits 5
    true o ob I, ?_⟩
  have hs : (fun l => dotLoop true (o ⟨r, hr⟩ l) (Model.zero FloatTy.float.fmt false)
      (stride (2 ^ 5) l (List.ofFn fun j => (I (.inl (⟨r, hr⟩, j)), I (.inr j))))) =
      fun l => dotLoop true (o ⟨r, hr⟩ l) (Model.zero _ false)
        (stride 32 l (matVecPairs A v ⟨r, hr⟩)) := by
    rw [pairs_eq bits A v I hA hv ⟨r, hr⟩]
    rfl
  show bflyRoundsAt _ _ _ 0 = _
  rw [hs]
  exact (total_eq c k0 _ (ob ⟨r, hr⟩) hob z hz).symm

/-- The value lane `l` offers at `%78`'s shuffle `i` (from 0), for every family of lane contexts
`c l`, steps `k0 l` (lane `l`'s at position 1 of `%78`), binary32 sums `x l` of `%79` and
deliveries `z i l` of shuffle `i` at lane `l`: `x l` at the first shuffle, then the value offered
at the shuffle before plus its delivery, through `addAt` at step `k0 l + (4 i + 3)` (`total`'s
`fadd`s). After the fifth, `offered c k0 x z 5 l` is `total` at lane `l`. A test definition. -/
def offered (c : Nat → Ctx) (k0 : Nat → Nat) (x : Nat → Model FloatTy.float.fmt)
    (z : Nat → Nat → Model FloatTy.float.fmt) : Nat → Nat → Model FloatTy.float.fmt
  | 0, l => x l
  | i + 1, l => addAt (c l) (k0 l + (4 * i + 3)) (offered c k0 x z i l) (z i l)

/-- **`offered` is the value `shfls` offers** (test of gemv_kernel's `%78`, for every family of
lane contexts, steps, sums and deliveries, every lane `l`, memory and resumptions): the second
argument of each of `shfls`' five waits at lane `l` (the bits of the sum so far) is
`offered c k0 x z i l`, for `i` from 0 to 4. By `rfl`. -/
theorem shfls_offered (c : Nat → Ctx) (k0 : Nat → Nat) (x : Nat → Model FloatTy.float.fmt)
    (z : Nat → Nat → Model FloatTy.float.fmt) (l : Nat) (m : Mem)
    (d₁ d₂ d₃ d₄ d₅ : Option Val × Mem) :
    (shfls (c l) (k0 l) (x l) (z 0 l) (z 1 l) (z 2 l) (z 3 l) m d₁ d₂ d₃ d₄ d₅).map
        (·.args[1]?) = (List.range 5).map fun i => some (.ofFloat .float (offered c k0 x z i l)) :=
  rfl

/-- **Each lane's offered values are its values after the butterfly rounds, when each shuffle
delivers its partner's offered value** (test of gemv_kernel's `%78`, for every family of lane
contexts `c l`, steps `k0 l`, binary32 sums `x l` of `%79` and deliveries `z i l`): if at every
shuffle `i < 5` and lane `l < 32` the delivery `z i l` is what lane `l`'s partner
`l ^^^ 2 ^ (4 - i)` offers there (`offered`, `shfls`' argument by `shfls_offered`), then at
every `i ≤ 5` and lane `l < 32`, `offered c k0 x z i l` is lane `l`'s value after the first `i`
rounds `deliver (Model.add a b)`, with lane `l`'s oracle number of round `r`,
`(c l).oracle (Nat.pair (k0 l + (4 r + 3)) 0) / 3`, over `bflyOffsets 5` from the sums `x`. So
each delivery `z i l` is its partner's value after the first `i` rounds, which at lane 0 is
`total_eq`'s and `stored_holds`' premise on the deliveries (`0 ^^^ 2 ^ (4 - i) = 2 ^ (4 - i)`).
Proof: `MojoProof.Tile.bflyRoundsAt_chain` over the lanes below 32 (each offset `2 ^ (4 - r)`
is below 32, `Nat.xor_lt_two_pow`), with `offered` as the values per round. -/
theorem offered_eq (c : Nat → Ctx) (k0 : Nat → Nat) (x : Nat → Model FloatTy.float.fmt)
    (z : Nat → Nat → Model FloatTy.float.fmt)
    (hz : ∀ i < 5, ∀ l < 32, z i l = offered c k0 x z i (l ^^^ 2 ^ (4 - i))) :
    ∀ i ≤ 5, ∀ l < 32, offered c k0 x z i l =
      bflyRoundsAt (fun r l a b => deliver (Model.add a b)
        ((c l).oracle (Nat.pair (k0 l + (4 * r + 3)) 0) / 3)) ((bflyOffsets 5).take i) x l := by
  have hm : ∀ r (hr : r < (bflyOffsets 5).length), (bflyOffsets 5)[r] = 2 ^ (4 - r) := by
    decide
  have hlen : (bflyOffsets 5).length = 5 := rfl
  exact MojoProof.Tile.bflyRoundsAt_chain (fun r l a b => deliver (Model.add a b)
      ((c l).oracle (Nat.pair (k0 l + (4 * r + 3)) 0) / 3)) (bflyOffsets 5) (· < 2 ^ 5)
    (fun r hr l hl => Nat.xor_lt_two_pow hl
      ((hm r hr).symm ▸ Nat.pow_lt_pow_right (by decide) (by omega)))
    (offered c k0 x z)
    (fun r hr l hl => by rw [hm r hr, ← hz r (hlen ▸ hr) l hl]; rfl)

/-- **Every lane's `total` is its value after the five butterfly rounds, when each shuffle
delivers its partner's offered value** (test of gemv_kernel's `%78`, for every family of lane
contexts `c l`, steps `k0 l`, binary32 sums `x l` of `%79` and deliveries `z i l`): under
`offered_eq`'s premise (each delivery `z i l` is what lane `l`'s partner `l ^^^ 2 ^ (4 - i)`
offers at shuffle `i`), at every lane `l < 32`, `total (c l) (k0 l) (x l) (z 0 l) … (z 4 l)` is
lane `l`'s value after the five rounds `deliver (Model.add a b)`, with lane `l`'s oracle number
of round `r`, `(c l).oracle (Nat.pair (k0 l + (4 r + 3)) 0) / 3`, over `bflyOffsets 5` from the
sums `x`. At lane 0 it is the word `MojoProofTest.GemvLoopTail.to_ret` has lane 0 store, as
`bflyRoundsAt … (bflyOffsets 5) x 0`. What stays a premise: that each shuffle delivers its
partner's offered value, the shuffle's part of the warp at every `K`. Proof: `offered_eq` at
`i = 5`, where `offered c k0 x z 5 l` is `total` at lane `l` by definition. -/
theorem total_chain (c : Nat → Ctx) (k0 : Nat → Nat) (x : Nat → Model FloatTy.float.fmt)
    (z : Nat → Nat → Model FloatTy.float.fmt)
    (hz : ∀ i < 5, ∀ l < 32, z i l = offered c k0 x z i (l ^^^ 2 ^ (4 - i))) :
    ∀ l < 32, total (c l) (k0 l) (x l) (z 0 l) (z 1 l) (z 2 l) (z 3 l) (z 4 l) =
      bflyRoundsAt (fun r l a b => deliver (Model.add a b)
        ((c l).oracle (Nat.pair (k0 l + (4 * r + 3)) 0) / 3)) (bflyOffsets 5) x l :=
  offered_eq c k0 x z hz 5 le_rfl

-- `offered_eq` at lane 0 is `total_eq`'s premise on the deliveries (and so `stored_holds`'), and
-- `total_eq` then gives `total_chain` at lane 0.
example (c : Nat → Ctx) (k0 : Nat → Nat) (x : Nat → Model FloatTy.float.fmt)
    (z : Nat → Nat → Model FloatTy.float.fmt)
    (hz : ∀ i < 5, ∀ l < 32, z i l = offered c k0 x z i (l ^^^ 2 ^ (4 - i))) :
    total (c 0) (k0 0) (x 0) (z 0 0) (z 1 0) (z 2 0) (z 3 0) (z 4 0) =
      bflyRoundsAt (fun r l a b => deliver (Model.add a b)
        ((c l).oracle (Nat.pair (k0 l + (4 * r + 3)) 0) / 3)) (bflyOffsets 5) x 0 :=
  total_eq (c 0) (k0 0) x (fun r l => (c l).oracle (Nat.pair (k0 l + (4 * r + 3)) 0) / 3)
    (fun _ _ => rfl) (fun r => z r 0) fun r hr => by
      rw [hz r hr 0 (by decide), Nat.zero_xor]
      exact offered_eq c k0 x z hz r hr.le (2 ^ (4 - r))
        (show 2 ^ (4 - r) < 2 ^ 5 from Nat.pow_lt_pow_right (by decide) (by omega))

/-- A context of gemv_kernel's program: no globals, every special register `0`, thread 0 of block
0, every skeleton and oracle choice `0`. A test definition. -/
def cx : Ctx := ⟨gemv.prog, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩, fun _ => 0, fun _ => 0⟩

/-- Lane values: `2 ^ 24` (binary32 `0x4b800000`) at lane 0, `1` (`0x3f800000`) at lanes 1 and 17,
`+0` elsewhere. A test definition. -/
def vS (l : Nat) : Model FloatTy.float.fmt :=
  Model.ofNatBits (if l = 0 then 0x4b800000 else if l = 1 ∨ l = 17 then 0x3f800000 else 0)

/-- Deliveries `+0, +0, +0, +0, 2` (`0x40000000`): over `vS`, lane 0's partners' values after the
rounds before (`premises_vS`). A test definition. -/
def zS (r : Nat) : Model FloatTy.float.fmt :=
  Model.ofNatBits (if r = 4 then 0x40000000 else 0)

/-- **The premises of `total_eq` at one example** (test of one example): in context `cx` at step
0, over the lane values `vS`, with `ob r l` `total`'s oracle number of round `r` at every lane,
the deliveries `zS` are lane 0's partners' values after the rounds before theirs (lanes 16, 8, 4
and 2 hold `+0` then; lane 1 holds `1 + 1 = 2` after the first four rounds), and lane 0's value
after the five rounds is `2 ^ 24 + 2`, exact. By `decide +kernel`; `total_eq` then gives
`total`'s value. -/
theorem premises_vS :
    (∀ r < 5, zS r = bflyRoundsAt (fun r _ x y => deliver (Model.add x y)
        (cx.oracle (Nat.pair (0 + (4 * r + 3)) 0) / 3)) ((bflyOffsets 5).take r) vS
        (2 ^ (4 - r))) ∧
      (bflyRoundsAt (fun r _ x y => deliver (Model.add x y)
        (cx.oracle (Nat.pair (0 + (4 * r + 3)) 0) / 3)) (bflyOffsets 5) vS 0).toRat? =
        some 16777218 := by
  decide +kernel

-- `total_eq` at the example: `total cx 0 (vS 0) (zS 0) … (zS 4)` is lane 0's rounds.
example := total_eq cx 0 vS (fun r _ => cx.oracle (Nat.pair (0 + (4 * r + 3)) 0) / 3)
  (fun _ _ => rfl) zS premises_vS.1

/-- The binary32 `1 × 32` matrix whose row holds `vS`'s lane values (`2 ^ 24` at column 0, `1` at
columns 1 and 17, `+0` elsewhere), as a TorchLean tensor of shape `[1, 32]`. A test definition. -/
def A32 : TorchLean.Tensor (Model FloatTy.float.fmt) [1, 32] :=
  TorchLean.Tensor.Rep.ofFn fun c => vS c.2.1.val

/-- The binary32 vector of 32 ones (`0x3f800000`), as a TorchLean tensor of shape `[32]`. A test
definition. -/
def v32 : TorchLean.Tensor (Model FloatTy.float.fmt) [32] :=
  TorchLean.Tensor.Rep.ofFn fun _ => Model.ofNatBits 0x3f800000

/-- The input words of `MojoProof.Tile.matVecEnc` at size `(1, 32)` and width 32: `vS j` at matrix
position `(0, j)` and `1` at every vector position. A test definition. -/
def I32 : (MojoProof.Tile.matVecEnc FloatTy.float.fmt 32 (1, 32)).inp.Words :=
  Sum.elim (fun ik => vS ik.2.val) fun _ => Model.ofNatBits 0x3f800000

/-- Every lane loop's oracle choice is `(0, 0)`: the `fadd contract` is rounded separately
(`contract` at 0), and each result is its IEEE one (`deliver` at 0). A test definition. -/
def oZ : Fin 1 → Nat → Nat → Nat × Nat := fun _ _ _ => (0, 0)

/-- The rounds' oracle numbers at every lane: `total`'s of round `j` in context `cx` at step 0. A
test definition. -/
def ob32 : Fin 1 → Nat → Nat → Nat := fun _ j _ => cx.oracle (Nat.pair (0 + (4 * j + 3)) 0) / 3

/-- **The premises of `stored_holds` at one example** (test of one example): at size `1 × 32`,
`I32`'s words are the entries of the matrix `A32` and the vector `v32`; with the lane loops'
oracle choices `oZ` and the rounds' numbers `ob32`, the deliveries `zS` are lane 0's partners'
values after the rounds before over the lanes' loops of row 0 (lane `l` folds its one pair
`(vS l, 1)`, so its sum is `vS l`); and row 0 of `rowWords oZ ob32 I32` is `2 ^ 24 + 2`, exact.
`stored_holds` then gives the rule and `total`'s value (the `example` after it). By
`decide +kernel`; the equations between `I32`'s words, typed as `matVecEnc`'s input words, and the
tensors' entries are decided through `GPUProof.Encodings.decEqUniformInp`. -/
theorem premises32 :
    (∀ i j, I32 (.inl (i, j)) = TorchLean.Tensor.get2 A32 i j) ∧
      (∀ j, I32 (.inr j) = v32.getScalar j) ∧
      (∀ j < 5, zS j = bflyRoundsAt (fun j l x y => deliver (Model.add x y) (ob32 0 j l))
        ((bflyOffsets 5).take j) (fun l => dotLoop true (oZ 0 l) (Model.zero _ false)
          (stride 32 l (matVecPairs A32 v32 0))) (2 ^ (4 - j))) ∧
      (rowWords (fmt := FloatTy.float.fmt) (bits := 32) (σ := (1, 32)) oZ ob32 I32 0).toRat? =
        some 16777218 := by
  decide +kernel

-- `stored_holds` at the example: the words meet the rule, and row 0 is `total`'s word at lane 0's
-- sum and the deliveries `zS`.
example := stored_holds 32 A32 v32 I32 premises32.1 premises32.2.1 oZ ob32 cx 0 0 (by decide)
  (fun _ _ => rfl) zS premises32.2.2.1

/-- Deliveries `1, +0, +0, +0, 1`: over `vS`, lane 0's partners' values with the rounds in the
reversed order, offsets `1, 2, 4, 8, 16` (`mutant_order`). A test definition. -/
def zR (r : Nat) : Model FloatTy.float.fmt :=
  Model.ofNatBits (if r = 0 ∨ r = 4 then 0x3f800000 else 0)

/-- **Mutant: the deliveries in the reversed round order** (test of one example): over `vS` in
context `cx`, the deliveries `zR` are lane 0's partners' values (lane `2 ^ r` after the first `r`
rounds) when the rounds take the offsets in the reversed order `1, 2, 4, 8, 16`. With them,
`total` is `2 ^ 24`: lane 0 adds `1` to `2 ^ 24` in the first round and in the last, and each is
a tie that rounds to the even `2 ^ 24`. That is not lane 0's value after the rounds over
`bflyOffsets 5`, `2 ^ 24 + 2` (`premises_vS`), where lanes 1 and 17 add their `1`s first. So the
order of the deliveries matters to `total_eq`. By `decide +kernel`. -/
theorem mutant_order :
    (∀ r < 5, zR r = bflyRoundsAt (fun r _ x y => deliver (Model.add x y)
        (cx.oracle (Nat.pair (0 + (4 * r + 3)) 0) / 3)) ((bflyOffsets 5).reverse.take r) vS
        (2 ^ r)) ∧
      (total cx 0 (vS 0) (zR 0) (zR 1) (zR 2) (zR 3) (zR 4)).toRat? = some 16777216 ∧
      total cx 0 (vS 0) (zR 0) (zR 1) (zR 2) (zR 3) (zR 4) ≠
        bflyRoundsAt (fun r _ x y => deliver (Model.add x y)
          (cx.oracle (Nat.pair (0 + (4 * r + 3)) 0) / 3)) (bflyOffsets 5) vS 0 := by
  decide +kernel

/-- A context of gemv_kernel's program as `cx`, except that its oracle offers `3 · 0x7fc00001` at
`Nat.pair 19 0`, the number of `total`'s last `fadd` at step 0 (`19 = 4 · 5 - 1`), which `deliver`
reads, divided by 3, as the binary32 NaN `0x7fc00001`. A test definition. -/
def cn : Ctx := ⟨gemv.prog, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩, fun _ => 0,
  fun n => if n = Nat.pair 19 0 then 3 * 0x7fc00001 else 0⟩

/-- Lane values: the binary32 quiet NaN `0x7fc00000` at lane 0, `+0` elsewhere. A test
definition. -/
def vN (l : Nat) : Model FloatTy.float.fmt := Model.ofNatBits (if l = 0 then 0x7fc00000 else 0)

/-- **Mutant: the oracle numbers one off** (test of one example): with `ob r 0` the number at
`Nat.pair (k0 + 4 i) 0`, `i = r + 1`, in place of `total`'s `k0 + 4 i - 1`, in context `cn` at
step 0 over `vN`, the deliveries `+0` are still lane 0's partners' values after the rounds before
(no partner, lanes 16, 8, 4, 2 and 1, has met lane 0's NaN by then), but `total`, whose last
`fadd` delivers the oracle's NaN `0x7fc00001`, is not lane 0's value after the rounds at the
shifted numbers, where every number is `0` and each `fadd` keeps its IEEE NaN. So the reindexing
of `total_eq`'s `hob` is the one that holds. By `decide +kernel`. -/
theorem mutant_oracle :
    (∀ r < 5, (Model.ofNatBits 0 : Model FloatTy.float.fmt) = bflyRoundsAt
        (fun r _ x y => deliver (Model.add x y) (cn.oracle (Nat.pair (0 + (4 * r + 4)) 0) / 3))
        ((bflyOffsets 5).take r) vN (2 ^ (4 - r))) ∧
      total cn 0 (vN 0) (Model.ofNatBits 0) (Model.ofNatBits 0) (Model.ofNatBits 0)
          (Model.ofNatBits 0) (Model.ofNatBits 0) ≠
        bflyRoundsAt
          (fun r _ x y => deliver (Model.add x y) (cn.oracle (Nat.pair (0 + (4 * r + 4)) 0) / 3))
          (bflyOffsets 5) vN 0 := by
  decide +kernel

end MojoProofTest.GemvLoopBfly
