# The pointer facts of a block summary (`Block.sound_ptrs`)

Lean: `MojoProof/Sym/Block.lean` and `MojoProof/Sym/Path.lean` (the pointer facts) and
`MojoProof/Sym/PtrMem.lean` (the memory premises of a path from them). Tests: `MojoProofTest/SymRun.lean` (`vadd21_ptrs`,
`vadd21_memNext_twin`, `store_pathMem`).

**Scope.** Every program `P`, function `fn`, block `lbl`, entry position `p0`, condition list
`ds` and summary `S` that `covers` (or `coversWith` with an exit function meeting `hex`, or
`coversTo` with its edge premise) accepts, every context of `P` and every thread whose innermost
frame runs `fn` at block `lbl`'s position `p0`, with any memory and caller frames, whenever the
conditions of `ds` hold at the entry valuation. Along a path: every path that
`coversPathWith contract` accepts, for either value of the flag, with its premises
(`WalkWith contract`). The memory premises: every labelling, payload set and path that
`coversPathWith false` and `pathOk` accept.

**What this connects.** `Labels.MemOk` (MojoProof/Sem/Labels.lean, through `Labels.MemNext` and
`Labels.MemAt`) constrains, at each statement a running thread reaches, the value of the
statement's pointer operand in the thread's scope, `evalV (c.scope m f t.k) (.ptr a) p`.
`Valuation.LoadsOk` and `Valuation.StoresOk` (MojoProof/Sym/Payload.lean) constrain the summary
term's pointer value `p.eval V (vals V ns)`. `SState.run_sound` proves that the two agree
(through `SState.op_eval`) inside its induction. The pointer facts state it, and the theorems of
MojoProof/Sym/PtrMem.lean turn `Labels.MemOk` into the memory premises `Valuation.PathMem` of
every path the checkers accept.

## Statement

Definitions (`PtrIs`, `StoreVal`, `StoreAt` and `StmtPtrs` in MojoProof/Sym/Rel.lean, the others in
MojoProof/Sym/Block.lean; `Valuation.blocksWith` in MojoProof/Sym/Path.lean).

- `PtrIs ld st s pv`: `st` is a `load` (`ld = true`) or a `store` (`ld = false`) whose
  pointer operand `(.ptr a) q` has `evalV s (.ptr a) q = pv`.
- `StoreVal ns regs x w`: the term `x` describes the stored operand `w` with the node table
  `ns` and the register entries `regs`. For a register `w = .loc r`, `x = .reg r` (its value at
  the block's entry) or `(r, x) ∈ regs`; for a float constant `.float lit`, `x` is a node `.node j`
  with `ns[j]? = some (.flit ft lit)`; for any other operand, `x` is an integer constant
  `.int n i`.
- `StoreAt fn lbl pc ns regs x`: statement `pc` of block `lbl` of `fn` is a `store` whose
  stored operand `w` has `StoreVal ns regs x w`.
- `StmtPtrs V vs lbl pc σ σ' st s`: the pointer facts of one statement, which takes `σ`
  to `σ'`. A `load` node at index `j ≥ σ.nodes.length` of `σ'` is at `lbl` and `pc`, with
  `PtrIs true st s (p.eval V (vals V (σ'.nodes.take j)))`, its pointer term on the nodes before
  it (the node `σ.nodes.length`, or the next one after the node of a global the `load` reads
  directly, `SNode.globalAt`). A `store` effect
  `SEff.store l pc' v p` in `σ'.effs.drop σ.effs.length` is at `lbl` and `pc`, with
  `PtrIs false st s (p.eval V vs)`, and `st` is `.store vol (.mk t w) ptr al` with
  `σ.op t w = some v`.
- `PtrAt c t m rest fn lbl pc ld pv`: there are `f`, `k`, `m'`, `b` and `st` with
  - `Steps c t m ⟨f :: rest, k⟩ m'`;
  - `f.fn = fn`, `f.label = lbl` and `f.pc = pc`;
  - `fn.blocks.find? (·.label == lbl) = some b` and `b.stmts[pc]? = some st`;
  - `PtrIs ld st (c.scope m' f k) pv`.

  This is the statement and scope at which `Labels.MemNext` applies `Labels.MemAt` to the
  thread `⟨f :: rest, k⟩` on memory `m'`.
- `Ptrs c t m rest (V, lbl, S)` holds when both of these do:
  - for each `S.nodes[j]? = some (.load l pc p)`,
    `PtrAt c t m rest V.fn l pc true (p.eval V (vals V (S.nodes.take j)))`;
  - for each `SEff.store l pc v p ∈ S.effs`,
    `PtrAt c t m rest V.fn l pc false (p.eval V (vals V S.nodes))` and
    `StoreAt V.fn l pc S.nodes S.regs v`.

  These are the terms and values that `LoadsOk` and `StoresOk` read.
- `Valuation.blocksWith contract V l S ps`: the blocks of the path, each with its entry valuation
  (`Valuation.intoWith contract` of the blocks before it).

Theorems (MojoProof/Sym/Block.lean; 6 in MojoProof/Sym/Path.lean).

1. `SState.stmt_sound` also concludes
   `StmtPtrs V vs lbl fi.pc σ σ' st (V.ctx.scope mi fi k)`. That scope is the one `exec` runs the
   statement in.
2. `SState.run_ptrs` concludes `SState.run_sound`'s conclusion together with two pointer
   facts:
   - `PtrAt V.ctx ⟨fi :: rest, kk⟩ mi rest V.fn l pc true (p.eval V (vals V (σf.nodes.take j)))`
     for each `load` node `j ≥ σ.nodes.length` of `σf`;
   - `PtrAt … false (p.eval V vs)` and `StoreAt V.fn l pc σf.nodes σf.regs v` for each `store`
     effect `SEff.store l pc v p` that the run appends.

   `SState.run_sound` is its first component.
3. `SState.stmt_mono` and `SState.run_mono`: a statement in the fragment, and a run
   of statements, keep the obligations, extend the effects and the table, and put entries in
   front of the register entries (`σf.regs = rs ++ σ.regs` for some `rs`).
4. `Block.sound_withAt` without `alloca` and `fmul contract` (`EndsAt.ends`; with
   `fmul contract`, `EndsWith true` in place of `Ends`; docs/proofs/contract.md) and
   `Block.sound_to` conclude
   `Ends c t m f rest (Valuation.entry c t.k m f, lbl, S) ∧
   Ptrs c t m rest (Valuation.entry c t.k m f, lbl, S)`.
5. `Block.sound_ptrs` has `Block.sound`'s premises and the conclusion `Ends … ∧ Ptrs …`.
   `Block.sound` is its first component.
6. `Block.sound_pathWith_ptrs`, for a path that `coversPathWith contract` accepts with its
   premises `WalkWith contract`, concludes
   `EndsWith contract c t m f rest ((Valuation.entry c t.k m f).lastWith contract l S ps) ∧
   ∀ q ∈ (Valuation.entry c t.k m f).blocksWith contract l S ps, Ptrs c t m rest q`.

Theorems (MojoProof/Sym/PtrMem.lean). In all of them, `lab` is a labelling, `pay` a set of
payload blocks, `c` a context, `t` a thread, `m` a memory and `rest` a list of frames, and
`hM : ∀ t' m', Steps c t m t' m' → lab.MemNext pay c m' t'` says that every state the thread's
steps reach meets `Labels.MemNext`.

8. `StoreVal.mentions`. For every labelling, function, node table `ns`, register entries
   `regs`, term `x` and operand `w` with `StoreVal ns regs x w`, with `ps` the roles of `ns`
   (`roles lab fn ns`): if `x.pay lab fn ps = true` and every entry `(r, y) ∈ regs` with
   `y.pay lab fn ps = true` has `lab.reg fn.name r = true`, then
   `w.mentions (lab.reg fn.name) = true` (a float constant's node is never payload).
9. `Ptrs.loadsOk`. For every valuation `V`, label `lbl` and summary `S`:

   ```lean
   theorem Ptrs.loadsOk (hQ : Ptrs c t m rest (V, lbl, S))
       (hM : ∀ t' m', Steps c t m t' m' → lab.MemNext pay c m' t') :
       V.LoadsOk lab pay S.nodes
   ```
10. `Ptrs.storesOk`. For every valuation `V`, label `lbl` and summary `S` whose register
    entries agree with `lab` (`Summary.agrees`):

    ```lean
    theorem Ptrs.storesOk (hQ : Ptrs c t m rest (V, lbl, S))
        (ha : S.agrees lab V.fn = true)
        (hM : ∀ t' m', Steps c t m t' m' → lab.MemNext pay c m' t') : V.StoresOk lab pay S
    ```
11. `Valuation.pathMem_of_ptrs`. For every path `(l, S) :: ps` and valuation `V`: if
    `pathOk lab V.fn l S ps = true` and `Ptrs c t m rest q` for every
    `q ∈ V.blocksWith false l S ps`, then `V.PathMem lab pay l S ps` (`Valuation.LoadsOk` and
    `Valuation.StoresOk` at each block's entry valuation).
12. `Block.sound_pathMem`. For every program `P`, function `fn`, path
    `(l, ds, S) :: ps` with `coversPathWith false P fn p0 ((l, ds, S) :: ps) = true` and
    `pathOk lab fn l S ps = true`, every context `c` with `c.prog = P`, and every thread `t`
    whose innermost frame `f` (above `rest`) runs `fn` at block `l`'s position `p0`, on memory
    `m`, with `WalkWith false (Valuation.entry c t.k m f) ((l, ds, S) :: ps)`: `hM` gives
    `(Valuation.entry c t.k m f).PathMem lab pay l S ps`. That is the premise `hm` of
    `Block.sound_ret_rel`.
13. `Labels.MemOk.steps`. For every launch `L`, contexts `c`, grids `g₀` and `g` with
    `lab.MemOk pay L c g₀` and `g` reachable from `g₀` (`Relation.ReflTransGen (Grid.Step L c)`),
    every running thread `g.threads[n]? = some (.run t)` and every `Steps (c n) t g.mem t' m'`:
    `lab.MemNext pay (c n) m' t'`. So `hM` holds for every running thread of every grid a launch
    reaches, and `Block.sound_pathMem` applies to it.

## Proof

1. In the `load` case, the new node is `.load lbl pc x` with `x ← σ.op (.ptr as) p`. Its index is
   `σ.nodes.length` (`getElem?_snoc_ge`). `SState.op_eval` gives
   `x.eval V (vals V σ.nodes) = evalV s (.ptr as) p`, which is the value the proof already used.
   In the `store` case, the only new effect is `.store lbl pc x y`, with `x ← σ.op t w` for the
   stored operand. Its pointer term `y` has the same `SState.op_eval` fact on `vs`, and a store
   appends no node. The other statements append a node that is not a `load` and no effect
   (`SState.def_ptrs`, by its `autoParam`).
2. The proof is by induction on the statement list, as for `SState.run_sound`.
   - A `load` node of `σf` past `σ'`'s table comes from the induction hypothesis, moved back one
     step by `PtrAt.pre`. One in `σ'` comes from item 1 at the thread itself (`Steps.refl`). For
     it, `σf.nodes.take j` is `σ.nodes`, because `σf`'s table extends `σ'`'s, which is
     `σ.nodes ++ [nd]`.
   - A `store` effect is either in the statement's own effects (item 1) or in the rest of the run
     (the induction hypothesis and `PtrAt.pre`). For its own, `σ.op t w = some v` gives
     `StoreVal (σ.nodes ++ ns) (rs ++ σ.regs) v w` for every `ns` and `rs`
     (`SState.op_storeVal`), and `σf`'s table is `σ.nodes` with nodes after it and its register
     entries are `σ.regs` with entries in front (item 3).
3. Case analysis of `SState.stmt` (`SState.def_regs` for the statements that set a register),
   then induction on the statement list.
4. and 5. Apply `SState.run_ptrs` from `SState.init`, whose table and effects are empty.
6. The head block's pointer facts come from `Block.sound_atWith` or `Block.sound_toWith`. Each
   later block's facts come from the recursive call at the thread after the edge, moved back by
   `Ptrs.pre` along `Steps.trans_step hS₁ hst₁ (.refl _ _)`.
8. A register operand is `x` itself, whose payload role is the hypothesis, or an entry of
   `regs` set to `x`, which the entries hypothesis covers; a constant term has no payload role.
9. `PtrAt` gives the thread's state `⟨f :: rest, k⟩`, memory `m'`, block `b` and statement `st`,
   which meet `hM`'s premises. `resReg V.fn l pc` is `st.res` (from `hb` and `hst`), so `MemAt`'s
   `load` clause applies to the pointer value that `PtrIs` equates with the term's.
10. As 9, with `MemAt`'s `store` clause. Its premise, that the stored operand mentions a payload
    register, is `StoreVal.mentions` with `StoreAt`'s `StoreVal`, the effect's payload term, and
    `Summary.agrees`, which says that each register entry of `S` with a payload term is of a
    payload register.
11. Induction on the path. `pathOk` gives `Summary.agreesI`, whose first part is
    `Summary.agrees`, at each block; items 9 and 10 apply at each block of
    `Valuation.blocksWith false`.
    The next block's entry valuation keeps the function (`Valuation.into_k`).
12. `Block.sound_pathWith_ptrs` gives the pointer facts of every block of the path; then
    item 11.
13. `Steps.grid` (MojoProof/Sym/Sched.lean) turns the thread's steps into grid steps from `g`, to
    the grid with the reached state at index `n`. That grid is reachable from `g₀`, so
    `Labels.MemOk` gives `Labels.MemAll` there, at index `n`.

## Dependencies

`SState.op_eval`, `SState.op_storeVal`, `SState.def_regs`, `SState.run_mono`, `SState.stmt_mono`,
`step_stmt`, `Steps.trans` and `Steps.trans_step`, `Ends.edgeWith`; `Labels.MemNext`,
`Labels.MemAt` and `Labels.MemOk` (MojoProof/Sem/Labels.lean); `Valuation.LoadsOk`,
`Valuation.StoresOk`, `Valuation.PathMem`, `Summary.agrees`, `pathOk` and `resReg`
(MojoProof/Sym/Payload.lean); `Steps.grid` (MojoProof/Sym/Sched.lean).

## Instances

In MojoProofTest/SymRun.lean.

With `vector_addition`'s block `%21` (`Kernels.vadd.b1`), the context `ctx0`, the memory `mem0`
and the frames `frame0 i 3`:

- `vadd21_q` is `Block.sound_ptrs` itself.
- `vadd21_ptrs` holds for every `i < 4`. The thread's steps reach each `load` node's statement,
  whose pointer operand evaluates to cell `i` of block 1 or 2 (the inputs). They also reach the
  `store`'s statement, whose pointer is cell `i` of block 3 (the output). The term values come
  from `vadd21_ptrval` (`decide +kernel`, through `cellIs`).
- The negative twin is `vadd21_memNext_twin`. Under `labNone` (no payload register) with block 1
  payload, `Ptrs.loadsOk` and `vadd21_load1` show that for every `i < 4` some state of thread
  `i`'s run fails `Labels.MemNext`.

With the block of `kernel #[store01]` (MojoProofTest/Labels.lean), which stores register 0
through the pointer in register 1 and returns (summary `st01`):

- `store_pathMem` holds for every launch `L`. Under `lab0` (register 0 payload) with block 1
  payload, `storeGrid` meets `Labels.MemOk` (`store_ok`), so `Labels.MemOk.steps` and
  `Block.sound_pathMem` give `Valuation.PathMem` of the one-block path at its thread's entry
  valuation: its `store` of the payload term `.reg 0` writes into block 1. The twin: with no
  payload block, `Valuation.PathMem` fails.

These instances cover two blocks of two programs. The theorems in items 1 to 13 cover every
program, labelling and block or path the checkers accept.

## Limits

- `atomicrmw` is outside the fragment, so it has no pointer facts. `Labels.MemAt` constrains it,
  and `Valuation.StoresOk` does not read it.
- `Block.sound_pathMem` needs `pathOk` of the path's summaries; a path whose register entries do
  not agree with the labelling gets no `StoresOk`.
