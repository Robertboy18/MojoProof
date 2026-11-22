import MojoProof.Sem.Labels
import MojoProof.Sem.Confluence

/-!
# T3b's statement and block-entry lemmas (`exec_skel`, `enter_skel`)

The step of docs/proofs/payload.md section T3b for one statement: two runs that differ in the
payload only execute it in lockstep. For every labelling `lab` and payload blocks `pay` (`Labels`,
`Mem.SkelEq`), context, oracle `o`, thread position `k`, frames related by `Frame.Skel` and
memories by `Mem.SkelEq`, a program that passes `Labels.Ok` and a statement that passes
`Labels.stmtOk` and meets `Labels.MemAt`, `exec` under the context and under it with oracle `o`
gives one fault or effects related by `Eff.Skel` (`exec_skel`): frames and memories related, a
payload result register holding related values and a skeleton one equal values; calls of one
function with arguments related at its payload parameters; waits at one intrinsic with arguments
equal after `Intrinsic.eraseArgs`.

Each row of `exec` goes through the lemma of payload.md's table: operands by `evalV_skel` (a
skeleton operand gives one result) and `evalV_pay` (a payload operand of `TValue.payOk` gives
related results); `bin` by `lanes2_skel` and `intBin_skel`, `fbin` by `floatBin_skel`, `fneg`
by `fnegV_skel`, `icmp` and `fcmp` by `icmpV_skel` and `fcmpV_skel`, casts by `castV_skel` (and,
for a skeleton result, `castV_ch`), `select`, `extractvalue`, `insertvalue`, `extractelement`,
`insertelement` and `shufflevector` by their lemmas; `getelementptr` and `alloca` on skeleton
operands by `gep_shape` and `Mem.alloc_skel`; `load`, `store` and `atomicrmw` by `Mem.load_skel`,
`Mem.store_skel` and `rmw_skel`, with `Labels.MemAt` for the block; `call` by `exec_call_skel`
(`withAttrs_skel` for payload arguments and results, `fminmax_skel`, `rsqrt_skel`,
`intrinsic_skel`, `shfl_erase`). `phi` is refused by `exec` in both runs (it is `enter`'s).

The step for a branch to block `dest`: for the same labelling, payload blocks, context, oracle,
thread position, related frames and memories, if the frames' function passes `Labels.funcOk`,
`enter` gives one fault or frames related by `Frame.Skel` (`enter_skel`). Its `phi`s take their
values by `evalV_skel` (skeleton result) or `evalV_pay` (payload result), and are set in turn
(`Frame.Skel.setAll`, by `Frame.Skel.set`); the frames then move to the head of `dest`
(`Frame.Skel.goto`).

The lemmas cover every program, statement or block, context, oracle and pair of related states;
they need no condition on the kernel's parameters.

Tests (MojoProofTest/SkelExec.lean):
- `exec_inst`: the instance, an `add` of a payload register into a payload register, on two
  frames whose payload words differ, gives related effects (the words 8 and 9, `add_eval`);
- `exec_twin`: the twin of `Labels.stmtOk`, the same `add` into a skeleton register fails it and
  gives effects that `Eff.Skel` does not relate;
- `exec_mem_twin`: the twin of `Labels.MemAt`, a `store` of a payload register to a block that is
  not payload meets every other premise and gives memories that `Mem.SkelEq` does not relate;
- `exec_call_twin`: the twin of `Labels.Ok`, a call that passes a payload register to a parameter
  with a `range` attribute passes `Labels.stmtOk` and gives arguments 1 and `poison`, which
  `Eff.Skel` does not relate;
- `enter_inst`: the instance of `enter_skel`, a `phi` of a payload register into a payload
  register, on two frames whose payload words differ, gives related frames (`enter_eval`);
- `enter_twin`: the twin of `Labels.funcOk`, the same `phi` into a skeleton register fails it and
  gives frames that `Frame.Skel` does not relate.
-/

namespace MojoProof.Sem
open LLVM

/-- Effects of one statement in two runs, related under labelling `lab` and payload blocks `pay`
for a statement whose result is payload when `p`: `next` with frames related by `Frame.Skel` and
memories by `Mem.SkelEq`; `call` of one function with arguments related by `Val.Skel` at its
payload parameters and equal at the others; `wait` at one intrinsic declared by one function, with
arguments equal after `Intrinsic.eraseArgs` when `p` and equal when not. -/
def Eff.Skel (lab : Labels) (pay : Nat → Prop) (p : Bool) : Eff → Eff → Prop
  | .next f₁ m₁, .next f₂ m₂ => f₁.Skel lab f₂ ∧ m₁.SkelEq pay m₂
  | .call g₁ a₁, .call g₂ a₂ => g₁ = g₂ ∧ ∀ j : Nat, Option.Rel
      (Labels.Rel ((g₁.params[j]?).any fun q : Param => q.name.any (lab.reg g₁.name)) Val.Skel)
      a₁[j]? a₂[j]?
  | .wait i₁ a₁ f₁, .wait i₂ a₂ f₂ =>
    i₁ = i₂ ∧ f₁ = f₂ ∧ Labels.Rel p (fun a b => i₁.eraseArgs a = i₁.eraseArgs b) a₁ a₂
  | _, _ => False

/-- Values related by `Labels.Rel false` are equal. -/
theorem Labels.Rel.eq {α : Type} {R : α → α → Prop} {x y : α} (h : Labels.Rel false R x y) :
    x = y := h

/-- Options related by `Option.Rel (Labels.Rel false R)` are equal. -/
theorem Labels.Rel.option_eq {α : Type} {R : α → α → Prop} {x y : Option α}
    (h : Option.Rel (Labels.Rel false R) x y) : x = y := by
  cases h with
  | none => rfl
  | some h => exact congrArg some h

/-- Equal values are related by `Labels.Rel p R` when `p` is false. -/
theorem Labels.Rel.of_eq {α : Type} {R : α → α → Prop} {p : Bool} {x y : α} (hp : p = false)
    (h : x = y) : Labels.Rel p R x y := by
  subst hp; exact h

/-- Values related by `R` are related by `Labels.Rel p R` when `p` is true. -/
theorem Labels.Rel.of_rel {α : Type} {R : α → α → Prop} {p : Bool} {x y : α} (hp : p = true)
    (h : R x y) : Labels.Rel p R x y := by
  subst hp; exact h

/-- Results related by `Except.Rel R` are related by `Except.Rel S` when `R` implies `S`. -/
theorem _root_.Except.Rel.imp {ε α β : Type} {R S : α → β → Prop} (h : ∀ a b, R a b → S a b)
    {x : Except ε α} {y : Except ε β} (hr : Except.Rel R x y) : Except.Rel S x y := by
  cases hr with
  | error e => exact .error e
  | ok hr => exact .ok (h _ _ hr)

/-- For every computation `x` and functions `f₁` and `f₂` whose results are related by
`Except.Rel S` at each value `x` returns, `x >>= f₁` and `x >>= f₂` are related by it. -/
theorem _root_.Except.Rel.bind_eq {ε α γ δ : Type} {S : γ → δ → Prop} (x : Except ε α)
    {f₁ : α → Except ε γ} {f₂ : α → Except ε δ} (hf : ∀ a, x = .ok a → Except.Rel S (f₁ a) (f₂ a)) :
    Except.Rel S (x >>= f₁) (x >>= f₂) := by
  cases x with
  | error e => exact .error e
  | ok a => exact hf a rfl

/-- Options related by `Option.Rel R` are both `some` or both `none`. -/
theorem _root_.Option.Rel.isSome {α β : Type} {R : α → β → Prop} {o₁ : Option α} {o₂ : Option β}
    (h : Option.Rel R o₁ o₂) : o₁.isSome = o₂.isSome := by
  cases h <;> rfl

/-- Operands none of which mentions a register of `p` have `TValue.anyMentions p` false. -/
theorem TValue.anyMentions_of_all {p : Nat → Bool} : ∀ {vs : List TValue},
    vs.all (fun v => !v.mentions p) = true → TValue.anyMentions p vs = false
  | [], _ => rfl
  | v :: vs, h => by
    simp only [List.all_cons, Bool.and_eq_true, Bool.not_eq_true'] at h
    simp only [TValue.anyMentions, h.1, TValue.anyMentions_of_all h.2, Bool.or_false]

/-- For every scope, memory `m` related to its memory by `Mem.SkelEq`, registers `r` related to its
registers by `Labels.Rel (p n) Val.Skel` at each register `n`, choices `ch` and type, an operand
that passes `TValue.payOk p` gives one fault or values related by `Val.Skel` in the scope and in
it with memory `m`, registers `r` and choices `ch`. -/
theorem evalV_pay {pay : Nat → Prop} {s : Scope} {m : Mem} {r : Nat → Option Val}
    {ch : Nat → Nat} {p : Nat → Bool} (hm : s.mem.SkelEq pay m)
    (hr : ∀ n, Option.Rel (Labels.Rel (p n) Val.Skel) (s.regs n) (r n)) (t : Ty) {t' : Ty}
    {v : Value} (hv : TValue.payOk p ⟨t', v⟩ = true) :
    Except.Rel Val.Skel (evalV s t v) (evalV { s with mem := m, regs := r, ch := ch } t v) := by
  have hr' : ∀ n, p n = false → r n = s.regs n := fun n hn =>
    (Labels.Rel.option_eq (hn ▸ hr n)).symm
  cases v
  case loc n =>
    have h := hr n
    simp only [evalV]
    generalize s.regs n = a at h ⊢
    generalize r n = b at h ⊢
    cases h with
    | none => exact .error _
    | some h =>
      refine .ok ?_
      cases hp : p n
      · rw [hp] at h; exact (Labels.Rel.eq h) ▸ .refl _
      · rw [hp] at h; exact h
  all_goals
    rw [(evalV_skel hm hr').1 _ _ (by simpa [TValue.payOk, TValue.mentions] using hv)]
    exact .refl Val.Skel.refl _

/-- Frames related by `Frame.Skel` stay related after setting register `r` (if any) to options `v₁`
and `v₂`, and its `fmul contract` operands to `p₁` and `p₂`, related by `Labels.Rel` at `r`'s
label. -/
theorem Frame.Skel.set {lab : Labels} {f₁ f₂ : Frame} (hf : f₁.Skel lab f₂) {r : Option Nat}
    {v₁ v₂ : Option Val} {p₁ p₂ : Option (Val × Val)}
    (hv : Option.Rel (Labels.Rel (r.any (lab.reg f₁.fn.name)) Val.Skel) v₁ v₂)
    (hp : Option.Rel (Labels.Rel (r.any (lab.reg f₁.fn.name)) fun a b => a.1.Skel b.1 ∧
      a.2.Skel b.2) p₁ p₂) :
    Frame.Skel lab (f₁.set r v₁ p₁) (f₂.set r v₂ p₂) := by
  cases r with
  | none => exact hf
  | some n =>
    cases hv with
    | none => exact hf
    | some hv =>
      refine ⟨hf.shape, fun q => ?_, fun q => ?_⟩
      · simp only [Frame.set]
        split
        · subst q; exact .some hv
        · exact hf.regs q
      · simp only [Frame.set]
        split
        · subst q; exact hp
        · exact hf.prods q

/-- Frames related by `Frame.Skel` stay related after a statement that sets result register `r` (if
any) to options `v₁` and `v₂`, and its `fmul contract` operands to `p₁` and `p₂`, related by
`Labels.Rel` at `r`'s label, and moves to the next statement (`Frame.Skel.set`). -/
theorem Frame.Skel.next {lab : Labels} {f₁ f₂ : Frame} (hf : f₁.Skel lab f₂) {r : Option Nat}
    {v₁ v₂ : Option Val} {p₁ p₂ : Option (Val × Val)}
    (hv : Option.Rel (Labels.Rel (r.any (lab.reg f₁.fn.name)) Val.Skel) v₁ v₂)
    (hp : Option.Rel (Labels.Rel (r.any (lab.reg f₁.fn.name)) fun a b => a.1.Skel b.1 ∧
      a.2.Skel b.2) p₁ p₂) :
    Frame.Skel lab { f₁.set r v₁ p₁ with pc := f₁.pc + 1 }
      { f₂.set r v₂ p₂ with pc := f₂.pc + 1 } := by
  have h := hf.set hv hp
  have e := hf.shape
  have e' := h.shape
  simp only [Frame.mk.injEq] at e e'
  refine ⟨?_, h.regs, h.prods⟩
  simp only [Frame.mk.injEq]
  exact ⟨e'.1, e'.2.1, by rw [e.2.2.1], e'.2.2.2⟩

/-- Frames related by `Frame.Skel` stay related after a statement with no result. -/
theorem Frame.Skel.succ {lab : Labels} {f₁ f₂ : Frame} (hf : f₁.Skel lab f₂) :
    Frame.Skel lab { f₁ with pc := f₁.pc + 1 } { f₂ with pc := f₂.pc + 1 } :=
  hf.next (r := none) (v₁ := none) (v₂ := none) (p₁ := none) (p₂ := none) .none .none

/-- Frames related by `Frame.Skel` stay related after an `alloca` that sets register `r` (if any)
to `v` and records block `b` in both. -/
theorem Frame.Skel.alloca {lab : Labels} {f₁ f₂ : Frame} (hf : f₁.Skel lab f₂) (r : Option Nat)
    (v : Val) (b : Nat) :
    Frame.Skel lab { f₁.set r (some v) none with pc := f₁.pc + 1, allocas := b :: f₁.allocas }
      { f₂.set r (some v) none with pc := f₂.pc + 1, allocas := b :: f₂.allocas } := by
  have h := hf.next (r := r) (p₁ := none) (p₂ := none) (.some (Labels.Rel.refl Val.Skel.refl _ v))
    .none
  have e := hf.shape
  have e' := h.shape
  simp only [Frame.mk.injEq] at e e'
  refine ⟨?_, h.regs, h.prods⟩
  simp only [Frame.mk.injEq]
  exact ⟨e'.1, e'.2.1, e'.2.2.1, trivial, trivial, by rw [e.2.2.2.2.2.1], e'.2.2.2.2.2.2⟩

/-- Two `if`s on one decidable condition are related by `Except.Rel R` when their `then` branches
are, under the condition, and their `else` branches are, under its negation. -/
theorem _root_.Except.Rel.ite {ε α β : Type} {R : α → β → Prop} {c : Prop} [Decidable c]
    {a₁ b₁ : Except ε α} {a₂ b₂ : Except ε β} (h₁ : c → Except.Rel R a₁ a₂)
    (h₂ : ¬c → Except.Rel R b₁ b₂) :
    Except.Rel R (if c then a₁ else b₁) (if c then a₂ else b₂) := by
  by_cases hc : c
  · simp only [hc, ↓reduceIte]; exact h₁ hc
  · simp only [hc, ↓reduceIte]; exact h₂ hc

/-- A value whose address (`Val.addr?`) is `q` is the pointer `q`. -/
theorem Val.addr?_eq {x : Val} {q : Ptr} (h : x.addr? = .ok q) : x = .ptr q := by
  cases x <;> first | (cases h; done) | (cases h; rfl)

/-- Values related by `Val.Skel` are both scalars of width `w` (`Val.Scalar`) or neither. -/
theorem Val.Skel.scalar {x y : Val} (h : x.Skel y) (w : Nat) : x.Scalar w ↔ y.Scalar w := by
  rcases x with _ | _ | _ | _ | _ | _ <;> rcases y with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at h; done)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj h)
  all_goals simp only [Val.Scalar, Val.bits.injEq, reduceCtorEq, exists_const, or_false,
    false_or, iff_self]
  constructor <;> rintro ⟨_, rfl, _⟩ <;> exact ⟨_, rfl, .rfl⟩

/-- For every signedness and direction, `intMinMax` on values related by `Val.Skel` gives one fault
or related results. -/
theorem intMinMax_skel (signed max : Bool) {x₁ x₂ y₁ y₂ : Val} (hx : x₁.Skel x₂)
    (hy : y₁.Skel y₂) :
    Except.Rel Val.Skel (intMinMax signed max x₁ y₁) (intMinMax signed max x₂ y₂) := by
  rcases x₁ with _ | _ | _ | _ | _ | _ <;> rcases x₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hx; done)
  all_goals rcases y₁ with _ | _ | _ | _ | _ | _ <;> rcases y₂ with _ | _ | _ | _ | _ | _
  all_goals try (exfalso; simp [Val.Skel, Val.erase] at hy; done)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hx)
  all_goals try (obtain ⟨rfl, -⟩ := Val.bits.inj hy)
  all_goals simp only [intMinMax, strict2]
  all_goals first
    | exact .error _
    | exact .ok rfl
    | (split_ifs <;> first | exact .ok rfl | exact .error _)

/-- For every width and `atomicrmw` operation, `rmw` on values related by `Val.Skel` gives one
fault or related results. -/
theorem rmw_skel (w : Nat) (op : RmwOp) {x₁ x₂ y₁ y₂ : Val} (hx : x₁.Skel x₂) (hy : y₁.Skel y₂) :
    Except.Rel Val.Skel (rmw w op x₁ y₁) (rmw w op x₂ y₂) := by
  cases op
  all_goals first
    | exact intBin_skel w rfl hx hy nofun
    | exact intMinMax_skel _ _ hx hy
    | exact .error _

/-- The operand type of an `atomicrmw` that passes `Stmt.checkAtomic` is a data type (`Ty.data`). -/
theorem Stmt.checkAtomic_data {fn : Func} {res : Option Nat} {vol : Bool} {op : RmwOp}
    {p : TValue} {t : Ty} {v : Value} {sc : Option String} {ord : LLVM.Ordering} {al : Option Nat}
    {md : List (String × Nat)}
    (h : Stmt.checkAtomic fn ⟨res, .atomicrmw vol op p ⟨t, v⟩ sc ord al, md⟩ = .ok ()) :
    t.data = true := by
  obtain ⟨w, rfl, h8, hp⟩ :=
    Stmt.checkAtomic_int (st := ⟨res, .atomicrmw vol op p ⟨t, v⟩ sc ord al, md⟩) rfl h
  have e := Layout.eight_mul_stored {} h8 hp
  simp only [Ty.data, beq_iff_eq]
  omega

/-- `Except.Rel.bind` whose continuation also knows that the first computation returned `a`. -/
theorem _root_.Except.Rel.bind_ok {ε α β γ δ : Type} {R : α → β → Prop} {S : γ → δ → Prop}
    {x₁ : Except ε α} {x₂ : Except ε β} (h : Except.Rel R x₁ x₂) {f₁ : α → Except ε γ}
    {f₂ : β → Except ε δ} (hf : ∀ a b, x₁ = .ok a → R a b → Except.Rel S (f₁ a) (f₂ b)) :
    Except.Rel S (x₁ >>= f₁) (x₂ >>= f₂) := by
  cases h with
  | error e => exact .error e
  | ok h => exact hf _ _ rfl h

/-- Options related by `Option.Rel R`, mapped by functions that take `R` to `S`, are related by
`Option.Rel S`. -/
theorem _root_.Option.Rel.map {α β γ δ : Type} {R : α → β → Prop} {S : γ → δ → Prop}
    {f : α → γ} {g : β → δ} (hf : ∀ a b, R a b → S (f a) (g b)) :
    ∀ {x : Option α} {y : Option β}, Option.Rel R x y → Option.Rel S (x.map f) (y.map g)
  | _, _, .none => .none
  | _, _, .some h => .some (hf _ _ h)

/-- Options related by `Option.Rel R` are related by `Option.Rel S` when `R` implies `S`. -/
theorem _root_.Option.Rel.imp {α β : Type} {R S : α → β → Prop} (h : ∀ a b, R a b → S a b)
    {x : Option α} {y : Option β} (hr : Option.Rel R x y) : Option.Rel S x y := by
  simpa using Option.Rel.map h hr

/-- `Option.mapM` of functions whose results are related by `Except.Rel S` on arguments related by
`R`, on options related by `Option.Rel R`, gives results related by `Except.Rel (Option.Rel S)`. -/
theorem _root_.Option.Rel.mapM {ε α β γ δ : Type} {R : α → β → Prop} {S : γ → δ → Prop}
    {f : α → Except ε γ} {g : β → Except ε δ} (hf : ∀ a b, R a b → Except.Rel S (f a) (g b)) :
    ∀ {x : Option α} {y : Option β}, Option.Rel R x y →
      Except.Rel (Option.Rel S) (x.mapM f) (y.mapM g)
  | _, _, .none => .ok .none
  | _, _, .some h => (hf _ _ h).map fun _ _ h => .some h

/-- `List.mapM` of functions whose results are related by `Except.Rel (S j)` on arguments related
by `R j`, on lists related at each index `j` by `R j`, gives one fault or lists related at each
index `j` by `S j`. -/
theorem _root_.Except.Rel.mapIdx {ε α β γ δ : Type} {R : Nat → α → β → Prop}
    {S : Nat → γ → δ → Prop} {f : α → Except ε γ} {g : β → Except ε δ}
    (hf : ∀ j a b, R j a b → Except.Rel (S j) (f a) (g b)) {xs : List α} {ys : List β}
    (h : ∀ j, Option.Rel (R j) xs[j]? ys[j]?) :
    Except.Rel (fun us vs => ∀ j, Option.Rel (S j) us[j]? vs[j]?) (xs.mapM f) (ys.mapM g) := by
  induction xs generalizing ys R S with
  | nil =>
    cases ys with
    | nil => exact .ok fun _ => .none
    | cons =>
      have h0 := h 0
      simp only [List.getElem?_nil, List.getElem?_cons_zero] at h0
      cases h0
  | cons x xs ih =>
    cases ys with
    | nil =>
      have h0 := h 0
      simp only [List.getElem?_nil, List.getElem?_cons_zero] at h0
      cases h0
    | cons y ys =>
      have h0 := h 0
      simp only [List.getElem?_cons_zero] at h0
      obtain ⟨h0⟩ := h0
      simp only [List.mapM_cons]
      refine (hf 0 _ _ h0).bind fun u v hc => (ih (R := fun j => R (j + 1))
        (S := fun j => S (j + 1)) (fun j => hf (j + 1))
        (fun j => by simpa only [List.getElem?_cons_succ] using h (j + 1))).bind
        fun us vs hcs => .ok fun j => ?_
      cases j with
      | zero => simpa only [List.getElem?_cons_zero] using Option.Rel.some hc
      | succ j => simpa only [List.getElem?_cons_succ] using hcs j

/-- Each list is related to itself at index `j` by equality with its `j`-th element. -/
theorem _root_.List.rel_self {α : Type} (l : List α) (j : Nat) :
    Option.Rel (fun a b => a = b ∧ l[j]? = some a) l[j]? l[j]? := by
  cases h : l[j]? with
  | none => exact .none
  | some a => exact .some ⟨rfl, rfl⟩

/-- Lists related at each index by `R` and lists related at each index by `S` zip to lists related
at index `j` by `R j` on the first components and `S j` on the second. -/
theorem _root_.List.rel_zip {α β γ δ : Type} {R : Nat → α → β → Prop}
    {S : Nat → γ → δ → Prop} {xs : List α} {ys : List β} {us : List γ} {vs : List δ}
    (h₁ : ∀ j, Option.Rel (R j) xs[j]? ys[j]?) (h₂ : ∀ j, Option.Rel (S j) us[j]? vs[j]?)
    (j : Nat) :
    Option.Rel (fun a b => R j a.1 b.1 ∧ S j a.2 b.2) (xs.zip us)[j]? (ys.zip vs)[j]? := by
  rw [List.zip_eq_zipWith, List.zip_eq_zipWith, List.getElem?_zipWith, List.getElem?_zipWith]
  have e₁ := h₁ j
  have e₂ := h₂ j
  revert e₁ e₂
  generalize xs[j]? = a₁
  generalize ys[j]? = b₁
  generalize us[j]? = a₂
  generalize vs[j]? = b₂
  rintro (_ | _) (_ | _)
  all_goals first | exact .none | exact .some ⟨‹_›, ‹_›⟩

/-- Lists related by `R` at every index are related by `List.Forall₂ R`. -/
theorem _root_.List.forall₂_of_rel {α β : Type} {R : α → β → Prop} :
    ∀ {xs : List α} {ys : List β}, (∀ j : Nat, Option.Rel R xs[j]? ys[j]?) → List.Forall₂ R xs ys
  | [], [], _ => .nil
  | [], _ :: _, h => by
    have h0 := h 0
    simp only [List.getElem?_nil, List.getElem?_cons_zero] at h0
    cases h0
  | _ :: _, [], h => by
    have h0 := h 0
    simp only [List.getElem?_nil, List.getElem?_cons_zero] at h0
    cases h0
  | _ :: _, _ :: _, h => by
    have h0 := h 0
    simp only [List.getElem?_cons_zero] at h0
    obtain ⟨h0⟩ := h0
    exact .cons h0 (List.forall₂_of_rel fun j => by
      simpa only [List.getElem?_cons_succ] using h (j + 1))

/-- For a reflexive `R`, `Labels.Rel p R` implies `Labels.Rel q R` when `p` implies `q`. -/
theorem Labels.Rel.mono {α : Type} {R : α → α → Prop} (hR : ∀ x, R x x) {p q : Bool}
    (hpq : p = true → q = true) {x y : α} (h : Labels.Rel p R x y) : Labels.Rel q R x y := by
  cases p
  · obtain rfl : x = y := h
    exact Labels.Rel.refl hR q x
  · exact .of_rel (hpq rfl) h

/-- For a reflexive `R`, values related by `Labels.Rel p R` are related by `R`. -/
theorem Labels.Rel.to {α : Type} {R : α → α → Prop} (hR : ∀ x, R x x) {p : Bool} {x y : α}
    (h : Labels.Rel p R x y) : R x y := by
  cases p
  · obtain rfl : x = y := h
    exact hR x
  · exact h

/-- Lists related at each index `j` by `Labels.Rel (q j) R`, with every `q j` false, are equal. -/
theorem _root_.List.eq_of_rel {α : Type} {R : α → α → Prop} {q : Nat → Bool} {xs ys : List α}
    (h : ∀ j, Option.Rel (Labels.Rel (q j) R) xs[j]? ys[j]?) (hq : ∀ j, q j = false) :
    xs = ys :=
  List.ext_getElem? fun j => Labels.Rel.option_eq (by simpa only [hq j] using h j)

/-- For every context, oracle `o`, two scopes with memories related by `Mem.SkelEq`, flags,
intrinsic but `maxnum`, `minnum` and `rsqrt.approx`, and arguments, `intrinsic` under the context
and under it with oracle `o` gives one fault, or `none` in both, or one result and related
memories. -/
theorem intrinsic_skel {pay : Nat → Prop} (c : Ctx) (o : Nat → Nat) {s₁ s₂ : Scope}
    (hm : s₁.mem.SkelEq pay s₂.mem) (fm : FastMath) {i : Intrinsic}
    (hi : (i matches .fminmax .. | .rsqrtApprox) = false) (vs : List Val) :
    Except.Rel (Option.Rel fun r₁ r₂ => r₁.1 = r₂.1 ∧ r₁.2.SkelEq pay r₂.2)
      (intrinsic c s₁ fm i vs) (intrinsic { c with oracle := o } s₂ fm i vs) := by
  have ho : ∀ (p : Ptr) w, ((s₂.mem.block p).any fun B : Block => B.owner == w) =
      ((s₁.mem.block p).any fun B : Block => B.owner == w) := by
    intro p w
    simp only [Mem.block]
    have h := hm.blocks p.block
    revert h
    generalize s₁.mem.blocks p.block = x₁
    generalize s₂.mem.blocks p.block = x₂
    rintro (h | _)
    · have e := congrArg Block.owner h.shape
      dsimp only at e
      simp only [Option.any_some, e]
    · rfl
  cases h : intrinsic c s₁ fm i vs <;>
  · unfold intrinsic at h ⊢
    repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
    all_goals cases h
    all_goals first
      | (simp at hi; done)
      | exact .error _
      | exact .ok .none
      | exact .ok (.some ⟨rfl, hm⟩)
      | (simp only [*, bind, Except.bind, pure, Except.pure, ↓reduceIte]
         first
          | exact .error _
          | exact .ok (.some ⟨rfl, hm⟩)
          | exact .ok (.some ⟨rfl, Mem.setLive_skel hm _ _⟩))

/-- `ownUndef` is equal for two calls whose results with no flags are related by `Option.Rel R`, for
a relation `R` that relates the result values by `Option.Rel Val.Skel`. -/
theorem ownUndef_rel {c₁ c₂ : Ctx} {s₁ s₂ : Scope} {i₁ i₂ : Intrinsic} {vs₁ vs₂ : List Val}
    {R : Option Val × Mem → Option Val × Mem → Prop}
    (hR : ∀ r₁ r₂, R r₁ r₂ → Option.Rel Val.Skel r₁.1 r₂.1)
    (h : Except.Rel (Option.Rel R) (intrinsic c₁ s₁ {} i₁ vs₁) (intrinsic c₂ s₂ {} i₂ vs₂)) :
    ownUndef c₁ s₁ i₁ vs₁ = ownUndef c₂ s₂ i₂ vs₂ := by
  unfold ownUndef
  revert h
  generalize intrinsic c₁ s₁ {} i₁ vs₁ = x₁
  generalize intrinsic c₂ s₂ {} i₂ vs₂ = x₂
  intro h
  cases h with
  | error => rfl
  | ok h =>
    cases h with
    | none => rfl
    | some h =>
      rename_i r₁ r₂
      obtain ⟨a₁, n₁⟩ := r₁
      obtain ⟨a₂, n₂⟩ := r₂
      have h' : Option.Rel Val.Skel a₁ a₂ := hR _ _ h
      cases h' with
      | none => rfl
      | some h' => simp only [h'.defined]

/-- `maxnum` and `minnum` on two arguments never return `none` (a collective's stop). -/
theorem intrinsic_fminmax (c : Ctx) (s : Scope) (fm : FastMath) (max : Bool) (t : Ty)
    (x y : Val) : intrinsic c s fm (.fminmax max t) [x, y] ≠ .ok none := by
  dsimp only [intrinsic]
  split
  · intro h
    simp only [bind, Except.bind, pure, Except.pure] at h
    split at h <;> cases h
  · intro h
    cases h

/-- `rsqrt.approx` on one argument never returns `none` (a collective's stop). -/
theorem intrinsic_rsqrt (c : Ctx) (s : Scope) (fm : FastMath) (x : Val) :
    intrinsic c s fm .rsqrtApprox [x] ≠ .ok none := by
  dsimp only [intrinsic]
  split
  all_goals try split
  all_goals intro h; cases h

/-- For every `shfl.sync`, argument lists equal at every index but 1, where they are related by
`Val.Skel`, are equal after `Intrinsic.eraseArgs`. -/
theorem shfl_erase (sh : Shfl) {xs ys : List Val}
    (h : ∀ j, Option.Rel (Labels.Rel (j == 1) Val.Skel) xs[j]? ys[j]?) :
    (Intrinsic.shfl sh).eraseArgs xs = (Intrinsic.shfl sh).eraseArgs ys := by
  rcases xs with _ | ⟨x₀, _ | ⟨x₁, xs⟩⟩ <;> rcases ys with _ | ⟨y₀, _ | ⟨y₁, ys⟩⟩
  all_goals try first
    | (have h0 := h 0
       simp only [List.getElem?_nil, List.getElem?_cons_zero] at h0
       cases h0; done)
    | (have h1 := h 1
       simp only [List.getElem?_nil, List.getElem?_cons_succ, List.getElem?_cons_zero] at h1
       cases h1; done)
  · rfl
  · have h0 := h 0
    simp only [List.getElem?_cons_zero] at h0
    obtain ⟨h0⟩ := h0
    obtain rfl : x₀ = y₀ := h0
    rfl
  · have h0 := h 0
    have h1 := h 1
    simp only [List.getElem?_cons_zero, List.getElem?_cons_succ] at h0 h1
    obtain ⟨h0⟩ := h0
    obtain ⟨h1⟩ := h1
    obtain rfl : x₀ = y₀ := h0
    have e : xs = ys := List.ext_getElem? fun j => Labels.Rel.option_eq (by
      have := h (j + 2)
      rw [show (j + 2 == 1) = false from beq_eq_false_iff_ne.2 (by omega)] at this
      simpa only [List.getElem?_cons_succ] using this)
    subst e
    simp only [Intrinsic.eraseArgs]
    rw [show x₁.erase = y₁.erase from h1]

/-- An attribute equal to `noundef` is not named `range`. -/
theorem Attr.name_ne {x : Attr} (h : (x == .flag "noundef") = true) : x.name ≠ "range" := by
  cases x <;> first
    | cases h
    | (simp only [Attr.name]; intro e; subst e; revert h; decide)

/-- `exec_skel` for a `call` (the premises on operands are those `exec_skel` derives): an inline
`asm` is refused in both runs; a defined function gets arguments related by `Val.Skel` at its
payload parameters, by (O4) for the arguments and `range`-free payload parameters; a declared
intrinsic of `maxnum` or `minnum` gives related results by `fminmax_skel`, and of `rsqrt.approx`
by `rsqrt_skel`, a `shfl.sync` waits with arguments equal after `Intrinsic.eraseArgs`, and every
other intrinsic, of skeleton arguments by (O1), gives one result by `intrinsic_skel`. -/
theorem exec_call_skel {lab : Labels} {pay : Nat → Prop} {c : Ctx} {o : Nat → Nat} {k : Nat}
    {f₁ f₂ : Frame} {m₁ m₂ : Mem} {res : Option Nat} {fm : FastMath} {cc : Ty}
    {callee : Callee} {args : List (TValue × List Attr)} {md : List (String × Nat)}
    (hf : f₁.Skel lab f₂) (hm : m₁.SkelEq pay m₂) (hL : Labels.Ok c.prog lab = true)
    (hok : lab.stmtOk c.prog f₁.fn ⟨res, .call fm cc callee args, md⟩ = true)
    (hsk2 : ∀ v : TValue, v.mentions (lab.reg f₁.fn.name) = false →
      evalTV ({ c with oracle := o }.scope m₂ f₂ k) v = evalTV (c.scope m₁ f₁ k) v)
    (hpoT : ∀ v : TValue, TValue.payOk (lab.reg f₁.fn.name) v = true →
      Except.Rel Val.Skel (evalTV (c.scope m₁ f₁ k) v)
        (evalTV ({ c with oracle := o }.scope m₂ f₂ k) v)) :
    Except.Rel (Eff.Skel lab pay (res.any (lab.reg f₁.fn.name)))
      (exec c (c.scope m₁ f₁ k) k f₁ ⟨res, .call fm cc callee args, md⟩)
      (exec { c with oracle := o } ({ c with oracle := o }.scope m₂ f₂ k) k f₂
        ⟨res, .call fm cc callee args, md⟩) := by
  have hm₁ : (c.scope m₁ f₁ k).mem = m₁ := rfl
  have hm₂ : ({ c with oracle := o }.scope m₂ f₂ k).mem = m₂ := rfl
  have hS := hm.sameShape fun _ => True
  refine (Except.Rel.refl (R := Eq) (fun _ => rfl)
    (Stmt.checkMd ⟨res, .call fm cc callee args, md⟩)).bind fun _ _ _ => ?_
  generalize hpr : res.any (lab.reg f₁.fn.name) = pr
  cases callee
  case asm => exact .error _
  case fn g =>
    simp only [Labels.stmtOk, hpr] at hok
    dsimp only
    simp only [hm₁, hm₂]
    have hfacts : ∀ (j : Nat) (tv : TValue) as, args[j]? = some (tv, as) →
        tv.mentions (lab.reg f₁.fn.name) = true → tv.payOk (lab.reg f₁.fn.name) = true ∧
        ∀ fn : Func, c.prog.module.funcs.find? (·.name == g) = some fn →
          ∀ p : Param, fn.params[j]? = some p → ∀ x ∈ p.attrs, x.name ≠ "range" := by
      intro j tv as ha hmt
      have hz : ((tv, as), j) ∈ args.zipIdx := List.mem_zipIdx_iff_getElem?.2 ha
      have hz' := List.mem_of_getElem? ha
      rcases hfd : c.prog.module.funcs.find? (·.name == g) with _ | fn
      · simp only [hfd] at hok
        exact ⟨List.all_eq_true.1 hok _ hz', fun _ h => by rw [hfd] at h; cases h⟩
      simp only [hfd] at hok
      have hfn' : fn.name = g := by simpa using Array.find?_some hfd
      have hF := Array.all_eq_true_iff_forall_mem.1 hL fn (Array.mem_of_find?_eq_some hfd)
      have hnr : (fn.retAttrs ++ fn.params.flatMap fun q : Param => q.attrs).all
          (fun x : Attr => x.name != "range") = true →
          ∀ p : Param, fn.params[j]? = some p → ∀ x ∈ p.attrs, x.name ≠ "range" :=
        fun h p hp x hx => bne_iff_ne.1 (List.all_eq_true.1 h x
          (List.mem_append_right _ (List.mem_flatMap.2 ⟨p, List.mem_of_getElem? hp, hx⟩)))
      suffices h : tv.payOk (lab.reg f₁.fn.name) = true ∧
          ∀ p : Param, fn.params[j]? = some p → ∀ x ∈ p.attrs, x.name ≠ "range" from
        ⟨h.1, fun _ e => by rw [hfd] at e; cases e; exact h.2⟩
      split at hok
      · split at hok
        · cases pr
          · simp at hok
          · simp only [Bool.true_and, Bool.and_eq_true, ↓reduceIte] at hok
            exact ⟨List.all_eq_true.1 hok.2 _ (List.mem_map_of_mem hz'), hnr hok.1.2⟩
        · rw [Bool.and_eq_true] at hok
          have h := List.all_eq_true.1 hok.2 _ hz
          simp only [hmt, Bool.not_true, Bool.false_or, Bool.and_eq_true] at h
          have hr := hok.1
          simp only [h.1.2, Bool.not_true, Bool.false_or] at hr
          exact ⟨h.2, hnr hr⟩
        · cases pr
          · simp at hok
          · simp only [Bool.true_and, Bool.and_eq_true, ↓reduceIte] at hok
            exact ⟨List.all_eq_true.1 hok.2 _ (List.mem_map_of_mem hz'), hnr hok.1.2⟩
        · have h := List.all_eq_true.1 hok _ hz'
          simp [hmt] at h
      · simp only [Bool.and_eq_true] at hok
        have h := List.all_eq_true.1 hok.2 _ hz
        simp only [hmt, Bool.not_true, Bool.false_or, Bool.and_eq_true] at h
        refine ⟨h.2, fun p hp x hx => ?_⟩
        simp only [hp, Option.any_some] at h
        simp only [Labels.funcOk, Bool.and_eq_true, List.all_eq_true, Bool.or_eq_true,
          Bool.not_eq_true'] at hF
        rcases hF.1.2 p (List.mem_of_getElem? hp) with h' | h'
        · rw [hfn', h.1] at h'
          cases h'
        · exact bne_iff_ne.1 (h' x hx)
    refine (Except.Rel.mapIdx (R := fun j a b => a = b ∧ args[j]? = some a)
      (S := fun j => Labels.Rel ((args[j]?).any fun a => a.1.mentions (lab.reg f₁.fn.name))
        Val.Skel) ?_ (List.rel_self args)).bind fun vs₁ vs₂ hvs => ?_
    · rintro j ⟨tv, as⟩ _ ⟨rfl, ha⟩
      dsimp only
      simp only [ha, Option.any_some]
      cases hmt : tv.mentions (lab.reg f₁.fn.name)
      · rw [hsk2 tv hmt]
        exact .refl (fun x => Labels.Rel.refl Val.Skel.refl _ x) _
      · exact (hpoT tv (hfacts j tv as ha hmt).1).imp fun _ _ h => .of_rel rfl h
    split
    on_goal 2 => exact .error _
    rename_i fn hfd'
    have hfd : c.prog.module.funcs.find? (·.name == g) = some fn := hfd'
    simp only [hfd] at hok
    have hfn' : fn.name = g := by simpa using Array.find?_some hfd
    refine .ite (fun _ => .ite (fun hna => ?_) (fun _ => .error _)) (fun _ => .error _)
    refine (Except.Rel.mapIdx
      (R := fun j a b => ((a.1.1 = b.1.1 ∧ fn.params[j]? = some a.1.1) ∧
        Labels.Rel ((args[j]?).any fun a => a.1.mentions (lab.reg f₁.fn.name)) Val.Skel a.1.2
          b.1.2) ∧ a.2 = b.2 ∧ args[j]? = some a.2)
      (S := fun j => Labels.Rel ((args[j]?).any fun a => a.1.mentions (lab.reg f₁.fn.name))
        Val.Skel) ?_ (List.rel_zip (List.rel_zip (List.rel_self fn.params) hvs)
          (List.rel_self args))).bind fun ws₁ ws₂ hws => ?_
    · rintro j ⟨⟨p, v₁⟩, ⟨tv, as⟩⟩ ⟨⟨p', v₂⟩, ⟨tv', as'⟩⟩ ⟨⟨⟨e₁, hp⟩, hv⟩, ⟨e₂, ha⟩⟩
      dsimp only at e₁ hp hv e₂ ha
      cases e₁
      cases e₂
      dsimp only
      simp only [ha, Option.any_some] at hv ⊢
      cases hmt : tv.mentions (lab.reg f₁.fn.name)
      · rw [hmt] at hv
        obtain rfl : v₁ = v₂ := hv
        rw [withAttrs_shape hS (Val.namesIn_top _)]
        exact .refl (fun x => Labels.Rel.refl Val.Skel.refl _ x) _
      · rw [hmt] at hv
        refine (withAttrs_skel hm _ _ _ (Labels.Rel.to Val.Skel.refl hv) (.inl fun x hx => ?_)).imp
          fun _ _ h => .of_rel rfl h
        rcases List.mem_append.1 hx with hx | hx
        · exact (hfacts j tv as ha hmt).2 fn hfd p hp x hx
        · exact Attr.name_ne (List.all_eq_true.1 (List.all_eq_true.1 hna _
            (List.mem_of_getElem? ha)) x hx)
    refine .ite (fun hb => ?_) (fun hb => ?_)
    · have hb' : fn.blocks.isEmpty = false := by simpa using hb
      simp only [hb', Bool.false_eq_true, ↓reduceIte, Bool.and_eq_true] at hok
      refine .ite (fun _ => .error _) (fun _ => .ok ⟨rfl, fun j => ?_⟩)
      refine Option.Rel.imp (fun _ _ h => Labels.Rel.mono Val.Skel.refl (fun hj => ?_) h) (hws j)
      rcases ha : args[j]? with _ | ⟨tv, as⟩
      · simp [ha] at hj
      · simp only [ha, Option.any_some] at hj
        have h := List.all_eq_true.1 hok.2 _
          ((List.mem_zipIdx_iff_getElem? (x := ((tv, as), j))).2 ha)
        simp only [hj, Bool.not_true, Bool.false_or, Bool.and_eq_true] at h
        rw [hfn']
        exact h.1
    have hb' : fn.blocks.isEmpty = true := by simpa using hb
    simp only [hb', ↓reduceIte] at hok
    rcases hi : c.prog.intrinsics.lookup g with _ | i
    · exact .error _
    simp only [hi] at hok
    dsimp only
    by_cases hsp : (match (generalizing := false) i with
      | .fminmax .. | .rsqrtApprox | .shfl _ => true | _ => false) = true
    swap
    · have hi0 : (match (generalizing := false) i with
          | .fminmax .. | .rsqrtApprox => true | _ => false) = false := by
        revert hsp
        cases i <;> first | (intro; rfl) | (intro h; exact absurd rfl h)
      replace hok : args.all (fun a => !a.1.mentions (lab.reg f₁.fn.name)) = true := by
        revert hok hsp
        cases i <;> first | (intro h _; exact h) | (intro _ h; exact absurd rfl h)
      refine .bind_eq _ fun _ _ => .ite (fun _ => ?_) (fun _ => .error _)
      have hq0 : ∀ j : Nat,
          ((args[j]?).any fun a => a.1.mentions (lab.reg f₁.fn.name)) = false := by
        intro j
        rcases ha : args[j]? with _ | ⟨tv, as⟩
        · rfl
        · have h := List.all_eq_true.1 hok _ (List.mem_of_getElem? ha)
          simpa only [Option.any_some, Bool.not_eq_true'] using h
      obtain rfl := List.eq_of_rel hws hq0
      refine (intrinsic_skel (s₁ := c.scope m₁ f₁ k) (s₂ := { c with oracle := o }.scope m₂ f₂ k)
        c o hm _ hi0 ws₁).bind fun r₁ r₂ hr => ?_
      cases hr with
      | none => exact .ok ⟨rfl, rfl, Labels.Rel.refl (R := fun a b => i.eraseArgs a = i.eraseArgs b)
          (fun _ => rfl) _ _⟩
      | some hr =>
        rename_i a b
        obtain ⟨v₁, n₁⟩ := a
        obtain ⟨v₂, n₂⟩ := b
        obtain ⟨e, hn⟩ := hr
        dsimp only at e hn ⊢
        subst e
        rw [ownUndef_rel (fun _ _ h => by rw [h.1]; exact Option.Rel.refl Val.Skel.refl _)
          (intrinsic_skel (s₁ := c.scope m₁ f₁ k) (s₂ := { c with oracle := o }.scope m₂ f₂ k)
            c o hm {} hi0 ws₁)]
        refine .ite (fun _ => .error _) (fun _ => ?_)
        rw [show withAttrs c.prog.layout n₁ fn.ret fn.retAttrs =
          withAttrs c.prog.layout n₂ fn.ret fn.retAttrs from funext fun v =>
            withAttrs_shape (hn.sameShape fun _ => True) (Val.namesIn_top v) _ _ _]
        exact .bind_eq _ fun w _ =>
          .ok ⟨hf.next (Option.Rel.refl (Labels.Rel.refl Val.Skel.refl _) w) .none, hn⟩
    revert hsp
    cases i
    case fminmax max t =>
      intro _
      refine .bind_eq _ fun _ _ => .ite (fun _ => ?_) (fun _ => .error _)
      dsimp only at hok
      cases pr
      · simp at hok
      simp only [Bool.true_and, Bool.not_true, Bool.false_or, ↓reduceIte, Bool.and_eq_true,
        Bool.not_eq_true'] at hok
      obtain ⟨⟨⟨hn, hi'⟩, hnr⟩, -⟩ := hok
      have hret : ∀ x ∈ fn.retAttrs, x.name ≠ "range" := fun x hx =>
        bne_iff_ne.1 (List.all_eq_true.1 hnr x (List.mem_append_left _ hx))
      have h2 := List.forall₂_of_rel fun j =>
        Option.Rel.imp (fun _ _ h => Labels.Rel.to Val.Skel.refl h) (hws j)
      rcases h2 with _ | ⟨hx, _ | ⟨hy, _ | ⟨_, _⟩⟩⟩
      all_goals try exact .error _
      have H := fminmax_skel hn hi' c { c with oracle := o } (c.scope m₁ f₁ k)
        ({ c with oracle := o }.scope m₂ f₂ k) max t hx hy
      refine Except.Rel.bind_ok H fun r₁ r₂ he hr => ?_
      cases hr with
      | none => exact absurd he (intrinsic_fminmax _ _ _ _ _ _ _)
      | some hr =>
        rename_i a b
        obtain ⟨v₁, n₁⟩ := a
        obtain ⟨v₂, n₂⟩ := b
        obtain ⟨hv, rfl, rfl⟩ := hr
        dsimp only
        have hd : ∀ {x₁ x₂ y₁ y₂ : Val}, x₁.Skel x₂ → y₁.Skel y₂ →
            [x₂, y₂].all Val.defined = [x₁, y₁].all Val.defined := fun hx hy => by
          simp only [List.all_cons, List.all_nil, hx.defined, hy.defined]
        rw [ownUndef_rel (fun _ _ h => h.1) (fminmax_skel (fm := {}) rfl rfl c
          { c with oracle := o } _ _ max t hx hy), hd hx hy]
        refine .ite (fun _ => .error _) (fun _ => ?_)
        exact (Option.Rel.mapM (fun _ _ h => withAttrs_skel hm _ _ _ h (.inl hret)) hv).bind
          fun _ _ hw => .ok ⟨hf.next (Option.Rel.imp (fun _ _ h => Labels.Rel.of_rel hpr h) hw)
            .none, hm⟩
    case shfl sh =>
      intro _
      refine .bind_eq _ fun _ _ => .ite (fun _ => ?_) (fun _ => .error _)
      dsimp only at hok
      rw [Bool.and_eq_true] at hok
      refine .ok ⟨rfl, rfl, ?_⟩
      cases pr
      · refine Labels.Rel.of_eq rfl (List.eq_of_rel hws fun j => ?_)
        rcases ha : args[j]? with _ | ⟨tv, as⟩
        · rfl
        · have h := List.all_eq_true.1 hok.2 _
            ((List.mem_zipIdx_iff_getElem? (x := ((tv, as), j))).2 ha)
          simp only [Bool.and_false, Bool.false_and, Bool.or_false, Bool.not_eq_true'] at h
          simp only [Option.any_some, h]
      · refine Labels.Rel.of_rel rfl (shfl_erase sh fun j =>
          Option.Rel.imp (fun _ _ h => Labels.Rel.mono Val.Skel.refl (fun hj => ?_) h) (hws j))
        rcases ha : args[j]? with _ | ⟨tv, as⟩
        · simp [ha] at hj
        · simp only [ha, Option.any_some] at hj
          have h := List.all_eq_true.1 hok.2 _
            ((List.mem_zipIdx_iff_getElem? (x := ((tv, as), j))).2 ha)
          simp only [hj, Bool.not_true, Bool.false_or, Bool.and_eq_true] at h
          exact h.1.1
    case rsqrtApprox =>
      intro _
      refine .bind_eq _ fun _ _ => .ite (fun _ => ?_) (fun _ => .error _)
      dsimp only at hok
      cases pr
      · simp at hok
      simp only [Bool.true_and, Bool.not_true, Bool.false_or, ↓reduceIte, Bool.and_eq_true,
        Bool.not_eq_true'] at hok
      obtain ⟨⟨⟨hn, hi'⟩, hnr⟩, -⟩ := hok
      have hret : ∀ x ∈ fn.retAttrs, x.name ≠ "range" := fun x hx =>
        bne_iff_ne.1 (List.all_eq_true.1 hnr x (List.mem_append_left _ hx))
      have h2 := List.forall₂_of_rel fun j =>
        Option.Rel.imp (fun _ _ h => Labels.Rel.to Val.Skel.refl h) (hws j)
      rcases h2 with _ | ⟨hx, _ | ⟨_, _⟩⟩
      all_goals try exact .error _
      have H := rsqrt_skel hn hi' c { c with oracle := o } (c.scope m₁ f₁ k)
        ({ c with oracle := o }.scope m₂ f₂ k) hx
      refine Except.Rel.bind_ok H fun r₁ r₂ he hr => ?_
      cases hr with
      | none => exact absurd he (intrinsic_rsqrt _ _ _ _)
      | some hr =>
        rename_i a b
        obtain ⟨v₁, n₁⟩ := a
        obtain ⟨v₂, n₂⟩ := b
        obtain ⟨hv, rfl, rfl⟩ := hr
        dsimp only
        have hd : ∀ {x₁ x₂ : Val}, x₁.Skel x₂ → [x₂].all Val.defined = [x₁].all Val.defined :=
          fun hx => by simp only [List.all_cons, List.all_nil, hx.defined]
        rw [ownUndef_rel (fun _ _ h => h.1) (rsqrt_skel (fm := {}) rfl rfl c
          { c with oracle := o } _ _ hx), hd hx]
        refine .ite (fun _ => .error _) (fun _ => ?_)
        exact (Option.Rel.mapM (fun _ _ h => withAttrs_skel hm _ _ _ h (.inl hret)) hv).bind
          fun _ _ hw => .ok ⟨hf.next (Option.Rel.imp (fun _ _ h => Labels.Rel.of_rel hpr h) hw)
            .none, hm⟩
    all_goals intro h; cases h

/-- T3b's statement lemma: for every labelling `lab` and payload blocks `pay`, context, oracle `o`,
thread position `k`, frames related by `Frame.Skel` and memories by `Mem.SkelEq`, a program that
passes `Labels.Ok` and a statement that passes `Labels.stmtOk` and meets `Labels.MemAt`, `exec`
under the context and under it with oracle `o` gives one fault or effects related by `Eff.Skel`
at the statement's result label. -/
theorem exec_skel {lab : Labels} {pay : Nat → Prop} {c : Ctx} {o : Nat → Nat} {k : Nat}
    {f₁ f₂ : Frame} {m₁ m₂ : Mem} {st : Stmt} (hf : f₁.Skel lab f₂) (hm : m₁.SkelEq pay m₂)
    (hL : Labels.Ok c.prog lab = true) (hok : lab.stmtOk c.prog f₁.fn st = true)
    (hM : lab.MemAt pay (c.scope m₁ f₁ k) f₁.fn st) :
    Except.Rel (Eff.Skel lab pay (st.res.any (lab.reg f₁.fn.name)))
      (exec c (c.scope m₁ f₁ k) k f₁ st)
      (exec { c with oracle := o } ({ c with oracle := o }.scope m₂ f₂ k) k f₂ st) := by
  obtain ⟨res, inst, md⟩ := st
  have hsk : ∀ t v, Value.mentions (lab.reg f₁.fn.name) v = false →
      evalV ({ c with oracle := o }.scope m₂ f₂ k) t v = evalV (c.scope m₁ f₁ k) t v :=
    (evalV_skel (s := c.scope m₁ f₁ k) hm fun n hn =>
      (Labels.Rel.option_eq (hn ▸ hf.regs n)).symm).1
  have hsk2 : ∀ v : TValue, v.mentions (lab.reg f₁.fn.name) = false →
      evalTV ({ c with oracle := o }.scope m₂ f₂ k) v = evalTV (c.scope m₁ f₁ k) v :=
    (evalV_skel (s := c.scope m₁ f₁ k) hm fun n hn =>
      (Labels.Rel.option_eq (hn ▸ hf.regs n)).symm).2.1
  have hsk3 : ∀ vs, TValue.anyMentions (lab.reg f₁.fn.name) vs = false →
      evalTVs ({ c with oracle := o }.scope m₂ f₂ k) vs = evalTVs (c.scope m₁ f₁ k) vs :=
    (evalV_skel (s := c.scope m₁ f₁ k) hm fun n hn =>
      (Labels.Rel.option_eq (hn ▸ hf.regs n)).symm).2.2
  have hpo : ∀ t {t'} v, TValue.payOk (lab.reg f₁.fn.name) ⟨t', v⟩ = true →
      Except.Rel Val.Skel (evalV (c.scope m₁ f₁ k) t v)
        (evalV ({ c with oracle := o }.scope m₂ f₂ k) t v) :=
    fun t _ v h => evalV_pay hm hf.regs t h
  have hpoT : ∀ v : TValue, TValue.payOk (lab.reg f₁.fn.name) v = true →
      Except.Rel Val.Skel (evalTV (c.scope m₁ f₁ k) v)
        (evalTV ({ c with oracle := o }.scope m₂ f₂ k) v) :=
    fun ⟨t, v⟩ h => by simpa only [evalTV] using hpo t v h
  have hpe : ∀ (Q : Prop) t v, TValue.payOk (lab.reg f₁.fn.name) ⟨t, v⟩ = true →
      (Q → Value.mentions (lab.reg f₁.fn.name) v = false) →
      Except.Rel (fun y₁ y₂ => y₁.Skel y₂ ∧ (Q → y₁ = y₂)) (evalV (c.scope m₁ f₁ k) t v)
        (evalV ({ c with oracle := o }.scope m₂ f₂ k) t v) := by
    intro Q t v h hq
    by_cases q : Q
    · rw [hsk t v (hq q)]; exact .refl (fun _ => ⟨Val.Skel.refl _, fun _ => rfl⟩) _
    · exact (hpo t v h).imp fun _ _ h => ⟨h, fun x => absurd x q⟩
  have hfn : f₂.fn = f₁.fn := (congrArg Frame.fn hf.shape).symm
  have hm₁ : (c.scope m₁ f₁ k).mem = m₁ := rfl
  have hm₂ : ({ c with oracle := o }.scope m₂ f₂ k).mem = m₂ := rfl
  have hS := hm.sameShape fun _ => True
  have hfr : m₂.fresh c.who.thread k = m₁.fresh c.who.thread k := by simp only [Mem.fresh, hm.next]
  have hlt : lifetimeStarted { c with oracle := o } f₂.fn = lifetimeStarted c f₁.fn := by
    rw [hfn]; rfl
  have hbs : ∀ b, (m₂.blocks b).isSome = (m₁.blocks b).isSome := fun b => (hm.blocks b).isSome.symm
  by_cases hc : ∃ fm cc callee args, inst = .call fm cc callee args
  · obtain ⟨fm, cc, callee, args, rfl⟩ := hc
    exact exec_call_skel hf hm hL hok hsk2 hpoT
  refine (Except.Rel.refl (R := Eq) (fun _ => rfl) (Stmt.checkMd ⟨res, inst, md⟩)).bind
    fun _ _ _ => ?_
  generalize hpr : res.any (lab.reg f₁.fn.name) = pr
  cases inst
  case call => exact absurd ⟨_, _, _, _, rfl⟩ hc
  case bin op fl t a b =>
    simp only [Labels.stmtOk, hpr] at hok
    dsimp only
    cases pr
    · simp only [Bool.not_false, Bool.true_or, Bool.true_and, Bool.false_eq_true, ↓reduceIte,
        List.all_cons, List.all_nil, Bool.and_true, TValue.mentions, Bool.and_eq_true,
        Bool.not_eq_true'] at hok
      rw [hsk t a hok.2.1, hsk t b hok.2.2]
      exact .bind_eq _ fun x _ => .bind_eq _ fun y _ => .bind_eq _ fun v _ =>
        .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · simp only [Bool.not_true, Bool.false_or, ↓reduceIte, List.all_cons, List.all_nil,
        Bool.and_true, Bool.and_eq_true, Bool.or_eq_true, Bool.not_eq_true'] at hok
      obtain ⟨⟨htot, hb⟩, ha', hb'⟩ := hok
      refine (hpo t a ha').bind fun x₁ x₂ hx => (hpe (op.skelB = true) t b hb' fun h => ?_).bind
        fun y₁ y₂ hy => (lanes2_skel (P := op.skelB) (fun _ _ _ _ _ hx hy hP =>
          intBin_skel _ htot hx hy hP) hx hy.1 hy.2).bind fun v₁ v₂ hv =>
            .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
      simpa [h, TValue.mentions] using hb
  case fbin op fm t a b =>
    cases pr <;> simp only [Labels.stmtOk, hpr, Bool.false_and, Bool.true_and, Bool.not_true,
      Bool.false_or, ↓reduceIte, List.all_cons, List.all_nil, Bool.and_true, Bool.and_eq_true,
      Bool.not_eq_true', Bool.false_eq_true] at hok
    obtain ⟨⟨hn, hi⟩, ha, hb⟩ := hok
    dsimp only
    generalize t.elt = e
    cases e
    case fp ft =>
      dsimp only
      refine (hpo t a ha).bind fun x₁ x₂ hx => (hpo t b hb).bind fun y₁ y₂ hy =>
        (lanes2_skel (P := False) (fun _ _ _ _ _ hx hy _ =>
          floatBin_skel ft op hn hi hx hy _ _ _ _ _ _) hx hy False.elim).bind fun v₁ v₂ hv =>
            .ok ⟨hf.next (.some (.of_rel hpr hv)) ?_, hm⟩
      cases (op == .fmul && fm.contract)
      · exact .none
      · exact .some (.of_rel hpr ⟨hx, hy⟩)
    all_goals exact .error _
  case fneg fm a =>
    obtain ⟨t, a⟩ := a
    dsimp only
    cases pr <;> simp only [Labels.stmtOk, hpr, Bool.not_false, Bool.true_or, Bool.true_and,
      Bool.not_true, Bool.false_or, ↓reduceIte, List.all_cons, List.all_nil, Bool.and_true,
      Bool.and_eq_true, Bool.not_eq_true', Bool.false_eq_true, TValue.mentions] at hok
    · rw [hsk t a hok]
      exact .bind_eq _ fun x _ => .bind_eq _ fun v _ =>
        .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · obtain ⟨⟨hn, hi⟩, ha⟩ := hok
      exact (hpo t a ha).bind fun x₁ x₂ hx => (fnegV_skel hn hi t hx).bind fun v₁ v₂ hv =>
        .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case icmp p t a b =>
    dsimp only
    simp only [hm₁, hm₂]
    cases pr <;> simp only [Labels.stmtOk, hpr, ↓reduceIte, List.all_cons, List.all_nil,
      Bool.and_true, Bool.and_eq_true, Bool.not_eq_true', Bool.false_eq_true,
      TValue.mentions] at hok
    · rw [hsk t a hok.1, hsk t b hok.2]
      refine .bind_eq _ fun x _ => .bind_eq _ fun y _ => ?_
      rw [← icmpV_shape hS (Val.namesIn_top x) (Val.namesIn_top y)]
      exact .bind_eq _ fun v _ => .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · exact (hpo t a hok.1).bind fun x₁ x₂ hx => (hpo t b hok.2).bind fun y₁ y₂ hy =>
        (icmpV_skel hm _ p t hx hy).bind fun v₁ v₂ hv =>
          .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case fcmp fm p t a b =>
    dsimp only
    cases pr <;> simp only [Labels.stmtOk, hpr, Bool.not_false, Bool.true_or, Bool.true_and,
      Bool.not_true, Bool.false_or, ↓reduceIte, List.all_cons, List.all_nil, Bool.and_true,
      Bool.and_eq_true, Bool.not_eq_true', Bool.false_eq_true, TValue.mentions] at hok
    · rw [hsk t a hok.1, hsk t b hok.2]
      exact .bind_eq _ fun x _ => .bind_eq _ fun y _ => .bind_eq _ fun v _ =>
        .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · obtain ⟨⟨hn, hi⟩, ha, hb⟩ := hok
      exact (hpo t a ha).bind fun x₁ x₂ hx => (hpo t b hb).bind fun y₁ y₂ hy =>
        (fcmpV_skel hn hi p t hx hy).bind fun v₁ v₂ hv =>
          .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case cast op a ty =>
    obtain ⟨t, a⟩ := a
    dsimp only
    simp only [hm₁, hm₂]
    cases pr <;> simp only [Labels.stmtOk, hpr, Bool.false_or, Bool.true_or, Bool.true_and,
      ↓reduceIte, List.all_cons, List.all_nil, Bool.and_true, Bool.and_eq_true,
      Bool.not_eq_true', Bool.false_eq_true, TValue.mentions] at hok
    · rw [hsk t a hok.2]
      refine .bind_eq _ fun x _ => ?_
      rw [castV_ch hok.1 _ _ _ _ _ (c.scope m₁ f₁ k).ch ({ c with oracle := o }.scope m₂ f₂ k).ch,
        castV_shape hS (Val.namesIn_top x)]
      exact .bind_eq _ fun v _ => .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · exact (hpo t a hok).bind fun x₁ x₂ hx => (castV_skel hm _ op t ty hx _ _).bind
        fun v₁ v₂ hv => .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case select cv a b =>
    obtain ⟨ct, cv⟩ := cv
    obtain ⟨t, a⟩ := a
    obtain ⟨t', b⟩ := b
    dsimp only
    cases pr <;> simp only [Labels.stmtOk, hpr, ↓reduceIte, List.all_cons, List.all_nil,
      Bool.and_true, Bool.and_eq_true, Bool.not_eq_true', Bool.false_eq_true,
      TValue.mentions] at hok
    · rw [hsk ct cv hok.1, hsk t a hok.2.1, hsk t b hok.2.2]
      exact .bind_eq _ fun x _ => .bind_eq _ fun y _ => .bind_eq _ fun z _ => .bind_eq _
        fun v _ => .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · rw [hsk ct cv hok.1]
      exact .bind_eq _ fun x _ => (hpo t a hok.2.1).bind fun y₁ y₂ hy =>
        (hpo t b hok.2.2).bind fun z₁ z₂ hz => (selectV_skel t x hy hz).bind fun v₁ v₂ hv =>
          .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case phi => exact .error _
  case gep fl src b idx =>
    obtain ⟨bt, b⟩ := b
    cases bt
    case ptr a =>
      dsimp only
      simp only [hm₁, hm₂]
      simp only [Labels.stmtOk, Bool.and_eq_true, Bool.not_eq_true', TValue.mentions] at hok
      rw [hsk3 idx (TValue.anyMentions_of_all hok.2), hsk _ b hok.1]
      refine .bind_eq _ fun is _ => .bind_eq _ fun x _ => ?_
      rw [← gep_shape hS (Val.namesIn_top x)]
      exact .bind_eq _ fun v _ =>
        .ok ⟨hf.next (.some (Labels.Rel.refl Val.Skel.refl _ _)) .none, hm⟩
    all_goals exact .error _
  case extractvalue a is =>
    obtain ⟨t, a⟩ := a
    dsimp only
    cases pr <;> simp only [Labels.stmtOk, hpr, ↓reduceIte, List.all_cons, List.all_nil,
      Bool.and_true, Bool.not_eq_true', Bool.false_eq_true,
      TValue.mentions] at hok
    · rw [hsk t a hok]
      exact .bind_eq _ fun x _ => .bind_eq _ fun v _ =>
        .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · exact (hpo t a hok).bind fun x₁ x₂ hx => (extractV_skel is hx).bind fun v₁ v₂ hv =>
        .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case insertvalue a e is =>
    obtain ⟨t, a⟩ := a
    obtain ⟨te, e⟩ := e
    dsimp only
    cases pr <;> simp only [Labels.stmtOk, hpr, ↓reduceIte, List.all_cons, List.all_nil,
      Bool.and_true, Bool.and_eq_true, Bool.not_eq_true', Bool.false_eq_true,
      TValue.mentions] at hok
    · rw [hsk t a hok.1, hsk te e hok.2]
      exact .bind_eq _ fun x _ => .bind_eq _ fun y _ => .bind_eq _ fun v _ =>
        .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · exact (hpo t a hok.1).bind fun x₁ x₂ hx => (hpo te e hok.2).bind fun y₁ y₂ hy =>
        (insertV_skel hy is hx).bind fun v₁ v₂ hv =>
          .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case extractelement v i =>
    obtain ⟨t, v⟩ := v
    dsimp only
    cases pr <;> simp only [Labels.stmtOk, hpr, ↓reduceIte, List.all_cons, List.all_nil,
      Bool.and_true, Bool.and_eq_true, Bool.not_eq_true', Bool.false_eq_true,
      TValue.mentions] at hok
    · rw [hsk t v hok.2, hsk2 i hok.1]
      exact .bind_eq _ fun x _ => .bind_eq _ fun y _ => .bind_eq _ fun v _ =>
        .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · rw [hsk2 i hok.1]
      exact (hpo t v hok.2).bind fun x₁ x₂ hx => .bind_eq _ fun y _ =>
        (extractE_skel t hx y).bind fun v₁ v₂ hv =>
          .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case insertelement v e i =>
    obtain ⟨t, v⟩ := v
    dsimp only
    cases pr <;> simp only [Labels.stmtOk, hpr, ↓reduceIte, List.all_cons, List.all_nil,
      Bool.and_true, Bool.and_eq_true, Bool.not_eq_true', Bool.false_eq_true,
      TValue.mentions] at hok
    · rw [hsk t v hok.2.1, hsk2 e hok.2.2, hsk2 i hok.1]
      exact .bind_eq _ fun x _ => .bind_eq _ fun y _ => .bind_eq _ fun z _ => .bind_eq _
        fun v _ => .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · rw [hsk2 i hok.1]
      exact (hpo t v hok.2.1).bind fun x₁ x₂ hx => (hpoT e hok.2.2).bind fun y₁ y₂ hy =>
        .bind_eq _ fun z _ => (insertE_skel t hx hy z).bind fun v₁ v₂ hv =>
          .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case shufflevector a b mk =>
    obtain ⟨t, a⟩ := a
    dsimp only
    cases pr <;> simp only [Labels.stmtOk, hpr, ↓reduceIte, List.all_cons, List.all_nil,
      Bool.and_true, Bool.and_eq_true, Bool.not_eq_true', Bool.false_eq_true,
      TValue.mentions] at hok
    · rw [hsk t a hok.2.1, hsk2 b hok.2.2, hsk2 mk hok.1]
      exact .bind_eq _ fun x _ => .bind_eq _ fun y _ => .bind_eq _ fun z _ => .bind_eq _
        fun v _ => .ok ⟨hf.next (.some (.of_eq hpr rfl)) .none, hm⟩
    · rw [hsk2 mk hok.1]
      exact (hpo t a hok.2.1).bind fun x₁ x₂ hx => (hpoT b hok.2.2).bind fun y₁ y₂ hy =>
        .bind_eq _ fun z _ => (shuffleV_skel t hx hy z).bind fun v₁ v₂ hv =>
          .ok ⟨hf.next (.some (.of_rel hpr hv)) .none, hm⟩
  case alloca t cnt al =>
    dsimp only
    simp only [hm₁, hm₂, hlt, hfr, hbs]
    simp only [Labels.stmtOk] at hok
    rcases cnt with _ | ⟨ct, cv⟩
    all_goals dsimp only
    on_goal 2 =>
      simp only [Option.all, TValue.mentions, Bool.not_eq_true'] at hok
      rw [hsk ct cv hok]
      refine .bind_eq _ fun x _ => ?_
      cases x
      all_goals try exact .error _
    all_goals
      refine .bind_eq _ fun n _ => ?_
      refine .ite (fun _ => .error _) (fun _ => ?_)
      rw [← (Mem.alloc_skel hm _ _ _ _ _ _ _ _ _ _ _).2]
      exact .ok ⟨hf.alloca _ _ _, (Mem.alloc_skel hm _ _ _ _ _ _ _ _ _ _ _).1⟩
  case load vol t p al =>
    obtain ⟨pt, p⟩ := p
    cases pt
    case ptr a =>
      dsimp only
      simp only [hm₁, hm₂]
      simp only [Labels.stmtOk, hpr, Bool.and_eq_true, Bool.not_eq_true', TValue.mentions,
        Bool.or_eq_true] at hok
      simp only [Labels.MemAt] at hM
      rw [hsk _ p hok.1]
      refine .bind_eq _ fun x hx => .bind_eq _ fun q hq => ?_
      obtain rfl := Val.addr?_eq hq
      refine (Mem.load_skel hm (p := q) (t := t) ?_ _ _ _ _).bind fun v₁ v₂ hv => ?_
      · intro hq'
        cases pr
        · exact absurd hq' (hM hpr q hx)
        · simpa using hok.2
      rw [Val.Skel.defined hv.1]
      refine .ite (fun _ => .error _) (fun _ => .ok ⟨hf.next (.some ?_) .none, Mem.log_skel hm _⟩)
      cases pr
      · exact .of_eq hpr (hv.2 (hM hpr q hx))
      · exact .of_rel hpr hv.1
    all_goals exact .error _
  case store vol v p al =>
    obtain ⟨t, v⟩ := v
    obtain ⟨pt, p⟩ := p
    cases pt
    case ptr a =>
      dsimp only
      simp only [hm₁, hm₂]
      simp only [Labels.stmtOk, Bool.and_eq_true, Bool.not_eq_true', TValue.mentions] at hok
      simp only [Labels.MemAt, TValue.mentions] at hM
      refine (hpe (Value.mentions (lab.reg f₁.fn.name) v = false) t v hok.2 id).bind
        fun x₁ x₂ hx => ?_
      rw [hsk _ p hok.1]
      refine .bind_eq _ fun y hy => .bind_eq _ fun q hq => ?_
      obtain rfl := Val.addr?_eq hq
      refine (Mem.store_skel hm hx.1 (fun hn => hx.2 ?_) _ _ _ _ _ _).bind fun _ _ h =>
        .ok ⟨hf.succ, h⟩
      cases hv : Value.mentions (lab.reg f₁.fn.name) v
      · rfl
      · exact absurd (hM hv q hy) hn
    all_goals exact .error _
  case atomicrmw vol op p v sc ord al =>
    obtain ⟨t, v⟩ := v
    obtain ⟨pt, p⟩ := p
    cases pt
    case ptr a =>
      dsimp only
      simp only [hm₁, hm₂]
      rw [congrArg Stmt.checkAtomic hfn]
      simp only [Labels.stmtOk, Bool.and_eq_true, Bool.not_eq_true', TValue.mentions] at hok
      simp only [Labels.MemAt, TValue.mentions] at hM
      refine .ite (fun _ => .bind_eq _ fun _ hc => ?_) (fun _ => .error _)
      have hd := Stmt.checkAtomic_data hc
      rw [hsk _ p hok.1]
      refine .bind_eq _ fun y hy => .bind_eq _ fun q hq => ?_
      obtain rfl := Val.addr?_eq hq
      refine (hpe (Value.mentions (lab.reg f₁.fn.name) v = false) t v hok.2 id).bind
        fun x₁ x₂ hx => ?_
      rw [decide_eq_decide.2 (Val.Skel.scalar hx.1 _)]
      refine .ite (fun _ => ?_) (fun _ => .error _)
      refine (Mem.load_skel hm (p := q) (fun _ => hd) _ _ _ _).bind fun o₁ o₂ ho => ?_
      have hx' : ¬pay q.block → x₁ = x₂ := fun hn => hx.2 (by
        cases hv : Value.mentions (lab.reg f₁.fn.name) v
        · rfl
        · exact absurd (hM hv q hy) hn)
      have hr : Except.Rel (fun r₁ r₂ => r₁.Skel r₂ ∧ (¬pay q.block → r₁ = r₂))
          (rmw (c.prog.layout.scalarBits t) op o₁ x₁)
          (rmw (c.prog.layout.scalarBits t) op o₂ x₂) := by
        by_cases hp : pay q.block
        · exact (rmw_skel _ op ho.1 hx.1).imp fun _ _ h => ⟨h, absurd hp⟩
        · rw [ho.2 hp, hx' hp]
          exact .refl (fun _ => ⟨Val.Skel.refl _, fun _ => rfl⟩) _
      exact hr.bind fun r₁ r₂ hr => (Mem.store_skel (Mem.log_skel hm _) hr.1 hr.2 _ _ _ _ _ _).bind
        fun _ _ h => .ok ⟨hf.succ, h⟩
    all_goals exact .error _

/-- Frames related by `Frame.Skel` stay related when both move to statement `n` of block `l`. -/
theorem Frame.Skel.goto {lab : Labels} {f₁ f₂ : Frame} (hf : f₁.Skel lab f₂) (l n : Nat) :
    Frame.Skel lab { f₁ with label := l, pc := n } { f₂ with label := l, pc := n } := by
  have e := hf.shape
  simp only [Frame.mk.injEq] at e
  refine ⟨?_, hf.regs, hf.prods⟩
  simp only [Frame.mk.injEq]
  exact ⟨e.1, trivial, trivial, e.2.2.2⟩

/-- Frames of a function named `nm` related by `Frame.Skel` stay related after setting in turn the
result register of each statement of two lists of statements and values, with the same statements
and values related at each result's label (the `phi`s of `enter`). -/
theorem Frame.Skel.setAll {lab : Labels} {nm : String} {l₁ l₂ : List (Stmt × Val)}
    (h : List.Forall₂ (fun a b => a.1 = b.1 ∧
      Labels.Rel (a.1.res.any (lab.reg nm)) Val.Skel a.2 b.2) l₁ l₂) :
    ∀ {g₁ g₂ : Frame}, g₁.Skel lab g₂ → g₁.fn.name = nm →
      Frame.Skel lab (l₁.foldl (fun f x => f.set x.1.res (some x.2) none) g₁)
        (l₂.foldl (fun f x => f.set x.1.res (some x.2) none) g₂) := by
  induction h with
  | nil => exact fun hg _ => hg
  | @cons a b _ _ hab _ ih =>
    intro g₁ g₂ hg hn
    obtain ⟨st, v₁⟩ := a
    obtain ⟨st', v₂⟩ := b
    obtain ⟨e, hv⟩ := hab
    dsimp only at e hv
    subst e
    refine ih (hg.set (.some (hn ▸ hv)) .none) ?_
    show (g₁.set st.res (some v₁) none).fn.name = nm
    cases st.res <;> exact hn

/-- For every labelling `lab`, payload blocks `pay`, context, oracle `o`, thread position `k`,
frames related by `Frame.Skel` whose function passes `Labels.funcOk`, memories related by
`Mem.SkelEq` and block `dest`, `enter` (the `phi`s at the head of `dest`) under the context and
under it with oracle `o` gives one fault or frames related by `Frame.Skel`: the incoming values of
a `phi` with a skeleton result are skeleton (`evalV_skel`), and those of one with a payload result
pass `TValue.payOk` (`evalV_pay`). -/
theorem enter_skel {lab : Labels} {pay : Nat → Prop} {c : Ctx} {o : Nat → Nat} {k : Nat}
    {f₁ f₂ : Frame} {m₁ m₂ : Mem} (hf : f₁.Skel lab f₂) (hm : m₁.SkelEq pay m₂)
    (hok : lab.funcOk c.prog f₁.fn = true) (dest : Nat) :
    Except.Rel (Frame.Skel lab) (enter (c.scope m₁ f₁ k) f₁ dest)
      (enter ({ c with oracle := o }.scope m₂ f₂ k) f₂ dest) := by
  have e := hf.shape
  simp only [Frame.mk.injEq] at e
  have hsk : ∀ t v, Value.mentions (lab.reg f₁.fn.name) v = false →
      evalV ({ c with oracle := o }.scope m₂ f₂ k) t v = evalV (c.scope m₁ f₁ k) t v :=
    (evalV_skel (s := c.scope m₁ f₁ k) hm fun n hn =>
      (Labels.Rel.option_eq (hn ▸ hf.regs n)).symm).1
  have hst : ∀ b ∈ f₁.fn.blocks, ∀ st ∈ b.stmts, lab.stmtOk c.prog f₁.fn st = true := by
    intro b hb st hs
    simp only [Labels.funcOk, Bool.and_eq_true, Array.all_eq_true_iff_forall_mem] at hok
    exact (hok.2 b hb).1 st hs
  unfold enter
  rw [← e.1, ← e.2.1]
  generalize hB : Array.find? (fun x => x.label == dest) f₁.fn.blocks = B
  cases B with
  | none => exact .error _
  | some b =>
    dsimp only
    have hS := hst b (Array.mem_of_find?_eq_some hB)
    generalize hP : List.takeWhile (fun x => match x.inst with
      | Inst.phi .. => true
      | _ => false) b.stmts.toList = phis
    have hph : ∀ st ∈ phis, lab.stmtOk c.prog f₁.fn st = true := fun st h =>
      hS st (by rw [← hP] at h; exact Array.mem_toList_iff.1 ((List.takeWhile_sublist _).subset h))
    refine Except.Rel.bind_ok (Except.Rel.mapIdx
      (R := fun j a b => a = b ∧ phis[j]? = some a)
      (S := fun j v₁ v₂ => ∀ st, phis[j]? = some st →
        Labels.Rel (st.res.any (lab.reg f₁.fn.name)) Val.Skel v₁ v₂) ?_ (List.rel_self phis))
      fun vs₁ vs₂ _ hvs => .ok ((Frame.Skel.setAll (List.forall₂_of_rel fun j =>
        (List.rel_zip (List.rel_self phis) hvs j).imp fun _ _ h => ⟨h.1.1, h.2 _ h.1.2⟩)
        hf rfl).goto dest phis.length)
    rintro j a _ ⟨rfl, ha⟩
    have hok := hph a (List.mem_of_getElem? ha)
    refine (Except.Rel.refl (R := Eq) (fun _ => rfl) a.checkMd).bind fun _ _ _ => ?_
    obtain ⟨res, inst, md⟩ := a
    cases inst
    case phi t inc =>
      dsimp only
      cases hi : List.find? (fun x => x.2 == f₁.label) inc with
      | none => exact .error _
      | some x =>
        obtain ⟨v, l⟩ := x
        dsimp only
        have hv : (⟨t, v⟩ : TValue) ∈ inc.map (⟨t, ·.1⟩) :=
          List.mem_map.2 ⟨_, List.mem_of_find?_eq_some hi, rfl⟩
        simp only [Labels.stmtOk] at hok
        refine Except.Rel.imp (R := Labels.Rel (res.any (lab.reg f₁.fn.name)) Val.Skel)
          (fun _ _ h st hs => by rw [ha] at hs; cases hs; exact h) ?_
        cases hpr : res.any (lab.reg f₁.fn.name)
        · simp only [hpr, Bool.false_eq_true, ↓reduceIte, List.all_eq_true,
            Bool.not_eq_true'] at hok
          rw [hsk t v (by simpa only [TValue.mentions] using hok _ hv)]
          exact .refl (Labels.Rel.refl Val.Skel.refl _) _
        · simp only [hpr, ↓reduceIte, List.all_eq_true] at hok
          exact (evalV_pay hm hf.regs t (hok _ hv)).imp fun _ _ h => Labels.Rel.of_rel rfl h
    all_goals exact .error _

end MojoProof.Sem
