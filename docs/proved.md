# What is proved

MojoProof reads the LLVM IR file that `mojo build --emit llvm` writes for each GPU kernel, gives
it a semantics in Lean (integers, byte memory, threads, barriers, warp shuffles, and IEEE floats
through [FloatLib](https://github.com/lean-dojo/FloatLib)), and proves theorems about it. The
semantics leaves two things to choices: an address choice (where the blocks a launch allocates
are placed) and a NaN choice (the payload of each NaN result, and whether and how a `contract`
operation is fused). A kernel theorem (`Kernel.Sound`) says that, at every address choice and NaN
choice it admits, the launch starts and has no undefined behavior, no unsupported operation, no
data race and no deadlock, that no write touches bytes that a load marked `!invariant.load` reads,
that every run terminates, that every schedule gives the same result, and that the result meets
the spec. Each line below gives its scope (every program, a family of kernels, one named kernel,
one intrinsic, every formula or every float format) and the Lean declaration.

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
  `laneGrade_mag`, monotone, `laneGrade_mono`), with the dot product's grade `dotGrade` its
  one-lane case at depth 0 and the matrix-vector grades `laneVecGrade` and `matVecGrade` (its
  one-lane case) from it, by definition, and `vecMatGrade`, for every length, with the exact dot
  bound below it (`dotBound_le_dotGrade`) and the loop's own bound as its error (`dotGrade_ieee`:
  `MojoProof.Sem.dotLoopBound`, with `(1 + u) ^ n - 1` on the sum, `dotLoop_error_zero`). For
  every binary interchange format, flag, oracle sequences, lane count, length, tree over the
  lanes and input grade, lanes' dot loops added along the tree are `GPUProof.Approx` at
  `laneGrade` (`MojoProof.Sem.treeDot_approx`), and so is the dot loop at `dotGrade`
  (`dotLoop_approx`, its one-leaf case, with its error part `dotLoop_error_graded` and its
  finiteness `isFinite_dotLoop`) and every lane of a butterfly over `2 ^ k` strided loops at
  depth `k` (`MojoProof.Tile.bfly_approx`, `groupDot_approx`; gemv's word per row meets
  `Spec.matVec (laneVecGrade (2 ^ k) k ⌈n / 2 ^ k⌉)`'s rule, `groupDot_holds`). Every kernel of
  `mojo_kernel`'s `mat` clause whose second matrix has one row meets `Spec.matVec matVecGrade`'s
  rule at the cells `(i, 0)` of its tile run (`MojoProof.Tile.mat_holds`; instance: the naive
  matmul family, `MojoProofTest.TileNaive.naive_holds`); gemv's kernel theorem against it is not
  proved yet ([docs/proofs/spec.md](proofs/spec.md), [docs/proofs/dot.md](proofs/dot.md)). The design's
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
  (MojoProofTest/GPUProof/MixedRadix.lean).
- **Schedule independence**, every program: from a memory whose stored pointers name only blocks
  it has allocated, the steps of a launch are confluent up to faults and races (`Grid.confluent`),
  so one run to the end with no fault, no race and no broken `!invariant.load` promise shows that
  every schedule of that launch is safe, race free, makes progress, terminates and gives the same
  result, for every observation that reads only the memory's blocks (`Grid.start_sound`); the
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
  `path_walk`, `path_retWith`, `path_dead`, `path_steps`). Loops through blocks with `alloca`
  (`coversChainsAt`) are sound for every program too, and the blocks the cleanup sets dead are
  exactly those the run adds to the start memory (`Runs.of_chainsAt`, `Mem.Adds`). So a
  postcondition that reads only the start memory's blocks holds after the cleanup, with the run's
  blocks dead (`Runs.of_chainsDead`). Test, one program: `MojoProofTest.SymLoopAlloca.loopK_run`,
  the rounds' blocks dead and an output block's word kept, with the mutant `loopK_inUse`, a start
  memory whose fresh number is taken. A chain whose last path out stops after its last edge takes
  the thread to the frame it enters (`ChainWith.enter`, `RunsVia.of_chain`). gemv_kernel's thread
  runs at one context, frame, memory and choice of delivered values:
  - from statement 41 of `%6` to `ret` (`MojoProofTest.SymGemvTail.tail_runs`);
  - from statement 0 to `ret` on the `%43` branch (`gemv_runs`);
  - from statement 0 through the loop at `%54` with no round and `%78`'s five shuffles to `ret`
    (`gemv_loop_runs`).
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
  the last one into any continuation (`Piece.throughTo`), with the segments' premises one Boolean
  that the kernel decides (`Piece.fires`, `RunsVia.of_fires`), and a resumed frame has
  the summary's value at every register but the call's result (`Seg.resume_regs`, by
  `Thread.resume_regs`).
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
  the two are not yet joined. A schedule through collectives is the next item; none is built from
  a kernel's segments yet.
- **A start through a schedule of collectives**, every program and launch: a launch whose
  threads run in turn to a wait, then the phase's collectives fire, phase after phase, and then,
  resumed, in turn to their ends, with no race and the `!invariant.load` promise kept, is sound
  (`Sched.start_sound`). A phase is every block's barrier (each block's own number, below 16;
  `Fires.barriers`, by `Grid.fire_barriers`) or every warp's shuffle of one mode with the full
  mask, each lane resumed with the operand of the lane `shflSource` names (`Fires.shfls`, by
  `Grid.fire_shfl`). The start through one barrier (`Seq.start_sound_bar`) is its one-line case.
  After butterfly rounds at offsets `ms`, the lanes of a warp of width `2 ^ k`, `k ≤ 5`, hold
  `bflyRoundsAt F` of their first values, for a combination `F r l` per round and lane
  (`bflyRoundsAt_of_shfl`; `bflyRounds` is the case `F = fun _ _ => combine`). Tests: `Launch.k` on
  one block of two threads (MojoProofTest/SymWait.lean); a kernel with a barrier and two butterfly
  shuffles
  on one block of four threads, sound, each lane holding the sum of the four thread numbers,
  with an open-goal twin for a missing fire (MojoProofTest/SymColl.lean). The schedule's phases
  may be given by invariants on each phase's threads, statuses and memories
  (`Sched.start_sound_inv`), with the barrier's and the butterfly shuffle's fires from each
  status's facts (`Fires.barriers_at`, `Fires.bfly`) and a thread's first wait, at its named
  instruction, from its segments (`Seg.Through.wait`). Test: a barrier and two butterfly
  shuffles on one block of 4 and of 8 threads, sound, with an open-goal twin
  (MojoProofTest/SymChain.lean).
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
  nested loop, and a loop that has no clause.
- **Loops**, every program: a loop the checker accepts runs its rounds back to its header for every
  trip count whose rounds meet their conditions (`Block.sound_loop`), and a thread runs through a
  sequence of loops, nested ones included, to its end, with or without `alloca`s in the loops'
  blocks (`Runs.of_chainWith`, `Runs.of_chainsAt`), the blocks set dead at its end the ones the
  run adds (`Mem.Adds`, `Runs.of_chainsDead`). This is only partly
  automated: the invariant and the trip count are the user's, and the rounds' conditions are
  closed by `decide +kernel` at a concrete launch. The kernel theorems that the `loop` clause gives
  are for test programs, each at one memory, address choice and NaN choice (the naive matrix
  product's theorem below is not: it holds for every memory, input and launch of its shape): the
  counting loop "for i in [0, n): p[i] = i" run by one thread with `n = 3`
  (`MojoProofTest.KernelLoop.kernelK`, the generated `loopK.sound_loop` with no evaluation of the
  start), and six threads in two blocks that each run
  a counted loop and then store one cell, apart only on the storing threads
  (`MojoProofTest.KernelCells.kernelC`, through `Kernel.sound_cells`); for two such loops in
  sequence the command gives the thread's run (`MojoProofTest.KernelLoop.cnt2k_retLs`).
- **Binary elementwise kernels**, a family: every kernel whose parameters are three `byval` structs
  that each hold a buffer pointer (two inputs and an output, as Mojo passes tensors) and an `i32`
  count, at one NaN choice and every address choice, meets the kernel theorem for memories and
  inputs that meet `Map2.Pre`, given that the launch starts and that each thread takes a checked
  path to `ret` storing the spec's bytes (`Kernel.sound_map2`). For every kernel with this theorem,
  at each output cell `k` below `n`, below the inputs' length and below the number of threads `T`, a
  finite output float is the operation applied to the inputs' cells `k` (`Kernel.map2_real`); when
  the theorem holds at every NaN choice, two runs give at that cell equal floats or two floats that
  are each NaN or infinite (`Kernel.map2_finEq`), so a finite output is the same at every address
  choice and NaN choice (`FinEq.eq_of_isFinite`). With `T` threads the theorem covers the first
  `min n T` cells, so all `n` cells when `T ≥ n` (`Kernel.map2_min`). The kernel theorem itself
  holds for any number of `byval` buffer structs and a count of any type, at one NaN choice and
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
  of length `N`, and `n < 2^31`), every address choice and every NaN choice, the kernel theorem
  holds: each output cell `k` below both `n` and the launch's number of threads holds `x k + y k`
  rounded to binary32, and the rest of the output and every other block of that memory are
  unchanged (`MojoProof.Kernels.vadd.correct`). At those cells, where an output float is finite it
  is TorchLean's `x + y` at that cell, and its real value is the real sum rounded to binary32
  (`MojoProofTest.Kernel.vadd_real`, in the tests).
- **A vector multiply kernel**, one kernel written for this repository: the same theorem
  (`MojoProof.Kernels.vmul.correct`). Where an output float is finite it is TorchLean's `x * y`
  at that cell, and its real value is the real product rounded to binary32
  (`MojoProofTest.Kernel.vmul_real`, in the tests).
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
  in the data bytes of the payload blocks, at every NaN choice (`Grid.skel_run`, `Grid.skel_six`).
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
  `acc := fadd acc (fmul a b)` from `+0`, with each `contract` step fused or not as the NaN choice
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
  memory's owners as premises (`MojoProofTest.GevmTrace.gevm_sound`), the events a
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
  `castV_join`). That a grid run of either kernel computes `warpDot` is not proved. For sum_kernel's
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
  `x j - log Σ exp x` (`lse_error`, `logSoftmax_error`). That a grid run of a kernel computes these
  trees is not proved; the corpus's layer norm merges Welford statistics across lanes, which the
  next bullet bounds.
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
  every IEEE dtype, with binary32 inputs (`rmsOff_error`, `rmsnormOff_error`). Instances:
  MojoProofTest/FloatWelford.lean and FloatNorm.lean, at two sizes each. Not proved: inputs of a
  narrower dtype cast to binary32, a merge with an empty state, the loop composed with the merges,
  a softmax entry under the contract, and a grid run.
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
  from `NaiveFam.sound`). When the second matrix has one row, the cells `(i, 0)` meet
  `GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule (`mat_holds`; `naive_holds`). Not proved: the loop's oracle steps from the
  kernel's paths (they come from the kernel's spec), phases, shared memory and collectives.
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
- anything after the LLVM IR: LLVM's optimizer, the NVPTX backend, `ptxas`, the driver and the GPU;
- the lexer, parser and printer, which are checked on every corpus file and at every import
  (printing gives back the file's tokens) but not proved.

What the theorems assume (Lean and the libraries, where the IR comes from, and our reading of
LLVM's and PTX's documentation) is listed in [docs/TRUST.md](TRUST.md).
