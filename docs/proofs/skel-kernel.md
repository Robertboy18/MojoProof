# The kernel theorem from one run per address choice (`Kernel.skel_sound`, `Kernel.Sound.of_blocks`)

Lean: MojoProof/Sem/SkelStep.lean, section "The kernel theorem". Instances and twins:
MojoProofTest/SkelKernel.lean, MojoProofTest/SkelVadd.lean and MojoProofTest/SkelVadd23.lean. The
statements hold for every program, kernel, launch, arguments, labelling, payload blocks, memories
and set of address choices that meet their premises.

## Where it sits

`Grid.skel_six` (payload.md, "The six-field lemma") turns one run on a first memory `m₁` at one
address choice into the six fields of `Grid.Sound`, with the blocks as observation, for every
memory `m₂` related to `m₁` by `Mem.SkelEq pay` and every oracle. Its proof is one use of
`Grid.sound_of_one_run` (adapter.md), through `Grid.skel_run`. `Kernel.Sound`
(MojoProof/Sem/Spec.lean) asks for a start and `Grid.Sound` at every admitted pair of an address
choice and an oracle.
`Grid.Sound` speaks of every grid reachable from the start, so of every schedule: every order in
which `Grid.Step` advances threads and fires collective calls. The two theorems below state what
`Grid.skel_six` gives at the level of `Kernel.Sound`, and how the seventh field is added there.

## Statements

1. `Kernel.skel_sound`. Premises: `Labels.Ok prog lab = true`; `fn` is the module's function of
   its name; `m₁.BytesIn m₁.Known` (the pointer bytes of the first memory name blocks it has); a
   set `A` of address choices such that for every `ch` in `A` there are an oracle `o₁`, a start
   `Grid.start prog fn L args m₁ ch o₁ = .ok (g₁, c₁)` with `lab.MemOk pay L c₁ g₁`, and one run
   `ReflTransGen (Grid.Step L c₁) g₁ z₁` to a grid `z₁` in which every thread has returned
   (`GPUProof.Done sig (z₁, L, c₁)`) and that is not bad (`¬ GPUProof.Bad sig (z₁, L, c₁)`: no
   thread faults, no race is enabled, its trace has no data race and keeps the promise of
   `!invariant.load`); and `m₁.SkelEq pay m₂`.
   Conclusion: `Kernel.Sound prog fn L args m₂ (fun ch _ => A ch) (fun m => some m.blocks)
   (fun _ => True)`: at every address choice in `A` and every oracle, the launch on `m₂` starts,
   and its grid is safe, race free, keeps the promise of `!invariant.load`, makes progress,
   terminates and is determinate for the blocks, under every schedule. With `A = (· = ch)` this is
   one run at one address choice; `o₁` may depend on `ch`.
2. `Kernel.Sound.of_blocks`. For every program, kernel, launch, arguments, memory `m`, admission
   `adm`, observation `obs` that reads only the blocks (`m.blocks = m'.blocks → obs m = obs m'`)
   and relation `R`: if the kernel is sound for `adm`, the blocks and `fun _ => True`, and for every
   admitted `(ch, o)` the start's grid reaches one grid in which every thread has returned and whose
   observation is some `y` with `R y`, then `Kernel.Sound prog fn L args m adm obs R`.

## Proofs

1. For an admitted `ch` and any oracle `o₂`, take `o₁`, the start, `Labels.MemOk` and the run that
   the premise gives at `ch`, and apply `Grid.skel_six` at `m₂` and `o₂`.
2. For an admitted `(ch, o)`, the start and `Grid.Sound` for the blocks come from the first
   premise, one final grid from the second, and `Grid.Sound.of_blocks` gives `Grid.Sound` for
   `obs` and `R`: every final grid has the blocks of the given one (`determinate`), so the same
   observation.

## Scope

- Neither theorem proves a premise. For a kernel, its proof must still give `Labels.Ok` and the
  lookup (by evaluation), `BytesIn` of the first memory, `Labels.MemOk` at each admitted address
  choice (that the pointer of every payload load and store points into a payload block at every
  reachable grid; it is not derived from the block checker's access terms), and one run at each
  admitted address choice to a grid that is done and not bad. For the seventh field it must give,
  at every admitted address choice and oracle on `m₂`, one final grid whose observation meets `R`;
  the output term of a whole kernel from its block summaries is not stated in Lean (payload.md).
- `MojoProof.Kernels.vadd.correct` does not use these theorems; its proof is by
  `Kernel.sound_map2`, from one covered path per thread (kernel.md).
- The admission of `Kernel.skel_sound` constrains the address choice only: every oracle is
  admitted.
- Instances (MojoProofTest/SkelKernel.lean) on `kF` of MojoProofTest/PayloadRun.lean (load a
  float, `fadd`, store): soundness at address choice 0 for every word in the payload block and
  every oracle, from the one run on 1.0 with oracle 0 (`kernel_six_inst`); the seventh field at
  1.0 and oracle 0 for bytes 0 to 3 of the block (`kernel_sum_inst`). The twin of
  `Mem.SkelEq`: the launch on the read-only copy of the memory is not sound (`kernel_six_twin`).
- Instances (MojoProofTest/SkelVadd.lean) on `vector_addition` (`Kernels.vadd`), with every
  premise closed by evaluation: launched on one thread (`Launch.one`) with buffers at blocks 1, 2,
  3 and count 5 on the memory `mem5` of MojoProofTest/Kernel.lean, labelling `%25`, `%27` and
  `%28` payload and blocks 1 to 3 payload. `Labels.Ok` by `rfl` (`vadd_ok`); `BytesIn` from
  `mem5`'s `Mem.Closed`; `Labels.MemOk` by a Boolean form of `Labels.MemAll` (`memAllB`, sound by
  `memAllB_sound`) checked by the kernel on every grid reachable from the start
  (`ScheduleOwned.every`, `memOk_of_every`); the run by `Grid.run` evaluated by the kernel, with
  `Grid.run_reach` and `Grid.run_done`. `skel_vadd`: for every memory related to `mem5` by
  `Mem.SkelEq` (every data byte of the inputs), soundness at address choice `ch₀` and every
  oracle; `out_vadd`: at `mem5`, `ch₀` and oracle `ω₀`, the seventh field for the blocks and a
  bounded check of `Elem.Out` at one thread with output cell 0 holding 33; `elem_vadd`: at the
  same memory, `ch₀` and `ω₀`, the seventh field for the blocks and `Elem.Out` itself at one
  thread, from the same run. The bounded check (`Elem.outBelow`, the blocks below 4 at the offsets
  below 24) gives every field and the bytes below 24; `Grid.start_reach_above`
  (MojoProof/Sem/Writes.lean) gives the bytes from each block's size on, as `mem5`'s blocks are
  of every thread (`above_vadd`); `mem5`'s blocks are below 4 and of at most 20 bytes, and thread
  0's 4 bytes are put at offset 0 (`mem5_blocks`, and `out_of_outV` by `Elem.Out.of_outBelow`).
  `every` explores every interleaving, so this route closes `Labels.MemOk` by evaluation only for
  a launch of one thread (the counts in the last section; at six threads, `skel_vadd23` takes the
  thread-modular route of that section); `Kernels.vadd.correct` covers every valid one-dimensional
  launch and every address choice, on the memories of `Map2.Pre` (`correct_one` states it at the
  same launch).

## `Labels.MemOk` at more threads: counts and the route

`memCheck` closes `Labels.MemOk` with `every`, which checks one grid per schedule prefix. Counted
on `vector_addition` from the start of MojoProofTest/SkelVadd.lean (blocks 1, 2, 3, count 5,
`mem5`, `ch₀`, `ω₀`), by a breadth-first search over `succs` evaluated with `#eval` (not in the
repository) that merges grids agreeing on every thread's status, step count and frames (label,
statement number, registers 0 to 63), the memory's next block number and bytes 0 to 23 of blocks
1 to 3, and counts the schedule prefixes with multiplicities:

- 1 thread (28 steps): 29 prefixes, 29 merged grids, 0.03 s.
- 2 threads in one block (28 steps each): 3.0e16 prefixes (C(56, 28) = 7.6e15 complete
  schedules), 841 = 29² merged grids, 1.7 s.
- 3 threads in one block: 3.9e38 prefixes, 24389 = 29³ merged grids, 111 s.
- `L23`, the launch of `g2_vadd` (2 blocks of 3 threads; threads 0 to 4 take 28 steps, thread 5,
  past the count, 19): stopped at depth 18 after 1059 s, with 134596 merged grids, C(24, 6), the
  count of every split of at most 18 steps among six threads. In full, by the same count:
  2.7e118 prefixes and 29⁵ · 20 = 410222980 merged grids, 8.1e6 at the widest depths (79 and 80).
  The search took 9 ms a grid at depth 18, more at each depth (the trace grows), so the merged
  check would take at least 43 days of `#eval`; `decide +kernel` evaluates more slowly than
  `#eval`.

The search's peak resident memory was 4.8 GB. At every launch measured, the merged grids are
exactly the vectors of per-thread step counts, `∏ (nᵢ + 1)`: the threads write disjoint cells, so
how far each thread has run fixes every part of the grid that the merging compares, and no merging
that tells the threads' step counts apart does better. Merging also needs a proof that grids it
merges have the same successors up to merging and the same `Labels.MemAll`, which `every_sound`
does not give.

So neither `every` nor a merging `every` closes `Labels.MemOk` at `L23` by evaluation. The route
is a thread-modular lemma: `Labels.MemAll` asks, of each running thread, only
`Labels.MemAt` at its own next statement in its own scope (`Labels.MemNext`). For a kernel without
barriers or shuffles whose skeleton loads read only bytes that no thread writes (for
`vector_addition`, the `byval` argument structs), each running thread of a reachable grid has the
frames of a grid on its own run with the other threads not moving, so `Labels.MemOk.of_closed`,
with the set of grids in which every running thread is at a point of its own run, gives
`Labels.MemOk` from one run of each thread (6 runs of at most 29 grids at `L23`). The proof
obligation is that set's closure under a step of another thread, which changes only that
thread's frames and the bytes of its stores.

The lemma is `Labels.MemOk.of_threads` (MojoProof/Sem/Labels.lean), for every labelling, payload
blocks, launch, contexts and start grid. Its premises are a property `I` of memories and a property
`R n s` of thread `n`'s status `s` that no waiting status has, both true at the start grid; a step
of a running thread `n` from a grid whose memory has `I` and whose statuses have `R` gives a grid
whose memory has `I` and in which `n`'s status has `R`; and each running thread of such a grid
meets `Labels.MemNext` in that grid's memory. The proof is `Labels.MemOk.of_closed` on the grids
whose memory has `I` and whose statuses have `R`: a step of `n` sets only `n`'s status
(`Grid.advance_set`), and no collective call completes, as a call completes only at a waiting
thread (`Grid.fire_trace`). Its instance, `store3_ok` (MojoProofTest/Labels.lean): three threads
that each store the payload register to block 1 meet `Labels.MemOk` with block 1 payload, with `I`
true of every memory and `R n` the three statuses of thread `n` on its own; with no block payload
they do not.

At `L23` the lemma needs `R n` to be "a status of thread `n`'s solo run, or returned", which no
waiting status has as `vector_addition` has no barrier or shuffle, and `I` to be "the bytes that
the skeleton loads read, the `byval` argument structs, are as at the start, and every block has
its start shape". The step premise is then `step_agree` (MojoProof/Sem/Frame.lean) from the
memory of the solo run to the memory reached: they agree at the pending reads of `n`, so `n`'s
step gives the next status of its solo run, and its store writes only the output buffer, which
keeps `I`. Each of the six solo runs has at most 29 statuses, each evaluated once.

This is in Lean, MojoProofTest/SkelVadd23.lean, with a stronger `I`: `EqOff 3 · m₀`, the memory
has the start memory `m₀`'s next block number and, at every number, no block or a block of the
same shape, read-only flag, owner and liveness as `m₀`'s, with the same bytes below its size
except in block 3, the output buffer. `R n s` (`RefStatus`) is: returned, or running a thread that
passes `walk` on `m₀`, the Boolean check of thread `n`'s run alone with every step from `m₀`
itself. At each step the check asks that the pending reads miss block 3 and stay below their
blocks' sizes (`readsOk`), that `Labels.MemNext` holds (`memNextB` of MojoProofTest/SkelVadd.lean),
and that the step changes nothing but block 3's bytes and adds no block at its fresh number
(`stepOk`); the run never waits. The kernel evaluates the six checks at the start (`check23_ok`).
The step premise is `Grid.advance_agree` (MojoProof/Sem/Confluence.lean): `EqOff` gives
`Mem.Agree` at the pending reads (`EqOff.agree`, with `Thread.pending_shape` for the pending reads
at the reached memory), so the step from the reached grid gives the status and the memory changes
of the step on `m₀`, and the same changes keep `EqOff` (`EqOff.run`, `run_none` for the fresh
numbers). `Labels.MemNext` moves from `m₀` to the reached memory by the blocks' shapes
(`memAt_shape`). This gives `memOk23`; with the run to the end by `Grid.run` evaluated by the
kernel (`runCheck23_ok`), `Kernel.skel_sound` gives `skel_vadd23`: for every memory related to
`mem5` by `Mem.SkelEq`, `vector_addition` at `L23` is sound at address choice `ch₀` and every
oracle, for the blocks and the trivial relation. The module builds in 5 to 10 s, at 4.2 GB peak
resident memory.
