import GPUProof.Uses
import MojoProofTest.GPUProof.Laminar

/-!
# Use maps on the toy machine

`GPUProof.racy_eq_false_of_uses` on the toy machine's hand-over
(MojoProofTest/GPUProof/Laminar.lean): lane `t` of warp `0` writes byte `0` of buffer `0` at the
warp's phase `t`, and after the launch's barrier every thread may read it (`handoverUse`).

* The uses are separated at every number `k ≥ 1` of lanes per warp and every number `nw ≥ 1` of
  warps (`handover_separated`), and at two warps of 2 lanes and three warps of 5 every access of
  the run is admitted, so the run is race free through the theorem (`handover_race_free`).
* A mutant for each premise:
  * the theorem needs no laminar trace: the run with a release and an acquire appended is not
    laminar and is race free through the theorem;
  * uses that are not separated: lane `0` writes before warp `0`'s barrier and lane `0` of warp
    `1`, which the barrier does not hold, writes after it; every access is admitted and the trace
    races, so the uses are not separated;
  * an access not admitted by its use: without the launch's barrier the read is not admitted, and
    the trace races;
  * proxies: a write through proxy `false` and a read through proxy `true` after the launch's
    barrier, each admitted by its use, race, so the uses are not separated; and the use `writer`
    through proxy `false` admits no thread's read back through proxy `true`, which races.
-/

open GPUProof MojoProofTest.GPUProof.Toy MojoProofTest.GPUProof.Race
  MojoProofTest.GPUProof.Laminar

namespace MojoProofTest.GPUProof.Uses

/-- The toy launch of `n` threads and level widths `ws`, as a `toy.Launch`, so that instance
search reads it as one: a pair `(n, ws)` has type `Nat × List Nat`, which instance search does
not unfold `toy.Launch` to. -/
def toyLaunch (n : Nat) (ws : List Nat) : toy.Launch := (n, ws)

/-- Thread `u` is a member of instance `g` of the toy launch of `n` threads and level widths
`ws` exactly when `u < n` and `u`'s instance at `g`'s level is `g`. -/
theorem mem_membersOf {n : Nat} {ws : List Nat} {g : Lvl × Nat} {u : Nat} :
    u ∈ membersOf n ws g ↔ u < n ∧ groupOf ws g.1 u = g := by
  simp [membersOf]

/-- One test machine (`toy`): the hand-over's uses at `k` lanes per warp, at every byte. While
the launch's instance `(⊤, 0)` is at phase `0`, the byte is lane `min p (k - 1)`'s, through proxy
`false`, where `p` is the phase of warp `0` (instance `(1, 0)`); afterwards every thread of the
launch may read it through proxy `false`. -/
def handoverUse (k : Nat) (π : toy.Gid → Nat) (_ : toy.Loc) : Use toy :=
  if π ((⊤, 0) : Lvl × Nat) = 0 then
    .writer (.thread (min (π (((1 : Nat) : Lvl), 0)) (k - 1) : Nat)) false
  else .readers ((⊤, 0) : Lvl × Nat) false

/-- One test machine (`toy`): the hand-over's uses are separated in the launch of `nw` warps of
`k` lanes, for every `k ≥ 1` and `nw ≥ 1`: two lanes' writes are told apart by warp `0`'s phase,
and a write and a later read by the launch's phase. -/
theorem handover_separated {k nw : Nat} (hk : 0 < k) (hnw : 0 < nw) :
    Use.Separated toy (toyLaunch (k * nw) [k]) (handoverUse k) := by
  intro π π' l x y hle _ _ hx hy hc
  have hwr : x.kind.writes = true ∨ y.kind.writes = true := by
    simp only [Access.conflict, Bool.and_eq_true, Bool.or_eq_true] at hc
    exact hc.1.2
  have hkn : k ≤ k * nw := Nat.le_mul_of_pos_right k hnw
  have hlane : ∀ p, min p (k - 1) ∈ membersOf (k * nw) [k] (((1 : Nat) : Lvl), 0) := fun p => by
    have hp : min p (k - 1) < k := by omega
    refine mem_membersOf.2 ⟨by omega, ?_⟩
    simp only [groupOf, WithTop.coe_ne_top, ite_false, WithTop.untopD_coe]
    rw [show span [k] 1 = k by simp [span], Nat.div_eq_of_lt hp]
  have htop : ∀ p, min p (k - 1) ∈ membersOf (k * nw) [k] (⊤, 0) := fun p =>
    mem_membersOf.2 ⟨by omega, by simp [groupOf]⟩
  unfold handoverUse at hx hy
  by_cases h1 : π ((⊤, 0) : Lvl × Nat) = 0 <;> by_cases h2 : π' ((⊤, 0) : Lvl × Nat) = 0 <;>
    simp only [h1, h2, ↓reduceIte, Use.Admits] at hx hy
  · obtain ⟨hxw, hxp⟩ := hx
    obtain ⟨hyw, hyp⟩ := hy
    refine ⟨hxp.trans hyp.symm, ?_⟩
    have hle1 : π (((1 : Nat) : Lvl), 0) ≤ π' (((1 : Nat) : Lvl), 0) := hle _
    by_cases heq : min (π (((1 : Nat) : Lvl), 0)) (k - 1) =
      min (π' (((1 : Nat) : Lvl), 0)) (k - 1)
    · exact .inl (by rw [hxw, hyw, heq])
    · exact .inr ⟨(((1 : Nat) : Lvl), 0), ⟨_, hlane _, hxw⟩, ⟨_, hlane _, hyw⟩, by omega⟩
  · obtain ⟨hxw, hxp⟩ := hx
    obtain ⟨⟨t, ht, hyt⟩, -, hyp⟩ := hy
    exact ⟨hxp.trans hyp.symm, .inr ⟨((⊤, 0) : Lvl × Nat), ⟨_, htop _, hxw⟩, ⟨t, ht, hyt⟩,
      by omega⟩⟩
  · exact absurd (show π ((⊤, 0) : Lvl × Nat) ≤ π' (⊤, 0) from hle _) (by omega)
  · obtain ⟨-, hxk, -⟩ := hx
    obtain ⟨-, hyk, -⟩ := hy
    simp [hxk, hyk] at hwr

/-- One test machine (`toy`): the hand-over's run at two warps of 2 lanes and at three warps of
5 is race free through `GPUProof.racy_eq_false_of_uses`, with `handoverUse` admitting each of
its accesses. -/
theorem handover_race_free :
    racy toy (run true true 2 2).trace = false ∧ racy toy (run true true 5 3).trace = false :=
  ⟨racy_eq_false_of_uses (handoverUse 2) (handover_separated (k := 2) (nw := 2) (by decide)
      (by decide)) (by decide +kernel),
    racy_eq_false_of_uses (handoverUse 5) (handover_separated (k := 5) (nw := 3) (by decide)
      (by decide)) (by decide +kernel)⟩

-- and `racy` evaluates to `false` on both
#guard [(2, 2), (5, 3)].all fun (k, nw) => !racy toy (run true true k nw).trace

/-- The hand-over's run at `nw` warps of `k` lanes with a release of object `1` by thread `0`
and an acquire of it by thread `1` appended. -/
def withRelAcq (k nw : Nat) : List Ev := (run true true k nw).trace ++ [rel 0 1 0, acq 1 1 0]

/-- One test machine (`toy`): the hand-over's run with a release and an acquire appended is not
laminar for any launch, at every size: its release is not an access, a fence or a rendezvous. -/
theorem withRelAcq_not_laminar (L : toy.Launch) (k nw : Nat) :
    ¬ Laminar toy L (withRelAcq k nw) := by
  intro h
  have hm : rel 0 1 0 ∈ withRelAcq k nw := by simp [withRelAcq]
  rcases h _ hm with ⟨a, ha⟩ | ⟨_, _, _, ha⟩ | ⟨_, _, _, ha, -⟩ <;> cases ha

/-- One test machine (`toy`): the theorem needs no laminar trace. The non-laminar `withRelAcq`
at two warps of 2 lanes and three warps of 5 is race free through
`GPUProof.racy_eq_false_of_uses`. -/
theorem withRelAcq_race_free :
    racy toy (withRelAcq 2 2) = false ∧ racy toy (withRelAcq 5 3) = false :=
  ⟨racy_eq_false_of_uses (handoverUse 2) (handover_separated (k := 2) (nw := 2) (by decide)
      (by decide)) (by decide +kernel),
    racy_eq_false_of_uses (handoverUse 5) (handover_separated (k := 5) (nw := 3) (by decide)
      (by decide)) (by decide +kernel)⟩

/-- Thread `0` writes byte `0` of buffer `0`, warp `0` (threads `0` to `k - 1`) meets at its
barrier, and thread `k`, lane `0` of warp `1`, writes the byte. -/
def outsideWarp (k : Nat) : List Ev :=
  [w 0 0 1, barSync (2 * k) [k] (((1 : Nat) : Lvl), 0), w k 0 1]

/-- One test machine (`toy`): uses that are not separated. Before warp `0`'s barrier the byte is
thread `0`'s, and after it thread `k`'s, through proxy `false`; warp `0` does not contain thread
`k`. -/
def outsideUse (k : Nat) (π : toy.Gid → Nat) (_ : toy.Loc) : Use toy :=
  if π (((1 : Nat) : Lvl), 0) = 0 then .writer (.thread (0 : Nat)) false
  else .writer (.thread k) false

/-- One test machine (`toy`): at 2 and 5 lanes per warp, `outsideUse` admits every access of
`outsideWarp`, which races, so the uses are not separated (`GPUProof.racy_eq_false_of_uses`). -/
theorem outside_not_separated :
    (racy toy (outsideWarp 2) = true ∧ ¬ Use.Separated toy (toyLaunch 4 [2]) (outsideUse 2)) ∧
      (racy toy (outsideWarp 5) = true ∧ ¬ Use.Separated toy (toyLaunch 10 [5]) (outsideUse 5)) :=
  ⟨⟨by decide +kernel, fun hU => absurd
      (racy_eq_false_of_uses (tr := outsideWarp 2) (outsideUse 2) hU (by decide +kernel))
      (by decide +kernel)⟩,
    ⟨by decide +kernel, fun hU => absurd
      (racy_eq_false_of_uses (tr := outsideWarp 5) (outsideUse 5) hU (by decide +kernel))
      (by decide +kernel)⟩⟩

/-- One test machine (`toy`): without the launch's barrier, at two warps of 2 lanes and three
warps of 5, some access of the run is not admitted by `handoverUse`, and the run races. -/
theorem noTop_not_admitted :
    (racy toy (run true false 2 2).trace = true ∧
      ¬ ∀ x ∈ phases toy (toyLaunch 4 [2]) (run true false 2 2).trace, ∀ l ∈ x.1.locs toy,
        (handoverUse 2 x.2 l).Admits toy (toyLaunch 4 [2]) x.1) ∧
    (racy toy (run true false 5 3).trace = true ∧
      ¬ ∀ x ∈ phases toy (toyLaunch 15 [5]) (run true false 5 3).trace, ∀ l ∈ x.1.locs toy,
        (handoverUse 5 x.2 l).Admits toy (toyLaunch 15 [5]) x.1) :=
  ⟨⟨by decide +kernel, by decide +kernel⟩, ⟨by decide +kernel, by decide +kernel⟩⟩

/-- Thread `0` writes byte `0` of buffer `0` through proxy `false`, the `n` threads meet at the
launch's barrier, and thread `1` reads the byte through proxy `true`. -/
def proxySwap (n : Nat) : List Ev :=
  [w 0 0 1 false, barSync n [] (⊤, 0), r 1 0 1 true]

/-- One test machine (`toy`): before the launch's barrier the byte is thread `0`'s through proxy
`false`; after it the launch's threads read it through proxy `true`. -/
def proxySwapUse (π : toy.Gid → Nat) (_ : toy.Loc) : Use toy :=
  if π ((⊤, 0) : Lvl × Nat) = 0 then .writer (.thread (0 : Nat)) false
  else .readers ((⊤, 0) : Lvl × Nat) true

/-- One test machine (`toy`): at 3 and 7 threads, `proxySwapUse` admits every access of
`proxySwap`, which races, so the uses are not separated: the instance's rendezvous orders the
write before the read, but they go through two proxies with no fence between them. -/
theorem proxySwap_not_separated :
    (racy toy (proxySwap 3) = true ∧ ¬ Use.Separated toy (toyLaunch 3 []) proxySwapUse) ∧
      (racy toy (proxySwap 7) = true ∧ ¬ Use.Separated toy (toyLaunch 7 []) proxySwapUse) :=
  ⟨⟨by decide +kernel, fun hU => absurd
      (racy_eq_false_of_uses (tr := proxySwap 3) proxySwapUse hU (by decide +kernel))
      (by decide +kernel)⟩,
    ⟨by decide +kernel, fun hU => absurd
      (racy_eq_false_of_uses (tr := proxySwap 7) proxySwapUse hU (by decide +kernel))
      (by decide +kernel)⟩⟩

/-- One test machine (`toy`): each thread owns the byte at its own offset of every buffer,
through proxy `false`, at every phase. -/
def ownUse (_ : toy.Gid → Nat) (l : toy.Loc) : Use toy := .writer (.thread l.2.toNat) false

/-- One test machine (`toy`): at 3 and 7 threads, each thread's write through proxy `false` and
read back through proxy `true` without a fence (`MojoProofTest.GPUProof.Toy.crossProxy`) race,
and `ownUse`, whose writer goes through proxy `false`, admits none of the reads. -/
theorem crossProxy_not_admitted : [3, 7].all fun n =>
    racy toy (final (crossProxy false) n).trace &&
      !decide (∀ x ∈ phases toy (toyLaunch n []) (final (crossProxy false) n).trace,
        ∀ l ∈ x.1.locs toy, (ownUse x.2 l).Admits toy (toyLaunch n []) x.1) := by
  decide +kernel

end MojoProofTest.GPUProof.Uses
