import MojoProof.Sym.Kernel
import MojoProof.Sym.OblLemmas
import MojoProof.Sem.Index

/-!
# The kernel theorem of a matmul kernel from its threads' runs

docs/proofs/kernel.md. `Kernel.sound_mat`: for every flag `contract`, program, kernel whose
parameters are three `byval` structs (the output `o`, the inputs `a`, `b`) then three `i32`
scalars `m`, `n`, `K`, the one at each position `j` named `%j`, launch valid with `z` sides 1,
paths, sequences of loops, element type, encoder, alignment, block numbers, sizes, row strides,
tensors, caller's memory with the memory premises of `Mat.Pre` (Sem/Precond.lean) but for
`a ≠ b` and `K`'s bounds, admission, cell width and bytes: `Kernel.Sound` on `Mat.args` for the
observation of the blocks and `Elem.Out` at the cells `(row * sC + column) * w` of the threads in
the window and the matrix, from the start on every admitted choice and the threads' runs, given
as two premises on the facts the start gives each thread (`Mat.Entry`): a thread in bounds runs
some sequence of loops to `ret` (`RetLsWith`), a thread out of bounds takes some path to `ret`
(`RetWith`). It is `Kernel.sound_mapNWith` at the three structs and scalars, with the cells apart
by `Launch.apart_xy`.

`RetWith.of_first` gives the second premise's run for a path whose blocks after the first have
no effects, from its premises (`WalkWith`) and three facts decided on the path; the `mat` clause
of `mojo_kernel` (Sym/KernelCmd.lean) proves the out-of-bounds run with it. Its instance is
`NaiveSound.naive_sound` (MojoProofTest/NaiveSound.lean), the naive matmul kernel.

`RetLsWith.of_inv` gives the first premise's run for a sequence of one loop with no nested loop,
from the edge into the loop, an invariant indexed by the round at the round's step count, and
the path out at the trip count; `NaiveThread.thread_run` (MojoProofTest/NaiveThread.lean) is its
instance at the naive kernel. `LoopInvWith` gathers those three facts after the edge (from the
facts at the heads of the rounds alone by `LoopIterWith.toInv`, Sym/KernelIter.lean), and
`Mat.Thread` the facts of one thread in bounds (its oracles, index, entry facts and bounds): the
`mat … inv` clause states `n.runInv` and `n.sound_inv` over `LoopIterWith`, and `n.sound_inv`'s
premise at each `Mat.Thread`.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **The facts the start gives a thread of a matmul kernel, on its memory.** For program
`prog`, kernel `fn`, launch `L`, struct type `T` whose tail value is `z`, loaded at alignment
`al'`, element type `t` with encoder `enc`, alignment `al`, block numbers `o` (output), `a`,
`b` (inputs), size `K`, row stride `sC`, tensors `x` (`m × sA`) and `y` (`n × sB`), thread `k`,
context `c`, blocks `q0`, `q1`, `q2`, memory `m'` and frame `f`: `c` is thread `k`'s context of
`prog` (its program, special registers and identity), `f` is a frame of `fn` whose registers
`%0`, `%1`, `%2` point at offset 0 of `q0`, `q1`, `q2`, none of them `o`, from which `T` loads
on `m'` as the structs of `o`, `a`, `b`, and whose `%3`, `%4`, `%5` are the `i32` words of `m`,
`n`, `K`; on `m'`, `a` and `b` are read-only buffers of `m * sA` and `n * sB` elements that fit
their spaces and hold `x` and `y` row-major, and `o` is a writable buffer of `m * sC` elements
that fits its space. `Kernel.sound_mat`'s two per-thread premises take it. -/
structure Mat.Entry (prog : Program) (fn : Func) (L : Launch) (T : Ty) (z : Val) (al' : Nat)
    {α : Type} [TorchLean.Storage α] (t : Ty) (enc : α → Val) (al o a b K sC : Nat)
    {m n sA sB : Nat} (x : TorchLean.Tensor α [m, sA]) (y : TorchLean.Tensor α [n, sB])
    (k : Nat) (c : Ctx) (q0 q1 q2 : Nat) (m' : Mem) (f : Frame) : Prop where
  /-- Builds `Mat.Entry` from its fields. -/
  mk ::
  /-- `c` is thread `k`'s context of `prog`: its program, special registers and identity. -/
  ctx : c.prog = prog ∧ c.env = L.env k ∧ c.who = ⟨k, k / volume L.block⟩
  /-- `f` is a frame of `fn`. -/
  func : f.fn = fn
  /-- `%0`, `%1`, `%2` point at offset 0 of the blocks `q0`, `q1`, `q2`, none of them `o`. -/
  ptrs : f.regs 0 = some (.ptr ⟨q0, 0⟩) ∧ f.regs 1 = some (.ptr ⟨q1, 0⟩) ∧
    f.regs 2 = some (.ptr ⟨q2, 0⟩) ∧ q0 ≠ o ∧ q1 ≠ o ∧ q2 ≠ o
  /-- The structs at `q0`, `q1`, `q2` load from `m'` as the structs of `o`, `a`, `b`. -/
  loads : m'.load prog.layout c.who 0 T ⟨q0, 0⟩ (some al') = .ok (.agg [.ptr ⟨o, 0⟩, z]) ∧
    m'.load prog.layout c.who 0 T ⟨q1, 0⟩ (some al') = .ok (.agg [.ptr ⟨a, 0⟩, z]) ∧
    m'.load prog.layout c.who 0 T ⟨q2, 0⟩ (some al') = .ok (.agg [.ptr ⟨b, 0⟩, z])
  /-- `%3`, `%4`, `%5` are the 32-bit words of `m`, `n` and `K`. -/
  scalars : f.regs 3 = some (.bits 32 (BitVec.ofNat 32 m)) ∧
    f.regs 4 = some (.bits 32 (BitVec.ofNat 32 n)) ∧
    f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K))
  /-- On `m'`, `a` is a read-only buffer of `m * sA` elements aligned to `al` that fits its
  space and holds `x` row-major from offset 0. -/
  bufA : m'.Buffer a (m * sA * prog.layout.size t) al false ∧
    m'.Fits prog.layout a (m * sA * prog.layout.size t) ∧
    m'.Holds prog.layout a t enc (rowMajor prog.layout t 0) x
  /-- On `m'`, `b` is a read-only buffer of `n * sB` elements aligned to `al` that fits its
  space and holds `y` row-major from offset 0. -/
  bufB : m'.Buffer b (n * sB * prog.layout.size t) al false ∧
    m'.Fits prog.layout b (n * sB * prog.layout.size t) ∧
    m'.Holds prog.layout b t enc (rowMajor prog.layout t 0) y
  /-- On `m'`, `o` is a writable buffer of `m * sC` elements aligned to `al` that fits its
  space. -/
  bufC : m'.Buffer o (m * sC * prog.layout.size t) al true ∧
    m'.Fits prog.layout o (m * sC * prog.layout.size t)

/-- **The kernel theorem of a matmul kernel from its threads' runs, with or without
`fmul contract`.** For every flag `contract`, program `prog`, kernel `fn` whose parameters are
`p0` to `p5`, the one at each position `j` named `%j`, `p0`, `p1`, `p2` `byval` of a struct type
`T` whose values `.agg [.ptr p, z]` have a codec (`Layout.Codec`) and `p3`, `p4`, `p5` not
`byval`, alignment `al'` of `T` and of the generic space's addresses, launch `L` valid with `z`
sides 1, paths from the entry (`coversEntryWith contract`), sequences of loops from the entry
(`coversChainsWith contract`), sizes `m`, `n`, `K` whose `i32` words `p3`, `p4`, `p5`'s attributes
keep on every memory, element type `t` with encoder `enc`, alignment `al`, block numbers `o`
(output), `a`, `b` (inputs), row strides `sA`, `sB`, `sC` with `n ≤ sC`, tensors `x` (`m × sA`)
and `y` (`n × sB`), caller's memory `mem` closed for `Mat.args z o a b m n K` on which `a` and
`b` are read-only buffers other than `o` holding `x` and `y` row-major and `o` a writable buffer
of `m * sC` elements, the three fitting their spaces, admission `adm`, cell width `w` and bytes
`bs`: if the start succeeds on every admitted choice and oracle, and `Hin` and `Hout` hold, then
`fn` is sound on `Mat.args z o a b m n K` (`Kernel.Sound`) for the observation of the blocks and
`Elem.Out` of `mem`'s block `o` at the cells `(L.index k .x * sC + L.index k .y) * w`.

`Hin` and `Hout`: for every admitted choice and oracle, thread `k` (in `Hin` in the window and
the matrix: `k` below the thread count, its row `L.index k .x < m` and its column
`L.index k .y < n`; in `Hout` a thread of the launch that is not), blocks `q0`, `q1`, `q2`,
context `c` with thread `k`'s oracle, memories `m₀` and `m'` and frame `f` with the facts the
start gives the thread (`Mat.Entry`: the context, the frame's kernel, its struct pointers to
`q0`, `q1`, `q2` other than `o` and their loads at alignment `al'` as the structs of `o`, `a`,
`b`, its scalar registers, and on `m'` the buffers of `mem`, fitting, `a` and `b` holding `x` and
`y`), if `m'` meets `Elem` after `k` threads (from `m₀`) and its accesses to `o` are by threads
in bounds (`Elem.Only`), then the thread runs to `ret` with a memory that meets `Elem` after
`k + 1` threads and whose accesses to `o` are by threads in bounds: in `Hin` through some
sequence of loops of `chains` (`RetLsWith contract`), in `Hout` along some path of `paths`
(`RetWith contract`).

The proof is `Kernel.sound_mapNWith` at the structs of `o`, `a`, `b` and the three scalars, with
the cells apart by `Launch.apart_xy` and the buffers moved to `m'` by the `of_block` lemmas,
`Elem.buffer` and `Elem.fits`. It covers the family of kernels with this parameter shape at
every launch valid with `z` sides 1; the codec, the start, `Hin` and `Hout` are the caller's
premises. -/
theorem Kernel.sound_mat {contract : Bool} {prog : Program} {fn : Func} {L : Launch}
    (hL : L.Valid) (hz : L.grid .z = 1 ∧ L.block .z = 1)
    {paths : List (List (Nat × List Cond × Summary))} {chains : List LoopChain}
    (hc : coversEntryWith contract prog fn paths = true)
    (hcL : coversChainsWith contract prog fn chains = true) {p0 p1 p2 p3 p4 p5 : Param}
    (hps : fn.params = [p0, p1, p2, p3, p4, p5])
    (hn : ∀ j (p : Param), fn.params[j]? = some p → p.name = some j) {T : Ty}
    (hT : p0.byval? = some T ∧ p1.byval? = some T ∧ p2.byval? = some T)
    (hsc : p3.byval? = none ∧ p4.byval? = none ∧ p5.byval? = none)
    {z : Val} (hcod : prog.layout.Codec T fun p => .agg [.ptr p, z]) {al' : Nat}
    (hal' : al' ∣ prog.layout.align T ∧ al' ∣ 2 ^ (prog.layout.ptr 0).1) {m n K : Nat}
    (hw : ∀ m', withAttrs prog.layout m' p3.ty p3.attrs (.bits 32 (BitVec.ofNat 32 m)) =
        .ok (.bits 32 (BitVec.ofNat 32 m)) ∧
      withAttrs prog.layout m' p4.ty p4.attrs (.bits 32 (BitVec.ofNat 32 n)) =
        .ok (.bits 32 (BitVec.ofNat 32 n)) ∧
      withAttrs prog.layout m' p5.ty p5.attrs (.bits 32 (BitVec.ofNat 32 K)) =
        .ok (.bits 32 (BitVec.ofNat 32 K)))
    {α : Type} [TorchLean.Storage α] {t : Ty} {enc : α → Val} {al o a b sA sB sC : Nat}
    {x : TorchLean.Tensor α [m, sA]} {y : TorchLean.Tensor α [n, sB]} {mem : Mem}
    (hC : mem.Closed (Mat.args z o a b m n K)) (hne : a ≠ o ∧ b ≠ o)
    (hbuf : mem.Buffer a (m * sA * prog.layout.size t) al false ∧
      mem.Buffer b (n * sB * prog.layout.size t) al false ∧
      mem.Buffer o (m * sC * prog.layout.size t) al true)
    (hx : mem.Holds prog.layout a t enc (rowMajor prog.layout t 0) x)
    (hy : mem.Holds prog.layout b t enc (rowMajor prog.layout t 0) y) (hsC : n ≤ sC)
    (hfit : mem.Fits prog.layout a (m * sA * prog.layout.size t) ∧
      mem.Fits prog.layout b (n * sB * prog.layout.size t) ∧
      mem.Fits prog.layout o (m * sC * prog.layout.size t))
    {adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop}
    (hs : ∀ ch oracle, adm ch oracle → ∃ g c, Grid.start prog fn L (Mat.args z o a b m n K) mem
      ch oracle = .ok (g, c))
    {w : Nat} {bs : Nat → Option (List MemByte)}
    (Hin : ∀ ch oracle, adm ch oracle → ∀ k q0 q1 q2 (c : Ctx) (m₀ m' : Mem) (f : Frame),
      (k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n) →
      c.oracle = oracle k → Mat.Entry prog fn L T z al' t enc al o a b K sC x y k c q0 q1 q2 m' f →
      Elem m₀ o w (fun k => (L.index k .x * sC + L.index k .y) * w) bs k m' →
      Elem.Only o (fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
        L.index k .y < n) m' →
      ∃ C ∈ chains, RetLsWith contract
        (fun me => Elem m₀ o w (fun k => (L.index k .x * sC + L.index k .y) * w) bs (k + 1) me ∧
          Elem.Only o (fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
            L.index k .y < n) me)
        C.loops (Valuation.entry c 0 m' f) C.l C.ds C.S C.E)
    (Hout : ∀ ch oracle, adm ch oracle → ∀ k q0 q1 q2 (c : Ctx) (m₀ m' : Mem) (f : Frame),
      k < volume L.grid * volume L.block →
      ¬ (k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n) →
      c.oracle = oracle k → Mat.Entry prog fn L T z al' t enc al o a b K sC x y k c q0 q1 q2 m' f →
      Elem m₀ o w (fun k => (L.index k .x * sC + L.index k .y) * w) bs k m' →
      Elem.Only o (fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
        L.index k .y < n) m' →
      ∃ ps ∈ paths, RetWith contract (Valuation.entry c 0 m' f)
        (fun me => Elem m₀ o w (fun k => (L.index k .x * sC + L.index k .y) * w) bs (k + 1) me ∧
          Elem.Only o (fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
            L.index k .y < n) me) ps) :
    Kernel.Sound prog fn L (Mat.args z o a b m n K) mem adm (fun m => some m.blocks)
      (Elem.Out mem o (fun k => (L.index k .x * sC + L.index k .y) * w) bs
        (volume L.grid * volume L.block)) := by
  obtain ⟨hA, hB, hO⟩ := hbuf
  obtain ⟨hFa, hFb, hFo⟩ := hfit
  refine Kernel.sound_mapNWith (ps := [p0, p1, p2])
    (sc := [(p3, .bits 32 (BitVec.ofNat 32 m), .bits 32 (BitVec.ofNat 32 m)),
      (p4, .bits 32 (BitVec.ofNat 32 n), .bits 32 (BitVec.ofNat 32 n)),
      (p5, .bits 32 (BitVec.ofNat 32 K), .bits 32 (BitVec.ofNat 32 K))])
    (bl := [o, a, b]) (w := w) (cell := fun k => (L.index k .x * sC + L.index k .y) * w)
    (S := fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n)
    hc hcL hps hn
    (fun _ h => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at h
      rcases h with rfl | rfl | rfl
      exacts [hT.1, hT.2.1, hT.2.2])
    (fun _ h => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at h
      rcases h with rfl | rfl | rfl
      exacts [hsc.1, hsc.2.1, hsc.2.2])
    hcod hal' rfl
    (fun _ h m' => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at h
      rcases h with rfl | rfl | rfl
      exacts [(hw m').1, (hw m').2.1, (hw m').2.2])
    hC.bytesIn (by obtain ⟨xo, hxo, -, -, hown, -⟩ := hO; exact ⟨xo, hxo, hown⟩) hs
    (Launch.apart_xy hL hz hsC w) ?_
  intro ch oracle ha k hk c hcp hce hcw hco m₀ m' f hf hq hr hrest hm₀ hE hOn
  obtain ⟨q0, hr0, hp0, hv0⟩ := hq 0 (by simp)
  obtain ⟨q1, hr1, hp1, hv1⟩ := hq 1 (by simp)
  obtain ⟨q2, hr2, hp2, hv2⟩ := hq 2 (by simp)
  have hqa := hrest a hne.1
  have hqb := hrest b hne.2
  have h : Mat.Entry prog fn L T z al' t enc al o a b K sC x y k c q0 q1 q2 m' f :=
    ⟨⟨hcp, hce, hcw⟩, hf, ⟨hr0, hr1, hr2, hp0, hp1, hp2⟩, ⟨hv0, hv1, hv2⟩,
      ⟨hr 0 (by simp), hr 1 (by simp), hr 2 (by simp)⟩,
      ⟨hA.of_block hqa, hFa.of_block hqa, hx.of_block hqa⟩,
      ⟨hB.of_block hqb, hFb.of_block hqb, hy.of_block hqb⟩,
      ⟨hE.buffer (hO.of_block hm₀), hE.fits (hFo.of_block hm₀)⟩⟩
  by_cases hS : k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n
  · exact .inr (Hin ch oracle ha k q0 q1 q2 c m₀ m' f hS hco h hE hOn)
  · exact .inl (Hout ch oracle ha k q0 q1 q2 c m₀ m' f hk hS hco h hE hOn)

/-- The exit of a path's last block, at its entry valuation (`Valuation.lastWith`), is the exit
of the summary of the path's last element, for every flag, valuation, first block and rest of
the path. -/
theorem Valuation.lastWith_exit (contract : Bool) (V : Valuation) (l : Nat) (ds : List Cond)
    (S : Summary) (ps : List (Nat × List Cond × Summary)) :
    some (V.lastWith contract l S ps).2.2.exit =
      ((l, ds, S) :: ps).getLast?.map (·.2.2.exit) := by
  induction ps generalizing V l ds S with
  | nil => rfl
  | cons p ps ih =>
    obtain ⟨l', ds', S'⟩ := p
    rw [List.getLast?_cons_cons]
    exact ih (V.intoWith contract l S) l' ds' S'

/-- **A path whose blocks after the first have no effects ends on the first block's memory**:
for every flag, valuation, first block `(l, S)` and nonempty rest `p :: ps` whose blocks have no
effects, the last block has no effects and its entry valuation (`Valuation.lastWith`) has the
memory after `S` (`Valuation.after`). -/
theorem Valuation.lastWith_noEffs (contract : Bool) : ∀ (V : Valuation) (l : Nat) (S : Summary)
    (p : Nat × List Cond × Summary) (ps : List (Nat × List Cond × Summary)),
    (∀ b ∈ p :: ps, b.2.2.effs = []) →
    (V.lastWith contract l S (p :: ps)).2.2.effs = [] ∧
      (V.lastWith contract l S (p :: ps)).1.mem = (V.after S).mem
  | V, l, S, (_, _, _), [], h =>
    ⟨h _ (List.mem_singleton_self _), Valuation.intoWith_mem contract V l S⟩
  | V, l, S, (l', ds', S'), p' :: ps, h =>
    have e : S'.effs = [] := h (l', ds', S') List.mem_cons_self
    let ⟨e', hm⟩ := Valuation.lastWith_noEffs contract (V.intoWith contract l S) l' S' p' ps
      fun b hb => h b (List.mem_cons_of_mem _ hb)
    ⟨e', hm.trans ((Valuation.after_mem (me := (V.intoWith contract l S).mem)
      (by rw [e]; rfl)).trans (Valuation.intoWith_mem contract V l S))⟩

/-- **A path to `ret` whose blocks after the first have no effects.** For every flag
`contract`, valuation `V`, predicate `Q` on memories, first block `(l, ds, S)` and rest `ps`: if
the first block's obligations `ds` include that `S`'s effects run (`Cond.mem S.effs`), the blocks
of `ps` have no effects and the path's last block returns (`hp`, three facts decided on a
concrete path), the path's premises hold at `V` (`WalkWith contract`), and `Q` holds of every
memory that `S`'s effects give from `V`, then the path runs from `V` to `ret` with a memory of
`Q` (`RetWith contract`). -/
theorem RetWith.of_first {contract : Bool} {V : Valuation} {Q : Mem → Prop} {l : Nat}
    {ds : List Cond} {S : Summary} {ps : List (Nat × List Cond × Summary)}
    (hp : Cond.mem S.effs ∈ ds ∧ (∀ b ∈ ps, b.2.2.effs = []) ∧
      ((l, ds, S) :: ps).getLast?.map (·.2.2.exit) = some .ret)
    (hW : WalkWith contract V ((l, ds, S) :: ps))
    (hQ : ∀ me, SEff.run V (vals V S.nodes) S.effs = .ok me → Q me) :
    RetWith contract V Q ((l, ds, S) :: ps) := by
  cases ps with
  | nil =>
    obtain ⟨me, hme⟩ := hW _ hp.1
    exact ⟨hW, Option.some.inj hp.2.2, me, hme, hQ me hme⟩
  | cons p ps =>
    obtain ⟨l', ds', S'⟩ := p
    obtain ⟨me, hme⟩ := hW.1 _ hp.1
    obtain ⟨e, hm⟩ := Valuation.lastWith_noEffs contract V l S (l', ds', S') ps hp.2.1
    refine ⟨hW, Option.some.inj ((Valuation.lastWith_exit contract V l ds S _).trans hp.2.2),
      me, ?_, hQ me hme⟩
    exact (congrArg (SEff.run _ _) e).trans
      (congrArg Except.ok (hm.trans (Valuation.after_mem hme)))

/-- **A thread's run through one loop from an invariant, with or without `fmul contract`.** For
every flag `contract`, predicate `Q` on memories, loop `L` with no nested loop
(`L.inner = []`), path `(l, ds, S) :: E` before it, valuation `V`, trip count `n` and invariant
`I` indexed by the round, let `V₀` be the header's entry valuation after the path,
`Valuation.roundWith contract l S E V`. Suppose:

* `hE`: the path's premises hold at `V` and its last edge goes to `L.h` at position `L.p`
  (`EdgeWith contract`);
* `h0`: `I 0` holds at `V₀`;
* `hR`: for every round `i < n`, every valuation `W` with `V`'s context and the step count of
  round `i`, `V₀.k + i * (pathLen L.H L.B + 1)`, at which `I i` holds meets the premises of a
  round (`RoundWith contract`), and `I (i + 1)` holds after the round;
* `hX`: every valuation `W` with `V`'s context and the step count of round `n` at which `I n`
  holds runs the path out of the loop to `ret` with a memory of `Q` (`RetWith contract`).

Then the thread runs from `V` through the loop to `ret` with a memory of `Q`
(`RetLsWith contract Q [L]`). The context and the step count let a round's floating-point
operations name their oracle numbers. The proof is `Round.of_inv` on `I` with the context and
the step count (`Valuation.roundWith_k`), then `ChainWith.of_rounds` with the path out as
`ChainWith.last`. It covers every program and every loop without a nested loop that is the one
loop of a thread's sequence of loops; a sequence of several loops, or a nested loop, is
`ChainWith.loop` with one invariant per loop. -/
theorem RetLsWith.of_inv {contract : Bool} {Q : Mem → Prop} {L : LoopSeg} (hL : L.inner = [])
    {V : Valuation} {l : Nat} {ds : List Cond} {S : Summary}
    {E : List (Nat × List Cond × Summary)} (n : Nat) (I : Nat → Valuation → Prop)
    (hE : EdgeWith contract L.h L.p V l ds S E)
    (h0 : I 0 (Valuation.roundWith contract l S E V))
    (hR : ∀ i < n, ∀ W, W.ctx = V.ctx →
      W.k = (Valuation.roundWith contract l S E V).k + i * (pathLen L.H L.B + 1) → I i W →
      RoundWith contract L.h L.p L.dh L.H L.B W ∧
        I (i + 1) (Valuation.roundWith contract L.h L.H L.B W))
    (hX : ∀ W, W.ctx = V.ctx →
      W.k = (Valuation.roundWith contract l S E V).k + n * (pathLen L.H L.B + 1) → I n W →
      RetWith contract W Q ((L.h, L.dh, L.H) :: L.X)) :
    RetLsWith contract Q [L] V l ds S E := by
  obtain ⟨hrs, hc, hk, hn⟩ := Round.of_inv (contract := contract) (h := L.h) (p := L.p)
    (ds := L.dh) (S := L.H) (B := L.B) (n := n) (V := Valuation.roundWith contract l S E V)
    (fun i W => W.ctx = V.ctx ∧
      W.k = (Valuation.roundWith contract l S E V).k + i * (pathLen L.H L.B + 1) ∧ I i W)
    ⟨(Valuation.roundWith_k contract l S E 1 V).1, by omega, h0⟩
    fun i hi W ⟨hc, hk, hI⟩ => by
      obtain ⟨c1, -, k1⟩ := Valuation.roundWith_k contract L.h L.H L.B 1 W
      rw [Function.iterate_one] at c1 k1
      refine ⟨(hR i hi W hc hk hI).1, c1.trans hc, ?_, (hR i hi W hc hk hI).2⟩
      rw [k1, hk, Nat.add_mul, Nat.one_mul]
      omega
  exact ChainWith.of_rounds hL n ⟨hE, hrs⟩ (.last (hX _ hc hk hn))

/-- **An invariant of a loop at a thread, with or without `fmul contract`**: the premises `h0`,
`hR` and `hX` of `RetLsWith.of_inv` as one structure, for every flag `contract`, loop `L`,
valuation `V`, path `(l, _, S) :: E` before the loop, predicate `Q` on memories, trip count `n`
and invariant `I` indexed by the round, at the header's entry valuation after the path,
`Valuation.roundWith contract l S E V`. The premises at the heads of the rounds alone
(`LoopIterWith`, Sym/KernelIter.lean, over which the `mat … inv` clause of `mojo_kernel` states
its `n.runInv` and `n.sound_inv`) give it (`LoopIterWith.toInv`). -/
structure LoopInvWith (contract : Bool) (L : LoopSeg) (V : Valuation) (l : Nat) (S : Summary)
    (E : List (Nat × List Cond × Summary)) (Q : Mem → Prop) (n : Nat)
    (I : Nat → Valuation → Prop) : Prop where
  /-- Builds `LoopInvWith` from its fields. -/
  mk ::
  /-- `I 0` holds at the header's entry valuation after the path. -/
  head : I 0 (Valuation.roundWith contract l S E V)
  /-- For every round `i < n`, every valuation `W` with `V`'s context and the step count of
  round `i` at which `I i` holds meets the premises of a round (`RoundWith contract`), and
  `I (i + 1)` holds after the round. -/
  round : ∀ i < n, ∀ W, W.ctx = V.ctx →
    W.k = (Valuation.roundWith contract l S E V).k + i * (pathLen L.H L.B + 1) → I i W →
    RoundWith contract L.h L.p L.dh L.H L.B W ∧
      I (i + 1) (Valuation.roundWith contract L.h L.H L.B W)
  /-- Every valuation `W` with `V`'s context and the step count of round `n` at which `I n`
  holds runs the path out of the loop to `ret` with a memory of `Q` (`RetWith contract`). -/
  exit : ∀ W, W.ctx = V.ctx →
    W.k = (Valuation.roundWith contract l S E V).k + n * (pathLen L.H L.B + 1) → I n W →
    RetWith contract W Q ((L.h, L.dh, L.H) :: L.X)

/-- **A thread of a matmul kernel in bounds, with its facts**: the binders and the premises of
`Kernel.sound_mat`'s `Hin` as one structure. For program `prog`, kernel `fn`, launch `L`, struct
type `T` whose tail value is `z`, loaded at alignment `al'`, element type `t` with encoder `enc`,
alignment `al`, block numbers `o` (output), `a`, `b` (inputs), size `K`, row stride `sC`,
tensors `x` (`m × sA`) and `y` (`n × sB`), admission `adm`, cell width `w` and bytes `bs`: an
admitted choice and oracle, a thread `k` in the window and the matrix (`k` below the thread
count, its row below `m`, its column below `n`), blocks `q0`, `q1`, `q2`, a context `c` with
thread `k`'s oracle, memories `m₀` and `m'` and a frame `f` with the facts of `Mat.Entry`, where
`m'` meets `Elem` after `k` threads (from `m₀`, cells `(row * sC + column) * w`) and its
accesses to `o` are by threads in bounds (`Elem.Only`). The `mat … inv` clause of `mojo_kernel`
(Sym/KernelCmd.lean) states its `n.sound_inv`'s invariant, trip count and premise over it. -/
structure Mat.Thread (prog : Program) (fn : Func) (L : Launch) (T : Ty) (z : Val) (al' : Nat)
    {α : Type} [TorchLean.Storage α] (t : Ty) (enc : α → Val) (al o a b K sC : Nat)
    {m n sA sB : Nat} (x : TorchLean.Tensor α [m, sA]) (y : TorchLean.Tensor α [n, sB])
    (adm : (Nat → Nat) → (Nat → Nat → Nat) → Prop) (w : Nat)
    (bs : Nat → Option (List MemByte)) where
  /-- Builds `Mat.Thread` from its fields. -/
  mk ::
  /-- The choice. -/
  ch : Nat → Nat
  /-- The oracle family. -/
  oracle : Nat → Nat → Nat
  /-- The choice and the oracle family are admitted. -/
  admits : adm ch oracle
  /-- The thread. -/
  k : Nat
  /-- The block of the output's struct. -/
  q0 : Nat
  /-- The block of the first input's struct. -/
  q1 : Nat
  /-- The block of the second input's struct. -/
  q2 : Nat
  /-- The thread's context. -/
  c : Ctx
  /-- The memory before the first thread. -/
  m₀ : Mem
  /-- The thread's memory at its entry. -/
  m' : Mem
  /-- The thread's frame. -/
  f : Frame
  /-- `k` is below the thread count, its row below `m` and its column below `n`. -/
  inBounds : k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n
  /-- `c`'s oracle is thread `k`'s. -/
  oracleEq : c.oracle = oracle k
  /-- The facts the start gives the thread (`Mat.Entry`). -/
  entry : Mat.Entry prog fn L T z al' t enc al o a b K sC x y k c q0 q1 q2 m' f
  /-- `m'` meets `Elem` after `k` threads from `m₀`. -/
  elem : Elem m₀ o w (fun k => (L.index k .x * sC + L.index k .y) * w) bs k m'
  /-- The accesses of `m'` to `o` are by threads in bounds. -/
  only : Elem.Only o (fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
    L.index k .y < n) m'

end MojoProof.Sym
