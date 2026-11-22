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
- `hF`, `hT`, `hK`: if `π x` faults, its trace is `racy`, or its trace is not `kept`, then `Bad x`;
- `hD`: `e x x'` and `(π x).Done` give `(π x').Done`;
- `hO`: `e x x'` gives `obs (π x).mem = obs (π x').mem`;
- `run : Path rc n x₀ z`, `hz : (π z).Done`, `hb : ¬ Bad z`, `hy : obs (π z).mem = some y`, `hR : R y`.

Conclusion: `Grid.Sound L c (π x₀) obs R`, all seven fields (`safe`, `raceFree`, `kept`, `progress`,
`terminates`, `determinate`, `post`).

## Proof

**`z` is normal for `rc`.** A step `rc z x'` projects (`proj`) to a step from the done grid `π z`, which
`Grid.Done.final` excludes.

**Lifting reachability (`up`).** Every grid that `Grid.Step` reaches from `π x₀` is `π x` for some `x` that
`rc` reaches from `x₀`. The proof is by induction on reachability, using `lift` at each step.

**One run.** `Confluent.one_run` with `run`, the normality of `z` and `hb` gives four facts:

- `rc` is well founded from `x₀`;
- no `x` reachable from `x₀` is bad;
- every normal `x` reachable from `x₀` is `e`-equivalent to `z`;
- every reachable `x` reaches some `z'` equivalent to `z`.

**Final grids (`final`).** A done grid `g` reachable from `π x₀` is `π x` with `x` reachable (`up`). `x` is
normal, because a step would project to a step from a done grid. So `e z x`, and `hO` gives
`obs g.mem = obs (π z).mem = some y`.

**The seven fields.**

- `safe`, `raceFree`, `kept`: a reachable grid is `π x` with `x` reachable. A fault, a racy trace or a
  broken promise would make `x` bad (`hF`, `hT`, `hK`), which `one_run` excludes.
- `progress`: if `π x` is not done, `x` reaches some `z'` equivalent to `z`. If that run is empty, `e z x`,
  and `hD` with `hz` makes `π x` done, which is a contradiction. Otherwise its first step `rc x x₁` projects
  to a grid step.
- `terminates`: `Acc` of the converse of `rc` at `x₀` gives `Acc` of the converse of `Grid.Step` at `π x₀`,
  by induction on `Acc`: every grid step from `π x` lifts to an `rc` step from `x`.
- `determinate`: two reachable done grids both observe `y` (`final`).
- `post`: `final` and `hR`.

## Dependencies

- `Confluent`, `Path`, `Confluent.one_run` (`MojoProof/Sem/OneRun.lean`);
- `Grid.Step`, `Grid.Faults`, `Grid.Done`, `Grid.Done.final`, `Grid.Sound`, `racy`, `kept`
  (`MojoProof/Sem/Grid.lean`, `MojoProof/Sem/Spec.lean`);
- `Relation.ReflTransGen` (Mathlib).

## Instances in the tree

- `Grid.sound_one`: one thread whose step returns. `γ` is the subtype of grids reachable from the start
  grid, `rc` is `Grid.Step` on it, `e` is `=`, and `Bad` is a fault, a racy trace or a broken
  `!invariant.load` promise: the case where `γ` is the reachable grids.
- `Grid.sound_returning`: `N` threads that each return in one step without changing memory, for every `N`.
  `γ` is the set of returned threads, `rc` returns one thread, `e` is `=`, and `Bad` is empty. The diamond
  is proved for every pair of threads.
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
