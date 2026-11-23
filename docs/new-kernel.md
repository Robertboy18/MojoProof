# Proving a new kernel

This guide takes one Mojo GPU kernel from source to a machine-checked theorem about what it
computes. It assumes nothing about the repository beyond a clone that builds (README.md, "Quick
start"). The worked example is `vector_subtraction`; the repository holds every file it makes:
the source and its IR in `tests/corpus/vsub/`, the proof in `MojoProof/Kernels/Vsub.lean` and its
tests in `MojoProofTest/Kernel.lean`. The commands below were run on that example, and their
output is shown where it matters, except as follows. In steps 2 and 3 the `mkdir`, `cp` and `cd`
lines were not run. The compile ran the same `mojo build` command through the repository's Mojo
wrapper, in a scratch directory, and `corpus.py add` read the IR from that directory, not from
`../build-vsub`.

## What is automatic today, and what is not

- **Automatic: binary elementwise kernels, with `map2`, on one-dimensional launches.** A kernel
  whose parameters are two input buffers, one output buffer and an `i32` count, in that order,
  where the three buffers are passed `byval` as structs of one type (how Mojo passes a
  `TileTensor` or `LayoutTensor`), with no loop, no globals, and every block in the block
  checker's fragment. `mojo_kernel` with the `map2` clause then proves the whole theorem from
  your specification: no proof lines. The theorem covers every valid launch whose grid and block
  have side 1 in `y` and `z`, every caller's memory of the precondition `Map2.Pre` (distinct,
  large enough buffers; inputs holding the tensors), every address choice and every oracle.
- **In the library, not generated: `Kernel.sound_mapNWith`.** The kernel theorem for kernels
  whose parameters are any number of `byval` buffer structs of one type followed by any number
  of scalars, at every launch, with or without `fmul contract` and loops, with the cells apart
  only on the threads that store (for 2-D cells `(row * s + col) * w`, `Launch.apart_xy` gives
  that premise) and at every admitted oracle. You supply its per-thread premise, a `Ret` for each
  thread's path or a run through its loops (`RetLsWith`). `Kernel.sound_mapN` is its case with
  one count, no loops and no `contract`; `Kernel.sound_mat` its case for a matmul kernel (the
  output and two input structs, then the `i32` sizes `m`, `n`, `K`, with 2-D cells), whose two
  per-thread premises are the runs of the threads in and out of bounds. No clause of
  `mojo_kernel` generates the whole per-thread premise for any shape other than `map2`'s (`mat`
  generates the run out of bounds), and the
  tactic `mojo_ret`, which proves `map2`'s, handles only parameters `%0` to `%3`, paths without
  loops and launches with side 1 in `y` and `z`.
- **Matmul kernels: `mat`, with the run in bounds yours.** For a kernel of `Kernel.sound_mat`'s
  shape, `mojo_kernel` with the clause `mat paths chains` (the kernel's loop-free paths and its
  sequences of loops, which it checks by evaluation) generates the call of `Kernel.sound_mat`:
  the start, the register names, the codec, the attributes, the coverage and the run of a thread
  out of bounds (`n.out`, a path of `paths` that stores nothing) are proved by the command, and
  the theorem `n.sound_mat` is left with the memory premises (`Mat.Pre` gives them), the sizes
  below `2 ^ 31`, the bytes none out of bounds, and the run of a thread in bounds `Hin` as
  premises, which you prove. With `mat paths chains inv`, for a kernel with one loop and no
  nested loop, `Hin` is proved from your invariant: `n.sound_inv` leaves one premise, at each
  thread in bounds the invariant at the loop head, its step over each round and the path out to
  `ret`, at the heads of the rounds, where the command gives the facts that rounds which only
  read keep (`LoopIterWith` with `Mat.Head`) and `n.kept` the registers the loop keeps. See
  docs/kernel.md, "The matmul clause `mat`".
- **Loops: a clause with your invariant, for loops in sequence.** The `loop` clause takes, per
  loop, the header's block number, a precondition, an invariant, a trip count, a postcondition
  and a tactic (default `decide +kernel`, which closes few obligations). The kernel must have one
  path into the first loop and, for each loop, one round and one path out, into the next loop or
  to `ret`; a nested loop is refused. The command states four obligations per loop (the path in,
  the invariant at round 0, each round keeping it, the path out) and fails, naming them, if your
  tactic leaves any. See docs/kernel.md, "The loop clause".
- **Not automatic: shared memory and barriers.** The block checker refuses a `getelementptr`
  whose base is a shared-memory global and a barrier call, and `map2` refuses a program with
  globals, so kernels such as `tiled_matmul` get no theorem from the command today.

## 1. Choose or write a kernel

Start from a kernel of the automatic shape. The example is the `vector_addition` example of the
`modular/modular` repository (`max/examples/gpu-functions/vector_addition.mojo`), with the
kernel renamed `vector_subtraction` and `-` for `+`, saved as
`tests/corpus/vsub/vector_subtraction.mojo`. Its kernel:

```mojo
def vector_subtraction(
    lhs_tensor: TileTensor[float_dtype, type_of(layout), ImmutAnyOrigin],
    rhs_tensor: TileTensor[float_dtype, type_of(layout), ImmutAnyOrigin],
    out_tensor: TileTensor[float_dtype, type_of(layout), MutAnyOrigin],
    size_dev: Int32,
):
    """The calculation to perform across the vector on the GPU."""
    var size = Int(size_dev)
    var global_tid = global_idx.x
    if global_tid < size:
        out_tensor[global_tid] = lhs_tensor[global_tid] - rhs_tensor[global_tid]
```

## 2. Compile it to LLVM IR

In a scratch directory next to the clone:

```sh
mkdir -p ../build-vsub && cp tests/corpus/vsub/vector_subtraction.mojo ../build-vsub/
cd ../build-vsub
mojo --version
mojo build --emit llvm --target-accelerator sm_80 -o vector_subtraction.ll vector_subtraction.mojo
cd -
```

`mojo build` writes one `.nvptx.ll` file per kernel, named after it; here
`vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll`. With another
Mojo version, use the name `ls ../build-vsub/*.nvptx.ll` shows.

Add `--fp-mode contract=off` (before `-o`) when the kernel's products must be exact. Without it
Mojo marks float operations `contract`, and the compiler may fuse an `fmul` with the `fadd` or
`fsub` that uses it into one multiply-add, which rounds once instead of twice; the semantics then
allows both results, and so does the theorem. `vector_subtraction` has no product (its IR has
`fsub contract`, and `#mojo_info` in step 7 reports 0 fusable pairs), so it is compiled without
the flag; with the flag the only change in its IR is `fsub float` for `fsub contract float`.
`tests/corpus/vmul/` is a kernel compiled with the flag.

**Versions.** `mojo --version` printed `Mojo 1.3.0.dev2026112105 (f23ed0af)`. The rest of the
corpus (110 files) was compiled with Mojo 1.3.0.dev2026111705 (298d4f45), the version
`scripts/corpus.py` records by default (`MOJO`). Another version may emit IR that the importer
or the block checker does not support; then step 4 or step 6 names the file, the block or the
statement.

## 3. Add the IR to the corpus

```sh
python3 scripts/corpus.py add --mojo "1.3.0.dev2026112105 (f23ed0af)" vsub \
  tests/corpus/vsub/vector_subtraction.mojo repo:tests/corpus/vsub/vector_subtraction.mojo \
  "--emit llvm --target-accelerator sm_80" \
  ../build-vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll
python3 scripts/corpus.py check
```

The arguments are the family (the directory under `tests/corpus/`), the source, where the source
comes from (`repo:<path>` for a source kept in this repository, or its path in the
`modular/modular` repository), the exact flags given to `mojo build`, and the `.nvptx.ll` files.
`add` copies each file to `tests/corpus/<family>/` and writes its row of
`tests/corpus/MANIFEST.tsv`: its sha256, line count, kernel, arch, PTX version, Mojo version,
flags and source. Leave out `--mojo` when you compiled with the version `corpus.py` records.
When the kernel is defined in a library file that the source imports, name that file with
`--lib <path>`; the vsub source defines its kernel, so its row's `lib` is `-`. `add` refuses a
source whose header lacks the Apache-LLVM license line.
`check` printed `corpus: 114 files, 0 problems`.

The repository already has this row, and `add` refuses a file already in the manifest: for your
own kernel, use your own family name.

A new row changes the corpus's counts, which a test checks: in `MojoProofTest/Corpus.lean`, the
expected message of `#mojo_corpus` (`mojo_corpus: 114 rows, 107 imported, ...` after this
example) must count your row, or step 8's build fails there with "Docstring on `#guard_msgs`
does not match".

## 4. Import it with `mojo_import`

Make a file `MyKernel.lean` at the repository root (the repository's copy of this example is
`MojoProof/Kernels/Vsub.lean`; the differences are at the end of step 8). Its start:

```lean
import MojoProof.LLVM.Quote
import MojoProof.Sym.Info
import MojoProof.Sym.KernelCmd
import MojoProof.Sym.Ops
import MojoProof.Sem.Elementwise

namespace MyKernels

open MojoProof.LLVM MojoProof.Sem MojoProof.Sym TorchLean FloatLib.Floats.Formats.BinaryInterchange

mojo_import "vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1.nvptx.ll"
  as vsub

#mojo_info vsub.prog
```

`mojo_import "<family>/<file>" as vsub` reads the file under `tests/corpus/`, checks its sha256
against its manifest row, parses and imports it, and adds the program `vsub.prog` and its
kernel `vsub.fn_0` as Lean terms, checking that they evaluate back to the importer's result and
print back to the file. `#mojo_info` is explained in step 7.

## 5. Write the specification

The specification says what each thread writes, in FloatLib and TorchLean terms. For a `map2`
kernel it is a function `bytes ω x y n k`: the bytes thread `k` stores, or `none` if it stores
nothing, for input tensors `x`, `y` of length `N`, count `n` and oracle `ω`. Next in
`MyKernel.lean`:

```lean
/-- The bytes thread `k` stores at oracle `ω`, for count `n` and vectors `x`, `y` of length `N`:
for `k < n` and `k < N`, the encoding of `deliver (x_k - y_k)` at the oracle number of thread
`k`'s `fsub` (`ω k (Nat.pair 23 0) / 3`); `none` otherwise. -/
def vsub.bytes (ω : Nat → Nat → Nat) {N : Nat} (x y : Tensor (Model FloatTy.float.fmt) [N])
    (n k : Nat) : Option (List MemByte) :=
  if h : k < n ∧ k < N then
    vsub.prog.layout.encode (.fp .float) (Val.ofFloat .float
      (deliver (Model.sub (x (⟨k, h.2⟩, PUnit.unit)) (y (⟨k, h.2⟩, PUnit.unit)))
        (ω k (Nat.pair 23 0) / 3)))
  else none
```

`Tensor (Model FloatTy.float.fmt) [N]` is a TorchLean vector of FloatLib binary32 floats, and
`x (⟨k, _⟩, PUnit.unit)` its cell `k`. `Model.sub` is FloatLib's IEEE 754 subtraction, rounded to
nearest even; `deliver r o` is `r`, with the NaN payload number `o` chooses when `r` is a NaN;
`vsub.prog.layout.encode` gives the 4 bytes of the float. `MojoProof/Kernels/Vadd.lean`'s
`vadd.bytes` is the same specification with `Model.add`.

**The oracle number.** In `vsub.bytes`, `ω k (Nat.pair 23 0) / 3` is the NaN choice of thread
`k`'s `fsub`. The `fsub` is the thread's step 23, counting from 0 (the 17 instructions of the
entry block, then 6 more); the semantics reads the choices of a thread's step `s` at
`Nat.pair s i`, for vector lane `i` (0 for a scalar); and a float operation takes its NaN choice
from that number divided by 3 (the remainder chooses a fused form under `contract`). For another
kernel, count the steps to its float instruction the same way.

**What a specification must not do.**

- Restate the code. A specification in terms of the IR (its registers, its blocks, "what block
  `%21` computes") is true of every kernel and says nothing. Write the mathematical result:
  FloatLib's operation on the inputs' cells, as `vsub.bytes` does.
- Drop cases. Say what every thread writes for every input: threads at or past the count
  (`none`: they store nothing), and every float, NaNs and infinities included. A specification
  that leaves a case out, or that assumes finite inputs, is not the kernel's behaviour, and the
  command does not prove it.

## 6. Run `mojo_kernel`

Next in `MyKernel.lean`, the command, then the axiom check:

```lean
mojo_kernel vsub := vsub.prog vsub.fn_0
  reads a := a0, b := a1
  writes out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) vsub.bytes

#print axioms vsub.correct

end MyKernels
```

Run it:

```sh
lake env lean MyKernel.lean
```

Each parameter `a<i>` of the kernel is named by one clause: `reads` and `writes` for buffers
passed `byval`, `scalars` for integers passed by value, and `pointers` for plain pointers.
`map2 t e bytes` says the kernel is binary elementwise, with element type `t` (`.fp .float`,
binary32), encoding `e` and the specification `bytes`. The command summarizes the kernel's
blocks, finds its paths, checks them, and proves `MyKernels.vsub.correct`: on every valid
one-dimensional launch and every caller's memory of `Map2.Pre`, at every address choice and
oracle `ω`, the kernel has no undefined behaviour and no data race, terminates with one result
whatever the schedule, and leaves the output buffer as the caller's with `vsub.bytes ω x y n i`
at cell `4 i` for every thread `i`, every other block unchanged. The last line prints:

```
'MyKernels.vsub.correct' depends on axioms: [propext, Classical.choice, Quot.sound]
```

Lean's three standard axioms. docs/kernel.md has every clause, every declaration the command
adds, the statement of `correct` and every refusal message.

## 7. When the command fails or goals stay open

`#mojo_info P` reports, per function of program `P`, what the checker needs to know: the
intrinsics and other functions it calls, its phases (barriers plus one), its back edges
(loops), its float operators with their flags, its fusable pairs, and for each block whether it
is in the checker's fragment or the first statement refused. On the example it printed:

```
@vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1:
  intrinsics: [@llvm.nvvm.read.ptx.sreg.tid.x ×1, @llvm.nvvm.read.ptx.sreg.ctaid.x ×1, @llvm.nvvm.read.ptx.sreg.ntid.x ×1]
  calls: []
  phases: 1
  back edges: []
  float operators: [fsub contract]
  fusable pairs: 0
  %4: 16 statements, 0 phis, to [%21, %30]; in the fragment
  %21: 9 statements, 0 phis, to [%31]; in the fragment
  %30: 0 statements, 0 phis, to [%31]; in the fragment
  %31: 0 statements, 0 phis, to []; in the fragment
```

One phase, no back edges and every block in the fragment: the `map2` shape. A kernel with back
edges needs the `loop` clause; a refused block needs a change to the kernel or to the checker.

The command's messages say which check failed (docs/kernel.md, "What it refuses, and why"). An
error at `n.ret` means `mojo_ret` could not prove a thread's path, most often because `bytes` is
not what the kernel stores. For the goals you prove yourself (a loop clause's obligations, the
per-thread premise of `Kernel.sound_mapNWith`), the tactics are, with details in docs/tactics.md:

- `mojo_obl`: a path's obligations and exits, including a loop's entry edge and round
  ([docs/tactics.md](tactics.md#mojo_obl-mojoproofsymobllean)).
- `mojo_vals`: a block's node values, the table its loads, addresses and stores are read from
  ([docs/tactics.md](tactics.md#mojo_vals-mojoproofsymvalslean)).
- `mojo_ret`: an elementwise kernel's memory steps (`Elem`) and a path's `Ret`
  ([docs/tactics.md](tactics.md#mojo_ret-mojoproofsymopslean)).
- `mojo_race`: the disjointness premises of the race-freedom results
  ([docs/tactics.md](tactics.md#mojo_race-mojoproofsymracelean)).
- `mojo_bounds`: index arithmetic on bit vectors, natural numbers and integers, such as a
  memory access's bounds ([docs/tactics.md](tactics.md#mojo_bounds-mojoproofsymboundslean)).

## 8. Check, build, test and audit

`#print axioms` in step 6 checked the theorem's axioms. To keep the kernel in the repository,
build, test and audit it as every change is (CONTRIBUTING.md):

```sh
lake build MojoProof MojoProofKernels MojoProofTest
lake test
lake env lean --run scripts/Audit.lean
python3 scripts/cited.py
python3 scripts/corpus.py check
```

`lake build MojoProof MojoProofKernels` builds the library and the kernels (the default targets),
`MojoProofTest` the test modules, and `lake test` runs the test runner: for every corpus file, its
digest, its parse, its print and its import. The audit checks that every declaration uses only
the three standard axioms, and prints counts (repeated definitions and theorems, unused
declarations) to compare with their limits in `scripts/counts.tsv`, all 0 except
`instances_tests`, at 1.

The repository's copy, `MojoProof/Kernels/Vsub.lean`, is `MyKernel.lean` with three changes:
it is in `namespace MojoProof.Kernels`, so its names are `MojoProof.Kernels.vsub.*`; it imports
`MojoProof.Kernels.Vadd`, so that the command reuses `vector_addition`'s summaries of the three
blocks the kernels share instead of declaring them again (docs/kernel.md, "Sharing
definitions"); and it has no `#mojo_info` or `#print axioms`, which the audit replaces.
`MojoProofTest/Kernel.lean` instantiates `vsub.correct`: `correctS23` on a launch of 2 blocks of
3 threads, `canaries_vsub` (five wrong outputs, each refuted), and `vsub_real`, which says that
where an output float is finite it is TorchLean's `x - y` at the cell, and its real value is the
real difference rounded to binary32.
