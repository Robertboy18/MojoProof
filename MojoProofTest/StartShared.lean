import MojoProof.Sym.StartShared
import MojoProofTest.OblGevm
import MojoProofTest.SymSeg

/-!
# Tests of `Grid.start_shared`: the start's shared arrays of two corpus programs

`Grid.start_shared` (MojoProof/Sym/StartShared.lean) at gevm_kernel's start at one block of 1024
threads (its one internal shared global, 4096 bytes), and at the layer-norm program `ln`'s start
at every launch (its one internal shared global, 48 bytes), each by the theorem with its premises
(the global's position, its `undef` initializer, no other global of its name) evaluated. No run
is evaluated.
-/

namespace MojoProofTest.StartShared

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane

/-- **gevm_kernel's shared array at one block.** gevm_kernel (the corpus file) at one block of
1024 threads (`launch2 1 1 1024 1`), for every argument values, memory, address choice `ch` and
oracle with which the launch starts: every thread's context names the shared array
(`OblGevm.sharedName`) at offset 0 of one block of the start's memory, of 4096 bytes in address
space 3, writable, owned by the block of threads 0, with undefined bytes, at the addresses
`ch (Nat.pair 2 2) * 4 % 2 ^ 32` and `ch (Nat.pair 2 3) * 4 % 2 ^ 64`. -/
theorem gevm_one_block {args : List Val} {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat}
    {g : Grid} {c : Nat → Ctx}
    (h : Grid.start gevm.prog gevm.fn_0 (launch2 1 1 1024 1) args m ch oracle = .ok (g, c)) :
    ∃ q, (∀ n < 1024, (c n).globals MojoProofTest.OblGevm.sharedName = some ⟨q, 0⟩) ∧
      g.mem.blocks q = some
        { space := 3, size := 4096, live := true, readOnly := false, owner := .cta 0,
          bytes := fun _ => .undef, addr := ch (Nat.pair 2 2) * 4 % 2 ^ 32,
          gaddr := ch (Nat.pair 2 3) * 4 % 2 ^ 64 } := by
  obtain ⟨q, hc, hb, -⟩ := Grid.start_shared h (i := 0) (List.getElem?_eq_getElem (by decide)) rfl
    (by decide)
  refine ⟨q 0, fun n hn => ?_, hb 0 (by decide)⟩
  have hv : n / volume (launch2 1 1 1024 1).block = 0 :=
    Nat.div_eq_of_lt (by simpa [volume, launch2] using hn)
  have := hc n (by rw [hv]; decide)
  rw [hv] at this
  exact this

/-- **The layer-norm program's shared array at every launch.** The program `ln`
(MojoProofTest/SymSeg.lean's `mojo_import`), for every launch `L`, argument values, memory,
address choice `ch` and oracle with which the launch starts: there are block numbers `q b` such
that every context of block of threads `b < volume L.grid` names the shared array at offset 0 of
`q b`, the start's memory has at `q b` a block of 48 bytes in address space 3, writable, owned by
`b`, with undefined bytes, at the addresses `ch (Nat.pair (b + 2) 2) * 4 % 2 ^ 32` and
`ch (Nat.pair (b + 2) 3) * 4 % 2 ^ 64`, and different blocks of threads have different blocks. -/
theorem ln_every_launch {L : Launch} {args : List Val} {m : Mem} {ch : Nat → Nat}
    {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start MojoProofTest.SymSeg.ln.prog MojoProofTest.SymSeg.ln.fn_0 L args m ch oracle =
      .ok (g, c)) :
    ∃ q : Nat → Nat, (∀ n, n / volume L.block < volume L.grid →
        (c n).globals "rowwise_block_t0_r1_ax0_w1_bs128_847b1b53._global_alloc_0._gpu_shared_mem" =
          some ⟨q (n / volume L.block), 0⟩) ∧
      (∀ b < volume L.grid, g.mem.blocks (q b) = some
        { space := 3, size := 48, live := true, readOnly := false, owner := .cta b,
          bytes := fun _ => .undef, addr := ch (Nat.pair (b + 2) 2) * 4 % 2 ^ 32,
          gaddr := ch (Nat.pair (b + 2) 3) * 4 % 2 ^ 64 }) ∧
      ∀ b < volume L.grid, ∀ b' < volume L.grid, q b = q b' → b = b' :=
  Grid.start_shared h (i := 0) (List.getElem?_eq_getElem (by decide)) rfl (by decide)

end MojoProofTest.StartShared
