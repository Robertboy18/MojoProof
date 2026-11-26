import MojoProofTest.SymColl
import MojoProofTest.SymChain
import MojoProofTest.Atomics
import MojoProof.Sym.Canon
import MojoProof.LLVM.Import

/-!
# The canonical run of a kernel whose warps branch around a shuffle

Instances of `CanonRun`, `WarpRun`, `WarpShfl` and `CanonRun.start_sound`
(MojoProof/Sym/Canon.lean) for a hand-built kernel at block sizes 40 and 70. The kernel `kern`
is the parser's term for `text` (checked by `#guard`):

    %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
    %1 = and i32 %0, 32
    %2 = icmp eq i32 %1, 0
    br i1 %2, label %sh, label %end
    sh:
    %3 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %0, i32 16, i32 31)
    br label %end
    end:
    ret void

launched on one block of `B` threads (`SymChain.L B`) on the empty memory, with address choice
and oracle 0; thread `n`'s `%0` is the `i32` scalar `n` (`Atomics.b n`). A warp whose first
thread has bit 5 clear shuffles; the others skip the shuffle. The module `md ra` declares the
shuffle with the result attributes `ra`: `text` is `md []`, and `textN`, `text` with
`declare noundef i32 @llvm.nvvm.shfl…`, is `md [.flag "noundef"]` (both checked by `#guard`). The
lanes' and warps' theorems are for every `ra` at which the checkers accept the kernel (`Checks`,
decided at `[]` and `noundef` by `covers`).

* Each lane's run is by the checkers (`lane`, `skipLane`): a lane that shuffles goes from the
  start through the entry block's edge into `sh` (`Block.sound_edge`, `RunsVia.of_steps`), through
  `sh`'s segments at the shuffle (`Piece.throughTo`) and from there to `ret` (`Runs.of_retMem`),
  joined by `RunsVia.of_fires`; a lane that skips it runs along the path to `ret`
  (`Runs.of_retMem`). The kernel decides each lane's premises (`Edge`, `Piece.fires`, the wait's
  call, arguments and delivery) and evaluates its memories (`endMem`).
* `sound40`: at block size 40 (warps 0 and 32), warp 0 shuffles and warp 32 (8 lanes) skips; the
  launch is sound (`Grid.Sound`), by `CanonRun.start_sound` at the canonical run, with the
  shuffle declared without result attributes and with `noundef`. A warp that shuffles runs by
  `WarpRun.of_waits` (`shflWarp`), from each lane's run through its wait (`wt`), its deliveries
  under the declaration's attributes (`withAttrs`; `noundef` keeps warp 0's words).
  `deliver40`: lane `j` of warp 0 is delivered thread `j ^^^ 16`'s `%0`.
* `sound70`: at block size 70 (warps 0, 32 and 64), with no attribute, warps 0 and 64 shuffle and
  warp 32 skips; the launch is sound. `poison70`: every lane of the last warp, 64 (6 lanes), is
  delivered `poison`, as lane `j ^^^ 16` is not one of its lanes.
* `attrs`: with `noundef`, each of warp 64's deliveries at block size 70 faults, so that warp has
  no `WarpShfl`; `range(i32 0, 16)` keeps lane 16's word and turns lane 0's into `poison`.
* The refused fires (`early`, `mixed`): at block size 40, with lanes 0 to 30 of warp 0 at the
  shuffle (each lane's thread `atSh`, a frame at the shuffle's instruction), `Grid.fire` at thread
  0 gives no step while lane 31 still runs, and refuses the shuffle when lane 31 waits at a
  shuffle of another mode. `halfMask`: with lane 31 at the
  shuffle with a mask that is not full, the statuses have no `WarpShfl`.

Statements about this kernel at these launches and these two declarations of the shuffle, not
about every kernel or launch.
-/

namespace MojoProofTest.SymCanon

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym
open MojoProofTest.SymColl (tidDecl shflDecl shflName shflCall)
open MojoProofTest.SymChain (L)
open MojoProofTest.Atomics (b)

-- `Array.any` recurses by well-founded recursion, so `rfl` cannot evaluate a step without this.
unseal Array.anyM.loop

/-- The kernel's text. -/
def text : String := "declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()
declare i32 @llvm.nvvm.shfl.sync.bfly.i32(i32, i32, i32, i32) #0

define ptx_kernel void @k() {
entry:
  %0 = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %1 = and i32 %0, 32
  %2 = icmp eq i32 %1, 0
  br i1 %2, label %sh, label %end
sh:
  %3 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 %0, i32 16, i32 31)
  br label %end
end:
  ret void
}

attributes #0 = { convergent }
"

/-- The kernel `@k`, numbered as the parser numbers it: `entry` is label 0, `%0` to `%2` are
locals 1 to 3, `sh` and `end` labels 4 and 5, `%3` local 6. -/
def kern : Func :=
  { linkage := [], cconv := some "ptx_kernel", retAttrs := [], ret := .void, name := "k",
    params := [], group := none, names := #["entry", "0", "1", "2", "sh", "end", "3"],
    blocks := #[
      ⟨0, #[{ res := some 1, inst := .call {} (.int 32) (.fn tidDecl.name) [] },
            { res := some 2, inst := .bin .and {} (.int 32) (.loc 1) (.int 32) },
            { res := some 3, inst := .icmp .eq (.int 32) (.loc 2) (.int 0) }],
        .condBr (.loc 3) 4 5⟩,
      ⟨4, #[{ res := some 6, inst := shflCall 1 16 }], .br 5⟩,
      ⟨5, #[], .ret none⟩] }

/-- The module of the two intrinsics and `kern`, with attribute group 0 `convergent`, the
shuffle's declaration putting the attributes `ra` on its result. -/
def md (ra : List Attr) : Module :=
  { (default : Module) with
    funcs := #[tidDecl, { shflDecl with retAttrs := ra }, kern]
    attrGroups := #[(0, [.flag "convergent"])] }

/-- The program of `md ra`. -/
def prog (ra : List Attr) : Program :=
  { module := md ra, sha256 := "", layout := {},
    intrinsics := [(tidDecl.name, .sreg .tid .x), (shflName, .shfl .bfly)], kernels := ["k"] }

/-- `text` with `noundef` on the shuffle's result. -/
def textN : String :=
  text.replace "declare i32 @llvm.nvvm.shfl" "declare noundef i32 @llvm.nvvm.shfl"

-- The parser and the import checks accept `text`, with module `md []` and `prog []`'s layout,
-- intrinsics and kernels, and `textN`, with module `md [.flag "noundef"]`.
#guard [(text, []), (textN, [.flag "noundef"])].all fun (t, ra) => match importBytes t.toUTF8 with
  | .ok p => p.module == md ra && p.layout == (prog ra).layout &&
      p.intrinsics == (prog ra).intrinsics && p.kernels == (prog ra).kernels
  | .error _ => false

/-- The launch of `kern` in `prog ra` on `L B`, on the empty memory, with address choice and
oracle 0. -/
def start (ra : List Attr) (B : Nat) : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start (prog ra) kern (L B) [] {} (fun _ => 0) (fun _ _ => 0)

/-- The grid and contexts of `start ra B`. -/
def run0 (ra : List Attr) (B : Nat) : Grid × (Nat → Ctx) :=
  match start ra B with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, Launch.c)

/-- The start's grid. -/
def g0 (ra : List Attr) (B : Nat) : Grid := (run0 ra B).1

/-- The start's contexts. -/
def c (ra : List Attr) (B : Nat) : Nat → Ctx := (run0 ra B).2

/-- A start that succeeds gives `g0 ra B` and `c ra B`. -/
theorem start_eq {ra : List Attr} {B : Nat} (h : (start ra B).toBool = true) :
    start ra B = .ok (g0 ra B, c ra B) := by
  unfold g0 c run0
  cases hs : start ra B with
  | error => rw [hs] at h; cases h
  | ok r => rfl

/-- What the shuffle of warp `k` delivers to its lane `j`: lane `j ^^^ 16`'s `%0` if it is one
of the warp's lanes, `poison` otherwise (`shflVal`, `shflSource`). -/
def r (B k j : Nat) : Option Val :=
  some (shflVal (warpLanes (L B) k) (fun i => b (k + i)) (shflSource .bfly j 16 31))

/-- The summary of `kern`'s block `l` from position `p` in `prog ra` (`summarizeAt false`, the
exit from `SState.exitAt`), the default summary when there is none. -/
def sS (ra : List Attr) (l p : Nat) : Summary :=
  (summarizeAt false (prog ra) kern l p fun σ tm => σ.exitAt kern l tm).getD default

/-- The entry block alone, the path to its branch. -/
def entryPs (ra : List Attr) : List (Nat × List Cond × Summary) :=
  [(0, (sS ra 0 0).obls, sS ra 0 0)]

/-- The path from position 1 of `sh` (after the shuffle) through `end` to `ret`. -/
def endPs (ra : List Attr) : List (Nat × List Cond × Summary) :=
  [(4, (sS ra 4 1).obls, sS ra 4 1), (5, (sS ra 5 0).obls, sS ra 5 0)]

/-- The path of a thread that skips the shuffle: the entry block, then `end` to `ret`. -/
def skipPs (ra : List Attr) : List (Nat × List Cond × Summary) :=
  [(0, (sS ra 0 0).obls, sS ra 0 0), (5, (sS ra 5 0).obls, sS ra 5 0)]

/-- The segments of block `sh` from position 0 with the stop at the shuffle (position 0): one
collective segment and the rest's summary (`summarizePieces`), the default when there is none. -/
def shP (ra : List Attr) : List Piece × Summary :=
  (summarizePieces (prog ra) kern 4 0 [0] false).getD default

/-- The checkers accept `kern` in `prog ra`: the path checker (`coversPathAt` with neither flag)
`entryPs` and `skipPs` from position 0 and `endPs` from position 1, and the segment checker
`sh` at the shuffle. -/
abbrev Checks (ra : List Attr) : Prop :=
  coversPathAt false false (prog ra) kern 0 (entryPs ra) = true ∧
    coversPathAt false false (prog ra) kern 1 (endPs ra) = true ∧
    coversPathAt false false (prog ra) kern 0 (skipPs ra) = true ∧
    (summarizePieces (prog ra) kern 4 0 [0] false).isSome = true

/-- **The checkers accept the kernel** with the shuffle declared without result attributes and
with `noundef`. -/
theorem covers : Checks [] ∧ Checks [.flag "noundef"] := by
  decide +kernel

/-- `shP ra` is the segment checker's result when the checkers accept the kernel. -/
theorem shP_eq {ra : List Attr} (h : Checks ra) :
    summarizePieces (prog ra) kern 4 0 [0] false = some (shP ra) := by
  have h4 := h.2.2.2
  unfold shP
  cases hx : summarizePieces (prog ra) kern 4 0 [0] false with
  | none => rw [hx] at h4; cases h4
  | some s => rfl

/-- The frame of `kern` at the shuffle's instruction (block `sh`, position 0), with no register,
product, `alloca` block or caller register. -/
def fr : Frame := ⟨kern, 4, 0, fun _ => none, fun _ => none, [], none⟩

/-- Thread `n`'s frame at the start (`fr` if it has none). -/
def f0 (ra : List Attr) (B n : Nat) : Frame := (Grid.thread (g0 ra B) n).frames.headD fr

/-- Thread `n`'s entry valuation at the start: `f0 ra B n` under its context, on the start's
memory, at step count 0. -/
def V0 (ra : List Attr) (B n : Nat) : Valuation :=
  Valuation.entry (c ra B n) 0 (g0 ra B).mem (f0 ra B n)

/-- Thread `n`'s valuation at the entry of `sh`, after the entry block's edge
(`Valuation.roundWith`). -/
def V1 (ra : List Attr) (B n : Nat) : Valuation :=
  Valuation.roundWith false 0 (sS ra 0 0) [] (V0 ra B n)

/-- Thread `n` goes from the entry block to `sh`: the block's premises hold at `V0 ra B n`, its
branch goes to label 4, at position 0. -/
abbrev Edge (ra : List Attr) (B n : Nat) : Prop :=
  WalkWith false (V0 ra B n) (entryPs ra) ∧
    (sS ra 0 0).exit.dest (V0 ra B n) (vals (V0 ra B n) (sS ra 0 0).nodes) = some 4 ∧
    (sS ra 0 0).exit.pc kern 4 = 0

/-- The memory thread `n` ends at, from the end of `sh`'s segments with the deliveries `ds`
(`Piece.after`, `Piece.allocs`) through `endPs ra` (`Valuation.retMem`). -/
def endMem (ra : List Attr) (B n : Nat) (ds : List (Option Val × Mem)) : Mem :=
  (Piece.after kern 4 (shP ra).1 0 ds (V1 ra B n)).retMem false
    (Piece.allocs kern 4 (shP ra).1 0 ds (V1 ra B n) ++
      (V0 ra B n).allocsWith false 0 (sS ra 0 0) []) (endPs ra)

/-- **A lane that shuffles, by the checkers**: for every result attributes `ra` of the shuffle's
declaration at which the checkers accept the kernel (`Checks`), block size `B` whose start
succeeds, thread `n` of the start with `Edge ra B n`, and deliveries `ds` at which `sh`'s segments
pass (`Piece.fires` with `retB false (endPs ra)` at the end), the thread runs from the start
through the waits `Piece.walk` records to its end at `endMem ra B n ds` (`RunsVia`): the entry
block's edge (`Block.sound_edge`, `RunsVia.of_steps`), the segments (`Piece.throughTo`) and the
path to `ret` (`Runs.of_retMem`), joined by `RunsVia.of_fires`. -/
theorem lane {ra : List Attr} {B n : Nat} (hC : Checks ra) (hs : (start ra B).toBool = true)
    (hn : n < (g0 ra B).threads.size) (hE : Edge ra B n) {ds : List (Option Val × Mem)}
    (hF : Piece.fires kern 4 (retB false (endPs ra)) (shP ra).1 0 ds (V1 ra B n) = true) :
    RunsVia (c ra B n) (· = endMem ra B n ds)
      ((Piece.waits kern 4 (shP ra).1 0 ds (V1 ra B n)).map (Piece.Wait.via kern 4))
      (Grid.thread (g0 ra B) n) (g0 ra B).mem := by
  obtain ⟨f, ht, hfn, hl, hp, ha⟩ := Grid.start_thread (start_eq hs) hn
  have hf : f0 ra B n = f := by unfold f0; rw [ht]; rfl
  subst hf
  have hP := (Grid.start_ctx (start_eq hs) n).1
  have hl0 : (f0 ra B n).label = 0 := Option.some.inj (hl.symm.trans (by decide))
  rw [ht]
  obtain ⟨t', m', f', hS, ht', hfn', hl', hp', ha', -, -, hV⟩ :=
    Block.sound_edge (t := ⟨[f0 ra B n], 0⟩) (d := 4) hP hC.1 rfl hfn hl0 hp hE.1 hE.2.1
  have hp1 : f'.pc = 0 := hp'.trans hE.2.2
  have hT := Piece.throughTo (alloca := false) (ps := [0]) (p0 := 0) hP (shP_eq hC)
    (K := fun t m f => retB false (endPs ra) (Valuation.entry (c ra B n) t.k m f) = true →
      Runs (c ra B n) t m ((Valuation.entry (c ra B n) t.k m f).retMem false f.allocas (endPs ra)))
    (fun _ _ _ ht hfn hl hp hR => Runs.of_retMem hP hC.2.1 ht hfn hl hp hR)
    (fun i => ds.getD i (none, (g0 ra B).mem)) (m := m') ht' hfn' hl' hp1
  have h := RunsVia.of_fires (Q := fun V A => (· = V.retMem false A (endPs ra)))
    (G := fun _ => []) (F := retB false (endPs ra)) (fun _ _ _ hK hF => ⟨_, hK hF, rfl⟩) hT hfn'
    hp1 (by rw [hV]; exact hF)
  simp only [hV, ha', ha, List.append_nil] at h
  exact RunsVia.of_steps hS h

/-- A lane that skips the shuffle, by the path checker: for every `ra` at which the checkers
accept the kernel, block size `B` whose start succeeds and thread `n` of the start whose path
`skipPs ra` returns from `V0 ra B n` (`retB`), the thread runs to its end at `Valuation.retMem` of
`skipPs ra` (`Runs.of_retMem`). -/
theorem skipLane {ra : List Attr} {B n : Nat} (hC : Checks ra) (hs : (start ra B).toBool = true)
    (hn : n < (g0 ra B).threads.size) (hR : retB false (skipPs ra) (V0 ra B n) = true) :
    Runs (c ra B n) (Grid.thread (g0 ra B) n) (g0 ra B).mem
      ((V0 ra B n).retMem false [] (skipPs ra)) := by
  obtain ⟨f, ht, hfn, hl, hp, ha⟩ := Grid.start_thread (start_eq hs) hn
  have hf : f0 ra B n = f := by unfold f0; rw [ht]; rfl
  subst hf
  have h := Runs.of_retMem (t := ⟨[f0 ra B n], 0⟩) (Grid.start_ctx (start_eq hs) n).1 hC.2.2.1
    rfl hfn (Option.some.inj (hl.symm.trans (by decide))) hp hR
  rw [ha] at h
  rw [ht]
  exact h

/-- **A warp that skips the shuffle**: for every `ra` at which the checkers accept the kernel,
block size whose start succeeds and warp `k` of `N` lanes whose lanes are threads of the start,
return along `skipPs ra` (`retB`) and end on the start's memory, the lanes run in turn to their
returns (`WarpRun.of_inv` with no shuffle), each by `skipLane`. -/
theorem skipWarp {ra : List Attr} {B k N : Nat} (hC : Checks ra)
    (hs : (start ra B).toBool = true) (hN : (warpLanes (L B) k).length = N)
    (hc : ∀ j < N, k + j < (g0 ra B).threads.size ∧
      retB false (skipPs ra) (V0 ra B (k + j)) = true)
    (he : ∀ j < N, (V0 ra B (k + j)).retMem false [] (skipPs ra) = (g0 ra B).mem) :
    ∃ Es, WarpRun (L B) (c ra B) k (Grid.thread (g0 ra B)) (g0 ra B).mem Es (g0 ra B).mem := by
  subst hN
  obtain ⟨Es, _, h, rfl⟩ := WarpRun.of_inv (L := L B) (c := c ra B) (k := k)
    (t := Grid.thread (g0 ra B)) (J := 0)
    (T := fun _ j t => t = Grid.thread (g0 ra B) (k + j)) (W := fun _ _ _ => True)
    (P := fun _ _ m => m = (g0 ra B).mem) (fun _ hi => absurd hi (Nat.not_lt_zero _))
    (fun _ hi => absurd hi (Nat.not_lt_zero _))
    (fun j hj t m ht hm => by
      obtain rfl := ht
      obtain rfl := hm
      have hj' := mem_warpLanes.1 hj
      exact ⟨_, skipLane hC hs (hc j hj').1 (hc j hj').2, he j hj'⟩)
    (fun _ _ => rfl) rfl
  exact ⟨Es, h⟩

/-- Lane `j` of warp `k`'s delivery: `r B k j` on the start's memory. -/
def dl (ra : List Attr) (B k j : Nat) : Option Val × Mem := (r B k j, (g0 ra B).mem)

/-- Lane `j` of warp `k`'s waits in `sh` (`Piece.waits`), delivered `dl ra B k j`. -/
def ws (ra : List Attr) (B k j : Nat) : List Piece.Wait :=
  Piece.waits kern 4 (shP ra).1 0 [dl ra B k j] (V1 ra B (k + j))

/-- The `i`-th of `ws ra B k j` (a barrier wait at position 0 on the empty memory if there is
none). -/
def wt (ra : List Attr) (B k i j : Nat) : Piece.Wait :=
  (ws ra B k j).getD i ⟨0, .barrier, [], {}, (none, {})⟩

/-- **The shuffle's declaration**: the declaration `prog ra` finds by a name whose intrinsic is a
shuffle is `shflDecl` with the result attributes `ra`. -/
theorem shfl_decl {ra : List Attr} {g : String} {e : Func} {mo : Shfl}
    (h : (prog ra).module.funcs.find? (·.name == g) = some e)
    (hl : (prog ra).intrinsics.lookup g = some (.shfl mo)) :
    e = { shflDecl with retAttrs := ra } := by
  have hg := beq_iff_eq.1 (Array.find?_some (p := fun x : Func => x.name == g) h)
  have he := Array.mem_of_find?_eq_some h
  simp only [prog, md, List.mem_toArray, List.mem_cons, List.not_mem_nil, or_false] at he
  rcases he with rfl | rfl | rfl
  · subst hg
    have hI : (prog ra).intrinsics.lookup tidDecl.name = some (.sreg .tid .x) := by kernel_rfl
    rw [hI] at hl
    cases hl
  · rfl
  · subst hg
    have hI : (prog ra).intrinsics.lookup kern.name = none := by kernel_rfl
    rw [hI] at hl
    cases hl

/-- **A warp that shuffles**: for every `ra` at which the checkers accept the kernel, block size
whose start succeeds and warp `k` of `N` lanes whose lanes are threads of the start with `Edge`,
pass `sh`'s segments delivered `dl ra B k j`, wait once at position 0 at the shuffle `bfly` with
mask `0xffffffff`, value `%0`, offset 16 and clamp 31, are delivered `r B k j`, which the
attributes `ra` keep (`withAttrs`), and keep the start's memory, the warp's run is
`WarpRun.of_waits` on the lanes' runs by `lane` (one wait each), so the shuffle's deliveries are
`Grid.fire`'s (`WarpShfl`), `r`. -/
theorem shflWarp {ra : List Attr} {B k N : Nat} (hC : Checks ra)
    (hs : (start ra B).toBool = true) (hN : (warpLanes (L B) k).length = N)
    (hc : ∀ j < N, k + j < (g0 ra B).threads.size ∧ Edge ra B (k + j) ∧
      Piece.fires kern 4 (retB false (endPs ra)) (shP ra).1 0 [dl ra B k j] (V1 ra B (k + j)) =
        true ∧
      (ws ra B k j).length = 1 ∧ (wt ra B k 0 j).call = .shfl .bfly ∧ (wt ra B k 0 j).pos = 0 ∧
      (wt ra B k 0 j).args = [.bits 32 (-1), b (k + j), .bits 32 16, .bits 32 31] ∧
      (wt ra B k 0 j).dlv.1 = r B k j)
    (hA : ∀ j < N, (r B k j).mapM (withAttrs (prog ra).layout (g0 ra B).mem (.int 32) ra) =
      .ok (r B k j))
    (hm : ∀ j < N, ((wt ra B k 0 j).mem, (wt ra B k 0 j).dlv.2, endMem ra B (k + j) [dl ra B k j]) =
      ((g0 ra B).mem, (g0 ra B).mem, (g0 ra B).mem)) :
    ∃ Es, WarpRun (L B) (c ra B) k (Grid.thread (g0 ra B)) (g0 ra B).mem Es (g0 ra B).mem := by
  subst hN
  refine WarpRun.of_waits (fn := kern) (lbl := fun _ => 4) (W := wt ra B k)
    (mo := fun _ => .bfly) (X := fun _ j => b (k + j)) (M := fun _ _ => (g0 ra B).mem) (J := 1)
    (fun j hj => ?_) (fun i hi j hj => ?_) (fun i hi j hj => ?_) (fun _ _ => rfl)
  · have hj' := mem_warpLanes.1 hj
    obtain ⟨hn, hE, hF, h1, -⟩ := hc j hj'
    obtain ⟨-, he⟩ := Prod.mk.inj (Prod.mk.inj (hm j hj')).2
    have h := lane hC hs hn hE hF
    rw [he, Piece.Wait.map_via (n := 0) (W := fun i => wt ra B k i j) (lbl := fun _ => 4)
      (fun i hi => by
        simp only [Nat.zero_add, wt, ws, List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi,
          Option.getD_some])
      (fun _ _ => rfl)] at h
    rw [show (Piece.waits kern 4 (shP ra).1 0 [dl ra B k j] (V1 ra B (k + j))).length = 1 from h1,
      ← List.range_eq_range'] at h
    exact h
  · obtain rfl : i = 0 := by omega
    have h0 := (hc 0 (List.length_pos_of_mem hj)).2.2.2.2.2.1
    have hj' := mem_warpLanes.1 hj
    obtain ⟨-, -, -, -, hcall, hpos, hargs, hdlv⟩ := hc j hj'
    refine ⟨congrArg Coll.intr hcall, hpos.trans h0.symm, _, _, _, _, _, hargs, rfl, rfl, rfl,
      fun g e h hl => ?_⟩
    have hP := (Grid.start_ctx (start_eq hs) (k + j)).1
    rw [hP] at h hl
    rw [shfl_decl h hl, hdlv, (Grid.start_ctx (start_eq hs) k).1]
    exact hA j hj'
  · obtain rfl : i = 0 := by omega
    obtain ⟨hw, hd⟩ := Prod.mk.inj (hm j (mem_warpLanes.1 hj))
    exact ⟨hw, (Prod.mk.inj hd).1⟩

/-- **The canonical run at block size 40 is sound** (`Grid.Sound`, with the observation that is
always `()`), with the shuffle declared without result attributes and with `noundef`: warp 0
shuffles and warp 32 skips the shuffle, by `CanonRun.start_sound`; each lane's runs by the
checkers (`shflWarp`, `skipWarp`), their premises, the attributes' check of warp 0's deliveries
(each a word, which `noundef` keeps) and the final trace's checks decided by the kernel. -/
theorem sound40 : ∀ ra ∈ ([[], [.flag "noundef"]] : List (List Attr)),
    Grid.Sound (L 40) (c ra 40) (g0 ra 40) (fun _ => some ()) fun _ => True := by
  intro ra hra
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hra
  have hC : Checks ra := by rcases hra with rfl | rfl; exacts [covers.1, covers.2]
  have hw : [0, 32] = warps (L 40) (g0 ra 40).threads.size := by
    rcases hra with rfl | rfl <;> decide +kernel
  rcases hra with rfl | rfl
  all_goals
    obtain ⟨_, w0⟩ := shflWarp (B := 40) (k := 0) (N := 32) hC (by decide +kernel)
      (by decide +kernel) (by decide +kernel) (fun j hj => by interval_cases j <;> kernel_rfl)
      (fun j hj => by interval_cases j <;> kernel_rfl)
    obtain ⟨_, w32⟩ := skipWarp (B := 40) (k := 32) (N := 8) hC (by decide +kernel)
      (by decide +kernel) (by decide +kernel) (fun j hj => by interval_cases j <;> kernel_rfl)
    have hc := CanonRun.cons w0 (.cons w32 (.nil _))
    rw [hw] at hc
    exact CanonRun.start_sound (start_eq (by decide +kernel)) (fun _ _ _ _ _ hc => by cases hc)
      (fun _ _ _ => rfl) (by decide) hc (fun _ _ => by decide +kernel) (by decide +kernel) rfl
      trivial

/-- **Warp 0's deliveries at block size 40**: lane `j` is delivered thread `j ^^^ 16`'s `%0`. -/
theorem deliver40 : ∀ j < 32, r 40 0 j = some (b (j ^^^ 16)) := by
  intro j hj
  interval_cases j <;> kernel_rfl

/-- **The canonical run at block size 70 is sound**: warps 0 and 64 shuffle and warp 32 skips the
shuffle; the run of the three warps by `CanonRun.of_inv`. -/
theorem sound70 : Grid.Sound (L 70) (c [] 70) (g0 [] 70) (fun _ => some ()) fun _ => True := by
  obtain ⟨_, w0⟩ := shflWarp (B := 70) (k := 0) (N := 32) covers.1 (by decide +kernel)
    (by decide +kernel) (by decide +kernel) (fun _ _ => withAttrs_mapM_nil _ _ _ _)
    (fun j hj => by interval_cases j <;> kernel_rfl)
  obtain ⟨_, w32⟩ := skipWarp (B := 70) (k := 32) (N := 32) covers.1 (by decide +kernel)
    (by decide +kernel) (by decide +kernel) (fun j hj => by interval_cases j <;> kernel_rfl)
  obtain ⟨_, w64⟩ := shflWarp (B := 70) (k := 64) (N := 6) covers.1 (by decide +kernel)
    (by decide +kernel) (by decide +kernel) (fun _ _ => withAttrs_mapM_nil _ _ _ _)
    (fun j hj => by interval_cases j <;> kernel_rfl)
  obtain ⟨_, _, hc, rfl⟩ := CanonRun.of_inv (L := L 70) (c := c [] 70)
    (t := Grid.thread (g0 [] 70)) (P := fun _ m => m = (g0 [] 70).mem) (ks := [0, 32, 64])
    (fun i hi m hm => by
      obtain rfl := hm
      match i, hi with
      | 0, _ => exact ⟨_, _, w0, rfl⟩
      | 1, _ => exact ⟨_, _, w32, rfl⟩
      | 2, _ => exact ⟨_, _, w64, rfl⟩
      | n + 3, h => simp only [List.length_cons, List.length_nil] at h; omega) rfl
  rw [show [0, 32, 64] = warps (L 70) (g0 [] 70).threads.size by decide +kernel] at hc
  exact CanonRun.start_sound (start_eq (by decide +kernel)) (fun _ _ _ _ _ hc => by cases hc)
    (fun _ _ _ => rfl) (by decide) hc (fun _ _ => by decide +kernel) (by decide +kernel) rfl
    trivial

/-- **A partial last warp delivers poison**: at block size 70, every lane of warp 64 (6 lanes) is
delivered `poison`, lane `j ^^^ 16` not being one of its lanes. -/
theorem poison70 : ∀ j ∈ warpLanes (L 70) 64, r 70 64 j = some .poison := by
  intro j hj
  rw [mem_warpLanes, show (warpLanes (L 70) 64).length = 6 by decide +kernel] at hj
  interval_cases j <;> kernel_rfl

/-- **Deliveries under other result attributes** (`withAttrs`), what `WarpRun.of_waits`'s `hW`
asks of the shuffle's declaration's: at block size 70, `noundef` faults at each of warp 64's
deliveries, `poison`, so that warp has no `WarpShfl` when the shuffle is declared `noundef`; at
block size 40, `range(i32 0, 16)` keeps lane 16's delivery (thread 0's `%0`) but turns lane 0's
(thread 16's) into `poison`. -/
theorem attrs :
    (∀ j < 6, ((r 70 64 j).mapM (withAttrs (prog [.flag "noundef"]).layout
      (g0 [.flag "noundef"] 70).mem (.int 32) [.flag "noundef"])).toBool = false) ∧
    ((r 40 0 16).mapM (withAttrs (prog []).layout (g0 [] 40).mem (.int 32)
      [.range (.int 32) 0 16])).toOption = some (r 40 0 16) ∧
    ((r 40 0 0).mapM (withAttrs (prog []).layout (g0 [] 40).mem (.int 32)
      [.range (.int 32) 0 16])).toOption = some (some .poison) := by
  decide +kernel

/-- A thread of `kern` at the shuffle: its one frame `fr`, at block `sh`, position 0. Before a
shuffle fires, `Grid.fire` reads only a waiting thread's position (`Thread.at`). -/
def atSh : Thread := ⟨[fr], 0⟩

/-- The status of lane `j` of warp 0 at the shuffle: `atSh` waits at the `bfly` with mask
`0xffffffff`, value `%0 = j`, offset 16 and clamp 31. -/
def st (j : Nat) : Status :=
  .wait atSh (.shfl .bfly) [.bits 32 (-1), b j, .bits 32 16, .bits 32 31] shflDecl

/-- The start's grid at block size 40 with lanes `0` to `30` of warp 0 at the shuffle (`st`). -/
def atShfl : Grid :=
  ⟨(List.range 31).foldl (fun ts n => ts.set! n (st n)) (g0 [] 40).threads, (g0 [] 40).mem⟩

/-- **No fire before the last lane waits**: `Grid.fire` at thread 0 gives no step while lane 31
still runs. -/
theorem early : Grid.fire (L 40) (c [] 40) atShfl 0 = .ok none := by
  kernel_rfl

/-- **No fire at different collectives**: with lane 31 waiting at a `shfl.sync.down` with the same
operands, `Grid.fire` at thread 0 refuses the shuffle. -/
theorem mixed : Grid.fire (L 40) (c [] 40)
    { atShfl with
      threads := atShfl.threads.set! 31
        (.wait atSh (.shfl .down) [.bits 32 (-1), b 31, .bits 32 16, .bits 32 31] shflDecl) }
    0 = .error (.unsupported "lanes of a warp at different collectives") := by
  kernel_rfl

/-- **No shuffle with a mask that is not full**: for every thread `t` of lane 31, with lane 31 of
warp 0 at the shuffle with mask `0xffff` and the others at `st`, the statuses have no `WarpShfl`,
for every threads and deliveries. -/
theorem halfMask (t : Thread) (u' : Nat → Thread) (r' : Nat → Option Val) : ¬ WarpShfl (L 40)
    (c [] 40) 0 (fun j => if j = 31 then
      .wait t (.shfl .bfly) [.bits 32 0xffff, b 31, .bits 32 16, .bits 32 31] shflDecl
      else st j) (g0 [] 40).mem u' r' := by
  rintro ⟨mode, M, A, B, C, bl, cl, d, h⟩
  obtain ⟨hs, hM, -⟩ := h 31 (by decide +kernel)
  simp only [↓reduceIte] at hs
  obtain ⟨-, -, ha, -⟩ := Status.wait.inj hs
  obtain ⟨hm, -⟩ := List.cons.inj ha
  rw [← hm] at hM
  exact absurd hM (by decide)

end MojoProofTest.SymCanon
