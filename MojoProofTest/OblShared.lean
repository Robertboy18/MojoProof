import MojoProofTest.SymLoop
import MojoProof.Sym.Obl

/-!
# mojo_obl through pointers of shared memory

`cnt3` is the counting loop `cnt` of MojoProofTest/SymLoop.lean with its array in shared memory:
its body's `getelementptr` and `store` go through pointers of address space 3. A buffer of shared
memory is a `Mem.BufferIn` of space 3, owned by one block of threads (`.cta g`, as the
semantics' `shared` makes it), not a `Mem.Buffer` (space 1, owned by every thread).

* `cnt3_covers`: the path checker accepts `cnt`'s loop paths for `cnt3`, so the summaries are
  `cnt`'s (`cntH`, `cntB`); the address space is in the function's instructions.
* `cnt3_rounds`: mojo_obl proves the loop's rounds for every bound under an invariant that
  describes the shared buffer, by `gep_buffer` and `store_buffer` in space 3.
* `cnt3_rounds_open`: the twin, with the fact that the buffer's owner admits the thread behind
  an irreducible definition; the store's obligation is left open, as logged.
-/

namespace MojoProofTest.OblShared

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLoop

/-- The counting loop `for i in [0, n): p[i] = i` on an `i64` array at `%p` in shared memory
(address space 3): `cnt` with its body's `getelementptr` and `store` through pointers of
space 3. -/
def cnt3 : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "cnt3", params := [],
    group := none, names := #["entry", "hdr", "body", "exit", "i", "inext", "c", "n", "p", "q"],
    blocks := #[⟨0, #[], .br 1⟩,
      ⟨1, #[{ res := some 4, inst := .phi (.int 64) [(.int 0, 0), (.loc 5, 2)] },
        { res := some 6, inst := .icmp .slt (.int 64) (.loc 4) (.loc 7) }], .condBr (.loc 6) 2 3⟩,
      ⟨2, #[{ res := some 5, inst := .bin .add { nsw := true } (.int 64) (.loc 4) (.int 1) },
        { res := some 9,
          inst := .gep {} (.int 64) (.mk (.ptr 3) (.loc 8)) [.mk (.int 64) (.loc 4)] },
        { res := none,
          inst := .store false (.mk (.int 64) (.loc 4)) (.mk (.ptr 3) (.loc 9)) (some 8) }],
        .br 1⟩,
      ⟨3, #[], .ret none⟩] }

/-- The program of `cnt3` alone. -/
def cnt3P : Program := .ofFunc cnt3

/-- The path checker with `phi`s accepts `cnt`'s loop paths (`cntL` of
MojoProofTest/SymLoop.lean) for `cnt3` (`LoopPaths.covers`): a summary does not record the
address space of a pointer, so `cnt3`'s blocks have `cnt`'s summaries `cntE`, `cntH` and `cntB`,
and the address space comes from the function's instructions at the valuation. -/
theorem cnt3_covers : cntL.covers cnt3P cnt3 0 = true := by
  decide +kernel

/-- The facts of round `i` of `cnt3` for the bound `n`, the block `b` and the block of threads
`g`, one conjunction: valuation `W` is in a context of `cnt3P` and in `cnt3`, `%i = i`, `%n = n`,
`%p` is at offset 0 of `b`, `b` is a writable buffer of shared memory (space 3) owned by `g` of
`n` cells of `i64` (`8 n` bytes) aligned to 8, `W`'s thread is in `g`, and the buffer's address
in space 3 plus its size is at most `2 ^ 64`, 2 to the width of the pointers of space 3. -/
def inv3 (n b g i : Nat) (W : Valuation) : Prop :=
  W.ctx.prog = cnt3P ∧ W.fn = cnt3 ∧ W.regs 4 = some (.bits 64 (BitVec.ofNat 64 i)) ∧
    W.regs 7 = some (.bits 64 (BitVec.ofNat 64 n)) ∧ W.regs 8 = some (.ptr ⟨b, 0⟩) ∧
    W.mem.BufferIn 3 b (8 * n) 8 (.cta g) true ∧ (Owner.cta g).admits W.ctx.who = true ∧
    ∃ blk, W.mem.blocks b = some blk ∧ blk.addr + 8 * n ≤ 2 ^ (cnt3P.layout.ptr 3).1

/-- **The rounds of the loop on shared memory, by mojo_obl**: for every bound `n ≤ 2 ^ 60`, block
`b`, block of threads `g`, round `i < n` and valuation `W` of `inv3 n b g i`, the round's
premises hold at `W` (`Round`: the header's comparison `i < n` is true, the body's increment,
address and store of cell `i` run, its edge goes to the header at position 1). The address of
cell `i` and the store, through pointers of address space 3, are by `gep_buffer` and
`store_buffer` in that space, the buffer by `inv3`'s `Mem.BufferIn`, its owner admitting the
thread by `inv3`'s `Owner.admits`. -/
theorem cnt3_rounds : ∀ n b g : Nat, n ≤ 2 ^ 60 → ∀ i < n, ∀ W : Valuation, inv3 n b g i W →
    Round 1 1 cntH.obls cntH [(2, cntB.obls, cntB)] W := by
  mojo_obl

/-- Thread `W.ctx.who` is in block of threads `g`, as the owner `.cta g` admits it; irreducible,
so that mojo_obl does not find it. -/
@[irreducible] def InCta (W : Valuation) (g : Nat) : Prop := (Owner.cta g).admits W.ctx.who = true

/-- `inv3` with the fact that the buffer's owner admits the thread stated as `InCta`. -/
def inv3C (n b g i : Nat) (W : Valuation) : Prop :=
  W.ctx.prog = cnt3P ∧ W.fn = cnt3 ∧ W.regs 4 = some (.bits 64 (BitVec.ofNat 64 i)) ∧
    W.regs 7 = some (.bits 64 (BitVec.ofNat 64 n)) ∧ W.regs 8 = some (.ptr ⟨b, 0⟩) ∧
    W.mem.BufferIn 3 b (8 * n) 8 (.cta g) true ∧ InCta W g ∧
    ∃ blk, W.mem.blocks b = some blk ∧ blk.addr + 8 * n ≤ 2 ^ (cnt3P.layout.ptr 3).1

/--
info: mojo_obl: open goal
  Cond.Holds (W.into 1 cntH) (vals (W.into 1 cntH) cntB.nodes)
    (Cond.mem [SEff.store 2 2 (SVal.reg 4) (SVal.node 1)])
-/
#guard_msgs (whitespace := lax) in
/-- **The twin of `cnt3_rounds`**: with the thread's block behind the irreducible `InCta`,
mojo_obl finds no fact that the shared buffer's owner `.cta g` admits the thread, so it leaves
open the obligation that the body's store runs, as logged, and proves the rest; unfolding
`InCta` lets it close it. -/
theorem cnt3_rounds_open : ∀ n b g : Nat, n ≤ 2 ^ 60 → ∀ i < n, ∀ W : Valuation,
    inv3C n b g i W → Round 1 1 cntH.obls cntH [(2, cntB.obls, cntB)] W := by
  mojo_obl
  unfold InCta at *
  mojo_obl

end MojoProofTest.OblShared
