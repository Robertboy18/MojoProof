# The spec layer: specifications are mathematics

Lean: GPUProof/Spec/Basic.lean (steps 1 to 8 below) and GPUProof/Spec/Linear.lean (steps 9 to 11),
with the equality up to NaN payloads in GPUProof/NaN.lean, tested in
MojoProofTest/GPUProof/Spec.lean. Still plan: the importer (step 12) and the tests marked "plan"
below; the kernels that meet `Spec.matVec matVecGrade` are in MojoProof/Tile/MatVec.lean (step 9).
This document fixes the definitions of the core's spec layer, the order in which they enter Lean,
the first instance of each, and which FloatLib, TorchLean and Mathlib definitions each one reuses.
Where the Lean departs from the design's sketch, the departure is listed with its reason (last
section). `Spec` cannot enter Lean alone: its `rule` field is a `FloatRule`, whose cases read
encodings, formats and grades, so the first unit that builds with an instance is steps 1 to 8.

**Scope.** Every definition below is stated for every size type `Sz` and every spec `Sp : Spec Sz`;
nothing fixes a machine, a format or a size. The instances are about one spec at a time
(`GPUProof.Spec.matVec`, `GPUProof.Spec.vecMat`, `GPUProof.Spec.sumReal`,
`GPUProof.Spec.sumInt`), at every size and grade, and one encoding family (FloatLib's binary
interchange formats, entry by entry). The importer is about one TorchLean operation
(`Tensor.contract … .matVec`), at every shape.

**Where it lives.** The spec layer is core: modules `GPUProof.Spec.*`, importing only `Mathlib.*`,
`FloatLib.*` and `GPUProof.*`, as `MojoProofTest/GPUProof/Imports.lean` requires of every core
module. The TorchLean importer imports TorchLean, so it cannot be a module of `lean_lib GPUProof`:
that test refuses any `TorchLean.*` module in the core's import closure. It goes into a library of
its own (`GPUProofImport`, below).

## What is reused

* `DType.Val`: `ℝ`, `ℤ` and `Bool` (Mathlib, Lean).
* `NumFormat`, its phase 0 form: FloatLib's `FloatFormat`
  (`FloatLib.Floats.Formats.BinaryInterchange`).
* `safeMax`: FloatLib's `Model.posMaxFinite` (Model/Carrier.lean) and `Model.toReal`
  (Model/RealSemantics.lean); its range lemma is FloatLib's
  `isFinite_roundDyadic_of_isIEEE_of_abs_toReal_le_posMaxFinite` (Arithmetic/Finiteness.lean).
* `Approx`: FloatLib's `Model.isFinite`, `Model.toReal` and `Model.toReal?`.
* `Grade`: new. FloatLib's `MixedError` (Numerics/MixedError/Basic.lean) and MojoProof's
  `MojoProof.Sem.Est` become instances of it, not copies.
* `ScalarEnc.ieee`: FloatLib's `Model.toReal?` as its decoder (`none` at a NaN and an infinity)
  and `Model.isNaN` as its NaN words, with FloatLib's `Model.toDyadic?_eq_none_of_isNaN` for the
  law that a NaN decodes to `none`. Its `nanEq` is `GPUProof.UpToNaN Model.isNaN`, and so is
  MojoProof's `MojoProof.Sem.NaNEq` (MojoProof/Sem/FloatRel.lean), by definition.
* `Spec.matVec` and `Spec.vecMat`: Mathlib's `Matrix.mulVec`, `Matrix.vecMul` and `Matrix.of`.
* `Spec.sumReal` and `Spec.sumInt`: Mathlib's `Finset.sum` over `Finset.univ`.
* The matVec importer: TorchLean's `Tensor.contract … .matVec` at `α := ℝ` as `denote`
  (Tensor/Contract.lean); `Tensor.toVecₗᵢ`, `TorchLean.Matmul.idxMN` and `Tensor.getScalar` for
  `readIn` and `readOut`; `getScalar_contract_matVec_eq_sum` and `TorchLean.Matmul.toVec_idxMN`
  for `eq`.

FloatLib also has generic format classes (`EncodedFormat` with `Code` and `Scalar`,
`FormatSemantics` with `denote : Code → NumericalValue Scalar`, and the structure
`NumericalSystem`). `ScalarEnc` is the same shape (a word type and a meaning of every word). When
FloatLib releases its format sum `NumFormat` through its intake, `ScalarEnc.ofSystem` reads any
`NumericalSystem` whose scalars are reals, and the phase 0 `NumFormat` below is replaced by
FloatLib's in one change. Nothing of FloatLib is copied: FloatLib v4.1.0 has no `safeMax`, no
grade, no NaN equivalence on `Model` (`GPUProof.UpToNaN` is new) and no format sum, so those are
new here.

## The definitions, in the order they enter Lean

Each step builds with its instance before the next starts. Module `GPUProof.Spec.Basic` holds
steps 1 to 8 (with `UpToNaN` of step 6 in `GPUProof.NaN`, which imports nothing),
`GPUProof.Spec.Linear` steps 9 to 11, and `GPUProofImport.TorchLean` will hold step 12. All names
below are in the namespace `GPUProof`.

1. **`DType`** (`real | int | bool`), **`DType.Val`** (`ℝ`, `ℤ`, `Bool`) and **`Ents ι d`**
   `:= (i : ι) → (d i).Val`. Instance: the entries of `Spec.matVec` at `(m, n)`, all `real`.
2. **`NumFormat`**, the phase 0 form: `ieee (fmt : FloatFormat) | int (bits : Nat) | bool`.
   Instance: `ieee .binary32`, `int 32`.
3. **`Grade`** `{ err mag : ℝ }` with its order (fieldwise `≤`, the order of `(err, mag)` in the
   product). Plan: the grade of `0` error and magnitude `|a|` of an exact input `a`.
4. **`NumFormat.safeMax`**: at `ieee fmt`, `(Model.posMaxFinite fmt).toReal`; at `int bits`,
   `2 ^ (bits - 1) - 1`; at `bool`, `1`. The range lemma **`Approx.finite_of_le`**, at IEEE
   formats: under `Approx`'s premise `g.mag ≤ safeMax`, a dyadic of magnitude at most `g.mag`
   rounds to a finite word, from FloatLib's
   `isFinite_roundDyadic_of_isIEEE_of_abs_toReal_le_posMaxFinite` (a rounding of a dyadic of
   magnitude at most `safeMax` is finite). Binary32's `safeMax` is `(2 - 2⁻²³) · 2¹²⁷` and
   bfloat16's `255 · 2¹²⁰`, each by evaluation of the word's rational value (tests
   `overflow_edge`, `copy_meets_bfloat16`).
5. **`Approx d g fmt v a`**, for an entry type `d`, on a decoded value `v : Option d.Val` (the
   decoder's output, `none` at a NaN or an infinity): `g.mag ≤ fmt.safeMax → d.Near g v a`, where
   **`DType.Near`** at `real` is `∃ r, v = some r ∧ |r - a| ≤ g.err`, and at `int` and `bool` is
   `v = some a`. The design's form on words, for `w : Model fmt`, is the corollary
   **`Approx.model`** at `v = w.toReal?`: `g.mag ≤ safeMax → w.isFinite = true ∧
   |w.toReal - a| ≤ g.err`. Instances: the tests `nan_approx` and `overflow_edge` (below).
6. **`ScalarEnc d`**, one entry's storage: `Word`, `decode : Word → Option d.Val`,
   `isNaN : Word → Bool` (its NaN words), `fmt : NumFormat`, and the law `decode_isNaN` (a NaN
   decodes to `none`). Its equality up to NaN payloads is defined, not a field:
   **`ScalarEnc.nanEq e`** `:= UpToNaN e.isNaN`, where **`UpToNaN nan x y`** (GPUProof/NaN.lean)
   is `x = y ∨ (nan x = true ∧ nan y = true)`, an equivalence (`UpToNaN.equivalence`), and
   related words decode alike (`ScalarEnc.decode_eq`). **`Encoding ι d`**, one side of a spec at
   one size: its word positions `Pos`, the words `Word p` at each position,
   `decode : ((p : Pos) → Word p) → (i : ι) → Option (d i).Val`, the NaN words `isNaN p` at each
   position and `fmt : ι → NumFormat`, with two laws that tie the NaN words to the decoder: words
   equal up to NaN payloads at every position decode alike (`decode_eq`: the decoder reads no
   payload), and a NaN at a position leaves some entry with no value, whatever the other
   positions hold (`decode_isNaN`). Its words are `Encoding.Words e := (p : e.Pos) → e.Word p`,
   and its equality up to NaN payloads is defined once, **`Encoding.nanEq e W W'`**
   `:= ∀ p, UpToNaN (e.isNaN p) (W p) (W' p)`, an equivalence (the theorem
   `Encoding.nanEq_equiv`). `Encoding.ofScalars (e : (i : ι) → ScalarEnc (d i))` is the
   entrywise case, a position per entry, with `Word i := (e i).Word` and
   `isNaN i := (e i).isNaN`; it proves both laws from its scalars'.
   **`Encodings In Out dIn dOut σ`** pairs an input and an output encoding at size `σ`.
   Instances: `ScalarEnc.ieee fmt` (words `Model fmt`, decoder `Model.toReal?`, NaNs
   `Model.isNaN`), `ScalarEnc.int bits` (words `BitVec bits`, decoder `BitVec.toInt`, no NaN),
   `ScalarEnc.bool` (no NaN), and `ScalarEnc.std fmt bits`, which stores reals in `fmt`, integers
   in `bits` bits and booleans as `Bool`.
7. **`FloatRule`** with its three cases `bitwise w hw`, `exact` and `graded g mono`, and
   **`FloatRule.Holds`**, what a rule says of input words `W` and output words `W'` at an encoding:
   * `bitwise E₀ w hw`, at the encodings `E₀ σ` it names and nowhere else: `W'` equals `w σ W` up
     to NaN payloads; `hw : DecodesAs Dom f E₀ w` says that `w` decodes as `f` wherever the
     inputs decode into `Dom`;
   * `exact`: for inputs `W` that decode to `A` with `Dom σ A`, and for which every `f σ A o` is
     the decoding of some output word, every output decodes to `f σ A o`;
   * `graded`: for exact inputs `A` with `Dom σ A` and grades `G` with
     `Approx (dIn σ i) (G i) (E.inp.fmt i) (E.inp.decode W i) (A i)` at every input `i`,
     `Approx (dOut σ o) (g σ E A G o) (E.out.fmt o) (E.out.decode W' o) (f σ A o)` at every
     output `o`.

   So, from the rule at `E₀ σ` and inputs `W` that decode to `A` with `Dom σ A`, the outputs are
   `w σ W` itself (**`FloatRule.Holds.bitwise_eq`**: every output of `w σ W` has a value, so by
   `Encoding.decode_isNaN` none of its words is a NaN), and every output decodes to `f σ A o`
   (**`FloatRule.Holds.bitwise`**, by `Encoding.decode_eq` and `hw`). Instances: `exact` on the
   identity spec at every size (a copy kernel's rule), and `bitwise` on entrywise negation in
   every binary interchange format, with FloatLib's `Model.neg` (tests `neg_meets`,
   `neg_decode`).
8. **`Spec Sz`**, with the design's fields (`In`, `Out`, `fin`, `dIn`, `dOut`, `Dom`, `f`, `rule`),
   **`Spec.Encs Sp σ`** (the encodings of `Sp` at `σ`), **`MeetsAt Sp k E`** (for every size `σ`,
   input words `W` and output words `W' ∈ k σ (E σ) W`, `Sp.rule.Holds σ (E σ) W W'`),
   **`Meets Sp k`** (`MeetsAt Sp k E` for every family of encodings `E`),
   **`Encodings.uniform Sp u`** (every entry of type `d` in the scalar encoding `u d`) and
   **`Meets.uniform`**, a one-line corollary: `h (Encodings.uniform Sp u)`. Instance: the copy
   spec at every size, and a copy behavior that meets it (tests `copy_meets`,
   `copy_meets_binary32`, `copy_meets_bfloat16`).
9. **`Spec.matVec g mono`**, at sizes `(m, n) : ℕ × ℕ`: inputs `(Fin m × Fin n) ⊕ Fin n`,
   outputs `Fin m`, every entry `real`, `Dom` everything (only `+` and `·`, so no junk value of
   Mathlib's arises), and `f (m, n) X i = Matrix.mulVec (Matrix.of fun i k => X (.inl (i, k)))
   (fun k => X (.inr k)) i`, with rule `graded g`. It is `Spec.ofReal` at that function:
   **`Spec.ofReal In Out f g mono`** is the spec of a real function `f`, every entry `real`, meant
   everywhere, with rule `graded g`, for grade functions `g : RealGrades In Out`. The test
   `matVec_f`: the function is `∑ k : Fin n, A i k * x k`, by `rfl`.
   **`laneGrade fmt W d L n a x ga gx`** (GPUProof/Spec/Linear.lean), the grade of a dot product
   of length `n` rounded to `fmt`, split over `W` lanes of at most `L` terms each whose sums are
   added along a tree of depth `d`: error `((1 + u) ^ (L + d) − 1) S + W (1 + u) ^ d (2 + u) η
   ((1 + u) ^ L − 1) / u + P`, with `S = Σₖ (|aₖ| + eₐₖ)(|xₖ| + eₓₖ)` and the propagated error
   `P = Σₖ (|aₖ| eₓₖ + |xₖ| eₐₖ + eₐₖ eₓₖ)`. **`dotGrade fmt n a x ga gx`** is its case of one
   lane of `n` terms and depth `0`, by definition: error
   `γₙ S + (2 + u) η γₙ / u + P`,
   with `γₙ = (1 + u)ⁿ − 1`, the output format's unit roundoff `u` and underflow allowance `η`
   (`NumFormat.roundoff`, `NumFormat.underflow`: FloatLib's `Model.unitRoundoffAt fmt` and
   `Model.underflowErrorAt fmt`, `0` at an integer or Boolean format), and the inputs' grade
   errors taken at least `0` (`Grade.pos`: a negative error would make `|a| + e` shrink, and the
   grade not monotone); magnitude bound the larger of the first sum plus the error and every
   input grade's magnitude bound (**`laneGrade_mag`**, so `dotGrade`'s too): an input whose
   grade's magnitude bound exceeds the largest finite value may be a NaN, which the loop carries
   to its result, so a smaller bound would claim a finite result that the loop does not give.
   **`laneGrade_mono`**, **`dotGrade_mono`**: they grow with the inputs' grades, for every
   format, counts, length and exact entries. **`laneVecGrade W d L`** is `laneGrade` at row `i`,
   length `n`, `L n` terms per lane, output `i`'s format, with **`laneVecGrade_mono`**, and
   **`matVecGrade`** is its case `laneVecGrade 1 0 id` (`dotGrade` at row `i`), by definition,
   with **`matVecGrade_mono`**; the
   test `matVecDot` is `Spec.matVec matVecGrade matVecGrade_mono`, and `dotGrade_one_zero` checks
   that at `n = 1`, exact entries `0` and grades `0`, the error is `(2 + u) η > 0`.
   The sequential loop meets the grade: `MojoProof.Sem.dotLoop_approx` proves that the word of
   the contracted loop `MojoProof.Sem.dotLoop` from `+0` is `Approx` at `dotGrade` of the exact
   dot product, for every IEEE format, length, input grade, `contract` flag and oracle, when each
   input word is `Approx` at its grade of its exact entry (finite and within the grade's error when
   the grade's magnitude bound is at most the largest finite value, `GPUProof.Approx.model`);
   `MojoProof.Sem.dotGrade_ieee`
   shows that `dotGrade`'s error is the loop's own bound `MojoProof.Sem.dotLoopBound` at the
   first sum (with `γₙ`, since the loop's first addition, to `+0`, is exact) plus the second sum
   (docs/proofs/dot.md, statements 12-14). Lanes meet `laneGrade`:
   `MojoProof.Sem.treeDot_approx` proves the same of `W` such loops added along any tree over the
   lanes (FloatLib's `Numerics.ReductionTree`) of depth `d`, each of at most `L` pairs, for every
   IEEE format, flag, oracle sequences, `W`, `L`, length, tree and input grade, and
   `dotLoop_approx` is its case of one lane and one leaf (docs/proofs/dot.md, statements 15-16).
   Kernels meet the grade. `MojoProof.Tile.Meets`, which `MojoProof.Tile.mat_refines` gives at
   every cell of every kernel of `mojo_kernel`'s `mat` clause, says that the cell's word is
   `Approx` at `dotGrade` of every exact row and column at which the cell's inputs are `Approx`
   (instances: MojoProofTest/TileNaive.lean at the naive kernel's corpus launch,
   MojoProofTest/TileGrade.lean at sizes 3 × 4 and 5 × 7 and a grade one ulp tighter refused).
   A matrix product whose second matrix has one row is a matrix-vector product, so those kernels
   meet `Spec.matVec matVecGrade` (MojoProof/Tile/MatVec.lean):
   * `MojoProof.Tile.rowLoops_meetsAt`: for every IEEE format `fmt`, width `bits` and flag `c`,
     `MeetsAt (Spec.matVec matVecGrade matVecGrade_mono) (rowLoops fmt bits c)
     (matVecEnc fmt bits)`. `matVecEnc fmt bits` is `Encodings.uniform` at
     `ScalarEnc.std fmt bits`, by definition, and the same encoding at every grade, by
     unfolding (test `MojoProofTest.TileMatVec.enc_grades`), and
     `rowLoops fmt bits c` are the behaviors whose output `i`, at that encoding, is
     `MojoProof.Sem.dotLoop c` from `+0` at some oracle sequence over row `i` and the vector
     (none at another encoding, so the claim is `MeetsAt` at that family, not `Meets`). The rule
     unfolded is `MojoProof.Tile.holds_of`; the step is `MojoProof.Sem.dotLoop_approx`.
   * `MojoProof.Tile.meets_holds`: words that meet the product at the cells `(i, 0)` (`Meets`)
     meet the rule (`FloatRule.Holds`) at the inputs read from the matrices
     (`MojoProof.Tile.matIn`), and `MojoProof.Tile.mat_holds` gives that for every kernel of the
     `mat` clause whose second matrix has one row and whose launch covers the rows and column 0
     (instance: `MojoProofTest.TileNaive.naive_holds`, the naive matmul kernel with one column).
   * Tests (MojoProofTest/TileMatVec.lean): the product by rows at sizes 3 × 4 and 5 × 7, and the
     spec graded one ulp tighter, not met by `rowLoops` unfused (`rowLoops_mutant`).
   * `MojoProof.Tile.groupDot_holds`: for every IEEE format, width, number of rounds `k`, flag,
     size, oracle sequences and input words, the lane group's dot product `MojoProof.Sem.groupDot
     k` per row (`2 ^ k` loops over the pairs strided by `2 ^ k`, then `k` butterfly rounds;
     `MojoProof.Sem.warpDot` at `k = 5`) meets the rule of
     `Spec.matVec (laneVecGrade (2 ^ k) k fun n => ⌈n / 2 ^ k⌉)`, by `holds_of` and
     `MojoProof.Tile.groupDot_approx` (docs/proofs/dot.md, statements 15-16; tests
     MojoProofTest/TileLanes.lean at 3 lanes and length 7, 4 lanes and length 10, and the grade at
     depth 0 refused).
   `Spec.vecMat vecMatGrade` is the case of one row of the first matrix, with the vector-matrix
   product's matrix transposed into the second; it is not stated yet. No matrix-product spec
   enters: a matrix product is met through these two as cases.
   Without the underflow allowance no kernel that rounds meets the grade: at `n = 1` a product
   `a x` below the normal range is rounded with an absolute error of up to half the spacing of
   the subnormals, which `γ₁ |a x|` does not bound when `|a x|` is small. An instance is
   MojoProofTest/DotGrade.lean `mutant_one`: in binary32, `3 · 2⁻¹⁴⁹ · 1/2` is a tie between
   subnormals, rounded to `2 · 2⁻¹⁴⁹`, an error of `η = 2⁻¹⁵⁰`, and the grade with `2⁻¹⁴⁹` (one
   subnormal spacing) less error, which leaves `4 u η` of it, is not met. The sequential loop's
   bounds in MojoProof (`MojoProof.Sem.dotLoopBound`, and `MojoProof.Sem.dotBound` with one more
   power of `1 + u` on the sum) have the allowance `(2 + u) η ((1 + u)^K − 1) / u` after `K`
   iterations.
10. **`Spec.vecMat g mono`**: the same at `Matrix.vecMul`, outputs `Fin n` (test `vecMat_f`).
    **`vecMatGrade`**: `dotGrade` again, at column `j`, length `m`, with **`vecMatGrade_mono`**
    (test `vecMatDot`).
11. **The sums**, over `ℝ` (`Spec.sumReal g mono`, rule `graded g`) and over `ℤ` (`Spec.sumInt`,
    rule `exact`), at sizes `n : ℕ`, inputs `Fin n`, one output, `f n x () = ∑ i, x i` (test
    `sumReal_f`). Instance: `Spec.sumInt` at `int 32` entries, where the `exact` rule's
    representability premise is what excludes a wrapped sum (below), checked at two inputs whose
    sum is `2³¹` (test `sumInt_wraps`).
12. **The TorchLean importer for `matVec`** (`GPUProofImport.TorchLean`): `Importer` with the
    design's fields, and its first instance at the one operation `contract … .matVec`:
    * `Src` is the operation, `Sz` the shape `(m, n)`;
    * `denote (m, n) (A, x) := Tensor.contract A x _ _ [m] .matVec`, TorchLean's own operation at
      `α := ℝ`, defined before and apart from the spec;
    * `readIn` reads `A` through `Tensor.toVecₗᵢ [m, n]` at `TorchLean.Matmul.idxMN i k` (row
      major, entry `(i, k)` at `k + n · i`) and `x` through `Tensor.getScalar`; `readOut` reads the
      result through `Tensor.getScalar`;
    * `translate` gives `Spec.matVec g` at the operation and `none` elsewhere;
    * `eq` is `TorchLean.matVec_eq`, the design's first equality, in the form

      ```lean
      theorem TorchLean.matVec_eq (A : Tensor ℝ [m, n]) (x : Tensor ℝ [n]) (i : Fin m) :
          (Tensor.contract A x _ _ [m] .matVec).getScalar i =
            Matrix.mulVec (Matrix.of fun i k => Tensor.get2 A i k) (Tensor.getScalar x) i
      ```

      proved by `getScalar_contract_matVec_eq_sum` and `Matrix.mulVec`'s unfolding, and stated
      through `readIn` by `TorchLean.Matmul.toVec_idxMN`. Instance: the importer at every shape;
      a test states the equality at one `2 × 3` matrix and closes it by `simp`.

The existing MojoProof statements against TorchLean (`MojoProof.Sem.groupDot_matVec`,
`MojoProof.Sem.warpDot_matVec`, `MojoProof.Sem.warpDot_vecMat`, MojoProof/Sem/WarpDot.lean)
stay as they are. Once the math statements exist, each is their instance through
`TorchLean.matVec_eq`, at the uniform encoding of its format.

## Tests, one per definition and one per premise

The tests are in the namespace `MojoProofTest.GPUProof.Spec`.

* `nan_approx`, in every binary interchange format with IEEE encoding, through `Approx.model`:
  with a grade of magnitude `0` the canonical NaN meets `Approx` at no real, and with a magnitude
  above `safeMax` every word meets it (`nan_approx_binary32` at binary32).
* `sumInt_wraps`: the `exact` rule without its representability premise is refused at
  `Spec.sumInt` by a 32-bit sum of `2³⁰` and `2³⁰`. Its words decode and its inputs are in `Dom`,
  but the 32-bit sum decodes to `-2³¹`, and no output word of the uniform 32-bit storage decodes
  to the sum `2³¹`.
* `copy_meets`, `copy_meets_binary32` and `copy_meets_bfloat16`: one `Meets` on the copy spec,
  and `Meets.uniform` at binary32 and at bfloat16, whose `safeMax` is `255 · 2¹²⁰`, eight bits of
  precision at binary32's largest exponent.
* `matVec_f`, `vecMat_f` and `sumReal_f`: the specs' functions are Mathlib's sums.
* `overflow_edge`: `Approx` at the overflow edge (the design's test), by evaluation of FloatLib's
  `Model.mul`, `Model.add` and `Model.fma` in binary32. The words `8390108` and
  `16774216 · 2⁸¹` have the exact product `(2⁴⁷ - 4500000) · 2⁸¹`, above `safeMax`
  (`(2⁴⁷ - 2²³) · 2⁸¹`) and below the overflow threshold (`(2⁴⁷ - 2²²) · 2⁸¹`), so it rounds to
  the largest finite word. With the addend `2¹⁰⁰` the unfused result is finite and the fused one
  infinite. The exact magnitude is above `safeMax`, so `Approx` claims nothing there and every
  word, both results among them, meets it.
* `neg_holds`, `neg_meets`, `neg_decode` and `neg_nan_finite`: in every binary interchange
  format the negation spec's `bitwise` rule holds exactly when each output is, up to NaN payloads,
  the negated input; negation meets it at every input, NaNs included; its outputs decode to the
  negated inputs (`FloatRule.Holds.bitwise`); and at a NaN input of binary32 a finite output
  breaks it, where the `exact` rule says nothing.
* `neg_words`, at two formats of different widths, by evaluation of the words: in binary32 at one
  entry and in binary16 at two, the output `1` from the input `1` is refused (another value), and
  from the canonical NaN a NaN with another payload and sign is accepted.
* `bool_total_refused` and `boolId_refuses`: no NaN words make the equality up to NaN payloads
  relate every two words at an encoding with words decoding to `true` and to `false` at one
  entry, and the `bitwise` identity on Booleans refuses the output `false` from the input `true`,
  at every size.
* `zero_sign`, the sign of zero: binary32 at one position, decoded by `Model.toReal?` (`b32 nan
  h`), with FloatLib's NaNs and with every NaN predicate `nan` whose words decode to no real,
  under the `bitwise` identity (`id32 nan h`), refuses `-0` (`0x80000000`) for `+0`
  (`0x00000000`), through `FloatRule.Holds.bitwise_eq`.
* Plan: the importer's `eq` evaluated at one shape, and `translate` refusing a second
  operation.

## Where the plan departs from the design, and why

1. **`safeMax` is not "the largest magnitude whose rounding is finite".** Under nearest-even
   rounding no such magnitude exists: every magnitude below FloatLib's `overflowThreshold fmt`
   (the largest finite value plus half an ulp) rounds to a finite value, and the threshold itself
   rounds to infinity. `safeMax` is the largest finite value, `(Model.posMaxFinite fmt).toReal`,
   for which FloatLib already has the range lemma; the design's overflow-edge test is unchanged.
2. **`Approx` is stated on decoded values, with the word form as a corollary.** A graded rule
   reads its outputs through `Encoding.decode`, which may decode several words at once (block
   scales), so it has values `Option ℝ` and no `Model fmt` word per entry.
3. **`FloatRule` takes `Dom` and `f` as parameters.** The design's `hw : DecodesAs w` must say
   that `w` decodes as the spec's `f` on its `Dom`, which are fields of `Spec`; `Spec.rule` then
   has type `FloatRule In Out dIn dOut Dom f`.
4. **`exact` has a representability premise.** On a 32-bit integer sum the design's `exact` rule
   is false on all of `Dom`, since the words wrap: the output decodes, but not to the sum. The
   integer sum is phase 2's exit test, so the rule claims only where each `f σ A o` decodes from
   some output word, the integer counterpart of `Approx`'s `safeMax` premise.
5. **`Spec.matVec` takes its grade.** Kernels with one mathematics have different proved bounds:
   gemv's `MojoProof.Sem.warpDot_matVec` has the error of
   `GPUProof.laneGrade (.ieee fmt) 32 5 ⌈n / 32⌉ n` at the grades `⟨0, 0⟩`, a sequential loop
   has `γₙ T`, and at `n = 1` the first is above the second. A spec with one fixed grade either
   refuses gemv or is weaker than its proof. `Spec.matVec g mono` shares `Dom` and `f` for every `g`
   (test `matVec_f`), and a kernel's headline names its grade.
6. **`Encodings.uniform` takes one scalar encoding per `DType`**, not one `NumFormat`, so a spec
   with `real` and `int` entries (an index input, a mask) also has a uniform case.
7. **`NumFormat` has a phase 0 form in the core.** FloatLib's format sum is an intake item and not
   released; the core's three cases are replaced by it in one change.
8. **The NaN equivalence is defined once, in a core module that imports nothing.**
   `GPUProof.UpToNaN nan` (GPUProof/NaN.lean) is equality up to the NaN words `nan`, for every word
   type, with its equivalence proved once (`GPUProof.UpToNaN.equivalence`). The encodings'
   `GPUProof.ScalarEnc.nanEq` and `GPUProof.Encoding.nanEq` are `UpToNaN` at their NaN words, and
   MojoProof's `MojoProof.Sem.NaNEq` is `UpToNaN Model.isNaN` at FloatLib's words, and its
   `MojoProof.Sem.FinEq` is `UpToNaN` at the words that are not finite, each with its name, type
   and every lemma's statement unchanged; so `ScalarEnc.ieee`'s relation and MojoProof's are one
   definition. The core cannot import MojoProof, so the definition is the core's, in a module of
   its own, so that a change to the spec layer does not rebuild MojoProof. FloatLib's intake (with
   `Model.add_comm_nanEq`) is its later home.
9. **The importer is a library of its own.** `MojoProofTest/GPUProof/Imports.lean` refuses
   TorchLean in the core's closure, so `GPUProofImport` needs a `lean_lib` entry in the lakefile,
   with its own imports test (only `GPUProof.*`, `Mathlib.*`, `FloatLib.*` and `TorchLean.*`).
10. **TorchLean has no `Tensor.toMatrix` and no `Tensor.toFun`.** The design's statement of
    `TorchLean.matVec_eq` uses both; the form above uses `Matrix.of` over `Tensor.get2` and
    `Tensor.getScalar`, which TorchLean has, and `readIn` connects them to `Tensor.toVecₗᵢ`.
11. **`Meets` and `MeetsAt` take the spec first**, `Meets Sp k` and not `Meets k Sp`: the type of
    the behavior `k` reads `Sp`'s encodings (`Spec.Encs Sp σ`), so `Sp` is bound before it.
12. **`Approx` takes the entry type `d`**, so one definition covers real, integer and boolean
    entries; a graded rule passes `dIn σ i` and `dOut σ o`.
13. **`bitwise` names its encodings.** The design's `w` maps input words to output words at every
    encoding, and no such `w` exists: at an encoding whose input words are `Unit` and whose output
    words are `Empty` it would give a word of `Empty`, and at an encoding whose output decoder
    gives `none` everywhere no `w` decodes as `f`. A bitwise rule is about one storage (NaN
    payloads, sign bits), so `bitwise E₀ w hw` carries its encodings `E₀`, `w` and `hw` are stated
    at `E₀` alone, and the rule claims nothing at other encodings.
14. **Equality up to NaN payloads is defined from NaN words, at every encoding.** In the design
    `nanEq` is a field of each encoding with no law, and a `bitwise` rule trusts it: an encoding
    of Booleans with `nanEq := fun _ _ => True` lets every output meet the bitwise identity spec.
    Laws on a free relation are not enough either: binary32 at one entry, decoded by
    `Model.toReal?`, with `nanEq x y := x.toReal? = y.toReal?`, is an equivalence whose related
    words decode alike, and it relates `+0` and `-0`, so the bitwise identity would accept `-0`
    (`0x80000000`) for `+0` (`0x00000000`), a word with another sign that is no NaN. So no
    encoding carries a relation. A scalar encoding names its NaN words, with the law that a NaN
    decodes to `none` (`GPUProof.ScalarEnc.decode_isNaN`). An encoding of a whole side names its
    word positions, since its words need not be one word per entry (block scales share bits), and
    the NaN words at each position, with two laws that tie them to the decoder: words equal up to
    NaN payloads at every position decode alike (`GPUProof.Encoding.decode_eq`), and a NaN at a
    position leaves some entry with no value, whatever the other positions hold
    (`GPUProof.Encoding.decode_isNaN`). The relation is defined once, `GPUProof.UpToNaN` at each
    position (`GPUProof.ScalarEnc.nanEq`, `GPUProof.Encoding.nanEq`), and its equivalence is a
    theorem (`GPUProof.UpToNaN.equivalence`, `GPUProof.Encoding.nanEq_equiv`). Both laws, and not
    the second alone, because the decoder reads all positions at once: with the second alone, a
    decoder could read another entry's value from a NaN's payload, which a `bitwise` rule lets
    change.

    The counterexample is refused at every NaN predicate, not only FloatLib's: `+0` and `-0`
    decode to `0`, so by the second law neither is a NaN, and `UpToNaN` relates them only if they
    are equal (test `zero_sign`). In general, at inputs that decode into the domain every output
    of the word function has a value, so none of its words is a NaN and the rule asks for those
    words themselves (`GPUProof.FloatRule.Holds.bitwise_eq`): payloads are free only where an
    output of the word function has no value. The Boolean encoding cannot be built either: NaN
    words that relate every two words relate a word decoding to `true` and one decoding to
    `false`, which `decode_eq` refuses (test `bool_total_refused`); and at
    `GPUProof.ScalarEnc.bool`, which has no NaN, the bitwise identity refuses `false` from `true`
    (test `boolId_refuses`). With the laws the outputs of a bitwise rule decode as its word
    function's (`GPUProof.FloatRule.Holds.bitwise`).

    What the laws do not exclude. An encoding may call NaN any word that leaves an entry with no
    value: an infinity, or a word out of range. A bitwise rule then accepts any such word in place
    of another, `+∞` for a NaN or `-∞` for `+∞`; `GPUProof.ScalarEnc.ieee` takes FloatLib's
    `Model.isNaN`, so not at FloatLib's formats. The second law asks for some entry with no value,
    not for the entry that the word stores: an encoding with an entry that never has a value
    (padding stored as an entry, say) may call NaN any words that its decoder reads alike, `+0`
    and `-0` among them. A `bitwise` rule whose outputs are stored so has no word function that
    decodes as `f` (`DecodesAs` asks for a value at every output entry) unless no input decodes
    into the domain, so it claims nothing about values. Padding is modelled as positions whose
    words are `Unit` or have no NaN, not as entries. Which words are NaNs remains the encoding's
    claim; the laws make it a claim about its decoder.

## Not in this layer

`Wiring`, `Meets.comp`, `Meets.choice` and `Meets.ofLocal` come after the three specs, with
softmax and the norms. `Meets.comp` needs one more condition than the design states: a graded
rule must bound its inputs' magnitudes by its output's, `(G i).mag ≤ (g σ E A G o).mag` for every
input `i` that output `o` reads, or an input that its own magnitude premise lets be a NaN makes
the output's claim false. `laneGrade` has that condition (`laneGrade_mag`), so `laneVecGrade`,
`matVecGrade` and `vecMatGrade` have it at every input that their output reads. `MixedRadix` follows the spec
layer.
