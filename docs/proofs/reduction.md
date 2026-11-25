# The reduction's halving tree and atomic sum (`racy_halving`, `Grid.sound_halving`, `rmw_add_perm`)

Lean: proved. `racy_halving`, `racy_dropBlocks` and `Grid.sound_halving` are in
MojoProof/Sem/Shared.lean. `racy_halving` goes through `racy_shared` (Shared.lean) and
`racy_eq_false_of_writers` (MojoProof/Sem/Trace.lean), the theorem that barrier-owned.md's
`racy_eq_false_of_phased` also comes from. `rmw_perm` and `rmw_add_perm`
are in MojoProof/Sem/Rmw.lean, from `rmw_comm`. Instances and twins: MojoProofTest/Shared.lean.

**Scope.**
- `racy_halving`: every trace, number of threads per block of threads, cell width and stride
  sequence. It is a statement about `racy`, not about a program.
- `racy_dropBlocks`: every trace and selector of blocks whose accesses are atomics of one
  commuting operation on the same bytes.
- `Grid.sound_halving`: every program, kernel, launch, arguments, address choice and oracle, on a
  caller's memory whose pointer bytes name known numbers, given one run to a done grid whose trace
  has the halving access pattern. That the reduction kernel's runs have this pattern is not proved
  (Gaps); a hand-built kernel's runs are checked for every launch and tree size the evaluator's
  checks accept (`red_sound_of`), decided at two sizes (`red_sound`, `red_sound28`).
- `rmw_add_perm`: every width, number of operands and value of each, and every order.

No reduction tree is defined here: the value the tree computes is not stated.

## What the kernel does

The corpus file tests/corpus/reduction/ (`sum_kernel`) works on `i32` words:
- The shared array is `[512 x i32]` (line 6), one 4-byte cell per thread.
- Thread `t` (`tid.x`, line 16) sums its slice of the input in the loop at `%24` (lines 33-79),
  then stores the sum at cell `t` (lines 83-85).
- Five barriers follow (lines 86, 101, 116, 131 and 146). After the barriers at lines 86, 101,
  116 and 131, thread `t < s` with `s` = 256, 128, 64 and 32 loads cells `t` and `t + s`, adds
  them, and stores the sum at cell `t` (lines 87-139).
- After the last barrier, thread `t < 32` loads cell `t` (line 150). Its warp sums the 32 words by
  `shfl.sync.bfly` (lines 151-160). Thread 0 then adds the warp's word to the output word by
  `atomicrmw add ptr %0, i32 %101` (line 164).

So, with `B` threads per block of threads (`B ≤ 512`), phase `p` of the shared array is the halving
pattern below with strides `s 0 = B`, then 256, 128, 64, 32, then `s 5 = 32` (reads of each
thread's own cell), then `s p = 0`.

## Statements

**Halving pattern.** Let `B` be the number of threads per block of threads, `w` the cell width and
`s : Nat → Nat` the stride of each phase. An access `x` in phase `p` (`phases`,
MojoProof/Sem/Race.lean) by thread `k` to the shared memory of block of threads `β` follows the
pattern if:
- `k` is a thread of `β`: `x.who.cta = β` and `k / B = β`;
- it lies in one cell `c`: its bytes are among `c * w`, …, `c * w + w - 1`;
- either `c = k % B` and `c < s p` (the cell's thread reads or writes its own cell), or the
  access is a read and `s p ≤ c` (a cell no thread writes in phase `p`).

At stride `s p`, thread `c < s p` reads cells `c` and `c + s p` and writes cell `c`; the threads
from `s p` on do not touch the array.

```lean
theorem racy_halving {tr : List Event} {B w : Nat} {s : Nat → Nat} {ofSh : Nat → Option Nat}
    {G : Nat → Option (Tiling Nat)}
    (hS : ∀ x ∈ (phases tr).1, ∀ β, ofSh x.1.ptr.block = some β →
      x.1.who.cta = β ∧ x.1.who.thread / B = β ∧ ∃ c : Nat, ((c * w : Nat) : Int) ≤ x.1.ptr.off ∧
        x.1.ptr.off + x.1.len ≤ ((c * w + w : Nat) : Int) ∧
        (c = x.1.who.thread % B ∧ c < s x.2 ∨ x.1.write = false ∧ s x.2 ≤ c))
    (hG : ∀ x ∈ (phases tr).1, ofSh x.1.ptr.block = none → Owned G id x.1) :
    racy tr = false
```

`ofSh b` is the block of threads whose shared memory block `b` is, and `none` for other blocks.
Those follow the discipline `G` (`Owned`, Trace.lean), each thread its own tile.

**Blocks of atomics.** The output word is updated by thread 0 of every block of threads with
`atomicrmw add`. `Access.conflict` exempts two atomics of one commuting operation
(`RmwOp.commutes`) at one pointer with one length, but `Owned` and the writer form do not: no discipline gives the threads 0 of two blocks
of threads one tile. `racy_dropBlocks` removes such blocks from the trace first.

```lean
def dropBlocks (A : Nat → Bool) : List Event → List Event
theorem racy_dropBlocks {A : Nat → Bool} {tr : List Event}
    (hA : ∀ x ∈ (phases tr).1, ∀ y ∈ (phases tr).1, A x.1.ptr.block = true →
      x.1.ptr.block = y.1.ptr.block → x.1.atomic.any RmwOp.commutes = true ∧
        x.1.atomic = y.1.atomic ∧ x.1.ptr = y.1.ptr ∧ x.1.len = y.1.len)
    (h : racy (dropBlocks A tr) = false) : racy tr = false
```

`dropBlocks A tr` is `tr` without its accesses to the blocks `A` selects; barriers are kept, so the
other accesses keep their phases (`phases_dropBlocks`).

On a run, `Grid.sound_halving` takes a selector `A` with `hA`, which asks only that the
accesses be atomics of one operation (`isSome`), since every operation of a run's atomics
commutes (`Grid.start_reach_commutes`), and the halving pattern for the
accesses to the other blocks, with `B = volume L.block` and `ofSh = Mem.ctaOf`. It drops the first
two conjuncts: `Grid.start_reach_cta` proves them of every reachable grid. Its other premises are
those of `Grid.start_sound_of_racy`: the run ends in a grid in which every thread has returned, no
access with `!invariant.load` is to a block that a write touches, and the observation is `y` with
`R y`. Its conclusion is `Grid.Sound L c g₀ obs R`.

**The atomic sum.**

```lean
theorem rmw_perm {w : Nat} {op : RmwOp} (hop : op.commutes) {xs ys : List Val}
    (hp : xs.Perm ys) (hs : ∀ x ∈ xs, x.Scalar w) {v : Val} (hv : v.Scalar w) :
    xs.foldlM (rmw w op) v = ys.foldlM (rmw w op) v
theorem rmw_add_perm {w : Nat} {xs ys : List (BitVec w)} (hp : ys.Perm xs) (a : BitVec w) :
    (ys.map (Val.bits w)).foldlM (rmw w .add) (.bits w a) = .ok (.bits w (a + xs.sum))
```

`ys` is the order in which the blocks of threads reach the output word. At `w = 32`, the word
the output holds after every block's `atomicrmw add` is the start word plus the sum of the blocks'
words modulo 2³², whatever the order and the number of blocks.

## Proof

1. **The writer form** (`racy_eq_false_of_writers`, Trace.lean). Its data is a writer map
   `W p b i : Option ι` (phase, block, byte) and tile maps `own p`. Its premises:
   - `hW`: every access, at each of its bytes `i`, has `W p b i = some (own p k)` for its thread
     `k`, or is a read and `W p b i = none`;
   - `hG`: accesses of one block by two blocks of threads see the same writers of it;
   - `hX`: two accesses of one block that no barrier orders, where that block has a writer at
     some byte in the first one's phase, and whose threads have one tile, are by one thread.

   The proof:
   - A race gives `x`, `y` that clash (`racy_iff`): different threads, overlapping, one a write,
     and different blocks of threads or one phase.
   - At the byte `max x.off y.off`, which both touch, the two see one writer map: by `hG` across
     blocks of threads, and trivially in one phase.
   - If both have a writer there, it is the same tile, so `hX` makes the threads equal, a
     contradiction. If one has a writer and the other `none`, the maps differ. If neither does,
     both are reads, so they do not conflict.
2. **Shared memory** (`racy_shared`, Shared.lean). Let the writer of byte `i` of `β`'s shared
   block in phase `p` be thread `β * B + wr p b i`, and elsewhere the tile of `G b` that holds
   the byte (`Tiling.at`, `Owned.at`). Take `own _ := id`.
   - `hW`: `k = β * B + k % B` because `k / B = β`. Elsewhere it is `Owned.at`.
   - `hG`: shared memory is accessed by one block of threads only (the `cta` conjunct); other
     blocks' writers do not depend on the phase.
   - `hX`: the writer is the thread itself.
3. **The halving tree** (`racy_halving`). Take `wr p _ i := if i / w < s p then some (i / w) else
   none`. An access in cell `c` touches only bytes with `i / w = c` (`toNat_div_of_cell`). If
   `c = k % B` and `c < s p`, the writer is `k % B`. If the access is a read with `s p ≤ c`,
   nobody writes the byte.
4. **Blocks of atomics** (`racy_dropBlocks`). A race gives `x`, `y` that clash. They overlap, so
   they are of one block. If `A` selects it, `hA` makes them atomics of one commuting operation at
   one pointer with one length, which do not conflict. Otherwise both are accesses of
   `dropBlocks A tr` with the same phases (`phases_dropBlocks`, by induction on the trace), so
   they clash there.
5. **On a run** (`Grid.sound_halving`): `racy_dropBlocks`, whose commuting operation
   `Grid.start_reach_commutes` gives (an update by `rmw` succeeds only by a commuting operation,
   `rmw_commutes`), then `racy_halving` on the trace without the selected blocks.
   - `Grid.start_reach_cta`: in every grid reachable from the start's, every access is by thread
     `k` of block of threads `k / volume L.block` (`Grid.start_ctx`). An access to a block whose
     owner is `.cta β` is by a thread of `β`: the owner admits it (`Grid.advance_admits`), and no
     step changes an owner (`Grid.start_reach_changes`).
   - `Grid.start_sound_of_racy`: `Grid.start_sound` needs the done grid not to be bad. A done grid
     is bad only if its trace is racy or breaks `!invariant.load` (`Grid.Done.bad_iff`). The
     second is `kept_of_split` with the blocks some write touches: an `atomicrmw`'s read, which
     writes for the core's `kept`, has its write right after it (`Trace.Shaped.writes`,
     `Grid.start_reach_shaped`).
6. **The atomic sum.**
   - `rmw_perm` is by induction on the permutation. A swap of two neighbours is `rmw_comm`. An
     update of a scalar that succeeds gives a scalar (`rmw_scalar`), so the rest of the list
     starts from a scalar.
   - `rmw_add_perm`: by `rmw_perm` the order is that of `xs`. Then induction on `xs`: one update
     of the word `a` by the word `b` is `.bits w (a + b)` (`intBin_lifts`), and `+` is
     associative.

## Instances and twins

All in MojoProofTest/Shared.lean.

- **The halving tree on a trace** (the first `example`). Four threads of block of threads 0 work
  on a shared block 0 of four 1-byte cells, with strides 4, 2, 1:
  - in phase 0, thread `k` writes cell `k`;
  - in phase 1, threads 0 and 1 read cells `k` and `k + 2` and write cell `k`;
  - in phase 2, thread 0 reads cells 0 and 1 and writes cell 0.

  `phases tr` is computed by `decide +kernel` (`phases_tr`). The premises are checked by cases,
  with `c` the access's offset.
- **Its twin.** Without the barriers, the trace is racy (`racy = true`, by `decide`). So no stride
  sequence meets the premises of it.
- **The words** (`add_any_order`). For every order of 2³² - 1, 2 and 5, the word 0 becomes 6, the
  sum modulo 2³².
- **Its twin** (`add_not_perm`). The words 2³² - 1, 2 and 2, not an order of those three, give 3.
  The twin of `rmw_perm`'s operation premise is `add_or` in MojoProofTest/Atomics.lean: `add` and
  `or` updates give different words in the two orders.
- **Blocks of atomics** (`racy_trA`). `tr` with two `atomicrmw add`s of the 4 bytes of block 1,
  by thread 0 of block of threads 0 and thread 4 of block of threads 1, has no race
  (`racy_dropBlocks` with block 1 selected).
- **Its twin.** With thread 4's update a plain store, the trace is racy (by `decide`).
- **A run** (`red_sound_of`), for every launch, level count `k` and output word that the
  evaluator's checks accept. The hand-built kernel `redK k true`, the tree of `2 ^ k` threads,
  runs on a caller's memory holding the output word 0, passed as the pointer argument. In each
  block of threads:
  - thread `t` stores its `%tid.x` to cell `t` of the shared global `@sh` (`[2 ^ k x i32]`), then
    a barrier;
  - at level `j < k` the threads below `2 ^ (k - j)` add the cell that far above into their own,
    then a barrier;
  - thread 0 adds cell 1 into cell 0 and adds the result into the output word by `atomicrmw
    add`.

  The checks (`redOk`): the evaluator's run (`Grid.run`, `Grid.run_reach`) ends with every thread
  returned and the given word, and its trace meets the premises of `Grid.sound_halving` at 4-byte
  cells, the strides `2 ^ k / 2 ^ p` and the output block selected. They are decided
  (`decide +kernel`) on two blocks of four threads (`k = 2`, the word 12, `red_sound`) and on two
  blocks of eight threads (`k = 3`, the word 56, `red_sound28`). The two `atomicrmw`s, by different
  blocks of threads on one word, are the accesses `racy_dropBlocks` drops. So the start's grid is
  sound for the output word, and every schedule observes it. The kernel does not reduce `phases`'
  hash map at block of threads 1, so the checks go through `phasesF`, the same phases computed
  with a function (`phasesF_eq`, for every trace).
- **Its twin** (`red_twin`). Without the second barrier, thread 0 reads cell 1 in the phase in
  which thread 1 writes it. The run's trace is racy, so the start's grid is sound for no
  observation.

## Gaps

- **The kernel's trace.** That every run of `sum_kernel` has the halving pattern is not proved.
  Proving it needs a summary of the kernel's phases between barriers, and the block checker
  refuses barrier calls (MojoProof/Sym/Rules.lean).
- **The atomic output.** `Grid.sound_halving`'s `hA` asks that every access to the output block
  be the `atomicrmw add` of its 4 bytes. That the kernel neither reads nor stores the output
  otherwise is part of the access pattern, not proved.
- **The value.** That the output word is the sum of the input is not stated. Only the race freedom
  of the shared phases and the order independence of the atomic words are proved. The warp's
  `shfl.sync.bfly` rounds (lines 151-160) are collectives and access no memory.

## Dependencies

- `phases` (MojoProof/Sem/SigDef.lean); `clash`, `mem_phases` (MojoProof/Sem/Race.lean); `racy_iff`
  (MojoProof/Sem/RaceSig.lean);
- `Tiling`, `Owned`, `Tiling.at`, `Owned.at`, `racy_eq_false_of_writers`, `kept_of_split`
  (MojoProof/Sem/Trace.lean);
- `Grid.start_ctx` (MojoProof/Sem/Grid.lean), `Grid.advance_admits` (Confluence.lean),
  `Grid.start_reach_changes` (Writes.lean), `Grid.start_sound` and `Grid.Done.bad_iff`
  (Determinism.lean);
- `rmw_comm`, `rmw_scalar`, `intBin_lifts` (MojoProof/Sem/Rmw.lean).
