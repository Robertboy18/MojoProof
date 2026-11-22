# PROOF: the kernel theorem from a covered path or loop run per thread (`Kernel.sound_of_chains`)

Lean: MojoProof/Sym/Kernel.lean, with the scope of each statement given below and in the section
"Scope". Instances and twins: MojoProofTest/Kernel.lean, and for a kernel whose thread runs a
loop MojoProofTest/KernelLoop.lean. The command that generates a kernel's theorem from these is
described in docs/kernel.md.

The kernel theorem composes four facts proved once: the block checker's path theorem with
`phi`s (`Block.sound_retI`, MojoProof/Sym/Block.lean), the loop theorem for a thread through a
sequence of loops (`Runs.of_chains`, MojoProof/Sym/Loop.lean), the sequential schedule by an
invariant (`Seq.start_sound_inv`, MojoProof/Sym/Sched.lean, which goes through
`Grid.start_sound`), and the shape of the threads the start makes (`Grid.start_run`,
MojoProof/Sem/Closed.lean). What is left to a kernel is per thread: which path or sequence of
loops it takes, that their premises hold (for a loop, from an invariant and a trip count), and
what its effects leave.

## Statements

1. `Runs.of_ret`. Let `t` be a thread with one frame `f` of kernel `fn`, at block `l` and
   instruction `p0`, with no `alloca` blocks, and let `(l, ds, S) :: ps` be a path that the
   checker with `phi`s accepts from `p0` (`coversPathI P fn p0 … = true`: each next block is
   covered from after its `phi`s when the edge enters it there) in a context whose program is `P`.
   If the path's premises with `phi`s hold on the entry valuation (`WalkI`: an edge into a block
   with `phi`s sets them, `Valuation.into`), its last block's exit is `ret`, and the last block's
   effects succeed at its entry valuation (`Valuation.lastI`) with a memory `me` of `Q` (together:
   `Ret V Q path`), then `t` runs to its end from `m` leaving `me` (`Runs c t m me`), and `Q me`.
   `Walk.walkI`: if a path's premises without `phi`s hold (`Walk`), its premises with `phi`s hold
   and its last block's entry valuation is the same (`V.lastI l S ps = V.last l S ps`).
   `Ret.of_walk`: a path with `Walk` whose last block (at its entry valuation `Valuation.last`)
   returns and whose effects succeed there with a memory `me` of `Q` is a `Ret` to `Q`.
   `Ret.mono`: a `Ret` to `Q` is a `Ret` to every `Q'` that holds of every memory of `Q`.
2. `Grid.start_thread`. If `Grid.start` gives grid `g`, every thread `k < g.threads.size` of `g`
   (`Grid.thread g k`) is `⟨[f], 0⟩`, where `f` is a frame of `fn` at the label of `fn`'s first
   block, at instruction 0, with no `alloca` blocks.
3. `Kernel.sound_of_chains`. Let `paths` be a list of paths, each starting at `fn`'s first block
   and accepted from instruction 0 by the checker with `phi`s (`coversEntry`, a closed Boolean),
   and `chains` a list of sequences of loops (`LoopChain`, MojoProof/Sym/Loop.lean), each starting
   at `fn`'s first block, whose paths the checker with `phi`s accepts: the path into the first
   loop from instruction 0, each loop's round with its nested loops, and each path out
   (`coversChains`, a closed Boolean). Suppose the caller's pointer bytes name known numbers
   (`m.BytesIn m.Known`), the start succeeds on every admitted address choice and oracle, the
   observation reads only blocks, and for every admitted choice and oracle, with `g`, `c` the
   start's grid and contexts, there is an invariant `P` with: `P 0 g.mem`; for every thread `k`
   with frame `f` and every memory `m'` of `P k`, with `V = Valuation.entry (c k) 0 m' f`, either
   some path of `paths` is a `Ret` from `V` to `P (k + 1)`, or some sequence `C` of `chains` runs
   from `V` through its loops to `ret` with a memory of `P (k + 1)`
   (`RetLs (P (k + 1)) C.loops V C.l C.ds C.S C.E`: for each loop an invariant indexed by the
   round and a trip count, `Chain.loop`); and every memory of `P N` (`N` the number of threads)
   has a trace with no data race that keeps the promise of `!invariant.load`, and an observation
   `y` with `R y`. Then `Kernel.Sound prog fn L args m adm obs R`. `Kernel.sound_of_paths` is the
   case `chains = []`, whose second disjunct is false: the same conclusion from `coversEntry` and
   a `Ret` along some path of `paths` for every thread.
4. The elementwise invariant `Elem m₀ out w cell bs k m`: block `out` of `m` is block `out` of
   `m₀` after threads `i < k` in turn wrote `bs i` at `cell i` (nothing when `bs i = none`), every
   other block is `m₀`'s, and every access of `m`'s trace is owned (`Elem.Own`: one to `out` lies
   in its thread's cell of `w` bytes, one elsewhere reads, no `!invariant.load` reads `out`).
   `Elem.zero`: a memory with an empty trace is of `Elem … 0` from itself. `Elem.succ`: a memory
   whose block `out` adds thread `k`'s write, whose other blocks are unchanged and whose new
   accesses are owned, is of `Elem … (k + 1)`. `Elem.safe`: if the cells are `w` apart, the trace
   of every memory of `Elem` has no data race and keeps the promise of `!invariant.load`.
5. `Kernel.sound_eval`. `Ret.check V ps` is a Boolean (`WalkI` decided, the `ret` exit decided, the
   last block's effects `.ok`), `Ret.out V d ps` the memory those effects leave (`d` if none),
   and `Ret.of_check`: `Ret.check V ps = true → Ret V (· = Ret.out V d ps) ps`. `Ret.pick V paths`
   is the first path that `Ret.check` accepts. `Kernel.mems g c paths k` is the memory threads
   `0` to `k - 1` leave in turn, each along its picked path from the memory before it, and
   `Kernel.check g c paths` says that every thread's picked path is accepted. If `coversEntry`
   holds, the caller's pointer bytes are known, the start at choice `ch` and oracle `ω` is
   `.ok (g, c)`, the observation reads only blocks, `Kernel.check g c paths = true`, and the memory
   `Kernel.mems g c paths N` has a trace with no data race that keeps the promise of
   `!invariant.load` and an observation `y` with `R y`, then
   `Kernel.Sound prog fn L args m (fun ch' ω' => ch' = ch ∧ ω' = ω) obs R`.
6. `Kernel.sound_elem`. Fix an oracle `ω`, an output block `out`, cells `cell` that are `w` apart
   (`Apart cell w`) and bytes `bs`. If `coversEntry` holds, the caller's pointer bytes are known,
   the start succeeds at every address choice and `ω`, and on every start `(g, c)` every thread
   `k`, from every memory of `Elem g.mem out w cell bs k` and with its one frame `f`, takes some
   path of `paths` that is a `Ret` to `Elem g.mem out w cell bs (k + 1)`, then
   `Kernel.Sound prog fn L args m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
   (Elem.Out m out cell bs N)` with `N = volume L.grid * volume L.block`: block `out` of the
   final memory is block `out` of `m` with the bytes of threads `0` to `N - 1` put in turn, and
   every other block of `m` is unchanged. `Kernel.sound_mapN`: let `fn`'s parameters be
   `ps ++ [pc]`, the one at each position `j` named `%j`, every one of `ps` `byval` of a struct
   type `T` with a codec for `.agg [.ptr p, z]` (alignment `al'` dividing `T`'s and the generic
   space's) and `pc` not `byval` with `withAttrs` taking the count argument `v` to `u` on every
   memory (any type and width); let `bl` be block numbers, one for each of `ps`, `m`'s pointer
   bytes be known, `m` have block `o` owned by all threads, the start on
   `bl.map (fun a => .agg [.ptr ⟨a, 0⟩, z]) ++ [v]` succeed at every choice and `ω`, and `cell`
   be `w` apart. If for every thread `k < N`, context with `prog`, `L.env k`, identity
   `⟨k, k / volume L.block⟩` and oracle `ω k`, memory `m₀` with `m`'s block `o`, memory `m'` with
   `Elem m₀ o w cell bs k m'` on which every block of `m` but `o` is unchanged, and frame `f` of
   `fn` whose `%i`, for each position `i` of `bl`, points to offset 0 of a block other than `o`
   from which `T` loads at alignment `al'` as the struct of `bl[i]`, and whose `%n` (`n` the
   length of `bl`) is `u`, some path of `paths` is a `Ret` to `Elem m₀ o w cell bs (k + 1)`, then
   the conclusion of `Kernel.sound_elem` holds on those arguments with `out = o`.
   `Kernel.sound_map2`, its case `bl = [a, b, o]` with an `i32` count: let `fn`'s parameters be
   `[p0, p1, p2, p3]` named `%0` to `%3`, `p0` to `p2` `byval` of a struct type `T` with a codec
   for `.agg [.ptr p, z]` (alignment `al'` dividing `T`'s and the generic space's), `p3` not `byval`
   with `withAttrs` passing `.bits 32 n` as it is; let `m` meet `Map2.Pre l t enc al z m a b o n x
   y` (`l = prog.layout`), the start on `Map2.args z a b o n` succeed at every choice and `ω`, and
   `cell` be `w` apart. If for every thread `k < N`, context with `prog`, `L.env k`, identity
   `⟨k, k / volume L.block⟩` and oracle `ω k`, memories `m₀`, `m'` with `Elem m₀ o w cell bs k m'`,
   and frame `f` of `fn` whose `%0` to `%2` point to offset 0 of blocks `q0` to `q2` other than `o`
   from which `T` loads at alignment `al'` as the structs of `a`, `b`, `o`, whose `%3` is `n`, and
   on whose memory `m'` the buffer, tensor and `Mem.Fits` facts of `Map2.Pre` hold, some path of
   `paths` is a `Ret` to `Elem m₀ o w cell bs (k + 1)`, then the conclusion of `Kernel.sound_elem`
   holds with `args = Map2.args z a b o n` and `out = o`.
7. `vadd.ret` and `vadd.correct` (MojoProof/Kernels/Vadd.lean), about the one kernel
   `vector_addition`. Assume a valid launch whose grid and block have side 1 in `y` and `z`,
   `4 ∣ al`, distinct `a`, `b`, `out`, `n ≤ N` and `n < 2 ^ 31`. `vadd.ret`: for a thread `k` of the
   launch whose context has `vadd.prog`, `L.env k`, identity `⟨k, k / volume L.block⟩` and oracle
   `ω k`, a frame of `fn_0` whose `%0` to `%2` point to offset 0 of blocks `p0` to `p2` other than
   `out` that hold the structs of `a`, `b`, `out`, and whose `%3` is `n`, and a memory of
   `Elem m₀ out 4 (4 * ·) (vadd.bytes ω x y n) k` on which `a`, `b`, `out` are buffers of at least
   `n` floats that fit and `a`, `b` hold `x`, `y`: some path of `vadd.paths` is a `Ret` to the same
   invariant at `k + 1`. `vadd.correct`: for a caller's memory of `Map2.Pre`
   (MojoProof/Sem/Precond.lean, tail `vadd.argTail`: closed for the arguments, the buffer and tensor
   facts above, `n ≤ N`, `n < 2 ^ 31`, the three buffers fit), `vector_addition` is sound as in 6
   with `bs = vadd.bytes ω x y n` and cells `4 i`.
8. The start facts (MojoProof/Sym/Start.lean and MojoProof/Sym/Kernel.lean), for every
   program, kernel, launch, arguments, memory, address choice `ch` and oracle with
   `Grid.start … = .ok (g, c)`, thread `k < g.threads.size` with frame `[f]`, and position `i` with
   parameter `p` and argument `v`, where `p`'s name `r` names no parameter before `i`:
   `launchArgs_byval`: every value `w` at position `i` of what `launchArgs` returns is
   `LaunchArg … i p v w` in the memory it returns (for a `byval(T)` parameter, `w` points to
   offset 0 of a block `byvalBlock` holding `T`'s encoding of `v`, owned by the thread; otherwise
   `withAttrs` gives `w` on some memory). `Thread.start_regs`: register `r` of the start's frame
   holds the argument at `i`. `Grid.start_arg`: their composition in `g.mem`. `Grid.start_buffer`:
   if `p` is `byval(T)`, `v = enc x` for a codec `enc` of `T` and `al` divides `T`'s alignment and
   `2 ^ w`, then `f.regs r` points to offset 0 of a block `q` of `g.mem` owned by thread `k` from
   which `T` loads as `enc x` at alignment `al`. `Grid.start_scalar`: if `p` is not `byval` and
   `withAttrs` gives `w` on every memory, `f.regs r = some w`.
9. The corollaries of a binary float map (MojoProof/Sym/Kernel.lean, section
   `Map2`), for every program, kernel, launch, arguments, memory `m` with a block `out`, layout
   `l`, float type `ft`, operation `op`, oracle numbers `o`, tensors `x`, `y` of length `N`, count
   `n`, and cells `l.stored (.fp ft)` bytes apart. `Elem.map2 l ft op o x y n k` is the encoding of
   `deliver (op x_k y_k) (o k)` if `k < n` and `k < N`, else `none` (`Kernels.vadd.bytes ω` and
   `Kernels.vmul.bytes ω` are it at `Model.add`, `Model.mul` and `o k = ω k (Nat.pair 23 0) / 3`).
   `Elem.word l ft out cell B k` is the float that cell `cell k` of block `out` of `B` decodes to.
   `Kernel.Obs … obs ch ω y`: the start at `ch` and `ω` succeeds and some schedule reaches from its
   grid a grid where every thread has returned, whose memory `obs` maps to `y`. Write `S o T` for
   `Kernel.Sound` for the observation of the blocks and `Elem.Out m out cell (Elem.map2 l ft op o x
   y n) T`. `Kernel.Sound.map` (MojoProof/Sem/Replay.lean) at `f := some`: `Kernel.Sound` for
   `R` gives it for every weaker `R'`.
   `Kernel.Sound.obs`: `R` holds of every `Kernel.Obs` at an admitted choice and oracle.
   `Elem.Out.map2_word`: blocks of `Elem.Out` after `M` threads for `Elem.map2`'s bytes hold at the
   cell of every thread `k` below `n`, `N` and `M` the float `deliver (op x_k y_k) (o k)`.
   - `Kernel.map2_min`: `S o T` at an admission gives `Kernel.Sound` at it for `Elem.Out` after
     `min n T` threads, so after the `n` threads below the count when `n ≤ T` (`Elem.Out.min`:
     when threads from `n` on put nothing, `Elem.Out` after `T` threads is `Elem.Out` after
     `min n T`).
   - `Kernel.map2_real`: from `S o T` at an admission, at every admitted choice and oracle every
     observation `B` of a complete run has a float `v` at the cell of every thread `k` below `n`,
     `N` and `T`, and if `v` is finite then `v = op x_k y_k`.
   - `Kernel.map2_finEq`: if `S (o ω) T` holds for every oracle `ω` at the admission
     `fun _ ω' => ω' = ω`, then at any two choices and oracles the observations `B`, `B'` of
     complete runs have floats `v`, `v'` at the cell of every such `k`, with `FinEq v v'`.
   - `Kernel.map2_finEq` with `FinEq.eq_of_isFinite` (a word `FinEq` to a finite word is equal to
     it): under `Kernel.map2_finEq`'s premise, a finite float at the cell of such a `k` in one
     observation is the float there in every observation, at every choice and oracle.

   The instances (MojoProofTest/Kernel.lean) take `S` from `Kernels.vadd.correct` and
   `Kernels.vmul.correct`, for every valid launch of `T` threads whose grid and block have side 1 in
   `y` and `z`, `4 ∣ al`, memory of `Map2.Pre`, choice and oracle: `vadd_min`, `vadd_real`,
   `vadd_finEq`, `vadd_stable` and the four `vmul_*`. `vadd_real` also states that `op x_k y_k` is
   TorchLean's `(x + y)` at `k` and that its real value is the real sum rounded to binary32
   (`Model.roundAt`); `vmul_real` states that it is TorchLean's `(x * y)` at `k` and that its real
   value is the real product rounded to binary32.
10. Checking `Elem.Out` by evaluation, and refuting the canaries (MojoProof/Sym/Kernel.lean).
   `Elem.outBelow m out cell bs N nb K B` is a Boolean: every block `b < nb` that `m` has is a block
   of `B` that agrees (`Elem.agree`: every field, and the bytes at the offsets below `K`) with
   `Elem.put cell bs N` of `m`'s block at `out` and with `m`'s block elsewhere.
   `Elem.Out.outBelow`: `Elem.Out m out cell bs N B` implies it, for every `nb` and `K`.
   `Elem.canaries l t enc x bs n` is the list of the five byte functions that Sem/Replay.lean's
   probes make from `bs`: `Probe.drop 0 bs` (cell 0 omitted), `Probe.stale` (no thread stores),
   `Probe.swap 0 1 bs` (cells 0 and 1 swapped), `Probe.zero (l.stored t) n` (cells below `n` zero)
   and `Probe.copy l t enc x n` (cells below `n` hold the input `x`'s cells under `enc`).
   `Kernel.replay_canaries`: for every program, kernel, launch, arguments, memory `m` with a block
   `out`, choice `ch`, oracle `ω`, fuel, phases, cells, `T` and canaries: if for each canary `bs'`
   the replay (`Kernel.replay`) with the observation of block `out`'s bytes (`Replay.bytes?`) and
   the predicate "equal to the bytes of `Elem.put cell bs' T` of `m`'s block `out`" is `bad`, then
   for each canary `bs'` and every admission that admits `ch` and `ω`, the kernel is not
   `Kernel.Sound` for the observation of the blocks and `Elem.Out m out cell bs' T`.

## Proofs

1. If the path is empty, `Ret` is false. Otherwise `Block.sound_retI` applies (its premises are
   `coversPathI`, the one frame, `f.fn = fn`, the label and instruction, `WalkI` and the `ret`
   exit): the thread's steps reach the last block's end on the memory `me'` that the last
   block's effects make, and the next step is `.done` of `f.allocas.foldl (setLive · false) me'`.
   The effects' result is `.ok me'` and `.ok me`, so `me' = me`, and the fold over the empty list
   of `alloca` blocks is `me`. Steps followed by that step is `Runs` by definition.
   `Walk.walkI`, by induction on the path: on one block `Walk` and `WalkI` are the same
   proposition and `lastI` is `last`. Otherwise `Walk` gives the first block's obligations, its
   exit's target `d` (the next label) and `Walk` of the rest from `V.after S`; a target means the
   edge is a branch or `ret`, never `Exit.phi`, so `Exit.of_target` gives the same destination,
   entry position 0, and `V.into l S = V.after S`; the induction hypothesis gives `WalkI` of the
   rest and the same last valuation. `Ret.of_walk`: `Walk.walkI`, then the exit and the effects'
   run at the same last valuation.
2. By `Grid.start_run`, entry `k` of the start's thread array is `.run t` with
   `Thread.start fn as = .ok t` for some arguments `as`. `Thread.start` fails when `fn` has no
   block, and otherwise returns exactly the one-frame thread at the first block's label,
   instruction 0, no `alloca` blocks and step count 0. `Grid.thread` reads `t` back.
3. Fix an admitted choice and oracle. The start succeeds, with `g` and `c`; take `P` from the
   premise. `Seq.start_sound_inv` needs `P 0 g.mem`, the trace and observation facts on `P N`
   (premises), and, for each thread `k < N` and memory `m'` of `P k`, a run to its end leaving a
   memory of `P (k + 1)`. For that run: by 2, thread `k` is `⟨[f], 0⟩` with `f` at the entry;
   the premise gives a path of `paths` that is a `Ret` from `Valuation.entry (c k) 0 m' f`; by
   `coversEntry` the path starts at the entry's label and is accepted from instruction 0; the
   context's program is `prog` (`Grid.start_ctx`); so 1 gives the run and `P (k + 1)`. In the
   second case, `Runs.of_chains` (MojoProof/Sym/Loop.lean) gives the run and `P (k + 1)` from
   `coversChains`, the same frame facts and the `RetLs`: `coversChains` says that `C` starts at
   the entry's label and that its paths are accepted, `Chain.reach` takes the thread through the
   loops to the last path, `Block.sound_retI` takes it to its end, and the frame has no `alloca`
   blocks, so the memory left is the `RetLs`'s. The conclusion `Grid.Sound L c g obs R` with the
   start's equation is `Kernel.Sound` at this choice. `Kernel.sound_of_paths`: the theorem at
   `chains = []` (`coversChains` of no sequence is `true` by evaluation), each thread's premise
   the first disjunct.
4. Zero: the fold over `range 0` is the identity (so block `out` is `(m₀.blocks out).map id`),
   and an empty trace has no access. Successor: `range (k + 1)` is `range k` followed by `k`, so
   the fold for `k + 1` is thread `k`'s write after the fold for `k`; old accesses were owned and
   new ones are owned by premise. Safety: `racy_kept_of_cells` (MojoProof/Sem/Trace.lean) asks,
   of every access of the trace, exactly the three conjuncts of `Elem.Own`, and `Apart cell w`.
5. `Ret.of_check`: on a nonempty path the Boolean's three conjuncts give `WalkI`, the exit, and an
   `.ok me` of the effects, and `Ret.out` is that `me`. `Kernel.sound_eval`: apply 3 with the
   admission's one choice and oracle (the start's equation is the premise) and the invariant
   `P k m' := m' = Kernel.mems g c paths k`. `P 0` is `Kernel.mems`'s first equation. For thread
   `k` with frame `f`, `Kernel.check`'s conjunct `k` says that `Ret.check` accepts the picked path
   on `Kernel.mems … k`, so `Ret.of_check` makes it a `Ret` to `Kernel.mems … (k + 1)`, which is
   `Ret.out` of that path by `Kernel.mems`'s second equation at `[f]`; the picked path is in
   `paths` because `find?` returned it (it is not `none`, since `Ret.check` rejects the empty
   path). `P N` is the premises on `Kernel.mems … N`.
6. Apply 3 with the invariant `P k := Elem g.mem out w cell bs k`. `P 0 g.mem` is `Elem.zero` on
   the start's empty trace (`Grid.start_trace`); the per-thread premise is the hypothesis. On
   `P N`, `Elem.safe` with `Apart` gives the trace facts, and the observation `some m'.blocks`
   meets `Elem.Out`: block `out` of `m'` is block `out` of `g.mem` with the puts (`Elem.cells`),
   which is block `out` of `m` (`Grid.start_blocks`) after the puts of the
   `g.threads.size = N` threads (`Grid.start_args`); every other block is `g.mem`'s
   (`Elem.rest`), hence `m`'s.
   `Kernel.sound_mapN`: apply `Kernel.sound_elem`. For a thread `k` with frame `f` on a memory
   `m'` of `Elem k`: `f.fn = fn` (`Grid.start_thread`), `k` is below the thread count
   (`Grid.start_args`), the context facts are `Grid.start_ctx` and `Grid.start_env`. For each
   position `i` of `bl`, parameter `i` is `ps[i]` and argument `i` is the struct of `bl[i]`
   (`List.getElem?_append_left`, `List.getElem?_map`); no earlier parameter is named `%i`, since
   parameter `j` is named `%j` (`take_names`); so register `%i` points to a block `q` of `g.mem`
   owned by thread `k` from which `T` loads as the struct (8, `Grid.start_buffer` with the codec).
   `q` is not `o`, which `g.mem` has with `m`'s owner `.all` (`Grid.start_blocks`), so the struct
   load moves from `g.mem` to `m'` (`Elem.load`). Parameter and argument `n` are `pc` and `v`
   (`List.getElem?_append_right`), so `%n` is `u` (`Grid.start_scalar`). The blocks of `m` other
   than `o` are blocks of `g.mem` (`Grid.start_blocks`) and of `m'` (`Elem.rest`; together
   `Elem.start_block`). Then the premise applies at `m₀ = g.mem`. `Kernel.sound_map2`: apply
   `Kernel.sound_mapN` at `ps = [p0, p1, p2]`, `pc = p3` and `bl = [a, b, o]`, the pointer bytes
   by `Mem.Closed.bytesIn` from `Map2.Pre`'s `closed` and `o`'s owner from its `Mem.Buffer`; the
   names by cases on the position. For a thread, the three positions give `q0` to `q2`; the facts
   of `a` and `b` move from `m` to `m'` since each reads only its block (`Mem.Buffer.of_block`,
   `Mem.Fits.of_block`, `Mem.Holds.of_block`), and those of `o` move to `m₀` and then by
   `Elem.buffer` and `Elem.fits`. Then the premise applies.
7. `vadd.ret`, generated by `mojo_kernel`'s `map2` clause (MojoProof/Sym/KernelCmd.lean, item 6):
   the tactic `mojo_ret` (MojoProof/Sym/Ops.lean, docs/tactics.md; not reproved here). No path
   is proved before a case split, so it splits on the branch condition neither side of which `omega`
   decides, `k < n` (the index `ctaid * ntid + tid` is `k` on a one-dimensional launch,
   `Launch.index_oneDim`). On each side it takes the path the branch selects, path 0 (`%4 → %21 →
   %31`) for `k < n` and path 1 (`%4 → %30 → %31`) otherwise, and proves its premises (`Walk`,
   mojo_obl's walk, docs/proofs/obl.md) and each block's effects as steps of `Elem` with the node
   values as `mojo_vals` proves them: block `%4`'s three loads from the structs' blocks `p0` to
   `p2`, not `out` (`Elem.apply_load`); on path 1 no effect, and `bs k = none` for `k ≥ n`
   (`Elem.skip`); on path 0 block `%21`'s loads of `x_k` and `y_k` from `a` and `b` and its store of
   the encoding of `deliver (x_k + y_k)` at `⟨out, 4 k⟩`, thread `k`'s bytes (`Elem.apply_store`);
   the blocks before the last by `Elem.after` (MojoProof/Sym/Ops.lean, `Valuation.after_mem`),
   the last by
   `Elem.ret` (`Ret.of_walk`). `vadd.correct`, generated by the same clause:
   `Kernel.sound_map2` (6) at `vadd.covers`, `vadd.starts` and cells `4 i`, which are 4 apart
   (`apart_mul`, from `apart_stride` at base 0), with `T = vadd.argTy`, `z = vadd.argTail`, the
   codec `Layout.Codec.ptrArg` at alignment 8, the parameters' names, `byval` types and `withAttrs`
   by `rfl`; its per-thread premise is `vadd.ret`.
8. `launchArgs` is a `foldlM` over `(fn.params.zip args).zipIdx`; `foldlM_zipIdx_inv` proves an
   invariant `P i` of the accumulator from one step at each position. The invariant: the list has
   length `i` and each entry `j < i` is its `LaunchArg` in the current memory. A `byval` step
   allocates block `next` (`Mem.allocNext`, which fails if `next` is taken), so the blocks before
   are unchanged (`LaunchArg.mono`) and the new entry is the pointer to it, whose block is
   `byvalBlock` by the definition of `Mem.alloc`; another step keeps the memory. `Thread.start`
   sets the registers by the first parameter of each name (`find?` over the zip), so with no
   earlier parameter of name `r`, induction on the parameters gives the argument at `i`.
   `Grid.start_arg`: `Grid.start_args` gives thread `k`'s `launchArgs` and `Thread.start`, and the
   blocks of the arguments' memory are blocks of `g.mem`. `Mem.load_byval`: the block's address in
   the generic space is `ch (2 i) * align % 2 ^ w`, which `al` divides; the check passes (owner
   thread `k`, offset 0, `T`'s stored size within its size), and the bytes read are the encoding
   (`read_alloc`, `Layout.encode_length`), which decodes to `enc x` by the codec's round trip.
9. `Kernel.Sound.obs`: the admitted `Kernel.Sound` gives the start's grid `g` and `Grid.Sound` of
   `g`; `Kernel.Obs`'s start is the same (the start is a function), so `post` applies to its done
   grid. `Elem.Out.map2_word`: `Elem.Out`'s first field gives block `out` of `B` as
   `Elem.put cell bs M` of `m`'s block; every encoding is `l.stored (.fp ft)` bytes long and decodes
   back (`Elem.encode_float`, from `Layout.Codec.float`'s round trip), so `Elem.put_read` (by
   induction on `M`: a put at cell `k` is read back, `Block.read_put_self`, and a put at another
   cell, `w` apart, is not seen, `Block.read_put_apart`) reads thread `k`'s encoding at cell `k`,
   which decodes to its float. `Kernel.map2_min`: `Elem.map2` is `none` from `n` on
   (`Elem.map2_none`), so `Elem.put_of_none` (induction on `T - n` with `Elem.put_succ`) gives
   `Elem.Out.min`, and `Kernel.Sound.map` at `f := some` lifts it. `Kernel.map2_real`:
   `Kernel.Sound.obs` then `Elem.Out.map2_word` give `v = deliver r (o k)` with `r = op x_k y_k`; if
   `v` is finite, `r` is not a NaN (a NaN is delivered as a NaN, `isNaN_deliver`, which is not
   finite), and `deliver` returns a non-NaN unchanged (`deliver_of_isNaN_eq_false`).
   `Kernel.map2_finEq`: the same at each oracle, with its own admission `ω' = ω` met by `rfl`, gives
   `deliver r (o ω k)` and `deliver r (o ω' k)`, which are `FinEq` (`FinEq.deliver` from `r = r`).
   With `FinEq.eq_of_isFinite`: as `Kernel.map2_finEq`, and the finite `deliver r (o ω k)` makes `r`
   not a NaN, so both are `r`. The instances: `Kernels.vadd.bytes ω` is `Elem.map2` at `Model.add`
   by definition, `out` is a block of `m` by `Map2.Pre`'s buffer field, the cells `4 i` are 4 apart
   (`apart_mul`) and `l.stored (.fp .float) = 4` by `rfl`; `vadd_real` adds TorchLean's
   `Tensor.add_apply` and FloatLib's `Model.toReal_add_eq_roundAt` (binary32 is IEEE, by `rfl`),
   `vmul_real` adds TorchLean's `Tensor.mul_apply` and FloatLib's `Model.toReal_mul_eq_roundAt`.
10. `Elem.Out.outBelow`: for each block `b` below `nb`, if `m` has none the check is `true`;
   otherwise `Elem.Out`'s first field (at `out`) or second field (elsewhere) gives `B b` as the
   block the check compares with, and every block agrees with itself (`Elem.agree_self`).
   `Kernel.replay_canaries`: for a canary `bs'`, `List.all` gives its replay's `bad`, and
   `Kernel.replay_block` (MojoProof/Sem/Replay.lean) at `f = Elem.put cell bs' T` refutes the
   relation, whose block `out` is `f` of `m`'s by `Elem.Out`'s first field; `Kernel.replay_block`
   is `Kernel.replay_sound` for the observation of block `out`'s bytes, to which `Kernel.Sound.map`
   carries the observation of the blocks.

## Dependencies

`Block.sound_retI`, `coversPathI`, `WalkI`, `Walk`, `Exit.of_target`, `Valuation.entry`,
`Valuation.into`, `Valuation.lastI`, `Valuation.last` (Sym/Block.lean);
`SEff.run`, `vals` (Sym/Term.lean); `Runs`, `Grid.thread`, `Seq.start_sound_inv`
(Sym/Sched.lean); `LoopChain`, `Chain`, `RetLs`, `coversChains`, `Runs.of_chains`, and for the
loop instance `Chain.of_rounds`, `Edge.dec`, `Round.dec` (Sym/Loop.lean); `Grid.start_run`
(Sem/Closed.lean); `Grid.start_ctx` (Sem/Grid.lean); `Thread.start` (Sem/Thread.lean);
`racy_kept_of_cells`, `Apart` (Sem/Trace.lean, Sem/Buffer.lean).
For 6 and 7 also: `Grid.start_blocks` (Sem/Grid.lean), `Grid.start_trace`
(Sem/ScheduleOwned.lean); `Grid.start_args`, `Grid.start_env` (Sym/Start.lean);
`Launch.sreg_bound` (Sem/Spec.lean); `SNode.eval_sreg` (Sym/OblLemmas.lean); `Launch.index_ops`,
`Launch.index_oneDim`, `intCast_trunc_sext` (Sem/Index.lean); `apart_stride` (Sem/Buffer.lean);
`gep_buffer`, `load_buffer`, `SVal.eval_reg`, `SVal.eval_node` (Sym/OblLemmas.lean);
`floatBin_ofFloat` (Sem/FloatRel.lean). For 7 and 8: `Map2.Pre`, `Mem.Fits`,
`Layout.Codec.ptrArg` (Sem/Precond.lean); `launchArgs`, `Mem.allocNext`, `withAttrs`
(Sem/Thread.lean); `Mem.check_ok`, `Mem.load_of_check`, `read_alloc` (Sem/Buffer.lean);
`Mem.Closed.bytesIn` (Sem/Closed.lean). For 9: `deliver`, `deliver_of_isNaN_eq_false`,
`isNaN_deliver` (Sem/Float.lean); `FinEq`, `FinEq.deliver` (Sem/FloatRel.lean);
`Layout.Codec.float`, `Block.read_put_self`, `Block.read_put_apart` (Sem/Buffer.lean); for the
instances FloatLib's `Model.toReal_add_eq_roundAt`, `Model.toReal_mul_eq_roundAt` and TorchLean's
`Tensor.add_apply`, `Tensor.mul_apply`. For 10: `Kernel.replay`, `Kernel.replay_block`,
`Kernel.replay_sound`, `Kernel.Sound.map`, `Replay.bytes?` and the probes `Probe.drop`,
`Probe.stale`, `Probe.swap`, `Probe.zero`, `Probe.copy` (Sem/Replay.lean).

## Scope

- `Kernel.sound_of_chains` (3) holds for every program, kernel, launch, admitted address choice
  and oracle, list of paths and list of sequences of loops. It covers the kernels whose every
  thread runs in its own frame, with no barrier or other collective call (every grid step is a
  thread's `Grid.advance`), either one path without a cycle from the entry to `ret` or a
  sequence of loops (each with the loops nested in its rounds) from the entry to `ret`. The
  per-thread `Ret` or `RetLs` on every memory of the invariant, with each loop's invariant and
  trip count, is the caller's premise. `Kernel.sound_of_paths` is its case without loops.
- Its loop instance (MojoProofTest/KernelLoop.lean) is one program and one launch: `cntK`, the
  counting loop of MojoProofTest/SymLoop.lean (`for i in [0, n): p[i] = i`) with `%n` and `%p`
  as parameters, on one block of one thread with `n = 3`, the memory `outC` (one global writable
  block of three `i64` cells), address choice `ch₀` and oracle `ω₀`. `kernelK` is an instance
  of `loopK.sound_loop`, which `mojo_kernel` generates for `cntK` with the `pointers` clause for
  `%p` and the loop clause; its per-thread premise, the precondition `preB` at the start's one
  frame, is evaluated by the kernel. The clause's obligations are closed by `invB_entry`,
  `invB_step` and `invB_exit`, which hold for every function with `cnt`'s blocks, every context
  whose program has `cntP`'s layout, and every bound `n ≤ 2 ^ 60`, block and trace. Their
  invariant `invB` is SymLoop's `invN` (stated for `cnt` itself) with the stores of the rounds
  so far on the trace, so that the postcondition gives the end's trace.
- The `loop` clause of `mojo_kernel` (docs/kernel.md) proves `n.loop` from its four obligations
  by `Chain.loop` at the clause's invariant and trip count, with `Chain.last` for each round and
  for the path out (`Ret.mono` from the postcondition to `Q`), and `n.sound_loop` by `n.sound_of`
  (3, the second disjunct) and `n.loop`. Its instance `cntk.loop` (MojoProofTest/KernelCmd.lean)
  holds for every valuation of `cntPre`, at every bound `n ≤ 2 ^ 60`; `cntk_three` applies it at
  `start 3`. `cntk.sound_loop` has no instance: `cnt` has no parameters, so no start meets
  `cntPre`. `loopK.sound_loop` (MojoProofTest/KernelLoop.lean) is the one for `cntK`. With a
  clause for each of several loops in sequence, `n.loop` is `Chain.loop` for each loop in turn:
  the next loop's run starts at every valuation of the invariant at the trip count, by that
  loop's exit obligation (the next clause's precondition, and the next postcondition implies
  this one's), and the last loop's path out ends with `Chain.last` and `Ret.mono`. Its instance
  `cnt2k.loop` (MojoProofTest/KernelLoop.lean) is SymLoop's `cnt2` from one valuation, `V2`
  (`%n = 2`); `cnt2k_retLs` applies it there.
- `Kernel.sound_eval` (5) holds for every program and kernel, at one launch, memory, address
  choice and oracle, where it reduces the theorem to Booleans the kernel decides. Its instance
  `kernel22` is `vector_addition` on 2 blocks of 2 threads with 3 elements, so threads 0 to 2 take
  the in-range path and thread 3 the other, on the paths `mojo_kernel` generates
  (MojoProof/Kernels/Vadd.lean).
- `Kernel.sound_elem` (6) holds for every elementwise kernel that meets its premises,
  `Kernel.sound_mapN` (6) for the family of kernels whose parameters are any number of `byval`
  buffer structs then a count of any type, and `Kernel.sound_map2` (6) for its case of three
  structs and an `i32` count. In all three, the per-thread `Ret` is the caller's premise. No
  instance of `Kernel.sound_mapN` other than `Kernel.sound_map2` is proved: the `map2` clause
  of `mojo_kernel` is the only one that generates its per-thread `Ret`.
- `vadd.correct` (7) is about the one kernel `vector_addition`, at every valid launch whose grid
  and block have side 1 in `y` and `z` and every caller's memory of `Map2.Pre`. It takes the
  per-thread `Ret` from `mojo_ret` (`vadd.ret`) and the start facts from `Kernel.sound_map2` (6)
  and 8. Its instances in MojoProofTest/Kernel.lean are `correct23` (2 blocks of 3 threads,
  5 elements, nonconstant inputs on `Map2.mem`, every premise discharged) and `correct12` (one
  block of 2 threads, fewer than the 5 elements). `vmul.correct` is the same for the one kernel
  vector_multiply.
- Not covered: calls to defined functions, barriers and shuffles.

The corollaries (9) are for every program and kernel whose theorem is `Kernel.Sound` for `Elem.Out`
with `Elem.map2`'s bytes; their instances `vadd_*` and `vmul_*` cover what `Kernels.vadd.correct`
and `Kernels.vmul.correct` cover (every valid launch whose grid and block have side 1 in `y` and
`z`, memory of `Map2.Pre`, address choice and oracle). The checks by evaluation and the refutations
(10) are for one launch, memory, address choice `ch₀` and oracle `ω₀` each
(MojoProofTest/Kernel.lean): the satisfiability witness `g2_vadd` (`Grid.start` then `Grid.run` on
`L23` with count 5 and `mem5`, whose final grid is done and meets `Elem.outBelow` and the sums cell
by cell; `correct23` gives `Elem.Out` itself for it); the negative twins `twin_len` (a),
`twin_alias` (b), `twin_tid` (c) and `twin_2d` (d), each a `¬ Kernel.Sound` for every observation,
relation and admission that admits `ch₀` and `ω₀` (`Kernel.replay_unsafe`), with the run that shows
what fails (`run_len`, a fault; `run_alias`, `kept` false without a race; `run_tid`, a race with its
two accesses; for (d) the hypothesis `block y = 1` false); and the canaries `canaries_vadd`,
`canaries_vmul` (`Kernel.replay_canaries`), whose controls are `correct23` and `correctV23`.

`Kernel.Sound`'s predicate `R` does not see the oracle. A result that names the oracle's numbers
(for `vector_addition`: cell `i` is `fadd`'s value at thread `i`'s oracle number) is stated for
every oracle `ω` with the admission `fun _ o => o = ω` and a predicate `R ω`.
