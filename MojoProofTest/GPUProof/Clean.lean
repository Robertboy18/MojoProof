import MojoProofTest.GPUProof.Toy
import Mathlib.Algebra.Order.BigOperators.Group.Finset

/-!
# `Clean` at the toy machine

An instance of `Clean`, `GoodStart`, `Live` and `Bad` at the toy machine
(MojoProofTest/GPUProof/Toy.lean), for a family of programs at every size: each of `n` threads
writes a value `v` to its own `c` bytes `[c t, c t + c)` of buffer `0` (`own`), on every memory
whose buffer `0` has at least `c * n` bytes (`own_clean`). `own_not_bad` shows that no state
reachable from that good start is `Bad`.

The proof keeps an invariant on every reachable state (`Inv`): the launch and the room in buffer
`0` stay, each thread has returned or has its write or nothing left, and every event of the trace
is a thread's write of its own bytes (`OwnWrites`). Two such writes by two threads share no byte,
and two by one thread are ordered by its program order, so `racy` passes the trace
(`racy_ownWrites`, through `racy_iff`); they are not frozen reads, so `kept` keeps it. Each step
lowers the threads' remaining work (`work`), so every run is finite.

`own_clean_zeros` is the instance on a buffer of exactly `c * n` zero bytes. The `#guard`s run it
at 3 threads of width 2 and at 7 threads of width 5, and check that the mutant with one byte too
few faults.
-/

open GPUProof MojoProofTest.GPUProof.Toy

namespace MojoProofTest.GPUProof.Clean

/-- Thread `t`'s write of the value `v` to its own `c` bytes `[c t, c t + c)` of buffer `0`,
through proxy `false`. -/
def ownIns (c : Nat) (v : UInt8) (t : Nat) : Ins :=
  .write 0 ((c : Int) * t) c v false

/-- The program of thread `t`: its own write (`ownIns`) and nothing else. -/
def own (c : Nat) (v : UInt8) (t : Nat) : List Ins :=
  [ownIns c v t]

/-- Every event of trace `tr` is a thread's write of its own `c` bytes of buffer `0`, through
proxy `false`. -/
def OwnWrites (c : Nat) (tr : List Ev) : Prop :=
  ∀ e ∈ tr, ∃ t, e = acc t 0 ((c : Int) * t) c .write false

/-- The invariant of the runs of `own c v` on `n` threads. -/
structure Inv (n c : Nat) (v : UInt8) (s : St) : Prop where
  /-- The invariant from its four fields, at every `n`, `c`, `v` and state. -/
  mk ::
  /-- The launch has `n` threads. -/
  n_eq : s.n = n
  /-- Buffer `0` has at least `c * n` bytes. -/
  room : ∃ L, (s.mem 0).map List.length = some L ∧ c * n ≤ L
  /-- Each thread has returned, or is a thread of the launch with its write or nothing left. -/
  th : ∀ t, s.th t = .done ∨ (t < n ∧ (s.th t = .run [] ∨ s.th t = .run (own c v t)))
  /-- Every event of the trace is a thread's write of its own bytes. -/
  trace : OwnWrites c s.trace

/-- Two own writes by threads `t` and `t'` that share a byte are by one thread, for every width
`c`: if `c t + k = c t' + k'` with `k, k' < c`, then `t = t'`. -/
theorem eq_of_mul_add {c t t' k k' : Nat} (hk : k < c) (hk' : k' < c)
    (h : c * t + k = c * t' + k') : t = t' := by
  rcases Nat.lt_trichotomy t t' with h1 | h1 | h1
  · have h2 := Nat.mul_le_mul (Nat.le_refl c) (Nat.succ_le_of_lt h1)
    rw [Nat.mul_succ] at h2
    omega
  · exact h1
  · have h2 := Nat.mul_le_mul (Nat.le_refl c) (Nat.succ_le_of_lt h1)
    rw [Nat.mul_succ] at h2
    omega

/-- The race check passes every trace of own writes, at every width `c`. -/
theorem racy_ownWrites {c : Nat} {tr : List Ev} (h : OwnWrites c tr) : racy toy tr = false := by
  rw [Bool.eq_false_iff]
  intro hr
  obtain ⟨i, j, a, b, hij, ha, hb, hc, ho⟩ := (racy_iff toy).1 hr
  obtain ⟨t, hta⟩ := h _ (List.mem_of_getElem? ha)
  obtain ⟨t', htb⟩ := h _ (List.mem_of_getElem? hb)
  obtain rfl := Event.access.inj hta
  obtain rfl := Event.access.inj htb
  simp only [Access.conflict, Bool.and_eq_true, List.any_eq_true, decide_eq_true_eq] at hc
  obtain ⟨⟨⟨l, hl, hl'⟩, -⟩, -⟩ := hc
  simp only [Access.locs, List.mem_map, List.mem_range] at hl hl'
  obtain ⟨k, hk, rfl⟩ := hl
  obtain ⟨k', hk', hkk⟩ := hl'
  have hp : ((0 : Nat), (c : Int) * t' + k') = (0, (c : Int) * t + k) := hkk
  simp only [Prod.mk.injEq, true_and] at hp
  have htt : t' = t := eq_of_mul_add hk' hk (by exact_mod_cast hp)
  subst htt
  apply ho
  refine Or.inl ⟨rfl, Relation.TransGen.single ?_⟩
  simp [edge, ha, hb, hij, Event.agents]
  refine Or.inl ⟨_, List.mem_singleton_self _, ?_⟩
  exact Lean.Grind.decide_eq_true (eq_true (List.mem_singleton_self _))

/-- Every trace of own writes keeps its frozen reads, since it has none, at every width `c`. -/
theorem kept_ownWrites {c : Nat} {tr : List Ev} (h : OwnWrites c tr) : kept toy tr = true :=
  (kept_iff toy).2 fun _ a _ ha _ hf => by
    obtain ⟨t, he⟩ := h _ ha
    injection he with he
    subst he
    cases hf

/-- Buffer `b'` of memory `store m b off len f` has as many bytes as in `m`, for every store. -/
theorem store_length (m : Memory) (b : Nat) (off : Int) (len : Nat) (f : UInt8 → UInt8)
    (b' : Nat) : (store m b off len f b').map List.length = (m b').map List.length := by
  by_cases h : b' = b
  · rw [h]
    cases hm : m b <;> simp [store, hm]
  · simp [store, h]

/-- A thread `t < n` of a state of the invariant may run its own write: its bytes are in
bounds. -/
theorem fits_own {n c : Nat} {v : UInt8} {s : St} (hs : Inv n c v s) {t : Nat} (htn : t < n) :
    fits s.mem (ownIns c v t) = true := by
  obtain ⟨L, hL, hcL⟩ := hs.room
  obtain ⟨bs, hbs, rfl⟩ := Option.map_eq_some_iff.1 hL
  have h2 : c * t + c ≤ bs.length := by
    rw [← Nat.mul_succ]
    exact Nat.le_trans (Nat.mul_le_mul (Nat.le_refl c) (Nat.succ_le_of_lt htn)) hcL
  simp only [fits, ownIns, inBounds, hbs, Bool.and_eq_true, decide_eq_true_eq]
  exact ⟨by exact_mod_cast Nat.zero_le (c * t), by exact_mod_cast h2⟩

/-- State `s` after thread `t` runs its own write: `t` has nothing left, the bytes are stored, and
the write is logged. -/
def wrote (s : St) (c : Nat) (v : UInt8) (t : Nat) : St :=
  { setTh s t (.run []) with
    mem := effect s.mem (ownIns c v t), trace := s.trace ++ logs t (ownIns c v t) }

/-- A thread `t < n` with its write left steps to `wrote`, at every state of the invariant. -/
theorem step_own {n c : Nat} {v : UInt8} {s : St} (hs : Inv n c v s) {t : Nat} (htn : t < n)
    (h1 : s.th t = .run (own c v t)) : step s (.thread t) = .ok (some (wrote s c v t)) := by
  simp only [step, h1, own]
  unfold exec
  rw [ite_eq_left (fits_own hs htn)]
  rfl

/-- At a state of the invariant the barrier never completes: no thread waits. -/
theorem complete_none {n c : Nat} {v : UInt8} {s : St} (hs : Inv n c v s) (t : Nat) :
    complete s t = .ok none := by
  rcases hs.th t with h | ⟨_, h | h⟩ <;> simp [complete, h]

/-- The remaining work of a thread: its instructions left and one more for its return. -/
def weight : Status (List Ins) Lvl → Nat
  | .run k | .wait k _ => k.length + 1
  | .done => 0

/-- The remaining work of the threads of the launch of `s`. -/
def work (s : St) : Nat :=
  ∑ u ∈ Finset.range s.n, weight (s.th u)

/-- Setting one thread `t` of the launch to a status of less work lowers `work`, for every
state. -/
theorem work_lt {s s' : St} {t : Nat} {st : Status (List Ins) Lvl} (hn : s'.n = s.n)
    (hth : s'.th = fun u => if u = t then st else s.th u) (ht : t < s.n)
    (hw : weight st < weight (s.th t)) : work s' < work s := by
  unfold work
  rw [hn, hth]
  apply Finset.sum_lt_sum
  · intro u _
    show weight (if u = t then st else s.th u) ≤ weight (s.th u)
    by_cases hu : u = t
    · rw [ite_eq_left hu, hu]
      exact Nat.le_of_lt hw
    · rw [ite_eq_right hu]
  · exact ⟨t, Finset.mem_range.2 ht, by simp [hw]⟩

/-- Every step from a state of the invariant keeps the invariant and lowers `work`. -/
theorem step_inv {n c : Nat} {v : UInt8} {s s' : St} (hs : Inv n c v s) (h : Step toy s s') :
    Inv n c v s' ∧ work s' < work s := by
  rcases h with ⟨a, ha⟩ | ⟨t, ht⟩
  · rcases a with t | j
    · change Nat at t
      change step s (.thread t) = .ok (some s') at ha
      rcases hs.th t with hd | ⟨htn, h0 | h1⟩
      · simp [step, hd] at ha
      · simp only [step, h0, Except.ok.injEq, Option.some.injEq] at ha
        subst ha
        refine ⟨⟨hs.n_eq, hs.room, fun u => ?_, hs.trace⟩, ?_⟩
        · simp only [setTh]
          by_cases hu : u = t
          · rw [ite_eq_left hu]
            exact .inl rfl
          · rw [ite_eq_right hu]
            exact hs.th u
        · exact work_lt (t := t) (st := .done) rfl rfl (by rw [hs.n_eq]; exact htn)
            (by simp [h0, weight])
      · rw [step_own hs htn h1, Except.ok.injEq, Option.some.injEq] at ha
        subst ha
        refine ⟨⟨hs.n_eq, ?_, fun u => ?_, ?_⟩, ?_⟩
        · obtain ⟨L, hL, hcL⟩ := hs.room
          exact ⟨L, (store_length s.mem 0 ((c : Int) * t) c (fun _ => v) 0).trans hL, hcL⟩
        · simp only [wrote, setTh]
          by_cases hu : u = t
          · rw [ite_eq_left hu, hu]
            exact .inr ⟨htn, .inl rfl⟩
          · rw [ite_eq_right hu]
            exact hs.th u
        · intro e he
          have he' : e ∈ s.trace ++ logs t (ownIns c v t) := he
          rcases List.mem_append.1 he' with he' | he'
          · exact hs.trace e he'
          · have he'' : e ∈ [acc t 0 ((c : Int) * t) c .write false] := he'
            exact ⟨t, List.mem_singleton.1 he''⟩
        · exact work_lt (t := t) (st := .run []) rfl rfl (by rw [hs.n_eq]; exact htn)
            (by simp [h1, weight, own])
    · exact Empty.elim j
  · change complete s t = .ok (some s') at ht
    rw [complete_none hs t] at ht
    cases ht

/-- Every state reachable from a state of the invariant is one. -/
theorem reach_inv {n c : Nat} {v : UInt8} {s₀ s : St} (h0 : Inv n c v s₀)
    (h : Reach toy s₀ s) : Inv n c v s := by
  induction h with
  | refl => exact h0
  | tail _ hst ih => exact (step_inv ih hst).1

/-- No state of the invariant faults. -/
theorem no_fault {n c : Nat} {v : UInt8} {s : St} (hs : Inv n c v s) : ¬ Faults toy s := by
  rintro (⟨a, e, ha⟩ | ⟨t, e, ht⟩)
  · rcases a with t | j
    · change step s (.thread t) = .error e at ha
      rcases hs.th t with hd | ⟨htn, h0 | h1⟩
      · simp [step, hd] at ha
      · simp [step, h0] at ha
      · rw [step_own hs htn h1] at ha
        cases ha
    · exact Empty.elim j
  · change complete s t = .error e at ht
    rw [complete_none hs t] at ht
    cases ht

/-- A state of the invariant that is not done steps. -/
theorem progress_of_inv {n c : Nat} {v : UInt8} {s : St} (hs : Inv n c v s)
    (hnd : ¬ Done toy s) : ∃ s', Step toy s s' := by
  refine Classical.byContradiction fun hno => hnd ⟨fun t _ => ?_, fun j _ => Empty.elim j⟩
  change s.th t = .done
  rcases hs.th t with hd | ⟨htn, h0 | h1⟩
  · exact hd
  · refine absurd ⟨setTh s t .done, Or.inl ⟨.thread t, ?_⟩⟩ hno
    show step s (.thread t) = .ok (some (setTh s t .done))
    simp [step, h0]
  · exact absurd ⟨wrote s c v t, Or.inl ⟨.thread t, step_own hs htn h1⟩⟩ hno

/-- Every run from a state of the invariant with `work` below `k` is finite. -/
theorem acc_of_inv {n c : Nat} {v : UInt8} :
    ∀ (k : Nat) (s : St), Inv n c v s → work s < k → Acc (fun s' s => Step toy s s') s
  | 0, _, _, h => absurd h (Nat.not_lt_zero _)
  | k + 1, s, hs, h => Acc.intro s fun s' hst =>
    acc_of_inv k s' (step_inv hs hst).1 (by have := (step_inv hs hst).2; omega)

/-- The start of `own c v` on `n` threads over a memory whose buffer `0` has `L ≥ c * n` bytes
satisfies the invariant. -/
theorem launch_inv {n c L : Nat} {v : UInt8} {m : Memory} (hm : (m 0).map List.length = some L)
    (hL : c * n ≤ L) : Inv n c v (launch (own c v) n m) where
  n_eq := rfl
  room := ⟨L, hm, hL⟩
  th u := by
    simp only [launch]
    by_cases h : u < n
    · rw [ite_eq_left h]
      exact .inr ⟨h, .inr rfl⟩
    · rw [ite_eq_right h]
      exact .inl rfl
  trace := fun _ he => nomatch he

/-- **`Clean` at the toy machine**, for every number of threads `n`, width `c`, value `v` and
memory `m` whose buffer `0` has `L ≥ c * n` bytes: from the start of `own c v` on `n` threads, no
reachable state faults, races or breaks a frozen read, every reachable state that is not done
steps, and every run is finite. -/
theorem own_clean (n c : Nat) (v : UInt8) (m : Memory) (L : Nat)
    (hm : (m 0).map List.length = some L) (hL : c * n ≤ L) :
    Clean toy (launch (own c v) n m) :=
  have h0 := launch_inv (v := v) hm hL
  ⟨fun _ hr => no_fault (reach_inv h0 hr),
   fun _ hr => racy_ownWrites (reach_inv h0 hr).trace,
   fun _ hr => kept_ownWrites (reach_inv h0 hr).trace,
   fun _ hr hnd => progress_of_inv (reach_inv h0 hr) hnd,
   acc_of_inv (work (launch (own c v) n m) + 1) _ h0 (Nat.lt_succ_self _)⟩

/-- The start of `own c v` on `n` threads over every memory is a good start of the toy machine,
which checks nothing of the caller's memory. -/
theorem own_goodStart (n c : Nat) (v : UInt8) (m : Memory) :
    GoodStart toy (launch (own c v) n m) :=
  ⟨own c v, (n, []), [], m, (), rfl, trivial⟩

/-- **No live state of the toy machine is `Bad`** from the start of `own c v` on `n` threads over
a memory whose buffer `0` has `L ≥ c * n` bytes, for every `n`, `c`, `v`, `m` and `L`: no fault,
no race in the trace or enabled, and the frozen reads kept. -/
theorem own_not_bad {n c L : Nat} {v : UInt8} {m : Memory} (hm : (m 0).map List.length = some L)
    (hL : c * n ≤ L) {s : St} (hs : Live toy (launch (own c v) n m) s) : ¬ Bad toy s := by
  have hi := reach_inv (launch_inv (v := v) hm hL) hs.2
  rintro (hf | hr | hk | (⟨a, -, ha⟩ | ⟨t, s', ht, -⟩))
  · exact no_fault hi hf
  · exact Bool.false_ne_true ((racy_ownWrites hi.trace).symm.trans hr)
  · exact Bool.false_ne_true ((kept_ownWrites hi.trace).symm.trans hk).symm
  · rcases a with t | j
    · have hl : OwnWrites c (s.trace ++ logged s (.thread t)) := by
        intro e he
        rcases List.mem_append.1 he with he | he
        · exact hi.trace e he
        · rcases hi.th t with hd | ⟨_, h0 | h1⟩
          · simp [logged, hd] at he
          · simp [logged, h0] at he
          · simp only [logged, h1, own, ownIns, logs, List.mem_singleton] at he
            exact ⟨t, he⟩
      exact Bool.false_ne_true ((racy_ownWrites hl).symm.trans ha)
    · exact Empty.elim j
  · change complete s t = .ok (some s') at ht
    rw [complete_none hi t] at ht
    cases ht

/-- Buffer `0` of `zeros k` has `k` bytes. -/
theorem zeros_length (k : Nat) : (zeros k 0).map List.length = some k := by
  simp [zeros]

/-- **`Clean` on zero bytes**: `own_clean` on a buffer of exactly `c * n` zero bytes, for every
`n`, `c` and `v`. -/
theorem own_clean_zeros (n c : Nat) (v : UInt8) :
    Clean toy (launch (own c v) n (zeros (c * n))) :=
  own_clean n c v _ _ (zeros_length _) (Nat.le_refl _)

-- the runs at 3 and 7 threads, widths 2 and 5: every thread returns, the bytes are written, and
-- the trace has one write per thread
#guard [(3, 2), (7, 5)].all fun (n, c) =>
  let z := runFor (10 * n + 10) (launch (own c 9) n (zeros (c * n)))
  allDone z && !racy toy z.trace && kept toy z.trace &&
    z.mem 0 == some (List.replicate (c * n) 9) && z.trace.length == n
-- the mutant with one byte too few faults
#guard [(3, 2), (7, 5)].all fun (n, c) =>
  match step (launch (own c 9) n (zeros (c * n - 1))) (.thread (n - 1)) with
  | .error _ => true
  | .ok _ => false

end MojoProofTest.GPUProof.Clean
