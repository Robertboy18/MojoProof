import MojoProofTest.SymSeg
import MojoProof.LLVM.Mutate

/-!
# Segments with an `alloca` after the last marker

The segment checker's summary of the statements after a block's last collective call or lifetime
marker (the tail of `summarizePieces`, MojoProof/Sym/Segment.lean) takes the `alloca` flag, and
`Piece.Through`'s terminal case ends with the tail's `alloca` blocks in front of the frame's
(`EndsAt false`), for every flag (`Piece.through`). Two kernels, each one hand-built block with
gemv_kernel's header, declarations, attribute groups, metadata and data layout (fixture `gemv`,
MojoProofTest/SymLane.lean):

* `kA`, `@k` with the block `%0`: `%1 = alloca i32, i64 1, align 4` and `ret void`, with no
  marker;
* `kB`, `@k` with the block `%0`: `%1 = alloca i32, i64 1, align 4`,
  `call void @llvm.lifetime.start.p0(ptr %1)`, `%2 = alloca i32, i64 1, align 4` and `ret void`,
  an `alloca` after the last marker.

Each module defines no name twice (`Module.twice`), and its printed text imports back to the same
module, intrinsics, data layout and kernel `@k` (`Mutate.admission`: parsed, checked, printed back
token for token, no use of an undefined local).

* `alloca_ret`: with the flag on, `kA`'s block from statement 0 with no stop is no segment and the
  tail, the `alloca`'s effect (one cell of `i64`) to `ret void`; with the flag off it has no
  summary. On every thread at statement 0 of the block, the block ends with the `alloca`'s block
  in front of the frame's (`Piece.through`).
* `alloca_after_marker`: with the flag on, `kB`'s block from statement 0 with the stop 1 is the
  segment of the `lifetime.start` on the first `alloca`'s pointer (node 0) and the tail, the second
  `alloca` to `ret void`; with the flag off the tail from statement 2 has no summary, with it on
  it has one. On every thread at statement 0, the thread runs the block through the marker to its
  end (`Piece.through`).
* `alloca_tail_mutant`: with the flag on, `kA`'s block with the stop 0 (no marker there) and
  `kB`'s with no stop (the marker in the tail) have no summary.
-/

namespace MojoProofTest.SymSegAlloca

open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane
  MojoProofTest.SymSeg

/-- `%i = alloca i32, i64 1, align 4`, the form of gemv_kernel's `alloca`s of an `i32`. -/
def allocaStmt (i : Nat) : Stmt :=
  { res := some i, inst := .alloca (.int 32) (some (.mk (.int 64) (.int 1))) (some 4) }

/-- `call void @llvm.lifetime.start.p0(ptr %i)`, the form of gemv_kernel's markers. -/
def startStmt (i : Nat) : Stmt :=
  { res := none,
    inst := .call {} .void (.fn "llvm.lifetime.start.p0") [(.mk (.ptr 0) (.loc i), [])] }

/-- The kernel `@k` with gemv_kernel's linkage, calling convention and attribute group, no
parameter, the local names `names` (local `i` is `%i`) and one block `%0` of the statements `ss`
and `ret void`. -/
def kern (names : Array String) (ss : Array Stmt) : Func :=
  { gemv.fn_0 with name := "k", params := [], names, blocks := #[⟨0, ss, .ret none⟩] }

/-- gemv_kernel's program with the kernel `k` in place of gemv_kernel: gemv's declarations,
intrinsics, attribute groups, metadata and data layout. -/
def prog (k : Func) : Program :=
  { gemv.prog with
    module := { gemv.prog.module with
      funcs := #[k] ++ gemv.prog.module.funcs.filter (·.blocks.isEmpty) }
    kernels := [k.name] }

/-- `@k` with `%1 = alloca i32, i64 1, align 4` and `ret void`. -/
def kA : Func := kern #["0", "1"] #[allocaStmt 1]

/-- `@k` with `%1 = alloca i32, i64 1, align 4`, `call void @llvm.lifetime.start.p0(ptr %1)`,
`%2 = alloca i32, i64 1, align 4` and `ret void`. -/
def kB : Func := kern #["0", "1", "2"] #[allocaStmt 1, startStmt 1, allocaStmt 2]

/-- Whether the printed text of `k`'s program's module imports back to the same module,
intrinsics, data layout and kernels (`Mutate.admission`). -/
def admitted (k : Func) : Bool :=
  match Mutate.admission (prog k).module with
  | .ok P => P.module == (prog k).module && P.intrinsics == (prog k).intrinsics &&
      P.layout == (prog k).layout && P.kernels == (prog k).kernels
  | .error _ => false

#guard ((prog kA).module.twice).isNone && admitted kA
#guard ((prog kB).module.twice).isNone && admitted kB

/-- **An `alloca` with no marker**: one hand-built block (`kA`'s `%0`: an `alloca` of an `i32` and
`ret void`). With the `alloca` flag on, `summarizePieces` from statement 0 with no stop gives no
segment and the tail: the `alloca`'s effect (one cell of `i64`) and the exit `ret`; with the flag
off it gives none. For every context of the program, deliveries `w` and thread whose innermost
frame `f` (above frames `rest`) runs `kA` at statement 0 of `%0`, with memory `m`, if the tail's
obligations hold the block ends with the `alloca`'s block in front of `f`'s (`Piece.Through`'s
`EndsAt false`, by `Piece.through`). -/
theorem alloca_ret :
    (summarizePieces (prog kA) kA 0 0 [] true).map (fun r => (r.1.length, r.2.effs, r.2.exit)) =
      some (0, [.alloca 0 0 0 (some (.int 64 1))], .ret) ∧
    (summarizePieces (prog kA) kA 0 0 []).isNone ∧
    ∀ {c : Ctx}, c.prog = prog kA → ∀ (w : Nat → Option Val × Mem) {t : Thread} {m : Mem}
      {f : Frame} {rest : List Frame}, t.frames = f :: rest → f.fn = kA → f.label = 0 →
      f.pc = 0 → ∃ Ss L, summarizePieces (prog kA) kA 0 0 [] true = some (Ss, L) ∧
        Piece.Through c 0 rest L Ss w t m f := by
  have h : (summarizePieces (prog kA) kA 0 0 [] true).isSome = true := by decide +kernel
  obtain ⟨⟨Ss, L⟩, hx⟩ := Option.isSome_iff_exists.1 h
  refine ⟨by decide +kernel, by decide +kernel, ?_⟩
  intro c hP w t m f rest ht hfn hl hp
  exact ⟨Ss, L, hx, Piece.through hP hx w ht hfn hl hp⟩

/-- **An `alloca` after the last marker**: one hand-built block (`kB`'s `%0`: an `alloca`, the
`lifetime.start` on its pointer, a second `alloca` and `ret void`). With the `alloca` flag on,
`summarizePieces` from statement 0 with the stop 1 gives the segment of the marker (a
`lifetime.start` on node 0, the first `alloca`'s pointer, after one statement) and the tail: the
second `alloca`'s effect at statement 2 and the exit `ret`. The tail alone, from statement 2, has
no summary with the flag off and one with it on. For every context of the program, deliveries `w`
and thread whose innermost frame `f` (above frames `rest`) runs `kB` at statement 0 of `%0`, with
memory `m`, the thread runs the block through the marker to its end (`Piece.Through`, by
`Piece.through`), each piece's obligations a premise at its start frame. -/
theorem alloca_after_marker :
    (summarizePieces (prog kB) kB 0 0 [1] true).map (fun r => r.1.map lifeShape) =
      some [some (true, .node 0, 1)] ∧
    (summarizePieces (prog kB) kB 0 0 [1] true).map (fun r => (r.2.effs, r.2.exit)) =
      some ([.alloca 0 2 0 (some (.int 64 1))], .ret) ∧
    (summarizePieces (prog kB) kB 0 2 []).isNone ∧
    (summarizePieces (prog kB) kB 0 2 [] true).isSome ∧
    ∀ {c : Ctx}, c.prog = prog kB → ∀ (w : Nat → Option Val × Mem) {t : Thread} {m : Mem}
      {f : Frame} {rest : List Frame}, t.frames = f :: rest → f.fn = kB → f.label = 0 →
      f.pc = 0 → ∃ Ss L, summarizePieces (prog kB) kB 0 0 [1] true = some (Ss, L) ∧
        Piece.Through c 0 rest L Ss w t m f := by
  have h : (summarizePieces (prog kB) kB 0 0 [1] true).isSome = true := by decide +kernel
  obtain ⟨⟨Ss, L⟩, hx⟩ := Option.isSome_iff_exists.1 h
  refine ⟨by decide +kernel, by decide +kernel, by decide +kernel, by decide +kernel, ?_⟩
  intro c hP w t m f rest ht hfn hl hp
  exact ⟨Ss, L, hx, Piece.through hP hx w ht hfn hl hp⟩

/-- **The mutants**: with the `alloca` flag on, `kA`'s block with the stop 0 (an `alloca`, neither
a collective call nor a marker) has no summary, nor has `kB`'s block with no stop (its
`lifetime.start` in the tail, which the block checker refuses). -/
theorem alloca_tail_mutant :
    (summarizePieces (prog kA) kA 0 0 [0] true).isNone ∧
    (summarizePieces (prog kB) kB 0 0 [] true).isNone := by
  decide +kernel

end MojoProofTest.SymSegAlloca
