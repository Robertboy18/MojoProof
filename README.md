# MojoProof

Machine-checked proofs for compiled Mojo, in Lean. The roadmap, the guide and the docs are on the
website: **<https://robertboy18.github.io/MojoProof/>**

## Why Mojo

I really like Mojo, for two reasons.

1. **One language, all the way down.** The same language takes you from Python-style code to kernels on NVIDIA, AMD
   and Apple GPUs.
2. **One system instead of many.** What makes PyTorch and JAX hard to verify is how heterogeneous they are. One model
   runs through Python, C++, CUDA or Triton kernels and a graph compiler, each with its own semantics. With Mojo there
   is one language and one open-source compiler, so there is one thing to give a semantics to.

## Why verification

GPU kernels are easy to get quietly wrong, and testing can't cover them. A kernel that passes on the sizes you tried can
still read out of bounds, race, or give a different answer at another size or under another thread schedule. A proof can
cover every input, every launch size and every schedule at once. MojoProof's proofs read the LLVM IR that the Mojo
compiler prints for each kernel, not a hand-written transcription of the kernel. Applying them to what runs on a GPU
still trusts the semantics given to that IR and every step after it: LLVM's optimizer, the NVPTX backend, `ptxas`, the
driver and the hardware ([docs/TRUST.md](docs/TRUST.md) T2 and T7).

## What is proved today

Each line says how far it reaches. Every statement, with all its premises, is in
[docs/proved.md](docs/proved.md), and what the proofs trust is in [docs/TRUST.md](docs/TRUST.md).

- **Schedule independence**, every program: from a memory whose pointers name only its own
  blocks, at one address choice and one float choice (the whole float oracle: the payload of every
  NaN result, whether each `contract` operation is fused, and the other float freedoms of
  [docs/TRUST.md](docs/TRUST.md) T7, so runs at two float choices may differ even where no NaN
  occurs), one complete run of a launch with no fault, no race and no
  broken `!invariant.load` promise shows that every thread schedule of it is safe, terminates and
  ends with the same memory blocks, so every observation that reads only the blocks is the same;
  the traces may differ (`Grid.confluent`, `Grid.start_sound`). It is about the semantics' runs,
  not about the hardware's memory model or a launch the semantics does not describe.
- **A sound symbolic checker**, every program: a block or path the checker accepts runs as its
  summary says whenever its conditions hold (`Block.sound`).
- **Elementwise kernels**, a family: a kernel with two input buffers, an output and a count meets
  the kernel theorem when each thread takes a checked path, and each finite output cell is the
  float operation on the inputs' cells (`Kernel.sound_map2`, `Kernel.map2_real`).
- **Three kernels end to end**: `vector_addition` from `max/examples`, a vector multiply and a vector
  subtraction, each proved by one `mojo_kernel` command from its spec (`vadd.correct`,
  `vmul.correct`, `vsub.correct`).
- **A kernel with a loop**, one family: Modular's naive matrix product meets the kernel theorem at
  every row stride, and for every K up to the input strides each finite output cell is within
  FloatLib's dot-product error bound of the exact matrix product (`NaiveFam.sound`,
  `NaiveFam.matmul_error`; at the corpus's strides `NaiveKernel.correct`,
  `NaiveKernel.matmul_error`). A loop invariant of a thread in bounds, its three premises and the
  family's run are proved by hand; for the corpus's one program `mojo_kernel` generates the run.
- **Layout laws**, every layout meeting each premise: on a transcription of Mojo's layout library,
  the offsets of `crd2idx` (mixed coordinates included), `coalesce`, `row_major`,
  `zipped_divide`, `blocked_product`, `upcast` (strides that divide the factor included),
  `Swizzle`, `is_affine`, `composition` with a layout of any number of modes whose terms do not
  carry, the placement of a bit-linear layout as a `BitLayout`, and the two-level layout of a
  swizzle follow their algebraic laws
  ([docs/proofs/layout-laws.md](docs/proofs/layout-laws.md)).
- **A tile layer**, every kernel of the `map2` and `mat` clauses: the kernel theorem gives that a
  complete run computes what a small tile program computes, and the tile matrix product meets
  TorchLean's matrix product at every format and size (`map2_refines`, `mat_refines`,
  `dot_meets`; [docs/proofs/tile.md](docs/proofs/tile.md)).
- **Float bounds of reductions and normalizations**, every IEEE format and reduction tree: sums,
  butterflies, Welford statistics, softmax (masked too), log-sum-exp, layer norm and RMS norm, each
  finite result within a stated error of the exact or TorchLean's real value
  ([docs/proofs/float-reductions.md](docs/proofs/float-reductions.md)).

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

To prove your own kernel, follow [docs/new-kernel.md](docs/new-kernel.md), or hand
[AGENTS.md](AGENTS.md) to your coding agent.

## Contributing

The bugs we've found and filed in Mojo and MAX are listed in [docs/found-bugs.md](docs/found-bugs.md).

Contributions are welcome! Pick a card on the [roadmap](roadmap/STATUS.md) whose level can go up;
[CONTRIBUTING.md](CONTRIBUTING.md) says how to build, test and check a change. The website is
rebuilt from main on every merge. More: [the repository's layout](docs/layout.md) and
[related work](docs/related-work.md).

## License

Apache License 2.0 ([LICENSE](LICENSE)). The files in `tests/corpus/` come from Modular's repository
and are under the Apache License v2.0 with LLVM Exceptions ([tests/corpus/NOTICE](tests/corpus/NOTICE)).
