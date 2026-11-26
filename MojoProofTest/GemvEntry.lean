import MojoProofTest.SymLane
import MojoProof.Sym.OblPieces

/-!
# gemv_kernel's entry block `%6`: the loads of `%7`'s pointers, the `i32` slots, `%35`

MojoProof/Sym/OblPieces.lean's lemmas at gemv_kernel's statements of `%6` (gemv IR :37-45):
`store [2 x ptr] %27, ptr %7` (statement 29), `%29 = load ptr, ptr %28` (31) and
`%33 = load ptr, ptr %32` (35), the `i32` slot `%30` reads (32) after a lifetime marker of
another block, and the two `insertelement`s `%31` (33) and `%35` (37). Each test takes the
operands' values as premises, for every valuation of `%6`'s frame (so every valid launch,
thread, context and memory), and the statements' lookups close by `rfl`.

The run of `%6` from pc 0 to statement 41 is `MojoProofTest.GemvEntryRun.entry`
(MojoProofTest/GemvEntryRun.lean), for every valid launch, thread, context and memory with the
start's facts and the two shuffles' deliveries as premises; its proof uses the OblPieces lemmas
these tests check at the same statements. Left (docs/proofs/gemv.md, "The order of the work"):
the deliveries as the other lanes' values (`WarpRun.of_waits`) and the kernel theorem.
-/

namespace MojoProofTest.GemvEntry
open MojoProof MojoProof.LLVM MojoProof.Sem MojoProof.Sym MojoProofTest.SymLane

/-- gemv_kernel's `%29` (statement 31, `load ptr, ptr %28` with `%28 = %7`), for every
valuation of `%6`'s frame and node list, after the effect `store [2 x ptr] %27, ptr %7`
(statement 29) of `[q₉, q₈]` at `r`, whose check at `r` succeeds before it: element 0, `q₉`. -/
theorem load29 {V : Valuation} {vs : List (Except Fault Val)} {x y p : SVal} {q₉ q₈ r : Ptr}
    {rr : Sem.Block × Nat} (hF : V.fn = gemv.fn_0) (hP : V.ctx.prog = gemv.prog)
    (hr : ∃ m, SEff.run V vs [.store 6 29 x y] = .ok m)
    (hx : x.eval V vs = .ok (.agg [.ptr q₉, .ptr q₈])) (hy : y.eval V vs = .ok (.ptr r))
    (hp : p.eval V vs = .ok (.ptr r))
    (hq : V.mem.check gemv.prog.layout V.ctx.who 0 r (gemv.prog.layout.stored (.ptr 0))
      (some 8) = .ok rr) :
    (SNode.loadAfter 6 31 p [.store 6 29 x y]).eval V vs = .ok (.ptr q₉) :=
  SNode.eval_loadAfter_elem (es := []) (xs := [q₉, q₈]) (n := 2) (k := 0) hF hP
    (Layout.Codec.ptr _ 0 (by decide)) rfl (by decide) (by rfl) (by rfl) hr hx hy hp rfl
    (by simp) rfl hq

/-- gemv_kernel's `%33` (statement 35, `load ptr, ptr %32` with `%32` 8 bytes past `%7`), for
every valuation of `%6`'s frame and node list, after the effect `store [2 x ptr] %27, ptr %7`
(statement 29) of `[q₉, q₈]` at `r`, whose check at `%32` succeeds before it: element 1, `q₈`. -/
theorem load33 {V : Valuation} {vs : List (Except Fault Val)} {x y p : SVal} {q₉ q₈ q r : Ptr}
    {rr : Sem.Block × Nat} (hF : V.fn = gemv.fn_0) (hP : V.ctx.prog = gemv.prog)
    (hr : ∃ m, SEff.run V vs [.store 6 29 x y] = .ok m)
    (hx : x.eval V vs = .ok (.agg [.ptr q₉, .ptr q₈])) (hy : y.eval V vs = .ok (.ptr r))
    (hp : p.eval V vs = .ok (.ptr q)) (hb : q.block = r.block) (ho : q.off = r.off + 8)
    (hq : V.mem.check gemv.prog.layout V.ctx.who 0 q (gemv.prog.layout.stored (.ptr 0))
      (some 8) = .ok rr) :
    (SNode.loadAfter 6 35 p [.store 6 29 x y]).eval V vs = .ok (.ptr q₈) :=
  SNode.eval_loadAfter_elem (es := []) (xs := [q₉, q₈]) (n := 2) (k := 1) hF hP
    (Layout.Codec.ptr _ 0 (by decide)) rfl (by decide) (by rfl) (by rfl) hr hx hy hp hb
    (by rw [ho]; rfl) rfl hq

/-- gemv_kernel's `i32` slot `%9` as `%30` (statement 32) reads it, for every memory, threads,
word `u` and liveness: after the store of `%24`'s word `u` at `%9` (block `b`, statement 21)
whose check succeeds before it, and a lifetime marker of another block `b'` (`%8`'s or `%7`'s),
the load gives `u`. -/
theorem slot30 {m m' : Mem} {w w' : Who} {b b' : Nat} {u : BitVec 32} {l : Bool}
    {r : Sem.Block × Nat} (hb : b ≠ b')
    (h : m.store gemv.prog.layout w 0 (.int 32) (.bits 32 u) ⟨b, 0⟩ (some 4) none = .ok m')
    (hc : m.check gemv.prog.layout w' 0 ⟨b, 0⟩ (gemv.prog.layout.stored (.int 32)) (some 4) =
      .ok r) :
    (m'.setLive b' l).load gemv.prog.layout w' 0 (.int 32) ⟨b, 0⟩ (some 4) = .ok (.bits 32 u) :=
  Mem.load_store_codec_of_block (Layout.Codec.int _ 32) u h hc
    (Mem.foldl_setLive_blocks (bs := [b']) (by simpa using hb))

/-- gemv_kernel's `undef` operand of `%31` (statement 33), for every valuation of `%6`'s frame
and node list: the `<2 x i32>` of two `undef`s. -/
theorem undef31 {V : Valuation} {vs : List (Except Fault Val)} (hF : V.fn = gemv.fn_0) :
    (SNode.constAt 6 33 0).eval V vs = .ok (.vec [.undef, .undef]) := by
  have h := SNode.eval_constAt_undef (vs := vs) (lbl := 6) (pc := 33) (i := 0) hF (by rfl)
    (by rfl)
  exact h.trans rfl

/-- gemv_kernel's `%31` (statement 33, `insertelement <2 x i32> undef, i32 %30, i64 0`), for
every valuation of `%6`'s frame and node list with `%30`'s word `u₁`: `<u₁, undef>`. -/
theorem vec31 {V : Valuation} {vs : List (Except Fault Val)} {a e i : SVal} {u₁ : BitVec 32}
    (hF : V.fn = gemv.fn_0) (ha : a.eval V vs = .ok (.vec [.undef, .undef]))
    (he : e.eval V vs = .ok (.bits 32 u₁)) (hi : i.eval V vs = .ok (.bits 64 0)) :
    (SNode.insEltAt 6 33 a e i).eval V vs = .ok (.vec [.bits 32 u₁, .undef]) :=
  SNode.eval_insEltAt_at hF (by rfl) ha he hi (by rfl)

/-- gemv_kernel's `%35` (statement 37, `insertelement <2 x i32> %31, i32 %34, i64 1`), for every
valuation of `%6`'s frame and node list with `%31 = <u₁, undef>` and `%34`'s word `u₂`: the
vector `<u₁, u₂>` of the two delivered words. -/
theorem vec35 {V : Valuation} {vs : List (Except Fault Val)} {a e i : SVal} {u₁ u₂ : BitVec 32}
    (hF : V.fn = gemv.fn_0) (ha : a.eval V vs = .ok (.vec [.bits 32 u₁, .undef]))
    (he : e.eval V vs = .ok (.bits 32 u₂)) (hi : i.eval V vs = .ok (.bits 64 1)) :
    (SNode.insEltAt 6 37 a e i).eval V vs = .ok (.vec [.bits 32 u₁, .bits 32 u₂]) :=
  SNode.eval_insEltAt_at hF (by rfl) ha he hi (by rfl)

end MojoProofTest.GemvEntry
