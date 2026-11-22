import MojoProof.Sym.Kernel
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
as two premises on the facts the start gives each thread: a thread in bounds runs some sequence
of loops to `ret` (`RetLsWith`), a thread out of bounds takes some path to `ret` (`RetWith`). It
is `Kernel.sound_mapNWith` at the three structs and scalars, with the cells apart by
`Launch.apart_xy`. Its instance is `NaiveSound.naive_sound` (MojoProofTest/NaiveSound.lean), the
naive matmul kernel.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

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
`L.index k .y < n`; in `Hout` a thread of the launch that is not), context of `prog` with thread
`k`'s registers, identity and oracle, memories `m₀` and `m'`, frame of `fn` whose registers `%0`,
`%1`, `%2` point to blocks `q0`, `q1`, `q2` other than `o` from which `T` loads at alignment
`al'` as the structs of `o`, `a`, `b`, and whose `%3`, `%4`, `%5` are the words of `m`, `n`, `K`,
on which `m'` has the buffers of `mem` (fitting, `a` and `b` holding `x` and `y`), if `m'` meets
`Elem` after `k` threads (from `m₀`) and its accesses to `o` are by threads in bounds
(`Elem.Only`), then the thread runs to `ret` with a memory that meets `Elem` after `k + 1`
threads and whose accesses to `o` are by threads in bounds: in `Hin` through some sequence of
loops of `chains` (`RetLsWith contract`), in `Hout` along some path of `paths`
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
    (Hin : ∀ ch oracle, adm ch oracle → ∀ k,
      (k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n) →
      ∀ c : Ctx, c.prog = prog → c.env = L.env k → c.who = ⟨k, k / volume L.block⟩ →
      c.oracle = oracle k → ∀ (m₀ m' : Mem) (f : Frame), f.fn = fn → ∀ q0 q1 q2 : Nat,
      f.regs 0 = some (.ptr ⟨q0, 0⟩) → f.regs 1 = some (.ptr ⟨q1, 0⟩) →
      f.regs 2 = some (.ptr ⟨q2, 0⟩) → q0 ≠ o ∧ q1 ≠ o ∧ q2 ≠ o →
      m'.load prog.layout c.who 0 T ⟨q0, 0⟩ (some al') = .ok (.agg [.ptr ⟨o, 0⟩, z]) →
      m'.load prog.layout c.who 0 T ⟨q1, 0⟩ (some al') = .ok (.agg [.ptr ⟨a, 0⟩, z]) →
      m'.load prog.layout c.who 0 T ⟨q2, 0⟩ (some al') = .ok (.agg [.ptr ⟨b, 0⟩, z]) →
      f.regs 3 = some (.bits 32 (BitVec.ofNat 32 m)) →
      f.regs 4 = some (.bits 32 (BitVec.ofNat 32 n)) →
      f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)) →
      m'.Buffer a (m * sA * prog.layout.size t) al false →
      m'.Buffer b (n * sB * prog.layout.size t) al false →
      m'.Buffer o (m * sC * prog.layout.size t) al true →
      m'.Fits prog.layout a (m * sA * prog.layout.size t) →
      m'.Fits prog.layout b (n * sB * prog.layout.size t) →
      m'.Fits prog.layout o (m * sC * prog.layout.size t) →
      m'.Holds prog.layout a t enc (rowMajor prog.layout t 0) x →
      m'.Holds prog.layout b t enc (rowMajor prog.layout t 0) y →
      Elem m₀ o w (fun k => (L.index k .x * sC + L.index k .y) * w) bs k m' →
      Elem.Only o (fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
        L.index k .y < n) m' →
      ∃ C ∈ chains, RetLsWith contract
        (fun me => Elem m₀ o w (fun k => (L.index k .x * sC + L.index k .y) * w) bs (k + 1) me ∧
          Elem.Only o (fun k => k < volume L.grid * volume L.block ∧ L.index k .x < m ∧
            L.index k .y < n) me)
        C.loops (Valuation.entry c 0 m' f) C.l C.ds C.S C.E)
    (Hout : ∀ ch oracle, adm ch oracle → ∀ k, k < volume L.grid * volume L.block →
      ¬ (k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n) →
      ∀ c : Ctx, c.prog = prog → c.env = L.env k → c.who = ⟨k, k / volume L.block⟩ →
      c.oracle = oracle k → ∀ (m₀ m' : Mem) (f : Frame), f.fn = fn → ∀ q0 q1 q2 : Nat,
      f.regs 0 = some (.ptr ⟨q0, 0⟩) → f.regs 1 = some (.ptr ⟨q1, 0⟩) →
      f.regs 2 = some (.ptr ⟨q2, 0⟩) → q0 ≠ o ∧ q1 ≠ o ∧ q2 ≠ o →
      m'.load prog.layout c.who 0 T ⟨q0, 0⟩ (some al') = .ok (.agg [.ptr ⟨o, 0⟩, z]) →
      m'.load prog.layout c.who 0 T ⟨q1, 0⟩ (some al') = .ok (.agg [.ptr ⟨a, 0⟩, z]) →
      m'.load prog.layout c.who 0 T ⟨q2, 0⟩ (some al') = .ok (.agg [.ptr ⟨b, 0⟩, z]) →
      f.regs 3 = some (.bits 32 (BitVec.ofNat 32 m)) →
      f.regs 4 = some (.bits 32 (BitVec.ofNat 32 n)) →
      f.regs 5 = some (.bits 32 (BitVec.ofNat 32 K)) →
      m'.Buffer a (m * sA * prog.layout.size t) al false →
      m'.Buffer b (n * sB * prog.layout.size t) al false →
      m'.Buffer o (m * sC * prog.layout.size t) al true →
      m'.Fits prog.layout a (m * sA * prog.layout.size t) →
      m'.Fits prog.layout b (n * sB * prog.layout.size t) →
      m'.Fits prog.layout o (m * sC * prog.layout.size t) →
      m'.Holds prog.layout a t enc (rowMajor prog.layout t 0) x →
      m'.Holds prog.layout b t enc (rowMajor prog.layout t 0) y →
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
  by_cases hS : k < volume L.grid * volume L.block ∧ L.index k .x < m ∧ L.index k .y < n
  · exact .inr (Hin ch oracle ha k hS c hcp hce hcw hco m₀ m' f hf q0 q1 q2 hr0 hr1 hr2
      ⟨hp0, hp1, hp2⟩ hv0 hv1 hv2 (hr 0 (by simp)) (hr 1 (by simp)) (hr 2 (by simp))
      (hA.of_block hqa) (hB.of_block hqb) (hE.buffer (hO.of_block hm₀)) (hFa.of_block hqa)
      (hFb.of_block hqb) (hE.fits (hFo.of_block hm₀)) (hx.of_block hqa) (hy.of_block hqb) hE hOn)
  · exact .inl (Hout ch oracle ha k hk hS c hcp hce hcw hco m₀ m' f hf q0 q1 q2 hr0 hr1 hr2
      ⟨hp0, hp1, hp2⟩ hv0 hv1 hv2 (hr 0 (by simp)) (hr 1 (by simp)) (hr 2 (by simp))
      (hA.of_block hqa) (hB.of_block hqb) (hE.buffer (hO.of_block hm₀)) (hFa.of_block hqa)
      (hFb.of_block hqb) (hE.fits (hFo.of_block hm₀)) (hx.of_block hqa) (hy.of_block hqb) hE hOn)

end MojoProof.Sym
