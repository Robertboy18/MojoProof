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

- **Schedule independence**, every program: from a memory whose stored pointers name only blocks
  it has allocated, the steps of a launch are confluent up to faults and races (`Grid.confluent`),
  so one run to the end with no fault, no race and no broken `!invariant.load` promise shows that
  every schedule of that launch is safe, race free, makes progress, terminates and gives the same
  result, for every observation that reads only the memory's blocks (`Grid.start_sound`).
- **The block checker is sound**, every program: a block, a path of blocks or a path to `ret` that
  the symbolic checker accepts runs as its summary says whenever the path's conditions hold at its
  entry (`Block.sound`, `Block.sound_pathI`, `Block.sound_retR`). Its fragment includes integer
  `select`, the `llvm.smax`, `smin`, `umax` and `umin` intrinsics, the lane number
  (`llvm.nvvm.read.ptx.sreg.laneid`, `exec_laneid`), the casts `castV` evaluates (`castOk`,
  exactly its cases by `castOk_iff`: not `fptoui`, `fptosi`, `inttoptr` or an ill-typed cast;
  `SNode.castAt`, `exec_cast`; `ptrtoint` before the block's first store only), with the value of
  a same-width scalar `bitcast` (`SNode.eval_bitcast`), a `getelementptr`, `load` or `store` on
  a global (the node `SNode.globalAt` at the pointer's operand, the context's address of the
  global, `SNode.eval_globalAt`), and a `load` after a store, from the memory the effects before
  it make (`SNode.loadAfter`; after a `store` at the same pointer it is the stored value,
  `SNode.eval_loadAfter_store`, and after one apart from it the value without it,
  `SNode.eval_loadAfter_apart`; tests at a layernorm block); a block with `fmul contract` (whose
  products a later `fadd contract` may fuse) is checked with the products it records
  (`Block.soundC`, and along a path `Block.sound_pathC`).
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
  each segment's obligations a premise at its start frame, and the block ends (`Seg.through`).
  Test: gevm_kernel's `%59` at symbolic values (`gevm_through`). A schedule through one barrier
  is the next item; none through a kernel's shuffles is proved.
- **A start through one barrier**, every program: a launch whose threads run in turn to one
  barrier (each block's own number, below 16) and then, resumed, in turn to their ends, with no
  race and the `!invariant.load` promise kept, is sound (`Seq.start_sound_bar`), by the barrier's
  fire (`Grid.fire_barrier`) block by block; a warp's shuffle resumes each lane with the value of
  the lane `shflSource` names (`Grid.fire_shfl`). Test: `Launch.k` on one block of two threads
  (MojoProofTest/SymWait.lean).
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
  sequence of loops, nested ones included, to its end (`Runs.of_chain`). This is only partly
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
- **Modular's naive matrix product** (`matmul_kernel_naive`), one float32 specialization of the
  multistage GEMM test, in the tests: compiled with `fmul contract`, for every oracle family,
  every valid launch whose side in `z` is 1, all sizes, blocks and tensors and every memory that
  meets the matmul precondition `Mat.Pre`, the kernel theorem holds: no run faults or races,
  every run terminates, and each cell `(r, c)` with `r < m`, `c < n` inside the launch's window
  holds the contracted dot loop of row `r` of `A` and row `c` of `B`, every other byte the
  caller's (`MojoProofTest.NaiveKernel.correct`, from the library's `Kernel.sound_mat` through
  `mojo_kernel`'s `mat … inv` clause, which also proves the run of a thread out of bounds, and
  the run of a thread in bounds through its loop from an invariant of the loop at the heads of
  its rounds, with the function, the buffers, `Elem`, `Elem.Only` and the registers the loop
  keeps at every head; the rest of the invariant and its three premises, at the loop head, at
  each round and at the exit, are proved by hand).
  For every `K ≤ 768`, a
  finite cell is within `dotBound` of the real product at every oracle
  (`MojoProofTest.NaiveKernel.matmul_error`), and at a thread whose oracle fuses no round the
  cell is TorchLean's `Tensor.matmul`, the same word or both NaNs
  (`MojoProofTest.NaiveKernel.matmul_nanEq`). For the same kernel compiled with contraction off,
  the cell is `Tensor.matmul`'s up to NaNs at every oracle (`MojoProofTest.NaiveOff.matmul_nanEq`).
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
  unit roundoff and `η` the underflow allowance (`dotLoop_error`). One iteration of the
  semantics' `fmul` then `fadd` is one step of `dotLoop` (`floatBin_dotStep`).
- **Matrix product and matrix-vector cells**, every format and size: for TorchLean tensors `A`
  and `B`, the loop over row `i` of `A` and column `j` of `B` with contraction off is
  `get2 (Tensor.matmul A B) i j`, bit for bit when that is not a NaN, and a NaN exactly when it is
  (`matmul_cell_nanEq`, `matmul_cell_eq`); the exact sum is the entry of TorchLean's real matrix
  product (`matmul_cell_real`), and with contraction on a finite result is within `dotBound` of it
  (`matmul_cell_error`). The same four hold for a matrix times a vector (`matVec_cell_nanEq`,
  `matVec_cell_eq`, `matVec_cell_real`, `matVec_cell_error`). These are about the loop's floats;
  the naive matrix product's kernel theorems below use their forms on the first `K` columns
  (`matmul_take_nanEq`, `matmul_take_error`); for rows of two strides `sA`, `sB` the same
  comparisons are `matmul_cols_nanEq`, `matmul_cols_eq` and `matmul_cols_error`.
- **The warp's dot product**, every IEEE format, every length and every oracle: the two gemv
  kernels' order, the factor pairs split by position modulo 32 into strided lists (`stride`),
  each folded by `dotLoop` from `+0`, then five butterfly rounds of `Model.add` at lane 0
  (`warpDot`). Over the reals the rounds of the exact strided sums are TorchLean's matrix-vector
  and vector-matrix entries (`bfly_matVec`, `bfly_vecMat`); a finite result is within
  `warpBound fmt ⌈K / 32⌉ 5 32 T` of them (`warpDot_matVec`, `warpDot_vecMat`, from
  `warpDot_error`); with the contraction off it is FloatLib's `Model.reduceAlong` along the
  butterfly tree of the 32 in-order dot products, the same word or both NaNs (`warpDot_nanEq`,
  `warpDot_eq`), not the sequential fold (at 40 binary32 pairs the two differ,
  `MojoProofTest.WarpDot.eq40`); and the semantics' rounds through `deliver` at one oracle number
  are `Model.add`'s up to NaNs (`bflyRounds_nanEq`). For gevm_kernel's transposition through
  shared memory: the accesses that give thread `(w, l)` cell `32 l + w` before the barrier and
  only reads after it are race free (`racy_tpose`, at every block of every launch with
  `ntid.x = 1024`, `Launch.tpose_env`); on a run, cells written at any cell map injective on a
  block of threads before the barrier and only read after it make every schedule give the run's
  observation (`Grid.sound_cells`, with `sound1024` at the cell map `tpose 32`), and the rounds over
  the transposed cells are `warpDot` of the column's pairs (`warpDot_tpose`). A vector `bitcast` of
  an `n · w`-bit word gives its `n` `w`-bit pieces, low first, and back (`castV_split`,
  `castV_join`). That a grid run of either kernel computes `warpDot` is not proved. For sum_kernel's
  pattern: the halving tree of a reduction in shared memory has no race for every block size, cell
  width and stride sequence (`racy_halving`), with the output word's `atomicrmw`s
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
  (`softmax_error`). One binary32 instance each (MojoProofTest/FloatTree.lean,
  MojoProofTest/FloatStats.lean). That a grid run of a kernel computes these trees is not
  proved; the corpus's layer norm merges Welford statistics across lanes, so the two-pass
  bounds are not its bound.
- **Layout laws**, every layout meeting each premise: on a model of Mojo's layout library
  transcribed from modular/modular bbc13a71 (trusted, T16), a scalar coordinate below the size
  of a layout whose shape and stride are congruent has the offset of its colexicographic digits
  dotted with the strides (`Lay.call_scalar`), below the cosize (`Lay.call_lt_cosize`), and
  coalesce keeps the size and every such offset (`Lay.coalesce_call`); a flat layout is affine in
  its coordinates (`Lay.call_add`); `row_major` of positive extents is a bijection onto
  `[0, size)` (`rowMajor_inj`, `rowMajor_onto`); idx2crd inverts a flat layout whose modes are
  nested in order or in reverse order, with positive strides (`idx2crd_call`,
  `idx2crd_call_reverse`); zipped divide keeps the size when every tile extent divides its
  extent (`Lay.zippedDivide_size`); upcast by `f` of strides that are positive multiples of `f`
  divides every offset by `f` (`Lay.upcast_call`); a `w`-bit offset is exact when the offset is
  below `2^w` (`Lay.call_flat_toNat`); a swizzle with `bits ≤ |shift|` is its own inverse
  (`Swizzle.call_call`) and every swizzle is linear over F2 (`Swizzle.call_xor`); composing a
  layout whose shape and stride are congruent with a single-mode layout (s):(d) that meets the
  divisibility premise `composeDiv` gives every c < s the layout's offset of c * d, when c * d
  is below its size (`Lay.compose_call`). Without the premises, five counterexamples hold by
  evaluation (composition, filed as modular/modular #7738; blocked product; idx2crd; zipped
  divide; the swizzle). The compiler's folded values equal the model's on 37 static layouts (a
  test, not a proof). Not proved: composition with a layout of more than one mode (under the
  premise taken mode by mode, the composite is not the one layout after the other, by
  evaluation), mixed coordinates on nested layouts, layouts with runtime leaves against the
  compiler, upcast of a stride that divides the factor, the two-level swizzle and
  `BitLayout`.
- **Tensor-core fragments and `mma`**, every layout family: the A, B and C/D fragments of
  `mma.m16n8k<k>` (tf32, bf16 and f16 inputs with f32 accumulators, and f64) and of
  `mma.m8n8k4 .f64`, the f16 accumulators, and the destinations of `ldmatrix.x<q>`, with and
  without `.trans`, are bijections between the 32 lanes' registers and the tile, checked
  against the PTX ISA's tables at `m16n8k8 .tf32`, `m16n8k16` and `m8n8k4 .f64`;
  `ldmatrix` loads the A and B operands; `mma` on the fragments is TorchLean's `matmul A B + C`
  over the reals, and within a stated bound of it under an accumulation contract (trusted,
  T14; docs/proofs/tensor-core.md).
- **Asynchronous copies**, every sequence of one thread's operations: after
  `cp.async.wait_group n` at most `n` groups are pending, and after `wait_group 0` every copy
  committed before it has landed, in order, its bytes visible when the destinations are
  disjoint; race freedom is the caller's premise (docs/proofs/async-copy.md).

Not proved yet:

- kernel theorems for corpus kernels with shared memory or barriers, and for the other 12
  specializations of the naive matrix product: the importer accepts `tiled_matmul` and most other
  corpus files, but only the elementwise kernels above, the tutorial's `vector_subtraction` and
  one naive matrix product have a kernel theorem, and for that product's threads in bounds the
  loop's invariant (but for the function, the memory facts and the registers the loop keeps at
  the loop's heads, which `mojo_kernel` proves) and its three premises are proved by hand in the
  tests: `mojo_kernel` generates the run from them, not the invariant;
- launches other than one-dimensional ones for the elementwise kernels above (the naive matrix
  product's theorem covers every valid launch with side 1 in z), and real MAX kernels (layer norm,
  softmax, GEMM) against the PyTorch-level operations they implement;
- that a grid run reaching `ldmatrix`, `mma` or `cp.async` computes the models above: the grid
  does not dispatch them yet;
- anything after the LLVM IR: LLVM's optimizer, the NVPTX backend, `ptxas`, the driver and the GPU;
- the lexer, parser and printer, which are checked on every corpus file and at every import
  (printing gives back the file's tokens) but not proved.

What the theorems assume (Lean and the libraries, where the IR comes from, and our reading of
LLVM's and PTX's documentation) is listed in [docs/TRUST.md](TRUST.md).
