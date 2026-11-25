import MojoProof.Sem.Names

/-!
# The closed-grid invariant, and waiting threads at their calls

The closed-grid invariant (W1 of docs/proofs/schedule-owned.md, section "The closed-grid
invariant"). A number is *known* to a memory (`Mem.Known`) if it is below `next` or has a block.
`Grid.Closed c g`: null, every global of every thread's context `c n`, every pointer byte below the
size of a block (`Mem.BytesIn`), and every value in a register of a frame of a thread or in the
arguments of the collective call a thread waits at (`Status.NamesIn`) name only known numbers. Every
step and every fire keeps it (`Grid.advance_closed`, `Grid.fire_closed`), so every grid reachable
from a closed grid is closed (`Grid.reach_closed`). With `Grid.reach_keeps` this gives C1 of that
document: a known number with no block is below `next` (`Mem.Known.below`), so it has no block in
any grid reachable from there, and the pending accesses of a running thread of a closed grid are the
same in every grid reachable from it (`Grid.pending_reach`, by `Thread.pending_shape`).

The parts, for every program, context, launch, choice and memory: values and the memory are in
MojoProof/Sem/Names.lean (`Mem.Known`, `Mem.BytesIn`, a lemma per operation, loads, stores and
allocations); here are frames (`Frame.set_namesIn`, `intrinsic_namesIn`), statements
(`exec_closed`), `phi`s (`enter_closed`), steps (`step_closed`) and resumes
(`Thread.resume_namesIn`, `resumeAll_namesIn`). The invariant leaves out a frame's `prods` (the
`fmul` operands, from which an operation gives only floats) and `allocas` (a return's `setLive` adds
no number).

The start (section Start): the grid that `Grid.start` gives is closed if every pointer byte below
the size of a block of the caller's memory names a number below `next` or with a block
(`Grid.start_closed`; a closed memory has that, `Mem.Closed.bytesIn`; the start's check gives the
rest, `Mem.checkClosed_ok`), through `Mem.allocNext_closed`, `shared_closed`, `launchArgs_closed`
and `Thread.start_namesIn`. So every grid reachable from the start is closed, and a running thread
of the start's grid has the same pending accesses in each (`Grid.start_reach_closed`,
`Grid.start_pending`), for every program, kernel, launch, arguments, memory with that property,
address choice and oracle.

Waiting threads at their calls (section Waits; the second part of W5 of
docs/proofs/schedule-owned.md): a waiting thread is at its collective call. `Thread.AtCall c t i
fn`: the current statement of `t` calls `fn`, the function of `c`'s module whose intrinsic is `i`, a
declaration (`exec` waits only at a function without blocks). A step that waits is at its call
(`exec_wait`, `step_wait`), a fire only resumes threads, so every step and fire keeps `Grid.AtCalls`
(every waiting thread `n` is at its call in context `c n`; `Grid.advance_atCalls`,
`Grid.fire_atCalls`, `Grid.reach_atCalls`). Every thread of the start's grid runs at the start of
the kernel (`Grid.start_run`, `Grid.start_atCalls`), so this holds of every grid reachable from the
start, for every program, kernel, launch, arguments, memory and choices
(`Grid.start_reach_atCalls`).
-/

namespace MojoProof.Sem

open FloatLib.Floats.Formats.BinaryInterchange LLVM

section Frames

variable {S T : Nat → Prop}

/-- Every register of frame `f` holds a value that names only numbers of `S`. -/
def Frame.NamesIn (S : Nat → Prop) (f : Frame) : Prop := ∀ r v, f.regs r = some v → v.NamesIn S

/-- A frame whose registers name only numbers of `S` names only numbers of every `T` that has
every number of `S`. -/
theorem Frame.NamesIn.mono {f : Frame} (h : ∀ b, S b → T b) (hf : f.NamesIn S) : f.NamesIn T :=
  fun r v hr => Val.NamesIn.mono h (hf r v hr)

/-- Setting register `r` (if any) of a frame whose registers name only numbers of `S` to a value
`v` (if any) that does keeps that, whatever `fmul contract` operands `prod` it records. -/
theorem Frame.set_namesIn {f : Frame} (hf : f.NamesIn S) {r : Option Nat} {v : Option Val}
    (hv : ∀ x, v = some x → x.NamesIn S) (prod : Option (Val × Val)) :
    (f.set r v prod).NamesIn S := by
  unfold Frame.set
  split
  · intro q x hq
    simp only at hq
    split at hq
    · cases hq
      exact hv _ rfl
    · exact hf q x hq
  · exact hf

/-- The value of an intrinsic that completes names only numbers of `S` if its arguments do, and
its memory keeps that every pointer byte names a number of `S`. -/
theorem intrinsic_namesIn {c : Ctx} {s : Scope} {fm : FastMath} {i : Intrinsic}
    {args : List Val} {v : Option Val} {m' : Mem} (h : intrinsic c s fm i args = .ok (some (v, m')))
    (hargs : ∀ x ∈ args, x.NamesIn S) :
    (∀ x, v = some x → x.NamesIn S) ∧ (s.mem.BytesIn S → m'.BytesIn S) := by
  unfold intrinsic at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals refine ⟨fun x hx => ?_, fun hm => ?_⟩
  all_goals first
    | exact hm
    | exact Mem.setLive_bytesIn hm _ _
    | (cases hx; done)
    | cases hx
      first
        | trivial
        | exact fill_namesIn (x := .poison) trivial _
        | (unfold Option.elim; split <;> trivial)
        | exact lanes2_namesIn (fun _ _ _ _ hw hx hy => intMinMax_namesIn hw hx hy) ‹_›
            (hargs _ (by simp)) (hargs _ (by simp))
        | (refine lanes2_namesIn ?_ ‹_› (hargs _ (by simp)) (hargs _ (by simp))
           intro _ _ _ _ hw hx hy
           exact floats2_namesIn (fun _ _ => by split <;> trivial) hw hx hy)
        | exact Val.allNamesIn_iff.2 fun y hy => Val.allNamesIn_iff.1 (hargs (.vec _) (by simp))
            y (List.mem_of_mem_drop (List.mem_of_mem_take hy))
        | (refine Val.allNamesIn_iff.2 fun y hy => ?_
           obtain ⟨j, -, rfl⟩ := List.mem_map.1 hy
           trivial)

end Frames

section Exec

set_option maxHeartbeats 400000 in
/-- The closed-grid invariant for statements: a statement of a frame whose scope, registers and
memory's pointer bytes name only known numbers continues to a frame and memory that do, or calls or
waits with arguments that do. -/
theorem exec_closed {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {e : Eff}
    (h : exec c s k f st = .ok e) (hs : s.NamesIn s.mem.Known) (hf : f.NamesIn s.mem.Known)
    (hm : s.mem.BytesIn s.mem.Known) :
    match e with
    | .next f' m' => f'.NamesIn m'.Known ∧ m'.BytesIn m'.Known
    | .call _ args | .wait _ args _ => ∀ x ∈ args, x.NamesIn s.mem.Known := by
  have hk := exec_keeps h
  have ev := fun t v => (evalV_shape (m' := s.mem) hs (fun _ _ => rfl) t v).2
  have evt := fun v => (evalTV_shape (m' := s.mem) hs (fun _ _ => rfl) v).2
  unfold exec at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals dsimp only at hk ⊢
  all_goals first
    | cases ‹throw _ = Except.ok _›
    | (refine mapM_mem ‹_› ?_
       rintro ⟨⟨p, v⟩, tv, as⟩ hq w hw
       refine withAttrs_namesIn hw ?_
       refine mapM_mem ‹_› ?_ v (List.of_mem_zip (List.of_mem_zip hq).1).2
       rintro ⟨tv, _⟩ - y hy
       exact evt _ _ hy)
    | (have hi := intrinsic_namesIn (S := s.mem.Known) ‹_› ?args
       case args =>
         refine mapM_mem ‹_› ?_
         rintro ⟨⟨p, v⟩, tv, as⟩ hq w hw
         refine withAttrs_namesIn hw ?_
         refine mapM_mem ‹_› ?_ v (List.of_mem_zip (List.of_mem_zip hq).1).2
         rintro ⟨tv, _⟩ - y hy
         exact evt _ _ hy
       exact ⟨Frame.NamesIn.mono hk.known (Frame.set_namesIn hf
           (Option.mapM_namesIn ‹_› fun x hx y hy => withAttrs_namesIn hy (hi.1 x hx)) _),
         Mem.BytesIn.mono hk.known (hi.2 hm)⟩)
    | (refine ⟨Frame.NamesIn.mono hk.known ?_, Mem.BytesIn.mono hk.known ?_⟩
       · first
           | exact hf
           | (refine Frame.set_namesIn hf (fun x hx => ?_) _
              cases hx
              first
                | (refine lanes2_namesIn ?_ ‹_› (ev _ _ _ ‹_›) (ev _ _ _ ‹_›)
                   intros
                   first | exact intBin_namesIn ‹_› | exact floatBin_namesIn ‹_›)
                | exact fnegV_namesIn ‹_› (ev _ _ _ ‹_›)
                | exact icmpV_namesIn ‹_› (ev _ _ _ ‹_›) (ev _ _ _ ‹_›)
                | exact fcmpV_namesIn ‹_› (ev _ _ _ ‹_›) (ev _ _ _ ‹_›)
                | exact castV_namesIn (ev _ _ _ ‹_›) ‹_›
                | exact selectV_namesIn ‹_› (ev _ _ _ ‹_›) (ev _ _ _ ‹_›)
                | exact gep_namesIn (ev _ _ _ ‹_›) ‹_›
                | exact extractV_namesIn ‹_› (ev _ _ _ ‹_›)
                | exact insertV_namesIn ‹_› (ev _ _ _ ‹_›) (ev _ _ _ ‹_›)
                | exact extractE_namesIn ‹_› (ev _ _ _ ‹_›)
                | exact insertE_namesIn ‹_› (ev _ _ _ ‹_›) (evt _ _ ‹_›)
                | exact shuffleV_namesIn ‹_› (ev _ _ _ ‹_›) (evt _ _ ‹_›)
                | exact Mem.load_namesIn hs.null hm ‹_›)
       · first
           | exact hm
           | exact Mem.store_bytesIn ‹_› hm (ev _ _ _ ‹_›)
           | (refine Mem.store_bytesIn ‹_› ?_ (rmw_namesIn ‹_› (Mem.load_namesIn hs.null hm ‹_›)
                (ev _ _ _ ‹_›))
              exact hm))
    | (refine ⟨Frame.set_namesIn (Frame.NamesIn.mono hk.known hf) (fun x hx => ?_) _, ?_⟩
       · cases hx
         exact Mem.alloc_known ..
       · exact Mem.BytesIn.mono hk.known
           (Mem.alloc_bytesIn hm (fun _ _ h => by cases h) _ _ _ _ _ _ _ _ _ _))

end Exec

section Threads

variable {S T : Nat → Prop}

/-- The closed-grid invariant for the `phi`s: a frame whose scope and registers name only numbers of
`S` enters a block with registers that do. -/
theorem enter_closed {s : Scope} {f f' : Frame} {d : Nat} (h : enter s f d = .ok f')
    (hs : s.NamesIn S) (hf : f.NamesIn S) : f'.NamesIn S := by
  unfold enter at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  split at h
  · split at h
    · cases h
    rename_i vals hv
    cases h
    intro r v hr
    refine foldl_inv (P := Frame.NamesIn S) (Q := fun q : Stmt × Val => q.2.NamesIn S) ?_ _ f ?_ hf
      r v hr
    · rintro f ⟨st, v⟩ hq hf
      exact Frame.set_namesIn hf (fun x hx => by cases hx; exact hq) _
    · rintro ⟨st, v⟩ hq
      show v.NamesIn S
      refine mapM_mem hv (fun st _ y hy => ?_) v (List.of_mem_zip hq).2
      repeat' split at hy
      all_goals first
        | cases hy
        | exact (evalV_shape (m' := s.mem) hs (fun _ _ => rfl) _ _).2 _ hy
  · cases h

/-- Every frame of thread `t` names only numbers of `S`. -/
def Thread.NamesIn (S : Nat → Prop) (t : Thread) : Prop := ∀ f ∈ t.frames, f.NamesIn S

/-- A thread whose frames name only numbers of `S` names only numbers of every `T` that has
every number of `S`. -/
theorem Thread.NamesIn.mono {t : Thread} (h : ∀ b, S b → T b) (ht : t.NamesIn S) :
    t.NamesIn T :=
  fun f hf => (ht f hf).mono h

/-- The closed-grid invariant for steps: a step of a thread whose frames and memory's pointer bytes
name only known numbers, with null and every global known, continues to a thread and memory that do,
waits with arguments that do, or returns with a memory that does. -/
theorem step_closed {c : Ctx} {t : Thread} {m : Mem} {r : Step} (h : step c t m = .ok r)
    (h0 : m.Known 0) (hg : ∀ x p, c.globals x = some p → m.Known p.block)
    (ht : t.NamesIn m.Known) (hm : m.BytesIn m.Known) :
    match r with
    | .next t' m' => t'.NamesIn m'.Known ∧ m'.BytesIn m'.Known
    | .wait _ args _ => ∀ x ∈ args, x.NamesIn m.Known
    | .done m' => m'.BytesIn m'.Known := by
  have hk := step_keeps h
  unfold step at h
  rcases hf : t.frames with _ | ⟨f, rest⟩
  · simp only [hf] at h
    cases h
  have hfr : ∀ g ∈ f :: rest, g.NamesIn m.Known := fun g hg => ht g (by rw [hf]; exact hg)
  have hs : (c.scope m f t.k).NamesIn m.Known := ⟨h0, hfr f List.mem_cons_self, hg⟩
  have evt := fun v => (evalTV_shape (m' := m) hs (fun _ _ => rfl) v).2
  simp only [hf] at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals dsimp only [Thread.NamesIn] at hk ⊢
  all_goals first
    | cases ‹throw _ = Except.ok _›
    | (obtain ⟨he1, he2⟩ := exec_closed (e := .next _ _) ‹_› hs (hfr f List.mem_cons_self) hm
       exact ⟨List.forall_mem_cons.2 ⟨he1, fun g hg =>
         (hfr g (List.mem_cons_of_mem _ hg)).mono hk.known⟩, he2⟩)
    | exact exec_closed (e := .wait _ _ _) ‹_› hs (hfr f List.mem_cons_self) hm
    | (have he := exec_closed (e := .call _ _) ‹_› hs (hfr f List.mem_cons_self) hm
       refine ⟨List.forall_mem_cons.2 ⟨fun r v hr => ?_, hfr⟩, hm⟩
       dsimp only at hr
       obtain ⟨⟨p, w⟩, hq, rfl⟩ := Option.map_eq_some_iff.1 hr
       exact he _ (List.of_mem_zip (List.mem_of_find?_eq_some hq)).2)
    | exact ⟨List.forall_mem_cons.2 ⟨enter_closed ‹_› hs (hfr f List.mem_cons_self),
        fun g hg => hfr g (List.mem_cons_of_mem _ hg)⟩, hm⟩
    | exact Mem.BytesIn.mono hk.known (Mem.foldl_setLive_bytesIn hm _ _)
    | (refine ⟨List.forall_mem_cons.2 ⟨Frame.NamesIn.mono hk.known (Frame.set_namesIn
          (hfr _ (List.mem_cons_of_mem _ List.mem_cons_self)) ?_ _),
          fun g' hg' => (hfr g' (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ hg'))).mono
            hk.known⟩,
          Mem.BytesIn.mono hk.known (Mem.foldl_setLive_bytesIn hm _ _)⟩
       refine Option.mapM_namesIn ‹_› fun x _ y hy => ?_
       split at hy
       · cases hy
       · exact withAttrs_namesIn hy (evt _ _ ‹_›))

/-- A waiting thread resumed with a result that names only numbers of `S` names only them. -/
theorem Thread.resume_namesIn {t : Thread} (ht : t.NamesIn S) {v : Option Val}
    (hv : ∀ x, v = some x → x.NamesIn S) : (t.resume v).NamesIn S := by
  unfold Thread.resume
  split
  · rename_i f rest hf
    intro g hg
    rcases List.mem_cons.1 hg with rfl | hg
    · exact Frame.set_namesIn (ht _ (by rw [hf]; exact List.mem_cons_self)) hv _
    · exact ht _ (by rw [hf]; exact List.mem_cons_of_mem _ hg)
  · exact ht

end Threads

section Grids

variable {S T : Nat → Prop}

/-- Thread state `s` names only numbers of `S`: its frames do, and so do the arguments of the
collective call it waits at. -/
def Status.NamesIn (S : Nat → Prop) : Status → Prop
  | .run t => t.NamesIn S
  | .wait t _ args _ => t.NamesIn S ∧ ∀ x ∈ args, x.NamesIn S
  | .done => True

/-- A thread state that names only numbers of `S` names only numbers of every `T` that has
every number of `S`. -/
theorem Status.NamesIn.mono {s : Status} (h : ∀ b, S b → T b) (hs : s.NamesIn S) :
    s.NamesIn T := by
  cases s with
  | run t => exact Thread.NamesIn.mono h hs
  | wait t i args fn =>
    exact ⟨Thread.NamesIn.mono h hs.1, fun x hx => Val.NamesIn.mono h (hs.2 x hx)⟩
  | done => trivial

/-- A property of every member of an array holds of every member after a `set!` with a member
that has it. -/
theorem set!_inv {α : Type} {P : Nat → α → Prop} {xs : Array α} {a : α} {n : Nat}
    (hxs : ∀ (j : Nat) x, xs[j]? = some x → P j x) (ha : P n a) :
    ∀ (j : Nat) x, (xs.set! n a)[j]? = some x → P j x := by
  intro j x hj
  rw [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds] at hj
  split at hj
  · split at hj
    · cases hj
      subst ‹n = j›
      exact ha
    · cases hj
  · exact hxs j x hj

/-- The closed-grid invariant (W1 of docs/proofs/schedule-owned.md): every number that grid `g`
names is known to its memory (below `next` or with a block): null, every global of every thread's
context, every pointer byte of the memory, and every value in a thread's registers or in the
arguments of the collective call it waits at. -/
structure Grid.Closed (c : Nat → Ctx) (g : Grid) : Prop where
  /-- The invariant from its four parts. -/
  mk ::
  /-- Null's number 0 is known. -/
  null : g.mem.Known 0
  /-- Every thread's state names only known numbers (`Status.NamesIn`). -/
  threads : ∀ (n : Nat) s, g.threads[n]? = some s → s.NamesIn g.mem.Known
  /-- Every pointer byte below the size of a block names a known number (`Mem.BytesIn`). -/
  bytes : g.mem.BytesIn g.mem.Known
  /-- Every global of every thread's context `c n` points into a known number. -/
  globals : ∀ n x p, (c n).globals x = some p → g.mem.Known p.block

/-- A closed grid with thread `n` set to a state that names only known numbers, on a memory that
keeps every block, is closed. -/
theorem Grid.Closed.set {c : Nat → Ctx} {g : Grid} (hg : g.Closed c) {m : Mem}
    (hk : g.mem.Keeps m) (hm : m.BytesIn m.Known) {n : Nat} {s : Status}
    (hs : s.NamesIn m.Known) : Grid.Closed c { threads := g.threads.set! n s, mem := m } where
  null := hk.known _ hg.null
  threads := set!_inv (P := fun _ s => s.NamesIn m.Known)
    (fun j x hj => (hg.threads j x hj).mono hk.known) hs
  bytes := hm
  globals n x p hp := hk.known _ (hg.globals n x p hp)

/-- The closed-grid invariant for the grid's steps: a step of thread `n` keeps the grid closed. -/
theorem Grid.advance_closed {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.advance c n = .ok (some g')) (hg : g.Closed c) : g'.Closed c := by
  unfold Grid.advance at h
  split at h
  · rename_i t ht
    simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      have hk := step_keeps hr
      have hc := step_closed hr hg.null (hg.globals n) (hg.threads n _ ht) hg.bytes
      split at h <;> cases h <;> dsimp only at hk hc
      · exact hg.set hk hc.2 hc.1
      · exact hg.set (Mem.Keeps.refl _) hg.bytes ⟨hg.threads n _ ht, hc⟩
      · exact hg.set hk hc trivial
  · cases h

/-- A property of the threads by number holds after `resumeAll` if it holds before and a
thread that waits keeps it when resumed with its result. -/
theorem resumeAll_inv {l : Layout} {m : Mem} {ts ts' : Array Status} {ns : List Nat}
    {v : Nat → Option Val} {P : Nat → Status → Prop} (h : resumeAll l m ts ns v = .ok ts')
    (hP : ∀ n t i args fn r, P n (.wait t i args fn) →
      (v n).mapM (withAttrs l m fn.ret fn.retAttrs) = .ok r → P n (.run (t.resume r)))
    (hts : ∀ (j : Nat) s, ts[j]? = some s → P j s) :
    ∀ (j : Nat) s, ts'[j]? = some s → P j s := by
  unfold resumeAll at h
  refine foldlM_inv (P := fun ts : Array Status => ∀ (j : Nat) s, ts[j]? = some s → P j s)
    (fun ts n ts' hs hts => ?_) _ _ h hts
  split at hs
  · rename_i t i args fn hn
    simp only [bind, Except.bind, pure, Except.pure] at hs
    split at hs
    · cases hs
    · cases hs
      exact set!_inv hts (hP _ _ _ _ _ _ (hts _ _ hn) ‹_›)
  · cases hs
    exact hts

/-- The threads that `resumeAll` resumes name only numbers of `S` if the threads before do and
so do the results. -/
theorem resumeAll_namesIn {l : Layout} {m : Mem} {ts ts' : Array Status} {ns : List Nat}
    {v : Nat → Option Val} (h : resumeAll l m ts ns v = .ok ts')
    (hts : ∀ (j : Nat) s, ts[j]? = some s → s.NamesIn S) (hv : ∀ n x, v n = some x → x.NamesIn S) :
    ∀ (j : Nat) s, ts'[j]? = some s → s.NamesIn S :=
  resumeAll_inv (P := fun _ s => s.NamesIn S) h (fun _ _ _ _ _ _ ht hr =>
    Thread.resume_namesIn ht.1
      (Option.mapM_namesIn hr fun _ hx _ hy => withAttrs_namesIn hy (hv _ _ hx))) hts

/-- The value `getD` gives from `find?` and a map names only numbers of `S` if the map does on
every member. -/
theorem find?_getD_namesIn {α : Type} {xs : List α} {p : α → Bool} {F : α → Val}
    (hF : ∀ q ∈ xs, (F q).NamesIn S) : (((xs.find? p).map F).getD .poison).NamesIn S := by
  cases hq : xs.find? p with
  | none => trivial
  | some q => exact hF q (List.mem_of_find?_eq_some hq)

/-- The closed-grid invariant for fires: a collective call that completes keeps the grid closed. -/
theorem Grid.fire_closed {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.fire L c n = .ok (some g')) (hg : g.Closed c) : g'.Closed c := by
  unfold Grid.fire at h
  cases hn : g.threads[n]? with
  | none => simp [hn, pure, Except.pure] at h
  | some s =>
    cases s with
    | run t => simp [hn, pure, Except.pure] at h
    | done => simp [hn, pure, Except.pure] at h
    | wait t i args r =>
      simp only [hn] at h
      repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
      all_goals cases h
      all_goals first
        | cases ‹throw _ = Except.ok _›
        | exact ⟨(Mem.log_keeps _ _).known _ hg.null,
            resumeAll_namesIn ‹_› (fun j s hs => (hg.threads j s hs).mono (Mem.log_keeps _ _).known)
              (fun _ _ h => by cases h),
            Mem.BytesIn.mono (Mem.log_keeps _ _).known hg.bytes,
            fun n x p hp => (Mem.log_keeps _ _).known _ (hg.globals n x p hp)⟩
        | (refine ⟨hg.null, resumeAll_namesIn ‹_› hg.threads ?_, hg.bytes, hg.globals⟩
           intro k x hx
           obtain ⟨⟨j, a, b, d⟩, -, rfl⟩ := Option.map_eq_some_iff.1 hx
           refine find?_getD_namesIn fun q hq => ?_
           refine mapM_mem_option
             (P := fun q : Nat × Val × Nat × Nat => Val.NamesIn g.mem.Known q.2.1)
             ‹_› (fun o ho y hy => ?_) q hq
           cases hy
           refine mapM_mem (P := fun o : Option (Nat × Val × Nat × Nat) =>
             ∀ y, o = some y → Val.NamesIn g.mem.Known y.2.1) ‹_› ?_ _ ho _ rfl
           intro j _ o ho y hy
           subst hy
           repeat' split at ho
           all_goals first
             | cases ‹throw _ = Except.ok _›
             | (cases ho; done)
             | (cases ho
                have hw := hg.threads _ _ ‹_›
                exact hw.2 _ (by simp)))
        | (refine ⟨hg.null, resumeAll_namesIn ‹_› hg.threads ?_, hg.bytes, hg.globals⟩
           intro k x hx
           cases hx
           obtain ⟨_, hy, -⟩ := mmaRes_ok ‹_›
           obtain ⟨rs, e, hrs⟩ := mmaGrid_agg hy (k - _)
           rw [e]
           exact Val.allNamesIn_iff.2 fun r hr => by
             obtain ⟨w, b, rfl⟩ := hrs r hr
             trivial)

/-- A property of grids that every step of a thread and every fire keeps holds of every grid
reachable from a grid that has it. -/
theorem Grid.reach_inv {L : Launch} {c : Nat → Ctx} {P : Grid → Prop}
    (ha : ∀ g g' n, g.advance c n = .ok (some g') → P g → P g')
    (hf : ∀ g g' n, g.fire L c n = .ok (some g') → P g → P g') {g g' : Grid}
    (h : Relation.ReflTransGen (Grid.Step L c) g g') (hg : P g) : P g' := by
  induction h with
  | refl => exact hg
  | tail _ hs ih =>
    obtain ⟨n, hn | hn⟩ := hs
    · exact ha _ _ _ hn ih
    · exact hf _ _ _ hn ih

/-- Every grid reachable from a closed grid is closed, for every launch and context map. -/
theorem Grid.reach_closed {L : Launch} {c : Nat → Ctx} {g g' : Grid}
    (h : Relation.ReflTransGen (Grid.Step L c) g g') (hg : g.Closed c) : g'.Closed c :=
  Grid.reach_inv (fun _ _ _ => Grid.advance_closed) (fun _ _ _ => Grid.fire_closed) h hg

/-- The pending accesses of a running thread of a closed grid are the same on the memory of every
grid reachable from it: a known number with no block keeps no block, so the blocks the thread names
keep their shape (`Grid.reach_keeps`, `Thread.pending_shape`). -/
theorem Grid.pending_reach {L : Launch} {c : Nat → Ctx} {g g' : Grid} (hg : g.Closed c)
    (h : Relation.ReflTransGen (Grid.Step L c) g g') {n : Nat} {t : Thread}
    (ht : g.threads[n]? = some (.run t)) : t.pending (c n) g'.mem = t.pending (c n) g.mem :=
  Thread.pending_shape ((Grid.reach_keeps h).sameShape fun _ hb hn => hb.below hn)
    fun f hf => ⟨hg.null, hg.threads n _ ht f (List.mem_of_mem_head? hf), hg.globals n⟩

end Grids

section Waits

/-- Thread `t` is at a call of `fn`, the function of context `c`'s module whose intrinsic is `i`,
a declaration (no blocks): its current statement calls it. -/
def Thread.AtCall (c : Ctx) (t : Thread) (i : Intrinsic) (fn : Func) : Prop :=
  ∃ f rest b st fm ty g args, t.frames = f :: rest ∧
    f.fn.blocks.find? (·.label == f.label) = some b ∧ b.stmts[f.pc]? = some st ∧
    st.inst = .call fm ty (.fn g) args ∧
    c.prog.module.funcs.find? (·.name == g) = some fn ∧ fn.blocks.isEmpty = true ∧
    c.prog.intrinsics.lookup g = some i

/-- A statement that stops at a collective intrinsic `i` declared by `fn` is a call of `fn`, the
declaration of the module whose intrinsic is `i`. -/
theorem exec_wait {c : Ctx} {s : Scope} {k : Nat} {f : Frame} {st : Stmt} {i : Intrinsic}
    {args : List Val} {fn : Func} (h : exec c s k f st = .ok (.wait i args fn)) :
    ∃ fm ty g as, st.inst = .call fm ty (.fn g) as ∧
      c.prog.module.funcs.find? (·.name == g) = some fn ∧ fn.blocks.isEmpty = true ∧
      c.prog.intrinsics.lookup g = some i := by
  unfold exec at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals exact ⟨_, _, _, _, ‹_›, ‹_›, Bool.not_not_eq.mp ‹¬(!_) = true›, ‹_›⟩

/-- A thread whose step waits at intrinsic `i` declared by `fn` is at its call. -/
theorem step_wait {c : Ctx} {t : Thread} {m : Mem} {i : Intrinsic} {args : List Val} {fn : Func}
    (h : step c t m = .ok (.wait i args fn)) : t.AtCall c i fn := by
  unfold step at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  obtain ⟨fm, ty, g, as, h1, h2, h3, h4⟩ := exec_wait ‹_›
  exact ⟨_, _, _, _, fm, ty, g, as, ‹_›, ‹_›, Array.getElem?_eq_getElem ‹_›, h1, h2, h3, h4⟩

/-- Thread state `s` in context `c`: if it waits, it is at its call. -/
def Status.AtCall (c : Ctx) : Status → Prop
  | .wait t i _ fn => t.AtCall c i fn
  | _ => True

/-- Every thread of `g` that waits is at its call, in its context `c n`. -/
def Grid.AtCalls (c : Nat → Ctx) (g : Grid) : Prop :=
  ∀ (n : Nat) s, g.threads[n]? = some s → s.AtCall (c n)

/-- A step of thread `n` keeps `Grid.AtCalls`: a thread whose step waits is at its call. -/
theorem Grid.advance_atCalls {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.advance c n = .ok (some g')) (hg : g.AtCalls c) : g'.AtCalls c := by
  unfold Grid.AtCalls at hg ⊢
  unfold Grid.advance at h
  split at h
  · simp only [bind, Except.bind] at h
    split at h
    · cases h
    · rename_i r hr
      split at h <;> cases h
      · exact set!_inv (P := fun j (s : Status) => s.AtCall (c j)) hg trivial
      · exact set!_inv (P := fun j (s : Status) => s.AtCall (c j)) hg (step_wait hr)
      · exact set!_inv (P := fun j (s : Status) => s.AtCall (c j)) hg trivial
  · cases h

/-- A fire keeps `Grid.AtCalls`: the threads it resumes run. -/
theorem Grid.fire_atCalls {L : Launch} {c : Nat → Ctx} {g g' : Grid} {n : Nat}
    (h : g.fire L c n = .ok (some g')) (hg : g.AtCalls c) : g'.AtCalls c := by
  unfold Grid.fire at h
  repeat' (first | split at h | (simp only [bind, Except.bind, pure, Except.pure] at h))
  all_goals cases h
  all_goals first
    | cases ‹throw _ = Except.ok _›
    | exact resumeAll_inv (P := fun j s => s.AtCall (c j)) ‹_› (fun _ _ _ _ _ _ _ _ => trivial) hg

/-- In every grid reachable from one whose waiting threads are at their calls (a grid of running
threads, as `Grid.start` gives), every waiting thread is at its call. -/
theorem Grid.reach_atCalls {L : Launch} {c : Nat → Ctx} {g g' : Grid}
    (h : Relation.ReflTransGen (Grid.Step L c) g g') (hg : g.AtCalls c) : g'.AtCalls c :=
  Grid.reach_inv (fun _ _ _ => Grid.advance_atCalls) (fun _ _ _ => Grid.fire_atCalls) h hg

/-- Every thread of the grid that `Grid.start` gives runs at the start of kernel `fn`
(`Thread.start`), with some arguments; and there is one only if the blocks of threads are not
empty. -/
theorem Grid.start_run {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) :
    ∀ (j : Nat) s, g.threads[j]? = some s →
      0 < volume L.block ∧ ∃ as t, Thread.start fn as = .ok t ∧ s = .run t := by
  unfold Grid.start at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  split at h
  · cases h
  rename_i v2 h2
  cases h
  refine foldlM_mem_inv (P := fun r : Mem × Array Status =>
      ∀ (j : Nat) s, r.2[j]? = some s → 0 < volume L.block ∧
        ∃ as t, Thread.start fn as = .ok t ∧ s = .run t)
    (Q := (· < volume L.grid * volume L.block))
    (fun r k r' hk hs hr => ?_) _ _ (fun _ hk => List.mem_range.1 hk) h2
    (fun _ _ h => by simp at h)
  simp only [pure, Except.pure] at hs
  split at hs
  · cases hs
  · split at hs
    · cases hs
    · cases hs
      intro j s hj
      rw [Array.getElem?_push] at hj
      split at hj
      · cases hj
        exact ⟨Nat.pos_of_ne_zero fun h0 => by simp [h0] at hk, _, _, ‹_›, rfl⟩
      · exact hr j s hj

/-- Every thread of the grid that `Grid.start` gives runs, so its waiting threads are at their
calls in every context. -/
theorem Grid.start_atCalls {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (c' : Nat → Ctx) : g.AtCalls c' :=
  fun j s hs => by
    obtain ⟨-, _, _, -, rfl⟩ := Grid.start_run h j s hs
    trivial

/-- Waiting threads at their calls from the start: in every grid reachable from the grid that
`Grid.start` gives, every waiting thread is at its call. -/
theorem Grid.start_reach_atCalls {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g' : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c))
    (hr : Relation.ReflTransGen (Grid.Step L c) g g') : g'.AtCalls c :=
  Grid.reach_atCalls hr (Grid.start_atCalls h c)

end Waits


section Start

variable {S : Nat → Prop}

/-- The bound of a value of `xs` is at most the bound of `xs`. -/
theorem Val.bound_le : ∀ {xs : List Val} {x : Val}, x ∈ xs → x.bound ≤ Val.bounds xs
  | _ :: _, _, .head _ => Nat.le_max_left _ _
  | _ :: _, _, .tail _ h => Nat.le_trans (Val.bound_le h) (Nat.le_max_right _ _)

/-- A value names only numbers below its bound. -/
theorem Val.namesIn_bound : ∀ v : Val, v.NamesIn (· < v.bound)
  | .ptr p => Nat.lt_succ_self p.block
  | .vec xs | .agg xs => Val.allNamesIn_iff.2 fun x hx =>
    (Val.namesIn_bound x).mono fun _ hb => Nat.lt_of_lt_of_le hb (Val.bound_le hx)
  | .bits .. | .poison | .undef => trivial

/-- The start's check gives that `next` is positive and that every argument value names only
numbers below `next`. -/
theorem Mem.checkClosed_ok {m : Mem} {vs : List Val} {u : Unit} (h : m.checkClosed vs = .ok u) :
    0 < m.next ∧ ∀ v ∈ vs, v.NamesIn m.Known := by
  unfold Mem.checkClosed at h
  split at h
  · cases h
  · split at h
    · rename_i h0 hn
      simp only [Mem.namesBelow, Bool.and_eq_true, decide_eq_true_eq] at hn
      refine ⟨by omega, fun v hv => (Val.namesIn_bound v).mono fun _ hb =>
        Or.inl (Nat.lt_of_lt_of_le hb (Nat.le_trans (Val.bound_le hv) hn.1))⟩
    · cases h

/-- A launch allocation that succeeds, of bytes naming known numbers, keeps the pointer bytes
naming known numbers, keeps every known number known, and knows its block's number. -/
theorem Mem.allocNext_closed {l : Layout} {m m' : Mem} {space size align : Nat}
    {live readOnly : Bool} {owner : Owner} {addr gaddr : Nat} {init : List MemByte} {d : Nat}
    (h : m.allocNext l space size align live readOnly owner addr gaddr init = .ok (m', d))
    (hm : m.BytesIn m.Known) (hinit : ∀ p j, MemByte.ptr p j ∈ init → m.Known p.block) :
    m'.BytesIn m'.Known ∧ (∀ b, m.Known b → m'.Known b) ∧ m'.Known d := by
  unfold Mem.allocNext at h
  split at h
  · cases h
  · cases h
    have hk : ∀ b, m.Known b →
        (m.alloc l space size align live readOnly owner addr gaddr init).1.Known b := by
      rintro b (hb | hb)
      · left
        simp only [Mem.alloc]
        omega
      · right
        simp only [Mem.alloc, Mem.set]
        split <;> simp_all
    exact ⟨Mem.alloc_bytesIn (hm.mono hk) (fun p j hp => hk _ (hinit p j hp)) l _ _ _ _ _ _ _ _
      none, hk, Or.inl (Nat.lt_succ_self _)⟩

/-- The shared memory of a block of threads keeps the pointer bytes naming known numbers and
every known number known, and its table names known numbers. -/
theorem shared_closed {l : Layout} {gs : List Global} {dyn c : Nat} {ch : Nat → Nat} {m m' : Mem}
    {tab : List (String × Ptr)} (h : shared l gs dyn c ch m = .ok (m', tab))
    (hm : m.BytesIn m.Known) :
    m'.BytesIn m'.Known ∧ (∀ b, m.Known b → m'.Known b) ∧ ∀ x ∈ tab, m'.Known x.2.block := by
  unfold shared at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  · rename_i v hv
    obtain ⟨hb1, hk1, hd⟩ := Mem.allocNext_closed hv hm (by simp)
    have := foldlM_inv (P := fun r : Mem × List (String × Ptr) => r.1.BytesIn r.1.Known ∧
        (∀ b, m.Known b → r.1.Known b) ∧ r.1.Known v.2 ∧ ∀ x ∈ r.2, r.1.Known x.2.block)
      (fun r gi r' hs hr => ?_) _ _ h ⟨hb1, hk1, hd, by simp⟩
    · exact ⟨this.1, this.2.1, this.2.2.2⟩
    obtain ⟨m1, acc⟩ := r
    obtain ⟨g, i⟩ := gi
    obtain ⟨hr1, hr2, hr3, hr4⟩ := hr
    simp only [pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hs
    split at hs
    · cases hs
    · split at hs
      · split at hs
        · cases hs
        · cases hs
          refine ⟨hr1, hr2, hr3, ?_⟩
          rintro x (_ | ⟨_, hx⟩)
          · exact hr3
          · exact hr4 x hx
      · split at hs
        · cases hs
        · rename_i v' hv'
          cases hs
          obtain ⟨hb2, hk2, hd2⟩ := Mem.allocNext_closed hv' hr1 (by simp)
          refine ⟨hb2, fun b hb => hk2 _ (hr2 b hb), hk2 _ hr3, ?_⟩
          rintro x (_ | ⟨_, hx⟩)
          · exact hd2
          · exact hk2 _ (hr4 x hx)
      · cases hs

/-- The arguments of a launch keep the pointer bytes naming known numbers and every known number
known, and name known numbers if the argument values do. -/
theorem launchArgs_closed {l : Layout} {m m' : Mem} {n : Nat} {fn : Func} {args vs : List Val}
    {ch : Nat → Nat} (h : launchArgs l m n fn args ch = .ok (m', vs)) (hm : m.BytesIn m.Known)
    (hargs : ∀ v ∈ args, v.NamesIn m.Known) :
    m'.BytesIn m'.Known ∧ (∀ b, m.Known b → m'.Known b) ∧ ∀ v ∈ vs, v.NamesIn m'.Known := by
  refine foldlM_mem_inv (P := fun r : Mem × List Val => r.1.BytesIn r.1.Known ∧
      (∀ b, m.Known b → r.1.Known b) ∧ ∀ v ∈ r.2, v.NamesIn r.1.Known)
    (Q := fun pv : (Param × Val) × Nat => pv.1.2.NamesIn m.Known)
    (fun r pv r' hq hs hr => ?_) _ _ (fun pv hpv => hargs _
      (List.of_mem_zip (List.fst_mem_of_mem_zipIdx hpv)).2) h ⟨hm, fun _ h => h, by simp⟩
  obtain ⟨m1, acc⟩ := r
  obtain ⟨⟨p, v⟩, i⟩ := pv
  obtain ⟨hr1, hr2, hr3⟩ := hr
  have hv : v.NamesIn m1.Known := Val.NamesIn.mono hr2 hq
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at hs
  split at hs
  · split at hs
    · split at hs
      · cases hs
      · rename_i v' hv'
        cases hs
        obtain ⟨hb2, hk2, hd2⟩ := Mem.allocNext_closed hv' hr1
          (encode_namesIn l _ ‹_› hv)
        refine ⟨hb2, fun b hb => hk2 _ (hr2 b hb), ?_⟩
        simp only [List.mem_append, List.mem_singleton]
        rintro w (hw | rfl)
        · exact (hr3 w hw).mono hk2
        · exact hd2
    · cases hs
  · split at hs
    · cases hs
    · cases hs
      refine ⟨hr1, hr2, ?_⟩
      simp only [List.mem_append, List.mem_singleton]
      rintro w (hw | rfl)
      · exact hr3 w hw
      · exact withAttrs_namesIn ‹_› hv

/-- A thread at the start of a kernel names only the numbers its arguments name. -/
theorem Thread.start_namesIn {fn : Func} {as : List Val} {t : Thread}
    (h : Thread.start fn as = .ok t) (has : ∀ v ∈ as, v.NamesIn S) : t.NamesIn S := by
  unfold Thread.start at h
  split at h
  · cases h
    intro f hf r v hr
    simp only [List.mem_singleton] at hf
    subst hf
    obtain ⟨q, hq, rfl⟩ := Option.map_eq_some_iff.1 hr
    exact has _ (List.of_mem_zip (List.mem_of_find?_eq_some hq)).2
  · cases h

/-- **The start's grid is closed**: for every program, kernel, launch,
argument values, address choice and oracle, if the launch on memory `m` starts and every pointer
byte below the size of a block of `m` names a number below `next` or with a block, the grid is
closed. The start's check gives the rest (`Mem.checkClosed_ok`); it checks the bytes of the blocks
below `next` only, so the premise is about the blocks from `next` on, which a closed memory does
not have (`Mem.Closed.bytesIn`). -/
theorem Grid.start_closed {prog : Program} {fn : Func} {L : Launch} {args : List Val} {m : Mem}
    {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (hm : m.BytesIn m.Known) :
    g.Closed c := by
  unfold Grid.start at h
  simp only [bind, Except.bind] at h
  split at h
  · cases h
  split at h
  · cases h
  rename_i u hu
  obtain ⟨hpos, hargs⟩ := Mem.checkClosed_ok hu
  split at h
  · cases h
  rename_i v1 h1
  have I1 := foldlM_inv (P := fun r : Mem × List (List (String × Ptr)) =>
      r.1.BytesIn r.1.Known ∧ (∀ b, m.Known b → r.1.Known b) ∧
        ∀ tab ∈ r.2, ∀ x ∈ tab, r.1.Known x.2.block)
    (fun r k r' hs hr => by
      simp only [pure, Except.pure] at hs
      split at hs
      · cases hs
      · rename_i v hv
        cases hs
        obtain ⟨hb2, hk2, ht2⟩ := shared_closed hv hr.1
        refine ⟨hb2, fun b hb => hk2 _ (hr.2.1 b hb), ?_⟩
        simp only [List.mem_append, List.mem_singleton]
        rintro tab (htab | rfl) x hx
        · exact hk2 _ (hr.2.2 tab htab x hx)
        · exact ht2 x hx) _ _ h1 ⟨hm, fun _ h => h, by simp⟩
  split at h
  · cases h
  rename_i v2 h2
  have I2 := foldlM_inv (P := fun r : Mem × Array Status =>
      r.1.BytesIn r.1.Known ∧ (∀ b, v1.1.Known b → r.1.Known b) ∧
        ∀ (j : Nat) s, r.2[j]? = some s → s.NamesIn r.1.Known)
    (fun r k r' hs hr => by
      simp only [pure, Except.pure] at hs
      split at hs
      · cases hs
      · rename_i v hv
        split at hs
        · cases hs
        · cases hs
          obtain ⟨hb2, hk2, ha2⟩ := launchArgs_closed hv hr.1
            (fun x hx => (hargs x hx).mono fun b hb => hr.2.1 b (I1.2.1 b hb))
          refine ⟨hb2, fun b hb => hk2 _ (hr.2.1 b hb), fun j s hj => ?_⟩
          rw [Array.getElem?_push] at hj
          split at hj
          · cases hj
            exact Thread.start_namesIn ‹_› ha2
          · exact (hr.2.2 j s hj).mono hk2) _ _ h2 ⟨I1.1, fun _ h => h, by simp⟩
  cases h
  simp only [Mem.compact_eq]
  refine ⟨I2.2.1 0 (I1.2.1 0 (Or.inl hpos)), I2.2.2, I2.1, fun n x p hp => ?_⟩
  obtain ⟨l₁, l₂, hl, -⟩ := List.lookup_eq_some_iff.1 hp
  have hmem : (x, p) ∈ v1.2.getD (n / volume L.block) [] := by
    rw [hl]
    simp
  rw [List.getD_eq_getElem?_getD] at hmem
  cases hk : v1.2[n / volume L.block]? with
  | none => simp [hk] at hmem
  | some tab =>
    rw [hk, Option.getD_some] at hmem
    exact I2.2.1 _ (I1.2.2 tab (List.mem_of_getElem? hk) _ hmem)

/-- A closed memory's pointer bytes name known numbers. -/
theorem Mem.Closed.bytesIn {m : Mem} {vs : List Val} (h : m.Closed vs) : m.BytesIn m.Known :=
  fun c b i p j hc hi hp => Or.inl (h.bytes c b i p j hc hi hp)

/-- **The closed-grid invariant from the start**: every grid reachable from the grid that
`Grid.start` gives is closed, for every program, kernel, launch, argument values, address choice and
oracle, if every pointer byte below the size of a block of the caller's memory names a number below
`next` or with a block. -/
theorem Grid.start_reach_closed {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g' : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (hm : m.BytesIn m.Known)
    (hr : Relation.ReflTransGen (Grid.Step L c) g g') : g'.Closed c :=
  Grid.reach_closed hr (Grid.start_closed h hm)

/-- **Pending accesses from the start**: a running thread of the grid that `Grid.start` gives has
the same pending accesses in every grid reachable from it, under `Grid.start_closed`'s premise. -/
theorem Grid.start_pending {prog : Program} {fn : Func} {L : Launch} {args : List Val}
    {m : Mem} {ch : Nat → Nat} {oracle : Nat → Nat → Nat} {g g' : Grid} {c : Nat → Ctx}
    (h : Grid.start prog fn L args m ch oracle = .ok (g, c)) (hm : m.BytesIn m.Known)
    (hr : Relation.ReflTransGen (Grid.Step L c) g g') {n : Nat} {t : Thread}
    (ht : g.threads[n]? = some (.run t)) : t.pending (c n) g'.mem = t.pending (c n) g.mem :=
  Grid.pending_reach (Grid.start_closed h hm) hr ht

end Start

end MojoProof.Sem
