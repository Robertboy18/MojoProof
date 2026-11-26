# The spec layer: specifications are mathematics

Lean: GPUProof/Spec/Basic.lean (steps 1 to 8 below), GPUProof/Spec/Linear.lean (steps 9 to 11),
GPUProof/Spec/Import.lean with MojoProof/Import/TorchLean.lean (step 12, in `import.md`) and
GPUProof/Spec/Comp.lean (step 13), with the equality up to NaN payloads in GPUProof/NaN.lean,
tested in MojoProofTest/GPUProof/Spec.lean, MojoProofTest/ImportTorchLean.lean and
MojoProofTest/GPUProof/SpecComp.lean. Still plan: the tests marked "plan" below; the kernels that
meet `Spec.matVec matVecGrade` are in MojoProof/Tile/MatVec.lean (step 9).
This document fixes the definitions of the core's spec layer, the order in which they enter Lean,
the first instance of each, and which FloatLib, TorchLean and Mathlib definitions each one reuses.
Where the Lean departs from the design's sketch, the departure is listed with its reason (last
section). `Spec` cannot enter Lean alone: its `rule` field is a `FloatRule`, whose cases read
encodings, formats and grades, so the first unit that builds with an instance is steps 1 to 8.

**Scope.** Every definition below is stated for every size type `Sz` and every spec `Sp : Spec Sz`;
nothing fixes a machine, a format or a size. The instances are about one spec at a time
(`GPUProof.Spec.matVec`, `GPUProof.Spec.vecMat`, `GPUProof.Spec.sumReal`,
`GPUProof.Spec.sumInt`), at every size and grade, and one encoding family (FloatLib's binary
interchange formats, entry by entry). The composition (step 13) is stated for every two specs,
wiring, behaviors and encodings of its parts; its instances are test wirings of two specs each.
The importer is about two TorchLean operations (`Tensor.contract … .matVec` and
`Tensor.contract … .vecMat`), at every shape.

**Where it lives.** The spec layer is core: modules `GPUProof.Spec.*`, importing only `Mathlib.*`,
`FloatLib.*` and `GPUProof.*`, as `MojoProofTest/GPUProof/Imports.lean` requires of every core
module. The TorchLean importer imports TorchLean, so it cannot be a module of `lean_lib GPUProof`:
that test refuses any `TorchLean.*` module in the core's import closure. The importer's structure
`GPUProof.Importer` names no front end and is core (`GPUProof.Spec.Import`); its TorchLean
instance is in `lean_lib MojoProof` (`MojoProof.Import.TorchLean`, departure 9).

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
* The importer: TorchLean's `Tensor.contract … .matVec` and `Tensor.contract … .vecMat` at
  `α := ℝ` as `denote` (Tensor/Contract.lean); `Tensor.toVecₗᵢ` at `Shape.Coord.equivFin` for
  `readIn` and `readOut`; `toVec_apply`, `Tensor.getScalar_contract_matVec_eq_mulVec`,
  `Tensor.getScalar_contract_vecMat_eq_sum`, `Tensor.get2_eq_apply` and
  `Tensor.getScalar_eq_apply` for `eq` and for the agreement with `Tensor.get2` and
  `Tensor.getScalar`.

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
`GPUProof.Spec.Linear` steps 9 to 11, and `GPUProof.Spec.Import` with `MojoProof.Import.TorchLean`
step 12. All names below are in the namespace `GPUProof`, apart from step 12's instance.

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
   `copy_meets_binary32`, `copy_meets_bfloat16`). The words at a position of
   `Encoding.ofScalars e` and at an input or output position of `Encodings.uniform Sp u σ` have
   decidable equality whenever the scalar words do, for every index type, spec, size and storage
   (GPUProof/Spec/DecEq.lean: `Encoding.decEqOfScalars`, `Encodings.decEqUniformInp`,
   `Encodings.decEqUniformOut`, and instances for the words of `ScalarEnc.ieee`, `ScalarEnc.int`,
   `ScalarEnc.bool` and `ScalarEnc.std`), so `decide` decides an equation between two such words.
   Instance search compares a word at a position with, say, a `BitVec 32` at implicit
   transparency, so the encodings above and the specs of GPUProof/Spec/Linear.lean are
   `[implicit_reducible]`. The positions of `Encoding.ofScalars e` are finite at every finite
   index type, the input positions of `Encodings.uniform Sp u σ` at every spec (its inputs are
   finite), and its output positions wherever the spec's outputs are
   (`Encoding.fintypeOfScalars`, `Encodings.fintypeUniformInp`, `Encodings.fintypeUniformOut`), so
   Mathlib's `Fintype.decidablePiFintype` decides equality of whole words, functions on the
   positions. A spec written as `Spec.ofReal …`, or as an `abbrev` of one, has finite outputs
   wherever its output type does, for every grade and size (`Spec.ofReal.fintypeOut`). Instance
   search does not unfold a `def` such as `Spec.matVec` to `Spec.ofReal` (its index of
   instances unfolds only reducible definitions), so each spec past `Spec.ofReal` in
   GPUProof/Spec/Linear.lean has its own instance (`Spec.matVec.fintypeOut`,
   `Spec.vecMat.fintypeOut`, `Spec.sumReal.fintypeOut`, `Spec.sumInt.fintypeOut`); a composite
   has it wherever its second spec does (`Wiring.spec.fintypeOut`, GPUProof/Spec/Comp.lean). An
   earlier probe of the instance at `Spec.ofReal` failed only because its monotonicity proof, a
   `fun … => le_rfl`, had an unfolded type that the instance's premise did not meet. Tests:
   `prefixSums_outPos_card`, the output positions of an `abbrev` of `Spec.ofReal` (the prefix
   sums) at sizes 3 and 7, found through `Spec.ofReal.fintypeOut`, and the mutant without
   `Spec.matVec.fintypeOut`, where instance search finds none; `sumInt_words`, one
   example at `Spec.sumInt` with integers stored in 32 bits, at one position of the inputs and the
   outputs and for the whole input words at size 3; `sumInt_outWords`, for the whole output words
   at size 2; `outPos_card`, the output positions of `Spec.matVec` and `Spec.vecMat` at `(2, 3)`
   and of `Spec.sumReal` at `4`, for every grade and storage; and `copySum_outWords`
   (MojoProofTest/GPUProof/SpecComp.lean), the whole output words of a composite into
   `Spec.sumInt` at size 2.
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
     unfolding (test `MojoProofTest.TileMatVec.enc_grades`). `rowLoops fmt bits c` is
     `MojoProof.Tile.rowTrees fmt bits 1 (.leaf 0) c`, the lanes' behaviors below at one lane:
     output `i`, at that encoding, is `MojoProof.Sem.dotLoop c` from `+0` at some oracle
     sequence over row `i` and the vector, by `MojoProof.Sem.treeDot`'s definition at a leaf and
     `MojoProof.Tile.stride_one`, and every such loop is a behavior
     (`MojoProof.Tile.rowLoops_dotLoop`); none at another encoding, so the claim is `MeetsAt` at
     that family, not `Meets`. The theorem is
     `MojoProof.Tile.rowTrees_meetsAt` there. Its grade, `laneVecGrade 1 0` at lane length
     `⌈n / 1⌉`, is `matVecGrade`, which is `laneVecGrade 1 0 id`, by an equation and not by
     definition (`n + 1 - 1 = n` and `n / 1 = n`, in the proof); the equation enters through
     `MojoProof.Tile.meetsAt_grade`, since a rewrite of the grade inside `MeetsAt` is not type
     correct. The rule unfolded is `MojoProof.Tile.holds_of`.
   * `MojoProof.Tile.meets_holds`: words that meet the product at the cells `(i, 0)` (`Meets`)
     meet the rule (`FloatRule.Holds`) at the inputs read from the matrices
     (`MojoProof.Tile.matIn`). `MojoProof.Tile.mat_holds` gives such words in the observed
     memory, for every kernel of the `mat` clause whose second matrix has one row and whose
     launch covers the rows and column 0: in every observation `Bk` of a complete run at an
     admitted choice and oracle, the floats of `Bk`'s output block at the rows' cells
     `i * sC * w` (`Elem.word`) meet the rule. The words come from the kernel's soundness and
     the observation (through `Kernel.Sound.obs` and `MojoProof.Tile.mat_word`), the rule from
     `Meets`' graded clause at the same words (instances: `MojoProofTest.TileNaive.naive_holds`,
     the naive matmul kernel with one column, and `MojoProofTest.TileNaive.naive_words`, its two
     words computed, `6` and `-1`, at one launch and memory, with the other row's cell refused).
   * A kernel meets the spec through `MeetsAt`. Its behaviors are read from its runs, not from a
     tile program: `MojoProof.Tile.kernelRows prog fn l ft w bits S` is, at size `(m, K)`, the
     encoding `matVecEnc ft.fmt bits` and input words `W`, the set of output words `W'` such that
     for some setup `s ∈ S (m, K) W` (a `MojoProof.Tile.MatSetup`: launch, arguments, caller
     memory, admission, output block and its row stride), some address choice and oracle that
     `s` admits, and some observation `Bk` of a complete run of `fn` from `s`'s memory
     (`Kernel.Obs`), `W' i` is the float of `Bk`'s output block at row `i`'s cell `i * sC * w`
     (`Elem.word`), for every `i < m`; at another encoding there are none, so the claim is
     `MeetsAt` at `matVecEnc ft.fmt bits`.
     - The input words enter the memory through the setups: a setup's matrices `A` (`m × sA`)
       and `B` (`1 × sB`) are the ones whose inputs are `W` (`matIn A B hA hB = W`, the first `K`
       columns of `A`'s rows and of `B`'s row), and the setup's memory holds them row-major (the
       kernel's precondition, `Mat.Pre` for the naive kernel). The tile run's memory `mats A B`
       is `mat_refines`' and does not enter the behaviors.
     - The runs that count are every complete run at an address choice and oracle the setup
       admits (`s.adm ch ω`); for the naive kernel `adm` is `fun _ ω' => ω' = ω` for the setup's
       oracle family `ω`, so every address choice and every oracle family count.
     - `MojoProof.Tile.MatSetup.Fits` is `mat_holds`' premises at a setup and `matIn A B = W`;
       `MojoProof.Tile.kernelRows_meetsAt`: when every setup fits, `kernelRows` meets
       `Spec.matVec matVecGrade` at `matVecEnc ft.fmt bits` (`mat_holds` at each run, the
       observed words being the behavior's). It is vacuous at a size with no setup;
       `MojoProof.Tile.kernelRows_nonempty` gives a behavior at every fitting setup and admitted
       choice and oracle, from the run `Kernel.Sound.exists_obs` gives.
     - The naive instance (MojoProofTest/TileNaive.lean): `naiveSetups sA sB sC` are the setups
       of `Mat.Pre` at `n = 1`, `Mat.args`, launches valid with `z` sides 1 that cover the rows
       and column 0, sizes below `2 ^ 31` and one oracle family each; `naive_fits` proves they
       fit (`NaiveFam.sound`), so `naive_meetsAt` is `MeetsAt` at every row stride. The set is
       not empty at any size within the family's bounds: `naive_rows` gives, for every row
       stride, width, size `(m, K)` with `1 ≤ sC`, `K ≤ sA`, `K ≤ sB`, and `m * sC`, `m * sA`,
       `sB` below `2 ^ 31`, and every input words `W`, a behavior at `W` that meets the rule. Its
       setup is the tensors of `W` (`tensA`, `tensB`, `+0` past `K`; `matIn_tens`), the launch of
       `max m 1` blocks of one thread, the memory of `naive_pre` (`Mat.pre_mem` at every such
       size, blocks at addresses `4 (i + 1)`) and the oracle family 0. `naive_rows_3x4` and
       `naive_rows_5x7` are its instances at sizes 3 × 4 (row strides 5, 6 and 2) and 5 × 7 (row
       strides 7, 7 and 1), for every `A` and `B`; a mutant, size 2 × 4 at row strides 3, 3
       and 1 (`K` past `sA`), has no setup and no behavior.
   * Tests (MojoProofTest/TileMatVec.lean): the product by rows at sizes 3 × 4 and 5 × 7,
     `rowLoops_meetsAt` at binary32 (`rowLoops_binary32`), and the spec graded one ulp tighter,
     not met by `rowLoops` unfused (`rowLoops_mutant`, at a behavior of `rowLoops_dotLoop`).
   * `MojoProof.Tile.groupDot_holds`: for every IEEE format, width, number of rounds `k`, flag,
     size, oracle sequences and input words, the lane group's dot product `MojoProof.Sem.groupDot
     k` per row (`2 ^ k` loops over the pairs strided by `2 ^ k`, then `k` butterfly rounds;
     `MojoProof.Sem.warpDot` at `k = 5`) meets the rule of
     `Spec.matVec (laneVecGrade (2 ^ k) k fun n => ⌈n / 2 ^ k⌉)`: the case of
     `MojoProof.Tile.rowTrees_meetsAt` below at `2 ^ k` lanes and lane 0's butterfly tree
     (`eval_bflyTree`, `leaves_offsets k 0`, `depth_bflyTree`). The words' bound is
     `MojoProof.Tile.groupDot_approx` (docs/proofs/dot.md, statements 15-16; tests
     MojoProofTest/TileLanes.lean at 3 lanes and length 7, 4 lanes and length 10, and the grade at
     depth 0 refused).
   * `MojoProof.Tile.bflyDeliver_holds`: the same rule for the semantics' rounds, whose `fadd`
     goes through `deliver` with its own oracle number in every round and lane
     (`MojoProof.Sem.bflyRoundsAt`). For every IEEE format, width, `k`, flag, size, oracle
     sequences `o i l` of row `i`'s lane loops, oracle numbers `ob i r l` of round `r`'s `fadd` at
     lane `l`, and input words, lane 0's word after the `k` rounds of
     `deliver (Model.add x y) (ob i r l)` from the lanes' loops meets the rule: it is
     `groupDot k`'s word or both are NaNs (`MojoProof.Sem.bflyDeliver_nanEq`), so the two decode
     alike (`GPUProof.ScalarEnc.decode_eq`). Its statement:

     ```lean
     theorem MojoProof.Tile.bflyDeliver_holds (hfmt : fmt.isIEEE = true) (bits k : Nat)
         (c : Bool) {σ : ℕ × ℕ} (o : Fin σ.1 → Nat → Nat → Nat × Nat)
         (ob : Fin σ.1 → Nat → Nat → Nat) (I : (matVecEnc fmt bits σ).inp.Words) :
         (Spec.matVec (laneVecGrade (2 ^ k) k fun n => (n + 2 ^ k - 1) / 2 ^ k)
             (laneVecGrade_mono _ _ _)).rule.Holds σ (matVecEnc fmt bits σ) I
           fun i => bflyRoundsAt (fun r l x y => deliver (Model.add x y) (ob i r l))
             (bflyOffsets k) (fun l => dotLoop c (o i l) (Model.zero fmt false)
               (stride (2 ^ k) l (List.ofFn fun j => (I (.inl (i, j)), I (.inr j))))) 0
     ```

     `gemv_kernel` is its case `k = 5` (32 lanes; `bflyOffsets 5` is the offsets 16, 8, 4, 2, 1
     of gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, lines 113-132),
     with `o i l` lane `l`'s loop oracle numbers and `ob i r l` those of the `fadd` of round `r`
     at lane `l`. The lanes' order is `MojoProof.Sem.dotLoop_take_stride` (warp-dot.md,
     statement 10): for every `l < w` and round `j`,

     ```lean
     theorem MojoProof.Sem.dotLoop_take_stride (c : Bool) (o : Nat → Nat × Nat) (a : Model fmt)
         {w l : Nat} (hl : l < w) (j : Nat) (ps : List (Model fmt × Model fmt)) :
         dotLoop c o a ((stride w l ps).take (j + 1)) =
           if h : w * j + l < ps.length then
             dotStep c (dotLoop c o a ((stride w l ps).take j)) ps[w * j + l] (o j)
           else dotLoop c o a ((stride w l ps).take j)
     ```

     so in a run in which lane `l`'s sum `%56` before round `j` is
     `dotLoop c (o i l) (+0) ((stride 32 l ps).take j)`, with `ps` row `i`'s pairs
     `List.ofFn fun j => (I (.inl (i, j)), I (.inr j))`, the sum after it has `take (j + 1)`
     (lines 89-108: the arm `%70` folds the pair at `%65 = 32 j + l` when `%69`, `%65 < K`, holds,
     and the arm `%75` keeps the sum), and after `⌈K / 32⌉` rounds the sum is lane `l`'s loop in
     the theorem above (`List.take_of_length_le` and `MojoProof.Sem.length_stride_le`). Tests
     (MojoProofTest/WarpDot.lean): `holds40`, the instance at size `1 × 40`; `rounds40`,
     `MojoProof.Sem.take_stride_succ` at 40 pairs; `mutant_order`, the blocked lane order, which
     gives another word.

     The run of one thread of `gemv_kernel` (tests of that one program): at every `K`, lane `l`'s
     `%79` after the loop is that lane loop with the `contract` flag
     (`MojoProofTest.GemvLoop.run`, with `MojoProofTest.GemvLoop.pairs_eq` for the pairs), and
     the thread runs through the five shuffles to lane 0's store (line 136), with the delivered
     values as premises (`MojoProofTest.GemvLoopTail.thread`). The stored word is lane 0's value
     after the rounds above at `k = 5` when lane 0's oracle numbers are those of its five `fadd`s
     and each delivered value is lane 0's partner's (`0 ^^^ m`) after the rounds before
     (`MojoProofTest.GemvLoopBfly.total_eq`; at the run with the rule,
     `MojoProofTest.GemvLoopBfly.stored_holds`). The step is
     `MojoProof.Tile.bflyRoundsAt_take_succ`: for every carrier, combination per round and lane,
     offsets, round `r` and values, lane `l`'s value after the first `r + 1` rounds is round `r`'s
     combination of its own value and lane `l ^^^ ms[r]`'s after the first `r`. Tests
     (MojoProofTest/GemvLoopBfly.lean): `offsets`, the IR's five offsets are `bflyOffsets 5` in
     order; `premises_vS`, `total_eq`'s premises decided at one example; `premises32`,
     `stored_holds`'s at a matrix of size `1 × 32` and a vector of ones, where the stored word is
     `2 ^ 24 + 2`; `mutant_order`, the deliveries in the reversed round order, and
     `mutant_oracle`, the oracle numbers one off, where the equation fails. The partner chain
     closes over the 32 lanes at once: for every family of lane contexts, steps, sums and
     deliveries, if each lane's delivery at shuffle `i` is the value its partner
     `l ^^^ 2 ^ (4 - i)` offers there (`MojoProofTest.GemvLoopBfly.offered`, the `addAt` chain
     at the partner's own context, step, sum and deliveries, `shfls`' argument by `rfl` in
     `shfls_offered`), then every lane's offered values are its values after the rounds before
     (`offered_eq`, by `MojoProof.Tile.bflyRoundsAt_chain` over the lanes below 32), and every
     lane's `total` is its value after the five rounds (`total_chain`); at lane 0 that is
     `total_eq`'s premise on the deliveries. Not proved: that the shuffles deliver those values,
     which is the warp's run at every `K` (each lane's `run`, then the lanes of one warp in
     turn).
   * `MojoProof.Tile.rowTrees_meetsAt`: the lanes' form, of which `rowLoops_meetsAt` above is the
     case at one lane and the tree `.leaf 0`. For every IEEE
     format, width, lane count `W`, tree `t` whose leaves are the lanes, each once, and flag, the
     behaviors `MojoProof.Tile.rowTrees fmt bits W t c` (output `i` is `MojoProof.Sem.treeDot t`
     over the lanes' loops on the pairs of row `i` strided by `W`, at some oracle sequences) meet
     `Spec.matVec (laneVecGrade W t.depth fun n => ⌈n / W⌉)` at `matVecEnc` (`MeetsAt`), by
     `holds_of` and `MojoProof.Tile.stride_approx`. `groupDot k` per row is a behavior at lane
     0's butterfly tree (`eval_bflyTree`), for every `k` (`groupDot_holds`). Tests
     (MojoProofTest/TileLanes.lean): `rows_2x7`, 3 lanes along `(0 + 1) + 2` at size 2 × 7, and
     `rows_3x10`, `groupDot 2` per row at size 3 × 10.
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
12. **The TorchLean importer for `matVec` and `vecMat`** (`GPUProof.Spec.Import`,
    `MojoProof.Import.TorchLean`, in `import.md`): `GPUProof.Importer` with the design's fields
    `Src`, `Sz`, `SIn`, `SOut`, `denote`, `translate`, `readIn`, `readOut` and `eq`, and its first
    instance `MojoProof.Import.torchLean g mono gv monov`:
    * `Src` has TorchLean's contractions `.matVec` and `.vecMat`, `Sz` the sizes `(m, n)`;
    * `denote (m, n) (A, x) := Tensor.contract A x _ _ [m] .matVec` and
      `denote (m, n) (x, A) := Tensor.contract x A _ _ [n] .vecMat`, TorchLean's own operations
      at `α := ℝ`, defined before and apart from the specs;
    * `readIn` and `readOut` read every tensor through `Tensor.toVecₗᵢ` at the row-major index
      `Shape.Coord.equivFin` of each coordinate (`MojoProof.Import.entry`);
    * `translate` gives `Spec.matVec g mono` at `.matVec` and `Spec.vecMat gv monov` at
      `.vecMat`;
    * `eq` is `MojoProof.Import.matVec_eq` and `MojoProof.Import.vecMat_eq`, at every shape:

      ```lean
      theorem MojoProof.Import.matVec_eq (A : Tensor ℝ [m, n]) (x : Tensor ℝ [n]) (i : Fin m) :
          entry (Tensor.contract A x _ _ [m] .matVec) (i, ()) =
            Matrix.mulVec (Matrix.of fun i k => entry A (i, k, ())) (fun k => entry x (k, ())) i
      theorem MojoProof.Import.vecMat_eq (x : Tensor ℝ [m]) (A : Tensor ℝ [m, n]) (j : Fin n) :
          entry (Tensor.contract x A _ _ [n] .vecMat) (j, ()) =
            Matrix.vecMul (fun i => entry x (i, ())) (Matrix.of fun i j => entry A (i, j, ())) j
      ```

      proved by TorchLean's `toVec_apply`, `Tensor.getScalar_contract_matVec_eq_mulVec` and
      `Tensor.getScalar_contract_vecMat_eq_sum`;
    * the reading is `MojoProof.Sem.matVecPairs`' (`Tensor.get2` and `Tensor.getScalar`), in
      every format and at every size: `readIn_map` and `readOut_map` read the maps by
      `Model.toReal` of a matrix and a vector of words as the real values of `matVecPairs`' words
      and its exact sum.

    Tests: both sides of `.matVec` at a `2 × 3` and a `3 × 5` matrix and of `.vecMat` at
    `2 × 3`, `3 × 5` and `2 × 2`, a transposed `readIn` at each operation, `translate .vecMat`,
    and `cell_spec`, the exact sum over `matVecPairs` as `Spec.matVec`'s function at the words'
    real values in every format.

13. **Composition** (`GPUProof.Spec.Comp`, importing `GPUProof.Spec.Basic` and Mathlib only), for
    every two specs `S₁`, `S₂` over one size type:
    * **`Wiring S₁ S₂`**: at every size `σ`, extra inputs `Extra σ` with their types `dEx σ`, a
      bijection `wire σ : S₂.In σ ≃ S₁.Out σ ⊕ Extra σ`, and the law `types` that each input of
      `S₂` has the type of the output or extra input it is wired to. The design's premise
      `hd : w.DomOk` of `Meets.comp` is a definition with a lemma instead (departure 15).
    * **`Wiring.spec r`**, the composite spec with rule `r`: inputs `S₁.In σ ⊕ Extra σ`, outputs
      `S₂.Out σ`, function `S₂.f` at the exact intermediate `Wiring.mid` (`S₁.f` at the first
      inputs beside the extra inputs, read along `wire`), and domain `Wiring.Dom`, `S₁.Dom` at the
      first inputs and `S₂.Dom` at the intermediate, which is `S₁.Dom` alone when `S₁` maps its
      domain into `S₂`'s (`Wiring.DomOk`, `Wiring.dom_iff`).
    * **The encodings.** The composite's encodings do not fix the intermediate's, so the claim is
      made at encodings built from parts: for every encodings `E₁` of `S₁`, `Ex` of the extra
      inputs and `Eo` of `S₂`'s outputs, the composite has `E₁`'s inputs beside `Ex`
      (**`Encoding.sum`**) with `Eo` (`Wiring.encs`), and `S₂` has `E₁`'s outputs beside `Ex`,
      read along `wire` (**`Encoding.reindex`**), with `Eo` (`Wiring.encs₂`).
    * **`Wiring.behav k₁ k₂ E₁ Ex Eo`**, the composite behavior: at `Wiring.encs`, the relational
      composition, the outputs of `k₂` from some output words of `k₁` and the extra words; at
      every other encoding every output, so nothing is claimed there.
    * **`MeetsAt.comp`**: when both rules are graded (`S₁.rule = .graded g₁ m₁`,
      `S₂.rule = .graded g₂ m₂`), `k₁` meets `S₁` at `E₁` and `k₂` meets `S₂` at `Wiring.encs₂`,
      `Wiring.behav` meets the composite with the graded rule `Wiring.grade` at `Wiring.encs`.
      `Wiring.grade` is `g₂` at the exact intermediate with, along `wire`, the grades that `g₁`
      gives `S₁`'s outputs at `E₁` and the extra inputs' own grades; it is monotone when `g₁` and
      `g₂` are (**`Wiring.grade_mono`**). No premise bounds an input's magnitude by an output's
      (departure 16).
    * **`Wiring.MidRep E M`**, the intermediate's representability at encodings `M` of `S₁`'s
      outputs where the composite's rule makes a claim at encodings `E`: at every size, input
      words of `E` that decode to `Z` in the composite's domain, with some output words of `E`
      decoding to the composite's function at `Z`, give some words of `M` that decode to `S₁.f`
      at `Z`'s first inputs. It asks this only where the composite's `exact` rule makes a claim,
      so a domain of `S₂` that excludes the unrepresentable intermediates gives it there.
    * **`MeetsAt.comp_exact`**: when both rules are `exact` (`S₁.rule = .exact`,
      `S₂.rule = .exact`), `k₁` meets `S₁` at `E₁`, `k₂` meets `S₂` at `Wiring.encs₂` and
      `Wiring.MidRep` holds at `Wiring.encs` and `E₁`'s outputs, `Wiring.behav` meets the composite
      with the `exact` rule at `Wiring.encs`. Proof: from the composite's premise at input words `W`
      decoding to `Z`, `Wiring.MidRep` gives `S₁`'s representability premise, so `k₁`'s output words
      `V` decode to `S₁.f` at `Z`'s first inputs; the words `V` beside the extra words then decode,
      along `wire`, to the exact intermediate `Wiring.mid σ Z`, which is in `S₂`'s domain (the
      second half of `Wiring.Dom`), and the composite's representability premise is `S₂`'s there, so
      `k₂`'s output words decode to `S₂.f` at it, the composite's function.
    * **At every encoding.** The intermediate's encoding is data of the behavior: encodings
      `M σ E` of `S₁`'s outputs chosen at each composite encoding `E`. The composite's input
      words are read at the first inputs and at the extra inputs through **`Encoding.comap`**
      (the same positions and words, entry `i` decoded as entry `g i`, no NaN words, since a NaN
      word may leave only the other entries with no value): **`Wiring.fstEncs M σ E`** is `E`'s
      inputs at the first inputs with `M σ E`, and **`Wiring.exEnc σ E`** `E`'s inputs at the
      extra inputs. **`Wiring.behavMid k₁ k₂ M`** runs `k₁` at `Wiring.fstEncs` on `E`'s input
      words and `k₂` at `M σ E` beside `Wiring.exEnc`, read along `wire`, with `E`'s outputs, on
      `k₁`'s output words beside the same input words.
    * **`Wiring.holds_comp`**, **`Wiring.holds_comp_exact`**: the two compositions at one size
      and composite encoding `E`, for encodings of `S₁` and of the extra inputs whose words
      decode, and for graded rules are stored, as `E`'s input words at the first and at the
      extra inputs; the graded one's grade is **`Wiring.gradeBy F₁ Fx g₁ g₂`**, `Wiring.grade`
      with the encodings of the parts chosen at each composite encoding (`Wiring.grade` is its
      case at fixed `E₁`, `Ex`; **`Wiring.gradeBy_mono`**). `MeetsAt.comp` and
      `MeetsAt.comp_exact` are their cases at `Wiring.encs`, the words of `E₁` and `Ex` being
      the halves of the composite's.
    * **`Meets.comp`**, **`Meets.comp_exact`**: when both rules are graded, or both `exact` with
      `Wiring.MidRep E` at `M σ (E σ)` for every composite encodings `E`, and `k₁` and `k₂` meet
      `S₁` and `S₂` at every encoding, `Wiring.behavMid k₁ k₂ M` meets the composite at every
      encoding, with the grade `Wiring.gradeBy (Wiring.fstEncs M) Wiring.exEnc g₁ g₂` or the
      `exact` rule (`Wiring.holds_comp` and `Wiring.holds_comp_exact` at `Wiring.fstEncs` and
      `Wiring.exEnc`, every decoding premise by `rfl`).
    * **An `exact` rule then a graded one.** An `exact` rule claims only at input words that
      decode exactly, so at an inexact first input nothing is known of the intermediate, and the
      composite's grade claims nothing there. **`Grade.onlyIf c fmt g`** is `g` where `c` holds
      and otherwise `g` with its magnitude raised above `fmt`'s `NumFormat.safeMax`, where
      `Approx` claims nothing (**`Grade.onlyIf_pos`**, **`Approx.onlyIf_neg`**,
      **`Grade.onlyIf_mono`**). **`Wiring.gradeEx M Fx g₂`** is, where every first input's grade
      is exact (error at most `0`, magnitude at most its format's `safeMax`, so that `Approx`
      there is exact decoding, **`Approx.eq_some`**), `g₂` at `M σ E` and `Fx σ E` along the
      wiring with `E`'s outputs, the exact intermediate, and the grade `⟨0, 0⟩` at the wired
      outputs with the extra inputs' own grades (**`Wiring.gradeEx_eq`**); elsewhere it is
      `Grade.onlyIf`'s grade. It is monotone when `g₂` is (**`Wiring.gradeEx_mono`**).
    * **`Wiring.FstRep E M`**, the premise the mixed case needs: at every size, input words of `E`
      that decode exactly at the first inputs to `Z`, with `Z` in the composite's domain, give
      some words of `M` that decode to `S₁.f` at `Z`'s first inputs. Unlike `Wiring.MidRep` it
      reads no extra input and has no premise on the composite's outputs, since a graded rule's
      conclusion asks for no representable output; so a domain of `S₂` that excludes the
      unrepresentable outputs does not give it.
    * **`Wiring.holds_comp_gradeEx`**, at one size and composite encoding `E`: if the words of
      `M σ E` decode to `S₁.f` wherever the first inputs decode exactly into the composite's
      domain (`hV`), and `W'` meets `S₂`'s graded rule at them beside the extra words, then `W'`
      meets the composite's graded rule `Wiring.gradeEx`. **`MeetsAt.comp_graded_of_dec`** is
      its case at `Wiring.encs`, with `hV` as a premise on `k₁`'s outputs at `E₁` (`hdec`) for
      every first rule. **`MeetsAt.comp_exact_graded`** (`S₁.rule = .exact`,
      `S₂.rule = .graded g₂ m₂`, `Wiring.FstRep` at `Wiring.encs` and `E₁`'s outputs) is
      `MeetsAt.comp_graded_of_dec` with `hdec` from `k₁`'s rule with `Wiring.FstRep`, and
      **`Meets.comp_exact_graded`** (`Wiring.FstRep E` at `M σ (E σ)` for every composite
      encodings `E`) is the case at every encoding.
    * **One step for the three.** `Wiring.holds_comp`, `Wiring.holds_comp_exact` and
      `Wiring.holds_comp_gradeEx` share **`Wiring.along`**: an entrywise relation that holds at
      every output of `S₁` and every extra input holds at every input of `S₂`, read along `wire`.
      They use it at `Approx` (graded, and the mixed case, whose exact first outputs
      `Approx.some_zero` puts at the grade `⟨0, 0⟩`) and at exact decoding
      (**`Wiring.decode_mid`**: output words of `S₁` that decode to `S₁.f` at the first inputs,
      beside extra words that decode to the extra inputs, decode along `wire` to
      `Wiring.mid σ Z`).
    * **One step for an `exact` second rule.** **`Wiring.holds_exact_of_mid`**, at one size and
      composite encoding `E`, for every encodings `e₁` of `S₁`'s outputs and `ex` of the extra
      inputs whose words decode as `E`'s at the extra inputs: if the words `V` of `e₁` decode to
      `S₁.f` at the first inputs wherever the composite's `exact` rule makes a claim at `E` (`hV`),
      and `W'` meets the `exact` rule of `S₂`'s domain and function at `V` beside the extra words,
      then `W'` meets the composite's `exact` rule. `Wiring.holds_comp_exact` is its case with
      `hV` from `S₁`'s `exact` rule and the representability premise; the two pairs below with a
      `bitwise` rule and an `exact` one are the others.
    * Not covered: a graded rule then an `exact` one. The composite's rule would be graded, and
      `S₁`'s graded outputs give `S₂` inputs `Y` within grades of the exact intermediate
      `Wiring.mid σ Z`, where `S₂`'s `exact` rule claims `S₂.f σ Y` and the composite's claim is
      about `S₂.f σ (Wiring.mid σ Z)`. A rule for the pair would have to name, at every size,
      composite encoding, input `Z` in the composite's domain and input grades:
      * a modulus of continuity of `S₂.f`: a grade `ω` of each output, monotone in the input
        grades, such that every `Y` within the grades `Wiring.grade` gives the wired inputs (each
        `Y i` meeting `Approx` at its grade and the exact intermediate's entry) has `S₂.f σ Y`
        within `ω` of `S₂.f σ (Wiring.mid σ Z)`;
      * that such `Y` stay in `S₂.Dom` (its domain closed under the first rule's perturbation);
      * that `S₂.f σ Y` has words at `Eo` at such `Y`, since the graded composite has no
        representability premise and `S₂`'s `exact` rule needs one;
      * that `ω`'s magnitude is above its format's `NumFormat.safeMax` wherever an input grade's
        is (as `Grade.onlyIf` does), since there `S₁`'s output may be a word with no value and
        `S₂`'s rule then claims nothing.
      The composite would then meet the graded rule `ω` at `Wiring.encs`. No spec here has such a
      modulus with a test, so the theorem is not stated.
    * **Pairs with a `bitwise` rule**, which claims only at its own encodings `E₀`, at encodings
      built from parts where `E₀` is the parts': `E₁` for a first `bitwise` rule, `Wiring.encs₂`
      for a second one. At every encoding none holds: at the other encodings its rule claims
      nothing.
      * A first `bitwise` rule's output words decode to `S₁.f` wherever its inputs decode into
        `S₁`'s domain (`FloatRule.Holds.bitwise`), with no representability premise. That is `hV`
        of `Wiring.holds_comp_gradeEx` and of `Wiring.holds_exact_of_mid`:
        **`MeetsAt.comp_bitwise_graded`** (`S₁.rule = .bitwise E₁ w₁ hw₁`,
        `S₂.rule = .graded g₂ m₂`) gives the composite's graded rule `Wiring.gradeEx` at
        `Wiring.encs` (`MeetsAt.comp_graded_of_dec`), and **`MeetsAt.comp_bitwise_exact`**
        (`S₂.rule = .exact`) its `exact` rule.
      * **`MeetsAt.comp_exact_bitwise`** (`S₁.rule = .exact`,
        `S₂.rule = .bitwise (Wiring.encs₂ E₁ Ex Eo) w₂ hw₂`, `Wiring.MidRep` at `Wiring.encs` and
        `E₁`'s outputs): `S₂`'s outputs decode to `S₂.f` wherever its inputs decode into its
        domain, which is its `exact` claim, so the proof is `MeetsAt.comp_exact`'s. After a graded
        rule no claim follows, as for a graded rule then an `exact` one: its word function's
        `DecodesAs` speaks only of input words that decode into its domain.
      * **`MeetsAt.comp_bitwise`** (both `bitwise`, the second at `Wiring.encs₂ E₁ Ex Eo`): the
        composite meets the `bitwise` rule at `Wiring.encs` whose word function
        **`Wiring.bitW`** is `w₂` after `w₁` beside the extra words, which decodes as the
        composite's function (**`Wiring.bitW_dec`**, by `hw₂` at `Wiring.mid` through
        `Wiring.decode_mid`), given that `w₂` maps words equal up to NaN payloads to words equal
        up to NaN payloads, since `k₁`'s outputs are `w₁`'s only up to NaN payloads. Without that
        premise it is false: `squash` maps the NaNs `1` and `2` of a storage of three words to
        `0` and `1` (`squash_nanEq`), and at size 0 `ruleK` after `ruleK` allows the output `1`
        from the NaN input `1` through the intermediate NaN `2`, where the composite asks for
        `squash 1 = 0` up to NaN payloads (`nanIdSq_refused`, `nanIdSq_noresp`). `DecodesAs`
        asks this of no word function.

    Instances (MojoProofTest/GPUProof/SpecComp.lean): two copies at binary32 with no extra input
    (`chain_meets`), and the design's `D = A·x + e`, `Spec.matVec matVecGrade` wired into an
    entrywise sum with `e` as the extra input (`dax_meets`, `dax_f`, `dax_dom`, `dax_grade`). For
    `MeetsAt.comp_exact`: `n` 32-bit integers copied (`copyInt`, rule `exact`) into
    `GPUProof.Spec.sumInt`, where the intermediate is the input words themselves, so `Wiring.MidRep`
    holds at every size and storage of the integers (`copySum_rep`, `copySum_meets`), with the sums
    `6` of the words `1, 2, 3` at size 3 and `-7` of seven words `-1` at size 7 (the two examples of
    `copySum_meets` after it); and the mutant `GPUProof.Spec.sumInt` into a negation (`negInt`, rule
    `exact`) at size 2 and inputs `2 ^ 30`, where the sum `2 ^ 31` has no 32-bit word while its
    negation `-2 ^ 31` has one: the behaviors that allow every output their rule allows (`ruleK`)
    meet both parts, and their composition does not meet the composite (`sumNeg_refused`), so
    `Wiring.MidRep` fails there (`sumNeg_norep`). At every encoding: `ruleK` after `ruleK` along
    `chain` at every `M` (`chain_meetsAll`); along `copySum` with the intermediate encoded as the
    composite's inputs (`Encoding.comap` at `Sum.inl`), where `Wiring.MidRep` holds at every
    composite encoding (`copySum_repAll`, `copySum_meetsAll`); and along `sumNeg` with the
    intermediate stored as a 32-bit integer, refused at the encodings of `sumNeg_refused`
    (`sumNeg_refusedAll`; both mutants through `sumInt_none`, `negInt_zero`, `sumNeg_fails`). These
    tests are stated for every binary interchange format, which integer entries do not read, with no
    premise on the format's encoding. For `MeetsAt.comp_exact_graded`: `n` integers copied
    (`copyInt`) into their negations with a graded rule (`negG Fin`, at the grade `sameGrade`)
    along `copyNegG`, where `Wiring.FstRep` holds at every size and storage (`copyNegG_rep`,
    `copyNegG_meets`) and at every encoding (`copyNegG_repAll`, `copyNegG_meetsAll`); at exact
    input grades the composite's grade is `⟨0, 0⟩` (`copyNegG_grade`), and with 32-bit integers
    at size 3 the words `1, 2, 3` give `-1, -2, -3` (the example after `copyNegG_grade`). The
    mutant: `GPUProof.Spec.sumInt` into the graded negation (`sumNegG`) at size 2 and inputs
    `2 ^ 30`, where `ruleK`'s composition does not meet the composite at its encodings or at
    every encoding (`sumNegG_refused`, `sumNegG_refusedAll`, through `sumInt_none`, `negG_zero`
    and `sumNegG_fails`), so `Wiring.FstRep` fails there (`sumNegG_norep`) and is needed. For the
    pairs with a `bitwise` rule, at every size and storage of the integers: `n` integers copied
    by `copyBit u` (`bitwise` at `copyInt`'s uniform encodings, the identity word function) into
    `GPUProof.Spec.sumInt` (`bitSum_meets`) and `copyInt` into `copyW u` (`bitwise` at the wired
    encodings `wiredEncs u`, the word function that reads the wired position), with
    `Wiring.MidRep` by the input words themselves (`copyCp_rep`, `copyCp_meets`), and `copyBit u`
    into `copyW u` (`bitCp_meets`, `copyW u`'s word function keeping NaN payloads' equality
    since it reads one position), each with 32-bit integers at size 3 (words `1, 2, 3`) and size 7
    (seven words `-1`) in the two examples after it. At one integer entry stored by `nanInt` (the
    word `0` with the value `0`, the NaNs `1` and `2`), copied by `nanId` (`bitwise`, the
    identity word function): into the graded negation (`nanIdNeg_meets`, at every size), into
    `nanCp` (`bitwise`, the word function that reads the first position; `nanIdCp_meets`, at
    every size) and into the copy `nanSq` with the word function `squash` (`squash_dec`,
    `nanIdSqW`, `nanIdSqW_dec`, `nanIdSq_refused`, at size 0), so `MeetsAt.comp_bitwise`'s
    premise fails for `squash` (`nanIdSq_noresp`) and is needed. The mutant for
    `MeetsAt.comp_exact_bitwise`'s premise: `negInt` with its output stored by `nanInt` into
    `zeroW` (`bitwise`, the constant word `0`, `zero_dec`) along `negZ`, at size 0 and the input
    `5`: `-5` has no word of `nanInt`, so `negInt`'s rule allows the intermediate `0`, and the
    composite asks for the 32-bit word of `-5` (`negZ_refused`), so `Wiring.MidRep` fails there
    (`negZ_norep`).

The existing MojoProof statements against TorchLean (`MojoProof.Sem.groupDot_matVec`,
`MojoProof.Sem.warpDot_matVec`, `MojoProof.Sem.warpDot_vecMat`, MojoProof/Sem/WarpDot.lean)
stay as they are. Once the math statements exist, each is their instance through
`MojoProof.Import.matVec_eq` or `MojoProof.Import.vecMat_eq`, at the uniform encoding of its
format.

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
* `out23`, `spec23`, `out35` and `spec35` (namespace `MojoProofTest.ImportTorchLean`): both sides
  of the importer's `eq` at a `2 × 3` and a `3 × 5` matrix, each by `simp` or `norm_num`;
  `outv23`, `specv23`, `vecMat35` and `vecMat22`: the same at `.vecMat` at `2 × 3`, `3 × 5` and
  `2 × 2`; `mutant_transposed` and `mutant_vecMat_transposed` at `2 × 2`: a transposed `readIn`
  has no `eq` at either operation; `translate_vecMat`: `translate` proposes `Spec.vecMat` at
  `.vecMat`; `cell_spec`: `eq` read through `readOut_map` and `readIn_map` (`import.md`).

The composition's tests are in the namespace `MojoProofTest.GPUProof.SpecComp`, on copy specs
with a graded rule (`copyG I g`) and the behaviors that output words decoding as the input words
do (`sameK`).

* `nan_needs_mag`, `forget_refused` and `id_meets`, at one input stored in a binary interchange
  format with IEEE encoding: `sameK` keeps a NaN a NaN, so it meets `copyG` at grade `g` only if
  `g`'s magnitude is above `safeMax` wherever the input grade's is (departure 16). It does not
  meet the monotone grade `forget` of magnitude `0`, and it meets the identity grade.
* `chain_meets` and `chain_grade`: every premise of `MeetsAt.comp` at two copies in binary32 wired
  with no extra input, and the composite's grade is the input's.
* `dax_meets`, `dax_f`, `dax_domOk`, `dax_dom` and `dax_grade`: `MeetsAt.comp` at `D = A·x + e`
  for every behaviors that meet the two specs, the product stored in binary32; the composite's
  function is `A.mulVec x + e`, its domain is everything (`Wiring.dom_iff`), and its error at
  output `i` is `matVecGrade`'s at row `i` plus `e i`'s.
* `int_real_refused`, a mismatched type: no wiring feeds `Spec.sumInt`'s integer output into a
  real input (`types` at size `1`).

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
9. **The importer's structure is core and its TorchLean instance is in `MojoProof`.**
   `MojoProofTest/GPUProof/Imports.lean` refuses TorchLean in the core's closure.
   `GPUProof.Importer` imports only `GPUProof.Spec.Basic`, so it is core; the instance
   `MojoProof.Import.torchLean` is in `lean_lib MojoProof`, which already imports TorchLean, so
   the planned library `GPUProofImport` and its imports test are not needed (`import.md`,
   departure 1).
10. **TorchLean has no `Tensor.toMatrix`, no `Tensor.toFun` and no `Matmul.idxMN`.** The design's
    statement of `TorchLean.matVec_eq` uses the first two; `MojoProof.Import.matVec_eq` reads every
    tensor through `Tensor.toVecₗᵢ` at `Shape.Coord.equivFin` (`MojoProof.Import.entry`), and
    `MojoProof.Import.entry_eq` with TorchLean's `Tensor.get2_eq_apply` and
    `Tensor.getScalar_eq_apply` connects that reading to `Tensor.get2` and `Tensor.getScalar`
    (`entry_get2`, `entry_getScalar`, and at words `readIn_map`, `readOut_map`; `import.md`,
    departures 6 and 7).
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
15. **`MeetsAt.comp` has no premise `hd : w.DomOk`; `Wiring` names the extra inputs' types and
    has no finiteness field.** The composite's domain is `S₁.Dom` at the first inputs with
    `S₂.Dom` at the exact intermediate (`Wiring.Dom`), which needs no premise and holds at every
    wiring; where `S₁` maps its domain into `S₂`'s, `Wiring.DomOk` is a definition and
    `Wiring.dom_iff` gives the design's domain, `S₁.Dom` alone. The design leaves the extra
    inputs' types to its law `types`; the field `dEx` names them, so `types` is one equation with
    `Sum.elim` and the composite's input types are `Sum.elim S₁.dIn dEx`. The extra inputs are
    finite because `S₂`'s inputs are and `wire` is a bijection with `S₁`'s outputs and the extra
    inputs (Mathlib's `Fintype.sumRight`), so `Wiring.spec` derives it.
16. **`Meets.comp` needs no magnitude condition; one kernel meeting one graded rule does.** This
    document used to require of `Meets.comp` that a graded rule bound its inputs' magnitudes by
    its output's. `MeetsAt.comp` has no such premise: at each input of `S₂`, `S₂`'s premise is the
    implication "magnitude at most `safeMax`, then near", and `S₁`'s conclusion at the output
    wired to that input is the same implication at the grade that `Wiring.grade` passes there, so
    the composite's premise gives `S₂`'s at every input, NaN or not. The condition belongs to a
    kernel that keeps NaNs: an input whose grade's magnitude is above `safeMax` may be a NaN, and
    the kernel's output is then a NaN, so the output grade's magnitude must be above `safeMax`
    too, or `Approx` asks for a value (test `nan_needs_mag`, at one input, and `forget_refused`).
    `laneGrade` has that condition (`laneGrade_mag`, step 9), so `laneVecGrade`, `matVecGrade` and
    `vecMatGrade` have it at every input that their output reads.

## Not in this layer

`Meets.choice` and `Meets.ofLocal` come after the three specs, with softmax and the norms.
`MeetsAt.comp` covers two graded rules, `MeetsAt.comp_exact` two `exact` rules, the second with
the intermediate's representability as a premise, and `MeetsAt.comp_exact_graded` an `exact`
rule then a graded one, with the first outputs' representability as a premise, at encodings
built from parts; `Meets.comp`, `Meets.comp_exact` and `Meets.comp_exact_graded` the same at
every encoding with the intermediate's encoding as data of the behavior (step 13);
`MeetsAt.comp_bitwise_exact`, `MeetsAt.comp_exact_bitwise`, `MeetsAt.comp_bitwise_graded` and
`MeetsAt.comp_bitwise` the pairs with a `bitwise` rule, at encodings built from parts only. A
graded rule then an `exact` one is not stated: step 13 lists what its rule would have to name.
`MixedRadix` follows the spec layer.
