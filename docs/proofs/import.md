# Spec importers: TorchLean's matrix-vector and vector-matrix products

Lean: `GPUProof/Spec/Import.lean` (the structure `GPUProof.Importer`, core) and
`MojoProof/Import/TorchLean.lean` (its TorchLean instance `MojoProof.Import.torchLean`, the
equalities `MojoProof.Import.matVec_eq` and `MojoProof.Import.vecMat_eq`, and the agreement of
its reading with `MojoProof.Sem.matVecPairs`'), whose operations, readings and importer one
command declares, `MojoProof.Import.import_spec` (`MojoProof/Import/Command.lean`, with its
tactic `MojoProof.Import.import_fact`). Tests: `MojoProofTest/ImportTorchLean.lean` and, for the
command, `MojoProofTest/ImportSpec.lean` and `MojoProofTest/ImportDom.lean` (with its bridges in
`MojoProofTest/ImportFacts.lean`). This is step 12 of `spec.md`.

**Scope.** `GPUProof.Importer` is stated for every front end: every type of operations, sizes per
operation, input and output tensors at every size, meaning and proposed specs;
`GPUProof.Importer.Graded` and `GPUProof.Importer.graded_of_holds` for every importer,
operation, graded spec, size and words. `MojoProof.Import.matVec_eq` and
`MojoProof.Import.vecMat_eq` hold for every shape `m`, `n`, real matrix, real vector and output
index. `MojoProof.Import.torchLean` is one importer, for every
grade of `GPUProof.Spec.matVec` and every grade of `GPUProof.Spec.vecMat`, at two operations
(TorchLean's `.matVec` and `.vecMat` contractions) and every size; it proposes a spec for both,
and its `eq` holds at both and every size. The agreement lemmas (`readIn_map`, `readOut_map`)
hold in every format and at every size. The tests evaluate both sides of `eq` at 2 × 3 and
3 × 5 for each operation, and at 2 × 2 for `.vecMat` and the mutants. `import_spec` is a
command for every list of operations whose inputs are explicit binders, with one size type for
all; it declares the importer only if `import_fact` closes `eq` at every operation, and its tests
are at one source (the sum of a vector read backwards) at sizes 2 and 5, with a mutant, and at one
source with a domain (the truncated difference of two natural vectors, proposed as the test spec
`diffInt`, the integer difference, meant where `b ≤ a`) at sizes 3 and 5, with a bridge of
another module and a refused one.

## Definitions

* `GPUProof.Importer` (GPUProof/Spec/Import.lean:51), nine fields:
  * `Src`, the source's operations, and `Sz e`, the sizes of operation `e`;
  * `SIn e σ` and `SOut e σ`, its input and output tensors at size `σ`;
  * `denote e σ : SIn e σ → SOut e σ`, the source's own meaning at the reals;
  * `translate e : Option (Spec (Sz e))`, the proposed spec, `none` outside the fragment;
  * `readIn` and `readOut`, of types `Importer.ReadIn` (:32) and `Importer.ReadOut` (:40): for each
    operation `e`, spec `Sp` with `translate e = some Sp` and size `σ`, a map from the tensors to
    `Sp`'s input or output entries;
  * `eq`: on `Sp`'s domain, `readOut e Sp h σ (denote e σ x) = Sp.f σ (readIn e Sp h σ x)`.
* `GPUProof.Importer.Graded Imp e h g σ E I W` (GPUProof/Spec/Import.lean:80), for every
  importer, operation `e`, proposed spec `Sp` (`h : translate e = some Sp`), grade `g` of the
  graded shape, size, encodings `E`, input words `I` and output words `W`: at every input tensors
  `x` of the source and input grades `G` within which each input word approximates entry `i` of
  `readIn e Sp h σ x`, each output word is `Approx` at `g`'s grade of entry `o` of
  `readOut e Sp h σ (denote e σ x)`. It names the source's meaning, not `Sp.f`: it is the form of
  a kernel's words against the source.
* `entry t c` (MojoProof/Import/TorchLean.lean:59): `TorchLean.Tensor.toVecₗᵢ s t` at
  `TorchLean.Shape.Coord.equivFin s c`, the tensor's flattening at the row-major index of
  coordinate `c`.
* The rest are declared by the `import_spec` command at :138, which has no line per declaration:
  * `MojoProof.Import.TorchOp`: `matVec` and `vecMat`, at sizes `(m, n) : ℕ × ℕ`.
    `TorchOp.SIn` is a real `m × n` tensor and a real vector of length `n` (`.matVec`) or of
    length `m` and the matrix (`.vecMat`); `TorchOp.SOut` the result.
  * `TorchOp.denote`: `TorchLean.Tensor.contract A x _ _ [m] .matVec` and
    `Tensor.contract x A _ _ [n] .vecMat`, TorchLean's definitions at `α := ℝ`.
  * `TorchOp.translate g mono gv monov`: `some (GPUProof.Spec.matVec g mono)` at `.matVec`,
    `some (GPUProof.Spec.vecMat gv monov)` at `.vecMat`.
  * `readIn`: at `.matVec`, input `inl (i, k)` is `entry A (i, k, ())` and input `inr k` is
    `entry x (k, ())`; at `.vecMat`, input `inl i` is `entry x (i, ())` and input `inr (i, j)` is
    `entry A (i, j, ())`. `readOut`: output `i` is `entry y (i, ())` at both. Their unfoldings
    at each operation are `readIn_matVec`, `readIn_vecMat`, `readOut_matVec` and
    `readOut_vecMat`, each by `rfl`.

## Statements

* `MojoProof.Import.entry_eq` (:64), for every shape, real tensor and coordinate:
  `entry t c = t c`. By TorchLean's `toVec_apply`.
* `MojoProof.Import.entry_get2` (:70) and `entry_getScalar` (:77), for every shape, real matrix
  `A`, real vector `x` and indices: `entry A (i, k, ()) = Tensor.get2 A i k` and
  `entry x (k, ()) = x.getScalar k`. By `entry_eq` and TorchLean's `Tensor.get2_eq_apply`,
  `Tensor.getScalar_eq_apply`.
* `MojoProof.Import.entry_map_get2` (:86) and `entry_map_getScalar` (:96), in every format
  `fmt`, for every shape, matrix `A` and vector `v` of words of `fmt` and indices:
  `entry (Tensor.map Model.toReal A) (i, k, ()) = (Tensor.get2 A i k).toReal` and
  `entry (Tensor.map Model.toReal v) (k, ()) = (v.getScalar k).toReal`.
* `MojoProof.Import.matVec_eq` (:106), for every `m`, `n`, `A : Tensor ℝ [m, n]`,
  `x : Tensor ℝ [n]` and `i : Fin m`:

  ```lean
  entry (Tensor.contract A x _ _ [m] .matVec) (i, ()) =
    Matrix.mulVec (Matrix.of fun i k => entry A (i, k, ())) (fun k => entry x (k, ())) i
  ```

* `MojoProof.Import.vecMat_eq` (:121), for every `m`, `n`, `x : Tensor ℝ [m]`,
  `A : Tensor ℝ [m, n]` and `j : Fin n`:

  ```lean
  entry (Tensor.contract x A _ _ [n] .vecMat) (j, ()) =
    Matrix.vecMul (fun i => entry x (i, ())) (Matrix.of fun i j => entry A (i, j, ())) j
  ```

* `MojoProof.Import.readIn_get2` (:156), `readIn_vecMat_get2` (:167) and `readOut_getScalar`
  (:177), for every pair of grades, size `σ` and real tensors: `readIn` at `.matVec` is
  `Sum.elim (fun ik => Tensor.get2 A ik.1 ik.2) fun k => x.getScalar k`, `readIn` at `.vecMat` is
  `Sum.elim (fun i => x.getScalar i) fun ij => Tensor.get2 A ij.1 ij.2`, and `readOut` at
  `.matVec` is `fun i => y.getScalar i`.
* `MojoProof.Import.readIn_map` (:190) and `readOut_map` (:206), for every pair of grades, format
  `fmt`, size `σ`, matrix `A : Tensor (Model fmt) [σ.1, σ.2]`, vector
  `v : Tensor (Model fmt) [σ.2]` and row `i : Fin σ.1`:

  ```lean
  readIn g mono gv monov .matVec (GPUProof.Spec.matVec g mono) rfl σ
      (Tensor.map Model.toReal A, Tensor.map Model.toReal v) =
    Sum.elim (fun ik => (Tensor.get2 A ik.1 ik.2).toReal) fun k => (v.getScalar k).toReal

  readOut g mono gv monov .matVec (GPUProof.Spec.matVec g mono) rfl σ
      (TorchOp.denote .matVec σ (Tensor.map Model.toReal A, Tensor.map Model.toReal v)) i =
    ((MojoProof.Sem.matVecPairs A v i).map fun ab => ab.1.toReal * ab.2.toReal).sum
  ```

* `MojoProof.Import.torchLean g mono gv monov` (the command at :138), a `GPUProof.Importer` whose
  `eq` is `matVec_eq` at `.matVec` and `vecMat_eq` at `.vecMat`.
* `GPUProof.Importer.graded_of_holds` (GPUProof/Spec/Import.lean:94), for every importer,
  operation, proposed spec whose rule is `.graded g mono` (`hr`) and whose domain is everything
  (`hD`), size, encodings and words: `Sp.rule.Holds σ E I W` gives `Graded Imp e h g σ E I W`.
  `eq` at `x` rewrites the reading of the source's meaning to `Sp.f` at `readIn`'s entries, where
  the rule's grade holds.

## Proof

`entry_eq` is TorchLean's `toVec_apply` (the flattening at index `i` is the tensor at
`(equivFin s).symm i`) at `i = equivFin s c`. `matVec_eq` rewrites every `entry` by `entry_eq`,
so it reads `contract A x` at `(i, ())` and `A`, `x` at their coordinates. TorchLean's
`Tensor.getScalar_contract_matVec_eq_mulVec` says that `getScalar (contract A x)` is
`Matrix.mulVec (Rep.matrixEquiv ℝ m n A) (getScalar x)`; `Tensor.getScalar_eq_apply` turns each
`getScalar` into the read at `(i, ())`, and `Rep.matrixEquiv`'s entry `(i, k)` is `A (i, k, ())`
by definition, so the two sides agree by `rfl`. `vecMat_eq` rewrites the left side by
`entry_getScalar` and TorchLean's `Tensor.getScalar_contract_vecMat_eq_sum` (a `Finset.sum` of
`getScalar x i * get2 A i j`), and the right side's `Matrix.vecMul` and `dotProduct` unfold to the
same sum once `entry_eq`, `get2_eq_apply` and `getScalar_eq_apply` read every entry at its
coordinate. `torchLean`'s `eq` is the script `import_spec` generates: it takes the operation
apart, the proof `h` of `translate e = some Sp` fixes `Sp`, `funext` at an output, the unfoldings
`readIn_op`, `readOut_op` and `TorchOp.denote` by `dsimp`, and `import_fact` finds `matVec_eq`
at `.matVec` and `vecMat_eq` at `.vecMat` by their types.

The agreement lemmas are `entry_eq` and TorchLean's readers. `entry_get2` and `entry_getScalar`
are `entry_eq` then `get2_eq_apply` or `getScalar_eq_apply`; `entry_map_get2` adds TorchLean's
`Tensor.unstack_map` and `Tensor.getScalar_map`, which move the map by `Model.toReal` past the
readers. `readIn_get2`, `readIn_vecMat_get2` and `readIn_map` split the spec's input index into
its two cases and close each by one of these. `readOut_map` is `entry_getScalar` followed by
`MojoProof.Sem.matVec_cell_real` (MojoProof/Sem/Matmul.lean:225) backwards, which says that
TorchLean's real contraction at row `i` is the exact sum over `matVecPairs A v i`.

## Tests (`MojoProofTest/ImportTorchLean.lean`)

The tensors are built with TorchLean's `Tensor.Rep.ofFn`. Both sides are rewritten by `simp` or
`norm_num` and checked by the kernel; nothing is run, since the reals do not compute.

* `out23`, `spec23`, `eq23`: at 2 × 3, rows `1 2 3`, `4 5 6`, vector `1 2 3`. TorchLean's side,
  through `readOut_getScalar` and `Tensor.getScalar_contract_matVec` (its fold over
  `List.finRange`), and the spec's side, through `readIn_get2` and `Matrix.mulVec`, are both
  `14 32`; `eq23` is `eq` there.
* `out35`, `spec35`: at 3 × 5, entries `1` to `15` row by row, vector `1` to `5`: `55 130 205`.
* `mutant_transposed`, at 2 × 2, rows `1 2`, `3 4`, vector `1 0`: TorchLean's contraction is
  `1 3`, and the spec's function at the transposed reading of the matrix is `1 2`, so a transposed
  `readIn` has no `eq`.
* `outv23`, `specv23`, `eqv23`: `.vecMat` at 2 × 3, vector `1 2` and the matrix of `out23`.
  TorchLean's side, through `Tensor.getScalar_contract_vecMat`, and the spec's side, through
  `readIn_vecMat_get2` and `Matrix.vecMul`, are both `9 12 15`; `eqv23` is `eq` there.
* `vecMat35`: `.vecMat` at 3 × 5, vector `1 2 3` and the matrix of `out35`: both sides are
  `46 52 58 64 70`.
* `vecMat22`: `.vecMat` at 2 × 2, vector `1 0` and the matrix of `mutant_transposed`: both sides
  are `1 2`. The matrix-vector product at the same tensors is `1 3` (`mutant_transposed`), so a
  `translate` proposing `GPUProof.Spec.matVec` for `.vecMat` would have no `eq`.
* `mutant_vecMat_transposed`, at the same tensors: `GPUProof.Spec.vecMat`'s function at the
  reading of the matrix transposed (`inr (i, j)` from entry `(j, i)`) is `1 3`, not TorchLean's
  `1 2`, so a transposed `readIn` at `.vecMat` has no `eq`.
* `translate_vecMat`: `translate .vecMat` is `some (GPUProof.Spec.vecMat gv monov)` (by `rfl`).
* `cell_spec`, in every format and at every size: the exact sum of the products of the real
  values of `MojoProof.Sem.matVecPairs A v i` is `GPUProof.Spec.matVec`'s function at row `i`
  of the words' real values read by `get2` and `getScalar`. It is `eq` at the maps of `A` and `v`
  by `Model.toReal`, read through `readOut_map` and `readIn_map`: the form a statement relating
  the gemv kernel's words to the imported spec takes.

## The kernels' words through the importer

A kernel whose output words meet a spec's graded rule meets `Graded` at the operation the
importer translates to that spec, at the same words, by `graded_of_holds`. Two kernels' words are
stated so, each as `MojoProof.Tile.Loads` (MojoProof/Tile/Words.lean: the outputs load as
binary32 words that meet a property) at `Graded` of `torchLean`:

* `MojoProofTest.GemvTorch.TorchRows`, gemv_kernel's rows at `.matVec` and the grade
  `GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉`, with `torchRows_of_rule` (the rows of
  `MojoProofTest.GemvSound.RowsRule` meet it) and `gemv_torchLean` (gemv_kernel's
  `GPUProof.Kernel.Sound` for it). Before `Graded`, `TorchRows` quantified over the real matrix
  `A'` and vector `x'` one after the other; `Graded` quantifies over the pair `(A', x')`, the
  source's input. The two are equivalent by `Prod.forall`, not by definition, and no statement
  takes the old form.
* `MojoProofTest.GevmSpec.TorchCols`, gevm_kernel's columns at `.vecMat` and the grade
  `GPUProof.vecMatLaneGrade 32 5 fun m => ⌈m / 32⌉`, with `torchCols_of_rule` (the columns of
  `MojoProofTest.GevmSpec.ColsRule` meet it) and the test `torch_3x2` (binary32, width 32, at
  3 × 2). gevm_kernel's run is not proved, so it has no `Kernel.Sound` for `TorchCols`.

## Where the Lean form departs from the design

1. **The structure is core and the instance is in `MojoProof`.** `spec.md` planned a library of
   its own (`GPUProofImport`). `GPUProof.Importer` names no front end and imports only
   `GPUProof.Spec.Basic`, so it is a core module (`MojoProofTest/GPUProof/Imports.lean` lists it,
   and TorchLean stays out of the core's closure). The TorchLean instance is in `lean_lib
   MojoProof` (`MojoProof/Import/`), which already imports TorchLean, so no new library and no
   new imports test are needed.
2. **`Sz` is per operation** (`Sz : Src → Type`), so that one importer can hold operations whose
   sizes differ (a reduction's `n`, a matrix product's `(m, n)`); here both are `ℕ × ℕ`.
3. **`readIn` and `readOut` take the proof `translate e = some Sp`.** The entries' index and
   entry types are `Sp`'s (`Sp.In σ`, `Sp.dIn σ`), so the reading exists only for a proposed
   spec.
4. **The importer takes the grades.** `GPUProof.Spec.matVec g mono` and
   `GPUProof.Spec.vecMat gv monov` take their grades (`spec.md`, departure 5), so
   `torchLean g mono gv monov` proposes each at a grade its user names, the kernel's proved
   bound. The two grades are separate parameters, since the specs' index types differ
   (`Fin m × Fin n ⊕ Fin n` against `Fin m ⊕ Fin m × Fin n`); a statement about one operation
   still names both, and holds for every grade of the other.
5. **`denote` is the contraction, not TorchLean's op table.** TorchLean's `TorchLean.Op` has
   `matmul` (with batch prefixes and vector flags) and `contract`; `TorchOp` is the importer's own
   two-operation type, and its meaning is `Tensor.contract` with the proofs `.matVec` and
   `.vecMat`, the definitions `TorchLean.Tensor.getScalar_contract_matVec_eq_mulVec` is about.
6. **The row-major index is `Shape.Coord.equivFin`.** TorchLean v1.5 has no
   `TorchLean.Matmul.idxMN` and no `Matmul.toVec_idxMN`; `equivFin` is TorchLean's row-major
   equivalence of coordinates and flat indices, and `toVec_apply` is stated at it. `readOut` also
   reads through `toVecₗᵢ`, not `getScalar`, so that both readings are one definition (`entry`).
7. **`matVec_eq` is `MojoProof.Import.matVec_eq`, through `entry`.** The design's
   `TorchLean.matVec_eq` would add a name to TorchLean's namespace. The plan's form through
   `getScalar` and `get2` is TorchLean's own `getScalar_contract_matVec_eq_mulVec` up to
   `Rep.matrixEquiv`; the form through `entry` is the one `readIn` and `readOut` meet. The two
   are connected once, in the library: `entry_get2` and `entry_getScalar` on the reals,
   `readIn_get2` and `readOut_getScalar` at the importer, and `readIn_map` and `readOut_map` at
   the real values of words, the reading of `MojoProof.Sem.matVecPairs`.
8. **No operation is refused.** Both operations of `TorchOp` propose a spec, so every operation
   is in the fragment and no test checks a refusal. An operation outside the fragment would be a
   further constructor with `translate` at `none`, and a test that `translate` refuses it.
9. **`Dom` is everything.** The domains of `GPUProof.Spec.matVec` and `GPUProof.Spec.vecMat` are
   `True` (both are `GPUProof.Spec.ofReal`), so `eq`'s domain premise is not used at this
   instance. `MojoProofTest/ImportDom.lean` tests the command at a spec whose domain is not
   everything.

## The `import_spec` command

`MojoProof/Import/Command.lean` holds the command and its tactic; `torchLean` and its pieces are
one use of it (MojoProof/Import/TorchLean.lean:138):

```lean
import_spec torchLean g mono gv monov : TorchOp (σ : ℕ × ℕ) where
  /-- `TorchLean.Tensor.contract A x _ _ [m] .matVec`. -/
  | matVec (A : Tensor ℝ [σ.1, σ.2]) (x : Tensor ℝ [σ.2]) → (y : Tensor ℝ [σ.1]) :=
      Tensor.contract A x _ _ [σ.1] .matVec
    ↦ GPUProof.Spec.matVec g mono
    from Sum.elim (fun ik => entry A (ik.1, ik.2, ())) fun k => entry x (k, ())
    at fun i => entry y (i, ())
  | vecMat …
```

After `import_spec` come the importer's name, the section variables the specs mention, in their
order, the type of operations and the size, one type for every operation. Each operation gives
its docstring, its name, its input tensors as explicit binders, its output tensor, its meaning
(after `:=`), the spec it is proposed as (after `↦`), the reading of its inputs as the spec's
inputs (after `from`) and that of its output as the spec's outputs (after `at`). The command
declares, each with a docstring quoting the given terms:

* the inductive type of operations, one constructor per operation, with its docstring;
* the abbreviations `SIn` (the product of the input types) and `SOut` (the output type);
* `denote` (the meaning at the tuple of inputs) and `translate` (`some` of the spec at each
  operation), in the type's namespace;
* `readIn` and `readOut`, of types `GPUProof.Importer.ReadIn` and `GPUProof.Importer.ReadOut`, at
  each operation and the proof `rfl`, with the unfoldings `readIn_op` and `readOut_op` by `rfl`;
* the importer, whose `eq` is a generated script: at each operation it introduces the spec, the
  proof `h`, the size, the inputs as the tuple and the hypothesis that their reading is in the
  spec's domain (MojoProof/Import/Command.lean:315), fixes the spec by `cases h`, takes `funext` at
  an output, unfolds `readIn_op`, `readOut_op` and `denote` by `dsimp only` in the goal, and calls
  `import_fact`, with the command's `using` list if it has one.

**`import_fact`** (MojoProof/Import/Command.lean:143) closes an equation with a theorem found by
its type: first the theorems named after `using`, in their order, then the current file's
theorems not named there, in declaration order (`localFacts`, :66). Each is tried at fresh
metavariables for its arguments (`closesBy`, :112). Its conclusion must be definitionally the
goal; then each argument still open whose type is a proposition, a premise the conclusion does
not determine, is given a hypothesis of the goal's context of that type, up to definitional
unfolding (`MVarId.assumptionCore`, the last such hypothesis declared). The first theorem whose
arguments are then all assigned is used; otherwise nothing is assigned and the next is tried. In
the generated `eq` case the context holds the domain hypothesis, so a bridge whose premise is the
spec's domain, as stated by the spec, closes it. Two cheap tests come first, so that a theorem
about the same terms with another right side is not unfolded far: its left side is the goal's up
to reducible unfolding, and the head of its right side is among the heads of the goal's right
side and of its successive unfoldings, or the other way round (`unfoldHeads`, :76). In the left
side's match only the terms are compared at reducible unfolding: when an argument is assigned a
term of the goal, its type and the term's are compared at default transparency (the match runs
with `backward.isDefEq.respectTransparency.types` off; Lean has it on by default, and then
compares them at `.implicit` transparency, which does not unfold `diffInt`). So a bridge stated
at `Fin n` closes a goal whose output has type `diffInt.Out n`, since `Fin n` is that type once
`diffInt` is unfolded, and a bridge need not be stated at the spec's own types; one stated at
`Fin (0 + n)`, which is `Fin n` only by `Nat.zero_add`, is refused. The types are small terms, and
the terms, where a bridge about other terms differs, are still compared at reducible unfolding.
At `torchLean` the `.matVec` goal is `matVec_eq`'s conclusion with the spec's function on the
right; `entry_eq` has the same left side, and its right side, the tensor at the coordinate, has a
head no unfolding of the spec's function reaches, so it is refused before the unifier unfolds
TorchLean's contraction.

**`using`.** `import_spec … : Src (σ : Sz) using t₁ … tₘ where …` passes `using t₁ … tₘ` to every
`eq` case's `import_fact`; each name must be a declaration, of the current file or of an imported
module, or the command fails at it. Bridges of other modules are given by this list rather than by
an attribute marking theorems as bridges: the theorems an `eq` case may use are written at the
command, as `simp only [...]` writes its lemmas; nothing outside the command (no index of marked
theorems across imports, no environment extension) decides which theorems are tried, so the cost
of a case does not grow with the imports and the result does not depend on which modules are
loaded; and the test of a bridge's effect is the same command without `using`. The candidates
listed go through the same two cheap tests and the same unification.

**Refusal.** If `import_fact` fails at some operation, the importer is not declared and the
command warns with the open goals; the other declarations stay, so the importer can be written by
hand from them. The importer is elaborated with `Elab.async` off, so that its errors are known
before it is kept. Names the command introduces inside its terms and proofs are hygienic; the
declared names are the given ones and `readIn`, `readOut`, `readIn_op`, `readOut_op`, so one
namespace holds one importer.

**Against the plan this section held before**, the command does less:

1. It does not read a TorchLean definition: the tensors' types, the meaning and the readings are
   written at the command, which only arranges them into the importer's fields. Deriving the
   readings from the definition's shapes needs, for each spec index, the coordinate it names in
   a tensor, which is what the `from` and `at` terms say.
2. No `none` clause: every operation proposes a spec (departure 8).
3. No tests are generated; `MojoProofTest/ImportSpec.lean` tests the command.
4. The facts `import_fact` tries are the current file's theorems and those named after `using`,
   not TorchLean's lemmas or the spec's unfolding: an `eq` case closes when its goal is proved
   first, here `matVec_eq` and `vecMat_eq`, which were proved by hand before and are kept.

## Tests (`MojoProofTest/ImportSpec.lean`)

One operation, the sum of a real vector, is proposed as `GPUProof.Spec.sumReal g` with the
vector read backwards (input `i` is entry `Fin.rev i`), so its `eq` needs a theorem, for every
grade `g`.

* `Open`: the command before any theorem closes `eq`. It warns with the open goal
  `∑ i, v i = (GPUProof.Spec.sumReal g mono).f n (fun i => v (Fin.rev i)) o` and
  `Open.sumImp` is unknown (both pinned by `#guard_msgs`); the readings are declared, and
  `readIn2` reads input `0` of the vector `1 2` as `2`.
* `sum_rev`: the sum does not depend on the order (Mathlib's `Fintype.sum_equiv` at
  `Fin.revPerm`).
* `Good`: the same command after `sum_rev` declares `sumImp`; `eq2` and `eq5` are its `eq` at
  the vectors `1 2` and `1 2 3 4 5`, and `out2`, `out5` their sums `3` and `15`.
* `Twice`: the mutant meaning `2 * ∑ i, v i` is refused with its open goal, since `sum_rev`'s
  left side is not twice a sum.

## Tests (`MojoProofTest/ImportFacts.lean`, `MojoProofTest/ImportDom.lean`)

`MojoProofTest/ImportFacts.lean` declares the test spec `diffInt`: at every size `n`, the
difference `a - b` of two integer vectors of length `n` (inputs `inl i` and `inr i`), meant where
`b i ≤ a i` at every `i`. Its bridges, `sub_cast` (premise: that domain) and `sub_strict` (premise:
`b i < a i`), say that the truncated difference of two natural vectors, read as integers, is
`diffInt`'s function, with the output at type `Fin n`, not the goal's `diffInt.Out n`;
`sub_zero_add` says it at size `0 + n`, over `Fin (0 + n)`. `MojoProofTest/ImportDom.lean`
imports it and proposes the truncated difference as `diffInt`, with no hand-written clause and no
local restatement of the bridges.

* `Bare`: the command without `using`. No theorem of its file closes `eq`, so it warns with the
  open goal `↑((a - b) o) = diffInt.f n (Sum.elim (fun i => ↑(a i)) fun i => ↑(b i)) o` and
  `Bare.subImp` is unknown (both pinned by `#guard_msgs`).
* `Good`: the command `using sub_cast` declares `subImp`, its premise taken from the domain
  hypothesis. `eq3` and `eq5` are its `eq` at `a = 5 2 7`, `b = 1 2 3` and at `a = 9 4 6 1 8`,
  `b = 0 4 2 1 3`, their domain premises by `decide`; `out3` and `out5` are the outputs `4 0 4`
  and `9 0 4 0 5` (by `decide`). `off3` and `off5` are inputs out of the domain at sizes 3 and 5;
  at `off3`'s, `a = 1 2 7`, `b = 2 2 3`, the truncated difference is `0 0 4` and `diffInt`'s
  function `-1 0 4`, so the equation holds only on the domain.
* `Strict`: the command `using sub_strict` is refused with the open goal (pinned): the context
  gives `b i ≤ a i`, not `b i < a i`.
* `Far`: the command `using sub_zero_add` is refused with the open goal (pinned): its vectors'
  type `Fin (0 + n) → ℕ` is not the goal's `Fin n → ℕ` up to unfolding.

## Cost

`MojoProof.Import.TorchLean` imports `TorchLean.NN.FDeriv.TensorVectorization` (for `toVecₗᵢ`
and `toVec_apply`) and `TorchLean.Tensor.LinearAlgebra.Real` (for
`getScalar_contract_matVec_eq_mulVec`). Loading these two alone takes 7.4 s and 3.8 GB, loading
`GPUProof.Spec.Linear` alone 6.6 s and 3.0 GB, and both together 8.6 s and 3.9 GB, most of it
Mathlib's shared modules. Building the module takes 3.4 s.

It also imports `MojoProof.Sem.Matmul` (for `matVecPairs` and `matVec_cell_real`, used by
`readOut_map`). Measured before adding it, a file importing `MojoProof.Import.TorchLean` loaded
in 7.00 s and 3,853,164 KB, and one importing `MojoProof.Sem.Matmul` as well in 6.98 s and
3,910,676 KB: no time and 57 MB (logs/s57b-r2base.log, logs/s57b-r2mm.log).

`MojoProof.Import.Command` imports only `Lean` and `GPUProof.Spec.Import` and builds in 4.5 s;
`MojoProof.Import.TorchLean` with the command builds in 3.5 s, as before, and the command's tests
in 2.7 s. With the premises from the context and `using`, rebuilding the command and everything
that imports it took 26 s of wall time and 3.99 GB at most, with the modules built side by side:
the command 9.5 s, `MojoProof.Import.TorchLean` 6.7 s, the tests 2.9 s (`ImportSpec`), 4.4 s
(`ImportTorchLean`), 6.5 s (`ImportFacts`) and 2.9 s (`ImportDom`). `torchLean`'s bridges have
no premises, so its `eq` cases search no hypothesis. With the arguments' types compared at default
transparency, the same rebuild with `MojoProofTest.GemvTorch` took 23.5 s and 4.03 GB at most: the
command 5.2 s, `MojoProof.Import.TorchLean` 7.1 s, the tests 2.9 s (`ImportSpec`), 6.0 s
(`ImportTorchLean`), 2.8 s (`ImportFacts`) and 2.9 s (`ImportDom`), and `GemvTorch` 4.7 s.

## Trust

No TorchLean evaluator is run or trusted: the tests rewrite TorchLean's definitions in the kernel,
and no compiled TorchLean code, `Float` runtime or `#eval` is used. What is assumed is that
TorchLean's definitions `Tensor.contract … .matVec` and `Tensor.contract … .vecMat` at the reals
are the meaning of the source operations: a statement through `torchLean` is about those
definitions.
