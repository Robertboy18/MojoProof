# PROOF: the kernel theorem from a covered path or loop run per thread (`Kernel.sound_of_chains`)

Lean: MojoProof/Sym/Kernel.lean and, for matmul kernels (13), MojoProof/Sym/KernelMat.lean, with
the scope of each statement given below and in the section
"Scope". Instances and twins: MojoProofTest/Kernel.lean, for a kernel whose thread runs a loop
MojoProofTest/KernelLoop.lean, for a kernel whose threads run a loop and store to cells apart
only on the storing threads MojoProofTest/KernelCells.lean, for a kernel whose threads run a loop
with `fmul contract` MojoProofTest/KernelContract.lean, and for 2-D cells and `Elem.Out` at the
end of a run MojoProofTest/KernelXY.lean. The section "Plan: the naive matmul's kernel theorem"
is a plan, not a proof. The command that generates a kernel's theorem from these is described in
docs/kernel.md.

The kernel theorem composes four facts proved once: the block checker's path theorem with
`phi`s (`Block.sound_retR`, MojoProof/Sym/Path.lean), the loop theorem for a thread through a
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
   a `Ret` along some path of `paths` for every thread. `Kernel.sound_of_chainsWith` is the
   theorem for every flag `contract`: the checks are `coversEntryWith contract` and
   `coversChainsWith contract` (with `fmul contract` in the path checker when `contract`,
   `coversPathWith`), and each thread's run is a `RetWith contract` along a path or a
   `RetLsWith contract` through a sequence of loops, in which a `fadd contract` reads the operands
   of a recorded `fmul contract` and fuses them or not by the thread's oracle.
   `Kernel.sound_of_chains` is its case `contract = false`.
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
   the conclusion of `Kernel.sound_elem` holds on those arguments with `out = o`. It is
   `Kernel.sound_mapNWith` (11) without `fmul contract`, with no loops, the one scalar
   `(pc, v, u)`, `S` every thread and the admission of `ω` alone.
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
   `Elem.Out.of_outBelow`, the converse: for every `m`, `out`, `cell`, `bs`, `N`, `nb`, `K` and
   `B`, if `B` passes the check, `m` has no block from `nb` on, every thread `i < N` with bytes
   `l` has `cell i + l.length ≤ K`, and every block `x` of `m` and `B`'s block `y` at its number
   have `y.bytes i = x.bytes i` for every `i ≥ K`, then `Elem.Out m out cell bs N B`.
   `Elem.Out.of_run`: for every program, kernel, launch, arguments, memory `m`, choice and oracle
   whose start gives `(g, c)`, and grid `z` that `g` reaches (`Grid.Step`), if `z`'s blocks pass
   `Elem.outBelow m out cell bs N nb K`, `m` has no block from `nb` on, every thread `i < N` with
   bytes `l` has `cell i + l.length ≤ K`, and every block of `m` is owned by no thread and has at
   most `K` bytes, then `Elem.Out m out cell bs N z.mem.blocks`.
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

11. Elementwise kernels with loops (MojoProof/Sym/Kernel.lean). `Elem.Only out S m`: every access
   to block `out` on `m`'s trace is by a thread of `S`. `Elem.Only.log`: logging an access keeps
   it if, when the access is to `out`, its thread is in `S`. `Elem.Only.apply`: a block effect
   (`SEff.apply`) that succeeds at a valuation whose thread is in `S` keeps it. `Elem.safe_on`:
   every memory of `Elem m₀ out w cell bs k` and `Elem.Only out S` whose cells are `w` apart on
   `S` (`Apart (fun i : {i // S i} => cell i) w`; the cells of other threads may overlap them) has
   a trace with no data race that keeps the promise of `!invariant.load`. `Kernel.sound_cells`:
   for every program, kernel, launch, arguments, admission `adm`, paths, sequences of loops,
   output block `out`, cells, bytes and set `S`, let `coversEntry` and `coversChains` hold, the
   caller's pointer bytes be known, the start succeed on every admitted choice and oracle, and the
   cells be `w` apart on `S`. If on every admitted start `(g, c)` every thread `k` with frame `f`,
   from every memory `m'` of `Elem g.mem out w cell bs k` and `Elem.Only out S`, with
   `V = Valuation.entry (c k) 0 m' f`, either takes some path of `paths` that is a `Ret` from `V`,
   or runs some sequence of `chains` from `V` to `ret` (`RetLs`), to a memory of
   `Elem g.mem out w cell bs (k + 1)` and `Elem.Only out S`, then
   `Kernel.Sound prog fn L args m adm (fun m => some m.blocks) (Elem.Out m out cell bs N)`.
   `Kernel.sound_elem` (6) is its case with no loops, `S` every thread and one oracle.
   `Kernel.sound_cellsWith` is the theorem for every flag `contract` (`coversEntryWith`,
   `coversChainsWith`, `RetWith` and `RetLsWith` at `contract`, as in 3); `Kernel.sound_cells` is
   its case `contract = false`. `Kernel.sound_mapNWith`: for every flag `contract`, let `fn`'s
   parameters be `ps ++` the parameters of a list `sc` of scalars (each a parameter, its argument
   and the value `withAttrs` takes the argument to on every memory), the one at each position `j`
   named `%j`, every one of `ps` `byval` of a struct type `T` with a codec for `.agg [.ptr p, z]`
   (alignment `al'` dividing `T`'s and the generic space's) and none of `sc`'s `byval`; let `bl`
   be block numbers, one for each of `ps`, `m`'s pointer bytes be known, `m` have block `o` owned
   by all threads, the start on `bl.map (fun a => .agg [.ptr ⟨a, 0⟩, z]) ++ sc.map (·.2.1)`
   succeed on every admitted choice and oracle, and the cells be `w` apart on `S`. If for every
   admitted choice and oracle, thread `k < N`, context with `prog`, `L.env k`, identity
   `⟨k, k / volume L.block⟩` and oracle `oracle k`, memory `m₀` with `m`'s block `o`, memory `m'`
   of `Elem m₀ o w cell bs k` and `Elem.Only o S` on which every block of `m` but `o` is
   unchanged, and frame `f` of `fn` whose `%i`, for each position `i` of `bl`, points to offset 0
   of a block other than `o` from which `T` loads at alignment `al'` as the struct of `bl[i]`, and
   whose `%(n + j)` (`n` the length of `bl`) is `sc[j]`'s value, either some path of `paths` is a
   `RetWith contract` or some sequence of `chains` runs to `ret` (`RetLsWith contract`), to a
   memory of `Elem m₀ o w cell bs (k + 1)` and `Elem.Only o S`, then
   `Kernel.Sound prog fn L (bl.map (fun a => .agg [.ptr ⟨a, 0⟩, z]) ++ sc.map (·.2.1)) m adm
   (fun m => some m.blocks) (Elem.Out m o cell bs N)`. `Launch.apart_xy`: for every valid launch
   `L` with side 1 in `z`, row stride `s`, bounds `m` and `n ≤ s` and width `w`, the cells
   `(L.index k .x * s + L.index k .y) * w` are `w` apart on the threads `k < N` with
   `L.index k .x < m` and `L.index k .y < n`.
12. The start's facts as premises (MojoProof/Sym/Kernel.lean). `Kernel.sound_entry`: for every
   program, kernel `fn`, launch, arguments `args`, memory `m`, admission, observation `obs`,
   predicate `R`, paths and sequences of loops, let `coversEntry` and `coversChains` hold, the
   caller's pointer bytes be known, the start succeed on every admitted choice and oracle, and
   `obs` read only blocks. Let `I` be a predicate on the number of threads done and a memory such
   that `I 0` holds of every memory that has every block of `m` and an empty trace; for every
   thread `k < N` and valuation `V` whose context has the program `prog`, the identity
   `⟨k, k / volume L.block⟩` and the special registers `L.env k`, whose function is `fn`, whose
   register `r` holds `w` for every position `i` with parameter `p` named `r` (named by no earlier
   parameter, not `byval`), argument `v` and `withAttrs` taking `v` to `w` on every memory, and
   whose memory is one of `I k`, either some path of `paths` is a `Ret` from `V` to `I (k + 1)`
   or some sequence of `chains` runs from `V` to `ret` with a memory of `I (k + 1)` (`RetLs`); and
   let every memory of `I N` have a trace with no data race that keeps the promise of
   `!invariant.load` and an observation `y` with `R y`. Then
   `Kernel.Sound prog fn L args m adm obs R`. `Kernel.sound_entryWith` is the theorem for every
   flag `contract` (as in 3), with `I` also indexed by the start's memory `m₀` (`I m₀ 0 m₀` for
   every `m₀` that has `m`'s blocks and an empty trace, the per-thread premise for every admitted
   choice and oracle and every `m₀` that has `m`'s blocks, from a memory of `I m₀ k` to
   `I m₀ (k + 1)`, and the end on `I m₀ N` for every `m₀`) and two more facts on `V`: its oracle is
   `oracle k`, and the register `r` of every `byval(t)` parameter named `r` (by no earlier
   parameter) whose argument is `enc x` for a codec `enc` of `t` points to offset 0 of a block of
   `m₀` owned by thread `k` from which `t` loads as `enc x` at every alignment dividing `t`'s and
   the generic space's. `Kernel.sound_entry` is its case `contract = false` with `I` not
   depending on `m₀`. `n.sound_loop`, which `mojo_kernel` generates with
   the `loop` clause when `fn` is a constant and the program has no globals: for every launch,
   block numbers and scalars of the clauses, memory `m` closed for `n.args` (`Mem.Closed`) whose
   pointer bytes are known, admission, observation reading only blocks, predicate `R` and
   invariant `I` as above, if each thread's `V` with the facts above (the registers of the
   `scalars` and `pointers` parameters holding their arguments as hypotheses) and a memory of
   `I k` meets the first clause's precondition `pre V`, with every memory of `post V` one of
   `I (k + 1)`, and `I N` gives the trace and observation facts, then the kernel on `n.args` is
   `Kernel.Sound`.
13. Matmul kernels (MojoProof/Sym/KernelMat.lean). `Kernel.sound_mat`: for every flag
   `contract`, program `prog`, kernel `fn` whose parameters are `p0` to `p5`, the one at each
   position `j` named `%j`, `p0` to `p2` `byval` of a struct type `T` with a codec for
   `.agg [.ptr p, z]` (alignment `al'` dividing `T`'s and the generic space's) and `p3` to `p5`
   not `byval`, whose attributes keep the `i32` words of `m`, `n` and `K` on every memory, valid
   launch `L` with side 1 in `z`, paths and sequences of loops with `coversEntryWith contract` and
   `coversChainsWith contract`, element type `t` with encoder `enc`, alignment `al`, blocks `o`,
   `a`, `b`, row strides `sA`, `sB`, `sC` with `n ≤ sC`, tensors `x` (`m × sA`) and `y`
   (`n × sB`), and memory `mem` closed for `Mat.args z o a b m n K` with `a ≠ o`, `b ≠ o`, the
   three `Mem.Buffer`s, `Mem.Holds` of `x` and `y` and the three `Mem.Fits` of `Mat.Pre`, let the
   start on `Mat.args z o a b m n K` succeed on every admitted choice and oracle, and let
   `S k := k < N ∧ L.index k .x < m ∧ L.index k .y < n` and
   `cell k := (L.index k .x * sC + L.index k .y) * w`. If for every admitted choice and oracle,
   thread `k < N`, context with `prog`, `L.env k`, identity `⟨k, k / volume L.block⟩` and oracle
   `oracle k`, memories `m₀` and `m'`, and frame `f` of `fn` whose `%0` to `%2` point to offset 0
   of blocks other than `o` from which `T` loads at alignment `al'` as the structs of `o`, `a`,
   `b`, and whose `%3` to `%5` are the words of `m`, `n`, `K`, on which `m'` has the buffers of
   `mem` (`a` and `b` holding `x` and `y`), from `Elem m₀ o w cell bs k` and `Elem.Only o S`,
   a thread of `S` runs some sequence of `chains` to `ret` (`Hin`, `RetLsWith contract`) and a
   thread not of `S` takes some path of `paths` (`Hout`, `RetWith contract`), to a memory of
   `Elem m₀ o w cell bs (k + 1)` and `Elem.Only o S`, then
   `Kernel.Sound prog fn L (Mat.args z o a b m n K) mem adm (fun m => some m.blocks)
   (Elem.Out mem o cell bs N)`.

## Proofs

1. `Runs.of_ret` is `Runs.of_retWith` (MojoProof/Sym/Loop.lean) at `contract = false`. There:
   if the path is empty, `Ret` is false. Otherwise the path is a chain with no loop, and
   `Runs.of_chainWith` runs it to its end. Its last block is taken there by
   `Block.sound_retWith`, the theorem `Block.sound_retR` is the `false` case of: the thread's
   steps reach the last block's end on the memory `me'` that the last block's effects make, and
   the next step is `.done` of `f.allocas.foldl (setLive · false) me'`. The effects' result is
   `.ok me'` and `.ok me`, so `me' = me`, and the fold over the empty list of `alloca` blocks is
   `me`. Steps followed by that step is `Runs` by definition.
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
   loops to the last path, `Block.sound_retR` takes it to its end, and the frame has no `alloca`
   blocks, so the memory left is the `RetLs`'s. The conclusion `Grid.Sound L c g obs R` with the
   start's equation is `Kernel.Sound` at this choice. `Kernel.sound_of_paths`: the theorem at
   `chains = []` (`coversChains` of no sequence is `true` by evaluation), each thread's premise
   the first disjunct. The theorem proved this way is `Kernel.sound_of_chainsWith`, at every flag,
   with `Runs.of_retWith` for a path and `Runs.of_chainsWith` for a sequence of loops
   (MojoProof/Sym/Loop.lean; `Block.sound_retWith` for the last block, MojoProof/Sym/Path.lean).
   `Kernel.sound_of_chains` is it at `false`: `coversEntryWith false` is `coversEntry` and
   `RetWith false` is `Ret` by definition, and `RetLs` gives `RetLsWith false` (`Chain.with_iff`).
4. Zero: the fold over `range 0` is the identity (so block `out` is `(m₀.blocks out).map id`),
   and an empty trace has no access. Successor: `range (k + 1)` is `range k` followed by `k`, so
   the fold for `k + 1` is thread `k`'s write after the fold for `k`; old accesses were owned and
   new ones are owned by premise. Safety: `Elem.safe` is `Elem.safe_on` (11) with every thread in
   `S` (`Apart cell w` composed with the injective `Subtype.val`; `Elem.Only` holds trivially).
5. `Ret.of_check`: on a nonempty path the Boolean's three conjuncts give `WalkI`, the exit, and an
   `.ok me` of the effects, and `Ret.out` is that `me`. `Kernel.sound_eval`: apply 3 with the
   admission's one choice and oracle (the start's equation is the premise) and the invariant
   `P k m' := m' = Kernel.mems g c paths k`. `P 0` is `Kernel.mems`'s first equation. For thread
   `k` with frame `f`, `Kernel.check`'s conjunct `k` says that `Ret.check` accepts the picked path
   on `Kernel.mems … k`, so `Ret.of_check` makes it a `Ret` to `Kernel.mems … (k + 1)`, which is
   `Ret.out` of that path by `Kernel.mems`'s second equation at `[f]`; the picked path is in
   `paths` because `find?` returned it (it is not `none`, since `Ret.check` rejects the empty
   path). `P N` is the premises on `Kernel.mems … N`.
6. `Kernel.sound_elem` is 11 at `chains = []` (`coversChains` of no sequence is `true` by `rfl`),
   `S` every thread (`Apart cell w` composed with the injective `Subtype.val` is `Apart` on the
   subtype), the admission `fun _ ω' => ω' = ω`, and each thread's `Ret` to `Elem` raised to a
   `Ret` to `Elem` and the trivially true `Elem.Only` (`Ret.mono`), the first disjunct.
   `Kernel.sound_mapN`: apply `Kernel.sound_mapNWith` (11) at `contract = false`, `chains = []`,
   `sc = [(pc, v, u)]`, `S` every thread and the admission `fun _ ω' => ω' = ω`; its scalar fact
   at `j = 0` is `%n = u`, and each thread's `Ret` to `Elem` is raised to a `Ret` to `Elem` and
   the trivially true `Elem.Only` (`Ret.mono`), the first disjunct. `Kernel.sound_map2`: apply
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
   induction on `M`: a put at cell `k` is read back, `Block.read_put_self`, a put by another thread
   with bytes, at a cell `w` apart, is not seen, `Block.read_put_apart`, and a thread without bytes
   puts nothing), with `Apart cell` restricted to the threads with bytes (`Subtype.val_injective`),
   reads thread `k`'s encoding at cell `k`, which decodes to its float. `Kernel.map2_min`:
   `Elem.map2` is `none` from `n` on (`Elem.map2_none`), so `Elem.put_of_none` (induction on `T - n`
   with `Elem.put_succ`) gives `Elem.Out.min`, and `Kernel.Sound.map` at `f := some` lifts it.
   `Kernel.map2_real`: `Kernel.Sound.obs` then `Elem.Out.map2_word` give `v = deliver r (o k)` with
   `r = op x_k y_k`; if `v` is finite, `r` is not a NaN (a NaN is delivered as a NaN,
   `isNaN_deliver`, which is not finite), and `deliver` returns a non-NaN unchanged
   (`deliver_of_isNaN_eq_false`). `Kernel.map2_finEq`: the same at each oracle, with its own
   admission `ω' = ω` met by `rfl`, gives `deliver r (o ω k)` and `deliver r (o ω' k)`, which are
   `FinEq` (`FinEq.deliver` from `r = r`). With `FinEq.eq_of_isFinite`: as `Kernel.map2_finEq`, and
   the finite `deliver r (o ω k)` makes `r` not a NaN, so both are `r`. The instances:
   `Kernels.vadd.bytes ω` is `Elem.map2` at `Model.add` by definition, `out` is a block of `m` by
   `Map2.Pre`'s buffer field, the cells `4 i` are 4 apart (`apart_mul`) and
   `l.stored (.fp .float) = 4` by `rfl`; `vadd_real` adds TorchLean's `Tensor.add_apply` and
   FloatLib's `Model.toReal_add_eq_roundAt` (binary32 is IEEE, by `rfl`), `vmul_real` adds
   TorchLean's `Tensor.mul_apply` and FloatLib's `Model.toReal_mul_eq_roundAt`.
10. `Elem.Out.outBelow`: for each block `b` below `nb`, if `m` has none the check is `true`;
   otherwise `Elem.Out`'s first field (at `out`) or second field (elsewhere) gives `B b` as the
   block the check compares with, and every block agrees with itself (`Elem.agree_self`).
   `Elem.Out.of_outBelow`: a block `x` of `m` is at a number below `nb`, so the check gives a
   block `y` of `B` there that `Elem.agree K` accepts against `Elem.put cell bs N x` (at `out`)
   or `x`. From `K` on, `y`'s bytes are `x`'s by the last premise, and so are those of
   `Elem.put cell bs N x` (`Elem.put_above`, by induction on `N`: each put ends by `K`). Two
   blocks that agree on every field, on the bytes below `K` and on the bytes from `K` on are
   equal (`Elem.agree_eq`), which gives `Elem.Out`'s two fields. `Elem.Out.of_run`:
   `Elem.Out.of_outBelow`, whose last premise is `Grid.start_reach_above`
   (MojoProof/Sem/Writes.lean): a block `x` of `m` is a block of `g.mem` (`Grid.start_blocks`)
   owned by no thread, so `z` has a block at its number with the same bytes from `x.size` on, and
   `K ≥ x.size`.
   `Kernel.replay_canaries`: for a canary `bs'`, `List.all` gives its replay's `bad`, and
   `Kernel.replay_block` (MojoProof/Sem/Replay.lean) at `f = Elem.put cell bs' T` refutes the
   relation, whose block `out` is `f` of `m`'s by `Elem.Out`'s first field; `Kernel.replay_block`
   is `Kernel.replay_sound` for the observation of block `out`'s bytes, to which `Kernel.Sound.map`
   carries the observation of the blocks.

11. `Elem.Only.log`: the new event is the access, which is to `out` only with its thread in `S`;
   the others are `m`'s. `Elem.Only.apply`: by cases on the effect; a load or a store that
   succeeds logs one access by `V`'s thread (for a store, through `Mem.store_inv`,
   MojoProof/Sem/Confluence.lean), so `Elem.Only.log`; a failing effect gives no memory.
   `Elem.safe_on`: let `ts` be the list of the threads of the accesses to `out` on the trace (a
   `filterMap`), all in `S` by `Elem.Only`, and `K` a number above `cell i + w` for every `i` of
   `ts` (induction on `ts`). Apply `racy_kept_of_cells` to the cells `cell i` for `i ∈ ts` and
   `K + w * i` otherwise. They are `w` apart: two of `ts` by the premise on `S`; one of `ts` and
   one not since `K + w * j ≥ K ≥ cell i + w`; two not of `ts` by `apart_mul`. An access to `out`
   is by a thread of `ts`, so it lies in that thread's cell (`Elem.Own`); the other two conjuncts
   are `Elem.Own`'s. `Kernel.sound_cells`: apply 3 with the invariant
   `P k me := Elem g.mem out w cell bs k me ∧ Elem.Only out S me`. `P 0 g.mem` is `Elem.zero` on
   the start's empty trace (`Grid.start_trace`), on which `Elem.Only` holds vacuously; the
   per-thread premise is the hypothesis. On `P N`, `Elem.safe_on` gives the trace facts, and the
   observation `some m'.blocks` meets `Elem.Out`: block `out` of `m'` is block `out` of `g.mem`
   with the puts (`Elem.cells`), which is block `out` of `m` (`Grid.start_blocks`) after the puts
   of the `g.threads.size = N` threads (`Grid.start_args`); every other block is `g.mem`'s
   (`Elem.rest`), hence `m`'s. The theorem proved this way is `Kernel.sound_cellsWith`, through
   `Kernel.sound_of_chainsWith` (3); `Kernel.sound_cells` is it at `false` (the loop disjunct by
   `Chain.with_iff`). `Kernel.sound_mapNWith`: apply `Kernel.sound_cellsWith`. For a thread `k`
   with frame `f` on a memory `m'` of `Elem k` and `Elem.Only`: `f.fn = fn` (`Grid.start_thread`),
   `k` is below the thread count (`Grid.start_args`), the context facts are `Grid.start_ctx`. For
   each position `i` of `bl`, parameter `i` is `ps[i]` and argument `i` is the struct of `bl[i]`
   (`List.getElem?_append_left`, `List.getElem?_map`); no earlier parameter is named `%i`, since
   parameter `j` is named `%j` (`take_names`); so register `%i` points to a block `q` of `g.mem`
   owned by thread `k` from which `T` loads as the struct (8, `Grid.start_buffer` with the codec).
   `q` is not `o`, which `g.mem` has with `m`'s owner `.all` (`Grid.start_blocks`), so the struct
   load moves from `g.mem` to `m'` (`Elem.load`). For each position `j` of `sc`, parameter and
   argument `n + j` are `sc[j]`'s (`List.getElem?_append_right`), so `%(n + j)` holds its value
   (`Grid.start_scalar`). The blocks of `m` other than `o` are blocks of `g.mem`
   (`Grid.start_blocks`) and of `m'` (`Elem.rest`; together `Elem.start_block`). Then the premise
   applies at `m₀ = g.mem`. `Launch.apart_xy`: `Launch.cell_apart` (MojoProof/Sem/Index.lean) on
   the threads of the subtype, at base 0 and width `w`, for two threads whose values differ
   (`Subtype.ext`).
12. `Kernel.sound_entry`: apply 3 with `P := I` at each admitted start `(g, c)`. `P 0 g.mem`:
   `g.mem` has every block of `m` (`Grid.start_blocks`) and an empty trace (`Grid.start_trace`).
   For a thread `k < g.threads.size` with frame `f` and memory `m'` of `I k`: `g.threads.size = N`
   (`Grid.start_args`); the thread is `⟨[f'], 0⟩` with `f'.fn = fn` (`Grid.start_thread`), so
   `f' = f`; the entry valuation's context has the program, identity and special registers
   (`Grid.start_ctx`), its function is `f.fn = fn`, its registers are `f.regs`, which hold the
   arguments (`Grid.start_scalar`, 8), and its memory is `m'`; the premise gives the disjunct. On
   `P N`, the premise on `I N`. `n.sound_loop`: `mojo_kernel` elaborates `Kernel.sound_entry` at
   `n.covers`, `n.coversChains`, the pointer bytes and the start by `n.starts` from `Mem.Closed`;
   the per-thread premise applies the clause's hypothesis to the register facts that
   `Kernel.sound_entry` provides (for each `scalars` or `pointers` parameter, its position, name,
   argument and attributes by `rfl` on the concrete function and `n.args`; `withAttrs` of a value
   with no `range`, `nonnull` or `align` attribute returns it, by `rfl`), then `n.loop` on
   `pre V` and `post V`, the second disjunct. The theorem proved this way is
   `Kernel.sound_entryWith`, through `Kernel.sound_of_chainsWith` (3) with `P := I g.mem`, the
   oracle by `Grid.start_ctx` and each `byval` parameter's register by `Grid.start_buffer` (8) at
   the frame `f`; `Kernel.sound_entry` is it at `false` with `I` constant in `m₀` (the loop
   disjunct by `Chain.with_iff`).
13. `Kernel.sound_mat`: apply `Kernel.sound_mapNWith` (11) at the structs `[p0, p1, p2]` of the
   blocks `[o, a, b]`, the scalars `p3`, `p4`, `p5` with the words of `m`, `n`, `K`, and `S` and
   `cell` as in 13 of the statements. Its parameter, `byval`, codec and `withAttrs` premises are
   the hypotheses (by cases on the three members of each list); `Mem.BytesIn` is
   `Mem.Closed.bytesIn`; `o` is owned by all threads by its `Mem.Buffer`; the cells are apart on
   `S` by `Launch.apart_xy` with `n ≤ sC`. For a thread with the facts of 11: registers `%0` to
   `%2` and the struct loads are its first premise at positions 0, 1 and 2, and `%3` to `%5` its
   second; `a` and `b` are blocks of `mem` other than `o`, so unchanged on `m'`, and their
   `Mem.Buffer`, `Mem.Fits` and `Mem.Holds` move to `m'` (`Mem.Buffer.of_block`,
   `Mem.Fits.of_block`, `Mem.Holds.of_block`); `o`'s come from `m₀`'s through `Elem`
   (`Elem.buffer`, `Elem.fits`). By cases on `S k`, `Hin` gives the second disjunct and `Hout` the
   first.

## Dependencies

`Block.sound_retR`, `coversPathI`, `WalkI`, `Walk`, `Exit.of_target`, `Valuation.entry`,
`Valuation.into`, `Valuation.lastI`, `Valuation.last` (Sym/Block.lean);
`SEff.run`, `vals` (Sym/Term.lean); `Runs`, `Grid.thread`, `Seq.start_sound_inv`
(Sym/Sched.lean); `LoopChain`, `Chain`, `RetLs`, `coversChains`, `Runs.of_chains`, and for the
loop instance `Chain.of_rounds`, `Edge.dec`, `Round.dec` (Sym/Loop.lean); `Grid.start_run`
(Sem/Closed.lean); `Grid.start_ctx` (Sem/Grid.lean); `Thread.start` (Sem/Thread.lean);
`racy_kept_of_cells`, `Apart` (Sem/Trace.lean, Sem/Buffer.lean).
For 6 and 7 also: `Grid.start_blocks` (Sem/Grid.lean), `Grid.start_trace`
(Sem/ScheduleOwned.lean); `Grid.start_args` (Sym/Start.lean), `Grid.start_ctx` (Sem/Grid.lean);
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
`Probe.stale`, `Probe.swap`, `Probe.zero`, `Probe.copy` (Sem/Replay.lean). For 11 also:
`Mem.store_inv` (Sem/Confluence.lean); `apart_mul` (Sem/Buffer.lean, from `apart_stride`);
`Ret.mono` (Sym/Kernel.lean); for its instance `kernelC` `Chain.of_rounds`, `Chain.last`
(Sym/Loop.lean), `Elem.apply_store`, `Elem.skip` (Sym/Kernel.lean). For 12 also:
`Grid.start_thread` (2), `Grid.start_scalar` (8); for `n.sound_loop`'s instance `kernelK`
`Mem.Closed.alloc` (Sem/Precond.lean). For the `contract` forms: `coversPathWith`, `RetWith`,
`Block.sound_retWith` (Sym/Path.lean); `coversChainsWith`, `RetLsWith`, `ChainWith`,
`Runs.of_retWith`, `Runs.of_chainsWith`, `Chain.with_iff` (Sym/Loop.lean); `summarizeC`
(Sym/Checker.lean); for the instance `kernelF` the tactic `kernel_check`, `mem_eta` and
`ret_storeWith` (MojoProofTest/KernelCells.lean). For `Launch.apart_xy`: `Launch.cell_apart`
(Sem/Index.lean). For `Elem.Out.of_run`: `Grid.start_reach_above` (Sem/Writes.lean). For 13:
`Mat.args`, `Mem.Buffer.of_block`, `Mem.Fits.of_block`, `Mem.Holds.of_block` (Sem/Precond.lean),
`Elem.buffer`, `Elem.fits` (Sym/Kernel.lean) and `Launch.apart_xy`.

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
  of `loopK.sound_loop` (12), which `mojo_kernel` generates for `cntK` with the `scalars` clause
  for `%n`, the `pointers` clause for `%p` and the loop clause; the start's facts come from
  `outC_closed` (`Mem.Closed`), and its per-thread premise, the precondition `preB`, from the
  registers `%n` and `%p` the generated premise provides and `outC`'s block in the thread's
  memory, with nothing of the start evaluated. The clause's obligations are closed by
  `invB_entry`, `invB_step` and `invB_exit`, which hold for every function with `cnt`'s blocks,
  every context whose program has `cntP`'s layout, and every bound `n ≤ 2 ^ 60`, block and
  trace. Their invariant `invB` is SymLoop's `invN` (stated for `cnt` itself) with the stores of
  the rounds so far on the trace, so that the postcondition gives the end's trace.
- The `loop` clause of `mojo_kernel` (docs/kernel.md) proves `n.loop` from its four obligations
  by `Chain.loop` at the clause's invariant and trip count, with `Chain.last` for each round and
  for the path out (`Ret.mono` from the postcondition to `Q`), and `n.sound_loop` by
  `Kernel.sound_entry` (12, the second disjunct) and `n.loop`. Its instance `cntk.loop`
  (MojoProofTest/KernelCmd.lean) holds for every valuation of `cntPre`, at every bound
  `n ≤ 2 ^ 60`; `cntk_three` applies it at `start 3`. `cntk.sound_loop` has no instance: `cnt`
  has no parameters, so no start meets `cntPre`. `loopK.sound_loop` (MojoProofTest/KernelLoop.lean)
  is the one for `cntK`. `n.sound_loop` gives no register fact for a `byval` buffer parameter
  (the start copies it into a new block, `Grid.start_buffer`). With a clause for each of several
  loops in sequence, `n.loop` is `Chain.loop` for each loop in turn: the next loop's run starts
  at every valuation of the invariant at the trip count, by that loop's exit obligation (the
  next clause's precondition, and the next postcondition implies this one's), and the last
  loop's path out ends with `Chain.last` and `Ret.mono`. Its instance `cnt2k.loop`
  (MojoProofTest/KernelLoop.lean) is SymLoop's `cnt2` from one valuation, `V2` (`%n = 2`);
  `cnt2k_retLs` applies it there.
  With the flag `contract` the clause checks its loops with `fmul contract` (`summarizeC`), its
  obligations are over `EdgeWith true`, `Valuation.roundWith true`, `RoundWith true` and
  `RetWith true`, `n.loop` is a `RetLsWith true` by `ChainWith.loop` and `ChainWith.last`
  (`RetWith.mono` for the path out), and `n.sound_loop` is by `Kernel.sound_entryWith` at
  `contract = true`, whose per-thread premise also takes an admitted address choice and oracle
  and gives `V.ctx.oracle = oracle k`. Its instance `kfK` (MojoProofTest/KernelContract.lean)
  is the one-loop kernel `kf` (three rounds of `%a = fadd contract (fmul contract %a, 2.0), 1.0`)
  on `L23`, six threads. Its clause's precondition `preF` is the start's facts of some thread
  `k` with a memory of `memF k` (some memory `m₀` with the caller's blocks, `Elem` from `m₀`
  after `k` threads, and `Elem.Only`), so it follows from the per-thread premise's facts for
  every admitted thread, and the tactic closes the four obligations at every valuation of
  `preF`, thread by thread (`interval_cases` on `k`, then evaluation in the kernel).
  `kfK_retLs` is `kfK.loop` at thread 0's valuation `VF`. `kernelK` is `kfK.sound_loop` with
  every premise closed: `I` is `memF`, `I 0` by `memF_zero`, the end by `memF_end`
  (`Elem.safe_on`), on `kfK.args 3 outF.2`, every address choice and the oracle `ω₁`, with the
  conclusion `Elem.Out` of `kernelF`. The generated statement is unchanged: `I` does not depend
  on the start's memory, and the existential over `m₀` in `memF` stands in for it. The
  open-goal test there checks the per-thread premise that `kernelK` proves.
  With the flag and no loop clause, for a loop-free kernel, `n.covers` is `coversEntryWith true`
  and `n.sound_of` is `Kernel.sound_of_chainsWith` at `contract = true`, `n.covers` and no
  sequence of loops (`coversChainsWith true P fn [] = true` by `rfl`), so each thread's run is a
  `RetWith true` along some path. Its instance `kgK` (MojoProofTest/KernelContract.lean) is the
  one-block kernel `kg` (`fadd contract (fmul contract 3.0, 2.0), 1.0`, stored). The flag is
  refused with `map2`, since `Kernel.sound_map2` has no form with the flag.
- `Kernel.sound_cells` (11) holds for every program, kernel, launch, admission, list of paths,
  list of sequences of loops, output block, cells and set `S` of threads that meet its premises;
  `Kernel.sound_entry` (12) for every program, kernel, launch, arguments, memory, admission,
  observation and predicate. In both, the per-thread `Ret` or `RetLs` is the caller's premise.
  The instance of `Kernel.sound_cells` (MojoProofTest/KernelCells.lean) is one program and one
  launch: `kc`, a hand-built `Func` (as SymLoop's `cnt`) whose threads count `%i` from 0 to `%n`
  and then store it to cell `%ctaid.x * %n + %tid.x` if `%tid.x < %n`, on `L23` (two blocks of
  three threads) with `%n = 2`, the memory `outM` (one global block of four `i32` cells), address
  choice `ch₀` and oracle `ω₀`. There the cells are apart on the storing threads (`apartC`) but
  not on all (`not_apartC`: thread 2, which skips, has thread 3's cell), so `Kernel.sound_elem`
  does not apply. Each thread's run is checked by evaluation in the kernel on a memory symbolic
  but for its output block (`kernel_check`). `Kernel.sound_cells` and `Kernel.sound_entry` take
  `coversChains` and `RetLs`, whose loops are checked without `contract` flags on float
  operations; `Kernel.sound_of_chainsWith` (3), `Kernel.sound_cellsWith` (11) and
  `Kernel.sound_entryWith` (12) hold for both flags, with the same generality.
- `kernelF` (MojoProofTest/KernelContract.lean) is an instance of `Kernel.sound_mapNWith` (11) at
  `contract = true`, so of `Kernel.sound_cellsWith`, with every premise closed. It is one program
  and one launch: `kf`, a hand-built `Func` whose threads run `%n` rounds of
  `%a = fadd contract (fmul contract %a, 2.0), 1.0` and store `%a` to cell
  `%ctaid.x * %n + %tid.x`, on `L23` with `%n = 3`, the memory `outF` (one global block of six
  `float` cells), address choice `ch₀` and the oracle `ω₁` (every `fadd contract` fuses). It has
  no `byval` struct and two scalars (`scF`). Each thread's run is proved for every context and
  frame with the start's facts and every memory of `Elem` and `Elem.Only`, by evaluation in the
  kernel one round at a time (`roundsF`, `chainF_of`). Its twin shows that the same proof at
  `contract = false` fails, since the checker without `fmul contract` refuses the loop
  (`chainF_refused`). The one instance of `Kernel.sound_mapNWith` with both a `byval` struct and
  a loop is the naive matmul kernel's (`NaiveKernel.correct`, through `Kernel.sound_mat` (13)),
  whose threads' runs are proved by hand (`NaiveIn.runIn`, `NaiveOut.runOut`): a load from a
  struct's copy whose contents are a hypothesis (not a literal memory) is not discharged by
  evaluation in the kernel, and `mojo_ret`, which proves such loads, proves only loop-free
  paths. The other instances with `byval` structs are `vector_addition`, `vector_multiply` and
  `vector_subtraction`, without loops, through `Kernel.sound_map2` and `Kernel.sound_mapN`, so
  through `Kernel.sound_mapNWith`.
- `Kernel.sound_eval` (5) holds for every program and kernel, at one launch, memory, address
  choice and oracle, where it reduces the theorem to Booleans the kernel decides. Its instance
  `kernel22` is `vector_addition` on 2 blocks of 2 threads with 3 elements, so threads 0 to 2 take
  the in-range path and thread 3 the other, on the paths `mojo_kernel` generates
  (MojoProof/Kernels/Vadd.lean).
- `Kernel.sound_elem` (6) holds for every elementwise kernel that meets its premises,
  `Kernel.sound_mapNWith` (11) for the family of kernels whose parameters are any number of
  `byval` buffer structs then any number of scalars, with or without `fmul contract`, with loops,
  cells apart on a set of threads and every admitted oracle, `Kernel.sound_mapN` (6) for its case
  of one count of any type without loops at one oracle, and `Kernel.sound_map2` (6) for the case
  of three structs and an `i32` count. In all of them the per-thread run is the caller's premise.
  The instances: `kernelF` of `Kernel.sound_mapNWith` (no struct, two scalars, a loop with
  `fmul contract`), and `Kernel.sound_map2` for `vector_addition`, `vector_multiply` and
  `vector_subtraction`, whose per-thread `Ret` the `map2` clause of `mojo_kernel` generates (the
  only clause that generates one for this family). `Kernel.sound_mapN` is proved from
  `Kernel.sound_mapNWith`, not from `Kernel.sound_elem`, whose statement is unchanged.
- `Kernel.sound_mat` (13) holds for the family of kernels whose parameters are three `byval`
  structs then three `i32` scalars, with or without `fmul contract`, at every launch valid with
  side 1 in `z`, every memory with its premises and every admission; the per-thread runs and the
  start are the caller's premises. The `mat` clause of `mojo_kernel` discharges every premise
  but the memory's, the launch's and the runs for one named kernel (`n.sound_mat`). Its instance
  is `NaiveSound.naive_sound`, through `naive.sound_mat`, the one program `naive` with `RunIn`
  and `RunOut` as premises, which `NaiveKernel.correct` closes with `NaiveIn.runIn` and
  `NaiveOut.runOut`.
- `Launch.apart_xy` (11) holds for every valid launch with side 1 in `z`, stride, bounds and
  width. Its instance `apart2x3` (MojoProofTest/KernelXY.lean) is one launch of 2 × 3 threads;
  its twin `apart2x3_twin` shows that the premise `n ≤ s` is needed (at stride 2, below the
  column bound 3, threads 4 and 1 share cell 8). `Elem.Out.of_run` (10) holds for every run from
  a start; its instance `out_run` is one run of `vector_addition` (the memory `mem5`, count 5,
  the launch `.one`, address choice `ch₀` and oracle `ω₀`).
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
two accesses; for (d) four launches, each with one of the four hypotheses on the launch false, a
race on each); and the canaries `canaries_vadd`,
`canaries_vmul` (`Kernel.replay_canaries`), whose controls are `correct23` and `correctV23`.

`Kernel.Sound`'s predicate `R` does not see the oracle. A result that names the oracle's numbers
(for `vector_addition`: cell `i` is `fadd`'s value at thread `i`'s oracle number) is stated for
every oracle `ω` with the admission `fun _ o => o = ω` and a predicate `R ω`.

## Plan: the naive matmul's kernel theorem

**Proved: the composition, from the threads' runs (MojoProofTest/NaiveSound.lean).** The theorem
`naive_sound` is `Kernel.Sound naive.prog naive.fn_0 L args mem (fun _ ω' => ω' = ω)
(fun m => some m.blocks) (Elem.Out mem bC (cell L) (bytes ω L K A B) N)` (`N` the thread count;
`S`, `cell`, `bytes`, `At`, `RunIn`, `RunOut` of MojoProofTest/NaiveSpec.lean), for one program
(`naive`) at every oracle `ω`, every valid launch `L` with side 1 in `z`, every `m`, `n ≤ 50257`
and `K ≤ 768` with the `i32` products in range, every blocks `bC`, `bA`, `bB`, tensors `A`,
`B` and memory `mem`. It is `Kernel.sound_mat` (13) at `contract := true`, the paths `[skipN]`,
the chains `[chainN]`, the struct type `NaiveSpec.T` and tail `NaiveSpec.z`, alignment 8,
binary32 at alignment 4 and the strides 768, 768 and 50257, with the start by `Grid.start_ok`
(`naive.starts`) and the register names by `naive.names`; `Kernel.sound_mat` is
`Kernel.sound_mapNWith` at the blocks `[bC, bA, bB]` and the scalars `%3`, `%4`, `%5`, with the
cells by `Launch.apart_xy`. Its body applies `naive.sound_mat`, the call the `mat` clause of
`mojo_kernel` generates (the next section), with `RunIn` and `RunOut` giving its two
obligations. Its premises, in the field order of `Mat.Pre`, and what gives each:

- `mem.Closed args`, `bA ≠ bC ∧ bB ≠ bC`, the three `Mem.Buffer`s, `Mem.Holds` of `A` and `B`,
  the bounds of `At.dims`, the three `Mem.Fits`: the caller's precondition, the projections of
  `Mat.Pre` (Sem/Precond.lean) at naive's layout, `binary32`, alignment 4 and the strides 768,
  768 and 50257. `Mat.pre_mem` proves `Mat.Pre` for all sizes at `Mat.mem`, a memory of the
  three blocks built by `Mem.alloc`.
- `RunIn ω L K bC bA bB A B`: a thread in bounds runs `chainN` to `ret`, for every launch,
  thread and memory; `NaiveIn.runIn` proves it for every oracle family, launch, sizes, blocks
  and tensors (docs/proofs/naive.md).
- `RunOut ω L K bC bA bB A B`: a thread out of bounds runs `skipN` to `ret`; `NaiveOut.runOut`
  proves it for every oracle family, launch, sizes, blocks and tensors (docs/proofs/obl.md).

In each of `Kernel.sound_mat`'s two per-thread premises `At` is built from the facts it gives
(inside `Kernel.sound_mat`, `Mem.Buffer.of_block`, `Mem.Fits.of_block`, `Mem.Holds.of_block` for
`A`'s and `B`'s blocks, `Elem.buffer` and `Elem.fits` for `C`'s, and the case `S L m n k` or not
picks the premise), with the register names `idx "j" = j` by evaluation; `At` needed no fact
beyond those. The read-off is proved on the observation
(`Kernel.Obs`) of every program whose kernel theorem has this `Elem.Out`: `naive_read` gives,
for `r < m`, `c < n` in the launch's window, the one thread `k` of row `r` and column `c`
(`Launch.cell_onto`, unique by `Launch.xy_inj`) whose 4 bytes at `(r * 50257 + c) * 4` encode
`dotLoop true (o (ω k)) +0 (pairs A B r c K)` (`Elem.put_read`), the caller's bytes outside the
cells of the threads in bounds (`Elem.put_out`) and the caller's other blocks. `naive_matmul`,
for every `K ≤ 768`, compares each cell with entry `(r, c)` of TorchLean's `Tensor.matmul` of
the first `K` columns of `A` and of `B`, transposed (`cols`, Sem/Matmul.lean): `NaNEq` at a
thread whose oracle fuses no round (`matmul_take_nanEq`), and within `dotBound` of the real
product when finite, for every oracle (`matmul_take_error`).

**Proved: the kernel theorem (MojoProofTest/NaiveKernel.lean).** `NaiveKernel.correct hL hz h`
is `naive_sound` with `runIn` and `runOut`: `naive` is sound for `Elem.Out` of its bytes at every
oracle family, valid launch with side 1 in `z`, sizes, blocks, tensors and memory `h : Mat.Pre`
at naive's constants, with no premise on the threads. `naive_read` and `naive_matmul` read its
cells. `sound12` is its instance at one block of 2 × 2 threads with `m = 1`, `n = 2` and
`K = 768` (threads 0 and 2 in bounds, 1 and 3 not, `in12`) on `mem12`, `Mat.mem` with `C`, `A`
and `B` at blocks 1, 2 and 3 (`pre12`, by `Mat.pre_mem`), for every `A`, `B` and oracle family.
It covers the one program `naive`, at every launch and memory of its family; it is
`naive_sound` at the two runs, so the call of `Kernel.sound_mat` in it is the one `mojo_kernel`
generates, and the `At` repack and the runs are by hand. Its corollaries, each
`naive_read` or `naive_matmul` at `correct` with the observed block from `Mat.Pre`, cover the same
family:

- `read_cover`: when the window covers `m × n` (`m ≤ grid.x * block.x`, `n ≤ grid.y * block.y`),
  every cell `(r, c)` with `r < m`, `c < n` holds the contracted dot loop of its one thread; the
  window premises of `naive_read` are gone. Its instance `read12` reads `sound12`'s two cells;
  its twin `keep11`, on the one-thread launch `L11` at the same memory (window 1 × 1, `n = 2`),
  shows by `naive_read`'s second clause, with no evaluation, that every byte of `C` from offset
  4 on, so `C[0, 1]`, is the caller's.
- `matmul_nanEq`: each cell in bounds and in the window is `NaNEq` to entry `(r, c)` of
  TorchLean's `Tensor.matmul` of the first `K ≤ 768` columns, at a thread whose oracle fuses no
  round (no `fadd` oracle number `2` modulo `3`). The equality needs that premise: a fused
  round rounds the product and the sum once, TorchLean's product rounds each. `nanEq_zero` is it
  at the oracle family `fun _ _ => 0`, which fuses nothing, with the premise discharged.
- `matmul_error`: each finite cell in bounds and in the window is within `dotBound` of binary32
  at `K` of the real product, at every oracle family.

**What remains.**

- The naive kernel's roadmap card: its L3 and L4 evidence from `NaiveKernel.matmul_nanEq` and
  `NaiveKernel.matmul_error`, and a GPU run for L1.
- The threads' runs of a matmul kernel are not generated. The `mat` clause (the next section)
  generates the call of `Kernel.sound_mat` (13) from the program, and `naive_sound`'s body
  applies it, but `naive_sound` is not a one-line corollary: `RunIn` and `RunOut`
  (MojoProofTest/NaiveSpec.lean) take the facts as one `NaiveSpec.At`, with the registers named
  `idx "j"`, so its body builds `At` from the facts in each of the two premises. The runs
  themselves are `NaiveIn.runIn` and `NaiveOut.runOut`, by hand.
- The `loop` clause on the naive loop: with the flag `contract` its obligations, `n.loop` and
  `n.sound_loop` are the `With true` forms, but the naive loop's obligations (an invariant over
  `dotLoop`'s accumulator, for every launch and every trip count `smax(K, 0)`) are not proved,
  and `n.sound_loop` gives no register fact for the three `byval` structs (the next section's
  clause takes the chains as arguments instead).

The rest of this section is the earlier plan of the whole proof. The kernel is the one function
`matmul_kernel_naive_float32_float32_float32_True_16_16826c8c`
(tests/corpus/mgemm/g_matmul_kernel_naive_float32_float32_float32_True_16_16826c8c.nvptx.ll). Its
parameters are three `byval` buffer structs `%0` (C), `%1` (A), `%2` (B) and the `i32` scalars
`%3 = m`, `%4 = n`, `%5 = K`. Thread `k` has row `r = L.index k .x` (`%24`, `ctaid.x * ntid.x +
tid.x`) and column `c = L.index k .y` (`%35`). If `r ≥ m` or `c ≥ n` (signed, `%43`) it returns
(`%44`, `%69`). Otherwise it runs the loop at header `%46` from `%47 = 0` and the accumulator
`%48 = 0.0` (the float constant of the edge from `%45`) while `%47 < smax(K, 0)` (`%16`); the
body `%52` loads `A[r * 768 + i]` and `B[c * 768 + i]` (`i32` arithmetic, then `sext`;
`!invariant.load`) and computes `%66 = fadd contract %48 (fmul contract a b)`; the exit `%67`
stores the accumulator at `C[r * 50257 + c]` (`i32` arithmetic, then `sext`).

**Statement.** For every valid launch `L` with side 1 in `z` (`L.grid .z = 1 ∧ L.block .z = 1`),
every `m`, `n ≤ 50257` and `K ≤ 768` with the `i32` products in range (`m * 50257 < 2 ^ 31`,
`m * 768 < 2 ^ 31`, `n * 768 < 2 ^ 31`), every oracle `ω`, and every caller's memory whose
pointer bytes are known, with distinct blocks for C (room for `m * 50257` cells), A (holding a
row-major `m × 768` tensor of binary32 words, `Block.Holds` at `rowMajor`) and B (an `n × 768`
tensor): the kernel on these arguments is `Kernel.Sound` at the admission `fun _ o => o = ω`
for the observation of the blocks and the predicate that every block but C's is the caller's,
and cell `(r, c)` of C, for `r < min m X` and `c < min n Y` (`X = L.grid .x * L.block .x`,
`Y = L.grid .y * L.block .y`, the launch's rows and columns), holds the word
`dotLoop true (o ω r c) +0 (matmulPairs A_K (B_K)ᵀ r c)`, where `A_K` and `B_K` are the first
`K` columns, `(B_K)ᵀ` is TorchLean's `Tensor.permute` of `B_K`, and `o ω r c j` is the pair of
the oracle numbers of thread `(r, c)` at positions `54 + 18 j` and `55 + 18 j` (the `fmul` and
`fadd` of round `j`). Every other cell of C is the caller's. Since `Kernel.Sound`'s predicate
does not see the oracle (see the end of Scope), the statement is one for each `ω`. Its
corollaries against TorchLean are Sem/Matmul.lean's: at an oracle that never fuses (no `fadd` number
`2` modulo 3), `matmul_cell_nanEq` and `matmul_cell_eq` give cell `(r, c)` equal to
`get2 (Tensor.matmul A_K (B_K)ᵀ) r c` up to NaNs; at every oracle, `matmul_cell_error` bounds a
finite cell's distance from the real matmul.

**Premises and the module whose theorem gives each.** Every name in this list is in the tree.
Of the proof after the list, steps 1, 2 and 5 and the cell fact are in Lean
(`Kernel.sound_of_chainsWith`, `Kernel.sound_cellsWith`, `Kernel.sound_mapNWith`,
`Launch.apart_xy`, and `naive_sound` and `naive_read` of MojoProofTest/NaiveSound.lean); steps 3
and 4 are the statements `RunOut` and `RunIn` of MojoProofTest/NaiveSpec.lean.

- The semantics (Sem/Index.lean, Sem/Dot.lean, Sem/Matmul.lean): the 2-D cells, `Launch.apart_xy` at
  `s = 50257`, `n ≤ 50257` and `w = 4` (from `Launch.cell_apart` at base 0), which gives
  `Apart (fun i : {i // S i} => cell i) 4` for `S k := k < N ∧ L.index k .x < m ∧ L.index k .y < n`
  and `cell k := (L.index k .x * 50257 + L.index k .y) * 4`; `Launch.index_ops` for the index words
  `%24` and `%35`; `rowMajor_two` and `Mem.load_get2` for the words the loads return; `get2_swap`
  and `matmulPairs_swap` for `Bᵀ`; `dotLoop_of_floatBin` and `cell_of_floatBin` for the accumulator
  after `K` rounds against `dotLoop true`; `matmul_cell_nanEq`, `matmul_cell_eq`,
  `matmul_cell_error` for the corollaries.
- The loop checker (Sym/Loop.lean, MojoProofTest/SymNaive.lean): the naive loop's `LoopSeg`
  `naiveL` with its rounds checked with the `fmul contract` flag (`RoundWith true`,
  `coversChainsWith true`), the header's `phi float` of `%45`'s constant `0.0`, and
  `Runs.of_chainsWith` for the thread's run; the `LoopChain` from the entry through `%45` to
  `naiveL`, its path out `%46 → %51 → %67 → %69`, and the skip path `%6 → %44 → %69`.
- The obligation prover (Sym/Obl.lean, Sym/Ops.lean): `mojo_obl` for the round obligations over
  the runtime trip count `smax(K, 0)` (a bound that is not a literal), and `mojo_ret`-style
  obligations for the index and address arithmetic of the entry block and the store.
- The kernel theorem (this file): `Kernel.sound_mapNWith` (11) at `contract = true`,
  `bl = [C, A, B]` and `sc` the three `i32` scalars, with the start facts.

**Proof, through `Kernel.sound_mapNWith`.**

1. A `contract` form of 3 and 11 (in Lean). `Kernel.sound_of_chainsWith` and
   `Kernel.sound_cellsWith` take `coversChainsWith contract` and `RetLsWith contract`, which the
   naive loop needs at `true`; `Kernel.sound_of_chains` and `Kernel.sound_cells` are their
   `false` cases by `Chain.with_iff`.
2. The start facts for three `byval` structs and three scalars (in Lean).
   `Kernel.sound_mapNWith`'s per-thread premise gives each struct's register pointing to a block
   other than C's from which the struct loads (`Grid.start_buffer`), the registers `%3` to `%5`
   holding `m`, `n`, `K` (`Grid.start_scalar`), the context (`Grid.start_ctx`) and the caller's
   blocks unchanged (`Grid.start_blocks`, `Elem.start_block`).
3. A thread outside `S` takes the skip path, the first disjunct: a `Ret` with no effect to C,
   `Elem.skip` at `bs k = none`, and `Elem.Only` kept since its only accesses are the loads of
   its struct copies (`Elem.Only.apply`).
4. A thread of `S` runs the `LoopChain`, the second disjunct, at the invariant of round `j`:
   `%47 = j`, `%48` the accumulator `acc j` of `dotLoop_of_floatBin`, and the memory the entry's
   with the loads of rounds `< j` logged (`Elem.apply_load`, `Elem.Only.apply`: the loads are to
   A's and B's blocks, not C's); trip count `K` (`smax(K, 0) = K` for `0 ≤ K`) by `mojo_obl`.
   The path out stores `acc K` at the thread's cell (`Elem.apply_store`, `Elem.Only.apply`) with
   `bs k` its encoding, and `cell_of_floatBin` names it `dotLoop true (o ω r c) +0 (matmulPairs …)`.
5. The end: `Kernel.sound_mapNWith` gives `Elem.Out` for the blocks. `Elem.put_read`, whose cells
   are apart only on the threads with bytes (those of `S`; two threads outside `S` may share a
   cell), reads cell `(r, c)` as `bs k` for the one thread `k` with `L.index k .x = r` and
   `L.index k .y = c` (Sem/Index.lean's `Launch.xy_inj` and `coord_linear`), and every other cell
   as the caller's.

What it does not cover: launches with side other than 1 in `z` (two threads then share a cell, as
the twin of `Launch.cell_apart` without side 1 in `z` shows), `K > 768` or `n > 50257` (the
strides are the corpus's constants), and the `i32` products out of range.

## The 2-D clause of `mojo_kernel` (`mat`)

The clause `mat` makes `mojo_kernel` state and prove the kernel theorem of a matmul kernel, with
the threads' runs as the two premises the user proves. It is the call of `Kernel.sound_mat`
(Sym/KernelMat.lean) with every premise that depends only on the program discharged. It is
implemented by `elabMat` (Sym/KernelCmd.lean, step 7 of the command), and its instance is the
naive matmul kernel.

**Syntax.** `mat paths chains` is the last clause group, after `contract`:

```lean
mojo_kernel naive := naive.prog naive.fn_0 reads bA := a1, bB := a2 writes bC := a0
  scalars m := a3, n := a4, K := a5 contract mat [skipN] [chainN]
```

- `paths : List (List (Nat × List Cond × Summary))` is the kernel's loop-free paths from the entry
  block, and `chains : List LoopChain` is its sequences of loops. Both are terms, as
  `Kernel.sound_mat` takes them.
- The clauses must be `reads` of `a1` and `a2`, `writes` of `a0`, and `scalars` of `a3`, `a4`
  and `a5` (the command's clause order is `reads`, `writes`, `scalars`). Their names are the
  binder names of the inputs, the output and the sizes `m`, `n`, `K`.
- `contract` is optional with `mat`. It sets `Kernel.sound_mat`'s flag, so the path checker and
  the runs are the variants with `fmul contract`. Without `mat`, `contract` still needs a loop
  clause.
- `mat` is not combined with `map2` or `loop`.

**The chains are arguments, not computed.** The loop clause computes the chains from the
header, but it needs its own obligations (`pre`, `inv`, `trips` and `post` over valuations), and
their shapes carry neither the memory facts of `Kernel.sound_mat`'s per-thread premises (`Elem`,
`Elem.Only`, the buffers) nor the 2-D index facts. The runs are proved over the given chains
instead. For naive, `NaiveIn.runIn` proves the run over `chainN` through
`NaiveThread.thread_run`. The command checks the given paths and chains with the path checker,
by evaluation, before it adds anything. So a wrong chain is refused, and it cannot make a
theorem hold.

**Checks, each an error naming the reason and `fn`; a refused command adds nothing:**

- `fn` elaborates to a constant;
- `P` has no globals;
- `fn` has six parameters. The first three are `byval` of one struct type `T`, a pointer of
  address space `sp` then a tail `u` with a zero value `z` (`Layout.zero`). The last three are
  `i32` without `byval`.
- parameter `j` has register name `j`;
- the clauses are as above, and their names are not binder names of the generated theorem;
- `paths` and `chains` are not empty, evaluated before the path checker;
- the path checker accepts the arguments: `coversEntryWith contract P fn paths` and
  `coversChainsWith contract P fn chains`, evaluated.

The messages begin `mojo_kernel: mat` and end with `fn`, for example `mojo_kernel: mat needs a
kernel of six parameters, three byval structs then three i32s; edgeF has 0`. The checker's cover
of an empty list is vacuous. With `mat [] chains` the theorem would still be true, since
`Kernel.sound_mat` is proved for every list, but its `Hout` would hold only at a launch with no
thread out of bounds. An empty `chains` would likewise give a `Hin` that holds only with no
thread in bounds. So the clause refuses an empty list (`mojo_kernel: mat needs a path; with no
paths the theorem covers only launches with no thread out of bounds (naive.fn_0)`, and the same
with a chain).

**What it generates.** It adds three theorems and no definition:

- `n.starts`: the start on `Mat.args z o a b m n K` succeeds for every launch, block numbers,
  sizes, memory closed for the arguments, address choice and oracle. It is
  `Sym.Grid.start_ok`, proved as the other clauses' `n.starts`.
- `n.names`: parameter `j` of `fn` has register name `j`, for each `j`. It is proved by
  `decide +kernel`.
- `n.sound_mat`: the kernel theorem. It is `Kernel.sound_mat` with these premises discharged:
  - the paths and the chains, each by `decide +kernel`;
  - the parameter list, by `rfl`, and the names, by `n.names`;
  - `byval` of `T` for the structs and none for the sizes, by `rfl`;
  - the codec of `T`, by `Layout.Codec.ptrArg` at `sp`;
  - the alignment `al'`, which is `P.layout.align T` evaluated, by `decide`;
  - `withAttrs` of the three words, by `rfl`;
  - the start, by `n.starts`.

No `n.covers` or `n.coversChains` is added, since a theorem with the chains' type can already
exist (for naive, `chainN_covers`). No `n.args`, `n.argTy` or `n.argTail` is added either: the
arguments are `Mat.args` at `z`, and `T` and `z` are written into the statement as literals.

**The generated statement, for naive.** Here `z` stands for the tail's zero value
`.agg [.agg [.agg [], .agg []], .agg [.agg [], .agg []]]`, and `T` for the struct type
`.struct [.ptr 0, .struct [.struct [.struct [], .struct []], .struct [.struct [], .struct []]]]`:

```lean
theorem naive.sound_mat {L : Launch} (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
    {bC bA bB m n K : Nat} {α : Type} [TorchLean.Storage α] {t : Ty} {enc : α → Val}
    {al sA sB sC : Nat} {x : TorchLean.Tensor α [m, sA]} {y : TorchLean.Tensor α [n, sB]}
    {mem : Mem} (hC : mem.Closed (Mat.args z bC bA bB m n K)) (hne : bA ≠ bC ∧ bB ≠ bC)
    (hbuf : mem.Buffer bA (m * sA * naive.prog.layout.size t) al false ∧
      mem.Buffer bB (n * sB * naive.prog.layout.size t) al false ∧
      mem.Buffer bC (m * sC * naive.prog.layout.size t) al true)
    (hx : mem.Holds naive.prog.layout bA t enc (rowMajor naive.prog.layout t 0) x)
    (hy : mem.Holds naive.prog.layout bB t enc (rowMajor naive.prog.layout t 0) y)
    (hsC : n ≤ sC)
    (hfit : mem.Fits naive.prog.layout bA (m * sA * naive.prog.layout.size t) ∧
      mem.Fits naive.prog.layout bB (n * sB * naive.prog.layout.size t) ∧
      mem.Fits naive.prog.layout bC (m * sC * naive.prog.layout.size t))
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {w : Nat}
    {bs : Nat → Option (List MemByte)}
    (Hin : ∀ ch oracle, adm ch oracle → ∀ k,
      (k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n) →
      ∀ c : Ctx, c.prog = naive.prog → c.env = L.env k → c.who = ⟨k, k / volume L.block⟩ →
      c.oracle = oracle k → ∀ (m₀ m' : Mem) (f : Frame), f.fn = naive.fn_0 → ∀ q0 q1 q2,
      -- the struct pointers in %0 to %2, their loads at alignment 8, the words of m, n, K in
      -- %3 to %5, the buffers on m', Elem after k threads and Elem.Only, as in Kernel.sound_mat
      … →
      ∃ C ∈ [chainN], RetLsWith true (fun me => Elem m₀ bC w cell bs (k + 1) me ∧
        Elem.Only bC S me) C.loops (Valuation.entry c 0 m' f) C.l C.ds C.S C.E)
    (Hout : ∀ ch oracle, adm ch oracle → ∀ k, k < volume L.grid * volume L.block → ¬ S k →
      … (the same facts) →
      ∃ ps ∈ [skipN], RetWith true (Valuation.entry c 0 m' f)
        (fun me => Elem m₀ bC w cell bs (k + 1) me ∧ Elem.Only bC S me) ps) :
    Kernel.Sound naive.prog naive.fn_0 L (Mat.args z bC bA bB m n K) mem adm
      (fun m => some m.blocks)
      (Elem.Out mem bC (fun k => (L.index k .x * sC + L.index k .y) * w) bs
        (volume L.grid * volume L.block))
```

In `Hin` and `Hout`, `cell` is `fun k => (L.index k .x * sC + L.index k .y) * w`, and `S` is the
threads in bounds, `fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
L.index k .y < n`. Both are written out in the statement. The statement covers this one kernel
at every launch valid with side 1 in `z`, every element type, encoder, alignment, strides,
tensors and memory with the memory premises, every admission, cell width and bytes.

**What is left to the user.** The user proves the threads' runs, `Hin` (a thread in bounds runs
a chain to `ret`) and `Hout` (a thread out of bounds takes a path to `ret`). They are premises
of `n.sound_mat`, in `Kernel.sound_mat`'s flat form. The memory premises are the caller's, and
`Mat.Pre` (Sem/Precond.lean) gives all of them.

**The instance.** MojoProofTest/NaiveSound.lean runs the command above.

- `naive_sound` keeps its statement. Its proof is `naive.sound_mat` at binary32, alignment 4
  and strides 768, 768, 50257, with `Hin` and `Hout` from its premises `hin` and `hout`
  (`NaiveSpec.RunIn` and `RunOut`), through the `NaiveSpec.At` repack of the facts.
- `NaiveKernel.correct` passes `NaiveIn.runIn` and `NaiveOut.runOut` for them, unchanged.
- The hand theorems `starts` and `names` of MojoProofTest/NaiveSound.lean are deleted. The
  generated `naive.names` has the statement of the hand `names`; the generated `naive.starts`
  has the hand `starts`'s, with the tail written as a literal where the hand one has
  `NaiveSpec.z`.
- `naive.sound_mat` has premises in flat form where `naive_sound` has `RunIn` and `RunOut`, so
  no two theorems have one statement (DUPTHM, by the elaborated type).

**Tests** (MojoProofTest/NaiveSound.lean, section `Clause`).

- An open-goal test (`#guard_msgs`) shows the two obligations, `case Hin` and `case Hout`, as
  the goals `naive.sound_mat` leaves at every launch and memory of `Mat.Pre` at naive's
  constants.
- Five refusals, each with its message:
  - `mat` on a kernel whose parameters are not three `byval` structs and three `i32`s (`edgeF`,
    of no parameters);
  - on `naive` with the reads in the other order (`bA := a2, bB := a1`);
  - on `naive` with a clause named `x`, a binder name of the generated theorem;
  - on `naive` with no paths (`mat [] [chainN]`) and with no chains (`mat [skipN] []`).

**What the clause does not do.**

- It does not generate the runs. `mojo_ret` proves only `Ret` along loop-free paths, at launches
  with side 1 in `y` and `z`, and its index facts are 1-D.
- The loop clause's tactic evaluates each thread of one concrete launch. It does not prove the
  invariant over `dotLoop`'s accumulator at every launch, which `NaiveIn.runIn` proves by hand.
- The `At` repack of the instance stays: `NaiveSpec.At` states the registers by `idx` and groups
  the facts differently.
