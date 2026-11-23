import MojoProof.Layout.Laws
import MojoProof.Layout.Swizzle

/-!
# Instances of the layout laws, and the counterexamples

One concrete instance of each law of docs/proofs/layout-laws.md, each by the general theorem
(its premises closed by `decide`, the remaining arithmetic by `decide`), on the layouts `nested`
(shape (2, (2, 3)), stride (1, (2, 4))), `colMajor23` ((2, 3):(1, 2)) and `rowMajor23`
((2, 3):(3, 1)). Then the counterexamples of section 3 of that document, each by `decide` on the
model: composition, blocked product, idx2crd, zipped divide and the swizzle. Each of these covers
one example; the laws they instantiate cover all shapes that meet their premises.
-/

namespace MojoProofTest.LayoutLaws

open MojoProof.Layout MojoProof.Layout.Tup

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

-- upcast of a stride-0 mode: `shape_div(2, 0)` is 0 in the model, so the extent becomes 0
example : (Lay.upcast 2 (Lay.flat [(4, 0)])).modes = [(0, 0)] := by decide

-- `Lay.call_flat_ofNat` and `Lay.call_flat_toNat`: at 8 bits, the offset 300 of (100, 2):(3, 0)
-- wraps to 44, and the offset 5 of (1, 2) in (2, 3):(1, 2) is exact
example : (List.zipWith (fun x d => BitVec.ofNat 8 x * BitVec.ofNat 8 d) [100, 2]
    ([(101, 3), (3, 0)].map Prod.snd)).sum = 44#8 := by
  rw [Lay.call_flat_ofNat 8 [(101, 3), (3, 0)] [100, 2] false rfl]; decide
example : (List.zipWith (fun x d => BitVec.ofNat 8 x * BitVec.ofNat 8 d) [1, 2]
    (colMajor23.map Prod.snd)).sum.toNat = 5 := by
  rw [Lay.call_flat_toNat 8 colMajor23 [1, 2] false rfl (by decide)]; decide

/-! ## Composition -/

-- `Lay.compose_call`: `nested` composed with (6):(2). The stride 2 is a multiple of the first
-- extent 2, which leaves the stride 1; the second extent 2 divides the extent 6, which leaves
-- the extent 3 for the last mode. The composite (2, 3):(2, 4) has the size 6 and maps 5 to
-- nested(10) = 2 + 8
example : (nested.compose (Lay.flat [(6, 2)])).size = 6 :=
  (Lay.compose_call nested (by decide) 6 2 (by decide) (by decide) 5 false (by decide)
    (by decide)).1
example : (nested.compose (Lay.flat [(6, 2)])).call (leaf 5 false) = 10 := by
  rw [(Lay.compose_call nested (by decide) 6 2 (by decide) (by decide) 5 false (by decide)
    (by decide)).2]; decide

/-! ## The swizzle -/

-- `Swizzle.call_call`: `Swizzle(2, 0, 2)` meets `bits ≤ |shift|`, so it undoes itself at 13
example : Swizzle.call ⟨2, 0, 2⟩ (Swizzle.call ⟨2, 0, 2⟩ 13) = 13 :=
  Swizzle.call_call ⟨2, 0, 2⟩ (by decide) 13

-- `Swizzle.call_xor`, with a negative shift
example : Swizzle.call ⟨2, 1, -3⟩ (6 ^^^ 3) =
    Swizzle.call ⟨2, 1, -3⟩ 6 ^^^ Swizzle.call ⟨2, 1, -3⟩ 3 :=
  Swizzle.call_xor ⟨2, 1, -3⟩ 6 3

/-! ## The counterexamples -/

-- composition (filed as modular/modular #7738): A = (6, 2):(1, 6) and B = (3):(4) give (3):(6),
-- so B's index 1 goes to 6, while A(B(1)) = A(4) = 4. B's stride 4 neither divides A's first
-- extent 6 nor is a multiple of it, so B fails `composeDiv`, the premise of `Lay.compose_call`
example : composeDiv [(6, 1)] (3, 4) = false := by decide
example : composeLeaf [(6, 1), (2, 6)] 3 4 = [(3, 6)] := by decide
example : ((Lay.flat [(6, 1), (2, 6)]).compose (Lay.flat [(3, 4)])).call (leaf 1 false) = 6 := by
  decide
example : (Lay.flat [(6, 1), (2, 6)]).call
    (leaf ((Lay.flat [(3, 4)]).call (leaf 1 false)) false) = 4 := by decide

-- composition with two modes: A = (2, 2):(1, 10) and B = (2, 2):(1, 1), of cosize 3 within A's
-- size 4. Each mode of B meets `composeDiv` and composes to (2):(1), so the composite
-- ((2), (2)):((1), (1)) maps 3 to 1 + 1 = 2, while A(B(3)) = A(2) = 10: the composite adds A's
-- offsets of B's modes, and A does not add over them. `Lay.compose_call` states one mode
example : composeDiv [(2, 1)] (2, 1) = true := by decide
example : ((Lay.flat [(2, 1), (2, 10)]).compose (Lay.flat [(2, 1), (2, 1)])).call
    (leaf 3 false) = 2 := by decide
example : (Lay.flat [(2, 1), (2, 10)]).call
    (leaf ((Lay.flat [(2, 1), (2, 1)]).call (leaf 3 false)) false) = 10 := by decide

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

-- coalesce drops extent-1 modes and merges contiguous ones
example : (Lay.flat [(2, 1), (1, 7), (3, 4)]).coalesce.modes = [(2, 1), (3, 4)] := by decide
example : (Lay.flat [(2, 1), (3, 2)]).coalesce.modes = [(6, 1)] := by decide

end MojoProofTest.LayoutLaws
