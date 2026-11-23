/-!
# The layout model: shapes, strides and the coordinate map

A transcription of the typed layouts of the Mojo kernels library at modular/modular bbc13a71: the
coordinate trees of Mojo/stdlib/std/utils/coord.mojo and the layout struct, its coordinate map and
the layout algebra of max/kernels/src/layout/layout.mojo and swizzle.mojo. Each definition's
docstring names the Mojo function and line it transcribes. docs/proofs/layout-laws.md states the
laws, their preconditions and the transcription table; this module only defines.

Values are natural numbers: Mojo's documentation requires a layout's shapes and strides to be
non-negative (layout.mojo:345), and the coordinates and offsets of such a layout are then
non-negative too. The model computes at unbounded precision; Mojo computes offsets in its index
type, and the index-width law of docs/proofs/layout-laws.md relates the two.
Where Mojo rejects an input (a compile-time error or an abort), the model returns 0 or an empty
tree; each such case is named in the definition's docstring, and no law holds there.

Every definition here reduces in the kernel, so `decide` evaluates the model on concrete layouts.
-/

namespace MojoProof.Layout

/-- A node of a Mojo `Coord` tree (coord.mojo:186): a leaf `leaf v static` carries the value `v`,
statically known (`ComptimeInt[v]`, coord.mojo:97) when `static` is `true` and a runtime
`Scalar` otherwise; `tup ts` is a tuple of subtrees. Shapes, strides and coordinates are all
trees of this kind. -/
inductive Tup where
  /-- A leaf of value `v`, static when `static` is `true`. -/
  | leaf (v : Nat) (static : Bool)
  /-- A tuple of the subtrees `ts`. -/
  | tup (ts : List Tup)
  deriving Repr, Inhabited

namespace Tup

/-- Mojo's `__len__` of a coordinate: 1 for a leaf (coord.mojo:125-131) and the number of
children for a tuple (coord.mojo:307). -/
def len : Tup → Nat
  | leaf _ _ => 1
  | tup ts => ts.length

/-- Mojo's `value()` of a coordinate: a leaf's value. A tuple has no value (Mojo rejects the call
at compile time); the model gives 0. -/
def value : Tup → Nat
  | leaf v _ => v
  | tup _ => 0

/-- A coordinate's elements as `crd2idx` indexes them (`crd.tuple()[i]`): a tuple's children; a
leaf is its own single element. -/
def elems : Tup → List Tup
  | leaf v b => [leaf v b]
  | tup ts => ts

/-- The scalar `crd2idx` splits when the coordinate has length at most 1 (coord.mojo:916-921):
a leaf's value, 0 for the empty tuple, and the first child's value for a one-element tuple. -/
def scalar : Tup → Nat
  | leaf v _ => v
  | tup [] => 0
  | tup (t :: _) => t.value

mutual
/-- The leaves of a tree from left to right: Mojo's `flatten` (coord.mojo:524). -/
def leaves : Tup → List Nat
  | leaf v _ => [v]
  | tup ts => leavesL ts
/-- The leaves of a list of trees, concatenated: `Tup.leaves` of `tup ts`. -/
def leavesL : List Tup → List Nat
  | [] => []
  | t :: ts => leaves t ++ leavesL ts
end

/-- Mojo's `product()` of a coordinate (coord.mojo:368): the product of its leaves, 1 for the
empty tuple. For a shape, the number of coordinates it admits. -/
def size (t : Tup) : Nat := t.leaves.prod

mutual
/-- `congruent s d` is `true` when the trees `s` and `d` have the same structure: both leaves, or
tuples of equal length whose children are pairwise `congruent`. A layout's shape and stride are
congruent in every layout Mojo builds. -/
def congruent : Tup → Tup → Bool
  | leaf _ _, leaf _ _ => true
  | tup ss, tup ds => congruentL ss ds
  | _, _ => false
/-- `Tup.congruent` for two lists of trees: equal lengths and pairwise congruent. -/
def congruentL : List Tup → List Tup → Bool
  | [], [] => true
  | s :: ss, d :: ds => congruent s d && congruentL ss ds
  | _, _ => false
end

end Tup

open Tup

/-- The colexicographic digits of `i` against the extents `ss`, the first extent fastest:
`i % s₀`, `(i / s₀) % s₁`, and so on. This is the coordinate that `crd2idx` gives a scalar when
`i` is below the product of the extents. -/
def colex (i : Nat) : List Nat → List Nat
  | [] => []
  | s :: ss => i % s :: colex (i / s) ss

mutual
/-- `crd2idx(crd, shape, stride)` (coord.mojo:856), the offset of coordinate `c` in the layout
with shape `s` and stride `d`:

* when `s` and `d` are tuples of equal length and `c` has more than one element: the sum of the
  elements' offsets in the matching modes if `c` has as many elements as `s` (coord.mojo:899-904),
  and otherwise the dot product of `c`'s element values with `d`'s leaves (`_crd2idx_flat`,
  coord.mojo:795, called at line 908, on the leaves that `c` reaches);
* when they are tuples of equal length and `c` has at most one element: its scalar split across
  the modes by `divmod` with each mode's size, the first mode fastest, the last mode taking the
  remaining quotient (coord.mojo:914-935);
* otherwise the product of `c`'s value with `d`'s value (coord.mojo:936-953).

Mojo's abort for a tuple coordinate against a leaf shape and its compile-time rejection of tuples
of unequal lengths give 0 here; its static bounds asserts are not modelled (the laws state the
bound as a premise instead). -/
def crd2idx (c : Tup) (s d : Tup) : Nat :=
  match s, d with
  | tup ss, tup ds =>
    if ss.length = ds.length then
      if 1 < c.len then
        if c.len = ss.length then zipIdx c.elems ss ds
        else (List.zipWith (· * ·) (c.elems.map value) (leavesL ds)).sum
      else splitIdx c.scalar ss ds
    else 0
  | _, _ => if 1 < c.len then 0 else c.value * d.value
termination_by structural s
/-- The hierarchical case of `crd2idx` (coord.mojo:899-904): the sum of `crd2idx` of each
coordinate element in the matching shape and stride mode. -/
def zipIdx : List Tup → List Tup → List Tup → Nat
  | c :: cs, s :: ss, d :: ds => crd2idx c s d + zipIdx cs ss ds
  | _, _, _ => 0
termination_by structural _ ss _ => ss
/-- The scalar case of `crd2idx` (coord.mojo:925-935): the scalar `v` split across the modes
`ss` with strides `ds`. Each mode but the last takes `v % size` as a runtime scalar and passes
`v / size` on; the last mode takes what is left. -/
def splitIdx (v : Nat) : List Tup → List Tup → Nat
  | [], _ => 0
  | [s], d :: _ => crd2idx (leaf v false) s d
  | s :: ss, d :: ds => crd2idx (leaf (v % s.size) false) s d + splitIdx (v / s.size) ss ds
  | _, [] => 0
termination_by structural ss _ => ss
end

mutual
/-- `idx2crd(idx, shape, stride)` (coord.mojo:958 and 1067): the coordinate tree of `i`, of the
shape's structure, whose leaf for extent `s` and stride `d` is `(i / d) % s`
(`_linear_idx_to_coord`, coord.mojo:1966). A static extent 1 gives the static coordinate 0
(coord.mojo:1037-1042). Mojo's unsigned division by a zero stride is not modelled;
the model's `i / 0` is 0. A tuple extent against a leaf stride gives the empty tuple. -/
def idx2crd (i : Nat) : Tup → Tup → Tup
  | tup ss, tup ds => tup (idx2crdL i ss ds)
  | leaf s b, d => if b && s == 1 then leaf 0 true else leaf (i / d.value % s) false
  | tup _, leaf _ _ => tup []
/-- `idx2crd` mode by mode over the lists of shape and stride modes. -/
def idx2crdL (i : Nat) : List Tup → List Tup → List Tup
  | s :: ss, d :: ds => idx2crd i s d :: idx2crdL i ss ds
  | _, _ => []
end

/-- A layout: Mojo's `Layout[shape_types, stride_types]` (layout.mojo:329), whose shape and stride
are tuples of modes (`Coord[*shape_types]`). Named `Lay` so that it is not confused with the LLVM
data layout `MojoProof.Sem.Layout`. -/
structure Lay where
  /-- The layout of the shape modes `shape` and the stride modes `stride`. -/
  mk ::
  /-- The shape's modes. -/
  shape : List Tup
  /-- The stride's modes. -/
  stride : List Tup
  deriving Repr

namespace Lay

/-- The layout's rank: the number of shape modes (`Self.rank`). -/
def rank (L : Lay) : Nat := L.shape.length

/-- `Layout.__call__` (layout.mojo:484), the offset of coordinate `c`: a tuple with more
elements than the rank is a flat coordinate, dotted with the stride's leaves (lines 521-533);
every other coordinate goes to `crd2idx` with the shape and stride (lines 513-518 and 535-538). -/
def call (L : Lay) (c : Tup) : Nat :=
  match c with
  | .tup cs =>
    if L.rank < cs.length then (List.zipWith (· * ·) (leavesL cs) (leavesL L.stride)).sum
    else crd2idx c (.tup L.shape) (.tup L.stride)
  | _ => crd2idx c (.tup L.shape) (.tup L.stride)

/-- `Layout.size` and `Layout.product` (layout.mojo:616-635): the product of the shape's leaves,
the number of coordinates. -/
def size (L : Lay) : Nat := (tup L.shape).size

/-- `Layout.cosize` (layout.mojo:639-653): the offset of the last scalar coordinate, plus one.
For a layout of size 0 Mojo evaluates the offset of -1; the model evaluates the offset of 0. -/
def cosize (L : Lay) : Nat := L.call (leaf (L.size - 1) false) + 1

/-- `Layout.reverse` (layout.mojo:656-667), which `Layout.transpose` (layout.mojo:670) returns:
the shape's and the stride's modes in reverse order. -/
def reverse (L : Lay) : Lay := ⟨L.shape.reverse, L.stride.reverse⟩

/-- The flat static layout with the given (extent, stride) modes, each mode a static leaf. The
layouts `coalesce` and `composition` return are of this kind. -/
def flat (ps : List (Nat × Nat)) : Lay :=
  ⟨ps.map (fun p => leaf p.1 true), ps.map (fun p => leaf p.2 true)⟩

/-- The layout's flattened modes: its shape's and stride's leaves, paired in order (the
`_Flattened` shape and stride type lists of layout.mojo). -/
def modes (L : Lay) : List (Nat × Nat) := (leavesL L.shape).zip (leavesL L.stride)

end Lay

end MojoProof.Layout
