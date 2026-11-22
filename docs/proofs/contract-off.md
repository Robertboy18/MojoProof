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

**Corollary (`NaiveOff.correct`, MojoProofTest/NaiveOff.lean).** For the corpus kernel
`16826c8c` of the directory mgemm_nocontract, the naive matmul kernel compiled with contraction
off, at every oracle family `ω`, launch valid with `z` sides 1, sizes, blocks, tensors and memory of
`Mat.Pre` (the premises of `NaiveKernel.correct`): the kernel is sound for `Elem.Out` of the bytes
that put at every cell in bounds the binary32 encoding of `dotLoop false (o (ω k))` from `+0` over
its pairs, the unfused fold. It is `NaiveKernel.correct` at the rows `neverFuse (ω k)`, moved by
`Kernel.Sound.contractOff`, with `dotLoop_neverFuse` (MojoProof/Sem/Dot.lean): `dotLoop true` at
the numbers `3 * (n / 3)` is `dotLoop false` at the numbers `n`. By evaluation in the kernel
(`rfl`), the corpus program's module is `naive.prog.module.contractOff` (`module_eq`), its kernel
`naive.fn_0.contractOff` (`fn_eq`), and its layout and intrinsics are `naive`'s (`layout_eq`,
`intrinsics_eq`); by `decide +kernel`, `naive` and its kernel are of the fragment
(`naive_fbinOracle`, `fn_fbinOracle`).

**Corollary (`NaiveOff.matmul_nanEq`, `NaiveOff.matmul_error`).** For the same kernel, every
oracle family `ω`, launch valid with `z` sides 1, `K ≤ 768`, sizes, blocks, tensors and memory of
`Mat.Pre`: in every observation of a complete run under `ω`, every cell `(r, c)` in bounds and in
the launch's window holds the binary32 encoding of a word `v` that is `NaNEq` to entry `(r, c)`
of TorchLean's `Tensor.matmul` of the first `K` columns of `A` and the transpose of the first `K`
columns of `B`, with no premise on the oracle; when `v` is finite, it is within `dotBound` of the
real product on those columns. Every such observation is one of `naive` under the rows
`neverFuse (ω n)` (`NaiveOff.obs_contractOff`: the start by `Grid.start_contractOff`, the run by
`Grid.lockstep_contractOff` flipped), whose `fadd` numbers are multiples of 3 and fuse no round,
so `NaiveSound.naive_matmul` at `NaiveKernel.correct` applies with its premise met.

## Scope

The transport is proved for every program of the fragment `Program.fbinOracle` and every kernel of
`Func.fbinOracle`, in one direction: from `P` to the contraction-off program. The runs are moved
the other way (`NaiveOff.obs_contractOff`): a complete run of the contraction-off program is one
of `P`. The corollaries are for one program (the float32 naive kernel compiled with contraction
off), at every launch and memory of `Mat.Pre` and every oracle family.

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
6. `Kernel.Sound.contractOff`: an admitted `ω` gives the admitted rows `neverFuse (ω n)` for `P`,
   whose start is sound; 5 gives `Q`'s start and `CtxOff` (with `Grid.start_ctx`), and 4 its
   soundness.

## Instances and twins

- `NaiveOff.correct` (MojoProofTest/NaiveOff.lean), with `module_eq`, `fn_eq`, `layout_eq`,
  `intrinsics_eq`, `naive_fbinOracle` and `fn_fbinOracle`.
- `NaiveOff.matmul_nanEq` and `NaiveOff.matmul_error`, through `NaiveOff.obs_contractOff`.
- Twin of the fragment premise: the bfloat16 naive kernel of the corpus (`ba3789d9`) widens its
  words with `fpext`, whose result reads the whole oracle number, and fails `Program.fbinOracle`
  (`bf16_fbinOracle`).

## Not proved

- The converse (`Kernel.Sound` of the contraction-off program gives that of `P`).
- Programs outside the fragment: with `fpext`, `fptrunc`, `maxnum`, `minnum` or `rsqrt.approx`,
  `neverFuse` changes the numbers these read, and the transport does not apply.
- An instance of `NaiveOff.correct` at a concrete start: as for `NaiveKernel.correct`, the theorem
  is proved for every launch and memory of `Mat.Pre`, and `NaiveKernel.sound12`'s instance is not
  repeated for the contraction-off program.
