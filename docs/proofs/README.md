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
   equivalent to it in at most as many steps as the run (`MojoProof/Sem/OneRun.lean`).
2. `adapter.md`: `Grid.sound_of_one_run`, the seven fields of `Grid.Sound` from one run, for every
   program: for a step relation on states that projects onto `Grid.Step` and lifts every grid step,
   confluent up to an equivalence that keeps `Done` and the observation, with persistent bad states
   that include faults, racy traces and broken `!invariant.load` promises, one run to a done state
   that is not bad and whose observation meets `R` makes the start's grid sound. Its instances:
   `Grid.sound_one` (one thread that returns in one step) and `Grid.sound_returning` (`N` threads
   that each return in one step without changing the memory), for every observation and relation
   that the final memory meets when its trace has no race and keeps `!invariant.load`; and
   `Kernel.sound_ret_launch`, the kernel `ret void`, on every launch, closed memory, address
   choice and oracle (`MojoProof/Sem/Trace.lean`). Its section
   "The observation of an elementwise output": the observation of a block after stores to some of
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
   reads only the blocks (`Grid.start_sound`); if a reachable grid is bad, so is every reachable grid
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
5. `fast-race.md`: `fast_sound`, for every trace: if the fast race check `fast`, which groups the
   accesses by byte, finds no race, then the pairwise check `racy` finds none (the converse is not
   proved; `MojoProof/Sem/Race.lean`).
6. `barrier-owned.md`: race freedom when ownership changes at barriers, per barrier interval, for
   every trace (`racy_eq_false_of_phased`, `MojoProof/Sem/Trace.lean`).

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
   `intBin_mul_ofNat`; `MojoProof/Sem/Index.lean`; instances `index24`, `eval24`, `inj24`,
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
`MojoProof/Sym/Block.lean` unless another file is named.

10. `phi.md`: `Block.sound_pathI` and `Block.sound_retR`, soundness along a path whose edges may
    enter blocks with `phi`s, for every program, with `Ends.edge`; `Block.sound_path` and
    `Block.sound_ret` are their corollaries (`Walk.toI`) (`MojoProof/Sym/Block.lean`; instance and
    twins `trip0_cell`, `trip0_twins` in `MojoProofTest/SymPhi.lean`, one program).
11. `edge.md`: `Block.sound_to`, one edge of a `br i1` into blocks with `phi`s, with
    `Block.sound_with` and `SState.exitTo_sound`, for every program; `coversPathI` takes `covers`
    or `coversTo` (`MojoProof/Sym/Checker.lean`) per block (`MojoProof/Sym/Block.lean`; instances
    and twins `edge_covers`,
    `edge_walk`, `edge_run`, `edge_twins` in `MojoProofTest/SymPhi.lean`, one program).
12. `back.md`: `Block.sound_retR` and `Block.sound_back`, a `ret void` to a caller frame, for every
    program, path and caller; with one frame it is the `.done` case (`MojoProof/Sym/Block.lean`;
    instance `edge_back` in `MojoProofTest/SymPhi.lean`, one program).
13. `loop.md`: `Block.sound_loop`, soundness of a loop for every trip count, by induction on it, for
    every program; the trip count is a premise, and nothing is said about termination.
    `Round.of_inv` and `Block.sound_loop_inv` give the premises of every round from an invariant.
    `Runs.of_chain` and `Runs.of_chains` take a thread through loops in sequence, with loops nested
    in their rounds, to its end, for every program and chain the checker accepts (`coversChain`,
    `LoopSeg.coversRound`, `Chain`, `RetLs`), trip counts and invariants, by `Chain.reach` and
    `Block.sound_rounds` (the one induction on the trip count), with `Chain.of_rounds` and
    `Chain.of_iter`. The one-loop corollaries are `Runs.of_loop` (a thread from its entry through
    a loop to its end, for every loop the checker accepts, `LoopPaths.covers`) and `Runs.of_loops`
    (the same for a kernel's start thread, `coversLoops`). Also `Mem.foldl_setLive_load` (loads
    outside the blocks a return cleans up) and back edges and cut points by block order
    (`backEdges`, `cutPoints`) (`MojoProof/Sym/Loop.lean`; instances `cnt_run`, the counting loop
    for every bound `n ≤ 2 ^ 60` and output block outside the frame's `alloca` blocks,
    `cnt_run_outC` by `Runs.of_loops`, `cnt2_run`, two loops in sequence at `n = 2`, `nest_run`, two
    nested loops in a function built in the test; twins `cnt_twins`, `cnt_inv_twin`, `cnt2_twins`,
    `nest_twins` in `MojoProofTest/SymLoop.lean`, one function each).
14. `ptrs.md`: `Block.sound_ptrs`, `Block.sound_pathI_ptrs`, `Block.sound_path_ptrs` and
    `SState.run_ptrs`, the pointer facts (`Ptrs`, `PtrAt`) of every block and path the checker
    accepts, for every program; `Ptrs.loadsOk` and `Ptrs.storesOk` give `Valuation.LoadsOk` and
    `Valuation.StoresOk` from `Labels.MemNext`, `Valuation.pathMem_of_ptrs` and
    `Block.sound_pathMem` along a path, and `Labels.MemOk.steps` gives `MemNext` from `MemOk` along
    a thread's `Steps` (`MojoProof/Sym/Block.lean`, `MojoProof/Sym/PtrMem.lean`; instances
    `vadd21_ptrs`, `vadd21_memNext_twin`, `store_pathMem`, one block).
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
    `vadd_finEq`, `vadd_stable`, `vadd_min` and the `vmul_` ones. And the naive matmul kernel
    (`naive`, one float32 specialization compiled with `fmul contract`), at every oracle family,
    valid launch with side 1 in `z`, sizes, blocks, tensors and caller's memory of `Mat.Pre`
    (`NaiveKernel.correct`, the instance in `NaiveSound.naive_sound` of the kernel theorem of a
    matmul kernel from its threads' runs, `Kernel.sound_mat` (statement 13 of kernel.md,
    MojoProof/Sym/KernelMat.lean: `Kernel.sound_mapNWith` at three structs and three `i32` sizes,
    with 2-D cells), through `naive.sound_mat`, which the `mat` clause of `mojo_kernel` generates
    (kernel.md, "The 2-D clause of `mojo_kernel` (`mat`)"), at `contract := true`, with the runs
    `NaiveIn.runIn` and `NaiveOut.runOut`; instance `sound12`, one block of 2 × 2 threads, two in
    bounds), with its cells read off against TorchLean's `Tensor.matmul` of the first `K` columns
    (`naive_read`, `naive_matmul`); for `naive` itself, `read_cover` (every cell when the window
    covers `m × n`, twin `keep11`), `matmul_nanEq` (with instance `nanEq_zero`) and
    `matmul_error`.
17. `obl.md`: `vector_addition` walks the path its index selects, for every valid one-dimensional
    launch, thread, count `n ≤ N` with `n < 2 ^ 31` and memory whose distinct buffers are aligned
    to a multiple of 4 and do not wrap (`vadd_walk_launch` and its open-goal twin
    `vadd_walk_launch_open` in `MojoProofTest/Obl.lean`, by the tactic `mojo_obl` of
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

## 5. Skeleton and payload

19. `payload.md`: T3, skeleton transfer, in parts.
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
      `SEff.run_rel`, `Valuation.into_rel`), along a path (`Valuation.lastI_rel`), and related
      memories after a returning path and its cleanup (`Block.sound_retI_rel`). On
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

20. `skel-kernel.md`: `Grid.skel_six` at the level of `Kernel.Sound`, for every program, kernel,
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
    `MojoProofTest/SkelVadd.lean`).
    `vadd.correct` does not use them.
21. `dot.md`: the float arithmetic of the contracted dot-product loop of the naive matmul kernel,
    `dotLoop`, for every list of factor pairs and every oracle sequence: without contraction, or
    with no `fadd` oracle number 2 modulo 3, its word is FloatLib's `Model.dotInOrder` up to NaN
    payloads, for every format (`dotLoop_nanEq`, `dotLoop_eq_dotInOrder`); with contraction and
    every oracle, a finite result is within `dotBound` of the exact sum, for every IEEE format
    (`dotLoop_error`); `floatBin`'s `fmul` then `fadd` is one iteration (`floatBin_dotStep`); and
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
    binary32 2 x 2 product). That the kernel's loop computes `dotLoop` of its loaded pairs is not
    proved.
22. `bfly.md`: the warp butterfly of the gemv kernels as a FloatLib reduction tree: for every
    combining operation, offsets, values and lane, a lane's value after the butterfly rounds is the
    evaluation of a fixed `ReductionTree` of lane numbers whose depth is the number of rounds
    (`eval_bflyTree`, `depth_bflyTree`); at the offsets 16, 8, 4, 2, 1 each lane below 32 is a
    leaf exactly once (`leaves_warp`); so FloatLib's tree bound applies with depth 5, and in
    binary32 a lane's result with every node's sum finite is within
    `((1 + 2 ^ -24) ^ 5 - 1) · Σ |v j|` of `Σ v j` (`bfly_warp_error`, `bfly_warp_add`); and the
    semantics' butterfly shuffle with clamp 31 reads lane `l ^^^ m` (`shflSource_bfly`)
    (`MojoProof/Sem/Bfly.lean`; instances and a twin in `MojoProofTest/Bfly.lean`). That a grid
    run of a gemv kernel computes the rounds is not proved.

## 6. Checking a run

23. `replay.md`: the trace-replay checker `Kernel.replay` and its soundness, for every program: a
    reported violation refutes `Grid.Sound` and `Kernel.Sound` (`Replay.found_bad`,
    `Kernel.replay_sound`, `Kernel.replay_unsafe`, `Kernel.replay_block`), and the fault side of
    `Grid.run_reach` (`Grid.run_ub`) (`MojoProof/Sem/Replay.lean`; instances in
    `MojoProofTest/Replay.lean` on `vector_addition` at one launch: a correct output, wrong outputs
    the checker must refuse, and a short output buffer).
24. `naive.md`: every in-bounds thread of the naive matmul kernel, for every oracle family, launch,
    sizes, blocks and tensors, from the entry facts `NaiveSpec.At` and a memory of `Elem`, runs
    its loop to `ret` and stores the contracted dot loop of its row and column at its cell
    (`NaiveIn.runIn`, from `NaiveThread.thread_run` with the premises `entry_in`, `head_in`,
    `round_in`, `exit_in`; `MojoProofTest/NaiveIn.lean`). Its instance at an evaluated start is
    `NaiveStart.runs12` (one block of 2 × 2 threads, `m = 1`, `n = 2`, every `A`, `B`, `K ≤ 768`
    and oracle; `MojoProofTest/NaiveStart.lean`).

## 7. Compile flags

25. `contract-off.md`: a program with contraction off runs as the program under a never-fusing
    oracle. For every program of the fragment `Program.fbinOracle` (no `fpext`, `fptrunc`,
    `maxnum`, `minnum` or `rsqrt.approx`), kernel of `Func.fbinOracle`, program with its module's
    `contract` flags removed and its layout and intrinsics, launch, arguments, memory,
    admissibility, observation and relation: `Kernel.Sound` of the kernel gives `Kernel.Sound` of
    the kernel with its flags removed, for every oracle family whose rows `neverFuse (ω n)` are
    admitted (`Kernel.Sound.contractOff`, through the lockstep bisimulation
    `Grid.lockstep_contractOff` and the start `Grid.start_contractOff`;
    `MojoProof/Sem/ContractOff.lean`). Corollary for one program: the naive matmul kernel compiled
    with contraction off (corpus `16826c8c` of mgemm_nocontract, checked by evaluation to be
    `naive`'s module and kernel with the flags removed), at every oracle family, launch, sizes,
    tensors and memory of `Mat.Pre`, stores the unfused fold `dotLoop false` at each cell in bounds
    (`NaiveOff.correct`; twin `bf16_fbinOracle`, a kernel with `fpext`, outside the fragment;
    `MojoProofTest/NaiveOff.lean`). Every observation of a run of that kernel under an oracle
    family is one of `naive` under the rows `neverFuse (ω n)` (`NaiveOff.obs_contractOff`), so for
    every `K ≤ 768` each cell in bounds and in the launch's window is `NaNEq` to TorchLean's
    `Tensor.matmul` of the first `K` columns, with no premise on the oracle, and within `dotBound`
    of the real product when finite (`NaiveOff.matmul_nanEq`, `NaiveOff.matmul_error`). The
    converse is not proved.

## Not proved

- T4, the output term of a whole kernel from its block summaries, has no Lean statement;
  `payload.md` fixes only its invariants.
- T3c is proved on terms only; its statement on the grid is not.
- The load and store premises of T3c on terms are not derived from `Labels.MemOk` and the grid.
- `Labels.MemOk`, the memory premise of T3b and of `Grid.skel_run` and `Grid.skel_six`, is not
  derived from the block checker's access terms, and evaluation closes it at one thread only; the
  thread-modular lemma that would close it at `g2_vadd`'s six threads is `Labels.MemOk.of_threads`
  (instance `store3_ok`), but its instance at those six threads is not proved; `skel-kernel.md`
  gives the counts that rule out evaluation.
- The error relation along terms is not proved; T5's rows are proved one operation at a time.
- T5's statement for every term, `SVal.eval_respects`, is not stated in Lean.
- The start of a launch of `At`'s sizes does not evaluate in the kernel with its check of the
  caller's memory in place (the check reads every byte); `NaiveStart` rewrites the check by
  `Mem.checkClosed_of_closed`.
