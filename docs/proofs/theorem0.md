# Theorem 0 at MojoProof's grid (`Sound.of_one_run` at `sig`)

Lean: Theorem 0 in `GPUProof/Sound.lean` (the core); MojoProof's signature `sig` in
`MojoProof/Sem/SigDef.lean` and the transport lemmas in `MojoProof/Sem/Sig.lean` (docs/proofs/sig.md
has its fields); the instance `OneRun sig` in `MojoProof/Sym/SigOneRun.lean`;
MojoProof's side in `MojoProof/Sem/Embed.lean`, on top of `Grid.confluent` and `Grid.start_sound`
(`MojoProof/Sem/Determinism.lean`) and W4 (`Grid.start_reach_byThreads`,
`MojoProof/Sem/Confluence.lean`). Instances: `MojoProofTest/Embed.lean`, `MojoProofTest/Sig.lean`
and the gate example, `MojoProofTest/Theorem0.lean`.

**Scope.** Theorem 0 is for every machine. MojoProof's lemmas are for every program, kernel,
launch, arguments, memory, address choice and oracle, and every grid reachable from the grid
`Grid.start` gives. The core (`GPUProof`) defines `Sig`, `Bad`, `racy`, `kept` and `HB` for every
machine (docs/proofs/core.md), proves `Confluent.transfer` and `HB.laminar_iff`, and now Theorem
0 (`Sound.of_one_run`). At `sig` it gives `Grid.start_sound`'s statement, with its binders,
premises and conclusion (the gate example below).

## Theorem 0 at the core

For every machine `S` with `OneRun S`: one run from a start `s₀` to a done state that is not bad,
whose observation of the bytes meets `R`, makes the start sound (`GPUProof/Sound.lean`).

```lean
theorem Sound.of_one_run [OneRun S] (h : S.start P L args m ω = .ok s₀) (hm : S.Closed m args)
    {n : Nat} {z : S.State} (run : Path (Step S) n s₀ z) (hz : Done S z) (hb : ¬ Bad S z)
    {y : β} (hy : obs (S.bytes z) = some y) (hR : R y) : Sound S s₀ obs R
```

`OneRun S` has five fields, each over the states reachable from a good start (`Live`):
`confluent` (the steps between states reachable from `s₀` are `Confluent` up to `S.Same` with
`Bad` persistent), `same_done`, `same_bytes`, `done_final` and `done_safe`. `Sound` extends the
core's `Clean` with `determinate` and `post`, and `Kernel.Sound` says that a launch starts, at a
sound state, at every admitted choice. The proof is `Sound.of_lift` at the states reachable from
`s₀`, along `Subtype.val`, with `Bad` and `OneRun`'s fields.

`Clean.of_lift`, for every machine, every relation `rc` on a type `γ` with a map
`π : γ → S.State` that projects `rc` onto `Step S` and lifts every step, and every observation
`obs` of the states into every type: if `rc` is `Confluent` up to `e` with `B` persistent,
faults, races and broken frozen reads are in `B`, a done state has no step and `e` keeps `Done`
and `obs`, then one run of `rc` from `x₀` to a done `z` not in `B` makes `π x₀` clean (`Clean`)
and gives every reachable done state the observation of `π z`. It assumes no good start. Its
proof is `Confluent.one_run` at `γ`, with reachability and termination lifted along `π`
(`ReflTransGen.of_lift`, `Acc.of_lift`). Two theorems are its cases, and neither repeats the
argument:

- `Sound.of_lift`, at `obs ∘ S.bytes`: if moreover `π z` observes `y` with `R y`, `π x₀` is
  sound.
- MojoProof's `Grid.sound_of_one_run`, at `sig` along `x ↦ (π x, L, c)`, with the observation
  `fun s => obs s.1.mem` of the grid's whole memory: `sig_step_iff` turns the grid's projection
  and lift into the core's, and `Grid.Sound.of_clean` (`MojoProof/Sem/Spec.lean`) carries the
  clean state back to `Grid.Sound`. It takes no premise on the observation beyond `e` keeping it
  (docs/proofs/sig.md, "Removing the five duplicates").

`Done.bad_iff`: a live done state whose running threads are threads of its launch is bad exactly
when its trace races or breaks a frozen read. The design states it without the premise on the
running threads (`hrun`); `OneRun` does not give it, since `Done` reads only the launch's threads.
At `sig` the premise holds on every reachable grid, whose threads are the launch's
(`Grid.start_reach_size`).

## The signature's parts this document uses

A state of `sig` is `(g, L, c)`: a grid, its launch and its contexts, which no step changes. Its
threads are `List.range (volume L.grid * volume L.block)`; it has no jobs. Its trace is the grid's
trace, oldest first: `(g.mem.trace.map (Event.toCore L)).reverse`. A thread's pending events are
`Grid.pending c g n`, and a fire's are the barrier `Grid.fired L g n`. A step is a grid step with
`(L, c)` kept. `Same` is equal `(L, c)` and `Grid.Same`. `Closed m args` is `m.BytesIn m.Known`,
`Grid.confluent`'s premise, for every argument list; the start's check `m.checkClosed args = .ok ()`
is `ArgsOk`. `Event.toCore L` maps `.barrier b` to the `sync` of block `b`'s threads, and an access
to its block, offset and length, by the agent `.thread a.who.thread`.

**The order of pending events.** MojoProof's traces are newest first, and a step logs
`g.pending c n ++ g.mem.trace` (`Grid.advance_set`); `Grid.pending` is newest first too (an
`atomicrmw` logs its write in front of its read, `Stmt.pending`). The core's traces are oldest
first, and its law `Local.advance_logs` says `trace s' = trace s ++ pending s a`. So the
signature's pending events must be reversed:
`pending (g, L, c) (.thread n) = ((g.pending c n).map (Event.toCore L)).reverse`. Without the
reversal `advance_logs` fails at every `atomicrmw`. With it, `trace s ++ pending s (.thread n)`
is `((g.pending c n ++ g.mem.trace).map (Event.toCore L)).reverse`, which is the list that
`Grid.raceEnabled_iff` reads at a running thread `n`. One barrier is its own reverse, so
`firePending` needs no change.

## What each transport lemma needs from MojoProof

Theorem 0 gives `Grid.start_sound` at `sig` through four transport lemmas. The bad set needs
none: MojoProof states a bad grid as the core's `Bad` at `sig` (below). For each one: the core's
statement, the MojoProof statement it needs, and its status.

### `Confluent.transfer`

Core: for types `α`, `β`, relations `r`, `e` and a set `B` on `α`, relations `r'`, `e'` and a set
`B'` on `β`, and a surjective map `f : α → β` with `r' (f a) (f b) ↔ r a b`,
`e' (f a) (f b) ↔ e a b` and `B' (f a) ↔ B a`, `Confluent r e B → Confluent r' e' B'`.
`Grid.confluent` is stated over `{g // ReflTransGen (Grid.Step L c) g₀ g}` and the core's
`OneRun.confluent` over `{s // Reach sig (g₀, L, c) s}`. The map is `g ↦ (g, L, c)`, which is
onto by `sig_reach_iff`; an equivalence of types is a surjection too.

MojoProof needs nothing. The statement is about `Confluent` alone (`GPUProof/OneRun.lean`).
Proof: each of the seven fields at `β` is the field at `α` at preimages under `f`; for `bisim`
and `diamond`, the field at `α` gives states whose images are the states needed at `β`. A new
core module needs its import in the core's imports test (`MojoProofTest/GPUProof/Imports.lean`,
"every `.lean` file under `GPUProof/` is a module of this test's environment"), and that test's
pinned list of core modules. Status: proved (GPUProof/Transfer.lean), for every pair of types,
relations and sets and every such surjection; its instance in this tree is the identity, for two
bad sets with the same members (`Grid.confluent_owned`, MojoProof/Sem/ScheduleOwned.lean).

### `sig_reach_iff`

Core: `Reach sig (g₀, L, c) s ↔ ∃ g, s = (g, L, c) ∧ ReflTransGen (Grid.Step L c) g₀ g`.

MojoProof needs nothing: a step of `sig` is a grid step with `(L, c)` kept (`sig_step_iff`), so
the proof is an induction on `ReflTransGen` on each side. Status: proved, for every launch,
contexts, grid and state (`MojoProof/Sem/Spec.lean`, with `sig_step_iff`, so that
`Grid.Sound.of_clean` there can use them).

### `sig_cta`

Core: on every state reachable from a good start, every access of the trace, and of the trace
followed by a thread's pending events or a fire's, is by a thread whose block is
`who.cta`. `racy_iff` needs this (with `Trace.Shaped`), because MojoProof's races by phases
order two accesses by a barrier when their `who.cta` fields match, and the core's `HB` orders
them when both threads are members of the barrier's block.

MojoProof:

- `Grid.start_reach_byThreads` (W4, exists): in every grid `g` reachable from the start's, every
  access of `g.mem.trace` has `who.thread < g.threads.size` and
  `who.cta = who.thread / volume L.block` (`Grid.ByThreads L g`).
- `Grid.start_reach_pending` (new): the same for the trace with any thread's pending accesses
  in front (`(g.retrace (g.pending c n ++ g.mem.trace)).ByThreads L`), and with the barrier of
  `n`'s collective call in front (`g.fired L n`), for every thread number `n`.

Status: proved. `sig_cta`: at every state `s` reachable at `sig` from the start of launch `L`,
`s.2.1 = L`, and for every thread number `n` both lists are `ByThreads L`.

### `sig_obs`

Core: `Grid.start_sound`'s observation is of a `Mem` under its premise
`hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m'`. The observation at `sig` is of
`sig.Bytes`, the blocks `Nat → Option Block`.

MojoProof: `Mem.obs_blocks` (new): `hO` holds exactly when
`∀ m, obs m = obs { blocks := m.blocks }`. So the observation at `sig` is
`fun bs => obs { blocks := bs }`, and on every memory it agrees with `obs`. `Mem.tensor_blocks`
(exists) is `hO` for the observation of an output buffer.

Status: proved. `sig_obs hO s : obs s.1.mem = obs { blocks := sig.bytes s }`, at every state.

### The bad set

Core: the core's `Bad` is `Faults ∨ racy trace ∨ kept trace = false ∨ RaceEnabled`, where
`RaceEnabled` is a running thread whose pending events make `trace ++ pending` racy, or a fire
that completes and whose events make `trace ++ firePending` racy.

MojoProof: a grid `g` at launch `L` and contexts `c` is bad when `GPUProof.Bad sig (g, L, c)`,
and a race is enabled in it when `GPUProof.RaceEnabled sig (g, L, c)`; MojoProof has no bad set
of its own, so no lemma carries one to the other. What reads the core's predicates at a grid:

- `Grid.raceEnabled_iff` (`MojoProof/Sem/Bad.lean`): the core's `RaceEnabled` at `sig` in the
  grid's terms. A race is enabled exactly when some thread `n` runs,
  `g.threads[n]? = some (.run t)`, and `racy (t.pending (c n) g.mem ++ g.mem.trace)`, or some
  fire of `n` completes and the grid's trace is racy. A barrier in front of a trace keeps
  `racy` (`racy_barriers`), so the fire case is the trace's race.
- `Faults`: MojoProof states its faults as the core's `Faults` at `sig`. `Grid.faults_iff` reads
  them as a thread's step or fire that faults, since `sig`'s steps map the grid's faults
  unchanged, and its agents are threads only.
- `Running`: the core's `Running (.thread n)` at `sig` is `∃ t, g.threads[n]? = some (.run t)`,
  the case of `Grid.raceEnabled_iff`. No lemma.
- `racy`: MojoProof has no `racy` of its own (`sig.md`, step 3). `racy_iff` (L9) reads it, at a
  trace by threads of the launch in their blocks (`sig_cta`) that is shaped, as two accesses
  with phases that `clash`: different threads, a conflict, and different blocks or the same
  phase, by the core's `HB.laminar_iff`, because blocks of threads are disjoint.
- `conflict` and `kept`: MojoProof's `Access.overlaps` is the core's footprint intersection
  ("share a byte"): `Access.overlaps_iff_bytes` (`Trace.lean`) says two accesses overlap exactly
  when they touch a common byte (`Access.bytes`: block and offset). The promise of
  `!invariant.load` is the core's `kept` at `sig` (`Grid.Kept`); `kept_sig_iff` (`Trace.lean`)
  reads it as no access that writes for the core overlapping a frozen read.
  `Access.conflict`'s exemption (one commuting `atomicrmw` operation, `RmwOp.commutes`, pointer
  and length) is the signature's `exempt`.

Status: nothing to prove. The run's premise `¬ Bad` of Theorem 0 at `sig` is
`Grid.start_sound`'s premise as it is.

Where a proof reads the core's `racy` at a reachable grid, `racy_iff` and `racy_sig_rev` need
the trace by threads of the launch in their blocks (`sig_cta`) and shaped (`Trace.Shaped`: every
`atomicrmw`'s read is followed at once by its write, and a load with `!invariant.load` neither
writes nor updates). `Grid.start_reach_fits` gives both, for the trace and for the trace with a
thread's pending events in front (`Grid.Fits`). The core counts an `atomicrmw`'s read as an
update, which writes (`Access.kind`); the write logged right after it has the same bytes and the
same order, so a race with the read is a race with the write (`racy_sig_rev`). The core's `racy`
at `sig` by positions is `racy_sig_iff`, through `HB.laminar_iff` and `Levels sig`.

## `OneRun`'s fields at MojoProof

`Grid.OneRun L c g₀` (new) has the five fields in MojoProof's terms, and
`Grid.start_oneRun` (new) proves them from the start, for a caller's memory every pointer byte
of whose blocks names a known number (`m.BytesIn m.Known`). That premise is `sig`'s `Closed`, so
the core's good start gives it as it is.

| Core field | MojoProof | From |
|---|---|---|
| `confluent` | `Confluent` over `{g // ReflTransGen (Grid.Step L c) g₀ g}`, up to `Grid.Same`, with the core's `Bad` at `sig` | `Grid.confluent` |
| `same_done` | `g.Same g' → GPUProof.Done sig (g, L, c) → GPUProof.Done sig (g', L, c)` | `Grid.Same`'s equal threads, `Grid.done_iff` |
| `same_bytes` | `g.Same g' → g.mem.blocks = g'.mem.blocks` | `Grid.Same`'s equal blocks |
| `done_final` | `ReflTransGen (Grid.Step L c) g₀ g → GPUProof.Done sig (g, L, c) → ¬ Grid.Step L c g g'` | `Done.final`, `Grid.start_reach_size` |
| `done_safe` | `ReflTransGen (Grid.Step L c) g₀ g → GPUProof.Done sig (g, L, c) → ¬ GPUProof.Faults sig (g, L, c)` | `done_not_faults`, `Grid.start_reach_size` |

The instance `sig_oneRun : OneRun sig` (`MojoProof/Sym/SigOneRun.lean`) is `Grid.start_oneRun` at
the start's grid, with the good start's `Closed` for its premise, carried to `sig` by
`Confluent.transfer` along `g ↦ (g, L, c)` (onto by `sig_reach_iff`), with the same bad sets (the
core's `Bad` at `sig` at the grid's state); `Done` is the core's on both sides. `Grid.OneRun` stays:
`Grid.start_oneRun` states it.

`same_done` and `same_bytes` hold for every grid; `done_final` and `done_safe` hold at the grids
reachable from `g₀`, as the core's `OneRun` states them. The core's `Done` at `sig` is "each
thread of `List.range (volume L.grid * volume L.block)` has returned", which reads no thread
beyond the launch's (`Grid.done_iff`: each of those thread numbers is absent or returned). Every
reachable grid has exactly that many threads (`Grid.start_reach_size`): a step keeps the number
of threads (`Grid.Step.size`, `Grid.reach_size`), and the start's grid has `volume L.grid *
volume L.block` (`Grid.start_size`), all three in `MojoProof/Sem/Determinism.lean`. With these,
`Done.bad_iff` at the core is `Grid.Done.bad_iff`.

## Instances

`MojoProofTest/Embed.lean`:

- `vadd` (`Kernels.vadd.prog`) on 2 blocks of 2 threads and on 1 block of 4, on `memV`, for every
  address choice and oracle: `Grid.start_oneRun`; every reachable grid has 4 threads, is done
  exactly when threads 0 to 3 have returned, and has its pending accesses by their threads in
  their blocks (`embed`).
- The output buffer's observation `Mem.tensor` is a function of the blocks (`tensor_obs`).
- A kernel text that stores at word `%ctaid.x * %ntid.x + %tid.x`, waits at a barrier and loads
  the word back, run by the evaluator on 2 blocks of 2 threads and on 3 blocks of 4: the start's
  pending accesses and the final trace are by their threads in their blocks, the final grid has
  the launch's number of threads and is done, and its trace has one store, one load and one
  barrier per thread (`#guard`).

`MojoProofTest/Sig.lean`, one program (vadd) at two launches (2 blocks of 2 threads, 1 block of
4), by evaluation: `sig`'s own steps from `sig.start` end with every thread returned, with the
grid evaluator's trace reversed as `sig`'s trace; the core's `racy` and the race check by phases
(`fast`) agree on it and the core's `kept` keeps it; and a mutant with a write by thread 3 to the
bytes of thread 0's store races for both.

`MojoProofTest/Close.lean`, one memory at two launches: on `launch2 1 1 2 1` and `launch2 1 1 3 1`,
for every contexts, the grid of 2 (or 3) threads in which thread `n` ends its own `alloca` block
`n + 1` in its one step is sound for the observation of which blocks are live (`sound_dead`). It is
`Grid.sound_commuting` (MojoProof/Sem/Trace.lean): for every `N`, launch of at least `N` threads,
contexts `c`, threads `ts`, memory `M`, changes `f` and property `P` of memories with `P M` that
every `f n` (`n < N`) keeps, if at every memory `m` with `P m` the step of thread `n < N` is
`.ok (.done (f n m))`, `f i (f j m) = f j (f i m)` for distinct `i, j < N` and `f n` keeps the
trace, and `M`'s trace has no race and keeps `!invariant.load`, then
`Grid.Sound L c (retGrid N ts M fun _ => false) obs R` for every `obs` and `R` with
`obs ((List.range N).foldr f M) = some y` and `R y`. A step that returns changes memory only by
ending its frame's `alloca`s, so these are the changes such a grid can make; threads that store and
then return take more than one step and are not covered. `Grid.sound_returning` is its case
`f n m = m`.

The twins of the premises: W4's premise that the contexts are the start's (`byThreads_twin`,
`MojoProofTest/Start.lean`), and the premise on the caller's pointer bytes (`closed_twin`, the
same file).

## The gate: `Grid.start_sound` from Theorem 0

`MojoProofTest/Theorem0.lean` states `Grid.start_sound`'s statement as an `example`, with its
binders, premises and conclusion: for every program, kernel, launch, arguments, memory every
pointer byte of whose blocks names a known number (`m.BytesIn m.Known`, `sig`'s `Closed`),
address choice, oracle and observation that reads only the blocks. It proves it from
`Sound.of_one_run` at `sig` with the instance `OneRun sig` (`sound_sig`,
MojoProof/Sym/SigKernel.lean:141, in the library because gemv's and gevm's theorems use it
through `kernel_sound_sig`), and carries the core's `Sound` back to `Grid.Sound`
(`Grid.Sound.of_sig`, SigKernel.lean:194, in the library because `Kernel.Sound.of_sig`, which
MojoProofTest/GemvObs.lean's observations of gemv's and gevm's theorems use, goes through it). It
uses no `Grid.start_sound`, `Grid.sound_of_one_run` or `Grid.confluent`; `OneRun sig` reaches
`Grid.confluent` only through `Grid.start_oneRun`. Without their docstrings the example takes 9
lines, `sound_sig` 21 and `Grid.Sound.of_sig` 16; `Grid.Sound.of_sig` holds at every grid and
contexts, not only a start's.

`Grid.Sound.of_sig` gives the core's `Clean` part of `Sound` to `Grid.Sound.of_clean`, which carries
its five fields: `safe` as it is (`Grid.Safe` reads the core's faults at `sig`), `raceFree` and
`kept` as they are (`Grid.RaceFree` and `Grid.Kept` read the core's `racy` and `kept` at `sig`),
`progress` with the core's `Done` as it is, and `sig_step_iff` for `progress` and `terminates`.
`Grid.Sound.of_sig` carries `determinate` and `post`, with the core's `Done` as it is and `sig_obs`
for the observations. The run's premise `¬ Bad` is the core's at
`sig` on both sides. Nothing else of MojoProof enters, and no change to its semantics.

The example applies on memories that are not closed (`Mem.Closed`), by evaluation at address
choice and oracle 0: at `memAt 2 5 4` (`next = 2`, no block 0, a block 5 of 4 data bytes) with no
arguments, `ret void` on one thread (`applies_one`), and at `memAt 3 7 8` (`next = 3`, a block 7
of 8 data bytes) on 2 blocks of 3 threads (`applies_six`). Each memory is `sig`'s `Closed` and not
`m.Closed []`; the start succeeds; one step of each thread gives a grid in which every thread has
returned and that is not bad; and the example's proof makes the start's grid sound.

## Not proved

- `Done.bad_iff` without the premise on the running threads.
