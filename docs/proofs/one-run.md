# The one-run theorem (`Confluent.one_run`)

Lean: `MojoProof/Sem/OneRun.lean`.

**Scope.** Every type `α`, step relation `r`, relation `e` and set `Bad`. Nothing here is about kernels.
It is Newman's random descent with an equivalence and a bad set (van Oostrom and Toyama, FSCD 2016); not
a new principle.

## Statement

`Path r n a z`: a run of exactly `n` steps of `r` from `a` to `z`. `Normal r z`: `z` has no step.

Hypothesis `h : Confluent r e Bad`:

1. `e` is an equivalence (`refl`, `symm`, `trans`);
2. `e` is a simulation for `r` (`bisim`): `e a a'` and `r a b` give `b'` with `r a' b'` and `e b b'`;
3. `Bad` is closed under `e` (`bad_eqv`) and under steps (`bad_step`);
4. the one-step diamond (`diamond`): steps `r a b` and `r a c` give `e b c`, or both `Bad b` and `Bad c`,
   or `d`, `d'` with `r b d`, `r c d'` and either `e d d'` or both `Bad d` and `Bad d'`.

The alternative `Bad b ∧ Bad c` is for T2 (schedule.md, S1): two conflicting steps of a grid
give two grids that are bad at once, from which the other step may fault rather than step.

Further hypotheses: `hp : Path r n a z`, `hz : Normal r z`, `hb : ¬ Bad z`.

Conclusions:

1. `Acc (fun b a => r a b) a`: every run from `a` is finite;
2. no state reachable from `a` is bad;
3. every normal state reachable from `a` is `e`-equivalent to `z`;
4. every state `g` reachable from `a` has a run of `m ≤ n` steps to some `z'` with `e z z'`.

The diamond must be the one-step form. Plain confluence is not enough: `s → s` and `s → done` is confluent
and has an infinite run.

## Proof

**A (`normal_eqv`).** If `e a a'` and `a` is normal, so is `a'`: a step `r a' b` gives, by `bisim` with
`e a' a`, a step from `a`.

**B (`path_eqv`).** If `Path r n a z` and `e a a'`, then `Path r n a' z'` with `e z z'`, by induction on the
path, using `bisim` at each step.

**C (`bad_path`).** If `Path r n a z` and `Bad a`, then `Bad z`, by induction, using `bad_step`.

**Key lemma (`key`).** If `Path r n a z`, `z` is normal and not bad, `e a a'` and `r a' b`, then `n = m + 1`
and `Path r m b z'` with `e z z'`. The proof is by induction on `n`.

- `n = 0`: then `a = z`, so `a'` is normal by A, which contradicts `r a' b`.
- `n + 1`: the run is `r a a₁` followed by `Path r n a₁ z`. `bisim` gives `r a' a₁'` with `e a₁ a₁'`. The
  diamond on `r a' b` and `r a' a₁'` gives four cases.
  - `e b a₁'`: then `e a₁ b`, and B on `Path r n a₁ z` gives `Path r n b z''` with `e z z''`.
  - `r b d` and `r a₁' d'` with `e d d'`: the induction hypothesis on `Path r n a₁ z`, with `e a₁ a₁'`
    and `r a₁' d'`, gives `n = m + 1` and `Path r m d' z''` with `e z z''`. B, with `e d' d`, gives
    `Path r m d z₃` with `e z'' z₃`. So `Path r (m + 1) b z₃`, `n + 1 = (m + 1) + 1`, and `e z z₃`.
  - `Bad a₁'` (with `Bad b`): B on `Path r n a₁ z` with `e a₁ a₁'` gives `Path r n a₁' z''` with
    `e z z''`. C gives `Bad z''`, and `bad_eqv` gives `Bad z`, which contradicts `hb`.
  - `r b d` and `r a₁' d'` with `Bad d'`: the induction hypothesis gives `Path r m d' z''` with
    `e z z''`. C gives `Bad z''`, and `bad_eqv` gives `Bad z`, which contradicts `hb`.

**Termination (`acc`).** By induction on `n`. For `n = 0`, `a = z` has no step. For `n + 1`, every step
`r a b` gives, by the key lemma with `e a a`, `Path r n b z'` with `e z z'`. `z'` is normal (A) and not bad
(`bad_eqv`), so the induction hypothesis gives `Acc` at `b`.

**Reachable states (`reach`).** If `g` is reachable from `a`, then `Path r m g z'` with `m ≤ n` and `e z z'`.
The proof is by induction on reachability. The base is `hp`. For a step `g → g'`: `z'` is normal and not bad
(A, `bad_eqv`), and the key lemma gives `Path r m' g' z''` with `m = m' + 1` and `e z' z''`.

**`one_run`.** (1) is `acc`. (2): if `Bad g`, then `reach` and C give `Bad z'`, so `Bad z`. (3): if `g` is
normal, the path `reach` gives has no step, so `z' = g`. (4) is `reach`.

## Dependencies

`Relation.ReflTransGen` (Mathlib) and `Acc` (Lean core); no MojoProof definition. Axioms: none beyond
`propext`, `Classical.choice` and `Quot.sound`.

## Instances

`Grid.sound_one` (states are the grids reachable from one thread; `e` is `=`; `Bad` is a fault, a race or a
broken `!invariant.load` promise) and `Grid.sound_returning` (states are the sets of returned threads; `Bad`
is empty). Both go through the adapter (`adapter.md`).
