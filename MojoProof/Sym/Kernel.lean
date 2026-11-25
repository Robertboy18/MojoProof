import MojoProof.Sym.Sched
import MojoProof.Sem.Trace
import MojoProof.Sem.Precond
import MojoProof.Sem.ScheduleOwned
import MojoProof.Sym.Start
import MojoProof.Sem.FloatRel
import MojoProof.Sem.Replay
import MojoProof.Sym.Loop

/-!
# The kernel theorem from one covered path or sequence of loops per thread

docs/proofs/kernel.md. Every result here is for every program, kernel, launch, arguments, memory,
address choice and oracle.

* `Runs.of_ret`: for `Ret` (Sym/Path.lean: a path whose premises hold from a valuation, whose
  last block returns, and whose last block's effects succeed with a memory of a predicate `Q`), a
  thread with one frame, no `alloca` blocks, at the first block of a path the path checker accepts
  (`coversPathWith false`) and that is a `Ret` from the frame's entry valuation, runs to its end
  (`Runs`) leaving a memory of `Q` (`Runs.of_retWith` at `contract = false`).
* `Grid.start_thread`: every thread of the grid `Grid.start` gives has one frame of the kernel,
  at its first block's label, instruction 0, with no `alloca` blocks, and step count 0.
* What a thread's frame holds at the start. `Grid.start_arg`: each register a parameter names
  holds what `launchArgs` makes for its argument. `Grid.start_buffer`: for a `byval(T)` parameter
  whose argument has a codec, a pointer to a block owned by the thread from which the load of a
  `T` gives the argument (`Mem.load_byval`). `Grid.start_scalar`: for another parameter, its
  argument under its attributes.
* `coversEntry`: every path of a list starts at the kernel's first block and is accepted by the
  path checker with `phi`s from instruction 0 (a closed Boolean, decided by the kernel on a
  concrete program), so a kernel's paths may cross a join with `phi`s.
* `Kernel.sound_of_chains`: the kernel theorem (`Kernel.Sound`) from `coversEntry` of a list of
  paths and `coversChains` of a list of sequences of loops (MojoProof/Sym/Loop.lean), the start
  succeeding on every admitted choice, and, per start, an invariant `P` indexed by the number of
  threads done whose every thread `k`, from every memory of `P k`, either takes some path of the
  list that is a `Ret` to `P (k + 1)` or runs some sequence of loops of the list to `ret` with a
  memory of `P (k + 1)` (`RetLs`, each loop with an invariant and a trip count), and whose
  memories of `P N` have a trace that keeps the promise of `!invariant.load`, that has no data
  race under the premises of `racy_iff`, and an observation meeting `R` (`Seq.start_sound_inv`,
  `Runs.of_ret`, `Runs.of_chainsWith`). It covers kernels whose threads each run one path without a
  cycle or one sequence of loops to `ret`, with no call of a defined function and no collective
  call. `Kernel.sound_of_paths`: its case without loops (`chains = []`).
* `coversEntryWith`, `Kernel.sound_of_chainsWith`: the same with the flag `contract` of the path
  checker (`coversPathWith`, `coversChainsWith`, `RetWith`, `RetLsWith`): at `true` a block with
  `fmul contract` is summarized with its operands recorded (`summarizeC`). `coversEntry` and
  `Kernel.sound_of_chains` are its `false` case (`RetLs` is `RetLsWith false` by definition).
* `Kernel.sound_entryWith`, `Kernel.sound_entry`: the kernel theorem from an invariant `I m₀ k`
  over the start's memory `m₀`, with each thread's premise over every valuation whose context is
  the thread's (program, thread, environment, oracle) and whose registers hold the start's facts:
  each scalar parameter's argument under its attributes (`Grid.start_scalar`), and for each
  `byval(T)` parameter whose argument has a codec, a pointer to a block of `m₀` owned by the
  thread from which the load of a `T` gives the argument (`Grid.start_buffer`).
  `Kernel.sound_entry` is its `false` case with `I` not depending on `m₀`.
* `Ret.check`, `Ret.out`, `Ret.of_check`: a Boolean test of `Ret` and the memory the path
  leaves, with the theorem that a path it accepts is a `Ret` to that memory. `Ret.pick`: the first
  path of a list that `Ret.check` accepts. `Kernel.mems`, `Kernel.check`: the memories threads
  leave in turn, each along its picked path, and the test that every thread's picked path is
  accepted. `Kernel.sound_eval`: the kernel theorem at one address choice and oracle from
  `Kernel.check` and the final memory's trace and observation (`Kernel.sound_of_paths`), so that
  at a concrete launch, memory, choice and oracle the kernel decides every premise but the start's
  equation, the pointer bytes and the observation's.
* `Elem`: the invariant of an elementwise kernel, for an output block `out` and cells `cell i`
  of `w` bytes: block `out` holds the first `k` threads' stores in turn (`Elem.put`), every
  other block is unchanged, and every access of the trace is owned (`Elem.Own`). `Elem.zero`:
  a memory with an empty trace meets it from itself with no thread done. `Elem.succ`: a thread's
  store to its cell, with no other block changed and owned accesses, keeps it. `Elem.safe`: with
  cells `w` apart, the trace of every memory of `Elem` keeps the promise of `!invariant.load` and,
  under the premises of `racy_iff`, has no data race (`Elem.safe_on` with every thread in `S`).
* `Elem.log`: an owned access keeps `Elem`. `Elem.skip`: a thread that puts no bytes keeps it.
  `Elem.store`: a thread's store of its bytes to its cell keeps it (`Mem.store_inv`).
  `Elem.load`: a load from another block than `out` gives what it gives on `m₀` (by
  `Mem.load_of_block`, MojoProof/Sym/Loop.lean). `Elem.put_fields`: the puts change only bytes.
  `Elem.buffer`: the output block stays a `Mem.Buffer`.
* `Valuation.after_mem`: the memory after a block is what its effects make.
* `Elem.fits`: the output block still fits (`Mem.Fits`, Sem/Precond.lean).
  `Elem.apply_load`: a load effect outside the output block keeps `Elem`. `Elem.apply_store`: a
  thread's store effect of its bytes to its cell advances it.
* `Elem.Only`: every access to the output block is by a thread of a set `S`.
  `Elem.Only.log`, `Elem.Only.apply`: an access or an effect of a thread of `S` keeps it.
  `Elem.safe_on`: with the cells of the threads of `S` `w` apart (the others may overlap them),
  the trace of every memory of `Elem` and `Elem.Only` keeps the promise of `!invariant.load` and,
  under the premises of `racy_iff`, has no data race.
* `Elem.Out`, `Kernel.sound_cells`: the kernel theorem of an elementwise kernel at every
  admitted address choice and oracle, for the observation of the blocks: the output block holds
  every thread's bytes at its cell and the caller's other blocks are unchanged, from each
  thread's `Ret` of a covered path or `RetLs` of a covered sequence of loops from every memory of
  `Elem k` and `Elem.Only` to `Elem (k + 1)` and `Elem.Only` (`Kernel.sound_of_chains`).
  `Kernel.sound_cellsWith`: the same with the flag `contract` (`Kernel.sound_of_chainsWith`);
  `Kernel.sound_cells` is its `false` case. `Kernel.sound_elem`: its case with no loops, every
  thread in `S` and one oracle.
* `take_names`: parameters named by their positions name no register twice.
  `Kernel.sound_mapNWith`: `Kernel.sound_cellsWith` for a kernel whose parameters are `byval`
  structs of buffer pointers then any number of scalars, each named by its position, on an output
  block owned by all threads, with the start facts derived: each thread's premise is a
  `RetWith contract` or a `RetLsWith contract` from a frame whose registers point to its `byval`
  structs and hold the scalars, on a memory where the caller's other blocks are unchanged.
  `Kernel.sound_mapN`: its case without `fmul contract`, with no loops, one scalar, every thread
  in `S` and one oracle. `Kernel.sound_map2`: its case of three structs and an `i32` count on
  `Map2.args` and a caller's memory of `Map2.Pre` (Sem/Precond.lean), whose premise also has the
  buffers of `Map2.Pre`.
* `Elem.put_succ`, `Elem.put_of_none`: a thread's put. `Elem.Out.min`: `Elem.Out` after `M`
  threads whose bytes from thread `n` on are none holds after `min n M`. `Elem.put_read`: the
  bytes at the cell of a thread that has bytes after the puts, with the cells apart on the
  threads that have bytes. `Elem.put_out`: the bytes outside every thread's bytes are the block's.
* `Elem.agree`, `Elem.outBelow`, `Elem.Out.outBelow`: `Elem.Out` checked by evaluation at the
  blocks and offsets below bounds, which `Elem.Out` passes. `Elem.agree_eq`, `Elem.put_above`,
  `Elem.Out.of_outBelow`: the converse, when the memory has no block from the bound on, the
  bytes end by the bound of offsets, and the blocks agree from it on. `Elem.canaries`: the
  canaries of the output, five wrong outputs made from the right one by Sem/Replay.lean's
  probes, one definition for every kernel. `Elem.Out.of_run`: `Elem.Out` of the blocks at the
  end of a run from `Elem.outBelow`, when the caller's blocks are owned by no thread and end by
  the bound of offsets (`Grid.start_reach_above`). `Kernel.replay_canaries`: each is refuted,
  for every admission of the choice and oracle, when the trace-replay checker reports its
  violation (`Kernel.replay_block`).
* The corollaries of a binary float map, for every kernel whose theorem is `Kernel.Sound` for
  `Elem.Out` with `Elem.map2`'s bytes. `Kernel.Obs`: an observation of a complete run;
  `Kernel.Sound.obs`: it meets the relation. `Elem.map2`: the bytes thread `k` puts for
  operation `op` on the inputs' cells `k` (`Kernels.vadd.bytes` and `Kernels.vmul.bytes` are it
  by definition). `Elem.map2_none`, `Elem.encode_float`. `Elem.word`: the float at an output
  cell. `Elem.Out.map2_word`: it is the delivered result of `op`. `isNaN_eq_false_of_deliver`.
  `Kernel.map2_min`: `Elem.Out` after `min n T` threads, the threads that put bytes.
  `Kernel.map2_real`: a finite output float is `op` of the inputs' cells.
  `Kernel.map2_finEq`: two runs' output floats are equal up to `FinEq`. With it,
  `FinEq.eq_of_isFinite`: a finite output float is the same at every address choice and
  oracle.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **A thread along a covered path to its end.** For every program `P`, function `fn`, context
of `P`, path `ps` the path checker accepts from position `p0` (`coversPathWith false`) and
thread `t` with one frame `f` of `fn` at the path's first label and position `p0`, with no
`alloca` blocks, on memory `m`: if `ps` is a `Ret` to `Q` from `f`'s entry valuation, `t` runs to
its end (`Runs`) leaving a memory of `Q`: `Runs.of_retWith` at `contract = false`. -/
theorem Runs.of_ret {P : Program} {fn : Func} {c : Ctx} (hP : c.prog = P) {p0 : Nat}
    {ps : List (Nat × List Cond × Summary)} (hc : coversPathWith false P fn p0 ps = true)
    {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = [f]) (hfn : f.fn = fn)
    (hl : ps.head?.map (·.1) = some f.label) (hp : f.pc = p0) (ha : f.allocas = [])
    {Q : Mem → Prop} (hR : Ret (Valuation.entry c t.k m f) Q ps) : ∃ m', Runs c t m m' ∧ Q m' :=
  Runs.of_retWith (contract := false) hP hc ht hfn hl hp ha hR

/-- **The start's threads.** For every program, kernel `fn`, launch, arguments, memory, address
choice and oracle whose start gives grid `g`: every thread `k` of `g` (`Grid.thread`) has one
frame `f` of `fn` at the label of `fn`'s first block, position 0, with no `alloca` blocks, and
step count 0 (`Grid.start_run`, `Thread.start`). -/
theorem Grid.start_thread {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) {k : Nat} (hk : k < g.threads.size) :
    ∃ f, Grid.thread g k = ⟨[f], 0⟩ ∧ f.fn = fn ∧ fn.blocks[0]?.map (·.label) = some f.label ∧
      f.pc = 0 ∧ f.allocas = [] := by
  obtain ⟨-, as, t, ht, e⟩ := Grid.start_run h k _ (Array.getElem?_eq_getElem hk)
  have e' : g.threads[k]? = some (.run t) := by rw [Array.getElem?_eq_getElem hk, e]
  unfold Grid.thread
  rw [e']
  unfold Thread.start at ht
  cases hb : fn.blocks[0]? with
  | none => rw [hb] at ht; cases ht
  | some b =>
    rw [hb] at ht
    cases ht
    exact ⟨_, rfl, rfl, rfl, rfl, rfl⟩

/-- **A thread's argument at the start.** For every program, kernel `fn`, launch, argument values
`args`, memory, address choice `ch` and oracle whose start gives `(g, c)`, and every thread `k` of
`g` with frame `f`: for every position `i` whose parameter `p` names register `r` (no earlier
parameter naming `r`) and whose argument is `v`, register `r` of `f` holds a value `w` that is
what `launchArgs` makes for `p` and `v` in `g`'s memory (`LaunchArg`, with thread `k`'s address
choices; `Grid.start_args`, `Thread.start_regs`, `launchArgs_byval`). -/
theorem Grid.start_arg {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) {k : Nat} (hk : k < g.threads.size)
    {f : Frame} (hf : (Grid.thread g k).frames = [f]) {i : Nat} {p : Param} {v : Val} {r : Nat}
    (hp : fn.params[i]? = some p) (hv : args[i]? = some v) (hr : p.name = some r)
    (hu : (fn.params.take i).all (·.name != some r) = true) :
    ∃ w, f.regs r = some w ∧
      LaunchArg prog.layout g.mem k (fun j => ch (Nat.pair 0 (Nat.pair k j))) i p v w := by
  obtain ⟨m₁, m₂, ws, t, h1, h2, h3, h4⟩ := (Grid.start_args h).2 k hk
  obtain ⟨f', hf', hreg⟩ := Thread.start_regs h2
  obtain ⟨hlen, hA⟩ := launchArgs_byval h1
  have e : Grid.thread g k = t := by unfold Grid.thread; rw [h3]
  rw [e, hf', List.cons.injEq] at hf
  obtain rfl := hf.1
  have hi : i < ws.length := by
    rw [hlen, List.length_zip]
    have := (List.getElem?_eq_some_iff.1 hp).1
    have := (List.getElem?_eq_some_iff.1 hv).1
    omega
  exact ⟨ws[i], hreg i p _ r hp hr hu (List.getElem?_eq_getElem hi),
    (hA i p v _ hp hv (List.getElem?_eq_getElem hi)).mono h4⟩

/-- **A load from a `byval` copy.** For every layout, memory, block `b` that is `byvalBlock` of
bytes `bs` encoding `v` as a `T` that decode back to `v`, thread of the block's owner and
alignment `al` dividing `T`'s and `2 ^ w` (`w` the width of an address-space-0 pointer): the
load of a `T` from `⟨b, 0⟩` with alignment `al` gives `v`. -/
theorem _root_.MojoProof.Sem.Mem.load_byval {l : Layout} {m : Mem} {b n i : Nat}
    {ch : Nat → Nat} {t : Ty} {ro : Bool} {bs : List MemByte} {v : Val}
    (hb : m.blocks b = some (byvalBlock l n ch i t ro bs)) (he : l.encode t v = some bs)
    (hd : l.decode t bs = some v) {w : Who} (hw : w.thread = n) {al : Nat}
    (hal : al ∣ l.align t) (hal' : al ∣ 2 ^ (l.ptr 0).1) :
    m.load l w 0 t ⟨b, 0⟩ (some al) = .ok v := by
  have hlen := Layout.encode_length l t v bs he
  obtain ⟨ad, ha, hdv⟩ : ∃ ad, m.addr l 0 ⟨b, 0⟩ = .ok ad ∧ al ∣ ad := by
    by_cases hb0 : b = 0
    · exact ⟨0, by simp [Mem.addr, hb0, pure, Except.pure], Nat.dvd_zero al⟩
    · refine ⟨ch (2 * i) * l.align t % 2 ^ (l.ptr 0).1, ?_,
        (Nat.dvd_mod_iff hal').2 (Nat.dvd_trans hal (Nat.dvd_mul_left _ _))⟩
      have key : ∀ x : Nat, x < 2 ^ (l.ptr 0).1 → ((x : Int) % 2 ^ (l.ptr 0).1).toNat = x := by
        intro x hx
        have hx' : (x : Int) < 2 ^ (l.ptr 0).1 := by exact_mod_cast hx
        rw [Int.emod_eq_of_lt (by omega) hx']
        simp
      have e : m.addr l 0 ⟨b, 0⟩ = .ok ((((ch (2 * i) * l.align t % 2 ^ (l.ptr 0).1 : Nat) : Int)
          % 2 ^ (l.ptr 0).1).toNat) := by
        simp [Mem.addr, Mem.block, hb0, hb, byvalBlock, pure, Except.pure]
      rw [e, key _ (Nat.mod_lt _ (Nat.two_pow_pos _))]
  have hc := Mem.check_ok (n := l.stored t) (p := ⟨b, 0⟩) (al := some al) (w := w) hb rfl
    (by simp [byvalBlock, Owner.admits, hw]) (Int.le_refl 0)
    (by have := Layout.stored_le_size l t; simp only [byvalBlock]; omega) ha
    (fun k hk => by cases hk; exact Nat.mod_eq_zero_of_dvd hdv)
  refine Mem.load_of_check hc ?_
  show l.decode t ((List.range (l.stored t)).map fun j => bs.getD (0 + j) .undef) = some v
  rw [read_alloc bs (by omega), Layout.slice, List.drop_zero, ← hlen, List.take_length]
  exact hd

/-- **A `byval` argument at the start.** For every program, kernel, launch, argument values,
memory, address choice and oracle whose start gives `(g, c)`, thread `k` of `g` with frame `f`,
and position `i` whose parameter `p` is `byval(T)` and names register `r` (no earlier parameter
naming `r`), with argument `enc x` for a codec of `T` (`Layout.Codec`) and alignment `al`
dividing `T`'s and `2 ^ w`: register `r` of `f` points to offset 0 of a block `q` of `g`'s memory
owned by thread `k`, from which a load of a `T` with alignment `al` by thread `k` gives `enc x`. -/
theorem Grid.start_buffer {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) {k : Nat} (hk : k < g.threads.size)
    {f : Frame} (hf : (Grid.thread g k).frames = [f]) {i : Nat} {p : Param} {r : Nat} {t : Ty}
    (hp : fn.params[i]? = some p) (hr : p.name = some r)
    (hu : (fn.params.take i).all (·.name != some r) = true) (ht : p.byval? = some t)
    {α : Type} {enc : α → Val} (hc : prog.layout.Codec t enc) {x : α}
    (hv : args[i]? = some (enc x)) {al : Nat} (hal : al ∣ prog.layout.align t)
    (hal' : al ∣ 2 ^ (prog.layout.ptr 0).1) :
    ∃ q blk, f.regs r = some (.ptr ⟨q, 0⟩) ∧ g.mem.blocks q = some blk ∧ blk.owner = .thread k ∧
      g.mem.load prog.layout (c k).who 0 t ⟨q, 0⟩ (some al) = .ok (enc x) := by
  obtain ⟨w, hw, hA⟩ := Grid.start_arg h hk hf hp hv hr hu
  obtain ⟨q, bs, rfl, he, hb⟩ := hA.1 t ht
  obtain ⟨bs', he', -, hd⟩ := hc.round x
  rw [he, Option.some.injEq] at he'
  subst he'
  exact ⟨q, _, hw, hb, rfl, Mem.load_byval hb he hd (by rw [(Grid.start_ctx h k).2.1]) hal hal'⟩

/-- **A non-`byval` argument at the start.** For every program, kernel, launch, argument values,
memory, address choice and oracle whose start gives `(g, c)`, thread `k` of `g` with frame `f`,
and position `i` whose parameter `p` has no `byval` and names register `r` (no earlier parameter
naming `r`), with argument `v` that `p`'s attributes take to `w` on every memory: register `r` of
`f` is `w`. -/
theorem Grid.start_scalar {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) {k : Nat} (hk : k < g.threads.size)
    {f : Frame} (hf : (Grid.thread g k).frames = [f]) {i : Nat} {p : Param} {r : Nat} {v w : Val}
    (hp : fn.params[i]? = some p) (hr : p.name = some r)
    (hu : (fn.params.take i).all (·.name != some r) = true) (ht : p.byval? = none)
    (hv : args[i]? = some v) (hw : ∀ m', withAttrs prog.layout m' p.ty p.attrs v = .ok w) :
    f.regs r = some w := by
  obtain ⟨w', hw', hA⟩ := Grid.start_arg h hk hf hp hv hr hu
  obtain ⟨m', hm'⟩ := hA.2 ht
  rw [hw m', Except.ok.injEq] at hm'
  rw [hw', hm']

/-- **The entry check, with or without `fmul contract`**: every path of `paths` starts at the
label of `fn`'s first block and is accepted by `coversPathWith contract` from position 0. -/
def coversEntryWith (contract : Bool) (P : Program) (fn : Func)
    (paths : List (List (Nat × List Cond × Summary))) : Bool :=
  paths.all fun ps => decide (ps.head?.map (·.1) = fn.blocks[0]?.map (·.label)) &&
    coversPathWith contract P fn 0 ps

/-- Every path of `paths` starts at the label of `fn`'s first block and is accepted by the path
checker from position 0: `coversEntryWith` without `fmul contract`. -/
def coversEntry (P : Program) (fn : Func) (paths : List (List (Nat × List Cond × Summary))) :
    Bool :=
  coversEntryWith false P fn paths

/-- **Kernel soundness from one covered path or sequence of loops per thread, with or without
`fmul contract`.** For every flag `contract`, program `prog`, kernel `fn`, launch `L`, arguments,
caller's memory `m` whose pointer bytes are known (`Mem.BytesIn`), admission `adm` of address
choices and oracles, observation `obs` that reads only the blocks, predicate `R`, list `paths` of
paths that each start at `fn`'s first block and are accepted from position 0
(`coversEntryWith contract`), and list `chains` of sequences of loops that each start at `fn`'s
first block and whose paths are accepted (`coversChainsWith contract`): if the start succeeds on
every admitted choice and oracle, and for each such start, with grid `g` and contexts `c`, there is
a family `P` of memory predicates indexed by the number of threads done with `P 0 g.mem`, such that
each thread `k` (`Grid.thread`, one frame `f`), from every memory `m'` of `P k`, either takes some
path of `paths` that is a `RetWith contract` to `P (k + 1)` from `f`'s entry valuation on `m'`, or
runs some sequence `C` of `chains` from that valuation through its loops to `ret` with a memory of
`P (k + 1)` (`RetLsWith contract`), and every memory of `P N` (`N` threads) has a trace that
keeps the promise of `!invariant.load` (the core's `GPUProof.kept` at `sig`), that has no data
race (the core's `racy` at `sig`) when it has the premises of `racy_iff`, and an observation
`y` with `R y`, then the kernel is sound (`Kernel.Sound`). With `contract` the blocks may have
`fmul contract` and `fadd contract` (each thread's fused operands in its valuation's record).
`Seq.start_sound_inv`, `Grid.start_thread`, `Runs.of_retWith` for a path,
`Runs.of_chainsWith` for a sequence of loops. -/
theorem Kernel.sound_of_chainsWith {contract : Bool} {prog : Program} {fn : Func} {L : Launch}
    {args : List Val} {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type}
    {obs : Mem → Option β} {R : β → Prop} {paths : List (List (Nat × List Cond × Summary))}
    {chains : List LoopChain} (hc : coversEntryWith contract prog fn paths = true)
    (hcL : coversChainsWith contract prog fn chains = true) (hm : m.BytesIn m.Known)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (H : ∀ ch oracle g c, adm ch oracle → Grid.start prog fn L args m ch oracle = .ok (g, c) →
      ∃ P : Nat → Mem → Prop, P 0 g.mem ∧
        (∀ k < g.threads.size, ∀ m' f, P k m' → (Grid.thread g k).frames = [f] →
          (∃ ps ∈ paths, RetWith contract (Valuation.entry (c k) 0 m' f) (P (k + 1)) ps) ∨
            ∃ C ∈ chains, RetLsWith contract (P (k + 1)) C.loops (Valuation.entry (c k) 0 m' f)
              C.l C.ds C.S C.E) ∧
        (∀ m', P g.threads.size m' →
          ((∀ a, Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
              a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
            GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false) ∧
          GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true ∧
          ∃ y, obs m' = some y ∧ R y)) :
    Kernel.Sound prog fn L args m adm obs R := by
  intro ch oracle ha
  obtain ⟨g, c, h⟩ := hs ch oracle ha
  obtain ⟨P, h0, hk, hb⟩ := H ch oracle g c ha h
  refine ⟨g, c, h, Seq.start_sound_inv h hm hO h0 (fun k hk' m' hm' => ?_)
    (fun m' hm' => ⟨(hb m' hm').1, (hb m' hm').2.1⟩) fun m' hm' => (hb m' hm').2.2⟩
  obtain ⟨f, ht, hfn, hl, hp, ha'⟩ := Grid.start_thread h hk'
  rw [ht]
  rcases hk k hk' m' f hm' (by rw [ht]) with ⟨ps, hps, hR⟩ | hR
  · have hcp := List.all_eq_true.1 hc ps hps
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hcp
    exact Runs.of_retWith (t := ⟨[f], 0⟩) (Grid.start_ctx h k).1 hcp.2 rfl hfn (hcp.1.trans hl)
      hp ha' hR
  · exact Runs.of_chainsWith (t := ⟨[f], 0⟩) (Grid.start_ctx h k).1 hcL rfl hfn hl hp ha' hR

/-- **Kernel soundness from one covered path or sequence of loops per thread.** For every
program `prog`, kernel `fn`, launch `L`, arguments, caller's memory `m` whose pointer bytes are
known (`Mem.BytesIn`), admission `adm` of address choices and oracles, observation `obs` that
reads only the blocks, predicate `R`, list `paths` of paths that each start at `fn`'s first block
and are accepted from position 0 (`coversEntry`), and list `chains` of sequences of loops that
each start at `fn`'s first block and whose paths are accepted (`coversChains`: the path into the
first loop from position 0, each round with its nested loops, each path out): if the start
succeeds on every admitted choice and oracle, and for each such start, with grid `g` and contexts
`c`, there is a family `P` of memory predicates indexed by the number of threads done with
`P 0 g.mem`, such that each thread `k` (`Grid.thread`, one frame `f`), from every memory `m'` of
`P k`, either takes some path of `paths` that is a `Ret` to `P (k + 1)` from `f`'s entry
valuation on `m'`, or runs some sequence `C` of `chains` from that valuation through its loops to
`ret` with a memory of `P (k + 1)` (`RetLs`: for each loop an invariant indexed by the round and a
trip count), and every memory of `P N` (`N` threads) has a trace that keeps the promise of
`!invariant.load` (the core's `GPUProof.kept` at `sig`), that has no data race (the core's `racy`
at `sig`) when it has the premises of `racy_iff`, and an observation `y` with `R y`, then the
kernel is sound (`Kernel.Sound`). `Kernel.sound_of_chainsWith` without `fmul contract`. -/
theorem Kernel.sound_of_chains {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
    {R : β → Prop} {paths : List (List (Nat × List Cond × Summary))} {chains : List LoopChain}
    (hc : coversEntry prog fn paths = true) (hcL : coversChains prog fn chains = true)
    (hm : m.BytesIn m.Known)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (H : ∀ ch oracle g c, adm ch oracle → Grid.start prog fn L args m ch oracle = .ok (g, c) →
      ∃ P : Nat → Mem → Prop, P 0 g.mem ∧
        (∀ k < g.threads.size, ∀ m' f, P k m' → (Grid.thread g k).frames = [f] →
          (∃ ps ∈ paths, Ret (Valuation.entry (c k) 0 m' f) (P (k + 1)) ps) ∨
            ∃ C ∈ chains, RetLs (P (k + 1)) C.loops (Valuation.entry (c k) 0 m' f) C.l C.ds
              C.S C.E) ∧
        (∀ m', P g.threads.size m' →
          ((∀ a, Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
              a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
            GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false) ∧
          GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true ∧
          ∃ y, obs m' = some y ∧ R y)) :
    Kernel.Sound prog fn L args m adm obs R :=
  Kernel.sound_of_chainsWith (contract := false) hc hcL hm hs hO H

/-- **Kernel soundness from each thread's entry facts, with or without `fmul contract`.** For
every flag `contract`, program `prog`, kernel `fn`, launch `L`, arguments `args`, caller's memory
`m` whose pointer bytes are known (`Mem.BytesIn`), admission `adm`, observation `obs` that reads
only the blocks, predicate `R`, list `paths` of paths from the entry (`coversEntryWith contract`),
list `chains` of sequences of loops from the entry (`coversChainsWith contract`) and family `I`
of memory predicates indexed by the start's memory `m₀` and the number of threads done: if the
start succeeds on every admitted choice and oracle, `I m₀ 0 m₀` holds of every memory `m₀` that
has `m`'s blocks and an empty trace, and, for every admitted choice and oracle `oracle` and every
memory `m₀` that has `m`'s blocks, each thread `k` of the launch (`k < volume L.grid * volume
L.block`), from every valuation `V` with the start's facts and a memory of `I m₀ k`, either takes
some path of `paths` that is a `RetWith contract` to `I m₀ (k + 1)` or runs some sequence of
`chains` to `ret` with a memory of `I m₀ (k + 1)` (`RetLsWith contract`), and every memory of
`I m₀` after all threads has a trace that keeps the promise of `!invariant.load`, that has no
data race when it has the premises of `racy_iff`, and an observation `y` with `R y`, then the
kernel is sound (`Kernel.Sound`).
The start's facts: `V`'s program is `prog`, its identity `⟨k, k / volume L.block⟩`, its special
registers `L.env k`, its oracle `oracle k`, its function `fn`; each named parameter with no
`byval` and no earlier parameter of its name holds in its register the value that its attributes
make of its argument on every memory; and each named `byval(t)` parameter with no earlier
parameter of its name, whose argument is `enc x` for a codec `enc` of `t` (`Layout.Codec`), holds
in its register a pointer to offset 0 of a block of `m₀` owned by thread `k` from which a load of
a `t` at every alignment `al` dividing `t`'s and the generic space's gives `enc x`.
`Kernel.sound_of_chainsWith` with `P := I g.mem`: the start's memory has `m`'s blocks
(`Grid.start_blocks`) and an empty trace (`Grid.start_trace`), and each thread's frame and context
have the facts (`Grid.start_thread`, `Grid.start_ctx`, `Grid.start_scalar`,
`Grid.start_buffer`). -/
theorem Kernel.sound_entryWith {contract : Bool} {prog : Program} {fn : Func} {L : Launch}
    {args : List Val} {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type}
    {obs : Mem → Option β} {R : β → Prop} {paths : List (List (Nat × List Cond × Summary))}
    {chains : List LoopChain} (hc : coversEntryWith contract prog fn paths = true)
    (hcL : coversChainsWith contract prog fn chains = true) (hm : m.BytesIn m.Known)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') (I : Mem → Nat → Mem → Prop)
    (h0 : ∀ m₀ : Mem, (∀ b x, m.blocks b = some x → m₀.blocks b = some x) → m₀.trace = [] →
      I m₀ 0 m₀)
    (H : ∀ ch oracle, adm ch oracle → ∀ m₀ : Mem,
      (∀ b x, m.blocks b = some x → m₀.blocks b = some x) →
      ∀ k < volume L.grid * volume L.block, ∀ V : Valuation, V.ctx.prog = prog →
      V.ctx.who = ⟨k, k / volume L.block⟩ → V.ctx.env = L.env k → V.ctx.oracle = oracle k →
      V.fn = fn →
      (∀ i p v w r, fn.params[i]? = some p → args[i]? = some v → p.name = some r →
        (fn.params.take i).all (·.name != some r) = true → p.byval? = none →
        (∀ m', withAttrs prog.layout m' p.ty p.attrs v = .ok w) → V.regs r = some w) →
      (∀ i p r t, fn.params[i]? = some p → p.name = some r →
        (fn.params.take i).all (·.name != some r) = true → p.byval? = some t →
        ∀ (α : Type) (enc : α → Val), prog.layout.Codec t enc → ∀ x al,
        args[i]? = some (enc x) → al ∣ prog.layout.align t → al ∣ 2 ^ (prog.layout.ptr 0).1 →
        ∃ q blk, V.regs r = some (.ptr ⟨q, 0⟩) ∧ m₀.blocks q = some blk ∧
          blk.owner = .thread k ∧
          m₀.load prog.layout V.ctx.who 0 t ⟨q, 0⟩ (some al) = .ok (enc x)) →
      I m₀ k V.mem →
      (∃ ps ∈ paths, RetWith contract V (I m₀ (k + 1)) ps) ∨
        ∃ C ∈ chains, RetLsWith contract (I m₀ (k + 1)) C.loops V C.l C.ds C.S C.E)
    (hend : ∀ m₀ m', I m₀ (volume L.grid * volume L.block) m' →
      ((∀ a, Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
          a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
        GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false) ∧
      GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true ∧
        ∃ y, obs m' = some y ∧ R y) :
    Kernel.Sound prog fn L args m adm obs R :=
  Kernel.sound_of_chainsWith hc hcL hm hs hO fun ch oracle g c ha h => by
    have hn := (Grid.start_args h).1
    refine ⟨I g.mem, h0 _ (fun _ _ => Grid.start_blocks h) (Grid.start_trace h),
      fun k hk m' f hm' hf => ?_, fun m' h' => hend g.mem m' (hn ▸ h')⟩
    obtain ⟨f', ht, hfn, -⟩ := Grid.start_thread h hk
    obtain rfl : f' = f := by rw [ht] at hf; exact (List.cons.inj hf).1
    obtain ⟨hp, hw, he, ho⟩ := Grid.start_ctx h k
    exact H ch oracle ha g.mem (fun _ _ => Grid.start_blocks h) k (hn ▸ hk) _ hp hw he ho hfn
      (fun _ _ _ _ _ hp hv hr hu hb hw => Grid.start_scalar h hk hf hp hr hu hb hv hw)
      (fun _ _ _ _ hp hr hu hb _ _ hcod _ _ hv hal hal' =>
        Grid.start_buffer h hk hf hp hr hu hb hcod hv hal hal') hm'

/-- **Kernel soundness from each thread's entry facts.** For every program `prog`, kernel `fn`,
launch `L`, arguments `args`, caller's memory `m` whose pointer bytes are known (`Mem.BytesIn`),
admission `adm`, observation `obs` that reads only the blocks, predicate `R`, list `paths` of
paths from the entry (`coversEntry`), list `chains` of sequences of loops from the entry
(`coversChains`) and family `I` of memory predicates indexed by the number of threads done: if
the start succeeds on every admitted choice and oracle, `I 0` holds of every memory that has
`m`'s blocks and an empty trace, each thread `k` of the launch (`k < volume L.grid * volume
L.block`) from every valuation `V` with the start's facts (`V`'s program is `prog`, its identity
`⟨k, k / volume L.block⟩`, its special registers `L.env k`, its function `fn`, and each named
parameter with no `byval` and no earlier parameter of its name holds in its register the value
that its attributes make of its argument on every memory) and a memory of `I k` either takes some
path of `paths` that is a `Ret` to `I (k + 1)` or runs some sequence of `chains` to `ret` with a
memory of `I (k + 1)` (`RetLs`), and every memory of `I` after all threads has a trace that
keeps the promise of `!invariant.load`, that has no data race when it has the premises of
`racy_iff`, and an observation `y` with `R y`, then
the kernel is sound (`Kernel.Sound`). `Kernel.sound_entryWith` without `fmul contract`, with `I`
not depending on the start's memory. -/
theorem Kernel.sound_entry {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
    {R : β → Prop} {paths : List (List (Nat × List Cond × Summary))} {chains : List LoopChain}
    (hc : coversEntry prog fn paths = true) (hcL : coversChains prog fn chains = true)
    (hm : m.BytesIn m.Known)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m') (I : Nat → Mem → Prop)
    (h0 : ∀ m₀ : Mem, (∀ b x, m.blocks b = some x → m₀.blocks b = some x) → m₀.trace = [] →
      I 0 m₀)
    (H : ∀ k < volume L.grid * volume L.block, ∀ V : Valuation, V.ctx.prog = prog →
      V.ctx.who = ⟨k, k / volume L.block⟩ → V.ctx.env = L.env k → V.fn = fn →
      (∀ i p v w r, fn.params[i]? = some p → args[i]? = some v → p.name = some r →
        (fn.params.take i).all (·.name != some r) = true → p.byval? = none →
        (∀ m', withAttrs prog.layout m' p.ty p.attrs v = .ok w) → V.regs r = some w) →
      I k V.mem →
      (∃ ps ∈ paths, Ret V (I (k + 1)) ps) ∨ ∃ C ∈ chains, RetLs (I (k + 1)) C.loops V C.l C.ds
        C.S C.E)
    (hend : ∀ m', I (volume L.grid * volume L.block) m' →
      ((∀ a, Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
          a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
        GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false) ∧
      GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true ∧
        ∃ y, obs m' = some y ∧ R y) :
    Kernel.Sound prog fn L args m adm obs R :=
  Kernel.sound_entryWith (contract := false) hc hcL hm hs hO (fun _ => I) h0
    (fun _ _ _ _ _ k hk V hp hw he _ hfn hr _ hI => H k hk V hp hw he hfn hr hI) fun _ => hend

/-- **Kernel soundness from one covered path per thread**: `Kernel.sound_of_chains` with no
sequence of loops (`chains = []`), for every program, kernel, launch, arguments, memory whose
pointer bytes are known, admission, observation that reads only the blocks, predicate and list
of paths from the entry (`coversEntry`), when each thread `k`, from every memory of `P k`, takes
some path of `paths` that is a `Ret` to `P (k + 1)`. -/
theorem Kernel.sound_of_paths {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {β : Type} {obs : Mem → Option β}
    {R : β → Prop} {paths : List (List (Nat × List Cond × Summary))}
    (hc : coversEntry prog fn paths = true) (hm : m.BytesIn m.Known)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (H : ∀ ch oracle g c, adm ch oracle → Grid.start prog fn L args m ch oracle = .ok (g, c) →
      ∃ P : Nat → Mem → Prop, P 0 g.mem ∧
        (∀ k < g.threads.size, ∀ m' f, P k m' → (Grid.thread g k).frames = [f] →
          ∃ ps ∈ paths, Ret (Valuation.entry (c k) 0 m' f) (P (k + 1)) ps) ∧
        (∀ m', P g.threads.size m' →
          ((∀ a, Event.access a ∈ m'.trace → a.who.thread < volume L.grid * volume L.block ∧
              a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m'.trace.reverse →
            GPUProof.racy sig (m'.trace.map (Event.toCore L)).reverse = false) ∧
          GPUProof.kept sig (m'.trace.map (Event.toCore L)).reverse = true ∧
          ∃ y, obs m' = some y ∧ R y)) :
    Kernel.Sound prog fn L args m adm obs R :=
  Kernel.sound_of_chains (chains := []) hc rfl hm hs hO fun ch ω g c ha h => (H ch ω g c ha h).imp
    fun _ ⟨h0, hk, hb⟩ => ⟨h0, fun k hk' m' f hm' => Or.inl ∘ hk k hk' m' f hm', hb⟩

/-- The memory the last block of path `ps` leaves from `V` (`SEff.run` at its entry valuation,
`Valuation.lastWith false`), `d` if the path is empty or the effects fault. -/
def Ret.out (V : Valuation) (d : Mem) : List (Nat × List Cond × Summary) → Mem
  | [] => d
  | (l, _, S) :: ps =>
    match SEff.run (V.lastWith false l S ps).1
        (vals (V.lastWith false l S ps).1 (V.lastWith false l S ps).2.2.nodes)
        (V.lastWith false l S ps).2.2.effs with
    | .ok me => me
    | .error _ => d

/-- Whether path `ps` is a `Ret` from `V`: its premises hold (`WalkWith false`, decided), its last
block returns, and its last block's effects succeed. The kernel evaluates it on a concrete
valuation. -/
def Ret.check (V : Valuation) : List (Nat × List Cond × Summary) → Bool
  | [] => false
  | (l, ds, S) :: ps => decide (WalkWith false V ((l, ds, S) :: ps)) &&
      decide ((V.lastWith false l S ps).2.2.exit = .ret) &&
      match SEff.run (V.lastWith false l S ps).1
          (vals (V.lastWith false l S ps).1 (V.lastWith false l S ps).2.2.nodes)
          (V.lastWith false l S ps).2.2.effs with
      | .ok _ => true
      | .error _ => false

/-- A path that `Ret.check` accepts is a `Ret` to the memory `Ret.out` gives, for every
valuation, path and default memory. -/
theorem Ret.of_check {V : Valuation} {d : Mem} :
    ∀ {ps : List (Nat × List Cond × Summary)}, Ret.check V ps = true → Ret V (· = Ret.out V d ps) ps
  | [], h => by cases h
  | (l, ds, S) :: ps, h => by
    simp only [Ret.check, Bool.and_eq_true, decide_eq_true_eq] at h
    obtain ⟨⟨hW, hx⟩, he⟩ := h
    refine ⟨hW, hx, ?_⟩
    simp only [Ret.out]
    split at he
    · rename_i me hme
      exact ⟨me, hme, by simp only⟩
    · cases he

/-- **`RetWith contract` is monotone in its predicate**: for every flag, valuation `V`, predicates
`Q`, `Q'` with `Q'` holding of every memory of `Q`, and path, a path that is a `RetWith contract`
from `V` to `Q` is one to `Q'`. -/
theorem RetWith.mono {contract : Bool} {V : Valuation} {Q Q' : Mem → Prop}
    (h : ∀ m, Q m → Q' m) :
    ∀ {ps : List (Nat × List Cond × Summary)}, RetWith contract V Q ps → RetWith contract V Q' ps
  | [], hR => (hR : False).elim
  | (_, _, _) :: _, hR => by
    obtain ⟨hW, hx, me, hr, hQ⟩ := hR
    exact ⟨hW, hx, me, hr, h me hQ⟩

/-- **`Ret` is monotone in its predicate**: a path that is a `Ret` from `V` to `Q` is one to every
`Q'` that holds of every memory of `Q`, for every valuation, predicates and path
(`RetWith.mono` without `fmul contract`). -/
theorem Ret.mono {V : Valuation} {Q Q' : Mem → Prop} (h : ∀ m, Q m → Q' m) :
    ∀ {ps : List (Nat × List Cond × Summary)}, Ret V Q ps → Ret V Q' ps :=
  fun {_} hR => RetWith.mono (contract := false) h hR

/-- The first path of `paths` that `Ret.check` accepts from `V` (the empty path if none). -/
def Ret.pick (V : Valuation) (paths : List (List (Nat × List Cond × Summary))) :
    List (Nat × List Cond × Summary) :=
  (paths.find? (Ret.check V)).getD []

/-- The memory threads `0` to `k - 1` of grid `g` leave when they run in turn from `g.mem`, each
with one frame `f` along the path `Ret.pick` gives from its entry valuation (`Ret.out`); a thread
without exactly one frame leaves the memory unchanged. -/
def Kernel.mems (g : Grid) (c : Nat → Ctx) (paths : List (List (Nat × List Cond × Summary))) :
    Nat → Mem
  | 0 => g.mem
  | k + 1 => match (Grid.thread g k).frames with
    | [f] => Ret.out (Valuation.entry (c k) 0 (Kernel.mems g c paths k) f)
        (Kernel.mems g c paths k)
        (Ret.pick (Valuation.entry (c k) 0 (Kernel.mems g c paths k) f) paths)
    | _ => Kernel.mems g c paths k

/-- Whether every thread of grid `g` with one frame, from the memory `Kernel.mems` gives for the
threads before it, has a path of `paths` that `Ret.check` accepts. The kernel evaluates it on a
concrete grid. -/
def Kernel.check (g : Grid) (c : Nat → Ctx) (paths : List (List (Nat × List Cond × Summary))) :
    Bool :=
  (List.range g.threads.size).all fun k => match (Grid.thread g k).frames with
    | [f] => Ret.check (Valuation.entry (c k) 0 (Kernel.mems g c paths k) f)
        (Ret.pick (Valuation.entry (c k) 0 (Kernel.mems g c paths k) f) paths)
    | _ => true

/-- **Kernel soundness at one address choice and oracle, by evaluation.** For every program
`prog`, kernel `fn`, launch `L`, arguments, memory `m` whose pointer bytes are known, address
choice `ch`, oracle `ω`, observation `obs` that reads only the blocks, predicate `R` and paths
from the entry (`coversEntry`): if the start at `ch` and `ω` gives grid `g` and contexts `c`, each
thread has a path that `Ret.check` accepts (`Kernel.check`), and the memory the threads leave
in turn (`Kernel.mems` after all of them) has a trace with no data race that keeps the promise
of `!invariant.load` and an observation meeting `R`, then the kernel is sound at the admission of
`ch` and `ω` alone (`Kernel.sound_of_paths` with the invariant `m = Kernel.mems g c paths k`).
On a concrete launch, memory, choice and oracle the premises are closed and the kernel decides
them. -/
theorem Kernel.sound_eval {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {ω : Nat → Nat → Nat} {β : Type} {obs : Mem → Option β} {R : β → Prop}
    {paths : List (List (Nat × List Cond × Summary))} {g : Grid} {c : Nat → Ctx}
    (hc : coversEntry prog fn paths = true) (hm : m.BytesIn m.Known)
    (hs : Grid.start prog fn L args m ch ω = .ok (g, c))
    (hO : ∀ m m' : Mem, m.blocks = m'.blocks → obs m = obs m')
    (hr : Kernel.check g c paths = true)
    (hf : GPUProof.racy sig ((Kernel.mems g c paths g.threads.size).trace.map
        (Event.toCore L)).reverse = false ∧
      GPUProof.kept sig ((Kernel.mems g c paths g.threads.size).trace.map
        (Event.toCore L)).reverse = true)
    (hR : ∃ y, obs (Kernel.mems g c paths g.threads.size) = some y ∧ R y) :
    Kernel.Sound prog fn L args m (fun ch' ω' => ch' = ch ∧ ω' = ω) obs R := by
  refine Kernel.sound_of_paths hc hm (by rintro _ _ ⟨rfl, rfl⟩; exact ⟨_, _, hs⟩) hO ?_
  rintro _ _ g' c' ⟨rfl, rfl⟩ h
  rw [hs] at h
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj h)
  refine ⟨fun k m' => m' = Kernel.mems g c paths k, rfl, fun k hk m' f hm' hf' => ?_,
    fun m' hm' => by subst hm'; exact ⟨fun _ _ => hf.1, hf.2, hR⟩⟩
  subst hm'
  have hk' := List.all_eq_true.1 hr k (List.mem_range.2 hk)
  simp only [hf'] at hk'
  have e : Kernel.mems g c paths (k + 1) = Ret.out (Valuation.entry (c k) 0
      (Kernel.mems g c paths k) f) (Kernel.mems g c paths k)
      (Ret.pick (Valuation.entry (c k) 0 (Kernel.mems g c paths k) f) paths) := by
    simp only [Kernel.mems, hf']
  simp only [e]
  refine ⟨Ret.pick (Valuation.entry (c k) 0 (Kernel.mems g c paths k) f) paths, ?_,
    Ret.of_check hk'⟩
  unfold Ret.pick at hk' ⊢
  cases h : paths.find? (Ret.check (Valuation.entry (c k) 0 (Kernel.mems g c paths k) f)) with
  | none => simp [h, Ret.check] at hk'
  | some ps => exact List.mem_of_find?_eq_some h

/-- The ownership discipline of an elementwise kernel's output block `out`, with thread `i`'s
cell of `w` bytes at offset `cell i`: an access to `out` lies in its thread's cell, an access to
another block reads and is not an `atomicrmw`'s, and an access with `!invariant.load` is not to
`out`. -/
def Elem.Own (out w : Nat) (cell : Nat → Nat) (a : Access) : Prop :=
  (a.ptr.block = out →
    (cell a.who.thread : Int) ≤ a.ptr.off ∧ a.ptr.off + a.len ≤ cell a.who.thread + w) ∧
  (a.ptr.block ≠ out → a.write = false ∧ a.atomic = none) ∧
    (a.invariant = true → a.ptr.block ≠ out)

/-- Block `blk` after threads `i < k` in turn put bytes `bs i` at offset `cell i` (nothing when
`bs i = none`). -/
def Elem.put (cell : Nat → Nat) (bs : Nat → Option (List MemByte)) (k : Nat) (blk : Sem.Block) :
    Sem.Block :=
  (List.range k).foldl (fun blk i => (bs i).elim blk (blk.put (cell i))) blk

/-- The memory `m` after `k` threads of an elementwise kernel ran in turn from `m₀`: block `out`
is `m₀`'s with the bytes of threads below `k` put in turn (`Elem.put`), every other block is
`m₀`'s, and every access of `m`'s trace is owned (`Elem.Own`). -/
structure Elem (m₀ : Mem) (out w : Nat) (cell : Nat → Nat) (bs : Nat → Option (List MemByte))
    (k : Nat) (m : Mem) : Prop where
  /-- `Elem m₀ out w cell bs k m` from its three fields: block `out` of `m` is `m₀`'s with the
  puts of the threads below `k`, every other block is `m₀`'s, and every access of `m`'s trace is
  owned. -/
  mk ::
  /-- Block `out` is `m₀`'s with the bytes of the threads below `k` put in turn. -/
  cells : m.blocks out = (m₀.blocks out).map (Elem.put cell bs k)
  /-- Every other block is `m₀`'s. -/
  rest : ∀ b, b ≠ out → m.blocks b = m₀.blocks b
  /-- Every access of the trace is owned. -/
  owned : ∀ a, Event.access a ∈ m.trace → Elem.Own out w cell a

/-- A memory with an empty trace meets `Elem` from itself with no thread done, for every output
block, cell width, cells and bytes. -/
theorem Elem.zero {m₀ : Mem} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    (h : m₀.trace = []) : Elem m₀ out w cell bs 0 m₀ where
  cells := by
    cases m₀.blocks out with
    | none => rfl
    | some x => simp [Elem.put]
  rest _ _ := rfl
  owned a ha := by rw [h] at ha; cases ha

/-- A thread's step of `Elem`: if memory `m` meets `Elem` after `k` threads, and `m'` has block
`out` with thread `k`'s bytes put at `cell k` (nothing when `bs k = none`), every other block
unchanged, and every access of its trace either `m`'s or owned, then `m'` meets `Elem` after
`k + 1` threads. For every memory, output block, cell width, cells and bytes. -/
theorem Elem.succ {m₀ : Mem} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    {k : Nat} {m : Mem} (h : Elem m₀ out w cell bs k m) {m' : Mem}
    (hout : m'.blocks out = (m.blocks out).map fun blk => (bs k).elim blk (blk.put (cell k)))
    (hrest : ∀ b, b ≠ out → m'.blocks b = m.blocks b)
    (htr : ∀ a, Event.access a ∈ m'.trace → Event.access a ∈ m.trace ∨ Elem.Own out w cell a) :
    Elem m₀ out w cell bs (k + 1) m' where
  cells := by
    rw [hout, h.cells, Option.map_map]
    congr 1
    funext blk
    simp only [Function.comp_apply, Elem.put, List.range_succ, List.foldl_append, List.foldl_cons,
      List.foldl_nil]
  rest b hb := (hrest b hb).trans (h.rest b hb)
  owned a ha := (htr a ha).elim (h.owned a) id

/-- An owned access keeps `Elem`: logging it on a memory of `Elem` after `k` threads gives a
memory of `Elem` after `k` threads, for every memory, output block, cell width, cells and bytes. -/
theorem Elem.log {m₀ : Mem} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    {k : Nat} {m : Mem} (h : Elem m₀ out w cell bs k m) {a : Access}
    (ha : Elem.Own out w cell a) : Elem m₀ out w cell bs k (m.log (.access a)) where
  cells := h.cells
  rest := h.rest
  owned a' ha' := by
    simp only [Mem.log, List.mem_cons] at ha'
    rcases ha' with e | e
    · injection e with e
      subst e
      exact ha
    · exact h.owned a' e

/-- A thread that puts no bytes (`bs k = none`) and leaves the memory as it is keeps `Elem`, for
every memory, output block, cell width, cells and bytes. -/
theorem Elem.skip {m₀ : Mem} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    {k : Nat} {m : Mem} (h : Elem m₀ out w cell bs k m) (hb : bs k = none) :
    Elem m₀ out w cell bs (k + 1) m :=
  h.succ (by simp [hb]) (fun _ _ => rfl) fun _ ha => .inl ha

/-- **A thread's store to its cell keeps `Elem`.** For every memory of `Elem` after `k` threads,
layout, thread `who` numbered `k`, space, type `t` of at most `w` stored bytes, value `v`,
alignment and atomic operation: a store of `v` at offset `cell k` of block `out` that succeeds,
whose bytes are `bs k` (`Layout.encode`), gives a memory of `Elem` after `k + 1` threads
(`Mem.store_inv`, `Elem.succ`). -/
theorem Elem.store {m₀ : Mem} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    {k : Nat} {m : Mem} (h : Elem m₀ out w cell bs k m) {l : Layout} {who : Who} {a : Nat} {t : Ty}
    {v : Val} {al : Option Nat} {op : Option RmwOp} {m' : Mem}
    (hs : m.store l who a t v ⟨out, cell k⟩ al op = .ok m') (hw : who.thread = k)
    (he : l.encode t v = bs k) (hl : l.stored t ≤ w) : Elem m₀ out w cell bs (k + 1) m' := by
  obtain ⟨blk, bs', hc, -, hbs, rfl⟩ := Mem.store_inv hs
  have hb : m.blocks out = some blk := (Mem.check_inv hc).1
  rw [hbs] at he
  refine h.succ ?_ (fun b hb' => by simp [Mem.log, Mem.set, hb']) fun a' ha' => ?_
  · simp [Mem.log, Mem.set, hb, ← he]
  · simp only [Mem.log, List.mem_cons] at ha'
    rcases ha' with e | e
    · injection e with e
      subst e
      refine .inr ⟨fun _ => ?_, fun hne => absurd rfl hne, fun hi => by cases hi⟩
      dsimp only
      rw [hw]
      omega
    · exact .inl e

/-- The blocks other than `out` of a memory of `Elem` are `m₀`'s: a load through a pointer into
another block gives what it gives on `m₀`, for every memory, output block, cell width, cells,
bytes, layout, thread, space, type and alignment. -/
theorem Elem.load {m₀ : Mem} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    {k : Nat} {m : Mem} (h : Elem m₀ out w cell bs k m) {p : Ptr} (hp : p.block ≠ out) (l : Layout)
    (who : Who) (a : Nat) (t : Ty) (al : Option Nat) :
    m.load l who a t p al = m₀.load l who a t p al :=
  Mem.load_of_block (h.rest _ hp) who a t al

/-- `Elem.put` changes only bytes: after the puts of `k` threads, a block has the space,
liveness, owner, writability, size and addresses it had, for every cells, bytes, thread count and
block. -/
theorem Elem.put_fields (cell : Nat → Nat) (bs : Nat → Option (List MemByte)) :
    ∀ (k : Nat) (x : Sem.Block), (Elem.put cell bs k x).space = x.space ∧
      (Elem.put cell bs k x).live = x.live ∧ (Elem.put cell bs k x).owner = x.owner ∧
      (Elem.put cell bs k x).readOnly = x.readOnly ∧ (Elem.put cell bs k x).size = x.size ∧
      (Elem.put cell bs k x).addr = x.addr ∧ (Elem.put cell bs k x).gaddr = x.gaddr := by
  intro j
  induction j with
  | zero => intro x; simp [Elem.put]
  | succ j ih =>
    intro x
    simp only [Elem.put, List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]
    cases hj : bs j with
    | none => simpa [Elem.put] using ih x
    | some y => simpa [Elem.put, Sem.Block.put] using ih x

/-- The output block of a memory of `Elem` is a buffer (`Mem.Buffer`) exactly as in `m₀`: the
puts of the threads change only bytes (`Elem.put_fields`). For every memory, output block, cell
width, cells, bytes, size, alignment and writability. -/
theorem Elem.buffer {m₀ : Mem} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    {k : Nat} {m : Mem} (h : Elem m₀ out w cell bs k m) {size al : Nat} {wr : Bool}
    (hB : m₀.Buffer out size al wr) : m.Buffer out size al wr := by
  obtain ⟨blk, hb, h1, h2, h3, h4, h5, h6, h7⟩ := hB
  obtain ⟨e1, e2, e3, e4, e5, e6, e7⟩ := Elem.put_fields cell bs k blk
  exact ⟨_, by rw [h.cells, hb]; rfl, e1.trans h1, e2.trans h2, e3.trans h3, e4.trans h4,
    by rw [e5]; exact h5, by rw [e6]; exact h6, by rw [e7]; exact h7⟩

/-- The output block of a memory of `Elem` fits (`Mem.Fits`) exactly as in `m₀`: the puts keep
its generic address (`Elem.put_fields`). For every memory, output block, cell width, cells,
bytes, layout and size. -/
theorem Elem.fits {m₀ : Mem} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    {k : Nat} {m : Mem} (h : Elem m₀ out w cell bs k m) {l : Layout} {size : Nat}
    (hF : m₀.Fits l out size) : m.Fits l out size := by
  obtain ⟨blk, hb, h1⟩ := hF
  exact ⟨_, by rw [h.cells, hb]; rfl, by rw [(Elem.put_fields cell bs k blk).2.2.2.2.2.2]; exact h1⟩

/-- A block of the caller's memory `m` other than `out` is, unchanged, a block of every memory of
`Elem` from the start's memory (`Elem.rest`, `Grid.start_blocks`): for every program, kernel,
launch, arguments, address choice and oracle whose start succeeds, output block, cell width,
cells, bytes and thread count. -/
theorem Elem.start_block {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {ω : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch ω = .ok (g, c)) {out w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {k : Nat} {m' : Mem} (hE : Elem g.mem out w cell bs k m')
    {q : Nat} (hq : q ≠ out) : ∀ x, m.blocks q = some x → m'.blocks q = some x :=
  fun _ hb => (hE.rest _ hq).trans (Grid.start_blocks h hb)

/-- **A load effect keeps `Elem`.** For every memory of `Elem` after `k` threads, valuation, node
values, label, instruction and pointer: if every value the pointer evaluates to is an address
outside block `out`, the memory the load effect gives (`SEff.apply`) meets `Elem` after `k`
threads (`Elem.log`). -/
theorem Elem.apply_load {m₀ : Mem} {out w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {k : Nat} {m : Mem} (h : Elem m₀ out w cell bs k m)
    {V : Valuation} {vs : List (Except Fault Val)} {lbl pc : Nat} {p : SVal} {m' : Mem}
    (ha : SEff.apply V vs m (.load lbl pc p) = .ok m')
    (hp : ∀ v, p.eval V vs = .ok v → ∀ q, v.addr? = .ok q → q.block ≠ out) :
    Elem m₀ out w cell bs k m' := by
  simp only [SEff.apply] at ha
  split at ha
  · obtain ⟨v, hv, ha⟩ := Except.bind_eq_ok.1 ha
    obtain ⟨q, hq, ha⟩ := Except.bind_eq_ok.1 ha
    cases ha
    exact h.log ⟨fun hb => absurd hb (hp v hv q hq), fun _ => ⟨rfl, rfl⟩, fun _ => hp v hv q hq⟩
  · cases ha

/-- **A thread's store effect to its cell advances `Elem`.** For every memory of `Elem` after `k`
threads and valuation `V` of thread `k`: if the statement at `(lbl, pc)` stores a value of type
`t`, the effect's value evaluates to `x` whose bytes (`Layout.encode`) are `bs k`, its pointer
evaluates to `⟨out, cell k⟩`, and `t` fills at most `w` bytes, then the memory the store effect
gives (`SEff.apply`) meets `Elem` after `k + 1` threads (`Elem.store`). -/
theorem Elem.apply_store {m₀ : Mem} {out w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {k : Nat} {m : Mem} (h : Elem m₀ out w cell bs k m)
    {V : Valuation} {vs : List (Except Fault Val)} {lbl pc : Nat} {v p : SVal} {m' : Mem}
    (ha : SEff.apply V vs m (.store lbl pc v p) = .ok m') {r : Option Nat} {vol : Bool} {t : Ty}
    {tv : Value} {a : Nat} {pv : Value} {al : Option Nat} {md : List (String × Nat)}
    (hs : V.stmt lbl pc = some ⟨r, .store vol ⟨t, tv⟩ ⟨.ptr a, pv⟩ al, md⟩)
    (hw : V.ctx.who.thread = k) {x : Val} (hx : v.eval V vs = .ok x)
    (hp : p.eval V vs = .ok (.ptr ⟨out, cell k⟩))
    (he : V.ctx.prog.layout.encode t x = bs k) (hl : V.ctx.prog.layout.stored t ≤ w) :
    Elem m₀ out w cell bs (k + 1) m' := by
  simp only [SEff.apply, hs, hx, hp, Val.addr?, bind, Except.bind, pure, Except.pure] at ha
  exact h.store ha hw he hl

/-- Blocks `B` agree with the caller's memory `m` after `N` threads of an elementwise kernel, on
the blocks `m` has: if `m` has block `out`, `B`'s block `out` is it with the bytes `bs i` of the
threads `i < N` put in turn at their cells (`Elem.put`), and every other block of `m` is a block
of `B` unchanged. Blocks that `m` does not have (such as those the start allocates for `byval`
arguments) are not constrained, and if `m` has no block `out` nothing is said about `B`'s. -/
def Elem.Out (m : Mem) (out : Nat) (cell : Nat → Nat) (bs : Nat → Option (List MemByte)) (N : Nat)
    (B : Nat → Option Sem.Block) : Prop :=
  (∀ x, m.blocks out = some x → B out = some (Elem.put cell bs N x)) ∧
  ∀ b x, b ≠ out → m.blocks b = some x → B b = some x

/-- Every access to block `out` in memory `m`'s trace is by a thread of `S`, for every output
block, set of threads and memory. -/
def Elem.Only (out : Nat) (S : Nat → Prop) (m : Mem) : Prop :=
  ∀ a, Event.access a ∈ m.trace → a.ptr.block = out → S a.who.thread

/-- Logging an access keeps `Elem.Only` if, when it is to block `out`, its thread is in `S`; for
every output block, set of threads, memory and access. -/
theorem Elem.Only.log {out : Nat} {S : Nat → Prop} {m : Mem} (h : Elem.Only out S m) {a : Access}
    (ha : a.ptr.block = out → S a.who.thread) : Elem.Only out S (m.log (.access a)) := by
  intro a' ha' hb
  simp only [Mem.log, List.mem_cons] at ha'
  rcases ha' with e | e
  · injection e with e
    subst e
    exact ha hb
  · exact h a' e hb

/-- **An effect of a thread of `S` keeps `Elem.Only`.** For every output block, set of threads
`S`, memory, valuation `V` whose thread is in `S`, node values and effect: the memory the effect
gives (`SEff.apply`: a load or a store logs one access by `V`'s thread, `Mem.store_inv`; an
`alloca`'s logs none) has every access to `out` by a thread of `S` if the memory before it has. -/
theorem Elem.Only.apply {out : Nat} {S : Nat → Prop} {m : Mem} (h : Elem.Only out S m)
    {V : Valuation} {vs : List (Except Fault Val)} {e : SEff} {m' : Mem}
    (hS : S V.ctx.who.thread) (ha : SEff.apply V vs m e = .ok m') : Elem.Only out S m' := by
  cases e with
  | load lbl pc p =>
    simp only [SEff.apply] at ha
    split at ha
    · obtain ⟨v, -, ha⟩ := Except.bind_eq_ok.1 ha
      obtain ⟨q, -, ha⟩ := Except.bind_eq_ok.1 ha
      cases ha
      exact h.log fun _ => hS
    · cases ha
  | store lbl pc v p =>
    simp only [SEff.apply] at ha
    split at ha
    · obtain ⟨x, -, ha⟩ := Except.bind_eq_ok.1 ha
      obtain ⟨pv, -, ha⟩ := Except.bind_eq_ok.1 ha
      obtain ⟨q, -, ha⟩ := Except.bind_eq_ok.1 ha
      obtain ⟨blk, bs', -, -, -, rfl⟩ := Mem.store_inv ha
      exact h.log fun _ => hS
    · cases ha
  | alloca lbl pc n cnt =>
    simp only [SEff.apply] at ha
    split at ha
    · obtain ⟨c, -, ha⟩ := Except.bind_eq_ok.1 ha
      split at ha
      · cases ha
      · cases ha
        exact h
    · cases ha

/-- **Cells apart on the threads that access the output are safe**: for every memory meeting
`Elem` whose accesses to block `out` are by threads of `S` (`Elem.Only`), with the cells of the
threads of `S` `w` bytes apart (`Apart` on the subtype of `S`; cells of other threads may
overlap them), its trace keeps the promise of `!invariant.load` and, under the premises of
`racy_iff`, has no data race (`racy_kept_of_cells` for cells equal to `cell` on the finitely
many threads that access `out` and `w` apart past their maximum on the others). -/
theorem Elem.safe_on {L : Launch} {m₀ : Mem} {out w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {k : Nat} {m : Mem} {S : Nat → Prop}
    (hap : Apart (fun i : {i // S i} => cell i) w) (h : Elem m₀ out w cell bs k m)
    (hS : Elem.Only out S m) :
    ((∀ a, Event.access a ∈ m.trace → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m.trace.reverse →
      GPUProof.racy sig (m.trace.map (Event.toCore L)).reverse = false) ∧
      GPUProof.kept sig (m.trace.map (Event.toCore L)).reverse = true := by
  classical
  obtain ⟨ts, hts, hS'⟩ : ∃ ts : List Nat,
      (∀ a, Event.access a ∈ m.trace → a.ptr.block = out → a.who.thread ∈ ts) ∧ ∀ i ∈ ts, S i :=
    ⟨m.trace.filterMap fun e => match e with
        | .access a => if a.ptr.block = out then some a.who.thread else none
        | .barrier _ => none,
      fun a ha hb => List.mem_filterMap.2 ⟨_, ha, by simp [hb]⟩, fun i hi => by
        obtain ⟨e, he, hi⟩ := List.mem_filterMap.1 hi
        cases e with
        | access a =>
          by_cases hb : a.ptr.block = out
          · simp only [hb, ↓reduceIte, Option.some.injEq] at hi
            subst hi
            exact hS a he hb
          · simp [hb] at hi
        | barrier _ => cases hi⟩
  have hK : ∀ l : List Nat, ∃ K, ∀ i ∈ l, cell i + w ≤ K := fun l => by
    induction l with
    | nil => exact ⟨0, fun _ h => by cases h⟩
    | cons x l ih =>
      obtain ⟨K, hK⟩ := ih
      refine ⟨K + cell x + w, fun i hi => ?_⟩
      rcases List.mem_cons.1 hi with rfl | hi
      · omega
      · have := hK i hi
        omega
  obtain ⟨K, hK⟩ := hK ts
  refine racy_kept_of_cells (cell := fun i => if i ∈ ts then cell i else K + w * i) ?_
    (fun a ha hb => by simp only [hts a ha hb, ↓reduceIte]; exact (h.owned a ha).1 hb)
    (fun a ha hb => (h.owned a ha).2.1 hb) fun a ha hi => (h.owned a ha).2.2 hi
  intro i j hij
  by_cases hi : i ∈ ts <;> by_cases hj : j ∈ ts <;> simp only [hi, hj, ↓reduceIte]
  · exact hap ⟨i, hS' i hi⟩ ⟨j, hS' j hj⟩ fun e => hij (congrArg Subtype.val e)
  · have := hK i hi
    omega
  · have := hK j hj
    omega
  · have := apart_mul w i j hij
    simp only at this
    omega

/-- **The elementwise discipline is safe**: for every memory meeting `Elem` with cells `w` bytes
apart (`Apart`), its trace keeps the promise of `!invariant.load` and, under the premises of
`racy_iff`, has no data race (`Elem.safe_on` with every thread in `S`). -/
theorem Elem.safe {L : Launch} {m₀ : Mem} {out w : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {k : Nat} {m : Mem} (hap : Apart cell w)
    (h : Elem m₀ out w cell bs k m) :
    ((∀ a, Event.access a ∈ m.trace → a.who.thread < volume L.grid * volume L.block ∧
        a.who.cta = a.who.thread / volume L.block) → Trace.Shaped m.trace.reverse →
      GPUProof.racy sig (m.trace.map (Event.toCore L)).reverse = false) ∧
      GPUProof.kept sig (m.trace.map (Event.toCore L)).reverse = true :=
  Elem.safe_on (S := fun _ => True) (hap.comp Subtype.val_injective) h fun _ _ _ => trivial

/-- **The kernel theorem of an elementwise kernel with loops and cells apart where it stores, with
or without `fmul contract`.** For every flag `contract`, program, kernel `fn`, launch `L`,
arguments, caller's memory `m` whose pointer bytes are known, admission `adm` of address choices
and oracles, paths from the entry (`coversEntryWith contract`), sequences of loops from the entry
(`coversChainsWith contract`), output block `out`, cells `cell` of `w` bytes, bytes `bs` and set
`S` of threads whose cells are `w` bytes apart (`Apart` on the subtype of `S`; the cells of other
threads may overlap them): if the start succeeds on every admitted choice and oracle, and on each
start every thread `k`, from every memory of `Elem` after `k` threads whose accesses to `out` are
by threads of `S` (`Elem.Only`), either takes some path of `paths` that is a `RetWith contract`,
or runs some sequence of loops of `chains` to `ret` (`RetLsWith contract`), to a memory of `Elem`
after `k + 1` threads whose accesses to `out` are by threads of `S`, then the kernel is sound
(`Kernel.Sound`) for the observation of the blocks and `Elem.Out`: block `out` (if `m` has it) is
`m`'s with the bytes `bs i` of the `volume L.grid * volume L.block` threads put in turn at their
cells (`Elem.put`), and every other block of `m` is unchanged (`Kernel.sound_of_chainsWith` with
the invariant `Elem` and `Elem.Only`, `Elem.zero`, `Elem.safe_on`, `Grid.start_blocks`,
`Grid.start_args`). It covers kernels whose threads each run one path without a cycle or one
sequence of loops to `ret`, with `fmul contract` and `fadd contract` when `contract`; a thread
outside `S` may share a cell but must not access `out`. The per-thread runs are the caller's
premise. -/
theorem Kernel.sound_cellsWith {contract : Bool} {prog : Program} {fn : Func} {L : Launch}
    {args : List Val} {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}
    {paths : List (List (Nat × List Cond × Summary))} {chains : List LoopChain} {out w : Nat}
    {cell : Nat → Nat} {bs : Nat → Option (List MemByte)} {S : Nat → Prop}
    (hc : coversEntryWith contract prog fn paths = true)
    (hcL : coversChainsWith contract prog fn chains = true) (hm : m.BytesIn m.Known)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hap : Apart (fun i : {i // S i} => cell i) w)
    (H : ∀ ch oracle g c, adm ch oracle → Grid.start prog fn L args m ch oracle = .ok (g, c) →
      ∀ k < g.threads.size, ∀ m' f, Elem g.mem out w cell bs k m' → Elem.Only out S m' →
        (Grid.thread g k).frames = [f] →
        (∃ ps ∈ paths, RetWith contract (Valuation.entry (c k) 0 m' f)
          (fun me => Elem g.mem out w cell bs (k + 1) me ∧ Elem.Only out S me) ps) ∨
        ∃ C ∈ chains, RetLsWith contract
          (fun me => Elem g.mem out w cell bs (k + 1) me ∧ Elem.Only out S me)
          C.loops (Valuation.entry (c k) 0 m' f) C.l C.ds C.S C.E) :
    Kernel.Sound prog fn L args m adm (fun m => some m.blocks)
      (Elem.Out m out cell bs (volume L.grid * volume L.block)) := by
  refine Kernel.sound_of_chainsWith hc hcL hm hs (fun _ _ h => congrArg some h) ?_
  intro ch oracle g c ha h
  refine ⟨fun k me => Elem g.mem out w cell bs k me ∧ Elem.Only out S me,
    ⟨Elem.zero (Grid.start_trace h), fun a ha => by rw [Grid.start_trace h] at ha; cases ha⟩,
    fun k hk m' f hm' => H ch oracle g c ha h k hk m' f hm'.1 hm'.2,
    fun m' hm' => ⟨(Elem.safe_on (L := L) hap hm'.1 hm'.2).1, (Elem.safe_on hap hm'.1 hm'.2).2,
      _, rfl, And.intro (fun x hx => ?_) fun b x hb hx => ?_⟩⟩
  · rw [hm'.1.cells, Grid.start_blocks h hx, (Grid.start_args h).1]
    rfl
  · rw [hm'.1.rest b hb, Grid.start_blocks h hx]

/-- **The kernel theorem of an elementwise kernel with loops and cells apart where it stores.**
For every program, kernel `fn`, launch `L`, arguments, caller's memory `m` whose pointer bytes
are known, admission `adm` of address choices and oracles, paths from the entry (`coversEntry`),
sequences of loops from the entry (`coversChains`), output block `out`, cells `cell` of `w`
bytes, bytes `bs` and set `S` of threads whose cells are `w` bytes apart (`Apart` on the subtype
of `S`; the cells of other threads may overlap them): if the start succeeds on every admitted
choice and oracle, and on each start every thread `k`, from every memory of `Elem` after `k`
threads whose accesses to `out` are by threads of `S` (`Elem.Only`), either takes some path of
`paths` that is a `Ret`, or runs some sequence of loops of `chains` to `ret` (`RetLs`), to a
memory of `Elem` after `k + 1` threads whose accesses to `out` are by threads of `S`, then the
kernel is sound (`Kernel.Sound`) for the observation of the blocks and `Elem.Out`: block `out`
(if `m` has it) is `m`'s with the bytes `bs i` of the `volume L.grid * volume L.block` threads
put in turn at their cells (`Elem.put`), and every other block of `m` is unchanged
(`Kernel.sound_cellsWith` without `fmul contract`). It covers kernels whose
threads each run one path without a cycle or one sequence of loops to `ret`; a thread outside
`S` may share a cell but must not access `out`. The per-thread runs are the caller's premise. -/
theorem Kernel.sound_cells {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {paths : List (List (Nat × List Cond × Summary))}
    {chains : List LoopChain} {out w : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    {S : Nat → Prop} (hc : coversEntry prog fn paths = true)
    (hcL : coversChains prog fn chains = true) (hm : m.BytesIn m.Known)
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hap : Apart (fun i : {i // S i} => cell i) w)
    (H : ∀ ch oracle g c, adm ch oracle → Grid.start prog fn L args m ch oracle = .ok (g, c) →
      ∀ k < g.threads.size, ∀ m' f, Elem g.mem out w cell bs k m' → Elem.Only out S m' →
        (Grid.thread g k).frames = [f] →
        (∃ ps ∈ paths, Ret (Valuation.entry (c k) 0 m' f)
          (fun me => Elem g.mem out w cell bs (k + 1) me ∧ Elem.Only out S me) ps) ∨
        ∃ C ∈ chains, RetLs (fun me => Elem g.mem out w cell bs (k + 1) me ∧ Elem.Only out S me)
          C.loops (Valuation.entry (c k) 0 m' f) C.l C.ds C.S C.E) :
    Kernel.Sound prog fn L args m adm (fun m => some m.blocks)
      (Elem.Out m out cell bs (volume L.grid * volume L.block)) :=
  Kernel.sound_cellsWith (contract := false) hc hcL hm hs hap H

/-- **The kernel theorem of an elementwise kernel.** For every program,
kernel `fn`, launch `L`, arguments, caller's memory `m` whose pointer bytes are known, oracle `ω`,
paths from the entry (`coversEntry`), output block `out`, cells `cell` of `w` bytes apart
(`Apart`) and bytes `bs`: if the start succeeds on every address choice at `ω`, and on each start
every thread `k`, from every memory of `Elem` after `k` threads, takes some path of `paths` that
is a `Ret` to a memory of `Elem` after `k + 1` threads, then the kernel is sound at every address
choice and `ω` (`Kernel.Sound`) for the observation of the blocks and `Elem.Out`: block `out`
(if `m` has it) is `m`'s with the bytes `bs i` of the `volume L.grid * volume L.block` threads
put in turn at their cells (`Elem.put`), and every other block of `m` is unchanged. It is
`Kernel.sound_cells` with no sequence of loops, every thread in `S` and the admission of `ω`
alone. It covers kernels whose threads each run one path without a cycle to `ret`; the
per-thread `Ret` is the caller's premise. -/
theorem Kernel.sound_elem {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ω : Nat → Nat → Nat} {paths : List (List (Nat × List Cond × Summary))} {out w : Nat}
    {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    (hc : coversEntry prog fn paths = true) (hm : m.BytesIn m.Known)
    (hs : ∀ ch, ∃ g c, Grid.start prog fn L args m ch ω = .ok (g, c)) (hap : Apart cell w)
    (H : ∀ ch g c, Grid.start prog fn L args m ch ω = .ok (g, c) →
      ∀ k < g.threads.size, ∀ m' f, Elem g.mem out w cell bs k m' →
        (Grid.thread g k).frames = [f] →
        ∃ ps ∈ paths, Ret (Valuation.entry (c k) 0 m' f) (Elem g.mem out w cell bs (k + 1)) ps) :
    Kernel.Sound prog fn L args m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m out cell bs (volume L.grid * volume L.block)) :=
  Kernel.sound_cells (chains := []) (S := fun _ => True) hc rfl hm (fun ch _ e => e ▸ hs ch)
    (hap.comp Subtype.val_injective) fun ch _ g c e h k hk m' f hE _ hf => .inl <| by
      subst e
      exact (H ch g c h k hk m' f hE hf).imp fun _ ⟨hp, hR⟩ =>
        ⟨hp, hR.mono fun _ h => ⟨h, fun _ _ _ => trivial⟩⟩

/-- Parameters named by their positions name no register twice: for every function whose
parameter at each position `j` is named `%j` and every position `i`, no parameter before `i` is
named `%i`. -/
theorem take_names {fn : Func} (hn : ∀ j (p : Param), fn.params[j]? = some p → p.name = some j)
    (i : Nat) : (fn.params.take i).all (·.name != some i) = true := by
  refine List.all_eq_true.2 fun p hp => ?_
  obtain ⟨j, hj, e⟩ := List.getElem_of_mem hp
  rw [List.getElem_take] at e
  rw [List.length_take] at hj
  rw [hn j p (by rw [← e]; exact List.getElem?_eq_getElem _)]
  simp only [bne_iff_ne, ne_eq, Option.some.injEq]
  omega

/-- **The kernel theorem of an elementwise kernel over any number of buffer structs and scalars,
with loops, cells apart where it stores and every admitted oracle, with or without
`fmul contract`.** For every flag `contract`, program `prog`, kernel `fn` whose parameters are
`ps ++` the parameters of `sc`, the one at each position `j` named `%j`, every one of `ps`
`byval` of a struct type `T` whose values `.agg [.ptr p, z]` have a codec (`Layout.Codec`) and
none of `sc`'s `byval`, alignment `al'` of `T` and of the generic space's addresses, launch `L`,
paths from the entry (`coversEntryWith contract`), sequences of loops from the entry
(`coversChainsWith contract`), block numbers `bl`, one for each of `ps`, scalars `sc` (each a
parameter, an argument and the value its attributes take it to on every memory), caller's memory
`m` whose pointer bytes are known and which has an output block `o` owned by all threads,
admission `adm` of address choices and oracles, set `S` of threads whose cells `cell` are `w`
bytes apart (`Apart` on the subtype of `S`) and bytes `bs`: if the start on the structs of `bl`
then the arguments of `sc` succeeds on every admitted choice and oracle, and `H` holds, then `fn`
is sound (`Kernel.Sound`) for the observation of the blocks and `Elem.Out`
(`Kernel.sound_cellsWith`). `H`: for every admitted choice and oracle, thread `k` of the launch,
context of `prog` with thread `k`'s registers, identity and oracle, memory `m₀` that has `m`'s
block `o`, memory `m'` of `Elem` after `k` threads whose accesses to `o` are by threads of `S`
(`Elem.Only`) and on which every block of `m` but `o` is unchanged, and frame of `fn` whose
register `%i`, for each position `i` of `bl`, points to a block other than `o` from which `T`
loads at alignment `al'` as the struct of `bl[i]`, and whose register `%(n + j)` (`n` the length
of `bl`) is the value of `sc[j]`, either some path of `paths` from the frame's entry is a
`RetWith contract`, or some sequence of loops of `chains` runs to `ret` (`RetLsWith contract`),
to a memory of `Elem` after `k + 1` threads whose accesses to `o` are by threads of `S`. The
start gives these facts (`Grid.start_buffer`, `Grid.start_scalar`, `Elem.start_block`,
`Elem.load`). It covers the family of kernels with this parameter shape, with no bound on the
number of structs or scalars; `H` and the start on every choice are the caller's premises. -/
theorem Kernel.sound_mapNWith {contract : Bool} {prog : Program} {fn : Func} {L : Launch}
    {paths : List (List (Nat × List Cond × Summary))} {chains : List LoopChain}
    (hc : coversEntryWith contract prog fn paths = true)
    (hcL : coversChainsWith contract prog fn chains = true) {ps : List Param}
    {sc : List (Param × Val × Val)} (hps : fn.params = ps ++ sc.map (·.1))
    (hn : ∀ j (p : Param), fn.params[j]? = some p → p.name = some j) {T : Ty}
    (hT : ∀ p ∈ ps, p.byval? = some T) (hsc : ∀ s ∈ sc, s.1.byval? = none)
    {z : Val} (hcod : prog.layout.Codec T fun p => .agg [.ptr p, z]) {al' : Nat}
    (hal' : al' ∣ prog.layout.align T ∧ al' ∣ 2 ^ (prog.layout.ptr 0).1)
    {bl : List Nat} (hbl : bl.length = ps.length)
    (hw : ∀ s ∈ sc, ∀ m', withAttrs prog.layout m' s.1.ty s.1.attrs s.2.1 = .ok s.2.2) {m : Mem}
    (hm : m.BytesIn m.Known) {o : Nat} (hO : ∃ x, m.blocks o = some x ∧ x.owner = .all)
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L
      (bl.map (fun a => Val.agg [.ptr ⟨a, 0⟩, z]) ++ sc.map (·.2.1)) m ch oracle = .ok (g, c))
    {S : Nat → Prop} {w : Nat} {cell : Nat → Nat} (hap : Apart (fun i : {i // S i} => cell i) w)
    {bs : Nat → Option (List MemByte)}
    (H : ∀ ch oracle, adm ch oracle → ∀ k, k < volume L.grid * volume L.block →
      ∀ c : Ctx, c.prog = prog → c.env = L.env k → c.who = ⟨k, k / volume L.block⟩ →
      c.oracle = oracle k → ∀ (m₀ m' : Mem) (f : Frame), f.fn = fn →
      (∀ i (hi : i < bl.length), ∃ q, f.regs i = some (.ptr ⟨q, 0⟩) ∧ q ≠ o ∧
        m'.load prog.layout c.who 0 T ⟨q, 0⟩ (some al') = .ok (.agg [.ptr ⟨bl[i], 0⟩, z])) →
      (∀ j (hj : j < sc.length), f.regs (bl.length + j) = some sc[j].2.2) →
      (∀ q, q ≠ o → ∀ x, m.blocks q = some x → m'.blocks q = some x) →
      (∀ x, m.blocks o = some x → m₀.blocks o = some x) →
      Elem m₀ o w cell bs k m' → Elem.Only o S m' →
      (∃ ps ∈ paths, RetWith contract (Valuation.entry c 0 m' f)
        (fun me => Elem m₀ o w cell bs (k + 1) me ∧ Elem.Only o S me) ps) ∨
      ∃ C ∈ chains, RetLsWith contract
        (fun me => Elem m₀ o w cell bs (k + 1) me ∧ Elem.Only o S me)
        C.loops (Valuation.entry c 0 m' f) C.l C.ds C.S C.E) :
    Kernel.Sound prog fn L (bl.map (fun a => Val.agg [.ptr ⟨a, 0⟩, z]) ++ sc.map (·.2.1)) m adm
      (fun m => some m.blocks) (Elem.Out m o cell bs (volume L.grid * volume L.block)) := by
  refine Kernel.sound_cellsWith hc hcL hm hs hap fun ch oracle g c ha h k hk m' f hE hS hfr => ?_
  obtain ⟨xo, hxo, hxo'⟩ := hO
  have hgo := Grid.start_blocks h hxo
  obtain ⟨f', ht, hf, -⟩ := Grid.start_thread h hk
  have e : [f'] = [f] := by rw [← hfr, ht]
  refine H ch oracle ha k (by rw [← (Grid.start_args h).1]; exact hk) (c k)
    (Grid.start_ctx h k).1 (Grid.start_ctx h k).2.2.1 (Grid.start_ctx h k).2.1
    (Grid.start_ctx h k).2.2.2 g.mem m' f (by rw [← (List.cons.inj e).1]; exact hf)
    (fun i hi => ?_) (fun j hj => ?_) (fun q hq => Elem.start_block h hE hq)
    (fun _ hx => Grid.start_blocks h hx) hE hS
  · have hi' : i < ps.length := hbl ▸ hi
    have hp : fn.params[i]? = some ps[i] := by
      rw [hps, List.getElem?_append_left hi']
      exact List.getElem?_eq_getElem hi'
    obtain ⟨q, B, hr, hb, ho, hv⟩ := Grid.start_buffer h hk hfr hp (hn i _ hp) (take_names hn i)
      (hT _ (List.getElem_mem hi')) hcod (x := ⟨bl[i], 0⟩)
      (by rw [List.getElem?_append_left (by simpa using hi), List.getElem?_map,
        List.getElem?_eq_getElem hi]; rfl) hal'.1 hal'.2
    have hqo : q ≠ o := by
      rintro rfl
      rw [hgo, Option.some.injEq] at hb
      subst hb
      rw [hxo'] at ho
      cases ho
    exact ⟨q, hr, hqo, (hE.load (p := ⟨q, 0⟩) hqo _ _ _ _ _).trans hv⟩
  · have hp : fn.params[bl.length + j]? = some sc[j].1 := by
      rw [hps, List.getElem?_append_right (by omega), hbl, Nat.add_sub_cancel_left,
        List.getElem?_map, List.getElem?_eq_getElem hj]
      rfl
    exact Grid.start_scalar h hk hfr hp (hn _ _ hp) (take_names hn _)
      (hsc _ (List.getElem_mem hj))
      (by rw [List.getElem?_append_right (by simp), List.length_map, Nat.add_sub_cancel_left,
        List.getElem?_map, List.getElem?_eq_getElem hj]; rfl) (hw _ (List.getElem_mem hj))

/-- **The kernel theorem of an elementwise kernel over any number of buffer structs and a count
of any type.** For every program `prog`, kernel `fn` whose parameters are `ps ++ [pc]`, the one
at each position `j` named `%j`, every one of `ps` `byval` of a struct type `T` whose values
`.agg [.ptr p, z]` have a codec (`Layout.Codec`) and `pc` not `byval`, alignment `al'` of `T`
and of the generic space's addresses, launch `L`, paths from the entry (`coversEntry`), block
numbers `bl`, one for each of `ps`, count argument `v` that `pc`'s attributes take to `u` on every
memory, caller's memory `m` whose pointer bytes are known and which has an output block `o`
owned by all threads, oracle `ω`, cells `cell` of `w` bytes apart (`Apart`) and bytes `bs`: if
the start on the structs of `bl` then `v` succeeds on every address choice at `ω`, and `H`
holds, then `fn` is sound at every address choice and `ω` (`Kernel.Sound`) for the observation
of the blocks and `Elem.Out` (`Kernel.sound_mapNWith` without `fmul contract`, with no loops,
the one scalar `pc`, the set `S` of all threads and the admission of `ω` alone). `H`: for every
thread `k` of the launch, context of `prog` with thread `k`'s registers, identity and oracle
`ω k`, memory `m₀` that has `m`'s block `o`, memory `m'` of `Elem` after `k` threads on which
every block of `m` but `o` is unchanged, and frame of `fn` whose register `%i`, for each position
`i` of `bl`, points to a block other than `o` from which `T` loads at alignment `al'` as the
struct of `bl[i]`, and whose register `%n` (`n` the length of `bl`) is `u`, some path of `paths`
from the frame's entry is a `Ret` to `Elem` after `k + 1` threads. The start gives these facts
(`Grid.start_buffer`, `Grid.start_scalar`, `Elem.start_block`, `Elem.load`). It covers the family
of kernels with this parameter shape at one oracle `ω`, with no bound on the number of structs
and no condition on the count's type or width; `H` and the start on every choice are the
caller's premises. -/
theorem Kernel.sound_mapN {prog : Program} {fn : Func} {L : Launch}
    {paths : List (List (Nat × List Cond × Summary))} (hc : coversEntry prog fn paths = true)
    {ps : List Param} {pc : Param} (hps : fn.params = ps ++ [pc])
    (hn : ∀ j (p : Param), fn.params[j]? = some p → p.name = some j) {T : Ty}
    (hT : ∀ p ∈ ps, p.byval? = some T) (hpc : pc.byval? = none)
    {z : Val} (hcod : prog.layout.Codec T fun p => .agg [.ptr p, z]) {al' : Nat}
    (hal' : al' ∣ prog.layout.align T ∧ al' ∣ 2 ^ (prog.layout.ptr 0).1)
    {bl : List Nat} (hbl : bl.length = ps.length) {v u : Val}
    (hw : ∀ m', withAttrs prog.layout m' pc.ty pc.attrs v = .ok u) {m : Mem}
    (hm : m.BytesIn m.Known) {o : Nat} (hO : ∃ x, m.blocks o = some x ∧ x.owner = .all)
    {ω : Nat → Nat → Nat}
    (hs : ∀ ch, ∃ g c, Grid.start prog fn L
      (bl.map (fun a => Val.agg [.ptr ⟨a, 0⟩, z]) ++ [v]) m ch ω = .ok (g, c))
    {w : Nat} {cell : Nat → Nat} (hap : Apart cell w) {bs : Nat → Option (List MemByte)}
    (H : ∀ k, k < volume L.grid * volume L.block → ∀ c : Ctx, c.prog = prog →
      c.env = L.env k → c.who = ⟨k, k / volume L.block⟩ → c.oracle = ω k →
      ∀ (m₀ m' : Mem) (f : Frame), f.fn = fn →
      (∀ i (hi : i < bl.length), ∃ q, f.regs i = some (.ptr ⟨q, 0⟩) ∧ q ≠ o ∧
        m'.load prog.layout c.who 0 T ⟨q, 0⟩ (some al') = .ok (.agg [.ptr ⟨bl[i], 0⟩, z])) →
      f.regs bl.length = some u →
      (∀ q, q ≠ o → ∀ x, m.blocks q = some x → m'.blocks q = some x) →
      (∀ x, m.blocks o = some x → m₀.blocks o = some x) →
      Elem m₀ o w cell bs k m' →
      ∃ ps ∈ paths, Ret (Valuation.entry c 0 m' f) (Elem m₀ o w cell bs (k + 1)) ps) :
    Kernel.Sound prog fn L (bl.map (fun a => Val.agg [.ptr ⟨a, 0⟩, z]) ++ [v]) m
      (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m o cell bs (volume L.grid * volume L.block)) :=
  Kernel.sound_mapNWith (contract := false) (chains := []) (sc := [(pc, v, u)])
    (S := fun _ => True) hc rfl hps hn hT (fun _ hs => by rw [List.mem_singleton.1 hs]; exact hpc)
    hcod hal' hbl (fun _ hs => by rw [List.mem_singleton.1 hs]; exact hw) hm hO
    (fun ch _ e => e ▸ hs ch) (hap.comp Subtype.val_injective)
    fun ch _ e k hk c hP hE hW hω m₀ m' f hf hb hr hq ho hE' _ => .inl <| by
      subst e
      exact (H k hk c hP hE hW hω m₀ m' f hf hb (hr 0 (by simp)) hq ho hE').imp
        fun _ ⟨hp, hR⟩ => ⟨hp, hR.mono fun _ h => ⟨h, fun _ _ _ => trivial⟩⟩

/-- **The kernel theorem of a binary elementwise kernel from its threads' runs, with or without
`fmul contract`.** For every flag `contract`, program `prog`, kernel `fn` whose parameters `p0` to
`p3` are named `%0` to `%3`, the first three `byval` of a struct type `T` whose values
`.agg [.ptr p, z]` have a codec (`Layout.Codec`) and the last passed by value as the `i32` `n`
(`withAttrs`), alignment `al'` of `T` and of the generic space's addresses, launch `L`, paths
from the entry (`coversEntryWith contract`), element type `t` with encoder `enc`, alignment `al`,
block numbers `a`, `b`, `o`, count `n`, tensors `x`, `y`, caller's memory `m` of `Map2.Pre`,
oracle `ω`, cells `cell` of `w` bytes apart (`Apart`) and bytes `bs`: if the start on
`Map2.args z a b o n` succeeds on every address choice at `ω`, and `H` holds, then `fn` is sound
at every address choice and `ω` (`Kernel.Sound`) for the observation of the blocks and
`Elem.Out` (`Kernel.sound_mapNWith` at the structs of `a`, `b` and `o` and the `i32` count, with
no loops, the set of all threads and the admission of `ω` alone; `Elem.buffer`, `Elem.fits` and
the `of_block` lemmas move the buffers of `Map2.Pre` to `m'`). `H` is `Kernel.sound_map2`'s with
a `RetWith contract` in place of the `Ret`. It covers the family of kernels with this parameter
shape at one oracle `ω`, with or without the flag; `H`, the start on every choice and the codec
are the caller's premises, which `mojo_kernel`'s `map2` clause discharges for one named kernel
(`n.ret`, `n.starts`, `Layout.Codec.ptrArg`), with the flag through `RetWith.exists_true_of_ret`
(Sym/RetFlag.lean). -/
theorem Kernel.sound_map2With {contract : Bool} {prog : Program} {fn : Func} {L : Launch}
    {paths : List (List (Nat × List Cond × Summary))}
    (hc : coversEntryWith contract prog fn paths = true)
    {p0 p1 p2 p3 : Param} (hps : fn.params = [p0, p1, p2, p3])
    (hn : p0.name = some 0 ∧ p1.name = some 1 ∧ p2.name = some 2 ∧ p3.name = some 3) {T : Ty}
    (hT : p0.byval? = some T ∧ p1.byval? = some T ∧ p2.byval? = some T ∧ p3.byval? = none)
    {z : Val} (hcod : prog.layout.Codec T fun p => .agg [.ptr p, z]) {al' : Nat}
    (hal' : al' ∣ prog.layout.align T ∧ al' ∣ 2 ^ (prog.layout.ptr 0).1)
    {α : Type} [TorchLean.Storage α] {t : Ty} {enc : α → Val} {al a b o n N : Nat}
    {x y : TorchLean.Tensor α [N]} {m : Mem} (hP : Map2.Pre prog.layout t enc al z m a b o n x y)
    (hw : ∀ m', withAttrs prog.layout m' p3.ty p3.attrs (.bits 32 (BitVec.ofNat 32 n)) =
      .ok (.bits 32 (BitVec.ofNat 32 n)))
    {ω : Nat → Nat → Nat}
    (hs : ∀ ch, ∃ g c, Grid.start prog fn L (Map2.args z a b o n) m ch ω = .ok (g, c))
    {w : Nat} {cell : Nat → Nat} (hap : Apart cell w) {bs : Nat → Option (List MemByte)}
    (H : ∀ k, k < volume L.grid * volume L.block → ∀ c : Ctx, c.prog = prog →
      c.env = L.env k → c.who = ⟨k, k / volume L.block⟩ → c.oracle = ω k →
      ∀ (m₀ m' : Mem) (f : Frame), f.fn = fn → ∀ q0 q1 q2 : Nat,
      f.regs 0 = some (.ptr ⟨q0, 0⟩) → f.regs 1 = some (.ptr ⟨q1, 0⟩) →
      f.regs 2 = some (.ptr ⟨q2, 0⟩) → f.regs 3 = some (.bits 32 (BitVec.ofNat 32 n)) →
      m'.load prog.layout c.who 0 T ⟨q0, 0⟩ (some al') = .ok (.agg [.ptr ⟨a, 0⟩, z]) →
      m'.load prog.layout c.who 0 T ⟨q1, 0⟩ (some al') = .ok (.agg [.ptr ⟨b, 0⟩, z]) →
      m'.load prog.layout c.who 0 T ⟨q2, 0⟩ (some al') = .ok (.agg [.ptr ⟨o, 0⟩, z]) →
      m'.Buffer a (n * prog.layout.size t) al false →
      m'.Buffer b (n * prog.layout.size t) al false →
      m'.Buffer o (n * prog.layout.size t) al true →
      m'.Holds prog.layout a t enc (rowMajor prog.layout t 0) x →
      m'.Holds prog.layout b t enc (rowMajor prog.layout t 0) y →
      m'.Fits prog.layout a (n * prog.layout.size t) →
      m'.Fits prog.layout b (n * prog.layout.size t) →
      m'.Fits prog.layout o (n * prog.layout.size t) → q0 ≠ o ∧ q1 ≠ o ∧ q2 ≠ o →
      Elem m₀ o w cell bs k m' →
      ∃ ps ∈ paths, RetWith contract (Valuation.entry c 0 m' f) (Elem m₀ o w cell bs (k + 1)) ps) :
    Kernel.Sound prog fn L (Map2.args z a b o n) m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m o cell bs (volume L.grid * volume L.block)) := by
  obtain ⟨hC, hne, ⟨hA, hB, hO⟩, hx, hy, -, -, hFa, hFb, hFo⟩ := hP
  obtain ⟨h0, h1, h2, h3⟩ := hn
  refine Kernel.sound_mapNWith (chains := []) (ps := [p0, p1, p2]) (bl := [a, b, o])
    (sc := [(p3, .bits 32 (BitVec.ofNat 32 n), .bits 32 (BitVec.ofNat 32 n))])
    (S := fun _ => True) hc rfl hps
    (fun j p hp => by
      rw [hps] at hp
      rcases j with _ | _ | _ | _ | j <;> simp at hp <;> subst hp <;> assumption)
    (by simp [hT.1, hT.2.1, hT.2.2.1])
    (fun _ hs => by rw [List.mem_singleton.1 hs]; exact hT.2.2.2) hcod hal' rfl
    (fun _ hs => by rw [List.mem_singleton.1 hs]; exact hw) hC.bytesIn
    (by obtain ⟨xo, hxo, -, -, hown, -⟩ := hO; exact ⟨xo, hxo, hown⟩) (fun ch _ e => e ▸ hs ch)
    (hap.comp Subtype.val_injective)
    fun ch _ e k hk c hcp hce hcw hco m₀ m' f hf hq hr hrest hm₀ hE _ => .inl ?_
  subst e
  obtain ⟨q0, hr0, hp0, hv0⟩ := hq 0 (by simp)
  obtain ⟨q1, hr1, hp1, hv1⟩ := hq 1 (by simp)
  obtain ⟨q2, hr2, hp2, hv2⟩ := hq 2 (by simp)
  have hqa := hrest a hne.2.1
  have hqb := hrest b hne.2.2
  exact (H k hk c hcp hce hcw hco m₀ m' f hf q0 q1 q2 hr0 hr1 hr2 (hr 0 (by simp)) hv0 hv1 hv2
    (hA.of_block hqa) (hB.of_block hqb) (hE.buffer (hO.of_block hm₀)) (hx.of_block hqa)
    (hy.of_block hqb) (hFa.of_block hqa) (hFb.of_block hqb) (hE.fits (hFo.of_block hm₀))
    ⟨hp0, hp1, hp2⟩ hE).imp fun _ ⟨hp, hR⟩ => ⟨hp, hR.mono fun _ h => ⟨h, fun _ _ _ => trivial⟩⟩

/-- **The kernel theorem of a binary elementwise kernel from its threads' `Ret`s.** For every
program `prog`, kernel `fn` whose parameters `p0` to `p3` are named `%0` to `%3`, the first three
`byval` of a struct type `T` whose values `.agg [.ptr p, z]` have a codec (`Layout.Codec`) and the
last passed by value as the `i32` `n` (`withAttrs`), alignment `al'` of `T` and of the generic
space's addresses, launch `L`, paths from the entry (`coversEntry`), element type `t` with encoder
`enc`, alignment `al`, block numbers `a`, `b`, `o`, count `n`, tensors `x`, `y`, caller's memory
`m` of `Map2.Pre`, oracle `ω`, cells `cell` of `w` bytes apart (`Apart`) and bytes `bs`: if the
start on `Map2.args z a b o n` succeeds on every address choice at `ω`, and `H` holds, then `fn`
is sound at every address choice and `ω` (`Kernel.Sound`) for the observation of the blocks and
`Elem.Out` (`Kernel.sound_map2With` without `fmul contract`, whose `RetWith false` is `Ret` by
definition). `H`: for every thread `k` of the launch, context of
`prog` with thread `k`'s registers, identity and oracle `ω k`, memories `m₀` and `m'` of `Elem`
after `k` threads, and frame of `fn` whose registers `%0` to `%2` point to blocks `q0` to `q2`
other than `o` from which `T` loads at alignment `al'` as the structs of `a`, `b` and `o`, and
whose `%3` is `n`, on which `a`, `b` and `o` are the buffers of `Map2.Pre` that fit and `a`, `b`
hold `x`, `y`, some path of `paths` from the frame's entry is a `Ret` to `Elem` after `k + 1`
threads. The start gives these facts. It covers the family of kernels with this parameter shape
at one oracle `ω`; `H`, the start on every choice and the codec are the caller's premises, which
`mojo_kernel`'s `map2` clause discharges for one named kernel (`n.ret`, `n.starts`,
`Layout.Codec.ptrArg`). -/
theorem Kernel.sound_map2 {prog : Program} {fn : Func} {L : Launch}
    {paths : List (List (Nat × List Cond × Summary))} (hc : coversEntry prog fn paths = true)
    {p0 p1 p2 p3 : Param} (hps : fn.params = [p0, p1, p2, p3])
    (hn : p0.name = some 0 ∧ p1.name = some 1 ∧ p2.name = some 2 ∧ p3.name = some 3) {T : Ty}
    (hT : p0.byval? = some T ∧ p1.byval? = some T ∧ p2.byval? = some T ∧ p3.byval? = none)
    {z : Val} (hcod : prog.layout.Codec T fun p => .agg [.ptr p, z]) {al' : Nat}
    (hal' : al' ∣ prog.layout.align T ∧ al' ∣ 2 ^ (prog.layout.ptr 0).1)
    {α : Type} [TorchLean.Storage α] {t : Ty} {enc : α → Val} {al a b o n N : Nat}
    {x y : TorchLean.Tensor α [N]} {m : Mem} (hP : Map2.Pre prog.layout t enc al z m a b o n x y)
    (hw : ∀ m', withAttrs prog.layout m' p3.ty p3.attrs (.bits 32 (BitVec.ofNat 32 n)) =
      .ok (.bits 32 (BitVec.ofNat 32 n)))
    {ω : Nat → Nat → Nat}
    (hs : ∀ ch, ∃ g c, Grid.start prog fn L (Map2.args z a b o n) m ch ω = .ok (g, c))
    {w : Nat} {cell : Nat → Nat} (hap : Apart cell w) {bs : Nat → Option (List MemByte)}
    (H : ∀ k, k < volume L.grid * volume L.block → ∀ c : Ctx, c.prog = prog →
      c.env = L.env k → c.who = ⟨k, k / volume L.block⟩ → c.oracle = ω k →
      ∀ (m₀ m' : Mem) (f : Frame), f.fn = fn → ∀ q0 q1 q2 : Nat,
      f.regs 0 = some (.ptr ⟨q0, 0⟩) → f.regs 1 = some (.ptr ⟨q1, 0⟩) →
      f.regs 2 = some (.ptr ⟨q2, 0⟩) → f.regs 3 = some (.bits 32 (BitVec.ofNat 32 n)) →
      m'.load prog.layout c.who 0 T ⟨q0, 0⟩ (some al') = .ok (.agg [.ptr ⟨a, 0⟩, z]) →
      m'.load prog.layout c.who 0 T ⟨q1, 0⟩ (some al') = .ok (.agg [.ptr ⟨b, 0⟩, z]) →
      m'.load prog.layout c.who 0 T ⟨q2, 0⟩ (some al') = .ok (.agg [.ptr ⟨o, 0⟩, z]) →
      m'.Buffer a (n * prog.layout.size t) al false →
      m'.Buffer b (n * prog.layout.size t) al false →
      m'.Buffer o (n * prog.layout.size t) al true →
      m'.Holds prog.layout a t enc (rowMajor prog.layout t 0) x →
      m'.Holds prog.layout b t enc (rowMajor prog.layout t 0) y →
      m'.Fits prog.layout a (n * prog.layout.size t) →
      m'.Fits prog.layout b (n * prog.layout.size t) →
      m'.Fits prog.layout o (n * prog.layout.size t) → q0 ≠ o ∧ q1 ≠ o ∧ q2 ≠ o →
      Elem m₀ o w cell bs k m' →
      ∃ ps ∈ paths, Ret (Valuation.entry c 0 m' f) (Elem m₀ o w cell bs (k + 1)) ps) :
    Kernel.Sound prog fn L (Map2.args z a b o n) m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m o cell bs (volume L.grid * volume L.block)) :=
  Kernel.sound_map2With (contract := false) hc hps hn hT hcod hal' hP hw hs hap H

/-- `Elem.put` after `k + 1` threads: thread `k`'s bytes, if any, put on the block after `k`. -/
theorem Elem.put_succ (cell : Nat → Nat) (bs : Nat → Option (List MemByte)) (k : Nat)
    (x : Sem.Block) : Elem.put cell bs (k + 1) x =
      (bs k).elim (Elem.put cell bs k x) ((Elem.put cell bs k x).put (cell k)) := by
  simp only [Elem.put, List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]

/-- Threads from `n` on that put no bytes leave the block as after `n` threads: for every
`T ≥ n`, `Elem.put` after `T` threads is `Elem.put` after `n`. -/
theorem Elem.put_of_none {bs : Nat → Option (List MemByte)} {n : Nat}
    (hb : ∀ k, n ≤ k → bs k = none) (cell : Nat → Nat) {T : Nat} (hT : n ≤ T) (x : Sem.Block) :
    Elem.put cell bs T x = Elem.put cell bs n x := by
  obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hT
  clear hT
  induction d with
  | zero => rfl
  | succ d ih =>
    show Elem.put cell bs (n + d + 1) x = _
    rw [Elem.put_succ, hb _ (Nat.le_add_right n d)]
    exact ih

/-- **`Elem.Out` at `min n N`**: for every caller's memory, output block, cells, bytes and
blocks `B`, when the threads from `n` on put no bytes, `Elem.Out` after `N` threads gives
`Elem.Out` after `min n N` threads; so when `n ≤ N` (a count at most the number of threads),
block `out` of `B` (if `m` has it) is `m`'s with the bytes of threads `0` to `n - 1` put at
their cells (`Elem.put_of_none`). -/
theorem Elem.Out.min {m : Mem} {out : Nat} {cell : Nat → Nat} {bs : Nat → Option (List MemByte)}
    {N : Nat} {B : Nat → Option Sem.Block} (h : Elem.Out m out cell bs N B) {n : Nat}
    (hb : ∀ k, n ≤ k → bs k = none) : Elem.Out m out cell bs (min n N) B := by
  rcases Nat.le_total n N with hn | hn
  · rw [Nat.min_eq_left hn]
    exact ⟨fun x hx => by rw [h.1 x hx, Elem.put_of_none hb cell hn], h.2⟩
  · rw [Nat.min_eq_right hn]
    exact h

/-- Reading cell `k`'s `w` bytes after `Elem.put` on `x`, for every thread `k` that has bytes,
with the cells of the threads that have bytes `w` apart (`Apart` on their subtype; a thread
without bytes may share a cell) and every thread's bytes `w` long: thread `k`'s bytes if `k < N`,
`x`'s otherwise. -/
theorem Elem.put_read {cell : Nat → Nat} {w : Nat} {bs : Nat → Option (List MemByte)}
    (hap : Apart (fun i : {i // bs i ≠ none} => cell i) w)
    (hl : ∀ k l, bs k = some l → l.length = w) (x : Sem.Block) {k : Nat} (hk : bs k ≠ none) :
    ∀ N, (Elem.put cell bs N x).read (cell k) w =
      if k < N then (bs k).getD (x.read (cell k) w) else x.read (cell k) w
  | 0 => rfl
  | N + 1 => by
    rw [Elem.put_succ]
    have ih := Elem.put_read hap hl x hk N
    cases hN : bs N with
    | none =>
      simp only [Option.elim, ih]
      have : k ≠ N := fun e => hk (e ▸ hN)
      simp only [show k < N + 1 ↔ k < N by omega]
    | some l =>
      simp only [Option.elim]
      by_cases hkN : k = N
      · subst hkN
        rw [← hl _ l hN, Block.read_put_self]
        simp [hN]
      · rw [Block.read_put_apart _ (o := cell N) (o' := cell k) (n := w) l
          (by rw [hl N l hN]; exact hap ⟨k, hk⟩ ⟨N, by simp [hN]⟩ fun e => hkN (congrArg (·.1) e)),
          ih]
        simp only [show k < N + 1 ↔ k < N by omega]

/-! ### `Elem.Out` checked by evaluation, and its canaries -/

/-- Whether blocks `x` and `y` agree on every field but the bytes, and on the bytes at the
offsets below `K`. -/
def Elem.agree (K : Nat) (x y : Sem.Block) : Bool :=
  x.space == y.space && x.size == y.size && x.live == y.live && x.readOnly == y.readOnly &&
    x.owner == y.owner && x.addr == y.addr && x.gaddr == y.gaddr &&
    (List.range K).all fun o => x.bytes o == y.bytes o

/-- Every block agrees with itself at every number of offsets. -/
theorem Elem.agree_self (K : Nat) (x : Sem.Block) : Elem.agree K x x = true := by
  simp [Elem.agree]

/-- `Elem.Out` checked at the blocks below `nb` and the offsets below `K` (`Elem.agree`): every
block `b < nb` that `m` has is a block of `B` that agrees with `Elem.put`'s at `out` and with
`m`'s elsewhere. A closed Boolean, which the kernel evaluates at a concrete memory and
observation; `Elem.Out` passes it (`Elem.Out.outBelow`). -/
def Elem.outBelow (m : Mem) (out : Nat) (cell : Nat → Nat) (bs : Nat → Option (List MemByte))
    (N nb K : Nat) (B : Nat → Option Sem.Block) : Bool :=
  (List.range nb).all fun b => (m.blocks b).all fun x =>
    (B b).any fun y => Elem.agree K y (if b = out then Elem.put cell bs N x else x)

/-- `Elem.Out` passes its check `Elem.outBelow`, at every number of blocks and of offsets. -/
theorem Elem.Out.outBelow {m : Mem} {out : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {N : Nat} {B : Nat → Option Sem.Block}
    (h : Elem.Out m out cell bs N B) (nb K : Nat) :
    Elem.outBelow m out cell bs N nb K B = true := by
  simp only [Elem.outBelow, List.all_eq_true]
  intro b _
  cases hx : m.blocks b with
  | none => rfl
  | some x =>
    by_cases hb : b = out
    · subst hb
      simp [h.1 x hx, Elem.agree_self]
    · simp [h.2 b x hb hx, hb, Elem.agree_self]

/-- Blocks `y` and `x` that `Elem.agree K` accepts (every field but the bytes, and the bytes
below `K`) and whose bytes agree at every offset of at least `K` are equal, for every `K`. -/
theorem Elem.agree_eq {K : Nat} {y x : Sem.Block} (h : Elem.agree K y x = true)
    (hb : ∀ i, K ≤ i → y.bytes i = x.bytes i) : y = x := by
  cases y
  cases x
  simp only [Elem.agree, Bool.and_eq_true, beq_iff_eq, List.all_eq_true, List.mem_range] at h
  obtain ⟨⟨⟨⟨⟨⟨⟨rfl, rfl⟩, rfl⟩, rfl⟩, rfl⟩, rfl⟩, rfl⟩, h8⟩ := h
  congr 1
  funext i
  by_cases hi : i < K
  · exact h8 i hi
  · exact hb i (by omega)

/-- `Elem.put` keeps the bytes outside every cell: for every block `x`, cells, bytes, number of
threads `N` and offset `i` outside the bytes of every thread below `N` (`i < cell k` or
`cell k + l.length ≤ i` for every `k < N` with bytes `l`), `Elem.put cell bs N x` has `x`'s byte
at `i`. -/
theorem Elem.put_out {cell : Nat → Nat} {bs : Nat → Option (List MemByte)} (x : Sem.Block)
    {N i : Nat} (hi : ∀ k < N, ∀ l ∈ bs k, i < cell k ∨ cell k + l.length ≤ i) :
    (Elem.put cell bs N x).bytes i = x.bytes i := by
  induction N with
  | zero => rfl
  | succ N ih =>
    rw [Elem.put_succ]
    have ih := ih fun k hk => hi k (by omega)
    cases hN : bs N with
    | none => exact ih
    | some l =>
      have := hi N (by omega) l (Option.mem_def.2 hN)
      simp only [Option.elim, Sem.Block.put]
      split
      · omega
      · exact ih

/-- `Elem.put` keeps the bytes from offset `K` on: for every block `x`, cells, bytes, offset `K`
and number of threads `N` whose bytes end by `K` (`cell i + l.length ≤ K` for every `i < N`),
`Elem.put cell bs N x` has `x`'s byte at every offset of at least `K` (`Elem.put_out`). -/
theorem Elem.put_above {cell : Nat → Nat} {bs : Nat → Option (List MemByte)} {K : Nat}
    (x : Sem.Block) {N : Nat} (hc : ∀ i < N, ∀ l ∈ bs i, cell i + l.length ≤ K) (o : Nat)
    (ho : K ≤ o) : (Elem.put cell bs N x).bytes o = x.bytes o :=
  Elem.put_out x fun k hk l hl => .inr (le_trans (hc k hk l hl) ho)

/-- **`Elem.Out` from its bounded check** (the converse of `Elem.Out.outBelow`): for every
caller's memory `m`, output block, cells, bytes, number of threads `N`, numbers `nb` of blocks and
`K` of offsets, and blocks `B`, if `B` passes `Elem.outBelow` at `nb` and `K`, `m` has no block
from `nb` on, the bytes of the threads below `N` end by offset `K`, and every block of `m` and
`B`'s block at its number agree from offset `K` on, then `B` is `Elem.Out`'s (`Elem.agree_eq`,
`Elem.put_above`). -/
theorem Elem.Out.of_outBelow {m : Mem} {out : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {N nb K : Nat} {B : Nat → Option Sem.Block}
    (h : Elem.outBelow m out cell bs N nb K B = true)
    (hnb : ∀ b, nb ≤ b → m.blocks b = none)
    (hc : ∀ i < N, ∀ l ∈ bs i, cell i + l.length ≤ K)
    (hK : ∀ b x y, m.blocks b = some x → B b = some y → ∀ i, K ≤ i → y.bytes i = x.bytes i) :
    Elem.Out m out cell bs N B := by
  have key : ∀ b x, m.blocks b = some x →
      B b = some (if b = out then Elem.put cell bs N x else x) := by
    intro b x hx
    have hb : b < nb := Nat.lt_of_not_le fun hb => by rw [hnb b hb] at hx; cases hx
    unfold Elem.outBelow at h
    have hc' := List.all_eq_true.1 h b (List.mem_range.2 hb)
    cases hy : B b with
    | none => simp only [hx, hy, Option.all_some, Option.any_none] at hc'; cases hc'
    | some y =>
      simp only [hx, hy, Option.all_some, Option.any_some] at hc'
      refine congrArg some (Elem.agree_eq hc' fun i hi => ?_)
      rw [hK b x y hx hy i hi]
      split
      · exact (Elem.put_above x hc i hi).symm
      · rfl
  exact ⟨fun x hx => by simpa using key out x hx, fun b x hb hx => by simpa [hb] using key b x hx⟩

/-- **`Elem.Out` at the end of a run, from its bounded check.** For every program, kernel, launch,
arguments, caller's memory `m`, address choice and oracle whose start gives `(g, c)`, grid `z`
that `g` reaches, output block, cells, bytes, and numbers `N` of threads, `nb` of blocks and `K`
of offsets: if `z`'s blocks pass `Elem.outBelow` at `nb` and `K`, `m` has no block from `nb` on,
the bytes of the threads below `N` end by offset `K`, and every block of `m` is owned by no thread
and has at most `K` bytes, then `z`'s blocks are `Elem.Out`'s (`Elem.Out.of_outBelow`, whose
premise on the bytes from `K` on is `Grid.start_reach_above`). -/
theorem Elem.Out.of_run {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g z : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hr : Relation.ReflTransGen (Grid.Step L c) g z) {out : Nat} {cell : Nat → Nat}
    {bs : Nat → Option (List MemByte)} {N nb K : Nat}
    (hb : Elem.outBelow m out cell bs N nb K z.mem.blocks = true)
    (hnb : ∀ b, nb ≤ b → m.blocks b = none) (hc : ∀ i < N, ∀ l ∈ bs i, cell i + l.length ≤ K)
    (hm : ∀ b x, m.blocks b = some x → (∀ w, x.owner ≠ .thread w) ∧ x.size ≤ K) :
    Elem.Out m out cell bs N z.mem.blocks :=
  Elem.Out.of_outBelow hb hnb hc fun b x y hx hy i hi => by
    obtain ⟨x', hx', -, -, hby⟩ :=
      Grid.start_reach_above h hr (Grid.start_blocks h hx) (hm b x hx).1
    rw [hx', Option.some.injEq] at hy
    subst hy
    exact hby i (by have := (hm b x hx).2; omega)

/-- **The canaries of `Elem.Out`** (probes of the observation): the bytes of five wrong
outputs made from the right bytes `bs` of `n` cells of type `t` under layout `l` by the probes of
Sem/Replay.lean, one definition for every kernel: cell 0 omitted (`Probe.drop 0`), the output
left stale (`Probe.stale`), cells 0 and 1 swapped (`Probe.swap 0 1`), `n` cells of `l.stored t`
zero bytes (`Probe.zero`), and the first `n` cells of the input `x` copied under the encoding
`enc` (`Probe.copy`). -/
def Elem.canaries {α : Type} (l : Layout) (t : Ty) (enc : α → Val) {N : Nat}
    (x : TorchLean.Tensor α [N]) (bs : Nat → Option (List MemByte)) (n : Nat) :
    List (Nat → Option (List MemByte)) :=
  [Probe.drop 0 bs, Probe.stale, Probe.swap 0 1 bs, Probe.zero (l.stored t) n,
    Probe.copy l t enc x n]

/-- **The canaries refuted by the trace-replay checker** (`Kernel.replay_block`): for every
program, kernel, launch, arguments, memory `m` with a block `out`, address choice `ch`, oracle
`ω`, fuel, phases, cells, number of threads `T` and canaries `Elem.canaries` (every layout, type,
encoding, input, bytes and count), if for each canary `bs'` the replay that compares block `out`'s
final bytes with those `Elem.Out` fixes for `bs'` reports a violation, the kernel is not sound
for `Elem.Out` with any canary, for every admission that admits `ch` and `ω`. -/
theorem Kernel.replay_canaries {α : Type} {prog : Program} {fn : Func} {L : Launch}
    {args : List Val} {m : Mem} {ch : Nat → Nat} {ω : Nat → Nat → Nat} {fuel phases : Nat}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {l : Layout} {t : Ty} {enc : α → Val}
    {N : Nat} {x : TorchLean.Tensor α [N]} {bs : Nat → Option (List MemByte)} {n out : Nat}
    {cell : Nat → Nat} {T : Nat} (hx : (m.blocks out).isSome = true)
    (h : (Elem.canaries l t enc x bs n).all (fun bs' =>
      (Kernel.replay prog fn L args m ch ω fuel phases (fun m' => Replay.bytes? (m'.blocks out))
        (fun z => some z = Replay.bytes? ((m.blocks out).map (Elem.put cell bs' T)))).bad) = true)
    (hadm : adm ch ω) : ∀ bs' ∈ Elem.canaries l t enc x bs n,
      ¬ Kernel.Sound prog fn L args m adm (fun m => some m.blocks) (Elem.Out m out cell bs' T) :=
  fun bs' hb => Kernel.replay_block (fun _ hB => hB.1) hx (List.all_eq_true.1 h bs' hb) hadm

/-! ### The corollaries of a binary float map -/

/-- `y` is the observation `obs` of a complete run of kernel `fn` at address choice `ch` and
oracle `ω`: the start succeeds, and some schedule reaches from its grid one where every thread
has returned (the core's `Done` at `sig`), whose memory `obs` maps to `y`. -/
def Kernel.Obs {β : Type} (prog : Program) (fn : Func) (L : Launch) (args : List Val) (m : Mem)
    (obs : Mem → Option β) (ch : Nat → Nat) (ω : Nat → Nat → Nat) (y : β) : Prop :=
  ∃ g c g', Grid.start prog fn L args m ch ω = .ok (g, c) ∧
    Relation.ReflTransGen (Grid.Step L c) g g' ∧ GPUProof.Done sig (g', L, c) ∧ obs g'.mem = some y

/-- `Kernel.Sound`'s relation holds of every observation of a complete run (`Kernel.Obs`) at an
admitted address choice and oracle. -/
theorem Kernel.Sound.obs {β : Type} {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {obs : Mem → Option β}
    {R : β → Prop} (h : Kernel.Sound prog fn L args m adm obs R) {ch : Nat → Nat}
    {ω : Nat → Nat → Nat} (ha : adm ch ω) {y : β} (hy : Kernel.Obs prog fn L args m obs ch ω y) :
    R y := by
  obtain ⟨g, c, hs, hS⟩ := h ch ω ha
  obtain ⟨g₁, c₁, g', hs', hr, hd, ho⟩ := hy
  rw [hs] at hs'
  cases hs'
  obtain ⟨y', hy', hR⟩ := hS.post g' hr hd
  rw [ho] at hy'
  cases hy'
  exact hR

section Map2

open FloatLib.Floats.Formats FloatLib.Floats.Formats.BinaryInterchange

/-- **The bytes of a binary float map** under layout `l`, of float type `ft`, operation `op` and
oracle numbers `o`: thread `k` with `k < n` and `k < N` puts the encoding of
`deliver (op x_k y_k) (o k)` (the result of `op` on the inputs' cells `k`, delivered at oracle
number `o k`); the other threads put nothing. `Kernels.vadd.bytes ω` and `Kernels.vmul.bytes ω`
are this at `Model.add` and `Model.mul` with `o k = ω k (Nat.pair 23 0) / 3`, by definition. -/
def Elem.map2 (l : Layout) (ft : FloatTy) (op : Model ft.fmt → Model ft.fmt → Model ft.fmt)
    (o : Nat → Nat) {N : Nat} (x y : TorchLean.Tensor (Model ft.fmt) [N]) (n k : Nat) :
    Option (List MemByte) :=
  if h : k < n ∧ k < N then
    l.encode (.fp ft) (.ofFloat ft
      (deliver (op (x (⟨k, h.2⟩, PUnit.unit)) (y (⟨k, h.2⟩, PUnit.unit))) (o k)))
  else none

/-- `Elem.map2` puts nothing from thread `n` on. -/
theorem Elem.map2_none {l : Layout} {ft : FloatTy}
    {op : Model ft.fmt → Model ft.fmt → Model ft.fmt} {o : Nat → Nat} {N : Nat}
    {x y : TorchLean.Tensor (Model ft.fmt) [N]} {n k : Nat} (hk : n ≤ k) :
    Elem.map2 l ft op o x y n k = none := by
  unfold Elem.map2
  split
  · rename_i h
    exact absurd h.1 (by omega)
  · rfl

/-- The float of type `ft` that cell `cell k` of block `out` of blocks `B` holds under layout `l`:
its `l.stored (.fp ft)` bytes decoded (`Layout.decode`) and read as a float (`Val.float?`); `none`
if `B` has no block `out` or the bytes decode to no float. -/
def Elem.word (l : Layout) (ft : FloatTy) (out : Nat) (cell : Nat → Nat)
    (B : Nat → Option Sem.Block) (k : Nat) : Option (Model ft.fmt) :=
  (B out).bind fun x => (l.decode (.fp ft) (x.read (cell k) (l.stored (.fp ft)))).bind (·.float? ft)

/-- The encoding of a float, if any, is `l.stored (.fp ft)` bytes long and decodes back to it
(`Layout.Codec.float`). -/
theorem Elem.encode_float {l : Layout} {ft : FloatTy} {v : Model ft.fmt} {b : List MemByte}
    (h : l.encode (.fp ft) (.ofFloat ft v) = some b) :
    b.length = l.stored (.fp ft) ∧ l.decode (.fp ft) b = some (.ofFloat ft v) := by
  obtain ⟨b', he, hl, hd⟩ := (Layout.Codec.float l ft).round v
  rw [he] at h
  cases h
  exact ⟨hl, hd⟩

/-- **The float at a cell of `Elem.Out` for `Elem.map2`'s bytes.** For every memory `m` with a
block `out`, cells `l.stored (.fp ft)` bytes apart, and blocks `B` that meet `Elem.Out` after `M`
threads for `Elem.map2`'s bytes: every thread `k` below `n`, `N` and `M` leaves at its cell
(`Elem.word`) the result of `op` on the inputs' cells `k` delivered at its oracle number
(`Elem.put_read`, `Elem.encode_float`). -/
theorem Elem.Out.map2_word {m : Mem} {out : Nat} {cell : Nat → Nat} {l : Layout} {ft : FloatTy}
    {op : Model ft.fmt → Model ft.fmt → Model ft.fmt} {o : Nat → Nat} {N : Nat}
    {x y : TorchLean.Tensor (Model ft.fmt) [N]} {n M : Nat} {B : Nat → Option Sem.Block}
    (h : Elem.Out m out cell (Elem.map2 l ft op o x y n) M B) (hb : ∃ blk, m.blocks out = some blk)
    (hap : Apart cell (l.stored (.fp ft))) {k : Nat} (hk : k < n) (hkN : k < N) (hkM : k < M) :
    Elem.word l ft out cell B k =
      some (deliver (op (x (⟨k, hkN⟩, PUnit.unit)) (y (⟨k, hkN⟩, PUnit.unit))) (o k)) := by
  obtain ⟨blk, hb⟩ := hb
  have hl : ∀ k b, Elem.map2 l ft op o x y n k = some b → b.length = l.stored (.fp ft) :=
    fun k b hb => by
      unfold Elem.map2 at hb
      split at hb
      · exact (Elem.encode_float hb).1
      · cases hb
  obtain ⟨b, he, -, hd⟩ := (Layout.Codec.float l ft).round
    (deliver (op (x (⟨k, hkN⟩, PUnit.unit)) (y (⟨k, hkN⟩, PUnit.unit))) (o k))
  have e : Elem.map2 l ft op o x y n k = some b := by
    unfold Elem.map2
    split
    · exact he
    · rename_i h
      exact absurd ⟨hk, hkN⟩ h
  simp [Elem.word, h.1 blk hb,
    Elem.put_read (hap.comp Subtype.val_injective) hl blk (k := k) (by simp [e]) M, hkM, e, hd]

/-- A result delivered as a finite word is not a NaN, for every oracle number (`isNaN_deliver`). -/
theorem isNaN_eq_false_of_deliver {fmt : FloatFormat} {r : Model fmt} {n : Nat}
    (h : (deliver r n).isFinite = true) : r.isNaN = false := by
  cases hr : r.isNaN
  · rfl
  · rw [Model.isFinite_eq_false_of_isNaN (isNaN_deliver hr n)] at h
    cases h

/-- **`Elem.Out` after `min n T` threads, for a binary float map.** For every program, kernel,
launch, arguments, memory, admission, output block, cells, layout, float type, operation, oracle
numbers, tensors, count `n` and number `T`: `Kernel.Sound` for `Elem.Out` after `T` threads with
`Elem.map2`'s bytes gives it after `min n T` threads (`Elem.Out.min`, `Elem.map2_none`,
`Kernel.Sound.map`), since threads from `n` on put nothing; when `n ≤ T` that is `Elem.Out`
after the `n` threads `0` to `n - 1`. It covers every kernel with such a theorem. -/
theorem Kernel.map2_min {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {out : Nat} {cell : Nat → Nat} {l : Layout}
    {ft : FloatTy} {op : Model ft.fmt → Model ft.fmt → Model ft.fmt} {o : Nat → Nat} {N : Nat}
    {x y : TorchLean.Tensor (Model ft.fmt) [N]} {n T : Nat}
    (h : Kernel.Sound prog fn L args m adm (fun m => some m.blocks)
      (Elem.Out m out cell (Elem.map2 l ft op o x y n) T)) :
    Kernel.Sound prog fn L args m adm (fun m => some m.blocks)
      (Elem.Out m out cell (Elem.map2 l ft op o x y n) (min n T)) :=
  h.map (f := some) fun _ hB => ⟨_, rfl, hB.min fun _ hk => Elem.map2_none hk⟩

/-- **A finite output float is the operation's result, for a binary float map.** For every
program, kernel, launch, arguments, memory `m` with a block `out`, admission, cells
`l.stored (.fp ft)` bytes apart, layout, float type, operation `op`, oracle numbers, tensors `x`,
`y`, count `n` and number `T`, if the kernel is sound (`Kernel.Sound`) for `Elem.Out` after `T`
threads with `Elem.map2`'s bytes, then at every admitted address choice and oracle, every
observation of a complete run (`Kernel.Obs`) holds a float at the cell of every thread `k` below
`n`, `N` and `T`, and where that float is finite it is `op x_k y_k`, the operation on the inputs'
cells `k` (the oracle only chooses NaNs; `deliver`). It covers every kernel with such a
theorem. -/
theorem Kernel.map2_real {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop} {out : Nat} {cell : Nat → Nat} {l : Layout}
    {ft : FloatTy} {op : Model ft.fmt → Model ft.fmt → Model ft.fmt} {o : Nat → Nat} {N : Nat}
    {x y : TorchLean.Tensor (Model ft.fmt) [N]} {n T : Nat}
    (h : Kernel.Sound prog fn L args m adm (fun m => some m.blocks)
      (Elem.Out m out cell (Elem.map2 l ft op o x y n) T))
    (hb : ∃ blk, m.blocks out = some blk) (hap : Apart cell (l.stored (.fp ft)))
    {ch : Nat → Nat} {ω : Nat → Nat → Nat} (ha : adm ch ω) {B : Nat → Option Sem.Block}
    (hB : Kernel.Obs prog fn L args m (fun m => some m.blocks) ch ω B) {k : Nat} (hk : k < n)
    (hkN : k < N) (hkT : k < T) : ∃ v, Elem.word l ft out cell B k = some v ∧
      (v.isFinite = true → v = op (x (⟨k, hkN⟩, PUnit.unit)) (y (⟨k, hkN⟩, PUnit.unit))) :=
  ⟨_, (Kernel.Sound.obs h ha hB).map2_word hb hap hk hkN hkT,
    fun hf => deliver_of_isNaN_eq_false (isNaN_eq_false_of_deliver hf) _⟩

/-- **Two runs' output floats are equal up to `FinEq`, for a binary float map.** For every
program, kernel, launch, arguments, memory `m` with a block `out`, cells `l.stored (.fp ft)`
bytes apart, layout, float type, operation, oracle numbers `o ω` of each oracle `ω`, tensors,
count `n` and number `T`, if the kernel is sound at every oracle `ω` (and every address choice)
for `Elem.Out` after `T` threads with `Elem.map2`'s bytes at `o ω`, then the observations of
complete runs at any two address choices and oracles hold, at the cell of every thread `k` below
`n`, `N` and `T`, floats equal up to `FinEq` (`FinEq.deliver`). It covers every kernel with
such a theorem. -/
theorem Kernel.map2_finEq {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {out : Nat} {cell : Nat → Nat} {l : Layout} {ft : FloatTy}
    {op : Model ft.fmt → Model ft.fmt → Model ft.fmt} {o : (Nat → Nat → Nat) → Nat → Nat}
    {N : Nat} {x y : TorchLean.Tensor (Model ft.fmt) [N]} {n T : Nat}
    (h : ∀ ω, Kernel.Sound prog fn L args m (fun _ ω' => ω' = ω) (fun m => some m.blocks)
      (Elem.Out m out cell (Elem.map2 l ft op (o ω) x y n) T))
    (hb : ∃ blk, m.blocks out = some blk) (hap : Apart cell (l.stored (.fp ft)))
    {ch ch' : Nat → Nat} {ω ω' : Nat → Nat → Nat} {B B' : Nat → Option Sem.Block}
    (hB : Kernel.Obs prog fn L args m (fun m => some m.blocks) ch ω B)
    (hB' : Kernel.Obs prog fn L args m (fun m => some m.blocks) ch' ω' B') {k : Nat}
    (hk : k < n) (hkN : k < N) (hkT : k < T) : ∃ v v', Elem.word l ft out cell B k = some v ∧
      Elem.word l ft out cell B' k = some v' ∧ FinEq v v' :=
  ⟨_, _, (Kernel.Sound.obs (h ω) rfl hB).map2_word hb hap hk hkN hkT,
    (Kernel.Sound.obs (h ω') rfl hB').map2_word hb hap hk hkN hkT, FinEq.deliver (.inl rfl) _ _⟩

/-- **A word `FinEq` to a finite word is equal to it**, for every FloatLib format. With
`Kernel.map2_finEq`: a finite output float of a binary float map is the same at every address
choice and oracle. -/
theorem _root_.MojoProof.Sem.FinEq.eq_of_isFinite {fmt : FloatFormat} {v v' : Model fmt}
    (h : FinEq v v') (hf : v.isFinite = true) : v' = v :=
  (GPUProof.UpToNaN.eq h (by simp [hf])).symm

end Map2

end MojoProof.Sym
