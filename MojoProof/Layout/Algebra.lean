import MojoProof.Layout.Basic

/-!
# The layout algebra and the swizzle

The layout functions of max/kernels/src/layout/layout.mojo at modular/modular bbc13a71 that build
a layout from a shape or from other layouts (row major, coalesce, composition, zipped divide,
blocked product, upcast) and the XOR swizzle of swizzle.mojo, transcribed over the model of
MojoProof/Layout/Basic.lean. Each docstring names the Mojo function and line it transcribes. The
layouts these functions return are given static leaves; no value of the model depends on a
leaf's static flag.
-/

namespace MojoProof.Layout

open Tup

/-- CuTe's `shape_div` as Mojo computes it on non-negative values: `a / b` when `b` divides `a`,
and 1 otherwise (`_shape_div`, layout.mojo:1501; `_comptime_shape_div`, layout.mojo:2094; and
`_runtime_shape_div`, layout.mojo:2199, whose result `-1` needs a negative argument). For a
divisor 0 the model gives `a / 0`, which is 0, and so does Mojo on the conformance test's
upcast of a stride-0 mode (`MojoProofTest.LayoutConformance`, case 22). -/
def shapeDiv (a b : Nat) : Nat := if b = 0 ∨ a % b = 0 then a / b else 1

/-- `row_major(shape)` (layout.mojo:1002) on a flat shape, as (extent, stride) pairs: the last
stride is 1 and each earlier stride is the product of the later extents (lines 1029-1048). -/
def rowMajor : List Nat → List (Nat × Nat)
  | [] => []
  | s :: ss => (s, ss.prod) :: rowMajor ss

/-- One step of `coalesce` (`_CoalesceReducerIdx`, layout.mojo:2316-2358) on the list of
(extent, stride) pairs kept so far and the next flat mode `m`: a mode of extent 1 is dropped; a
mode after a kept mode of extent 1 replaces it; a mode whose stride is the kept mode's extent
times its stride merges into it; any other mode is appended. -/
def coalesceStep (acc : List (Nat × Nat)) (m : Nat × Nat) : List (Nat × Nat) :=
  if m.1 = 1 then acc else
  match acc.getLast? with
  | some (ps, pd) =>
    if ps = 1 then acc.dropLast ++ [m]
    else if ps * pd = m.2 then acc.dropLast ++ [(ps * m.1, pd)]
    else acc ++ [m]
  | none => [m]

/-- `coalesce(layout)` (layout.mojo:2462, `CoalesceLayout` at line 2436): the flat layout of the
pairs that `coalesceStep` keeps over the layout's flattened modes, from the start pair (1, 0)
(line 2380). Mojo computes it on static layouts only. -/
def Lay.coalesce (L : Lay) : Lay := Lay.flat (L.modes.foldl coalesceStep [(1, 0)])

/-- One pass of the loop of `_compose_leaf` (layout.mojo:1533-1545) over a mode `(cs, cd)` of the
outer layout. The state is the leaves emitted so far, the remaining extent and the remaining
stride of the inner leaf. When `cs` divided by the stride is not 1 and the extent is not 1, it
emits a leaf of extent `min(shape_div(cs, stride), extent)` and stride `stride * cd`, and divides
the extent by that; the stride becomes `shape_div(stride, cs)` either way. -/
def composeStep (cd : Nat × Nat) (st : List (Nat × Nat) × Nat × Nat) :
    List (Nat × Nat) × Nat × Nat :=
  let ns := shapeDiv cd.1 st.2.2
  let nd := shapeDiv st.2.2 cd.1
  if ns ≠ 1 ∧ st.2.1 ≠ 1 then
    (st.1 ++ [(min ns st.2.1, st.2.2 * cd.2)], shapeDiv st.2.1 (min ns st.2.1), nd)
  else (st.1, st.2.1, nd)

/-- `_compose_leaf` (layout.mojo:1509): the leaves into which the inner leaf of extent `s` and
stride `d` splits as it crosses the flat outer layout `A`. A stride 0 gives the single leaf
`(s, 0)` (lines 1524-1527); otherwise `composeStep` runs over every mode of `A` but the last,
and the last mode takes the remaining extent, with the remaining stride times its stride, when
that extent is not 1 or nothing was emitted (lines 1546-1551). Mojo rejects an empty `A`; the
model takes the last stride to be 0. -/
def composeLeaf (A : List (Nat × Nat)) (s d : Nat) : List (Nat × Nat) :=
  if d = 0 then [(s, 0)] else
  let r := A.dropLast.foldl (fun st cd => composeStep cd st) ([], s, d)
  if r.2.1 ≠ 1 ∨ r.1 = [] then r.1 ++ [(r.2.1, r.2.2 * ((A.getLast?.map Prod.snd).getD 0))]
  else r.1

/-- `composition(a, b)` (layout.mojo:1641, `ComposedLayout` at line 1618): the layout of `B`'s
rank whose mode `m` is the flat tuple of the leaves that `B`'s mode `m` splits into, leaf by
leaf, against `A`'s flattened modes (`_compose_mode`, layout.mojo:1556). Mojo requires both
layouts static and `B`'s cosize at most `A`'s size (lines 1664-1669); the model computes the
same leaves without these checks. -/
def Lay.compose (A B : Lay) : Lay :=
  let ms := List.zipWith (fun bs bd => ((leaves bs).zip (leaves bd)).flatMap
    (fun m => composeLeaf A.modes m.1 m.2)) B.shape B.stride
  ⟨ms.map (fun m => tup (m.map fun p => leaf p.1 true)),
   ms.map (fun m => tup (m.map fun p => leaf p.2 true))⟩

/-- `zipped_divide[tile](layout)` (layout.mojo:1407): the rank-2 layout whose first mode is the
tile, with the layout's strides, and whose second mode has extents `s // t` and strides `d * t`,
mode by mode (`_Divide` and `_Multiply`, lines 1427-1432 and the result at line 1457). The modes
of the layout are read as leaves; a tuple mode has value 0 here. -/
def Lay.zippedDivide (L : Lay) (t : List Nat) : Lay :=
  ⟨[tup (t.map (leaf · true)), tup (List.zipWith (fun s k => leaf (s.value / k) true) L.shape t)],
   [tup L.stride, tup (List.zipWith (fun d k => leaf (d.value * k) true) L.stride t)]⟩

/-- `blocked_product(block, tiler)` (layout.mojo:1954, `BlockedProductLayout` at line 1884):
mode `i` has shape `(block.shape[i], tiler.shape[i])` and stride
`(block.stride[i], size(block) * tiler.stride[i])`. The docstring (line 1911) says `block.cosize`;
the code multiplies by the block's size (`BlockShape.static_product` at line 1995, and
`block.shape_coord().product()` at line 2016 for runtime strides), and the model follows the
code. -/
def Lay.blockedProduct (B T : Lay) : Lay :=
  ⟨List.zipWith (fun bs ts => tup [bs, ts]) B.shape T.shape,
   List.zipWith (fun bd td => tup [bd, leaf (B.size * td.value) true]) B.stride T.stride⟩

/-- `upcast[factor](layout)` (layout.mojo:2218): mode by mode, the stride `shape_div(d, f)` and
the extent `shape_div(s, shape_div(f, d))` (lines 2263-2296). The modes are read as leaves, as
Mojo reads them with `static_value` (lines 2265-2266); a tuple mode has value 0 here. -/
def Lay.upcast (f : Nat) (L : Lay) : Lay :=
  ⟨List.zipWith (fun s d => leaf (shapeDiv s.value (shapeDiv f d.value)) true) L.shape L.stride,
   L.stride.map (fun d => leaf (shapeDiv d.value f) true)⟩

/-- Mojo's `Swizzle(bits, base, shift)` (swizzle.mojo:274 and its constructor at line 316). -/
structure Swizzle where
  /-- The swizzle `Swizzle(bits, base, shift)`. -/
  mk ::
  /-- The number of bits XORed. -/
  bits : Nat
  /-- The lowest bit position of the target bits. -/
  base : Nat
  /-- The distance from the source bits down to the target bits; negative shifts up. -/
  shift : Int

/-- `shiftr(a, s)` (swizzle.mojo:236): `a >> s` for a positive `s` and `a << -s` otherwise. -/
def shiftr (a : Nat) (s : Int) : Nat := if 0 < s then a >>> s.toNat else a <<< (-s).toNat

/-- The swizzle's source mask `yyy_mask` (swizzle.mojo:337):
`((1 << bits) - 1) << (base + max(shift, 0))`. -/
def Swizzle.mask (S : Swizzle) : Nat := (2 ^ S.bits - 1) <<< (S.base + S.shift.toNat)

/-- `Swizzle.__call__` (swizzle.mojo:369-381): `offset ^ shiftr(offset & yyy_mask, shift)`. The
constructor's check that `abs(shift) >= bits` (line 332) is skipped in Mojo's compile-time
interpreter; the model has no check. -/
def Swizzle.call (S : Swizzle) (x : Nat) : Nat := x ^^^ shiftr (x &&& S.mask) S.shift

end MojoProof.Layout
