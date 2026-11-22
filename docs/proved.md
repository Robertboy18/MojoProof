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
  `select` and the `llvm.smax`, `smin`, `umax` and `umin` intrinsics; a block with `fmul contract`
  (whose products a later `fadd contract` may fuse) is checked with the products it records
  (`Block.soundC`, and along a path `Block.sound_pathC`).
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
  closed by `decide +kernel` at a concrete launch. The kernel theorems through a loop are for test
  programs, each at one memory, address choice and NaN choice: the counting loop "for i in [0, n):
  p[i] = i" run by one thread with `n = 3` (`MojoProofTest.KernelLoop.kernelK`, the generated
  `loopK.sound_loop` with no evaluation of the start), and six threads in two blocks that each run
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
  case); `mojo_kernel` still generates only the three-struct `i32` shape.
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
  `mojo_kernel`'s `mat` clause; the threads' runs are proved by hand). For every `K ≤ 768`, a
  finite cell is within `dotBound` of the real product at every oracle
  (`MojoProofTest.NaiveKernel.matmul_error`), and at a thread whose oracle fuses no round the
  cell is TorchLean's `Tensor.matmul`, the same word or both NaNs
  (`MojoProofTest.NaiveKernel.matmul_nanEq`). For the same kernel compiled with contraction off,
  the cell is `Tensor.matmul`'s up to NaNs at every oracle (`MojoProofTest.NaiveOff.matmul_nanEq`).
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
  promise, from a memory whose stored pointers name only blocks it has allocated and a start whose reachable grids all meet the
  labelling's memory condition (`Labels.MemOk`), gives safety, race freedom, progress, termination
  and determinacy for every memory that differs from the first only in the data bytes of the payload
  blocks, at every NaN choice (`Grid.skel_run`, `Grid.skel_six`). At the kernel level, for every
  program, a set of address choices with one such run each gives the kernel theorem for the blocks
  and the trivial relation (`Kernel.skel_sound`), and one final grid per admitted choice whose
  observation meets the spec gives it for that spec (`Kernel.Sound.of_blocks`). The instances are
  `vector_addition` on one thread with count 5 at one address choice, for every memory that
  differs from one test memory only in the inputs' data bytes (`MojoProofTest.SkelVadd.skel_vadd`)
  and with the output's value at that memory (`MojoProofTest.SkelVadd.out_vadd`); with more
  threads `Labels.MemOk` has no decision procedure yet. `MojoProof.Kernels.vadd.correct` does not use this route.
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
  (`matmul_take_nanEq`, `matmul_take_error`).

Not proved yet:

- kernel theorems for corpus kernels with shared memory or barriers, and for the other 12
  specializations of the naive matrix product: the importer accepts `tiled_matmul` and most other
  corpus files, but only the elementwise kernels above, the tutorial's `vector_subtraction` and
  one naive matrix product have a kernel theorem, and that product's threads' runs are proved by
  hand in the tests, not generated by `mojo_kernel`;
- launches other than one-dimensional ones for the kernels above, and real MAX kernels (layer norm,
  softmax, GEMM) against the PyTorch-level operations they implement;
- anything after the LLVM IR: LLVM's optimizer, the NVPTX backend, `ptxas`, the driver and the GPU;
- the lexer, parser and printer, which are checked on every corpus file and at every import
  (printing gives back the file's tokens) but not proved.

What the theorems assume (Lean and the libraries, where the IR comes from, and our reading of
LLVM's and PTX's documentation) is listed in [docs/TRUST.md](TRUST.md).
