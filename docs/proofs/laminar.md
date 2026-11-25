# Laminar levels, happens-before and use maps

Lean: `GPUProof/Laminar.lean` and `GPUProof/Uses.lean`. Tests: the instance `Levels toy` and
`reach_laminar` in `MojoProofTest/GPUProof/Toy.lean`, `MojoProofTest/GPUProof/Laminar.lean` and
`MojoProofTest/GPUProof/Uses.lean`. The use maps are the section
[Use maps decide race freedom](#use-maps-decide-race-freedom).

**Scope.** `Levels` and `Laminar` are stated for every machine `S : Sig`; `Laminar.agents` holds
for every machine; `Laminar.nested` and `HB.laminar_iff` hold for every machine with `Levels`.
The instance and the tests are about one test machine (`toy`), at every number of levels and
widths for the instance and `reach_laminar`, and at two sizes for the `#guard`s.

## Definitions

**`Levels S`**, the laws of the level instances (`Sig.group`, `Sig.levelOf`, `Sig.members`), for
every launch `L`, levels `ℓ ≤ ℓ'`, instance `g` and threads `t`, `u`:

1. `mem_members`: `u ∈ S.members L g ↔ u ∈ S.threads L ∧ S.group L (S.levelOf g) u = g`;
2. `levelOf_group`: `S.levelOf (S.group L ℓ t) = ℓ`;
3. `nest`: `S.group L ℓ t = S.group L ℓ u → S.group L ℓ' t = S.group L ℓ' u`;
4. `top`: for `t ∈ S.threads L`, the members of `S.group L ⊤ t` are `S.threads L` up to order;
5. `bot`: for `t ∈ S.threads L`, the members of `S.group L ⊥ t` are `[t]`;
6. `nodup`: `S.threads L` and `S.members L g` have no repetition.

These are the six fields the design gives the class, with the same statements.

**`Laminar S L tr`**: every event of `tr` is an access, a fence, or a rendezvous `sync o ms` for
which some instance `g` of `L` has `c ∈ ms ↔ ∃ u ∈ S.members L g, c = .thread u` for every agent
`c`. So a laminar trace has no `rel` and no `acq`, and every rendezvous in it is one instance's
members, as threads, in any order and with any repetition.

## Statements

* `Laminar.agents` (every machine): an event of a laminar trace has one agent, or exactly the
  members of an instance as its agents.
* `Laminar.nested` (every machine with `Levels`): two events of a laminar trace that share an agent
  have nested agent lists, each agent of one being an agent of the other.
* `HB.laminar_iff` (every machine with `Levels`): for `hl : Laminar S L tr`,

  ```lean
  HB S tr i j ↔ i < j ∧ ∃ e e', tr[i]? = some e ∧ tr[j]? = some e' ∧
    ((∃ a ∈ e.agents, a ∈ e'.agents) ∨
      ∃ k o ms, i < k ∧ k < j ∧ tr[k]? = some (.sync o ms) ∧ (∃ a ∈ e.agents, a ∈ ms) ∧
        ∃ b ∈ e'.agents, b ∈ ms)
  ```

What the words of the design's statement ("the same agent, or some instance containing both
agents has a `sync` between them") mean here:

* **between**: at a position `k` with `i < k < j`, strictly. A rendezvous at `i` or `j` itself
  shares an agent with the other event when it orders them, so the first case covers it.
* **containing both agents**: the rendezvous at `k` has an agent of the event at `i` and an agent
  of the event at `j` among its agents. By `Laminar` its agents are the members of one instance
  `g`, so `g` contains an agent of each. For an event with several agents (a rendezvous) one of
  its agents suffices: by `Laminar.nested` the rest of them then lie in `g`, or `g` in them.
* **the same agent**: the events share an agent, at any two positions (program order relates any
  two events of one agent, `GPUProof.edge`).
* **jobs**: a job is in no instance, since an instance's members are threads, and a laminar
  trace has no rendezvous of a job. So an event of a job is ordered only with a later event that
  has that job among its agents: its own accesses and fences.

## Proof

**`Laminar.nested`.** If either event has one agent, that agent is the shared one and the
inclusion is immediate. Otherwise their agents are the members of instances `g` and `g'`, with
a common member `u`. Say `S.levelOf g ≤ S.levelOf g'` (`le_total`). By `mem_members`, `u`'s
instances at those levels are `g` and `g'`. A member `v` of `g` has `v`'s and `u`'s instances at
`g`'s level equal, so by `nest` also at `g'`'s level, which is `g'`; by `mem_members`, `v` is a
member of `g'`.

**`HB.laminar_iff`, right to left.** A shared agent is one `edge`. A rendezvous at `k` with an
agent of each event gives the edges `i → k` and `k → j`, so `HB` by `Relation.TransGen.tail`.

**Left to right.** On a laminar trace an edge is a shared agent: the release-acquire case of
`GPUProof.edge` needs a `rel` at its first position, and a laminar trace has none. The invariant,
by induction on the `TransGen` path from `i` to `m`, is: `i < m`, the events at `i` and `m` have
agents, and some position `k` with `i ≤ k ≤ m` holds an event whose agents include all the agents
of the event at `i` and all those of the event at `m`.

* One edge `i → m` with shared agent `a`: by `Laminar.nested` one of the two events' agent lists
  contains the other's, and that event's position is `k`.
* A path `i → m` with witness `k`, then an edge `m → m'` with shared agent `c`. By
  `Laminar.nested` at `m` and `m'`, either `m'`'s agents lie in `m`'s, hence in `k`'s, and `k`
  stays the witness; or `m`'s lie in `m'`'s. Then `c` is an agent of `k` and of `m'`, and
  `Laminar.nested` at `k` and `m'` gives either `k`'s agents inside `m'`'s, so `m'` is the new
  witness, or `m'`'s inside `k`'s, so `k` stays.

At the end, with witness `k` for `i` and `j`: if `k = i` the event at `i` contains an agent of
`j`'s, and if `k = j` the event at `j` contains one of `i`'s, so they share an agent. If
`i < k < j`, the event at `k` is an access or a fence, whose one agent is then the agent of both,
or a rendezvous, which is the second case.

The proof uses `mem_members` and `nest` only, through `Laminar.nested`; the other four fields
are not needed for it.

## Where the Lean form departs from the design

1. **`Laminar` names every event, not only the ordering ones.** The design reads "every ordering
   event of the trace is a `sync` of the members of one level instance". Lean says each event is
   an access, a fence or such a rendezvous, so a `rel` or an `acq` makes a trace not laminar even
   when nothing acquires what it releases. A fence orders no positions of `HB` (only `Ordered`
   reads it), so it is allowed.
2. **A rendezvous's agents equal an instance's members as sets.** The design's "a `sync` of the
   members of one level instance" fixes no list. Lean asks for the same agents in any order and
   with any repetition, so a machine may log the members in the order they arrive.
3. **The theorem names the rendezvous, not the instance.** The right side gives the position `k`
   and the agents `ms` of the rendezvous. The instance `g` with `ms`'s agents as members is
   recovered from `Laminar`, so the statement needs no `Gid` and holds on every machine with
   `Levels`.
4. **The events at `i` and `j` need not be accesses**, and the theorem relates every pair of
   positions. `racy` reads it at pairs of accesses.

## The instance `Levels toy`

The toy machine's levels are `WithTop ℕ` (`Lvl`): `0`, which is `⊥`, the thread; `⊤` the launch;
each `k` between them a level of blocks of consecutive threads. A launch is a number of threads
and a list of widths from the thread up (`toy.Launch := Nat × List Nat`). A thread `t`'s instance
of level `k` is `(k, t / span ws k)`, where `span ws k` is the product of the first `k` widths, and
its instance of `⊤` is `(⊤, 0)` (`groupOf`). Past the last width every level has the instances of
the last one. `members` filters the launch's threads by their instance (`membersOf`), so
`mem_members` holds by `List.mem_filter`. Before this, levels were `Bool` and `members n (true, k)`
was the whole launch for every `k`, while `group` gave only `(true, 0)`, so `mem_members` failed at
`(true, 1)`.

* `nest`: for `k ≤ k + d`, `span ws (k + d) = span ws k * ((ws.drop k).take d).prod`, and
  `t / (a * b) = t / a / b` (`Nat.div_div_eq_div_mul`); every level is below `⊤`, whose instance
  is the same for all threads.
* `top`: every thread's instance of `⊤` is `(⊤, 0)`, so the filter keeps every thread.
* `bot`: `span ws 0 = 1`, so the instance of level `0` is the thread itself, which occurs once in
  `List.range n`.
* `levelOf_group` is by definition, and `nodup` is `List.nodup_range` and its filter.

The barrier instruction names its level (`Ins.bar ℓ`). A thread waiting at `ℓ` completes the
barrier of its instance `g` of level `ℓ` once every member of `g` waits at `ℓ` (`allWait`); the
members of `g` run again and `sync (barObj g) (members of g)` is logged. `barObj` is `0` at `⊤`,
the launch's barrier as before, and `Nat.pair k i + 1` for instance `i` of level `k`.
`reach_laminar` shows that every state the machine reaches from `launch P n m ws` keeps `n` and
`ws` and has a trace that is laminar for the launch `(n, ws)`.

**Changed test text**, all with the old meaning (the launch's barrier is `⊤`'s, and a launch with
no widths has the levels `⊥` and `⊤` only):

* `MojoProofTest/GPUProof/Toy.lean`, `ring`: `.bar` became `.bar ⊤`.
* `MojoProofTest/GPUProof/Clean.lean`: `own_goodStart`'s launch `n` became `(n, [])`; `weight` and
  `work_lt` take `Status (List Ins) Lvl`; `step_own`'s proof no longer rewrites the barrier case.
* `MojoProofTest/GPUProof/Imports.lean`: the pinned module list gains `GPUProof.Laminar`, and its
  `#guard_msgs` compares whitespace laxly so the list may wrap.

## Tests (`MojoProofTest/GPUProof/Laminar.lean`)

`handover warp top w` runs on `nw` warps of `w` lanes (widths `[w]`): lane `t` of warp `0` waits
at `t` warp barriers, writes `t` to byte `0` of buffer `0` and waits at the other `w - 1 - t`;
then every thread waits at the launch's barrier and lane `0` of warp `1` reads the byte.
`run_laminar` gives `Laminar` for every such run, from `reach_laminar`. At two warps of 2 lanes
and three warps of 5:

* the run ends with every thread returned, the last lane's value in the byte, `2 w + 1` events,
  a trace that `racy` passes and `kept` keeps, and `hb` from the first write to the read, which
  share no agent;
* `hb` equals the right side of `HB.laminar_iff` (`viaSync`) at every pair of positions, on the
  run and on the two mutants (no warp barriers, no launch barrier), which race.

The other side: the hand-over through a release and an acquire (`relAcqTrace`) is not laminar for
any launch (`relAcq_not_laminar`), and on it `hb` orders the write before the read while
`viaSync` refuses the pair, at 3 and 7 bytes.

## Use maps decide race freedom

**Scope.** `Use`, `Use.Admits`, `isSyncOf`, `phase`, `phases`, `Use.Separated`, `phase_mono`,
`phase_lt` and `racy_eq_false_of_uses` are stated and proved for every machine `S : Sig`, with no
`Levels` and no `Laminar` premise. The tests are about one test machine (`toy`):
`handover_separated` at every number of lanes and warps, the rest at two sizes each.

### Definitions

* **`Use S`**: `writer a p` (agent `a` reads and writes the byte), `readers g p` (the members of
  instance `g` read it), `frozen p` (anyone reads it), `rmw op word p` (only result-unused updates
  by `op` of exactly the bytes `word`). Each case names the proxy `p` its accesses go through.
* **`Use.Admits S L u x`**: `x` goes through `u`'s proxy, and is by `a` (`writer`); is a read or a
  frozen read (`Kind.writes = false`) by a member of `g`, as a thread (`readers`); is a read or a
  frozen read (`frozen`); or has kind `.rmw op` and `Access.locs S x = word` (`rmw`). It is
  decidable (`Use.decAdmits`).
* **`isSyncOf S L g o`**: `o` is a rendezvous `sync _ ms` whose agents are `g`'s members as
  threads, as sets: every agent of `ms` is a member of `g`, and every member is in `ms`.
* **`phase S L tr i g`**: the number of positions `k < i` at which `isSyncOf S L g tr[k]?`.
* **`phases S L tr`**: the accesses of `tr`, oldest first, each with `phase S L tr i` at its
  position `i`.
* **`Use.Separated S L U`**: for all phase vectors `π ≤ π'` (pointwise), a byte `l`, and accesses
  `x` admitted by `U π l` and `y` admitted by `U π' l` that both touch `l` and conflict
  (`Access.conflict`): `x.proxy = y.proxy`, and `x.who = y.who` or some instance `g` has both
  agents among its members (as threads) and `π g < π' g`.

```lean
theorem racy_eq_false_of_uses {L : S.Launch} {tr : List S.Event}
    (U : (S.Gid → Nat) → S.Loc → Use S) (hU : Use.Separated S L U)
    (h : ∀ x ∈ phases S L tr, ∀ l ∈ x.1.locs S, (U x.2 l).Admits S L x.1) :
    racy S tr = false
```

### Proof

From `GPUProof.racy_iff`, a race is a pair of positions `i < j` holding accesses `x` and `y` that
conflict and are not `Ordered`. Conflict gives a byte `l` of both. Both pairs `(x, phase at i)`
and `(y, phase at j)` are in `phases`, so `h` gives the admissions, and `phase_mono` gives the
pointwise `phase at i ≤ phase at j`. `hU` then gives one proxy, so it suffices to show
`GPUProof.HB` from `i` to `j` (the first case of `Ordered`):

* one agent: one `edge` from `i` to `j`;
* instance `g` with `π g < π' g`: `phase_lt` gives a position `k` with `i ≤ k < j` and
  `isSyncOf` there, so `tr[k]` is a rendezvous holding every member of `g`. It is not `i`, which
  holds an access, so `i < k`, and the edges `i → k` and `k → j` (both agents are members) give
  `HB` through `Relation.TransGen.tail`.

`phase_lt` is by induction on `j`: the count grows from `j` to `j + 1` only by the position `j`.

### How the statement departs from the design, and why

1. **Each `Use` names a proxy, and `Use.Separated` asks conflicting admitted accesses to go
   through one.** The design's `Use` has no proxy, and its separation speaks of agents only. On
   the core's `Racy`, two accesses through two proxies are ordered only through a fence
   (`GPUProof.Ordered`'s second case), which no use map sees. Without the proxy in `Admits`,
   `writer (thread t)` admits thread `t`'s write through proxy `false` and its read back through
   proxy `true`, with no fence between them, and the trace races
   (`MojoProofTest.GPUProof.Toy.crossProxy false`; the test `crossProxy_not_admitted` checks
   that, with the proxy, the read is not admitted). Without the proxy clause in `Separated`, the
   uses `writer (thread 0) false` before the launch's barrier and `readers (⊤, 0) true` after it
   are separated by the launch's phase, every access of the trace write, barrier, read is
   admitted, and the trace races: `HB` orders the pair but not through one proxy
   (`proxySwap_not_separated`). The proxy in `Use` is the choice made here; a use map that moves a
   byte to another proxy does so at a phase step, and the fence that makes the move race free is
   outside what this theorem covers (a fence orders only `Ordered`'s second case, and a use map
   would need the fence's position). That case is the permission history's (the design's
   `racy_eq_false_of_history`, where a cell changes proxy at a fence of its holder).
2. **No `Levels`, no `Laminar`.** The design states the theorem on laminar traces of a machine
   with `Levels`. The proof never uses either: a phase counts only rendezvous whose agents are
   exactly `g`'s members, so a phase step of an instance containing both agents is itself a
   rendezvous holding both, between the two positions, on every trace. The test
   `withRelAcq_race_free` applies the theorem to a trace with a release and an acquire, which is
   not laminar (`withRelAcq_not_laminar`). The design's form is the special case.
3. **`phases`, `Admits` and `Separated` take the launch `L`.** The members of an instance are
   `S.members L g`, so the phase of `g` and the agents of `readers g` need `L`. The design's
   `phases (tr)` names no launch.
4. **"Two updates admitted by one `rmw` use must be exempt" is not a separate clause.**
   `Separated` asks its conclusion of conflicting pairs only, and `Access.conflict` is false on
   the pairs the machine exempts. So two updates admitted by one `rmw` use that the machine does
   not exempt (other proxies, or a returned result, `Kind.rmwRet`, which `rmw` does not admit)
   must be one agent's or told apart, as any other pair.
5. **Separation includes one agent's pairs.** The design's separation speaks of "different
   agents". Here `x.who = y.who` is the first case of the conclusion, which is the same.
6. **The instance must contain both agents.** If "told apart" did not ask for the instance to
   contain both agents, the uses `writer (thread 0)` before warp `0`'s barrier and
   `writer (thread k)` after it, where thread `k` is lane `0` of warp `1`, would be told apart by
   warp `0`'s phase, and the trace write, warp barrier, write races (`outside_not_separated`).
7. **A phase counts a rendezvous of all the members.** `isSyncOf` asks every member of `g` to be
   among the rendezvous's agents; counting a rendezvous of some members only (a masked barrier)
   would grow `g`'s phase without ordering the members left out. It also asks every agent to be
   a member, which the proof does not need: a phase counts `g`'s own rendezvous, not those of a
   larger instance, as MojoProof's `phases` counts its block's barriers only.
8. **Jobs.** A job is in no instance (members are threads), so a job's byte can only be its
   `writer`'s, or read-only.

A finding of this proof, for the tests: instance search does not unfold a machine's fields, so
`Decidable (Use.Admits toy (n, ws) u x)` fails on a pair `(n, ws)`, whose type is
`Nat × List Nat`, not `toy.Launch`. The tests name their launches through `toyLaunch`, whose type
is `toy.Launch`. The same holds at any machine defined by a structure instance, `sig` included.

### The MojoProof corollaries, for later

`MojoProof.Sem.racy_eq_false_of_writers`, `racy_eq_false_of_phased` and `racy_eq_false_of_owned`
(MojoProof/Sem/Trace.lean) keep their statements. `racy_eq_false_of_phased` and
`racy_eq_false_of_owned` keep their proofs through `racy_eq_false_of_writers`, which are one line
each already. Only `racy_eq_false_of_writers` moves:

```lean
theorem racy_eq_false_of_writers ... (hU ...) (hs ...) (hW ...) (hG ...) (hX ...) :
    GPUProof.racy sig (tr.map (Event.toCore L)).reverse = false :=
  GPUProof.racy_eq_false_of_uses (writersUse tr W own)
    (writersUse_separated tr W own) (writersUse_admits hU hs hW hG hX)
```

The route, and what it needs besides `GPUProof.racy_eq_false_of_uses`:

1. **`racy_sig_iff`** (MojoProof/Sem/RaceSig.lean): the core's `racy` at `sig` of a trace `tr`
   whose accesses' `who` agree with the launch `L` (`hU`), as two conflicting accesses of two
   threads that no barrier of their block orders (by `GPUProof.HB.laminar_iff`), with `toCore`
   the embedding of MojoProof's trace into `sig`'s (newest-first to oldest-first, a barrier of
   block `k` to the rendezvous of `k`'s threads). With `racy_iff`, on shaped traces (`hs`), it is
   MojoProof's `clash` over `phases`. The three corollaries take `hU` and `hs`, which
   `Grid.start_reach_fits` gives at every grid reachable from the start: a deliberate
   restatement.
2. **`writersUse tr W own π l`**, built from the trace. For the byte `l = (b, i)`: if every
   access of `tr` to `l` is by block `c`, read `c`'s phase `p = π (block instance c)`, and give
   `writer (thread t)` when `W p b i = some o`, with `t` a thread of an access of `tr` to `l` at
   phase `p` whose `own p t = o` (a member of `c` otherwise), and `readers (block instance c)`
   when `W p b i = none`; if accesses of two blocks touch `l`, give `frozen`. Each through
   `sig`'s one proxy.
3. **`writersUse_separated`**, by construction and for every `W` and `own`: a frozen byte has no
   writes; a byte of block `c` has its use a function of `π c`, so equal phases of `c` give one
   use (one `writer`, or `readers` with no writes) and different ones are told apart by `c`,
   which contains every agent its uses admit.
4. **`writersUse_admits`**, from `hW`, `hG` and `hX`, with the phase correspondence: at `sig`,
   `GPUProof.phase` of block `c`'s instance at an access's position is MojoProof's barrier count
   of `c` there. `hW` says the access is its byte's owner's or a read of an unowned byte; `hX`
   makes the owner's thread unique among the accesses at one phase of one block; `hG` with `hW`
   and `hX` makes a byte touched by two blocks unowned, so every access to it is a read.

This is not the one-line corollary the design names: the use map is built from the trace, and
steps 2 to 4 are new MojoProof lemmas. It needs `sig`, `racy_iff` and the phase
correspondence first.

### Tests (`MojoProofTest/GPUProof/Uses.lean`)

`handoverUse k`: while the launch's phase is `0`, the byte is lane `min p (k - 1)`'s, through
proxy `false`, where `p` is warp `0`'s phase; afterwards it is `readers (⊤, 0) false`.

* `handover_separated`: the uses are separated for every `k ≥ 1` lanes and `nw ≥ 1` warps.
* `handover_race_free`: at two warps of 2 lanes and three warps of 5, the hand-over's run is race
  free through `GPUProof.racy_eq_false_of_uses`, with the admissions by `decide +kernel`; a
  `#guard` evaluates `racy` to `false` on both.
* The mutants, one per premise and design choice:
  * no laminar premise: `withRelAcq` (the run with a release and an acquire appended) is not
    laminar and is race free through the theorem;
  * not separated: `outsideWarp` (thread `0` writes, warp `0`'s barrier, thread `k` writes) with
    `outsideUse` admits every access and races, so the uses are not separated, at 2 and 5 lanes;
  * not admitted: without the launch's barrier (`run true false`) `handoverUse` does not admit
    the read, and the run races, at both sizes;
  * proxies: `proxySwap` with `proxySwapUse` (each admitted, through two proxies) races, so the
    uses are not separated; `crossProxy false` races, and `ownUse` (each thread's own byte,
    through proxy `false`) does not admit its reads, at 3 and 7 threads.
