import MojoProofTest.SymLane
import MojoProof.Sym.SchedWait

/-!
# `alloca` in the block checker

With the checker's `alloca` flag on (`SState.alloca`, `summarizeAt true`, `coversAt true`), an
`alloca` gives a pointer node to its block (`SNode.fresh`) and an effect that makes the block
(`SEff.alloca`), whose freshness is the summary's `.mem` obligation: the block's number, the
thread's `Mem.fresh` at the statement's step count, has no block yet. `Block.soundAt` and
`Block.sound_alloca` give the block's end with the summary's `alloca` blocks in front of the
entry frame's (`EndsAt`). Tests:

* `allocs_sound`: hand-built kernels of one to three `alloca`s and `ret void` (`allocK`; the
  first without a count, the others with counts 2 and 3). The checker accepts each with the
  flag (`allocs_covers`, by `decide +kernel`); its summary has one `SNode.fresh` and one
  `SEff.alloca` per statement and the obligations that the effects run and the nodes evaluate
  (`allocs_shape`). For
  every context, thread at the block's entry and memory whose obligation holds, the steps reach
  `ret` with the frame's `alloca` blocks the fresh numbers at the step counts of the statements,
  newest first, in front of the entry frame's (`allocs_sound`, from `Block.sound_alloca`, at
  every `n` the checker accepts; `two_sound` its instance at two).
* `allocs_twin`: the open twin: without the flag the checker refuses the same blocks; and the
  obligation fails on every memory that has a block at the first statement's number
  (`alloc_used`: the effect faults with "alloca number in use").
* `gemv_allocas`: gemv_kernel's entry block `%6` with the flag: the checker runs its three
  `alloca`s (statements 0 to 2, `%7`, `%8`, `%9`) and the statements after them to the shuffle at
  17, with three effects; `gemv_allocas_twin`: it refuses the shuffle at 17 (a call the block
  checker does not take), and the whole block from 0 has no summary.
* `reads_covers`: a hand-built kernel (`readK`) of an `alloca` and then a `getelementptr`, a
  `ptrtoint`, an `icmp` and a two-index `getelementptr` on its block. The checker accepts it with
  the flag, and those four nodes read the memory the `alloca`'s effect makes (`SNode.gepAfter`,
  `SNode.castAfter`, `SNode.icmpAfter`, `SNode.gepNAfter`); `reads_mutant`: the summary with the
  entry memory's `SNode.gep` in place of `SNode.gepAfter` is refused; `reads_sound`: the block
  reaches `ret` (`Block.sound_alloca`).
* `path_covers`: one function, the two-block alloca path: a kernel `@k` of LLVM text
  (`pathText`) whose block `%0` is an `alloca` and a `br` to `%2`, and block `%2` an `alloca`
  and `ret void`. `pathK` is written with the parser's ids, and a `#guard` checks that
  `MojoProof.LLVM.parse` and `Module.check` of the text give exactly its program `pathP`, with no
  id defined twice (`Module.twice`); a second `#guard` checks that the parser refuses the text
  whose first result is also the second block's label. The path checker with the flag
  (`coversPathAt true`) accepts the path 0, 2 and each block has one `alloca` effect; without it
  (`coversPathWith`) it is refused; `path_mutant`: the path whose last summary drops its effect
  is refused.
* `path_ret`, `path_runs`: for every context of `pathP`, thread whose only frame is at block 0's
  entry and memory whose path premises hold (`WalkWith false`), the steps reach the `ret` and its
  step ends the thread with both `alloca` blocks dead (`Block.sound_pathAt_ptrs`,
  `EndsWith.ret`); under `RetWith false` the thread runs to such a memory (`Runs.of_retAt`).
* `path_walk`, `path_retWith`, `path_dead`, `path_steps`, `path_used`: the two-block alloca path
  at one context, thread and memory: thread 0 of a launch of one thread, as `Grid.start` makes
  it (`path_start`: the context `pathCtx` with the address choices `pathCh`, the thread `pathT`,
  the memory `pathMem` with its one shared block), whose `alloca` blocks are numbers 2 and 6.
  The premises hold there (`path_walk`, decided), and the path runs to `ret` with the memory
  `pathRet` (`path_retWith`), which has both blocks live (`path_retMem`). The instances of
  `path_ret` and `path_runs` give the run to `pathEnd`, where blocks 2 and 6 are dead
  (`path_dead`); `step`, iterated from the launch (`runTo`), reaches `.done` with the same
  `pathEnd` (`path_steps`). On the memory that has a block at number 2 already, the premises
  fail (`path_used`).

The kernels are hand-built and gemv_kernel's block is one; `pathK` is the parse of its text.
`Block.soundAt` and `Block.sound_alloca` cover every program; the path tests are of one
function, and their concrete ones of one context, thread and memory.
-/

namespace MojoProofTest.SymAlloca

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane

/-- Statement `i` of `allocK n`: `%(i+1) = alloca i32` for `i = 0`, else
`%(i+1) = alloca i32, i64 (i+1)`. -/
def allocStmt (i : Nat) : Stmt :=
  { res := some (i + 1),
    inst := .alloca (.int 32) (if i = 0 then none else some ⟨.int 64, .int (i + 1)⟩) none }

/-- The kernel `@k` of `n` `alloca`s (`allocStmt 0` to `allocStmt (n - 1)`), then `ret void`, in
block 0. -/
def allocK (n : Nat) : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "k", params := [],
    group := none, names := #["entry"],
    blocks := #[⟨0, (List.range n).toArray.map allocStmt, .ret none⟩] }

/-- The program of `allocK n` alone, with the default data layout. -/
def allocP (n : Nat) : Program :=
  { module := { (default : Module) with funcs := #[allocK n] }, sha256 := "", layout := {},
    intrinsics := [], kernels := ["k"] }

/-- The exit function of `allocK n`'s block (`SState.exitAt`). -/
def ex (n : Nat) : SState → Term → Option (Exit × List Cond) :=
  fun σ tm => σ.exitAt (allocK n) 0 tm

/-- The summary of `allocK n`'s block with the `alloca` flag (`summarizeAt true`), the default
summary when there is none. -/
def allocS (n : Nat) : Summary :=
  (summarizeAt true (allocP n) (allocK n) 0 0 (ex n)).getD default

/-- **The checker accepts the kernels of one to three `alloca`s with the flag** (`coversAt true`,
the summary's own obligations as the conditions). -/
theorem allocs_covers : ∀ n ∈ [1, 2, 3],
    coversAt true (allocP n) (allocK n) 0 0 (ex n) (allocS n).obls (allocS n) = true := by
  decide +kernel

/-- **The summaries' shape**: for one to three `alloca`s, one `SNode.fresh` and one
`SEff.alloca` per statement, in order, the counts as `i64` constants after the first, the
obligations that the effects run and that each node evaluates (newest first), the exit
`ret void`, and `n` statements. -/
theorem allocs_shape : ∀ n ∈ [1, 2, 3],
    (allocS n).nodes = (List.range n).map SNode.fresh ∧
    (allocS n).effs = (List.range n).map (fun i =>
      .alloca 0 i i (if i = 0 then none else some (.int 64 (i + 1)))) ∧
    (allocS n).obls = .mem (allocS n).effs :: (List.range n).reverse.map (.ok <| .node ·) ∧
    (allocS n).exit = .ret ∧ (allocS n).len = n := by
  decide +kernel

/-- **The kernels' blocks end with their `alloca` blocks**: for every `n` the checker accepts
(`coversAt true`), every context of `allocP n` and thread whose innermost frame `f` (above
`rest`) is at the entry of `allocK n`'s block, with memory `m`, whose obligations hold: the steps
reach the block's `ret`, `n` steps later, with the frame's `alloca` blocks the effects' blocks
(`SEff.blocks`) in front of `f`'s, on the memory the effects make (`Block.sound_alloca`). -/
theorem allocs_sound {n : Nat}
    (hc : coversAt true (allocP n) (allocK n) 0 0 (ex n) (allocS n).obls (allocS n) = true)
    {c : Ctx} (hP : c.prog = allocP n) {t : Thread} {m : Mem} {f : Frame} {rest : List Frame}
    (ht : t.frames = f :: rest) (hfn : f.fn = allocK n) (hl : f.label = 0) (hp : f.pc = 0)
    (hds : ∀ d ∈ (allocS n).obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) (allocS n).nodes)) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + (allocS n).len⟩ me ∧
      fe.allocas = SEff.blocks (Valuation.entry c t.k m f) (allocS n).effs ++ f.allocas ∧
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) (allocS n).nodes)
        (allocS n).effs = .ok me := by
  obtain ⟨⟨fe, me, hS, -, -, ha, -, -, -, hm, -⟩, -⟩ :=
    Block.sound_alloca hc hP ht hfn hl hp hds
  exact ⟨fe, me, hS, ha, hm⟩

/-- **`allocs_sound` at two `alloca`s**: the frame's `alloca` blocks are the fresh numbers of the
thread at step counts `t.k + 1` and `t.k`, in front of `f`'s, two steps later. -/
theorem two_sound {c : Ctx} (hP : c.prog = allocP 2) {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = allocK 2) (hl : f.label = 0)
    (hp : f.pc = 0)
    (hds : ∀ d ∈ (allocS 2).obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) (allocS 2).nodes)) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + 2⟩ me ∧
      fe.allocas = m.fresh c.who.thread (t.k + 1) :: m.fresh c.who.thread (t.k + 0) ::
        f.allocas := by
  obtain ⟨fe, me, hS, ha, -⟩ := allocs_sound (allocs_covers 2 (by decide)) hP ht hfn hl hp hds
  obtain ⟨-, he, -, -, hn⟩ := allocs_shape 2 (by decide)
  rw [hn] at hS
  refine ⟨fe, me, hS, ?_⟩
  rw [ha, he]
  rfl

/-- **The open twin, without the flag**: `summarizeWith` (the `alloca` flag off, as
`SState.start` leaves it) gives no summary of the same blocks. -/
theorem allocs_twin : ∀ n ∈ [1, 2, 3],
    summarizeWith (allocP n) (allocK n) 0 0 (ex n) = none := by
  decide +kernel

/-- **The open twin of the obligation**: for every valuation of `allocK n` (`n ≥ 1`) whose entry
memory has a block at the first statement's number (`Mem.fresh` of the thread at the entry step
count), the summary's `.mem` obligation fails: the first effect faults with "alloca number in
use". For every `n` from one to three. -/
theorem alloc_used {n : Nat} (hn : n ∈ [1, 2, 3]) {V : Valuation} (vs : List (Except Fault Val))
    (hf : V.fn = allocK n)
    (hb : (V.mem.blocks (V.mem.fresh V.ctx.who.thread (V.k + 0))).isSome = true) :
    ¬ (Cond.mem (allocS n).effs).Holds V vs := by
  rintro ⟨me, hme⟩
  obtain ⟨-, he, -⟩ := allocs_shape n hn
  obtain ⟨n', rfl⟩ : ∃ n', n = n' + 1 := by
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hn
    rcases hn with rfl | rfl | rfl <;> exact ⟨_, rfl⟩
  have hs : V.stmt 0 0 = some (allocStmt 0) := by
    rw [Valuation.stmt, hf]
    simp [allocK, List.range_succ_eq_map]
  rw [he, List.range_succ_eq_map] at hme
  simp only [SEff.run, List.map_cons, List.foldlM_cons, SEff.apply, hs, allocStmt,
    ↓reduceIte, SEff.count, hb, bind, Except.bind, pure, Except.pure] at hme
  cases hme

/-- **gemv_kernel's `alloca`s with the flag**: from the entry of block `%6` with the `alloca` flag
on, the checker runs statements 0 to 16, the three `alloca`s (`%7 = alloca [2 x ptr]`,
`%8` and `%9` `alloca i32`, each `i64 1`) and the statements to the shuffle at 17, with three
effects: the three `alloca`s, in order. -/
theorem gemv_allocas :
    (SState.run false gemv.prog 6 0 (gemv.fn_0.b_0.stmts.toList.take 17) 0
      { SState.start gemv.fn_0 6 0 gemv.fn_0.b_0 with alloca := true }).map (·.effs) =
      some [.alloca 6 0 0 (some (.int 64 1)), .alloca 6 1 1 (some (.int 64 1)),
        .alloca 6 2 2 (some (.int 64 1))] := by
  decide +kernel

/-- **The twin of `gemv_allocas`**: the checker refuses the call of `llvm.nvvm.shfl.sync.idx.i32`
at statement 17, so the run to 18 gives nothing, and the block from 0 has no summary with the
flag. (Statements 19 to 28 hold calls of `llvm.lifetime.start` and `llvm.lifetime.end`, which the
checker refuses too.) -/
theorem gemv_allocas_twin :
    SState.run false gemv.prog 6 0 (gemv.fn_0.b_0.stmts.toList.take 18) 0
      { SState.start gemv.fn_0 6 0 gemv.fn_0.b_0 with alloca := true } = none ∧
    summarizeAt true gemv.prog gemv.fn_0 6 0 (fun σ tm => σ.exitAt gemv.fn_0 6 tm) = none := by
  decide +kernel

/-- The statements of `readK`: `%1 = alloca i32`, then the reads of its block's address:
`%2 = getelementptr inbounds i32, ptr %1, i64 0`, `%3 = ptrtoint ptr %2 to i64`,
`%4 = icmp eq i64 %3, 0` and `%5 = getelementptr [1 x i32], ptr %1, i64 0, i64 0`. -/
def readStmts : List Stmt :=
  [{ res := some 1, inst := .alloca (.int 32) none none },
   { res := some 2, inst := .gep { inbounds := true } (.int 32) ⟨.ptr 0, .loc 1⟩
      [⟨.int 64, .int 0⟩] },
   { res := some 3, inst := .cast .ptrtoint ⟨.ptr 0, .loc 2⟩ (.int 64) },
   { res := some 4, inst := .icmp .eq (.int 64) (.loc 3) (.int 0) },
   { res := some 5, inst := .gep {} (.arr 1 (.int 32)) ⟨.ptr 0, .loc 1⟩
      [⟨.int 64, .int 0⟩, ⟨.int 64, .int 0⟩] }]

/-- The kernel `@k` of `readStmts`, then `ret void`, in block 0. -/
def readK : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "k", params := [],
    group := none, names := #["entry"], blocks := #[⟨0, readStmts.toArray, .ret none⟩] }

/-- The program of `readK` alone, with the default data layout. -/
def readP : Program :=
  { module := { (default : Module) with funcs := #[readK] }, sha256 := "", layout := {},
    intrinsics := [], kernels := ["k"] }

/-- The exit function of `readK`'s block (`SState.exitAt`). -/
def readEx : SState → Term → Option (Exit × List Cond) :=
  fun σ tm => σ.exitAt readK 0 tm

/-- The summary of `readK`'s block with the `alloca` flag (`summarizeAt true`), the default
summary when there is none. -/
def readS : Summary :=
  (summarizeAt true readP readK 0 0 readEx).getD default

/-- **The reads after an `alloca`**: the checker accepts `readK`'s block with the flag
(`coversAt true`); its nodes are the block's pointer (`SNode.fresh`), then the `getelementptr`,
`ptrtoint`, `icmp` and two-index `getelementptr` on the memory the `alloca`'s effect makes
(`SNode.gepAfter`, `SNode.castAfter`, `SNode.icmpAfter`, `SNode.gepNAfter`), with one effect and
five statements. Without the flag the checker refuses the block. -/
theorem reads_covers :
    coversAt true readP readK 0 0 readEx readS.obls readS = true ∧
    readS.nodes = [.fresh 0, .gepAfter 0 1 (.node 0) (.int 64 0) [.alloca 0 0 0 none],
      .castAfter 0 2 2 (.node 1) [.alloca 0 0 0 none],
      .icmpAfter .eq 64 (.node 2) (.int 64 0) [.alloca 0 0 0 none],
      .gepNAfter 0 4 (.node 0) [.int 64 0, .int 64 0] [.alloca 0 0 0 none]] ∧
    readS.effs = [.alloca 0 0 0 none] ∧ readS.len = 5 ∧
    summarizeWith readP readK 0 0 readEx = none := by
  decide +kernel

/-- **The mutant**: the summary with the `getelementptr`'s node on the entry memory (`SNode.gep`,
the node before an `alloca`) in place of `SNode.gepAfter` is refused. -/
theorem reads_mutant :
    coversAt true readP readK 0 0 readEx readS.obls
      { readS with nodes := readS.nodes.set 1 (.gep 0 1 (.node 0) (.int 64 0)) } = false := by
  decide +kernel

/-- **`readK`'s block ends**: for every context of `readP` and thread whose innermost frame `f`
(above `rest`) is at the entry of `readK`'s block, with memory `m`, whose obligations hold: the
steps reach the block's `ret` five steps later, with the frame's `alloca` blocks the effect's
block in front of `f`'s, on the memory the effect makes (`Block.sound_alloca`). -/
theorem reads_sound {c : Ctx} (hP : c.prog = readP) {t : Thread} {m : Mem} {f : Frame}
    {rest : List Frame} (ht : t.frames = f :: rest) (hfn : f.fn = readK) (hl : f.label = 0)
    (hp : f.pc = 0)
    (hds : ∀ d ∈ readS.obls, d.Holds (Valuation.entry c t.k m f)
      (vals (Valuation.entry c t.k m f) readS.nodes)) :
    ∃ fe me, Steps c t m ⟨fe :: rest, t.k + 5⟩ me ∧
      fe.allocas = SEff.blocks (Valuation.entry c t.k m f) readS.effs ++ f.allocas ∧
      SEff.run (Valuation.entry c t.k m f) (vals (Valuation.entry c t.k m f) readS.nodes)
        readS.effs = .ok me := by
  obtain ⟨⟨fe, me, hS, -, -, ha, -, -, -, hm, -⟩, -⟩ :=
    Block.sound_alloca reads_covers.1 hP ht hfn hl hp hds
  obtain ⟨-, -, -, hn, -⟩ := reads_covers
  rw [hn] at hS
  exact ⟨fe, me, hS, ha, hm⟩

/-- The LLVM text of a kernel `@k` of two blocks with an `alloca` each, numbered as LLVM numbers
unnamed values (LangRef, "Identifiers": parameters, block labels and results share one counter,
the entry block taking `%0`): block `%0` is `%1 = alloca i32, align 4` then `br label %2`,
block `%2` is `%3 = alloca i32, align 4` then `ret void`. -/
def pathText : String :=
  "define ptx_kernel void @k() {\n  %1 = alloca i32, align 4\n  br label %2\n\n2:\n" ++
  "  %3 = alloca i32, align 4\n  ret void\n}\n"

/-- The function `MojoProof.LLVM.parse` gives for `pathText`, with the parser's ids (local `i`
is `%names[i]`): block 0 is `%1 = alloca i32, align 4` then `br label %2`, block 2 is
`%3 = alloca i32, align 4` then `ret void` (the first `#guard` below checks it). -/
def pathK : Func :=
  { linkage := [], cconv := some "ptx_kernel", retAttrs := [], ret := .void, name := "k",
    params := [], group := none, names := #["0", "1", "2", "3"],
    blocks := #[⟨0, #[{ res := some 1, inst := .alloca (.int 32) none (some 4) }], .br 2⟩,
      ⟨2, #[{ res := some 3, inst := .alloca (.int 32) none (some 4) }], .ret none⟩] }

/-- The program `Module.check` makes of `pathText`'s module (one kernel `@k`, the default data
layout, no intrinsics), with the empty digest (the `#guard` below checks it). -/
def pathP : Program :=
  { module := { (default : Module) with funcs := #[pathK] }, sha256 := "", layout := {},
    intrinsics := [], kernels := ["k"] }

-- the parser takes `pathText` to `pathP`'s module, and `Module.check` (with the
-- empty digest) to `pathP`, every field (`Program.diff`); `Module.twice` finds no id defined twice
#guard match parse pathText.toUTF8 >>= (·.check "") with
  | .ok p => p.diff pathP == [] && p.module.twice == none
  | .error _ => false
-- the mutant with the result `%1` of the first `alloca` also the second block's label, as a
-- hand-built function could give: the parser refuses it ("'%1 in @k' defined twice")
#guard match parse ("define ptx_kernel void @k() {\n  %1 = alloca i32, align 4\n" ++
    "  br label %1\n\n1:\n  %2 = alloca i32, align 4\n  ret void\n}\n").toUTF8 with
  | .ok _ => false
  | .error e => e == "'%1 in @k' defined twice"

/-- The summary of `pathK`'s block `l` with the `alloca` flag (`summarizeAt true`, the exit from
`SState.exitAt`), the default summary when there is none. -/
def pathS (l : Nat) : Summary :=
  (summarizeAt true pathP pathK l 0 fun σ tm => σ.exitAt pathK l tm).getD default

/-- The path of `pathK`'s two blocks, 0 then 2, each with its summary's own obligations. -/
def pathPs : List (Nat × List Cond × Summary) :=
  [(0, (pathS 0).obls, pathS 0), (2, (pathS 2).obls, pathS 2)]

/-- **The path checker with the flag accepts `pathK`'s path** (`coversPathAt true`), each block
with one `alloca` effect, the last exit `ret void`; without the flag (`coversPathWith`) it
refuses the path. -/
theorem path_covers :
    coversPathAt true false pathP pathK 0 pathPs = true ∧
    (pathS 0).effs = [.alloca 0 0 0 none] ∧ (pathS 2).effs = [.alloca 2 0 0 none] ∧
    (pathS 2).exit = .ret ∧ coversPathWith false pathP pathK 0 pathPs = false := by
  decide +kernel

/-- **The mutant**: the path whose last summary drops its `alloca` effect is refused. -/
theorem path_mutant :
    coversPathAt true false pathP pathK 0
      [(0, (pathS 0).obls, pathS 0), (2, (pathS 2).obls, { pathS 2 with effs := [] })] =
      false := by
  decide +kernel

/-- **`pathK`'s path returns with both `alloca` blocks dead**: for every context of `pathP` and
thread whose only frame `f` is at the entry of `pathK`'s block 0, with memory `m`, whose path
premises hold (`WalkWith false`): the steps reach the `ret` of block 2 on the memory `me` that
block 2's effects make from its entry valuation (`Valuation.intoWith false` of block 0), and its
step ends the thread with the blocks of both `alloca`s (block 2's first) and `f`'s dead
(`Block.sound_pathAt_ptrs`, `EndsWith.ret`). -/
theorem path_ret {c : Ctx} (hP : c.prog = pathP) {t : Thread} {m : Mem} {f : Frame}
    (ht : t.frames = [f]) (hfn : f.fn = pathK) (hl : f.label = 0) (hp : f.pc = 0)
    (hW : WalkWith false (Valuation.entry c t.k m f) pathPs) :
    ∃ fe me, Steps c t m ⟨[fe], t.k + pathLen (pathS 0) pathPs.tail⟩ me ∧
      SEff.run ((Valuation.entry c t.k m f).intoWith false 0 (pathS 0))
        (vals ((Valuation.entry c t.k m f).intoWith false 0 (pathS 0)) (pathS 2).nodes)
        (pathS 2).effs = .ok me ∧
      step c ⟨[fe], t.k + pathLen (pathS 0) pathPs.tail⟩ me = .ok (.done
        ((SEff.blocks ((Valuation.entry c t.k m f).intoWith false 0 (pathS 0)) (pathS 2).effs ++
          SEff.blocks (Valuation.entry c t.k m f) (pathS 0).effs ++ f.allocas).foldl
          (fun m b => m.setLive b false) me)) :=
  EndsWith.ret
    (Block.sound_pathAt_ptrs (rest := []) hP pathPs.tail path_covers.1 ht hfn hl hp hW).1
    (Valuation.lastWith_k false (Valuation.entry c t.k m f) 0 (pathS 0) pathPs.tail).2.2
    path_covers.2.2.2.1

/-- **`pathK`'s thread runs to its end**: for every context of `pathP` and thread whose only
frame `f` is at the entry of `pathK`'s block 0, with memory `m`, whose path runs to `ret` with a
memory of `Q` (`RetWith false`), the thread runs (`Runs`) leaving such a memory with the blocks
of both `alloca`s and `f`'s dead (`Runs.of_retAt`). -/
theorem path_runs {c : Ctx} (hP : c.prog = pathP) {t : Thread} {m : Mem} {f : Frame}
    (ht : t.frames = [f]) (hfn : f.fn = pathK) (hl : f.label = 0) (hp : f.pc = 0)
    {Q : Mem → Prop} (hR : RetWith false (Valuation.entry c t.k m f) Q pathPs) :
    ∃ me, Runs c t m ((SEff.blocks ((Valuation.entry c t.k m f).intoWith false 0 (pathS 0))
      (pathS 2).effs ++ SEff.blocks (Valuation.entry c t.k m f) (pathS 0).effs ++
        f.allocas).foldl (fun m b => m.setLive b false) me) ∧ Q me :=
  Runs.of_retAt hP path_covers.1 ht hfn hl hp hR

/-- The skeleton choices of `pathK`'s launch: choice `i` is `i`. -/
def pathCh : Nat → Nat := fun i => i

/-- The context of thread 0 of `pathK` launched as one thread (`Launch.one`) with the skeleton
choices `pathCh` and every payload choice 0, as `Grid.start` makes it (`path_start`): its
`alloca` at step `k` reads the addresses `pathCh (Nat.pair 1 (Nat.pair 0 (Nat.pair k i)))`,
`i = 0, 1`. -/
def pathCtx : Ctx :=
  { prog := pathP, globals := fun _ => none, env := Launch.one.env 0, who := ⟨0, 0⟩,
    addr := fun j => pathCh (Nat.pair 1 (Nat.pair 0 j)), oracle := fun _ => 0 }

/-- The frame of `pathK`'s thread at the launch: block 0's entry, no registers and no `alloca`
blocks. -/
def pathF : Frame :=
  { fn := pathK, label := 0, pc := 0, regs := fun _ => none, prods := fun _ => none,
    allocas := [], dest := none }

/-- `pathK`'s thread at the launch: the one frame `pathF`, no step taken. -/
def pathT : Thread := ⟨[pathF], 0⟩

/-- The memory of `pathK`'s launch (`path_start`): from the empty memory, the block of dynamic
shared memory of block of threads 0 (number 1, 0 bytes), so the next fresh number is 2; and an
empty trace. -/
def pathMem : Mem :=
  { (({} : Mem).alloc {} 3 0 1 true false (.cta 0) (pathCh (Nat.pair 2 0))
      (pathCh (Nat.pair 2 1))).1 with trace := [] }

/-- **The launch**: `Grid.start` of `pathK` as one thread with the skeleton choices `pathCh` and
every payload choice 0, from the empty memory, gives one thread, `pathT`, on the memory
`pathMem`, with thread 0's context `pathCtx`. -/
theorem path_start :
    (Grid.start pathP pathK Launch.one [] {} pathCh fun _ _ => 0).map (fun r => (r.1, r.2 0)) =
      .ok (⟨#[.run pathT], pathMem⟩, pathCtx) := rfl

/-- The memory at `pathK`'s `ret` from the launch: what block 2's effects (`SEff.run`) make from
its entry valuation on the path (`Valuation.intoWith false` of block 0 from the launch), the empty
memory if they fault (they do not: `path_retMem`). -/
def pathRet : Mem :=
  match SEff.run ((Valuation.entry pathCtx pathT.k pathMem pathF).intoWith false 0 (pathS 0))
      (vals ((Valuation.entry pathCtx pathT.k pathMem pathF).intoWith false 0 (pathS 0))
        (pathS 2).nodes) (pathS 2).effs with
  | .ok m => m
  | .error _ => {}

/-- **The memory at the `ret`** (one function at one context, thread and memory): `pathRet` keeps
`pathMem`'s next number 2, its empty trace and its block 1 (dynamic shared memory: space 3, 0
bytes, owned by block of threads 0), and has a live block of 4 bytes in the alloca space 0,
writable, owned by thread 0, at each `alloca`'s number (`Mem.fresh` of thread 0 at steps 0 and
2: 2 and 6), with the addresses `pathCtx.addr (Nat.pair k i) * 4`; numbers 0, 3, 4, 5 and 7 have
no block. -/
theorem path_retMem :
    pathRet.next = 2 ∧ pathRet.trace.isEmpty ∧
    (pathRet.blocks 1).map (fun b => (b.space, b.size, b.live, b.readOnly, b.owner)) =
      some (3, 0, true, false, .cta 0) ∧
    (∀ k ∈ [0, 2],
      (pathRet.blocks (pathMem.fresh 0 k)).map
        (fun b => (b.space, b.size, b.live, b.readOnly, b.owner)) =
        some (0, 4, true, false, .thread 0) ∧
      (pathRet.blocks (pathMem.fresh 0 k)).map (fun b => (b.addr, b.gaddr)) =
        some (pathCtx.addr (Nat.pair k 0) * 4, pathCtx.addr (Nat.pair k 1) * 4)) ∧
    ∀ b ∈ [0, 3, 4, 5, 7], (pathRet.blocks b).isNone := by
  decide +kernel

/-- The memory `pathK`'s thread ends with: `pathRet` with the two `alloca` blocks, 6 and then 2,
set dead (`Mem.setLive`). -/
def pathEnd : Mem := [6, 2].foldl (fun m b => m.setLive b false) pathRet

/-- **The path's premises hold at the launch** (one function, the two-block alloca path, at one
context, thread and memory: `pathCtx`, `pathT`, `pathMem`): each block's obligations, the
`alloca`s' `.mem` obligations included, hold at its entry valuation, and block 0 branches to
block 2 (`WalkWith false`, decided). -/
theorem path_walk : WalkWith false (Valuation.entry pathCtx pathT.k pathMem pathF) pathPs := by
  decide +kernel

/-- **The path runs to `ret` at the launch, with the memory `pathRet`** (one function at one
context, thread and memory): `RetWith false` with the predicate "is `pathRet`": the premises
(`path_walk`), block 2's exit `ret void`, and block 2's effects from its entry valuation make
exactly `pathRet`. -/
theorem path_retWith :
    RetWith false (Valuation.entry pathCtx pathT.k pathMem pathF) (· = pathRet) pathPs :=
  ⟨path_walk, by decide +kernel, _, rfl, rfl⟩

/-- **Both `alloca` blocks are dead after the return** (one function at one context, thread and
memory): the instance of `path_ret` at the launch reaches the `ret` at step 3 on `pathRet`,
where blocks 2 and 6 (`Mem.fresh` of thread 0 at steps 0 and 2) are live (`path_retMem`), and the
`ret`'s step ends the thread on `pathEnd`, where both are dead; the instance of `path_runs` with
`path_retWith` is the run (`Runs`) to `pathEnd`. -/
theorem path_dead :
    (∃ fe, Steps pathCtx pathT pathMem ⟨[fe], 3⟩ pathRet ∧
      step pathCtx ⟨[fe], 3⟩ pathRet = .ok (.done pathEnd)) ∧
    Runs pathCtx pathT pathMem pathEnd ∧
    pathMem.fresh 0 0 = 2 ∧ pathMem.fresh 0 2 = 6 ∧
    ∀ b ∈ [2, 6], (pathEnd.blocks b).map (·.live) = some false := by
  have hk : pathT.k + pathLen (pathS 0) pathPs.tail = 3 := by decide +kernel
  have hb : SEff.blocks ((Valuation.entry pathCtx pathT.k pathMem pathF).intoWith false 0
      (pathS 0)) (pathS 2).effs ++ SEff.blocks (Valuation.entry pathCtx pathT.k pathMem pathF)
      (pathS 0).effs ++ pathF.allocas = [6, 2] := by
    decide +kernel
  obtain ⟨fe, me, hS, hm, hst⟩ :=
    path_ret (c := pathCtx) (t := pathT) (f := pathF) rfl rfl rfl rfl rfl path_walk
  obtain rfl : me = pathRet := Except.ok.inj (hm.symm.trans rfl)
  obtain ⟨_, hr, rfl⟩ :=
    path_runs (c := pathCtx) (t := pathT) (f := pathF) rfl rfl rfl rfl rfl path_retWith
  rw [hk] at hS hst
  rw [hb] at hst hr
  exact ⟨⟨fe, hS, hst⟩, hr, by decide +kernel⟩

/-- **The interpreter's cross-check** (one function at one context, thread and memory): `step`,
iterated from the launch (`runTo`, four steps: the two `alloca`s, the branch and the `ret`),
reaches the `ret` on `pathRet` and ends the thread on `pathEnd`, the memories of `path_dead`. -/
theorem path_steps : (runTo pathCtx 4 pathT pathMem).map (·.2) = some (pathRet, .done pathEnd) :=
  rfl

/-- **The mutant memory** (one function at one context and thread): `pathMem` with a block at the
first `alloca`'s number (`Mem.fresh` of thread 0 at step 0, 2) already. The path's premises fail
there (the `.mem` obligation of block 0: the `alloca`'s effect faults with "alloca number in
use"), so `RetWith` fails for every predicate. -/
theorem path_used (Q : Mem → Prop) : ¬ RetWith false
    (Valuation.entry pathCtx pathT.k
      (pathMem.alloc {} 1 4 4 true false .all 0 0 (num := some (pathMem.fresh 0 0))).1 pathF)
    Q pathPs := by
  have h : ¬ WalkWith false (Valuation.entry pathCtx pathT.k
      (pathMem.alloc {} 1 4 4 true false .all 0 0 (num := some (pathMem.fresh 0 0))).1 pathF)
      pathPs := by
    decide +kernel
  exact fun hR => h hR.1

end MojoProofTest.SymAlloca
