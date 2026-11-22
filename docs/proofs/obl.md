# `vector_addition` walks the path its index selects (`vadd_walk_launch`, `mojo_obl`)

Lean: `MojoProof/Sym/OblLemmas.lean` (the lemmas) and `MojoProof/Sym/Obl.lean` (the tactic).
Tests: `MojoProofTest/Obl.lean`.

**Scope.** Every valid one-dimensional launch, alignment, pair of input buffers and output buffer of
`n < 2 ^ 31` floats that fit below `2 ^ 64`, thread `k`, and context, memory and frame with the
facts below. The goal is the walk along the path the index selects, the first conjunct of `Ret` in
`Kernel.sound_of_paths`; `mojo_ret` proves it inside its `Ret` goals. The program, its summaries and paths are `Kernels.vadd.*`
(MojoProof/Kernels/Vadd.lean); the lemmas are for every valuation, program and table.

## Statement

`MojoProofTest.Obl.vadd_walk_launch` (MojoProofTest/Obl.lean). For every `L : Launch`
with `L.Valid`, `L.grid .y = 1 ∧ L.grid .z = 1`, `L.block .y = 1 ∧ L.block .z = 1`; every `al`
with `4 ∣ al`; every `a b out n N` and tensors `x y` of `N` binary32 values with `a`, `b`, `out`
distinct, `n ≤ N`, `n < 2 ^ 31`; every `k < volume L.grid * volume L.block`; every `c : Ctx` with
`c.prog = Kernels.vadd.prog`, `c.env = L.env k`, `c.who = ⟨k, k / volume L.block⟩`; every memory
`m` and frame `f` with `f.fn = Kernels.vadd.fn_0`, registers `0, 1, 2` the pointers `⟨p0, 0⟩`,
`⟨p1, 0⟩`, `⟨p2, 0⟩` and register `3` the word of `n`; the byval loads at `p0`, `p1`, `p2` giving
the structs of `a`, `b`, `out`; `m.Buffer` of `n * 4` bytes at `a`, `b` (read-only) and `out`
(writable), aligned to `al`; `m.Holds` of `x` at `a` and `y` at `b`, row-major; and
`m.Fits l a (n * 4)` (`Mem.Fits`, MojoProof/Sem/Precond.lean), the same for `b` and `out`:

    (k < n → Walk (Valuation.entry c 0 m f) (Kernels.vadd.paths.getD 0 [])) ∧
    (¬ k < n → Walk (Valuation.entry c 0 m f) (Kernels.vadd.paths.getD 1 []))

Path 0 is `%4 → %21 → %31` (labels 4, 21, 31), path 1 is `%4 → %30 → %31` (labels 4, 22, 31).
`m.Fits l c s` is `∃ blk, m.blocks c = some blk ∧ blk.gaddr + s ≤ 2 ^ (l.ptr 0).1`; mojo_obl
unfolds it by one step of its head.

## Proof

A (the walk). `Walk V ((l, ds, S) :: (l', ds', S') :: ps)` is `∀ d ∈ ds, d.Holds V (vals V
S.nodes)`, then `S.exit.target V (vals V S.nodes) = some l'`, then the walk of the rest from
`V.after S` (`Walk.cons2`; `Walk.one`, `Walk.nil'` for the ends). So the proof is, per block, its
obligations at its entry valuation and its exit.

B (block `%4`, at `V = Valuation.entry c 0 m f`). The node values, in order:
nodes 0, 2, 4 are the byval loads at `p2`, `p1`, `p0`, whose values are the hypotheses' structs
(`SNode.eval_load_at`, the statement and its alignment by kernel `whnf`); nodes 1, 3, 5 their first
fields, the pointers `⟨out, 0⟩`, `⟨b, 0⟩`, `⟨a, 0⟩` (`SNode.eval_extract`); node 6 is
`sext 64` of the word of `n`, the word of `n` since `2 n < 2 ^ 32` (`intCast_sext_ofNat`); nodes
7, 9, 11 are `tid.x`, `ctaid.x`, `ntid.x`, the words of the registers of `L.env k`, which are in
the `range` attributes the declarations carry (`SNode.eval_sreg_at`, `withAttrs_ofNat`,
`Launch.sreg_bound`); nodes 8, 10, 12 their extensions to 64 bits, node 13 the product and node 14
the sum, the words of the natural numbers since the register bounds (`Launch.sreg_lt`) keep them
below `2 ^ 63` (`intCast_ofNat`, `intBin_mul_ofNat`, `intBin_add_ofNat`); node 15 is
`Val.ofBool (decide (ctaid.x * ntid.x + tid.x < n))` (`SNode.eval_icmp_slt_ofNat`, both sides
below `2 ^ 63`). The obligations: `ok` of each node from its value, `bool` of node 15 from
`Val.ofBool`, and the three load effects run, each logging its access (`SEff.apply_load_at`,
`SEff.foldlM_cons_ex`). The exit `cond (node 15) 21 22` goes to 21 when the comparison holds
(`Exit.target_cond_true`) and to 22 when it fails (`Exit.target_cond_false`); `Launch.index_oneDim`
says `ctaid.x * ntid.x + tid.x = k` on this launch, so the comparison is `k < n`, which `hkn`
decides either way (`omega`).

C (block `%21`, at `V₁ = V.after b0`, when `k < n`). The registers of `V₁` are `b0`'s node values
(`Valuation.after_regs_some`), its memory is `m` with three trace entries, with `m`'s blocks
(`Valuation.after_mem_fold`). Node 0 is `trunc 32` of the index and node 1 its `sext 64`, the
word of `k` since `k < n < 2 ^ 31`. Nodes 2, 4, 7 are `getelementptr inbounds float` from `⟨a, 0⟩`,
`⟨b, 0⟩`, `⟨out, 0⟩` by `k`: by `gep_buffer`, `⟨c, 4 k⟩`, since `4 k < 4 n` and the buffer fits,
so its address `gaddr + 4 k` does not reach `2 ^ 64` and the `inbounds` checks pass. Nodes 3 and 5
are the loads of element `k` of `a` and `b`, the floats `x k` and `y k` (`load_buffer`: `Mem.Holds`
with `rowMajor_one`, `Mem.load_holds`, alignment from `4 ∣ al ∣ gaddr`). Node 6 is the `fadd` of
them (`SNode.eval_fbin_ofFloat`). The obligations: each node's `ok`, and the effects (the two loads,
then the store of node 6 at node 7) run: the store's check passes on the writable buffer `out`
(`store_buffer`: `Mem.check_ok`, `Mem.write_of_check`, the float's encoding). The exit is `br 31`
(`Exit.target_br`).

D (blocks `%30` and `%31`). No nodes; the one obligation `mem []` runs (`SEff.foldlM_nil_ex`); `%30`
exits by `br 31`. `%31`'s exit (`ret`) is not part of `Walk`.

E (the twin, `vadd_walk_launch_open`, MojoProofTest/Obl.lean). With `hkn : ¬ Below k n` and
`Below` irreducible, step B's `omega` has no fact on `k < n`, so the exit of `%4` stays open: the
logged goal is `Exit.target (Valuation.entry c 0 m f) (vals (Valuation.entry c 0 m f)
Kernels.vadd.b0.nodes) Kernels.vadd.b0.exit = some 22` (checked by `#guard_msgs`). After
`unfold Below at hkn`, `mojo_obl` closes it.

## Why the buffers must fit

Without `Mem.Fits`, the goal is false. `Mem.Buffer` bounds a block's size and alignment, not its
generic address `gaddr`. If `gaddr + 4 k ≥ 2 ^ 64` for some `k < n`, the `getelementptr inbounds`
of step C is `poison` (`gepPtr`'s `badS`, MojoProof/Sem/Eval.lean), the load through it faults, and
`%21`'s `mem` obligation fails. So the start facts include `Mem.Fits`; `addr_buffer` is where
they are used.

## Heartbeats

`vadd_walk_launch` takes 42,217 heartbeats (Mathlib's `#count_heartbeats in`, in a scratch file),
of the default 200,000; no option is set.
