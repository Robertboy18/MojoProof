# A naive thread in bounds, for every launch (`NaiveIn.runIn`)

Lean: `MojoProofTest/NaiveIn.lean`. The statement `NaiveSpec.RunIn` is in
`MojoProofTest/NaiveSpec.lean`; the run of one thread is `NaiveSound.naive.runInv`, which the
`mat … inv` clause of `mojo_kernel` generates (docs/proofs/kernel.md); the obligations are
`OblMatmul.naive_rounds` and `naive_exit`, proved by `mojo_obl` (docs/proofs/obl.md).

**Scope.** Every oracle family `ω`, launch `L`, dimensions `m`, `n`, `K`, buffers `bC`, `bA`, `bB`,
matrices `A`, `B`, and every thread `k` in bounds with every context, memory and frame at which
`NaiveSpec.At` holds: all threads in bounds of every launch of the one program `naive`. Its
closed application is `NaiveKernel.sound12` (section "Instances"); `NaiveThread`'s launch is not
an instance.

## Statement

`runIn ω L K bC bA bB A B : NaiveSpec.RunIn ω L K bC bA bB A B`: a thread `k` in bounds, from the
entry valuation `Valuation.entry c 0 m' f` with `At` and `c.oracle = ω k`, whose memory meets
`Elem` after `k` threads and `Elem.Only`, runs `chainN` to `ret` with a memory that meets `Elem`
after `k + 1` threads (its cell holds `bytes ω L K A B k`) and `Elem.Only`.

## Proof plan

`naive.runInv` at the entry facts `At` and the invariant
`I j W := Inv (oN c 0) ps j W ∧ W.prods %48 = none`, with `ps := pairs A B ⟨row, _⟩ ⟨col, _⟩ K`
(its length is `K`, since `K ≤ 768`) and the postcondition of `RunIn`. The clause discharges the
entry block and its edge into the loop by `mojo_obl`, and proves `Mat.Head` at the head of every
round `W`, the `j`-th iterate of `NaiveThread.round` after `NaiveThread.head`: `W.fn`, on
`W.mem` `A`'s and `B`'s buffer, fit and contents and `C`'s buffer and fit, `Elem` after `k`
threads and `Elem.Only` (mojo_inv at the loop head, then `Mat.Head.iterate`: the round reads
memory only through `%11` and `%12`, which it keeps). The clause also gives the registers the
loop keeps at every head, `naive.kept`: `%11`, `%12` (the pointers of `A` and `B`), `%16`
(`smax(K, 0)`), `%26`, `%37` (row times 768, column times 768) with their values by `obl_have` at
the loop head, and `%40` (the address of the thread's cell) with its value at the loop head,
which `obl_have` gives there only as a `Classical.choose` from the clause's facts (it computes
the address with `At`'s bounds `m * 50257 < 2 ^ 31` and `n ≤ 50257`). The three premises (`LoopIterWith`, at the heads of the
rounds) are three lemmas:

1. `head_in` (`head`): `obl_have` gives `%47 = 0` and `%48 = +0` after the edge `%45 → %46`
   (the `phi`s' integer and float constants); `mojo_inv` gives `%48`'s `fmul contract` operands
   (none, `Obl.prodOf`).
2. `round_in` (`round`): `naive_rounds` gives `RoundWith true` from `naive.kept`'s registers and
   `Mat.Head`'s buffers. One `obl_have` gives `%47`, `%48` (the latch's `fadd contract` on the
   symbolic accumulator, by mojo_obl's evaluator, `SNode.eval_fbinP_ofFloat`) and the memory
   after the round, from one evaluation of the latch's nodes; `mojo_inv` gives `%48`'s operands
   after it (none). `NaiveThread.round_inv` gives `Inv` after the round from it.
3. `exit_in` (`exit`): `naive_exit` gives the walk `%46 → %51 → %67 → %69` from `naive.kept`'s
   `%16` and `%40` (its value at the loop head by `mojo_inv` with `At`'s bounds) and `Mat.Head`'s
   buffer of `C`; `%69` returns. `mojo_inv`'s store rule gives `Elem`
   after one more thread and `Elem.Only` on the memory of `%67`'s store (`Elem.apply_store`,
   `Elem.Only.apply`) from `Mat.Head`'s `Elem` and `Elem.Only` and the encoding of `%48`
   (`NaiveSpec.bytes`): the stored value is `dotLoop` over all of `ps`, at the thread's cell.

The thirteen facts at a loop head that the invariant used to carry in one structure are now
`Mat.Head`'s, which the clause proves at every head, and `naive.kept`'s registers; the structure
and its round lemma in `MojoProofTest/LoopFacts.lean` are deleted.

## Instances

`At` asks for buffers of the kernel theorem's size: `bC` of `m * 50257` cells, `bA` and `bB` of
`m * 768` and `n * 768` floats, `bA` and `bB` read-only. `NaiveThread`'s launch (`memN`) has
blocks of one and two floats and writable inputs, so `At` does not hold there and `thread0` is
not a corollary of `runIn`.

The closed application is `NaiveKernel.sound12`: `NaiveKernel.correct`, which applies `runIn` to
each thread in bounds (`runIn` is the `mat … inv` clause's `naive.runInv` at `head_in`,
`round_in` with `NaiveThread.round_inv`, and `exit_in`, the last two with `naive.kept`), at `L12` (one block of 2 × 2 threads), `m = 1`, `n = 2`, `K = 768` and
the memory `mem12 A B` (`Mat.mem`, which meets `Mat.Pre` by `Mat.pre_mem`), for every `A`, `B`
and `ω`. Threads 0 and 2 are in bounds there (`NaiveKernel.in12`). It is symbolic: the proof does not
evaluate `Grid.start` on `mem12`.

`MojoProofTest/NaiveStart.lean` is an instance at an evaluated start of one block of 2 × 2
threads with `m = 1`, `n = 2`, a `C` block of 201,028 bytes and read-only `A` and `B`, for every
`A`, `B`, `K ≤ 768` and oracle: `At` at every thread (`at12`), and `runIn` at threads 0 and 2,
`runOut` at threads 1 and 3 (`runs12`). The start evaluates in the kernel with its check of the
caller's memory in place, for every `K` (`start12`); `trace12` is `Grid.start_trace`, for every
`K`, and `facts12` rewrites the check by `Mem.checkClosed_of_closed`, so that the kernel does not
read every byte again for each. At `K = 768`, `correct` at this start is `NaiveKernel.sound12`;
`obs12` gives it a complete run at every address choice and oracle (`Grid.Sound.result`), and
`cells12` is `read12` at that run, its premise discharged. `soundOff12` and `obsOff12` are their
counterparts for the contraction-off build.
