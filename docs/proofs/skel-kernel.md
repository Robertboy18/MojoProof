# The kernel theorem from one run per address choice (`Kernel.skel_sound`, `Kernel.Sound.of_blocks`)

Lean: MojoProof/Sem/SkelStep.lean, section "The kernel theorem". Instances and twins:
MojoProofTest/SkelKernel.lean and MojoProofTest/SkelVadd.lean. The statements hold for every
program, kernel, launch, arguments, labelling, payload blocks, memories and set of address choices
that meet their premises.

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
   (`z₁.Done`) and that is not bad (`¬ z₁.Bad L c₁`: no thread faults, no race is enabled, its
   trace has no data race and keeps the promise of `!invariant.load`); and `m₁.SkelEq pay m₂`.
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
  bounded check of `Elem.Out` at one thread with output cell 0 holding 33. `every` explores every
  interleaving, so this route closes `Labels.MemOk` by evaluation only for launches of one or a
  few threads; `Kernels.vadd.correct` covers every valid one-dimensional launch and every address
  choice, on the memories of `Map2.Pre` (`correct_one` states it at the same launch).
