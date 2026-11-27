import MojoProofTest.SymGemvTail
import MojoProofTest.KernelRfl
import MojoProof.Sym.CanonBar
import MojoProof.Sym.WarpRoute
import MojoProof.Sem.WarpDot

/-!
# gemv_kernel's warps from `Grid.start`: seven shuffles as phases of one warp run

gemv_kernel (fixture `gemv`, MojoProofTest/SymLane.lean) launched by `Grid.start` with the
output, matrix and vector at blocks 3, 1 and 2 of `memAB` (MojoProofTest/SymRun.lean), the row
count `M` and the column count `K`. Each thread computes its own row
`%20 = (ctaid.x · ntid.x + tid.x) / 32`
(tests/corpus/gemv/gemv_f32_gemv_kernel_float32_float32_float32_False_b79a852b.nvptx.ll lines
13-21), but the guard `%36 ≥ M` and the rest of the lane read `%36`, the row of the warp's lane
0, which `%6`'s two `shfl.sync.idx` broadcast (`%24` and `%25`, lines 25-26; PTX ISA 9.5,
section 9.7.10.6, mode `.idx`). A warp's row below is this row, its lane 0's. The two rows are
equal when 32 divides the block size, and at the five launches here (blocks of 32, 64, 16, 32
and 32 threads) every lane's own row is its lane 0's. They differ otherwise: at 2 blocks of 48
threads and `M = 2`, thread 64 computes row 2, but its warp starts at thread 48 (row 1), so it
takes `%44`.

* `lane`: a lane whose warp's row is below `M` runs from the start through `%6`'s two
  `shfl.sync.idx` (`Piece.throughTo`), the chain through `%44` into the loop at `%54` and `n`
  rounds through one arm (`ChainWith.of_rounds`), `%59`'s edge into `%78` (`RunsVia.of_chain`),
  `%78`'s five `shfl.sync.bfly` (`Piece.throughTo`) and the path to `ret` (`Runs.of_retMem`), the
  three joined by `RunsVia.of_fires`. `lane43`: a lane whose warp's row is at least `M` runs
  through `%6`'s two shuffles and `%43` to `ret`.
* `warp78`: the lanes of a warp whose row is below `M`, in turn, make one `WarpRun.of_waits`
  with seven phases, two in `%6` and five in `%78`; `warp43` the same with two phases. The
  deliveries are `Grid.fire`'s (`WarpShfl`), from the values the lanes offer, each lane its own
  (`Warp.v`, by phase and lane). Lane `j` runs `⌈K / 32⌉` rounds (`rounds`) through `%70` if
  `j < K` and through `%75` if not (`arm`), which is lane `j`'s path when `K ≤ 32` or `32 ∣ K`.
* `run32`: one block of 32 threads, `M = 1`: warp 0 by `warp78`. `run64`: one block of 64
  threads, `M = 1`: warp 0 by `warp78`, warp 32 (row 1) by `warp43`; the two in turn by
  `CanonRun`. Each reaches a done grid whose output cell 0 holds `0.0` (`CanonRun.start_done`),
  at `K = 0`, the loop at 0 rounds.
* `run4`: one block of 32 threads, `M = 1`, `K = 4`, the row `[2 ^ 24, 1, -2 ^ 24, 1]` and the
  vector of ones: lanes 0 to 3 take one round through `%70`, the others one through `%75`, and
  the done grid's output cell 0 holds the word of `warpDot` of the four pairs (`2`), not the
  left-to-right `dotLoop` sum (`1`, `orders`). `run3`: the same at `K = 3` (the row's first
  three words), `1` and not `0`. `run32`, `run4`, `run3` and `poison16` are `one78`, a launch of
  one warp by `warp78` and `CanonRun.start_done`, at their launch. `run4_deliver`: `run4`'s cell
  as the word of the semantics' rounds `deliver (Model.add x y) 0` (`bflyRoundsAt_deliver`, its
  premise decided at the row), the form of `MojoProof.Tile.bflyDeliver_holds` at the run's
  oracle; after it, an oracle and row at which the two forms differ.
* `poison16`: one block of 16 threads. The mask stays full, so the shuffles fire, but the first
  `bfly`'s offset 16 reads lanes outside the warp: every lane is delivered `poison` at it, offers
  `poison` at the four after it (`v16`), and the warp still runs (`warp78`), storing `poison` to
  the output's cell 0.
* `refused`: lane 0's checks on the `%43` branch at row 0 < `M`, on the `%44` branch at `M = 0`,
  with `%6`'s deliveries on a memory without its `alloca` blocks, and with four deliveries for
  `%78`'s five shuffles; `twins`: the last two with the right memory and count.

The kernel decides each lane's premises (`ok78`, `ok43`) and evaluates each lane's memories
(`mems78`, `mems43`), lane after lane, each from the lanes before it, in the one kernel check of
the declaration (`kernel_rfl_late`). `lane`, `lane43`, `warp78` and `warp43` are for every launch
whose start succeeds, every arm and round count; the runs are statements about this kernel at
these five launches, not about every launch or `K`.
-/

namespace MojoProofTest.GemvWarp

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.SymRun MojoProofTest.SymSeg MojoProofTest.SymGemvTail
  FloatLib.Floats.Formats.BinaryInterchange

-- `Array.any` recurses by well-founded recursion, so the kernel cannot evaluate a step without
-- this.
unseal Array.anyM.loop

/-- A launch of gemv_kernel: `G` blocks of `B` threads, the row count `M`, the column count `K`,
the binary32 words `a` of the matrix (row by row) and `b` of the vector, and the output's word
count `out`. -/
structure Cfg where
  /-- The launch from its blocks, threads of a block, row and column counts, matrix, vector and
  output size. -/
  mk ::
  /-- The blocks. -/
  G : Nat
  /-- The threads of a block. -/
  B : Nat
  /-- The row count. -/
  M : Nat
  /-- The column count. -/
  K : Nat
  /-- The matrix's words, row by row. -/
  a : List Nat
  /-- The vector's words. -/
  b : List Nat
  /-- The output's words (block 3 holds `4 · out` bytes). -/
  out : Nat

/-- The launch of `G` blocks of `B` threads with row count `M`, `K = 0`, the matrix and vector
`inA` and `inB` and an output of four words (`mem0`). -/
def x0 (G B M : Nat) : Cfg := ⟨G, B, M, 0, inA, inB, 4⟩

/-- The launch of `x.G` blocks of `x.B` threads in `x`. -/
def L (x : Cfg) : Launch := launch2 x.G 1 x.B 1

/-- The arguments: the output, matrix and vector at the starts of blocks 3, 1 and 2, the row count
`x.M`, `0` for `%4`, and the column count `x.K`, all `i32`. -/
def args (x : Cfg) : List Val :=
  [.ptr ⟨3, 0⟩, .ptr ⟨1, 0⟩, .ptr ⟨2, 0⟩, .bits 32 (.ofNat 32 x.M), .bits 32 0,
    .bits 32 (.ofNat 32 x.K)]

/-- The launch `x` of gemv_kernel on `memAB x.a x.b x.out`, with address choice and oracle 0. -/
def start (x : Cfg) : Except Fault (Grid × (Nat → Ctx)) :=
  Grid.start gemv.prog gemv.fn_0 (L x) (args x) (memAB x.a x.b x.out) (fun _ => 0)
    (fun _ _ => 0)

/-- The trip count `%53 = ⌈K / 32⌉` of `x`'s loop at `%54`. -/
def rounds (x : Cfg) : Nat := (x.K + 31) / 32

/-- Whether lane `j`'s rounds take the arm `%70` (`%65 = 32 i + j < K`, lines 89-95 of the IR):
in round 0 exactly when `j < K`. Every round of lane `j < 32` takes this arm when `K ≤ 32` or
`32 ∣ K`. -/
def arm (x : Cfg) (j : Nat) : Bool := decide (j < x.K)

/-- The grid and contexts of `start x`. -/
def run0 (x : Cfg) : Grid × (Nat → Ctx) :=
  match start x with
  | .ok r => r
  | .error _ => (⟨#[], {}⟩, fun _ => ctx0)

/-- The start's grid. -/
def g0 (x : Cfg) : Grid := (run0 x).1

/-- The start's contexts. -/
def c (x : Cfg) : Nat → Ctx := (run0 x).2

/-- A start that succeeds gives `g0 x` and `c x`. -/
theorem start_eq {x : Cfg} (h : (start x).toBool = true) : start x = .ok (g0 x, c x) := by
  unfold g0 c run0
  cases hs : start x with
  | error => rw [hs] at h; cases h
  | ok r => rfl

/-- The frame at statement 0 of `%6` with no register, product or `alloca` block. -/
def fr : Frame := ⟨gemv.fn_0, 6, 0, fun _ => none, fun _ => none, [], none⟩

/-- Thread `n`'s frame at the start (`fr` if it has none). -/
def f0 (x : Cfg) (n : Nat) : Frame := (Grid.thread (g0 x) n).frames.headD fr

/-- Thread `n`'s entry valuation at the start's frame, on memory `m`, at step count 0. -/
def V0 (x : Cfg) (n : Nat) (m : Mem) : Valuation := Valuation.entry (c x n) 0 m (f0 x n)

/-- **A thread of the start**: for every launch `x` whose start succeeds and thread `n` of it, the
thread is its one frame `f0 x n` at step count 0, of gemv_kernel at statement 0 of `%6`, with no
`alloca` block, and its context runs gemv's program (`Grid.start_thread`, `Grid.start_ctx`). -/
theorem start_frame {x : Cfg} {n : Nat} (hs : (start x).toBool = true)
    (hn : n < (g0 x).threads.size) :
    Grid.thread (g0 x) n = ⟨[f0 x n], 0⟩ ∧ (f0 x n).fn = gemv.fn_0 ∧ (f0 x n).label = 6 ∧
      (f0 x n).pc = 0 ∧ (f0 x n).allocas = [] ∧ (c x n).prog = gemv.prog := by
  obtain ⟨f, ht, hfn, hl, hp, ha⟩ := Grid.start_thread (start_eq hs) hn
  have hf : f0 x n = f := by unfold f0; rw [ht]; rfl
  subst hf
  exact ⟨ht, hfn, Option.some.inj (hl.symm.trans (by decide +kernel)), hp, ha,
    (Grid.start_ctx (start_eq hs) n).1⟩

/-- The chain checker without the `alloca` flag accepts the loop at `%54` through `%70` and
through `%75` with its path out cut after `%59`'s edge into `%78` (`coversChainAt false true` of
`lp true` and `lp false`), and the path checker with both flags the path from `%78`'s statement
19 to `ret` through `%101` (the lanes other than 0; locals 102, 103 and 45). Lane 0's path through
`%100`'s `store` is `bflyOut` (`bfly_covers`). -/
theorem tail_covers78 :
    coversChainAt false true gemv.prog gemv.fn_0 41 6 (gC 6 41).obls (gC 6 41) [gB 44 0]
      [lp true] = true ∧
    coversChainAt false true gemv.prog gemv.fn_0 41 6 (gC 6 41).obls (gC 6 41) [gB 44 0]
      [lp false] = true ∧
    coversPathAt true true gemv.prog gemv.fn_0 19 (gB 65 19 :: [gB 102 0, gB 103 0, gB 45 0]) =
      true := by
  decide +kernel

/-- The path after `%78`'s statement 19 of lane `j`: through `%100`'s `store` for lane 0,
through `%101` for the others. -/
def out (j : Nat) : List (Nat × List Cond × Summary) :=
  if j = 0 then [gB 101 0, gB 103 0, gB 45 0] else [gB 102 0, gB 103 0, gB 45 0]

/-- The path checker accepts `gB 65 19 :: out j` from statement 19, for every lane `j`. -/
theorem out_covers (j : Nat) :
    coversPathAt true true gemv.prog gemv.fn_0 19 (gB 65 19 :: out j) = true := by
  unfold out
  split
  · exact bfly_covers.2
  · exact tail_covers78.2.2

/-- The chain from statement 41 of `%6` into `%78` at position 1 and `%78`'s segments with the
deliveries `ds`, as a Boolean at valuation `V`, with `n` rounds of the loop `lp a` (through `%70`
if `a`, else `%75`): the edge from `%6` through `%44` into the loop's header at position 2, the
premises of rounds 0 to `n - 1` at the header's iterates (`RoundWith`), the edge of the path out
`%59` into `%78` from the `n`-th, and there (`at78 a n V`) `Piece.fires` of `bP` with the return
along `gB 65 19 :: ps` (`retB true`). -/
def chainP (a : Bool) (n : Nat) (ps : List (Nat × List Cond × Summary))
    (ds : List (Option Val × Mem)) (V : Valuation) : Bool :=
  decide (EdgeWith true (lp a).h (lp a).p V 6 (gC 6 41).obls (gC 6 41) [gB 44 0] ∧
    (∀ i < n, RoundWith true (lp a).h (lp a).p (lp a).dh (lp a).H (lp a).B (hd a i V)) ∧
    EdgeWith true 65 1 (hd a n V) (lp a).h (lp a).dh (lp a).H (lp a).X ∧
    Piece.fires gemv.fn_0 65 (retB true (gB 65 19 :: ps)) bP.1 1 ds (at78 a n V) = true)

/-- `%78`'s waits with the deliveries `ds`, from the valuation `V` at statement 41 of `%6` and `n`
rounds of `lp a`. -/
def w78 (a : Bool) (n : Nat) (ds : List (Option Val × Mem)) (V : Valuation) : List Piece.Wait :=
  Piece.waits gemv.fn_0 65 bP.1 1 ds (at78 a n V)

/-- The memory at the end of the path `gB 65 19 :: ps` after `%78`'s segments with the deliveries
`ds`, from valuation `V` at statement 41 of `%6` with `alloca` blocks `A` and `n` rounds of `lp a`
(`Valuation.retMem`). -/
def endM (a : Bool) (n : Nat) (ps : List (Nat × List Cond × Summary))
    (ds : List (Option Val × Mem)) (V : Valuation) (A : List Nat) : Mem :=
  (Piece.after gemv.fn_0 65 bP.1 1 ds (at78 a n V)).retMem true
    (Piece.allocs gemv.fn_0 65 bP.1 1 ds (at78 a n V) ++ A) (gB 65 19 :: ps)

/-- **gemv_kernel from statement 41 of `%6` through `n` rounds of the loop at `%54` and `%78`'s
five shuffles to `ret`, by the checkers**: for every context of gemv's program, arm `a`, round
count `n`, path `ps` after `%78`'s statement 19 that the path checker accepts, deliveries `ds`,
and thread whose one frame `f` is at statement 41 of `%6` with `chainP a n ps ds` at its entry
valuation `V`, the thread runs through `%78`'s waits (`w78 a n ds V`) to its end at
`endM a n ps ds V f.allocas`. The chain is `ChainWith.of_rounds` of `lp a` at `n` rounds and stops
after `%59`'s edge (`RunsVia.of_chain` without the `alloca` flag, `tail_covers78`, so the frame
keeps `f`'s `alloca` blocks), the segments run by `Piece.throughTo` and the path by
`Runs.of_retMem`, joined by `RunsVia.of_fires`. -/
theorem tail78 {c : Ctx} (hP : c.prog = gemv.prog) {a : Bool} {n : Nat}
    {ps : List (Nat × List Cond × Summary)}
    (hc : coversPathAt true true gemv.prog gemv.fn_0 19 (gB 65 19 :: ps) = true)
    {ds : List (Option Val × Mem)} {t : Thread} {m : Mem} {f : Frame} (ht : t.frames = [f])
    (hfn : f.fn = gemv.fn_0) (hl : f.label = 6) (hp : f.pc = 41)
    (h : chainP a n ps ds (Valuation.entry c t.k m f) = true) :
    RunsVia c (· = endM a n ps ds (Valuation.entry c t.k m f) f.allocas)
      ((w78 a n ds (Valuation.entry c t.k m f)).map (Piece.Wait.via gemv.fn_0 65)) t m := by
  simp only [chainP, decide_eq_true_eq] at h
  refine RunsVia.of_chain (alloca := false) (d := 65) (q := 1)
    (J := fun V => V = at78 a n (Valuation.entry c t.k m f) ∧
      Piece.fires gemv.fn_0 65 (retB true (gB 65 19 :: ps)) bP.1 1 ds V = true)
    hP (by cases a; exacts [tail_covers78.2.1, tail_covers78.1]) ht hfn hl hp
    (ChainWith.of_rounds (L := lp a) (by cases a <;> rfl) n ⟨h.1, h.2.1⟩
      (ChainWith.last ⟨h.2.2.1, rfl, h.2.2.2⟩)) fun t' m' f' ht' hfn' hl' hp' ⟨_, hal⟩ ⟨hV, hF⟩ =>
    ?_
  have hT := Piece.throughTo (alloca := true) (ps := bflyStops) (p0 := 1) (Ss := bP.1) (L := bP.2)
    hP bP_eq
    (K := fun t m f => retB true (gB 65 19 :: ps) (Valuation.entry c t.k m f) = true →
      Runs c t m ((Valuation.entry c t.k m f).retMem true f.allocas (gB 65 19 :: ps)))
    (fun _ _ _ ht hfn hl hp hR => Runs.of_retMem hP hc ht hfn hl (hp.trans rfl) hR)
    (fun i => ds.getD i (none, m)) (m := m') ht' hfn' hl' hp'
  have h2 := RunsVia.of_fires (Q := fun V A => (· = V.retMem true A (gB 65 19 :: ps)))
    (G := fun _ => []) (F := retB true (gB 65 19 :: ps)) (fun _ _ _ hK hF => ⟨_, hK hF, rfl⟩) hT
    hfn' hp' hF
  simp only [hV, hal, Bool.cond_false, List.nil_append, List.append_nil] at h2
  exact h2

/-- **A lane whose warp's row is below `M`, from the start to `ret` through seven shuffles** (the
row `%36`, lane 0's, which `%6`'s shuffles deliver, not the lane's own `%20`): for every launch `x`
whose start succeeds, thread `n` of it, arm `a`, round count `R`, path `ps` after `%78`'s
statement 19 that the path checker accepts, deliveries `d6` of `%6`'s two shuffles and `d78` of
`%78`'s five, and memory `m` at which `%6`'s segments pass with `chainP a R ps d78` at their end
(`Piece.fires`), the thread runs from the start on `m` through `%6`'s waits and then `%78`'s
(`RunsVia`, each `Piece.Wait.via`) to its end at `endM` of the valuation and `alloca` blocks
after `%6`'s segments: `Piece.throughTo` to statement 41, `tail78` through `R` rounds of the loop
`lp a`, joined by `RunsVia.of_fires`. -/
theorem lane {x : Cfg} {n : Nat} (hs : (start x).toBool = true) (hn : n < (g0 x).threads.size)
    {a : Bool} {R : Nat} {ps : List (Nat × List Cond × Summary)}
    (hc : coversPathAt true true gemv.prog gemv.fn_0 19 (gB 65 19 :: ps) = true)
    {d6 d78 : List (Option Val × Mem)} {m : Mem}
    (hF : Piece.fires gemv.fn_0 6 (chainP a R ps d78) gP.1 0 d6 (V0 x n m) = true) :
    RunsVia (c x n) (· = endM a R ps d78 (Piece.after gemv.fn_0 6 gP.1 0 d6 (V0 x n m))
        (Piece.allocs gemv.fn_0 6 gP.1 0 d6 (V0 x n m)))
      ((Piece.waits gemv.fn_0 6 gP.1 0 d6 (V0 x n m)).map (Piece.Wait.via gemv.fn_0 6) ++
        (w78 a R d78 (Piece.after gemv.fn_0 6 gP.1 0 d6 (V0 x n m))).map
          (Piece.Wait.via gemv.fn_0 65))
      (Grid.thread (g0 x) n) m := by
  obtain ⟨ht, hfn, hl, hp, ha, hP⟩ := start_frame hs hn
  rw [ht]
  have hT := Piece.throughTo (alloca := true) (ps := gemvStops) (p0 := 0) (Ss := gP.1) (L := gP.2)
    hP gP_eq
    (K := fun t m f => chainP a R ps d78 (Valuation.entry (c x n) t.k m f) = true →
      RunsVia (c x n) (· = endM a R ps d78 (Valuation.entry (c x n) t.k m f) f.allocas)
        ((w78 a R d78 (Valuation.entry (c x n) t.k m f)).map (Piece.Wait.via gemv.fn_0 65)) t m)
    (fun _ _ _ ht hfn hl hp hC => tail78 hP hc ht hfn hl (hp.trans rfl) hC)
    (fun i => d6.getD i (none, m)) (t := ⟨[f0 x n], 0⟩) (m := m) rfl hfn hl hp
  have h := RunsVia.of_fires (Q := fun V A => (· = endM a R ps d78 V A))
    (G := fun V => (w78 a R d78 V).map (Piece.Wait.via gemv.fn_0 65)) (F := chainP a R ps d78)
    (fun _ _ _ hK hF => hK hF) hT hfn hp hF
  rw [ha, List.append_nil] at h
  exact h

/-- **A lane whose warp's row is at least `M`, from the start to `ret` through `%6`'s two
shuffles** (lane 0's row `%36`, as in `lane`): for every launch whose start succeeds, thread `n`
of it, deliveries `d6` and memory `m` at which `%6`'s segments pass with the return along
`tailPs` (`%43`, `%103`) at their end, the thread runs from the start on `m` through `%6`'s waits
to its end at `Valuation.retMem` of `tailPs` (`Piece.throughTo`, `Runs.of_retMem`,
`RunsVia.of_fires`). -/
theorem lane43 {x : Cfg} {n : Nat} (hs : (start x).toBool = true)
    (hn : n < (g0 x).threads.size) {d6 : List (Option Val × Mem)} {m : Mem}
    (hF : Piece.fires gemv.fn_0 6 (retB false tailPs) gP.1 0 d6 (V0 x n m) = true) :
    RunsVia (c x n) (· = (Piece.after gemv.fn_0 6 gP.1 0 d6 (V0 x n m)).retMem false
        (Piece.allocs gemv.fn_0 6 gP.1 0 d6 (V0 x n m)) tailPs)
      ((Piece.waits gemv.fn_0 6 gP.1 0 d6 (V0 x n m)).map (Piece.Wait.via gemv.fn_0 6))
      (Grid.thread (g0 x) n) m := by
  obtain ⟨ht, hfn, hl, hp, ha, hP⟩ := start_frame hs hn
  rw [ht]
  have hT := Piece.throughTo (alloca := true) (ps := gemvStops) (p0 := 0) (Ss := gP.1) (L := gP.2)
    hP gP_eq
    (K := fun t m f => retB false tailPs (Valuation.entry (c x n) t.k m f) = true →
      Runs (c x n) t m ((Valuation.entry (c x n) t.k m f).retMem false f.allocas tailPs))
    (fun _ _ _ ht hfn hl hp hR => Runs.of_retMem hP tail_covers.1 ht hfn hl (hp.trans rfl) hR)
    (fun i => d6.getD i (none, m)) (t := ⟨[f0 x n], 0⟩) (m := m) rfl hfn hl hp
  have h := RunsVia.of_fires (Q := fun V A => (· = V.retMem false A tailPs)) (G := fun _ => [])
    (F := retB false tailPs) (fun _ _ _ hK hF => ⟨_, hK hF, rfl⟩) hT hfn hp hF
  rw [ha, List.append_nil, List.append_nil] at h
  exact h

/-! ## A warp's phases -/

/-- A warp of a launch of gemv_kernel: the launch `x`, its first thread `k`, the value `v i j` its
lane `j` offers at its `i`-th shuffle, and the memory `ms` it starts on. -/
structure Warp where
  /-- The warp from its launch, first thread, offered values and starting memory. -/
  mk ::
  /-- The launch. -/
  x : Cfg
  /-- The warp's first thread. -/
  k : Nat
  /-- The value lane `j` offers at its `i`-th shuffle (`v i j`). -/
  v : Nat → Nat → Val
  /-- The memory the warp starts on. -/
  ms : Mem

/-- The number of the warp's lanes. -/
def Warp.N (w : Warp) : Nat := (warpLanes (L w.x) w.k).length

/-- The mode of the `i`-th shuffle: `idx` for `%6`'s two, `bfly` for `%78`'s five. -/
def mode (i : Nat) : Shfl := if i < 2 then .idx else .bfly

/-- The lane operand of the `i`-th shuffle: 0 for `%6`'s, 16, 8, 4, 2 and 1 for `%78`'s. -/
def ofs (i : Nat) : Nat := [0, 0, 16, 8, 4, 2, 1].getD i 0

/-- The position of the `i`-th shuffle in its block: 17 and 18 in `%6`, 2, 6, 10, 14 and 18 in
`%78`. -/
def pos (i : Nat) : Nat := [17, 18, 2, 6, 10, 14, 18].getD i 0

/-- What `Grid.fire` delivers to lane `j` at the `i`-th shuffle (`shflVal`, `shflSource` with
clamp 31): the offer `w.v i s` of the source lane `s = shflSource (mode i) j (ofs i) 31`,
`poison` if `s` is not one of the warp's lanes. -/
def r (w : Warp) (i j : Nat) : Option Val :=
  some (shflVal (warpLanes (L w.x) w.k) (w.v i) (shflSource (mode i) j (ofs i) 31))

/-- Lane `j`'s memory after `%6`'s first segment (its three `alloca`s) from memory `m`. -/
def mW (w : Warp) (j : Nat) (m : Mem) : Mem :=
  match gP.1 with
  | .coll S :: _ =>
    let V := V0 w.x (w.k + j) m
    (SEff.run V (vals V S.nodes) S.effs).toOption.getD m
  | _ => m

/-- The memory after `j` lanes' first segments: `w.ms`, then each lane's `mW` in turn. -/
def m0 (w : Warp) : Nat → Mem
  | 0 => w.ms
  | j + 1 => mW w j (m0 w j)

/-- The memory after every lane's first segment, at which `%6`'s first shuffle fires. -/
def A (w : Warp) : Mem := m0 w w.N

/-- Lane `j`'s deliveries at `%6`'s shuffles: `r w 0 j` on `A w`, `r w 1 j` on `m`. -/
def d6 (w : Warp) (j : Nat) (m : Mem) : List (Option Val × Mem) := [(r w 0 j, A w), (r w 1 j, m)]

/-- Lane `j`'s valuation and `alloca` blocks after `%6`'s segments, delivered `d6 w j m`. -/
def V6 (w : Warp) (j : Nat) (m : Mem) : Valuation :=
  Piece.after gemv.fn_0 6 gP.1 0 (d6 w j m) (V0 w.x (w.k + j) (m0 w j))

/-- Lane `j`'s `alloca` blocks after `%6`'s segments, delivered `d6 w j m`. -/
def A6 (w : Warp) (j : Nat) (m : Mem) : List Nat :=
  Piece.allocs gemv.fn_0 6 gP.1 0 (d6 w j m) (V0 w.x (w.k + j) (m0 w j))

/-- Lane `j`'s waits in `%6`, delivered `d6 w j m`. -/
def ws6 (w : Warp) (j : Nat) (m : Mem) : List Piece.Wait :=
  Piece.waits gemv.fn_0 6 gP.1 0 (d6 w j m) (V0 w.x (w.k + j) (m0 w j))

/-- Lane `j`'s deliveries at `%78`'s shuffles: `r w (i + 2) j`, the first four on `b`, the last on
`m`. -/
def d78 (w : Warp) (j : Nat) (b m : Mem) : List (Option Val × Mem) :=
  [(r w 2 j, b), (r w 3 j, b), (r w 4 j, b), (r w 5 j, b), (r w 6 j, m)]

/-- A wait at position 0 of a barrier on the empty memory, the default of a list of waits. -/
def w0 : Piece.Wait := ⟨0, .barrier, [], {}, (none, {})⟩

/-- The memory after `j` lanes' runs from `%6`'s second shuffle to `%78`'s first: `A w`, then each
lane's memory at its first `%78` wait, with `%78`'s deliveries on the memory before it (the
memory at a wait does not depend on later deliveries). -/
def m2 (w : Warp) : Nat → Mem
  | 0 => A w
  | j + 1 =>
    ((w78 (arm w.x j) (rounds w.x) (d78 w j (m2 w j) (m2 w j)) (V6 w j (m2 w j))).headD w0).mem

/-- The memory at which `%78`'s shuffles fire. -/
def Bm (w : Warp) : Mem := m2 w w.N

/-- The memory after `j` lanes' runs from `%78`'s last shuffle to `ret`. -/
def m7 (w : Warp) : Nat → Mem
  | 0 => Bm w
  | j + 1 => endM (arm w.x j) (rounds w.x) (out j) (d78 w j (Bm w) (m7 w j)) (V6 w j (m2 w j))
    (A6 w j (m2 w j))

/-- Lane `j`'s seven waits: `%6`'s two, then `%78`'s five. -/
def ws (w : Warp) (j : Nat) : List Piece.Wait :=
  ws6 w j (m2 w j) ++ w78 (arm w.x j) (rounds w.x) (d78 w j (Bm w) (m7 w j)) (V6 w j (m2 w j))

/-- The memory after `j` lanes of phase `i` of a warp through seven shuffles: `m0`, `A`, `m2`,
`Bm` for phases 3 to 6, `m7`. -/
def M (w : Warp) : Nat → Nat → Mem
  | 0, j => m0 w j
  | 1, _ => A w
  | 2, j => m2 w j
  | 7, j => m7 w j
  | _, _ => Bm w

/-- The memory after `j` lanes' runs from `%6`'s second shuffle through `%43` to `ret`. -/
def mE (w : Warp) : Nat → Mem
  | 0 => A w
  | j + 1 => (V6 w j (mE w j)).retMem false (A6 w j (mE w j)) tailPs

/-- The memory after `j` lanes of phase `i` of a warp through two shuffles: `m0`, `A`, `mE`. -/
def M43 (w : Warp) : Nat → Nat → Mem
  | 0, j => m0 w j
  | 1, _ => A w
  | _, j => mE w j

/-- **Lane `j`'s premises through seven shuffles, as a Boolean**: thread `k + j` is one of the
start's; `%6`'s segments pass with `chainP (arm w.x j) (rounds w.x) (out j)` at their end
(`Piece.fires`): the loop's `⌈K / 32⌉` rounds through lane `j`'s arm; two waits in `%6` and
seven in all, which pass `Piece.Wait.shflOk` (at `pos i`, the shuffle of mode `mode i` with the
full mask, lane `j`'s offer `w.v i j`, lane operand `ofs i` and clamp 31, delivered what
`Grid.fire` delivers). -/
def ok78 (w : Warp) (j : Nat) : Bool :=
  decide (w.k + j < (g0 w.x).threads.size) &&
    Piece.fires gemv.fn_0 6 (chainP (arm w.x j) (rounds w.x) (out j) (d78 w j (Bm w) (m7 w j)))
      gP.1 0 (d6 w j (m2 w j)) (V0 w.x (w.k + j) (m0 w j)) &&
    (ws6 w j (m2 w j)).length == 2 && (ws w j).length == 7 &&
    Piece.Wait.shflOk (warpLanes (L w.x) w.k) mode pos (fun i => .ofNat 32 (ofs i)) (fun _ => 31)
      w.v w0 7 j (ws w j)

/-- **Lane `j`'s premises through two shuffles, as a Boolean**: thread `k + j` is one of the
start's; `%6`'s segments pass with the return along `tailPs` at their end (`Piece.fires`); two
waits, which pass `Piece.Wait.shflOk` (as in `ok78`). -/
def ok43 (w : Warp) (j : Nat) : Bool :=
  decide (w.k + j < (g0 w.x).threads.size) &&
    Piece.fires gemv.fn_0 6 (retB false tailPs) gP.1 0 (d6 w j (mE w j))
      (V0 w.x (w.k + j) (m0 w j)) &&
    (ws6 w j (mE w j)).length == 2 &&
    Piece.Wait.shflOk (warpLanes (L w.x) w.k) mode pos (fun i => .ofNat 32 (ofs i)) (fun _ => 31)
      w.v w0 2 j (ws6 w j (mE w j))

/-- The memories and delivered memories of the waits `us`. -/
def memsOf (us : List Piece.Wait) : List (Mem × Mem) := us.map fun u => (u.mem, u.dlv.2)

/-- What `WarpRun.of_waits` asks of lane `j`'s seven waits' `memsOf`: phase `i`'s memory after
lane `j` and phase `i + 1`'s before it (`M`). -/
def mems78 (w : Warp) (j : Nat) : List (Mem × Mem) :=
  [(m0 w (j + 1), A w), (A w, m2 w j), (m2 w (j + 1), Bm w), (Bm w, Bm w), (Bm w, Bm w),
    (Bm w, Bm w), (Bm w, m7 w j)]

/-- What `WarpRun.of_waits` asks of lane `j`'s two waits' `memsOf` (`M43`). -/
def mems43 (w : Warp) (j : Nat) : List (Mem × Mem) := [(m0 w (j + 1), A w), (A w, mE w j)]

/-- **Gemv's shuffles put no attribute on their results**: every declaration of gemv's program
whose name its intrinsic table maps to a shuffle has no result attribute (`Program.shflNil`,
decided by the kernel). -/
theorem gemv_nil : gemv.prog.shflNil = true := by decide +kernel

/-- **`WarpRun.of_waits`'s memory premise from one list equation**: for every list of waits `us`
whose memories and delivered memories are `ms`, the `i`-th wait's are `ms`'s `i`-th pair. -/
theorem mems_of {us : List Piece.Wait} {ms : List (Mem × Mem)} (h : memsOf us = ms) (i : Nat) :
    (us.getD i w0).mem = (ms.getD i (w0.mem, w0.dlv.2)).1 ∧
      (us.getD i w0).dlv.2 = (ms.getD i (w0.mem, w0.dlv.2)).2 := by
  subst h
  simp only [memsOf, List.getD_map, and_self]

/-- **A warp whose row (its lane 0's) is below `M`, through seven shuffles**: for every warp `w` of
a launch whose start succeeds, with `N` lanes, each with `ok78` and with its waits' memories
`mems78`, the warp runs from `w.ms` to `m7 w N` (`WarpRun`): `WarpRun.of_waits` with seven phases,
`%6`'s two `shfl.sync.idx` and `%78`'s five `shfl.sync.bfly`, by `warp_route`: each lane's run by
`lane` (through `RunsVia.of_blocks`, `start_frame` and `out_covers` for its premises), the
shuffles by `WarpRun.shfl_of` and `gemv_nil`, the waits' memories by `mems_of`. The deliveries
are `Grid.fire`'s (`WarpShfl`) from the lanes' offers `w.v`. Lane `j` runs
`rounds w.x = (K + 31) / 32` rounds of the loop at `%54`, every one through the one arm
`arm w.x j` fixes (`%70` for the lanes `j < K`, `%75` for the others), the chain `chainP` checks
with the loop `lp` of that arm. The kernel's lane `j` takes `%70` at round `i` exactly when
`%65 = 32 i + j < K` (`%69`, lines 89-95 of the IR), so its rounds take one arm, the one `arm`
gives, at every launch with `K ≤ 32` or `32 ∣ K`; at a launch with `K > 32` and `32 ∤ K` the lanes
`j ≥ K % 32` take `%70` and then `%75` at their last round, their `ok78` fails, and the theorem
states no run of their warp. -/
theorem warp78 {w : Warp} {N : Nat} (hs : (start w.x).toBool = true) (hN : w.N = N)
    (hc : ∀ j < N, ok78 w j = true) (hm : ∀ j < N, memsOf (ws w j) = mems78 w j) :
    ∃ Es, WarpRun (L w.x) (c w.x) w.k (Grid.thread (g0 w.x)) w.ms Es (m7 w w.N) := by
  warp_route (J := 7) (fn := gemv.fn_0) (lbl := fun i => if i < 2 then 6 else 65)
    (W := fun i j => (ws w j).getD i w0) (mo := mode) (X := w.v) (M := M w)
    using lane, start_frame, out_covers, mems_of, gemv_nil

/-- **A warp whose row (its lane 0's) is at least `M`, through two shuffles**: for every warp `w`
of a launch whose start succeeds, with `N` lanes, each with `ok43` and with its waits' memories
`mems43`, the warp runs from `w.ms` to `mE w N` (`WarpRun`): `WarpRun.of_waits` with `%6`'s two
`shfl.sync.idx` as its phases, by `warp_route` as in `warp78`, each lane's run by `lane43`
(through `RunsVia.of_block`). The deliveries are `Grid.fire`'s (`WarpShfl`) from the lanes'
offers `w.v`. -/
theorem warp43 {w : Warp} {N : Nat} (hs : (start w.x).toBool = true) (hN : w.N = N)
    (hc : ∀ j < N, ok43 w j = true) (hm : ∀ j < N, memsOf (ws6 w j (mE w j)) = mems43 w j) :
    ∃ Es, WarpRun (L w.x) (c w.x) w.k (Grid.thread (g0 w.x)) w.ms Es (mE w w.N) := by
  warp_route (J := 2) (fn := gemv.fn_0) (lbl := fun _ => 6)
    (W := fun i j => (ws6 w j (mE w j)).getD i w0) (mo := mode) (X := w.v) (M := M43 w)
    using lane43, start_frame, mems_of, gemv_nil

/-- **A launch of one warp from the start to a done grid**: for every warp `w` from thread 0 on the
start's memory of a launch `x` whose start succeeds, whose blocks have threads and whose one warp
starts at thread 0 (`warps`), if its `N` lanes pass the kernel's checks (`ok78`, `mems78`), the
start steps (`Grid.Step`) to a done grid whose memory is the warp's end memory `m7 w w.N`:
`warp78`, then `CanonRun.start_done` of the one warp. -/
theorem one78 {w : Warp} {N : Nat} (hs : (start w.x).toBool = true) (hk : w.k = 0)
    (hm : w.ms = (g0 w.x).mem) (hB : 0 < volume (L w.x).block)
    (hW : warps (L w.x) (g0 w.x).threads.size = [0]) (hN : w.N = N)
    (hc : ∀ j < N, ok78 w j = true) (hm' : ∀ j < N, memsOf (ws w j) = mems78 w j) :
    ∃ z, (∃ i, GPUProof.Path (Grid.Step (L w.x) (c w.x)) i (g0 w.x) z) ∧
      GPUProof.Done sig (z, L w.x, c w.x) ∧ z.mem = m7 w w.N := by
  obtain ⟨Es, h⟩ := warp78 hs hN hc hm'
  rw [hk, hm] at h
  have hc : CanonRun (L w.x) (c w.x) (Grid.thread (g0 w.x)) (warps (L w.x) (g0 w.x).threads.size)
      (g0 w.x).mem (Es ++ []) (m7 w w.N) := by
    rw [hW]
    exact .cons h (.nil _)
  exact CanonRun.start_done (start_eq hs) hB hc

/-! ## Instances -/

/-- The four bytes of `f32` cell `i` of block `b` of memory `m`, if `m` has the block. -/
def cell (m : Mem) (b i : Nat) : Option (List MemByte) :=
  (m.blocks b).map fun B => (List.range 4).map fun o => B.bytes (4 * i + o)

/-- The bytes of `0.0 : f32`. -/
def zero : List MemByte := [.byte 0, .byte 0, .byte 0, .byte 0]

/-- Row `i`'s factor pairs at launch `x`: `(a[i K + c], b[c])` for the columns `c < K`, as
binary32 words. -/
def pairs (x : Cfg) (i : Nat) : List (Model .binary32 × Model .binary32) :=
  (List.range x.K).map fun c => (Model.ofNatBits (x.a.getD (i * x.K + c) 0),
    Model.ofNatBits (x.b.getD c 0))

/-- What lane `j` of warp `k` offers at its `i`-th shuffle, for its row's pairs `ps`: the low and
high halves of its own row `(k + j) / 32` at `%6`'s shuffles (the high half `0`), and at `%78`'s
`i - 2`-th its value after `i - 2` butterfly rounds of `Model.add` at `warpOffsets`, from lane
`l`'s loop `dotLoop` over `stride 32 l ps` under the oracle numbers `(0, 0)` (as `i32` bits). -/
def offer (ps : List (Model .binary32 × Model .binary32)) (k i j : Nat) : Val :=
  if i = 0 then .bits 32 (.ofNat 32 ((k + j) / 32)) else if i = 1 then .bits 32 0 else
    .ofFloat .float (bflyRounds (fun x y => Model.add x y) (warpOffsets.take (i - 2))
      (fun l => dotLoop true (fun _ => (0, 0)) (Model.zero _ false) (stride 32 l ps)) j)

/-- One block of 32 threads, row count 1, `K = 0`. -/
def x32 : Cfg := x0 1 32 1

/-- The one warp of `x32`, from the start's memory. -/
def w32 : Warp := ⟨x32, 0, offer [] 0, (g0 x32).mem⟩

/-- **One block of 32 threads, from the start to a done grid**: at `x32` (`M = 1`, `K = 0`) the
start steps (`Grid.Step`) to a done grid whose output cell 0 holds `0.0`. Warp 0 by `warp78`
(the kernel decides each lane's premises, `ok78`, and evaluates its memories, `mems78`), the run of
the one warp by `CanonRun.start_done`. The loop at `%54` is at 0 rounds (`%11 = 0`). -/
theorem run32 : ∃ z, (∃ i, GPUProof.Path (Grid.Step (L x32) (c x32)) i (g0 x32) z) ∧
    GPUProof.Done sig (z, L x32, c x32) ∧ cell z.mem 3 0 = some zero := by
  obtain ⟨z, hp, hd, hm⟩ := one78 (w := w32) (N := 32) (by decide +kernel) rfl rfl
    (by decide +kernel) (by decide +kernel) (by decide +kernel)
    (of_decide_eq_true (by kernel_rfl_late)) fun j hj => by interval_cases j <;> kernel_rfl_late
  refine ⟨z, hp, hd, ?_⟩
  rw [hm]
  exact of_decide_eq_true (by kernel_rfl_late)

/-- One block of 64 threads, row count 1, `K = 0`. -/
def x64 : Cfg := x0 1 64 1

/-- `x64`'s warp 0, from the start's memory. -/
def wa : Warp := ⟨x64, 0, offer [] 0, (g0 x64).mem⟩

/-- `x64`'s warp 32, after warp 0. -/
def wb : Warp := ⟨x64, 32, offer [] 32, m7 wa wa.N⟩

/-- **One block of 64 threads, from the start to a done grid**: at `x64` (`M = 1`, `K = 0`) the
start steps to a done grid whose output cell 0 holds `0.0`. Warp 0 (row 0) runs through seven
shuffles (`warp78`), warp 32 (row 1, threads 32 to 63 of the block, lanes 0 to 31) through
`%6`'s two and `%43` (`warp43`); the two in turn are the canonical run
(`CanonRun.start_done`). The loop at `%54` is at 0 rounds (`%11 = 0`). -/
theorem run64 : ∃ z, (∃ i, GPUProof.Path (Grid.Step (L x64) (c x64)) i (g0 x64) z) ∧
    GPUProof.Done sig (z, L x64, c x64) ∧ cell z.mem 3 0 = some zero := by
  have hs : (start x64).toBool = true := by decide +kernel
  obtain ⟨E1, h1⟩ := warp78 (w := wa) (N := 32) hs (by decide +kernel)
    (of_decide_eq_true (by kernel_rfl_late)) fun j hj => by interval_cases j <;> kernel_rfl_late
  obtain ⟨E2, h2⟩ := warp43 (w := wb) (N := 32) hs (by decide +kernel)
    (of_decide_eq_true (by kernel_rfl_late)) fun j hj => by interval_cases j <;> kernel_rfl_late
  have hc : CanonRun (L x64) (c x64) (Grid.thread (g0 x64)) (warps (L x64) (g0 x64).threads.size)
      (g0 x64).mem (E1 ++ (E2 ++ [])) (mE wb wb.N) := by
    rw [show warps (L x64) (g0 x64).threads.size = [0, 32] by decide +kernel]
    exact .cons h1 (.cons h2 (.nil _))
  obtain ⟨z, hp, hd, hm⟩ := CanonRun.start_done (start_eq hs) (by decide +kernel) hc
  refine ⟨z, hp, hd, ?_⟩
  rw [hm]
  exact of_decide_eq_true (by kernel_rfl_late)

/-- The matrix row `[2 ^ 24, 1, -2 ^ 24, 1]` (binary32 words), at which the butterfly's order
and the left-to-right order give different sums. -/
def a4 : List Nat := [0x4b800000, 0x3f800000, 0xcb800000, 0x3f800000]

/-- One block of 32 threads, row count 1, `K = 4`: the matrix `a4` and the vector of four ones. -/
def x4 : Cfg := ⟨1, 32, 1, 4, a4, List.replicate 4 0x3f800000, 4⟩

/-- The one warp of `x4`, from the start's memory. -/
def w4 : Warp := ⟨x4, 0, offer (pairs x4 0) 0, (g0 x4).mem⟩

/-- The four little-endian bytes of a binary32 word. -/
def word (y : Model .binary32) : List MemByte := leBytes 4 y.toBits.toNat

/-- **One block of 32 threads at `K = 4`, from the start to a done grid**: at `x4` (`M = 1`) the
start steps to a done grid whose output cell 0 holds the word of `warpDot` of row 0's pairs
(`2`, `orders`), not that of the left-to-right loop `dotLoop` (`1`). Warp 0 by `warp78` and `one78`:
lanes 0 to 3 run one round of the loop through `%70`, lanes 4 to 31 one round through `%75`
(`arm`, `rounds`), and the five shuffles add the lanes' sums. -/
theorem run4 : ∃ z, (∃ i, GPUProof.Path (Grid.Step (L x4) (c x4)) i (g0 x4) z) ∧
    GPUProof.Done sig (z, L x4, c x4) ∧
    cell z.mem 3 0 = some (word (warpDot true (fun _ _ => (0, 0)) (pairs x4 0))) ∧
    cell z.mem 3 0 ≠ some (word (dotLoop true (fun _ => (0, 0)) (Model.zero _ false) (pairs x4 0)))
    := by
  obtain ⟨z, hp, hd, hm⟩ := one78 (w := w4) (N := 32) (by decide +kernel) rfl rfl
    (by decide +kernel) (by decide +kernel) (by decide +kernel)
    (of_decide_eq_true (by kernel_rfl_late)) fun j hj => by interval_cases j <;> kernel_rfl_late
  refine ⟨z, hp, hd, ?_⟩
  rw [hm]
  exact of_decide_eq_true (by kernel_rfl_late)

/-- `x4` at `K = 3`: the row `[2 ^ 24, 1, -2 ^ 24]` (`a4`'s first three words) and three ones. -/
def x3 : Cfg := { x4 with K := 3 }

/-- The one warp of `x3`, from the start's memory. -/
def w3 : Warp := ⟨x3, 0, offer (pairs x3 0) 0, (g0 x3).mem⟩

/-- **One block of 32 threads at `K = 3`, from the start to a done grid**: at `x3` (`M = 1`) the
start steps to a done grid whose output cell 0 holds the word of `warpDot` of row 0's pairs
(`1`, `orders`), not that of `dotLoop` (`0`). Lanes 0 to 2 run one round through `%70`, lanes 3 to
31 one through `%75`; warp 0 by `warp78` and `one78`. -/
theorem run3 : ∃ z, (∃ i, GPUProof.Path (Grid.Step (L x3) (c x3)) i (g0 x3) z) ∧
    GPUProof.Done sig (z, L x3, c x3) ∧
    cell z.mem 3 0 = some (word (warpDot true (fun _ _ => (0, 0)) (pairs x3 0))) ∧
    cell z.mem 3 0 ≠ some (word (dotLoop true (fun _ => (0, 0)) (Model.zero _ false) (pairs x3 0)))
    := by
  obtain ⟨z, hp, hd, hm⟩ := one78 (w := w3) (N := 32) (by decide +kernel) rfl rfl
    (by decide +kernel) (by decide +kernel) (by decide +kernel)
    (of_decide_eq_true (by kernel_rfl_late)) fun j hj => by interval_cases j <;> kernel_rfl_late
  refine ⟨z, hp, hd, ?_⟩
  rw [hm]
  exact of_decide_eq_true (by kernel_rfl_late)

/-- **The two orders differ at `x4`'s and `x3`'s rows**: the warp's dot product of the pairs
(`warpDot`, the butterfly over the 32 lanes' loops) is `2` at `x4` and `1` at `x3`, and the
left-to-right loop (`dotLoop`) is `1` and `0`, as `2 ^ 24 + 1` rounds to `2 ^ 24`. -/
theorem orders : (warpDot true (fun _ _ => (0, 0)) (pairs x4 0)).toRat? = some 2 ∧
    (dotLoop true (fun _ => (0, 0)) (Model.zero _ false) (pairs x4 0)).toRat? = some 1 ∧
    (warpDot true (fun _ _ => (0, 0)) (pairs x3 0)).toRat? = some 1 ∧
    (dotLoop true (fun _ => (0, 0)) (Model.zero _ false) (pairs x3 0)).toRat? = some 0 := by
  decide +kernel

/-- **`run4`'s cell in the semantics' rounds**: the done grid of `run4` holds in its output cell 0
the word of lane 0's value after the five rounds `deliver (Model.add x y) 0` in every round and
lane (`bflyRoundsAt`; the run's oracle numbers are 0) from lane `l`'s `dotLoop` over
`stride 32 l` of row 0's pairs. This is the word that `MojoProof.Tile.bflyDeliver_holds`
(MojoProof/Tile/MatVec.lean) reads at `k = 5`, `c = true`, `o i l = fun _ => (0, 0)` and
`ob i r l = 0`. `run4`'s cell through `bflyRoundsAt_deliver`, whose premise (no lane below 32
holds a NaN after any round of `Model.add`) the kernel decides at the row. -/
theorem run4_deliver : ∃ z, (∃ i, GPUProof.Path (Grid.Step (L x4) (c x4)) i (g0 x4) z) ∧
    GPUProof.Done sig (z, L x4, c x4) ∧
    cell z.mem 3 0 = some (word (bflyRoundsAt (fun _ _ x y => deliver (Model.add x y) 0)
      (bflyOffsets 5) (fun l => dotLoop true (fun _ => (0, 0)) (Model.zero _ false)
        (stride (2 ^ 5) l (pairs x4 0))) 0)) := by
  obtain ⟨z, hp, hd, hc, -⟩ := run4
  exact ⟨z, hp, hd, hc.trans (congrArg (some ∘ word) (bflyRoundsAt_deliver
    (fun x y => Model.add x y) (fun _ _ => 0) (e := 5) (by decide) _ (by decide +kernel)
    (by decide)).symm)⟩

-- `bflyRoundsAt_deliver`'s premise is needed: at the row `[+∞, -∞, 0, 0]` (`x4`'s launch with
-- that matrix) lane 0 holds `+∞` and lane 1 `-∞` until the last round, whose sum at lane 0 is a
-- NaN; at the oracle number `0x7fc00001` (a quiet NaN, payload 1) in every round and lane the
-- semantics' rounds give its word, `Model.add`'s rounds `0x7fc00000`. At the run's oracle 0 the
-- two agree even there: 0 encodes `+0`, not a NaN, so `deliver r 0 = r`.
example : let v := (fun l => dotLoop true (fun _ => (0, 0)) (Model.zero _ false)
      (stride (2 ^ 5) l (pairs { x4 with a := [0x7f800000, 0xff800000, 0, 0] } 0)))
    (bflyRounds (fun x y => Model.add x y) (bflyOffsets 5) v 0).isNaN = true ∧
    word (bflyRoundsAt (fun _ _ x y => deliver (Model.add x y) 0x7fc00001) (bflyOffsets 5) v 0) =
      leBytes 4 0x7fc00001 ∧
    word (bflyRounds (fun x y => Model.add x y) (bflyOffsets 5) v 0) = leBytes 4 0x7fc00000 ∧
    word (bflyRoundsAt (fun _ _ x y => deliver (Model.add x y) 0) (bflyOffsets 5) v 0) =
      leBytes 4 0x7fc00000 := by
  decide +kernel

/-- **The checks refuse the wrong branch and wrong deliveries** (lane 0 of `x32`'s warp unless
said): `%6`'s segments with the return along `%43` (`ok43`), as row 0 is below `M = 1`; at
`M = 0` the chain through `%44` (`ok78`); `%6`'s two deliveries on the start's memory, which
lacks the lane's `alloca` blocks (`Piece.fires` with the end check `fun _ => true`); and `%78`'s
segments with four deliveries for five shuffles (`chainP`). `twins` gives the last two with the
right memories and count. -/
theorem refused : ok43 w32 0 = false ∧
    ok78 ⟨x0 1 32 0, 0, offer [] 0, (g0 (x0 1 32 0)).mem⟩ 0 = false ∧
    Piece.fires gemv.fn_0 6 (fun _ => true) gP.1 0
      [(r w32 0 0, (g0 x32).mem), (r w32 1 0, (g0 x32).mem)] (V0 x32 0 (m0 w32 0)) = false ∧
    chainP false 0 (out 0) [(r w32 2 0, A w32), (r w32 3 0, A w32), (r w32 4 0, A w32),
      (r w32 5 0, A w32)] (V6 w32 0 (A w32)) = false :=
  ⟨by decide +kernel, by decide +kernel, by decide +kernel, by decide +kernel⟩

/-- The twins of `refused`'s last two: `%6`'s deliveries on the memory after lane 0's `alloca`s,
and `%78`'s segments with five deliveries, pass. -/
theorem twins : Piece.fires gemv.fn_0 6 (fun _ => true) gP.1 0
      [(r w32 0 0, m0 w32 1), (r w32 1 0, m0 w32 1)] (V0 x32 0 (m0 w32 0)) = true ∧
    chainP false 0 (out 0) [(r w32 2 0, A w32), (r w32 3 0, A w32), (r w32 4 0, A w32),
      (r w32 5 0, A w32), (r w32 6 0, A w32)] (V6 w32 0 (A w32)) = true :=
  ⟨by decide +kernel, by decide +kernel⟩

/-- One block of 16 threads, row count 1, `K = 0`. -/
def x16 : Cfg := x0 1 16 1

/-- What each of the 16 lanes of `x16`'s warp offers: row 0's halves at `%6`'s shuffles, the sum
`0.0` at the first `bfly`, and `poison` at the four after it (the sum plus the first `bfly`'s
`poison`). -/
def v16 (i _ : Nat) : Val := if i < 3 then .bits 32 0 else .poison

/-- The one warp of `x16`, from the start's memory. -/
def w16 : Warp := ⟨x16, 0, v16, (g0 x16).mem⟩

/-- **The mutant, a block of 16 threads**: the mask stays full, so every shuffle fires (`warp78`,
with `WarpShfl` at each of the seven), but the first `bfly`'s offset 16 reads lanes outside the
warp: every lane is delivered `poison` there, and the start steps to a done grid whose output
cell 0 holds `poison`. -/
theorem poison16 : (∀ j < 16, r w16 2 j = some .poison) ∧
    ∃ z, (∃ i, GPUProof.Path (Grid.Step (L x16) (c x16)) i (g0 x16) z) ∧
      GPUProof.Done sig (z, L x16, c x16) ∧
      cell z.mem 3 0 = some [.poison, .poison, .poison, .poison] := by
  refine ⟨fun j hj => by interval_cases j <;> kernel_rfl, ?_⟩
  obtain ⟨z, hp, hd, hm⟩ := one78 (w := w16) (N := 16) (by decide +kernel) rfl rfl
    (by decide +kernel) (by decide +kernel) (by decide +kernel)
    (of_decide_eq_true (by kernel_rfl_late)) fun j hj => by interval_cases j <;> kernel_rfl_late
  refine ⟨z, hp, hd, ?_⟩
  rw [hm]
  exact of_decide_eq_true (by kernel_rfl_late)

end MojoProofTest.GemvWarp
