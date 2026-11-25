import MojoProof.Sem.TensorCore

/-!
# Warp-collective `mma` and `ldmatrix` on the lanes' registers (docs/proofs/tensor-core.md)

`MojoProof.Sem.TensorCore` places the tiles of `mma` and `ldmatrix` in the lanes' registers as
elements (`Frag`, `mmaStep`, `ldmatrix`). This module reads those elements out of the run-time
values (`Val`) the 32 lanes pass to the call and writes the results back as values: one warp
step for each intrinsic, from the 32 lanes' arguments to the 32 lanes' results.

An element is its bit pattern, a number below `2 ^ width`. A register holds its elements in one
of three forms (`RegForm`), the register types of `Mma.regs`' signature (`MmaTy.reg`, and
`Ty.fp` for the accumulators) and of `ldmatrix`'s:
* `word w`: one element, the scalar `Val.bits w` (tf32 in an `i32`, f64 in a `double`, the
  `float` and `double` accumulators);
* `pair`: two 16-bit elements in an `i32` `Val.bits 32`, element 0 in the low half (bf16 inputs,
  the `b16` elements of `ldmatrix`);
* `vec2`: two 16-bit elements, the lanes of a `<2 x half>` `Val.vec` (f16 inputs).

Definitions: `RegForm.get` and `RegForm.put`, an element out of a register and a register out of
its elements; `RegForm.ok`, the register is of the form; `abForm` and `accForm`, the forms of
`mma`'s operands; `argElem` and `argsOk`, the elements of an operand in the lanes' arguments and
the check that they decode; `encode`, a tile as each lane's registers; `resElem`, the elements of
the lanes' results; `mmaWarp v acc x`, the warp's `mma` of the importer's value `v` with the
accumulation `acc` on bit patterns; `ldmWarp q t rd x`, the warp's `ldmatrix.x<q>`, with
`.trans` when `t` and the memory's 16-bit elements read by `rd`.

Proved, for every form and every layout with `Frag.Inv`:
* `RegForm.get_put`: a register built from elements reads back as them, modulo `2 ^ width`;
  `RegForm.put_elem`: a register of the form is rebuilt from its elements; `RegForm.ok_put`;
* `accForm_pack`: an accumulator's form holds one element, so `mmaFrags`' layouts fit the forms
  (`mmaFrags_pack`; their A and B layouts hold `(abForm v.ab).pack` by definition);
* `mmaWarp_spec`: for every `Mma` value `mmaFrags` accepts (those of `Mma.table`) and every
  accumulation on bit patterns (every policy's `A.bits fi` among them), on
  the lanes' arguments that encode tiles `TA`, `TB`, `TC` the step succeeds, and its results,
  read in the layout of D, are `acc (TA i ·) (TB · j) (TC i j)` at every cell;
* `ldmWarp_spec`: for every count `q` and flag `t`, when lane `R < 8q` passes one pointer `P R`
  and every element of its row reads, the step succeeds and its results, read in the layout
  `ldm q t`, are the elements at `P R` plus `2 C`.
* `Grid.fire_mma`: for every launch, so every accumulation policy `L.acc`, every warp and every
  `mma` of the table with bf16 or f16 inputs and an f32 accumulator, a grid step at a warp
  whose lanes all wait at the `mma` with registers that encode tiles of finite words, and whose
  callees' return attributes refuse no aggregate, succeeds: the successor grid has the same
  memory and threads outside the warp, and each lane runs on with its result, whose D tile is
  `L.acc.bits fi` of the tiles. `ldmatrix` is not part of `Grid.fire` (unsupported).
-/

namespace MojoProof.Sem

open LLVM

namespace RegForm

/-- **A register built from elements reads back as them**, for every form `f`, elements `e` and
`s < f.pack`: element `s` of `f.put e` is `e s` modulo `2 ^ f.width`. -/
theorem get_put (f : RegForm) (e : Nat → Nat) {s : Nat} (hs : s < f.pack) :
    f.get (f.put e) s = some (e s % 2 ^ f.width) := by
  cases f with
  | word w =>
    simp only [pack] at hs
    obtain rfl : s = 0 := by omega
    simp [get, put, width]
  | pair =>
    simp only [pack] at hs
    have h0 : e 0 % 65536 < 65536 := Nat.mod_lt _ (by decide)
    have h1 : e 1 % 65536 < 65536 := Nat.mod_lt _ (by decide)
    interval_cases s <;> simp [get, put, width]
    omega
  | vec2 =>
    simp only [pack] at hs
    interval_cases s <;> simp [get, put, width, BitVec.toNat_ofNat]

/-- **Element `s` of a register built from elements is `e s`** when it is below
`2 ^ f.width`, for every form `f` and `s < f.pack`. -/
theorem elem_put (f : RegForm) (e : Nat → Nat) {s : Nat} (hs : s < f.pack)
    (he : e s < 2 ^ f.width) : f.elem (f.put e) s = e s := by
  rw [elem, get_put f e hs, Nat.mod_eq_of_lt he, Option.getD_some]

/-- A register built from elements is of the form, for every form and elements. -/
theorem ok_put (f : RegForm) (e : Nat → Nat) : f.ok (f.put e) = true :=
  List.all_eq_true.2 fun s hs => by simp [get_put f e (List.mem_range.1 hs)]

/-- **A register of the form is rebuilt from its elements**, for every form `f` and value `v`
with `f.ok v`: `f.put (f.elem v) = v`. -/
theorem put_elem {f : RegForm} {v : Val} (h : f.ok v = true) : f.put (f.elem v) = v := by
  have h0 : (f.get v 0).isSome = true :=
    List.all_eq_true.1 h 0 (List.mem_range.2 (by cases f <;> simp [pack]))
  show f.put (fun s => (f.get v s).getD 0) = v
  unfold get at h0 ⊢
  split at h0
  · rename_i w n b
    split_ifs at h0 with hc
    · obtain ⟨rfl, -⟩ := hc
      simp [put]
    · simp at h0
  · rename_i n b
    split_ifs at h0 with hc
    · obtain ⟨rfl, -⟩ := hc
      have hb : b.toNat < 4294967296 := b.isLt
      simp only [put, Val.bits.injEq, heq_eq_eq, true_and]
      apply BitVec.eq_of_toNat_eq
      simp
      omega
    · simp at h0
  · rename_i n x m y
    split_ifs at h0 with hc hs
    · obtain ⟨rfl, rfl, -⟩ := hc
      simp [put]
    · exact absurd rfl hs
    · simp at h0
  · simp at h0

end RegForm

/-- **An accumulator's form holds one element**: for every accumulator type, a register of
`accForm` holds one element, the `pack` of `fragC h 1`. -/
theorem accForm_pack (c : FloatTy) : (accForm c).pack = 1 := by
  cases c <;> rfl

/-- The layouts `mmaFrags` gives hold the forms' elements: for every importer `Mma` value `v`
with `mmaFrags v = some (FA, FB, FC)`, `FA.pack` and `FB.pack` are `(abForm v.ab).pack`, and
`FC.pack` is `(accForm v.cd).pack`. -/
theorem mmaFrags_pack {v : Mma} {FA FB FC : Frag} (h : mmaFrags v = some (FA, FB, FC)) :
    FA.pack = (abForm v.ab).pack ∧ FB.pack = (abForm v.ab).pack ∧
      FC.pack = (accForm v.cd).pack := by
  simp only [mmaFrags] at h
  split_ifs at h
  simp only [Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl⟩ := h
  exact ⟨rfl, rfl, (accForm_pack v.cd).symm⟩

/-- Lane `l`'s registers holding the tile `T` of bit patterns in the layout `F` and the form
`f`: register `r < F.regs` holds the elements `F.scatter T l r s`. -/
def encode (f : RegForm) (F : Frag) (T : Nat → Nat → Nat) (l : Nat) : List Val :=
  List.ofFn fun r : Fin F.regs => f.put fun s => F.scatter T l r s

/-- Element `s` of register `r` of lane `l` of the 32 lanes' results `y`, each an aggregate of
registers in the form `f`: element `s` of the aggregate's element `r`, `0` when it does not
decode, is missing or `y l` is not an aggregate. -/
def resElem (f : RegForm) (y : Nat → Val) (l r s : Nat) : Nat :=
  match y l with
  | .agg rs => f.elem (rs.getD r .poison) s
  | _ => 0

/-- The argument at `off + r` of the list `pre ++ encode f F T l ++ post`, with `pre` of
length `off` and `r < F.regs`, is register `r` of the encoding. -/
private theorem getD_encode {f : RegForm} {F : Frag} {T : Nat → Nat → Nat} {l r off : Nat}
    (pre post : List Val) (hpre : pre.length = off) (hr : r < F.regs) :
    (pre ++ encode f F T l ++ post).getD (off + r) .poison = f.put fun s => F.scatter T l r s := by
  subst hpre
  have h1 : pre.length ≤ pre.length + r := Nat.le_add_right _ _
  have h2 : r < (encode f F T l).length := by simpa [encode] using hr
  rw [List.getD_eq_getElem?_getD, List.append_assoc, List.getElem?_append_right h1,
    Nat.add_sub_cancel_left, List.getElem?_append_left h2]
  simp [encode, hr]

/-- On registers that encode `T`, the decoded elements are `T`'s entries at `F.pos` (the
elements of `F.scatter T`) at every lane, register and element in range, when `T`'s values are
below `2 ^ f.width` and `F.pack ≤ f.pack`. -/
private theorem argElem_encode {f : RegForm} {F : Frag} {T : Nat → Nat → Nat} {x : Nat → List Val}
    {off : Nat} (pre post : Nat → List Val) (hx : ∀ l, x l = pre l ++ encode f F T l ++ post l)
    (hpre : ∀ l, (pre l).length = off) (hT : ∀ i j, T i j < 2 ^ f.width)
    (hp : F.pack ≤ f.pack) :
    ∀ l < 32, ∀ r < F.regs, ∀ s < F.pack,
      argElem f x off l r s = T (F.pos l r s).1 (F.pos l r s).2 := by
  intro l _ r hr s hs
  rw [argElem, hx, getD_encode _ _ (hpre l) hr]
  exact RegForm.elem_put f _ (by omega) (hT _ _)

/-- On registers that encode a tile, the operand decodes (`argsOk`). -/
private theorem argsOk_encode {f : RegForm} {F : Frag} {T : Nat → Nat → Nat} {x : Nat → List Val}
    {off : Nat} (pre post : Nat → List Val) (hx : ∀ l, x l = pre l ++ encode f F T l ++ post l)
    (hpre : ∀ l, (pre l).length = off) : argsOk f x off F.regs = true := by
  simp only [argsOk, List.all_eq_true, List.mem_range]
  intro l _ r hr
  rw [hx, getD_encode _ _ (hpre l) hr]
  exact RegForm.ok_put f _

/-- `mmaWarp` succeeds when the layouts are `mmaFrags v`'s and the lanes' arguments pass its
checks, and its result is then each lane's aggregate of the D registers `mmaStep` gives. -/
private theorem mmaWarp_eq {v : Mma} {FA FB FC : Frag} (hv : mmaFrags v = some (FA, FB, FC))
    {acc : (Fin v.k → Nat) → (Fin v.k → Nat) → Nat → Nat} {x : Nat → List Val}
    (hL : ((List.range 32).all fun l => (x l).length == FA.regs + FB.regs + FC.regs) = true)
    (hA : argsOk (abForm v.ab) x 0 FA.regs = true)
    (hB : argsOk (abForm v.ab) x FA.regs FB.regs = true)
    (hC : argsOk (accForm v.cd) x (FA.regs + FB.regs) FC.regs = true) :
    mmaWarp v acc x = some fun l => .agg (List.ofFn fun r : Fin FC.regs =>
      (accForm v.cd).put fun s =>
        mmaStep FA FB FC acc (argElem (abForm v.ab) x 0) (argElem (abForm v.ab) x FA.regs)
          (argElem (accForm v.cd) x (FA.regs + FB.regs)) l r s) := by
  unfold mmaWarp
  rw [hv]
  simp only [hL, hA, hB, hC, Bool.and_self, ↓reduceIte]

/-- **The warp's `mma` on registers that hold tiles is the accumulation on the tiles**, for
every importer `Mma` value `v` that `mmaFrags` accepts, with layouts `(FA, FB, FC)`, every
accumulation `acc` on bit patterns (every policy's `A.bits fi` among them) and all tiles `TA`,
`TB` of elements below `2 ^ (abForm v.ab).width` and `TC` below `2 ^ (accForm v.cd).width`:
when each lane passes its A, B and C registers encoding the tiles (`encode`), `mmaWarp`
succeeds, and its results, read in the layout `FC` (`Frag.gather` of `resElem`), are
`acc (TA i ·) (TB · j) (TC i j)`, modulo `2 ^ (accForm v.cd).width`, at every cell `i < v.m`,
`j < 8`. -/
theorem mmaWarp_spec {v : Mma} {FA FB FC : Frag} (hv : mmaFrags v = some (FA, FB, FC))
    (acc : (Fin v.k → Nat) → (Fin v.k → Nat) → Nat → Nat) (TA TB TC : Nat → Nat → Nat)
    (hTA : ∀ i j, TA i j < 2 ^ (abForm v.ab).width) (hTB : ∀ i j, TB i j < 2 ^ (abForm v.ab).width)
    (hTC : ∀ i j, TC i j < 2 ^ (accForm v.cd).width) :
    ∃ y, mmaWarp v acc (fun l => encode (abForm v.ab) FA TA l ++ encode (abForm v.ab) FB TB l ++
        encode (accForm v.cd) FC TC l) = some y ∧
      ∀ i < v.m, ∀ j < 8, FC.gather (resElem (accForm v.cd) y) i j =
        acc (fun k => TA i k) (fun k => TB k j) (TC i j) % 2 ^ (accForm v.cd).width := by
  obtain ⟨hA, hB, hC, hAr, hAc, hBr, hBc, hCr, hCc, -⟩ := mmaFrags_inv hv
  obtain ⟨pA, pB, pC⟩ := mmaFrags_pack hv
  set x : Nat → List Val := fun l => encode (abForm v.ab) FA TA l ++ encode (abForm v.ab) FB TB l ++
    encode (accForm v.cd) FC TC l
  have lenE : ∀ (f : RegForm) (F : Frag) (T : Nat → Nat → Nat) l,
      (encode f F T l).length = F.regs :=
    fun _ _ _ _ => by simp [encode]
  have eA := argElem_encode (f := abForm v.ab) (F := FA) (T := TA) (x := x) (off := 0) (fun _ => [])
    (fun l => encode (abForm v.ab) FB TB l ++ encode (accForm v.cd) FC TC l)
    (fun l => by simp [x, List.append_assoc]) (fun _ => rfl) hTA pA.le
  have eB := argElem_encode (f := abForm v.ab) (F := FB) (T := TB) (x := x) (off := FA.regs)
    (fun l => encode (abForm v.ab) FA TA l) (fun l => encode (accForm v.cd) FC TC l)
    (fun _ => rfl) (fun l => lenE _ _ _ l) hTB pB.le
  have eC := argElem_encode (f := accForm v.cd) (F := FC) (T := TC) (x := x)
    (off := FA.regs + FB.regs)
    (fun l => encode (abForm v.ab) FA TA l ++ encode (abForm v.ab) FB TB l) (fun _ => [])
    (fun l => by simp [x]) (fun l => by simp [lenE]) hTC pC.le
  have oA := argsOk_encode (f := abForm v.ab) (F := FA) (T := TA) (x := x) (off := 0) (fun _ => [])
    (fun l => encode (abForm v.ab) FB TB l ++ encode (accForm v.cd) FC TC l)
    (fun l => by simp [x, List.append_assoc]) (fun _ => rfl)
  have oB := argsOk_encode (f := abForm v.ab) (F := FB) (T := TB) (x := x) (off := FA.regs)
    (fun l => encode (abForm v.ab) FA TA l) (fun l => encode (accForm v.cd) FC TC l)
    (fun _ => rfl) (fun l => lenE _ _ _ l)
  have oC := argsOk_encode (f := accForm v.cd) (F := FC) (T := TC) (x := x)
    (off := FA.regs + FB.regs)
    (fun l => encode (abForm v.ab) FA TA l ++ encode (abForm v.ab) FB TB l) (fun _ => [])
    (fun l => by simp [x]) (fun l => by simp [lenE])
  have oL : ((List.range 32).all fun l => (x l).length == FA.regs + FB.regs + FC.regs) = true := by
    simp [x, lenE, Nat.add_assoc]
  refine ⟨_, mmaWarp_eq hv oL oA oB oC, ?_⟩
  intro i hi j hj
  have hi' : i < FC.rows := by omega
  have hj' : j < FC.cols := by omega
  obtain ⟨-, hr, hs, hpos⟩ := hC.2 i hi' j hj'
  simp only [Frag.gather, resElem]
  rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn]
  simp only [hr, dite_true, Option.getD_some]
  have hs' : (FC.own i j).2.2 < (accForm v.cd).pack := by omega
  rw [RegForm.elem, RegForm.get_put _ _ hs', Option.getD_some]
  have fA : ∀ k : Fin v.k, FA.gather (argElem (abForm v.ab) x 0) i k = TA i k := fun k =>
    Frag.gather_of_scatter hA eA (by omega) (by have := k.isLt; omega)
  have fB : ∀ k : Fin v.k, FB.gather (argElem (abForm v.ab) x FA.regs) k j = TB k j := fun k =>
    Frag.gather_of_scatter hB eB (by have := k.isLt; omega) (by omega)
  have fC : FC.gather (argElem (accForm v.cd) x (FA.regs + FB.regs)) i j = TC i j :=
    Frag.gather_of_scatter hC eC hi' hj'
  simp only [mmaStep, hpos, fA, fB, fC]

/-- The row address lane `R` passes to `ldmatrix` among the lanes' arguments `x`: its one
argument when that is a pointer, `none` otherwise. -/
def ldmRow (x : Nat → List Val) (R : Nat) : Option Ptr :=
  match x R with
  | [.ptr p] => some p
  | _ => none

/-- Element `C` of row `R` of an `ldmatrix` source: `rd` at lane `R`'s row address plus `2 C`
bytes (`ldmRow`), `none` when the lane passes no pointer or the element does not read. -/
def ldmCell (rd : Ptr → Option Nat) (x : Nat → List Val) (R C : Nat) : Option Nat :=
  (ldmRow x R).bind fun p => rd ⟨p.block, p.off + 2 * C⟩

/-- The warp's `ldmatrix.sync.aligned.m8n8.x<q>.b16`, with `.trans` when `t`, from the 32 lanes'
arguments `x`: lane `R < 8q` passes the address of row `R` of the stacked tile as its one
argument, a pointer `p`; `rd p` is the 16-bit element at `p` (`none` when it may not be read).
Lane `l`'s result is the aggregate of its `q` registers in the form `pair`, element `s` of
register `r` the element at the row address plus `2 C`, `(R, C) = (ldm q t).pos l r s`, as
`ldmatrix` places it. `none` when a row's lane does not pass one pointer or an element of a row
does not read. -/
def ldmWarp (q : Nat) (t : Bool) (rd : Ptr → Option Nat) (x : Nat → List Val) :
    Option (Nat → Val) :=
  if (List.range (8 * q)).all fun R => (List.range 8).all fun C => (ldmCell rd x R C).isSome then
    some fun l => .agg (List.ofFn fun r : Fin q => RegForm.pair.put fun s =>
      (ldm q t).scatter (fun R C => (ldmCell rd x R C).getD 0) l r s)
  else none

/-- **The warp's `ldmatrix` loads the rows at the lanes' pointers**, for every count `q`, flag
`t`, reader `rd` and arguments `x`: when lane `R < 8q` passes the one pointer `P R` and the
element `C < 8` of its row reads as `T R C` below `2 ^ 16` (`rd` at `P R` plus `2 C`),
`ldmWarp` succeeds and its results, read in the layout `ldm q t` (`Frag.gather` of `resElem`),
are `T R C` at every cell `R < 8q`, `C < 8`. -/
theorem ldmWarp_spec {q : Nat} {t : Bool} {rd : Ptr → Option Nat} {x : Nat → List Val}
    {P : Nat → Ptr} {T : Nat → Nat → Nat} (hx : ∀ R < 8 * q, x R = [.ptr (P R)])
    (hrd : ∀ R < 8 * q, ∀ C : Nat, C < 8 → rd ⟨(P R).block, (P R).off + 2 * C⟩ = some (T R C))
    (hT : ∀ R C, T R C < 2 ^ 16) :
    ∃ y, ldmWarp q t rd x = some y ∧
      ∀ R < 8 * q, ∀ C < 8, (ldm q t).gather (resElem .pair y) R C = T R C := by
  have hcell : ∀ R < 8 * q, ∀ C < 8, ldmCell rd x R C = some (T R C) := by
    intro R hR C hC
    simp [ldmCell, ldmRow, hx R hR, hrd R hR C hC]
  have hok : ((List.range (8 * q)).all fun R => (List.range 8).all fun C =>
      (ldmCell rd x R C).isSome) = true := by
    simp only [List.all_eq_true, List.mem_range]
    intro R hR C hC
    simp [hcell R hR C hC]
  refine ⟨fun l => .agg (List.ofFn fun r : Fin q => RegForm.pair.put fun s =>
      (ldm q t).scatter (fun R C => (ldmCell rd x R C).getD 0) l r s), ?_, ?_⟩
  · simp only [ldmWarp, hok, ↓reduceIte]
  intro R hR C hC
  obtain ⟨-, hr, hs, hpos⟩ := (ldm_inv q t).2 R hR C hC
  have hr' : ((ldm q t).own R C).2.1 < q := hr
  have hs' : ((ldm q t).own R C).2.2 < RegForm.pair.pack := hs
  simp only [Frag.gather, resElem]
  rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn]
  simp only [hr', dite_true, Option.getD_some]
  rw [RegForm.elem_put _ _ hs']
  · simp only [Frag.scatter, hpos, hcell R hR C hC, Option.getD_some]
  · simp only [Frag.scatter, hpos, hcell R hR C hC, Option.getD_some, RegForm.width]
    exact hT R C

/-- Arguments that agree below lane 32 pass the same check over the 32 lanes. -/
private theorem all32_congr {x x' : Nat → List Val} (h : ∀ l < 32, x l = x' l)
    (P : List Val → Bool) :
    ((List.range 32).all fun l => P (x l)) = (List.range 32).all fun l => P (x' l) := by
  rw [Bool.eq_iff_iff]
  simp only [List.all_eq_true, List.mem_range]
  exact forall_congr' fun l => imp_congr_right fun hl => by rw [h l hl]

/-- `mmaWarp` reads the lanes' arguments below lane 32 only, for every `Mma` value and
accumulation: on arguments that agree there it gives the same results. -/
private theorem mmaWarp_lanes {v : Mma} {acc : (Fin v.k → Nat) → (Fin v.k → Nat) → Nat → Nat}
    {x x' : Nat → List Val} (h : ∀ l < 32, x l = x' l) : mmaWarp v acc x = mmaWarp v acc x' := by
  have he : ∀ f off l r s, l < 32 → argElem f x off l r s = argElem f x' off l r s :=
    fun f off l r s hl => by simp only [argElem, h l hl]
  have e2 : ∀ f off k, argsOk f x off k = argsOk f x' off k := fun f off k =>
    all32_congr h fun xl => (List.range k).all fun r => f.ok (xl.getD (off + r) .poison)
  unfold mmaWarp
  cases hv : mmaFrags v with
  | none => rfl
  | some F =>
    obtain ⟨FA, FB, FC⟩ := F
    dsimp only
    have e1 : ((List.range 32).all fun l => (x l).length == FA.regs + FB.regs + FC.regs) =
        ((List.range 32).all fun l => (x' l).length == FA.regs + FB.regs + FC.regs) :=
      all32_congr h fun xl => xl.length == FA.regs + FB.regs + FC.regs
    rw [e1, e2, e2, e2]
    simp only [mmaFrags] at hv
    split_ifs at hv
    simp only [Option.some.injEq, Prod.mk.injEq] at hv
    obtain ⟨rfl, rfl, rfl⟩ := hv
    congr 1
    congr 1
    funext l
    congr 2
    funext r
    congr 1
    funext s
    dsimp only [mmaStep, Frag.gather, fragA, fragB, fragC]
    congr 1
    · funext k
      apply he
      omega
    · funext k
      apply he
      omega
    · apply he
      omega

/-- `mmaGrid` reads the lanes' arguments below lane 32 only, for every policy and `Mma` value:
on arguments that agree there it gives the same results. -/
private theorem mmaGrid_lanes {A : MmaAcc} {v : Mma} {x x' : Nat → List Val}
    (h : ∀ l < 32, x l = x' l) : mmaGrid A v x = mmaGrid A v x' := by
  have e3 : ∀ f F off fi, allFinite fi F (argElem f x off) = allFinite fi F (argElem f x' off) :=
    fun f F off fi => all32_congr h fun xl => (List.range F.regs).all fun r =>
      (List.range F.pack).all fun s => wordFinite fi (f.elem (xl.getD (off + r) .poison) s)
  unfold mmaGrid
  rcases gridFmt v.ab with _ | fi <;> rcases mmaFrags v with _ | ⟨FA, FB, FC⟩ <;>
    simp only [e3, mmaWarp_lanes h]

/-- The callee's return attributes give an aggregate of words back, for every layout, memory and
return type, when none of them is a `range`, `nonnull` or `align`, the attributes `withAttrs`
refuses on an aggregate. -/
private theorem withAttrs_agg {l : Layout} {m : Mem} {t : Ty} {attrs : List Attr} {rs : List Val}
    (hrs : ∀ r ∈ rs, ∃ w b, r = .bits w b)
    (ha : ∀ a ∈ attrs, (∀ t lo hi, a ≠ .range t lo hi) ∧ a ≠ .flag "nonnull" ∧
      ∀ k, a ≠ .int "align" k) :
    withAttrs l m t attrs (.agg rs) = .ok (.agg rs) := by
  have hd : (Val.agg rs).defined = true := by
    simp only [Val.defined]
    induction rs with
    | nil => rfl
    | cons r rs ih =>
      obtain ⟨w, b, rfl⟩ := hrs r List.mem_cons_self
      simp only [Val.allDefined, Val.defined, Bool.true_and]
      exact ih fun r' h => hrs r' (List.mem_cons_of_mem _ h)
  unfold withAttrs
  dsimp only
  split
  · contradiction
  refine Except.bind_eq_ok.2 ⟨Val.agg rs, ?_, ?_⟩
  · clear hd
    induction attrs with
    | nil => rfl
    | cons a as ih =>
      rw [List.foldlM_cons]
      obtain ⟨h1, h2, h3⟩ := ha a List.mem_cons_self
      have e := ih fun a' h => ha a' (List.mem_cons_of_mem _ h)
      cases a with
      | range t' lo hi => exact absurd rfl (h1 t' lo hi)
      | int s k =>
        by_cases hs : s = "align"
        · subst hs; exact absurd rfl (h3 k)
        · split <;> first | exact e | (rename_i heq; simp_all)
      | flag s =>
        by_cases hs : s = "nonnull"
        · subst hs; exact absurd rfl h2
        · split <;> first | exact e | (rename_i heq; simp_all)
      | _ => exact e
  · simp only [hd, Bool.not_true, Bool.and_false]
    rfl

/-- Setting the indices `ks` of an array in turn, index `j` to `f j`: index `k` holds `f k` when
it is one of `ks` and within the array's bounds, and is unchanged otherwise, for every array,
indices and values. -/
private theorem getElem?_foldl_set {α : Type} (f : Nat → α) (k : Nat) :
    ∀ (ks : List Nat) (a : Array α), (ks.foldl (fun a j => a.set! j (f j)) a)[k]? =
      if k ∈ ks ∧ k < a.size then some (f k) else a[k]?
  | [], a => by simp
  | j :: ks, a => by
    rw [List.foldl_cons, getElem?_foldl_set f k ks, Array.set!_eq_setIfInBounds,
      Array.size_setIfInBounds, Array.getElem?_setIfInBounds]
    by_cases hk : k < a.size <;> by_cases hj : j = k <;> by_cases hm : k ∈ ks <;>
      simp [hk, hj, hm, Ne.symm]

/-- **A grid step at a warp's `mma` resumes the warp with its D registers of the launch's policy
on the tiles**, for every launch `L` (so for every accumulation policy `L.acc`), contexts `c`,
grid `g`, thread `n` and every `mma` of the table with bf16 or f16 inputs and an f32 accumulator
(`mmaFrags v = some (FA, FB, FC)`, `gridFmt v.ab = some fi`, `v.cd = .float`): when `n`'s warp,
the threads from `base = n - n % volume L.block % 32`, lies whole in its block of threads and
each lane `j < 32` waits, from thread `u j`, at that `mma` at the instruction lane
`n % volume L.block % 32` is at, with its A, B and C registers encoding tiles `TA`, `TB`, `TC`
of finite words (`encode`, `wordFinite`) and a callee `d j` none of whose return attributes is a
`range`, `nonnull` or `align` (the attributes `withAttrs` refuses on an aggregate), the grid's
step at `n` (`Grid.fire`) succeeds with a grid `g'` on the same memory in which every thread
outside the warp is unchanged and lane `j` runs `(u j).resume (some (y j))`, and `y`, read in
the layout `FC` (`Frag.gather` of `resElem`), is `L.acc.bits fi (TA i ·) (TB · j) (TC i j)` at
every cell `i < v.m`, `j < 8`. -/
theorem Grid.fire_mma {L : Launch} {c : Nat → Ctx} {g : Grid} {n : Nat} {v : Mma} {FA FB FC : Frag}
    {fi : FloatLib.Floats.Formats.BinaryInterchange.FloatFormat}
    (hv : mmaFrags v = some (FA, FB, FC)) (hfi : gridFmt v.ab = some fi) (hcd : v.cd = .float)
    (hb : n % volume L.block - n % volume L.block % 32 + 32 ≤ volume L.block)
    (TA TB TC : Nat → Nat → Nat)
    (hTA : ∀ i j, TA i j < 2 ^ (abForm v.ab).width ∧ wordFinite fi (TA i j) = true)
    (hTB : ∀ i j, TB i j < 2 ^ (abForm v.ab).width ∧ wordFinite fi (TB i j) = true)
    (hTC : ∀ i j, TC i j < 2 ^ 32 ∧ wordFinite .binary32 (TC i j) = true)
    {u : Nat → Thread} {d : Nat → Func}
    (hl : ∀ j < 32, g.threads[n - n % volume L.block % 32 + j]? =
      some (.wait (u j) (.mma v) (encode (abForm v.ab) FA TA j ++ encode (abForm v.ab) FB TB j ++
        encode (accForm v.cd) FC TC j) (d j)) ∧ (u j).at = (u (n % volume L.block % 32)).at)
    (hd : ∀ j < 32, ∀ a ∈ (d j).retAttrs, (∀ t lo hi, a ≠ .range t lo hi) ∧
      a ≠ .flag "nonnull" ∧ ∀ k, a ≠ .int "align" k) :
    ∃ y g', g.fire L c n = .ok (some g') ∧ g'.mem = g.mem ∧
      (∀ k, k < n - n % volume L.block % 32 ∨ n - n % volume L.block % 32 + 32 ≤ k →
        g'.threads[k]? = g.threads[k]?) ∧
      (∀ j < 32, g'.threads[n - n % volume L.block % 32 + j]? =
        some (.run ((u j).resume (some (y j))))) ∧
      ∀ i < v.m, ∀ j < 8, FC.gather (resElem (accForm v.cd) y) i j =
        L.acc.bits fi (fun k : Fin v.k => TA i k) (fun k : Fin v.k => TB k j) (TC i j) := by
  have hw32 : (accForm v.cd).width = 32 := by rw [hcd]; rfl
  obtain ⟨pA, pB, pC⟩ := mmaFrags_pack hv
  set base := n - n % volume L.block % 32 with hbase
  set lane := n % volume L.block % 32 with hlane
  have hlane32 : lane < 32 := Nat.mod_lt _ (by decide)
  have hbn : base + lane = n := by
    have := Nat.mod_le (n % volume L.block) 32
    have := Nat.mod_le n (volume L.block)
    omega
  set X : Nat → List Val := fun l => encode (abForm v.ab) FA TA l ++
    encode (abForm v.ab) FB TB l ++ encode (accForm v.cd) FC TC l with hX
  have lenE : ∀ (f : RegForm) (F : Frag) (T : Nat → Nat → Nat) l,
      (encode f F T l).length = F.regs :=
    fun _ _ _ _ => by simp [encode]
  have eA := argElem_encode (f := abForm v.ab) (F := FA) (T := TA) (x := X) (off := 0) (fun _ => [])
    (fun l => encode (abForm v.ab) FB TB l ++ encode (accForm v.cd) FC TC l)
    (fun l => by simp [X, List.append_assoc]) (fun _ => rfl) (fun i j => (hTA i j).1) pA.le
  have eB := argElem_encode (f := abForm v.ab) (F := FB) (T := TB) (x := X) (off := FA.regs)
    (fun l => encode (abForm v.ab) FA TA l) (fun l => encode (accForm v.cd) FC TC l)
    (fun _ => rfl) (fun l => lenE _ _ _ l) (fun i j => (hTB i j).1) pB.le
  have eC := argElem_encode (f := accForm v.cd) (F := FC) (T := TC) (x := X)
    (off := FA.regs + FB.regs)
    (fun l => encode (abForm v.ab) FA TA l ++ encode (abForm v.ab) FB TB l) (fun _ => [])
    (fun l => by simp [X]) (fun l => by simp [lenE]) (fun i j => hw32 ▸ (hTC i j).1) pC.le
  have fin : ∀ (f : RegForm) (F : Frag) (off : Nat)
      (fm : FloatLib.Floats.Formats.BinaryInterchange.FloatFormat) (T : Nat → Nat → Nat),
      (∀ l < 32, ∀ r < F.regs, ∀ s < F.pack,
        argElem f X off l r s = T (F.pos l r s).1 (F.pos l r s).2) →
      (∀ i j, wordFinite fm (T i j) = true) → allFinite fm F (argElem f X off) = true := by
    intro f F off fm T he hT
    simp only [allFinite, List.all_eq_true, List.mem_range]
    intro l hl r hr s hs
    rw [he l hl r hr s hs]
    exact hT _ _
  obtain ⟨y, hy, hspec⟩ := mmaWarp_spec hv (L.acc.bits fi) TA TB TC (fun i j => (hTA i j).1)
    (fun i j => (hTB i j).1) (fun i j => hw32 ▸ (hTC i j).1)
  have hgrid : mmaGrid L.acc v X = some y := by
    unfold mmaGrid
    rw [hfi, hv]
    dsimp only
    rw [ite_eq_left ⟨hcd, fin _ _ _ _ _ eA fun i j => (hTA i j).2,
      fin _ _ _ _ _ eB fun i j => (hTB i j).2, fin _ _ _ _ _ eC fun i j => (hTC i j).2⟩]
    exact hy
  have hx' : ∀ l < 32, X l = ((List.range 32).map X).getD l [] := fun l hl => by
    simp [hl]
  have hsome : ∀ (ns : List Nat) (F : Nat → List Val),
      (ns.map fun j => some (F j)).mapM id = some (ns.map F) := fun ns F => by
    induction ns <;> simp_all
  have hres : mmaRes L.acc ((List.range 32).map fun j => g.threads[base + j]?) (u lane).at v =
      .ok (some y) := by
    unfold mmaRes
    rw [List.mapM_map, mapM_congr (g := fun j => pure (some (X j))) fun j hj => ?_,
      List.mapM_pure]
    · simp only [bind, Except.bind, pure, Except.pure, hsome, ← mmaGrid_lanes hx', hgrid]
    · obtain ⟨e, ht'⟩ := hl j (List.mem_range.1 hj)
      simp only [Function.comp_apply, e]
      rw [ite_eq_left ⟨trivial, ht'⟩]
  have hn : g.threads[n]? = some (.wait (u lane) (.mma v) (X lane) (d lane)) := by
    rw [← hbn]
    exact (hl lane hlane32).1
  have hnd : ((List.range 32).map (base + ·)).Nodup :=
    List.nodup_range.map fun _ _ => Nat.add_left_cancel
  have hmem : ∀ k, k ∈ (List.range 32).map (base + ·) ↔ base ≤ k ∧ k < base + 32 := fun k => by
    simp only [List.mem_map, List.mem_range]
    constructor
    · rintro ⟨j, hj, rfl⟩
      omega
    · intro h
      exact ⟨k - base, by omega, by omega⟩
  have hwait : ∀ k ∈ (List.range 32).map (base + ·), ∃ i as d', g.threads[k]? =
      some (.wait (u (k - base)) i as d') ∧ (some (y (k - base))).mapM
        (withAttrs (c n).prog.layout g.mem d'.ret d'.retAttrs) = .ok (some (y (k - base))) := by
    intro k hk
    obtain ⟨j, hj, rfl⟩ := List.mem_map.1 hk
    have hj' := List.mem_range.1 hj
    obtain ⟨rs, hrs, hbits⟩ := mmaGrid_agg hgrid j
    refine ⟨_, _, _, by rw [Nat.add_sub_cancel_left]; exact (hl j hj').1, ?_⟩
    rw [Nat.add_sub_cancel_left, hrs]
    simp [Option.mapM_some, withAttrs_agg hbits (hd j hj')]
  refine ⟨y, { g with
      threads := ((List.range 32).map (base + ·)).foldl
        (fun ts k => ts.set! k (.run ((u (k - base)).resume (some (y (k - base)))))) g.threads },
    ?_, rfl, fun k hk => ?_, fun j hj => ?_, fun i hi j hj => ?_⟩
  · unfold Grid.fire
    simp only [hn, ← hbase, ← hlane, hb, ↓reduceIte, bind, Except.bind, pure, Except.pure, hres]
    rw [Sym.resumeAll_eq hnd hwait]
  · dsimp only
    rw [getElem?_foldl_set (fun k => Status.run ((u (k - base)).resume (some (y (k - base))))),
      ite_eq_right fun h => by have := (hmem k).1 h.1; omega]
  · dsimp only
    have hin : base + j < g.threads.size := by
      have e := (hl j hj).1
      rw [Array.getElem?_eq_some_iff] at e
      exact e.1
    rw [getElem?_foldl_set (fun k => Status.run ((u (k - base)).resume (some (y (k - base))))),
      ite_eq_left ⟨(hmem _).2 ⟨by omega, by omega⟩, hin⟩, Nat.add_sub_cancel_left]
  · rw [hspec i hi j hj, hw32]
    exact Nat.mod_eq_of_lt (by unfold MmaAcc.bits; exact BitVec.isLt _)

end MojoProof.Sem
