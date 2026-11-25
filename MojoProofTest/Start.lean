import MojoProof.Kernels
import MojoProofTest.Confluence

/-!
# The invariants W1 to W5 at the start of `vadd`

The instance of the invariants W1 to W5 of docs/proofs/schedule.md (section "W3 and W4, and the
invariants on `vadd`"), whose statements are over every program: `vadd` (`Kernels.vadd.prog`, the
corpus file `tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll`)
on 2 blocks of 2 threads (`launch2 2 1 2 1`), with its three buffers at blocks 1 to 3 of `memV`
(blocks of 16 undefined bytes) and size 4, starts for every address choice and oracle, with 4
running threads and an empty trace; its contexts give thread `n` the program and the number `n` in
block of threads `n / 2` (W3); and every grid reachable from its grid is closed (W1,
`Grid.start_reach_closed`), has threads that own their allocas (W2, `Grid.start_owns`,
`Grid.reach_owns`), has the accesses of its trace by its threads (W4, `Grid.start_reach_byThreads`),
and has its waiting threads at their calls and the start's blocks' shapes (W5,
`Grid.start_reach_atCalls`, `Grid.reach_keeps`) (`invariants`).

The twin of W1's premise that the caller's pointer bytes name known numbers: on `memP`, `memV`
with block 1000 holding a pointer to block 2000, `vadd` starts, but its grid is not closed
(`closed_twin`). The twin of W4's premise that the contexts are the start's: in `ctxOf` (both
threads in block of threads 0) on a launch of one thread per block of threads, `stores 0` has W4,
but after thread 1's store it does not (`byThreads_twin`).

Statements about this launch, these memories and these grids.
-/

namespace MojoProofTest.Start

open MojoProof.Sem MojoProof.LLVM MojoProof MojoProofTest.Pending MojoProofTest.Confluence

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- A buffer of `vadd` at block `b`: the pointer and two empty layouts (its `byval` type). -/
def buf (b : Nat) : Val := .agg [.ptr ⟨b, 0⟩, .agg [.agg [.agg []], .agg [.agg []]]]

/-- `vadd`'s arguments: the inputs at blocks 1 and 2, the output at block 3, and the size 4. -/
def argsV : List Val := [buf 1, buf 2, buf 3, .bits 32 (BitVec.ofNat 32 4)]

/-- Blocks 1 to 3, each `Close.blk` with 16 bytes, and `next = 4`. -/
def memV : Mem :=
  { blocks := fun c => if 1 ≤ c ∧ c ≤ 3 then some { Close.blk with size := 16 } else none,
    next := 4 }

/-- `memV` has no pointer byte. -/
theorem memV_bytesIn : memV.BytesIn memV.Known :=
  fun c b i p j hc _ hp => by
    simp only [memV] at hc
    split at hc
    · cases hc
      cases hp
    · cases hc

/-- **W1 to W5 on `vadd`**, for every address choice and oracle: `vadd` on `launch2 2 1 2 1` starts
on `memV` with 4 running threads and an empty trace, its contexts give thread `n` the program and
the number `n` in block of threads `n / 2`, and every grid reachable from its grid is closed, has
threads that own their allocas, has the accesses of its trace by its threads, and has its waiting
threads at their calls and the start's blocks' shapes. -/
theorem invariants (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 (launch2 2 1 2 1) argsV memV ch oracle =
        .ok (g, c) ∧
      g.threads.size = 4 ∧ (∀ (n : Nat) s, g.threads[n]? = some s → ∃ t, s = .run t) ∧
      g.mem.trace = [] ∧ (∀ n, (c n).prog = Kernels.vadd.prog ∧ (c n).who = ⟨n, n / 2⟩) ∧
      ∀ g', Relation.ReflTransGen (Grid.Step (launch2 2 1 2 1) c) g g' →
        g'.Closed c ∧ g'.Owns c ∧ g'.ByThreads (launch2 2 1 2 1) ∧ g'.AtCalls c ∧
          g.mem.Keeps g'.mem := by
  -- The start's grid and contexts stay opaque; only `hst` evaluates them.
  obtain ⟨g, c, h⟩ : ∃ g c,
      Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 (launch2 2 1 2 1) argsV memV ch oracle =
        .ok (g, c) :=
    ⟨_, _, rfl⟩
  have hst :
      (Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 (launch2 2 1 2 1) argsV memV ch oracle).map
      (fun x => (x.1.threads.size, x.1.mem.trace)) = .ok (4, []) := rfl
  simp only [h, Except.map, Except.ok.injEq, Prod.mk.injEq] at hst
  refine ⟨g, c, h, hst.1, fun n s hs => ?_, hst.2,
    fun n => (Grid.start_ctx h n).imp_right And.left, fun g' hr =>
    ⟨Grid.start_reach_closed h memV_bytesIn hr, Grid.reach_owns hr (Grid.start_owns h c),
      Grid.start_reach_byThreads h hr, Grid.start_reach_atCalls h hr, Grid.reach_keeps hr⟩⟩
  obtain ⟨-, -, t, -, e⟩ := Grid.start_run h n s hs
  exact ⟨t, e⟩

/-- A block of `memV`'s shape whose byte 0 is a pointer to block 2000. -/
def blkP : MojoProof.Sem.Block :=
  { Close.blk with size := 16, bytes := fun i => if i = 0 then .ptr ⟨2000, 0⟩ 0 else .undef }

/-- `memV` with block 1000, `blkP` (above the numbers the start gives its `byval` copies). -/
def memP : Mem := { memV with blocks := fun c => if c = 1000 then some blkP else memV.blocks c }

/-- The twin of W1's premise that the caller's pointer bytes name known numbers: `vadd` on
`launch2 2 1 2 1` starts on `memP` (the start's check reads the bytes of the blocks below `next`
only), for every address choice and oracle, but its grid is not closed: block 1000 is kept
(`Grid.start_blocks`) and names block 2000, which is from `next` on and has no block. -/
theorem closed_twin (ch : Nat → Nat) (oracle : Nat → Nat → Nat) :
    ∃ g c, Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 (launch2 2 1 2 1) argsV memP ch oracle =
        .ok (g, c) ∧ ¬ g.Closed c := by
  have h : Grid.start Kernels.vadd.prog Kernels.vadd.fn_0 (launch2 2 1 2 1) argsV memP ch oracle =
      .ok (_, _) := rfl
  refine ⟨_, _, h, fun hg => ?_⟩
  have := hg.bytes 1000 blkP 0 _ _ (Grid.start_blocks h rfl) (by decide) rfl
  simp [Mem.Known, Mem.compact_eq, Mem.set, memP, memV] at this

/-- The twin of W4's premise that the contexts are the start's: in `ctxOf`, which puts both
threads in block of threads 0, on a launch of one thread per block of threads, `stores 0` (an
empty trace) has W4, but after thread 1's store, by thread 1 in block of threads 0, it does
not. -/
theorem byThreads_twin : (stores 0).ByThreads (launch2 1 1 1 1) ∧
    ∃ g', Grid.Step (launch2 1 1 1 1) ctxOf (stores 0) g' ∧ ¬ g'.ByThreads (launch2 1 1 1 1) := by
  obtain ⟨g', h1, ht⟩ : ∃ g', (stores 0).advance ctxOf 1 = .ok (some g') ∧
      g'.mem.trace = [Same.w 1 0] := ⟨_, rfl, rfl⟩
  refine ⟨(fun _ ha => nomatch ha), g', ⟨1, .inl h1⟩, fun hg => ?_⟩
  have := (hg _ (by rw [ht]; exact List.mem_cons_self)).2
  simp [launch2, volume] at this

end MojoProofTest.Start
