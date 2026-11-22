import MojoProof.Kernels
import MojoProof.Sem.Labels
import MojoProofTest.Pending

/-!
# Instances and twins of T3b's labelling checks (`Labels.Ok`, `Labels.MemOk`)

The instance of `Labels.Ok`: `vector_addition` (corpus `vadd/`, `Kernels.vadd.prog`) passes it
with its two loaded floats `%25` and `%27` and their sum `%28` payload (`vadd_ok`). The twins: of
(O1) for addresses, with the stored pointer `%29` payload too it fails, and of (O2), with `%28` not
payload it fails, as the `fadd` of payload operands would have a skeleton result (`vadd_twin`).

The twin of (O1) for control: `branchFn`, whose entry branches on register 0 to one of two blocks
of `ret void`, fails `Labels.Ok` with register 0 payload, and two frames at its entry whose
register 0 holds the `i1` words 1 and 0, related by `Frame.Skel`, step to different blocks, so the
threads after are not related by `Thread.Skel` (`branch_twin`).

The instance of `Labels.MemOk`: for every launch, the grid of one thread that stores the payload
register 0 to block 1 (through the pointer in register 1) and returns (`storeGrid`) meets it with
block 1 payload, by `Labels.MemOk.of_closed` on the three kinds of grid it reaches; its twin: with
no block payload it does not, as the store writes payload outside `pay` (`store_ok`). The instance
of `Labels.MemOk.of_threads`: the grid of three such threads (`storeGrid3`) meets it with block 1
payload, from each thread's statuses on its own (`Store3`: at the store, at `ret void`,
returned) on every memory, as the store's step reaches `ret void` on every memory
(`storeAt_step`); its twin: with no block payload it does not (`store3_ok`). The twin of
`TValue.payOk`: a store of a vector that holds the payload register fails `Labels.Ok`
(`payOk_twin`; an AST form, as the parser refuses a local in a constant). (O3)'s `range`
check at a shuffle: the butterfly shuffle of the constant 5 into the payload register 0
(`shflSt`, `shflProg`) passes `Labels.Ok` when the declaration has no attribute, and fails it when
its result has `range(i32 0, 8)` (`shfl_range_twin`). (O2) and (O3) at `rsqrt.approx`
(`rsqrtProg`): the approximation of a register into the payload register 0 passes `Labels.Ok`, and
fails it with `nnan`, with `ninf`, with a `range` result attribute, or into a skeleton register
(`rsqrt_ok`).

Statements about these programs and this grid.
-/

namespace MojoProofTest.Labels

open MojoProof MojoProof.Sem MojoProof.LLVM MojoProofTest.Pending

-- `Array.all` recurses by well-founded recursion, so `rfl` cannot evaluate `Labels.Ok` without
-- this.
unseal Array.anyM.loop

/-- The registers whose names in `fn` are in `ns` are payload, in every function; no function
has a payload result. -/
def labIn (fn : Func) (ns : List String) : Labels :=
  { reg := fun _ n => (fn.names[n]?).any ns.contains, ret := fun _ => false }

/-- The registers of `vector_addition` named in `ns` are payload; no function has a payload
result. -/
def vaddLab (ns : List String) : Labels := labIn Kernels.vadd.fn_0 ns

/-- The instance of `Labels.Ok`: `vector_addition` passes it with `%25`, `%27` and `%28`
payload. -/
theorem vadd_ok : Labels.Ok Kernels.vadd.prog (vaddLab ["25", "27", "28"]) = true := rfl

/-- The twins: with the stored pointer `%29` payload too, `vector_addition` fails `Labels.Ok`, as
a `store`'s pointer must be skeleton (O1); with `%28` not payload, it fails too, as the `fadd` of
the payload `%25` and `%27` would have a skeleton result (O2). -/
theorem vadd_twin : Labels.Ok Kernels.vadd.prog (vaddLab ["25", "27", "28", "29"]) = false ∧
    Labels.Ok Kernels.vadd.prog (vaddLab ["25", "27"]) = false := ⟨rfl, rfl⟩

/-- Register 0 of every function is payload; no function has a payload result. -/
def lab0 : Labels := { reg := fun _ n => n == 0, ret := fun _ => false }

/-- `define void @b()`: the entry (label 1) branches on register 0 (`%c`) to block 2 or block 3,
each `ret void`. -/
def branchFn : Func :=
  { linkage := [], cconv := none, retAttrs := [], ret := .void, name := "b", params := [],
    group := none, names := #["c", "entry", "t", "f"],
    blocks := #[⟨1, #[], .condBr (.loc 0) 2 3⟩, ⟨2, #[], .ret none⟩, ⟨3, #[], .ret none⟩] }

/-- A frame at the entry of `branchFn` whose register 0 holds the `i1` word `x`. -/
def branchAt (x : BitVec 1) : Frame :=
  { fn := branchFn, label := 1, pc := 0, regs := fun n => if n = 0 then some (.bits 1 x) else none,
    prods := fun _ => none, allocas := [], dest := none }

/-- Thread 0 of block 0 of the program of `f` alone, with the default layout and no globals. -/
def ctxOf (f : Func) : Ctx :=
  ⟨.ofFunc f, fun _ => none, ⟨fun _ _ => 0, 0⟩, ⟨0, 0⟩, fun _ => 0, fun _ => 0⟩

/-- The twin of (O1) for control: with register 0 payload, `branchFn` fails `Labels.Ok`, and the
frames `branchAt 1` and `branchAt 0` are related by `Frame.Skel` but step to blocks 2 and 3, so
the threads after are not related by `Thread.Skel`. -/
theorem branch_twin : Labels.Ok (.ofFunc branchFn) lab0 = false ∧
    (branchAt 1).Skel lab0 (branchAt 0) ∧
    ∃ t₁ t₂ m₁ m₂, step (ctxOf branchFn) ⟨[branchAt 1], 0⟩ {} = .ok (.next t₁ m₁) ∧
      step (ctxOf branchFn) ⟨[branchAt 0], 0⟩ {} = .ok (.next t₂ m₂) ∧
      t₁.at = some ("b", 2, 0) ∧ t₂.at = some ("b", 3, 0) ∧ ¬ t₁.Skel lab0 t₂ := by
  refine ⟨rfl, ⟨rfl, fun r => ?_, fun _ => .none⟩, _, _, _, _, rfl, rfl, rfl, rfl, fun h => ?_⟩
  · by_cases hr : r = 0
    · subst hr
      exact .some (show Val.Skel (.bits 1 1) (.bits 1 0) from rfl)
    · have e : ∀ x : BitVec 1, (if r = 0 then some (Val.bits 1 x) else none) = none :=
        fun _ => ite_eq_right hr
      show Option.Rel _ (if r = 0 then _ else none) (if r = 0 then _ else none)
      rw [e, e]
      exact .none
  · obtain ⟨_, hf⟩ := h
    cases hf with
    | cons hF _ => exact absurd (congrArg Frame.label hF.shape) (by decide)

/-- `store i8 %0, ptr %1`. -/
def store01 : Stmt := { res := none, inst := .store false ⟨.int 8, .loc 0⟩ ⟨.ptr 0, .loc 1⟩ none }

/-- The AST of `store <1 x i8> <i8 %0>, ptr %1`: not LLVM IR (a vector constant has constant
members), and the parser refuses its text. -/
def storeVec : Stmt :=
  { res := none,
    inst := .store false ⟨.vec 1 (.int 8), .vec [⟨.int 8, .loc 0⟩]⟩ ⟨.ptr 0, .loc 1⟩ none }

/-- The twin of `TValue.payOk`, on the AST: `storeVec`, of a vector that holds the payload register
0, fails `Labels.Ok`, though `store01` of register 0 itself passes it (`store_ok`). -/
theorem payOk_twin : Labels.Ok (.ofFunc (kernel #[storeVec])) lab0 = false := rfl

/-- `declare i32 @llvm.nvvm.shfl.sync.bfly.i32()` with result attributes `ats` (the parameters do
not matter here). -/
def shflDecl (ats : List Attr) : Func :=
  { kernel #[] with
    name := "llvm.nvvm.shfl.sync.bfly.i32", ret := .int 32, retAttrs := ats, blocks := #[] }

/-- `%0 = call i32 @llvm.nvvm.shfl.sync.bfly.i32(i32 -1, i32 5, i32 0, i32 31)`: a butterfly
shuffle of the constant 5 into register 0. -/
def shflSt : Stmt :=
  { res := some 0, inst := .call {} (.int 32) (.fn "llvm.nvvm.shfl.sync.bfly.i32")
      (([-1, 5, 0, 31] : List Int).map fun v => (⟨.int 32, .int v⟩, [])) }

/-- The program of `kernel #[shflSt]` and `shflDecl ats`, the declaration as the intrinsic
`shfl.sync.bfly`. -/
def shflProg (ats : List Attr) : Program :=
  { module := { (default : Module) with funcs := #[kernel #[shflSt], shflDecl ats] }, sha256 := "",
    layout := {}, intrinsics := [("llvm.nvvm.shfl.sync.bfly.i32", .shfl .bfly)], kernels := ["k"] }

/-- (O3)'s `range` check at a shuffle: with the payload result register 0 (`lab0`), the
shuffle of the skeleton 5 passes `Labels.Ok` when the declaration has no attribute, and fails it
when the result has `range(i32 0, 8)`, which `resumeAll` applies to the payload result. -/
theorem shfl_range_twin : Labels.Ok (shflProg []) lab0 = true ∧
    Labels.Ok (shflProg [.range (.int 32) 0 8]) lab0 = false := ⟨rfl, rfl⟩

/-- `%r = call fm float @llvm.nvvm.rsqrt.approx.ftz.f(float %a)`. -/
def rsqrtSt (fm : FastMath) (r a : Nat) : Stmt :=
  { res := some r, inst := .call fm (.fp .float) (.fn "llvm.nvvm.rsqrt.approx.ftz.f")
      [(⟨.fp .float, .loc a⟩, [])] }

/-- `declare float @llvm.nvvm.rsqrt.approx.ftz.f(float)` with result attributes `ats` (the
parameters do not matter here). -/
def rsqrtDecl (ats : List Attr) : Func :=
  { kernel #[] with
    name := "llvm.nvvm.rsqrt.approx.ftz.f", ret := .fp .float, retAttrs := ats, blocks := #[] }

/-- The program of `kernel #[rsqrtSt fm r a]` and `rsqrtDecl ats`, the declaration as the
intrinsic `rsqrt.approx`. -/
def rsqrtProg (fm : FastMath) (r a : Nat) (ats : List Attr) : Program :=
  { module := { (default : Module) with funcs := #[kernel #[rsqrtSt fm r a], rsqrtDecl ats] },
    sha256 := "", layout := {}, intrinsics := [("llvm.nvvm.rsqrt.approx.ftz.f", .rsqrtApprox)],
    kernels := ["k"] }

/-- (O2) and (O3) at `rsqrt.approx`, under `lab0`: the approximation of register 1 into the
payload register 0 with no flags passes `Labels.Ok`. The twins: with `nnan`, with `ninf`, or with
`range(i32 0, 8)` on the declaration's result it fails, and so does the approximation into the
skeleton register 1, as the result reads the oracle. -/
theorem rsqrt_ok : Labels.Ok (rsqrtProg {} 0 1 []) lab0 = true ∧
    Labels.Ok (rsqrtProg { nnan := true } 0 1 []) lab0 = false ∧
    Labels.Ok (rsqrtProg { ninf := true } 0 1 []) lab0 = false ∧
    Labels.Ok (rsqrtProg {} 0 1 [.range (.int 32) 0 8]) lab0 = false ∧
    Labels.Ok (rsqrtProg {} 1 2 []) lab0 = false := ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- The contexts of `kernel #[store01]`: every thread number has `ctxOf`'s. -/
def cS : Nat → Ctx := fun _ => ctxOf (kernel #[store01])

/-- A frame at statement `pc` of `kernel #[store01]` whose register 0 holds the data word 7 and
register 1 a pointer to block 1. -/
def storeAt (pc : Nat) : Frame :=
  { fn := kernel #[store01], label := 0, pc,
    regs := fun n => if n = 0 then some (.bits 8 7) else if n = 1 then some (.ptr ⟨1, 0⟩) else none,
    prods := fun _ => none, allocas := [], dest := none }

/-- One thread at `storeAt 0` on the memory of block 1 of 8 live bytes. -/
def storeGrid : Grid := { threads := #[.run ⟨[storeAt 0], 0⟩], mem := memOf [(1, blk 8 true)] }

/-- The grids `storeGrid` reaches: itself, one thread at `ret void` after its step, and one
returned thread, on any memory. -/
def StoreReach (g : Grid) : Prop :=
  g = storeGrid ∨ (∃ m, g = ⟨#[.run ⟨[storeAt 1], 1⟩], m⟩) ∨ ∃ m, g = ⟨#[.done], m⟩

/-- The grids of `StoreReach` step to grids of `StoreReach`, for every launch. -/
theorem storeReach_step (L : Launch) :
    ∀ g g', StoreReach g → Grid.Step L cS g g' → StoreReach g' := by
  rintro g g' (rfl | ⟨m, rfl⟩ | ⟨m, rfl⟩) ⟨n, ha | hf⟩
  · rcases n with _ | n
    · have e : storeGrid.advance cS 0 = .ok (some ⟨#[.run ⟨[storeAt 1], 1⟩], _⟩) := rfl
      rw [e] at ha
      cases ha
      exact .inr (.inl ⟨_, rfl⟩)
    · simp [Grid.advance, storeGrid, pure, Except.pure] at ha
  · rcases n with _ | n <;> simp [Grid.fire, storeGrid, pure, Except.pure] at hf
  · rcases n with _ | n
    · have e : Grid.advance cS ⟨#[.run ⟨[storeAt 1], 1⟩], m⟩ 0 = .ok (some ⟨#[.done], m⟩) := rfl
      rw [e] at ha
      cases ha
      exact .inr (.inr ⟨_, rfl⟩)
    · simp [Grid.advance, pure, Except.pure] at ha
  · rcases n with _ | n <;> simp [Grid.fire, pure, Except.pure] at hf
  · rcases n with _ | n <;> simp [Grid.advance, pure, Except.pure] at ha
  · rcases n with _ | n <;> simp [Grid.fire, pure, Except.pure] at hf

/-- The instance of `Labels.MemOk`: for every launch, `storeGrid` with register 0 payload meets it
with block 1 payload (`Labels.MemOk.of_closed` on `StoreReach`), and `kernel #[store01]` passes
`Labels.Ok`; the twin: with no block payload it does not meet it, as its store writes payload to
block 1. -/
theorem store_ok (L : Launch) : Labels.Ok (.ofFunc (kernel #[store01])) lab0 = true ∧
    lab0.MemOk (· = 1) L cS storeGrid ∧ ¬ lab0.MemOk (fun _ => False) L cS storeGrid := by
  have hM : ∀ pay : Nat → Prop, lab0.MemAll pay cS storeGrid → pay 1 := fun pay h =>
    h 0 _ rfl _ _ _ _ rfl rfl rfl rfl _ rfl
  refine ⟨rfl, .of_closed StoreReach (.inl rfl) (storeReach_step L) ?_, fun h => hM _ (h _ .refl)⟩
  rintro g (rfl | ⟨m, rfl⟩ | ⟨m, rfl⟩) n t ht f rest b st hf hb hs
  · rcases n with _ | n
    · cases ht
      cases hf
      cases hb
      cases hs
      rintro - q hq
      cases hq
      rfl
    · simp [storeGrid] at ht
  · rcases n with _ | n
    · cases ht
      cases hf
      cases hb
      simp [storeAt, kernel] at hs
    · simp at ht
  · rcases n with _ | n <;> simp at ht

/-- On every memory, a step of `⟨[storeAt 0], 0⟩` that succeeds reaches `⟨[storeAt 1], 1⟩`. -/
theorem storeAt_step (n : Nat) (m : Mem) {r : Step} (h : step (cS n) ⟨[storeAt 0], 0⟩ m = .ok r) :
    ∃ m', r = .next ⟨[storeAt 1], 1⟩ m' := by
  obtain ⟨e, he, h⟩ := Except.bind_eq_ok.1
    (show Except.bind (exec (cS n) ((cS n).scope m (storeAt 0) 0) 0 (storeAt 0) store01) _ = .ok r
      from h)
  obtain ⟨m', -, he⟩ := Except.bind_eq_ok.1
    (show Except.bind (m.store (cS n).prog.layout (cS n).who 0 (.int 8) (.bits 8 7) ⟨1, 0⟩
        (some ((cS n).prog.layout.align (.int 8)))) _ = .ok e from he)
  simp only [pure, Except.pure, Except.ok.injEq] at he
  subst he
  simp only [pure, Except.pure, Except.ok.injEq] at h
  exact ⟨m', h.symm⟩

/-- Three threads at `storeAt 0`, each to store the payload register 0 to block 1, on the memory of
block 1 of 8 live bytes. -/
def storeGrid3 : Grid :=
  { threads := #[.run ⟨[storeAt 0], 0⟩, .run ⟨[storeAt 0], 0⟩, .run ⟨[storeAt 0], 0⟩],
    mem := memOf [(1, blk 8 true)] }

/-- The statuses of thread `n` of `storeGrid3` on its own: at the store, at `ret void`, or
returned. -/
def Store3 (n : Nat) (s : Status) : Prop :=
  n < 3 ∧ (s = .run ⟨[storeAt 0], 0⟩ ∨ s = .run ⟨[storeAt 1], 1⟩ ∨ s = .done)

/-- The instance of `Labels.MemOk.of_threads`: for every launch, `storeGrid3` meets `Labels.MemOk`
with block 1 payload, with every memory and the statuses `Store3`; the twin: with no block payload
it does not, as each store writes payload to block 1. -/
theorem store3_ok (L : Launch) : lab0.MemOk (· = 1) L cS storeGrid3 ∧
    ¬ lab0.MemOk (fun _ => False) L cS storeGrid3 := by
  refine ⟨.of_threads (fun _ => True) Store3 (fun _ _ _ _ _ h => by simp [Store3] at h)
    ⟨trivial, fun n s hs => ?_⟩ ?_ ?_, fun h => h _ .refl 0 _ rfl _ _ _ _ rfl rfl rfl rfl _ rfl⟩
  · rcases n with _ | _ | _ | n <;> simp [storeGrid3] at hs ⊢ <;> simp [Store3, ← hs]
  · intro g g' n t _ hR ht h
    have hlt : n < g.threads.size := (Array.getElem?_eq_some_iff.1 ht).1
    obtain ⟨hn, e | e | e⟩ := hR n _ ht
    · cases e
      simp only [Grid.advance, ht] at h
      obtain ⟨r, hr, h⟩ := Except.bind_eq_ok.1 h
      obtain ⟨m', rfl⟩ := storeAt_step n g.mem hr
      simp only [pure, Except.pure, Except.ok.injEq, Option.some.injEq] at h
      subst h
      refine ⟨trivial, fun s hs => ⟨hn, .inr (.inl ?_)⟩⟩
      simp [Array.set!_eq_setIfInBounds, hlt] at hs
      exact hs.symm
    · cases e
      have es : step (cS n) ⟨[storeAt 1], 1⟩ g.mem = .ok (.done g.mem) := rfl
      simp only [Grid.advance, ht, es, bind, Except.bind, pure, Except.pure, Except.ok.injEq,
        Option.some.injEq] at h
      subst h
      refine ⟨trivial, fun s hs => ⟨hn, .inr (.inr ?_)⟩⟩
      simp [Array.set!_eq_setIfInBounds, hlt] at hs
      exact hs.symm
    · cases e
  · intro g n t _ hR ht f rest b st hf hb hs
    obtain ⟨-, e | e | e⟩ := hR n _ ht
    · cases e
      cases hf
      cases hb
      cases hs
      rintro - q hq
      cases hq
      rfl
    · cases e
      cases hf
      cases hb
      simp [storeAt, kernel] at hs
    · cases e

end MojoProofTest.Labels
