# What is proved

MojoProof reads the LLVM IR file that `mojo build --emit llvm` writes for each GPU kernel, gives
it a semantics in Lean (integers, byte memory, threads, barriers, warp shuffles, and IEEE floats
through [FloatLib](https://github.com/lean-dojo/FloatLib)), and proves theorems about it. The
semantics leaves two things to choices: an address choice (where the blocks a launch allocates
are placed) and a float choice (the payload of each NaN result, whether and how a `contract`
operation is fused, and the other float freedoms of [TRUST.md](TRUST.md) T7). A kernel theorem (`Kernel.Sound`) says that, at every address choice and float
choice it admits, the launch starts and has no undefined behavior, no unsupported operation, no
data race and no deadlock, that no write touches bytes that a load marked `!invariant.load` reads,
that every run terminates, that every schedule gives the same result, and that the result meets
the spec. Each line below gives its scope (every program, a family of kernels, one named kernel,
one intrinsic, every formula or every float format) and the Lean declaration.

A spec-free kernel theorem (`Kernel.Safe`, MojoProof/Kernels/Safe.lean) is `Kernel.Sound` at the
relation that holds of every result: all of the above but the spec. Every kernel theorem gives it
(`Kernel.Safe.of_sound`, for every program, kernel, launch, arguments, memory, admission,
observation and relation); its instance is a test at `vector_addition`
(MojoProofTest/SafeVadd.lean `vadd_safe`). The spec-free mode proves it from the function alone,
with no specification: `Kernel.safe_of_admits` (MojoProof/Kernels/SafeCmd.lean), for every
program, kernel and list of paths that `coversEntry` accepts and every launch, arguments and
memory whose pointer bytes are known, gives `Kernel.Safe` for the observation of the blocks at the
admission `Kernel.Admits`: the start succeeds, the block checker accepts each thread's path, and
the trace has no data race and keeps `!invariant.load`'s promise, decided by evaluation at each
choice (not a formula of the sizes). The command `mojo_safe` applies it to one kernel; it proves
the two `bitonic_global_step` kernels of Modular's tests (MojoProofTest/SweepSafe.lean
`bitonicT.safe`, `bitonicF.safe`, one kernel each, every launch of the admission, each with a
witness at one valid launch), the sweep's second round ([proofs/safe.md](proofs/safe.md),
roadmap/kernels/sweep.tsv: 2 of 820 attempts proved; a loop, a warp shuffle or a CTA barrier stops
the rest). roadmap/llvm-ir/kinds.tsv gives each soundness term of each listed theorem its kind,
`correct` or `safe`, and the coverage history counts only the `correct` ones.

The semantics follows LLVM's LangRef where the corpus reaches it. A `byval` copy lies where
LangRef's allocated objects may (`place`, `launchArgs_placed`): at a nonzero aligned address `x`
with `x + size < 2 ^ w` and `size < 2 ^ (w - 1)` for `w`-bit pointers; an address choice outside
these rules is moved to the lowest placed address, and every placed aligned address is some choice's
(`place_onto`). A copy with no placed address, or whose type has padding (LangRef copies the bytes,
the semantics re-encodes the typed value), is unsupported (`Func.byvalPlaced`). A store to a stack
object outside its lifetime, and every access to a returned frame's object, is undefined behavior
(`Mem.check`); a load from the function's own `alloca` outside its lifetime, poison in LangRef, is
unsupported (`deadLoad`); a callee's load from its caller's `alloca` outside its lifetime is still
undefined behavior, stricter than LangRef ([TRUST.md](TRUST.md) T7). A lifetime marker takes poison
or a value an `alloca` of the function defines (`Func.lifetimeOk`); a struct index is an `i32`
constant (the importer and the evaluator refuse any other) and selects its field by its value; an
`f0x` literal has exactly its type's number of digits. `getelementptr nuw` reads its indices
unsigned. `volatile` accesses, string attributes other than those of `strAttrs`, and a launch with
another number of arguments than the kernel's parameters or a block beyond its `nvvm.maxntid` (the
product of its sides) or `nvvm.reqntid` (each side), given as string attributes or as `i32`
`!nvvm.annotations` entries, are unsupported, and so is any other annotation key than `kernel`
(`Func.checkLaunch`). `griddepcontrol.wait` and `griddepcontrol.launch_dependents` do nothing: a
launch is one grid with no prerequisite or dependent grid in flight, and a module in which a
function calls either while its target (its own `"target-cpu"`, else the module's: the one value its
functions agree on) is missing, ambiguous or below `"sm_90"` is unsupported (`Func.check`,
`Func.griddepBad`; [TRUST.md](TRUST.md) T19).

- **The core** (`GPUProof/`), for every machine: a signature `Sig`, trace events, a race check
  `racy`, one pass that gives each position the set of the positions that happen before it and
  checks each access against the earlier writes and, when it writes, the earlier others, which
  decides `Racy` (`racy_iff`), happens-before `HB` decided by `hb` (`hb_iff`), `Ordered` decided by
  `ordered` (`ordered_iff`), the runs and `Clean`; one test machine with `Clean` of a family of its
  programs at every size (MojoProofTest/GPUProof/Clean.lean `own_clean`). Theorem 0
  (`Sound.of_one_run`): for every machine with `OneRun`, one run from a good start to a done state
  that is not bad makes the start sound; `Clean.of_lift`, for every machine and every observation of
  the states: one run along a projection whose steps lift, to a done state outside a bad set that is
  persistent and confluent (up to an equivalence that keeps `Done` and the observation), makes the
  first state's image clean (`Clean`) and gives every done state reachable from it the observation
  of the run's last state, with no good start. `Sound.of_lift` is its case at an observation of the
  bytes (the first state's image is sound when the last state's observation meets `R`), and
  `Sound.of_one_run` is the case of `Sound.of_lift` at the states reachable from a good start.
  MojoProof's `Grid.sound_of_one_run` is its case at `sig`, with the grid's whole memory as the
  observation (`Grid.Sound.of_clean` carries `Clean` back to `Grid.Sound`); its corollary
  `Grid.sound_commuting` proves a grid sound, for every program, launch and memory, when each thread
  returns in one step and the threads' changes of memory are maps that commute and keep the trace
  (tested at 2 and 3 threads that end their allocas, `MojoProofTest.Close.sound_dead`), and
  `Grid.sound_returning` is its case with no change of memory. MojoProof's grid machine
  is a machine of the core (`sig`) with `OneRun sig` and `Levels sig`, and its bad grids are the
  core's `Bad` at `sig` (MojoProof has no `Grid.Bad`; `Grid.raceEnabled_iff` reads the core's
  `RaceEnabled` in the grid's terms); its faults, and so `Grid.Safe` and `Grid.Sound`, are the
  core's `Faults` at `sig`
  (`Grid.faults_iff`), and its done grids and promise of `!invariant.load` are the core's `Done` and
  `kept` at `sig` (`Grid.done_iff`, `kept_sig_iff`), and two atomic updates of the same bytes are
  exempt from the race check only for a commuting operation ([docs/proofs/core.md](proofs/core.md),
  [docs/proofs/theorem0.md](proofs/theorem0.md)). The test machine has `Levels` at every launch. For
  every machine with `Levels`, happens-before on a laminar trace is sharing an agent or a rendezvous
  between them (`HB.laminar_iff`); for every machine, a separated use map that admits every access
  shows that a trace has no race (`racy_eq_false_of_uses`), and `kept` decides `Kept` (`kept_iff`)
  ([docs/proofs/laminar.md](proofs/laminar.md)). The tactic `racy_by_chunks` proves
  `racy S tr = false` at a concrete trace by chunks that the kernel checks (from `scan_add`, for
  every machine), tested on the toy's ring at two sizes. On a machine that proves its placement
  injective (`Sig.placeInj`, a proof of the law `PlaceInj`), `racy` compares two accesses by their
  buffers and intervals of offsets (`Sig.share_iff`, `Access.meets_iff`, for every machine). At
  one program (vector_addition) at one launch through `sig`, on the trace the evaluator produced,
  which the kernel checks is the run's (`MojoProofTest.RacySig.trSig_run`), `decide +kernel`
  proves in one proof each that the trace is race free and keeps its frozen reads
  (`MojoProofTest.RacySig.vadd_sig_racy`, `MojoProofTest.RacySig.vadd_sig_kept`), so that run's
  trace is race free (`MojoProofTest.RacySig.vadd_run_racy`). The spec layer states what a kernel computes: specs at every size with float
  rules, and the matrix-vector, vector-matrix and sum specs; an encoding
  names its word positions and the NaN words at each; its words equal up to NaN payloads at every
  position decode alike, and a NaN leaves some entry with no value (`Encoding.decode_isNaN`), so at
  inputs in the domain a `bitwise` rule asks for its word function's words
  (`FloatRule.Holds.bitwise_eq`), and its outputs decode as its word function's
  (`FloatRule.Holds.bitwise`), and in every IEEE format a dyadic within a grade's
  magnitude, at most the format's largest finite value, rounds to a finite word
  (`Approx.finite_of_le`); the grade of a dot product over `W` lanes of at most `L` terms added
  along a tree of depth `d` (`laneGrade`; error `((1 + u) ^ (L + d) - 1) S + W (1 + u) ^ d (2 + u)
  η ((1 + u) ^ L - 1) / u` plus the inputs' error terms, magnitude at least each input grade's,
  `laneGrade_mag`, monotone, `laneGrade_mono`), with the dot product's grade `dotGrade` its one-lane
  case at depth 0, and the matrix-vector and vector-matrix grades `laneVecGrade` and
  `vecMatLaneGrade` from it, by definition, each `laneGrade` where every input grade it reads has
  magnitude at most its input format's largest value and elsewhere a grade that claims nothing
  (`laneGradeIn`, through `Grade.onlyIf`), with `matVecGrade` and `vecMatGrade` their one-lane
  cases, for every length, with the exact dot
  bound below it (`dotBound_le_dotGrade`) and the loop's own bound as its error (`dotGrade_ieee`:
  `MojoProof.Sem.dotLoopBound`, with `(1 + u) ^ n - 1` on the sum, `dotLoop_error_zero`). Two specs
  compose along a wiring of the second's inputs to the first's outputs and extra inputs
  (`GPUProof.Wiring`): for every two graded rules, wiring and encodings of the first spec's words,
  the extra inputs and the outputs, behaviors that meet each meet the composite at the grade
  `Wiring.grade`, at the encodings built from those (`GPUProof.MeetsAt.comp`); for every two
  `exact` rules the same with the `exact` rule, given that the intermediate is representable
  where the composite's rule makes a claim (`GPUProof.MeetsAt.comp_exact`, `Wiring.MidRep`;
  without it the composition fails, `MojoProofTest.GPUProof.SpecComp.sumNeg_refused`). With the
  intermediate's encoding chosen at each composite encoding as data of the behavior
  (`Wiring.behavMid`), behaviors that meet their parts at every encoding meet the composite at
  every encoding (`GPUProof.Meets.comp`, `GPUProof.Meets.comp_exact`). An `exact` rule then a
  graded one compose at a graded rule that claims only where the first inputs decode exactly
  (`Wiring.gradeEx`), given the first outputs' representability there
  (`GPUProof.MeetsAt.comp_exact_graded`, `GPUProof.Meets.comp_exact_graded`, `Wiring.FstRep`).
  Without that representability the composition fails
  (`MojoProofTest.GPUProof.SpecComp.sumNegG_refused`). Both use
  `GPUProof.MeetsAt.comp_graded_of_dec` (a first stage whose outputs decode to the first spec's
  function where the first inputs decode exactly, then a graded rule), as does a `bitwise` rule then
  a graded one (`GPUProof.MeetsAt.comp_bitwise_graded`). A `bitwise` rule and an `exact` one compose
  in either order (`GPUProof.MeetsAt.comp_bitwise_exact`; `GPUProof.MeetsAt.comp_exact_bitwise`
  given `Wiring.MidRep`, without which it fails, `negZ_refused`). Two `bitwise` rules compose at the
  composed word function `Wiring.bitW` when the second word function respects NaN payloads
  (`GPUProof.MeetsAt.comp_bitwise`), and without that the composition is false (`nanIdSq_refused`,
  `nanIdSq_noresp`). A graded rule then an `exact` one composes through a modulus of continuity of the
  second spec's function (`GPUProof.Spec.Modulus`: within the first grades, the function moves
  within the modulus's grade, stays in the domain and has output words), which turns its `exact`
  rule into the graded rule `GPUProof.Spec.modGrade` (`GPUProof.MeetsAt.graded_of_exact`); the
  composite then meets `Wiring.grade` at the two grades, for every pair of specs, wiring and
  encodings (`GPUProof.MeetsAt.comp_graded_exact`, GPUProof/Spec/CompGraded.lean), and for
  behaviors that meet the two specs at every encoding, at every composite encoding at which the
  modulus is one (`GPUProof.Meets.comp_graded_exact`); an output encoding with no word of the
  second function's value has no modulus, so the composite is not claimed there. Test
  MojoProofTest/GPUProof/SpecCompGraded.lean, `Spec.matVec` then an exact sum: every premise but
  the two behaviors' `MeetsAt` is proved at every size, and every premise but their `Meets` at
  every composite input encoding (`mvSum_meetsAll`); at the behaviors `ruleK` and input words
  `1`, at every size with `n ≤ 127`, the composite has an output, the word `m n`
  (`mvSum_ones_mem`), and every output decodes to `m n` (`mvSum_ones`); a modulus too small is
  refused (`sumZero_refused`); at 8-bit inputs and 16-bit outputs the exact words meet
  `matVecGrade`'s rule at sizes `(1, 1)` and `(2, 5)` (`wide_holds`, `wide_holds_2x5`, by
  `laneVecGrade_holds`, which has no premise on the formats) and `vecMatGrade`'s at `(5, 2)`
  (`wide_vecMat`), so `ruleK` has an output there; the mutant grade with no guard on the input
  grades (`rawGrade`) is met by no words at `(1, 1)` (`wide_refused`). It needs no bound of an
  input's magnitude by an output's:
  that condition is what one NaN-keeping kernel needs to meet one graded rule
  (`MojoProofTest.GPUProof.SpecComp.nan_needs_mag`, `forget_refused`). Instance: `D = A·x + e` from
  `Spec.matVec` and an addition with `e` as the extra input, both meets as hypotheses (`dax_meets`).
  Concrete specs' outputs are finite by instance search (`GPUProof.Spec.matVec.fintypeOut` and the
  like, `Wiring.spec.fintypeOut`). A spec written as `GPUProof.Spec.ofReal` or an `abbrev` of one
  has finite outputs by instance search (`GPUProof.Spec.ofReal.fintypeOut`). The TorchLean importer
  for the matrix-vector and vector-matrix products (`MojoProof.Import.torchLean`, a
  `GPUProof.Importer`, docs/proofs/import.md), declared by the `import_spec` command
  (`MojoProof/Import/Command.lean`; an importer from its operations, its `eq` closed at each
  operation by a theorem of the file found by its type, the arguments' types compared at default
  transparency (a bridge at `Fin n` closes a goal at `Sp.Out n`, one at `Fin (0 + n)` does not;
  MojoProofTest/ImportDom.lean), refused with the open goal otherwise; tests
  in MojoProofTest/ImportSpec.lean at sizes 2 and 5): at every shape, TorchLean's `Tensor.contract …
  .matVec` and `Tensor.contract … .vecMat` at the reals, read through `toVecₗᵢ`, are
  `GPUProof.Spec.matVec`'s and `GPUProof.Spec.vecMat`'s functions at the tensors read the same
  way (`MojoProof.Import.matVec_eq`, `MojoProof.Import.vecMat_eq`). In every format, the
  importer reads the real values of a matrix and a vector of words as
  `MojoProof.Sem.matVecPairs` reads the words, and its output at row `i` is the exact sum over
  `matVecPairs` (`MojoProof.Import.readIn_map`, `MojoProof.Import.readOut_map`). It is tested at
  2 × 3 and 3 × 5 for each product and at 2 × 2 for `.vecMat`, with a transposed reading of each
  as a mutant. For every importer, source and spec with a graded rule, words that meet the rule
  are within the grade of the importer's denotation at every reading of the inputs
  (`GPUProof.Importer.Graded`, `graded_of_holds`); `torchRows_of_rule` and `torchCols_of_rule`
  are its cases. For every binary interchange format, flag, oracle sequences,
  lane count, length, tree over the lanes and input grade, lanes' dot loops added along the tree are `GPUProof.Approx` at
  `laneGrade` (`MojoProof.Sem.treeDot_approx`), and so is the dot loop at `dotGrade`
  (`dotLoop_approx`, its one-leaf case, with its error part `dotLoop_error_graded` and its
  finiteness `isFinite_dotLoop`) and every lane of a butterfly over `2 ^ k` strided loops at
  depth `k` (`MojoProof.Tile.bfly_approx`, `groupDot_approx`). Every kernel of `mojo_kernel`'s
  `mat` clause whose second matrix has one row meets `Spec.matVec matVecGrade`'s rule at its
  observed memory: in every observation of an admitted complete run, the floats of the output
  block at the rows' cells meet the rule (`MojoProof.Tile.mat_holds`; instance: the naive matmul
  family, `MojoProofTest.TileNaive.naive_holds`, its two words computed at one launch in
  `naive_words`). Its behaviors, the observed output words of the setups it runs on, meet the
  spec through `GPUProof.MeetsAt` when every setup fits (`MojoProof.Tile.kernelRows_meetsAt`; the
  naive family at every row stride, `MojoProofTest.TileNaive.naive_meetsAt`, with a behavior at
  every size within its bounds and every input words, `naive_rows`). Strided lanes added along a
  tree per row meet `Spec.matVec (laneVecGrade W depth ⌈n / W⌉)` through `MeetsAt` for every IEEE
  format, lane count and tree (`MojoProof.Tile.rowTrees_meetsAt`), and gemv's word per row meets
  `Spec.matVec (laneVecGrade (2 ^ k) k ⌈n / 2 ^ k⌉)`'s rule as its case at lane 0's butterfly
  tree (`groupDot_holds`), and so does lane 0's word after the semantics' `fadd` rounds, each
  through `deliver` with its own oracle number, from the lanes' strided loops
  (`MojoProof.Tile.bflyDeliver_holds`), each loop taken round by round in the IR's lane order
  (`MojoProof.Sem.dotLoop_take_stride`).
  Words that are NaN-equal per row to `groupDot` meet `Spec.matVec`'s rule at `laneVecGrade`
  (`MojoProof.Tile.groupDot_rows_holds`, for every IEEE format, size, lane count and oracle), with
  `groupDot_holds`, `bflyDeliver_holds` and the warp's `warpDot` per row (`warpDot_matVec_holds`)
  its cases. The words a warp stores per output, their relation to `warpDot` and a rule's words
  are shared forms (`MojoProof/Tile/Words.lean`: `warpObs`, `WarpWords`, `Loads`), and gemv's
  `rowsObs`, `RowsDot`, `RowsRule` and `TorchRows` are their cases. gemv_kernel's
  `GPUProof.Kernel.Sound` against
  `Spec.matVec (laneVecGrade 32 5 ⌈n / 32⌉)` (the matrix-vector spec, at `k = 5`) is proved for
  one IR file, the gemv_kernel specialization
  tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll, at every
  valid launch with `y` and `z` sizes 1 whose block's `x` size 32 divides and whose warps' rows
  cover the matrix's rows (`MojoProofTest.GemvSound.kernel_sound`, below). For the vector-matrix
  product, `groupDot k` per column, and the warp's `warpDot` per column, meet
  `Spec.vecMat (vecMatLaneGrade (2 ^ k) k ⌈m / 2 ^ k⌉)`'s rule at the uniform encoding
  `MojoProof.Tile.vecMatEnc` for every IEEE format and size (`MojoProof.Tile.groupDot_cols_holds`,
  `warpDot_vecMat_holds`; tests at 3 × 5 in binary32 and 40 × 2 in binary64, and a grade one
  subnormal spacing tighter refused, `MojoProofTest.TileLanes.col_mutant`). gevm_kernel's spec
  side is in
  the same forms (`MojoProofTest/GevmSpec.lean`: `colsObs`, `ColsRule` at
  `Spec.vecMat (vecMatLaneGrade 32 5 ⌈m / 32⌉)`, `cols_holds` from `WarpWords` at `vecMatPairs`,
  and `TorchCols` with `torchCols_of_rule`), tested in binary32 at 3 × 2 and 40 × 3, with a word
  one ulp off (not in `WarpWords`) and a load that is not a binary32 word (not in `ColsRule`) as
  mutants (`off_ulp`, `refused`). gevm_kernel's `GPUProof.Kernel.Sound` against `Spec.vecMat` is
  proved for the one IR file
  (tests/corpus/gemv/gemv_f32_gevm_kernel_float32_float32_float32_1024_1308aaae.nvptx.ll), at
  every valid launch with 1024 threads per block in `x`, a one-dimensional grid and
  `N = 32 · L.grid .x`, every `K` with `32 ∣ K` and every `N`, `K < 2 ^ 31` with `K N < 2 ^ 29`,
  and every closed caller memory with a writable output of `N` words and read-only buffers
  holding the vector and the matrix row-major (`MojoProofTest.GevmSound.kernel_sound`, by
  `MojoProof.Sem.kernel_sound_sig`, through `MojoProof.Sem.sound_sig`, from `GevmWarp1.grid`,
  `GevmSound.grid_bad` and `GevmSpec.cols_holds`). The steps both kernels' theorems share are
  library theorems for every program (MojoProof/Sym/SigKernel.lean): the starts are by
  `Grid.start_of_check`, which also asks the launch check `Func.checkLaunch` (gevm's start asks
  `volume L.block ≤ 1024`, `GevmSound.starts`, which `kernel_sound`'s launch gives), gevm's
  `grid_bad` by `Grid.not_bad_cells` and the store extensions of the trace by `Ext.store`, and
  both `kernel_sound`s are uses of `kernel_sound_sig`; the hand-written proof lines left are 2352
  in gemv's per-kernel files and 1148 in gevm's. The admission is that the address choice puts
  each block's 4096-byte shared array below `2 ^ 32`; the rule is `GevmSpec.ColsRule`, which is
  `Spec.vecMat (vecMatLaneGrade 32 5 ⌈m / 32⌉)`; against TorchLean's `.vecMat` at that grade,
  `vecMatLaneGrade 32 5 ⌈m / 32⌉` (the importer's grade at `.matVec` is any monotone one), it is
  `gevm_torchLean`, and with every premise proved at one block,
  `N = K = 32`, it is `sound1024` and `torch1024`. Still assumed: the launch premises, among them
  `N = 32 · L.grid .x` (the IR has no guard against `N`, and at `N < 32 · L.grid .x` the last
  block reads and writes past its buffers). The kernel theorem is hand-proved, not generated by
  `mojo_kernel` ([docs/proofs/gemv.md](proofs/gemv.md) (c) and (d))
  ([docs/proofs/spec.md](proofs/spec.md),
  [docs/proofs/dot.md](proofs/dot.md)). The design's
  other law classes are not in Lean yet. For every type, step relation, equivalence and bad set, a confluent system
  needs one run (`Confluent.one_run`), and confluence moves along a surjection that maps the steps,
  the equivalence and the bad set (`Confluent.transfer`; `Grid.confluent_owned` uses it along the
  identity). Mixed-radix indices at symbolic sizes (`GPUProof/MixedRadix.lean`,
  [docs/proofs/mixed-radix.md](proofs/mixed-radix.md)): for every size assignment, radix list and
  width, an index in range is below its radix product (`GPUProof.MixedRadix.lt_prod`), two in
  range, each at its own size assignment, whose radices have the same values there, are equal
  exactly when their digits are (`GPUProof.MixedRadix.eq_iff_digits`); the value splits at a digit
  by Horner's rule (`GPUProof.MixedRadix.val_append`); and one in range whose radix product is below
  `2 ^ (w - 1)` fits `w` bits (`GPUProof.MixedRadix.fits`; `GPUProof.WordFit`: the unsigned and
  signed value, sign extension, and adds of two parts without unsigned or signed overflow; the
  word lemmas of MojoProof/Sem/Index.lean are its corollaries). Tests: gemv's write index and the
  naive matrix product's offsets at symbolic sizes, two threads' warp keys at their two
  assignments (`warp_two`) and a key split after its warp digit (`warp_split`)
  (MojoProofTest/GPUProof/MixedRadix.lean). Footprints at symbolic sizes (`GPUProof/View.lean`,
  the same document): for every machine whose placement is injective, the tiles of a view's
  instances that own one lie in the view's bytes and are pairwise disjoint at every size
  assignment and launch where the view is well formed (`GPUProof.View.tiling`); at a key stride
  `d` beside the layout, the tiles are a tiling wherever every layout offset modulo the radix
  product times `d` is below `d` (`GPUProof.View.tilingAt`, with `View.tiling` its case at the
  cosize; test: layer norm's rank-1 block kernel, thread `t` owning the floats `t + B j`,
  MojoProofTest/GPUProof/ViewStride.lean, with a mutant at another block size's stride); at a key
  stride the tiles are a tiling exactly when the layout is separated, no two offsets differing by
  `m d` with `0 < m` below the radix product (`GPUProof.View.tiling_separated` for every machine
  with an injective placement, and `GPUProof.View.separated_of_disjoint` where every key value is
  an owner's; `tilingAt` is its interleaved case; test: layer norm's view with fewer threads than
  columns, `ln_cols_not_interleaved`); for every
  machine, the owners' tiles cover the bytes of the first `B` key values when every offset below
  the layout's cosize is a coordinate's and every key value below `B` is an owner's
  (`GPUProof.View.cover`), and at every positive `B` these premises are the least for a well
  formed view and an injective placement (`GPUProof.View.cover_iff`); at a key stride `d` the
  owners' tiles cover `Q` periods of the first `P` key values when every offset `r + P d q` is a
  coordinate's and every key value below `P` an owner's (`GPUProof.View.coverAt`; test: layer
  norm's view at every block size, `ln_cover`, and a mutant at block size 64's stride whose byte
  768 is in no tile, `ln_stride64_uncovered`), and these
  premises are the least where every offset modulo `P d` is below `d` and `Q = 1` or the radix
  product is at most `P` (`GPUProof.View.cover_iffAt`; without those two, `ln_cover_period` and
  `ln_cover_short` cover); coarsened at a level, an instance's tile holds
  the tiles inside it when the owners inside agree on the outer digits
  (`GPUProof.View.tile_subset_coarsen`), and is their union when they also realize every inner
  key value (`GPUProof.View.coarsen_tile`); at a key stride, `GPUProof.View.coarsenAt` with
  `tile_subset_coarsenAt` and `coarsenAt_tile`, the coarse key stride `R d`, and `coarsen` and
  its lemmas are the case at the cosize. Tests at a key stride other than the cosize, on a
  grid-stride view with a two-digit key: `gs_coarsen` (the union at stride 4 and coarse stride 8)
  and the mutant `gs_gap` (an owner missing at an inner key value: only the inclusion holds, byte 12
  in the coarse tile and in no owner's tile). Tests: gemv's warp view (one 4-byte float per row,
  1-D launches) and the naive matmul's thread view (symbolic `m`, the row stride `N` of each
  kernel of the family, 50257 for the corpus kernel, the threads past the matrix owning no tile)
  at MojoProof's machine, their tilings at every admissible assignment and launch and their
  coverage (gemv's with at least `m` warps, the naive matmul's at every valid launch), gemv coarsened at the block level with its partly
  owned last block, and mutants for an overlap, a key out of range, more warps than rows, a
  column count other than the corpus kernel's row stride, a radix that reads a bound variable
  and a radix past a block's warps (MojoProofTest/GPUProof/View.lean); a well formed view's
  tiles at that machine as MojoProof's `Tiling` of byte intervals over its owners and an empty
  interval, with an index for every thread, under which a thread that owns no tile accesses no
  byte of the view's buffer (MojoProofTest/GPUProof/ViewTiling.lean). The tiles are
  natural-number models of offsets. For every machine, an owner's key value fits `w` bits when
  the key's radix product is below `2 ^ (w - 1)` (`GPUProof.View.key_fits`, the word premise).
  Under it at `w = 32`, the naive matmul's index words (every row stride `N`, `m · N < 2 ^ 31`)
  and gemv's row word (`m < 2 ^ 31`) are the views' key values, the guards are false exactly
  when the thread or warp owns its tile, and the `getelementptr` is the tile's first byte; at
  the two launches where the premise fails, the kernels skip an owned store or store outside the
  tile (MojoProofTest/GPUProof/ViewWords.lean). A guarded tile is a tile's bytes whose offsets lie
  below a bound (`GPUProof.View.guardAt`, `guardsAt`; inside the tile, `guardAt_subset`; the
  whole tile when every offset is below it, `tile_subset_guardAt`; covering what the tiles cover
  below the bound, `cover_guardAt`; and `Tiling.mono`, so guarded tiles of a tiling tile). Layer
  norm's rank-1 block kernel is covered at a row of `n` floats for every `n` and block size `B`
  with `X = ⌈n / B⌉` steps and the guard of its loop (`ln_guard_tile`, `ln_guard_tiling`,
  `ln_guard_cover`, `ln_guard_stores`, the last against the IR loop's model `lnStores`,
  enumerated for every block size, row length, thread and count, `lnStores_eq`; at `B ∣ n` the
  guarded tile is the tile, `ln_guard_dvd`), tested at `n = 300`, `B = 128` and `n = 170`,
  `B = 64`, with the unguarded tile's extra byte as a mutant (`ln_unguarded_300`). Its loop's index add, guard, exit
  and step tests, second bound test and `getelementptr` are the view's offsets and the guarded
  tile's bound at every block size, row length, thread and step, under 64-bit word premises, by
  the semantics' word operations (`ln_words`, `ln_offAt`, `ln_gep`, `ln_second`; the premise's
  mutant `ln_wrap` at `n = 2^63`); this is not a run theorem. The loop's run is proved at
  every block size `B` of the corpus family (the files
  ln_rowwise_block_t0_r1_ax0_w1_bs{64,128,256,1024}, which differ only in `B`) with `0 < B`,
  `B ≤ 2 ^ 32` and the path checker's covers `LnCovers B`, for the family's function `lnFam.fn B`
  in a context of the bs128 file's program `ln.prog` (`runB`, `run_entryB`, the hand-proved
  `run_fromB`; MojoProofTest/LnRun.lean, [docs/proofs/layernorm.md](proofs/layernorm.md)). For
  one thread, every launch, thread index `tid < 1024`, row length `n < 2 ^ 32` and memory with the
  four row buffers of `4 n` bytes, the run from the loop's entry to its exit logs, per float of
  `lnStores B n tid` in order, three 4-byte reads of `x`, `g`, `b` and one 4-byte write of the
  output, and no other event
  (`MojoProofTest.LnRun.LnTrace`). It changes no other byte, and the 4 bytes at each such float
  encode `%503` by the semantics' float rules (`LnOut` at `LnBytes`, `lnVal`): FloatLib's fused
  `fma` or the separately rounded `add`, as the context's oracle chooses, each with a free NaN
  payload (`lnVal_cases`). A finite one is the float library's layer norm output
  (`lnVal_finite`) and, given bounds on the errors of the mean and the inverse deviation, has its
  mixed error bound (`lnVal_error`, `LnBytes.error`) (`run`, `run_entry` and `run_from` at the
  bs128 file, their statements unchanged; one round per value of the guard,
  `MojoProofTest.LnRound.round_trueB`, `round_falseB`). At 64, 256 and 1024 the files' loop
  blocks summarize to the family's at `B` and the covers hold, and the run is `run_entryB` at
  that `B` (MojoProofTest/LnFamily.lean, `run_entry_64`, `run_entry_256`, `run_entry_1024`, with
  `lnStores B n tid` evaluated at one row and thread). MojoProofTest/LnRunTest.lean builds the memory from three tensors and proves
  every premise (`run_mem`, `run_floats`; `run_300` and `float_43` at `n = 300`; the mutant
  `short`). With the float library's Welford words as the mean and inverse deviation, each
  finite float stored is `lnorm`'s (`run_lnorm`) and, for `n ≤ 2 ^ 24`, within FloatLib's mixed
  error of TorchLean's `layerNorm` (`run_torch`, every premise at one row in `torch_iota`). Not
  proved: the code that computes the mean and inverse deviation (they are given registers), the
  run of each of the files at 64, 256 and 1024 for its own function in its own program (it
  differs from the family's in 5 of 60 blocks, none in the loop, and in names), and the whole
  launch. At a buffer of exactly `4 n` bytes the
  `getelementptr inbounds` past the row is poison, not a fault, and the guard skips its store
  (`MojoProofTest.LnGep.ln_gep_past`, `ln_gep_row`).
- **Schedule independence**, every program: from a memory whose stored pointers name only blocks
  it has allocated, the steps of a launch are confluent up to faults and races (`Grid.confluent`),
  so one run to the end with no fault, no race and no broken `!invariant.load` promise shows that
  every schedule of that launch, at the run's address choice and float choice, is safe, race free,
  makes progress, terminates and gives the same result for every observation that reads only the
  memory's blocks (`Grid.start_sound`; a run at another address or float choice is not covered and
  may differ); the
  same statement, at the same premise, follows from Theorem 0 at `sig`
  (MojoProofTest/Theorem0.lean).
- **The block checker is sound**, every program: a block, a path of blocks or a path to `ret` that
  the symbolic checker accepts runs as its summary says whenever the path's conditions hold at its
  entry (`Block.sound`, `Block.sound_pathWith_ptrs`, `Block.sound_retWith`). Its fragment includes
  integer `select`, the `llvm.smax`, `smin`, `umax` and `umin` intrinsics, the lane number
  (`llvm.nvvm.read.ptx.sreg.laneid`, `exec_laneid`), the casts `castV` evaluates (`castOk`, exactly
  its cases by `castOk_iff`: not `fptoui`, `fptosi`, `inttoptr` or an ill-typed cast;
  `SNode.castAt`, `exec_cast`), with the value of a same-width scalar `bitcast`
  (`SNode.eval_bitcast`), a `getelementptr`, `load` or `store` on a global (the node
  `SNode.globalAt` at the pointer's operand, the context's address of the global,
  `SNode.eval_globalAt`), and a `load` after a store, from the memory the effects before it make
  (`SNode.loadAfter`; after a `store` at the same pointer it is the stored value,
  `SNode.eval_loadAfter_store`, and after one apart from it the value without it,
  `SNode.eval_loadAfter_apart`; tests at a layernorm block); `getelementptr`, `icmp`, `ptrtoint` and
  the special registers after a store (`SEff.run_shape`); stores of `zeroinitializer`, `undef` and
  `poison` (`SNode.constAt`); `insertvalue`, `extractelement` and `insertelement` (`SNode.insert`,
  `eltAt`, `insEltAt`) and `getelementptr` with any number of indices on a base that is not a global
  (`SNode.gepN`); a block with `fmul contract` (whose products a later `fadd contract` may fuse) is
  checked with the products it records (`Block.soundC`, and along a path `Block.sound_pathC`); and
  with the checker's `alloca` flag on, a block with `alloca`s runs as its summary says, each
  `alloca` a fresh block (`SNode.fresh`) put in front of the frame's `alloca` blocks
  (`Block.soundAt`, `Block.sound_alloca`); after an `alloca`, `getelementptr`, `icmp` and `ptrtoint`
  are read on the memory the block's effects make (`SNode.gepAfter`, `gepNAfter`, `icmpAfter`,
  `castAfter`, evaluated by `SEff.run`). A block's `mem` obligation holds exactly when its effects
  run on `sig`'s metadata alone (`SEff.holds_iff_runMeta`, for every valuation and effects), and
  the checker decides a closed `mem` obligation that way (`SEff.holds_of_runMeta_toBool`).
  Paths through blocks with `alloca` (`coversPathAt`) are sound for every program: the last block
  ends with the path's alloca blocks in front of the frame's (`Block.sound_pathAt_ptrs`), and a
  returning kernel thread runs to its end with them dead (`Runs.of_retAt`). The flag-off path
  checker is its case (`coversPathWith` is `coversPathAt false`, `Block.sound_pathWith_ptrs` a
  corollary by `Valuation.allocsWith_nil`). A two-block path with an `alloca` in each block,
  parsed from LLVM text, meets these premises at one launch of one thread and runs to its end with
  both blocks dead, which the interpreter's steps confirm (MojoProofTest/SymAlloca.lean
  `path_walk`, `path_retWith`, `path_dead`, `path_steps`), and as a kernel theorem through the
  command (`pathA`, `pathA_sound`). Loops through blocks with `alloca`
  (`coversChainsAt`) are sound for every program too, and the blocks the cleanup sets dead are
  exactly those the run adds to the start memory (`Runs.of_chainsAt`, `Mem.Adds`). So a
  postcondition that reads only the start memory's blocks holds after the cleanup, with the run's
  blocks dead (`Runs.of_chainsDead`). Test, one program: `MojoProofTest.SymLoopAlloca.loopK_run`,
  the rounds' blocks dead and an output block's word kept, with the mutant `loopK_inUse`, a start
  memory whose fresh number is taken. A chain whose last path out stops after its last edge takes
  the thread to the frame it enters, the continuation given the entered frame's `alloca` blocks
  (`ChainWith.enter`, `RunsVia.of_chain`). gemv_kernel's warps run from `Grid.start` with
  `Grid.fire`'s deliveries, at `K = 0`, and with one round of the loop at `%54` at `K = 4` and
  `K = 3` (MojoProofTest/GemvWarp.lean). Each lane runs by the checkers from the start's thread: through
  `%6`'s two `shfl.sync.idx` and `%43` to `ret` (`lane43`), or through `%44`, the loop's `n`
  rounds through one arm (`ChainWith.of_rounds`; lane `j` through `%70` if `j < K`, `arm`,
  `rounds`) and `%78`'s five `shfl.sync.bfly` to `ret` (`lane`, `tail78`). This holds for every
  launch whose start succeeds and every deliveries and memory at which the kernel's per-lane
  premises hold; those premises are decided at five launches. A warp's lanes form one
  `WarpRun.of_waits` (`warp78`, `warp43`), each delivery is `Grid.fire`'s, and each wait memory
  is decided (`mems78`, `mems43`). Tests: one block of 32 threads and one of 64 (`run32`,
  `run64`), each to a done grid with the output's cell 0 at `0.0`; one block of 32 at `M = 1`, `K = 4`
  with the row `[2^24, 1, -2^24, 1]` and ones, whose output cell holds the word of `warpDot` (2),
  not the left-to-right `dotLoop`'s (1) (`run4`, `orders`), and the same at `K = 3` (`run3`), the
  offers each lane's own (`Warp.v` by phase and lane); `run4`'s cell as the word of the
  semantics' `deliver` rounds at the run's oracle (`run4_deliver`), and a mutant row
  `[+∞, -∞, 0, 0]` at which the two forms differ; the 16-thread mutant, whose first `bfly`
  delivers `poison` (`poison16`); refusals (`refused`, `twins`). The launches' blocks are sized
  from their words (`memAB`, `memAB_size`). The values of gemv_kernel's `%6` loads, for every program (MojoProof/Sym/OblPieces.lean): a load of element `k` of an array stored whole (`Mem.load_store_elem`, as `Mem.load_store` for the whole value), its `loadAfter` node (`SNode.eval_loadAfter_elem`), a slot through later changes of other blocks (`Mem.load_store_codec_of_block`), and the `insertelement` and `undef` nodes; tests at gemv_kernel's statements 29 to 37 (MojoProofTest/GemvEntry.lean). gemv_kernel's entry block at a free thread (one program): for every valid launch, thread, context and memory whose three fresh block numbers have no block, a frame at pc 0 of `%6` with `%0`, `%1`, `%2` pointers, `%3 = M` and `%5 = K`, and `%6`'s two `shfl.sync.idx` deliveries as premises, the thread runs to statement 41, where `%10` and `%11` are `M` and `K` sign-extended and `%35` is the vector of the two delivered words, with the three `alloca` blocks written and their lifetimes ended, the frame's `alloca` list those three in front of the start's, the step count 41 more, and every other block as in the second delivery's memory, whose trace it extends by the thread's accesses of the three blocks only; the two waits are stated with each call's position, arguments (the full mask, the row word's halves, source lane 0, clamp 31) and memory (MojoProofTest/GemvEntryRun.lean `entry`, continued at the meeting point of `GemvLoop.run` below). gemv_kernel's thread at every `K` (one program, float32 `b79a852b`): for every valid launch, thread, context and memory with `M, K < 2 ^ 31`, `M K < 2 ^ 61`, row `r < M` and the matrix and vector in buffers, a thread from statement 41 of `%6` runs through `%44`, the loop's `⌈K / 32⌉` rounds (lane `l` through `%70` for `(K + 31 - l) / 32` of them, then through `%75`) and `%59` to position 1 of `%78`, on a memory whose trace extends the start's by reads of the matrix's and the vector's blocks only, where `%79` is the `dotLoop` with contraction of the lane's strided pairs of row `r` (MojoProofTest/GemvLoop.lean `run`; the rounds by mojo_obl, MojoProofTest/OblGemv.lean `roundA`, `roundB`); from there, with the five shuffles' deliveries as premises, it runs to `ret`, lane 0 storing the sum through `%37` (MojoProofTest/GemvLoopTail.lean `thread`, and `to_ret` from statement 41). Lane 0's stored word is its value after the semantics' five `deliver` rounds over `%78`'s offsets, when lane 0's oracle numbers are its `fadd`s' and each delivered value is the partner's after the rounds before, so at the run it is row `r` of words that meet `bflyDeliver_holds`'s rule (MojoProofTest/GemvLoopBfly.lean `total_eq`, `stored_holds`; `stored_holds`'s premises decided at a `1 × 32` matrix, `premises32`). gemv_kernel's thread from its start to its `ret` (one program, float32 `b79a852b`): for every valid launch with `M, K < 2 ^ 31` and `M K < 2 ^ 61`, thread, context and memory, a thread whose only frame is at pc 0 of `%6` with no `alloca` blocks and the arguments `Grid.start_arg` gives, whose three fresh block numbers have no block, with a row `r < M` and the first two deliveries the halves of `r` on a memory where the three blocks are the thread's slots, the output block is a writable buffer and the input blocks are read-only buffers holding the matrix and vector, runs through its seven shuffles (each wait's position, call, argument values and memory as `Piece.Wait.via` states them, `entry`'s two and `%78`'s five) to its end, where lane 0 has stored `total` of its strided `dotLoop` at element `r` of the output, the three slots are dead and the output block is live, and at the wait at `%78`'s first shuffle the trace extends the second delivery's memory's by the thread's accesses of its three slots and reads of the matrix's and the vector's blocks only (MojoProofTest/GemvThread.lean `run`, `live_out`; `run_out` and `waits_range` give the final memory and the waits in `WarpRun.of_waits`'s form). When each of `%78`'s deliveries is the partner lane's offered value (`MojoProofTest.GemvLoopBfly.offered`, the argument of the partner's shuffle), every lane's `total` is its value after the five butterfly rounds (`total_chain`, through `MojoProof.Tile.bflyRoundsAt_chain`, for every round function, offsets and set of lanes closed under partners). Every premise holds at lane 3 of one block of 32 threads, `M = 1`, `K = 4`, row 0, with `Grid.fire`'s two deliveries on the memory with every lane's slots (`lane3_inv`); the memory at `%78`'s first shuffle is `waitAt c [d₁, d₂] t m`, the memory at the thread's wait after the two deliveries (`MojoProof.Sym.waitAt`, for every program). A shuffle delivers its source lane's offered word, for every program whose shuffle declarations' result attributes keep words and every source lane of the warp (MojoProof/Sym/ShflDeliver.lean `Program.shfl_deliver`, with its `bfly` and `idx` cases in a full warp); gemv_kernel's seven shuffles meet it (MojoProofTest/GemvShfl.lean `keeps`, `deliver7`), and `%24` and `%25` deliver lane 0's halves of the row word (`idx_row`). Another thread's `alloca`s, slot stores and slot deaths keep a thread's slots and the buffers, for every memory (MojoProof/Sym/Slot.lean `Mem.SameOff`, `Mem.FreshOf`; MojoProof/Sym/LaneFrame.lean `Mem.SameOff.chain`). gemv_kernel's warp at every `K` (one program, float32 `b79a852b`): for every valid launch whose block size 32 divides, warp's first thread, contexts at the lanes' special registers with distinct threads and address oracles below `2 ^ 60`, threads at gemv's start, `M, K < 2 ^ 31` with `M K < 2 ^ 61`, row `r` lane 0's row, and memory with no block at the warp's own `alloca` numbers and with the writable output buffer and the read-only matrix and vector buffers, which fit, the last two holding the matrix and vector, the warp's 32 lanes run (`WarpRun`) through their seven shuffles, each delivering its source lane's offer, and the word at row `r` of the output then loads as lane 0's `total` of its strided `dotLoop` and the sums its partners 16, 8, 4, 2 and 1 offer (MojoProofTest/GemvWarpRun.lean `Lanes.warp`); its premises hold at one block of 32 threads, `M = 1`, `K = 4`, row 0 (`w0_pre`). In every such warp each delivery is the partner's offered value (MojoProofTest/GemvWarpWord.lean `partner_offered`), so the stored word is lane 0's value after the five butterfly rounds from the lanes' sums (`word_rounds`, `warp_word`), row `r` of words that meet `bflyDeliver_holds`'s rule (`warp_row`), and row `r`'s `warpDot` up to NaN payloads (`word_warpDot_nanEq`, with its instance at `w0`), equal to it where no round's sum is a NaN (`warp_dot`, whose premise is stated, not derived from the inputs). After the warp the memory keeps `next`, its blocks outside the output and the warp's `alloca` numbers, the output buffer and every output load outside row `r`'s word (`warp_frame`), so a later warp of the launch whose threads are none of the warp's keeps its premises (`Lanes.Pre.later`) and row `r`'s word (`later_row`). A warp's premises hold on `Grid.start`'s memory for every valid launch whose block size 32 divides and every warp whose row is below `M`, from a caller's memory with no block from `next` on (`Lanes.Pre.of_start`). For every program whose globals are shared and uninitialized, the start's memory has no block from `next` on (`MojoProof.Sym.Grid.start_free`), and the contexts' address oracles are the start's address choice (`Grid.start_addr`, MojoProof/Sym/LaneFrame.lean). A property that every step keeps holds at a run's wait and at its end, and a run's end memory is determined (`RunsVia.waitAt_keeps`, `RunsVia.waitAt_next`, `Runs.det`, `RunsVia.endAt`, MojoProof/Sym/WaitAt.lean). gemv_kernel's warp whose row is `M` or more (one program): for every valid launch whose block size 32 divides, 32 lanes at gemv's start with distinct threads and address oracles below `2 ^ 60`, lane 0's row `M` or more, `M, K < 2 ^ 31`, and memory with no block at the warp's `alloca` numbers and with the writable output buffer, each lane runs from its start through `%6`'s two `idx` shuffles and `%42`'s branch to `%43` to its `ret`, its trace after the second delivery extended by its accesses of its three `alloca` blocks only (`MojoProofTest.GemvOut.run`), the warp runs (`WarpRun`, `Out.warp`), and the memory after it keeps `next` and every block outside the lanes' `alloca` numbers (`Out.warp_frame`). gemv_kernel's grid (one program): for every valid launch with `y` and `z` sizes 1 whose block's `x` size 32 divides, with the arguments, bounds and buffers above, the grid's warps from the start form one canonical run (`CanonRun`, `Lanes.grid_run`, by `CanonRun.of_inv`) to a done grid where each warp whose row is below `M` has its row word load (`Lanes.grid_done`). When `M` is at most the launch's row count `L.block .x / 32 · L.grid .x`, every output row of the done grid is its row's `warpDot` up to NaNs (`grid_rows`, MojoProofTest/GemvWarpWord.lean). Instances from the start: one block of 32 threads, `M = 1` (`w0_done`); of 64, `M = 2` (`w64_done`); and of 64, `M = 1`, whose second warp takes the branch to `ret` (`w64_out_done`). gemv_kernel's grid's events (one program): in every warp of such a launch, lane `j`'s events after its second delivery are accesses of its own three `alloca` blocks and reads of the matrix's and the vector's blocks (`Lanes.mem2_ext`; a warp whose row is `M` or more, `Out.memE_ext`, accesses of its slots only), the `alloca`s and the butterfly shuffles log nothing, and the last phase logs lane 0's store at its row only, so along the grid's canonical run every event since the start is one of `Ev`: an access of a lane's own slot, a read of the matrix or the vector, or lane 0's store at its row (MojoProofTest/GemvSound.lean `lanes_events`, `out_events`, through `Lanes.grid_run_inv`, `grid_run` with an invariant). Every trace of `Ev` events has no race at `sig` (`GPUProof.racy` is `false`: each slot is its thread's, `Mem.fresh` numbering a thread's `alloca`s by its thread; row `i`'s cell is only thread `32 i`'s; the matrix and vector are only read; `racy_ev`, through `GPUProof.racy_iff`) and keeps the `!invariant.load` promise (`GPUProof.kept`; `kept_ev`: no event writes the matrix or the vector). gemv_kernel's grid is sound (one program): for every valid launch with `y` and `z` sizes 1 whose block's `x` size 32 divides and with `M ≤ L.block .x / 32 · L.grid .x`, address choice below `2 ^ 60`, `M, K < 2 ^ 31` with `M K < 2 ^ 61`, and caller's memory with no block from `next` on whose known bytes are in its blocks (`m.BytesIn m.Known`), with the writable output buffer and the read-only matrix and vector buffers, which fit, the last two holding `A` and `v`: `Grid.Sound` from the start for the output rows read at `p0` (`rowsObs`) and the relation that each row loads as its row's `warpDot` up to NaNs at its warp's loop oracle numbers (`RowsDot`) (`grid_sound`, by `CanonRun.start_sound`, with the run, its race and promise facts and its rows at one end memory, `grid_end`); its premises hold at one block of 32 threads, `M = 1`, `K = 4`, the start proved (the example after `starts`). gemv_kernel's kernel theorem (one program, hand-proved, not by `mojo_kernel`): at those launches and buffers, for a caller's memory closed for the six arguments (`Mem.Closed`), every width `bits` and input words `I` holding `A` and `v`, `GPUProof.Kernel.Sound` at `sig` for the admission "address choice below `2 ^ 60`", the output rows and the rule of `GPUProof.Spec.matVec (GPUProof.laneVecGrade 32 5 fun n => ⌈n / 32⌉)` at `MojoProof.Tile.matVecEnc` (`RowsRule`; `kernel_sound`, through Theorem 0, `GPUProof.Sound.of_one_run`, with no `Res`; each row graded at every oracle numbers, `rows_holds`), and the same for the rows within that grade of TorchLean's contraction `.matVec` of every real matrix and vector the input words approximate, read through `MojoProof.Import.torchLean` (`TorchRows`; `gemv_torchLean`, MojoProofTest/GemvTorch.lean). Every premise of both holds at one block of 64 threads, `M = 2`, `K = 4`, width 32 (`sound64`, `torch64`): the caller's memory with the output at block 3 and the matrix and vector at blocks 1 and 2 is closed and meets the buffer, fit and holding premises at every `M, K < 2 ^ 31` with `M K < 2 ^ 61`, matrix and vector (`GemvThread.mem_caller`, MojoProofTest/GemvThread.lean). Not proved: launches with a `y` or `z` size above 1. A thread's row reads only its `x` coordinates, so two warps can share a row: at block (32, 2, 1) and grid (1, 1, 1) the warps from threads 0 and 32 both have row 0, and two stores by those threads at row 0's cell race at `sig` (`GPUProof.racy` is `true`), while thread 32's store at row 1's cell would not (`row_race`, by evaluation of the two stores' events); no theorem states that a run reaches both stores.
- **Segments that end at a collective**, every program: the statements of a block up to a
  barrier or warp-shuffle call that the checker accepts (`summarizeTo`) run, from a valuation
  meeting the segment's obligations, to the call's `.wait` on its arguments' values
  (`Seg.sound`), and the resumed thread is at the next statement (`Thread.resume_at`; the two
  together, `Seg.resume`). A segment also ends at an `llvm.lifetime.start` or
  `llvm.lifetime.end` call (`summarizeLife`, `Seg.lifetime`), and the step there moves to the
  next statement on the memory `Mem.setLive` makes (`Seg.lifetime_ptr`; tests at layernorm's
  `%453` and `%151`). Tests:
  gemv_kernel's `%78` is six segments and gevm_kernel's `%59` seven
  (MojoProofTest/SymSeg.lean). A block's segments in a row on one thread: when `summarizeSegs`
  gives the summaries of the segments to the block's collective calls and of the rest, a thread
  at the block's start runs them in turn for every value and memory each collective delivers,
  each segment's obligations a premise at its start frame, and the block ends (`Seg.through`); the
  same holds through its collectives and lifetime markers, with the checker's `alloca` flag in the
  tail after the last one (`Piece.through`, the tail's `alloca` blocks in front of the frame's;
  tests in MojoProofTest/SymSegAlloca.lean). The segments' run also continues from the frame after
  the last one into any continuation (`Piece.throughTo`), with the segments' premises one checker
  that the kernel decides (`Piece.walk`: the waits, each with its call, argument values and the
  memory the segment's effects make, the valuation after the block and the segments' `alloca`
  blocks, `Piece.allocs`; `Piece.fires`, `RunsVia.of_fires`, through a continuation of that
  valuation and those blocks), and a resumed frame has the summary's value at every register but
  the call's result (`Seg.resume_regs`, by `Thread.resume_regs`). A thread whose path to `ret`
  the path checker accepts (`retB`) runs to its end at a memory the kernel evaluates: the last
  block's effects with the path's and the frame's `alloca` blocks dead (`Valuation.retMem`,
  `Runs.of_retMem`).
  Test: gevm_kernel's `%59` at symbolic values (`gevm_through`). One program (gevm_kernel float32
  `1308aaae`): every thread from `%59` through the barrier and its five butterfly shuffles to `ret`.
  Lane 0 stores the sum, by five IEEE binary32 adds rounded to nearest (NaN results as the oracle
  gives), of the shared array's cell `tid.x` and the five delivered values; the other lanes store
  nothing, and each wait is at its statement of `%59` (`Thread.at`: the barrier at 6, the shuffles
  at 11, 15, 19, 23 and 27; MojoProofTest/OblGevmThread.lean, `thread`). The delivered values are
  premises. The kernel's entry block and loop are proved separately, for every `K` with `K % 32 = 0`
  and every `N` with `K * N < 2 ^ 29` (MojoProofTest/OblGevmRun.lean, `loop`: the thread reaches
  `%59` with
  `%60` the warp's strided dot product `dotLoop … (stride 32 (tid.x / 32) (vecMatPairs A B _))`);
  the two are joined to the barrier by `MojoProofTest.GevmBar.bar` (MojoProofTest/GevmBar.lean):
  every thread, at every valid launch with 1024 threads a block, runs from the entry to the
  barrier's call with `i32 0` (`ToWait`) at statement 6 of `%59`, `41 + 17 (K / 32)` steps on, on
  the memory the store of `%60` to cell `laneid · 32 + tid.x / 32` of the shared array makes.
  `GevmLane.thread` (MojoProofTest/GevmLane.lean) states `%59`'s six waits whole (`Piece.Wait.via`:
  the barrier's `i32 0` and memory, the shuffles' mask, value, offset and clamp), as
  `RunsVia.of_block` takes them at `J = 6`. The warps' and blocks' runs are built: each warp to the
  barrier by `WarpWait.of_inv` (`MojoProofTest.GevmWarp0.warp`), each block's warps by
  `CanonWait.of_merge` (each warp at its own statuses) and its barrier by `BlockBar.of_waits`
  (`GevmWarp0.block`; after it the
  shared array holds thread `1024 g + tpose 32 x`'s sum at cell `x`), each warp's five shuffles
  by `WarpRun.of_waits` (`GevmWarp1.Warp.warp`), each block from its entry to its end
  (`GevmWarp1.block`), the blocks in turn (`GevmWarp1.blocks`, `PhaseRun.of_inv`) and the grid
  from `Grid.start` to a done grid (`GevmWarp1.grid`, `PhaseRun.start_done`). Each level carries
  its trace's extension (`GevmWarp0.Ev0`, `GevmWarp1.Ev1`), and `MojoProof.Sym.PhaseInv` gives
  every access of the done grid's trace with its phase (`GevmWarp1.Acc`).
- **A start through one barrier, and butterfly rounds**, every program and launch: a launch whose
  threads run in turn to a barrier, then every block's barrier fires (each block's own number,
  below 16, `Grid.fire_barriers`), and then, resumed, in turn to their ends, with no race and the
  `!invariant.load` promise kept, is sound (`Seq.start_sound_bar`, from `Seq.ToWait.grid`,
  `Grid.fire_barriers` and `Seq.grid`); a warp's shuffle of one mode with the full mask resumes
  each lane with the operand of the lane `shflSource` names (`Grid.fire_shfl`). Kernels with
  barriers and shuffles run at the phase level below (`PhaseRun`).
  After butterfly rounds at offsets `ms`, the lanes of a warp of width `2 ^ k`, `k ≤ 5`, hold
  `bflyRoundsAt F` of their first values, for a combination `F r l` per round and lane
  (`bflyRoundsAt_of_shfl`; `bflyRounds` is the case `F = fun _ _ => combine`); at offsets below
  `2 ^ e`, the rounds that deliver each sum of `F` at an oracle number per round and lane
  (`deliver (F x y) (o r l)`, the semantics' `fadd` at `F = Model.add`) are the rounds of `F`
  wherever no partial sum is a NaN (`bflyRoundsAt_deliver`, every format, operation and oracle).
  Tests: `Launch.k` on
  one block of two threads (MojoProofTest/SymWait.lean); a kernel with a barrier and two butterfly
  shuffles on one block of four threads, sound by `PhaseRun.start_sound` at the block's run (the
  barrier a `BlockBar`, the warp past it by `warp_route`: `WarpRun.of_waits` with each shuffle by
  `WarpRun.shfl_of`), each lane holding the sum of the four thread
  numbers, with an open-goal twin for a missing fire (MojoProofTest/SymColl.lean). A thread's
  first wait, at its named instruction, comes from its segments (`Seg.Through.wait`). Test: a
  barrier and two butterfly shuffles on one block of 4 and of 8 threads, sound by
  `PhaseRun.start_sound` with the phases' runs from invariants on each phase's threads and
  memories (`BlockRun.of_inv`, `WarpWait.of_inv`; the warp past the barrier by `warp_route`;
  `WarpWait.of_waits` (MojoProof/Sym/WarpWaits.lean) at `J = 1` from the lanes' runs through
  their waits and the first shuffle's premise from the waits, with each lane's status at its wait,
  `statusAt`, `shfl_wait`; its earlier statements are `example`s from it), with an open-goal twin
  (MojoProofTest/SymChain.lean).
- **A start through warps in turn**, every program and launch: the canonical run at one level
  takes the warps in turn; a warp's lanes run in turn to their next shuffle, the shuffle fires
  once its last lane waits, each lane resumed with the value `Grid.fire` delivers (`WarpShfl`:
  `shflVal` at `shflSource`, `poison` for a lane not of the warp), until every lane ends; each
  warp has its own number of shuffles (`WarpRun`, `CanonRun`). It is a run of grid steps to a
  done grid with its trace (`WarpRun.grid`, `CanonRun.grid`, `CanonRun.done`), and with no race
  and the `!invariant.load` promise kept, the start is sound (`CanonRun.start_sound`); a
  canonical run from the start reaches a done grid (`CanonRun.start_done`). The three are the
  phase level's (below) at the run of one phase per block (`PhaseRun.of_canon`). The run is
  built from per-lane run predicates (`WarpRun.of_inv`,
  `CanonRun.of_inv`), and a warp's run from each lane's run through its waits, as
  `RunsVia.of_fires` concludes, with the recorded calls (one mode, the full mask, word operands)
  as `WarpShfl`'s premises and the deliveries `Grid.fire`'s (`WarpRun.of_waits`, each delivery under
  the result attributes of the declaration the lane's call finds, `withAttrs`, as `Grid.fire`
  computes it). The `warp_route` tactic builds a warp's run through `WarpRun.of_waits`
  (MojoProof/Sym/WarpRoute.lean): the lanes' runs from a lane lemma (`RunsVia.of_runs`,
  `RunsVia.of_block`, `RunsVia.of_blocks`), the shuffles from each lane's `Piece.Wait.shflOk`
  (`WarpRun.shfl_of`, with `Program.shfl_nil` for a program whose shuffles put no result attribute),
  the rest from the lanes' facts. Barriers are at the phase level below
  (docs/proofs/canon.md). Tests: a
  hand-built kernel the parser accepts, whose warps with bit 5 of their first thread set skip a
  `shfl.sync.bfly`, at block sizes 40 and 70, sound (`sound40`, `sound70`; `sound40` both with the shuffle declared without result
  attributes and with `noundef`, `shfl_decl`), each lane by the
  checkers (the entry edge, `Piece.throughTo` at the shuffle's block, `RunsVia.of_fires` with the
  end's `retB`, `Runs.of_retMem`) into `WarpRun.of_waits` by `warp_route` (`RunsVia.of_block`,
  `WarpRun.shfl_of`); lane
  `j` of warp 0 gets thread `j ^^^ 16`'s value (`deliver40`) and the partial last warp of 6 lanes
  gets `poison` (`poison70`); the shuffle does not fire while a lane still runs (`early`) or with
  a lane at another mode (`mixed`), and a mask that is not full gives no `WarpShfl` (`halfMask`); with `noundef`, warp 64's deliveries
  at block size 70 fault, and `range(i32 0, 16)` turns an out-of-range delivery into `poison`
  (`attrs`) (MojoProofTest/SymCanon.lean). From each warp's lanes' runs through their waits in
  the segment checker's form (`WarpSegs`: `RunsVia`, `Piece.Wait.shflOk`, the declarations'
  keeping), the kernel theorem for kernels whose collectives are shuffles, for every program,
  launch, arguments, memory, admission, observation and rule (`Kernel.sound_of_warps`,
  MojoProof/Sym/KernelWarps.lean); tested on SymCanon's kernel at one block of 40 threads
  (MojoProofTest/KernelWarps.lean `sound40`); no corpus kernel uses it yet. From each block's
  phases between its barriers, each warp's phase to a barrier in the segment checker's form
  (`WarpSegsBar`: the lanes' `RunsVia` through their waits, the barrier call on a word below 16
  at one block and position, the lanes resumed there of the next phase's predicate) and its last
  phase as `WarpSegs`, the kernel theorem for every program, kernel, launch, arguments, memory,
  admission, observation, relation, barrier count and phases (`Kernel.sound_of_phases`,
  MojoProof/Sym/KernelWarps.lean); `Kernel.sound_of_warps` is its case with no barrier. Its run
  part is its own theorem, `Kernel.run_of_phases`: from the same premises without the end
  checks, each start runs to a done grid whose memory is of the last memory predicate, the run
  and done parts of the premise of `kernel_sound_sig`. Tested on SymColl's hand-written kernel (a
  barrier, two butterfly shuffles) at one block of 4 and of 8 threads on the empty memory, the
  blocks at the end the start's and the trace race-free (MojoProofTest/KernelPhases.lean `sound`,
  `run`), with a twin at another barrier word; the premises are supplied, not generated; no
  corpus kernel uses it yet. Both theorems are corollaries of `Kernel.sound_of_prefixes` and
  `Kernel.run_of_prefixes`, where each warp's phase to a barrier is a `WarpSegsTo`: the lanes'
  runs stop at the barrier's wait (`RunsUpto`), and the run after it is asked once, by the next
  phase's premise (`Kernel.Prefixes`); `WarpSegsBar.to` gives a `WarpSegsTo` from a
  `WarpSegsBar`. Tested on SymColl's kernel at 4 and 8 threads (KernelPhases.lean `seg_to`,
  `prefixes`, `sound`, with the twin `bar_other_to`); a kernel of two warps parsed from text uses
  them (MojoProofTest/KernelTwoWarp.lean `sound`, with the twin `race`).
- **A start through blocks, barriers and warps in turn**, every program, launch, contexts, threads
  and memory (MojoProof/Sym/CanonBar.lean): the canonical run at the phase level takes the blocks in
  turn (`PhaseRun`) and a block's phases in turn (`BlockRun`); in a phase the block's warps run in
  turn to the barrier (`CanonWait`), each warp's lanes in turn to their next shuffle or to the
  barrier (`WarpWait`), and the barrier fires once every thread of the block waits, each resumed as
  `Grid.fire_barrier` resumes it (`BlockBar`, `BlockBar.fire`); a block's last phase is a `CanonRun`
  over its warps. It is a run of grid steps with its trace (`trace` and `grid` at each level) to a
  done grid (`PhaseRun.done`), and when the end memory's trace has no race and keeps the
  `!invariant.load` promise and its observation meets the relation (`EndChecks`), the start is sound
  (`PhaseRun.start_sound`; `PhaseRun.start_done`). The runs come from per-lane run predicates
  (`WarpWait.of_inv`, `CanonWait.of_inv` at statuses fixed before the run, `CanonWait.of_merge`
  at each warp's own statuses, `BlockRun.of_inv`, `PhaseRun.of_inv`) or from threads that
  run in order to the barrier and then to their end, over warps that cover the block (`warpsCover`;
  `WarpWait.of_turns`, `WarpRun.of_turns`, `CanonWait.of_turns`, `CanonRun.of_turns`,
  `BlockRun.of_turns`), and the one-level `CanonRun` over every warp is the phase-level run with one
  phase per block (`PhaseRun.of_canon`), so `CanonRun.done`, `CanonRun.start_done` and
  `CanonRun.start_sound` are `PhaseRun`'s at that run (docs/proofs/canon.md). Tests: a
  hand-written kernel that stages through shared memory
  (each thread stores its `tid.x` to its block's array, a barrier, then it stores its neighbour's
  word `tid.x xor 1` to word `40 + tid.x`), sound at one block of 34 threads (a full warp and one of
  2 lanes) and at two blocks of 6 (`sound34`, `sound26`, by `PhaseRun.start_sound`), its first phase
  by `CanonWait.of_inv` (`warps34`, `phase34`; by `CanonWait.of_merge` in an `example`), each
  lane's premises decided one lane at a time
  (MojoProofTest/SymCanonBar.lean); and `sound70` through `PhaseRun.of_canon`
  (MojoProofTest/SymCanon.lean).
- **Facts at a loop's heads**, every program and loop: the registers the rounds keep, that
  rounds that only load keep the memory's blocks, `Elem` and `Elem.Only`, and the step count
  at each block of a round (`LoopSeg.kept_round`, `Valuation.iterate_loads` and its instances,
  `LoopSeg.stepAt_k`, `LoopSeg.steps_k`; MojoProof/Sym/LoopFacts.lean).
- **Kernels from checked paths**, every program: from a memory whose stored pointers name only
  blocks it has allocated, and for an observation that reads only the memory's blocks, the kernel
  theorem follows from a per-thread invariant, with the launch's start and the invariant as
  premises: each thread either takes a loop-free path from the entry block that the checker
  accepts, or runs a sequence of loops the checker accepts (each loop with an invariant indexed by
  the round and a trip count) to `ret`; every final memory of the invariant must have a trace with
  no race that keeps the `!invariant.load` promises and an observation that meets the spec
  (`Kernel.sound_of_chains`; `Kernel.sound_of_paths` is the loop-free case). The `mojo_kernel`
  command applies it to one named kernel at a time. It takes plain pointer parameters (a
  `pointers` clause) and loops in sequence, one `loop` clause per loop, keyed by the loop header's
  position, with the user's precondition, invariant, trip count and postcondition. It refuses a
  nested loop, and a loop that has no clause. With `alloca` in the checker's fragment, the same
  holds with each thread's predicate on the memory its path leaves with the blocks it adds, its
  `alloca` blocks, dead (`Kernel.sound_of_chainsAt`, for both values of the flags `alloca` and
  `contract`; `Mem.Dead`); `mojo_kernel`'s `alloca` clause applies it (tested on the two-block
  alloca path of one thread, MojoProofTest/SymAlloca.lean `pathA_sound`), and refuses it with
  `loop`, `map2` and `mat`. With the flag, gemv_kernel stops at statement 17 of `%6`, its first
  `shfl.sync.idx` (`gemvA`); without it, at statement 0, an `alloca`.
- **Loops**, every program: a loop the checker accepts runs its rounds back to its header for every
  trip count whose rounds meet their conditions (`Block.sound_loop`), and a thread runs through a
  sequence of loops, nested ones included, to its end, with or without `alloca`s in the loops'
  blocks (`Runs.of_chainWith`, `Runs.of_chainsAt`), the blocks set dead at its end the ones the
  run adds (`Mem.Adds`, `Runs.of_chainsDead`). This is only partly
  automated: the invariant and the trip count are the user's, and the rounds' conditions are
  closed by `decide +kernel` at a concrete launch. The kernel theorems that the `loop` clause gives
  are for test programs, each at one memory, address choice and float choice (the naive matrix
  product's theorem below is not: it holds for every memory, input and launch of its shape): the
  counting loop "for i in [0, n): p[i] = i" run by one thread with `n = 3`
  (`MojoProofTest.KernelLoop.kernelK`, the generated `loopK.sound_loop` with no evaluation of the
  start), and six threads in two blocks that each run
  a counted loop and then store one cell, apart only on the storing threads
  (`MojoProofTest.KernelCells.kernelC`, through `Kernel.sound_cells`); for two such loops in
  sequence the command gives the thread's run (`MojoProofTest.KernelLoop.cnt2k_retLs`).
- **Binary elementwise kernels**, a family: every kernel whose parameters are three `byval` structs
  that each hold a buffer pointer (two inputs and an output, as Mojo passes tensors) and an `i32`
  count, at one float choice and every address choice, meets the kernel theorem for memories and
  inputs that meet `Map2.Pre`, given that the launch starts and that each thread takes a checked
  path to `ret` storing the spec's bytes (`Kernel.sound_map2`). For every kernel with this theorem,
  at each output cell `k` below `n`, below the inputs' length and below the number of threads `T`, a
  finite output float is the operation applied to the inputs' cells `k` (`Kernel.map2_real`); when
  the theorem holds at every float choice, two runs give at that cell equal floats or two floats that
  are each NaN or infinite (`Kernel.map2_finEq`), so a finite output is the same at every address
  choice and float choice (`FinEq.eq_of_isFinite`). With `T` threads the theorem covers the first
  `min n T` cells, so all `n` cells when `T ≥ n` (`Kernel.map2_min`). The kernel theorem itself
  holds for any number of `byval` buffer structs and a count of any type, at one float choice and
  every address choice (`Kernel.sound_mapN`, of which `Kernel.sound_map2` is the three-struct
  case); `mojo_kernel` still generates only the three-struct `i32` shape. The theorem holds with
  the checker's flag `contract` too (`Kernel.sound_map2With`); `mojo_kernel`'s `map2` clause takes
  the flag only for paths that record no `fmul contract` product, where the flag changes nothing
  (`RetWith.true_eq`).
- **Modular's `vector_addition` example**, one kernel: for every valid launch whose grid and block
  are one-dimensional (side 1 in `y` and `z`), every memory that meets the precondition `Map2.Pre`
  (the arguments and the pointers stored in memory name only its blocks; the inputs and the output
  are distinct live global buffers of at least `n` floats, 4-byte aligned, whose addresses do not
  wrap; the inputs are read-only and hold `x` and `y`, the output is writable; `n ≤ N` for inputs
  of length `N`, and `n < 2^31`), every address choice and every float choice, the kernel theorem
  holds: each output cell `k` below both `n` and the launch's number of threads holds `x k + y k`
  rounded to binary32, and the rest of the output and every other block of that memory are
  unchanged (`MojoProof.Kernels.vadd.correct`; at every float format: `vadd.family`). At those
  cells, where an output float is finite it is TorchLean's `x + y` at that cell, and its real
  value is the real sum rounded to binary32
  (`MojoProofTest.Kernel.vadd_real`, in the tests).
- **A vector multiply kernel**, one kernel written for this repository: the same theorem
  (`MojoProof.Kernels.vmul.correct`). Where an output float is finite it is TorchLean's `x * y`
  at that cell, and its real value is the real product rounded to binary32
  (`MojoProofTest.Kernel.vmul_real`, in the tests).
- **The three elementwise kernels at every float format** (`vector_addition`, vector_multiply,
  vector_subtraction): for every format `t` (half, bfloat, float, double), the kernel's Float32
  program with its float accesses and operation retyped at `t` (`Program.retype`) is sound under
  the same premises at `t` (alignment that `t`'s divides, `Map2.Pre` at `t`), each output cell
  `k < min n (volume L.grid * volume L.block)` holding `x k + y k` (`*`, `-`) rounded at `t` and
  the rest of the output unchanged (`Map2.Pre` does not ask the launch to cover the `n` cells;
  `MojoProof.Kernels.vadd.family`, `vmul.family`, `vsub.family`; each is `vadd.sound_retype`, for
  every kernel with `vector_addition`'s layout and parameters and every launch that the retyped
  function's launch check `Func.checkLaunch` passes, at its kernel; the three kernels have no
  launch limit, so the families do not ask it). At float it is the
  Float32 theorem's statement, for all three kernels. At half and bfloat, for vector_addition
  only, the retyped function is the f16 and bf16 compile's up to its name (MojoProofTest/Formats.lean,
  where the two programs also agree on the intrinsics, globals, attribute groups and the
  declarations the kernel calls, and both kernels check, by `rfl`; vector_multiply and
  vector_subtraction have no f16 or bf16 corpus file), and the kernel theorems at those two files
  are generated there (`MojoProofTest.v16.correct`, `MojoProofTest.vb16.correct`, in the tests),
  not derived from the family: the theorem that would carry the family to the files' programs is
  planned in [docs/proofs/elementwise.md](proofs/elementwise.md), not built.
- **Modular's naive matrix product** (`matmul_kernel_naive`), float32 compiled with
  `fmul contract`, at every row stride of `A`, `B` and `C` (a family with the three stride
  constants as parameters; the multistage GEMM test's specialization and tests/corpus/naive_k512
  are two of its members), in the tests: for every oracle family, every valid launch whose side
  in `z` is 1, all sizes below `2 ^ 31`, blocks and tensors and every memory that meets the matmul
  precondition `Mat.Pre` at those strides (so `K` is at most both input strides), the kernel
  theorem holds: no run faults or races,
  every run terminates, and each cell `(r, c)` with `r < m`, `c < n` inside the launch's window
  holds the contracted dot loop of row `r` of `A` and row `c` of `B`, every other byte the
  caller's (`MojoProofTest.NaiveFam.sound`, from the library's `Kernel.sound_mat` with the run of
  a thread out of bounds and the run of a thread in bounds through its loop from an invariant of
  the loop at the heads of its rounds; the entry block is summarized as a function of the strides
  by `sym_summary_family`, and the invariant, its three premises and the run are proved by hand).
  At the GEMM test's strides it is `MojoProofTest.NaiveKernel.correct`, which `mojo_kernel`'s
  `mat … inv` clause also proves for that one program, with the function, the buffers, `Elem`,
  `Elem.Only` and the registers the loop keeps at every head.
  For every `K` up to the input strides (`K ≤ 768` at the GEMM test's), a finite cell is within
  `dotBound` of the real product at every oracle (`MojoProofTest.NaiveFam.matmul_error`;
  `MojoProofTest.NaiveKernel.matmul_error`), and at a thread whose oracle fuses no round the
  cell is TorchLean's `Tensor.matmul`, the same word or both NaNs
  (`MojoProofTest.NaiveFam.matmul_nanEq`; `MojoProofTest.NaiveKernel.matmul_nanEq`). For the
  same kernels compiled with contraction off, the cell is `Tensor.matmul`'s up to NaNs at every
  oracle (`MojoProofTest.NaiveOff.matmul_nanEqF`; `MojoProofTest.NaiveOff.matmul_nanEq` at the
  GEMM test's).
  The move to the contraction-off build reverses exactly at the never-fusing oracle rows
  (`Kernel.Obs.contractOff_iff`). At an oracle that fuses it does not: a kernel of one
  `fmul contract` and one `fadd contract` observes a word under fusion that its contraction-off
  build never observes (`MojoProofTest.ContractOff.twin`, one example).
- **Refutations**, every program: a violation the trace-replay checker reports disproves the kernel
  theorem at that input (`Kernel.replay_sound`). For every program, five wrong elementwise outputs
  (a cell left out, the output left unchanged, two cells swapped, zeros, a copy of an input) are
  each refuted once the checker reports their violation (`Kernel.replay_canaries`).
- **`rsqrt.approx`**, one intrinsic: the semantics gives `rsqrt.approx.ftz.f32` exactly the results
  that meet our reading of PTX's documented contract (`rsqrtOk`, with a rational relative error
  bound of 1.0718 times `2^-23`, just above PTX's `2^-22.9`; `rsqrtOk_of_rsqrt`,
  `rsqrt_toNatBits`), and FloatLib's reciprocal square root, with subnormal inputs flushed to zero,
  meets it, so the contract can always be met (`rsqrtOk_rSqrt`).
- **SAT certificates**, every formula: a RUP certificate that Lean's kernel checks proves the
  formula unsatisfiable (`MojoProof.Cert.unsat`).
- **Skeleton transfer**, every program that passes a labelling check of its registers (`Labels.Ok`):
  at one address choice, one run to the end with no fault, no race and no broken `!invariant.load`
  promise, from a memory whose stored pointers name only blocks it has allocated and a start whose
  reachable grids all meet the labelling's memory condition (`Labels.MemOk`), gives safety, race
  freedom, progress, termination and determinacy for every memory that differs from the first only
  in the data bytes of the payload blocks, at every float choice (`Grid.skel_run`, `Grid.skel_six`).
  At the kernel level, for every program, a set of address choices with one such run each gives the
  kernel theorem for the blocks and the trivial relation (`Kernel.skel_sound`), and one final grid
  per admitted choice whose observation meets the spec gives it for that spec
  (`Kernel.Sound.of_blocks`). The instances are `vector_addition` on one thread with count 5 at one
  address choice, for every memory that differs from one test memory only in the inputs' data bytes
  (`MojoProofTest.SkelVadd.skel_vadd`) and with the output's value at that memory
  (`MojoProofTest.SkelVadd.out_vadd`), and on six threads (`L23`) for every such memory
  (`MojoProofTest.SkelVadd23.skel_vadd23`), with `Labels.MemOk` from each thread's run alone
  (`Labels.MemOk.of_threads`, `memOk23`). `MojoProof.Kernels.vadd.correct` does not use this route.
- **The dot-product loop's floats**, every IEEE format and every length: the loop
  `acc := fadd acc (fmul a b)` from `+0`, with each `contract` step fused or not as the float choice
  says (`dotLoop`), is FloatLib's in-order dot product `Model.dotInOrder` when contraction is off,
  the same word or both NaNs (`dotLoop_nanEq`, `dotLoop_eq_dotInOrder`); with contraction on, at
  every fusion choice, a finite result is within `dotBound fmt K T` of the exact sum Σ aₖbₖ, where
  `dotBound fmt K T = ((1+u)^(K+1) - 1) T + (2+u) η ((1+u)^K - 1) / u`, `T = Σ |aₖbₖ|`, `u` the
  unit roundoff and `η` the underflow allowance (`dotLoop_error`); from `+0` the first addition is
  exact, so the bound has one power of `1 + u` fewer on the sum, `(1+u)^K - 1` in place of
  `(1+u)^(K+1) - 1` (`dotLoopBound`, `dotLoop_error_zero`); the exponent counts how far an error
  propagates (each later rounding multiplies an earlier error by at most `1 + u`), not the number
  of roundings, which unfused is `K` products and `K - 1` sums. One iteration of the
  semantics' `fmul` then `fadd` is one step of `dotLoop` (`floatBin_dotStep`).
- **Matrix product and matrix-vector cells**, every format and size: for TorchLean tensors `A`
  and `B`, the loop over row `i` of `A` and column `j` of `B` with contraction off is
  `get2 (Tensor.matmul A B) i j`, bit for bit when that is not a NaN, and a NaN exactly when it is
  (`matmul_cell_nanEq`, `matmul_cell_eq`); the exact sum is the entry of TorchLean's real matrix
  product (`matmul_cell_real`), and with contraction on a finite result is within `dotBound` of it
  (`matmul_cell_error`). The same four hold for a matrix times a vector (`matVec_cell_nanEq`,
  `matVec_cell_eq`, `matVec_cell_real`, `matVec_cell_error`). These are about the loop's floats;
  for rows of two strides `sA`, `sB` the same comparisons on the first `K` columns are
  `matmul_cols_nanEq`, `matmul_cols_eq` and `matmul_cols_error`, which the naive matrix
  product's kernel theorems below use; at one stride they are `matmul_take_eq` and
  `matmul_take_error`.
- **The warp's dot product**, every IEEE format, every length and every oracle: the two gemv
  kernels' order, the factor pairs split by position modulo 32 into strided lists (`stride`),
  each folded by `dotLoop` from `+0`, then five butterfly rounds of `Model.add` at lane 0
  (`warpDot`). Over the reals the rounds of the exact strided sums are TorchLean's matrix-vector
  and vector-matrix entries (`bfly_matVec`, `bfly_vecMat`); a finite result is within the error
  of `GPUProof.laneGrade (.ieee fmt) 32 5 ⌈K / 32⌉ K` at the words' real values and the grades
  `⟨0, 0⟩` of them (`warpDot_matVec`, `warpDot_vecMat`, from `warpDot_error`, which is
  `MojoProof.Sem.treeDot_error` at the butterfly's tree); with the contraction off it is FloatLib's `Model.reduceAlong` along the
  butterfly tree of the 32 in-order dot products, the same word or both NaNs (`warpDot_nanEq`,
  `warpDot_eq`), not the sequential fold (at 40 binary32 pairs the two differ,
  `MojoProofTest.WarpDot.eq40`); the same holds for every group of `2 ^ k` lanes (`groupDot_error`,
  `groupDot_matVec`, `groupDot_vecMat`, `groupDot_nanEq`, `groupDot_eq`), the warp's being `k = 5`;
  the butterfly shuffle reads lane `l ^^^ m` at every width's clamp (`shflSource_group`); and the
  semantics' rounds through `deliver`, at one oracle number
  or at an oracle number for every round and lane, are `Model.add`'s up to NaNs (`bflyRounds_nanEq`,
  `bflyDeliver_nanEq`), so a finite lane value is within the butterfly's bound
  (`bflyDeliver_error`). Every lane of the butterfly over `2 ^ k` strided loops is the lanes'
  loops added along its own tree of depth `k` over all the lanes, so it is `GPUProof.Approx` at
  `GPUProof.laneGrade` with exponent `⌈K / 2 ^ k⌉ + k` on the sum, finite when the grade's
  magnitude is at most the largest finite value (`MojoProof.Tile.bfly_approx`, `groupDot_approx`,
  from `MojoProof.Sem.treeDot_approx`). For gevm_kernel's transposition through
  shared memory: the accesses that give thread `(w, l)` cell `32 l + w` before the barrier and
  only reads after it are race free (`racy_tpose`, at every block of every launch with
  `ntid.x = 1024`, `Launch.tpose_env`; the store cell for every block of `32 W` threads,
  `Launch.warps_env`); on a run, cells written at any cell map injective on a block of threads
  before the barrier and only read after it make every schedule give the run's observation
  (`Grid.sound_cells`, with `sound_tpose` at the cell map `tpose 32` on every valid launch and
  cell width, and `sound1024` its instance at `ntid.x = 1024`), on a trace of rounds
  (`Grid.sound_rounds`), and gevm_kernel's two rounds meet it on every valid launch with
  `ntid.x = 1024`, with the loop's reads, the start's arrival at the barrier block and the last
  memory's owners as premises (`MojoProofTest.GevmTrace.gevm_sound`; the kernel theorem uses
  `racy_cells` at `tpose 32` on the run's phases directly instead,
  `MojoProofTest.GevmSound.grid_bad`), the events a
  thread's run to its next collective adds are its segment summary's loads and stores at the
  addresses its nodes evaluate to (`Waits.events`), each round of a trace of rounds, with every
  block's barrier between two rounds, is in that round's phase (`phases_rounds`), and gevm_kernel's
  segments before and after its barrier, run in turn by the threads, meet the access premise of
  `Grid.sound_cells` at `tpose 32` (`MojoProofTest.SegEvents.gevm_turns`), threads that store their
  values at their cells of a block in turn, one thread per cell, leave the tensor of the cells'
  writers (`Turns.cells`), so after gevm_kernel's first round and the barriers the shared array
  holds row-major the word of thread `tpose 32 x` at cell `x` and every thread of the second round
  starts on that memory (`MojoProofTest.SegEvents.gevm_buffer`, `gevm_reads`), and the rounds over
  the transposed cells are `warpDot` of the column's pairs (`warpDot_tpose`). A vector `bitcast` of
  an `n · w`-bit word gives its `n` `w`-bit pieces, low first, and back (`castV_split`,
  `castV_join`). gemv_kernel's done grid holds each row's `warpDot` up to NaNs at one-dimensional
  launches whose block's `x` size 32 divides and whose row count is at least `M` (`grid_rows`,
  above); gevm_kernel's start steps to a done grid that holds each column's
  `warpDot` up to NaNs (`MojoProofTest.GevmWarp1.grid`, `ColsDot`, which is
  `MojoProof.Tile.WarpWords` at `vecMatPairs`) at one-dimensional launches with 1024 threads a
  block and `N = 32 · L.grid .x`, from the kernel's arguments and the caller's buffers, at
  address choices that put each block's shared array below `2 ^ 32`. The shared arrays at the
  start are for every program (`MojoProof.Sym.Grid.start_shared`: each block of threads' globals
  entry and block, owned by it). A last block past `N` is not a case of the kernel, since the IR
  has no guard against `N`. For sum_kernel's
  pattern: the halving tree of a reduction in shared memory has no race (the core's `racy` at
  `sig`) for every block size, cell width and stride sequence, on a trace whose accesses are by the
  launch's threads in their blocks and that is shaped, as every reachable grid's is
  (`racy_halving`, `Grid.start_reach_fits`), with the output word's `atomicrmw`s
  (`racy_dropBlocks`, on a run `Grid.sound_halving`), and the output word of an `atomicrmw add` sum
  is the same for every order of the blocks (`rmw_add_perm`). That the kernel's runs have these
  patterns is not proved.
- **Reductions along any tree**, every IEEE format, every length and tree
  (MojoProof/Float/, docs/proofs/float-reductions.md): a finite sum of words along any FloatLib
  `ReductionTree` whose leaves are a permutation of the indices has finite inputs and is within
  `((1 + u) ^ depth - 1) · Σ |v j|` of the exact sum (`sum_error`), and for approximate inputs
  within the tree form of FloatLib's left-fold mixed error (`sum_mixedError`); a butterfly at
  any order of the offsets `1, 2, …, 2 ^ (k - 1)` has every lane below `2 ^ k` as a leaf once
  (`leaves_bfly`); the shared-memory halving loop over `2 ^ k` cells is a tree of depth `k`
  with every cell once (`leaves_halve`, `depth_halve`, `halve_error`), and a butterfly in each
  warp followed by any tree over the warps is one tree whose depth is the sum (`block_error`);
  the two-pass mean and variance along any two trees, divided by a word whose value is `n`,
  are within mixed errors of the exact mean and TorchLean's `TorchLean.var` (`mean_error`,
  `var_error`); a tree of `maxnum` over finite inputs is exact in every format (`max_exact`);
  the sum of correctly rounded exponentials of the rounded differences with a word `m` is
  within a mixed error of `Σ exp (x j - m)` (`expSum_error`), and when `m` is an input's
  value each softmax entry is within a mixed error of TorchLean's real softmax
  (`softmax_error`). In the kernel's order `e_j * (1 / s)` (the reciprocal rounded, then the
  product), the entry is within a mixed error of the same softmax with one more rounding
  (`softmaxRecip_error`; every IEEE format, `n`, tree and set of kept indices; instances at 4 and
  8 inputs). One binary32 instance each (MojoProofTest/FloatTree.lean,
  MojoProofTest/FloatStats.lean). Masked inputs `-∞`: a term of a `-∞` difference is `+0`, and the
  sum and each softmax entry over the kept indices are within mixed errors of the exact sum and
  TorchLean's softmax over them (`expTerm_negInf`, `maskSum_error`, `maskSoftmax_error`; the
  unmasked bounds are their cases); with FloatLib's correctly rounded log, log-sum-exp `m + log s`
  and the log-softmax entry `(x j - m) - log s` are within mixed errors of `log Σ exp x` and
  `x j - log Σ exp x` (`lse_error`, `logSoftmax_error`). FloatLib's addition commutes up to NaN
  payloads in every format (`MojoProof.Float.add_comm_nanEq`), so two trees with the same canonical
  form up to swapped children (`MojoProof.Float.canon`, for every leaf type with a linear order)
  have sums that are equal or both NaNs at every input (`eval_nanEq_of_canon`); conversely, in every
  IEEE format, two trees over the same distinct leaves whose sums agree up to NaN payloads at every
  input have the same `canon` (`MojoProof.Float.eval_add_eq_iff`, MojoProof/Float/CanonIff.lean;
  tests in MojoProofTest/FloatCanonIff.lean at 3 and 6 leaves in binary16, binary32 and binary64,
  and the mutant with `=`). So the sums of `n` distinct inputs up to NaN payloads are in bijection
  with the canonical trees over `Fin n`, in every IEEE format and for every `n`
  (`MojoProof.Float.sumFunctionEquiv`, `card_sumFunction`, MojoProof/Float/CardSums.lean); the
  counts at one and two inputs are tests (MojoProofTest/FloatCardSums.lean). The number of these
  sums is `(2n - 3)‼` for every `n ≥ 2`, in every IEEE format (`MojoProof.Float.card_sums`, from
  `card_canonTree`, the canonical trees over `Fin n` for every `n ≥ 1`; tests at 3 and 4 inputs in
  binary32 and binary16). A warp's butterfly lanes below `2 ^ k` after the rounds `bflyOffsets k`
  and cell 0 after the halving rounds over `2 ^ k` cells have one canonical form, the halving tree,
  for every `k`, so their sums agree up to NaN payloads in every format at all values
  (`MojoProof.Float.canon_bflyOffsets`, `canon_halve`, `bfly_nanEq_halve`,
  MojoProof/Float/CanonHalve.lean; tests in MojoProofTest/FloatCanonHalve.lean at 2, 4, 8 and 32
  lanes). Every lane's tree is lane 0's relabelled by XOR for every offset list
  (`MojoProof.Float.bflyTree_xor`), and after `bflyOffsets k` in any order lane 0's tree is
  canonical and lane `l`'s canonical form is it relabelled `j + 2 ^ k ⌊l / 2 ^ k⌋`, for every `k`
  and lane (`MojoProof.Float.canon_bflyTree_perm`; tests at 4 and 8 lanes, in other orders and
  above `2 ^ k`). That a grid run of a kernel computes these trees is not proved;
  the corpus's layer norm merges Welford statistics across lanes, which the next bullet bounds.
- **Welford statistics, layer norm, RMS norm and the compiled exponential** (MojoProof/Float/,
  docs/proofs/float-welford.md, float-norm.md, float-reductions.md): Welford's merge as the corpus's
  layer norm executes it, along any tree in every IEEE format with at most `2 ^ p` leaves and inputs
  within `B`: finite words give the exact count, a mean within `(welfErr u η B d).1` of the inputs'
  mean and a sum of squared deviations within `l · (welfErr u η B d).2` (`welford_error`), so the
  mean word is near `𝔼 x` and the variance word near `TorchLean.var` (`wmean_error`, `wvar_error`);
  in binary32 with `rsqrt.approx`'s contract, a finite layer norm output
  `((x j - μ) · r) · γ j + β j`, fused or not, is within a mixed error of TorchLean's
  `TorchLean.TransformerBlock.layerNorm` (`lnorm_error`), and a finite RMS norm output
  `(x j · r) · γ j` is within a mixed error of `x j / √(𝔼 x² + ε) · γ j` with the mean of squares of
  `msq_error` (`rmsnorm_error`; TorchLean has no closed form of its RMS norm over the reals). Mojo's
  float32 `exp` is `ex2.approx.ftz.f32` of `(x - m) · log2e`; under that instruction's contract
  (`Ex2Close`, T17) a term is within `(ex2Rel u η ρ (x - m), 2^-126)` of `exp (x - m)` (`ex2_error`,
  with `log2e_close`), and a finite sum along any tree is within `expSum_error`'s form with that
  term error (`ex2Sum_error`). One binary32 instance each (MojoProofTest/FloatWelford.lean,
  FloatNorm.lean, FloatEx2.lean). For every choice of contraction at each node of the tree, each of
  the merge's two `fmul`/`fadd` pairs fused or not, the same bounds hold (`welfordC_error`;
  `welford_error` is its case with no pair fused). Welford's loop over a list of at most `2 ^ p`
  words (`p` the format's precision), as the layer norm kernels' loop updates it, for every choice
  of contraction at each iteration, has the exact count and the mean and sum within `welfErr`'s
  bounds at depth `l - 1` (`wloop_error`). Mojo's RMS norm with a weight offset, in both of its
  orders (the offset added in binary32 and the product cast to the dtype, or the product cast and
  the offset added in the dtype), is within a mixed error of `x j / √(𝔼 x² + ε) · (γ j + o)` for
  every IEEE dtype, with binary32 inputs (`rmsOff_error`, `rmsnormOff_error`), and with inputs of
  every IEEE format with at most binary32's widths cast to binary32, whose widening cast is exact
  (`cast_widen`, `rmsnormOff_widen`). Instances: MojoProofTest/FloatWelford.lean and
  FloatNorm.lean, at two sizes each, and at binary16 and bfloat16 inputs. Not proved: input
  formats other than IEEE's, a merge with an empty state, the loop composed with the merges, a
  softmax entry under the contract, and a grid run.
- **Layout laws**, every layout meeting each premise: on a model of Mojo's layout library
  transcribed from modular/modular bbc13a71 (trusted, T16), a scalar coordinate below the size
  of a layout whose shape and stride are congruent has the offset of its colexicographic digits
  dotted with the strides (`Lay.call_scalar`), below the cosize (`Lay.call_lt_cosize`), and
  coalesce keeps the size and every such offset (`Lay.coalesce_call`); a coordinate mixing
  scalars and tuples, each scalar below its sub-shape's size, has the offset of its digits
  dotted with the strides, on every shape (`Lay.call_mixed`); a flat layout is affine in its
  coordinates (`Lay.call_add`), and `is_affine` holds for it with what it promises, a step of n
  in coordinate k adds n times stride k (`Lay.isAffine_flat`); `row_major` of positive extents
  is a bijection onto `[0, size)` (`rowMajor_inj`, `rowMajor_onto`); idx2crd inverts a flat
  layout whose modes are nested in order or in reverse order, with positive strides
  (`idx2crd_call`, `idx2crd_call_reverse`); zipped divide keeps the size when every tile extent
  divides its extent (`Lay.zippedDivide_size`); upcast by `f` of positive strides, each a
  multiple of `f` or a divisor `s` of it with `f / s` dividing the extent, has the modes
  `(e, s / f)` or `(e / (f / s), 1)` (`Lay.upcast_fuse`), and `f` times its offset of c is the
  original offset of c with each digit times `shape_div(f, s)` (`Lay.upcast_scale`), which
  covers the docstring's `row_major[4, 8]`; a `w`-bit offset is exact when the offset is below
  `2^w` (`Lay.call_flat_toNat`); a swizzle with `bits ≤ |shift|` is its own inverse
  (`Swizzle.call_call`) and every swizzle is linear over F2 (`Swizzle.call_xor`); every bit
  layout is linear over F2 (`BitLayout.call_xor`), and the placement of a flat layout that
  `is_bit_linear` accepts, with extents, strides and size within 64 bits, has the domain mask
  size − 1 and is the layout's offset at every point below the size (`placement_call`); for
  every swizzle and every flat layout that passes the asserts of `two_level_layout_from_swizzle`
  (extents and strides powers of two below `2^64`, and no offset bit reached by the inner bits
  of two modes), the two-level layout is the swizzle of the layout's offset at every tuple
  coordinate inside the shape and every index below the size (`Swizzle.twoLevel_call`);
  composing a layout A whose shape and stride are congruent with a layout B of any number of
  modes, each meeting the divisibility premise `composeDiv`, maps B's index v below B's size to
  the sum of A's offsets of B's mode terms (`Lay.compose_sum`), and to A's offset of B's offset
  of v when those terms do not carry against A's extents (`noCarry`, `Lay.compose_call`), which
  a single mode never does (`noCarry_one`); when B's term lists (x · d for x < s, for each mode
  (s, d)) are `carryFree` against A's extents, a premise on A and B alone, that holds at every
  v below B's size (`Lay.compose_all`). Without the premises, counterexamples hold by
  evaluation (composition with one mode, filed as modular/modular #7738, and with two modes
  that carry; blocked product; idx2crd; zipped divide; upcast; the swizzle; (2, 2):(1, 1),
  whose extents and strides are powers of two but which is not linear over F2; and the
  two-level swizzle with overlapping inner bits, at a tuple coordinate past an extent, and with
  a zero shift, where its inner map is not one-to-one). Tests, not proofs: the compiler's
  folded values equal the model's on 43 static layouts, and a CPU run of a compiled program
  gives the model's values on 8 of 9 layouts with runtime leaves; on the ninth, past its size
  0, Mojo's remainder by 0 is 0 where the model's keeps the dividend. Not proved: the
  injectivity of the two-level inner map, nested layouts in `is_bit_linear`, and that
  `carryFree` is necessary as well as sufficient.
- **The tile layer**, outside the trusted base: tile programs over numbered buffers and their
  interpreter (`run1`, `runAll`, MojoProof/Tile/Basic.lean). For every kernel whose theorem has
  `Kernel.sound_map2`'s conclusion, every observation of a complete run holds at each thread's
  output cell the value of cell `k` of buffer 2 of the run of `map2 op n` at the tile oracle
  computed from the kernel's paths (`map2_refines`); `vadd_tile`, `vmul_tile` and `vsub_tile`,
  generated by one test command, at every valid one-dimensional launch, memory, count and
  input. For every float format, flag, sizes with `K` at most the row lengths, matrices,
  placement with no two threads at one cell and tile oracle, the run of `dot c K` ends without
  a fault and each placed cell holds a word that is TorchLean's `Tensor.matmul` of the first
  `K` columns up to NaN when no step fuses, and within `dotBound` of the real product when the
  format is IEEE and the word finite, and `GPUProof.Approx` at `GPUProof.dotGrade` of the row and
  column for every input grades at which the inputs are `Approx` (`dot_run`, `dot_meets`,
  `Meets`). For every kernel sound
  for `Elem.Out` with `matBytes` at the cells of `Kernel.sound_mat`'s conclusion, on every
  launch valid with `z` sides 1, every cell in bounds and in the launch's window is computed by
  a thread whose output word is the tile run's cell and meets the product (`mat_refines`); the
  naive matmul's row-stride family at every row stride and every `K ≤ min sA sB` (`naive_tile`,
  from `NaiveFam.sound`). When the second matrix has one row, the floats of the observed output
  block at the rows' cells meet `GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule (`mat_holds`;
  `naive_holds`), and the kernel's behaviors at setups that fit meet the spec through
  `GPUProof.MeetsAt` (`kernelRows_meetsAt`; `naive_meetsAt`, with a behavior at every size within
  the family's bounds, `naive_rows`). Not proved: the loop's oracle steps from the kernel's paths
  (they come from the kernel's spec), phases, shared memory and collectives.
- **Tensor-core fragments and `mma`**, every layout family: the A, B and C/D fragments of
  `mma.m16n8k<k>` (tf32, bf16 and f16 inputs with f32 accumulators, f64, and 8-bit and 4-bit
  inputs), of `mma.m8n8k4 .f64` and of `mma.m8n8k4` with f16 inputs (the four quad pairs'
  tiles, stacked), the f16 accumulators, and the destinations of `ldmatrix.x<q>`, with and
  without `.trans`, are bijections between the 32 lanes' registers and the tile, checked
  against the PTX ISA's tables at `m16n8k8 .tf32`, `m16n8k16`, `m16n8k32`, `m16n8k64`,
  `m8n8k16`, `m8n8k32` and `m8n8k4` (f64 and f16); `ldmatrix` loads the A and B operands;
  `mma` on the fragments is TorchLean's `matmul A B + C` over the reals, and within a stated
  bound of it under an accumulation contract (trusted, T14; docs/proofs/tensor-core.md).
  The grid runs a warp's `mma` under the launch's accumulation policy (`Launch.acc`, an
  `MmaAcc`; `gridAcc` by default, `seqAcc` the round-to-nearest sequential one, with contracts
  `gridAcc_ok` and `seqAcc_ok`): for every launch, grid and warp whose 32 lanes wait at one
  `mma` at one instruction, of a shape `Mma.table` lists with bf16 or f16 inputs and an f32
  accumulator, on finite words, with no range, nonnull or align on the waiting functions'
  returns, `fire` returns a grid with the same memory and other threads, each lane resumed with
  its D registers, which hold the policy's value of the tiles its A, B and C registers encode
  (`Grid.fire_mma`). On the lanes' registers, `mma` and `ldmatrix` give the
  fragments' tiles (`mmaWarp_spec`, `ldmWarp_spec`). Tests: MojoProofTest/TensorCoreGrid.lean
  (one program at two shapes, and refusals at m16n8k24 bf16 and m16n8k32 f16) and
  TensorCoreWarp.lean.
  One A100 agrees with the `mma.m16n8k16` bf16 and `ldmatrix.x4` layouts, and its
  accumulation exceeds `dotBound` once (tests/gpu/mma/ and tests/gpu/ldmatrix/, conformance
  tests).
- **Fused tensor-core accumulation**, every IEEE accumulator format, every input format, block
  size `n ≥ 1`, width and count: the accumulation `fuseAcc fi fc n p` meets the `mma` contract
  `AccBy` with the bound `fuseBound fc n p ⌈K / n⌉` (`fuseAcc_ok`). It works in blocks of `n`
  products, each addend truncated toward zero to `p` bits below the largest one's leading power,
  the sum rounded by `fuseRound fc`: FloatLib's `roundRat` toward zero while its magnitude is at
  most the largest finite one `M`, `M` with the sum's sign beyond that and below `2^(emax + 1)`,
  and the infinity of the sum's sign from `2^(emax + 1)` on (an exact `2^128` in binary32 gives
  `+∞`, MojoProofTest/TensorCore.lean).
  This is about the model. That an A100's `m16n8k16 .bf16` computes it at `n = 8`, `p = 24` is a
  recorded measurement (tests/gpu/mma/record.txt).
- **Asynchronous copies**, every sequence of one thread's operations and every completion
  order the ISA permits (a pending copy may land at any time, trusted, T15): after
  `cp.async.wait_group n` at most `n` groups are pending and every copy of the older groups
  has landed; after `wait_group 0` every copy committed before it has landed, its bytes
  visible when the destinations of the issued copies are disjoint; a byte written again only
  after a wait for its previous writer holds the same value in every run; race freedom is the
  caller's premise (docs/proofs/async-copy.md; one A100 run agrees, tests/gpu/cp-async/).

Not proved yet:

- kernel theorems for corpus kernels with shared memory or barriers, and for the other 12
  specializations of the naive matrix product in the GEMM test (the nine other float32 ones are
  not yet checked to be members of the row-stride family): the importer accepts `tiled_matmul`
  and most other corpus files, but only the elementwise kernels above, the tutorial's
  `vector_subtraction` and the naive matrix product's row-stride family have a kernel theorem;
  for the family's threads in bounds the loop's invariant, its three premises and the run are
  proved by hand in the tests, and for the GEMM test's one program `mojo_kernel` generates the
  run from them (with the function, the memory facts and the registers the loop keeps at the
  loop's heads), not the invariant;
- launches other than one-dimensional ones for the elementwise kernels above (the naive matrix
  product's theorem covers every valid launch with side 1 in z), and real MAX kernels (layer norm,
  softmax, GEMM) against the PyTorch-level operations they implement;
- that a grid run reaching `ldmatrix` or `cp.async` computes the models above: the grid does
  not dispatch them yet; and a grid `mma` other than bf16 or f16 inputs with an f32 accumulator
  on finite words;
- the naive matrix product's, gemv_kernel's and gevm_kernel's theorems at their Mojo
  1.3.0.dev2026112705 compiles (tests/corpus/mgemm_dev2026112705/, gemv_dev2026112705/): that
  compiler folds blocks of their control flow, and gevm's shared tile has another type, so the
  hand-written chains and runs do not apply; the vector kernels' compiles there are the pinned
  files' bytes, so their theorems hold at them (MojoProofTest/Nightly.lean);
- anything after the LLVM IR: LLVM's optimizer, the NVPTX backend, `ptxas`, the driver and the GPU;
- the lexer, parser and printer, which are checked on every corpus file and at every import
  (printing gives back the file's tokens) but not proved.

What the theorems assume (Lean and the libraries, where the IR comes from, and our reading of
LLVM's and PTX's documentation) is listed in [docs/TRUST.md](TRUST.md).
