# The core: what every machine has (`GPUProof`)

Lean: `GPUProof/Sig.lean`, `GPUProof/Race.lean`, `GPUProof/Run.lean`, the one-run theorem in
`GPUProof/OneRun.lean` (`one-run.md`), `Confluent.transfer` in `GPUProof/Transfer.lean`
(`theorem0.md`), `Levels` with `HB.laminar_iff` in `GPUProof/Laminar.lean`, and the use maps with
`racy_eq_false_of_uses` in `GPUProof/Uses.lean` (both `laminar.md`), Theorem 0 with `Sound`,
`Kernel.Sound` and `OneRun` in `GPUProof/Sound.lean` (`theorem0.md`), and `racy` by chunks in the
kernel (`racy_by_chunks`, `trace_literal%`) in `GPUProof/Chunks.lean` ("`racy` in the kernel"
below). Tests: `MojoProofTest/GPUProof/Toy.lean`, `MojoProofTest/GPUProof/Race.lean`,
`MojoProofTest/GPUProof/Clean.lean`, `MojoProofTest/GPUProof/Laminar.lean`,
`MojoProofTest/GPUProof/Uses.lean`, `MojoProofTest/GPUProof/Chunks.lean`,
`MojoProofTest/RacySig.lean` and `MojoProofTest/RacySigRun.lean` (through `sig`), and
`MojoProofTest/GPUProof/Imports.lean`, which checks that the core imports only `GPUProof.*`,
`Mathlib.*` and `FloatLib`. The core's spec layer, `GPUProof/Spec/Basic.lean` and
`GPUProof/Spec/Linear.lean`, has its own document (`spec.md`).

**Scope.** Every machine, that is every `S : Sig`: the definitions read only the fields of `S`. No
definition of the nine modules above fixes a machine constant (a warp width, a barrier count, a
memory space, a proxy); the only numerals in them count the steps of a `Path`, and in
`GPUProof/Chunks.lean` the positions of a trace and the universe levels and bound variable of the
terms it writes. The tests are about one test machine (`toy`, below), except
`MojoProofTest/RacySig.lean` and `MojoProofTest/RacySigRun.lean`, about one program
(`vector_addition`) at one launch through `sig`. MojoProof's grid machine keeps its own definitions
(`Grid.Step`, `Grid.Sound`, whose faults are the core's `Faults` at `sig`), and the law classes
below are statements in this document only, except `Levels` and `OneRun`, which are Lean, and the law on `place`, which is the Lean proposition `PlaceInj`
with their first instances (`laminar.md`, `theorem0.md`, departure 9).

## The signature (`GPUProof/Sig.lean`)

* `Status T C`: a thread is running (`run t`), waiting at a collective call (`wait t call`, with
  the thread as it was before the call), or returned (`done`).
* `Agent Tid Job`: a thread of the launch (`thread t`) or an issued asynchronous job (`job j`).
* `Kind Op`: `read`, `frozen` (a read of bytes no write may touch during the launch), `write`,
  `rmw op` (an update whose result is unused, which the machine may exempt) and `rmwRet op` (one
  whose result is used). `Kind.writes`: every kind but `read` and `frozen`.
* `Access A Buf Op Proxy`: agent `who`, buffer `buf`, offset `off : Int`, length `len : Nat`,
  `kind`, `proxy`. An access names an interval, so a bulk copy is one access.
* `Event A Buf Op Proxy Obj`, five forms: `access a`; `sync o members`, a rendezvous on the
  program order of every member; `rel who o ph` and `acq who o ph`, a release and an acquire of
  phase `ph` of object `o`; `fence who p q`, a proxy fence from `p` to `q`.
  `Event.agents` is the agents whose program order the event lies on, `Event.access?` its access.
* `Sig`: the launches, agents and levels (`threads`, a linear and bounded order of `Level`,
  `group`, `levelOf`, `members`), the memory (`Space`, `home`, `Loc`, `key`, `place`, `placeInj`,
  `Meta`, `Bytes`, `byteAt`, `metaAt`; `key`, a number for each byte, has the default `fun _ => 0`
  and only orders `kept`'s comparisons; `placeInj`, a proof that `place` puts different bytes of
  buffers at different bytes, has the default `none` and only chooses how `racy` compares two
  accesses' bytes), the updates (`Op`, `commutes`, `combine`, `exempt`), the
  proxies and objects, programs, values and choices, the states and steps (`status`, `jobs`,
  `landed`, `bytes`, `trace`, `pending`, `firePending`, `reads`, `start`, `advance`, `fire`,
  `Same`, `Agree`, `Delta`, `apply`), the caller's checks and the launch boundary (`Closed`,
  `ArgsOk`, `StartOk`, `ValidLaunch`, `launchCells`, `endLaunch`), and thirteen fields of
  decidable equality, for the types the race check, joins and checks compare.
* `Access.locs S a`: byte `a.off + i` of `a.buf` through `S.place`, for each `i < a.len`.
  `Access.conflict S a b`: the accesses share a byte, one of them writes, and `S.exempt a b` is
  `false`.
* `PlaceInj place`, the design's optional law on `place` (its `inj` and `disjoint` in one
  statement: `place b i = place b' j → b = b' ∧ i = j`), a proposition that a machine proves as the
  field `Sig.placeInj` and that `Access.meets_iff` takes as a premise. `Access.meets S a b`: `a` and `b` are of one buffer, neither is empty and
  their intervals of offsets meet. `Sig.share S a b L L'`: `Access.meets` when `S.placeInj` is a
  proof, and otherwise whether a byte of `L` is one of `L'`.

## The race check (`GPUProof/Race.lean`)

Positions are indices into a trace, oldest first.

* `edge S tr i j`: `i < j` and the events at `i` and `j` share an agent (`Event.agents`), or the
  event at `i` releases a phase of an object that the event at `j` acquires (`Event.relAcq`, any
  two agents). `edge_lt`: an edge goes forward, to a position of the trace.
* `HB S tr`: Mathlib's `Relation.TransGen` of `edge`. `HB.lt`: it goes forward. `HB.tail_iff`:
  `HB S tr i j` holds when an edge into `j` comes from `i` or from a position `k` with
  `HB S tr i k`.
* `scan S tr K`: one pass over the first `K` positions in order (`Scan.step`). A clock is a set of
  positions kept as the bits of a number: `Nat.testBit` reads it and `Nat.lor` joins two. The
  event at position `j` gets the clock `Scan.clock`: `j`, joined with the clocks of its agents so
  far and, at an acquire, the clock of the phase it acquires. Then each of its agents joins that
  clock into its own (`Scan.cur`), a release joins it into the clock of its object's phase
  (`Scan.rel`), and a fence is kept with it (`Scan.fences`). Agents and phases keep their clocks
  in association lists (`clockOf`, `addClock`). `Scan.Inv` says what the state holds after the
  first `K` positions, and `scan_inv` says the pass keeps it, by `Scan.Inv.testBit_clock` at each
  step. Since every edge goes forward, the clocks of the positions before `j` are complete at `j`.
* `clock S tr j`: the clock of position `j` from the pass over the positions before it.
  `testBit_clock`: it holds exactly `j` and the positions `i` with `HB S tr i j`. `hb S tr i j` is
  `i < j` and `i` in the clock of `j`, and `hb_iff : hb S tr i j = true ↔ HB S tr i j`.
* `Ordered S tr p q i j`: `p = q` and `HB S tr i j`, or a fence from `p` to `q` at a position `k`
  (by any agent) with `HB S tr i k` and `HB S tr k j`. `ordered` checks it through `isFence` and
  `hb` at each position of the trace, and `ordered_iff` says it decides `Ordered`.
* `Racy S tr`: positions `i < j` holding accesses `a` and `b` that conflict and that
  `Ordered S tr a.proxy b.proxy i j` does not order. `racePair` checks one pair
  (`racePair_iff`). `racy` is the pass over the whole trace. It keeps the accesses that write
  apart from the others (`Scan.writes`, `Scan.reads`), each with its position and its bytes
  (`Access.locs`), built once. At each access `b` with clock `c`, it checks each write `a` kept
  before it and, when `b` writes, each other access kept before it too (`Scan.races`), in this
  order: they are not ordered, that is, neither `c` holds `a`'s position with the same proxy, nor
  a fence kept from `a`'s proxy to `b`'s comes after `a`, holds `a` in its clock and is in `c`;
  they share a byte (`Sig.share`); and the machine does not exempt them (`Sig.exempt`).
  `Sig.share_iff`: on the bytes of two accesses, `Sig.share` holds exactly when they share one,
  for every machine: under the proof of `PlaceInj` that `placeInj` holds, by
  `Access.meets_iff`, and otherwise by the comparison of bytes. `Scan.Inv.races_iff`:
  for two accesses of which one writes, that check holds exactly when `racePair` does at the two
  positions. `racy_scan`: the pass finds a race exactly when two of its positions hold a pair that
  `racePair` checks. Then `racy_iff : racy S tr = true ↔ Racy S tr`.
* `kept S tr`: no access of `tr` that writes shares a byte with a frozen read of `tr`, before or
  after it, by any agent, ordered or not. It walks `tr` once and collects the bytes of the accesses
  that write and the bytes of the frozen ones (`keptFrom S W F tr`, with the bytes `W` and `F` of
  the events before), sorts each list by the machine's numbering of bytes (`S.key`) with a merge
  sort that is structural in its arguments, so that the kernel evaluates it (`keySort`: rounds of
  `keyPairs`, each merging the lists two by two with `keyMerge`), and walks the two sorted lists
  once (`disjointSorted`): each byte written is compared only with the frozen bytes of its number.
  `Kept S tr` says the same as a proposition, for all accesses `w` and `a` in `tr` (list membership,
  so at any positions), and `kept_iff : kept S tr = true ↔ Kept S tr` holds for every numbering
  (`keptFrom_iff`, `disjointSorted_iff`, `mem_keySort`, `pairwise_keySort`): equality of bytes still
  decides each match, and the numbering only says which bytes are compared. The walk of `tr` comes
  first so that unifying `kept S tr` with `kept S tr'` stops at `tr` when the trace is not known, as
  with the body before. `sig` numbers byte `(b, i)` by `Nat.pair b` of `i`'s number (`2·n` for `i =
  n`, `2·n + 1` for `i = -(n+1)`), so different bytes have different numbers
  (`MojoProof.Sem.sig_key_inj`); `toy` keeps the default `0`, so its `kept` compares every byte
  written with every frozen byte. The cost is in "`kept`'s cost" below.

One agent's accesses through one proxy are ordered by its program order, so a race needs two
agents, or one agent and two proxies.

## Runs (`GPUProof/Run.lean`)

* `Step S s s'`: an agent's step `S.advance s a = .ok (some s')`, or a completed collective call
  `S.fire s t = .ok (some s')`. `Reach S`: Mathlib's `Relation.ReflTransGen` of `Step S`. The
  paths of a relation (`Path`), normal states (`Normal`) and the one-run theorem
  (`Confluent.one_run`) are in `GPUProof/OneRun.lean`.
* `GoodStart S s₀`: `s₀` is the start of a launch on a caller's memory that `S.Closed` accepts
  with the arguments.
  `Live S s₀ s`: `GoodStart S s₀` and `Reach S s₀ s`.
* `Faults`: some agent's step or some completion faults. `Running`: a running thread, or an issued
  job that has not landed. `Done`: every thread of the launch returned and every issued job
  landed.
* `RaceEnabled`: a running agent's pending events, or the events of a completion, appended to the
  trace make it `racy`. `Bad`: `Faults`, a `racy` trace, a trace that is not `kept`, or
  `RaceEnabled`.
* `Clean S s₀`, the part of soundness that names no observation, with fields `safe`, `raceFree`,
  `kept`, `progress` (a reachable state that is not done steps) and `terminates` (`Acc` of the
  converse of `Step S` at `s₀`).

## Where the Lean definitions depart from the design

1. **`HB` is a closure of a Boolean edge, not an inductive.** The design declares happens-before
   as an inductive with program-order, rendezvous and release-acquire rules, closed transitively.
   Lean takes `Relation.TransGen` of `edge`, where program order relates any two positions of one
   agent rather than consecutive ones; the transitive closures are the same relation. Mathlib's
   lemmas on `TransGen` and `ReflTransGen` then give `HB.lt` and `HB.tail_iff`. Since program
   order relates any two positions of one agent, the clock of an agent stands for all of its
   events so far, which gives `testBit_clock` and `hb_iff`.
2. **`racy` is one pass with a clock per position.** The design asks for the plain check of every
   pair, with `HB` decided by one reachability pass. `racy` is one pass over the trace (`scan`). It
   gives each position its clock, the set of the positions that are it or happen before it, kept
   as the bits of a number. It checks each access against the accesses before it through its own
   clock and the clocks of the fences before it. `hb` and `ordered` read the same clocks
   (`clock`). A clock is indexed by position, not by agent as a vector clock is. Joining two
   clocks is then one `Nat.lor` and reading one is one `Nat.testBit`, which the kernel computes on
   numbers. A clock indexed by agent, as an association list, would take time in the number of
   agents at each join. Two accesses that do not write never conflict, so the pass keeps the
   writes apart from the others and checks each access only against the earlier writes and, when
   it writes, the earlier others. Each pair checked costs a few operations on numbers for the
   order, and the bytes of each access are built once and compared only when nothing orders the
   pair ("`racy` in the kernel" below gives the pairs skipped and measures it). The statements
   `hb_iff`, `ordered_iff` and `racy_iff` are the same as for the plain check, and there is no
   second decision procedure to relate to it.
3. **`Ordered` takes the two proxies.** The design's `Ordered tr i j` reads the proxies of the
   accesses at `i` and `j`. Lean's `Ordered S tr p q i j` takes them as arguments, so it is defined
   at every pair of positions and `ordered` needs no lookup; `Racy` passes `a.proxy` and
   `b.proxy`. A fence from `p` to `q` is any agent's, as in the design ("an `HB` path between them
   passes a fence").
4. **`racePair`, `Event.relAcq`, `Event.agents`, `Event.access?`, `Kind.writes`, `isFence`, the
   clocks (`clock`, `clockOf`, `addClock`) and the pass (`Scan`, `Scan.step`, `scan`) are
   helpers** that the design leaves inside its definitions. `Event.bind_access?_eq_some`,
   `isFence_iff`, `racePair_iff`, `testBit_clock`, `Scan.Inv.races_iff` and `racy_scan` relate them
   to the propositions.
5. **`kept` has a propositional form, `Kept`, with `kept_iff`**, which the design does not
   name: the design's `kept` is a `Bool` only. `Kept` quantifies over the accesses of the trace by
   list membership, not over positions as `Racy` does, since `kept` reads no order.
6. **`Access.locs` and `Access.conflict` take the machine `S` explicitly**, like every definition of
   the core (`variable (S : Sig)`); `Access.locs` casts the index to `Int`.
7. **The order and decidability fields of `Sig` are made instances** after the structure
   (`attribute [instance]`), so definitions over `S` compare its types without naming the fields.
8. **Not in Lean yet**: the abbreviations `Slot` and `ThreadStatus` (no definition uses them;
   `Sig.reads` and `Sig.launchCells` spell out `Loc ⊕ Buf`), `RunsTo`, and every law class but
   `Levels` and `OneRun`; the law `Place` is the proposition `PlaceInj` (departure 9). A law class
   enters Lean with its first instance: `Levels` with `Levels toy` (`laminar.md`), and `OneRun`
   with `OneRun sig` (MojoProof/Sym/SigOneRun.lean, `theorem0.md`). `Sound`, `Kernel.Sound`, `OneRun`,
   `Clean.of_lift` (one run along a projection whose steps lift makes the first state's image clean
   and gives every reachable done state the run's last observation, for every machine and every
   observation of the states), `Sound.of_lift` (its case at an observation of the bytes),
   `Sound.of_one_run` (the case of `Sound.of_lift` at the states reachable from a good start) and
   `Done.bad_iff` (with a premise that every running thread is one of the launch's, which the
   design's statement lacks and `OneRun` does not give) are in `GPUProof/Sound.lean`.
9. **The law on `place` is one proposition, `PlaceInj`, and a machine gives it through a field,
   `Sig.placeInj`.** The design says that `racy` decides the overlap of two accesses by their
   intervals under `Place.disjoint`. `racy` is one definition for every machine, with `racy_iff`
   for every machine, so it takes no instance. The design's class `Place` (`inj`, `disjoint`) is
   in Lean the one proposition `GPUProof.PlaceInj place`
   (`place b i = place b' j → b = b' ∧ i = j`, which gives both fields at once), defined before
   `Sig` so that the field can name it: `placeInj : Option (PLift (PlaceInj place))`, `none` by
   default. There is no class: its text would be the law a second time. `Sig.share` decides once,
   by a match on the field: by intervals (`Access.meets`) when it is a proof, and by the bytes
   otherwise. `Sig.share_iff` proves both cases once, the first by `Access.meets_iff`, which takes
   the proof of `PlaceInj` as its premise. Since the proof comes with the choice, a machine cannot
   take the interval test without the law. `toy` and `sig` prove the law once each, as
   `placeInj`, by `Prod.mk.inj`; a machine whose buffers alias leaves `none`
   (`MojoProofTest.GPUProof.Race.aliased`).

## `racy` in the kernel

**Measured.** `racy toy tr = false` proved by `decide +kernel`, one proof per trace, beside the
evaluator's `#guard !racy toy tr` on the same trace, for three bodies of `racy`: the plain check
of every pair that `racy` was before the clock pass, the clock pass checking every pair
(departure 2), and the clock pass checking fewer pairs ("Fewer pairs" below). All three compare
bytes, as `racy` does now on a machine without `placeInj`; `toy` gives it now, and the cost with
it is in "The law on `place`" below. Each trace is written out as a list; a `#guard` checks that
the ring's and the hand-over's lists are their runs' traces (`final (ring true n) n` and
`MojoProofTest.GPUProof.Laminar.run true true k nw`). The kernel's time is its check of the proof
alone; memory is the process's peak, under a limit of 24 GB.

| trace | events | kernel, every pair | memory | kernel, clocks | memory | kernel, fewer pairs | memory |
|---|---|---|---|---|---|---|---|
| ring, 8 threads | 17 | 0.3 s | 1.8 GB | under 0.1 s | 1.8 GB | under 0.1 s | 1.8 GB |
| ring, 32 threads | 65 | 4.3 s | 1.8 GB | 1.2 s | 1.8 GB | 1.0 s | 1.8 GB |
| ring, 128 threads | 257 | 71 s | 6.7 GB | 19 s | 3.6 GB | 16 s | 3.4 GB |
| hand-over, 2 warps of 4 lanes | 9 | under 0.1 s | 1.8 GB | under 0.1 s | 1.8 GB | under 0.1 s | 1.8 GB |
| hand-over, 2 warps of 16 lanes | 33 | 0.9 s | 1.8 GB | 0.6 s | 1.8 GB | 0.6 s | 1.8 GB |
| hand-over, 4 warps of 32 lanes | 65 | 3.3 s | 1.8 GB | 4.8 s | 2.0 GB | 4.5 s | 2.0 GB |
| `vector_addition`'s shape, 16 threads | 96 | 41 s | 5.0 GB | 6.7 s | 2.3 GB | 4.9 s | 2.1 GB |
| `vector_addition`'s shape, 32 threads | 192 | 170 s | 16 GB | 27 s | 5.0 GB | 24 s | 4.3 GB |
| `vector_addition`'s shape, 64 threads | 384 | not measured | | 116 s | 16 GB | 90 s | 13 GB |
| `vector_addition`'s launch, 128 threads | 684 | out of memory | | out of memory, after 2 min 48 s | | out of memory, after 3 min 28 s | |

| trace | evaluator, every pair | evaluator, clocks | evaluator, fewer pairs |
|---|---|---|---|
| ring, 8 threads | 3 ms | 1 ms | 1 ms |
| ring, 32 threads | 34 ms | 5 ms | 3 ms |
| ring, 128 threads | 1.3 s | 65 ms | 45 ms |
| hand-over, 2 warps of 4 lanes | 1 ms | under 1 ms | under 1 ms |
| hand-over, 2 warps of 16 lanes | 56 ms | 3 ms | 3 ms |
| hand-over, 4 warps of 32 lanes | 0.7 s | 23 ms | 20 ms |
| `vector_addition`'s shape, 16 threads | 0.24 s | 32 ms | 15 ms |
| `vector_addition`'s shape, 32 threads | 1.0 s | 0.14 s | 57 ms |
| `vector_addition`'s shape, 64 threads | not measured | 0.51 s | 0.22 s |
| `vector_addition`'s launch, 128 threads | 14 s | 1.6 s | 0.63 s |

The last row of both tables has as many events as the launch of `vector_addition` (a kernel of
scripts/SymBench.lean) in the evaluator tests (`MojoProofTest.vaddTests`: 4 blocks of 32 threads
on 100 floats). Its events were counted on the trace of `MojoProof.Sem.Grid.run` on that launch:
684 accesses and no barrier, that is three 8-byte loads of its arguments per thread and, for each
of the 100 threads in range, two 4-byte loads with `!invariant.load` and one 4-byte store. The
toy trace has the same accesses: the arguments are each thread's own buffers, and the
`!invariant.load` loads are frozen reads. Its smaller rows keep the shape with every thread in
range.

The clock pass takes 1.4 to 6 times less kernel time than the plain check on every trace but the
largest hand-over, up to 3 times less memory, and 2.5 to 30 times less evaluator time. Its kernel
time still grows with about the square of the events (4 times from 96 to 192 events and from 192
to 384), and its memory as fast (5.0 GB to 16 GB from 192 to 384), since the kernel keeps what it
reduces. A rendezvous of `m` agents costs `m` lookups and `m` updates in the association list of
the agents seen (`clockOf`, `addClock`). So the largest hand-over, 32 rendezvous of 32 or 128 of
its 128 threads, costs more than with the plain check.

Checking fewer pairs takes 7 to 28% less kernel time than the clock pass on the traces of more than
4 s (23% at 384 events), about a sixth less memory at 192 and 384 events (5.0 GB to 4.3 GB, 16 GB to
13 GB), and 1.1 to 2.6 times less evaluator time on the traces of more than 10 ms (1.6 s to 0.63 s
at the launch). The kernel gains less than the evaluator. The pairs it skips were already cheap in
the clock pass, which first tested whether one of the two accesses writes, and the byte comparisons,
which dominate in `vector_addition`'s shape, where nothing orders two threads' accesses, are the
same. The kernel's time still grows with about the square of the events (5 times from 96 to 192
events, 3.7 times from 192 to 384), and the launch is still out of memory at 24 GB in one proof. So
`decide +kernel` on `racy`, comparing bytes, fits the tests' traces, of up to a few hundred events,
and not one launch of a corpus kernel in one proof. Comparing intervals (`placeInj`), it fits
`vector_addition`'s launch through `sig` in one proof ("The law on `place`" below), and the number
of pairs still grows with the square of the accesses: one block of `tiled_matmul` alone makes
37,888 accesses (`MojoProofTest/Eval.lean`). A visit of only the pairs that share a byte, sorted
by `Sig.key`, is measured below and not taken ("Visiting the pairs sorted by `Sig.key`").

**By chunks.** GPUProof/Chunks.lean proves `racy S tr = false` on a trace too long for one proof.
`GPUProof.scan_add` splits the pass, for every machine: the pass over `K + m` positions is `m` more
steps (`GPUProof.Scan.step`) from the pass over `K`. The tactic `racy_by_chunks m` runs the pass in
the evaluator and writes out its state after every `m` positions (`GPUProof.quoteChunks`, through
`Lean.ToExpr` instances for the machine's types). Each chunk is a lemma of its own, `List.foldl
(Scan.step tr) s (List.range' K m) = t`, which the kernel checks by `decide` on the equality of
states (`DecidableEq (GPUProof.Scan S)`); `GPUProof.scan_chunk` chains the chunks and
`GPUProof.racy_eq_false_of_scan` reads `racy` off the last state. The evaluator only proposes the
states; the kernel checks each one. When the pass finds a race, the tactic fails and names the chunk
(`#guard_msgs` in MojoProofTest/GPUProof/Chunks.lean). `trace_literal% t` writes out the trace `t`,
as the evaluator computes it, as a list literal. A theorem about a definition made with it is about
the literal trace: the trace the evaluator produced, whose equality with the run is checked by the
evaluator (a `#guard` beside the definition), not by the kernel. For `vector_addition`'s launch
through `sig` the kernel checks it too: `MojoProofTest.RacySig.trSig_run` (`decide +kernel`,
MojoProofTest/RacySigRun.lean) evaluates the start and the run in one proof.

Measured with `set_option profiler true`, one process under a limit of 24 GB; the kernel's time is
its check of each chunk's lemma:

| trace | events | positions per chunk | chunks | kernel, each chunk | kernel, all chunks | process | memory |
|---|---|---|---|---|---|---|---|
| ring, 11 threads, the run itself (`final (ring true 11) 11`) | 23 | 5 | 5 | 0.18 to 0.21 s | 0.9 s | 9 s, with the next row | 1.8 GB |
| ring, 37 threads, written out (`trace_literal%`) | 75 | 16 | 5 | 0.15 to 0.53 s | 1.7 s | | |
| `vector_addition`'s launch through `sig`, written out, comparing bytes | 684 | 57 | 12 | 2.7 to 41 s; 1.8 to 39 s | 283 s; 266 s | 4 min 57 s; 4 min 33 s | 8.5 GB; 8.4 GB |
| `vector_addition`'s launch through `sig`, written out, comparing intervals (`placeInj`) | 684 | 57 | 12 | 0.78 to 11 s | 77 s | 1 min 29 s | 4.2 GB |
| `vector_addition`'s launch through `sig`, written out, comparing intervals, one proof (`decide +kernel`) | 684 | — | 1 | — | 64 s | 1 min 14 s | 9.1 GB |
| `vector_addition`'s launch through `sig`, the start and the run evaluated by the kernel (`trSig_run`, `decide +kernel`) | 684 | — | — | — | — | 91 to 92 s in `lake build` | 15.6 GB |

The two ring rows are MojoProofTest/GPUProof/Chunks.lean (`ring11_racy_chunks` and
`ring37_racy_chunks`). The third row, the launch by chunks comparing bytes, is
MojoProofTest/RacySig.lean's `MojoProofTest.RacySig.vadd_sig_racy` before `sig` gave `placeInj`
("The second measurement" below), which took 4 min 43 s to 5 min 47 s in `lake build` (two
builds); its second figures are a measurement of the same theorem alone, just before the change.
The fourth row is the same tactic on the same trace after it, measured alone; the module no longer
uses chunks. The fifth row is `vadd_sig_racy` now, in MojoProofTest/RacySig.lean: one proof by
`decide +kernel`, measured alone (54 s in `lake build`). The evaluator's part is small: each of
its four evaluations in that module (the trace written out and the three `#guard`s) took 0.4 to
1.2 s when the module used chunks, with 0.6 s for the tactic, and `decide +kernel`'s tactic now
takes under 1 ms. A chunk's time grows with the accesses kept before it, which
each access of the chunk is checked against, from 2.7 s for the first 57 positions to 41 s for the
11th chunk comparing bytes, and from 0.78 s to 11 s comparing intervals. The sixth row,
`trSig_run`, is MojoProofTest/RacySigRun.lean, a module of its own.

**Fewer pairs.** The pass keeps the accesses that write apart from the others, each with its
position and its bytes (`Scan.writes`, `Scan.reads`), and checks a pair only when one of its
accesses writes:

* What is checked. At each access `b`, every write kept before it and, when `b` writes, every
  other access kept before it too (`Scan.step`). For each such access `a`, in this order
  (`Scan.races`): the order, that is, `b`'s clock at `a`'s position when the proxies are the same
  (one comparison of proxies and one `Nat.testBit`), then each fence kept from `a`'s proxy to
  `b`'s; then whether `a` and `b` share a byte (`Sig.share`): on a machine that gives
  `placeInj`, by one comparison of buffers and four of numbers (`Access.meets`), and on the
  others by the bytes the pass built once when it kept each access (`Access.locs`); then the
  machine's exemption (`Sig.exempt`).
* Why a pair the pass does not check cannot race. Two accesses that do not write do not conflict,
  since `Access.conflict` needs a write, so `racePair` is false on them, and the pass never checks
  such a pair. A pair that the order check finds ordered fails `racePair` whatever its
  bytes, so its bytes are never compared, and a pair that shares no byte does not conflict
  whatever the exemption, so the exemption is never asked. `Scan.Inv.races_iff` says that the
  check equals `racePair` on every pair of which one access writes, and `racy_scan` covers the
  other pairs by `Access.conflict`, so `racy_iff` keeps its statement.
* The cost, on a trace of `E` events, of which `A` are accesses and `R` of those do not write,
  with `G` agents, `F` fences and at most `ℓ` bytes per access. Each event joins the clocks of
  its `m` agents: `m` lookups and `m` updates in the list of at most `G` agents seen. Each access
  places its bytes once (`ℓ` calls of `Sig.place`), which the pass keeps and, on a machine that
  gives `placeInj`, never compares. The pass visits `A(A−1)/2 − R(R−1)/2` pairs, each a
  comparison of proxies, one `Nat.testBit` and about five operations for each fence kept before
  it, and each pair that nothing orders compares at most `ℓ·ℓ` bytes, or makes five comparisons
  with `placeInj`. With at most `m` agents per event, that is at most `E·m·G` steps for the
  clocks, `A·ℓ` placements, and `(A(A−1)/2 − R(R−1)/2)·(2 + 5F + ℓ·ℓ)` for the pairs, or
  `(A(A−1)/2 − R(R−1)/2)·(7 + 5F)` with `placeInj`. The clock pass visited all `A(A−1)/2`
  pairs and built the bytes of both accesses (`2ℓ` placements) at each pair of which one writes
  and that nothing orders.

On the launch of `vector_addition` through `sig` (684 accesses, 100 of them writes, 128 threads,
no fence and no barrier, 4 or 8 bytes per access), 170,236 of the 233,586 pairs are of two
accesses that do not write and are skipped, and 63,350 are visited. Of those, 62,850 are not
ordered and none shares a byte. Comparing bytes, the byte comparisons are the same as in the
clock pass, 1,615,200, and the placements fall from 655,200 to 4,272, one for each byte of each
access; by chunks (above), the kernel checked those pairs in 266 to 283 s, in 12 chunks of 57
positions, where one proof of the launch was out of memory at 24 GB. Comparing intervals, since
`sig` gives `placeInj`, the 62,850 pairs are 62,850 checks of intervals (`Access.meets`) and no
two bytes are compared: 77 s by the same chunks, and 64 s and 9.1 GB in one proof.

**Checking the bytes first, measured and not taken.** `Scan.races` checks the order before the
bytes. Two variants, each a copy of `Scan.races`, `Scan.step` and `scan` in a scratch file outside
the library, checked by `decide +kernel` beside the body above, one process under 24 GB, kernel
time from `set_option profiler true`:

| check | body above | bytes first (`Sig.share`, then order, then exemption) | buffers first under `placeInj`, then the body above |
|---|---|---|---|
| `vadd_sig_racy` (684 events, through `sig`) | 45.3 s, 9.0 GB | 25.1 s, 6.7 GB | 37.6 s, 7.9 GB |
| `toy`, ring of 8 with the barrier | 160 ms, 200 ms (two runs) | 269 ms, 226 ms | 195 ms |
| `toy`, ring of 8 without it | 75 ms, 80 ms | 113 ms, 90 ms | 91 ms |
| `aliased`, `twoBufs 7` | 3.6 ms, 3.5 ms | 5.4 ms, 5.2 ms | 4.3 ms |
| `toy`, `twoBufs 7` | 2.7 ms, 2.6 ms | 2.6 ms, 2.4 ms | 1.8 ms |

Bytes first is 1.8 times faster at the launch, where no pair is ordered and no two accesses of
different buffers meet, but 1.1 to 1.7 times slower on the small traces, where most pairs are
ordered by the barrier and the order check is the cheaper one; on `aliased` it compares bytes
before the order. The second variant is slower than 1.2 times on `aliased` and saves a sixth at
the launch. Neither meets the rule (faster at the launch and at most 1.2 times slower on the small
tests), so the body is unchanged.

**Visiting the pairs sorted by `Sig.key`, measured and not taken.** `Sig.key` numbers bytes, not
intervals, and a numbering need not follow the offsets: `sig`'s, `Nat.pair` of the block and of
the offset folded onto `Nat`, puts the bytes of other blocks between two bytes of one block, and
the default, which `toy` and `aliased` keep, gives every byte `0`. So the variant sorts bytes, as
`kept` does. It is a copy of the pass in a scratch file outside the library, in two parts:

* The pass for the clocks alone: `Scan.step` without the checks, keeping each access with its
  position and its clock.
* Then each byte of each access (`Access.locs`), with the access, sorted by `Sig.key`
  (`keySort`). Each entry is compared with the next entries of its number, and only when the
  bytes are equal. Each such comparison checks, in this order, that one of the two accesses
  writes, then the order (the later access's clock, and every fence: a fence after the later
  access is not in its clock), then the exemption.

Two accesses that share a byte are compared once for each byte they share, and no others are.
At the launch, each of the 4,272 bytes is a byte of one access only, so no pair is compared.

The measurement was made in one process under 24 GB, the sorted visit first at the launch, with
the small tests twice each. Kernel time is the time of `addDecl` of the `decide` proof term (as
SymBench's `#ktime`); peak memory is the process's `VmHWM`:

| check | body above | sorted visit |
|---|---|---|
| `vadd_sig_racy` (684 events, through `sig`) | 60.7 s, 9.0 GB | 36.3 s, 7.6 GB |
| `toy`, ring of 8 with the barrier | 200 ms, 199 ms | 242 ms, 246 ms |
| `toy`, ring of 8 without it | 103 ms, 82 ms | 123 ms, 123 ms |
| `aliased`, `twoBufs 7` | 4.3 ms, 6.0 ms | 20.4 ms, 21.0 ms |
| `toy`, `twoBufs 7` | 3.9 ms, 3.3 ms | 43.7 ms, 41.8 ms |

On a busier box, the body above took 60.7 s at the launch here, against 45.3 s in the table
before. The sorted visit is 1.7 times faster at the launch. It is slower on every small test,
pairing each of its runs with each of the body's: 1.21 to 1.24 times on the ring with the barrier,
1.19 to 1.50 times on the ring without it, 3.4 to 4.9 times on `aliased` and 10.7 to 13.2 times
on `toy`'s `twoBufs 7`. Three of the four are over 1.2 times in every pairing.

Where the time goes on `toy`'s `twoBufs 7` (2 accesses, 14 bytes), each part checked on its own:

* the pass for the clocks: 2.4 ms;
* the 14 entries: 6.5 ms;
* their sort: 23.4 ms (`keySort` on 14 bare numbers alone takes 13.7 ms);
* the walk over the sorted entries: 38.5 ms;
* the whole check: 49.6 ms, against 4.4 ms for the body above in the same run.

The sort alone costs more than 1.2 times the body's whole check, so no visit that sorts in the
kernel meets the rule on that test. With `sig`'s numbering on `toy` and `aliased`, the four small
tests take 211, 156, 24 and 33 ms, no better. The body, `Scan.Inv` and `racy_iff` are unchanged,
and the variant's proof is not written.

On a machine without `placeInj`, a pass that checks each access only against the earlier accesses
that share a byte with it would skip the 62,850 visited pairs that share none. Bytes are `S.Loc`,
a type with decidable equality and a numbering (`S.key`) that may give every byte the same number
(its default), so a map from bytes is an association list, with a lookup linear in the bytes
seen: up to `A·ℓ·D` comparisons with `D` distinct bytes. The launch has 4,272 distinct bytes,
each in one access only, so that is about 9.1 million comparisons, more than the 1.6 million that
the pass makes comparing bytes. Such a map pays only on traces with fewer distinct bytes than
accesses, or, kept sorted by `S.key` as `kept` sorts its bytes, on a machine whose numbering gives
different bytes different numbers.

**The law on `place`.** With `place` injective (`S.place b i = S.place b' i' → b = b' ∧ i = i'`),
two accesses share a byte exactly when they are of the same buffer and their intervals of offsets
meet (`Access.meets_iff`, under `PlaceInj`). A machine gives that proof as `placeInj` (departure 9),
and `racy` then compares one buffer and four numbers per pair (`Sig.share`) in place of up to
`ℓ·ℓ` bytes: at the launch, 62,850 checks of intervals in place of 1.6 million byte comparisons. A
machine without it keeps the byte test, and `racy_iff` is unchanged for every machine
(`Sig.share_iff`). Both machines place byte `i` of buffer `b` at `(b, i)`
(`MojoProofTest.GPUProof.Toy.toy` and `MojoProof.Sem.sig`) and give the proof by `Prod.mk.inj`.
`MojoProofTest.GPUProof.Race.aliased`, `toy` with every buffer placed at buffer `0`'s bytes and no
`placeInj`, races on two writes of different buffers, which `Access.meets` would pass, at 3 and 7
bytes (`aliased_Racy`, by `decide +kernel`).

Measured with `set_option profiler true`, each check alone with asynchronous elaboration off, one
process under a limit of 24 GB:

* `vector_addition`'s launch through `sig` (the table of "By chunks" above): 266 s of kernel time
  by chunks before, 77 s by the same chunks after, and 64 s in one proof (9.1 GB), where one
  proof comparing bytes was out of memory at 24 GB. `MojoProofTest.RacySig.vadd_sig_racy` is now
  that one proof.
* The traces of the tests written out, on two copies of each machine that differ only in
  `placeInj` (`some` and `none`), in one process: the ring at 8 threads 81 ms comparing intervals
  and 95 ms comparing bytes, its mutant 24 ms and 25 ms, the ring at 32 threads 1.17 s and 1.19 s,
  and the traces through `sig` of MojoProofTest/Determinism.lean and ScheduleOwned.lean, of 2
  events each, 3 to 5 ms and 4 to 8 ms.
* The `decide +kernel` tests as they are, two runs before and three after. The box was busier
  during the first two runs after, when the `kept` tests, which the change does not touch, took 5
  to 10% longer; the figures after are the third run's, on a box about as busy as before:
  `ring_racy_kernel`'s two traces 154 to 173 ms and 75 ms before, 162 ms and 72 ms after; the
  Laminar and Uses tests on `toy` 2.7 to 14 ms before and 2.6 to 9.4 ms after; the tests through
  `sig` in MojoProofTest/Determinism.lean, ContractOff.lean, ScheduleOwned.lean and SkelStep.lean
  under 1 ms to 96 ms before and under 1 ms to 86 ms after. Those traces have 0 to 4 events, and
  most of each test's time is in computing its trace, which the change does not touch: the
  literal traces of the item above take 3 to 8 ms.

**`kept`'s cost.** `GPUProof.kept` walks the trace once and collects the bytes of the accesses
that write and the bytes of the frozen ones (`GPUProof.keptFrom`), sorts the two lists by the
machine's numbering of bytes (`GPUProof.keySort` at `S.key`), and walks the two sorted lists
once (`GPUProof.disjointSorted`). On a trace of `A` accesses, `W` of which write and `Z` are
frozen, with at most `ℓ` bytes per access, the two lists have `B ≤ (W + Z)·ℓ` bytes: the sort
makes about `B·log₂ B` comparisons of numbers, and the walk compares each byte written with the
frozen bytes of its number only. When the numbering gives different bytes different numbers, as
`MojoProof.Sem.sig`'s does, a frozen byte of that number is that byte, so the walk compares no
two bytes when no write meets a frozen byte; at the default numbering, which gives every byte `0`
(`MojoProofTest.GPUProof.Toy.toy`'s), it compares each byte written with all the frozen bytes,
`W·ℓ·Z·ℓ` comparisons. The body before collected the frozen bytes once, without repeated lists
(`List.eraseDups`), and searched them from their start for each byte written: with `Z'` distinct
lists of `D` bytes together, at most `Z·Z'` comparisons of lists and `W·ℓ·D` of bytes, all of
them when no write meets a frozen byte. The body before that checked each write against every
access of the trace and built the bytes of both at each frozen one: `W·A` pairs. Bytes are
`S.Loc`, with decidable equality and the numbering `S.key` (`GPUProof.Sig.key`, a field with a
default, so that no machine has to give one); `GPUProof.kept_iff` holds for every numbering.

The evaluator tests (`lake test`, after `lake build mojoproof_test`, under a limit of 16 GB) check
`kept` through `sig` on every run with `race` (`MojoProofTest.runF32`, `MojoProofTest.runText`).
They took 43 min 52.60 s with the first of those bodies, 5 min 44.96 s with the second
(peak 1.89 GB; 5 min 37.12 s and 5 min 39.61 s in later runs), 2 min 43.11 s with this one
(peak 1.89 GB; the build of `mojoproof_test` before them 29.58 s, peak 3.26 GB; no stack sampled),
and 3 min 16.87 s when they checked MojoProof's own form of the promise (since removed), which
compared each write with each frozen load as intervals of one block's offsets
(`MojoProof.Sem.Access.overlaps`): `W·Z` comparisons of a block and two offsets, with no list of
bytes. The second body's cost was in `tiled_matmul`'s 4,096-thread launch
(`MojoProofTest.matmulTests`): of 10 stacks of the test process sampled 30 s apart, all were in
`MojoProofTest.runF32` at that launch, 6 in `List.elem` through `sig`'s equality of bytes, in
`GPUProof.kept`, and 4 in the run itself (`MojoProof.Sem.Grid.run`). By the kernel's shape, each
thread writes 9 floats (8 to the tiles in shared memory, 1 to the output) and makes 8 frozen
loads (`!invariant.load` of the two inputs), so `W·ℓ` = 147,456 bytes written and `Z·ℓ` = 131,072
frozen bytes (`Z` = 32,768, `Z'` = 8,192, `D` = 32,768). The first body checked 36,864 writes
against about 600,000 accesses (`W·A`), MojoProof's form made about 1.2 billion comparisons of
intervals (`W·Z`), the second body about 4.8 billion comparisons of bytes and at most 268 million
of lists, and this one sorts `B` = 278,528 bytes, about 5 million comparisons of numbers
(`log₂ B` ≈ 18), then compares no two bytes, since no byte written there has the number of a
frozen byte.

In the kernel (`decide +kernel`), at the tests' sizes, the sort costs more than it saves: the
core's tests on `MojoProofTest.GPUProof.Toy.toy` at 3 and 7 bytes take 4 to 10 ms each in place
of 3 to 5 ms, and the tests on traces of `MojoProof.Sem.sig` in MojoProofTest/Determinism.lean,
ContractOff.lean, ScheduleOwned.lean and SkelStep.lean take under 1 ms to 65 ms in place of
under 1 ms to 62 ms (each check timed alone, with asynchronous elaboration off). At the launch of
`vector_addition` through `sig` it pays in the kernel too: `MojoProofTest.RacySig.vadd_sig_kept`,
`kept sig trSig = true` by `decide +kernel` on the 684 accesses of `MojoProofTest.RacySig.trSig`
(100 of them writes and 200 frozen loads), takes 3.4 s of kernel time, measured alone (10.6 s and
3.6 GB for the process), where `racy` on the same trace takes 64 s. Since `sig`'s numbering gives
different bytes different numbers, its walk compares no two bytes there.

**The second measurement, one summary check through `sig`**, the MojoProof machine's signature,
with its translation of MojoProof's trace events (`MojoProof.Sem.Event.toCore`,
MojoProof/Sem/SigDef.lean):

1. the trace of `vector_addition`'s launch above through that translation, `racy sig tr = false` in
   the kernel, in the test module MojoProofTest/RacySig.lean. `MojoProofTest.RacySig.trSig` is the
   trace that `sig` reads from the run (`MojoProof.Sem.Event.toCore` of the trace of
   `MojoProof.Sem.Grid.run` on the launch of `MojoProofTest.vaddTests`, reversed), 684 events,
   oldest first, written out by `trace_literal%`, with a `#guard` that it is the run's and a `#guard
   !racy sig trSig` (the evaluator). Comparing bytes, one proof by `decide +kernel` was out of
   memory at 24 GB, after 2 min 21 s, as on the toy machine, and `racy_by_chunks 57` proved it in
   12 chunks and 266 to 283 s of kernel time with a peak of 8.4 to 8.5 GB ("By chunks" above).
   Comparing intervals (`placeInj`, "The law on `place`" above),
   `MojoProofTest.RacySig.vadd_sig_racy` proves it in one proof by `decide +kernel`, in 64 s of
   kernel time with a peak of 9.1 GB, and depends on the axioms `propext`, `Classical.choice` and
   `Quot.sound` only. `MojoProofTest.RacySig.vadd_sig_kept` proves `kept sig trSig = true` the
   same way, in 3.4 s ("`kept`'s cost" above).
   `MojoProofTest.RacySig.vaddTrace` is the run of `MojoProofTest.gridF32` (from the start
   `MojoProofTest.startF32`), the run `MojoProofTest.runF32` checks. In
   MojoProofTest/RacySigRun.lean, `MojoProofTest.RacySig.trSig_run` proves by `decide +kernel` that
   `trSig` is that run's trace through `sig` (91 to 92 s in `lake build`, 15.6 GB), and
   `MojoProofTest.RacySig.vadd_run_racy` that the run succeeds and its trace through `sig` is race
   free;
2. take one summary check of scripts/SymBench.lean, `k21` (`covers` on `vector_addition`'s block
   `%21`), state its obligations through `sig`'s operations instead of MojoProof's, and prove it
   by `decide +kernel` in a file of its own under the same memory limit. This step needs a design
   first: `covers` checks MojoProof's symbolic terms by their structure, and its obligations
   (`Cond`: `ok`, `bool`, `mem`, MojoProof/Sym/Term.lean) meet MojoProof's operations only when
   evaluated (`Cond.Holds`, through `SNode.eval` and `SEff.run`). `sig`'s fields are on bytes,
   metadata, combination, placement and exemption, not on terms, so only a `mem` obligation has a
   counterpart. Stating `k21` through `sig` needs an obligation type over `sig`'s fields and a
   checker proved sound against `SEff.run` (the design below);
3. record the kernel's time and the peak memory of each, beside SymBench's own time for `k21`
   (its `#ktime` line) and the evaluator's ("Step 3, the measurement" below).

**A design for step 2 (its first step is Lean).** The `ok` and `bool` obligations are about values (an
operand that faults, a branch on poison) and have no counterpart in `sig`'s fields: they stay
MojoProof's. A `mem` obligation says that the block's effects `es` run (`SEff.run`), and each
effect's faults depend on the metadata of one buffer, not on its bytes:

* a `store` faults (`MojoProof.Sem.Mem.write`, `MojoProof.Sem.Mem.check`) when its pointer's
  block has no metadata (`sig.metaAt`), is not live, is read-only or is not the thread's, when
  its offsets `off` to `off + n − 1` leave `0` to the block's `size`, or when its address (the
  block's `addr` or `gaddr`, by the pointer's space, plus `off`) is not aligned: each a test of
  the `BlockMeta` that `sig.metaAt` gives and of the offset. It also faults when the value does
  not encode at its type, a condition on the value;
* a `load` faults in `SEff.apply` only when its pointer is not one: its access is checked by its
  node (`SNode.load`, under an `ok` obligation), which reads the bytes;
* an `alloca` faults when its count does or when the block number it takes has metadata already.

A store changes bytes only (`MojoProof.Sem.Block.put`) and an `alloca` adds one block, so the
metadata before each effect is the entry memory's with the blocks of the earlier `alloca`s added.
The obligation type would be `sig`'s, not the core's, whose `Meta` is opaque: for each effect,
its pointer and value as terms (`SVal`) and its test on the metadata of the pointer's block,
checked without writing a byte. Its checker is sound when the tests give `Cond.Holds` of
`.mem es`, by induction on `es` (`SEff.run_snoc`), from three facts of MojoProof/Sem:
`Mem.write` keeps each block's metadata, `Mem.check` succeeds when the tests pass, and
`Mem.alloc` adds the block it makes. Step 3 would then compare the kernel's cost of `k21`'s `mem`
obligations in that form with `Cond.Holds`'s, which runs each store into the blocks' bytes.

The first step is MojoProof/Sym/MetaRun.lean. The obligation stays `Cond.mem es`, and its checker
is `MojoProof.Sym.SEff.runMeta`: the effects in order on the blocks' metadata (`Metas`, which is
`sig.metaAt` of the blocks), from the entry memory's, by `SEff.applyMeta`, which writes no byte.
A `store` evaluates its value and pointer, encodes the value and runs `Metas.write` (the checks of
`Mem.write`, from `Mem.check`, on metadata) and keeps the metadata; a `load` evaluates its
pointer; an `alloca` evaluates its count, refuses a number with metadata and adds the metadata of
the block `SEff.apply` makes. `MojoProof.Sym.SEff.holds_iff_runMeta`: `Cond.Holds` of `.mem es` exactly when `runMeta`
succeeds, for every valuation, table of node values and list of effects, with no premise. Each
direction's proof is by induction on `es` from the front (`MetaAgree.foldlM`, with `List.foldlM_cons`) in
place of `SEff.run_snoc`, since the invariant (`MetaAgree`: the memory has the metadata) is carried
forward; its three facts are `MetaAgree.write` (a write that passes on metadata succeeds and keeps
the metadata), `MetaAgree.addr` (`Mem.addr` reads metadata only, so it gives on the memory what it gives on
`Metas.mem`, the memory of the metadata with poison bytes) and the `alloca` case of
`MetaAgree.apply`. The converse direction is `MetaAgree.foldlM_ok`, from `MetaAgree.write_ok` and
`MetaAgree.apply_ok`: what succeeds on a memory succeeds on its metadata, with the same invariant. The test
(MojoProofTest/MetaRun.lean) is one program (vector_addition) at one launch: thread 5 run by the
evaluator to the first block whose summary has a store, where `runMeta`, `SEff.run` and
`Cond.Holds` all succeed, and a mutant with every block read-only, which `runMeta` and the run
both refuse (`#guard`s, the evaluator's).

**Step 3, the measurement.** Each check timed in one to three rounds, in a file of its own outside
the build that imports MojoProofTest/MetaRun.lean and copies SymBench's `#ktime` (the time of
`addDecl` on the proof `decide +kernel` builds, with `Elab.async` off), through `lake env lean`
under a 16 GB limit, on 8 cores of a machine whose other cores ran other builds. The valuation is
the one of the test MojoProofTest/MetaRun.lean, at `%21`'s entry: thread 5 of `vector_addition`,
from the start `MojoProofTest.startF32` makes, run by the evaluator to the block.

* `k21` itself (`covers` on `%21`'s summary `s21`, 9 obligations) takes 62 to 101 ms in five
  measurements in the copy, and 66 ms in SymBench's table (docs/automation.md, "Benchmark").
  `covers` evaluates no obligation. One of the 9 is `mem`, of the summary's three effects: two
  `load`s and one `store`.
* The `mem` obligation at the valuation, in the kernel, through `runMeta` (`(SEff.runMeta V vs
  es).toBool`), `SEff.run` (`(SEff.run V vs es).toBool`) and `Cond.Holds` (`decide`), with `vs =
  vals V s21.nodes`. The kernel evaluates the launch's start and the thread's run to the block
  first, and that is most of the time. At MetaRun.lean's launch (4 blocks of 32 threads, 100 floats
  a buffer): the valuation alone 4.8 and 5.0 s; with the obligation 5.5 and 5.9 s through `runMeta`,
  5.2 and 6.3 s through `SEff.run`, 5.6 s through `Cond.Holds`. At a launch of 1 block of 8 threads
  and 8 floats a buffer: the valuation 0.65 to 0.76 s, the node values 0.67 to 0.78 s, and with the
  obligation 0.82 to 0.87 s through `runMeta`, 0.82 to 0.88 s through `SEff.run`, 0.63 and 0.84 s
  through `Cond.Holds`. The process's peak memory is 3.3 GB at the small launch and 3.75 GB at the
  larger one, and no check adds more than 25 MB to it.
* Scaled: `s21`'s effects 10, 50 and 200 times over (30, 150 and 600 effects, the stores at one
  address), at the small launch. Through `runMeta` 0.60 s, 0.57 and 0.60 s, 0.68 s; through
  `SEff.run` 0.58 s, 0.67 and 0.70 s, 1.07 s; the valuation alone 0.50 and 0.56 s. At 600 effects
  the check on metadata costs about 0.15 s above the valuation and the run on the memory about 0.55
  s, and the run adds 50 MB to the peak, the check on metadata nothing.
* The evaluator (compiled; 20000 checks, 2000 when scaled, each at one valuation): the node values
  160 to 200 µs a check; with the obligation 200 to 290 µs through `runMeta` and 210 to 300 µs
  through `SEff.run`; at 600 effects 4.2 and 4.5 ms against 4.7 and 5.2 ms.

What it shows: at `k21` the obligation's cost is below the spread of the valuation's, through either
check, so `runMeta` gains nothing measurable there; the summary's one `store` writes 4 bytes once.
The difference grows with the number of stores: at 600 effects the run on the memory costs three to
five times the check on metadata in the kernel, and the evaluator is 2 to 15 percent slower on it
than on `runMeta` at every size.

## The laws (statements only)

These are the design's laws, over a machine `S` with `{s₀ s s' : S.State}`. `Levels` is Lean
(`GPUProof/Laminar.lean`, with the same six fields), and so is `OneRun` (`GPUProof/Sound.lean`,
with the same five fields; its first instance is `OneRun sig`). `Place` is the proposition
`PlaceInj` (`GPUProof/Sig.lean`, its two fields in one statement; `toy` and `sig` prove it,
departure 9). The others are not Lean yet,
and most of them name predicates that are not defined yet (`SameStatus`, `slotAt`, `NoConflict`,
`FireMembers`, `FreshOwn`, `KeepsCaller`, `FreshCells`, `AgentsOf`, `CallsAt`, `Delivers`,
`OrderEvents`, `Waiting`, `WaitThread`, `NoEscape`, `ArgsIn`, `CallerPart`,
`FloatResultsReadOwnSite`).

```lean
class OneRun (S : Sig) : Prop where
  confluent : GoodStart S s₀ →
    Confluent (fun x y : {s // Reach S s₀ s} => Step S x.1 y.1)
      (fun x y => S.Same x.1 y.1) (fun x => Bad S x.1)
  same_done : Live S s₀ s → Live S s₀ s' → S.Same s s' → Done S s → Done S s'
  same_bytes : Live S s₀ s → Live S s₀ s' → S.Same s s' → S.bytes s = S.bytes s'
  done_final : Live S s₀ s → Done S s → ¬ Step S s s'
  done_safe : Live S s₀ s → Done S s → ¬ Faults S s

class Local (S : Sig) : Prop where
  advance_logs : Live S s₀ s → S.advance s a = .ok (some s') →
    S.trace s' = S.trace s ++ S.pending s a
  fire_logs : Live S s₀ s → S.fire s t = .ok (some s') →
    S.trace s' = S.trace s ++ S.firePending s t
  pending_who : e ∈ S.pending s a → e.agents = [a]
  advance_run : Live S s₀ s → Running S s a → S.advance s a ≠ .ok none
  advance_agree : Live S s₀ s → Live S s₀ s₂ → S.Agree s a s₂ → S.advance s a = .ok (some s') →
    ∃ δ, s' = S.apply s a δ ∧ S.advance s₂ a = .ok (some (S.apply s₂ a δ))
  agree_of_reads : Live S s₀ s → Live S s₀ s₂ → SameStatus S s s₂ a →
    (∀ x ∈ S.reads s a, slotAt S (S.bytes s) x = slotAt S (S.bytes s₂) x) → S.Agree s a s₂
  advance_agree_other : Live S s₀ s → a ≠ b → NoConflict S (S.pending s a) (S.pending s b) →
    S.advance s a = .ok (some s') → S.Agree s b s'
  fire_agree_other : Live S s₀ s → b ∉ FireMembers S s t →
    NoConflict S (S.firePending s t) (S.pending s b) → S.fire s t = .ok (some s') →
    S.Agree s b s'
  fresh_own : Live S s₀ s → FreshOwn S s

class Start (S : Sig) : Prop where
  ok : S.ValidLaunch L → S.StartOk P L → S.ArgsOk P args m → S.Closed m args →
    ∀ ω, ∃ s₀, S.start P L args m ω = .ok s₀
  launch : S.start P L args m ω = .ok s₀ → S.launchOf s₀ = L
  threads : S.start P L args m ω = .ok s₀ → ∀ t ∈ S.threads L, ∃ u, S.status s₀ t = .run u
  clean : S.start P L args m ω = .ok s₀ → S.jobs s₀ = [] ∧ S.trace s₀ = []
  keeps : S.start P L args m ω = .ok s₀ → KeepsCaller S (S.memBytes m) (S.bytes s₀)
  cells : S.start P L args m ω = .ok s₀ → FreshCells S m (S.launchCells s₀) (S.bytes s₀)

class Levels (S : Sig) : Prop where
  mem_members : u ∈ S.members L g ↔ u ∈ S.threads L ∧ S.group L (S.levelOf g) u = g
  levelOf_group : S.levelOf (S.group L ℓ t) = ℓ
  nest : ℓ ≤ ℓ' → S.group L ℓ t = S.group L ℓ u → S.group L ℓ' t = S.group L ℓ' u
  top : t ∈ S.threads L → (S.members L (S.group L ⊤ t)).Perm (S.threads L)
  bot : t ∈ S.threads L → S.members L (S.group L ⊥ t) = [t]
  nodup : (S.threads L).Nodup ∧ (S.members L g).Nodup

class Machine (S : Sig) extends OneRun S, Local S, Start S, Levels S : Prop

structure Rendezvous (S : Sig) (k : S.CollKind) where
  members : S.Launch → S.Tid → S.Call → List (Agent S.Tid S.Job)
  within : ∀ L t c, ∀ a ∈ members L t c, a ∈ AgentsOf S L (S.group L (S.level k) t)
  agrees : (S.Tid → S.Call) → Prop
  accepts : S.Call → Prop
  result : (S.Tid → List S.Val) → S.Bytes → S.Tid → Option S.Val
  accesses : (S.Tid → S.Call) → List S.Access
  result_footprint : ∀ c b b', (∀ a ∈ accesses c, ∀ l ∈ Access.locs S a,
    S.byteAt b l = S.byteAt b' l) → result (S.operandsOf ∘ c) b = result (S.operandsOf ∘ c) b'
  update : (S.Tid → S.Call) → S.Bytes → S.Bytes
  ready : S.State → S.Tid → Prop
  fire : ∀ s₀ s t c, Live S s₀ s → ready s t → CallsAt S s (members (S.launchOf s) t (c t)) c →
    agrees c → (∀ j, accepts (c j)) → Delivers S s c (result (S.operandsOf ∘ c) (S.bytes s)) →
    ∃ s', S.fire s t = .ok (some s') ∧ S.bytes s' = update c (S.bytes s) ∧
      S.firePending s t = (accesses c).map .access ++ OrderEvents S k s t c ∧
      ∀ j ∈ Waiting S s (members (S.launchOf s) t (c t)),
        S.status s' j = .run (S.resume (WaitThread S s j) (result (S.operandsOf ∘ c) (S.bytes s) j))
```

* `OneRun`: what the one-run theorem needs (`Confluent` is `GPUProof.Confluent`, in Lean).
* `Local`: a step logs exactly its pending events, reads only what `reads` names, and a running
  agent never stalls.
* `Start`: a checked launch starts for every choice, with its threads running, no jobs and an
  empty trace.
* `Levels`: at every level the instances partition the threads, finer instances lie in coarser
  ones, the top instance is the launch and a bottom one is a thread.
* `Rendezvous`: what a machine proves of one collective kind from its `fire`. A member's result is
  computed from the members' operands and the bytes at the fire, since a collective that loads
  memory into registers (PTX's `ldmatrix`) delivers memory words. `result_footprint` says it reads
  only the bytes of the call's `accesses`. A barrier or a shuffle has no accesses, so its result
  depends on the operands alone. `members` is a function of one call. So a barrier whose members
  depend on the order of arrival, such as PTX's counted `bar.sync a, b`, needs a quorum form of
  `Rendezvous`, which this version does not have.

The optional laws, each used only by the theorems that name it:

```lean
class Place (S : Sig) : Prop where
  inj : S.place b i = S.place b j → i = j
  disjoint : b ≠ b' → S.place b i ≠ S.place b' j

class Atomic (S : Sig) : Prop where
  right_comm : S.commutes op = true →
    (S.combine op x y).bind (S.combine op · z) = (S.combine op x z).bind (S.combine op · y)
  exempt_rmw : S.exempt a b = true → ∃ op, S.commutes op = true ∧ a.kind = .rmw op ∧
    b.kind = .rmw op ∧ a.buf = b.buf ∧ a.off = b.off ∧ a.len = b.len ∧ a.proxy = b.proxy

class OneRunUpTo (S : Sig) (E : S.State → S.State → Prop) : Prop

class Stream (S : Sig) : Prop where
  closed : S.start P L args₀ m₀ ω = .ok s₀ → Reach S s₀ z → Done S z → NoEscape S m₀ z →
    ArgsIn S args₁ m₀ → S.Closed (S.endLaunch m₀ z) args₁
  keeps : S.start P L args₀ m₀ ω = .ok s₀ → Reach S s₀ z →
    CallerPart S m₀ (S.memBytes (S.endLaunch m₀ z)) = CallerPart S m₀ (S.bytes z)

class Choices (S : Sig) : Prop where
  site_local : FloatResultsReadOwnSite S
```

* `Place`: the bytes of one buffer are distinct and two buffers share none, so overlap is decided
  by intervals (`GPUProof.Access.meets_iff`). In Lean it is the proposition `GPUProof.PlaceInj`
  (departure 9).
* `Atomic`: updates by a commuting operation right-commute, and the exemption covers only
  unused-result updates of one interval by one commuting operation through one proxy. The race
  check (`Access.conflict`) trusts `S.exempt` as it is, so the exemption is sound only through
  this law, and the law needs `S.commutes op = true`: without it a machine could exempt two
  unused-result exchanges of one byte (`combine old v = some v`), and the two orders of the
  exchanges would leave different bytes.
* `OneRunUpTo`: confluence up to a coarser equivalence, for float atomics.
* `Stream`: the launch boundary frees the launch's own slots and leaves a caller memory that the
  next start accepts.
* `Choices`: a float result reads only the choice at its own site.

The design also names `Summarizer`, `Device` and `Weak`, with no fields yet.

## The test machine (`MojoProofTest/GPUProof/Toy.lean`)

**Scope.** One test machine (`toy`), which names no front end: threads over a byte memory
(`Nat → Option (List UInt8)`), each running a list of instructions (`Ins`): a read or a write of an
interval of a buffer through one of two proxies (`Bool`), an unused-result addition to one byte,
a barrier of one level instance (logged as one `sync` of the instance's members; the launch's
barrier is object `0`) and a proxy fence. Its levels are `WithTop ℕ` (`0`, that is `⊥`, the
thread, `⊤` the launch, and each `k` between them blocks of consecutive threads); a launch is a
number of threads and the width of each level. There are no jobs (`Job := Empty`), and it exempts
two `rmw` updates of one interval through one proxy. Its fields `Same`, `Agree`, `Delta` and
`apply` are given (`SameSt`, `AgreeSt`, `Effect`, `applyEff`). The laws proved of it are
`Levels toy`, with `reach_laminar`: every trace it reaches from a launch is laminar for it
(`laminar.md`), and the law on `place`, which it proves once as `placeInj` (departure 9).

The tests run it at 3 and at 7 threads with a fixed schedule (`sched`, `runFor`), whose states are
reachable (`runFor_reach`). Each `#guard` is evaluated when its module is built.

* Runs (`Toy.lean`): a ring that writes its own byte, waits at the launch's barrier and reads a
  neighbor's ends with every thread returned and a trace that `racy` passes and `kept` keeps, and
  the mutant without the barrier is racy, and at 8 threads the kernel checks both
  (`ring_racy_kernel`, by `decide +kernel`); one thread's write through proxy `false` and read
  back through proxy `true` is race free with a fence from `false` to `true` between them, and
  racy without
  the fence or with the fence reversed; `n` additions to one byte are exempt and leave `n`; a
  write past the end of the buffer faults. Each run test checks that the schedule stopped
  (`stopped`, beside `allDone`), since `final` runs a bounded number of steps: one thread's 21
  writes outlast its 20 steps at one thread, and `stopped` says so.
* Traces (`Race.lean`), for each event form a trace that `racy` passes and one it refuses, and a
  mutant for every rule of the check:
  * `Access.conflict`: the write moved onto the other's last byte; a read made a write (either
    one); an exempt update with its result used, another interval, or another proxy;
  * program order: one thread's accesses made two threads';
  * placement: writes to two buffers, which `toy` places apart, made on `aliased`, the mutant
    machine that places every buffer at the same bytes and has no `placeInj`; `racy` decides
    `Racy` on both (`aliased_Racy`, by `decide +kernel` through `racy_iff`);
  * `sync`: the reader left out of the members;
  * `rel` and `acq`: another phase, another object, the acquire before the release, a release
    alone, an acquire alone;
  * transitivity: a chain of `n - 1` hand-overs, and the mutant with one link broken;
  * `fence`: none, reversed, before the write, after the read; a fence by another thread after a
    rendezvous; the other direction;
  * `hb` and `ordered` on the chain and the fenced pair;
  * `kept`: a write of the next byte keeps a frozen read and one of its last byte breaks it; a
    read keeps it and an update breaks it; a write before it breaks it even when ordered, and a
    write by the same thread breaks it; `racy` passes the ordered write that breaks it;
  * `kept_iff` both ways: `Kept` from `kept` on the write of the next byte, `kept` from a proof of
    `Kept` at every size, and not `Kept` where `kept` refuses.
* `Clean` (`Clean.lean`): `own_clean`, for every number of threads `n`, width `c`, value `v` and
  memory whose buffer `0` has at least `c * n` bytes, is `Clean` of the program in which each
  thread writes `v` to its own bytes `[c t, c t + c)`. Its proof keeps an invariant (`Inv`) on
  every reachable state and a measure (`work`) that every step lowers. `own_goodStart` shows the
  start is a `GoodStart`, and `own_not_bad` that no `Live` state from it is `Bad`.
  `own_clean_zeros` is the instance on exactly `c * n` zero bytes; the `#guard`s run it at
  `(n, c) = (3, 2)` and `(7, 5)`, and check that the mutant with one byte too few faults.
* Levels (`Laminar.lean`): a byte handed from lane to lane at a warp's barrier and then to
  another warp at the launch's barrier, at two warps of 2 lanes and three warps of 5, with `hb`
  checked against `GPUProof.HB.laminar_iff` at every pair, and a release-acquire hand-over that
  is not laminar (`laminar.md`).
* Use maps (`Uses.lean`): the same hand-over race free through
  `GPUProof.racy_eq_false_of_uses`, with uses separated at every size, and a mutant for each
  premise and for each proxy clause (`laminar.md`).
