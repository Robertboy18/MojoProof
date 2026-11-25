# A program with contraction off runs as the program under a never-fusing oracle

## Statement

`Module.contractOff` is a module with the `contract` flag removed from every float binary operation
(`fadd`, `fsub`, `fmul`, `fdiv`, `frem`) of every function; nothing else changes (calls, `fneg`,
`fcmp` and their flags are kept). `Func.contractOff` does the same to one function. `neverFuse o`
is the oracle row whose number at position `p` is `3 * (o p / 3)`: the same NaN choice (`floatBin`
delivers at `n / 3`) and the remainder 0, at which `contract` never fuses.

**Theorem (`Kernel.Sound.contractOff`, MojoProof/Sem/ContractOff.lean).** For every program `P`
whose only statements that read an oracle number are float binary operations
(`Program.fbinOracle`: no `fpext` or `fptrunc` instruction in any function, and no `maxnum`,
`minnum` or `rsqrt.approx` intrinsic), every kernel `fn` with no `fpext` or `fptrunc` instruction
(`Func.fbinOracle`), every program `Q` with the module `P.module.contractOff`, the layout of `P`
and the intrinsics of `P` (the digest and the kernel names may differ), every launch, argument
values, memory, admissibility `adm`, observation and relation `R`:

    Kernel.Sound P fn L args m adm obs R →
      Kernel.Sound Q fn.contractOff L args m (fun ch ω => adm ch fun n => neverFuse (ω n)) obs R

So every run of the contraction-off kernel under the oracle family `ω` is, step for step, a run of
`fn` in `P` under the rows `neverFuse (ω n)`, with the same memory at every step: the same faults,
trace, races and final memory, hence the same observation.

**Theorem (`Kernel.Sound.contractOff_iff`, the converse).** For the same `P`, `fn`, `Q`, launch,
arguments, memory, admissibility `adm`, observation and relation `R`:

    Kernel.Sound Q fn.contractOff L args m adm obs R ↔
      Kernel.Sound P fn L args m (fun ch ω' => ∃ ω, adm ch ω ∧ ω' = fun n => neverFuse (ω n)) obs R

The contraction-off kernel is sound for `adm` exactly when `fn` is sound at the never-fusing rows
of the families `adm` admits. The right-to-left direction is `Kernel.Sound.contractOff` (an
admitted `ω` gives its own rows); left to right, every run of `P` under the rows `neverFuse (ω n)`
is, mapped, a run of `Q` under `ω`.

**Theorem (`Kernel.Obs.contractOff_iff`, MojoProof/Sym/ContractOff.lean).** For the same `P`,
`fn`, `Q`, launch, arguments, memory, observation, address choices `ch` and oracle family `ω`, and
every value `y`: `y` is the observation of a complete run (`Kernel.Obs`) of `fn.contractOff` in
`Q` under `ω` exactly when it is one of `fn` in `P` under the rows `neverFuse (ω n)`.
`Kernel.Obs.contractOff` is its left-to-right direction.

**Corollary at every row stride (`NaiveOff.soundF`, MojoProofTest/NaiveOff.lean).** For every
row strides `sA`, `sB`, `sC` of the naive family (`NaiveFam.prog sA sB sC`,
MojoProofTest/Family.lean), every program `Q` and kernel `F` that are the family's compiled with
contraction off (`Q`'s module is `(NaiveFam.prog sA sB sC).module.contractOff`, its layout and
intrinsics are the family's, and `F` is `(NaiveFam.fn sA sB sC).contractOff`), every oracle
family `ω`, launch valid with `z` sides 1, sizes `m`, `n`, `K` below `2 ^ 31`, blocks, tensors
`A` (`m × sA`), `B` (`n × sB`) and memory of `Mat.Pre` at those strides (the premises of
`NaiveFam.sound`): `F` in `Q` is sound for `Elem.Out` of the family's bytes at the rows
`neverFuse (ω k)`, at the cells `NaiveFam.cell sC`. It is `NaiveFam.sound` at those rows, moved by
`Kernel.Sound.contractOff`. The family's program and kernel are of the fragment at every stride
(`progF_fbinOracle`, `fnF_fbinOracle`), by the kernel's evaluation under the binders
(`kernel_rfl`): the strides are the constants of three `mul` instructions, which the check does
not read. By `dotLoop_neverFuse` (MojoProof/Sem/Dot.lean: `dotLoop true` at the numbers
`3 * (n / 3)` is `dotLoop false` at the numbers `n`), those bytes put at every cell in bounds the
binary32 encoding of `dotLoop false (o (ω k))` from `+0` over its pairs, the unfused fold
(`bytes_neverFuseF`).

**Corollary at every row stride (`NaiveOff.matmul_nanEqF`, `NaiveOff.matmul_errorF`).** For the
same strides, `Q`, `F`, oracle family `ω`, launch, sizes, `K ≤ sA`, `K ≤ sB`, blocks, tensors and
memory: in every observation of a complete run of `F` in `Q` under `ω`, every cell `(r, c)` in
bounds and in the launch's window holds, at offset `(r * sC + c) * 4`, the binary32 encoding of a
word `v` that is `NaNEq` to entry `(r, c)` of TorchLean's `Tensor.matmul` of the first `K`
columns of `A` and the transpose of the first `K` columns of `B`, with no premise on the oracle;
when `v` is finite, it is within `dotBound` of the real product on those columns. Every such
observation is one of `NaiveFam.fn sA sB sC` under the rows `neverFuse (ω n)`
(`Kernel.Obs.contractOff`), whose `fadd` numbers are multiples of 3 and fuse no round, so
`NaiveFam.matmul_nanEq` and `NaiveFam.matmul_error` at those rows apply, the first with its
premise met.

**The corpus kernel (`NaiveOff.correct`, `NaiveOff.bytes_neverFuse`, `NaiveOff.matmul_nanEq`,
`NaiveOff.matmul_error`).** The corpus kernel `16826c8c` of the directory mgemm_nocontract is the
family's at `768`, `768`, `50257` compiled with contraction off (`corpus_off`): by evaluation in
the kernel (`rfl`), its module is `naive.prog.module.contractOff` (`module_eq`), its kernel
`naive.fn_0.contractOff` (`fn_eq`), and its layout and intrinsics are `naive`'s (`layout_eq`,
`intrinsics_eq`), `naive` being the family's at those strides (`NaiveFam.prog_corpus`). Each of
the four is the corollary above at those strides, at every oracle family, launch valid with `z`
sides 1, sizes, blocks, tensors and memory of `Mat.Pre` (the premises of `NaiveKernel.correct`,
whose bounds give the sizes below `2 ^ 31`, `NaiveSpec.dims_lt`), `K ≤ 768` for the last two;
`correct_unfused` is `NaiveOff.correct` with the bytes of `bytes_neverFuse`. By
`decide +kernel`, `naive` and its kernel are of the fragment (`naive_fbinOracle`,
`fn_fbinOracle`).

## Scope

The transport is proved for every program of the fragment `Program.fbinOracle` and every kernel of
`Func.fbinOracle`, in both directions: `Kernel.Sound` and the observations of complete runs move
from `P` to the contraction-off program and back, at the never-fusing rows. The converse holds
exactly at the image of `neverFuse`: by `Kernel.Obs.contractOff_iff`, the observations of `Q`
under `ω` are those of `P` under the rows `neverFuse (ω n)`. At a family with a fusing number it
fails: the twin `ContractOff.twin` (one program pair, one start) has an observation of `P` under
such a family that no complete run of `Q` under it has. The corollaries `soundF`, `bytes_neverFuseF`,
`matmul_nanEqF` and `matmul_errorF` are for every program and kernel that are the naive family's
at some row strides compiled with contraction off, at every launch valid with `z` sides 1, memory
of `Mat.Pre` at those strides with sizes below `2 ^ 31` and every oracle family; the corpus has one
such program, at `768`, `768`, `50257` (`NaiveOff.correct` and the others). `matmul_nanEqF` and
`matmul_errorF` and their instances cover the cells in the launch's window.

## The choice of the oracle

The oracle number at position `Nat.pair k i` of a thread is read by the statement the thread runs
at its step `k`, and statements read it in different ways: `floatBin` takes the NaN choice
`n / 3` and the fusion choice `n % 3`; `floatCast` (`fpext`, `fptrunc`) and `rsqrt.approx` take
the whole number, `maxnum` and `minnum` take `n % 2` and `n / 2`. Three ways to name the oracle of
`P`:

- (a) Change `ω` only at the positions of flagged `fadd` and `fsub` steps. Which statement a thread
  runs at step `k` depends on the run (loads, branches), so this oracle is a classical choice
  over runs, and the step positions of every corollary would have to be proved again.
- (b) Change every number the same way, `3 * (n / 3)`, and ask of `P` that its only oracle readers
  are float binary operations. The premise is a decidable property of the program's text: the
  naive kernel meets it by `decide +kernel`.
- (c) Relate the two runs' oracles statement by statement, inside the simulation: this is (a)
  stated as a relation, with the same dependence on the run.

The proof takes (b): one oracle family for every run and schedule, a premise checked by
evaluation, and an oracle whose fold for the naive kernel is a closed term (`dotLoop_neverFuse`).
No number `3 * (n / 3)` fuses, whatever the recorded factors (`floatBin_neverFuse`), so the factor
record `prods` that `fmul contract` keeps in `P`'s frames is never read; `Frame.contractOff`
clears it, and the contraction-off program records none.

## Proof

1. The operation (`floatBin_contractOff`, with `floatBin_neverFuse`): for every float type,
   operator, flags, words, factors and oracle number `n`, `floatBin` with `fm.contract` removed at
   `n` is `floatBin` with `fm` at `3 * (n / 3)`, whatever the factors on either side.
2. The statement (`exec_contractOff`): for every statement of the fragment and every frame, `exec`
   in a context of `Q` with oracle row `o` on the frame mapped by `Frame.contractOff` (the flags of
   its function removed, no factors) gives the effect, mapped by `Eff.contractOff`, of `exec` in
   the context of `P` with the scope's numbers `3 * (ch i / 3)`. Operands read no oracle number
   (`evalV_ch`, `evalTV_ch`, `evalTVs_ch`); casts other than `fpext` and `fptrunc` read none; the
   intrinsics left by `IntrinsicsOff` read none (`intrinsic_contractOff`); calls are
   `exec_contractOff_call` with its cases `exec_contractOff_found` (a defined function, or a
   declaration that is no intrinsic) and `exec_contractOff_intrinsic`; removing the flags keeps
   every function's name, parameters, attributes, check (`Func.contractOff_check`), blocks'
   labels, results, operands and terminators.
3. The step (`step_contractOff`): one thread step of a thread whose frames' functions are of the
   fragment, under row `neverFuse o` in a context of `P`, is the step of the thread mapped by
   `Thread.contractOff` in the context of `Q` with row `o`, its result mapped by
   `Step.contractOff`. It adds the block entered and its `phi`s (`enter_contractOff`, with
   `Block.contractOff_takeWhile`), calls and returns (`step_contractOff_inst`,
   `step_contractOff_term`).
4. The grid (`Grid.lockstep_contractOff`): for context families related by `CtxOff` (the contexts
   of `P` with rows `neverFuse (ω n)` and those of `Q` with rows `ω n`), the relation "the second
   grid is the first mapped by `Grid.contractOff`, and the first's frames are of the fragment
   (`Grid.FbinOracle`)" is a lockstep bisimulation (`Grid.Lockstep`). A thread's step is 3
   (`Grid.advance_contractOff`), and it keeps the fragment, since a step's new frames are of module
   functions (`step_fbinOracle`, `Grid.advance_fbinOracle`, `Grid.fire_fbinOracle`). A collective
   call keeps the participants' positions and arguments, and resuming commutes with the map
   (`Grid.fire_contractOff`, `resumeAll_contractOff`, `Thread.resume_contractOff`). The end, the
   trace and the pending accesses are kept (`Grid.done_contractOff`,
   `Grid.raceEnabled_contractOff`, `Thread.pending_contractOff`). So `Grid.Lockstep.sound` moves
   `Grid.Sound` across (`Grid.Sound.contractOff`), for every observation of the memory.
5. The start (`Grid.start_contractOff`): `Grid.start` of `Q` with `fn.contractOff` under `ω` and
   that of `P` with `fn` under the rows `neverFuse (ω n)` both fail, or both succeed, the first
   with the second's grid mapped and its contexts with program `Q` and rows `ω n`
   (`Thread.start_contractOff`). The start grid of a kernel of the fragment meets
   `Grid.FbinOracle` (`Grid.start_fbinOracle`).
6. The start with the contexts (`Grid.start_ctxOff`): 5 with the start grid of `P` in the
   fragment (`Grid.start_fbinOracle`) and the two context families related by `CtxOff`
   (`Grid.start_ctx`): the two starts are related by the lockstep relation of 4.
   `Except.Rel.ok_left` and `Except.Rel.ok_right` take one side's success to the other's.
7. `Kernel.Sound.contractOff`: an admitted `ω` gives the admitted rows `neverFuse (ω n)` for `P`,
   whose start is sound; 6 gives `Q`'s start and `CtxOff`, and 4 its soundness.
8. The converse (`Kernel.Sound.contractOff_iff`): an oracle family of the right side is
   `neverFuse (ω n)` for an `ω` that `adm` admits, at which `Q`'s start is sound; 6 gives `P`'s
   start, related to it, and 4 flipped (`Grid.Lockstep.symm`) moves `Grid.Sound` back.
9. The observations (`Kernel.Obs.contractOff_iff`): 6 relates the two starts whichever succeeds;
   `Grid.Lockstep.reach` (or its flip) takes a run of one to a run of the other ending in the
   related grid, which is done exactly when the first is (`Grid.done_contractOff`) and has the same
   memory.

## Instances and twins

- `NaiveOff.correct` and `NaiveOff.correct_unfused` (MojoProofTest/NaiveOff.lean), with
  `module_eq`, `fn_eq`, `layout_eq`, `intrinsics_eq`, `naive_fbinOracle`, `fn_fbinOracle` and
  `bytes_neverFuse`.
- `NaiveOff.matmul_nanEq` and `NaiveOff.matmul_error`, through `Kernel.Obs.contractOff`.
- `NaiveStart.soundOff12` and `NaiveStart.obsOff12` (MojoProofTest/NaiveStart.lean):
  `NaiveOff.correct` at the concrete launch and memory of `NaiveKernel.sound12` (one block of
  2 × 2 threads, `m = 1`, `n = 2`, `K = 768`, `mem12 A B` for every `A` and `B`, `Mat.Pre` by
  `NaiveKernel.pre12`), and an observation of it at every address choice and oracle family
  (`Kernel.Sound.exists_obs`, by `Grid.Sound.result`).
- Twin of the fragment premise: the bfloat16 naive kernel of the corpus (`ba3789d9`) widens its
  words with `fpext`, whose result reads the whole oracle number, and fails `Program.fbinOracle`
  (`bf16_fbinOracle`).
- Twin of the converse at a fusing family (`ContractOff.twin`, MojoProofTest/ContractOff.lean, a
  test of one example). The kernel `fmaK` stores `%1 = fmul contract float 1 + 2^-23, 1 - 2^-23`,
  `%2 = fadd contract float %1, -1.0` to a buffer of 4 bytes; its program `fmaP` is of the fragment
  and `fmaQ` has its module with the flags removed (both by evaluation). On `Launch.one`, at the
  address choice 0 and the family with every number 1 (each flagged `fadd` fuses with its first
  operand's product), observed by the buffer's 4 bytes: a complete run of `fmaK` observes the
  binary32 word `-2^-46` (`0xa8800000`, the product and the sum rounded once); `fmaK.contractOff`
  is sound for the word `+0` (the product rounds to 1.0), by `Grid.start_sound` from one evaluated
  run, so none of its complete runs observes `-2^-46`, and `fmaK` is not sound for the same
  admission and relation. The family is `neverFuse (ω n)` for no `ω`, so the admission of
  `Kernel.Sound.contractOff`'s conclusion at this admission is empty, the contraction-off kernel
  is sound for it with nothing to check, and the converse in that form fails here too. At the rows
  `neverFuse` of the family (every number 0) `fmaK` observes `+0` and never `-2^-46`, by
  `Kernel.Obs.contractOff_iff`. The words are evaluated through FloatLib in the kernel (`rfl`,
  `decide +kernel`).

## Not proved

- The converse at every admissibility is false, not only unproved: `Kernel.Sound` of the
  contraction-off kernel for `adm`, or for `fun ch ω => adm ch fun n => neverFuse (ω n)` (the
  conclusion of `Kernel.Sound.contractOff`), does not give `Kernel.Sound` of `fn` for `adm` when
  `adm` admits a family with a fusing row. Under such a row a flagged `fadd` of `P` rounds the
  product and the sum once, the contraction-off program rounds each, and the run of `P` is no run
  of `Q`; the twin `ContractOff.twin` shows both forms at one start (the second with an empty
  admission, since its family is `neverFuse (ω n)` for no `ω`). Which programs and fusing
  families keep the observations (a program whose flagged `fadd`s have no recorded product, or
  whose fused and unfused results agree) is not characterized.
- Programs outside the fragment: with `fpext`, `fptrunc`, `maxnum`, `minnum` or `rsqrt.approx`,
  `neverFuse` changes the numbers these read, and the transport does not apply.
