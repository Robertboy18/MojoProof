# `mojo_kernel`: the kernel theorem of an imported GPU kernel

`mojo_kernel` (MojoProof/Sym/KernelCmd.lean) takes a program imported from LLVM IR, one of its
kernels, and a clause for each of the kernel's parameters. It checks the kernel's blocks and paths,
and declares theorems about that one kernel. With the `map2` clause, for a binary elementwise kernel
such as `out[i] = x[i] + y[i]`, the last of them, `n.correct`, says what the kernel computes at
every valid one-dimensional launch (grid and block of side 1 in `y` and `z`) and every input that
meets the precondition. With the `mat` clause, for a matmul kernel, it declares `n.sound_mat`, the
kernel theorem at every launch with side 1 in `z`, whose premises are the memory's and the run
of a thread in bounds, which you prove; the run of a thread out of bounds is generated. Nothing
the command produces is trusted: every theorem it declares is checked by Lean's kernel like any
other.

This guide covers what the command needs, its clauses, what it declares, what the theorems say
and for which kernels, what it refuses and why, and one worked example, `vector_addition`
(MojoProof/Kernels/Vadd.lean). For a first kernel, start with docs/new-kernel.md, which takes
`vector_subtraction` (MojoProof/Kernels/Vsub.lean) from Mojo source to the kernel theorem step
by step. The proofs behind the command are explained in
docs/proofs/kernel.md. The section "The library behind the command" at the end lists the
definitions and theorems the generated theorems are built from.

## What the command needs

- **Imports.** `import MojoProof.Sym.KernelCmd` gives the command, the kernel theorems it
  instantiates, and the tactic `mojo_ret` (MojoProof/Sym/Ops.lean, docs/tactics.md) that the
  `map2` clause runs. The specification you write for `map2` needs the definitions it uses.
  MojoProof/Kernels/Vadd.lean imports `MojoProof.Kernels` (the corpus programs),
  `MojoProof.Sym.KernelCmd`, `MojoProof.Sym.Ops` and `MojoProof.Sem.Elementwise`.
- **A program and a kernel.** The command takes two terms, a `Program` and a `Func`, and evaluates
  both. They usually come from `mojo_import "path" as name` (MojoProof/LLVM/Quote.lean), which
  reads an LLVM IR file under the directory of the option `mojo_import.root` (default
  `tests/corpus`). The file's SHA-256 must be the one its `MANIFEST.tsv` row lists. The command
  declares `name.prog` and the functions `name.fn_<i>`. `mojo_corpus` (MojoProof/LLVM/Corpus.lean)
  imports several files at once; MojoProof/Kernels.lean uses it to declare `Kernels.vadd.prog`,
  `Kernels.vadd.fn_0` and the library's other corpus kernels.
- **A kernel the checker covers.** Every block must be in the block checker's fragment
  (docs/automation.md). Without the `loop` clause, each thread must run one path from the entry
  to `ret` without a cycle: the command refuses loops, naming the block. With the `loop` clause
  the kernel may have one loop, with one path into its header, one round and one path out, and no
  loop nested in it or after it; with a `loop` clause for each loop, several loops in sequence,
  each with one round and one path out into the next (below). With `map2` there are four more
  requirements: the kernel term must elaborate to a constant (a name, or a term such as `(f)`
  that denotes one), the program must have no globals, the kernel must have no loop, and the
  parameters must have the shape of a binary elementwise kernel (below). With `mat` the kernel
  must be a constant of a program without globals, with the parameters of a matmul kernel, and
  the paths and chains you give must be the kernel's (below); it may have loops.

## The command and its clauses

```lean
mojo_kernel n := P fn
  reads x := a0, y := a1
  writes out := a2
  scalars count := a3
  map2 t e bytes
```

`n` is the name under which the declarations are made, in the current namespace. `P` and `fn` are
terms (written with parentheses if they are not single identifiers). Parameter `a<i>` is the
kernel's parameter number `i`, counted from 0. The name on the left of `:=` is the binder name
that the generated theorems give the block number or the value of that parameter.

- `reads` and `writes` name buffer parameters, each passed `byval` as a struct whose first field
  is a pointer (how Mojo passes a `LayoutTensor`). For the clause check the two are the same.
  With `map2`, `reads` names the inputs and `writes` the output.
- `scalars` names integer parameters that are not passed `byval`, such as an element count.
- `pointers` names pointer parameters that are not passed `byval`, such as `ptr addrspace(1) %p`.
  The argument is the pointer itself, to offset 0 of a block number. The corpus's matmuls and
  `vector_addition` pass their tensors `byval` (`reads` and `writes`); this clause is for kernels
  that take plain pointers.
- `map2 t e bytes` (optional) declares the kernel a binary elementwise kernel. Here `t : Ty` is
  the element type (`.fp .float` for binary32), and `e : α → Val` encodes an element
  (`Val.ofFloat .float`). The specification `bytes ω x y n k : Option (List MemByte)` gives the
  bytes thread `k` stores at oracle `ω`, for input tensors `x`, `y` of one length `N` and the
  count `n`; it is `none` for a thread that stores nothing. The specification is written in Lean
  before the command, and it is the claim the command proves.
- `mat paths chains` (optional, last) declares the kernel a matmul kernel, with its paths and
  sequences of loops as terms ("The matmul clause `mat`" below).

Each parameter must be named by exactly one clause.

### The loop clause

```lean
mojo_kernel n := P fn
  loop h := pre inv trips post by tac
```

The clause comes after the others. `h` is the header's block number in `fn.blocks` (not the entry
block 0); the clause names no SSA value. The four terms are:

- `pre : Valuation → Prop`, the precondition on the thread's entry valuation `V`;
- `inv : Valuation → Nat → Valuation → Prop`, the invariant: `inv V i W` says the header's
  valuation `W` at round `i` is the one the loop reaches from `V`;
- `trips : Valuation → Nat`, the trip count from `V`;
- `post : Valuation → Mem → Prop`, what the memory the thread leaves satisfies.

`by tac` is optional; without it the tactic is `decide +kernel`, which closes few obligations.
The command runs `tac` on each of four obligations, at every valuation `V` of `pre`:

| Obligation | Statement |
| --- | --- |
| `n.entry` | the path into the loop has its premises and its last edge enters the header at the header's position (`Edge`) |
| `n.init` | `inv V 0` holds of the header's valuation after that path (`Valuation.round`) |
| `n.step` | for every `i < trips V` and `W` of `inv V i`, the round from `W` has its premises and goes back to the header (`Round`), and `inv V (i + 1)` holds after it |
| `n.exit` | for every `W` of `inv V (trips V)`, the path out from `W` runs to `ret` with a memory of `post V` (`Ret`) |

The tactic sees one obligation at a time and introduces its own names, so it typically starts
with `intro V hV` and uses `first` to pick the lemma for each shape. If it leaves any obligation,
the command fails, names each one it leaves (`n.entry (the path into the loop)`, …) and adds
nothing. MojoProofTest/KernelCmd.lean's `cnt_open` checks this message. The four terms are
elaborated in the generated statements, each at its type (`Valuation → Prop`,
`Valuation → Nat → Valuation → Prop`, `Valuation → Nat`, `Valuation → Mem → Prop`), so a term
may use field notation on a binder without a type, as in `fun V i W => inv V.ctx V.mem i W`
(MojoProofTest/KernelContract.lean's `kfK`).

### Loops in sequence

```lean
mojo_kernel n := P fn
  loop h₁ := pre₁ inv₁ trips₁ post₁ by tac₁
  loop h₂ := pre₂ inv₂ trips₂ post₂ by tac₂
```

With a clause for each of several loops, in the order a thread runs them, the paths end at a
branch into any of the headers. The command needs one path from the entry block into the first
loop and, for each loop, one round and one path out, into the next clause's loop or, after the
last, to `ret`; no loop is nested in another. `n.chains` holds one `LoopSeg` per loop. Each
loop's obligations are those above, named with its header (`n.entry4`, `n.init4`, …) and proved
by its clause's tactic, with two changes: a loop's path in is the previous loop's path out, and
the exit of each loop but the last says that every valuation `W` of `inv V (trips V)` meets the
next clause's precondition, and that every memory of the next clause's postcondition at `W` is
one of `post V`. `n.loop` runs `ChainWith.loop` for each loop in turn, from the first clause's
precondition to its postcondition, and `n.sound_loop` (on `n.args`) takes the first clause's
precondition and postcondition. With one clause, the names, the statements and the messages are as above.
MojoProofTest/KernelLoop.lean's `cnt2k` runs two clauses on SymLoop's `cnt2`, and `cnt2_open`
checks the message for the obligations of the second loop that its tactic leaves.

### Loops with `fmul contract`

```lean
mojo_kernel n := P fn
  contract
  loop h := pre inv trips post by tac
```

The flag `contract` comes before the loop clauses, if any, and puts `fmul contract` in the block
checker's fragment: the summaries are `summarizeC`'s, so a `fadd contract` that reads a recorded
`fmul contract` product fuses with it or not by the thread's oracle. The checks are
`coversEntryWith true` and `coversChainsWith true`, the obligations are over `EdgeWith true`,
`Valuation.roundWith true`, `RoundWith true` and `RetWith true` (their names and order are those
above), `n.loop` is a `RetLsWith true`, `n.sound_of` is `Kernel.sound_of_chainsAt` at
`alloca := false` and `contract := true` (its statement with `Mem.Dead false m Q` unfolded to `Q`)
and `n.sound_loop` is `Kernel.sound_entryWith` at `true`. The per-thread premise of
`n.sound_loop` also takes an admitted address choice and oracle and gives the thread's oracle
(`V.ctx.oracle = oracle k`), since a fused operation's rounding depends on it. A loop-free
kernel takes the flag with no loop clause: `n.sound_of` is then `Kernel.sound_of_chainsAt` at
`false` and `true`, `n.covers` and no sequence of loops (its cover is `rfl`). With `map2` the flag
gives `n.ret` as a `RetWith true` (the `mojo_ret` proof of a `Ret`, moved by
`RetWith.exists_true_of_ret` of MojoProof/Sym/RetFlag.lean, which holds when no summary of the
paths records an `fmul contract` product, decided on them) and `n.correct` by
`Kernel.sound_map2With (contract := true)` (MojoProofTest/KernelContract.lean's
`map2_contract`). Without the flag, a kernel with `fmul contract` is refused at the block that has
it. With `mat` the flag is optional ("The matmul clause `mat`" below).
MojoProofTest/KernelContract.lean's `kfK` is the flag on its one-loop kernel `kf`, on a launch of
six threads. Its `pre` (`preF`) is the start's facts of some thread with a memory of the invariant
`I` (`memF`, the memory after that many threads from a memory with the caller's blocks), so every
admitted thread's facts give it, and `kernelK` is `kfK.sound_loop` with every premise closed. Its
twins are the clause without the flag, the flag without a loop clause (refused at the loop, which
has no clause), and the message of a tactic that leaves two obligations; an open-goal test checks
`kfK.sound_loop`'s per-thread premise. The module's `kgK` is the flag on the loop-free kernel `kg`,
with no loop clause; its twin is `kg` without the flag.

The flag `alloca` comes after `contract`, if any, and puts `alloca` in the block checker's
fragment: the summaries are `summarizeAt true contract`'s, the check is `coversEntryAt true
contract` (`n.covers`) and `n.sound_of` is `Kernel.sound_of_chainsAt (alloca := true)` with no
sequence of loops. Its per-thread premise is a `RetWith contract` along a path to the thread's
predicate `P (k + 1)` on the memory its path leaves with the blocks it adds, its `alloca` blocks,
set dead (`Mem.Dead true m' (P (k + 1))`), since `ret` sets them dead. The flag is not combined
with a `loop` clause, `map2` or `mat`, each an error, since their theorems are with the flag off.
A block outside the checker's fragment under the flag is an error naming its first refused
statement (`refusalAt`), as LLVM text. Without the flag, the command and its declarations are as
before. MojoProofTest/SymAlloca.lean's `pathA` is the flag on the two-block alloca path of
`pathText`; `pathA_sound` meets its `sound_of`'s premises at a launch of one thread from the
empty memory, its two `alloca` blocks dead at the end. Its twins are the kernel without the flag
(refused at its first block), gemv_kernel with the flag (refused at `%6`'s statement 17, its
first `shfl.sync.idx`), and the flag with `loop`, `map2` and `mat`.

### The matmul clause `mat`

```lean
mojo_kernel naive := naive.prog naive.fn_0 reads bA := a1, bB := a2 writes bC := a0
  scalars m := a3, n := a4, K := a5 contract mat [skipN] [chainN]
```

`mat paths chains` is for a kernel whose parameters are the output `a0` and the inputs `a1`,
`a2`, passed `byval` as one struct type of a pointer and a tail with a zero value, then the
`i32` sizes `m`, `n`, `K` (`a3` to `a5`), with parameter `j` named `%j`: the naive matmul's
shape. Here `paths : List (List (Nat × List Cond × Summary))` are the kernel's loop-free paths
from the entry block and `chains : List LoopChain` its sequences of loops, both terms; the
command checks them with the path checker (`coversEntryWith contract` and
`coversChainsWith contract`) by evaluation before it adds anything, so a wrong path or chain is
refused. `contract` is optional and sets the flag of the checks and the runs. `mat` is not
combined with `map2` or `loop`. The clauses must be `reads` of `a1`, `a2`, `writes` of `a0` and
`scalars` of `a3`, `a4`, `a5`, and their names are the binder names of the blocks and sizes in
the theorems, so none may be one of their other binder names (`matBinders`: `L`, `t`, `x`, `k`,
`c`, `f`, `h`, `Hin`, …).

The clause declares four theorems and nothing else: `n.names` (parameter `j` has register name
`j`, by `decide +kernel`), `n.starts` (the start on `Mat.args z o a b m n K` of
MojoProof/Sem/Precond.lean succeeds, with `z` the zero tail), `n.out` and `n.sound_mat`.

`n.out` is the run of a thread out of bounds: from the facts the start gives the thread
(`Mat.Entry`, MojoProof/Sym/KernelMat.lean), the sizes `m`, `n`, `K` below `2 ^ 31` and bytes
`bs` that are none at every thread out of bounds, the thread takes some path of `paths` to `ret`
(`RetWith`) with a memory of `Elem` after one more thread. Its proof tries each path in order:
`RetWith.of_first` (the path's later blocks have no effects and its last returns, by
`decide +kernel`), the walk's conditions, the branch out of bounds among them, by `mojo_obl` at
the thread's row and column, and the memory by `mojo_ret`. If no path is discharged, the command
is refused (`mat: n.out does not elaborate: no path of the clause is discharged …`).

`n.sound_mat` is `Kernel.sound_mat` (MojoProof/Sym/KernelMat.lean) at `fn`, the paths and the
chains, with every premise that depends only on the program discharged: the coverage by
`decide +kernel`, the parameters by `rfl`, the names by `n.names`, the struct's codec by
`Layout.Codec.ptrArg`, the alignment by `decide`, `withAttrs` of the sizes by `rfl`, the start
by `n.starts`, the run of a thread out of bounds, `Hout`, by `n.out`. Its premises are the
launch's (valid, side 1 in `z`), the memory's (fields of `Mat.Pre`, which gives all of them;
`a ≠ b` and `K`'s bounds are not needed), `n.out`'s two (the sizes below `2 ^ 31`, the bytes
none out of bounds) and one you prove: `Hin`, every thread in bounds runs a chain of `chains` to
`ret` (`RetLsWith`) from the facts `Mat.Entry`, to `Elem` after one more thread at the 2-D cells
`(row * sC + column) * w`. Its binders have the names of the clauses and of
`Kernel.sound_mat`'s, so named arguments such as `(t := .fp .float)`, `(w := 4)` or
`(Hin := …)` work. The conclusion is `Kernel.Sound` on `Mat.args` with `Elem.Out` at those
cells.

The command does not find the run of a thread in bounds: a matmul thread's run needs a loop
invariant over the dot product at every launch, which no tactic of the library finds. With the
keyword `inv` after the clause's two terms (`mat paths chains inv`), for `chains` one chain of
one loop with no nested loop, it proves the run from an invariant you give. It adds three more
theorems. `n.runInv` is the run of one thread in bounds, from the facts the start gives it
(`Mat.Entry`, the inputs other than the output, `Elem` and `Elem.Only` before it), its bounds
and one premise `H : LoopIterWith …` at an invariant `I` for the trip count `max K 0`
(`smax(K, 0)`, `K` the third size: one round for each index below `K`). `n.sound_inv` is
`n.sound_mat` with `Hin` replaced by one premise `H`: `LoopIterWith` at each thread in bounds
`th`, where `I th` may use the thread's facts. `th : Mat.Thread …` is
a structure of those facts: the oracles, the index `th.k`, the context `th.c`, the memories
`th.m₀` and `th.m'`, the frame `th.f`, the bounds `th.inBounds`, the oracle fact `th.oracleEq`,
the entry facts `th.entry`, and `Elem` and `Elem.Only` before the thread (`th.elem`,
`th.only`). `n.kept` gives the registers that the loop keeps (`LoopSeg.kept`) at the head of
every round, each with the value that `obl_have` computes at the loop head from `Mat.Entry`, the
launch's validity, the sizes and the thread's index facts, or, where `obl_have` gives that value
only as a `Classical.choose` (at naive `%40`, the address of the thread's cell, which needs the
bounds `m * 50257 < 2 ^ 31` and `n ≤ 50257` that `Mat.Entry` does not carry), with its value at
the loop head itself. The three fields of
`LoopIterWith` (MojoProof/Sym/KernelIter.lean) are about the
heads of the rounds, the iterates `R^[i] V₀` of the round from the loop head's entry valuation
`V₀` after the chain's path in: `head` (`I` at round 0 at `V₀`), `round` (at the head of every
round `i < max K 0`, where `Mat.Head` and `I i` hold, the round's conditions, `RoundWith`, and
`I (i + 1)` after it) and `exit` (at the head of round `max K 0`, where `Mat.Head` and
`I (max K 0)` hold, the path out to `ret` with `Elem` after one more thread, `RetWith`). For a
loop that runs another number of rounds (a tiled loop over `K / t`), `H` does not hold, so the
clause's theorems do not apply to it. `Mat.Head` is what rounds that
only read keep: the function, the buffers of `Mat.Entry`, `Elem` and `Elem.Only`. The command
proves it at every head (mojo_inv at `V₀`, then `Mat.Head.iterate` at the registers through
which the loop reads, `LoopSeg.bases`, their values at `V₀` by `n.kept`, which the command adds
before `n.runInv`), and the registers the loop keeps have their values at
`V₀` at every head (`n.kept`), so `I` carries neither. A proof of `H` is
`fun th => ⟨head, round, exit⟩`, and it takes the thread's facts once. The edge into the loop is
discharged by `mojo_obl` at the thread's row and column, as `n.out`'s conditions are; if it is
not, or `Mat.Head` is not proved at `V₀`, the command is refused and adds nothing. The proof is
`RetLsWith.of_iter` (`RetLsWith.of_inv`, MojoProof/Sym/KernelMat.lean, at
`LoopIterWith.toInv`) at each thread. The round's `RoundWith` is still yours
(docs/proofs/kernel.md, "The heads of the rounds").

MojoProofTest/NaiveSound.lean runs the command on the naive matmul, with `inv`. Its
`naive_sound` is `naive.sound_mat` with the run's premise (`NaiveSpec.At`) from the facts
(`NaiveSpec.At.of_entry`); with the run `NaiveIn.runIn` it is `NaiveKernel.correct`.
`NaiveOut.runOut` is `naive.out` at `NaiveSpec.At`. Open-goal tests there show the one premise of
`naive.sound_mat` as `case Hin` and the premise of `naive.sound_inv` at a thread `th` as
`case head`, `case round` and `case exit`, and thirteen refusals check the messages. An empty
`paths` or `chains` is refused, since the checker's cover of an empty list is vacuous: with it
the theorem would cover only launches with no thread out of, or in, bounds.

## What it declares

| Declaration | What it is | When |
| --- | --- | --- |
| `n.b<i>` | the summary of block `i` (`Summary`, from after the block's `phi`s) | always |
| `n.paths` | the kernel's paths from the entry to `ret`, over the summaries | always |
| `n.covers` | `coversEntry P fn n.paths = true`, by `decide +kernel` | always |
| `n.sound_of` | the kernel theorem from the paths, with its premises left open | always |
| `n.args` | the arguments the clauses describe, from block numbers and scalars | `fn` a constant, `P` without globals |
| `n.starts` | the launch on `n.args` starts | as `n.args` |
| `n.sound` | `n.sound_of` on `n.args`, with the start discharged | as `n.args` |
| `n.argTy`, `n.argTail` | the buffers' struct type and the zero value of its fields after the pointer | `map2` |
| `n.ret` | each thread's path is a `Ret` to the elementwise invariant, by `mojo_ret` | `map2` |
| `n.correct` | the kernel theorem of the binary elementwise kernel | `map2` |
| `n.chains` | the kernel's one sequence of loops (`LoopChain`): the path into the first loop, and each loop's round and path out | `loop` |
| `n.coversChains` | `coversChains P fn n.chains = true`, by `decide +kernel` | `loop` |
| `n.entry`, `n.init`, `n.step`, `n.exit` | the loop's obligations, by the clause's tactic (with several clauses, `n.entry<h>`, … for each header `h`) | `loop` |
| `n.loop` | a thread of `pre` runs through the loops to `ret` with a memory of `post` (`RetLs`; the first clause's) | `loop` |
| `n.sound_loop` | the kernel theorem on `n.args` from `Mem.Closed` and an invariant, each thread by `n.loop` from the start's facts (`Kernel.sound_entry`) | `loop`, as `n.args` |
| `n.names` | parameter `j` of `fn` has register name `j`, by `decide +kernel` | `mat` |
| `n.starts` | the launch on `Mat.args z o a b m n K` starts | `mat` |
| `n.out` | a thread out of bounds takes a path of the clause to `ret` (`RetWith.of_first`, `mojo_obl`, `mojo_ret`) | `mat` |
| `n.sound_mat` | the matmul kernel theorem from the run of a thread in bounds `Hin` (`Kernel.sound_mat`, `Hout` by `n.out`) | `mat` |
| `n.kept` | the registers the loop keeps (`LoopSeg.kept`) at every head of a round, with their values at the loop head by `obl_have` (`LoopSeg.kept_round`) | `mat … inv` |
| `n.runInv` | a thread's run from its entry facts and `LoopIterWith` at an invariant, with `Mat.Head` at every head of a round (`RetLsWith.of_iter`, the edge into the loop by `mojo_obl`, `Mat.Head` by mojo_inv and `Mat.Head.iterate` at the registers `LoopSeg.bases`, their values at the loop head by `n.kept`) | `mat … inv` |
| `n.sound_inv` | `n.sound_mat` with `Hin` replaced by `LoopIterWith` with `Mat.Head` at each thread's `Mat.Thread` | `mat … inv` |

With `mat`, the command declares only the last six rows, the last two with `inv` (no summary,
path, `n.covers` or `n.args`).

With the flag `contract`, `n.covers`, `n.coversChains`, the obligations, `n.loop`, `n.sound_of`
and `n.sound_loop` are the `With true` forms of "Loops with `fmul contract`" above.

With the `loop` clause, `n.paths` holds only the paths that do not enter the loop (often none),
and `n.sound_of` is `Kernel.sound_of_chains` at `n.covers` and `n.coversChains`.
`n.b<i>` and `n.paths` are registered for equation lemmas, so `simp only [n.b0]` unfolds them in
the module that runs the command too. In `n.args`, a buffer is its `byval` struct with a pointer
to offset 0 of a block number and the zero value of every other field; a pointer parameter is the
pointer `.ptr ⟨b, 0⟩` to offset 0 of a block number `b`; a scalar is a bit vector. A pointer
parameter with an attribute the start checks against its address (`nonnull` or `align`) makes
`n.starts` an error: the start is proved by evaluation on every memory.

**Sharing definitions.** In a library module (one whose name starts with `MojoProof.`), and in any
module where the option `mojo_kernel.share` is `true`, the command does not add a definition
`n.b<i>`, `n.paths`, `n.chains`, `n.args`, `n.argTy` or `n.argTail` whose value an earlier
definition of `mojo_import`, `sym_summary` or `mojo_kernel` already has, in the imports or the
module. It uses that earlier constant instead, so the library has no two definitions of one
value. For example, vector_multiply has the same blocks `%4`, `%30` and `%31` as
`vector_addition`, so MojoProof/Kernels/Vmul.lean declares `vmul.b1` and uses `vadd.b0`,
`vadd.b2` and `vadd.b3`, and so does MojoProof/Kernels/Vsub.lean with `vsub.b1`. `mojo_import`
shares the same way: the blocks of vector_subtraction's file that are `vector_addition`'s are
`vector_addition`'s constants. In a module outside the library without the option, the command
does the same with the earlier definitions of the module itself, not with those of the imports,
so no module has two definitions of one value: in MojoProofTest/KernelContract.lean, `kgK.args`
is the module's `kfK.args`, without the option.

## What the theorems say, and for which kernels

Every theorem the command declares is about the one kernel `fn` of `P`. The kernel theorems
`n.sound_of`, `n.sound` and `n.correct` conclude `Kernel.Sound P fn L args m adm obs R`
(MojoProof/Sem/Spec.lean): for every address choice and oracle that the admission `adm` admits,
the launch starts, and its grid is sound (`Grid.Sound`). A sound grid has no undefined behaviour
and no data race, keeps the promise of every `!invariant.load`, makes progress and terminates.
Its final grids (the reachable grids in which every thread has returned) agree on the observation
`obs`, which is defined on each of them and meets `R`.

- **`n.sound_of` and `n.sound`.** These hold for every launch, arguments (for `n.sound`: block
  numbers and scalars), memory, admission, observation and relation, under premises that remain
  the caller's. The caller's pointer bytes must be known (`Mem.BytesIn`). `n.sound_of` also needs
  the start to succeed on every admitted address choice and oracle; `n.sound` replaces this with
  `Mem.Closed`, the memory being closed for the arguments, by `n.starts`. The observation must read
  only the memory's blocks. Finally, on each start some invariant, indexed by the number of
  threads done, must hold of the start's memory and be kept by each thread along some path of
  `n.paths` that is a `Ret` (with the `loop` clause: or through the loop of `n.chains` to `ret`,
  `RetLs`). At the end it must hold only of memories whose trace has no data race, keeps the
  promise of `!invariant.load`, and has an observation meeting `R`. These theorems reduce the
  kernel's soundness to a per-thread invariant. They do not by themselves say what the kernel
  computes.
- **`n.loop`** (with `loop`). For every valuation `V` of `pre` and every predicate `Q` that holds
  of every memory of `post V`, the thread runs from `V` through the loop of `n.chains` to `ret`
  with a memory of `Q` (`RetLs`, by `ChainWith.loop` with `inv V` and `trips V` from the four
  obligations).
- **`n.sound_loop`** (with `loop`, as `n.args`). For every launch, block numbers, scalars,
  memory `m` closed for `n.args` (`Mem.Closed`) whose pointer bytes are known, admission,
  observation reading only blocks and predicate `R`, the kernel on `n.args` is sound
  (`Kernel.Sound`) if some invariant `I`, indexed by the number of threads done, holds of every
  memory with `m`'s blocks and an empty trace (`I 0`); each thread `k`, from every valuation `V`
  with the start's facts and a memory of `I k`, meets `pre`, with every memory of `post V` one of
  `I (k + 1)`; and `I` after all threads holds only of memories whose trace has no data race,
  keeps the promise of `!invariant.load` and has an observation meeting `R`. The start's facts
  are the program, the identity `⟨k, k / volume L.block⟩`, the special registers `L.env k`, the
  function, and the register of each `scalars` and `pointers` parameter holding its argument
  (`Grid.start_scalar`). A `buffers` parameter (`byval`) gets no register fact: its register
  points to a copy the start makes. The proof is `Kernel.sound_entry` with the start by
  `n.starts`, so no evaluation of the start is needed. Without the flag `contract`,
  `n.sound_loop` is on `Kernel.sound_entry`; with it, on `Kernel.sound_entryWith` at `true`,
  whose per-thread premise also takes an admitted address choice and oracle and gives
  `V.ctx.oracle = oracle k` ("Loops with `fmul contract`" above). Neither form uses
  `Kernel.sound_entryWith`'s fact for the copy (`Grid.start_buffer`).
- **`n.starts`.** For every launch, block numbers, scalars, memory closed for the arguments,
  address choice and oracle, the start on `n.args` returns a grid (`Sym.Grid.start_ok`). Its one
  premise is `Mem.Closed`. The proof unfolds the kernel's constant to its parameters, and, when
  the kernel is `{ g with … }` (its parameters `g`'s), `g` too.
- **`n.ret`** (with `map2`). For every valid launch whose grid and block have side 1 in `y` and
  `z`, every thread of it, and every frame and memory with the facts the start gives a thread, some
  path of `n.paths` is a `Ret` to the elementwise invariant `Elem` after one more thread. That
  thread's bytes are those of `bytes`, at cell `size t * k`. The proof is `mojo_ret`: it splits on
  whether the thread is in range, and on each side proves the path's premises, the node values
  and each block's effects as steps of `Elem`. With `contract` the path is a `RetWith true`:
  `RetWith.exists_true_of_ret` moves mojo_ret's `Ret`, once `decide +kernel` checks that no
  summary of `n.paths` records an `fmul contract` product (`pathNoProds`).
- **`n.correct`** (with `map2`). Its hypotheses are:
  - a valid launch `L` (`L.Valid`, the limits of PTX launches) whose grid and block have side 1
    in `y` and `z`;
  - an alignment `al` that the element type's alignment divides;
  - block numbers for the three buffers, a count `n`, tensors `x`, `y` of length `N`, and an
    oracle `ω`;
  - a caller's memory `m` of the precondition `Map2.Pre` (MojoProof/Sem/Precond.lean).

  `Map2.Pre` says:
  - `m` is closed for the arguments;
  - the three buffers are distinct blocks;
  - each is a live global buffer owned by all threads, of at least `n` elements, at addresses
    that `al` divides; the inputs are read-only and the output is writable;
  - the generic addresses of each buffer's first `n` elements do not wrap;
  - the inputs hold `x` and `y` row-major from offset 0;
  - `n ≤ N` and `n < 2 ^ 31`.

  Under these hypotheses the kernel is `Kernel.Sound` on `n.args` at every address choice and the
  oracle `ω`, for the observation of the blocks and `Elem.Out`. The output block is `m`'s, with
  the bytes `bytes ω x y n i` of each thread `i` of the launch put at cell `size t * i` (nothing
  where they are `none`), and every other block of `m` is unchanged. Since `ω` is any oracle, the
  theorem holds at every oracle.

`n.correct` covers one kernel, at every launch and input that meet its hypotheses. It says nothing
about launches whose grid or block has a side other than 1 in `y` or `z`, about buffers that alias,
or about other kernels. Its consequences for float maps, such as "a finite output float is the
operation's result on the inputs' cells", follow from `Kernel.map2_min`, `Kernel.map2_real`,
`Kernel.map2_finEq` and `FinEq.eq_of_isFinite` (MojoProof/Sym/Kernel.lean). Their instances for
`vector_addition`, `vector_multiply` and `vector_subtraction` are in MojoProofTest/Kernel.lean.

## What it refuses, and why

The checks of the clauses, the blocks, the paths, the `loop` clause's paths and terms, and the
`map2` prerequisites all come before anything is declared. A command refused by one of them
therefore declares nothing. When the loop clause's tactic leaves an obligation, the command
restores the environment it had before its first declaration, so it declares nothing either; an
`#eval` in MojoProofTest/KernelCmd.lean checks both. With `mat` the checks come first in the same
way, and if a generated theorem does not elaborate (`mat: n.out does not elaborate`,
`mat: n.sound_mat does not elaborate`, `mat: inv: n.runInv does not elaborate`,
`mat: inv: n.kept does not elaborate`, `mat: inv: n.sound_inv does not elaborate`) the
environment is restored; for `n.out`, `n.runInv` and `n.kept` the failed attempt's own messages
are dropped, so the refusal is the one message. Every message starts with
`mojo_kernel:`. All but the first name the kernel term `fn`; the clause messages end with it in
parentheses, which the table leaves out.

| Message | Why |
| --- | --- |
| `p is not a parameter a<i>` | the right side `p` of a clause must have the form `a<i>` |
| `clause x := a<i>: the kernel has k parameters` | the parameter does not exist |
| `parameter a<i> is named by c clauses, not 1` | the launch built from the clauses must pass one value per parameter; the start pairs arguments with parameters by position and does not compare their numbers |
| `clause x := a<i>: a<i> is not byval of a buffer struct` | a `reads` or `writes` parameter must be a buffer struct passed `byval` |
| `clause x := a<i>: a<i> is not an integer passed by value` | a `scalars` parameter must be an integer not passed `byval` |
| `clause x := a<i>: a<i> is not a pointer without byval` | a `pointers` parameter must be a pointer not passed `byval` (a buffer struct passed `byval` is named by `reads` or `writes`) |
| `block %l (block i of fn) is outside the checker's fragment` | the block checker has no summary for an instruction of the block |
| `loop at block %l (block i of fn) with no loop clause; give its precondition, invariant, trip count and postcondition by loop i := pre inv trips post` | a branch goes back to a block on the current path, and the command has no `loop` clause; without one the kernel theorem covers threads that run one path without a cycle |
| `the loop clause's header h is not a block of fn other than its entry block 0 (it has k blocks)` | the header is a block number, and the entry block is not a loop's header |
| `loop at block %l (block i of fn), not at the loop clause's header …` | a second loop, or a loop nested in the clause's: the clause covers one loop |
| `the loop clause needs one path into the loop at …, one round and one path out; it has …` | `n.chains` holds one sequence of loops with one round and one path out |
| `loop at block %l (block i of fn), not at a loop clause's header (…); the clauses cover loops in sequence, with no loop in one` | with several clauses: a loop nested in one, or a loop without a clause |
| `the loop clauses need one path from the entry block to a loop, into the first clause's loop, and for each loop one round and one path out, into the next clause's loop or, after the last, to a ret; …` | with several clauses: the clauses are not in the order the thread runs the loops, or a loop has more than one round or path out; the message ends with the entry block's paths or the loop it fails at |
| `the path checker does not accept the paths of the loop at … (coversChains)` | `n.coversChains` would not hold (`the loops at …` with several clauses) |
| `the loop clause's tactic does not close n.entry (…), … for the loop at …; the command adds nothing` | the tactic leaves the obligations named |
| `the loop clauses' tactics do not close n.entry<h> (…), …; the command adds nothing` | with several clauses: the tactics leave the obligations named |
| `map2 needs a kernel without a loop (fn)` | `Kernel.sound_map2` is about kernels whose threads run one path |
| `map2 needs the kernel as a constant; … does not elaborate to one` | `n.correct` names the kernel by its constant |
| `map2 needs a program without globals; P has [@g] (fn)` | the command proves the start (`n.starts`) only for programs without globals |
| `map2 needs reads a0, a1, writes a2, scalars a3, an i32 (fn)` | `Kernel.sound_map2` is for kernels whose parameters are two inputs, an output and an `i32` count, in that order |
| `map2 needs a0, a1 and a2 byval of one type (fn)`, `map2 needs a0, a1 and a2 byval (fn)` | the three buffers must be passed `byval` with one struct type |
| `map2 needs a struct of a pointer and a tail (fn)`, `map2: the struct's tail has no zero value (fn)` | `n.args` passes each buffer as a pointer followed by the zero value of the remaining fields |
| `mat is not combined with map2 or loop (fn)` | `n.sound_mat` takes the paths and chains as given, and states no elementwise specification |
| `mat needs the kernel as a constant; …`, `mat needs a program without globals; P has [@g] (fn)` | as for `map2`: the theorem names the kernel by its constant, and `n.starts` is proved only for programs without globals |
| `mat needs a kernel of six parameters, three byval structs then three i32s; fn has k` | `Kernel.sound_mat` is for kernels of that shape |
| `mat needs reads a1, a2, writes a0 and scalars a3, a4, a5 (fn)`, `mat needs a3, a4 and a5 of type i32 (fn)` | the output first, then the inputs and the `i32` sizes `m`, `n`, `K`, the order of `Mat.args` |
| `mat needs a0, a1 and a2 byval of one type (fn)`, `mat needs a0, a1 and a2 byval (fn)`, `mat needs a struct of a pointer and a tail (fn)`, `mat: the struct's tail has no zero value (fn)` | `Mat.args` passes each buffer as a pointer followed by the zero value of the remaining fields, and the codec is `Layout.Codec.ptrArg`'s |
| `mat needs parameter j named %j, for each j (fn)` | `Kernel.sound_mat` takes the registers `%0` to `%5` by number (`n.names`) |
| `mat: the clause name x is a binder name of n.sound_mat or n.out (fn)`, `mat: two clauses have one name (fn)` | the clause names are binder names of `n.sound_mat` and `n.out`, beside their own |
| `mat needs a path; with no paths the theorem covers only launches with no thread out of bounds (fn)`, `mat needs a chain; with no chains … no thread in bounds (fn)` | the checker's cover of an empty list is vacuous, so the theorem's `Hout` (or `Hin`) would hold only when no thread is out of (or in) bounds |
| `mat: the path checker does not accept the paths (coversEntryWith c, fn)`, `… the chains (coversChainsWith c, fn)` | the given paths or chains are not the kernel's at the flag `c` |
| `mat: n.out does not elaborate: no path of the clause is discharged for a thread out of bounds by RetWith.of_first, mojo_obl and mojo_ret (fn): …` | no path of `paths` stores nothing after its entry block, returns and has its conditions proved by `mojo_obl` at a thread out of bounds, so `Hout` is not generated |
| `mat: inv needs one chain; the chains do not reduce to a list of one (fn)` | `n.runInv` proves `Hin` with one invariant, for one chain |
| `mat: inv needs a chain of one loop; its loops do not reduce to a list of one (fn)`, `mat: inv needs a loop with no nested loop; its nested loops do not reduce to [] (fn)` | `RetLsWith.of_inv` is for a sequence of one loop with no nested loop |
| `mat: the clause name x is a binder name of n.runInv, n.kept or n.sound_inv (fn)` | with `inv`, `I`, `H`, `th`, `C`, `i`, `W` and `hW` are binder names too |
| `mat: inv: n.runInv does not elaborate: Mat.Head.iterate's premise LoopSeg.loadsFrom at LoopSeg.bases (%r, …) is false: block %l of the loop path stores; block %l' of the loop path loads through a pointer whose base is not a register the loop keeps (fn)` | evaluated before the attempt: a block of the loop path stores, or loads through a pointer whose base is no register the loop keeps (`Summary.loadsIn` at `LoopSeg.bases` fails), so the rounds may change the memory `Mat.Head` is about |
| `mat: inv: n.runInv does not elaborate: Mat.Head.iterate's premise on the registers LoopSeg.bases fails at %r: obl_have gives it no value at the loop head (fn): ⊢ …`, `… fails at %r: its value at the loop head is not shown to name a block other than the output's by hne (a or b other than the output) (fn): ⊢ …` | register `%r` of `LoopSeg.bases`, which a load of the loop path reads through, has no value at the loop head by `obl_have`, or a value that `a ≠ o` and `b ≠ o` do not show to name a block other than the output's (at a pointer to the output, `⊢ o ≠ o`) |
| `mat: inv: n.runInv does not elaborate: the edge into the loop is not discharged by mojo_obl at the thread's 2-D index facts, or Mat.Head at the loop head is not proved by mojo_inv (fn): ⊢ …` | the chain's path into the loop has a condition `mojo_obl` does not prove at a thread in bounds, so `Hin` would need it as a further premise; or `Mat.Head` is not proved at the loop head. After the colon, in this row and the one above, the first error of the failed attempt from its first goal on, without the goal's hypotheses |
| `mat: inv: n.kept does not elaborate: the function at the loop head is not proved by mojo_inv, or a register the loop keeps (LoopSeg.kept, numbers rs) has no value there by obl_have (fn): …` | `obl_have` computes no value, closed or `Classical.choose`, for a register of `LoopSeg.kept` at the loop head from the clause's facts, or mojo_inv does not prove the function there. After the colon, the first error of the failed attempt from its first goal on, without the goal's hypotheses |

Two errors come from proofs, not checks. A scalar whose attributes do not accept its value by
evaluation is an error at `n.starts`. If `mojo_ret` does not prove a thread's path, for instance
because `bytes` is not what the kernel stores, the error is at `n.ret`.

Without `map2`, a kernel that is not a constant or a program with globals is not refused, but the
command stops after `n.sound_of`.

## Worked example: `vector_addition`

`vector_addition` (`tests/corpus/vadd/`) has four parameters: the inputs `a0` and `a1` and the
output `a2`, each a buffer struct passed `byval`, and the `i32` count `a3`. Thread `k` stores
`x[k] + y[k]` at output cell `k` when `k < n`. MojoProof/Kernels/Vadd.lean writes the
specification and runs the command:

```lean
def vadd.bytes (ω : Nat → Nat → Nat) {N : Nat} (x y : Tensor (Model FloatTy.float.fmt) [N])
    (n k : Nat) : Option (List MemByte) :=
  if h : k < n ∧ k < N then
    vadd.prog.layout.encode (.fp .float) (Val.ofFloat .float
      (deliver (Model.add (x (⟨k, h.2⟩, PUnit.unit)) (y (⟨k, h.2⟩, PUnit.unit)))
        (ω k (Nat.pair 23 0) / 3)))
  else none

mojo_kernel vadd := Kernels.vadd.prog Kernels.vadd.fn_0
  reads a := a0, b := a1
  writes out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) vadd.bytes
```

`vadd.bytes` is the binary32 sum of the inputs' cells `k`, delivered at the oracle number of the
thread's `fadd` (which fixes the payload of a NaN result), encoded as 4 bytes. The 7 lines of the
specification and the 5 lines of the command are all the kernel-specific text: there is no line
of proof after the command, and the module sets no option.

The command declares the summaries `vadd.b0` to `vadd.b3` of blocks `%4`, `%21`, `%30` and
`%31`, and the two paths `%4 → %21 → %31` (the thread is in range) and `%4 → %30 → %31` (it is
not). It then declares `vadd.covers`, `vadd.sound_of`, `vadd.args`, `vadd.starts`, `vadd.sound`,
`vadd.argTy`, `vadd.argTail`, `vadd.ret` and `vadd.correct`. The statement of `vadd.correct`,
written like the code above inside `namespace MojoProof.Kernels`, is

```lean
theorem vadd.correct {L : Launch} (hL : L.Valid) (hg : L.grid .y = 1 ∧ L.grid .z = 1)
    (hb : L.block .y = 1 ∧ L.block .z = 1) {al : Nat} (hal : 4 ∣ al) {a b out n N : Nat}
    {x y : Tensor (Model FloatTy.float.fmt) [N]} {m : Mem}
    (hP : Map2.Pre vadd.prog.layout (.fp .float) (Val.ofFloat .float) al vadd.argTail m
      a b out n x y) {ω : Nat → Nat → Nat} :
    Kernel.Sound vadd.prog vadd.fn_0 L (vadd.args a b out (BitVec.ofNat 32 n)) m
      (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m out (fun i => 4 * i) (vadd.bytes ω x y n) (volume L.grid * volume L.block))
```

Read in words: on every valid one-dimensional launch (side 1 in `y` and `z`), for every memory
meeting `Map2.Pre`, every address choice and every oracle, `vector_addition` starts, has no
undefined behaviour and no data race, terminates with one result whatever the schedule, and leaves
the output buffer as the caller's with each in-range thread's sum stored at its cell, every other
block of the caller's memory unchanged.

To use it, discharge its hypotheses. In MojoProofTest/Kernel.lean, `correct23` does so on a
launch `L23` of 2 blocks of 3 threads with count 5, where `pre5` gives `Map2.Pre` by
`Map2.pre_mem` on the memory `Map2.mem` builds:

```lean
theorem correct23 (ω : Nat → Nat → Nat) :
    Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 L23
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun _ ω' => ω' = ω)
      (fun m => some m.blocks)
      (Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω x5 y5 5) 6) :=
  Kernels.vadd.correct valid23 ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre5
```

The same module derives what the theorem means for the floats, under the hypotheses of
`vadd.correct`. The first three are about the observation of a complete run (`Kernel.Obs`) at
output cell `4 k`, for every thread `k` below the count, `N` and the number of threads `T`.
- `vadd_real`: the cell holds a float, and where it is finite it is TorchLean's `(x + y)` at `k`
  and its real value is the real sum of the inputs' cells rounded to binary32.
- `vadd_finEq`: the floats of two complete runs, at any two address choices and oracles, are
  equal up to `FinEq`.
- `vadd_stable`: a finite float there is the same in every complete run.
- `vadd_min`: the output after `min n T` threads, so when `n ≤ T` every cell below the count is
  written.

A second kernel, vector_multiply (MojoProof/Kernels/Vmul.lean, `vector_addition` with `*` for
`+`), uses the same clauses with `vmul.bytes` (`deliver (x_k * y_k)` at the `fmul`'s oracle
number). Its blocks `%4`, `%30` and `%31`, arguments, struct type and tail have the values of
`vadd.b0`, `vadd.b2`, `vadd.b3`, `vadd.args`, `vadd.argTy` and `vadd.argTail`, which it uses. So it
declares the definitions `vmul.b1` and `vmul.paths`, and the theorems `vmul.covers`,
`vmul.sound_of`, `vmul.starts`, `vmul.sound`, `vmul.ret` and `vmul.correct`.
Its corollaries `vmul_min`, `vmul_real`, `vmul_finEq` and `vmul_stable` are in
MojoProofTest/Kernel.lean; `vmul_real` is about each cell: where finite, the float at cell `4 k`
is the product of the inputs' cells `k`.

A third, vector_subtraction (MojoProof/Kernels/Vsub.lean, `vector_addition` with `-` for `+`), is
the worked example of docs/new-kernel.md. Its module imports its file itself with `mojo_import`
and runs the command with the same clauses and `vsub.bytes` (`deliver (x_k - y_k)` at the
`fsub`'s oracle number); like vector_multiply, it declares `vsub.b1` and `vsub.paths` and uses
`vector_addition`'s other definitions. Its corollaries `vsub_min`, `vsub_real` (with TorchLean's
`x - y` and the rounded real difference), `vsub_finEq` and `vsub_stable` are in
MojoProofTest/Kernel.lean.

## Worked example: a counting loop

The counting loop `cnt` of MojoProofTest/SymLoop.lean (`for i in [0, n): p[i] = i`, with `%n` in
register 7 and `%p` in register 8) has four blocks: the entry `%entry`, the header `%hdr` (block
1, a `phi` and the comparison), the body `%body` and the exit `%exit`. MojoProofTest/KernelCmd.lean
runs the command with the loop clause at header 1:

```lean
set_option mojo_kernel.share true in
mojo_kernel cntk := cntP cnt
  loop 1 := cntPre cntInv nOf cntPost by
    intro V hV
    obtain ⟨hP, hfn, hn, h7, h8, hm⟩ := hV
    first
      | obtain ⟨hW, hd, hpc, -⟩ := invN_entry (c := V.ctx) (k := V.k) (m := V.mem)
          (f := ⟨V.fn, 0, 0, V.regs, V.prods, [], none⟩) hfn h7 h8 hm
        rw [← hfn] at hpc
        exact ⟨hW, hd, hpc⟩
      | exact (invN_entry (c := V.ctx) (k := V.k) (m := V.mem)
          (f := ⟨V.fn, 0, 0, V.regs, V.prods, [], none⟩) hfn h7 h8 hm).2.2.2
      | (intro i hi W hW; exact invN_step hP hn hi hW)
      | (intro W hW; exact invN_exit hn hW)
```

`cntPre V` says `V` is in `cntP` and `cnt`, `%n` is `nOf V ≤ 2 ^ 60`, `%p` is at offset 0 of a
block `bOf V` with room for `nOf V` cells; `cntInv V` is SymLoop's invariant `invN` at `V`'s
context, bound and block; the trip count is `nOf V`; `cntPost V` says cell `j` holds `j` for every
`j < nOf V`. The tactic's four branches are the four obligations, by SymLoop's lemmas
`invN_entry`, `invN_step` and `invN_exit`. With `mojo_kernel.share` (and SymLoop's `sym_summary`
definitions recorded for it, which `sym_summary` does not do), the blocks' summaries are SymLoop's
`cntE`, `cntH`, `cntB` and the library's `Kernels.vadd.b3`, so the test adds no second definition
of one value. The command declares the empty `cntk.paths`, `cntk.chains` (equal to SymLoop's
`cntL.chain`, `cntk_chains`), the obligations, `cntk.loop`, `cntk.sound_of`, and, since `cnt` is
a constant and `cntP` has no globals, `cntk.args` (no arguments), `cntk.starts`, `cntk.sound` and
`cntk.sound_loop`. `cntk_three` applies `cntk.loop` at
SymLoop's `start 3`.

`cnt` has no parameters, so the frame a launch's start gives a thread has no `%n` and no `%p`, and
the per-thread premise of `cntk.sound_loop` does not hold on any launch: `cntk.sound_loop` is the
theorem's form for this kernel, not a kernel instance. MojoProofTest/KernelLoop.lean runs the
command on `cntK`, `cnt` with the parameters `%n` (an `i64`) and `%p` (a plain pointer of address
space 1):

```lean
set_option mojo_kernel.share true in
mojo_kernel loopK := cntKP cntK
  scalars n := a0
  pointers p := a1
  loop 1 := preB invV nOf postB by
    ...
```

Its invariant lemmas `invB_entry`, `invB_step` and `invB_exit` are SymLoop's for every function
with `cnt`'s blocks and every context whose program has `cntP`'s layout. The invariant `invB` also
puts the stores of the rounds so far on the trace, and the postcondition `postB` gives the end's
trace, which the end's check of data races needs. Since `cntK` is a constant and `cntKP` has no
globals, the command declares `loopK.args n p = [.bits 64 n, .ptr ⟨p, 0⟩]`, `loopK.starts` and
`loopK.sound` and `loopK.sound_loop`, whose per-thread premise has the registers `%n` and `%p`
holding the arguments; its summaries, paths and chains are `cntk`'s. `kernelK` is
`loopK.sound_loop` on `Launch.one` with `loopK.args 3 outC.2` and the memory `outC` (closed for
them, `outC_closed`), at `ch₀` and `ω₀`: the thread's precondition comes from those registers and
`outC`'s block, with nothing of the start evaluated. An `example` with `#guard_msgs` checks the
per-thread goal `loopK.sound_loop` leaves.

MojoProofTest/KernelCmd.lean tests the command:
- `vadd_paths_cmd` checks that the generated paths are the ones written by hand in
  MojoProofTest/Sym.lean.
- `short_clauses` (a clause list that misses a parameter), `kind_twin` (the count given as a
  buffer), `ptr_twin` (a buffer struct passed `byval` given as a plain pointer), `loop_refused`
  (a self-loop, refused naming `%loop`), `map2_twin` (`map2` with an input named as an output), `app_refused` (with `map2`, a kernel term that is not a constant) and
  `globals_refused` (with `map2`, a program with a global) check the refusals and their messages.
- `cntk` runs the loop clause on the counting loop (above); `cntk_chains` checks that the
  generated sequence of loops is SymLoop's, and `cntk_three` applies `cntk.loop` at `%n = 3`.
  `cnt_open` runs it with a tactic that closes the round's obligation alone, and checks the
  message naming the three it leaves.
- `paren` runs the command on `parenProg`, `vector_addition`'s program with another digest, with
  the kernel written `(Kernels.vadd.fn_0)` and the option `mojo_kernel.share` set. It uses the
  library's summaries, paths and arguments, and an `example` pins the statement of
  `paren.correct`.
- MojoProofTest/Ops.lean checks, by an `example` of `type_of% @Kernels.vadd.ret` proved by
  `mojo_ret`, that the tactic proves the statement of `vadd.ret`. `vadd_starts`
  (MojoProofTest/SymLaunch.lean) proves by hand that `vector_addition` starts on every launch
  and closed memory, the fact `vadd.starts` generates.

## The library behind the command

### Sequential schedules (MojoProof/Sym/Sched.lean)

Every result here is for every program, launch and contexts.

- **Thread steps in a grid.** `Steps.grid`: a thread's steps (`Steps`), taken by thread `n` of
  a grid that runs that thread on the grid's memory, are a run of grid steps (`Path` of
  `Grid.Step`). The run ends in the grid with only thread `n`'s status and the memory changed.
- **Runs.** `Runs c t m m'` is steps that continue `t`, then a step `.done m'`. `Runs.grid`: such
  a run is a run of grid steps to the grid with thread `n` done and memory `m'`. `Runs.trace`: it
  puts events in front of the trace.
- **Threads in turn.** `Seq c t ns m Es m'`: threads `ns` run in turn, each alone to its end from
  the memory the one before left; `Es` are the events of each. `Seq.grid`: from a grid where each
  of the distinct threads `ns` runs its thread on memory `m`, this is a run of grid steps to the
  grid with threads `ns` done, the others unchanged, and memory `m'`. `Seq.trace`:
  `m'.trace = Es.reverse.flatten ++ m.trace`. `Seq.done`: when `ns` names every thread, the grid
  reached is done (the core's `GPUProof.Done` at `sig`, `Grid.done_foldl`).
- **Soundness from a schedule.** `Seq.start_sound` holds for every program, kernel, launch,
  arguments, address choice and oracle. Start from the grid `Grid.start` gives. If threads that
  name every thread run in turn to a done grid that is not bad and observes `y` with `R y`, the
  start's grid is sound (`Grid.Sound`, by `Grid.start_sound`). That the done grid is not bad
  (`¬ GPUProof.Bad sig (z, L, c)`, the core's `Bad` at `sig`) is the caller's premise.
- **Soundness from an invariant.** `Seq.start_sound_inv` (with `Seq.of_inv`) is the same for an
  invariant `P k` of the memory after `k` threads. Suppose the start's memory is of `P 0`, and
  each thread `k` (`Grid.thread`), from every memory of `P k`, runs to its end leaving one of
  `P (k + 1)`. Suppose also that every memory of `P N` has a trace with no data race (`racy`)
  that keeps the promise of `!invariant.load` (the core's `GPUProof.kept` at `sig`), and an
  observation meeting `R`. Then the start's grid is sound. The done grid the threads leave is not
  bad, by `Grid.Done.bad_iff`: a done grid is bad only by its trace
  (MojoProof/Sem/Determinism.lean).

A kernel's proof then needs a per-thread run on every memory of the invariant, not one
schedule's memories, and facts about the last memory's trace, not about a grid. On a launch whose
grid and block have side 1 in `y` and `z`, thread `n`'s `ctaid.x * ntid.x + tid.x` is `n` for
every `n` below the number of threads (`Launch.index_oneDim`, MojoProof/Sem/Index.lean). So
thread `k` of `Seq.of_inv` is the thread whose one-dimensional index is `k`. No collective call
is involved: every grid step is `Grid.advance`, and no thread waits.

Tests: MojoProofTest/SymSched.lean and MojoProofTest/SymStart.lean.
- `vadd2_grid`: two threads of `vector_addition` in turn, the second on the memory the first
  left, reach a done grid with output cells 0 and 1 the inputs' sums.
- `vadd2_grid_twin`: with thread 0 alone, the grid reached is not done.
- `run2_runs`, `run2_seq` and `sound2_seq` use a start of two threads that each `alloca` and
  store 7. Each thread runs to its end from the memory the one before left, so the threads run in
  turn by `Seq.of_inv`. The invariant `m = mems k` ends in a memory whose trace has no data race
  and keeps the promise of `!invariant.load`, both evaluated, so by `Seq.start_sound_inv` the
  start's grid is sound for thread 1's `alloca` holding 7.

A per-thread run on every memory needs a block's table evaluated on an abstract valuation, where
`decide +kernel` refuses the goal (it has free variables). `vals_getElem?` (MojoProof/Sym/Term.lean)
takes it one node at a time: entry `j` of `vals V ns` is node `j`'s value on the values of the nodes
before it. Tests in MojoProofTest/SymCall.lean:
- `range_attrs`: the attributes `noundef` and `range(i32 lo, hi)` return every value in range
  unchanged.
- `call_sreg`: a special-register call node, on every valuation.
- `vadd4_calls`: entries 7, 9 and 11 of `vector_addition`'s block `%4` are its `tid.x`,
  `ctaid.x` and `ntid.x`, with their obligations `.ok (.node j)`.
- `vadd4_calls_launch`: the same on every thread of every valid launch, with the register ranges
  from `Launch.sreg_bound`.

### The start of a launch (MojoProof/Sym/Start.lean)

`Sym.Grid.start_ok` gives `Grid.start`'s `.ok` for every program, kernel, launch, arguments,
memory, address choice and oracle. Its premises are ones a caller checks:
- `Func.check` passes;
- the launch passes `Func.checkLaunch`: as many arguments as parameters, and the block within the
  kernel's `nvvm.maxntid` or of its `nvvm.reqntid` shape, if it has one, as a string attribute
  or as `!nvvm.annotations` entries (`maxntidx` to `reqntidz`; `kernel` admitted, other keys
  unsupported);
- the memory is `Mem.Closed` for the arguments;
- every global is in address space 3, and either external and not `constant`, or `undef`;
- every `byval(T)` argument encodes as a `T`;
- every other parameter's attributes accept its argument on every memory;
- the kernel has a body;
- every `byval` copy has a placement (`Func.byvalPlaced`): its type has no padding
  (`Layout.dense`), and some aligned address `x` in address space 0 is `placed`, that is
  nonzero, with `x + size < 2 ^ w` (no wrap, the address one past the end included) and
  `size < 2 ^ (w - 1)` for `w`-bit pointers (the index width); `launchArgs` refuses every other
  copy, and moves an address choice outside these rules to the lowest placed one (`place`).

Its invariant is `Mem.FreeAbove` (`Mem.Closed.above`): on such a memory, every allocation of the
start (`Mem.allocNext`) succeeds, whatever the address choice. Neither the address choice nor
the oracle is a premise.

Tests in MojoProofTest/SymLaunch.lean:
- `vadd_starts`: `vector_addition` starts on every launch and every closed memory, with each
  premise by `rfl`, `decide` or `simp`.
- `byval_twin`: the start faults when the first buffer is replaced by the size.
- `short_refused`: the start refuses three arguments for four parameters.

### The kernel theorem (MojoProof/Sym/Kernel.lean)

These results turn a kernel's paths into `Kernel.Sound`; their proofs are in
docs/proofs/kernel.md. Each holds for every program, kernel, launch, arguments, memory, address
choice and oracle, under the premises given.

- **Paths that return.** `Ret V Q ps` (`RetWith false`): path `ps` from valuation `V` has its
  premises (`WalkWith false`, an edge into a block with `phi`s setting them), its last block
  (`Valuation.lastWith false`) returns, and the last block's effects succeed with a memory of
  `Q`. `Runs.of_ret`: take a one-frame thread with no `alloca` blocks at the first block of a
  path that the path checker accepts (`coversPathWith false`). If the path is a `Ret` from the
  thread's entry valuation, the thread runs to its end leaving a memory of `Q`
  (`Block.sound_retWith`). `mojo_obl` proves the premises (`WalkWith` goals), and
  `Elem.retWith` (MojoProof/Sym/Ops.lean) gives a `Ret` from them with the effects as steps of
  `Elem`.
- **The start's threads.** `Grid.start_thread`: every thread `Grid.start` makes has one frame of
  the kernel at its first block, instruction 0, no `alloca` blocks, step count 0.
- **Covered paths.** `coversEntry P fn paths`: every path starts at `fn`'s first block and is
  accepted by the path checker (`coversPathWith false`) from instruction 0. A path may
  therefore cross a join whose block starts with `phi`s. This is a closed Boolean that
  `decide +kernel` evaluates on a concrete program. `coversEntryWith contract` is the same with
  the path checker with `fmul contract` when `contract` (`coversPathWith`); at `false` it is
  `coversEntry`.
- **`Kernel.sound_of_paths`.** `Kernel.Sound` from:
  - `coversEntry`;
  - the caller's pointer bytes;
  - the start on every admitted choice;
  - an observation that reads only blocks;
  - an invariant `P k` (the memory after `k` threads) along which every thread takes some path
    of the list that is a `Ret` to `P (k + 1)`. Its last memories must have a trace with no data
    race that keeps the promise of `!invariant.load`, and an observation meeting `R`
    (`Seq.start_sound_inv`).

  It covers kernels whose threads each run one path without a cycle to `ret`, with no call of a
  defined function and no collective call.
- **`Kernel.sound_eval`.** The same at one address choice and oracle, with the invariant
  `m = Kernel.mems g c paths k`. These are the memories the threads leave in turn, each along the
  first path that `Ret.check` (a Boolean `Ret`, with `Ret.of_check`) accepts (`Ret.pick`,
  `Ret.out`). Its premises are `Kernel.check` (every thread's picked path is accepted) and the
  last memory's trace and observation. The kernel evaluates these on a concrete launch, memory,
  choice and oracle.
- **`Kernel.sound_entry`.** `Kernel.sound_of_chains` with the start's facts derived: the invariant
  `I 0` holds of every memory with the caller's blocks and an empty trace, and each thread's
  premise is stated on every valuation `V` whose context has the program, the identity
  `⟨k, k / volume L.block⟩` and the special registers `L.env k`, whose function is the kernel,
  whose register of each parameter that is not `byval` and is named by no earlier parameter holds
  the argument as `withAttrs` gives it on every memory, and whose memory is one of `I k`
  (`Grid.start_thread`, `Grid.start_ctx`, `Grid.start_scalar`, `Grid.start_blocks`,
  `Grid.start_trace`). `mojo_kernel`'s `n.sound_loop` is it on `n.args`.
- **The `contract` forms.** `Kernel.sound_of_chainsAt` at `alloca := false`,
  `Kernel.sound_entryWith` and `Kernel.sound_cellsWith` are `Kernel.sound_of_chains`,
  `Kernel.sound_entry` and `Kernel.sound_cells` for every flag `contract`:
  `coversEntryWith contract` and `coversChainsWith contract` for the checks, and
  `RetWith contract` and `RetLsWith contract` for each thread's run, so the blocks may have
  `fmul contract` and `fadd contract`
  (`Runs.of_retWith`, `Runs.of_chainsWith`, MojoProof/Sym/Loop.lean). The three without the flag
  are their `false` cases, one line each (`RetLs` is `RetLsWith false` by definition).
  `Kernel.sound_entryWith` also indexes the invariant by the start's memory and gives each named
  `byval(t)` parameter's register a pointer to a block of the start's memory, owned by the
  thread, from which `t` loads as the argument (`Grid.start_buffer`), and the valuation's oracle.
- **The `alloca` form.** `Kernel.sound_of_chainsAt` is the `contract` form for both values of
  the flag `alloca`: `coversEntryAt alloca contract` and `coversChainsAt alloca
  contract` for the checks, and each thread's `RetWith contract` or `RetLsWith contract` to
  `Mem.Dead alloca m' (P (k + 1))`, the next predicate on the memory the thread leaves with its
  `alloca` blocks set dead (`Runs.of_retAt`, `Runs.of_chainsAt`, MojoProof/Sym/Loop.lean).
  `Mem.Dead false m' Q` is `Q` and `coversEntryWith contract` is `coversEntryAt false contract`
  by definition, so at `alloca := false` it is the `contract` form with each thread's predicate
  itself (the `example` after it), and `Kernel.sound_of_chains` is its case at both flags off, one
  line.
- **The elementwise invariant.** `Elem m₀ out w cell bs k m`: block `out` is `m₀`'s with the
  bytes of the first `k` threads put at their cells, other blocks are unchanged, and every access
  is owned.
  - `Elem.zero`, `Elem.succ` and `Elem.safe` give the invariant's first and last premises of
    `Kernel.sound_of_paths`. With `Apart` cells, `Elem.safe` shows the trace has no data race
    and keeps the promise of `!invariant.load` (`racy_kept_of_cells`).
  - Along a thread: `Elem.log` (an owned access), `Elem.skip` (a thread that puts nothing) and
    `Elem.store` (a thread's store of its bytes to its cell). For a block's effects:
    `Elem.apply_load` (a load outside `out`) and `Elem.apply_store`. `Elem.Steps` and `mojo_ret`
    (MojoProof/Sym/Ops.lean) chain these along a block's effects.
  - What a memory of `Elem` keeps from `m₀`: `Elem.load` (loads from other blocks),
    `Elem.put_fields` (the puts change only bytes), and `Elem.buffer` and `Elem.fits` (block `out`
    stays a `Mem.Buffer` that fits). `Elem.start_block`: a block of the caller's memory other than
    `out` is one of every memory of `Elem` from the start's memory.
  - `Mem.Buffer.of_block`, `Mem.Fits.of_block` and `Mem.Holds.of_block`: each reads only its
    block.
  - `Elem.Only out S m`: every access to block `out` on `m`'s trace is by a thread of `S`.
    `Elem.Only.log` and `Elem.Only.apply`: an access, and a block's effect, of a thread of `S`
    keep it. `Elem.safe_on`: with `Elem.Only` and the cells of the threads of `S` `Apart` (on the
    subtype of `S`; the others' cells may overlap them), the trace has no data race and keeps the
    promise of `!invariant.load`.
- **`Kernel.sound_cells`.** The kernel theorem of an elementwise kernel with loops: as
  `Kernel.sound_elem`, at every admission, with each thread either taking a path of `paths` that
  is a `Ret` or running a sequence of loops of `chains` to `ret` (`RetLs`), from every memory of
  `Elem` and `Elem.Only` after `k` threads to one after `k + 1`, and with the cells apart only on
  a set `S` of threads (the ones that access `out`). `Kernel.sound_of_chains` with the invariant
  `Elem` and `Elem.Only`. MojoProofTest/KernelCells.lean's `kernelC` is an instance on a launch of
  six threads where a thread that skips the store shares a cell with one that stores.
  `Kernel.sound_cellsWith` is its `contract` form; MojoProofTest/KernelContract.lean's `kernelF`
  is an instance at `contract = true` (through `Kernel.sound_mapNWith`), a loop with
  `fmul contract` and `fadd contract` on a launch of six threads, and its twin shows that the
  same proof at `false` fails.
- **`Kernel.sound_elem`.** `Kernel.sound_cells` with no loops, `S` all threads and one oracle.
  The kernel theorem of an elementwise kernel at every address choice
  and one oracle `ω`, for the observation of the blocks and `Elem.Out`. `Elem.Out` says block
  `out`, if the caller's memory has it, is the caller's with every thread's bytes put at its cell,
  and every other block of the caller's memory is unchanged. Its premises are the start on every
  choice, `Apart` cells, and each thread's `Ret` from every memory of `Elem k` to `Elem (k + 1)`
  (`Kernel.sound_of_paths` with the invariant `Elem`). `apart_mul` (MojoProof/Sem/Buffer.lean):
  cells `w i` are `w` apart (`apart_stride`), the `Apart` premise for cells of one stride.
  `Launch.apart_xy` (MojoProof/Sem/Index.lean): at every valid launch with side 1 in `z`, the 2-D
  cells `(row * s + col) * w` of the threads whose row (`Launch.index` in `x`) is below `m` and
  column (in `y`) below `n ≤ s` are `w` apart, the `Apart` premise on that set of threads
  (`Launch.cell_apart`).
- **`Kernel.sound_mapNWith`.** `Kernel.sound_cellsWith` for the family of kernels whose
  parameters are `ps ++` the parameters of a list `sc` of scalars, the one at each position `j`
  named `%j`. Every one of `ps` is `byval` of one struct type `T` with a codec for
  `.agg [.ptr p, z]`, and none of `sc`'s is `byval`; each scalar is a parameter, its argument and
  the value its attributes make of it on every memory (`withAttrs`). It is stated on the
  arguments `bl.map (fun a => .agg [.ptr ⟨a, 0⟩, z]) ++ sc.map (·.2.1)` for block numbers `bl`
  (one for each of `ps`) and a caller's memory whose output block `o` is owned by all threads, at
  every admission, with the cells apart on a set `S` of threads and the start facts derived. Its
  per-thread premise is a `RetWith contract` or a `RetLsWith contract` from every frame of `fn`
  whose `%i`, for each position `i` of `bl`, points to a block other than `o` holding the struct
  of `bl[i]`, and whose `%(n + j)` (`n` the length of `bl`) holds `sc[j]`'s value. It is required
  on every memory of `Elem k` and `Elem.Only` on which the caller's blocks other than `o` are
  unchanged (`Grid.start_buffer`, `Grid.start_scalar`, `take_names`, `Elem.start_block`,
  `Elem.load`). `take_names`: parameters named by their positions name no register twice.
  MojoProofTest/KernelContract.lean's `kernelF` is an instance with no struct and two scalars.
- **`Kernel.sound_mapN`.** `Kernel.sound_mapNWith` without `contract`, with no loops, one count
  `pc` of any type and width (`sc = [(pc, v, u)]`), `S` all threads and one oracle: the
  parameters are `ps ++ [pc]`, the arguments `bl.map (fun a => .agg [.ptr ⟨a, 0⟩, z]) ++ [v]`,
  and the per-thread premise a `Ret` to `Elem k + 1` from every frame whose `%n` holds `u`.
- **`Kernel.sound_map2`.** `Kernel.sound_mapN` for binary elementwise kernels: three structs
  (`bl = [a, b, o]`) and the `i32` count, on the arguments `Map2.args z a b o n` and a caller's
  memory of `Map2.Pre`. Its per-thread premise is a `Ret` from every frame of `fn` whose `%0` to
  `%2` point to blocks other than `o` holding the structs of `a`, `b`, `o` and whose `%3` is `n`.
  The `Ret` is required on every memory of `Elem k` with the buffers, tensors and `Mem.Fits` of
  `Map2.Pre` (the `of_block` lemmas, `Elem.buffer`, `Elem.fits`). `mojo_kernel`'s `map2` clause
  discharges these premises for one named kernel; no clause generates the per-thread premise
  for another shape of `Kernel.sound_mapNWith`.
- **`Kernel.sound_map2With`.** `Kernel.sound_map2` for each flag `contract`: the paths are
  checked by `coversEntryWith contract` and the per-thread premise is a `RetWith contract`, by
  `Kernel.sound_mapNWith` directly; `Kernel.sound_map2` is it at `false`. The `map2` clause with
  `contract` uses it at `true`, with each thread's `RetWith true` from mojo_ret's `Ret` by
  `RetWith.exists_true_of_ret` (MojoProof/Sym/RetFlag.lean: on paths none of whose summaries
  records an `fmul contract` product, `pathNoProds`, the flag changes no `RetWith`).
- **`Kernel.sound_mat`** (MojoProof/Sym/KernelMat.lean). `Kernel.sound_mapNWith` for matmul
  kernels, with or without `contract`: three structs (`bl = [o, a, b]`, the output first) and the
  `i32` words of `m`, `n` and `K`, on the arguments `Mat.args z o a b m n K`, at every launch
  valid with side 1 in `z`, with the 2-D cells `(row * sC + col) * w` apart on the threads in the
  window and the matrix (`Launch.apart_xy`) and every admission. Its memory premises are the
  fields of `Mat.Pre` but for `a ≠ b` and `K`'s bounds. Its two per-thread premises take the
  frame's registers `%0` to `%5`, the struct loads and the buffers of `Mat.Pre` on the thread's
  memory, as one structure `Mat.Entry`: a thread in bounds runs some sequence of loops to `ret`
  (`RetLsWith`), a thread out of bounds takes some path (`RetWith`). `mojo_kernel`'s `mat`
  clause generates its call for one named kernel, with the second premise discharged (`n.out`,
  through `RetWith.of_first`) and the first left open; MojoProofTest/NaiveSound.lean's
  `naive_sound` is its instance for the naive matmul kernel, through that call.
- **Buffers that fit.** `Mem.Fits l m c size` (MojoProof/Sem/Precond.lean): block `c`'s generic
  addresses up to `size` stay below `2 ^ w`. Each byte of a buffer that fits has an address with
  no wrap (`addr_buffer`, MojoProof/Sym/OblLemmas.lean). A `getelementptr inbounds` past the wrap is
  `poison`, so a kernel faults on a buffer that wraps; `Map2.Pre` requires its buffers to fit
  (field `fits`).
- **What a thread's frame holds at the start.** For every program, kernel, launch, arguments,
  memory, address choice and oracle:
  - `Grid.start_arg`: the register of parameter `i` of thread `k`'s frame holds what
    `launchArgs` made (`LaunchArg`, MojoProof/Sym/Start.lean).
  - `Grid.start_buffer`: take a `byval(T)` parameter whose argument is `enc x` for a codec `enc`
    of `T`. Its register points to a block of the start's memory, owned by thread `k`, from which
    `T` loads as `enc x` (`Mem.load_byval`).
  - `Grid.start_scalar`: any other parameter's register holds the value `withAttrs` gives on
    every memory.
- **Helpers.** `Valuation.after_mem` (the memory after a block).
- **The corollaries of a binary float map.** These hold for every kernel whose theorem is
  `Kernel.Sound` for `Elem.Out` with `Elem.map2`'s bytes. Those bytes are the encoding of
  `deliver (op x_k y_k) (o k)` for `k < n`; `Kernels.vadd.bytes`, `Kernels.vmul.bytes` and
  `Kernels.vsub.bytes` are `Elem.map2` at `Model.add`, `Model.mul` and `Model.sub`.
  - `Kernel.map2_min`: `Elem.Out` after `min n T` threads, so when `n ≤ T` every cell below `n`
    is written (`Elem.Out.min`). It weakens the relation by `Kernel.Sound.map`
    (MojoProof/Sem/Replay.lean).

  The other three are about every observation of a complete run (`Kernel.Obs`, of which
  `Kernel.Sound`'s relation holds, `Kernel.Sound.obs`), at the cell of every thread `k` below
  `n`, `N` and `T` (`Elem.word`, `Elem.Out.map2_word`):
  - `Kernel.map2_real`: a finite float there is `op x_k y_k`.
  - `Kernel.map2_finEq`: the observations at any two address choices and oracles hold floats
    equal up to `FinEq`.
  - With `FinEq.eq_of_isFinite`: a finite float there is the same in every observation.
- **Evaluation and canaries.** `Elem.outBelow` is `Elem.Out` as a closed Boolean on the blocks
  below `nb` and the offsets below `K`, which the kernel evaluates on a concrete final grid.
  `Elem.Out.outBelow`: `Elem.Out` passes it. `Elem.Out.of_outBelow` is the converse, for every
  memory and blocks. It holds when the memory has no block from `nb` on, every thread's bytes end
  by offset `K`, and every block of the memory agrees with the final block at its number from
  `K` on. `out_rev` (MojoProofTest/Kernel.lean) is an instance with every premise closed, and
  `out_rev_twin` shows that the last premise is needed. `Elem.Out.of_run`: on the blocks at the
  end of a run from the start, that last premise holds when every block of the caller's memory
  is owned by no thread and has at most `K` bytes (`Grid.start_reach_above`,
  MojoProof/Sem/Writes.lean); `out_run` (MojoProofTest/KernelXY.lean) is an instance on a run of
  `vector_addition`. `Elem.canaries` are the canaries
  (probes of the observation): five wrong outputs made from the right bytes by the probes of
  MojoProof/Sem/Replay.lean, one definition for every kernel. They are: cell 0 omitted, stale
  output, cells 0 and 1 swapped, zero output, and the first input copied.
  `Kernel.replay_canaries`: if the trace-replay checker reports each canary's violation on one
  run, the kernel is not sound for `Elem.Out` with any canary, for every admission that admits
  the run's address choice and oracle (`Kernel.replay_block`).

Tests in MojoProofTest/Kernel.lean. Each covers the launch and memory it names.

- **`kernel22`.** `vector_addition` on 2 blocks of 2 threads with count 3 on `mem0`, at one
  address choice and oracle, is sound for output cells 0 to 2 holding the FloatLib sums of the
  inputs. It is proved by `Kernel.sound_eval`, with every premise but the start's equation, the
  pointer bytes and the observation decided by the kernel.
- **Twins.**
  - `out_twin`: thread 0 does not take the out-of-range path, so the path is chosen per thread.
  - `entry_twin`: a path from `%21` passes `coversPathWith false` but not `coversEntry`.
  - `elem_twin`: cells that are not `Apart` meet `Elem` with a racy trace.
- **`phi_runs`.** `Runs.of_ret` on a path with a join: the naive matmul kernel's
  `%46 → %51 → %67 → %69`, whose edge into `%67` sets its `phi` (MojoProofTest/SymPhi.lean). It
  is decided a `Ret` by `Ret.check`, for one context, memory and frame; the thread stores the
  accumulator's value 1 to the output.
- **`elem22` and `elem1`** instantiate `Elem.zero`, `Elem.succ` and `Elem.safe`.
- **The kernel theorems with every premise discharged.**
  - `correct23`: `vadd.correct` on 2 blocks of 3 threads (`L23`, `valid23`) with count 5 and
    nonconstant inputs (`x5`, `y5`), on `Map2.mem` (`mem5`, `pre5` by `Map2.pre_mem`), at every
    address choice and oracle. Thread 5 is idle.
  - `correct12`: the same on one block of 2 threads (`Confluence.two`, `launch2 1 1 2 1`),
    fewer threads than the count 5. Only the cells of threads 0 and 1 are put, and cells 2 to 4
    keep `mem5`'s contents.
  - `correctV23`: `vmul.correct` on `L23` with inputs `x5`, `x5` (`memV`).
  - `correctS23`: `vsub.correct` on `L23` with inputs `x5`, `y5` (`mem5`, `pre5`).
- **The satisfiability witness `g2_vadd`.** `Grid.start` then `Grid.run` (fuel 64, one phase) on
  `L23` and `mem5`, at address choice `ch₀` and oracle `ω₀`, end in a done grid. Its blocks meet
  `Elem.outBelow` and its cells hold the sums of `x5` and `y5`, decided by the kernel
  (`evalRun_ok`). `correct23` gives `Elem.Out` for it.
- **Negative twins.** Each is a `¬ Kernel.Sound` for every observation, relation and admission
  that admits `ch₀` and `ω₀`, by the trace-replay checker (`Kernel.replay_unsafe`).
  - (a) `twin_len`: an output of 4 floats at count 5 (`mem4`, which meets every other field of
    `Map2.Pre`, `pre4_5`). The run faults (`run_len`).
  - (b) `twin_alias`: the output at the first input's block, which `Map2.Pre` refuses
    (`pre_alias`), on `mem5w` (that block writable). The run ends done with no race and the
    core's `GPUProof.kept` at `sig` false (`run_alias`).
  - (c) `twin_tid`: `fnTid` (statement 14 of the entry block adds 0 for `ctaid.x * ntid.x`,
    built from `Kernels.vadd.fn_0`'s AST). The run ends done with a race and its two accesses
    (`run_tid`).
  - (d) `twin_2d`: the four launches of `rows2`, valid, each with two rows in one of the grid's
    and the block's `y` and `z` (the block of 3 by 2 threads `launch2 1 1 3 2` is one) and so
    refused by one of `vadd.correct`'s hypotheses on the launch. The run races on each, so each
    hypothesis is needed.
- **The canaries `canaries_vadd`, `canaries_vmul` and `canaries_vsub`.** `Elem.canaries` of
  `correct23`'s, `correctV23`'s and `correctS23`'s bytes, each refuted
  (`Kernel.replay_canaries`, by the kernel).
- **The corollaries.** These hold for every launch, memory, address choice and oracle that
  `vadd.correct`, `vmul.correct` and `vsub.correct` cover. `vadd_min`, `vadd_real` (with
  TorchLean's `x + y` and the rounded real sum), `vadd_finEq`, `vadd_stable`, and the four
  `vmul_*` and the four `vsub_*`. `vmul_real` is about each cell: the product of the inputs'
  cells; `vsub_real` their difference.

Tests in MojoProofTest/KernelContract.lean and MojoProofTest/KernelXY.lean. Each covers the
launch, memory, address choice and oracle it names, except `not_apart_xy`, which holds for every
valid launch.

- **`kernelF`.** `Kernel.sound_mapNWith` at `contract = true` with every premise closed: `kf`,
  whose threads run three rounds of `%a = fadd contract (fmul contract %a, 2.0), 1.0` and store
  7.0 to their cells, on `L23` with `outF`, `ch₀` and the oracle `ω₁` (every `fadd contract`
  fuses). Its twin: the same proof at `contract = false` fails (`chainF_refused`: the checker
  without `fmul contract` refuses the loop).
- **`kernelK`.** `kfK.sound_loop` (`mojo_kernel` with the flag `contract`, so
  `Kernel.sound_entryWith` at `true`) with every premise closed: `kf` on `L23` with
  `kfK.args 3 outF.2`, `outF`, every address choice and the oracle `ω₁`, with the same
  postcondition (`Elem.Out` of 7.0 in each thread's cell). The clause's `pre` holds of every
  valuation with the start's facts of a thread and a memory of `memF` for that thread, so each
  admitted thread meets it; `kfK_retLs` is `kfK.loop` at thread 0.
- **`apart2x3`.** `Launch.apart_xy` on one block of 2 × 3 threads. Its twin `not_apart_xy`, for
  every valid launch: at a row stride below the column bound, two threads share a cell; tested
  on `L2x3` (`apart2x3_twin`) and on two blocks of 2 × 5 threads (`apart4x5_twin`).
- **`out_run`.** `Elem.Out.of_run` on one run of `vector_addition` (`mem5`, `ch₀`, `ω₀`).
