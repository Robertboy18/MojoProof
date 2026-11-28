# The spec-free kernel theorem (`Kernel.Safe`) and the sweep of Modular's GPU tests

Lean: MojoProof/Kernels/Safe.lean (`MojoProof.Sem.Kernel.Safe`, `Kernel.Safe.of_sound`); the
instance at `vector_addition` in MojoProofTest/SafeVadd.lean; the spec-free mode in
MojoProof/Kernels/SafeCmd.lean (`Kernel.safe_of_admits`, `mojo_safe`), tested in
MojoProofTest/SweepSafe.lean. Scripts: scripts/safe_sweep.py (the
sweep's order, compile, keep, corpus and table steps), scripts/SafeSweep.lean (its attempt),
scripts/L3Programs.lean (the kinds table roadmap/llvm-ir/kinds.tsv). Table:
roadmap/kernels/sweep.tsv. Corpus: tests/sweep/.

**Scope.** `Kernel.Safe` is defined for every program, kernel, launch, arguments, memory,
admission and observation; `Kernel.Safe.of_sound` is proved for all of them and every relation.
The theorems of MojoProofTest/SafeVadd.lean are about `vector_addition` (tests/corpus/vadd/)
only. `Kernel.safe_of_admits` is proved for every program, kernel, list of paths that
`coversEntry` accepts, launch, arguments and memory; the theorems `mojo_safe` adds are about the
one kernel it is given, and those at a launch (`n.safe_at`, `n.obs`) about that launch only.
The sweep is one compile of the files under `max/kernels/test/gpu` and `max/examples` of
modular/modular at one commit, with one Mojo nightly, up to the time budget of its round; the
table says which files it reached. It proves no theorem: a `proved` row names a theorem of a test
module.

## Statement

`Kernel.Safe prog fn L args m adm obs` is `MojoProof.Sem.Kernel.Sound prog fn L args m adm obs
(fun _ => True)`: soundness at the relation that holds of every output. Unfolded: for every
address choice `ch` and oracle family `ω` with `adm ch ω`, `Grid.start` returns `.ok (g, c)` and
`MojoProof.Sem.Grid.Sound L c g obs (fun _ => True)` holds, that is:

| field of `Grid.Sound` | what it says of every grid reachable from `g` |
|---|---|
| `safe` (`MojoProof.Sem.Grid.Safe`) | no step faults: no undefined behavior, out-of-bounds or dead access, or unsupported instruction |
| `raceFree` (`MojoProof.Sem.Grid.RaceFree`) | its trace has no data race |
| `kept` (`MojoProof.Sem.Grid.Kept`) | the promise of every `!invariant.load` is kept |
| `progress` (`MojoProof.Sem.Grid.Progress`) | a grid with a thread that has not returned has a step (no barrier deadlock) |
| `terminates` (`MojoProof.Sem.Grid.Terminates`) | every execution is finite, under every schedule |
| `determinate` (`MojoProof.Sem.Grid.Determinate`) | the grids in which every thread returned agree on `obs` |
| `post` | each of those grids has an observation (`obs` is `some y`) |

`MojoProof.Sem.Kernel.Sound.exists_obs` applies to it as to any soundness theorem: at an admitted
choice, some complete run is observed (`Kernel.Obs`), and the relation, `True`, holds of it.

What it does not say: anything of the observed value. No elementwise sum, product or error
bound, and no relation between the inputs and the output; those are `Kernel.Sound` at a relation
that depends on its argument, and the kinds table calls such a theorem `correct`.

`Kernel.Safe.of_sound`: `Kernel.Sound prog fn L args m adm obs R` gives `Kernel.Safe prog fn L
args m adm obs`, for every `R`. So every kernel theorem of the library gives its spec-free
statement; MojoProofTest/SafeVadd.lean does it at `Kernels.vadd.correct`.

## Premises, launch family, admission, observation

A spec-free theorem has the premises of the kernel it is about, in the form of the kernel
theorems (docs/proofs/kernel.md): a valid launch (`Launch.Valid`) and the shape the kernel
supports (for `vector_addition`, grid and block of side 1 in `y` and `z`), the arguments
(`Kernels.vadd.args a b out n`), and a memory with the buffers the arguments point to
(`Map2.Pre`). It does not need the inputs' values: the premise that gives the output's
specification (`x` and `y` the tensors at `a` and `b`) is kept only because `Kernels.vadd.correct`
takes it; a theorem proved directly from the symbolic run would not.

The admission `adm` is the set of address choices and oracle families the theorem is for.
`vadd_safe` admits all of them (`fun _ _ => True`): `Kernels.vadd.correct` is for one oracle
family `ω` (its admission is `fun _ ω' => ω' = ω`), and `vadd_safe` applies it at each.

The observation is that of the kernel theorem: for `vector_addition`, the blocks
(`fun m => some m.blocks`). An observation that does not depend on the memory (a constant) would
make `determinate` trivial; the witness rule refuses one (below).

## Witness

A spec-free theorem is counted when it has a witness that L3Programs accepts
(scripts/L3Programs.lean, `witnessOf`). The witness form is

```lean
theorem w : L.Valid ∧ ∃ y, Kernel.Obs prog fn L args m obs ch ω y ∧ Q y :=
  ⟨launch2_valid (by decide), Kernel.Sound.exists_obs (T a₁ … aₙ) …⟩
```

with the same closed launch `L` in both conjuncts, read by its syntax (no `abbrev` or `def`
around the statement), no premise, and only binders whose types have an `Inhabited` instance in
the empty context (the address choice and the oracle family do). The observation must depend on
its argument. `w` credits the theorems its soundness proof applies: `T`, and through a
conversion (one `GPUProof.Kernel.Sound` premise at the same program, function, launch,
arguments, memory, admission and relation) or an instance (a proof that is another theorem
applied) the theorems below it; a case split, `match`, `if` or bridge ends the chain. When the
relation is `fun _ => True` (`Kernel.Safe`), the witness counts for the spec-free theorems of
its chain only, never for a theorem with a specification. `L.Valid` rules out a launch with no
thread, where every kernel is sound for any relation of the initial memory. `vadd_safe_obs23` is
the witness of `vadd_safe23` and `vadd_safe`: `L23` is valid and one complete run of
`vector_addition` on 2 blocks of 3 threads with count 5 is observed.

## The spec-free mode (`mojo_safe`)

`mojo_safe n := P fn` proves `Kernel.Safe` of kernel `fn` of program `P` from the function
alone, with no specification and no hand-written proof line (MojoProof/Kernels/SafeCmd.lean).

- **What is proved, and for which launches, arguments and memories.** `n.safe`: for every
  launch `L`, arguments `args` and memory `m` whose pointer bytes are known (`Mem.BytesIn`),
  `Kernel.Safe P fn L args m (Kernel.Admits P fn L args m paths) (fun m => some m.blocks)`, at
  the kernel's paths `paths`. It is one application of the library theorem
  `MojoProof.Sem.Kernel.safe_of_admits`, proved once for every program, kernel and list of
  paths that `coversEntry` accepts, at the `covers` theorem of the kernel.
- **The parameter clauses** are derived from `fn.params` (`MojoProof.Sym.clausesFor`): a
  `byval` buffer struct (`Param.buffer`) is a `reads` clause, an integer (`Param.scalar`) a
  `scalars` clause, a plain pointer (`Param.pointer`) a `pointers` clause, parameter `i` named
  `p<i>`, and any other parameter an error naming it. Outside `map2` and `mat`, `mojo_kernel`
  checks `reads` and `writes` alike, so every buffer is a `reads` clause. The command runs
  `mojo_kernel n := P fn <clauses>` (the summaries `n.b<i>`, the paths `n.paths`, `n.covers` by
  `decide +kernel`, `n.sound_of`, and, for a constant `fn` in a program with no globals and no
  launch limit, `n.args`, `n.starts`, `n.sound`), unless the environment has a `covers` theorem
  of the same program and kernel (`coversEntry P fn _ = true`, the same terms), which it uses
  instead; `n.safe` likewise is not added when a theorem `safe` of the same statement exists.
  So `mojo_safe` at `Kernels.vadd` uses `Kernels.vadd.covers` and adds no second copy of its
  summaries. A kernel that `mojo_kernel` refuses (a block outside the fragment, a loop) is an
  error with `mojo_kernel`'s message.
- **The admission** `Kernel.Admits P fn L args m paths ch ω` (`Kernel.admits … = true`) is a
  closed form that the kernel decides on a concrete launch, arguments, memory, address choice
  and oracle: the start succeeds with grid `g` and contexts `c`; each thread in turn, from the
  memory the threads before it left (`Kernel.mems`), has a path of `paths` that `Ret.check`
  accepts (`MojoProof.Sym.Kernel.check`: the obligations of every block of the path, the exits
  between them, `ret`, and the last block's effects); and the trace of the memory the threads
  leave has no data race (the core's `GPUProof.racy` at `MojoProof.Sem.sig` is false) and keeps
  the promise of `!invariant.load` (`GPUProof.kept`). The first part is the conjunction of the
  block summaries' obligations over the threads, each at its own entry valuation; race freedom
  adds a condition on pairs of threads that no per-thread obligation states: no two threads'
  accesses to one cell, one a write, in the trace of that serial run. It is not a symbolic
  footprint: the conditions are evaluated at a concrete valuation, not stated of the launch's
  sizes.
- **The observation** is the blocks (`fun m => some m.blocks`), so `determinate` says every
  schedule ends with the same memory contents.
- **At one launch.** `mojo_safe n := P fn at L args m ch ω hm` (`hm : m.BytesIn m.Known`) first
  evaluates `Kernel.firstFail` there. When the admission holds it adds `n.safe_at`,
  `Kernel.Safe P fn L args m (fun ch' ω' => ch' = ch ∧ ω' = ω) (fun m => some m.blocks)`, by
  `Kernel.Safe.narrow` from `n.safe` with the admission decided by `decide +kernel`, and the
  witness `n.obs : L.Valid ∧ ∃ y, Kernel.Obs P fn L args m (fun m => some m.blocks) ch ω y ∧
  True` (the witness form above, by `Kernel.Sound.exists_obs` at `n.safe_at`; `L` a
  `launch2 …`). When it does not hold, the command fails with the first obligation left, and adds
  nothing after `mojo_kernel`'s declarations: `the start faults: <fault>`; `thread <k>: block
  %<name>: obligation <i> of <n> (<what it says>) does not hold: <fault>`, the first thread none
  of whose paths is a `Ret` and the first block and obligation on its paths that fails (or `its
  effects fault`, or `none of the kernel's paths is the one the thread follows`); `race
  freedom: the trace of the threads, run in turn, has a data race (GPUProof.racy)`; or the
  broken `!invariant.load` promise (`GPUProof.kept`).
- **What it does not cover.** A kernel with a loop: `mojo_kernel` stops at the loop's block, the
  obligation left being its invariant. A block outside the checker's fragment with both flags
  off (a warp shuffle, a barrier, `fcmp`, `lifetime.start`, `fmul contract`, `alloca`):
  `Kernel.safe_of_admits` is at `coversEntry`, and `MojoProof.Sym.Kernel.sound_eval`, which it
  applies, is at the flags off. A family of launches (every count `n`): the admission is not
  reduced to a formula of `n`; each instance is decided. And `n.safe` alone does not show its
  admission is satisfiable: that is `n.obs`, at one launch.

Tests (MojoProofTest/SweepSafe.lean): the two `bitonic_global_step` files of tests/sweep whose
kernels are in the fragment (`True`, the files' `sgt`, and `False`, `slt`; both have
`"nvvm.maxntid"="256"`, so `mojo_kernel` adds no `n.starts` for them), each safe at 2 blocks of 4
threads on 8 values with partner distance 1 and run length 2 (`bitonicT.safe_at`,
`bitonicF.safe_at`, `bitonicT.obs`, `bitonicF.obs`); `vector_addition` at `kernel22`'s launch,
arguments, memory, choice and oracle (MojoProofTest/Kernel.lean), whose `vaddS.safe_at` is
`Kernel.Safe.of_sound kernel22` (`rfl`: the same statement); and a negative twin of each, each
refused with the obligation named (`#guard_msgs`) and its admission false (`decide +kernel`):
`bitonic_global_step` at partner distance 4 with four values for a count of 8 (thread 0 loads
value 4: `block %34: obligation 0 of 7 (a branch condition evaluates to a word) does not hold:
undefined behavior: access out of bounds`), and `vector_addition` with its output one cell
after its first input, in the first input's block (`race freedom: …`).

## The kinds table

roadmap/llvm-ir/kinds.tsv: the header `theorem\tprogram\tkind`, then one row per soundness term
of each theorem of roadmap/llvm-ir/programs.tsv (`MojoProof.Sem.Kernel.Sound`, `Kernel.Safe`, or
`GPUProof.Kernel.Sound` at `MojoProof.Sem.sig`; each conjunct of a conjunction its own row),
sorted: `safe` when the term's relation applied to a variable reduces to `True` (so
`fun _ => True`, `Kernel.Safe`'s, and a definition that unfolds to it), `correct` otherwise; a
theorem with no soundness term has one row `-`, `safe`. A relation that ignores its argument but
is no `True` (`fun _ => 1 = 1`) is `correct`. scripts/kernel_universe.py reads it: the functions
with a `correct` theorem are those the coverage page calls proved, and `kind='safe'` gives those
with a spec-free one. A theorem the table does not list counts as `correct`.

## The sweep

One round compiles the test files, keeps the per-kernel files of the functions of
roadmap/kernels/universe.tsv, and tries the spec-free theorem at each.

1. **Order** (`safe_sweep.py order`): the `.mojo` files under the two directories, the files that
   launch a universe function by name in an `enqueue_function[...]` first (not a function the
   file defines itself), the smaller files first within each group. The target is read from the
   path: an AMD or Apple test is not compiled; Blackwell (`sm_100a`), Hopper, its TMA and clusters,
   and the multistage GEMM (`sm_90a`); `sm_80` otherwise.
2. **Compile** (`safe_sweep.py compile`): one file at a time with tools/mojoc.sh (the
   per-kernel `.nvptx.ll` files of the corpus's form), until the round's budget is spent; before
   each, the available memory and the box's load are read and recorded, and the compile waits
   while either is out of bounds. Each row of the state's compile.tsv records the exit, the
   seconds, the peak resident set and the emitted kernels; the step resumes where it stopped.
3. **Keep** (`safe_sweep.py keep`): each emitted per-kernel file whose one `ptx_kernel` is a
   specialization of a universe function (its name is the function's name or starts with it and
   `_`, the longest such name) that the test file does not define itself, one file per sha256.
   The attempt runs at every kept file. Of them, the smallest for each (function, test file)
   pair goes to the corpus (`safe_sweep.py corpus`, by `corpus.py add --root tests/sweep`): the
   directory tests/sweep/, with a manifest of its own (tests/sweep/MANIFEST.tsv, checked by
   `corpus.py check --root tests/sweep`), so that the gate's `#mojo_corpus`, which reads
   tests/corpus/MANIFEST.tsv, does not read them.
4. **Attempt** (scripts/SafeSweep.lean, `lake env lean --run scripts/SafeSweep.lean <state>
   <files> <revision>`): each kept file is imported as `mojo_import` imports it (the parser, then the
   module's checks at the file's SHA-256), and its kernel is run, block by block, by the block
   checker with no specification (`MojoProof.Sym.summarizeAt`), and the branches between the
   blocks' summaries are searched for a loop. The steps stop at the first that fails, and the
   reason says which: `importer refusal` (the importer's message), `automation failure` with
   `outside the fragment: <opcode>` (the block and the statement the checker refuses), `a loop at
   block <label>` (the spec-free mode has no loop invariant), or, from round 2, the spec-free
   mode's own steps as `mojo_safe` runs them (`mode`: the parameter clauses from the function,
   the summaries with both flags off, the paths, and `coversEntry` on them, evaluated), with
   reason `the mode: <the step that fails>` or `the mode applies`: then
   `Kernel.safe_of_admits` gives `Kernel.Safe` at the admission `Kernel.Admits` for every
   launch, arguments and memory, but the attempt chooses no launch, arguments and memory at which
   the admission holds, so the outcome stays `automation failure`. No step proves a theorem and
   no step finds a counterexample: the attempt measures how far the automation gets without a
   specification. A row is `proved` when a test module (MojoProofTest/Safe*.lean or
   MojoProofTest/Sweep*.lean) has `mojo_safe n := x.prog x.fn_0 at …`, not under `#guard_msgs`,
   at a file `x` of tests/sweep/ with the row's digest (`safe_sweep.py`'s `proofs`); the reason
   names `n.obs`. An attempt is keyed by the file's sha256 and the checker revision
   (`safe_sweep.py revision`): the first 16 hexadecimal digits of a SHA-256 digest of
   scripts/SafeSweep.lean and every repository module it imports, transitively (the importer, the
   block checker and everything they import), with lean-toolchain and lake-manifest.json. It is a
   digest of the sources, not a commit: an uncommitted change is a new revision too. A row of the
   state's attempts.tsv is reused only at its digest and its revision; at another revision, or
   another digest under the same file name, the file is attempted again.
5. **Table** (`safe_sweep.py table`): roadmap/kernels/sweep.tsv, one row per (universe function,
   its source path, test file, specialization, sha256) with its outcome and reason, the outcome
   that of the attempt at the row's sha256 and the current revision (else `not attempted at
   revision <revision>`); a test file that launches a function and was not compiled this round,
   or built and emitted no specialization of it at its target (`not compiled`), or failed to
   compile (`the file does not build`, with the compiler's first error line), and a function that
   no listed file launches by name (`no test launches it`), get a row too. A function is keyed by
   its source path and its name: universe.tsv has 14 names of two or more functions (the two
   `_bmm0_bs` of the attention kernels, `mha.mojo` and `mha_cross.mojo`, among them), and a test
   file's launch of such a name is of the function of the module it imports the name from (or
   imports whole), or of none when its imports do not say which.

The table is the round's measurement, not a proof: only a row whose outcome is `proved` names a
Lean theorem, and that theorem is in MojoProofTest/Safe*.lean or MojoProofTest/Sweep*.lean.

## Round 1

modular/modular at 483e1348 with Mojo 1.3.0.dev2026112705 (03c5ad77). Of the functions of
roadmap/kernels/universe.tsv, 58 are launched by name by a listed file; the round compiled every
such file at an NVIDIA target, which launches 54 of them, and kept per-kernel files of 30:

| step | count |
|---|---|
| test files ordered | 1003 (676 at `sm_80`, 62 at `sm_90a`, 154 at `sm_100a`, 111 AMD or Apple, not compiled) |
| compiled in the round's budget | 255: 211 built, 44 did not (below) |
| kept per-kernel files | 820, one per sha256: 820 runs of the attempt's steps, none a proof attempt (no step had a proof path) |
| in tests/sweep/ | 130, the smallest of each (function, test file) pair, 15.4 MB |
| `proved`, `counterexample` | 0, 0 |
| `importer refusal` | 34 at step 1, 28 at step 2 |
| `automation failure` | 786 at step 1, 792 at step 2 |
| rows `not compiled`, `the file does not build`, `no test launches it` | 70, 23, 373 |

Step 2 reran the attempt step on the 31 kept files refused at step 1 for a special or bit-pattern
float literal or a comment in a call's arguments, after the lexer (MojoProof/LLVM/Lexer.lean)
read both; the other 789 attempts are step 1's, made before the lexer change and kept at step 2
because the attempt was then keyed by the file name alone (the keys of step 4 above did not
exist yet), so step 2's table mixed two revisions of the importer. None
of the 31 is proved: 25 are refused at their next construct (an intrinsic the importer does not
know, or an inline `ex2.approx.ftz.f32`), and 6 reach the block checker and fail there (5 at
`call @llvm.lifetime.start.p0`, 1 at a branch to a block with a vector `phi`).

The 44 files that did not build: 19 import a module of their own directory (tools/mojoc.sh
passes no include path); 21 use a Blackwell or AMD feature their path does not name (`mxfp`,
`tmem`, `amd_structured`, `ping_pong`, `lds`) and were compiled at `sm_80` (11 `function
instantiation failed`, 10 `failed to run the pass manager for offload functions`); 2 fail a
`shmem_p` conversion, 1 a `shmem_put` aliasing check, and 1 at `syncscope("agent")`, which the
NVPTX backend does not support.

The automation failures and importer refusals at step 2, by reason, most frequent first (step 1
had 141 at `lifetime.start`, 25 at a terminator, and the 31 refusals step 2 reran: 29 for a
literal, `-inf`, `+inf`, `+qnan` or `f0xF1800000`, and 2 for a `/* (inf) */` comment):

| files | reason | functions |
|---|---|---|
| 461 | outside the fragment: `call @llvm.nvvm.shfl.sync.idx.i32` (a warp shuffle; the block checker runs one thread) | the `gemv_kernel` family, the `multistage_gemm_kernel` family, `multistage_gemm_split_k_kernel` |
| 146 | outside the fragment: `call @llvm.lifetime.start.p0` (in the semantics, not in the block checker) | the `gemv_split_k` family, `mha` |
| 113 | a loop (no invariant) | the `matmul_kernel_naive` family, `conv2d_gpu_naive_nhwc_rscf`, `mha`, `naive_batched_matmul_kernel` |
| 26 | outside the fragment: a terminator (a branch to a block with vector `phi`s) | `conv3d_gpu_naive_ndhwc_qrscf`, `mha` |
| 22 | outside the fragment: `call @llvm.nvvm.barrier.cta.sync.aligned.all` | the `gevm_kernel` family |
| 11 | outside the fragment: a call of a `grid_controls` function | the `gevm_kernel` family, `mha` |
| 9 | importer: the intrinsic `@llvm.ctlz.i64`, which it does not know | `matmul_kernel_naive` at 8-bit floats |
| 8 | importer: the intrinsic `@llvm.nvvm.cp.async.wait.all`, which it does not know | `mha`, `mha_decoding` |
| 6 | outside the fragment: `insertvalue` (into `{ i64, {} }`) | `multistage_gemm_split_k_kernel` |
| 6 | importer: an inline `ex2.approx.ftz.f32` | `mha_splitk_reduce` |
| 3 | outside the fragment: `call @llvm.lifetime.end.p0` | `repack_Q4_0_for_sm8x` |
| 3 | importer: an inline `cvt.rn.satfinite.e4m3x2.f32` | `matmul_kernel_naive`, `multistage_gemm_kernel`, `multistage_gemm_split_k_kernel` |
| 2 | importer: the intrinsic `@llvm.fabs.f32`, which it does not know | `gemv_kernel`, `gevm_kernel` at 8-bit floats |
| 2 | outside the fragment: `fcmp` (the block checker refuses it) | `bitonic_global_step` |
| 2 | in the fragment, no loop | `bitonic_global_step` |

A family is the function and its `_compute_fn` and `_epilogue_fn` (and, for `gemv_kernel`, its
`_vector` and `_vector_multirow`) variants, each a function of universe.tsv. The first reason is
no gap of the importer: the warp kernels the library proves (`gemv_kernel`, `gevm_kernel`) are
proved by the warp tactics, with a specification, and the attempt uses the per-thread block
checker only. The two files of `bitonic_global_step` in the fragment are the round's nearest
spec-free theorems: their kernels have 10 blocks and no loop, and no command proves
`Kernel.Safe` from the block summaries alone.

The naive matmul kernel at the nightly file
(tests/corpus/mgemm_dev2026112705/g_matmul_kernel_naive_float32_float32_float32_True_16_343aedc5.nvptx.ll)
is byte for byte a kept file of the round (from
`max/kernels/test/gpu/linalg/test_multistage_gemm_kernel.mojo`, the same sha256), so the run
covers it: `a loop at block %46`. No spec-free theorem of it is proved.

## Round 2

The attempt step again, over round 1's 820 kept files, at checker revision `f31ec9ed6c0b88a8`
(step 4 with the mode; the attempts keyed by digest and revision, the functions by source path
and name). No file was compiled again. None of round 1's attempts was reused (they carry no
revision), so all 820 ran again: 36:58 in one process, 3.4 GB at most. The table, before (round
1, step 2) and after:

| outcome | round 1 | round 2 |
|---|---|---|
| `proved` | 0 | 2 |
| `importer refusal` | 28 | 28 |
| `automation failure` | 792 | 790 |
| `counterexample` | 0 | 0 |
| `not compiled` | 70 | 39 |
| `the file does not build` | 23 | 14 |
| `no test launches it` | 373 | 393 |

At the kept files, 818 of the 820 attempts have round 1's outcome and reason, the 789 that round
1 kept from its step 1 among them: the two revisions that round 1's table mixed gave the same
outcomes. The other two are the `bitonic_global_step` files in the fragment, now `the mode applies
(10 blocks, 4 paths)` at step 4, and `proved` in the table by `MojoProofTest.SweepSafe.bitonicT.obs`
and `bitonicF.obs` (`mojo_safe`; `bitonicT.safe` and `bitonicF.safe` for every launch, arguments
and memory of the admission). No file stops inside the mode: these two are the only files that
reach step 4. The rows of no kept file differ by the keys alone: round 1 had one row per bare
name, so a test file's row for a name of two or more functions was repeated (31 `not compiled`
rows and 9 `the file does not build` rows were copies), and a name that no file launches had one
row for all its functions; round 2 has one row per function (source path and name), 451 of them,
58 launched by a listed file.

The reasons at round 2, most frequent first, are round 1's (the table above, under Round 1) less
the two files `in the fragment, no loop`: 461 at the warp shuffle, 146 at `lifetime.start`, 113 at
a loop, 26 at a branch to a block with vector `phi`s, 22 at the CTA barrier, 11 at a call of a
`grid_controls` function, 9 at `ctlz`, 8 at `cp.async.wait.all`, 6 at `insertvalue`, 6 at an
inline `ex2.approx.ftz.f32`, 3 at `lifetime.end`, 3 at an inline `cvt.rn.satfinite`, 2 at `fabs`
and 2 at `fcmp`.

## The next reason: loops, by walks (plan)

Of the reasons after the mode, the loop is the one the mode reaches first: a file whose blocks
the checker summarizes stops at step 3 (`a loop at block %<label>`) before the mode runs, while a
warp shuffle or a barrier stops it at step 2, in the block checker, which is the other lane's this
round. The loop needs no invariant in the spec-free mode, because the admission is decided by
evaluation at each launch: each thread's path through the loop can be computed there instead of
enumerated once for the kernel. The plan, for every program, kernel, launch, arguments and memory:

1. **The table** (one per kernel, decided once): `MojoProof.Sym.coversTable P fn sums`, with
   `sums : Array Summary` (`sums[i]` the summary of `fn.blocks[i]`), holds when `phiCount fn` is
   0 at the first block's label, and for every `i` with `l := fn.blocks[i].label`,
   `coversAt false P fn l (phiCount fn l) (fun σ tm => σ.exitAt fn l tm) sums[i].obls sums[i]`.
   These are the summaries `mojo_kernel` already computes (`summarizeAt false … (phiCount fn l)
   …`); no path is enumerated, so a back edge is no error.
2. **The walk** (per thread, evaluated): `MojoProof.Sym.walk fn sums V fuel :
   Option (List (Nat × List Cond × Summary))` follows the table from the first block at `V`: at
   label `l` with `S` the summary of `l`'s block, it ends with `[(l, S.obls, S)]` when
   `S.exit = .ret`; otherwise it goes to `l' := S.exit.dest V (vals V S.nodes)` at `V.intoWith false l S` when
   `S.exit.pc fn l' = phiCount fn l'`, with one unit of fuel less, and is `none` when the exit
   has no target, the positions differ, or the fuel is spent.
3. **The lemma** (no change to the checker): for every program, kernel, table, valuation, fuel
   and path,

   ```lean
   theorem walk_covers (ht : coversTable P fn sums = true)
       (hw : walk fn sums V fuel = some ps) :
       ps.head?.map (·.1) = fn.blocks[0]?.map (·.label) ∧
         coversPathAt false false P fn 0 ps = true
   ```

   by induction on the fuel, each block accepted at `SState.exitAt` (the first case of
   `coversPathAt`'s inner block), at the position its edge enters it.
4. **The admission and the theorem.** `Kernel.admitsWalk P fn L args m sums fuel ch ω` is
   `Kernel.admits` (MojoProof/Kernels/SafeCmd.lean) at the paths `Kernel.walks g c sums fuel`:
   thread `k`'s walk from its entry valuation on the memory `Kernel.mems` gives at the walks of
   the threads before it. `Kernel.safe_of_walks (ht : coversTable P fn sums = true) (fuel L args
   m) (hm : m.BytesIn m.Known)` is `Kernel.Safe` at the admission `Kernel.admitsWalk … = true`,
   for the observation of the blocks: at each admitted choice and oracle, `Kernel.sound_eval`
   at the paths `ws := Kernel.walks g c sums fuel`, whose `coversEntry` is `walk_covers` at each
   element of `ws` (they are the `some`s of `walk`). `Kernel.check` then decides each thread
   against `ws`, so the walks need not be the paths the threads follow: they are candidates the
   check accepts or not.
5. **The command**: `mojo_safe` with no `covers` (the kernel has a loop) adds `n.table`
   (`coversTable … = true`, by `decide +kernel`) and `n.safe`, `Kernel.safe_of_walks` at it, and
   at a launch `n.safe_at` and `n.obs` as now. The fuel is the command's argument (the trip
   counts of the launch bound it: the naive matmul at size `K` needs about `3 K + 4` blocks).

What it covers: every launch, arguments and memory of the admission, as now; a loop of any trip
count, the count being evaluated at each launch, not stated of the launch's sizes. What it does
not: a family of launches by one formula (the same as the loop-free mode), and a loop whose
blocks are outside the fragment with both flags off. The naive matmul files (113 at `a loop at
block`, the `matmul_kernel_naive` family, `conv2d_gpu_naive_nhwc_rscf`,
`naive_batched_matmul_kernel`) are the first candidates; whether their blocks are in the fragment with both flags off is the
first measurement (the sweep's step 2 is with both flags on).

## Files

- MojoProof/Kernels/Safe.lean: `Kernel.Safe`, `Kernel.Safe.of_sound`.
- MojoProof/Kernels/SafeCmd.lean: `Kernel.admits`, `Kernel.Admits`, `Kernel.safe_of_admits`,
  `Kernel.Safe.narrow`, `Kernel.firstFail` and `mojo_safe`.
- MojoProofTest/SafeVadd.lean: `vadd_safe`, `vadd_safe23`, `vadd_safe_obs23`.
- MojoProofTest/SweepSafe.lean: the spec-free mode's tests and their refused twins.
- scripts/safe_sweep.py: the sweep (`--self-test`).
- scripts/L3Programs.lean: roadmap/llvm-ir/kinds.tsv and the witness rule (`--self-test`).
- scripts/SafeSweep.lean: the attempt (`--self-test`).
- roadmap/kernels/sweep.tsv: the sweep's table.
- tests/sweep/: the sweep's corpus, with its manifest and notice.
