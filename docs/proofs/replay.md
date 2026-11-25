# The trace-replay checker

`Kernel.replay` and its soundness, for every program (MojoProof/Sem/Replay.lean).

## The checker

`Kernel.replay prog fn L args m ch oracle fuel phases obs R`, for a decidable `R`:

1. `Grid.start prog fn L args m ch oracle`. If the start faults, the result is `unknown`.
2. `Replay.run L c fuel phases g`. This is `Grid.run` (MojoProof/Sem/Grid.lean), except that a
   stop keeps what `Grid.run` drops (`Replay.Stop`):
   - `fault g n fire e`: the grid `g` and the thread `n` whose step (`fire = false`) or
     collective call (`fire = true`) is the fault `e`;
   - `deadlock g`: the grid after a phase that completed nothing with a thread not returned;
   - `out msg`: out of fuel or phases.
3. `Replay.found obs R`. A fault `.ub` gives `ub n msg`. An `.unsupported` fault gives `unknown`,
   and so does `out`. A deadlock gives `stuck`. For a final grid `g` the checks run in order:
   - `race? g.mem.trace`: an access and the earlier access it races with gives `race a e`;
   - then `broken? g.mem.trace`: a frozen read (an `!invariant.load` that neither writes nor is
     an `atomicrmw`'s) and an access that writes for the core's `kept` (a write or an
     `atomicrmw`'s read) that touches its bytes give `broken r w`;
   - then `obs g.mem`: `none` gives `post none`, a `y` failing `R` gives `post (some y)`, and a `y`
     satisfying `R` gives `pass y`.

`Found.bad` is true exactly for `ub`, `race`, `broken`, `stuck` and `post`.

## Statements

For every launch `L`, contexts `c`, grid `g`, fuel, phases, observation `obs` and decidable `R`:

- `Replay.run_eq`: `(Replay.run L c fuel phases g).mapError Stop.toFault = g.run L c fuel phases`.
- `Replay.run_stop`: if the replay stops with `s`, then `s.Holds L c g`:
  - for `fault g' n b e`, `g'` is reachable from `g` and its step or collective call is `e`;
  - for `deadlock g'`, `g'` is reachable, not done, and has no step.
- `Replay.found_bad`: `(found obs R (run L c fuel phases g)).bad = true → ¬ Grid.Sound L c g obs R`,
  for a grid with at most the launch's number of threads every grid reachable from which has the
  premises of `racy_iff` (`Grid.Fits`; `Grid.start_reach_fits` at a start's grid).
- `Grid.run_ub`: `g.run L c fuel phases = .error (.ub msg)` gives a reachable grid that faults
  (the core's `GPUProof.Faults` at `sig`), or one that is not done and has no step.

For every program, kernel, launch, arguments, memory, choice, oracle, fuel, phases and `adm` with
`adm ch oracle`:

- `Kernel.replay_sound`: a violation refutes `Kernel.Sound prog fn L args m adm obs R`.
- `Kernel.replay_unsafe`: a violation for the trivial observation `fun _ => some ()` and relation
  `fun _ => True` refutes `Kernel.Sound` for every observation and relation.
- `Kernel.replay_block`: suppose `R` on the blocks fixes block `out` of `m` to `f x`, where `x` is
  `m`'s block. Then a violation of the replay comparing block `out`'s final bytes (`Replay.bytes?`)
  with `f x`'s refutes `Kernel.Sound` for `fun m => some m.blocks` and `R`.

## Proofs

- **`run_eq`.** By induction on fuel, on the list of threads and on phases, following the
  definitions: each stop is mapped to the fault `Grid.run` throws. `bind_eq` passes the agreement
  through `>>=`. The two done tests use different matchers, so each `if` is split on both sides,
  and the mixed cases are contradictions.
- **`run_stop`.**
  - Fault: the stop's grid is reached by the steps taken before it. Those are `advance` steps in
    `thread`, the earlier threads' runs in `all` (`Grid.runThread_reach`), and the earlier
    completions in `fire`. Lift with `Stop.Holds.back`.
  - Deadlock: a phase ran every thread until it stopped running (`thread_ok`, `all_ok`).
    `advance_frame` gives that a step of one thread leaves the others unchanged. So no thread of
    the grid after the phase runs (`Replay.Idle`), and `advance_idle` gives no `advance` step.
  - Deadlock, continued: `fire_false` says no collective call completed, so every `fire` is
    `none`. This covers threads outside the grid too (`fire_none`). So the grid has no step.
- **`found_bad`.** Case on the result:
  - a `.ub` fault contradicts `safe` at the reachable grid;
  - a deadlock contradicts `progress`;
  - for a final grid (reachable and done by `run_ok`, from `Grid.run_reach` and `Grid.run_done`):
    - a race contradicts `raceFree` (`racy_of_race` via `Access.races_of_raceWith`);
    - a broken promise contradicts `kept` (`kept_of_broken`);
    - `post` contradicts the field `post`.
- **`replay_sound`.** Unfold the start and apply `found_bad` to the started grid.
- **`replay_unsafe`.** Use `Grid.Sound.unit`: the first six fields give soundness for the trivial
  observation.
- **`replay_block`.** Use `Kernel.Sound.map` with `f B := bytes? (B out)`.

## Probes

The probes of an output from its cells' bytes (wrong outputs the checker must refuse: one cell
omitted, no cell stored, two cells swapped, every cell zero, the input copied): `Probe.drop k`, `Probe.stale`, `Probe.swap i j`,
`Probe.zero w n` and `Probe.copy l t enc x n`.

## Scope

Every program, for the checker and its soundness. The instances in MojoProofTest/Replay.lean cover
`vector_addition` only, on one launch (`L23`), memories `mem5` and `mem4`, choice `ch₀` and oracle
`ω₀`:

- `control` passes;
- the canaries are refuted: `omit_cell`, `stale_out`, `swap_cells`, `zero_out`, `input_copy`;
- `pre_refutes` gives the same refutations with the precondition `Map2.Pre`, by `pre5`;
- `short_found`, `short_unsafe` and `short_reach` give the fault at thread 4 on `mem4`.

Kernel evaluation of one replay of `L23` takes about 3 s.

What a replay does not give:

- A `pass` is evidence for that one execution only, with no soundness claim.
- An `unknown` is never a violation.
