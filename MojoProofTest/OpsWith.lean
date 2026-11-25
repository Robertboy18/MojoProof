import MojoProofTest.KernelContract

/-!
# Tests of the tactic mojo_ret on `RetWith` goals, a path with an `fmul contract` product among them

mojo_ret proves a goal `∃ ps ∈ paths, RetWith c V (Elem m₀ out w cell bs K) ps` for every flag
`c` directly: each block of the path after the first is entered through `Valuation.intoWith c`
(`Obl.walk`, `Elem.intoWith`) and the last block's effects are steps by `Elem.retWith`, with no
detour through `Ret`.

* The first `example` states `map2_contract.ret` by `type_of%` (MojoProofTest/KernelContract.lean,
  `mojo_kernel`'s `map2` clause with the flag `contract` on vadd's program, a `RetWith true` on
  `Kernels.vadd.paths`), for every valid 1-D launch, thread `k`, count `n < 2 ^ 31` and memory of
  `Elem` after `k` threads with the buffer facts, and proves it by mojo_ret alone (it splits on the
  branch condition `k < n`), so it pins that statement and adds no copy of the theorem.
* `kh`, `khP`, `khE`, `khX`, `khPath`: a path with an `fmul contract` product, the hand-built
  kernel `@kh(ptr addrspace(1) %p)` whose entry block computes `%x = fmul contract 3.0, 2.0` and
  branches to a block that returns. Its summaries are `summarizeC`'s (with the flag; without it,
  `summarize` refuses the entry block), and the entry block records the product (`pathNoProds`
  is false, so `RetWith.exists_true_of_ret` does not apply to it).
  `kh_ret`: for every flag `c`, valuation `V` and memory of `Elem` after `k` threads, the path is
  a `RetWith c` to `Elem` after `k` threads, by mojo_ret alone (`Elem.intoWith` for the entry
  block, `Elem.retWith` for the last).
* The `example` after `Skip` is `kh_ret`'s open-goal twin: `Elem` after `k + 1` threads needs
  thread `k` skipped, `bs k = none`; with that fact behind an irreducible definition mojo_ret
  leaves it open, as logged, and unfolding the definition closes it.
* `kq`, `kqP`, `kqE`, `kqX`, `kqPath`: a path through a `phi` edge, the hand-built kernel
  `@kq(ptr addrspace(1) %p)` whose entry block computes `%x = fmul contract 3.0, 2.0` and branches
  to a block that starts with `%y = phi float [%x, %entry]` and `%z = phi i32 [7, %entry]`, adds
  `1` to `%z` and returns; the path checker with the flag accepts it (`coversPathWith true`).
  `kq_ret`: for every flag `c`, valuation `V` of `kq`'s function and memory of `Elem` after `k`
  threads, the path is a `RetWith c` to `Elem` after `k` threads, by mojo_ret alone (block
  `%exit` entered by `Valuation.intoWith c`, with `%z = 7` from the edge's `phi` operand).
* The last `example` is `kq_ret`'s open-goal twin: with `V.fn = kq` behind an irreducible
  definition, mojo_ret leaves the obligation of `%exit`'s `add` open, as logged, and mojo_obl
  closes it after unfolding the definition.
-/

namespace MojoProofTest.OpsWith

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.KernelContract

/-- **Thread `k`'s path is a `RetWith true` by mojo_ret**: the statement of `map2_contract.ret`
(the `map2` clause of `mojo_kernel` with the flag `contract`), for every valid launch with one
block row and one thread row, alignment `4 ∣ al`, distinct blocks `a`, `b`, `out`, `n ≤ N` below
`2 ^ 31`, vectors, thread `k` of the launch, context of the program with thread `k`'s registers,
identity and oracle `ω k`, caller's memory, memory of `Elem` after `k` threads and frame of
`fn_0` with the buffer structs and buffers: some path of `Kernels.vadd.paths` is a `RetWith true`
to `Elem` after `k + 1` threads. The hypotheses are introduced without names; mojo_ret finds them
by type. -/
example : type_of% @map2_contract.ret := by
  intros
  mojo_ret

/-- The kernel `@kh(ptr addrspace(1) %p)`, its locals `%p` (the parameter, local 0), `%entry`
(1), `%exit` (2) and `%x` (3): block `%entry` computes `%x = fmul contract float 3.0, 2.0` and
branches to `%exit`, which returns. -/
def kh : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "kh",
    params := [⟨.ptr 1, [], some 0⟩], group := none,
    names := #["p", "entry", "exit", "x"],
    blocks := #[
      ⟨1, #[
        { res := some 3,
          inst := .fbin .fmul { contract := true } (.fp .float)
            (.float (.hex "" 0x4008000000000000)) (.float (.hex "" 0x4000000000000000)) }],
        .br 2⟩,
      ⟨2, #[], .ret none⟩] }

/-- The program of `kh`, with the default data layout and no intrinsics. -/
def khP : Program :=
  { module := { (default : Module) with funcs := #[kh] }, sha256 := "", layout := {},
    intrinsics := [], kernels := ["kh"] }

/-- The summary of `kh`'s block `%entry` with `fmul contract` (`summarizeC`). -/
def khE : Summary := (summarizeC khP kh 1 0).getD default

/-- The summary of `kh`'s block `%exit` (`summarizeC`). -/
def khX : Summary := (summarizeC khP kh 2 0).getD default

/-- The path `%entry → %exit` of `kh`, each block with its summary's obligations. -/
def khPath : List (Nat × List Cond × Summary) := [(1, khE.obls, khE), (2, khX.obls, khX)]

/-- Without the flag the block checker refuses `%entry` (its `fmul contract`). -/
example : (summarize khP kh 1 0).isNone = true := by decide +kernel

/-- `%entry` records the `fmul contract` product, so `RetWith.exists_true_of_ret` does not apply
to `khPath`. -/
example : pathNoProds khPath = false := by decide +kernel

/-- **A path with an `fmul contract` product is a `RetWith` by mojo_ret**: for every flag `c`,
valuation `V`, caller's memory, output block, bytes and `k`, `Elem` after `k` threads at `V`'s
memory gives some path of `[khPath]` a `RetWith c` to `Elem` after `k` threads (block `%entry`
by `Elem.intoWith`, its exit to `%exit`, and `%exit`'s `ret` by `Elem.retWith`; no effects). -/
theorem kh_ret {c : Bool} {V : Valuation} {m₀ : Mem} {out k : Nat}
    {bs : Nat → Option (List MemByte)} (hE : Elem m₀ out 4 (fun i => 4 * i) bs k V.mem) :
    ∃ ps ∈ [khPath], RetWith c V (Elem m₀ out 4 (fun i => 4 * i) bs k) ps := by
  mojo_ret

/-- `bs k = none`, behind an irreducible definition. -/
@[irreducible] def Skip (bs : Nat → Option (List MemByte)) (k : Nat) : Prop := bs k = none

/--
info: mojo_ret: open goal
  bs k = none
-/
#guard_msgs (whitespace := lax) in
/-- **The open-goal twin of `kh_ret`**: `Elem` after `k + 1` threads needs thread `k` to have no
bytes; with `bs k = none` stated as `Skip bs k`, mojo_ret leaves it open on `khPath`, and
`unfold Skip` closes it. -/
example {c : Bool} {V : Valuation} {m₀ : Mem} {out k : Nat} {bs : Nat → Option (List MemByte)}
    (hE : Elem m₀ out 4 (fun i => 4 * i) bs k V.mem) (hb : Skip bs k) :
    ∃ ps ∈ [khPath], RetWith c V (Elem m₀ out 4 (fun i => 4 * i) bs (k + 1)) ps := by
  mojo_ret
  unfold Skip at hb
  exact hb

/-- The kernel `@kq(ptr addrspace(1) %p)`, its locals `%p` (the parameter, local 0), `%entry`
(1), `%exit` (2), `%x` (3), `%y` (4), `%z` (5) and `%w` (6): block `%entry` computes
`%x = fmul contract float 3.0, 2.0` and branches to `%exit`, which starts with two `phi`s,
`%y = phi float [%x, %entry]` and `%z = phi i32 [7, %entry]`, then computes
`%w = add nsw i32 %z, 1` and returns. -/
def kq : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "kq",
    params := [⟨.ptr 1, [], some 0⟩], group := none,
    names := #["p", "entry", "exit", "x", "y", "z", "w"],
    blocks := #[
      ⟨1, #[
        { res := some 3,
          inst := .fbin .fmul { contract := true } (.fp .float)
            (.float (.hex "" 0x4008000000000000)) (.float (.hex "" 0x4000000000000000)) }],
        .br 2⟩,
      ⟨2, #[{ res := some 4, inst := .phi (.fp .float) [(.loc 3, 1)] },
        { res := some 5, inst := .phi (.int 32) [(.int 7, 1)] },
        { res := some 6, inst := .bin .add { nsw := true } (.int 32) (.loc 5) (.int 1) }],
        .ret none⟩] }

/-- The program of `kq`, with the default data layout and no intrinsics. -/
def kqP : Program :=
  { module := { (default : Module) with funcs := #[kq] }, sha256 := "", layout := {},
    intrinsics := [], kernels := ["kq"] }

/-- The summary of `kq`'s block `%entry` with `fmul contract` (`summarizeC`): its exit is a
branch into a block with `phi`s (`Exit.phi`), and its obligations include that the `phi`
operands `%x` and `7` evaluate. -/
def kqE : Summary := (summarizeC kqP kq 1 0).getD default

/-- The summary of `kq`'s block `%exit` from position 2, after its two `phi`s (`summarizeC`):
the `add` of `%z` and `1`, and `ret void`. -/
def kqX : Summary := (summarizeC kqP kq 2 2).getD default

/-- The path `%entry → %exit` of `kq` through the `phi` edge, each block with its summary's
obligations. -/
def kqPath : List (Nat × List Cond × Summary) := [(1, kqE.obls, kqE), (2, kqX.obls, kqX)]

/-- The path checker with `fmul contract` accepts `kqPath` from position 0 (`%entry` for its
edge into `%exit`, `%exit` from position 2), and `%entry` records the `fmul contract` product. -/
example : coversPathWith true kqP kq 0 kqPath = true ∧ pathNoProds kqPath = false := by
  decide +kernel

/-- **A path through a `phi` edge is a `RetWith` by mojo_ret**: for every flag `c`, valuation `V`
of `kq`'s function, caller's memory, output block, bytes and `k`, `Elem` after `k` threads at
`V`'s memory gives some path of `[kqPath]` a `RetWith c` to `Elem` after `k` threads. Block
`%exit` is entered by `Valuation.intoWith c`, which sets `%y` and `%z` from the edge's `phi`
operands, so its obligation that `%w = add nsw i32 %z, 1` evaluates holds at `%z = 7`. -/
theorem kq_ret {c : Bool} {V : Valuation} {m₀ : Mem} {out k : Nat}
    {bs : Nat → Option (List MemByte)} (hF : V.fn = kq)
    (hE : Elem m₀ out 4 (fun i => 4 * i) bs k V.mem) :
    ∃ ps ∈ [kqPath], RetWith c V (Elem m₀ out 4 (fun i => 4 * i) bs k) ps := by
  mojo_ret

/-- `V.fn = kq`, behind an irreducible definition. -/
@[irreducible] def IsKq (V : Valuation) : Prop := V.fn = kq

/--
info: mojo_ret: open goal
  Cond.Holds (Valuation.intoWith c V 1 kqE) (vals (Valuation.intoWith c V 1 kqE) kqX.nodes)
    (Cond.ok (SVal.node 0))
-/
#guard_msgs (whitespace := lax) in
/-- **The open-goal twin of `kq_ret`**: the `phi` edge's operands are those of `V`'s function;
with `V.fn = kq` stated as `IsKq V`, mojo_ret does not know `%z` after the edge and leaves the
obligation of `%w` open, and after `unfold IsKq` mojo_obl closes it. -/
example {c : Bool} {V : Valuation} {m₀ : Mem} {out k : Nat}
    {bs : Nat → Option (List MemByte)} (hF : IsKq V)
    (hE : Elem m₀ out 4 (fun i => 4 * i) bs k V.mem) :
    ∃ ps ∈ [kqPath], RetWith c V (Elem m₀ out 4 (fun i => 4 * i) bs k) ps := by
  mojo_ret
  unfold IsKq at hF
  mojo_obl

end MojoProofTest.OpsWith
