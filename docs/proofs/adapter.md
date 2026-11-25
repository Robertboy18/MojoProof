# `Grid.Sound` from one run (`Grid.sound_of_one_run`)

Lean: `MojoProof/Sem/Trace.lean`.

**Scope.** Every program, launch `L`, contexts `c`, observation `obs` and relation `R`. Confluence is a
hypothesis; this theorem does not prove it for any kernel.

## Statement

The data are a state type `γ`, a projection `π : γ → Grid`, relations `rc` and `e` on `γ`, and a set
`Bad ⊆ γ`. The hypotheses:

- `hc : Confluent rc e Bad` (`one-run.md`);
- `proj`: `rc x x'` gives `Grid.Step L c (π x) (π x')`;
- `lift`: `Grid.Step L c (π x) g'` gives `x'` with `rc x x'` and `π x' = g'`;
- `hF`, `hT`, `hK`: if `π x` faults, its trace is `racy`, or the core's `kept` at `sig` of its
  trace's core events (`GPUProof.kept sig (((π x).mem.trace.map (Event.toCore L)).reverse)`) is
  false, then `Bad x`;
- `hfin`: if `GPUProof.Done sig (π x, L, c)` (every thread of the launch has returned), `π x` has no
  `Grid.Step`;
- `hD`: `e x x'` and `GPUProof.Done sig (π x, L, c)` give `GPUProof.Done sig (π x', L, c)`;
- `hO`: `e x x'` gives `obs (π x).mem = obs (π x').mem`;
- `run : Path rc n x₀ z`, `hz : GPUProof.Done sig (π z, L, c)`, `hb : ¬ Bad z`, `hy : obs (π z).mem = some y`, `hR : R y`.

Conclusion: `Grid.Sound L c (π x₀) obs R`, all seven fields (`safe`, `raceFree`, `kept`, `progress`,
`terminates`, `determinate`, `post`).

## Proof

The one-run argument is `GPUProof.Clean.of_lift`'s (`GPUProof/Sound.lean`, docs/proofs/theorem0.md),
for every machine; this theorem is its case at `sig` along `x ↦ (π x, L, c)`, with the observation
`fun s => obs s.1.mem` of the grid's whole memory. A step at `sig` from `(g, L, c)` is a grid step
with `(L, c)` kept (`sig_step_iff`), so `proj`, `lift` and `hfin` give the core's projection, lift
and `hfin`; `hF`, `hT`, `hK`, `hD` and `hO` are already stated at `sig`.

**`Clean.of_lift`'s argument.**

- `z` is normal for `rc`: a step `rc z x'` projects to a step from the done `π z`, which `hfin`
  excludes.
- Lifting reachability (`ReflTransGen.of_lift`): every state that the core's steps reach from
  `π x₀` is `π x` for some `x` that `rc` reaches from `x₀`, by induction, using `lift` at each step.
- `Confluent.one_run` with `run`, the normality of `z` and `hb` gives four facts: `rc` is well
  founded from `x₀`; no `x` reachable from `x₀` is bad; every normal `x` reachable from `x₀` is
  `e`-equivalent to `z`; every reachable `x` reaches some `z'` equivalent to `z`.
- `Clean`'s fields: a fault, a racy trace or a broken promise at a reachable `π x` would make `x`
  bad (`hF`, `hT`, `hK`); if `π x` is not done, the run from `x` to a `z'` equivalent to `z` is not
  empty (else `hD` with `hz` makes `π x` done), and its first step projects; termination is `Acc`
  carried along `π` (`Acc.of_lift`).
- A reachable done state is `π x` with `x` normal, so `e z x`, and `hO` gives it the observation
  of `π z`.

**Back to the grid (`Grid.Sound.of_clean`, `MojoProof/Sem/Spec.lean`).** Every grid that `π x₀`
reaches gives a state that `(π x₀, L, c)` reaches (`sig_reach_iff`), so `safe`, `raceFree` and
`kept` are `Clean`'s; a grid that is not done has a step because its state has one
(`sig_step_iff`); `terminates` is `Clean`'s, along `g ↦ (g, L, c)`. `determinate` and `post`: a
reachable done grid observes `obs (π z).mem = some y`, and `R y`.

## Dependencies

- `Confluent`, `Path`, `Confluent.one_run` (`GPUProof/OneRun.lean`); `GPUProof.Clean.of_lift`
  (`GPUProof/Sound.lean`);
- `Grid.Step`, `Grid.faults_iff`, `Grid.Sound`, `racy` (`MojoProof/Sem/Grid.lean`,
  `MojoProof/Sem/Spec.lean`); `sig_step_iff`, `sig_reach_iff` and `Grid.Sound.of_clean`
  (`MojoProof/Sem/Spec.lean`); `GPUProof.Faults` and `GPUProof.Done` (`GPUProof/Run.lean`) and
  `GPUProof.kept` (`GPUProof/Race.lean`) at `sig`;
- `Relation.ReflTransGen` (Mathlib).

## Instances in the tree

- `Grid.start_sound` (`MojoProof/Sem/Determinism.lean`): a launch's start grid. `γ` is the subtype of
  grids reachable from the start grid, `rc` is `Grid.Step` on it, `e` is `Grid.Same`, and `Bad` is a
  fault, a racy trace or a broken `!invariant.load` promise: the case where `γ` is the reachable grids.
- `Grid.sound_commuting`: `N` threads that each return in one step with a change of memory `f n`, for every
  `N`, launch of at least `N` threads, contexts, threads and memory `M`, when, at every memory with a property
  `P` that `M` has and every `f n` keeps, the step of thread `n < N` returns with memory `f n m`, the changes
  of two distinct threads commute and each keeps the trace; the observation is that of
  `(List.range N).foldr f M`, and `M`'s trace has no race and keeps `!invariant.load`. `γ` is the set of
  returned threads, the memory of a set is that of its threads' changes, `rc` returns one thread, `e` is `=`,
  and `Bad` is empty. Its instance with changes is `MojoProofTest.Close.sound_dead`: 2 and 3 threads, each
  ending its own `alloca` block (`Mem.setLive`), on one memory of 3 live blocks.
- `Grid.sound_returning`: its case of `N` threads that each return in one step without changing memory
  (`f n m = m`, `P` is `· = M`), for every `N`.
  `γ` is the set of returned threads, `rc` returns one thread, `e` is `=`, and `Bad` is empty. The diamond
  is proved for every pair of threads. Its instance at one thread is `MojoProofTest.Close.sound_one_ret`:
  one thread of `ret void` on the empty memory at `Launch.one`, its premises by `decide`.
- `Kernel.sound_ret_launch`: the kernel `ret void` on every launch and every closed memory (`Mem.Closed`,
  which the start's check needs), through `Grid.sound_returning`.

## The observation of an elementwise output

Lean: `MojoProof/Sem/Elementwise.lean`; proved. Instances and twins: MojoProofTest/Elementwise.lean.
This is the `obs` side of `Grid.sound_of_one_run` for a kernel that
stores one element per cell: what `Mem.tensor` (MojoProof/Sem/Buffer.lean) reads after the stores.

**Statements.** For a layout `l`, type `t`, codec `enc` for `t` (`Layout.Codec`), shape `s`, offsets
`off` that are `l.stored t` bytes apart (`Apart`), a tensor `x`, values `f i` with encodings `bs i`
(`l.encode t (enc (f i)) = some (bs i)` for every cell `i`) and a list of cells `is`:

1. `Block.holds_writes`: if block `blk` holds `x` (`Block.Holds`), then writing `bs i` at `off i`
   for the cells of `is`, in the order of `is` (repetitions allowed), gives a block that holds the
   tensor `y` with `y i = f i` for `i ∈ is` and `y i = x i` otherwise.
2. `Mem.tensor_writes`: a memory whose block `b` is that block observes `some y` at `b`.
3. `Mem.tensor_vec`: the case of shape `[N]`, binary32 (`.fp .float`, `Val.ofFloat .float`) at
   row-major offsets from `base`, and `is` the cells below `n` (`i ∈ is ↔ i < n`): the observation is
   `i ↦ w i` below `n` and `x i` from `n` on.
4. `Mem.tensor_vec_add`: in 3 with every cell stored (`n = N`) and `w i = deliver (a i + c i) (k i)`,
   which is what `fadd` with no flags gives on the words of `a i` and `c i` for the oracle number
   `3 k i` (`floatBin_ofFloat`), and no `a i + c i` a NaN: the observation is `some (a + c)`, where
   `+` on tensors is TorchLean's `Add (Tensor α s)` (`zipWith (· + ·)`) and on elements FloatLib's
   binary32 addition, the instance `Add (Model fmt)`. No copy of either is defined.

**Proofs.**

1. Writes change no block's size (`Block.size_puts`, by induction on the list), so each tile still
   lies in the block. The encodings have `l.stored t` bytes (the codec's round trip), and the tiles
   are apart, so after the writes the `l.stored t` bytes at `off i` are `bs i` if `i ∈ is` and the
   block's own otherwise (`Block.read_puts`). In the first case they decode to `enc (f i)` (the
   codec's round trip), in the second to `enc (x i)` (`blk` holds `x`). Both are `enc (y i)`
   (`Tensor.Rep.get_ofFn`).
2. Through a codec a block holds at most one tensor, so the observation is `y` (`Mem.tensor_eq`).
3. Binary32 words are a codec (`Layout.Codec.float`) and row-major offsets are apart
   (`apart_rowMajor`); rewrite `i ∈ is` by `i < n`.
4. By 3, the observation is `i ↦ deliver (a i + c i) (k i)` (every cell is below `N`). With no NaN,
   `deliver r n = r` (`deliver_of_isNaN_eq_false`), and `(a + c) i = a i + c i`
   (`Tensor.add_apply`), so the two tensors agree at every cell (`Tensor.Rep.ext`).

**Instances and twins.** A 16-byte block holding the zero tensor of shape `[4]`, row-major from 0:

- after one store per cell below 2 (order 1, 0), the observation is the stored words at cells 0
  and 1 and zero at 2 and 3 (`vec_inst`);
- with `a` = 1.0 and `c` = 2.0 in every cell, the four cells stored in the order 3, 1, 0, 2 with
  `deliver (a i + c i) 0` (`fadd_word`: what `fadd` gives for oracle number 0), the observation is
  `a + c` (`add_inst`), 3.0 in every cell (`sum_three`);
- twin of the coverage premise: with cells 0 and 1 stored, the observation is not `a + c`, cell 3
  is still 0 (`add_twin_partial`);
- twin of the NaN premise: `+∞ + -∞` is a NaN, and the oracle number of the NaN `0x7fc00001`
  stores another NaN, so the observation is not `pinf + ninf` though every cell is stored
  (`add_twin_nan`). Without the NaN premise the observation is related to `a + c` only up to NaN
  words.

**Scope.** These are statements about the bytes of a block after writes, for every layout, shape
and order of writes. That the stores of a kernel run write exactly these bytes, one per cell, is
the per-thread part of a kernel theorem (for `vector_addition`, with the index of
docs/proofs/index.md); it is not proved here.
