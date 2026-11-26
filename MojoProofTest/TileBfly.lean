import MojoProof.Tile.MatVec

/-!
# The butterfly's partner chain at 4 and 8 lanes

`MojoProof.Tile.bflyRoundsAt_chain` turns values per round and lane, of which each is the round
function of the lane's own and its partner's values the round before, into the butterfly rounds
`bflyRoundsAt` at every lane of a set closed under partners. Here it is tested with the round
function `a ++ b` on lists of lane numbers, which keeps the order in which each lane meets the
others' start values, so that two orders of the offsets give two different values:

* `lanes4`, `round4`, `chain4`: at 4 lanes over `bflyOffsets 2` (offsets `2, 1`), the table of
  each lane's list after rounds 0, 1 and 2 meets the round premise (by `decide`), and
  `bflyRoundsAt_chain` gives the rounds at every lane below 4;
* `mutant4`: the same table with the offsets reversed (`1, 2`) fails the round premise, and its
  value after both rounds at lane 0 is not the rounds' over the reversed offsets;
* `xorList`, `lanes8`, `round8`, `chain8`: at 8 lanes over `bflyOffsets 3` (offsets `4, 2, 1`)
  and over the offsets `1, 4, 2`, each lane's list in closed form, the round premise (by
  `decide`) and the rounds at every lane below 8;
* `mutant8`: the closed form over `4, 2, 1` fails the round premise over `1, 2, 4` and its value
  after the three rounds at lane 5 is not the rounds' over `1, 2, 4`.

Tests at 4 and 8 lanes; `bflyRoundsAt_chain` is for every type, round function, offsets and set
of lanes.
-/

namespace MojoProofTest.TileBfly

open MojoProof.Sem MojoProof.Tile

/-- At 4 lanes over `bflyOffsets 2` (offsets `2, 1`), the list of start lanes that lane `l < 4`
holds after round `r ≤ 2` with the round function `a ++ b`: `[l]` before the rounds, then lane `l`'s
list followed by its partner's (`l ^^^ 2`, then `l ^^^ 1`). `[]` elsewhere. A test definition. -/
def lanes4 (r l : Nat) : List Nat :=
  ([[[0], [1], [2], [3]], [[0, 2], [1, 3], [2, 0], [3, 1]],
    [[0, 2, 1, 3], [1, 3, 0, 2], [2, 0, 3, 1], [3, 1, 2, 0]]].getD r []).getD l []

/-- **The 4-lane table meets the round premise** (test at 4 lanes): over `bflyOffsets 2`, for
every round `r < 2` and lane `l < 4`, `lanes4 (r + 1) l` is lane `l`'s list after round `r`
followed by its partner's `l ^^^ (bflyOffsets 2)[r]`. By `decide`. -/
theorem round4 : ∀ r (hr : r < (bflyOffsets 2).length) l, l < 4 →
    lanes4 (r + 1) l = lanes4 r l ++ lanes4 r (l ^^^ (bflyOffsets 2)[r]) := by
  decide

/-- **The 4-lane table is the butterfly rounds** (test at 4 lanes): at every round `r ≤ 2` and lane
`l < 4`, `lanes4 r l` is lane `l`'s value after the first `r` rounds `a ++ b` over
`bflyOffsets 2` from the lists `[l]`. By `MojoProof.Tile.bflyRoundsAt_chain` with `round4`; the
lanes below 4 hold their partners (by `decide`). -/
theorem chain4 : ∀ r ≤ (bflyOffsets 2).length, ∀ l, l < 4 →
    lanes4 r l = bflyRoundsAt (fun _ _ a b => a ++ b) ((bflyOffsets 2).take r) (lanes4 0) l :=
  bflyRoundsAt_chain (fun _ _ a b => a ++ b) (bflyOffsets 2) (· < 4) (by decide) lanes4 round4

/-- **Mutant: the 4-lane table over the reversed offsets** (test at 4 lanes): with the offsets
`1, 2` in place of `2, 1`, `lanes4` fails the round premise, and its list after both rounds at
lane 0, `[0, 2, 1, 3]`, is not lane 0's value after the rounds `a ++ b` over `1, 2`,
`[0, 1, 2, 3]`. So the round function tells the two orders apart. By `decide`. -/
theorem mutant4 :
    ¬ (∀ r (hr : r < (bflyOffsets 2).reverse.length) l, l < 4 →
        lanes4 (r + 1) l = lanes4 r l ++ lanes4 r (l ^^^ (bflyOffsets 2).reverse[r])) ∧
      lanes4 2 0 ≠ bflyRoundsAt (fun _ _ a b => a ++ b) (bflyOffsets 2).reverse (lanes4 0) 0 := by
  decide

/-- The lanes `0 ^^^ p` that lane 0 meets over the offsets `ms`, last offset first, in the order of
the round function `a ++ b`: `[0]` over no offsets, and over `m :: ms` the list over `ms`
followed by each of its lanes xor `m`. A test definition. -/
def xorList : List Nat → List Nat
  | [] => [0]
  | m :: ms => xorList ms ++ (xorList ms).map (· ^^^ m)

/-- At 8 lanes over the offsets `ms`, the list of start lanes that lane `l` holds after round
`r` with the round function `a ++ b`, in closed form: each lane of `xorList` over the first `r`
offsets, last first, xor `l`. A test definition. -/
def lanes8 (ms : List Nat) (r l : Nat) : List Nat :=
  (xorList (ms.take r).reverse).map (l ^^^ ·)

/-- **The 8-lane closed form meets the round premise** (test at 8 lanes): over `bflyOffsets 3`
(offsets `4, 2, 1`) and over the offsets `1, 4, 2`, for every round `r < 3` and lane `l < 8`,
`lanes8 ms (r + 1) l` is lane `l`'s list after round `r` followed by its partner's. By
`decide`. -/
theorem round8 : ∀ ms ∈ [bflyOffsets 3, [1, 4, 2]], ∀ r (hr : r < ms.length) l, l < 8 →
    lanes8 ms (r + 1) l = lanes8 ms r l ++ lanes8 ms r (l ^^^ ms[r]) := by
  decide

/-- **The 8-lane closed form is the butterfly rounds** (test at 8 lanes): over `bflyOffsets 3` and
over the offsets `1, 4, 2`, at every round `r ≤ 3` and lane `l < 8`, `lanes8 ms r l` is lane `l`'s
value after the first `r` rounds `a ++ b` from the lists `[l]`. By
`MojoProof.Tile.bflyRoundsAt_chain` with `round8`; the lanes below 8 hold their partners (by
`decide`). -/
theorem chain8 : ∀ ms ∈ [bflyOffsets 3, [1, 4, 2]], ∀ r ≤ ms.length, ∀ l, l < 8 →
    lanes8 ms r l = bflyRoundsAt (fun _ _ a b => a ++ b) (ms.take r) (lanes8 ms 0) l := by
  intro ms hms
  have hS : ∀ r (hr : r < ms.length) l, l < 8 → l ^^^ ms[r] < 8 := by
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hms
    rcases hms with rfl | rfl <;> decide
  exact bflyRoundsAt_chain (fun _ _ a b => a ++ b) ms (· < 8) hS (lanes8 ms) (round8 ms hms)

/-- **Mutant: the 8-lane closed form over the reversed offsets** (test at 8 lanes): the closed
form over `bflyOffsets 3` (`4, 2, 1`) fails the round premise over the reversed offsets `1, 2, 4`,
and its list after the three rounds at lane 5, `[5, 1, 7, 3, 4, 0, 6, 2]`, is not lane 5's value
after the rounds `a ++ b` over `1, 2, 4`. By `decide`. -/
theorem mutant8 :
    ¬ (∀ r (hr : r < (bflyOffsets 3).reverse.length) l, l < 8 →
        lanes8 (bflyOffsets 3) (r + 1) l = lanes8 (bflyOffsets 3) r l ++
          lanes8 (bflyOffsets 3) r (l ^^^ (bflyOffsets 3).reverse[r])) ∧
      lanes8 (bflyOffsets 3) 3 5 = [5, 1, 7, 3, 4, 0, 6, 2] ∧
      lanes8 (bflyOffsets 3) 3 5 ≠
        bflyRoundsAt (fun _ _ a b => a ++ b) (bflyOffsets 3).reverse
          (lanes8 (bflyOffsets 3) 0) 5 := by
  decide

end MojoProofTest.TileBfly
