# MojoProof

Machine-checked proofs for compiled Mojo, in Lean.

## Why Mojo

I really like Mojo, for two reasons.

1. **One language, all the way down.** The same language takes you from Python-style code to kernels on NVIDIA, AMD
   and Apple GPUs.
2. **One system instead of many.** What makes PyTorch and JAX hard to verify is how heterogeneous they are. One model
   runs through Python, C++, CUDA or Triton kernels and a graph compiler, each with its own semantics. With Mojo there
   is one language and one open-source compiler, so there is one thing to give a semantics to.

## Why verification

GPU kernels are easy to get quietly wrong, and testing can't cover them. A kernel that passes on the sizes you tried can
still read out of bounds, race, or give a different answer at another size or under another thread schedule. A proof
covers every input, every launch size and every schedule at once. MojoProof proves things about the code the Mojo
compiler actually emits, so the guarantee is about what runs, not about a hand-written model of it.

## What is proved today

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
  entry (`Block.sound`, `Block.sound_pathI`, `Block.sound_retI`). Its fragment includes integer
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
  closed by `decide +kernel` at a concrete launch. The one kernel theorem through a loop is for a
  test program, the counting loop "for i in [0, n): p[i] = i" run by one thread with `n = 3`, at
  one memory, address choice and NaN choice (`MojoProofTest.KernelLoop.kernelK`, from what
  `mojo_kernel loopK` generates); for two such loops in sequence the command gives the thread's
  run (`MojoProofTest.KernelLoop.cnt2k_retLs`).
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
  no kernel theorem uses them yet.

Not proved yet:

- kernel theorems for corpus kernels with loops, shared memory or barriers: the importer accepts
  `tiled_matmul` and most other corpus files, but only the two elementwise kernels above have a
  kernel theorem; the naive matrix product's blocks are checked one by one, and its loop is not
  connected to the dot-product theorems above;
- launches other than one-dimensional ones for the kernels above, and real MAX kernels (layer norm,
  softmax, GEMM) against the PyTorch-level operations they implement;
- anything after the LLVM IR: LLVM's optimizer, the NVPTX backend, `ptxas`, the driver and the GPU;
- the lexer, parser and printer, which are checked on every corpus file and at every import
  (printing gives back the file's tokens) but not proved.

What the theorems assume (Lean and the libraries, where the IR comes from, and our reading of
LLVM's and PTX's documentation) is listed in [docs/TRUST.md](docs/TRUST.md).

## Quick start

Install Lean's toolchain manager [elan](https://github.com/leanprover/elan), then get and build
MojoProof. `lake exe cache get` downloads Mathlib's prebuilt files; `lake build` then takes about
11 minutes on 8 cores and under 5 GB of memory.

```sh
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
source ~/.elan/env
git clone https://github.com/Robertboy18/MojoProof
cd MojoProof
lake exe cache get
lake build
```

Check which axioms the kernel theorems use. Put this in a file `Axioms.lean`:

```lean
import MojoProof.Kernels.Vsub

#print axioms MojoProof.Kernels.vadd.correct
#print axioms MojoProof.Kernels.vsub.correct
```

and run it:

```sh
lake env lean Axioms.lean
```

It prints `'MojoProof.Kernels.vadd.correct' depends on axioms: [propext, Classical.choice, Quot.sound]`
and the same for `vsub.correct`: Lean's three standard axioms.

### Prove your own kernel

[docs/new-kernel.md](docs/new-kernel.md) walks through it, step by step, on
`vector_subtraction` (`vector_addition` with `-` for `+`), whose files are all in the
repository: the source and its IR in `tests/corpus/vsub/`, the proof in
`MojoProof/Kernels/Vsub.lean` and its tests in `MojoProofTest/Kernel.lean`. The steps:

1. Choose or write a Mojo GPU kernel. Binary elementwise kernels on one-dimensional launches are
   automatic; loops need an invariant from you, and shared memory and barriers are not covered.
2. Compile it: `mojo build --emit llvm --target-accelerator sm_80 -o <name>.ll <name>.mojo`,
   adding `--fp-mode contract=off` when its products must be exact.
3. Add the `.nvptx.ll` file to `tests/corpus/` with `python3 scripts/corpus.py add`, which writes
   its `MANIFEST.tsv` row; pass `--mojo "<version>"` when your Mojo is not the version
   `corpus.py` records (1.3.0.dev2026111705). `vector_subtraction` was compiled with
   1.3.0.dev2026112105.
4. Import it with `mojo_import "<family>/<file>" as <name>`.
5. Write the specification: what each thread writes, in FloatLib and TorchLean terms (for
   `vector_subtraction`, `vsub.bytes`, FloatLib's `Model.sub` on the inputs' cells).
6. Run `mojo_kernel` with a clause for each parameter and `map2`; it proves the kernel theorem
   `<name>.correct` with no proof lines.
7. Check it with `#print axioms`, then build, test and audit (CONTRIBUTING.md).

[docs/kernel.md](docs/kernel.md) explains the command, its clauses and its refusals, and
[docs/tactics.md](docs/tactics.md) the tactics for the goals it leaves. [AGENTS.md](AGENTS.md) is
the guide for coding agents working in the repository.

## Repository layout

- `MojoProof/LLVM/`: the LLVM IR syntax, lexer, parser and printer, the intrinsic table, the
  `mojo_import` and `mojo_corpus` commands, and a mutation harness.
- `MojoProof/Sem/`: the semantics (values, memory, floats, threads, launches) and what a kernel
  theorem states, with schedule independence and the trace-replay checker.
- `MojoProof/Sym/`: the symbolic block checker and its soundness, loops, the kernel theorems,
  `mojo_kernel` and the tactics.
- `MojoProof/Cert/`, `MojoProof/Util/`: the RUP certificate checker and SHA-256.
- `MojoProof/Kernels.lean`, `MojoProof/Kernels/`: three corpus kernels imported as Lean terms
  (`vector_addition`, the vector multiply and `tiled_matmul`), the theorems of the first two, and
  the tutorial's `vector_subtraction` with its theorem (`MojoProof/Kernels/Vsub.lean`).
- `MojoProofTest/`: the tests. Most are checked when `lake build MojoProofTest` compiles them;
  `lake test` runs the rest: SHA-256 vectors, the importer's refusals, each corpus file's digest and
  print-parse round trip, and the evaluator on `vector_addition`, `tiled_matmul` and small test
  kernels.
- `tests/corpus/`: the compiled kernels, with `MANIFEST.tsv` (digests and provenance) and the
  files the importer refuses, with their reasons (`REFUSALS.tsv`).
- `docs/`: the trusted base, guides to the commands and tactics, and informal proofs.
- `roadmap/`: one card per kernel, GPU-model construct, float operation, LLVM construct, layout law
  and `std.math` function, each with its source line, its Lean names and its level;
  `roadmap/STATUS.md` is the table of all cards, written by `scripts/roadmap_status.py`.
- `scripts/`: the corpus manifest tool, the declaration audit, the documentation checks and the
  roadmap scripts.

## Related work

- [LARK](https://arxiv.org/abs/2611.02028) proves LLM-generated GPU kernels in Lean against PyTorch,
  over a hand-built machine model with exact arithmetic; MojoProof starts from the IR the compiler
  emits, with IEEE floats, and proves schedule independence instead of assuming it.
- [VeriTile](https://github.com/VeriInfra-Lab/VeriTile) reasons in Lean 4 about Triton-style kernels
  written in its own language, against specifications over the reals; MojoProof proves the compiled
  output, with floats.
- [TensorLean](https://tensorlean.ai) verifies production GPU kernels against tensor-level
  specifications; MojoProof does this for Mojo, from the LLVM IR the Mojo compiler emits.
- [Vellvm](https://github.com/vellvm/vellvm) is a formal semantics of sequential LLVM IR in Rocq;
  MojoProof's semantics is in Lean and covers GPU launches: threads, barriers, shuffles and races.
- [lean-mlir](https://github.com/opencompl/lean-mlir) gives MLIR dialects a semantics in Lean and
  verifies rewrites; MojoProof proves properties of whole compiled kernels.
- [GPUVerify](https://github.com/mc-imperial/gpuverify) checks CUDA and OpenCL kernels for races
  and barrier divergence automatically; MojoProof also proves what the kernel computes, with every
  proof checked by Lean's kernel.
- [Faial](https://gitlab.com/umb-svl/faial) finds and rules out data races in GPU kernels by static
  analysis; in MojoProof race freedom is one part of a kernel theorem.
- On the Modular forum, Maxim's talk
  [Can the Mojo compiler prove it?](https://forum.modular.com/t/november-community-meeting-can-the-mojo-compiler-prove-it/3678)
  checks contracts inside the Mojo compiler with Z3; MojoProof works outside the compiler, on its
  output.
- [Flare](https://forum.modular.com/t/flare-v0-13-0-and-httparena-results/3587) keeps hand-written
  Lean 4 models of its protocol code in step with the Mojo code through hashes and differential
  tests; MojoProof proves the code the compiler emits instead of a model of it.

## Contributing

Contributions are welcome. Start with [roadmap/STATUS.md](roadmap/STATUS.md): pick a card whose
level can be raised. [docs/new-kernel.md](docs/new-kernel.md) takes one kernel from its Mojo source
to its kernel theorem, [CONTRIBUTING.md](CONTRIBUTING.md) says how to build, test and check a
change, and [AGENTS.md](AGENTS.md) gives the same rules to coding agents.

## License

Apache License 2.0; see [LICENSE](LICENSE). The files in `tests/corpus/` come from Modular's
repository and are under the Apache License v2.0 with LLVM Exceptions; see
[tests/corpus/NOTICE](tests/corpus/NOTICE).
