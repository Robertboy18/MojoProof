# Tactics and commands

The metaprogramming around the block checker (`docs/automation.md`): `MojoProof/Sym/Bounds.lean`
(`mojo_bounds`, the index arithmetic's obligations), `MojoProof/Sym/Obl.lean` (`mojo_obl`, the
obligations and exits of a path of block summaries), `MojoProof/Sym/Vals.lean` (`mojo_vals`, a
block's node values), `MojoProof/Sym/Ops.lean` (`mojo_ret`, an elementwise kernel's `Elem` steps and
`Ret`), `MojoProof/Sym/Inv.lean` (`mojo_inv`, the registers, operands and memory facts of a loop's
invariant after a path or rounds), `MojoProof/Sym/Race.lean` (`mojo_race`, the disjointness premises
of the race-freedom results), `MojoProof/Sym/Command.lean` (`sym_summary`),
`MojoProof/Sym/OblSeg.lean` (`mojo_seg` and `sym_segs`, a thread through collective calls),
`MojoProof/Sym/WarpRoute.lean` (`warp_route`, a warp's run from its lanes' facts),
`MojoProof/Sym/KernelCmd.lean` (`mojo_kernel`), `MojoProof/Sym/Info.lean` (`#mojo_info`),
`MojoProof/LLVM/Mutate.lean` (the mutation harness, `mojo_mutant`, `mojo_kills`),
`MojoProof/LLVM/Quote.lean` (`mojo_import`), `MojoProof/LLVM/Family.lean` (`mojo_family`, a
program with integer constants as parameters), `MojoProof/LLVM/Corpus.lean` (`mojo_corpus`) and
`MojoProof/Sym/RuleAttr.lean` with `MojoProof/Sym/Rules.lean` (the rule table, `@[mojo_rule]`);
tests in `MojoProofTest/SymBounds.lean`, `MojoProofTest/Obl.lean`, `MojoProofTest/OblNaive.lean`,
`MojoProofTest/OblShared.lean`, `MojoProofTest/OblGevmThread.lean`,
`MojoProofTest/OblLoadAfter.lean`, `MojoProofTest/Vals.lean`, `MojoProofTest/Ops.lean`,
`MojoProofTest/Vmul.lean`, `MojoProofTest/NaiveOut.lean`, `MojoProofTest/Inv.lean`,
`MojoProofTest/Race.lean`, `MojoProofTest/Sym.lean`, `MojoProofTest/KernelCmd.lean`,
`MojoProofTest/SymInfo.lean`, `MojoProofTest/Mutate.lean`, `MojoProofTest/Import.lean`,
`MojoProofTest/Family.lean`, `MojoProofTest/WarpRoute.lean`,
`MojoProofTest/Corpus.lean` and `MojoProofTest/Rule.lean`. None of them sets `maxHeartbeats` (the
library has 4 such overrides, all in `MojoProof/Sem`) or `maxRecDepth`, and their calls need
neither: the tests call them under the default limits.

## `mojo_bounds` (`MojoProof/Sym/Bounds.lean`)

A tactic for the integer obligations of index arithmetic: goals and hypotheses over bit vectors,
natural numbers and integers built from `setWidth` (`trunc`, `zext`), `signExtend` (`sext`), `+`,
`*`, signed and unsigned comparisons and `Int.bmod` (the operations of `intCast`, `binV` and
`gepPtr`), such as the access check `0 ≤ off ∧ off + size ≤ len` of `Mem.check`. Method, nothing
kernel-specific and no case split on concrete values:

1. lowering by `simp only` (`BitVec.toNat_add`, `toNat_mul`, `toNat_ofNat`, `toNat_setWidth`,
   `toNat_signExtend`, `msb_eq_decide`, `toInt_eq_toNat_cond`, `slt_iff_toInt_lt`, `ult_iff_lt`,
   `lt_def`, `le_def`, `Int.bmod_def`, `decide_eq_true_eq`) at every hypothesis and the goal, to
   `toNat` of the atoms, remainders by powers of two and `if`s;
2. every remainder `t % m` whose dividend has a bound `K ≤ m` rewritten to `t` (`Nat.mod_eq_of_lt`),
   innermost first; bounds by the term's structure, from the hypotheses `t < K` and `t ≤ K` with
   `K` closed, from the type (`x.toNat < 2 ^ w` for `x : BitVec w`, `BitVec.isLt`), from a
   remainder's modulus, and from sums and products of bounds;
3. a goal whose hypotheses `omega` refutes is closed; each `if` condition with no `if` inside it,
   the smallest first (sign bits of atoms before the conditions built on them), is decided by
   `omega` when it can be, else split on by the `if`'s own `Decidable` instance (`byCasesDec`, so
   no classical choice), and steps 2 to 5 go on in each case;
4. every product of natural numbers with bounded factors gets the fact `t * s < K₁ * K₂` (core's
   `Nat.mul_lt_mul_of_lt_of_lt`), which `omega`, treating the product as an atom, cannot find; these
   facts are added after step 2 and before step 3 decides or splits anything, in each case, so step
   3's `omega` calls have them;
5. `omega`.

The hypotheses it adds have inaccessible names (`mkFreshUserName`). A goal it does not close is left
open, lowered, with the cases taken, and logged ("mojo_bounds: open goal"). An `omega` call that
stops at a resource limit counts as a failure (`tryCatchRuntimeEx`): on some refutable contexts
with remainders by `2 ^ 32` and constants near `2 ^ 64`, `omega` reaches the maximum recursion depth
when asked for the goal and not when asked for `False`, which is why step 3 asks for `False` first.

Tests (MojoProofTest/SymBounds.lean, for every value of the variables meeting the hypotheses):
`vadd_index`, `vector_addition`'s index `%19 = zext ctaid.x * sext ntid.x + zext tid.x`
(…nvptx.ll:14-23) under the special registers' `range` attributes and the path condition
`%19 <s sext %3`: `trunc` to 32 bits then `sext` (`%22`, `%23`) is the identity on its signed
value, which is in `[0, n)`; `vadd_index_launch`, the same for the special registers of every
thread of every valid launch, whose ranges `Launch.sreg_bound` gives (MojoProof/Sem/Spec.lean,
each range fact by `mojo_bounds`); `vadd_index_1d`, on every valid launch whose grid and block
have side 1 in `y` and `z`, thread `i`'s index has signed value `i` and the path condition holds
exactly when `i < n` (`Launch.index_oneDim` and `mojo_bounds`), with the twin `vadd_index_1d_twin`
(side 2 in `y`: thread 1's index is 0); `vadd_access`, the offset
`Int.bmod (0 + 4 * i) (2 ^ 64)` that `gepPtr` computes at that index is in bounds of a buffer of
at least `4 * n` bytes; `rem_var`, a remainder by a variable `k` of a value below `2 ^ 32` is
unchanged by a `trunc` to 32 bits (the remainder bounded by its dividend); and
`vadd_access_open`, with the path condition hidden behind a definition, the two goals left open
(one per sign of `n`), checked by `#guard_msgs`, which unfolding the definition then closes.

## `mojo_obl` (`MojoProof/Sym/Obl.lean`)

A tactic for the premises of a path summary: goals `WalkWith c V ps` (each block of a path of
summaries meets its obligations and exits to the next block, into blocks with `phi`s too, each
block after the first entered at `Valuation.intoWith c`; `MojoProof/Sym/Kernel.lean` asks
`WalkWith false` per thread), a block's obligations `∀ d ∈ ds, d.Holds V (vals V S.nodes)`, one
obligation, an exit `S.exit.target V (vals V S.nodes) = some l` or
`S.exit.dest V (vals V S.nodes) = some l`, and a loop's `Edge h p V l ds S E` and
`Round h p ds S B V` (`MojoProof/Sym/Loop.lean`, the premises of `ChainWith.loop` at `false` and
`Runs.of_loop`); their forms under a `fmul contract` setting `c`, `EdgeWith c h p V l ds S E` and
`RoundWith c h p ds S B V` (the premises of `ChainWith.loop` and `Runs.of_chainsWith`, whose
valuations are `Valuation.intoWith c`); statements `∀ i < K, P i` for a literal `K`, one `P i` for
each `i`; other universal statements, such as `∀ i < K, P i` for a runtime trip count `K` (a
variable, or `smax(x, 0)` of an argument), proved for an arbitrary `i` with `i < K` as a hypothesis,
so one proof covers every bound; and conjunctions and implications of them, each hypothesis (of the
context or the goal) split into its parts, the conjuncts of a conjunction and the fields of a
structure of propositions (`Obl.withFacts`, `Obl.withParts`; so the facts may come as one invariant
or one structure, such as a precondition). `V` is a valuation under `Valuation.after`s and
`Valuation.into`s: an entry valuation `Valuation.entry c k m f` (facts on `c`, `m`, `f`) or any
other (facts on `V.regs`, `V.fn`, `V.ctx.prog`, `V.mem`). A loop's rounds `Valuation.round h S B W`
are first rewritten to the `Valuation.into`s of their path, an iterate `f^[k] W` with a literal `k`
to `k` applications, and another constant to its definition. The summaries, paths and program are
concrete (as `sym_summary` and `mojo_kernel` define them).

Method. mojo_obl builds each proof term itself, from the general lemmas of
`MojoProof/Sym/OblLemmas.lean` (for every valuation, program and table) with every argument given,
and lets the kernel do the reductions: it reads the summaries, statements and paths by kernel
`whnf` and never unfolds a program in the elaborator, so a premise costs about its own size.

1. Launch facts, by type: for hypotheses `L.Valid` and `c.env = L.env k`, the register ranges of
   `Launch.sreg_lt` and `Launch.index_lt` in each dimension, and with the hypotheses of
   `Launch.index_oneDim` (a 1-D grid and block, `k` below the thread count) its index equation.
2. Node values, block by block along the path, each node when a premise, an operand or an effect
   first reads it, once (`Obl.nodeVal`): `(vals V S.nodes)[j]? = some (.ok v)` by
   `vals_getElem?_eval` and the node kind's lemma (`SNode.eval_load_at`,
   `eval_extract`, `eval_cast` on `intCast_ofNat`/`intCast_sext_ofNat` (or, for `sext` of a
   word of no small number, `intCast_sext_bits`, its sign extension), `eval_bin` on
   `intBin_add_wrap`/`intBin_mul_wrap`/`intBin_sub_wrap` without `nuw` and `nsw` (the word
   modulo `2 ^ w`) and on `intBin_add_ofNat`/`intBin_mul_ofNat` otherwise, `intBin_udiv_ofNat`,
   `intBin_sdiv_ofNat` (a positive divisor) or `intBin_sdiv_neg` (a negative one,
   `2 ^ w ≤ 2 b`), `intBin_xor_ofNat`, and for an `ashr` of a `xor` by `w - 1`
   `intBin_ashr_xor_pos`/`_neg` (0, or all ones, by the sign bits of the `xor`'s operands),
   `eval_icmp_slt_ofNat`/`_ult_ofNat`/`_eq_ofNat`/`_sge_ofNat`/`_ne_ofNat` (or, for an `eq` that
   `omega` does not decide, `eval_icmp_eq_mod`: the boolean of the residues' equality),
   `eval_and_decide` (an `and` of two booleans `decide p`, `decide q`: `decide (p ∧ q)`),
   a load after the block's stores (`SNode.loadAfter`) by its effects from the last:
   `eval_loadAfter_log_ex` (a `load` effect), `eval_loadAfter_store_codec` (a `store` at a pointer
   of the same value, of an integer word or a `Val.ofFloat` float, `Layout.Codec.int`/`.float`:
   the stored value), `eval_loadAfter_apart_at` (a `store` at a pointer apart by `omega`) and
   `eval_loadAfter_nil` (none left: the `load` from the memory), each with the effects' run
   proved as a block's,
   `eval_select_true`/`_false` (the operand the condition picks, decided by `omega`),
   `eval_select_same` (two operands of one value), `eval_select_word` (two words: the word of an
   `if` on the condition) or `eval_select_ofBool`, `eval_smax_ofNat`, `eval_sreg_at` (and, for a
   register a hypothesis equates to another number, such as `ntid.x = 1024`, `eval_word_eq`),
   `eval_laneid_at` (the lane number, below 32 by a hypothesis or by `Launch.laneid_lt`),
   `eval_globalAt_at` (a global's pointer, from a hypothesis `c.globals g = some p`),
   `eval_bitcast_at` (a `bitcast` node between scalar types of one width, `SNode.castAt`: its
   operand's word),
   `eval_gep_at` on `gep_buffer` (or `gep_buffer2` by an index `r * S + k` into the buffer of an
   `R × S` matrix, or, by an index `omega` does not bound, `gep_buffer_ok`: some value, a pointer
   or poison, taken by `Classical.choose`), a load of an element of a 1-D tensor or of a
   row-major matrix (`load_buffer`, `load_buffer2`), with integer constants by `eval_int_ofNat`
   or, negative, `eval_int_negSucc` (the word of `2 ^ w - (k + 1)`),
   `eval_fbin_ofFloat`, `eval_fbinP` (a float operator with `fmul contract` factors, the
   semantics' `floatBin` evaluated by the kernel) or, when an operand is a symbolic float
   `.ofFloat t u`, `eval_fbinP_ofFloat` with the factors' floats (`laneOf_prodsWith_some`,
   `laneOf_prodsWith_none` on `Obl.prodOf`) and `floatBin_contract_ofFloat` (an `fadd` or `fsub`
   with `contract`: `deliver` of `contract`) or `floatBin_ofFloat_factors` (another operator:
   `deliver` of `fbin`'s operation), with no `nnan`, `ninf` or other fast-math flag; `eval_flit`
   with the float constant's value `floatLit ft lit` evaluated by the kernel; the node lemmas take
   the operation's result as a premise, so their conclusions are `nd.eval V vs = r`). Registers
   after a block by `Valuation.after_regs_some` and `after_regs_none`, memory by
   `Valuation.after_mem_fold` (`Valuation.after_mem` on the fold). Registers after an edge
   (`Valuation.into`) by `Valuation.into_regs_br` and `into_regs_cond`, and into a block with
   `phi`s by `Valuation.into_regs_phi` (and through `Valuation.intoWith c` by
   `Valuation.intoWith_regs_br`, `_cond` and `_phi`; from `enter_of_phiOps`: `enter` sets the
   `phi`s' registers
   to their operands' values for the edge, `phiOps` and `evalOps`, each a register by `evalV_loc`,
   an integer constant by `evalV_int_ofNat` or a float constant by `evalV_float` (its literal's
   value by the kernel's `floatLit`); the other registers by `Valuation.intoWith_regs_phi_ne`,
   with no operand evaluated);
   memory after an edge by `Valuation.into_mem` (`Valuation.intoWith_mem`); the function and
   context through an edge by
   `Valuation.into_k`. After a collective call (`Valuation.resume V S r d`,
   MojoProof/Sym/OblLemmas.lean: the registers after the segment `S` with the call's register `r`
   set to the delivered value `d.1`, on the delivered memory `d.2`), the call's register by
   `Valuation.resume_regs_self` from a hypothesis `d.1 = some v` (an error when there is none),
   the others by `Valuation.resume_regs_ne`, and the `fmul contract` operands by
   `resume_prods_self` and `_prods_ne`.
3. Premises, by kind: a hypothesis of the local context whose type unifies with the premise's or
   unfolds to it (`f.regs r = some v` or `V.regs r = some v`, `f.fn = F` or `V.fn = F`, `c.prog = P`
   or `V.ctx.prog = P`, `m.load … = .ok v`, `c.globals g = some p` for a global's pointer,
   `m.Buffer` for a global buffer or `m.BufferIn s c size
   al o w` for a buffer of address space `s` owned by `o`, `Mem.Fits` (MojoProof/Sem/Precond.lean)
   for a buffer reached through generic pointers, `∃ blk, m.blocks c = some blk ∧ blk.addr + size ≤
   2 ^ (l.ptr s).1` for one reached through the buffer's space `s`, `o.admits c.who = true` for an
   owner other than `.all` (whose case the kernel decides), `m.Holds`, `A ∣ al`), the entries
   already proved, `A ∣ al` of two literals by `decide`, `Eq.refl` checked by the kernel, `decide`
   on closed propositions (the `range` attributes, `keepsWord`, and an obligation on a closed
   valuation that the lemmas do not reach, such as a store to a block no `m.Buffer` describes, which
   the kernel then evaluates), a special register's range by `Launch.sreg_bound` (from the launch's
   validity), and arithmetic by `omega` on the local context and the launch facts after evaluating
   closed `Nat` subterms and splitting the `if`s of the goal (to depth 4; `eval_select_word`'s
   words are `if`s), first without the context's disequalities (`Obl.hasNe`), which omega splits
   in two cases each before a `max` or `min` a bound needs, then with them.
4. Goals: `.ok x` and `.bool x` from `x`'s value, `.mem es` by running the effects
   (`SEff.apply_load_at`, `load_buffer`, `SEff.apply_store_ex`, `store_buffer`), the exit by
   `Exit.target_br`, or `Exit.target_cond_true`/`_false` with the comparison decided by `omega`,
   or `Exit.target_cond` on a word whose low bit the kernel computes;
   an exit's destination by `Exit.dest_of_target`, or for a branch into blocks with `phi`s by
   `Exit.dest_phi_ofBool_true`/`_false` (a comparison decided by `omega`) or
   `Exit.dest_phi_true`/`_false` (a constant word's low bit); a path by `WalkWith.one` and
   `WalkWith.cons2` (at `c`, or at `false`); an `Edge` or `Round` (`EdgeWith`, `RoundWith`) as
   its path's `WalkWith`, its last exit's destination and
   the position it enters at, `Exit.pc_of_fn` with the function's hypothesis and `Exit.pc`
   computed by the kernel; `∀ i < K, P i` by `forall_lt_zero'` and `forall_lt_succ'` for a
   literal `K`, else by introducing `i` and `i < K`.
   The buffer lemmas (`addr_buffer`, `gep_buffer`, `load_buffer`, `store_buffer`) take a buffer
   of any address space `s` and any owner (`Mem.BufferIn`; a global buffer `m.Buffer` is one of
   space 1 owned by every thread, `Mem.Buffer.bufferIn`) and the pointer's address space `a`
   (0 or `s`) as arguments, so the counting loop's store through a pointer of space 1 is proved
   as `vector_addition`'s through generic ones (`MojoProofTest/Obl.lean`, `cnt_rounds`), and the
   same loop's on a buffer of shared memory through pointers of space 3, owned by a block of
   threads that admits the thread (`MojoProofTest/OblShared.lean`, `cnt3_rounds`).

Each obligation and exit it proves is checked by the kernel against its statement
(`Kernel.check`), and an attempt that fails, the kernel's rejection or a resource limit included,
is undone. A goal it does not prove stays a goal, as stated, with the hypotheses of the call
(not their parts; those of an implication it proves are kept), and is logged ("mojo_obl: open
goal"); `set_option mojo_obl.debug true` logs why, with the time each attempt took. A goal under
`have`'s annotation is read through it. `Obl.run` is the method for other metaprograms.

`obl_have h₁ : e₁, …, hₙ : eₙ` (`MojoProof/Sym/OblHave.lean`, for every program) names the values
of a path's registers and memory: each `eᵢ` is `V.regs r` (a register after the path's blocks and
edges), `V.prods r` (its `fmul contract` operands), `V.mem` or `(vals V S.nodes)[j]?`, and the
tactic adds `hᵢ : eᵢ = some v` (`V.prods r = p`, `V.mem = m`, `… = some (.ok v)`) with `v` the
value step 2 computes. All the items are found in one run of the method, inside `Obl.withFacts`
(so the facts may be parts of a hypothesis), and a value two items share is normalized once; the
proof is one conjunction, split into the `hᵢ`. An item of another form, or a node the method gives
no value, is an error.

The operands (`Obl.prodOf`) follow the path back to a fact. After a block (`Valuation.afterWith c`),
a register the block does not set keeps them (`Valuation.afterWith_prods_none`); one it sets has
none with contraction off (`afterWith_prods_off`), none when its value is no `fmul contract` node
(`afterWith_prods_unfactored`, on `SVal.factors`), and else the values of the `fmul`'s two operands
(`afterWith_prods_factors`). Through an edge, a branch keeps them (`Valuation.intoWith_prods_br`,
`_cond`), and an edge into a block with `phi`s clears them for the `phi`s' registers
(`Valuation.intoWith_prods_phi_none` when they are none after the block, with no operand evaluated,
else `Valuation.intoWith_prods_phi`, which evaluates the edge's operands as step 2 does) and keeps
them for the others (`intoWith_prods_phi_ne`). At the start, a hypothesis `f.prods r = p` (or
`V.prods r = p`) gives them, or the kernel computes them for a closed frame; otherwise the item is
the error `mojo_obl: register r has no known fmul contract operands`. In step 2, a node with a
hypothesis `(vals V S.nodes)[j]? = some (.ok v)` takes that value (`Obl.nodeHyp`), and so does one
with a hypothesis `∀ xs, P₁ → … → Pₙ → (vals V' ns)[j]? = some (.ok v)` whose premises are equations
on registers, their operands or nodes at `V'` that the method proves (their right sides fix `xs`),
so a lemma about one node (whose premises are the registers, operands and nodes it reads, as in
the test `hand_node`) feeds the registers after it in the same run.

`obl_exact` (`MojoProof/Sym/WaitVia.lean`, syntax `oblExact`, elaborator `evalOblExact`, for every
program) closes a goal `e = x` whose left side is an item `obl_have` takes: it runs `Obl.haves` on
`e` and checks the equation it proves against the goal up to definitional equality, so `x` is any
term equal to the computed value. A goal that is not an equation, or a value not equal to `x`, is
an error.

The lemmas it chains are general. `withAttrs_ofNat` (return attributes that are `noundef` or a
`range` containing `[lo, hi)` keep every word in it) and `SNode.eval_sreg` (a special-register call
node is the register's value, from the program's declaration, intrinsic table and attributes)
generalize `range_attrs` and `call_sreg` (`MojoProofTest/SymCall.lean`), which take the
attributes and the declaration as hypotheses.

Tests (MojoProofTest/Obl.lean). `vadd_walk`: for every valid launch, alignment `4 ∣ al`, distinct
buffers `a`, `b`, `out` of `n < 2 ^ 31` floats that fit below `2 ^ 64`, every thread `k` and every
context, memory and frame with the listed facts: `vector_addition` walks path 0 (`%4 → %21 → %31`)
when its index `L.index k .x` is below `n` and path 1 (`%4 → %30 → %31`) otherwise, both by
`mojo_obl` after unfolding `Launch.index`; `vadd_walk_launch` is its corollary on 1-D launches,
where the index is `k`. The twin `vadd_walk_open`: with `¬ L.index k .x < n` stated through an
irreducible definition, the exit of `%4` is left open, checked by `#guard_msgs`, and closed after
`unfold`; `vadd_walk_launch_open` is its corollary on 1-D launches. `hand_walk` and an `example`:
two hand-written summaries (an `icmp ult` of registers, a register read through a block that does
not set it, a branch condition that is a word) and the empty path (the statement of
`WalkWith.nil'` at `false`).
`cnt_paths`: the counting loop `cnt` of
`MojoProofTest/SymLoop.lean`, for every trip count `n < 4` on `outC` (the runs of `cnt_run_outC`):
the entry edge (`Edge`), every round below `n` (`Round`) and the path out (`WalkWith false`), with
the `phi`
values and branches by the lemmas, and the body's address and store (to a block no `m.Buffer`
describes, on a closed valuation) by the kernel's evaluation. `cnt_entry`: the entry edge for every
context, step count, memory and frame of `cnt`; its twin `cnt_entry_open`, with `f.fn = cnt` through
an irreducible definition, leaves the position `Exit.pc` open, checked by `#guard_msgs`.
`cnt_rounds_struct`: the counting loop's rounds under an invariant that is a structure of
propositions (its registers' facts one conjunction, its room one existential); the twin
`cnt_rounds_struct_open`, with the room behind a definition the parts do not unfold (`Room`), leaves
the store's obligation open, checked by `#guard_msgs`, and closed after `unfold`. `cnt_have`: two
registers after a round by one `obl_have`; an `example` checks the error on an item that is no
register, its operands, memory or node value. `hand_prods`: the operands of a hand-written block
whose register 3 is a `fmul contract` node of registers 1 and 2, after it with contraction on and
off, of a register it copies, and of a register through its branch from a hypothesis on the entry
frame; an `example` checks the error on a register with no fact. `cnt_prods`: for every bound, the
operands after a round of the counting loop of its `phi`'s register (none) and of another (kept).
`hand_node`: a register after the hand-written block from a hypothesis on a node's value whose
premises (a register and the operands of another at the entry valuation) `obl_have` proves.

Tests (MojoProofTest/OblNaive.lean). `pre_obls`: for every valuation, the obligations of the naive
matrix product's preheader `%45` (`pre` of MojoProofTest/SymPhi.lean), whose one node is the float
constant `0.000000e+00` at type `float`, by `mojo_obl`. The twin `flit_open`: a summary whose float
constant is an unknown literal `lit`; its obligation is left open, checked by `#guard_msgs`, and
closed by `SNode.eval_flit` from `floatLit .float lit = .ok v`. `dotS_vals`: a hand-written block
of a `fmul contract` of registers 1 and 2 and the `fadd contract` of register 0 and that product,
whose operands are symbolic floats; `obl_have` gives node 1 as `deliver` of `contract` of register
0, the product and its factors. The twin `dotS_open`: with register 0 any value, the obligation is
left open, checked by `#guard_msgs`, and closed by `mojo_obl` once it is a float.

Tests (MojoProofTest/OblShared.lean). `cnt3_rounds`: the counting loop with its array in shared
memory (its `getelementptr` and `store` through pointers of address space 3), its rounds for every
bound under an invariant with a buffer of space 3 owned by block of threads `g`
(`Mem.BufferIn 3 b (8 * n) 8 (.cta g) true`) and the fact that `g` admits the thread, by
`mojo_obl`. The twin `cnt3_rounds_open`: with that fact behind an irreducible definition, the
store's obligation is left open, checked by `#guard_msgs`.

Tests (MojoProofTest/OblMatmul.lean), on the naive matrix product `naive` (`m × 768` by the
transpose of `n × 768` into `m × 50257`, binary32) with `fmul contract`, all by `mojo_obl`:
`naive_rounds`, round `i < max K 0` of its loop (`RoundWith true`), for `K ≤ 768`,
`768 m, 768 n < 2 ^ 31`, row `r < m`, column `c < n`, the loads of `A (r, i)` and `B (c, i)` from
row-major buffers; `naive_exit`, the path out of the loop and its store into cell `50257 r + c`;
`naive_entry`, the edge into the loop (`EdgeWith true`) of every thread in range of every valid
launch, for `K ≤ 768`, `50257 m < 2 ^ 31`, `n ≤ 50257`, with `%16 = smax(K, 0) = max K 0`;
`naive_skip_row` and `naive_skip_col`, the path `%6 → %44 → %69` of every thread out of range
(row, or column with the row in range), its index arithmetic modulo `2 ^ 32`, its `sext` and
`getelementptr inbounds` of no known value proved to evaluate (tests only: no proof uses them,
and the kernel theorem's skip path is `NaiveSound.naive.out`). The twin `naive_rounds_open`:
with the accumulator's register behind an irreducible definition, the latch's `fadd contract`
obligation is left open, checked by `#guard_msgs`.

Tests (MojoProofTest/OblGevm.lean), on `gevm_kernel` (`gevm` of MojoProofTest/SymLane.lean,
`y = x B` for `x` of `K` and a row-major `K × N` matrix `B` of binary32), one program, every
launch: `lane`, register `%12` after the entry block `%6` (its lane-number call, statement 5) is
the word of `%laneid` at every context whose `%laneid` is below 32, by `obl_have`; `entry_edge`,
the entry block's obligations and its edge into the loop (`EdgeWith true`) at every thread of
every valid launch with `ntid.x = 1024`, `N, K < 2 ^ 31` and output cell
`32 ctaid.x + tid.x / 32 < N`, by `mojo_obl` (the `udiv`, `sdiv` by 32 and by `-32`, `xor`,
`ashr`, `select`, `sub` and `smax` of the cell and of the trip count); `entry_regs`, by
`obl_have`, the column `%17 = 32 ctaid.x + laneid`, the cell `%29` and the trip count
`%38 = (K + 31) / 32`; `rounds`, round `i < (K + 31) / 32` of the loop (`RoundWith true`) for
every `K` divisible by 32, `K N < 2 ^ 29`, warp `w < 32` and column `col < N`, the load of
`B (32 i + w, col)` at the address `gep_buffer2` gives. The twins, each with one fact behind an
irreducible definition and checked by `#guard_msgs`: `lane_open` (the lane bound, node 6 of the
entry), `entry_open` (`K < 2 ^ 31`, the `sdiv` `%30`), `rounds_open` (`K % 32 = 0`, the load
`%52` of `x`) and `matrix_open` (`K N < 2 ^ 29`, the `getelementptr` `%55` by `gep_buffer2` and
the load `%56` of `B`); `to_barrier`, by `mojo_obl`, the obligations of the segment of `%59`
before its barrier (`summarizeTo` from statement 1 to 6, as a `Summary`) for lane and warp below
32 and a shared array that the context gives a pointer to a writable buffer of shared memory of
the thread's block: the index `32 l + w`, its `trunc`, the array's pointer (`SNode.globalAt`),
the `getelementptr` and the `store`; `to_barrier_waits`, such a thread at statement 1 of `%59`
reaches the barrier's wait (`Seg.sound`), with the twin `shared_open` (the context's pointer
of the shared array behind an irreducible definition, the array's node open); `to_shfl` and
`to_shfl_waits`, the segment after the barrier to the first shuffle (statements 7 to 11) for
`tid.x < 1024` and a shared buffer holding a vector of 1024 binary32: the load of cell `tid.x`
and its `bitcast` (`SNode.castAt`); `shfl_round` and `shfl_round_waits`, the four segments
between the shuffles (statements `12 + 4 j` to `15 + 4 j`, `j < 4`): the `bitcast`s and the
`fadd contract`, whose operand's `fmul contract` factors are `none` by a hypothesis
`f.prods r = none` when the kernel does not show it; with the twins `bitcast_open` (the shuffle's
result a word behind an irreducible definition) and `factors_open` (the factors behind one). The
statements after the fifth shuffle, and the thread through all of `%59`, are in
MojoProofTest/OblGevmThread.lean (`mojo_seg`, below).

Tests (MojoProofTest/OblLoadAfter.lean), on hand-written twins of `gevm_kernel`'s `%59` without
its barrier (one program), the `store` of statement 5 and the `load` of statement 9 after it:
`same` (a `load` effect, then the `store` at the load's cell: the stored binary32), `apart` (the
`store` at another cell, `i ≠ i'`: the entry memory's binary32 of a shared vector) and the twin
`apart_open` (`i ≠ i'` behind an irreducible definition: the node's obligation open, checked by
`#guard_msgs`). Not covered: a `store` of a float as a word (`Val.bits`) at a float type, and
pointers neither of one value nor apart by `omega` (entry registers of which the hypotheses say
nothing).

Tests (MojoProofTest/OblInt.lean), on hand-written blocks of one to three nodes at every context,
memory and frame with the stated registers: the twins of the integer lemmas no `gevm_kernel` twin
leaves open, each with one premise of that lemma behind an irreducible definition, a variable or
another term, checked by `#guard_msgs` and closed once it is given (`udiv`, `sub`, `xor`, `ashr`
of either sign, `select` of equal operands and of words, `icmp eq` of residues, a negative
constant).

Not covered: a loop on a symbolic trip count (the rounds are proved for literal counts, one by
one; the invariant of `Runs.of_loop` is not found); a `phi` operand other than a register, an
integer constant of a natural number or a float constant; and the nodes of the fragment that it
gives no value, integer operators other than `add`, `mul`, `sub`, `udiv`, `sdiv`, `xor` and an
`ashr` by `w - 1` of a `xor`, comparisons other than `slt`, `ult`, `eq`, `sge` and `ne`, and casts
other than `sext` of a word of no small number, whose obligations and exits stay open. The
statements the block checker refuses (`fcmp`, `select` of floats, pointers or vectors, float
casts, calls other than special registers, the lane number and the integer maximum and minimum,
`alloca`, barriers) are no nodes: `summarize` gives their blocks no summary.

## `mojo_vals` (`MojoProof/Sym/Vals.lean`)

A tactic for a block's node values: goals `vals V S.nodes = [r₀, …, rₙ₋₁]`, one entry per node of a
concrete summary `S`, and goals `nd.eval V (vals V (S.nodes.take j)) = r` of one node (the goals it
leaves open). `V` is any valuation under `Valuation.after`s, as for mojo_obl. These are the premises
of the `Elem` steps (`Elem.Steps`, `MojoProof/Sym/Ops.lean`) and of `Ret`
(`MojoProof/Sym/Path.lean`), which read the loaded values, the addresses and the stored value from
the table. It fails on a goal of another form and when the list does not have one entry per node.

Method. Node by node, in order, with mojo_obl's state (`Obl.M`, so the same facts by type, the
same launch facts and the same kernel-checked lemma applications):

1. An entry `.ok v`: the node's value `v'` by mojo_obl's dispatch on its kind (`Obl.nodeEval`),
   then `.ok v' = .ok v` by `Vals.conv`: syntactic equality, congruence argument by argument
   (proof arguments by proof irrelevance, a value followed by proofs about it by `Vals.congrDep`),
   an `if` on either side whose condition `omega` decides (`Vals.ifStep`), kernel defeq (not tried
   on two different constructors), the first subterm `decide p` (in `Expr.find?`'s order, past
   those `omega` decides neither way) whose `p` or `¬ p` `omega` proves, as `true` or `false`
   (`Vals.decStep`, so a comparison's `Val.ofBool (decide (i < n))` is `.bits 1 1` under
   `i < n`), the local equations on subterms (`Vals.norm`), and on `Nat`
   and `Int` `omega` from the local context and the launch facts
   (`k * 4 = 4 * k` for `gep_buffer`'s offsets, `V.k + 6 = 23` from `V.k = 17` for a float
   operator's oracle number).
2. Another entry: the semantics' operation of the node on its operands' values (`Vals.raw`):
   `icmpV` by `SNode.eval_icmpV`, `intBin`, `intCast`, `extractV` by `SNode.eval_bin`,
   `eval_cast`, `eval_extract`, and a float constant's `floatLit ft lit` by `eval_flit`, up to
   `Vals.conv`.
3. Each node's proof is checked by the kernel (`Kernel.check`) against its equation; a node it
   does not prove stays a goal and is logged ("mojo_vals: open goal (node j)"), and the later
   nodes read its entry. The later nodes read the value mojo_obl's dispatch gives when it gives
   one (so `gep_buffer`'s `K * s` offsets reach the loads).
4. The table from its entries: `(vals V S.nodes)[j]? = some rⱼ` by `vals_getElem?_eval`, and the
   list by `drop_of_getElem?` from the last entry (`List.drop_eq_nil_of_le` at the length) to the
   first (`List.drop_zero`).

`set_option mojo_obl.debug true` logs why a node stays open. `Vals.run` is the method for other
metaprograms.

Tests (MojoProofTest/Vals.lean). `vadd_vals0` and `vadd_vals1`, by `mojo_vals` alone: block `%4`'s
16 values for every valid launch, thread, `n < 2 ^ 31` and entry valuation with the listed facts
(the last entry the `icmpV` itself), and block `%21`'s 8 values for every valuation of `fn_0` at
step 17 with the listed registers and buffers (the loads `x_k`, `y_k`, the addresses `4 k`, the
`fadd` at oracle number 23). The twin (an `example`): `vadd_vals0` with the load of `%1`'s struct
behind an irreducible definition; node 2 is left open, checked by `#guard_msgs`, the nodes after it
read its entry, and `unfold` then a second `mojo_vals` close it. A third `example` runs
`Vals.decStep` on `(decide P, decide (i < n))` for a proposition `P` about which nothing is known:
it skips `decide P` and rewrites `decide (i < n)` to `true`. Not covered: an entry `.ok _` of a
node that mojo_obl gives no value (an integer operator other than `add` and `mul`, a comparison
other than `slt` and `ult`), which stays open unless it is given as the operation (step 2), and
entries that are neither `.ok _` nor one of the four operations nor a float literal's value.
`pre_vals` and `pre_vals_lit` (MojoProofTest/OblNaive.lean): the node values of the naive matrix
product's preheader `%45`, for every valuation, as the float `+0` (`Model.ofNatBits 0`) and as
`floatLit` of the literal.

## `mojo_ret` (`MojoProof/Sym/Ops.lean`)

A tactic for an elementwise kernel's memory, stated with `Elem` (`MojoProof/Sym/Kernel.lean`) and
`Ret` (`MojoProof/Sym/Block.lean`). `Elem m₀ out w cell bs k m` is the memory `m` after the first
`k` threads: block `out` is `m₀`'s with the bytes `bs i` of each thread `i < k` put at its cell
`cell i` (nothing when `bs i = none`), every other block is `m₀`'s, and every access of `m`'s trace
is owned (`Elem.Own`: an access to `out` lies in its thread's cell of `w` bytes, an access to
another block reads and is not an `atomicrmw`'s, and an access with `!invariant.load` is not to
`out`). `Ret V Q ps` (`RetWith false`) says that the path `ps` from `V` meets its premises
(`WalkWith false`, the walk with `phi` edges), that its last block's exit is `ret`, and that the
last block's effects succeed with a memory of `Q`. Goals:

1. `Elem m₀ out w cell bs K me`, from a hypothesis `SEff.run V (vals V S.nodes) S.effs = .ok me`
   of a concrete summary `S` and a hypothesis `Elem m₀ out w cell bs k M` with `M` the memory of
   `V` (`vadd_elem0`, `vadd_elem1` in MojoProofTest/Ops.lean);
2. `∃ ps ∈ paths, Ret V (Elem m₀ out w cell bs K) ps` for a concrete list of paths, or
   `RetWith c V (Elem m₀ out w cell bs K) ps` for every flag `c` (with or without
   `fmul contract`), from `Elem m₀ out w cell bs k M` with `M` the memory of `V` (`vadd.ret`,
   which `mojo_kernel`'s `map2` clause generates; `map2_contract.ret`, a `RetWith true`, in
   MojoProofTest/OpsWith.lean);
3. `Elem.Only out S me` (every access of `me`'s trace to block `out` is by a thread of `S`), from
   the run of goal 1 and a hypothesis `Elem.Only out S M` with `M` the memory of `V`
   (`vadd_only0`, `vadd_only1` in MojoProofTest/Ops.lean).

Lemmas (for every caller's memory `m₀`, output block, cell width, cells, bytes, valuation and node
values): `Elem.Steps … V vs k K es` (effects `es` take every memory of `Elem` after `k` threads to
one of `Elem` after `K` threads), `Elem.steps_nil`, `Elem.steps_skip` (a thread with
`bs k = none`, by `Elem.skip`), `Elem.steps_load` (a load through a pointer to a block other than
`out`, by `Elem.apply_load`), `Elem.steps_store` (thread `k`'s store of `bs k` at `⟨out, cell k⟩`,
by `Elem.apply_store`), `Elem.after` (a block's steps across `Valuation.after`, by
`Valuation.after_mem`), `Elem.intoWith` (the same across `Valuation.intoWith c`, by
`Valuation.intoWith_mem`), `Elem.retWith` (a path whose walk holds, `WalkWith c`, and whose last
block, entered at `Valuation.lastWith c`, returns with steps is a `RetWith c`, at `false` a `Ret`)
and `vals_getElem?_of_eq`; for goal 3, `Elem.Only.Steps out S V vs es` (effects
`es` keep `Elem.Only out S`), `Elem.Only.steps_nil`, `Elem.Only.steps_of` (every effect of a
thread of `S`, by `Elem.Only.apply`) and `Elem.Only.steps_load` (a load through a pointer to a
block other than `out`, by any thread, by `Elem.Only.log`).

Method. With mojo_obl's state (`Obl.M`, named `"mojo_ret"`), effect by effect (`Ops.steps`):

1. Node values from mojo_obl's dispatch (`Obl.opnd`), or from a hypothesis `vals V S.nodes = ws`
   when there is one (`Ops.seed`, so `vadd_elem1`'s `hvs`).
2. A load: the pointer's block `c` and `c ≠ out` by `omega` on the local context (so `p0 ≠ out ∧
   p1 ≠ out ∧ p2 ≠ out`, `a ≠ out`).
3. A store: the function and program of `V` (`Obl.fnOf`, `progOf`), the statement by `Eq.refl`
   checked by the kernel, `V.ctx.who.thread = k`, the pointer `⟨out, cell k⟩` and the bytes
   `P.layout.encode t x = bs k` by `Vals.conv` (so `vadd.bytes`' `if` by `omega` on `k < n ≤ N`),
   the width by `decide`; then thread `k + 1`.
4. At the end of the effects, `K = k` or, for a thread with no bytes, `bs k = none` by `Vals.conv`
   and `K = k + 1`.
5. A `Ret` goal: each path in order in strict mode (no goal left open) by `Obl.walk` (its premises
   and exits, `WalkWith false`), `Obl.runEx` (each block's effects succeed), the blocks before the
   last by `Elem.intoWith` and the last by `Elem.retWith`, and
   `List.Mem` of the path; when no path is proved, a split on a branch condition mojo_obl's `omega`
   decided neither way (`Obl.St.undec`, by `Decidable.byCases`, at most two deep), each case proved
   so. For `vadd.ret` that is `k < n`: path `%4 → %21 → %31` with one store when `k < n`, path
   `%4 → %30 → %31` with `bs k = none` when not. A `RetWith c` goal is proved the same way with
   `Obl.walk` (`WalkWith c`, each block after the first entered by `Valuation.intoWith c`),
   `Elem.intoWith` for the blocks before the last and `Elem.retWith` for the last.
6. An `Elem.Only` goal (`Ops.onlyGoal`): when `omega` proves the thread `V.ctx.who.thread` in `S`
   (the predicate applied and beta-reduced, as `(· < n) k`), all the effects by
   `Elem.Only.steps_of`; otherwise effect by effect (`Ops.onlySteps`): a load by
   `Elem.Only.steps_load`, its block `c` and `c ≠ out` by `omega` as in step 2, and from the first
   store on `Elem.Only.steps_of`, the thread in `S` left open when `omega` does not prove it.
7. A premise it does not prove stays a goal, logged as `mojo_ret: open goal`; in a `Ret` or
   `RetWith` goal only
   when no path or split proves it, on the first path. It fails on a goal of none of the three
   forms, and when a hypothesis it needs (the run of the effects in goals 1 and 3, the `Elem` or
   `Elem.Only` at the memory of `V`) is missing.

Tests (MojoProofTest/Ops.lean). `vadd_elem0` (block `%4`'s three loads keep `Elem`, for every
context, memories, frame and bytes), `vadd_elem1` (block `%21` advances `Elem` by thread
`k < n ≤ N`, for every valuation of `fn_0` of thread `k` at oracle `ω k` with `vadd_vals1`'s node
values) and an `example`, the statement of `vadd.ret`, which `mojo_kernel`'s `map2` clause
generates, stated by `type_of%` with its hypotheses introduced unnamed (for every valid 1-D launch,
thread `k`, `n < 2 ^ 31`, context, caller's memory, memory of `Elem` after `k` threads and frame
with the buffer facts, some path of `vadd.paths` is a `Ret` to `Elem` after `k + 1` threads), each
by `mojo_ret` alone. The twin (an `example`): `vadd_elem0` with `p1 ≠ out` behind an irreducible
definition; the goal `¬p1 = out` is left open, checked by `#guard_msgs`, and closed by `unfold`.
Goal 3: `vadd_only0` (block `%4`'s three loads keep `Elem.Only out S`, for every set of threads
`S`, with no thread fact: each load is outside `out`) and `vadd_only1` (block `%21` keeps
`Elem.Only out (· < n)` for thread `k < n`, by `Elem.Only.steps_of`), and an open-goal twin of
`vadd_only0` with `p1 ≠ out` hidden as above. MojoProofTest/OpsWith.lean: an `example`, the
statement of `map2_contract.ret` (the `map2` clause with the flag `contract` on vadd's program) by
`type_of%`, some path of `vadd.paths` a `RetWith true` to `Elem` after `k + 1` threads, by
`mojo_ret` alone; `kh_ret`, a path with an `fmul contract` product (the hand-built kernel `kh`,
whose entry block computes `fmul contract 3.0, 2.0` and branches to a block that returns, so
`pathNoProds` is false and `RetWith.exists_true_of_ret` does not apply), a `RetWith c` for every
flag `c` by `mojo_ret` alone; its open-goal twin, with `bs k = none` behind an irreducible
definition; `kq_ret`, a path through a `phi` edge (the hand-built kernel `kq`, whose entry block
computes `fmul contract 3.0, 2.0` and branches to a block that starts with two `phi`s and adds `1`
to the second), a `RetWith c` for every flag `c` and valuation of `kq`'s function by `mojo_ret`
alone, the second block entered by `Valuation.intoWith` with the `phi` operands; and its open-goal
twin, with `V.fn = kq` behind an irreducible definition, which leaves the obligation of the `add`
open. MojoProofTest/NaiveOut.lean uses goals 1 and 3 on
the naive matrix product's entry block for every thread out of bounds (an `example`; the `mat`
clause's generated `naive.out` uses them too, docs/proofs/obl.md). Not covered: loops (`RetL`,
`MojoProof/Sym/Loop.lean`), a thread with more than one store to `out`
(each store is the next thread's, as `Elem` counts them), loads from `out`, and cells or bytes
`Vals.conv` cannot match (it does not rewrite under binders).

A second kernel (MojoProofTest/Vmul.lean): vector_multiply (`Kernels.vmul`, tests/corpus/vmul/),
written for this repository, not upstream: `vector_addition` with `*` for `+`, compiled with
`--fp-mode contract=off`, so block `%21` has an `fmul` with no flags for the `fadd contract`.
`vmul_vals0`, `vmul_vals1` (by `mojo_vals`) and `vmul_elem1` and an `example` (by `mojo_ret`) are
four of the vadd statements with `Kernels.vmul.prog`, its `fn_0`, the library's summaries
(`Kernels.vadd.b0` for block `%4`, which `mojo_kernel vmul` names in MojoProof/Kernels/Vmul.lean,
and `Kernels.vmul.b1`), and `Model.mul` for `Model.add` in the product and in the bytes
`Kernels.vmul.bytes`; neither tactic changed. The `example` states the generated
`Kernels.vmul.ret` by `type_of%`, as MojoProofTest/Ops.lean does `Kernels.vadd.ret`; block `%4`'s
`Elem` step is `vadd_elem0` itself. The test summarizes nothing again. Not covered: the default
compile (`fmul contract`), whose block `%21` `summarize` refuses.

## `mojo_inv` (`MojoProof/Sym/Inv.lean`)

A tactic for a loop's invariant (`Round.of_inv`, `MojoProof/Sym/Loop.lean`) at a valuation `V`
after a path or rounds of a loop: a conjunction, or a structure of propositions field by field,
of register equations `V.regs r = some v`, the function `V.fn = F`, the `fmul contract` operands
`V.prods r = p`, and memory facts at `V.mem` (`Mem.Buffer`, `Mem.Fits`, `Mem.Holds`, `Elem`,
`Elem.Only`). The hypotheses are found by type as mojo_obl finds them (the registers of an entry
frame or valuation, the function, the program, the launch, buffers), and each hypothesis gives
its parts, the conjuncts of a conjunction and the fields of a structure of propositions (so an
invariant such as `SymLoop.invN` or a structure of facts as a hypothesis).

Lemma (for every program, loop and path): `Valuation.iterate_regs_keep`. For every flag `c`,
header `h`, summary `S`, path `B`, valuation `V` of function `F`, register `r` that no `phi` of
`F` sets (`Func.phiSets F r = false`) and no summary of `S :: B` sets, and every count `i`, the
`i`-th iterate of `Valuation.roundWith c h S B` keeps `r`'s value at `V`. One edge's registers are
`Valuation.intoWith_regs_br`, `Valuation.intoWith_regs_cond` and `Valuation.intoWith_regs_phi`
(`MojoProof/Sym/OblLemmas.lean`). For the memory (for every memory, output block and access):
`Elem.log_read` (a read that is not an `atomicrmw`'s, of a block other than the output block,
keeps `Elem`), `Elem.Only.log_other` (an access to another block keeps `Elem.Only`) and
`Mem.blocks_keep` (a
memory with `m`'s blocks has each of them, the premise of `Mem.Buffer.of_block`,
`Mem.Fits.of_block` and `Mem.Holds.of_block`); for every valuation, node values and effect,
`SEff.run_one` (a run of one effect is its application to the valuation's memory).

Method (`Inv.run`, with mojo_obl's state named `"mojo_inv"`; `Inv.prove` takes a conjunction
conjunct by conjunct and a structure of propositions field by field), for each register equation
(`Inv.reg`):

1. `V` is `f^[i] W` for a round `f` (`Valuation.roundWith c h S B`, `Valuation.round h S B`, or a
   constant that unfolds to one, as `NaiveThread.round`; `Inv.roundOf?`) and a count `i` that is
   not a literal: `r`'s value at `W`, by `Valuation.iterate_regs_keep`, whose two conditions the
   kernel decides, the round's function being `Obl.fnOf` of `W` by its blocks and edges
   (`Inv.pathV`), so `W` may itself be a valuation after a path, as `NaiveThread.head`.
2. Otherwise `V` by its blocks and edges (`Inv.pathV`: a path's last block
   `(Valuation.lastWith c W l S ps).1` by `Obl.lastIOf`, other constants unfolded, then
   `Obl.normV`), and the register by `Obl.regOf`: through a block by its register list
   (`Valuation.after_regs_some`, `Valuation.after_regs_none`, the node's value from mojo_obl's
   evaluation), through an edge into blocks with `phi`s by `Valuation.intoWith_regs_phi` (the
   `phi`'s operand for the edge; the others by `Valuation.intoWith_regs_phi_ne`, with no operand
   evaluated), and through other edges
   by `Valuation.intoWith_regs_br` and `Valuation.intoWith_regs_cond`, down to a hypothesis on the
   entry frame's or valuation's register.
3. The value found is proved equal to `v` by `Vals.conv`.

The function and the `fmul contract` operands are `Obl.fnOf` and `Obl.prodOf` on `V` by its
blocks and edges, after a hypothesis with the goal's left side. A memory fact (`Inv.memFact`):
`V.mem` is the memory `M₀` before `V`'s blocks with the events they log (a hypothesis `V.mem = M`,
as `obl_have` gives, else `Obl.memOf`, which evaluates only the nodes the blocks' effects read,
`Obl.nodeVal`; `Inv.memEq`, `Inv.logs`; naming the memory in the `obl_have` that already
evaluates those nodes, as `round_in` does, still saves their evaluation); a buffer fact is its
hypothesis at `M₀` moved by `Mem.Buffer.of_block`, `Mem.Fits.of_block` or `Mem.Holds.of_block`, the kernel checking that `V.mem` has `M₀`'s blocks;
`Elem` and `Elem.Only` are their hypotheses at `M₀` through each event, an access whose block
(read off its pointer by the kernel) `omega` shows is not the output block, and, for `Elem`, a
read that is not an `atomicrmw`'s (`Elem.log_read`, `Elem.Only.log_other`). On a memory `m` an
effect
gives (`Inv.effHyp?`: a hypothesis `SEff.apply V vs M e = .ok m`, or a
block's run of one effect, as `RetWith` gives, by `SEff.run_one`): `Elem.Only` is its fact at
`M` (by the rule above at `V.mem`, else a hypothesis) through the effect, the thread in the set
by a hypothesis (`Elem.Only.apply`); `Elem` after `k + 1` threads is `Elem` after `k` threads at
`M` through a store (`Elem.apply_store`), with the store's statement from `V`'s function
(`Valuation.stmt_of_fn`), its operands by `Obl.opnd`, the thread from the context's hypotheses
(`Inv.ctxEq`, `Inv.threadEq`: `c.who = ⟨k, _⟩` or `c.who.thread = k`), and on `V.ctx.prog`
(`Inv.viaProg`, a hypothesis `c.prog = P`) the value's encoding `bs k` by a hypothesis and the
store's width by the kernel.

Each goal's proof is first built unchecked, and the kernel checks the whole proof once; when a
goal is left open or the kernel rejects that proof, the goals are proved again, each proof checked
by the kernel on its own (`Inv.attemptIf`, `Obl.attempt`), so that a proof the kernel rejects
leaves only its goal open. A goal it does not prove, and a goal of another form, stays a goal,
logged as `mojo_inv: open goal`.

Tests (MojoProofTest/Inv.lean). `cnt_regs`: for the counting loop `cnt`
(MojoProofTest/SymLoop.lean), every bound `n ≤ 2 ^ 60`, round `i < n` and valuation of `invN`, the
counter `%i` after the round `1 → 2` is `i + 1` (the `phi`'s operand `%inext`), and the bound `%n`
after any number of rounds is `n`. `naive_regs`: for the naive matrix product's loop `naiveL` with
`fmul contract` and `naive_rounds`' premises, `%47` after `NaiveThread.round` is `i + 1` (the
latch's `select` picks `%47 + 1`), and `%16` after any number of rounds is `max K 0`. `naive_path`:
at the latch's entry `NaiveThread.latchAt` (the last block of the path `%46 → %50 → %52`), `%47` is
unchanged (method step 2 with a path), and for `K ≤ 768` and `i < max K 0` the latch's comparison
`%49 = icmp slt %47, %16` is `.bits 1 1` (`Vals.decStep`); its twin `naive_path_open` states `%16`
through an irreducible definition and leaves `%49` open. `naive_head`: at the loop's head, `%47` is
0 and `%48` is `+0`, a `phi`'s float constant; its twin `naive_head_open` leaves `%48` open while
the function is hidden. `naive_iter`: after the head and any number of rounds, `%16` is
`max K 0`, with no hypothesis on the head's function (step 1 on a `W` after a path); its twin
`naive_iter_open` leaves `%16` open while the frame's function is hidden. The twin `cnt_regs_open` hides the counter's register behind
an irreducible definition; the counter's equation is left open, checked by `#guard_msgs`, and closed
once the definition is unfolded. `naive_mem`: after `NaiveThread.round`, whose two loads read `bA`
and `bB`, `bA` is still the buffer holding `A`, `bB` still fits, and `Elem` and `Elem.Only` with
output block `o` still hold, for `bA ≠ o` and `bB ≠ o`; its twin `naive_mem_open` states `bB ≠ o`
through an irreducible definition and leaves `Elem.Only` open. `mojo_kernel`'s `mat … inv`
clause proves `Mat.Head` (the function, buffers, `Elem`, `Elem.Only`) at the loop head by
mojo_inv; MojoProofTest/NaiveFamRun.lean proves `%48`'s `fmul contract` operands by it,
at every row stride (`NaiveFam.head_inF`, `NaiveFam.round_inF`).
`naive_store`: on the memory of `SymPhi.fin`'s run (`%67`'s store of `%68` into `%40`'s
cell), `Elem` after one more thread (`Elem.apply_store`, the encoding by a hypothesis) and
`Elem.Only` (`Elem.Only.apply`); NaiveFamRun's `exit_inF` uses it (NaiveIn's `exit_in` is its
instance at the corpus strides). Not covered: a block of several
effects with a store, a write to another block for `Elem`, and registers
that a `phi` sets after a symbolic number of rounds (the induction over the rounds stays with the
caller).

## `mojo_race` (`MojoProof/Sym/Race.lean`)

Goals: the premises the race-freedom results take of a kernel's accesses (docs/proofs/race.md):
`Apart cell w` (of `Elem.safe`), `Elem.Own out w cell a` for an access with given fields (the
`owned` field of `Elem`), `∀ x ∈ l, P x` for a list of accesses, `x.conflict y = false` for two
accesses (the pairwise form of `Grid.advance_comm`'s `hW`), and `Grid.owned_sound`'s `hX`, `hL`,
`hI` and `hO` (for the tiling `Tiling.clip` of `out` and the thread numbers as tiles; `hX` also
for the tile map through the index word on a valid 1-D launch).

Method. A list is taken element by element (`List.forall_mem_cons`). Each goal is tried by a
fixed list of routes, each kept only if it closes the goal: the introductions then `omega` (affine
cells with a literal stride, `hX` for an `own` that is injective with a literal stride, `hL`);
`apart_stride`; `Elem.Own` unfolded into its three implications, each by `rfl`, `⟨rfl, rfl⟩`,
`contradiction` or `omega`; `Access.conflict_of_reads`; `Access.conflict_of_apart` then `omega`;
`Elem.Own.invariant_apart` with a hypothesis that every access of the trace is owned (`hI`);
`Elem.Own.owned` with that hypothesis and one that every access to `out` ends by the extent (`hO`);
and `Launch.thread_eq_of_index` (`Launch.index_inj` and `Launch.index_oneDim`) with the launch's
validity, its 1-D sides and a hypothesis that every access's thread is below the thread count
(`hX` for the tile map `fun t => BitVec.ofNat 64 (ctaid.x * ntid.x + tid.x)` of thread `t`'s
registers). The facts are the local context's (`omega` reads every hypothesis, `assumption`
matches by type, `solve_by_elim` applies the bound hypothesis). A goal no route closes stays
open, as stated, and is logged ("mojo_race: open goal").

Tests (MojoProofTest/Race.lean). `vadd_apart`, `vadd_owned` (the six accesses of thread `k`'s
active path as a literal template, for every launch and `k`; no run is assumed), `vadd_stores`,
`vadd_loads`, `vadd_hX`, `vadd_hX_index` (the index word, for every valid 1-D launch, trace
with its threads below the thread count and tiling), `vadd_hL`, `vadd_hI`, `vadd_hO` (for every
trace with the two hypotheses); the twin (an `example`; `tid.x` alone as the index on two
blocks: the two stores' collision stays open, both accesses named, checked by `#guard_msgs`) and
`twin_clash` (the two stores conflict). Not covered: an `hO` with another tiling or tile map,
`hX` through the index on a launch of more than one dimension, and cells not linear in the
thread.

## `sym_summary` (`MojoProof/Sym/Command.lean`)

`sym_summary n := P fn lbl p0` evaluates `summarize P fn lbl p0` with Lean's compiled evaluation
and adds `n : Summary` as the quoted result; it refuses a block outside the fragment. Untrusted:
the kernel re-evaluates `summarize` when it checks `covers … n = true`, so a wrong evaluation or
quotation makes the check fail. The quoted table has one constructor term per node, so the
quotation is linear in the block's size. Tests: `MojoProofTest/Sym.lean` (`vector_addition`'s
blocks `%21`, `%30`, `%31`; the twins with a wrong register entry, a dropped obligation, the
conditions reversed (the check is by position), a relabelled atom in the table, reordered
effects and another exit evaluate to `false`; the entry block `%4`, with its three
special-register calls, is accepted (`vadd4_covers`), and its twins, the summary with the call
node of statement 7 moved to statement 9 and the block with the fast-math flag `nnan` on that
call, are refused, by `covers` and by `sym_summary` (`vadd4_twins`)); `MojoProofTest/Vals.lean`
(`b21`, block `%21` from position 1, after its `trunc`, a summary no library definition holds;
`simp only [b21]` unfolds it in its own module).

On block `%21` the summary has three accesses (two loads, a store) and one payload term
`fadd(load a i, load b i)` at one oracle position (`vadd21_shape`). Roles (`Atom`,
`payloadFree`, `Σ.oblivious`) are not implemented.

## `mojo_seg` and `sym_segs` (`MojoProof/Sym/OblSeg.lean`)

A block with collective calls (the barrier, warp shuffles) runs in segments (`summarizeSegs`,
`Seg.through`, MojoProof/Sym/Segment.lean): each to its call, the thread then resumed with the
value and memory the collective delivers. `RunsVia c Q ws t m` is a thread's run through the
calls of `ws`, one pair `(P, d)` each (the waiting thread, the call and the memory at it meet `P`,
so `P` can state the instruction the thread waits at, `Thread.at`; the thread resumes with `d`),
then to its end on a memory of `Q`.

`sym_segs n := P fn lbl p0 ps` evaluates `summarizeSegs P fn lbl p0 ps` (the segments of block
`lbl` from position `p0` to the calls at the positions `ps`) when it is elaborated and adds
`n_0`, …, `n_k : SegSummary` as the quoted segments, as `sym_summary` quotes a block's summary;
an optional doc comment becomes each definition's docstring, with the segment's number and call
position. It refuses a block outside the checker's fragment. Untrusted: a theorem uses the
segments through `summarizeSegs … = some ([n_0, …], L)`, which the kernel evaluates. Quoting
them keeps `mojo_obl` from evaluating the summarizer when it reads a segment's table.

`mojo_seg`, on a goal `RunsVia c Q ((P, d) :: ws) t m`, applies `RunsVia.of_through` at the latest
`Seg.Through` hypothesis with a segment (the one `Seg.through` gives, then each continuation's),
with the latest hypotheses on the valuation, the frame's function, position and `alloca` blocks,
the delivered values by `rfl` (as `fun i => [d₀, …].getD i d₀`), and `P` by `decide`, or, for
`P` as `fun _ i _ _ => i = cl.intr`, by the kernel's decision that the segment's collective is the
barrier or a shuffle of a mode; for `P` as `fun u i _ _ => u.at = some (n, lbl, q) ∧ i = cl.intr`,
first by the kernel's decision that `q` is the call's position (`RunsVia.of_through` gives
`u.at`). It runs `mojo_obl` on the segment's obligations at the valuation
the thread resumes at (`Valuation.resume`), whose open goals come first, then introduces the
continuation's frame, thread and facts, anonymous, for the next `mojo_seg`. After the last call,
`RunsVia.of_ends` takes the block's obligations, its exit and a returning path from its target
(`RetWith`). It fails, with a message, when there is no such hypothesis or `P` is not decided.
For every program.

Tests (MojoProofTest/OblGevmThread.lean), on `gevm_kernel`'s block `%59` (one program, float32
`1308aaae`): `seg_0` to `seg_5` (`sym_segs`, statement 1 to the barrier at 6 and the shuffles at
11, 15, 19, 23 and 27) and `segs_eq`; `thread`, for every thread at statement 1 of `%59` with
lane and warp below 32, `tid.x < 1024`, a shared buffer of 1024 binary32 the barrier delivers and
binary32 values the shuffles deliver: it runs through the barrier and the five shuffles (six
`mojo_seg`s), waiting at each at its statement (`Thread.at`), to its `ret` (`RunsVia.of_ends`,
by `mojo_obl`), lane 0 storing at its output cell (`SEff.run_store_one`) the sum by five `fadd`s
of the array's cell `tid.x` and the delivered values, each as `deliver` gives it, and the other
lanes storing nothing. The delivered values are premises, not the other lanes' sums, and it is
not joined to the kernel's entry and loop. The twin `tail_open` (the fifth shuffle's value
behind an irreducible definition: the `bitcast` `%86`'s obligation open) and mojo_seg's refusal
with no `Seg.Through` hypothesis are checked by `#guard_msgs`.

## `warp_route` (`MojoProof/Sym/WarpRoute.lean`)

A warp's run through `J` shuffles is `WarpRun.of_waits` (MojoProof/Sym/Canon.lean) from four
premises over the lanes `j ∈ warpLanes L k` and, but for the first, the phases `i < J`: each lane's
run through its waits (`hr`), the waits' shuffles (`hW`), the waits' memories (`hm`) and each
phase's start on the memory the one before leaves (`h0`). A kernel's proof states its lanes' facts
as `∀ j < N, …` with `N` the lane count and its lanes' runs as `RunsVia.of_fires` gives them, so
the glue is the move from `j < N` to `j ∈ warpLanes L k`, the lanes' runs in of_waits's form and
the premises lane by lane and phase by phase.

`warp_route (J := …) (W := …) (M := …) … using e₁, …`, on a goal `∃ Es, WarpRun L c k t m Es m'`:

1. every hypothesis `∀ j < b, P j` whose bound `b` is the lane count `(warpLanes L k).length`, or
   is `N` with a hypothesis `(warpLanes L k).length = N`, becomes `∀ j ∈ warpLanes L k, P j` under
   its name (`mem_warpLanes`); facts are found by their types, not by their names;
2. `refine WarpRun.of_waits` with the named arguments (`J`, `fn`, `lbl`, `W`, `mo`, `X`, `M`);
3. each premise: by a term `eᵢ` whole or by a hypothesis; or, its phase `i` and lane `j`
   introduced under fresh names, by the lane's facts: every hypothesis and term that takes a lane
   taken at `j` (and at `i` if it takes a phase), their conjuncts (through `∧`, equations of pairs
   and Boolean `&&`, `decide` and `==`, a definition at the head unfolded once), and every term
   whose premises those facts fill (two rounds); the premise whole or, when `J` is a numeral, one
   case per phase (`interval_cases`), each case by one of those facts, a hypothesis, `rfl`, a
   conjunction of their conjuncts, or a term or `Program.shfl_nil` applied backward;
4. the lanes' runs (`hr`) at a lane from a fact that is a lane's run, by its form:
   `RunsVia.of_runs` for `Runs c t m m'` (no wait), `RunsVia.of_block` for a run through
   `ws.map (Piece.Wait.via fn l)`, `RunsVia.of_blocks` for one through
   `a.map (Piece.Wait.via fn l₁) ++ b.map (Piece.Wait.via fn l₂)`; the lists' lengths by facts,
   the labels by `decide`, the run's end by a fact after substituting its end memory;
5. the shuffles (`hW`) by `WarpRun.shfl_of`: the lanes' one program `P` and each lane's
   `Piece.Wait.shflOk` (a Boolean: each wait's shuffle mode, position, full mask, offer, lane
   operand, clamp and `Grid.fire`'s delivery) by facts, the keeping premise (the shuffle
   declarations' result attributes keep the deliveries) by a fact, a term or `Program.shfl_nil`
   from `P.shflNil`.

A premise it does not close stays a goal, as `WarpRun.of_waits` states it, its binders not
introduced; the shuffles' premise stays `WarpRun.shfl_of`'s keeping premise when that lemma's
other premises close. It fails, with a message, on a goal that is not a warp's run. For every
program, launch, contexts, warp, threads, memories, waits and number of phases. Its uses, each one
call with no other proof line: `warp78` and `warp43` (MojoProofTest/GemvWarp.lean, seven and two
phases; `using` gemv's lane lemmas `lane` or `lane43`, `start_frame`, `out_covers`, `mems_of` and
`gemv_nil`), `skipWarp` (MojoProofTest/SymCanon.lean, no phase; `using skipLane`) and `shflWarp`
(one phase; `using lane, prog_eq, keep`). Tests (MojoProofTest/WarpRoute.lean), each at every
launch, contexts, warp, threads and memory: at no phase the lanes' runs closed by `RunsVia.of_runs`
and by a `using` term, and left open when no fact gives a run's end (`#guard_msgs`); at one phase
everything closed through `RunsVia.of_block`, `WarpRun.shfl_of` and `Program.shfl_nil`, the lanes'
runs left open without the waits' lengths and the keeping premise left open without `P.shflNil`
(`#guard_msgs`); at two phases everything closed through `RunsVia.of_blocks`, the lanes' runs left
open when the labels are not the blocks' (`#guard_msgs`); at two phases with a list literal of
waits the lanes' runs by a lifted hypothesis, the waits' memories by the conjuncts of a lane's
fact, the phases' starts by `rfl` and the shuffles left open (`#guard_msgs`); and the refusal of a
goal that is not a warp's run. docs/automation.md has what is automated and what is not.

## `mojo_kernel` (`MojoProof/Sym/KernelCmd.lean`)

`mojo_kernel n := P fn reads x := a0, … writes y := a2, … scalars z := a3, … pointers p := a4, …
map2 t e bytes` names the parameters of kernel `fn` of program `P` by clause (`pointers` for a plain
pointer parameter, not `byval`) and adds the summaries `n.b<i>` of its blocks (`summarize`, as for
`sym_summary`), its paths from the entry `n.paths`, `n.covers` (by `decide +kernel`) and the kernel
theorem `n.sound_of`; when `fn` elaborates to a constant and `P` has no globals, also `n.args`,
`n.starts` and `n.sound`; and with the optional `map2` clause, for a binary elementwise kernel, also
`n.argTy`, `n.argTail`, `n.ret` (each thread's path is a `Ret`, by `mojo_ret`) and `n.correct`
(`Kernel.sound_map2`). It refuses clauses that do not name each parameter once with its kind, a
block outside the checker's fragment and a loop (a branch to a block on the current path) that no
`loop` clause names, and with `map2` an `fn` that is not a constant, a program with globals and a
kernel of another shape; a refused command adds nothing. An `n.ret` that `mojo_ret` does not prove
is an error. A `loop h := pre inv trips post by tac` clause, one per loop for loops in sequence (a
loop nested in another is refused), takes the loop with header block `h`, its invariant `inv` and
trip count, and adds the loop's obligations (proved by `tac`), `n.chains`, `n.coversChains`,
`n.loop` and, when `fn` is a constant and the program has no globals, `n.sound_loop`: the kernel
theorem on `n.args` from `Mem.Closed` and an invariant, each thread's precondition from the start's
facts and the registers of its scalar and pointer parameters (`Kernel.sound_entry`). docs/kernel.md
has the steps, what each definition states, the sharing of definitions in library modules and the
tests (`MojoProofTest/KernelCmd.lean`, `MojoProofTest/KernelLoop.lean`); the instances are
`MojoProof/Kernels/Vadd.lean`, `MojoProof/Kernels/Vmul.lean` and `MojoProof/Kernels/Vsub.lean`, and
the loop clause's is `kernelK` in `MojoProofTest/KernelLoop.lean`. `kernelC` in
`MojoProofTest/KernelCells.lean` is the instance of `Kernel.sound_cells` (threads that each run a
counted loop and then store one cell, apart only on the storing threads), proved without the
command.

## `#mojo_info` (`MojoProof/Sym/Info.lean`)

`#mojo_info P` prints, per function of program `P` with blocks, the intrinsics it calls (direct
callees that `P.intrinsics` names) with their numbers of calls, separately the other functions it
calls (calls of module functions) with theirs, its phases (`barrier` calls plus one), its back edges
(branches to a block at or before the branching one, in the function's order), its float operators
with their fast-math flags, its fusable pairs (`fusable`: the operands of an `fadd` or `fsub` with
the `contract` flag that are results of an `fmul` with the `contract` flag, which the compiler may
fuse into a multiply-add), and per block its size, its `phi`s, its successors and the block
checker's verdict from after its `phi`s: in the fragment, or the first statement (or the terminator)
the checker refuses (`refusal`), printed as LLVM text. Untrusted and unproved: it is a report, not a
certificate.
Tests: `MojoProofTest/SymInfo.lean` (`refusal_vadd` by `decide +kernel`: blocks `%21` and `%4`
are in the fragment, block `%30` of `withHelper` is refused at statement 0; the report on
`vector_addition`, whose calls are all intrinsics (`calls: []`); the report on `withHelper`,
`vector_addition` with a call of a module function `@helper` in block `%30`, which prints
`calls: [@helper ×1]`, the refusal of `%30` at that call and `@helper`'s own report; an error on a
program without functions with blocks; the fusable pairs: 0 in `vector_addition` and
`vector_multiply`, 64 in `tiled_matmul`, and on the ten float32 naive matmul kernels of the
multistage GEMM test 1 each with the default flags (`tests/corpus/mgemm/`) against 0 each compiled
with `--fp-mode contract=off` (`tests/corpus/mgemm_nocontract/`)).

On the corpus (`lake env lean` on a file with `#mojo_info Kernels.vadd.prog` and
`#mojo_info Kernels.matmul.prog`): `vector_addition` has one phase,
no loops, `fadd contract`, and all four blocks in the fragment, the entry `%4` with its three
special-register calls included. `tiled_matmul` (fully unrolled: no back edges) has 9 phases
(8 barriers), `fmul contract` and `fadd contract`; 7 of its 28 blocks are in the fragment (the
four empty branch blocks and the epilogue `%569`, `%573`, `%574`), 16 are refused at a
`getelementptr` whose base is a shared-memory global, 4 (`%67`, `%297`, `%400`, `%503`) at their
first statement, a barrier, and the entry `%3` at statement 32, a `select` (its four
special-register calls before it are in the fragment). So the next fragment steps for
`tiled_matmul` are, in order: global operands (`Value.glob`, an atom read from `Ctx`), `select`,
barrier calls (a block split at the call, with the call's `step` from `Grid`), and
`fmul contract` (the `prods` record).

## The mutation harness (`MojoProof/LLVM/Mutate.lean`)

One generic program for every module, driven by a finite operator table given as data: `Mutate.Op`
is the table's type and `Op.mutants` its interpretation as edits of the `MojoProof.LLVM` syntax. The
operators: `icmp p q` (predicate `p` replaced by `q`), `brTrue` (a conditional branch's condition
replaced by `true`), `gepIdx d` (`d` added to a `getelementptr`'s last index: a constant changes,
any other index goes through a new local `add t x, d` placed just before), `storeDel`, `storeTo` (a
store redirected to a compatible pointer: a parameter or an earlier result of the same block that
the function loads or stores through with the same address space, type and alignment,
`Func.compatible`), `gepTy s t` (a byte-width change: the element type of a `getelementptr`),
`inbounds` (toggled), `dropAttr k` (flag `k`, such as `noundef`, removed from a return or parameter,
declarations included), `range d` (`d` added to the upper bound of a `range`) and `id` (the
identity, once per module: the control). The test table is `MojoProofTest/Mutate.lean`'s `table`.

`run tbl P n` enumerates every mutant of every operator (`mutants`), selects at most `n` stratified
by operator (`select`, round robin), and classifies them (`classify`). Admission (`admission`): the
printed mutant imports (`importBytes`: parse, closure, data layout), has the tokens of its import
printed back (`printDiff`, as `mojo_import` checks), parses back to the same AST, uses no local it
does not define (`Func.undefinedUse`), and indexes its type with every `getelementptr` instruction
(each index after the first steps into an array's or vector's element or names a struct's field by
an `i32` constant in range); the admitted mutant is the AST the text parses to. Then exact AST
deduplication: equal to the original is `equivalent` (certified by the equality), equal to an
earlier mutant is `duplicate j`. Then the checker (`refused`): `unsupported` when `Sym.summarize`
refuses a block of a ptx_kernel function (so `Sym.covers` holds for no summary). Then, given an
`Instance` (kernel function, launch, arguments, memory, address choice, oracle, fuel, phases, and
the output block with the final contents the contract fixes), the replay (`Instance.replayMutant`:
`Kernel.replay` of `MojoProof/Sem/Replay.lean` on `Mutant.program`, by evaluation): a reported
violation is `killed` when the mutant's index is in the caller's certified kills and `refuted`
(killed by evaluation, uncertified, counted as unknown) when it is not. The certified kills have
the type `Kills P ms I` (for `run`, `ms` is `selected tbl P n`), whose constructor is private:
outside `MojoProof/LLVM/Mutate.lean` a value is `Kills.empty` (the default, no kills) or one that
`mojo_kills` (below) defines, each index with a checked theorem. No violation, or
an undecided replay, is `passes` (counted as unknown: one instance is no proof against the contract,
so not survived). With no instance a mutant is `unclassified`. Conforming and survived need a proof
against the contract and no proof search runs, so they and infrastructure failure, timeout and open
proof are 0. `Counts.lines` prints the summary counts (generated, selected, admitted, equivalent,
conforming, killed, unknown) and each class; `Report.text` adds one line per selected mutant.
Admission does not check that a definition dominates its use, and of the types it checks only the
indices of `getelementptr` instructions. `storeTo` redirects only to a parameter or an earlier
result of the same block, and `gepIdx`'s new local is defined just before its use, so those
definitions dominate their uses. The operators do not all preserve types: `gepIdx` on a struct's
field index and `gepTy` on an instruction with more than one index can give indices that do not
index the type (a field the struct lacks, an index into a scalar); admission refuses those mutants
as malformed. The other edits keep the types: `storeTo`'s pointer has the store's address space,
type and alignment, `gepIdx`'s new local has the index's type, `gepTy` on an instruction with one
index changes only its stride, and the other operators delete a store or change a predicate, a
branch condition to the constant `true`, a flag or an attribute.

A certified kill is a theorem. `mojo_mutant x := e` evaluates `e : Program` (a mutant's) and adds
its term as `mojo_import` does (`quoteProgram`: `x.fn_<i>.b_<j>`, `x.fn_<i>`, `x.module`, `x.prog`,
sharing the original's unchanged blocks), checked to evaluate back and to print with its tokens. The
docstrings of the definitions it adds cite the mutant, not a corpus file (`mutantDoc`): the term
`e`; when `e` unfolds to `Mutant.program` of an indexed list, the operator, the site, the index and
the program it mutates (`mutantSource`); and the SHA-256 of the printed module. That of `x.prog`
says that its `sha256` field is the mutated program's digest, which `Mutant.program` keeps.
`Instance.refutes` (`Kernel.replay_block` on an instance) turns the replay on that term, decided by
`decide +kernel`, into `Instance.Refuted`: for every admission that admits the instance's choice and
oracle, the mutant is not sound for the observation of the blocks and the contract's relation. The
kernel cannot run the enumeration itself (the derived `BEq` of the nested `Ty` is `partial`, so
`Op`'s equality does not reduce), hence the quoted term. Each certified kill is a `mojo_mutant` line
and a theorem by `Instance.refutes` with `decide +kernel` (never `native_decide`).
`mojo_kills ks : mutant on I R := [k₁ => t₁, ...]` defines `ks : Kills P ms (some I)` with
`ks.rel = R` and `ks.ks = [k₁, ...]`, the kills to pass as `run`'s `certified`. `mutant` must
unfold to `fun k => Mutant.program P ms[k]!` with `P` and `ms` free of `k` (as
`fun k => ((selected tbl P n)[k]!).program P`), which gives `P` and `ms`. For each row it checks at
elaboration that `kᵢ` is below the length of `ms`, that `tᵢ` is a theorem whose type is
`Instance.Refuted I Q fn R` with the given `I` and `R` up to reducible unfolding, a program `Q`
whose evaluation has no field (`Program.diff`) that differs from `mutant kᵢ`'s, a function `fn`
that evaluates to that program's function `I.f`, and a proof with no axioms but `propext`,
`Classical.choice` and `Quot.sound` (`foreignAxiom` with `killAxioms`); any failed check is an
error and defines nothing. `run tbl P n I` takes only kills of type `Kills P (selected tbl P n) I`,
so kills of another selection, program or instance do not type-check, and a hand-written list or
structure is refused (the constructor is private). What it does not check: that the instance fits
the contract (`rel` is not tied to `I.put`), and that every refuted mutant is listed; the type
holds no proof (the kernel cannot run the enumeration), so its guarantee is that of the
elaborator's checks, and a metaprogram naming the private constructor can still build a value.

Tests (`MojoProofTest/Mutate.lean`), with the test table (10 `icmp` boundary swaps, `brTrue`,
`gepIdx` plus and minus one, `storeDel`, `storeTo`, `gepTy` float to half and to double,
`inbounds`, `dropAttr "noundef"`, `range (-1)`, `id`) and a budget of 32:

* `vector_addition`, replayed on `vaddAt` (`MojoProofTest/Kernel.lean`'s launch `L23`, 2 blocks of
  3 threads, memory `mem5`, address choice `ch₀`, oracle `ω₀`, fuel 100, 3 phases, output block 3
  against `correct23`'s relation `Sym.Elem.Out`): generated 31, selected 31, admitted 31,
  equivalent 1, conforming 0, killed 8, unknown 22; malformed 0, duplicate 0, unsupported 0,
  refuted (uncertified) 9, passes 13, unclassified 0. The replay refutes 17: the icmp swap and the
  constant branch (out of bounds at thread 5), the 6 index changes (out of bounds at thread 4,
  access through poison at thread 0), the store deletion (the output block differs), the 2 store
  redirections (a store to read-only memory), the 6 width changes (misaligned at thread 1, poison
  at thread 3). The 8 with a theorem (`vadd_m0` to `vadd_m7`: mutants 0 to 7, one of each
  operator that refutes) are certified kills; the other 9 are refuted by evaluation only. The 13
  that pass (3 `inbounds`, 7 `noundef`, 3 `range`) are unknown, not survived. Every mutant with
  its site and outcome is pinned (`#guard_msgs`); the identity mutant replays with no violation
  (`#guard`);
* vector_multiply on `vmulAt` (the same launch, memory, choice and oracle): the same operators
  and sites (`#guard`) and replay results (both listings pinned); one certified kill (`vmul_m4`,
  the store deletion), so killed 1, unknown 29, refuted (uncertified) 16, passes 13
  (`#guard_msgs`);
* controls: the identity edit gives one mutant, admitted, whose AST is the original's; the four
  operators of `fourOps` (icmp swaps, constant branch, index plus or minus one, store deletion) give
  9 candidates on vector addition; a budget of 4 selects the first mutant of each of the first
  four operators;
* the certified kills: `vaddKills` and `vmulKills` come from `mojo_kills` with the 9 theorems
  (`vadd_m0` to `vadd_m7`, `vmul_m4`), and `#guard_msgs` checks that it fails on another mutant's
  theorem, on another instance, on another kernel's mutant, on a theorem of another statement, on
  a definition, on the right program with another function (`vadd_m0_m4`: mutant 0's program with
  mutant 4's function), on an index beyond the selection and on a mutant term of another shape;
  the axioms check reports each of `vadd_m0`'s axioms when it is left out of the allowed list (no
  test declares an axiom, so mojo_kills' own refusal of a foreign one is not run); and kills
  written by hand (the anonymous constructor, a structure instance with or without `with`, the
  constructor's name, a plain list given to `run`) are refused;
* the docstrings: `Kernels.vadd.prog`'s cites its corpus file and manifest digest; those of
  `vadd.m0.prog` and `vadd.m0.fn_0.b_0` cite the mutant (`vaddMutant 0`, `icmp slt->sle`, its
  site, index 0 of the selection, `Kernels.vadd.prog`) and the SHA-256 of the printed module,
  which the test recomputes, and neither a corpus file nor the manifest;
* malformed edits: block `%21`'s terminator as a branch to `%0` (a parameter, not a block) and to
  a local the name table lacks are both malformed; on a function whose `getelementptr` takes field
  0 of `{ i32 }`, the `gepIdx 1` mutant (field 1) and the `gepTy` mutant to `float` (an index into
  a float) are refused by admission, and the original is admitted;
* unsupported: on `tiled_matmul`, a `getelementptr` with `inbounds` toggled is admitted and
  unsupported (the block checker refuses its entry block).

## `mojo_import` (`MojoProof/LLVM/Quote.lean`)

`mojo_import "<path>" as <name>` imports the file `tests/corpus/<path>` and adds, in the current
namespace, `<name>.fn_<i>.b_<j> : Block` for block `j` of function `i`, `<name>.fn_<i> : Func`,
`<name>.module : Module` and `<name>.prog : Program`, each with a docstring naming the file; a block
or function an earlier import defined (the same term) is named, not defined again (`share`). It
fails when the file has no row in `tests/corpus/MANIFEST.tsv`, when the importer (`importBytes`:
`parse`, then `Module.check`) refuses it, naming the construct, when its SHA-256 is not the row's
("the file changed"), and when the term does not evaluate back to the importer's program
(`evalConst`, `Program.diff`) or does not print back to the file's tokens (`printDiff`). Untrusted:
the checks rest on Lean's compiled evaluation, the comparison code and the printer (docs/TRUST.md,
T4). The option `mojo_import.root` (default `tests/corpus`) names the directory of the files and of
their `MANIFEST.tsv`. When both checks pass, `<name>.prog` is recorded with its file
(`progFiles`, an environment extension that importing modules inherit), which is how
`scripts/L3Programs.lean` tells an imported program from another term of type `Program` (one
that keeps an imported program's digest, say). The definitions are added with the recursion limit
raised to eight times the module's longest list plus 512, so that the multistage GEMM files, with
functions of several thousand statements, import without a `set_option`. Tests
(`MojoProofTest/Import.lean`): the imported terms by `rfl` (kernel names, function counts, block
constants), `Program.diff` and `printDiff` on a changed field and a changed token, `digestError`,
and the refusals of a file with no row, a file outside the subset and the changed file
`tests/stale/k.ll`; `MojoProofTest/Corpus.lean` reads `progFiles`.

The importer's closure check (`Module.check`, `MojoProof/LLVM/Import.lean`) accepts two forms of
inline assembly, the `cp.async.cg.shared.global` copies of the multistage GEMM kernels, with and
without a source size (`AsmCall`, `MojoProof/LLVM/Asm.lean`: the template and constraints
exactly, `sideeffect`, a `void` result, no flags or argument attributes, and the operands
`i32, ptr addrspace(1), i32 16[, i32]`), and refuses every other inline assembly by its template
and constraints. The semantics gives the accepted calls no meaning: `exec` faults at them, so no
launch that reaches one is `Kernel.Sound`. Tests (`MojoProofTest/Asm.lean`): the strings each form
is recognized by and five near misses, each check of `AsmCall.checkCall` failing, and
`Module.check` on modules of one call (both forms accepted, a near miss refused with its check,
the two e4m3 conversions refused).

## `mojo_family` (`MojoProof/LLVM/Family.lean`)

`mojo_family F := P i with x₁ at "%r₁", …, xₙ at "%rₙ"` makes program `P` (a constant
`mojo_import` added) a function of the integer constants of statements `%r₁, …, %rₙ` of its
function `i`: each statement must be a two-operand integer instruction (`bin`) with exactly one
integer constant operand, which is non-negative. The command adds `F.b_<j> (x₁ … xₙ : Nat) :
Block` for each block with such a statement (the constant replaced by `Value.int (Int.ofNat xₖ)`),
`F.fn (x₁ … xₙ : Nat) : Func` (the other blocks are the imported block definitions), `F.prog
(x₁ … xₙ : Nat) : Program` (every other field `P`'s, the digest included) and `F.prog_corpus :
F.prog v₁ … vₙ = P ∧ F.fn v₁ … vₙ = P_i` at `P`'s constants `v₁ … vₙ`, by `rfl` (checked by the
kernel), so a theorem for every `x₁ … xₙ` gives `P`'s. It fails when `P` is not a constant, when
function `i` or a local does not exist, when no statement or more than one has the result, when
the statement is not of that form, when the constant is negative and when two parameters name one
statement. Untrusted: it evaluates `P` (`evalExpr`); the kernel checks `F.prog_corpus`. Tests
(`MojoProofTest/Family.lean`): `NaiveFam` over the naive matmul kernel's three row strides (`%26`,
`%37`, `%27`), `NaiveFam.prog_corpus`, the second specialization in
`tests/corpus/naive_k512/` as `NaiveFam.fn 512 512 256` with that file's kernel name (by `rfl`),
the three refusals, and the tile-512 `gevm_kernel` of `tests/corpus/gevm_t512/`, whose blocks'
statement counts differ from the tile-1024 file's, so that no family of constants relates them.

## `mojo_corpus` and `#mojo_corpus` (`MojoProof/LLVM/Corpus.lean`)

`mojo_corpus "<path>" as <name> "<directory>" ...` imports the rows of `tests/corpus/MANIFEST.tsv`
that its arguments name, in their order (a path names its row, a directory every row under it, no
argument every row), each by `mojo_import`'s steps: the file's SHA-256 is the row's digest, and
the importer (`parse`, then `Module.check`) accepts it, unless `tests/corpus/REFUSALS.tsv` lists
it, when the importer must refuse it with exactly the listed reason and nothing is added. An
accepted file goes through `mojo_import`'s core (`quoteProgram` in `MojoProof/LLVM/Quote.lean`:
the definitions, each with a docstring naming the file, the evaluation check and the printed-token
check), in the current namespace, under the name `as` gives (its argument, a path or a directory,
must name one row, not a refused one) or else under its path, each component up to its first `.`
(`corpusName`: `mgemm/k.nvptx.ll` is `mgemm.k`). It
fails on an argument that names no row, a row named twice, a refusal with no row, and at the
first row that fails a check (`corpusPlan`, `corpusRow`). Blocks and functions are shared by term,
so the order of the arguments fixes which import names a shared one. `#mojo_corpus`, with the
same arguments, runs the same checks, keeps nothing and logs the counts.
`MojoProof/Kernels.lean` is `mojo_corpus "vadd" as vadd "vmul" as vmul "tiled_matmul" as matmul`,
which adds the names `Kernels.vadd.*`, `Kernels.vmul.*` and `Kernels.matmul.*`. Untrusted as
`mojo_import` is: the terms it adds are checked by evaluation and by the kernel.

Tests (`MojoProofTest/Corpus.lean`): `#mojo_corpus` on every row (116 rows, 109 imported, 7 refused
as `REFUSALS.tsv` lists; about 11 minutes, most of it the 22 multistage GEMM files, which is why
the whole corpus is checked in the tests and not imported by `Kernels.lean`); the directory
`reduction` imported under its path's name, and its program recorded with its file (`progFiles`,
as an imported module's is, and none of `#mojo_corpus`'s); `corpusName`; the names
`Kernels.lean` gives (`Kernels.vadd.prog.module`, `Kernels.vmul.fn_0`, `Kernels.matmul.fn_0`);
`corpusPlan`'s two plans and five failures on two rows, and `as` on a directory whose one row is
refused; `corpusRow`'s two results and four failures (a changed file, another reason, a listed
file that imports, an unlisted one that is refused); the commands on a missing row and on the
changed file `tests/stale/k.ll`.

## The rule table: `@[mojo_rule]`, `mojo_refuse`, `mojo_rules_complete`, `#mojo_rules`

`MojoProof/Sym/RuleAttr.lean` keys the block checker's rule table by constructor:
`@[mojo_rule C₁ … Cₙ "case"]` on a lemma (or `attribute [mojo_rule …] l` from another module)
adds the rule `l` for the constructors `Cᵢ` and the case (a flag pattern, type class or intrinsic
parameter, as text; none for every case), and `mojo_refuse C₁ … Cₙ "case" : "reason"` adds a
refusal. The attribute is registered with `registerBuiltinAttribute` and its entries kept in a
`SimplePersistentEnvExtension` (`ruleExt`), so it tags declarations of imported modules, which a
`registerTagAttribute` attribute refuses; it is global only, and each key must be a constructor.
`mojo_rules_complete T₁ … Tₙ` fails, naming them, when a constructor of a `Tᵢ` has neither a rule
nor a refusal; `#mojo_rules T₁ … Tₙ` prints the table, a line per constructor. Completeness is
per constructor: that a constructor's cases cover it is a convention of the table, not a check.

`MojoProof/Sym/Rules.lean` tags the lemmas of `MojoProof/Sym/Exec.lean`, `exec_bin`, `exec_icmp`,
`exec_cast`, `exec_extract`, `exec_gep`, `exec_load`, `exec_store`, `exec_fbin` and `exec_sreg`
(also keyed by `Intrinsic.sreg`), and of `MojoProof/Sym/Rel.lean`, `SState.exit_sound`
(`ret void`, and `br` and `br i1` into blocks that start without a `phi`) and
`SState.exitAt_sound` (`br` and `br i1` into blocks that start with `phi`s); it refuses the other
cases of `Inst`, `Term` and `Intrinsic` (19, 5 and 17 constructors, the 41 lines of
`#mojo_rules`), each with the case of `SState.stmt`, `SState.exit` or `SState.exitAt` that gives
`none` as the reason, and ends with
`mojo_rules_complete Inst Term Intrinsic`, so a constructor added without an entry fails the build.

Tests (`MojoProofTest/Rule.lean`): a test table over `TOp` with an extra opcode, for which
`mojo_rules_complete TOp` fails naming `TOp.extra` and passes after its refusal, and its
`#mojo_rules`; the library's table checked complete again and printed (41 lines, pinned); a key
that is not a constructor, in the attribute and in `mojo_refuse`, and a `local` attribute, each
an error.

## `kernel_rfl` and `kernel_rfl_late` (`MojoProofTest/KernelRfl.lean`)

Two test tactics for equations `a = b` that the kernel shows by unfolding, where the elaborator's
`rfl` or `decide` does not apply or is slow: types with no decidable equality (`Val`, `Value`,
threads, memories) and long evaluations. `kernel_rfl` checks `a` and `b` equal by the kernel's
definitional equality when it runs (`Obl.krfl`, MojoProof/Sym/Obl.lean) and fails there if they
are not, with a fresh kernel cache for each call. `kernel_rfl_late` (syntax
`MojoProofTest.kernelRflLate`) assigns `Eq.refl a` at the type `a = b` (`Obl.hint`) without
checking it: the kernel checks it when it checks the whole declaration, in one pass with that
declaration's other proofs, so the equations of one declaration share the kernel's caches. A goal
the kernel does not show then fails the declaration, at the declaration and not at the tactic.
`of_decide_eq_true (by kernel_rfl_late)` puts a Boolean decision into the same pass. Use: the
memories of a warp's lanes, each from the lanes before it (MojoProofTest/GemvWarp.lean), where
`kernel_rfl` or `decide +kernel` would evaluate the earlier lanes again for each equation.

Tests (`MojoProofTest/KernelRfl.lean`, `#guard_msgs`): `kernel_rfl` refuses `1 = 2` when it runs;
`kernel_rfl_late` closes `2 + 2 = 4`, refuses a goal that is not an equation when it runs, and
leaves `1 = 2` to the declaration's check, which the kernel refuses ("application type
mismatch").
