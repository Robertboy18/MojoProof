import GPUProof.Layout.Bits
import GPUProof.Layout.Swizzle
import GPUProof.Layout.TwoLevel

/-!
# Instances of the layout laws, and the counterexamples

One concrete instance of each law of docs/proofs/layout-laws.md, each by the general theorem
(its premises closed by `decide`, the remaining arithmetic by `decide`), on the layouts `nested`
(shape (2, (2, 3)), stride (1, (2, 4))), `colMajor23` ((2, 3):(1, 2)) and `rowMajor23`
((2, 3):(3, 1)), with `tileB` for a composition with three modes; `Lay.compose_all` also at a
second size, a 4 x 4 tile of `row_major[8, 16]` with two modes. Then, each by `decide` on
the model, a mixed coordinate past its bound and the counterexamples of section 3 of that
document: composition (one mode that fails `composeDiv` but meets `carryFree`, and two modes
that fail `noCarry` and `carryFree`), blocked product, idx2crd, zipped divide, upcast, the
swizzle, the placement of a layout that is not bit-linear, and the two-level swizzle (inner
bits that overlap, a coordinate past its extent, and an inner map that is not one-to-one). Each
of these covers one example; the laws they instantiate cover all shapes that meet their
premises.
-/

namespace MojoProofTest.LayoutLaws

open GPUProof.Layout GPUProof.Layout.Tup

/-- A nested layout: shape (2, (2, 3)) and stride (1, (2, 4)), of size 12 and cosize 12. -/
def nested : Lay :=
  ⟨[leaf 2 true, tup [leaf 2 true, leaf 3 true]], [leaf 1 true, tup [leaf 2 true, leaf 4 true]]⟩

/-- The column-major layout (2, 3):(1, 2). -/
def colMajor23 : List (Nat × Nat) := [(2, 1), (3, 2)]

/-- The row-major layout (2, 3):(3, 1), `row_major(2, 3)`. -/
def rowMajor23 : List (Nat × Nat) := rowMajor [2, 3]

/-! ## crd2idx, idx2crd, cosize, reverse, affinity -/

-- `Lay.call_scalar`: the scalar 7 of `nested` has the digits (1, 1, 1), so the offset 1 + 2 + 4
example : nested.call (leaf 7 false) = 7 := by
  rw [Lay.call_scalar nested (by decide) 7 false (by decide)]; decide

-- `Lay.call_flat`: the coordinate (1, 2) of (2, 3):(1, 2) has the offset 1 + 4
example : (Lay.flat colMajor23).call (tup ([1, 2].map (leaf · false))) = 5 := by
  rw [Lay.call_flat colMajor23 [1, 2] false rfl]; decide

-- `crd2idx_flat`: tuple extents do not enter the offset of leaf coordinates
example : crd2idx (tup ([1, 2].map (leaf · false))) (tup [tup [], leaf 7 true])
    (tup ([3, 1].map (leaf · true))) = 5 := by
  rw [crd2idx_flat false true [1, 2] [tup [], leaf 7 true] [3, 1] rfl rfl]; decide

-- `Lay.call_mixed`: the mixed coordinate (1, 5) of `nested` has the digits (1, 1, 2), the 5
-- split against the mode (2, 3); the offset is 1 + 2 + 8, the offset of (1, (1, 2))
example : digits (tup [leaf 1 false, leaf 5 false]) (tup nested.shape) = [1, 1, 2] := by decide
example : nested.call (tup [leaf 1 false, leaf 5 false]) = 11 := by
  rw [Lay.call_mixed nested (by decide) _ (by decide)]; decide
example : nested.call (tup [leaf 1 false, tup [leaf 1 false, leaf 2 false]]) = 11 := by
  rw [Lay.call_mixed nested (by decide) _ (by decide)]; decide
-- a leaf against a leaf extent has no bound: (7, 5) has the digits (7, 1, 2) and the offset 17
example : nested.call (tup [leaf 7 false, leaf 5 false]) = 17 := by
  rw [Lay.call_mixed nested (by decide) _ (by decide)]; decide
-- a scalar against a tuple mode needs its bound: 6 is not below the size 6 of (2, 3), so (1, 6)
-- fails `fits`; `crd2idx` gives the last mode the quotient 3, the offset 1 + 0 + 12 = 13,
-- where the digits (0, 0) of 6 against (2, 3) would give 1
example : fits (tup [leaf 1 false, leaf 6 false]) (tup nested.shape) = false := by decide
example : nested.call (tup [leaf 1 false, leaf 6 false]) = 13 := by decide

-- `idx2crd_call`: idx2crd of the offset 5 of (1, 2) in a column-major layout gives (1, 2)
example : (idx2crd ((Lay.flat colMajor23).call (tup ([1, 2].map (leaf · false))))
    (tup (Lay.flat colMajor23).shape) (tup (Lay.flat colMajor23).stride)).leaves = [1, 2] :=
  idx2crd_call colMajor23 (by decide) (by decide) [1, 2] rfl (by decide) false

-- `idx2crd_call_reverse`: the same in the row-major layout
example : (idx2crd ((Lay.flat rowMajor23).call (tup ([1, 2].map (leaf · false))))
    (tup (Lay.flat rowMajor23).shape) (tup (Lay.flat rowMajor23).stride)).leaves = [1, 2] :=
  idx2crd_call_reverse rowMajor23 (by decide) (by decide) [1, 2] rfl (by decide) false

-- `Lay.cosize_eq`: the cosize of `nested` is 1 * 1 + 1 * 2 + 2 * 4 + 1
example : nested.cosize = 12 := by
  rw [Lay.cosize_eq nested (by decide) (by decide)]; decide

-- `Lay.call_lt_cosize`: the last scalar's offset is below the cosize
example : nested.call (leaf 11 false) < nested.cosize :=
  Lay.call_lt_cosize nested (by decide) (by decide) 11 false (by decide)

-- `Lay.reverse_reverse` and `Lay.size_reverse`
example : nested.reverse.reverse = nested := Lay.reverse_reverse nested
example : nested.reverse.size = 12 := by rw [Lay.size_reverse]; decide

-- `Lay.call_reverse`: the transpose maps ((1, 2), 1) reversed to the offset of (1, (1, 2))
example : nested.reverse.call (tup [tup [leaf 1 false, leaf 2 false], leaf 1 false]) = 11 := by
  rw [show [tup [leaf 1 false, leaf 2 false], leaf 1 false] =
    [leaf 1 false, tup [leaf 1 false, leaf 2 false]].reverse from rfl,
    Lay.call_reverse nested [leaf 1 false, tup [leaf 1 false, leaf 2 false]] rfl rfl
      (by decide)]
  decide

-- `Lay.call_add`: the offset of (1, 0) + (1, 2) is the sum of the offsets
example : (Lay.flat colMajor23).call (tup ((List.zipWith (· + ·) [1, 0] [1, 2]).map
    (leaf · false))) = 1 + 5 := by
  rw [Lay.call_add colMajor23 [1, 0] [1, 2] false rfl rfl]; decide

-- `Lay.isAffine_flat`: adding 5 to the second element of (1, 2) in (2, 3):(1, 2) adds 5 * 2
example : (Lay.flat colMajor23).call (tup (([1, 2].modify 1 (· + 5)).map (leaf · false))) =
    (Lay.flat colMajor23).call (tup ([1, 2].map (leaf · false))) + 5 * 2 :=
  (Lay.isAffine_flat colMajor23 [1, 2] false rfl 1 5 (by decide)).2

-- a swizzle is not affine: `Swizzle(1, 0, 1)` maps 1 to 1 and 2 to 3, not to 2
example : Swizzle.call ⟨1, 0, 1⟩ 1 = 1 ∧ Swizzle.call ⟨1, 0, 1⟩ 2 = 3 := by decide

/-! ## Row major, coalesce, zipped divide, blocked product, upcast, index width -/

-- `rowMajor_call_lt`: (1, 2) is in bounds in (2, 3), and its offset 5 is below 6
example : (Lay.flat (rowMajor [2, 3])).call (tup ([1, 2].map (leaf · false))) < [2, 3].prod :=
  rowMajor_call_lt [2, 3] [1, 2] false rfl (by decide)

-- `rowMajor_onto`: the offset 4 of (2, 3) is the offset of an in-bounds coordinate
example : ∃ c : List Nat, c.length = (rowMajor [2, 3]).length ∧
    (∀ p ∈ c.zip (rowMajor [2, 3]), p.1 < p.2.1) ∧
    (Lay.flat (rowMajor [2, 3])).call (tup (c.map (leaf · false))) = 4 :=
  rowMajor_onto [2, 3] (by decide) 4 (by decide) false

-- `rowMajor_inj`: in-bounds coordinates of (2, 3) with one offset are equal
example (c : List Nat) (hl : c.length = 2) (hc : ∀ p ∈ c.zip (rowMajor [2, 3]), p.1 < p.2.1)
    (h : (Lay.flat (rowMajor [2, 3])).call (tup (c.map (leaf · false))) = 5) : c = [1, 2] := by
  refine rowMajor_inj [2, 3] (by decide) c [1, 2] false hl hc rfl (by decide) ?_
  rw [h]; decide

-- `Lay.coalesce_size` and `Lay.coalesce_call`: `nested` coalesces to (12):(1)
example : nested.coalesce.size = 12 := by rw [Lay.coalesce_size nested (by decide)]; decide
example : nested.coalesce.call (leaf 9 false) = nested.call (leaf 9 false) :=
  Lay.coalesce_call nested (by decide) 9 false (by decide)
example : nested.coalesce.modes = [(12, 1)] := by decide

-- `Lay.zippedDivide_call`: (4, 6):(1, 4) by the tile (2, 3) maps ((1, 2), (1, 1)) to the offset
-- of (1 + 2, 2 + 3)
example : ((Lay.flat [(4, 1), (6, 4)]).zippedDivide [2, 3]).call
    (tup [tup ([1, 2].map (leaf · false)), tup ([1, 1].map (leaf · false))]) =
    (Lay.flat [(4, 1), (6, 4)]).call (tup ([3, 5].map (leaf · false))) :=
  Lay.zippedDivide_call [(4, 1), (6, 4)] [2, 3] [1, 2] [1, 1] false rfl rfl rfl

-- `Lay.zippedDivide_size`: the tile (2, 3) divides (4, 6)
example : ((Lay.flat [(4, 1), (6, 4)]).zippedDivide [2, 3]).size = 24 := by
  rw [Lay.zippedDivide_size [(4, 1), (6, 4)] [2, 3] rfl (by decide)]; decide

-- `Lay.blockedProduct_call`: block (2, 2):(1, 2) and tiler (2, 3):(1, 2); the coordinate
-- ((1, 1), (1, 2)) has the offset 3 + 4 * 5
example : (Lay.blockedProduct (Lay.flat [(2, 1), (2, 2)]) (Lay.flat [(2, 1), (3, 2)])).call
    (tup (List.zipWith (fun a c => tup [leaf a false, leaf c false]) [1, 1] [1, 2])) = 23 := by
  rw [Lay.blockedProduct_call [(2, 1), (2, 2)] [(2, 1), (3, 2)] [1, 1] [1, 2] false (by decide)
    rfl rfl rfl]
  decide

-- `Lay.upcast_modes` and `Lay.upcast_call`: (4, 8):(8, 2) upcast by 2 is (4, 8):(4, 1)
example : (Lay.upcast 2 (Lay.flat [(4, 8), (8, 2)])).modes = [(4, 4), (8, 1)] := by
  rw [Lay.upcast_modes 2 [(4, 8), (8, 2)] (by decide)]; decide
example : 2 * (Lay.upcast 2 (Lay.flat [(4, 8), (8, 2)])).call (tup ([3, 5].map (leaf · false))) =
    34 := by
  rw [Lay.upcast_call 2 [(4, 8), (8, 2)] (by decide) [3, 5] false rfl]; decide

-- `Lay.upcast_fuse` and `Lay.upcast_scale`: Mojo's docstring example, `row_major[4, 8]` upcast
-- by 2. The stride 8 is a multiple of 2 and becomes 4; the stride 1 divides 2, so it becomes 1
-- and the extent 8 becomes 8 / (2 / 1) = 4. The upcast layout is (4, 4):(4, 1), and twice its
-- offset of (3, 2) is the offset of (3, 2 * 2) in (4, 8):(8, 1)
example : (Lay.upcast 2 (Lay.flat (rowMajor [4, 8]))).modes = [(4, 4), (4, 1)] := by
  rw [Lay.upcast_fuse 2 (rowMajor [4, 8]) (by decide)]; decide
example : 2 * (Lay.upcast 2 (Lay.flat (rowMajor [4, 8]))).call (tup ([3, 2].map (leaf · false))) =
    (Lay.flat (rowMajor [4, 8])).call (tup ([3, 4].map (leaf · false))) := by
  rw [Lay.upcast_scale 2 (rowMajor [4, 8]) (by decide) [3, 2] false rfl]; rfl

-- upcast of a stride-0 mode: `shape_div(2, 0)` is 0 in the model, so the extent becomes 0
example : (Lay.upcast 2 (Lay.flat [(4, 0)])).modes = [(0, 0)] := by decide

-- upcast of a divisor stride whose extent `f / stride` does not divide: (3):(1) by 2. The
-- extent 3 is not a multiple of 2 / 1, so `shape_div(3, 2)` is 1 and the upcast layout is
-- (1):(1), of size 1 where 3 / 2 elements of width 2 do not fit. `Lay.upcast_fuse` requires the
-- divisibility
example : (Lay.upcast 2 (Lay.flat [(3, 1)])).modes = [(1, 1)] := by decide

-- `Lay.call_flat_ofNat` and `Lay.call_flat_toNat`: at 8 bits, the offset 300 of (100, 2):(3, 0)
-- wraps to 44, and the offset 5 of (1, 2) in (2, 3):(1, 2) is exact
example : (List.zipWith (fun x d => BitVec.ofNat 8 x * BitVec.ofNat 8 d) [100, 2]
    ([(101, 3), (3, 0)].map Prod.snd)).sum = 44#8 := by
  rw [Lay.call_flat_ofNat 8 [(101, 3), (3, 0)] [100, 2] false rfl]; decide
example : (List.zipWith (fun x d => BitVec.ofNat 8 x * BitVec.ofNat 8 d) [1, 2]
    (colMajor23.map Prod.snd)).sum.toNat = 5 := by
  rw [Lay.call_flat_toNat 8 colMajor23 [1, 2] false rfl (by decide)]; decide

/-! ## Composition -/

-- `Lay.compose_sum` and `Lay.compose_call`, with one mode: `nested` composed with (6):(2). The
-- stride 2 is a multiple of the first extent 2, which leaves the stride 1; the second extent 2
-- divides the extent 6, which leaves the extent 3 for the last mode. The composite
-- (2, 3):(2, 4) has the size 6 and maps 5 to nested(10) = 2 + 8; its one term 10 meets
-- `noCarry` by `noCarry_one`
example : (nested.compose (Lay.flat [(6, 2)])).size = 6 :=
  (Lay.compose_sum nested _ (by decide) (by decide) (by decide) 5 false (by decide)
    (by decide)).1
example : (nested.compose (Lay.flat [(6, 2)])).call (leaf 5 false) = 10 := by
  rw [Lay.compose_call nested _ (by decide) (by decide) (by decide) 5 false (by decide)
    (by decide) (noCarry_one _ 10 (by decide))]; decide

/-- A tile of a 4 x 8 row-major layout, rows 0 and 1 by columns 0, 2, 4 and 6: the layout
(2, (2, 2)):(1, (8, 16)) of the indices of `row_major[4, 8]`, of size 8 and cosize 26. -/
def tileB : Lay :=
  ⟨[leaf 2 true, tup [leaf 2 true, leaf 2 true]], [leaf 1 true, tup [leaf 8 true, leaf 16 true]]⟩

-- `Lay.compose_all` with three modes: (4, 8):(8, 1) composed with `tileB` is
-- (2, 2, 2):(8, 2, 4). The term lists [0, 1], [0, 8] and [0, 16] of `tileB`'s modes are
-- `carryFree` against the extents (4, 8): their largest remainders by 4 add up to 1 < 4, those
-- of the quotients by 8 to 0 + 2 + 4 < 8, and the last quotients are 0. So the composite is A
-- after B at every coordinate, with no check per coordinate
example : ((Lay.flat (rowMajor [4, 8])).compose tileB).modes = [(2, 8), (2, 2), (2, 4)] := by
  decide
example : tileB.cosize = 26 := by decide
example (v : Nat) (hv : v < tileB.size) :
    ((Lay.flat (rowMajor [4, 8])).compose tileB).call (leaf v false) =
      (Lay.flat (rowMajor [4, 8])).call (leaf (tileB.call (leaf v false)) false) :=
  Lay.compose_all _ _ (by decide) (by decide) (by decide) (by decide) v false hv
example : ((Lay.flat (rowMajor [4, 8])).compose tileB).call (leaf 7 false) = 14 := by decide

-- `Lay.compose_all` at a second size, with two modes: (8, 16):(16, 1) composed with
-- (4, 4):(2, 16), the indices of rows 0, 2, 4, 6 by columns 0, 2, 4, 6 of `row_major[8, 16]`,
-- is (4, 4):(32, 2). The term lists [0, 2, 4, 6] and [0, 16, 32, 48] are `carryFree` against
-- the extents (8, 16): the largest remainders by 8 add up to 6 < 8, those of the quotients by
-- 16 to 0 + 6 < 16, and the last quotients are 0. So the composite is A after B at all 16
-- coordinates
example : ((Lay.flat (rowMajor [8, 16])).compose (Lay.flat [(4, 2), (4, 16)])).modes =
    [(4, 32), (4, 2)] := by
  decide
example (v : Nat) (hv : v < (Lay.flat [(4, 2), (4, 16)]).size) :
    ((Lay.flat (rowMajor [8, 16])).compose (Lay.flat [(4, 2), (4, 16)])).call (leaf v false) =
      (Lay.flat (rowMajor [8, 16])).call
        (leaf ((Lay.flat [(4, 2), (4, 16)]).call (leaf v false)) false) :=
  Lay.compose_all _ _ (by decide) (by decide) (by decide) (by decide) v false hv
example : ((Lay.flat (rowMajor [8, 16])).compose (Lay.flat [(4, 2), (4, 16)])).call
    (leaf 5 false) = 34 := by decide

/-! ## The swizzle -/

-- `Swizzle.call_call`: `Swizzle(2, 0, 2)` meets `bits ≤ |shift|`, so it undoes itself at 13
example : Swizzle.call ⟨2, 0, 2⟩ (Swizzle.call ⟨2, 0, 2⟩ 13) = 13 :=
  Swizzle.call_call ⟨2, 0, 2⟩ (by decide) 13

-- `Swizzle.call_xor`, with a negative shift
example : Swizzle.call ⟨2, 1, -3⟩ (6 ^^^ 3) =
    Swizzle.call ⟨2, 1, -3⟩ 6 ^^^ Swizzle.call ⟨2, 1, -3⟩ 3 :=
  Swizzle.call_xor ⟨2, 1, -3⟩ 6 3

/-! ## Bit layouts -/

-- `BitLayout.call_xor`: the map that sends domain bit 0 to 1 and bit 1 to 3 sends 3 to
-- 1 ^ 3 = 2
example : ((BitLayout.empty.put 0 1).put 1 3).call (1 ^^^ 2) =
    ((BitLayout.empty.put 0 1).put 1 3).call 1 ^^^ ((BitLayout.empty.put 0 1).put 1 3).call 2 :=
  BitLayout.call_xor _ 1 2
example : ((BitLayout.empty.put 0 1).put 1 3).call 3 = 2 := by decide

-- `placement_call`: `row_major(4, 8)` = (4, 8):(8, 1) is bit-linear, its placement's domain mask
-- is 31, its size 32 minus 1, and it maps 13 to the layout's offset 13 % 4 * 8 + 13 / 4 = 11
example : (placement (rowMajor [4, 8])).dom = (Lay.flat (rowMajor [4, 8])).size - 1 :=
  (placement_call _ (by decide) (by decide) (by decide)).1
example : (placement (rowMajor [4, 8])).call 13 =
    (Lay.flat (rowMajor [4, 8])).call (leaf 13 false) :=
  (placement_call _ (by decide) (by decide) (by decide)).2 13 false (by decide)
example : (placement (rowMajor [4, 8])).dom = 31 ∧ (placement (rowMajor [4, 8])).call 13 = 11 := by
  decide

-- `Swizzle.twoLevel_call`: `Swizzle(3, 0, 3)`, of period 6, on `row_major(16, 8)` =
-- (16, 8):(8, 1). Mode 0 gives its 3 low bits to the inner map and keeps the outer mode
-- (2):(64); mode 1 gives all 3 of its bits; their offset bits 3-5 and 0-2 are disjoint. The
-- coordinate (13, 5), of offset 109, goes to Swizzle(109) = 104, and the index 109, the
-- coordinate (13, 6) of offset 110, goes to Swizzle(110) = 107
example : (Swizzle.twoLevel ⟨3, 0, 3⟩ (rowMajor [16, 8])).call (tup [leaf 13 false, leaf 5 false]) =
    Swizzle.call ⟨3, 0, 3⟩
      ((Lay.flat (rowMajor [16, 8])).call (tup [leaf 13 false, leaf 5 false])) :=
  (Swizzle.twoLevel_call _ _ (by decide) (by decide) (by decide)).1 [13, 5] false rfl (by decide)
example : (Swizzle.twoLevel ⟨3, 0, 3⟩ (rowMajor [16, 8])).call (leaf 109 false) =
    Swizzle.call ⟨3, 0, 3⟩ ((Lay.flat (rowMajor [16, 8])).call (leaf 109 false)) :=
  (Swizzle.twoLevel_call _ _ (by decide) (by decide) (by decide)).2 109 false (by decide)
example : (Swizzle.twoLevel ⟨3, 0, 3⟩ (rowMajor [16, 8])).call (tup [leaf 13 false, leaf 5 false]) =
      104 ∧
    (Swizzle.twoLevel ⟨3, 0, 3⟩ (rowMajor [16, 8])).call (leaf 109 false) = 107 := by decide

/-! ## The counterexamples -/

-- composition (filed as modular/modular #7738): A = (6, 2):(1, 6) and B = (3):(4) give (3):(6),
-- so B's index 1 goes to 6, while A(B(1)) = A(4) = 4. B's stride 4 neither divides A's first
-- extent 6 nor is a multiple of it, so B fails `composeDiv`, the premise of `Lay.compose_call`
example : composeDiv [(6, 1)] (3, 4) = false := by decide
-- the term list [0, 4, 8] of B is `carryFree` against A's extents (6, 2), so of the two premises
-- of `Lay.compose_all` only `composeDiv` fails: neither premise implies the other
example : carryFree [6, 2] [[0, 4, 8]] = true := by decide
example : composeLeaf [(6, 1), (2, 6)] 3 4 = [(3, 6)] := by decide
example : ((Lay.flat [(6, 1), (2, 6)]).compose (Lay.flat [(3, 4)])).call (leaf 1 false) = 6 := by
  decide
example : (Lay.flat [(6, 1), (2, 6)]).call
    (leaf ((Lay.flat [(3, 4)]).call (leaf 1 false)) false) = 4 := by decide

-- composition with two modes, the twin of `Lay.compose_call` without `noCarry`:
-- A = (2, 2):(1, 10) and B = (2, 2):(1, 1), of cosize 3 within A's size 4. Each mode of B meets
-- `composeDiv` and composes to (2):(1), so the composite ((2), (2)):((1), (1)) maps 3 to
-- A(1) + A(1) = 2 (`Lay.compose_sum`), while A(B(3)) = A(2) = 10. The premise that fails is
-- `noCarry`: the terms 1 and 1 carry against A's first extent 2
example : (∀ m ∈ (Lay.flat [(2, 1), (2, 1)]).modes,
    composeDiv (Lay.flat [(2, 1), (2, 10)]).modes.dropLast m = true) := by decide
example : noCarry [2, 2] (List.zipWith (fun x m => x * m.2) (colex 3 [2, 2]) [(2, 1), (2, 1)]) =
    false := by decide
example : carryFree ((Lay.flat [(2, 1), (2, 10)]).modes.map Prod.fst)
    ((Lay.flat [(2, 1), (2, 1)]).modes.map fun m => (List.range m.1).map (· * m.2)) = false := by
  decide
example : ((Lay.flat [(2, 1), (2, 10)]).compose (Lay.flat [(2, 1), (2, 1)])).call
    (leaf 3 false) = (Lay.flat [(2, 1), (2, 10)]).call (leaf 1 false) +
      (Lay.flat [(2, 1), (2, 10)]).call (leaf 1 false) := by
  rw [(Lay.compose_sum _ _ (by decide) (by decide) (by decide) 3 false (by decide)
    (by decide)).2]; decide
example : ((Lay.flat [(2, 1), (2, 10)]).compose (Lay.flat [(2, 1), (2, 1)])).call
    (leaf 3 false) = 2 := by decide
example : (Lay.flat [(2, 1), (2, 10)]).call
    (leaf ((Lay.flat [(2, 1), (2, 1)]).call (leaf 3 false)) false) = 10 := by decide

-- the same with a one-to-one B: A = (6, 2):(1, 100) and B = (3, 2):(2, 3), whose offsets
-- 0, 2, 4, 3, 5, 7 are distinct and below A's size 12. B's modes meet `composeDiv`; at 5 the
-- terms 4 and 3 carry against A's extent 6, so the composite gives A(4) + A(3) = 7 while
-- A(B(5)) = A(7) = 101
example : (∀ m ∈ (Lay.flat [(3, 2), (2, 3)]).modes,
    composeDiv (Lay.flat [(6, 1), (2, 100)]).modes.dropLast m = true) := by decide
example : (List.range 6).map (fun v => (Lay.flat [(3, 2), (2, 3)]).call (leaf v false)) =
    [0, 2, 4, 3, 5, 7] := by decide
example : noCarry [6, 2] (List.zipWith (fun x m => x * m.2) (colex 5 [3, 2]) [(3, 2), (2, 3)]) =
    false := by decide
example : carryFree ((Lay.flat [(6, 1), (2, 100)]).modes.map Prod.fst)
    ((Lay.flat [(3, 2), (2, 3)]).modes.map fun m => (List.range m.1).map (· * m.2)) = false := by
  decide
example : ((Lay.flat [(6, 1), (2, 100)]).compose (Lay.flat [(3, 2), (2, 3)])).call
    (leaf 5 false) = 7 := by decide
example : (Lay.flat [(6, 1), (2, 100)]).call
    (leaf ((Lay.flat [(3, 2), (2, 3)]).call (leaf 5 false)) false) = 101 := by decide

-- blocked product: block (2):(2) and tiler (2):(1); the indices 1 and 2 both go to the
-- offset 2, since the code multiplies by the block's size 2 where its cosize is 3. The code and
-- its docstring agree when the block is compact (size = cosize); `Lay.blockedProduct_call`
-- states what the code computes
example : (Lay.blockedProduct (Lay.flat [(2, 2)]) (Lay.flat [(2, 1)])).call (leaf 1 false) = 2 := by
  decide
example : (Lay.blockedProduct (Lay.flat [(2, 2)]) (Lay.flat [(2, 1)])).call (leaf 2 false) = 2 := by
  decide
example : (Lay.flat [(2, 2)]).cosize = 3 := by decide

-- idx2crd: (2, 2):(3, 1) maps (1, 0) to 3, and idx2crd maps 3 to (1, 1). Its modes are
-- nested in neither order; `idx2crd_call` and `idx2crd_call_reverse` hold when they are
example : crd2idx (tup [leaf 1 false, leaf 0 false]) (tup [leaf 2 true, leaf 2 true])
    (tup [leaf 3 true, leaf 1 true]) = 3 := by decide
example : (idx2crd 3 (tup [leaf 2 true, leaf 2 true]) (tup [leaf 3 true, leaf 1 true])).leaves =
    [1, 1] := by decide

-- zipped divide: (5):(1) by the tile 2 has size 4, and no index reaches the element 4. The
-- size is kept when every tile extent divides its extent (`Lay.zippedDivide_size`)
example : (Lay.zippedDivide (Lay.flat [(5, 1)]) [2]).size = 4 := by decide
example : ∀ i, i < 4 → (Lay.zippedDivide (Lay.flat [(5, 1)]) [2]).call (leaf i false) ≠ 4 := by
  decide

-- the swizzle: `Swizzle(2, 0, 1)` has `bits > |shift|`, and applied twice to 6 it gives 7.
-- It is an involution when `bits ≤ |shift|` (`Swizzle.call_call`)
example : Swizzle.call ⟨2, 0, 1⟩ (Swizzle.call ⟨2, 0, 1⟩ 6) = 7 := by decide

-- bit layout, the twin of `placement_call` without bit-linearity: (2, 2):(1, 1), whose extents
-- and strides are powers of two, maps 1 and 2 to 1 and 3 to 2, not to 1 ^ 1 = 0, so it is not
-- linear over F2. Both modes reach the offset bit 0, so `is_bit_linear` refuses the layout, and
-- its placement maps 3 to 0
example : (Lay.flat [(2, 1), (2, 1)]).call (leaf 1 false) = 1 ∧
    (Lay.flat [(2, 1), (2, 1)]).call (leaf 2 false) = 1 := by decide
example : (Lay.flat [(2, 1), (2, 1)]).call (leaf 3 false) = 2 := by decide
example : isBitLinear [(2, 1), (2, 1)] = false := by decide
example : (placement [(2, 1), (2, 1)]).call 3 = 0 := by decide

-- two-level swizzle, the twin of `Swizzle.twoLevel_call` without disjoint inner bits:
-- `Swizzle(1, 0, 1)`, of period 2, on (2, 2):(1, 1), whose extents and strides are powers of
-- two. Both modes give their bit 0 to the inner map, with the image Swizzle(1) = 1, so
-- `_swizzle_inner_bits_disjoint` refuses the layout; at (1, 1) the two images cancel and the
-- two-level layout gives 0, while Swizzle(L(1, 1)) = Swizzle(2) = 3
example : (Swizzle.mk 1 0 1).disjoint [(2, 1), (2, 1)] 0 = false ∧
    (Swizzle.twoLevel ⟨1, 0, 1⟩ [(2, 1), (2, 1)]).call (tup [leaf 1 false, leaf 1 false]) = 0 ∧
    Swizzle.call ⟨1, 0, 1⟩ ((Lay.flat [(2, 1), (2, 1)]).call (tup [leaf 1 false, leaf 1 false])) =
      3 := by decide

-- the twin without the bound on the coordinate: (2, 2):(1, 2) passes both asserts for
-- `Swizzle(1, 0, 1)`, but at the tuple coordinate (2, 0), past the extent 2, mode 0 keeps
-- 2 >> 1 = 1 as its outer coordinate, of stride 2, and the two-level layout gives 2, below the
-- period, where Swizzle(L(2, 0)) = Swizzle(2) = 3
example : swizzleValid [(2, 1), (2, 2)] = true ∧ (Swizzle.mk 1 0 1).disjoint [(2, 1), (2, 2)] 0 ∧
    (Swizzle.twoLevel ⟨1, 0, 1⟩ [(2, 1), (2, 2)]).call (tup [leaf 2 false, leaf 0 false]) = 2 ∧
    Swizzle.call ⟨1, 0, 1⟩ ((Lay.flat [(2, 1), (2, 2)]).call (tup [leaf 2 false, leaf 0 false])) =
      3 := by decide

-- the inner map is not one-to-one with a zero shift: `Swizzle(1, 0, 0)` sends 1 to 0,
-- so its two-level layout on (2):(1) sends the indices 0 and 1 both to 0
example : (Swizzle.twoLevel ⟨1, 0, 0⟩ [(2, 1)]).call (leaf 0 false) = 0 ∧
    (Swizzle.twoLevel ⟨1, 0, 0⟩ [(2, 1)]).call (leaf 1 false) = 0 := by decide

-- coalesce drops extent-1 modes and merges contiguous ones
example : (Lay.flat [(2, 1), (1, 7), (3, 4)]).coalesce.modes = [(2, 1), (3, 4)] := by decide
example : (Lay.flat [(2, 1), (3, 2)]).coalesce.modes = [(6, 1)] := by decide

end MojoProofTest.LayoutLaws
