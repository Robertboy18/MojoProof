# A naive thread in bounds, for every launch (`NaiveIn.runIn`)

Lean: `MojoProofTest/NaiveIn.lean`. The statement `NaiveSpec.RunIn` is in
`MojoProofTest/NaiveSpec.lean`; the run of one thread is `NaiveThread.thread_run`
(docs/proofs/loop.md); the obligations are `OblMatmul.naive_entry`, `naive_rounds` and
`naive_exit`, proved by `mojo_obl` (docs/proofs/obl.md).

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

`thread_run` with `V := Valuation.entry c 0 m' f`, `ps := pairs A B ⟨row, _⟩ ⟨col, _⟩ K` (its
length is `K`, since `K ≤ 768`), `Q` the postcondition of `RunIn`, and `G := Head …`, a structure
on head valuations `W`:

- the program and function of `W` (`W.ctx.prog`, `W.fn`);
- the registers `%11`, `%12` (the pointers of `A` and `B`), `%16` (`smax(K, 0)`), `%26`, `%37`
  (row times 768, column times 768) and `%40` (the address of the thread's cell), and `%48`'s
  product (none: a `phi` sets it);
- on `W.mem`: `A`'s and `B`'s buffer, fit and contents, `C`'s buffer and fit, `Elem` after `k`
  threads and `Elem.Only`.

The four premises are four lemmas:

1. `entry_in` (`hE`): `naive_entry` at `At`'s fields gives the entry block's obligations and its
   branch to `%45`.
2. `head_in` (`h0`): one `obl_have` gives the registers after the edge `%45 → %46`: `%47 = 0`
   and `%48 = +0` (the `phi`'s integer and float constants) and the other registers, which the
   entry block's `Valuation.after` computes; the memory is the entry block's three loads
   (`Obl.memOf`), which add trace entries at blocks other than `bC`, so `Elem`, `Elem.Only` and
   the buffer facts carry over.
3. `round_in` (`hR`): `naive_rounds` gives `RoundWith true`; `%47 = j + 1` and the registers of
   `Head` come from `Obl.regOf`; `%48` after the round is `Valuation.intoWith_regs_phi` at the
   latch edge `%52 → %46`, whose operand `%66` is the latch's `fadd` node, evaluated with
   `SNode.eval_fbinP` on the latch's loads of pair `j` (`acc_round`); the two loads keep `Head`'s
   memory facts. One `obl_have` of 12 items gives the registers and the memory after the
   round, from `round_in`'s premises and the parts of `At`, `Head` and the invariant.
4. `exit_in` (`hX`): `naive_exit` gives the walk `%46 → %51 → %67 → %69`; `%69` returns; the
   memory at `%69` is that of `%67`'s store, and `Elem.apply_store` (the stored value is `%48`,
   `dotLoop` over all of `ps`, the pointer `%40` the thread's cell) and `Elem.Only.apply` give
   `Q`.

## Instances

`At` asks for buffers of the kernel theorem's size: `bC` of `m * 50257` cells, `bA` and `bB` of
`m * 768` and `n * 768` floats, `bA` and `bB` read-only. `NaiveThread`'s launch (`memN`) has
blocks of one and two floats and writable inputs, so `At` does not hold there and `thread0` is
not a corollary of `runIn`.

The closed application is `NaiveKernel.sound12`: `NaiveKernel.correct`, which applies `runIn` to
each thread in bounds, at `L12` (one block of 2 × 2 threads), `m = 1`, `n = 2`, `K = 768` and the
memory `mem12 A B` (`Mat.mem`, which meets `Mat.Pre` by `Mat.pre_mem`), for every `A`, `B` and
`ω`. Threads 0 and 2 are in bounds there (`NaiveKernel.in12`). It is symbolic: the proof does not
evaluate `Grid.start` on `mem12`.

`MojoProofTest/NaiveStart.lean` is an instance at an evaluated start of one block of 2 × 2
threads with `m = 1`, `n = 2`, a `C` block of 201,028 bytes and read-only `A` and `B`, for every
`A`, `B`, `K ≤ 768` and oracle: `At` at every thread (`at12`), and `runIn` at threads 0 and 2,
`runOut` at threads 1 and 3 (`runs12`). The start evaluates with its check of the caller's memory
rewritten by `Mem.checkClosed_of_closed`; with the check in place it does not reduce in the
kernel (see the bugs ledger).
