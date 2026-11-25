# Proof documents

Each file states one family of theorems with its exact premises and scope, gives the informal proof,
and names the Lean declarations, the instances and the twins (tests showing that a premise is needed).
The Lean statement is the reference: where a document's statement and the Lean one differ, the
document says so. The parts below go from the grid of threads to single kernels; each part uses the
ones before it. Some documents number their statements (T2 to T5, with parts such as T3a) and
invariants (W1 to W5); these numbers are the documents' own, not the items of `docs/TRUST.md`.

## 1. One run is enough

1. `one-run.md`: `Confluent.one_run`, for every relation: if a step relation is confluent up to an
   equivalence and a set of bad states (`Confluent`), one run to a normal state that is not bad shows
   that every run from the start is finite, that no reachable state is bad, that every normal
   reachable state is equivalent to that one, and that every reachable state reaches a state
   equivalent to it in at most as many steps as the run (`GPUProof/OneRun.lean`).
2. `adapter.md`: `Grid.sound_of_one_run`, the seven fields of `Grid.Sound` from one run, for every
   program: for a step relation on states that projects onto `Grid.Step` and lifts every grid step,
   confluent up to an equivalence that keeps `Done` and the observation, with persistent bad states
   that include faults, racy traces and broken `!invariant.load` promises, one run to a done state
   that is not bad and whose observation meets `R` makes the start's grid sound. It is the core's
   `GPUProof.Clean.of_lift` at `sig`, carried back by `Grid.Sound.of_clean`. Its instances:
   `Grid.sound_commuting` (`N` threads that each return in one step, changing the memory by maps
   that commute and keep the trace; at 2 and 3 threads that end their allocas: `MojoProofTest/Close.lean`,
   `sound_dead`) and its case `Grid.sound_returning` (no change of the memory),
   for every observation and relation that the final memory meets when its trace has no race and
   keeps `!invariant.load` (at one thread on `Launch.one`: `MojoProofTest/Close.lean`,
   `sound_one_ret`); and `Kernel.sound_ret_launch`, the kernel `ret void`, on every launch, closed
   memory, address choice and oracle (`MojoProof/Sem/Trace.lean`). Its section "The observation of
   an elementwise output": the observation of a block after stores to some of
   its cells, for every layout, codec, shape and order (`Block.holds_writes`, `Mem.tensor_writes`),
   on a rank-1 binary32 buffer (`Mem.tensor_vec`), and TorchLean's elementwise `a + c` when every
   cell stores what `fadd` gives and no sum is a NaN (`Mem.tensor_vec_add`,
   `MojoProof/Sem/Elementwise.lean`; instances `vec_inst`, `add_inst`, twins `add_twin_partial`,
   `add_twin_nan` in `MojoProofTest/Elementwise.lean`).

## 2. Schedule independence and race freedom

3. `schedule.md`: T2, schedule independence up to bad grids (a fault or an enabled race), for every
   program, kernel, launch, arguments, address choice and oracle, on a caller's memory whose pointer
   bytes name known numbers (`Grid.confluent`, `MojoProof/Sem/Determinism.lean`). Its conclusions:
   one run to a done grid that is not bad makes the start's grid sound for every observation that
   reads only the blocks (`Grid.start_sound`); a barrier with a running participant does not
   complete, for every launch with non-empty blocks of threads (`Grid.fired_run`), so an enabled
   race stays enabled or makes the trace racy at contexts that put each running thread `n` in block
   `n / volume L.block` (`Grid.Step.raceEnabled_of_ctx`); if a reachable grid is bad, so is every
   reachable grid
   without a step (`Grid.start_refute`). The document lists the lemmas in order: the trace relation
   `Trace.Same` and the grid relation `Grid.Same`, the pending accesses of a step
   (`Thread.pending`, `step_pending`), the cases of the diamond (two threads' steps,
   `Grid.advance_comm`; a step and a collective call, `Grid.advance_fire_comm`; two collective calls,
   `Grid.fire_fire_comm`; two `atomicrmw`s of one operation at one pointer,
   `Grid.advance_atomic_comm`), and that a bad grid stays bad (`Grid.Step.bad`,
   `MojoProof/Sem/Bad.lean`). Two design choices make it hold: the diamond admits two bad grids
   (S1), and an admitted `atomicrmw` leaves its result register unset (S2). The invariants W1 to W5
   hold in every grid reachable from the start, for every program (`MojoProof/Sem/Confluence.lean`).
   Instances and twins: `MojoProofTest/Determinism.lean`, `Bad.lean`, `Start.lean`.
4. `schedule-owned.md`: T2′, schedule independence under an ownership discipline, for every program
   whose accesses follow one tiling (`Grid.confluent_owned`, `Grid.owned_bad`, `Grid.owned_clean`,
   `MojoProof/Sem/ScheduleOwned.lean`), and `Grid.Sound` from one run whose trace meets the
   discipline (`Grid.owned_sound` with `racy_kept_of_local`). It takes the caller's memory to be
   closed: the start's check `Mem.checkClosed` is finite and reads no block from `next` on, so a
   memory that is not closed can pass it (`Closed.start_twin`), and that the start's grid is closed
   takes the caller's hypothesis on the pointer bytes (`Grid.start_closed`). Instances and twins:
   `cells_sound`, `cells_sound_twin`, `confluent_owned2`, `clean2`, `inv_twin`, `confluent_cells`,
   `cells_twin` in `MojoProofTest/ScheduleOwned.lean`.
5. `fast-race.md`: `fast_sound`, for every launch and every shaped trace whose accesses are by the
   launch's threads in their blocks: if the fast race check `fast`, which groups the accesses by
   byte, finds no race, then the core's `racy` at `sig` finds none (the converse is not proved;
   `MojoProof/Sem/RaceSig.lean`).
6. `barrier-owned.md`: race freedom when ownership changes at barriers, per barrier interval, for
   every trace (`racy_eq_false_of_phased`, `MojoProof/Sem/Trace.lean`), from the writer form
   `racy_eq_false_of_writers`, in which a thread may read bytes that nobody writes in that phase.
   On a run: every access to a block of threads' shared memory is by one of its threads
   (`Grid.start_reach_cta`), and one race-free run makes the start's grid sound
   (`Grid.start_sound_of_racy`); cells written before the barrier and read after it, the pattern of
   gevm_kernel's transposition through shared memory, for every block size, cell width and cell map
   injective on a block of threads (`Grid.sound_cells`, from `racy_cells`, and `Grid.sound_rounds`
   on a trace of rounds, `MojoProof/Sem/Shared.lean`; instance `sound_tpose` at the cell map
   `tpose 32` on every valid launch and cell width, with `sound1024` and `sound256`,
   `MojoProofTest/Transpose.lean`; gevm_kernel's two rounds, `gevm_sound`,
   `MojoProofTest/GevmTrace.lean`; the evaluated runs of a kernel with a barrier, for every launch
   and size the checks accept, `sh_sound_of`, with `sh_sound` and `sh_sound24`, and its racy twin
   without the barrier, `sh_twin`, `MojoProofTest/Shared.lean`). `reduction.md`: the halving
   tree of a reduction has no race, for every number of threads per block of threads, cell width
   and stride sequence (`racy_halving`), blocks whose accesses are atomics of one commuting
   operation (`RmwOp.commutes`) on the same bytes do not race (`racy_dropBlocks`), on a run both
   (`Grid.sound_halving`; instance on one evaluated run of a kernel with a shared halving tree and
   an `atomicrmw add` output word on two blocks of four threads, `red_sound`, and its racy twin
   without the second barrier, `red_twin`), and the output word of an atomic sum is the same for
   every order of the blocks of threads, for every width, number of blocks and words
   (`rmw_add_perm`, from `rmw_perm`, `MojoProof/Sem/Rmw.lean`); instances and twins in
   `MojoProofTest/Shared.lean`. That the kernels' traces have these access patterns is not proved.

## 3. Memory layout and the launch

7. `layout-tiles.md`: written tiles give the tensor, for every layout, codec, shape and offset map
   (`Block.holds_of_tiles`, `Block.holds_puts`, `MojoProof/Sem/Buffer.lean`), and the stride
   arithmetic proved once (`stride_lt`, `apart_stride`, `Tiling.ofApart`).
8. `index.md`: the global thread index `ctaid.x * ntid.x + tid.x`, as the IR computes it in `i64`,
   is the word of the thread number for the threads of a launch with a one-dimensional grid and
   block, so it is injective there (on a two-dimensional block it is not, `twin22`); two threads
   with one index have equal `ctaid` and `tid` in that dimension; for every valid launch, thread
   number, width and flags (`Launch.index_ops`, `Launch.index_oneDim`, `Launch.index_inj`, and the
   word lemmas `intCast_ofNat`, `intCast_sext_ofNat`, `intCast_trunc_sext`, `intBin_add_ofNat`,
   `intBin_mul_ofNat`; the word lemmas at `2 k < 2 ^ w` are corollaries of the core's
   `GPUProof.WordFit` (`GPUProof.WordFit.of_lt` through `GPUProof.WordFit.two_mul_lt_iff`), and
   `coord_onto`'s bound is `GPUProof.MixedRadix.lt_prod` ([mixed-radix.md](mixed-radix.md));
   `MojoProof/Sem/Index.lean`; instances `index24`, `eval24`, `inj24`,
   `roundtrip24`, twins `twin22`, `roundtrip_twin` in `MojoProofTest/Index.lean`).
9. `precond.md`: the precondition of a binary elementwise kernel over `LayoutTensor`s with a static
   layout, and that it can be met, for every layout, element codec, length, inputs, element count
   and address choice (`Map2.Pre`, `Map2.mem`, `Map2.pre_mem`), with the byval codecs
   (`Layout.Codec.ptr`, `Layout.Codec.ptrArg`) and `Mem.Closed.alloc`
   (`MojoProof/Sem/Precond.lean`). On `vector_addition` the precondition gives the start and W1
   (`pre_starts`); instances `byval_codec`, `pre5`, `start5`, twins `alias_twin`, `missing_twin` in
   `MojoProofTest/Precond.lean`. The same for a kernel `C = A Bᵀ` over row-major buffers, for
   every layout, element codec, sizes, row strides and tensors (`Mat.Pre`, `Mat.args`, `Mat.mem`,
   `Mat.pre_mem`); instance `preN`, twins `overlap_twin`, `absent_twin`. A store or a logged
   access at another block keeps `Mem.Buffer`, `Mem.Fits` and `Mem.Holds` (`Mem.Buffer.of_block`
   and its store forms); instance `store_x`.

## 4. The symbolic block checker and kernel theorems

The block checker (`MojoProof/Sym/Checker.lean`: `summarize`, `Summary`, `SState`, `covers`,
`coversTo`) summarizes each basic block as terms and checks a path of blocks once for every thread.
These documents prove that what it accepts holds of the semantics; the proofs are in
`MojoProof/Sym/Block.lean` and `MojoProof/Sym/Rel.lean` (the block relation, its lemmas and the
pointer facts' definitions) unless another file is named.

10. `phi.md`: `Block.sound_pathWith_ptrs` and `Block.sound_retWith`, soundness along a path whose
    edges may enter blocks with `phi`s, for every program and flag and every `alloca` flag
    (`Block.sound_retWith` takes it; `Block.sound_pathWith_ptrs` is the flag-off case of
    `Block.sound_pathAt_ptrs`), with `Ends.edge` and
    `Ends.edgeWith` (`MojoProof/Sym/Path.lean`; instance and twins `trip0_cell`, `trip0_twins` in
    `MojoProofTest/SymPhi.lean`, one program).
11. `edge.md`: `Block.sound_to`, one edge of a `br i1` into blocks with `phi`s, with
    `Block.sound_with` and `SState.exitTo_sound`, for every program; `coversPathWith false` takes
    `covers` or `coversTo` (`MojoProof/Sym/Checker.lean`) per block (`MojoProof/Sym/Block.lean`;
    instances and twins `edge_covers`, `edge_walk`, `edge_run`, `edge_twins` in
    `MojoProofTest/SymPhi.lean`, one program).
12. `back.md`: `Block.sound_retWith` and `Block.sound_back`, a `ret void` to a caller frame, for
    every program, path and caller, and `Block.sound_retWith` for every `alloca` and `contract`
    flag; with one frame it is the `.done` case (`MojoProof/Sym/Path.lean`; instance `edge_back` in
    `MojoProofTest/SymPhi.lean`, one program).
13. `loop.md`: `Block.sound_loop`, soundness of a loop for every trip count, by induction on it, for
    every program; the trip count is a premise, and nothing is said about termination.
    `Round.of_inv` and `Block.sound_loop_inv` give the premises of every round from an invariant.
    `Runs.of_chainWith` and `Runs.of_chainsWith` (with the `alloca` flag: `Runs.of_chainWith` and
    `Runs.of_chainsAt`, the checkers `coversChainAt`, `LoopSeg.coversRoundAt` and `coversChainsAt`,
    whose `With` forms are the flag-off cases) take a thread through loops in sequence, with
    loops nested in their rounds, to its end, for every program, `fmul contract` flag and chain
    the checker accepts (`coversChainWith`, `LoopSeg.coversRoundWith`, `ChainWith`,
    `RetLsWith`), trip counts and invariants, by `ChainWith.reach` and `Block.sound_rounds` (the
    one induction on the trip count), with `ChainWith.of_rounds` and `ChainWith.of_iter`. The
    one-loop corollaries are `Runs.of_loop` (a thread from its entry through
    a loop to its end, for every loop the checker accepts, `LoopPaths.covers`) and `Runs.of_loops`
    (the same for a kernel's start thread, `coversLoops`). Also `Mem.foldl_setLive_load` (loads
    outside the blocks a return cleans up). With the flag on, the blocks a run adds (`Mem.Adds`,
    `SEff.run_adds`, `Mem.Adds.trans`) are the ones the cleanup sets dead, and
    `Runs.of_chainsDead` carries a postcondition that reads only the start memory's blocks through
    it (`Mem.Adds.foldl_setLive`). `ChainWith.enter` (`BackWith.enter`) takes a thread through a
    chain whose last path out stops after its last edge, to the frame it enters. Back edges and
    cut points by block order (`backEdges`, `cutPoints`). The facts at a loop's heads, for every program and loop
    (`MojoProof/Sym/LoopFacts.lean`): the registers its rounds keep (`LoopSeg.kept`,
    `LoopSeg.kept_round`), that rounds that only load keep the blocks, `Elem` and `Elem.Only`
    (`LoopSeg.loadsFrom`, `Valuation.iterate_loads`, `iterate_blocks`, `iterate_elem`,
    `iterate_only`), and the step count at each block of a round (`pathOff`, `LoopSeg.stepAt_k`,
    `LoopSeg.steps_k`); instances at the naive loop and cnt2's loops in
    `MojoProofTest/LoopFacts.lean` (`MojoProof/Sym/Loop.lean`; instances `cnt_run`, the counting loop
    for every bound `n ≤ 2 ^ 60` and output block outside the frame's `alloca` blocks,
    `cnt_run_outC` by `Runs.of_loops`, `cnt2_run`, two loops in sequence at `n = 2`, `nest_run`, two
    nested loops in a function built in the test; twins `cnt_twins`, `cnt_inv_twin`, `cnt2_twins`,
    `nest_twins` in `MojoProofTest/SymLoop.lean`, one function each; `loopK_run`, a loop whose body
    allocates, its blocks dead at the end and an output block's word kept, and the mutant
    `loopK_inUse`, in `MojoProofTest/SymLoopAlloca.lean`, one program).
14. `ptrs.md`: `Block.sound_ptrs`, `Block.sound_pathAt_ptrs` (with `Block.sound_pathWith_ptrs` its
    flag-off case) and `SState.run_ptrs`, the pointer
    facts (`Ptrs`, `PtrAt`) of every block and path the checker accepts, for every program;
    `Ptrs.loadsOk` and `Ptrs.storesOk` give `Valuation.LoadsOk` and `Valuation.StoresOk` from
    `Labels.MemNext`, `Valuation.pathMem_of_ptrs` and `Block.sound_pathMem` along a path, and
    `Labels.MemOk.steps` gives `MemNext` from `MemOk` along a thread's `Steps`
    (`MojoProof/Sym/Block.lean`, `MojoProof/Sym/PtrMem.lean`; instances `vadd21_ptrs`,
    `vadd21_memNext_twin`, `store_pathMem`, one block).
15. `contract.md`: `Block.soundC`, soundness of a block with `fmul contract`, whose product a later
    `fadd contract` may fuse, for every program, block, entry position and summary that `coversC`
    accepts: the block ends with the frame's products recorded (`EndsC`), and `Block.sound` is the
    case with `contract` off (`Ends.of_C`). Along an edge and at the end of a path:
    `Valuation.afterC`, `Valuation.intoC`, `Ends.edgeC` and `Block.sound_pathC`
    (`MojoProof/Sym/Block.lean`; instances and twins `latch_nodes`, `latch_covers`,
    `latch_refused`, `latch_twins`, `latch_prods`, `latch_edge`, `latch_afterC` in
    `MojoProofTest/SymContract.lean`, and `trip1_covers`, `trip1_latch`, `trip1_round` in
    `MojoProofTest/SymNaive.lean`, on the naive matmul kernel's latch, one program). A block with
    `fmul contract` inside a path or in a loop's round is not covered.
16. `kernel.md`: the kernel theorem from one covered path or one covered sequence of loops per
    thread, for every program, kernel, launch, arguments, admission of address choices and oracles,
    caller's memory whose pointer bytes are known and observation that reads only the blocks: if the
    start succeeds on every admitted choice and oracle, and a family of memory predicates indexed by
    the number of threads done is carried from one to the next by each thread's path (`Ret`) or
    sequence of loops (`RetLs`) and ends in memories whose trace has no race, keeps
    `!invariant.load` and has an observation that meets `R` (`Kernel.sound_of_chains`, with
    `Kernel.sound_of_paths` its loop-free corollary; instance `kernelK`, the counting loop on one
    thread at one launch, memory, choice and oracle, in `MojoProofTest/KernelLoop.lean`, from the
    generated `loopK.sound_loop` through `Kernel.sound_entry`: the same on the start's facts, each
    thread's precondition from the registers of its scalar and pointer parameters; and
    `KernelContract.kernelK`, `kfK.sound_loop` with the flag `contract` closed on six threads);
    with the cells apart only on a set of threads that are the only ones to access the output block
    (`Kernel.sound_cells`, statement 11 of kernel.md; instance `kernelC`, six threads that each run
    a counted loop and then store one cell, in `MojoProofTest/KernelCells.lean`); and at
    one choice and oracle by evaluation (`Kernel.sound_eval`), with `Runs.of_ret`,
    `Grid.start_thread` and the elementwise invariant `Elem` (`MojoProof/Sym/Kernel.lean`; instance
    `kernel22`, `vector_addition` at one launch, memory, choice and oracle; twins `out_twin`,
    `entry_twin`, `elem_twin` in `MojoProofTest/Kernel.lean`). Then the kernel theorem of every
    elementwise kernel from each thread's `Ret` between memories of `Elem` (`Kernel.sound_elem`, the
    corollary of `Kernel.sound_cells` with every thread storing); of
    every binary elementwise kernel whose parameters `%0` to `%2` are `byval` structs that hold a
    buffer pointer and `%3` an `i32` count, at one oracle and every address choice, with the start
    facts derived from `launchArgs` (`Kernel.sound_map2`, `launchArgs_byval`, `Thread.start_regs`),
    the case of three structs and an `i32` count of `Kernel.sound_mapN`, for any number of `byval`
    buffer structs and a count of any type;
    and `vector_addition` at every address choice and oracle, for every valid one-dimensional launch
    and caller's memory of `Map2.Pre` with an alignment that 4 divides, where the output block holds
    the sum's float at every cell below `n` and every other byte is the caller's (`vadd.correct`,
    generated by `mojo_kernel`'s `map2` clause with `vadd.ret` by `mojo_ret`,
    `MojoProof/Kernels/Vadd.lean`; instances `correct23`, every premise discharged on 2 blocks of 3
    threads, and `correct12`, on one block of 2 threads with count 5), and the same for
    `vector_multiply`, a kernel written for this repository (`vmul.correct`,
    `MojoProof/Kernels/Vmul.lean`). Also: `g2_vadd`, one run on a launch with a partial last block
    and nonconstant data, compared with `Elem.Out` by kernel evaluation; the negative twins
    (`twin_len`, `twin_alias`, `twin_tid`, `twin_2d`); the wrong outputs the checker must refuse
    (`Elem.canaries`, `Kernel.replay_canaries`, `canaries_vadd`, `canaries_vmul`); and the
    corollaries, for every kernel with such a theorem, at the cell of every thread below `n`, `N`
    and the number of threads: a finite output float is the operation's result, two runs' floats are
    equal up to `FinEq`, and the threads from `n` on put nothing (`Kernel.map2_real`,
    `Kernel.map2_finEq` with `FinEq.eq_of_isFinite`, `Kernel.map2_min`), with instances `vadd_real`,
    `vadd_finEq`, `vadd_stable`, `vadd_min` and the `vmul_` ones. And the naive matmul kernel at
    every row stride `sA`, `sB`, `sC` (the family `NaiveFam.prog sA sB sC`, the float32 kernel
    compiled with `fmul contract` with its three stride constants as parameters), at every oracle
    family, valid launch with side 1 in `z`, sizes `m`, `n`, `K` below `2 ^ 31`, blocks, tensors
    and caller's memory of `Mat.Pre` (`NaiveFam.sound`, `MojoProofTest/NaiveFamRun.lean`: the
    kernel theorem of a matmul kernel from its threads' runs, `Kernel.sound_mat` (statement 13 of
    kernel.md, MojoProof/Sym/KernelMat.lean: `Kernel.sound_mapNWith` at three structs and three
    `i32` sizes, with 2-D cells), at `contract := true`, with the run `NaiveFam.runInF` of a
    thread in bounds, which is `NaiveFam.runF` (the run from an invariant of the loop at the heads
    of its rounds, `LoopIterWith`, with `Mat.Head` and the registers the loop keeps,
    `NaiveFam.keptF`, at every head) at the invariant `NaiveThread.Inv` with `%48`'s
    `fmul contract` operands and at `NaiveFam.head_inF`, `round_inF` and `exit_inF`, the entry
    block summarized at every stride by the command `sym_summary_family`, and the run
    `NaiveFam.outF` of a thread out of bounds; instance `NaiveFam.sound_512_512_256` at the
    strides of tests/corpus/naive_k512/). At the corpus strides 768, 768 and 50257 (`naive`, one
    float32 specialization, `NaiveFam.prog_corpus`) it is `NaiveKernel.correct`, one line
    (instance `sound12`, one block of 2 × 2 threads, two in bounds), and `NaiveIn.runIn`,
    `head_in`, `round_in` and `exit_in` are the family's run and premises there; the `mat` clause
    of `mojo_kernel` generates the same theorem for that one program (`NaiveSound.naive_sound`,
    through `naive.sound_mat`; kernel.md, "The 2-D clause of `mojo_kernel` (`mat`)"). Its cells
    are read off against TorchLean's `Tensor.matmul` of the first `K` columns
    (`NaiveSound.naive_read`, `NaiveSound.naive_matmul`); for `naive` itself, `read_cover` (every
    cell when the window covers `m × n`, twin `keep11`), `matmul_nanEq` (with instance
    `nanEq_zero`) and `matmul_error`, each one line from `NaiveFam`'s theorem for every program
    and row stride (tested at strides 16, 8 and 5).
17. `obl.md`: `vector_addition` walks the path its index selects, for every valid launch,
    thread, count `n ≤ N` with `n < 2 ^ 31` and memory whose distinct buffers are aligned
    to a multiple of 4 and do not wrap (`vadd_walk` and its open-goal twin `vadd_walk_open`
    in `MojoProofTest/Obl.lean`, with `vadd_walk_launch` and `vadd_walk_launch_open` their
    corollaries for one-dimensional launches, by the tactic `mojo_obl` of
    `MojoProof/Sym/Obl.lean` with the lemmas of `MojoProof/Sym/OblLemmas.lean`).
18. `race.md`: `vector_addition`'s accesses are race-free by construction: the disjointness premises
    of the race-freedom results, for every launch and thread index `k`, on the access template of
    thread `k`'s active path (`vadd_apart`, `vadd_owned`, `vadd_stores`, `vadd_loads`, `vadd_hX`,
    `vadd_hL`, `vadd_hI`, by `mojo_race`; `MojoProof/Sym/Race.lean`; the `tid.x` twin in
    `MojoProofTest/Race.lean`). `vadd_owned` has no execution premise, no bound `k < n` and no
    one-dimensional hypothesis: that a run makes these accesses is not proved there. And
    `Grid.owned_sound`'s `hO` for every trace and launch whose accesses are owned and end by the
    extent, through the tiling `Tiling.clip` of the thread numbers (`Elem.Own.owned`, `vadd_hO` by
    `mojo_race`).
19. `gemv.md`: the two float32 gemv kernels in the block checker. Proved for every program: the
    lane number (`exec_laneid`, through `exec_nullary`), the casts `castV` evaluates (`castOk`,
    `castOk_iff`; `SNode.castAt`, `SNode.eval_castAt`, `exec_cast`), the value of a same-width
    scalar `bitcast` (`SNode.eval_bitcast`,
    `bitcast_bits`), segments that end at a barrier, a warp shuffle or a lifetime marker
    (`summarizeTo`, `Seg.sound`, `Thread.resume_at`, `Seg.resume`, `Seg.resume_regs`;
    `summarizeLife`, `Seg.lifetime`), a block's segments in a row on one thread (`Seg.through`,
    `Piece.through`) and into a continuation (`Piece.throughTo`, `RunsVia.of_fires`), the vector
    and aggregate nodes and `getelementptr` with any number of indices
    (`SNode.insert`, `eltAt`, `insEltAt`, `gepN`), a
    `getelementptr`, `load` or `store` on a global (`SNode.globalAt`, `SNode.eval_globalAt`)
    and a `load` after a `store` (`SNode.loadAfter`, its value lemmas in
    `MojoProof/Sym/LoadAfter.lean`); tests at the two kernels' blocks
    (`MojoProofTest/SymLane.lean`,
    `MojoProofTest/SymCast.lean`, `MojoProofTest/SymSeg.lean`); the segment checker's tail takes
    the `alloca` flag (`MojoProofTest/SymSegAlloca.lean`), and with it the whole of `%6` from
    statement 0 is in the fragment (`gemv_segs_alloca`). The runs proved:
    - gevm_kernel's thread from its entry to `ret` at every launch with 1024 threads a block, for
      every `K` and `N` with `K % 32 = 0` and `K * N < 2 ^ 29` and every delivered values of the
      barrier and the shuffles (`whole`, `MojoProofTest/OblGevmWhole.lean`);
    - gemv_kernel's thread at one context, frame and memory (`MojoProofTest/SymGemvTail.lean`):
      `%6` from statement 41 through `%43` to `ret` (`tail_runs`); from statement 0 through its
      `alloca`s, shuffles and lifetime markers to `ret` on the `%43` branch (`gemv_runs`); from
      statement 0 through `%44`, the loop at `%54` with no round and `%78`'s five shuffles to
      `ret` (`gemv_loop_runs`, the chain's last path out stopped after `%59`'s edge,
      `RunsVia.of_chain`).

    The loop is accepted a round through either arm and as two loops at one header
    (`loop_rounds`, `loop_arms`), and refused with its path out through `%78`'s shuffles
    (`loop_refused`). The rest is a plan: the loop's rounds on a run, the delivered values as the
    collectives' results, the race freedom across gevm_kernel's barrier, and the order of the
    work.

## 5. Skeleton and payload

20. `payload.md`: T3, skeleton transfer, in parts.
    - T3a: a lockstep bisimulation carries runs, bad grids and `Grid.Sound`, for every relation
      (`Grid.Lockstep`, `Grid.payload_run`, `MojoProof/Sem/Lockstep.lean`; instance `eq_run`, twin
      `lockstep_twin` in `MojoProofTest/Lockstep.lean`).
    - T3b: the skeleton relation (`Val.Skel`, `Mem.SkelEq`, `Thread.Skel`, `Status.Skel`,
      `Grid.SkelRel`, `MojoProof/Sem/Skeleton.lean`) is a lockstep bisimulation from every start
      whose program passes the static labelling check `Labels.Ok`, whose kernel is the module's
      function of its name, and whose reachable grids all meet the memory hypothesis
      `Labels.MemOk`, for contexts that differ only in their oracles (`Grid.skel_lockstep`). The
      steps: memory (`Mem.load_skel`, `Mem.store_skel`), operands and operations (`evalV_skel`,
      `castV_skel`, `intBin_skel`, `floatBin_skel`), one statement (`exec_skel`,
      `MojoProof/Sem/SkelExec.lean`), one step (`step_skel`, `Grid.advance_skel`), collective calls
      (`Grid.fire_skel`) and the start (`Grid.start_skel`) (`MojoProof/Sem/SkelStep.lean`). So, at
      one address choice, a run from such a start on the first of two caller memories related by
      `Mem.SkelEq`, the first naming only known numbers in its pointer bytes, to a done grid that is
      not bad gives a run of the same length from the start on the second, at any oracle, to a
      related done grid that is not bad, and the second start is sound for every observation of the
      blocks and every relation its final observation meets (`Grid.skel_run`; a kernel that loads,
      adds and stores a payload float in `MojoProofTest/PayloadRun.lean`); and the start on every
      related memory and oracle is safe, race free, keeps `!invariant.load`, makes progress,
      terminates and is determinate for the blocks, with the trivial relation, using the run only
      through the relation, `Done` and `Bad`, never through a payload value (`Grid.skel_six`,
      section "Composition").
    - T3c on terms: the checks on a block summary (`Summary.oblivious`, `Summary.agrees`,
      `Summary.agreesI`, `Summary.phiAgrees`, `Summary.payOk`, `MojoProof/Sym/Payload.lean`) give
      related node values, memories and valuations at the next block's entry (`vals_rel`,
      `SEff.run_rel`, `Valuation.into_rel`), along a path (`Valuation.last_rel`), and related
      memories after a returning path and its cleanup (`Block.sound_ret_rel`). On
      `vector_addition`'s block `%21`: the term it stores (`vadd21_cellOk`, `vadd21_store`,
      `vadd21_store_sound`). Instances and twins in `MojoProofTest/Payload.lean`.
    - T5's rows, one float operation at a time (`MojoProof/Sem/FloatRel.lean`): `fadd`, `fsub` and
      `fmul` respect `Val.Lift t FinEq` (`floatOp_finEq`); `rsqrt.approx` meets its error contract
      (`rsqrt_close`, `rsqrtOk_of_rsqrt`); the `maxnum` and `minnum` rows (`maxnum_of_not_nan`,
      `maxnum_nanEq`, `fminmax_of_not_nan`, `fminmax_nanEq`, `fminmax_vec_of_not_nan`,
      `fminmax_vec_nanEq`); one contracted `fadd` or `fsub` (`contract_est`,
      `floatBin_contract_est`); the NaN row (`fbin_isNaN`, `floatOp_isNaN`); and NaN equivalence
      (`floatOp_nanEq`, a corollary of `floatOp_lift`). Each row's premises (flags, oracle numbers,
      float types) are in the document. Instances and twins in `MojoProofTest/FloatRel.lean`.

21. `skel-kernel.md`: `Grid.skel_six` at the level of `Kernel.Sound`, for every program, kernel,
    launch, arguments, labelling, payload blocks and set of address choices: one run per address
    choice in the set, on a first memory naming only known numbers in its pointer bytes, to a done
    grid that is not bad, with `Labels.Ok`, the kernel's lookup and `Labels.MemOk` at each start,
    gives `Kernel.Sound` on every memory related to the first by `Mem.SkelEq`, at every address
    choice in the set and every oracle, for the blocks and the trivial relation
    (`Kernel.skel_sound`); and the seventh field for an observation that reads only the blocks from
    one final grid per admitted pair (`Kernel.Sound.of_blocks`) (`MojoProof/Sem/SkelStep.lean`;
    instances `kernel_six_inst`, `kernel_sum_inst`, twin `kernel_six_twin` in
    `MojoProofTest/SkelKernel.lean`, one kernel; on `vector_addition` at one thread, with every
    premise by evaluation, `skel_vadd`, `out_vadd` and `elem_vadd` in
    `MojoProofTest/SkelVadd.lean`; at six threads (`L23`), with `Labels.MemOk` by
    `Labels.MemOk.of_threads` from each thread's run alone, `skel_vadd23` in
    `MojoProofTest/SkelVadd23.lean`).
    `vadd.correct` does not use them.
22. `dot.md`: the float arithmetic of the contracted dot-product loop of the naive matmul kernel,
    `dotLoop`, for every list of factor pairs and every oracle sequence: without contraction, or
    with no `fadd` oracle number 2 modulo 3, its word is FloatLib's `Model.dotInOrder` up to NaN
    payloads, for every format (`dotLoop_nanEq`, `dotLoop_eq_dotInOrder`); with contraction and
    every oracle, a finite result is within `dotBound` of the exact sum, for every IEEE format
    (`dotLoop_error`); from `+0` within `dotLoopBound`, one power of `1 + u` fewer on the sum
    (`dotLoop_error_zero`), finite when the sum and its bound stay below the largest finite value
    (`isFinite_dotLoop`), and `GPUProof.Approx` at `GPUProof.dotGrade` for every format, length
    and input grade (`dotLoop_approx`; tests in `MojoProofTest/DotGrade.lean`); lanes' dot loops
    added along a tree are `GPUProof.Approx` at `GPUProof.laneGrade` (`lanes_error`,
    `treeDot_error`, `treeDot_approx`, statements 15-16), with `dotLoop_approx` the one-leaf case,
    and the strided lanes, every lane of the butterfly and `groupDot` are its cases
    (`MojoProof/Tile/MatVec.lean`; tests and the depth mutant in `MojoProofTest/TileLanes.lean`);
    statement 12 names each term of the loop's step; `floatBin`'s `fmul` then `fadd` is one
    iteration (`floatBin_dotStep`); and
    the contracted loop at never-fusing numbers is the unfused one (`dotLoop_neverFuse`)
    (`MojoProof/Sem/Dot.lean`; instances and twins in `MojoProofTest/Dot.lean`, on binary32).
    Against TorchLean, for every format and all sizes: over the factor pairs `matmulPairs A B i j`
    of entry `(i, j)`, the loop without contraction is TorchLean's `Tensor.matmul A B` entry up to
    NaN payloads (`matmul_cell_nanEq`, `matmul_cell_eq`), the exact sum is the entry of
    TorchLean's matmul over `ℝ` of the matrices mapped by `Model.toReal` (`matmul_cell_real`), and
    a finite contracted result is within `dotBound` of it (`matmul_cell_error`); the same for the
    matrix-vector product `contract A v _ _ [m] .matVec` and `matVecPairs A v i`
    (`matVec_cell_nanEq`, `matVec_cell_eq`, `matVec_cell_real`, `matVec_cell_error`)
    (`MojoProof/Sem/Matmul.lean`; instances and a twin in `MojoProofTest/Matmul.lean`, on a
    binary32 2 x 2 product). For two rows of strides `sA` and `sB` with `K ≤ sA` and `K ≤ sB`, the
    `K` pairs `(get2 A i k, get2 B j k)` are the pairs of entry `(i, j)` of the product of the
    first `K` columns of `A` and the transpose of the first `K` columns of `B` (`cols_pairs`), so
    the three comparisons hold against that product (`matmul_cols_nanEq`, `matmul_cols_eq`,
    `matmul_cols_error`; instance `cols_inst` at strides 3 and 2); at one stride they are
    `take_pairs`, `matmul_take_eq` and `matmul_take_error`. That the kernel's
    loop computes `dotLoop` of its loaded pairs is not proved.
23. `bfly.md`: the warp butterfly of the gemv kernels as a FloatLib reduction tree: for every
    combining operation, offsets, values and lane, a lane's value after the butterfly rounds is the
    evaluation of a fixed `ReductionTree` of lane numbers whose depth is the number of rounds
    (`eval_bflyTree`, `depth_bflyTree`); at any order of the offsets 1, 2, …, 2 ^ (k - 1) each
    lane below 2 ^ k is a leaf exactly once (`leaves_bfly`), at the offsets 16, 8, 4, 2, 1 each
    lane below 32 (`leaves_warp`); so FloatLib's tree bound applies to every lane whose
    leaves are the lanes below `w`, with the number of rounds as depth (5 at a warp), and in
    every IEEE format a lane's finite result of `Model.add` is within
    `((1 + u) ^ d - 1) · Σ |v j|` of `Σ v j`, `d` the number of rounds (`bfly_warp_error`,
    `bfly_add_error`); and the semantics' butterfly shuffle with
    clamp 31 reads lane `l ^^^ m` (`shflSource_bfly`) (`MojoProof/Sem/Bfly.lean`; instances and a
    twin in `MojoProofTest/Bfly.lean`). `warp-dot.md`: the warp's dot product `warpDot`, the
    butterfly over the 32 strided loops `dotLoop`, for every format, length, flag and oracle: the
    exact strided sums give TorchLean's real matrix-vector and vector-matrix entries
    (`bfly_matVec`, `bfly_vecMat`); a finite result is within the error of
    `GPUProof.laneGrade (.ieee fmt) 32 5 ⌈K / 32⌉ K` at grades `⟨0, 0⟩` of the exact sum, as
    `treeDot_error` at the butterfly's tree (`warpDot_error`, `warpDot_matVec`, `warpDot_vecMat`);
    with the contraction off
    it is FloatLib's reduction along lane 0's tree of the in-order dot products, up to NaNs
    (`warpDot_nanEq`, `warpDot_eq`); the same over every group of `2 ^ k` lanes (`groupDot_*`), the
    warp's being its case at `k = 5`; the semantics' `fadd` rounds with an oracle number for every
    round and lane are `Model.add`'s up to NaNs and a finite lane value is within the butterfly's
    bound (`bflyDeliver_nanEq`, `bflyDeliver_error`) (`MojoProof/Sem/WarpDot.lean`; instances at 40
    pairs over 32 and over 8 lanes in `MojoProofTest/WarpDot.lean`). `gevm_kernel`'s transposition
    through shared memory
    (warp-dot.md, `MojoProof/Sem/Transpose.lean`): on every valid launch with `ntid.x = 1024`,
    thread `t` of a block stores to cell `tpose 32 t = 32 (t % 32) + t / 32`, a bijection of the
    1024 cells and its own inverse (`Launch.tpose_env`, `tpose_tpose`, `tpose_bijOn`); every
    trace whose accesses follow that tiling before the barrier and only read after it is
    race-free (`Tiling.tpose`, `racy_tpose`); and warp `w` then reduces column `32 β + w`'s 32
    strided sums in `warpDot`'s order (`warpDot_tpose`) (instances in
    `MojoProofTest/Transpose.lean`). That a grid run of a gemv kernel computes the rounds or
    `warpDot`, or stores and loads the transposed cells, is not proved. `float-reductions.md`:
    the float bounds of reductions along any tree in every IEEE format (`sum_error`,
    `sum_mixedError`, `MojoProof/Float/Tree.lean`), the shared-memory halving loop and a warp
    butterfly followed by a tree over the warps as one tree (`halve_error`, `block_error`,
    `MojoProof/Float/Halve.lean`), the two-pass mean and variance against the exact mean and
    `TorchLean.var` (`mean_error`, `var_error`, `MojoProof/Float/Stats.lean`), the exact maximum and
    the max-subtracted sum of correctly rounded exponentials and the softmax entries against
    TorchLean's real softmax, with masked inputs `-∞`, and log-sum-exp and log-softmax with the
    correctly rounded log (`max_exact`, `expSum_error`, `softmax_error`, `maskSum_error`,
    `maskSoftmax_error`, `lse_error`, `logSoftmax_error`, `MojoProof/Float/ExpSum.lean`), and the
    compiled exponential `ex2.approx.ftz.f32` under its contract (`ex2_error`, `ex2Sum_error`,
    `MojoProof/Float/Ex2.lean`); one binary32 instance each in `MojoProofTest/FloatTree.lean`,
    `MojoProofTest/FloatStats.lean` and `MojoProofTest/FloatEx2.lean`. `float-welford.md`: Welford's
    merge along any tree against the mean and `TorchLean.var` (`welford_error`, `wmean_error`,
    `wvar_error`, `MojoProof/Float/Welford.lean`; instances in `MojoProofTest/FloatWelford.lean`).
    `float-norm.md`: layer norm's output against `TorchLean.TransformerBlock.layerNorm` and RMS
    norm's against its real value, with `rsqrt.approx`'s contract (`lnorm_error`, `rmsnorm_error`,
    `msq_error`, `MojoProof/Float/Norm.lean`; instances in `MojoProofTest/FloatNorm.lean`). That a
    grid run of a kernel computes these trees is not
    proved.

## 6. Checking a run

24. `replay.md`: the trace-replay checker `Kernel.replay` and its soundness, for every program: a
    reported violation refutes `Grid.Sound` and `Kernel.Sound` (`Replay.found_bad`,
    `Kernel.replay_sound`, `Kernel.replay_unsafe`, `Kernel.replay_block`), and the fault side of
    `Grid.run_reach` (`Grid.run_ub`) (`MojoProof/Sem/Replay.lean`; instances in
    `MojoProofTest/Replay.lean` on `vector_addition` at one launch: a correct output, wrong outputs
    the checker must refuse, and a short output buffer).
25. `naive.md`: every in-bounds thread of the naive matmul kernel, at every row stride `sA`, `sB`,
    `sC` (`NaiveFam.prog sA sB sC`), oracle family, valid launch, sizes below `2 ^ 31` and within
    the strides, blocks and tensors, from the entry facts `Mat.Entry` and a memory of `Elem`, runs
    its loop to `ret` and stores the contracted dot loop of its row and column at its cell
    (`NaiveFam.runInF`, from `NaiveFam.runF` with the premises `head_inF`, `round_inF`,
    `exit_inF`, which read the registers the loop keeps from `NaiveFam.keptF`); every thread out
    of bounds stores nothing (`NaiveFam.outF`), so the kernel is sound at every row stride
    (`NaiveFam.sound`; `MojoProofTest/NaiveFamRun.lean`). At the corpus strides 768, 768 and
    50257 the run is `NaiveIn.runIn`, from the entry facts `NaiveSpec.At`
    (`MojoProofTest/NaiveIn.lean`, with `head_in`, `round_in` and `exit_in` the family's premises
    there). Its instance at an evaluated start is
    `NaiveStart.runs12` (one block of 2 × 2 threads, `m = 1`, `n = 2`, every `A`, `B`, `K ≤ 768`
    and oracle; `MojoProofTest/NaiveStart.lean`). Its start evaluates in the kernel with its
    check of the caller's memory in place, for every `K` (`NaiveStart.start12`). At `K = 768`,
    `NaiveKernel.sound12` is `correct` at that start; at every address choice and oracle some
    complete run exists, and its blocks meet `Elem.Out` (`NaiveStart.obs12`, by
    `Grid.Sound.result`), so `NaiveKernel.read12`'s cells of row 0 are those of a run that exists
    (`NaiveStart.cells12`).

## 7. Compile flags

26. `contract-off.md`: a program with contraction off runs as the program under a never-fusing
    oracle. For every program of the fragment `Program.fbinOracle` (no `fpext`, `fptrunc`,
    `maxnum`, `minnum` or `rsqrt.approx`), kernel of `Func.fbinOracle`, program with its module's
    `contract` flags removed and its layout and intrinsics, launch, arguments, memory,
    admissibility, observation and relation: `Kernel.Sound` of the kernel gives `Kernel.Sound` of
    the kernel with its flags removed, for every oracle family whose rows `neverFuse (ω n)` are
    admitted (`Kernel.Sound.contractOff`, through the lockstep bisimulation
    `Grid.lockstep_contractOff` and the starts `Grid.start_contractOff`, `Grid.start_ctxOff`;
    `MojoProof/Sem/ContractOff.lean`). The converse holds at the never-fusing rows: the kernel
    with its flags removed is sound for an admissibility exactly when the kernel is sound at the
    rows `neverFuse (ω n)` of the families it admits (`Kernel.Sound.contractOff_iff`), and a value
    is an observation of a complete run of the one under `ω` exactly when it is one of the other
    under those rows (`Kernel.Obs.contractOff_iff`, `Kernel.Obs.contractOff`;
    `MojoProof/Sym/ContractOff.lean`). Corollary for the naive family at every row stride `sA`,
    `sB`, `sC`: every program and kernel that are `NaiveFam.prog sA sB sC`'s with the flags
    removed (the family is of the fragment at every stride, `NaiveOff.progF_fbinOracle` and
    `fnF_fbinOracle`, by `kernel_rfl`), at every oracle family, launch valid with `z` sides 1,
    sizes below `2 ^ 31`, tensors and memory of `Mat.Pre`, are sound for the family's bytes at the
    rows `neverFuse (ω k)` (`NaiveOff.soundF`), which store the unfused fold `dotLoop false` at
    each cell in bounds (`bytes_neverFuseF`). Every observation of a run of that kernel is one of
    the family's under the never-fusing rows (`Kernel.Obs.contractOff`), so for every
    `K ≤ min sA sB` each cell in bounds and in the launch's window is `NaNEq` to TorchLean's
    `Tensor.matmul` of the first `K` columns, with no premise on the oracle, and within `dotBound`
    of the real product when finite (`NaiveOff.matmul_nanEqF`, `NaiveOff.matmul_errorF`). The
    corpus kernel compiled with contraction off (`16826c8c` of mgemm_nocontract) is checked by
    evaluation to be the family's at 768, 768 and 50257 with the flags removed
    (`NaiveOff.corpus_off`); there these are `NaiveOff.correct`, `bytes_neverFuse`, `matmul_nanEq`
    and `matmul_error` (`K ≤ 768`), one line each (with `correct_unfused`; twin
    `bf16_fbinOracle`, a kernel with `fpext`, outside the fragment;
    `MojoProofTest/NaiveOff.lean`). At the launch and memory of `NaiveKernel.sound12` (`K = 768`)
    it is sound, and has an observation at every address choice and oracle family
    (`NaiveStart.soundOff12`, `NaiveStart.obsOff12`). At a
    family with a fusing row the converse fails: the twin `ContractOff.twin`, one kernel with one
    `fmul contract` and one `fadd contract`, whose flags-removed form is sound for `+0` at the
    family `fun _ _ => 1` while a complete run of the kernel there observes `-2 ^ -46`
    (`MojoProofTest/ContractOff.lean`, by evaluation).

## 8. The layout library

27. `layout-laws.md`: a model of Mojo's layout library (shape, stride and coordinate trees with
    static and runtime leaves, `crd2idx`, `idx2crd`, `cosize`, `coalesce`, `composition`,
    `zipped_divide`, `blocked_product`, `upcast`, `Swizzle`, `is_affine`, `BitLayout`,
    `TwoLevelLayout` and `two_level_layout_from_swizzle`),
    transcribed from modular/modular bbc13a71, and its laws for every layout meeting each
    premise: the scalar offset on every shape (`Lay.call_scalar`) and the offset of a mixed
    coordinate (`Lay.call_mixed`), the cosize (`Lay.cosize_eq`, `Lay.call_lt_cosize`), coalesce
    keeps the size and the offsets (`Lay.coalesce_call`), `row_major` is a bijection onto
    `[0, size)` (`rowMajor_inj`, `rowMajor_onto`), idx2crd inverts flat layouts whose modes are
    nested (`idx2crd_call`), zipped divide and blocked product under their divisibility
    premises, upcast of strides that are multiples or divisors of the factor
    (`Lay.upcast_fuse`, `Lay.upcast_scale`), `is_affine` and its stepping law on flat layouts
    (`Lay.isAffine_flat`), the index width (`Lay.call_flat_toNat`), the swizzle is an
    involution when `bits ≤ |shift|` and linear over F2 (`Swizzle.call_call`,
    `Swizzle.call_xor`), every bit layout is linear over F2 (`BitLayout.call_xor`) and the
    placement of a layout that `is_bit_linear` accepts is the layout below its size
    (`placement_call`), the two-level layout of a swizzle and a flat layout that passes its
    asserts is the swizzle of the layout's offset at every coordinate inside the shape
    (`Swizzle.twoLevel_call`), and composition with a layout of any number of modes, each meeting
    `composeDiv`: the composite adds A's offsets of B's mode terms (`Lay.compose_sum`), is A
    after B when those terms do not carry (`noCarry`, `Lay.compose_call`), and is A after B at
    every coordinate when B's term lists are `carryFree` against A's extents, a premise on the
    two layouts alone (`Lay.compose_all`; `MojoProof/Layout/`).
    Counterexamples by `decide` show the laws fail without their premises: composition with one
    mode and with two modes that carry, blocked product, idx2crd, zipped divide, upcast, the
    swizzle, (2, 2):(1, 1), whose extents are powers of two but which is not linear over F2,
    and the two-level swizzle with overlapping inner bits, past an extent, and with a zero
    shift, where its inner map is not one-to-one (`MojoProofTest/LayoutLaws.lean`). Two tests,
    not proofs, check the model: against the compiler's folded values on 43 static cases
    (`MojoProofTest/LayoutConformance.lean`, `tests/layout/record.txt`), and against a CPU run
    on 9 layouts with runtime leaves, which agrees on 8 and differs past the size 0 of the
    ninth, where Mojo's remainder by 0 is 0 (`MojoProofTest/LayoutRuntime.lean`,
    `tests/layout/runtime/record.txt`). Neither covers bit layouts or two-level layouts.

## 9. Tensor cores and async copies

28. `tensor-core.md`: the fragment layouts of `mma` and `ldmatrix`, `mma` as a warp-collective
    step, exact and under an accumulation contract.
29. `async-copy.md`: `cp.async`, its commit and wait groups, and visibility after
    `wait_group 0`.

## 10. The tile layer

30. `tile.md`: tile programs, finite trees of loads, stores, choices, barriers and faults
    over cells of numbered buffers, with an interpreter that runs threads in order and logs every
    access (`MojoProof/Tile/`, not in the trusted base). Every kernel whose theorem has
    `Kernel.sound_map2`'s conclusion refines the element-wise program `map2` (`map2_refines`),
    at the tile oracle computed from the kernel's paths; `vector_addition`, `vector_multiply`
    and `vector_subtraction` by one test command each. The tile matrix product `dot` stores, at
    every placed cell, a word that meets TorchLean's `Tensor.matmul` of the first `K` columns
    (`dot_run`, `dot_meets`; every format, flag, size and placement), and every kernel sound for
    `Elem.Out` with `matBytes`, the shape of `Kernel.sound_mat`'s conclusion, refines it in every
    observation of a complete run (`mat_refines`); the naive matmul's row-stride family through
    `NaiveFam.sound` (`naive_tile`, `MojoProofTest/TileNaive.lean`). Each cell's word is also
    `GPUProof.Approx` at `GPUProof.dotGrade` (`Meets`' graded clause). With one column, these
    kernels meet `GPUProof.Spec.matVec GPUProof.matVecGrade`'s rule (`MojoProof/Tile/MatVec.lean`
    `mat_holds`; `naive_holds`), and gemv's lane-group word meets the rule at
    `GPUProof.laneVecGrade` (`groupDot_holds`). Phases, shared
    memory and collectives are not covered.

## 11. The core

31. `core.md`: the definitions over every machine (`GPUProof/`): the signature `Sig`, the trace
    events and the race check `racy` with `racy_iff`, `HB` with `hb_iff`, `Ordered` with
    `ordered_iff`, `kept` with `kept_iff`, the runs (`Step`, `Reach`, `Faults`, `Done`, `Bad`) and
    `Clean`; one test machine with `Clean` of a family of its programs at every size
    (`MojoProofTest/GPUProof/`); `racy`, `hb` and `ordered` read one pass with a clock per position
    (`scan`, `testBit_clock`), which checks each access only against the earlier writes and, when it
    writes, the earlier other accesses (`Scan.writes`, `Scan.reads`), and `racy` is checked by
    `decide +kernel`, measured on the toy's traces, and by chunks the kernel checks
    (`racy_by_chunks`, from `scan_add`; `GPUProof/Chunks.lean`) on the toy's ring at two sizes.
    On a machine that proves its placement injective (`Sig.placeInj`, a proof of the law
    `PlaceInj`), `racy` decides whether two accesses share a byte by their buffers and intervals of
    offsets (`Sig.share`, `Sig.share_iff`, `Access.meets_iff`). The trace of the launch of
    `vector_addition` through `sig`, which the kernel checks is the run's, is race free and keeps
    its frozen reads by `decide +kernel`, in one proof each (`MojoProofTest/RacySig.lean`:
    `vadd_sig_racy`, `vadd_sig_kept`; `MojoProofTest/RacySigRun.lean`: `trSig_run`,
    `vadd_run_racy`). The law classes other than `Levels` and `OneRun` are statements only
    (`laminar.md`, `theorem0.md`), and Theorem 0 (`Sound.of_one_run`, `GPUProof/Sound.lean`), the
    case of `Sound.of_lift` at the states reachable from a good start, is proved for every machine
    with `OneRun`; `Sound.of_lift` is the case at the bytes of `Clean.of_lift`, the one-run argument
    for every observation of the states.
32. `laminar.md`: for every machine with `Levels`, happens-before on a laminar trace (only
    accesses, fences and rendezvous of whole level instances) is sharing an agent or a
    rendezvous between that holds an agent of each (`HB.laminar_iff`); for every machine, a
    separated use map that admits every access at its phase decides race freedom
    (`racy_eq_false_of_uses`); the toy machine has `Levels` at every launch and laminar runs.
33. `spec.md`: the spec layer (`GPUProof/Spec/`): entry types, formats, grades, `Approx` with
    its form on one FloatLib word and the range lemma `Approx.finite_of_le`, encodings with their
    word positions, the NaN words at each and their laws (words equal up to NaN payloads at every
    position, `GPUProof.UpToNaN` of `GPUProof/NaN.lean`, decode alike; a NaN leaves some entry with
    no value), the float rules `bitwise` (at inputs in the domain it asks for its word function's
    words, `FloatRule.Holds.bitwise_eq`, which decode as its word function's,
    `FloatRule.Holds.bitwise`), `exact` and `graded`, `Spec`, `Meets` and its uniform case, and the
    specs `matVec`, `vecMat` and the sums, for every size; the grades `laneGrade` (lanes added
    along a tree), `dotGrade` and `matVecGrade` its cases by definition, `laneVecGrade`; which
    kernels meet `Spec.matVec` (step 9); tests at the overflow edge of binary32,
    at bfloat16 and at the sign of zero; the TorchLean importer is planned.
34. `mixed-radix.md`: mixed-radix indices at symbolic sizes (`GPUProof/MixedRadix.lean`):
    `SizeExpr`, `MixedRadix` with `val`, `InRange` and `radixProd`, and `GPUProof.WordFit`;
    `lt_prod` and `fits` for every size assignment, radix list and width, `eq_iff_digits` at two
    size assignments whose radices have the same values, and `val_append` (Horner's rule split at
    a digit); gemv's write index and the naive matmul's offsets at symbolic sizes, two threads'
    warp keys at two assignments (`warp_two`) and a split key (`warp_split`) as tests
    (`MojoProofTest/GPUProof/MixedRadix.lean`), by evaluation at two launches and two matrices,
    with a mutant per rule (`mutant_assign` for the radices' premise); the statements and proof
    plan of `View.tiling` and `View.coarsen_tile` (footprints at symbolic sizes) over the core's
    `Sig`, `PlaceInj` and `MixedRadix` keys, and the plan for the layout algebra's move into the
    core (not proved).

## 12. Theorem 0 at the grid

35. `theorem0.md`: what MojoProof proves so that the core's `Sound.of_one_run` gives
    `Grid.start_sound` at MojoProof's signature, for every program and launch: the five fields of
    `OneRun` at the grid from the start (`Grid.start_oneRun`), the number of threads and `Done`
    (`Grid.start_reach_size`, `Grid.done_iff`), the pending accesses by their threads in their
    blocks (`Grid.start_reach_pending`), observations of the blocks (`Mem.obs_blocks`) and the
    core's `RaceEnabled` at `sig` in the grid's terms (`Grid.raceEnabled_iff`,
    `Access.overlaps_iff_bytes`); the core's `Confluent.transfer`, for every surjection that maps
    the steps, the equivalence and the bad set (`GPUProof/Transfer.lean`). MojoProof's signature
    `sig` (`MojoProof/Sem/SigDef.lean`, its lemmas in `MojoProof/Sem/Sig.lean`), the transport
    lemmas `sig_step_iff`, `sig_reach_iff` (`MojoProof/Sem/Spec.lean`), `sig_cta` and `sig_obs`, the
    core's `racy` at `sig` by positions and by phases on shaped traces by the launch's threads
    (`racy_sig_rev`, `racy_iff`, `MojoProof/Sem/RaceSig.lean`), the core's `kept` at `sig` as no
    access that writes for the core overlapping a frozen read (`kept_sig_iff`), the instance `OneRun
    sig`, and `Grid.start_sound`'s
    exact statement, at `m.BytesIn m.Known`, from Theorem 0 (`MojoProofTest/Theorem0.lean`:
    `sound_sig`, `sound_of_sig`, with `applies_one` and `applies_six` at two memories that are not
    closed); `Clean.of_lift`, the one-run argument along a projection with no good start for every
    observation of the states, with its cases `Sound.of_lift` (the bytes) and
    `Grid.sound_of_one_run` (the grid's memory at `sig`, through `Grid.Sound.of_clean`); and
    `Grid.sound_commuting` and its case `Grid.sound_returning`, at one thread on `Launch.one` (`MojoProofTest/Close.lean`,
    `sound_one_ret`).
36. `sig.md`: MojoProof's machine as a machine of the core, for every program and launch: what fills
    each of the 84 fields of `Sig`, which theorem uses it, and where MojoProof falls short; the simp
    lemmas, a step appending its pending events (`sig_advance_logs`, `sig_fire_logs`) and `Levels
    sig`; the plan to remove MojoProof's five duplicates of the core's predicates at `sig` (`racy`,
    `kept`, `Grid.Faults`, `Grid.Done`, `Grid.Bad`), of which step 0 (`sig` and what it reaches in
    `MojoProof/Sem/SigDef.lean`, below `Spec.lean`), step 1 (`Grid.Faults` deleted;
    `Grid.faults_iff`), step 2 (`Grid.Done` deleted; `Grid.done_iff`), step 3 (`racy` deleted;
    `racy_iff` reads the core's `racy` at `sig`), step 4 (`kept` deleted; `kept_sig_iff`) and step 5
    (`Grid.Bad` and `Grid.RaceEnabled` deleted; `Grid.raceEnabled_iff`) are done, and the one-run
    argument is written once (`Clean.of_lift`, `GPUProof/Sound.lean`), with `Sound.of_lift` and
    `Grid.sound_of_one_run` its cases and `Grid.sound_one` deleted.

## Not proved

- T4, the output term of a whole kernel from its block summaries, has no Lean statement;
  `payload.md` fixes only its invariants.
- T3c is proved on terms only; its statement on the grid is not.
- The load and store premises of T3c on terms are not derived from `Labels.MemOk` and the grid.
- `Labels.MemOk`, the memory premise of T3b and of `Grid.skel_run` and `Grid.skel_six`, is not
  derived from the block checker's access terms. Evaluation closes it at one thread; at
  `vector_addition`'s six threads (`L23`) the thread-modular `Labels.MemOk.of_threads` closes it
  from each thread's run alone (`memOk23`), and other launches have no instance; `skel-kernel.md`
  gives the counts that rule out evaluating it on the whole grid.
- The error relation along terms is not proved; T5's rows are proved one operation at a time.
- T5's statement for every term, `SVal.eval_respects`, is not stated in Lean.
