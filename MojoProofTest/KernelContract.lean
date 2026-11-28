import MojoProofTest.KernelCells
import MojoProofTest.KernelCmd

/-!
# The kernel theorem with `fmul contract` in a loop, at a launch of six threads

Tests. Two instances with every premise closed of the kernel theorem at `contract = true`, with
no `byval` struct and two scalars: `Kernel.sound_mapNWith` (so `Kernel.sound_cellsWith`) by hand,
and `mojo_kernel`'s generated `n.sound_loop` with the flag `contract`, for the kernel `kf`, a
hand-built `Func` (as `MojoProofTest/KernelCells.lean` writes `kc`), whose threads each run a loop
of `%n` rounds on a float accumulator `%a` from 0.0, each round
`%a1 = fadd contract (fmul contract %a, 2.0), 1.0` (the shape of the naive matrix product's latch,
`MojoProofTest/SymContract.lean`), then store `%a` to cell `%ctaid.x * %n + %tid.x` of a `float`
array. On the launch `L23` (two blocks of three threads) with `%n = 3`, every thread stores 7.0
(0, 1, 3, 7) to its own cell.

* `kf`, `kfP`, its block summaries (`kfB` with `fmul contract`, `summarizeC`), the loop `loopF`
  and the sequence of loops `chainF`. `chainF_covers`: the path checker with `fmul contract`
  accepts it.
* The launch: `outF`, `argsF`, its scalars `scF` (`namesF`: each parameter is named by its
  position), the cells `cell` of MojoProofTest/Kernel.lean (offset `4 * k`: at `%n = 3` thread
  `k` of `L23`, block `b = k / 3` and thread `t = k % 3`, stores to cell `b * 3 + t = k`), `bsF`,
  `apartF` and the start `startF`. `entryF`: a valuation with the start's facts (those of
  `Kernel.sound_mapNWith`'s premise and of `kfK.sound_loop`'s) is its normal form with literal
  fields.
* The loop one round at a time: `accF` (`%a` after `i` rounds), the invariant `invF`, its normal
  form `normF` (`normF_eq`), `roundsF` (each round, for every thread, context and memory) and
  `chainF_of` (the three rounds from the invariant, `ChainWith.loop`), so that the kernel
  evaluates each round once, from literal values (evaluating three rounds' nested float
  operations at once exceeds the kernel's recursion depth).
* `kernelF`: the kernel theorem at the oracle `ω₁`, at which every `fadd contract` fuses with
  the recorded product (one rounding), for every context and frame that the start's facts
  describe, by `Kernel.sound_mapNWith`. It covers this one program, launch, argument list,
  memory, address choice and oracle.
* The twin: `chainF_refused`, the checker without `fmul contract` refuses `chainF` (at the body's
  `fmul contract`), so `kernelF`'s proof with `contract = false` fails (checked by the tactic
  fail_if_success).
* `kfK`: `mojo_kernel` on `kf` with the flag `contract` and a loop clause whose precondition
  `preF` is the start's facts of some thread of `L23` with a memory of the invariant `memF` (the
  memory after that many threads, `Elem` and `Elem.Only` from a memory with `outF`'s blocks), the
  invariant `invF` of the valuation's thread and the postcondition `memF` after one more thread;
  its tactic closes the four obligations for every valuation of `preF` by evaluation in the
  kernel, thread by thread, each round once (`entryF`, `normF_eq`, `roundsF`, `mem_eta`,
  `ret_storeWith`). `kfK_retLs`: `kfK.loop` at thread 0's entry valuation `VF`, an instance of
  `preF`. `kernelK`: the generated kernel theorem `kfK.sound_loop`
  (`Kernel.sound_entryWith (contract := true)`) with every premise closed (`outF_closed`,
  `memF_zero`, `memF_end`, each thread's facts give `preF`), on `L23` at every address choice and
  the oracle `ω₁`. With `mojo_kernel.share`, its summaries of blocks 0, 1 and 3 are `kfE`, `kfH`
  and `kfS`, and its paths (none) are MojoProofTest/KernelCmd.lean's `cntk.paths`. The twins
  (`#guard_msgs`): without the flag the command refuses the body, with the flag and no loop
  clause it refuses the loop (naming its header), and a tactic that leaves the round and the path
  out is named with them. The per-thread premise of `kfK.sound_loop` that `kernelK` proves is
  checked left open, with the thread's oracle.
* `kg`, `kgP`: a loop-free kernel with `fmul contract` and `fadd contract`. `kgK`: `mojo_kernel`
  on it with the flag `contract` and no loop clause (`kgK.sound_of`,
  `Kernel.sound_of_chainsAt (alloca := false) (contract := true)` at `kgK.covers` and no sequence
  of loops, with `Mem.Dead false` unfolded).
  Without `mojo_kernel.share` its arguments are the module's `kfK.args`, and `kgK.args` is not
  added. The twin: without the flag the command refuses its block.
* `contractProg` (vadd's program under another hash) and `map2_contract`: `mojo_kernel` on it
  with the `map2` clause and the flag `contract` (`map2_contract.covers`, `coversEntryWith true`
  on vadd's paths; `map2_contract.ret`, a `RetWith true` by `RetWith.exists_true_of_ret`;
  `map2_contract.correct`, `Kernel.sound_map2With (contract := true)`).
-/

namespace MojoProofTest.KernelContract

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.ScheduleOwned (tidName)
open MojoProofTest.Kernel (ch₀ L23 cell)
open MojoProofTest.KernelCells (ctaidName sreg mem_eta ret_storeWith)

/-- The kernel `@kf(i32 %n, ptr addrspace(1) %p)`, its parameters in registers `%0` and `%1`
(their positions, as `Kernel.sound_mapNWith` takes them): thread `(b, t)` (`%ctaid.x`,
`%tid.x`) runs `%n` rounds of `%a = %a * 2.0 + 1.0` from `%a = 0.0` (`fmul contract`, then
`fadd contract` on its result), counting `%i` from 0 to `%n`, then stores `%a` to cell
`b * n + t` of the `float` array at `%p`. Its locals are numbered as the parser numbers them,
one index space for parameters, block labels and results: `%n` and `%p` are locals 0 and 1, the
blocks' labels 2 to 5 and the results 6 to 16. Blocks: the entry `2`; the header `3`
(`%i = phi i32 [0, entry], [%i1, body]`, `%a = phi float [0.0, entry], [%a1, body]`,
`icmp slt %i, %n`); the body `4` (`%m = fmul contract %a, 2.0`, `%a1 = fadd contract %m, 1.0`,
`%i1 = add nsw %i, 1`, the back edge); the store `5`. -/
def kf : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "kf",
    params := [⟨.int 32, [], some 0⟩, ⟨.ptr 1, [], some 1⟩], group := none,
    names := #["n", "p", "entry", "hdr", "body", "st", "b", "t", "i", "a", "c", "m", "a1", "i1",
      "r", "x", "q"],
    blocks := #[
      ⟨2, #[{ res := some 6, inst := .call {} (.int 32) (.fn ctaidName) [] },
        { res := some 7, inst := .call {} (.int 32) (.fn tidName) [] }], .br 3⟩,
      ⟨3, #[{ res := some 8, inst := .phi (.int 32) [(.int 0, 2), (.loc 13, 4)] },
        { res := some 9, inst := .phi (.fp .float) [(.float (.hex "" 0), 2), (.loc 12, 4)] },
        { res := some 10, inst := .icmp .slt (.int 32) (.loc 8) (.loc 0) }],
        .condBr (.loc 10) 4 5⟩,
      ⟨4, #[
        { res := some 11,
          inst := .fbin .fmul { contract := true } (.fp .float) (.loc 9)
            (.float (.hex "" 0x4000000000000000)) },
        { res := some 12,
          inst := .fbin .fadd { contract := true } (.fp .float) (.loc 11)
            (.float (.hex "" 0x3FF0000000000000)) },
        { res := some 13, inst := .bin .add { nsw := true } (.int 32) (.loc 8) (.int 1) }],
        .br 3⟩,
      ⟨5, #[{ res := some 14, inst := .bin .mul {} (.int 32) (.loc 6) (.loc 0) },
        { res := some 15, inst := .bin .add {} (.int 32) (.loc 14) (.loc 7) },
        { res := some 16,
          inst := .gep {} (.fp .float) (.mk (.ptr 1) (.loc 1)) [.mk (.int 32) (.loc 15)] },
        { res := none,
          inst := .store false (.mk (.fp .float) (.loc 9)) (.mk (.ptr 1) (.loc 16)) (some 4) }],
        .ret none⟩] }

/-- The program of `kf` and the declarations of `%tid.x` and `%ctaid.x`, with the default data
layout. -/
def kfP : Program :=
  { module := { (default : Module) with funcs := #[kf, sreg tidName, sreg ctaidName] },
    sha256 := "", layout := {},
    intrinsics := [(tidName, .sreg .tid .x), (ctaidName, .sreg .ctaid .x)],
    kernels := ["kf"] }

/-- The entry block: the two special registers, then `br` to the header. -/
sym_summary kfE := kfP kf 2 0

/-- The header from position 2, after its two `phi`s. -/
sym_summary kfH := kfP kf 3 2

/-- The body with `fmul contract` in the fragment (`summarizeC`; the default summary if it
refuses, which `chainF_covers` excludes). -/
def kfB : Summary := (summarizeC kfP kf 4 0).getD default

/-- The store and `ret`. -/
sym_summary kfS := kfP kf 5 0

/-- The loop: header `3` at position 2, loop path `3 → 4`, path out `3 → 5`. -/
def loopF : LoopSeg :=
  ⟨3, 2, kfH.obls, kfH, [(4, kfB.obls, kfB)], [(5, kfS.obls, kfS)], []⟩

/-- The sequence of loops from the entry block to the store: the loop `loopF`. -/
def chainF : LoopChain := ⟨2, kfE.obls, kfE, [], [loopF]⟩

/-- **The checker with `fmul contract` accepts the loop**: `chainF` starts at `kf`'s first block,
and the path checker with `phi`s and `fmul contract` accepts the entry block, the loop path and
the path out. -/
theorem chainF_covers : coversChainsWith true kfP kf [chainF] = true := by
  decide +kernel

/-- **The twin: the checker without `fmul contract` refuses the loop**, at the body's
`fmul contract` (`summarize` gives no summary of block 4). -/
theorem chainF_refused : coversChainsWith false kfP kf [chainF] = false := by
  decide +kernel

/-! ## The launch -/

/-- The caller's memory: one global block of six `float` cells (24 bytes, aligned to 4), and its
number. -/
def outF : Mem × Nat := ({} : Mem).alloc kfP.layout 1 24 4 true false .all 1 1

/-- The arguments: `%n = 3` and `%p` at offset 0 of `outF`'s block. -/
def argsF : List Val := [.bits 32 (BitVec.ofNat 32 3), .ptr ⟨outF.2, 0⟩]

/-- `kf`'s parameters with their arguments `argsF` and the values their attributes (none) take
them to: `%0` the `i32` 3 and `%1` the pointer to offset 0 of `outF`'s block. -/
def scF : List (Param × Val × Val) :=
  [(⟨.int 32, [], some 0⟩, .bits 32 (BitVec.ofNat 32 3), .bits 32 (BitVec.ofNat 32 3)),
    (⟨.ptr 1, [], some 1⟩, .ptr ⟨outF.2, 0⟩, .ptr ⟨outF.2, 0⟩)]

/-- Each parameter of `kf` is named by its position. -/
theorem namesF : ∀ j (p : Param), kf.params[j]? = some p → p.name = some j := by
  intro j p h
  obtain ⟨hj, rfl⟩ := List.getElem?_eq_some_iff.1 h
  have : j < 2 := hj
  interval_cases j <;> rfl

/-- Every oracle number 1: each `fadd contract` whose first operand is a recorded `fmul contract`
product fuses them (`contract` at `n % 3 = 1`, one rounding). -/
def ω₁ : Nat → Nat → Nat := fun _ _ => 1

/-- Every thread's bytes: the binary32 word of 7.0 (`0x40e00000`), `%a` after three rounds. -/
def bsF (_ : Nat) : Option (List MemByte) :=
  kfP.layout.encode (.fp .float) (.bits 32 (BitVec.ofNat 32 0x40e00000))

/-- The cells of all threads are 4 bytes apart (`apart_mul`). -/
theorem apartF : Apart (fun i : Subtype fun _ : Nat => True => cell i) 4 :=
  (apart_mul 4).comp Subtype.val_injective

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The start's grid and contexts on `L23`, `argsF` and `outF` at `ch₀` and `ω₁` (the empty grid
if it faults). -/
def runF : Grid × (Nat → Ctx) :=
  match Grid.start kfP kf L23 argsF outF.1 ch₀ ω₁ with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => SymRun.ctx0)

/-- **The launch starts**, with grid `runF.1` and contexts `runF.2` (evaluated). -/
theorem startF : Grid.start kfP kf L23 argsF outF.1 ch₀ ω₁ = .ok (runF.1, runF.2) := rfl

/-- `outF` has no pointer byte. -/
theorem outF_bytesIn : outF.1.BytesIn outF.1.Known :=
  Mem.alloc_bytesIn (fun _ _ _ _ _ h => by cases h) (init := []) (fun _ _ h => by cases h)
    _ _ _ _ _ _ _ _ _ _

/-- **A thread's valuation with literal fields.** For every valuation `V` of `kfP` with thread
`k`'s special registers of `L23`, identity and oracle `ω₁ k`, function `kf` and registers `%0` and
`%1` holding `scF`'s values (the facts that `Kernel.sound_mapNWith`'s premise gives of a thread's
entry valuation and `kfK.sound_loop`'s per-thread premise of every valuation it takes): `V` is the
valuation with these fields literal, registers `%0`, `%1` a chain of `if`s and its other fields
`V`'s, so that evaluation in the kernel reads them without inspecting `V`. -/
theorem entryF {V : Valuation} {k : Nat} (hP : V.ctx.prog = kfP) (hE : V.ctx.env = L23.env k)
    (hW : V.ctx.who = ⟨k, k / volume L23.block⟩) (hω : V.ctx.oracle = ω₁ k) (hf : V.fn = kf)
    (h0 : V.regs 0 = some (.bits 32 (BitVec.ofNat 32 3)))
    (h1 : V.regs 1 = some (.ptr ⟨outF.2, 0⟩)) :
    V = ⟨{ V.ctx with prog := kfP, env := L23.env k, who := ⟨k, k / 3⟩, oracle := ω₁ k }, kf, V.k,
      V.mem, fun r => if r = 0 then some (.bits 32 (BitVec.ofNat 32 3))
        else if r = 1 then some (.ptr ⟨outF.2, 0⟩) else V.regs r, V.prods⟩ := by
  rcases V with ⟨c, fn, k', m, regs, prods⟩
  rcases c with ⟨prog, globals, env, who, addr, oracle⟩
  dsimp only at hP hE hW hω hf h0 h1
  subst hP hE hW hω hf
  congr 1
  funext r
  split_ifs <;> simp_all

/-! ## The loop, one round at a time -/

/-- `%a` after `i` rounds of `kf`'s loop from 0.0, for `i ≤ 3`: the binary32 word of 0.0, 1.0,
3.0 or 7.0 (`2 ^ i - 1`). -/
def accF (i : Nat) : Val :=
  .bits 32 (BitVec.ofNat 32 ([0, 0x3f800000, 0x40400000, 0x40e00000].getD i 0))

/-- The loop's invariant after `i` rounds, for thread `k` with context `c` and memory `m`: `W`
has `c` with `kfP`, the identity `⟨k, k / 3⟩` and the oracle `ω₁ k`, the function `kf`, the
memory `m`, `%n` (register 0) equal to 3, `%p` (1) the pointer to `outF`'s block, `%b` and `%t`
(6, 7) equal to `k / 3` and `k % 3`, the counter `%i` (8) equal to `i` and the accumulator `%a`
(9) equal to `accF i`. -/
abbrev invF (c : Ctx) (m : Mem) (k i : Nat) (W : Valuation) : Prop :=
  W.ctx = { c with prog := kfP, who := ⟨k, k / 3⟩, oracle := fun _ => 1 } ∧ W.fn = kf ∧
    W.mem = m ∧ W.regs 0 = some (.bits 32 (BitVec.ofNat 32 3)) ∧
    W.regs 1 = some (.ptr ⟨outF.2, 0⟩) ∧ W.regs 6 = some (.bits 32 (BitVec.ofNat 32 (k / 3))) ∧
    W.regs 7 = some (.bits 32 (BitVec.ofNat 32 (k % 3))) ∧
    W.regs 8 = some (.bits 32 (BitVec.ofNat 32 i)) ∧ W.regs 9 = some (accF i)

/-- The valuation that `invF c m k i` determines, with `W`'s step count, other registers and
`fmul contract` operands: its context, function and memory are literal and registers 0, 1 and 6
to 9 a chain of `if`s on their values, so evaluation in the kernel reads them without inspecting
`c`, `m` or `W`. -/
def normF (c : Ctx) (m : Mem) (k i : Nat) (W : Valuation) : Valuation :=
  ⟨{ c with prog := kfP, who := ⟨k, k / 3⟩, oracle := fun _ => 1 }, kf, W.k, m, fun r =>
    if r = 0 then some (.bits 32 (BitVec.ofNat 32 3)) else if r = 1 then some (.ptr ⟨outF.2, 0⟩)
    else if r = 6 then some (.bits 32 (BitVec.ofNat 32 (k / 3)))
    else if r = 7 then some (.bits 32 (BitVec.ofNat 32 (k % 3)))
    else if r = 8 then some (.bits 32 (BitVec.ofNat 32 i))
    else if r = 9 then some (accF i) else W.regs r, W.prods⟩

/-- A valuation of the invariant is its normal form: for every context `c`, memory `m`, thread
`k`, round `i` and valuation `W`, `invF c m k i W` gives `W = normF c m k i W`. -/
theorem normF_eq {c : Ctx} {m : Mem} {k i : Nat} {W : Valuation} (h : invF c m k i W) :
    W = normF c m k i W := by
  obtain ⟨h1, h2, h3, h4, h5, h6, h7, h8, h9⟩ := h
  rcases W with ⟨c', fn, k', m', regs, prods⟩
  dsimp only at h1 h2 h3 h4 h5 h6 h7 h8 h9
  subst h1 h2 h3
  unfold normF
  congr 1
  funext r
  split_ifs <;> simp_all

/-- **Each round of `kf`'s loop with `fmul contract`, for every thread, context and memory**:
for every context `c`, memory `m`, thread `k`, round `i < 3` and valuation `W`, the round's
premises hold at `normF c m k i W` (`RoundWith true`: the header, then the body with the
`fmul contract` operands of `%m` recorded and read by `fadd contract` at the oracle number 1,
which fuses) and `invF c m k (i + 1)` holds after it (evaluation in the kernel). -/
theorem roundsF (c : Ctx) (m : Mem) (k : Nat) : ∀ i < 3, ∀ W,
    RoundWith true loopF.h loopF.p loopF.dh loopF.H loopF.B (normF c m k i W) ∧
      invF c m k (i + 1) (Valuation.roundWith true loopF.h loopF.H loopF.B (normF c m k i W)) := by
  intro i hi W
  interval_cases i <;> kernel_check

/-- **The three rounds of `kf`'s loop from the invariant `invF`**, with or without
`fmul contract`. For every flag `b`, predicate `F`, thread `k` and valuation `V` at `kf`'s entry
block, with `V`'s context and memory in the invariant: suppose the entry block's premises hold,
its edge goes to the header at position 2 (`EdgeWith`) and `invF V.ctx V.mem k 0` holds after
it; for each round `i < 3` and every valuation `W`, the round's premises hold at
`normF V.ctx V.mem k i W` (`RoundWith`) and `invF V.ctx V.mem k (i + 1)` after it; and `F` holds
of the path out from `normF V.ctx V.mem k 3 W`. Then `ChainWith b F` holds of `chainF`'s loops
at `V` (`ChainWith.loop` with the invariant `invF V.ctx V.mem k`, `normF_eq`). -/
theorem chainF_of {b : Bool}
    {F : Valuation → Nat → List Cond → Summary → List (Nat × List Cond × Summary) → Prop}
    (k : Nat) {V : Valuation}
    (he : EdgeWith b loopF.h loopF.p V chainF.l chainF.ds chainF.S chainF.E ∧
      invF V.ctx V.mem k 0 (Valuation.roundWith b chainF.l chainF.S chainF.E V))
    (hr : ∀ i < 3, ∀ W, RoundWith b loopF.h loopF.p loopF.dh loopF.H loopF.B
        (normF V.ctx V.mem k i W) ∧
      invF V.ctx V.mem k (i + 1)
        (Valuation.roundWith b loopF.h loopF.H loopF.B (normF V.ctx V.mem k i W)))
    (hx : ∀ W, ChainWith b F [] (normF V.ctx V.mem k 3 W) loopF.h loopF.dh loopF.H loopF.X) :
    ChainWith b F [loopF] V chainF.l chainF.ds chainF.S chainF.E :=
  .loop (invF V.ctx V.mem k) 3 he.1 he.2
    (fun i hi W hW => by rw [normF_eq hW]; exact .last (hr i hi W))
    (fun W hW => by rw [normF_eq hW]; exact hx W)

/-- The proof of `kernelF` at flag `b`: `Kernel.sound_mapNWith (contract := b)` on `chainF` with
no struct and the scalars `scF`, the checker's premise by evaluation, and each thread's entry
block and store by evaluation in the kernel (`entryF`) and its three rounds by `roundsF`
(`chainF_of`), on a memory of `Elem` and `Elem.Only` symbolic but for its output block
(`mem_eta`, `kernel_check`, `ret_storeWith`). -/
local macro "kernelF_proof" b:term : tactic => `(tactic| (
  refine Kernel.sound_mapNWith (contract := $b) (paths := []) (chains := [chainF]) (ps := [])
    (sc := scF) (T := .struct [.ptr 0, .struct []]) (z := .agg []) (bl := []) (o := outF.2)
    (S := fun _ => True) rfl (by decide +kernel) rfl namesF (fun _ h => by cases h)
    (fun _ h => by
      simp only [scF, List.mem_cons, List.not_mem_nil, or_false] at h
      rcases h with h | h <;> subst h <;> rfl)
    (Layout.Codec.ptrArg _ 0 (by decide +kernel) (by decide +kernel) rfl rfl rfl)
    ⟨Nat.one_dvd _, Nat.one_dvd _⟩ rfl
    (fun _ h _ => by
      simp only [scF, List.mem_cons, List.not_mem_nil, or_false] at h
      rcases h with h | h <;> subst h <;> rfl)
    outF_bytesIn ⟨_, rfl, rfl⟩ (by rintro _ _ ⟨h₁, h₂⟩; subst h₁ h₂; exact ⟨_, _, startF⟩) apartF ?_
  rintro _ _ ⟨h₁, h₂⟩ k hk c hP hEnv hW hω m₀ m' f hf - hr - ho hE hO
  subst h₁ h₂
  have hk' : k < 6 := hk
  have hc := hE.cells.trans (congrArg (Option.map _) (ho _ rfl))
  rw [entryF (V := Valuation.entry c 0 m' f) hP hEnv hW hω hf (hr 0 (by decide))
    (hr 1 (by decide))]
  rw [mem_eta hc] at hE hO ⊢
  refine .inr ⟨chainF, List.mem_singleton.2 rfl, ?_⟩
  refine chainF_of k ?_ (roundsF _ _ _) fun W => ChainWith.last (ret_storeWith
    (lbl := 5) (pc := 3) (v := .reg 9) (p := .node 2) (x := accF 3) (r := none) (vol := false)
    (t := .fp .float) (tv := .loc 9) (a := 1) (pv := .loc 16) (al := some 4) (md := []) hE hO ?_)
  all_goals interval_cases k <;> kernel_check))

/-! ## The kernel theorem -/

/-- **The kernel theorem for a kernel whose threads each run a loop with `fmul contract` and
`fadd contract` and then store one cell, at a launch of six threads** (`Kernel.sound_mapNWith`,
so `Kernel.sound_cellsWith`, at `contract = true` with no struct and the two scalars of `scF`,
every premise closed). `kf` on `L23` (two blocks of three threads) with `%n = 3` and `%p` at
offset 0 of `outF`'s block, at the admission of `ch₀` and `ω₁` alone (every `fadd contract`
fuses with the recorded product: one rounding of `%a * 2.0 + 1.0`), is sound (`Kernel.Sound`)
for the observation of the blocks and `Elem.Out`: `outF`'s block ends with the binary32 word of
7.0 at each thread's cell `4 * k`. Each thread's run (three rounds of the loop, each with the
body's `fmul contract` operands recorded and read by its `fadd contract`, then the store) is
proved for every context and frame with the start's facts and every memory of `Elem` and
`Elem.Only` by evaluation in the kernel: the entry block and the store for each thread
(`entryF`), and each round once for every thread (`roundsF`, `chainF_of`). It covers this one
program, launch, argument list, memory, address choice and oracle. -/
theorem kernelF : Kernel.Sound kfP kf L23 argsF outF.1 (fun ch o => ch = ch₀ ∧ o = ω₁)
    (fun m => some m.blocks)
    (Elem.Out outF.1 outF.2 cell bsF (volume L23.grid * volume L23.block)) := by
  kernelF_proof true

/-- **The twin: the same proof without `fmul contract` fails.** `kernelF_proof false` (the proof
of `kernelF` with `contract = false`) does not prove the statement: its premise
`coversChainsWith false kfP kf [chainF] = true` is false (`chainF_refused`). It covers this one
proof script; it does not show that no other proof exists. -/
example : Kernel.Sound kfP kf L23 argsF outF.1 (fun ch o => ch = ch₀ ∧ o = ω₁)
    (fun m => some m.blocks)
    (Elem.Out outF.1 outF.2 cell bsF (volume L23.grid * volume L23.block)) := by
  fail_if_success kernelF_proof false
  exact kernelF

/-! ## The loop with `fmul contract` by `mojo_kernel` -/

/-- The memory after `k` threads of `kf` on `L23`: from some memory `m₀` that has `outF`'s blocks,
`m` meets `Elem` after `k` threads (block `outF.2` is `m₀`'s with `bsF i`, the binary32 word of
7.0, put at cell `4 * i` for each `i < k`, every other block `m₀`'s, every access owned) and every
access to `outF.2` is by a thread (`Elem.Only`). It is the invariant of `kfK.sound_loop` in
`kernelK`, by the number of threads done. -/
abbrev memF (k : Nat) (m : Mem) : Prop :=
  ∃ m₀ : Mem, (∀ b x, outF.1.blocks b = some x → m₀.blocks b = some x) ∧
    Elem m₀ outF.2 4 cell bsF k m ∧ Elem.Only outF.2 (fun _ => True) m

/-- `memF` holds before the first thread: every memory with `outF`'s blocks and an empty trace
meets it, from itself (`Elem.zero`). -/
theorem memF_zero (m₀ : Mem) (hb : ∀ b x, outF.1.blocks b = some x → m₀.blocks b = some x)
    (ht : m₀.trace = []) : memF 0 m₀ :=
  ⟨m₀, hb, Elem.zero ht, fun a ha => by rw [ht] at ha; cases ha⟩

/-- **`memF` after all threads is the end's check of `Elem.Out`**: every memory of `memF` after the
six threads of `L23` has a trace with no data race that keeps the promise of `!invariant.load`
(`Elem.safe_on`, the cells `apartF`), and its blocks meet `Elem.Out` for `outF` (block `outF.2` is
`outF`'s with the threads' bytes put in turn, every other block of `outF` unchanged), since its
start memory has `outF`'s blocks. -/
theorem memF_end (m' : Mem) (h : memF (volume L23.grid * volume L23.block) m') :
    ((∀ a, Event.access a ∈ m'.trace → a.who.thread < volume L23.grid * volume L23.block ∧
        a.who.cta = a.who.thread / volume L23.block) → Trace.Shaped m'.trace.reverse →
      GPUProof.racy sig (m'.trace.map (Event.toCore L23)).reverse = false) ∧
      GPUProof.kept sig (m'.trace.map (Event.toCore L23)).reverse = true ∧
      ∃ y, some m'.blocks = some y ∧
      Elem.Out outF.1 outF.2 cell bsF (volume L23.grid * volume L23.block) y := by
  obtain ⟨m₀, hb, hE, hO⟩ := h
  refine ⟨(Elem.safe_on (L := L23) apartF hE hO).1, (Elem.safe_on apartF hE hO).2, _, rfl,
    fun x hx => ?_, fun b x hne hx => ?_⟩
  · rw [hE.cells, hb _ _ hx]
    rfl
  · rw [hE.rest b hne, hb _ _ hx]

/-- The loop clause's precondition of `kfK`: valuation `V` has the start's facts of some thread
`k` of `L23` (the program `kfP`, the identity `⟨k, k / volume L23.block⟩`, the special registers
`L23.env k`, the oracle `ω₁ k`, the function `kf`, `%n = 3` in register 0 and the pointer to
offset 0 of `outF`'s block in register 1), and its memory is one of `memF k`. These are the facts
that `kfK.sound_loop`'s per-thread premise gives with the invariant `memF`, so every thread's
valuation meets it (`kernelK`). -/
abbrev preF (V : Valuation) : Prop :=
  ∃ k < volume L23.grid * volume L23.block, V.ctx.prog = kfP ∧
    V.ctx.who = ⟨k, k / volume L23.block⟩ ∧ V.ctx.env = L23.env k ∧ V.ctx.oracle = ω₁ k ∧
    V.fn = kf ∧ V.regs 0 = some (.bits 32 (BitVec.ofNat 32 3)) ∧
    V.regs 1 = some (.ptr ⟨outF.2, 0⟩) ∧ memF k V.mem

/-- Thread 0's entry valuation of `kf` on `L23` with `argsF` and `outF`'s memory: the context of
`kfP` with `L23.env 0`, the identity `⟨0, 0⟩` and the oracle `ω₁ 0`, step 0, registers `%0` and
`%1` holding `%n = 3` and the pointer to offset 0 of `outF`'s block and no other, and no
`fmul contract` operand recorded. An instance of `preF`. -/
def VF : Valuation :=
  ⟨{ SymRun.ctx0 with prog := kfP, env := L23.env 0, who := ⟨0, 0⟩, oracle := ω₁ 0 }, kf, 0,
    outF.1, fun r => if r = 0 then some (.bits 32 (BitVec.ofNat 32 3))
      else if r = 1 then some (.ptr ⟨outF.2, 0⟩) else none, fun _ => none⟩

-- `kfK`: `kf` with the flag `contract` and the loop clause at the header, block 1 (the clause
-- numbers blocks by position; its label is 3), from every valuation of `preF`, with the
-- invariant `invF` of the valuation's thread, trip count 3 and the postcondition `memF` after one
-- more thread; the terms' binders have no type, since the clause elaborates each term at its
-- type. The tactic puts the valuation in its normal form (`entryF`), then evaluates in the
-- kernel, for each of the six threads, the path into the loop and the invariant at round 0, each
-- round once for every thread (`roundsF`, from the invariant's normal form `normF_eq`), and the
-- path out with its store on a memory symbolic but for its output block (`mem_eta`,
-- `ret_storeWith`). With `mojo_kernel.share`, its summaries of blocks 0, 1 and 3 (labels 2, 3
-- and 5) are `kfE`, `kfH` and `kfS`, and its paths (none) are `cntk`'s
-- (MojoProofTest/KernelCmd.lean).
set_option mojo_kernel.share true in
mojo_kernel kfK := kfP kf
  scalars n := a0
  pointers p := a1
  contract
  loop 1 := preF (fun V i W => invF V.ctx V.mem V.ctx.who.thread i W) (fun _ => 3)
      (fun V => memF (V.ctx.who.thread + 1)) by
    rintro V ⟨k, hk, hP, hW, hE, hω, hf, h0, h1, m₀, hb, hM, hO⟩
    have hk' : k < 6 := hk
    rw [entryF hP hE hW hω hf h0 h1]
    first
      | (intro i hi W hW; rw [normF_eq hW]; exact roundsF _ _ _ i hi W)
      | (intro W hW
         rw [normF_eq hW]
         have hc := hM.cells.trans (congrArg (Option.map _) (hb _ _ rfl))
         rw [mem_eta hc] at hM hO ⊢
         refine RetWith.mono (fun me h => ⟨m₀, hb, h⟩) (ret_storeWith (lbl := 5) (pc := 3)
           (v := .reg 9) (p := .node 2) (x := accF 3) (r := none) (vol := false) (t := .fp .float)
           (tv := .loc 9) (a := 1) (pv := .loc 16) (al := some 4) (md := []) hM hO ?_)
         interval_cases k <;> kernel_check)
      | (interval_cases k <;> kernel_check)

/-- **Thread 0's loop with `fmul contract` by `mojo_kernel`**: from `VF` (an instance of `preF`:
thread 0's facts, on `outF`'s memory, `memF_zero`), the generated sequence of loops of
`kfK.chains` runs to `ret` with a memory of `memF 1`: cell 0 of `outF`'s block holds the binary32
word of 7.0 (`RetLsWith true`, the generated `kfK.loop`: three rounds of the body, each
`fadd contract` reading the recorded `fmul contract` product at the oracle number 1, which fuses).
It covers this one valuation. -/
theorem kfK_retLs : ∃ C ∈ kfK.chains, RetLsWith true (memF 1) C.loops VF C.l C.ds C.S C.E :=
  kfK.loop VF ⟨0, by decide, rfl, rfl, rfl, rfl, rfl, rfl, rfl,
    memF_zero _ (fun _ _ h => h) rfl⟩ fun _ h => h

/-- `outF` is closed for `kfK.args 3 outF.2`: one block allocated on the empty memory
(`Mem.Closed.alloc`), and the arguments name no block above it. -/
theorem outF_closed : outF.1.Closed (kfK.args (BitVec.ofNat 32 3) outF.2) :=
  Mem.closed_empty.alloc kfP.layout 1 24 4 true false .all 1 1 (fun _ _ h => by cases h)
    (by decide +kernel)

/-- **The kernel theorem for `kf` by `mojo_kernel` with the flag `contract`** (`kfK.sound_loop`,
generated, every premise closed). `kf` on `L23` (two blocks of three threads) with
`kfK.args 3 outF.2` (`%n = 3`, `%p` at offset 0 of `outF`'s block) and `outF`, at every address
choice and the oracle `ω₁` (every `fadd contract` fuses with the recorded product: one rounding
of `%a * 2.0 + 1.0`), is sound (`Kernel.Sound`) for the observation of the blocks and
`Elem.Out`: `outF`'s block ends with the binary32 word of 7.0 at each thread's cell `4 * k`.
`outF` is closed (`outF_closed`), the invariant is `memF` (`memF_zero`, `memF_end`), and the
clause's precondition `preF` is the per-thread premise's facts with a memory of `memF k`, so each
of the six threads meets it, and its postcondition is `memF (k + 1)`. Each thread's run is
`kfK.loop`, whose obligations the clause's tactic proves for every valuation of `preF`. It covers
this one program, launch, argument list and memory, every address choice and the one oracle
`ω₁`. -/
theorem kernelK : Kernel.Sound kfP kf L23 (kfK.args (BitVec.ofNat 32 3) outF.2) outF.1
    (fun _ o => o = ω₁) (fun m => some m.blocks)
    (Elem.Out outF.1 outF.2 cell bsF (volume L23.grid * volume L23.block)) :=
  kfK.sound_loop _ _ outF_closed outF_bytesIn (fun _ _ h => congrArg some h) memF memF_zero
    (fun _ _ ho k hk V hP hW hE hω hf h0 h1 hM =>
      ⟨⟨k, hk, hP, hW, hE, hω.trans (congrFun (ho : _ = ω₁) k), hf, h0, h1, hM⟩, fun me h => by
        obtain ⟨m₀, hb, hM', hO⟩ := h
        exact ⟨m₀, hb, by rwa [hW] at hM', hO⟩⟩)
    memF_end

/-- error: mojo_kernel: block %body (block 2 of kf) is outside the checker's fragment -/
#guard_msgs in
mojo_kernel kf_twin := kfP kf
  scalars n := a0
  pointers p := a1
  loop 1 := preF (fun (V : Valuation) i W => invF V.ctx V.mem V.ctx.who.thread i W) (fun _ => 3)
      (fun (V : Valuation) => memF (V.ctx.who.thread + 1))

/--
error: mojo_kernel: loop at block %hdr (block 1 of kf) with no loop clause; give its precondition, invariant, trip count and postcondition by loop 1 := pre inv trips post
-/
#guard_msgs in
mojo_kernel kf_noloop := kfP kf
  scalars n := a0
  pointers p := a1
  contract

/-- The loop-free kernel `@kg(i32 %n, ptr addrspace(1) %p)`, its parameters in registers `%0`
and `%1`: thread `(b, t)` (`%ctaid.x`, `%tid.x`) computes `%a = fadd contract (fmul contract 3.0,
2.0), 1.0` and stores it to cell `b * n + t` of the `float` array at `%p`. One block, the entry,
ending in `ret`; its label is local 9, after the parameters (0, 1) and the results (2 to 8), as
the three share one index space. -/
def kg : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "kg",
    params := [⟨.int 32, [], some 0⟩, ⟨.ptr 1, [], some 1⟩], group := none,
    names := #["n", "p", "b", "t", "m", "a", "r", "x", "q", "entry"],
    blocks := #[
      ⟨9, #[{ res := some 2, inst := .call {} (.int 32) (.fn ctaidName) [] },
        { res := some 3, inst := .call {} (.int 32) (.fn tidName) [] },
        { res := some 4,
          inst := .fbin .fmul { contract := true } (.fp .float)
            (.float (.hex "" 0x4008000000000000)) (.float (.hex "" 0x4000000000000000)) },
        { res := some 5,
          inst := .fbin .fadd { contract := true } (.fp .float) (.loc 4)
            (.float (.hex "" 0x3FF0000000000000)) },
        { res := some 6, inst := .bin .mul {} (.int 32) (.loc 2) (.loc 0) },
        { res := some 7, inst := .bin .add {} (.int 32) (.loc 6) (.loc 3) },
        { res := some 8,
          inst := .gep {} (.fp .float) (.mk (.ptr 1) (.loc 1)) [.mk (.int 32) (.loc 7)] },
        { res := none,
          inst := .store false (.mk (.fp .float) (.loc 5)) (.mk (.ptr 1) (.loc 8)) (some 4) }],
        .ret none⟩] }

/-- The program of `kg` and the declarations of `%tid.x` and `%ctaid.x`, with the default data
layout. -/
def kgP : Program :=
  { module := { (default : Module) with funcs := #[kg, sreg tidName, sreg ctaidName] },
    sha256 := "", layout := {},
    intrinsics := [(tidName, .sreg .tid .x), (ctaidName, .sreg .ctaid .x)],
    kernels := ["kg"] }

-- `kgK`: `mojo_kernel` on the loop-free `kg` with the flag `contract` and no loop clause: its
-- block is in the fragment with the flag (`summarizeC`), its paths are checked by
-- `coversEntryWith true`, and `kgK.sound_of` is `Kernel.sound_of_chainsAt` at `alloca := false`,
-- `contract := true`, `kgK.covers` and no sequence of loops (`Mem.Dead false` unfolded).
-- Without `mojo_kernel.share` the command shares with the module's own earlier definitions: its
-- arguments are `kfK.args`.
mojo_kernel kgK := kgP kg
  scalars n := a0
  pointers p := a1
  contract

/-- error: Unknown identifier `kgK.args` -/
#guard_msgs in
#check kgK.args

/-- error: mojo_kernel: block %entry (block 0 of kg) is outside the checker's fragment -/
#guard_msgs in
mojo_kernel kg_twin := kgP kg
  scalars n := a0
  pointers p := a1

/-- `vector_addition`'s program under another hash, so that the theorems `mojo_kernel
map2_contract` generates are not the library's `Kernels.vadd.*` (nor MojoProofTest/KernelCmd.lean's
`paren.*`): with or without the flag, the kernel theorem's statement is the same. -/
def contractProg : Program := { Kernels.vadd.prog with sha256 := "map2_contract" }

-- `map2_contract`: `mojo_kernel` on vadd's kernel with the `map2` clause and the flag
-- `contract`: its blocks are summarized by `summarizeC` and its paths checked by
-- `coversEntryWith true`; its `map2_contract.ret` is a `RetWith true` (the `mojo_ret` proof of a
-- `Ret`, moved by `RetWith.exists_true_of_ret`, since no summary records an `fmul contract`
-- product), and `map2_contract.correct` is `Kernel.sound_map2With (contract := true)`. With
-- `mojo_kernel.share`, its definitions are vadd's where they are equal.
set_option mojo_kernel.share true in
mojo_kernel map2_contract := contractProg Kernels.vadd.fn_0
  reads a := a0, b := a1
  writes out := a2
  scalars n := a3
  map2 (.fp .float) (Val.ofFloat .float) Kernels.vadd.bytes
  contract

/-- `map2_contract.covers` is the path checker with the flag on the library's paths
`Kernels.vadd.paths`: `summarizeC` gives vadd's summaries, which the command shares. -/
example : coversEntryWith true contractProg Kernels.vadd.fn_0 Kernels.vadd.paths = true :=
  map2_contract.covers

/--
error: mojo_kernel: the loop clause's tactic does not close kf_open.step (a round), kf_open.exit (the path out) for the loop at block %hdr (block 1 of kf); the command adds nothing
-/
#guard_msgs in
mojo_kernel kf_open := kfP kf
  scalars n := a0
  pointers p := a1
  contract
  loop 1 := preF (fun (V : Valuation) i W => invF V.ctx V.mem V.ctx.who.thread i W) (fun _ => 3)
      (fun (V : Valuation) => memF (V.ctx.who.thread + 1)) by
    rintro V ⟨k, hk, hP, hW, hE, hω, hf, h0, h1, -⟩
    have hk' : k < 6 := hk
    rw [entryF hP hE hW hω hf h0 h1]
    interval_cases k <;> kernel_check

/--
error: unsolved goals
⊢ ∀ (ch : ℕ → ℕ) (oracle : ℕ → ℕ → ℕ),
    oracle = ω₁ →
      ∀ k < volume L23.grid * volume L23.block,
        ∀ (V : Valuation),
          V.ctx.prog = kfP →
            V.ctx.who = { thread := k, cta := k / volume L23.block } →
              V.ctx.env = L23.env k →
                V.ctx.oracle = oracle k →
                  V.fn = kf →
                    V.regs 0 = some (Val.bits 32 3#32) →
                      V.regs 1 = some (Val.ptr { block := outF.2, off := 0 }) →
                        memF k V.mem →
                          preF V ∧ ∀ (me : Mem), (fun V => memF (V.ctx.who.thread + 1)) V me → memF (k + 1) me
-/
#guard_msgs in
/-- The per-thread premise of `kfK.sound_loop` (`Kernel.sound_entryWith (contract := true)`) that
`kernelK` proves, left open: at `L23`, `kfK.args 3 outF.2`, `outF`, every address choice and the
oracle `ω₁`, with the invariant `memF`, for every admitted address choice and oracle and every
thread `k`, every valuation with the start's facts, among them the thread's oracle `oracle k`,
and a memory of `memF k` meets `preF`, and every memory of `memF (V.ctx.who.thread + 1)` is one
of `memF (k + 1)`. An `example`, so that no declaration with the open goal enters the
environment. -/
example : Kernel.Sound kfP kf L23 (kfK.args (BitVec.ofNat 32 3) outF.2) outF.1
    (fun _ o => o = ω₁) (fun m => some m.blocks)
    (Elem.Out outF.1 outF.2 cell bsF (volume L23.grid * volume L23.block)) := by
  refine kfK.sound_loop _ _ outF_closed outF_bytesIn (fun _ _ h => congrArg some h) memF memF_zero
    ?_ memF_end

end MojoProofTest.KernelContract
