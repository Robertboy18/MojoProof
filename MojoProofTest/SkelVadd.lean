import MojoProofTest.Kernel
import MojoProofTest.Labels
import MojoProofTest.ScheduleOwned
import MojoProof.Sem.SkelStep

/-!
# The skeleton route on `vector_addition` (`Kernel.skel_sound`, `Kernel.Sound.of_blocks`)

`Kernel.skel_sound` (MojoProof/Sem/SkelStep.lean) on `vector_addition` (`Kernels.vadd`, corpus
`vadd/`), with every premise closed by evaluation:

* `memAtB`, `memNextB`, `memAllB`: `Labels.MemAt`, `Labels.MemNext` and `Labels.MemAll` as
  Booleans, for every labelling, payload blocks, scope, context and grid, and their soundness
  (`memAtB_sound`, `memNextB_sound`, `memAllB_sound`); with `ScheduleOwned.every`, a grid all of
  whose reachable grids within `f` steps pass `memAllB`, none with a step after `f`, meets
  `Labels.MemOk` (`memOk_of_every`). `every` explores every interleaving of the threads' steps, so
  by evaluation it closes a launch of one thread only: at two threads of `vector_addition` it
  would check 3.0e16 grids (docs/proofs/skel-kernel.md, last section).
* `atStart`, `memCheck`, `runCheck`: checks of the start of `vector_addition` on one thread
  (`Launch.one`) with buffers at blocks 1, 2, 3 and count 5
  (`Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)`) on the canaries' memory `mem5`
  (MojoProofTest/Kernel.lean: inputs `x5`, `y5`, an output of 5 undefined floats), at address
  choice `ch₀` and oracle `ω₀`. `memCheck_ok`, evaluated by the kernel
  (`decide +kernel`): every grid reachable from the start's grid within 40 steps passes `memAllB`
  under `labV` (`vaddLab ["25", "27", "28"]`, MojoProofTest/Labels.lean) with blocks 1 to 3
  payload (`payV`), and none has a step after 40. `runCheck_ok`, evaluated by the kernel: the run
  `Grid.run` (fuel 64, one phase) ends in a grid whose trace is not racy and keeps
  `!invariant.load`, whose blocks below 4 agree at the offsets below 24 with `Elem.Out`'s
  description at one thread (`Elem.outBelow`), and whose output cell 0 holds the float
  `1 + 32 = 33` (`Elem.word`; `outV`). `vaddOk`: the start, `Labels.MemOk`, and a run to a grid in
  which every thread has returned, that is not bad and passes `outV`.
* `skel_vadd`, the instance of `Kernel.skel_sound`: for every memory `m₂` related to `mem5` by
  `Mem.SkelEq` with blocks 1 to 3 payload (every data byte of the inputs, the same shape, the
  same undefined output bytes), `vector_addition` on one thread on `m₂` is sound at address
  choice `ch₀` and every oracle, for the blocks and the trivial relation. The premises:
  `Mem.Closed.bytesIn` of `pre5`'s field `closed`, `vadd_ok`, the lookup by `rfl`, and
  `vaddOk`.
* `out_vadd`, the instance of `Kernel.Sound.of_blocks`: at `mem5`, `ch₀` and `ω₀`, the kernel on
  one thread is sound for the blocks and `outV`, from the run's final grid.
* `elem_vadd`, the instance of `Kernel.Sound.of_blocks` for `Elem.Out` at one thread: at `mem5`,
  `ch₀` and `ω₀`, from the same run. Every grid reachable from the start keeps `mem5`'s blocks
  with their owners and sizes and their bytes from their sizes on (`above_vadd`, by
  `Grid.start_reach_above`); every block of `mem5` is below 4, of every thread and of at most 20
  bytes (`mem5_blocks`); so blocks that pass `outV` and keep `mem5`'s bytes beyond the sizes are
  `Elem.Out`'s (`out_of_outV`, by `Sym.Elem.Out.of_outBelow` at 4 blocks and offset 24).
* `correct_one`, for comparison: `Kernels.vadd.correct` at the same launch and memory, for every
  address choice and oracle, with `Elem.Out` at one thread.
* Twins of `memCheck`: with block 3 not payload, the store of the payload `%28` to block 3 fails
  `memAllB`; with every block payload, the load of the `byval` struct `%5` (a skeleton result)
  from the start's copy fails it (`pay_twin`).

One kernel, launch, start memory up to its payload bytes, and address choice; every oracle for
`skel_vadd`.
-/

namespace MojoProofTest.SkelVadd

open MojoProof MojoProof.Sem MojoProof.LLVM Relation
open MojoProofTest.Kernel (ch₀ ω₀ mem5 pre5 x5 y5 sums5 mem5_none bytes5_end)
open MojoProofTest.Labels (vaddLab vadd_ok)
open MojoProofTest.ScheduleOwned (every every_sound)

-- `Array.any` recurses by well-founded recursion, so the kernel cannot evaluate a step without
-- this.
unseal Array.anyM.loop

/-! ## `Labels.MemAll` as a Boolean -/

/-- Whether the pointer operand `p` of type `ptr a` evaluates in scope `s` to a pointer into a
block that `P` accepts; `true` if it evaluates to no pointer. -/
def ptrB (s : Scope) (a : Nat) (p : Value) (P : Nat → Bool) : Bool :=
  match evalV s (.ptr a) p with
  | .ok (.ptr q) => P q.block
  | _ => true

/-- What `ptrB` says, for every scope, operand and test: a pointer the operand evaluates to is
into a block that `P` accepts. -/
theorem ptrB_sound {s : Scope} {a : Nat} {p : Value} {P : Nat → Bool} {q : Ptr}
    (h : ptrB s a p P = true) (hq : evalV s (.ptr a) p = .ok (.ptr q)) : P q.block = true := by
  unfold ptrB at h
  rw [hq] at h
  exact h

/-- `Labels.MemAt` as a Boolean, for payload blocks `pay`: a `load` with a skeleton result
through a pointer outside `pay`, a `store` or an `atomicrmw` of a payload operand through a pointer
inside. -/
def memAtB (lab : Labels) (pay : Nat → Bool) (s : Scope) (fn : Func) (st : Stmt) : Bool :=
  match st.inst with
  | .load _ _ (.mk (.ptr a) p) _ => st.res.any (lab.reg fn.name) || ptrB s a p (!pay ·)
  | .store _ v (.mk (.ptr a) p) _ | .atomicrmw _ _ (.mk (.ptr a) p) v _ _ _ =>
    !v.mentions (lab.reg fn.name) || ptrB s a p pay
  | _ => true

/-- What `memAtB` says, for every labelling, payload blocks, scope, function and statement:
`Labels.MemAt` with the blocks `pay` accepts. -/
theorem memAtB_sound {lab : Labels} {pay : Nat → Bool} {s : Scope} {fn : Func} {st : Stmt}
    (h : memAtB lab pay s fn st = true) : lab.MemAt (pay · = true) s fn st := by
  unfold Labels.MemAt
  split
  · intro hr q hq
    rename_i heq
    simp only [memAtB, heq, hr, Bool.false_or] at h
    simpa using ptrB_sound h hq
  · intro hv q hq
    rename_i heq
    simp only [memAtB, heq, hv, Bool.not_true, Bool.false_or] at h
    exact ptrB_sound h hq
  · intro hv q hq
    rename_i heq
    simp only [memAtB, heq, hv, Bool.not_true, Bool.false_or] at h
    exact ptrB_sound h hq
  · trivial

/-- `Labels.MemNext` as a Boolean: `memAtB` at the next statement of the thread's first frame,
with its scope on memory `m` under context `c`; `true` if it has none. -/
def memNextB (lab : Labels) (pay : Nat → Bool) (c : Ctx) (m : Mem) (t : Thread) : Bool :=
  match t.frames with
  | [] => true
  | f :: _ => match f.fn.blocks.find? (·.label == f.label) with
    | none => true
    | some b => match b.stmts[f.pc]? with
      | none => true
      | some st => memAtB lab pay (c.scope m f t.k) f.fn st

/-- What `memNextB` says, for every labelling, payload blocks, context, memory and thread:
`Labels.MemNext` with the blocks `pay` accepts. -/
theorem memNextB_sound {lab : Labels} {pay : Nat → Bool} {c : Ctx} {m : Mem} {t : Thread}
    (h : memNextB lab pay c m t = true) : lab.MemNext (pay · = true) c m t := by
  intro f rest b st hf hb hst
  simp only [memNextB, hf, hb, hst] at h
  exact memAtB_sound h

/-- `Labels.MemAll` as a Boolean: `memNextB` at each running thread `n` of `g`, under
context `c n`. -/
def memAllB (lab : Labels) (pay : Nat → Bool) (c : Nat → Ctx) (g : Grid) : Bool :=
  (List.range g.threads.size).all fun n => match g.threads[n]? with
    | some (.run t) => memNextB lab pay (c n) g.mem t
    | _ => true

/-- What `memAllB` says, for every labelling, payload blocks, contexts and grid:
`Labels.MemAll` with the blocks `pay` accepts. -/
theorem memAllB_sound {lab : Labels} {pay : Nat → Bool} {c : Nat → Ctx} {g : Grid}
    (h : memAllB lab pay c g = true) : lab.MemAll (pay · = true) c g := by
  intro n t ht
  have hn : n < g.threads.size := by
    by_contra hlt
    rw [Array.getElem?_eq_none (Nat.le_of_not_lt hlt)] at ht
    cases ht
  have h' := List.all_eq_true.1 h n (List.mem_range.2 hn)
  simp only [ht] at h'
  exact memNextB_sound h'

/-- **`Labels.MemOk` by evaluation**, for every labelling, payload blocks, launch, contexts, grid
and bound `f`: if every grid reachable from `g₀` within `f` steps passes `memAllB` and none has a
step after `f` (`ScheduleOwned.every`), `g₀` meets `Labels.MemOk` with the blocks `pay`
accepts. -/
theorem memOk_of_every {lab : Labels} {pay : Nat → Bool} {L : Launch} {c : Nat → Ctx} {g₀ : Grid}
    {f : Nat} (h : every L c (memAllB lab pay c) f g₀ = true) :
    lab.MemOk (pay · = true) L c g₀ :=
  fun _ hr => memAllB_sound (every_sound hr h)

/-! ## The instance on `vector_addition` -/

/-- The payload blocks: 1 and 2 (the inputs) and 3 (the output). -/
def payV (b : Nat) : Bool := b == 1 || b == 2 || b == 3

/-- The labelling: `%25`, `%27` (the loaded floats) and `%28` (their sum) payload. -/
def labV : Labels := vaddLab ["25", "27", "28"]

/-- The relation on the final blocks `B` of a run on one thread at oracle `ω₀`: the blocks below 4
agree at the offsets below 24 with `Elem.Out mem5 3 (4 ·) (Kernels.vadd.bytes ω₀ x5 y5 5) 1`'s
description (`Elem.outBelow`: block 3 with thread 0's bytes put at cell 0, blocks 1 and 2
unchanged), and output cell 0 holds `1 + 32 = 33` (`sums5`'s first float, `Elem.word`). -/
def outV (B : Nat → Option Sem.Block) : Bool :=
  Sym.Elem.outBelow mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω₀ x5 y5 5) 1 4 24 B &&
    decide ((List.range 1).map
      (Sym.Elem.word Kernels.vadd.prog.layout .float 3 (fun i => 4 * i) B) = sums5.take 1)

/-- A check `p` of the start's grid and contexts of `vector_addition` on one thread (`Launch.one`)
with buffers at blocks 1, 2, 3 and count 5 on `mem5`, at address choice `ch₀` and oracle `ω₀`;
`false` if the start fails. -/
def atStart (p : Grid → (Nat → Ctx) → Bool) : Bool :=
  match Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ with
  | .ok (g, c) => p g c
  | .error _ => false

/-- A check `p` that `atStart` passes gives the start's grid and contexts, which `p` accepts, for
every check. -/
theorem atStart_ok {p : Grid → (Nat → Ctx) → Bool} (h : atStart p = true) :
    ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c) ∧ p g c = true := by
  unfold atStart at h
  split at h
  next g c hs => exact ⟨g, c, hs, h⟩
  next => cases h

/-- The memory check for payload blocks `pay`: every grid reachable from the start's grid within
40 steps passes `memAllB` under `labV` and `pay`, and none has a step after 40. -/
def memCheck (pay : Nat → Bool) (g : Grid) (c : Nat → Ctx) : Bool :=
  every .one c (memAllB labV pay c) 40 g

/-- The run check: the run (fuel 64, one phase) ends in a grid whose trace is not racy and keeps
`!invariant.load` (the core's `racy` and `kept` at `sig`) and whose blocks pass `outV`. -/
def runCheck (g : Grid) (c : Nat → Ctx) : Bool :=
  match g.run .one c 64 1 with
  | .ok z => !GPUProof.racy sig (z.mem.trace.map (Event.toCore .one)).reverse &&
    GPUProof.kept sig (z.mem.trace.map (Event.toCore .one)).reverse && outV z.mem.blocks
  | .error _ => false

/-- The memory check with blocks 1 to 3 payload passes at the start, by kernel evaluation. -/
theorem memCheck_ok : atStart (memCheck payV) = true := by decide +kernel

/-- The run check passes at the start, by kernel evaluation. -/
theorem runCheck_ok : atStart runCheck = true := by decide +kernel

/-- **What the checks give**: the launch of `vector_addition` on one thread on `mem5` at address
choice `ch₀` and oracle `ω₀` starts, its grid meets `Labels.MemOk` under `labV` with blocks 1 to
3 payload (`memCheck_ok`, `memOk_of_every`), and it reaches a grid in which every thread has
returned (`runCheck_ok`, `Grid.run_reach`, `Grid.run_done`), that is not bad and whose blocks pass
`outV`. -/
theorem vaddOk : ∃ g c z, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c) ∧
    labV.MemOk (payV · = true) .one c g ∧ ReflTransGen (Grid.Step .one c) g z ∧
    GPUProof.Done sig (z, Launch.one, c) ∧
    ¬ GPUProof.Bad sig (z, Launch.one, c) ∧ outV z.mem.blocks = true := by
  obtain ⟨g, c, hs, he⟩ := atStart_ok memCheck_ok
  obtain ⟨g', c', hs', hr⟩ := atStart_ok runCheck_ok
  rw [hs] at hs'
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj hs')
  unfold runCheck at hr
  split at hr
  next z hz =>
    simp only [Bool.and_eq_true, Bool.not_eq_true'] at hr
    obtain ⟨⟨hrc, hk⟩, ho⟩ := hr
    have hd : GPUProof.Done sig (z, Launch.one, c) := Grid.run_done hz
    have hsz := (Grid.start_reach_size hs (Grid.run_reach hz)).le
    refine ⟨g, c, z, hs, memOk_of_every he, Grid.run_reach hz, hd, ?_, ho⟩
    rintro (hf | hr | hk' | hr)
    · exact done_not_faults hsz hd hf
    · exact nomatch hrc.symm.trans hr
    · exact nomatch hk.symm.trans hk'
    · exact Grid.Done.not_raceEnabled hsz hd hr
  next => cases hr

/-- **The instance of `Kernel.skel_sound` on `vector_addition`**: under `labV` with blocks 1 to 3
payload, for every memory `m₂` related to `mem5` by `Mem.SkelEq` (every data byte of blocks 1 to
3, the same shape and the same other bytes), `vector_addition` launched on one thread
(`Launch.one`) on `m₂` with buffers at blocks 1, 2, 3 and count 5 is sound at address choice `ch₀`
and every oracle, for the blocks and the trivial relation: safe, race free, keeping
`!invariant.load`, making progress, terminating and determinate for the blocks. The premises:
`mem5`'s pointer bytes from `pre5` (`Mem.Closed.bytesIn`), `vadd_ok`, the lookup by `rfl`, and
`vaddOk` at `ch₀`. -/
theorem skel_vadd {m₂ : Mem} (hm : mem5.SkelEq (payV · = true) m₂) :
    Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) m₂ (fun ch _ => ch = ch₀)
      (fun m => some m.blocks) (fun _ => True) :=
  Kernel.skel_sound (lab := labV) pre5.closed.bytesIn vadd_ok rfl
    (fun ch h => by
      subst h
      obtain ⟨g, c, z, hs, hM, hr, hd, hb, -⟩ := vaddOk
      exact ⟨ω₀, g, c, z, hs, hM, hr, hd, hb⟩)
    hm

/-- **The instance of `Kernel.Sound.of_blocks` on `vector_addition`**: on one thread on `mem5`,
at address choice `ch₀` and oracle `ω₀`, the kernel is sound for the blocks and `outV`: the blocks
below 4 agree at the offsets below 24 with `Elem.Out`'s description at one thread, and output cell
0 holds `1 + 32 = 33`. From `skel_vadd` at `mem5` and the final grid of `vaddOk`'s run. -/
theorem out_vadd : Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun ch o => ch = ch₀ ∧ o = ω₀)
      (fun m => some m.blocks) (outV · = true) := by
  refine Kernel.Sound.of_blocks
    (fun ch o ha => skel_vadd (Mem.SkelEq.refl _ mem5) ch o ha.1) (fun _ _ h => congrArg some h) ?_
  rintro _ _ g c ⟨rfl, rfl⟩ e
  obtain ⟨g', c', z, hs, -, hr, hd, -, ho⟩ := vaddOk
  rw [hs] at e
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj e)
  exact ⟨z, hr, hd, _, rfl, ho⟩

/-! ## `Elem.Out` from the run -/

/-- Every block of `mem5` is at a number below 4, of every thread (`.all`), and of at most 20
bytes: below 4 by kernel evaluation; from 4 on `mem5` has no block (`mem5_none`). -/
theorem mem5_blocks {b : Nat} {x : Sem.Block} (h : mem5.blocks b = some x) :
    b < 4 ∧ x.owner = .all ∧ x.size ≤ 20 := by
  by_cases hb : b < 4
  · have hc : (List.range 4).all (fun b => (mem5.blocks b).all fun x =>
        x.owner == .all && decide (x.size ≤ 20)) = true := by decide +kernel
    have hx := List.all_eq_true.1 hc b (List.mem_range.2 hb)
    simp only [h, Option.all_some, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at hx
    exact ⟨hb, hx⟩
  · rw [mem5_none b (by omega)] at h
    cases h

/-- **`Grid.start_reach_above` on `vector_addition`**: on one thread on `mem5` at address choice
`ch₀` and oracle `ω₀`, in every grid `z` reachable from the start's grid, every block `x` of
`mem5` is a block at its number with the owner and size of `x` and, at every offset of at least
`x.size`, the byte of `x` (`Grid.start_blocks`; the blocks of `mem5` are of every thread,
`mem5_blocks`). -/
theorem above_vadd {g z : Grid} {c : Nat → Ctx}
    (hs : Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 ch₀ ω₀ = .ok (g, c))
    (hr : ReflTransGen (Grid.Step .one c) g z) {b : Nat} {x : Sem.Block}
    (hx : mem5.blocks b = some x) :
    ∃ x', z.mem.blocks b = some x' ∧ x'.owner = x.owner ∧ x'.size = x.size ∧
      ∀ i, x.size ≤ i → x'.bytes i = x.bytes i :=
  Grid.start_reach_above hs hr (Grid.start_blocks hs hx) fun _ h => by
    rw [(mem5_blocks hx).2.1] at h
    cases h

/-- **`Elem.Out` from `outV` and the bytes beyond the sizes**: blocks `B` that pass `outV` (the
blocks below 4 at the offsets below 24, `Elem.outBelow`) and have every block `x` of `mem5` at
its number with, at every offset of at least `x.size`, the byte of `x`, are those of
`Elem.Out mem5 3 (4 ·) (Kernels.vadd.bytes ω₀ x5 y5 5) 1`: block 3 is `mem5`'s with thread 0's
4 bytes put at offset 0, every other block of `mem5` is unchanged. By `Sym.Elem.Out.of_outBelow` at
4 blocks and offset 24: `mem5` has no block from 4 on (`mem5_none`), thread 0's bytes end by
offset 24 (`bytes5_end`), and every block of `mem5` has at most 20 bytes (`mem5_blocks`). -/
theorem out_of_outV {B : Nat → Option Sem.Block} (ho : outV B = true)
    (ha : ∀ b x, mem5.blocks b = some x →
      ∃ x', B b = some x' ∧ ∀ i, x.size ≤ i → x'.bytes i = x.bytes i) :
    Sym.Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω₀ x5 y5 5) 1 B := by
  simp only [outV, Bool.and_eq_true] at ho
  refine Sym.Elem.Out.of_outBelow ho.1 mem5_none (fun i hi => bytes5_end i (by omega))
    fun b x y hx hy i hi => ?_
  obtain ⟨x', hx', hby⟩ := ha b x hx
  rw [hx', Option.some.injEq] at hy
  subst hy
  exact hby i (by have := (mem5_blocks hx).2.2; omega)

/-- **`Kernel.Sound.of_blocks` to `Elem.Out` on `vector_addition`**: on one thread on `mem5`, at
address choice `ch₀` and oracle `ω₀`, the kernel is sound for the blocks and
`Elem.Out mem5 3 (4 ·) (Kernels.vadd.bytes ω₀ x5 y5 5) 1`, from `skel_vadd` and the final grid of
`vaddOk`'s run, whose blocks pass `outV` and keep `mem5`'s bytes beyond the sizes (`above_vadd`,
`out_of_outV`). `correct_one` gives the same at every address choice and oracle, from the kernel
theorem; this one is from one run. -/
theorem elem_vadd : Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun ch o => ch = ch₀ ∧ o = ω₀)
      (fun m => some m.blocks)
      (Sym.Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω₀ x5 y5 5) 1) := by
  refine Kernel.Sound.of_blocks
    (fun ch o ha => skel_vadd (Mem.SkelEq.refl _ mem5) ch o ha.1) (fun _ _ h => congrArg some h) ?_
  rintro _ _ g c ⟨rfl, rfl⟩ e
  obtain ⟨g', c', z, hs, -, hr, hd, -, ho⟩ := vaddOk
  rw [hs] at e
  obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Except.ok.inj e)
  refine ⟨z, hr, hd, _, rfl, out_of_outV ho fun b x hx => ?_⟩
  obtain ⟨x', hx', -, -, hby⟩ := above_vadd hs hr hx
  exact ⟨x', hx', hby⟩

/-- **The kernel theorem at the same launch, for comparison**: `Kernels.vadd.correct` on one
thread (`Launch.valid_one`) and `mem5` (`pre5`), for every oracle `ω`: the kernel is sound at every
address choice and `ω`, for the blocks and `Elem.Out` at one thread (block 3 of `mem5` with
`Kernels.vadd.bytes ω x5 y5 5 0`, the float `deliver (1 + 32)`, at cell 0, and every other block
of `mem5` unchanged). It covers every address choice and the output's value, on the memories of
`Map2.Pre`; `skel_vadd` covers every memory related to `mem5` by `Mem.SkelEq`, but address choice
`ch₀` and the trivial relation. -/
theorem correct_one (ω : Nat → Nat → Nat) :
    Kernel.Sound Kernels.vadd.prog Kernels.vadd.fn_0 .one
      (Kernels.vadd.args 1 2 3 (BitVec.ofNat 32 5)) mem5 (fun _ ω' => ω' = ω)
      (fun m => some m.blocks)
      (Sym.Elem.Out mem5 3 (fun i => 4 * i) (Kernels.vadd.bytes ω x5 y5 5) 1) :=
  Kernels.vadd.correct Launch.valid_one ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ (by decide) pre5

/-- **Twins of the memory check's payload blocks**: with blocks 1 and 2 payload but not the output
3, it fails, as the store of the payload `%28` is to block 3; with every block payload, it fails,
as the load of the `byval` struct `%5`, a skeleton result, is from the start's copy of the
argument, a block above 3. -/
theorem pay_twin : atStart (memCheck fun b => b == 1 || b == 2) = false ∧
    atStart (memCheck fun _ => true) = false :=
  ⟨by decide +kernel, by decide +kernel⟩

end MojoProofTest.SkelVadd
