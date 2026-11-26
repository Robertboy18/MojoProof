import MojoProof.Sym.Canon

/-!
# A shuffle's delivery at symbolic values

`WarpRun.of_waits` (MojoProof/Sym/Canon.lean) asks of each lane's wait that its delivery be what
`Grid.fire` delivers: `shflVal` of the lanes' offered values at `shflSource`'s lane, under the
result attributes of the shuffle's declaration (`withAttrs`). Every result here is for every
program, launch, warp, offered values, lane, layout and memory.

* `shflVal_mapM`: when the source lane is one of the warp's lanes and the attributes keep its
  offered value, the delivery equation holds exactly at `some` of that value.
* `keepsBits`, `withAttrs_keepsBits`: the return attributes that keep every word (all but `range`,
  `nonnull` and `align`), and `withAttrs` keeping a word under them; `Program.shflKeeps`: every
  shuffle declaration of a program has such return attributes, a check the kernel evaluates;
  `Program.shfl_deliver`: `WarpRun.of_waits`'s delivery equation for a program that passes it.
* `shflSource_idx`: an `idx` shuffle with clamp 31 reads lane `b % 32`, every lane alike.
* `zero_mem_warpLanes`: lane 0 is one of every warp's lanes; `warpLanes_full`: a warp has 32
  lanes when 32 divides the block's number of threads.
* `Program.shfl_deliver_bfly`, `Program.shfl_deliver_idx`: the delivery equation of a butterfly
  shuffle in a warp of 32 lanes and of an `idx` shuffle from lane 0.
-/

namespace MojoProof.Sym

open MojoProof.LLVM MojoProof.Sem

/-- **The delivery of a shuffle whose source lane is in the warp.** For every lanes `ls`, offered
values `a`, mode `mo`, lane `j`, lane and clamp operands `b`, `cl`, layout, memory, type,
attributes and delivery `d`: if the source lane `s = shflSource mo j b cl` is one of `ls` and the
attributes keep `a s` (`withAttrs`), then `Grid.fire`'s delivery under the attributes is `d`
exactly when `d = some (a s)`. -/
theorem shflVal_mapM {ls : List Nat} {a : Nat → Val} {mo : Shfl} {j b cl s : Nat} {l : Layout}
    {m : Mem} {t : Ty} {ats : List Attr} (hs : shflSource mo j b cl = s) (hl : s ∈ ls)
    (hk : withAttrs l m t ats (a s) = .ok (a s)) (d : Option Val) :
    (some (shflVal ls a (shflSource mo j b cl))).mapM (withAttrs l m t ats) = .ok d ↔
      d = some (a s) := by
  subst hs
  have e : (some (shflVal ls a (shflSource mo j b cl))).mapM (withAttrs l m t ats) =
      .ok (some (a (shflSource mo j b cl))) := by
    simp only [shflVal, hl, ite_true, Option.mapM, hk]
    rfl
  rw [e]
  exact ⟨fun h => by injection h with h; exact h.symm, fun h => h ▸ rfl⟩

/-- Whether return attribute `a` keeps every word: it is not a `range`, `nonnull` or `align`, the
attributes with which `withAttrs` can make a word poison or fail. -/
def keepsBits : Attr → Bool
  | .range .. => false
  | .flag n => n != "nonnull"
  | .int n _ => n != "align"
  | _ => true

/-- **Return attributes that keep every word.** For every layout, memory, type, attributes that
each pass `keepsBits`, width `w` and word `x : BitVec w`: `withAttrs` gives `.bits w x`. -/
theorem withAttrs_keepsBits (l : Layout) (m : Mem) (t : Ty) {ats : List Attr}
    (ha : ats.all keepsBits = true) (w : Nat) (x : BitVec w) :
    withAttrs l m t ats (.bits w x) = .ok (.bits w x) := by
  have hd : (Val.bits w x).defined = true := rfl
  unfold withAttrs
  dsimp only
  split
  · rename_i h
    cases h
  · rw [foldlM_fix]
    · simp only [hd, Bool.not_true, Bool.and_false, Bool.false_eq_true, ↓reduceIte, bind,
        Except.bind, pure, Except.pure]
    · intro a hm
      have h := List.all_eq_true.1 ha a hm
      cases a with
      | range => cases h
      | flag n =>
        have hn : n ≠ "nonnull" := by simpa [keepsBits] using h
        split <;> first | rfl | (exfalso; simp_all)
      | int n k =>
        have hn : n ≠ "align" := by simpa [keepsBits] using h
        split <;> first | rfl | (exfalso; simp_all)
      | _ => split <;> first | rfl | contradiction

/-- Whether every shuffle declaration of program `P` (one whose name its intrinsic table maps to
a shuffle) has return attributes that each pass `keepsBits`. -/
def _root_.MojoProof.LLVM.Program.shflKeeps (P : Program) : Bool :=
  P.module.funcs.all fun e => match P.intrinsics.lookup e.name with
    | some (.shfl _) => e.retAttrs.all keepsBits
    | _ => true

/-- For every program that passes `shflKeeps`, every declaration its calls find by a name the
intrinsic table maps to a shuffle keeps every word: `withAttrs_keepsBits`. -/
theorem _root_.MojoProof.LLVM.Program.withAttrs_shfl {P : Program} (hP : P.shflKeeps = true)
    {g : String} {e : Func} {mo : Shfl} (he : P.module.funcs.find? (·.name == g) = some e)
    (hg : P.intrinsics.lookup g = some (.shfl mo)) (l : Layout) (m : Mem) (w : Nat)
    (x : BitVec w) : withAttrs l m e.ret e.retAttrs (.bits w x) = .ok (.bits w x) := by
  have h := (Array.all_eq_true_iff_forall_mem.1 hP) e (Array.mem_of_find?_eq_some he)
  have hb : (e.name == g) = true := Array.find?_some (p := fun x : Func => x.name == g) he
  rw [beq_iff_eq.1 hb, hg] at h
  exact withAttrs_keepsBits l m e.ret h w x

/-- **`WarpRun.of_waits`'s delivery equation for a program that passes `shflKeeps`.** For every
program `P` with `P.shflKeeps`, lanes `ls`, offered values `a`, mode, lane `j`, operands `b`,
`cl`, source lane `s = shflSource mo j b cl` in `ls` offering a word, layout, memory and delivery
`d = some (a s)`: every declaration a call finds by a name mapped to the shuffle delivers `d`. -/
theorem _root_.MojoProof.LLVM.Program.shfl_deliver {P : Program} (hP : P.shflKeeps = true)
    {ls : List Nat} {a : Nat → Val} {mo : Shfl} {j b cl s w : Nat} {x : BitVec w} {l : Layout}
    {m : Mem} {d : Option Val} (hs : shflSource mo j b cl = s) (hl : s ∈ ls) (hx : a s = .bits w x)
    (hd : d = some (a s)) :
    ∀ g e, P.module.funcs.find? (·.name == g) = some e → P.intrinsics.lookup g = some (.shfl mo) →
      (some (shflVal ls a (shflSource mo j b cl))).mapM (withAttrs l m e.ret e.retAttrs) =
        .ok d := fun _ _ he hg =>
  (shflVal_mapM hs hl (hx ▸ P.withAttrs_shfl hP he hg l m w x) d).2 hd

/-- **An `idx` shuffle with clamp 31 reads lane `b % 32`**, for every lane `l` and lane operand
`b`: the clamp's segment mask is 0, so the first lane of the segment is 0 and its last 31, and
the source lane is `b`'s low five bits (PTX ISA 9.5, section 9.7.10.6, "Semantics"). -/
theorem shflSource_idx (l b : Nat) : shflSource .idx l b 31 = b % 32 := by
  have h1 : b % 32 &&& 31 = b % 32 := by
    rw [show (31 : Nat) = 2 ^ 5 - 1 by rfl, Nat.and_two_pow_sub_one_eq_mod, Nat.mod_mod]
  have h2 : b % 32 ≤ 31 := by omega
  simp [shflSource, h1, h2]
  omega

/-- Lane 0 is one of the lanes of every thread's warp, for every launch whose blocks have
threads. -/
theorem zero_mem_warpLanes {L : Launch} (hs : 0 < volume L.block) (n : Nat) :
    0 ∈ warpLanes L n := by
  have := Nat.mod_lt n hs
  rw [warpLanes_eq, List.mem_range]
  omega

/-- **A full warp**: for every launch whose blocks have a positive number of threads that 32
divides, every thread's warp has the 32 lanes `0, ..., 31`. -/
theorem warpLanes_full {L : Launch} (hs : 0 < volume L.block) (h : 32 ∣ volume L.block)
    (n : Nat) : warpLanes L n = List.range 32 := by
  obtain ⟨q, hq⟩ := h
  have hr := Nat.mod_lt n hs
  rw [warpLanes_eq, hq] at *
  congr 1
  omega

/-- **A butterfly shuffle's delivery in a full warp**, for every program `P` with `P.shflKeeps`,
launch `L` and thread `n` whose warp's lanes are `0, ..., 31`, offered values `a`, lane `j < 32`,
offset `b < 32`, layout and memory: with clamp 31, a lane `j ^^^ b` that offers a word delivers
`some (a (j ^^^ b))` (`shflSource_bfly`). -/
theorem _root_.MojoProof.LLVM.Program.shfl_deliver_bfly {P : Program}
    (hP : P.shflKeeps = true) {L : Launch} {n : Nat} (h32 : warpLanes L n = List.range 32)
    {a : Nat → Val} {j b w : Nat} {x : BitVec w} {l : Layout} {m : Mem} {d : Option Val}
    (hj : j < 32) (hb : b < 32)
    (hx : a (j ^^^ b) = .bits w x) (hd : d = some (a (j ^^^ b))) :
    ∀ g e, P.module.funcs.find? (·.name == g) = some e →
      P.intrinsics.lookup g = some (.shfl .bfly) →
      (some (shflVal (warpLanes L n) a (shflSource .bfly j b 31))).mapM
        (withAttrs l m e.ret e.retAttrs) = .ok d :=
  P.shfl_deliver hP (shflSource_bfly hj hb)
    (by rw [h32, List.mem_range]; exact Nat.xor_lt_two_pow (n := 5) hj hb) hx hd

/-- **An `idx` shuffle's delivery from lane 0**, for every program `P` with `P.shflKeeps`, launch
`L` whose blocks have threads, thread `n`, offered values `a` with `a 0` a word, lane `j`, layout
and memory: with lane operand 0 and clamp 31 every lane is delivered `some (a 0)`
(`shflSource_idx`, `zero_mem_warpLanes`). -/
theorem _root_.MojoProof.LLVM.Program.shfl_deliver_idx {P : Program}
    (hP : P.shflKeeps = true) {L : Launch} (hs : 0 < volume L.block) {n : Nat} {a : Nat → Val}
    {j w : Nat} {x : BitVec w} {l : Layout} {m : Mem} {d : Option Val} (hx : a 0 = .bits w x)
    (hd : d = some (a 0)) :
    ∀ g e, P.module.funcs.find? (·.name == g) = some e →
      P.intrinsics.lookup g = some (.shfl .idx) →
      (some (shflVal (warpLanes L n) a (shflSource .idx j 0 31))).mapM
        (withAttrs l m e.ret e.retAttrs) = .ok d :=
  P.shfl_deliver hP (shflSource_idx j 0) (zero_mem_warpLanes hs n) hx hd

end MojoProof.Sym
